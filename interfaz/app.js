// Banco de pruebas de la pierna Klann: 3D animado + graficas + ESP32 (Web Serial)
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { STLLoader } from "three/addons/loaders/STLLoader.js";

const $ = (id) => document.getElementById(id);
const SIM = await (await fetch("sim_data.json")).json();
const META = await (await fetch("cad_meta.json")).json();
const I_GEAR = SIM.i, ETA = SIM.eta;
// angulo (en el ensamble) del agujero del pasador C en el engranaje, para cada radio
const HOLE_ANG = { 16: -60, 18: 60, 20: 180 };

// ---------------- estado ----------------
const st = {
  modo: "sim", radio: 20, ang: 0, rpm: 0, rpmMotor: 0, pwm: 0, conectado: false,
  hist: [],                 // {t, ang, rpm, rpmMotor, T2}
  bins: Array.from({ length: 72 }, () => ({ s: 0, n: 0 })),   // T2 medido por cada 5 grados
  traza: [],                // posiciones recientes del LED
  cal: [], capturando: null,
  calibrada: false, cnt: 0, cnt0: 0, cpv: 3950, signo: 1, pwmReal: 0, buf: [], ab: null, vuelta: null,
  pwmCal: 100,              // PWM con que se calibro la recta (la recta de ejemplo: 100 %)
};
const R = () => SIM.radios[st.radio];
const ab = () => ({ a: +$("a").value, b: +$("b").value });
const T2sim = (k) => (($("carga").checked ? R().T_carga : R().T_libre)[k]);
// Motor DC: T = kt(V - ke*w)/R  ->  el torque de arranque "a" escala con el voltaje (PWM), "b" no.
const aEff = () => ab().a * ((st.modo === "esp" ? st.pwmReal : st.pwm) / st.pwmCal);
const Tmotor_de_rpm = (rpmMotor) => aEff() - ab().b * rpmMotor;   // mN.m

// ---------------- escena 3D ----------------
const vista = $("vista");
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(devicePixelRatio);
vista.appendChild(renderer.domElement);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x0b0f12);
const cam = new THREE.PerspectiveCamera(40, 1, 1, 3000);
cam.position.set(-60, 10, 330);
const ctl = new OrbitControls(cam, renderer.domElement);
ctl.target.set(-45, 0, 10); ctl.update();
scene.add(new THREE.HemisphereLight(0xffffff, 0x223344, 1.1));
const sol = new THREE.DirectionalLight(0xffffff, 1.2); sol.position.set(100, 150, 250); scene.add(sol);

const color = { placa: 0x2b2f33, base: 0x2b2f33, engranaje: 0xf28c38, pinon: 0xf2b138, biela: 0x7aa7ff,
  balancin_superior: 0x9ad0ff, balancin_inferior: 0x9ad0ff, pierna: 0xe6edf2, sepA: 0x888888, sepB: 0x888888 };
const mallas = {};
const loader = new STLLoader();
await Promise.all(Object.keys(color).map((n) => new Promise((ok) => loader.load(`modelos/${n}.stl`, (g) => {
  g.computeVertexNormals();
  const m = new THREE.Mesh(g, new THREE.MeshStandardMaterial({ color: color[n], metalness: 0.1, roughness: 0.7 }));
  m.matrixAutoUpdate = false; scene.add(m); mallas[n] = m; ok();
}, undefined, () => ok()))));

const led = new THREE.Mesh(new THREE.SphereGeometry(3.2, 20, 14), new THREE.MeshBasicMaterial({ color: 0xff3b30 }));
scene.add(led);
const ledLuz = new THREE.PointLight(0xff3b30, 2, 60); scene.add(ledLuz);
const ZLED = 26;
let lineaSim = null;
const trazaGeo = new THREE.BufferGeometry();
const trazaLinea = new THREE.Line(trazaGeo, new THREE.LineBasicMaterial({ color: 0xff6b5b }));
scene.add(trazaLinea);

function dibujarTrayectoriaSim() {
  if (lineaSim) scene.remove(lineaSim);
  const F = R().pts.F;
  const g = new THREE.BufferGeometry().setFromPoints([...F, F[0]].map(([x, y]) => new THREE.Vector3(x, y, ZLED)));
  lineaSim = new THREE.Line(g, new THREE.LineDashedMaterial({ color: 0x3fbf7f, dashSize: 3, gapSize: 2 }));
  lineaSim.computeLineDistances(); scene.add(lineaSim);
}

// transformacion rigida plana: lleva el segmento (p0,q0) de la pose de referencia a (p,q)
function rigida(m, p0, q0, p, q) {
  const d = Math.atan2(q[1] - p[1], q[0] - p[0]) - Math.atan2(q0[1] - p0[1], q0[0] - p0[0]);
  const c = Math.cos(d), s = Math.sin(d);
  const tx = p[0] - (c * p0[0] - s * p0[1]), ty = p[1] - (s * p0[0] + c * p0[1]);
  m.matrix.set(c, -s, 0, tx, s, c, 0, ty, 0, 0, 1, 0, 0, 0, 0, 1);
}
function giro(m, cx, cy, d) {
  const c = Math.cos(d), s = Math.sin(d);
  m.matrix.set(c, -s, 0, cx - c * cx + s * cy, s, c, 0, cy - s * cx - c * cy, 0, 0, 1, 0, 0, 0, 0, 1);
}

function pose(angDeg) {
  const a = ((angDeg % 360) + 360) % 360, k = Math.floor(a) % 360, k2 = (k + 1) % 360, f = a - Math.floor(a);
  const it = (v) => [v[k][0] + f * (v[k2][0] - v[k][0]), v[k][1] + f * (v[k2][1] - v[k][1])];
  const P = R().pts, ref = SIM.ref, fx = SIM.fijos;
  const C = it(P.C), E = it(P.E), K = it(P.K), H = it(P.H), F = it(P.F);
  const dGear = Math.atan2(C[1], C[0]) - HOLE_ANG[st.radio] * Math.PI / 180;
  if (mallas.engranaje) giro(mallas.engranaje, 0, 0, dGear);
  if (mallas.pinon) giro(mallas.pinon, META.motor_xy[0], META.motor_xy[1], -I_GEAR * dGear);
  if (mallas.biela) rigida(mallas.biela, ref.C, ref.E, C, E);
  if (mallas.balancin_inferior) rigida(mallas.balancin_inferior, fx.B, ref.E, fx.B, E);
  if (mallas.balancin_superior) rigida(mallas.balancin_superior, fx.A, ref.H, fx.A, H);
  if (mallas.pierna) rigida(mallas.pierna, ref.K, ref.H, K, H);
  for (const n of ["placa", "base", "sepA", "sepB"]) if (mallas[n]) mallas[n].matrix.identity();
  led.position.set(F[0], F[1], ZLED); ledLuz.position.copy(led.position);
  return { k, F };
}

function redimensionar() {
  const w = vista.clientWidth, h = vista.clientHeight;
  renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix();
  for (const id of ["gTray", "gTorque", "gRpm"]) { const c = $(id); c.width = c.clientWidth * devicePixelRatio; c.height = c.clientHeight * devicePixelRatio; }
}
addEventListener("resize", redimensionar);

// ---------------- graficas (canvas 2D) ----------------
function ejes(cv, xr, yr, xl, yl) {
  const g = cv.getContext("2d"), W = cv.width, H = cv.height, d = devicePixelRatio;
  g.clearRect(0, 0, W, H);
  const m = { l: 44 * d, r: 8 * d, t: 8 * d, b: 26 * d };
  const X = (x) => m.l + (x - xr[0]) / (xr[1] - xr[0]) * (W - m.l - m.r);
  const Y = (y) => H - m.b - (y - yr[0]) / (yr[1] - yr[0]) * (H - m.t - m.b);
  g.strokeStyle = "#2a3540"; g.fillStyle = "#8fa1b0"; g.font = `${10 * d}px Segoe UI`; g.lineWidth = d;
  for (let i = 0; i <= 4; i++) {
    const y = yr[0] + i * (yr[1] - yr[0]) / 4, x = xr[0] + i * (xr[1] - xr[0]) / 4;
    g.beginPath(); g.moveTo(m.l, Y(y)); g.lineTo(W - m.r, Y(y)); g.stroke();
    g.fillText(y.toFixed(0), 4 * d, Y(y) + 3 * d);
    g.fillText(x.toFixed(0), X(x) - 8 * d, H - 8 * d);
  }
  g.fillText(xl, W - m.r - g.measureText(xl).width, H - 16 * d);
  g.save(); g.translate(11 * d, m.t + 50 * d); g.fillText(yl, 0, 0); g.restore();
  return { g, X, Y, d };
}
function linea(c, pts, col, w = 1.5, dash = []) {
  const { g, X, Y, d } = c; g.strokeStyle = col; g.lineWidth = w * d; g.setLineDash(dash.map((v) => v * d));
  g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(X(x), Y(y)) : g.moveTo(X(x), Y(y)))); g.stroke(); g.setLineDash([]);
}

function graficar(k, F) {
  const r = R();
  // trayectoria del pie
  const c1 = ejes($("gTray"), [-135, -30], [-80, -10], "x (mm)", "y (mm)");
  linea(c1, [...r.pts.F, r.pts.F[0]], "#566573", 1.2);
  linea(c1, r.pts.F.filter((_, i) => r.apoyo[i]), "#3fbf7f", 2.5);
  linea(c1, st.traza, "#ff6b5b", 1.5);
  c1.g.fillStyle = "#ff3b30"; c1.g.beginPath(); c1.g.arc(c1.X(F[0]), c1.Y(F[1]), 5 * c1.d, 0, 7); c1.g.fill();
  // torque vs angulo
  const T = ($("carga").checked ? r.T_carga : r.T_libre);
  const lim = Math.max(10, ...T.map(Math.abs)) * 1.3;
  const c2 = ejes($("gTorque"), [0, 360], [-lim, lim], "θ₂ (°)", "mN·m");
  linea(c2, T.map((t, i) => [i, t]), "#7aa7ff", 1.8);
  const med = st.bins.map((b, i) => (b.n ? [i * 5 + 2.5, b.s / b.n] : null)).filter(Boolean);
  c2.g.fillStyle = "#f28c38"; med.forEach(([x, y]) => { c2.g.fillRect(c2.X(x) - 2 * c2.d, c2.Y(y) - 2 * c2.d, 4 * c2.d, 4 * c2.d); });
  c2.g.strokeStyle = "#e6edf2"; c2.g.beginPath(); c2.g.moveTo(c2.X(k), c2.Y(-lim)); c2.g.lineTo(c2.X(k), c2.Y(lim)); c2.g.stroke();
  c2.g.fillStyle = "#7aa7ff"; c2.g.fillText("simulado", c2.X(250), c2.Y(lim * 0.85));
  c2.g.fillStyle = "#f28c38"; c2.g.fillText(st.modo === "sim" ? "estimado (simulación)" : st.calibrada ? "estimado (encoder)" : "real: falta calibrar", c2.X(250), c2.Y(lim * 0.68));
  // rpm vs tiempo (ultimos 10 s)
  const t1 = performance.now() / 1000, h = st.hist.filter((p) => p.t > t1 - 10);
  const c3 = ejes($("gRpm"), [-10, 0], [0, Math.max(30, ...h.map((p) => p.rpm)) * 1.2], "t (s)", "rpm");
  linea(c3, h.map((p) => [p.t - t1, p.rpm]), "#f28c38", 1.8);
}

function tablaKlann() {
  const m = R().metricas, okG = m.grashof_s_l <= m.grashof_p_q;
  $("tablaK").innerHTML = `
    <tr><td>Ancho del paso</td><td>${m.ancho} mm</td></tr>
    <tr><td>Alto del paso</td><td>${m.alto} mm</td></tr>
    <tr><td>Factor de apoyo</td><td>${m.factor_apoyo}</td></tr>
    <tr><td>Rectitud del apoyo</td><td>${m.rectitud} mm</td></tr>
    <tr><td>Grashof lazo 1 (s+l ≤ p+q)</td><td class="${okG ? "ok" : "bad"}">${m.grashof_s_l} ≤ ${m.grashof_p_q} ${okG ? "✔ gira completa" : "✘"}</td></tr>
    <tr><td>Grados de libertad (Gruebler)</td><td>3(6−1) − 2·7 = 1 ✔</td></tr>`;
}

// ---------------- ESP32 por Web Serial ----------------
let puerto = null, escritor = null;
async function conectar() {
  if (st.conectado) { alert("Ya está conectado."); return; }
  if (!("serial" in navigator)) { alert("Usa Edge o Chrome: este navegador no tiene Web Serial."); return; }
  puerto = await navigator.serial.requestPort();
  await puerto.open({ baudRate: 115200 });
  escritor = puerto.writable.getWriter();
  st.conectado = true; st.lineas = 0; st.ultima = ""; st.tUlt = 0;
  document.querySelector('input[value="esp"]').checked = true; st.modo = "esp";
  // borrar lo simulado: no debe quedar dibujado como si fuera medido
  st.hist = []; st.traza = []; st.bins.forEach((b) => { b.s = 0; b.n = 0; }); st.rpm = st.rpmMotor = 0;
  st.cnt = st.cnt0 = 0; st.buf = []; st.pwm = 0; $("pwm").value = 0; $("pwmTxt").textContent = "0 %"; enviar("0");
  if (!st.timer) st.timer = setInterval(verEnlace, 400);
  const lector = puerto.readable.pipeThrough(new TextDecoderStream()).getReader();
  let buf = "";
  for (;;) {
    const { value, done } = await lector.read(); if (done) break;
    buf += value; let i;
    while ((i = buf.indexOf("\n")) >= 0) { procesarLinea(buf.slice(0, i).trim()); buf = buf.slice(i + 1); }
  }
}
async function enviar(txt) { if (escritor) await escritor.write(new TextEncoder().encode(txt + "\n")); }
function verEnlace() {
  if (st.modo !== "esp" || !st.conectado) return;
  diagnostico();
  if (st.buf.length && st.buf[0][4] !== undefined) enviar("k");   // latido (solo programa nuevo)
  const hay = st.tUlt && performance.now() - st.tUlt < 1500;
  if (st.grabando && !hay) detenerGrabacion("Se perdió la conexión.");
  else if (st.grabando) infoGrabacion();
  $("estado").classList.toggle("on", hay);
  $("estado").textContent = hay ? `Recibiendo datos (${st.lineas} líneas)`
    : st.ultima ? "Puerto abierto, texto no válido: " + st.ultima.slice(0, 50)
    : "Puerto abierto, pero NO llegan datos";
}
function procesarLinea(l) {
  if (l) st.ultima = l;
  const v = l.split(",").map(Number);
  if (v.length < 6 || v.some(Number.isNaN) || st.modo !== "esp") return;
  st.lineas++; st.tUlt = performance.now();
  const [tms, c] = v; st.pwmReal = v[5]; st.ab = v.length >= 8 ? [v[6], v[7]] : null;
  const ant = st.buf[st.buf.length - 1];
  if (ant && tms < ant[0]) { st.buf = []; st.cnt0 = 0; }          // el ESP32 se reinicio
  st.cnt = c; st.buf.push([tms, c, v[8], v[9], v[10]]);
  while (st.buf.length > 2 && tms - st.buf[0][0] > 1000) st.buf.shift();
  const s = st.signo * ($("invEnc").checked ? -1 : 1);
  const ang = ((s * (c - st.cnt0) / st.cpv * 360) % 360 + 360) % 360;
  const p = st.buf.find((x) => tms - x[0] <= 150) || ant;          // velocidad media de 150 ms
  const dt = p ? (tms - p[0]) / 60000 : 0;
  const rpm = dt > 0 ? Math.abs((c - p[1]) / st.cpv / dt) : 0;
  grabarMuestra(v, s, ang, rpm);
  registrar(ang, rpm, rpm * I_GEAR);
}

// ---------------- grabacion de ensayos (solo entre Iniciar y Detener) ----------------
const BLOQUEO = ["radio", "cpv", "btnCero", "invEnc", "btnVuelta", "nVueltas"];
function bloquear(si) {
  BLOQUEO.forEach((id) => ($(id).disabled = si));
  document.querySelectorAll('input[name="modo"]').forEach((e) => (e.disabled = si));
}
function iniciarGrabacion() {
  if (st.modo !== "esp" || !st.tUlt || performance.now() - st.tUlt > 1500) { $("recInfo").textContent = "⚠ No llegan datos del ESP32: conecta primero."; return; }
  if (st.vuelta !== null) { $("recInfo").textContent = "⚠ Termina primero de contar las vueltas."; return; }
  if (st.ensayo && st.ensayo.filas.length && !st.ensayo.guardado && !confirm("El ensayo anterior no se guardó. ¿Reemplazarlo?")) return;
  st.traza = [];
  st.ensayo = { filas: [], t0: null, ultT: 0, e0: 0, err: 0, radio: st.radio, cpv: st.cpv, pwmMax: 0, guardado: false };
  st.grabando = true; bloquear(true);
  $("btnRec").textContent = "■ Detener y guardar"; $("btnRec").classList.add("rec");
  $("btnDescartar").disabled = false; $("btnCsv").disabled = true;
  infoGrabacion();
}
function detenerGrabacion(motivo = "") {
  if (!st.grabando) return;
  st.grabando = false; bloquear(false);
  $("btnRec").textContent = "● Iniciar medición"; $("btnRec").classList.remove("rec"); $("btnDescartar").disabled = true;
  const n = st.ensayo.filas.length; $("btnCsv").disabled = !n;
  const nombre = n ? descargarEnsayo() : "";
  infoGrabacion((motivo ? "⚠ " + motivo + " " : "") + (n ? `Guardado en Descargas: ${nombre}` : "No se grabó nada."));
}
function descartarGrabacion() {
  if (!st.grabando) return;
  st.grabando = false; bloquear(false); st.ensayo = null;
  $("btnRec").textContent = "● Iniciar medición"; $("btnRec").classList.remove("rec");
  $("btnDescartar").disabled = true; $("btnCsv").disabled = true; $("recInfo").textContent = "Ensayo descartado.";
}
function grabarMuestra(v, s, ang, rpm) {
  const g = st.ensayo; if (!st.grabando) return;
  const [tms, c] = v;
  if (g.t0 === null) { g.t0 = tms; g.e0 = v[10] || 0; g.c0 = c; }
  else if (tms < g.ultT) { detenerGrabacion("El ESP32 se reinició: la medición se cortó."); return; }
  g.ultT = tms; g.err = (v[10] || 0) - g.e0; g.pwmMax = Math.max(g.pwmMax, v[5]);
  // angulo acumulado: no vuelve a 0 en cada vuelta, medido desde el ultimo "Angulo cero"
  const acum = s * (c - st.cnt0) / st.cpv * 360;
  g.giro = s * (c - g.c0) / st.cpv;
  g.filas.push([((tms - g.t0) / 1000).toFixed(3), c, acum.toFixed(3), ang.toFixed(3), rpm.toFixed(3), (rpm * I_GEAR).toFixed(3),
    v[5], v[8] ?? "", v[9] ?? "", v[10] ?? "", g.radio, g.cpv]);
}
function infoGrabacion(extra) {
  const g = st.ensayo; if (!g) return;
  const t = g.filas.length ? +g.filas[g.filas.length - 1][0] : 0;
  $("recInfo").textContent = `${st.grabando ? "GRABANDO · " : ""}${t.toFixed(1)} s · ${g.filas.length} muestras · ${(g.giro || 0).toFixed(2)} vueltas · errores ${g.err}` + (extra ? " — " + extra : "");
}
function descargarEnsayo() {
  const g = st.ensayo, d = new Date(), z = (x) => String(x).padStart(2, "0");
  const nombre = `klann_r${g.radio}_pwm${g.pwmMax}_${d.getFullYear()}${z(d.getMonth() + 1)}${z(d.getDate())}_${z(d.getHours())}${z(d.getMinutes())}${z(d.getSeconds())}.csv`;
  const txt = "t_s,cuentas,angulo_acum_deg,angulo_deg,rpm_manivela,rpm_motor,pwm_pct,nA,nB,err,radio_mm,cuentas_por_vuelta\n" + g.filas.map((f) => f.join(",")).join("\n") + "\n";
  const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([txt], { type: "text/csv" }));
  a.download = nombre; a.click(); g.guardado = true;
  return nombre;
}
$("btnRec").onclick = () => (st.grabando ? detenerGrabacion() : iniciarGrabacion());
$("btnDescartar").onclick = descartarGrabacion;
addEventListener("beforeunload", (e) => { if (st.grabando) e.preventDefault(); });

function diagnostico() {
  const b = st.buf; let net = 0, act = 0;
  if (b.length > 1) { net = Math.abs(b[b.length - 1][1] - b[0][1]); for (let i = 1; i < b.length; i++) act += Math.abs(b[i][1] - b[i - 1][1]); }
  let m, ch = "";
  const u = b[b.length - 1], p = b[0], nuevo = u && u[4] !== undefined;
  const dA = nuevo ? u[2] - p[2] : 0, dB = nuevo ? u[3] - p[3] : 0, dE = nuevo ? u[4] - p[4] : 0;
  if (nuevo) ch = `<br>pulsos/s: A <b>${dA}</b> · B <b>${dB}</b> · errores ${dE}`;
  if (nuevo && dA + dB > 20 && Math.min(dA, dB) < 0.5 * Math.max(dA, dB)) m = `⚠ Falla el canal ${dA < dB ? "A (amarillo, pin 15)" : "B (verde, pin 16)"}: llegan muchos menos pulsos que por el otro.`;
  else if (nuevo && dE > 0.05 * (dA + dB) && dA + dB > 20) m = "⚠ Señal con ruido o pulsos perdidos: revisar GND (negro), VCC y cables cerca del motor.";
  else if (act === 0 && st.pwmReal === 0) m = "Motor detenido (PWM real 0 %): mueve el PWM o gira la manivela a mano.";
  else if (act === 0) m = "⚠ Hay PWM pero las cuentas NO cambian: motor trabado o encoder sin señal (VCC a 3V3, GND, A→15, B→16).";
  else if (act > 20 && net < 0.2 * act) m = "⚠ Las cuentas oscilan sin avanzar: falta un canal del encoder (A o B).";
  else m = "Encoder leyendo bien: la pierna 3D sigue al mecanismo.";
  $("diag").innerHTML = `cuentas <b>${st.cnt}</b> · PWM real <b>${st.pwmReal} %</b>` + (st.ab ? ` · A=${st.ab[0]} B=${st.ab[1]}` : "") + ch + "<br>" + m;
}
function calibrarVuelta() {
  const n = +$("nVueltas").value || 1;
  if (st.vuelta === null) { st.vuelta = st.cnt; $("btnVuelta").textContent = "Listo, terminé"; return; }
  const d = st.cnt - st.vuelta; st.vuelta = null; $("btnVuelta").textContent = "Contar vueltas";
  if (Math.abs(d) < 50 * n) { alert("Casi no cambiaron las cuentas (" + d + "): el encoder no está leyendo."); return; }
  ponerCpv(Math.abs(d) / n, Math.sign(d));
}
function ponerCpv(cpv, signo = st.signo) {
  if (!(cpv > 0)) return;
  st.cpv = cpv; st.signo = signo; $("cpv").value = Math.round(cpv * 10) / 10;
  try { localStorage.setItem("klann_cpv", JSON.stringify([cpv, signo])); } catch {}
}
try { const g = JSON.parse(localStorage.getItem("klann_cpv")); if (g) ponerCpv(g[0], g[1]); } catch {}
$("btnVuelta").onclick = calibrarVuelta;
$("cpv").onchange = () => ponerCpv(+$("cpv").value);

// ---------------- registro y estimacion de torque ----------------
function registrar(ang, rpm, rpmMotor) {
  st.ang = ang; st.rpm = rpm; st.rpmMotor = rpmMotor;
  const T2 = rpmMotor > 1 && (st.modo === "sim" || st.calibrada) ? I_GEAR * ETA * Tmotor_de_rpm(rpmMotor) : NaN;
  const t = performance.now() / 1000;
  st.hist.push({ t, ang, rpm, rpmMotor, T2 }); if (st.hist.length > 20000) st.hist.shift();
  if (!Number.isNaN(T2)) { const b = st.bins[Math.floor(ang / 5) % 72]; b.s += T2; b.n++; }
  if (st.capturando) st.capturando.muestras.push(rpmMotor);
}

// ---------------- calibracion ----------------
function capturar() {
  const masa = +$("masa").value;
  st.capturando = { masa, muestras: [] };
  $("btnCapt").disabled = true;
  setTimeout(() => {
    const m = st.capturando.muestras; st.capturando = null; $("btnCapt").disabled = false;
    if (!m.length) { alert("No llegaron datos: conecta el ESP32 y pon el motor a girar."); return; }
    const rpm = m.reduce((a, b) => a + b, 0) / m.length;
    const T = masa / 1000 * 9.81 * (+$("rCarrete").value / 1000) * 1000;   // mN.m
    st.cal.push({ masa, rpm, T }); tablaCal();
  }, 3000);
}
function tablaCal() {
  $("tablaCal").innerHTML = "<tr><th>masa (g)</th><th>rpm motor</th><th>T (mN·m)</th></tr>" +
    st.cal.map((c) => `<tr><td>${c.masa}</td><td>${c.rpm.toFixed(1)}</td><td>${c.T.toFixed(1)}</td></tr>`).join("");
}
function ajustar() {
  const n = st.cal.length; if (n < 2) { alert("Captura al menos 2 masas (ideal 5)."); return; }
  const mx = st.cal.reduce((s, c) => s + c.rpm, 0) / n, my = st.cal.reduce((s, c) => s + c.T, 0) / n;
  const sxy = st.cal.reduce((s, c) => s + (c.rpm - mx) * (c.T - my), 0), sxx = st.cal.reduce((s, c) => s + (c.rpm - mx) ** 2, 0);
  const pend = sxy / sxx, a = my - pend * mx;
  $("a").value = a.toFixed(1); $("b").value = (-pend).toFixed(3); st.pwmCal = Math.max(1, st.pwm);
  $("calInfo").textContent = `Recta ajustada a PWM ${st.pwmCal} % con ${n} puntos: torque de arranque ≈ ${a.toFixed(0)} mN·m, vacío ≈ ${(a / -pend).toFixed(0)} rpm.`;
  st.calibrada = true; st.bins.forEach((b) => { b.s = 0; b.n = 0; });
}

// ---------------- simulacion (mismo modelo que el paper) ----------------
// velocidad del motor que resulta de la recta torque-velocidad con la carga simulada
function pasoSim(dt) {
  const k = ((Math.round(st.ang) % 360) + 360) % 360;
  const Tm = T2sim(k) / (I_GEAR * ETA);
  const rpmMotor = Math.max(0, (aEff() - Tm) / ab().b);
  const rpm = rpmMotor / I_GEAR;
  st.ang = (st.ang + rpm * 6 * dt) % 360;
  registrar(st.ang, rpm, rpmMotor);
}

// ---------------- eventos ----------------
$("btnConectar").onclick = () => conectar().catch((e) => alert("No se pudo conectar: " + e.message));
document.querySelectorAll('input[name="modo"]').forEach((r) => (r.onchange = () => {
  st.modo = r.value; $("estado").textContent = st.modo === "sim" ? "Simulación" : (st.conectado ? "ESP32 conectado" : "ESP32 sin conectar");
  st.bins.forEach((b) => { b.s = 0; b.n = 0; }); st.traza = [];
}));
$("pwm").oninput = () => { st.pwm = +$("pwm").value; $("pwmTxt").textContent = st.pwm + " %"; enviar(String(st.pwm)); };
$("btnCero").onclick = () => { st.cnt0 = st.cnt; st.ang = 0; st.traza = []; st.hist = []; st.bins.forEach((b) => { b.s = 0; b.n = 0; }); };
$("btnInv").onclick = () => enviar("r");
$("radio").onchange = () => { st.radio = +$("radio").value; tablaKlann(); dibujarTrayectoriaSim(); st.traza = []; st.bins.forEach((b) => { b.s = 0; b.n = 0; }); };
$("carga").onchange = () => st.bins.forEach((b) => { b.s = 0; b.n = 0; });
$("btnCapt").onclick = capturar;
$("btnAjuste").onclick = ajustar;
$("btnBorrar").onclick = () => { st.cal = []; tablaCal(); };
$("btnCsv").onclick = () => st.ensayo && descargarEnsayo();

// ---------------- bucle ----------------
redimensionar(); tablaKlann(); dibujarTrayectoriaSim();
let tPrev = performance.now();
function cuadro(t) {
  const dt = Math.min(0.05, (t - tPrev) / 1000); tPrev = t;
  if (st.modo === "sim") pasoSim(dt);
  const { k, F } = pose(st.ang);
  const u = st.traza[st.traza.length - 1];
  if (u && Math.hypot(u[0] - F[0], u[1] - F[1]) > 15) st.traza = [];   // salto: no unir con una recta
  if (!u || Math.hypot(u[0] - F[0], u[1] - F[1]) > 0.2) st.traza.push(F);
  if (st.traza.length > 400) st.traza.shift();
  trazaGeo.setFromPoints(st.traza.map(([x, y]) => new THREE.Vector3(x, y, ZLED)));
  const last = st.hist[st.hist.length - 1];
  $("hAng").textContent = st.ang.toFixed(0); $("hRpm").textContent = st.rpm.toFixed(1);
  $("hT").textContent = last && !Number.isNaN(last.T2) ? last.T2.toFixed(1) : "–";
  graficar(k, F);
  ctl.update(); renderer.render(scene, cam);
  requestAnimationFrame(cuadro);
}
requestAnimationFrame(cuadro);
