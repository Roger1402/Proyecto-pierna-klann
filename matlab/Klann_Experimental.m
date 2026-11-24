%% KLANN_EXPERIMENTAL  Prototipo (r = 20 mm) contra simulacion
% Lee los tres CSV del ensayo (carpeta ../datos):
%   encoder_r20.csv        interfaz ESP32: cuentas del encoder cada 10 ms
%   trayectoria_led.csv    OpenCV: pixel del LED del pie en cada cuadro (59.94 fps)
%   corriente_display.csv  OpenCV: corriente leida de la pantalla de la fuente (10 Hz)
% y guarda las figuras del paper en ../overleaf/figuras.
% Los tres registros son de la MISMA corrida: t_video = t_encoder + desfase.
clear; close all; clc;

datos  = fullfile('..','datos');
outdir = fullfile('..','figuras');
set(groot,'defaultFigureCreateFcn',@(f,~) theme(f,'light'));   % figuras claras para el paper
guardar = @(n) exportgraphics(gcf, fullfile(outdir,[n '.pdf']), 'ContentType','vector');

% ---------- PARAMETROS (lo unico que hay que tocar) ----------
fps    = 59.9447;     % cuadros por segundo del video
pwmMin = 99.5;        % solo se analiza el tramo con PWM = 100 %
Kt     = 0.0195;      % [N.m/A] ESTIMADA (no hay hoja de datos): Kt = Ke = (V - Vdrv - I*R)/w
KtMin  = 0.0153; KtMax = 0.0216;     % banda de incertidumbre
I0     = 0.011;       % [A] consumo con el motor parado (driver), leido en la fuente
etaRed = 0.70;        % eficiencia supuesta del reductor
etaHel = 0.95;        % eficiencia del par helicoidal
iHel   = 36/18;       % relacion del par helicoidal

%% 1) LEER LOS CSV
E = readtable(fullfile(datos,'encoder_r20.csv'));
L = readtable(fullfile(datos,'trayectoria_led.csv'));
A = readtable(fullfile(datos,'corriente_display.csv'));
te = E.t_s;  c = -(E.cuentas - E.cuentas(1));     % el encoder cuenta hacia abajo
tv = L.frame/fps;

%% 2) SINCRONIZAR Y CALIBRAR LAS CUENTAS POR VUELTA
% El LED pasa por su x maxima una vez por vuelta. Con el desfase correcto, las
% cuentas leidas en esos instantes crecen en linea recta; la pendiente es cpv.
xs = movmean(L.px_x, 5);
pk = picos(xs, 50, 30);  tp = tv(pk);
mejor = inf;
for d = 4:0.01:20
    ok = (tp-d > 8) & (tp-d < te(end));
    if nnz(ok) < 30, continue, end
    n = find(ok);  ce = interp1(te, c, tp(ok)-d);
    p = polyfit(n, ce, 1);  e = sqrt(mean((ce-polyval(p,n)).^2));
    if e < mejor, mejor = e; desfase = d; cpv = p(1); nv = numel(n)-1; end
end
fprintf('Desfase video-encoder = %.2f s | cpv = %.0f cuentas/vuelta (%d vueltas, error rms %.1f cuentas = %.1f deg)\n', ...
    desfase, cpv, nv, mejor, mejor/cpv*360);
redu = cpv/(11*4*iHel);
fprintf('Reduccion del motor = %.1f:1 (antes se suponia 34:1)\n', redu);

%% 3) VELOCIDAD DE LA MANIVELA
rpm = gradient(movmean(c,9), te)/cpv*60;
lleno = E.pwm_pct >= pwmMin;   t1 = te(find(lleno,1)) + 2;
reg = te >= t1 & te < te(end)-0.5;              % regimen a 100 %
rpmMed = (c(find(reg,1,'last'))-c(find(reg,1)))/cpv/(te(find(reg,1,'last'))-te(find(reg,1)))*60;
fprintf('Velocidad media de la manivela = %.1f rpm (rizado: desv. %.1f rpm)\n', rpmMed, std(rpm(reg)));

%% 4) TRAYECTORIA: PIXELES -> mm CON LOS PIVOTES FIJOS
% Escala tomada de O, A, B y el eje del motor (no del ancho de la trayectoria:
% eso seria obligarla a coincidir con la simulacion).
P  = Klann_Datos(20);
pp = [793 450; 709 226; 582 507; 929 582]/3 + [180 0];          % pixel de O, A, B, motor
pm = [0 0; P.xA'; P.xB'; 28.779 -28.779];                       % mm
M  = [pm ones(4,1)] \ pp;                                       % transformacion afin
resid = [pm ones(4,1)]*M - pp;
led = ([L.px_x L.px_y] - M(3,:)) / M(1:2,:);
fprintf('Escala: %.3f px/mm | residuo maximo en los pivotes = %.2f mm\n', norm(M(1,:)), max(vecnorm(resid,2,2))/norm(M(1,:)));

tl = tv - desfase;                                              % tiempo del encoder
sel = tl > t1 & tl < te(end)-0.5 & all(isfinite(led),2);
led = led(sel,:);  tl = tl(sel);
psi = mod(interp1(te, c, tl)/cpv*360, 360);                     % angulo sin cero absoluto

%% 5) FASE: BUSCAR EL CERO DE LA MANIVELA
th = 0:1:359;  F = zeros(360,2);
for i = 1:360, q = Klann_Posicion(th(i), P); F(i,:) = q.xF'; end
[Lm, Ls] = porAngulo(psi, led, th);                             % promedio de todas las vueltas
% Cero absoluto: angulo del pasador C medido sobre la imagen en 8 cuadros del video.
tC  = [40 40.2 40.4 40.6 40.8 41 41.2 41.4];         % tiempo del video [s]
thC = [355 46 85 131 176 218 254 310];               % theta2 leido en la imagen [deg]
dif = mod(thC - interp1(te, c, tC-desfase)/cpv*360, 360);
fprintf('Cero de manivela: %.1f deg (desv. de las 8 lecturas %.1f deg)\n', mean(dif), std(dif));
phi0 = round(mean(dif));
Lm = circshift(Lm, phi0, 1);  Ls = circshift(Ls, phi0, 1);      % th = psi + phi0
% Comparacion de FORMA: giro, escala y traslacion con puntos mas cercanos (ICP)
Rb = eye(2); sb = 1; tb = mean(Lm)-mean(F);
for it = 1:200
    Fa = sb*F*Rb + tb;
    D2 = (Lm(:,1)-Fa(:,1)').^2 + (Lm(:,2)-Fa(:,2)').^2;
    [dmin, ic] = min(D2, [], 2);
    [Rb, sb, tb] = procrustes2(F(ic,:), Lm);
end
mejor = sqrt(mean(dmin));
giro = atan2d(Rb(1,2), Rb(1,1));
Fa = sb*F*Rb + tb;
dist = vecnorm(Lm-F, 2, 2);
W = @(X) max(X)-min(X);
ws = W(F); wm = W(Lm); wa = W((Lm-tb)*Rb'/sb);
fprintf('Cero de manivela: theta2 = psi + %d deg\n', phi0);
fprintf('Ancho : sim %.1f | medido %.1f mm (%+.1f %%)\n', ws(1), wm(1), 100*(wm(1)/ws(1)-1));
fprintf('Alto  : sim %.1f | medido %.1f mm (%+.1f %%)\n', ws(2), wm(2), 100*(wm(2)/ws(2)-1));
fprintf('Distancia media punto a punto = %.1f mm, maxima = %.1f mm\n', mean(dist), max(dist));
fprintf('Repetibilidad entre vueltas (desv.) = %.2f mm\n', mean(vecnorm(Ls,2,2)));
fprintf('Alineada: giro %.1f deg, escala %.3f, traslacion [%.1f %.1f] mm, rms = %.2f mm | ancho %.1f, alto %.1f\n', ...
    giro, sb, tb, mejor, wa);

figure('Color','w','Position',[100 100 900 380]);
subplot(1,2,1); hold on; axis equal; grid on
plot(led(:,1), led(:,2), '.', 'Color',[.85 .75 .75], 'MarkerSize',2)
plot(F([1:end 1],1), F([1:end 1],2), 'b', 'LineWidth',1.5)
plot(Lm([1:end 1],1), Lm([1:end 1],2), 'r', 'LineWidth',1.5)
xlabel('x (mm)'); ylabel('y (mm)'); legend('LED (todas las vueltas)','simulada','medida (promedio)','Location','southoutside')
title('(a) marco de los pivotes fijos')
subplot(1,2,2); hold on; axis equal; grid on
plot(Fa([1:end 1],1), Fa([1:end 1],2), 'b', 'LineWidth',1.5)
plot(Lm([1:end 1],1), Lm([1:end 1],2), 'r', 'LineWidth',1.5)
xlabel('x (mm)'); ylabel('y (mm)'); legend('simulada, alineada','medida','Location','southoutside')
title(sprintf('(b) forma, alineada: giro %.1f°, rms %.1f mm', giro, mejor))
guardar('fig_exp_trayectoria');

figure('Color','w','Position',[100 100 900 300]);
subplot(1,2,1); plot(th, F(:,1),'b', th, Lm(:,1),'r'); grid on; xlim([0 360]); xticks(0:60:360)
xlabel('\theta_2 (°)'); ylabel('x del pie (mm)'); legend('simulada','medida')
subplot(1,2,2); plot(th, F(:,2),'b', th, Lm(:,2),'r'); grid on; xlim([0 360]); xticks(0:60:360)
xlabel('\theta_2 (°)'); ylabel('y del pie (mm)'); legend('simulada','medida')
guardar('fig_exp_xy');

%% 6) VELOCIDAD DEL PIE Y DE LA MANIVELA
w2 = rpmMed*2*pi/60;                            % rad/s
suav = @(X) movmean([X;X;X], 9, 1);             % suavizado periodico
Vs = derivar(F)*w2;  tmp = suav(Lm);  Vm = derivar(tmp(361:720,:))*w2;
[wm2, ws2] = porAngulo(mod(c(reg)/cpv*360+phi0,360), rpm(reg), th);
fprintf('Rapidez maxima del pie: sim %.0f | medida %.0f mm/s\n', max(vecnorm(Vs,2,2)), max(vecnorm(Vm,2,2)));
figure('Color','w','Position',[100 100 900 300]);
subplot(1,2,1); plot(te, rpm, 'Color',[.2 .4 .8]); grid on; xlabel('t (s)'); ylabel('n_2 (rpm)'); ylim([0 60])
title('manivela (encoder)')
subplot(1,2,2); yyaxis left
plot(th, vecnorm(Vs,2,2), th, vecnorm(Vm,2,2), '--'); ylabel('|v_F| (mm/s)')
yyaxis right; plot(th, wm2); ylabel('n_2 (rpm)'); ylim([0 60])
grid on; xlim([0 360]); xticks(0:60:360); xlabel('\theta_2 (°)'); legend('|v_F| simulada','|v_F| medida','n_2 medida')
guardar('fig_exp_velocidad');

%% 7) CORRIENTE -> TORQUE (T = Kt*I)
ta = A.t_enc_s;  Ia = A.I_fuente_A - I0;        % corriente del motor (PWM 100 %)
r1 = ta > t1 & ta < te(end)-0.5 & isfinite(Ia);
[Im, Is] = porAngulo(mod(interp1(te,c,ta(r1))/cpv*360+phi0,360), Ia(r1), th, 6);
kT2 = redu*etaRed*iHel*etaHel;                  % rotor -> manivela
Tem = Kt*Im;  T2m = Tem*kT2;
Psim = P; Psim.omega2 = w2; Psim.alpha2 = 0;  T2s = zeros(360,1);
for i = 1:360
    q = Klann_Posicion(th(i), Psim); T2s(i) = Klann_Fuerzas(q, Klann_VelAcc(q,Psim), Psim, [0;0]);
end
fprintf('Corriente del motor: media %.3f A, min %.3f, max %.3f A (desv. entre vueltas %.3f A)\n', mean(Im),min(Im),max(Im),mean(Is,'omitnan'));
fprintf('Torque electromagnetico Kt*I: media %.2f mN.m, max %.2f mN.m\n', 1e3*mean(Tem), 1e3*max(Tem));
fprintf('T2 estimado con Kt=%.4f: media %.0f, max %.0f mN.m (banda Kt: media %.0f a %.0f)\n', ...
    Kt, 1e3*mean(T2m), 1e3*max(T2m), 1e3*mean(Im)*KtMin*kT2, 1e3*mean(Im)*KtMax*kT2);
fprintf('T2 simulado sin friccion: max |T2| = %.1f mN.m\n', 1e3*max(abs(T2s)));

figure('Color','w','Position',[100 100 900 300]);
subplot(1,2,1); plot(ta, A.I_fuente_A, 'Color',[.2 .4 .8]); grid on; xlabel('t (s)'); ylabel('corriente de la fuente (A)'); ylim([0 .4])
subplot(1,2,2); hold on; grid on
fill([th fliplr(th)], 1e3*kT2*[KtMin*Im; flipud(KtMax*Im)]', [1 .85 .85], 'EdgeColor','none')
plot(th, 1e3*T2m, 'r', 'LineWidth',1.5); plot(th, 1e3*T2s, 'b', 'LineWidth',1.5)
xlim([0 360]); xticks(0:60:360); xlabel('\theta_2 (°)'); ylabel('T_2 (mN·m)')
legend('banda por K_t','estimado: K_t I','simulado sin fricción')
guardar('fig_exp_torque');


%% ---------- funciones ----------
function k = picos(x, dmin, prom)
% maximos locales separados al menos dmin muestras y altos respecto del entorno
k = [];
for i = dmin+1:numel(x)-dmin
    v = x(i-dmin:i+dmin);
    if x(i) == max(v) && x(i)-min(v) > prom && (isempty(k) || i-k(end) >= dmin), k(end+1,1) = i; end %#ok<AGROW>
end
end

function [m, s] = porAngulo(ang, Y, th, medio)
% media y desviacion de Y en una ventana de +-medio grados alrededor de th
if nargin < 4, medio = 2; end
m = nan(numel(th), size(Y,2)); s = m;
for i = 1:numel(th)
    d = abs(mod(ang-th(i)+180,360)-180) <= medio;
    m(i,:) = mean(Y(d,:),1,'omitnan');  s(i,:) = std(Y(d,:),0,1,'omitnan');
end
end

function [R, s, t] = procrustes2(X, Y)
% giro + escala + traslacion que mejor llevan X a Y (filas = puntos): Y ~ s*X*R + t
mx = mean(X); my = mean(Y); X0 = X-mx; Y0 = Y-my;
[U,S,V] = svd(X0'*Y0);  D = diag([1 sign(det(U*V'))]);
R = U*D*V';  s = trace(S*D)/sum(X0(:).^2);  t = my - s*mx*R;
end

function D = derivar(X)
% derivada periodica respecto de theta2 [por radian], 1 grado por fila
D = (circshift(X,-1,1) - circshift(X,1,1))/(2*pi/180);
end
