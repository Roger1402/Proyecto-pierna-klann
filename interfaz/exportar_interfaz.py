"""Exporta para la interfaz web: sim_data.json (cinematica y torque por grado, 3 radios)
y las piezas en STL en el marco del ensamble (mm, plano XY, +z hacia el frente)."""
import json
import math
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "analisis"), str(ROOT / "cad")]
import klann_modelo as km          # noqa: E402

OUT = Path(__file__).resolve().parent
(OUT / "modelos").mkdir(exist_ok=True)

# ---------------- simulacion ----------------
def lower_branch(F):
    n = len(F); i0, i1 = int(F[:, 0].argmin()), int(F[:, 0].argmax())
    a1 = [(i0 + k) % n for k in range((i1 - i0) % n + 1)]
    a2 = [(i1 + k) % n for k in range((i0 - i1) % n + 1)]
    low = a1 if F[a1, 1].mean() < F[a2, 1].mean() else a2
    m = np.zeros(n, bool); m[low] = True
    return m


def ramp(st, f=0.15):
    n = len(st); w = np.zeros(n); idx = [i for i in range(n) if st[i]]
    i0 = next(i for i in idx if not st[(i - 1) % n]); m = len(idx); nr = max(1, int(f * m))
    for k in range(m):
        w[(i0 + k) % n] = min(1, (k + 0.5) / nr, (m - k - 0.5) / nr)
    return w


data = {"W": 5.0, "i": 2.0, "eta": 0.95, "radios": {}}
mm = km.mass_model()
for r in (16, 18, 20):
    p = km.base_params(); p["r"] = float(r)
    cyc = km.cycle(p, 360, 2 * math.pi)
    F = np.array([q["F"] for q in cyc]); st = lower_branch(F); w = ramp(st)
    Tl, Tc = [], []
    for k, q in enumerate(cyc):
        va = km.vel_acc(q, p, 2 * math.pi)
        Tl.append(km.forces(q, va, p, np.zeros(2), mm)[0])
        Tc.append(km.forces(q, va, p, np.array([0, data["W"] * w[k]]), mm)[0])
    L = sorted([r, p["CE"], p["BE"], p["d1"]])
    data["radios"][r] = {
        "pts": {k: [[round(float(q[k][0]), 3), round(float(q[k][1]), 3)] for q in cyc] for k in "CEKHF"},
        "T_libre": [round(1e3 * t, 3) for t in Tl], "T_carga": [round(1e3 * t, 3) for t in Tc],
        "apoyo": [bool(s) for s in st],
        "metricas": {"ancho": round(float(np.ptp(F[:, 0])), 1), "alto": round(float(np.ptp(F[:, 1])), 1),
                     "factor_apoyo": round(float(st.mean()), 2), "rectitud": round(float(np.ptp(F[st, 1])), 1),
                     "grashof_s_l": round(L[0] + L[3], 2), "grashof_p_q": round(L[1] + L[2], 2)},
    }
data["fijos"] = {k: [round(float(v), 3) for v in km.P0[k]] for k in "OAB"}
data["ref"] = {k: [round(float(v), 3) for v in km.P0[k]] for k in "OCEKHF"}
(OUT / "sim_data.json").write_text(json.dumps(data))
print("sim_data.json listo")

# ---------------- piezas 3D en el marco del ensamble ----------------
import klann_parts as kp          # noqa: E402
from build123d import Pos, export_stl   # noqa: E402

piezas = {
    "placa": kp.placement("placa") * kp.placa(),
    "base": kp.placement("base") * kp.base(),
    "engranaje": kp.placement("engranaje") * kp.engranaje_manivela(),
    "pinon": kp.placement("pinon") * kp.pinon(),
    "biela": kp.placement("biela") * kp.biela(),
    "balancin_superior": kp.placement("balancin_superior") * kp.balancin_superior(),
    "balancin_inferior": kp.placement("balancin_inferior") * kp.balancin_inferior(),
    "pierna": kp.placement("pierna") * kp.pierna(),
    "sepA": Pos(*kg_A, 0) * kp.separador(13.0, "A") if (kg_A := km.P0["A"]) else None,
    "sepB": Pos(*km.P0["B"], 0) * kp.separador(18.5, "B"),
}
for n, s in piezas.items():
    export_stl(s, str(OUT / "modelos" / f"{n}.stl"), tolerance=0.05, angular_tolerance=0.2)
data_motor = {"motor_xy": [round(v, 3) for v in kp.MOTOR_XY], "z_gear": kp.Z_GEAR}
(OUT / "cad_meta.json").write_text(json.dumps(data_motor))
print("modelos STL listos:", ", ".join(piezas))
