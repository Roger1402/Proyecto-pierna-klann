%% KLANN_MAIN  Analisis completo de la pierna Klann reconfigurable
% Posicion (fourbar geometrico x2), comprobacion Newton-Raphson, velocidad,
% aceleracion, fuerzas (S f = t) con balance de potencias, reconfiguracion
% por radio de manivela y verificacion de la transmision por engranajes.
% Las figuras se guardan en ../overleaf/figuras con los nombres del paper.
clear; close all; clc;

P   = Klann_Datos();
N   = 360;
th2 = P.th2_0 + (0:N-1)*360/N;          % antihorario, desde la pose de la patente
thd = th2 - P.th2_0;                    % angulo relativo [deg]
outdir = fullfile('..','figuras');
if ~exist(outdir,'dir'), mkdir(outdir); end
guardar = @(nombre) exportgraphics(gcf, fullfile(outdir,[nombre '.pdf']), 'ContentType','vector');

%% 1) POSICION
Q = cell(1,N); F = zeros(2,N);
for i = 1:N
    Q{i} = Klann_Posicion(th2(i), P);
    F(:,i) = Q{i}.xF;
end
errNR = max(cellfun(@(q) Klann_NR(q,P), Q(1:10:end)));
fprintf('Newton-Raphson vs geometrico: max diferencia = %.2e rad\n', errNR);

% fase de apoyo = rama inferior de la curva entre los extremos en x
[~,i0] = min(F(1,:)); [~,i1] = max(F(1,:));
arc1 = mod(i0-1 + (0:mod(i1-i0,N)), N) + 1;
arc2 = mod(i1-1 + (0:mod(i0-i1,N)), N) + 1;
if mean(F(2,arc1)) < mean(F(2,arc2)), apoyo = arc1; else, apoyo = arc2; end
st = false(1,N); st(apoyo) = true;
fprintf('Paso: ancho = %.1f mm, alto = %.1f mm, factor de apoyo = %.2f, rectitud = %.1f mm\n', ...
    ptp(F(1,:)), ptp(F(2,:)), mean(st), ptp(F(2,st)));

% Grashof del lazo 1 y angulo de transmision
L = sort([P.r P.CE P.BE P.d1]);
fprintf('Grashof lazo 1: s+l = %.2f  <=  p+q = %.2f mm\n', L(1)+L(4), L(2)+L(3));

figure('Color','w'); hold on; axis equal; grid on
dibujar(Q{1}, P);
h1 = plot(F(1,:), F(2,:), 'r', 'LineWidth', 1.2);
h2 = plot(F(1,st), F(2,st), 'Color', [0.17 0.63 0.17], 'LineWidth', 2.5);
xlabel('x (mm)'); ylabel('y (mm)'); legend([h1 h2], {'Trayectoria del pie F','Fase de apoyo'}, 'Location','southeast')
guardar('fig_diagrama');

figure('Color','w','Position',[100 100 900 260]);
for k = 1:4
    subplot(1,4,k); hold on; axis equal; grid on
    dibujar(Q{1+(k-1)*90}, P); plot(F(1,:),F(2,:),'r');
    title(sprintf('\\theta_2-\\theta_{2,0} = %d°',(k-1)*90)); xlim([-132 28]); ylim([-70 90]); xlabel('x (mm)')
end
guardar('fig_secuencia');

%% 2) VELOCIDAD Y ACELERACION
VA = cell(1,N);
for i = 1:N, VA{i} = Klann_VelAcc(Q{i}, P); end
W = [cellfun(@(v) v.w3,VA); cellfun(@(v) v.w4,VA); cellfun(@(v) v.w5,VA); cellfun(@(v) v.w6,VA)];
A = [cellfun(@(v) v.a3,VA); cellfun(@(v) v.a4,VA); cellfun(@(v) v.a5,VA); cellfun(@(v) v.a6,VA)];
figure('Color','w','Position',[100 100 900 300]);
subplot(1,2,1); plot(thd, W); grid on; xlim([0 360]); xticks(0:60:360)
xlabel('\theta_2-\theta_{2,0} (°)'); ylabel('\omega (rad/s)')
legend('biela (3)','balancín inf. (4)','pierna (5)','balancín sup. (6)')
subplot(1,2,2); plot(thd, A); grid on; xlim([0 360]); xticks(0:60:360)
xlabel('\theta_2-\theta_{2,0} (°)'); ylabel('\alpha (rad/s^2)')
guardar('fig_omega_alpha');

vF = cell2mat(cellfun(@(v) v.vF, VA, 'UniformOutput', false));
aF = cell2mat(cellfun(@(v) v.aF, VA, 'UniformOutput', false));
figure('Color','w','Position',[100 100 900 300]);
subplot(1,2,1); plot(thd, vF); grid on; xlim([0 360]); xticks(0:60:360)
xlabel('\theta_2-\theta_{2,0} (°)'); ylabel('velocidad del pie (mm/s)'); legend('v_{Fx}','v_{Fy}')
subplot(1,2,2); plot(thd, aF); grid on; xlim([0 360]); xticks(0:60:360)
xlabel('\theta_2-\theta_{2,0} (°)'); ylabel('aceleración del pie (mm/s^2)'); legend('a_{Fx}','a_{Fy}')
guardar('fig_vel_pie');

%% 3) FUERZAS
wl = pesos_carga(st);                         % carga con rampas de 15 % en el apoyo
[Tlib, Tcar, Pc, Pe] = deal(zeros(1,N));
for i = 1:N
    [Tlib(i), ~, Pc(i), Pe(i)] = Klann_Fuerzas(Q{i}, VA{i}, P, [0;0]);
    Tcar(i) = Klann_Fuerzas(Q{i}, VA{i}, P, [0; P.W*wl(i)]);
end
fprintf('Balance de potencias: max |Pcin - Pext| = %.2e W\n', max(abs(Pc-Pe)));
fprintf('T2 max: pierna libre = %.2f mN.m, con carga = %.1f mN.m\n', 1e3*max(abs(Tlib)), 1e3*max(abs(Tcar)));
figure('Color','w','Position',[100 100 900 300]);
subplot(1,2,1); plot(thd, 1e3*Tlib, thd, 1e3*Tcar); grid on; xlim([0 360]); xticks(0:60:360)
xlabel('\theta_2-\theta_{2,0} (°)'); ylabel('T_2 (mN·m)')
legend('pierna libre (gravedad + inercia)', sprintf('con carga de apoyo F_W = %g N', P.W))
subplot(1,2,2); plot(thd, Pe, 'LineWidth', 2.5); hold on; plot(thd, Pc, '--'); grid on
xlim([0 360]); xticks(0:60:360); xlabel('\theta_2-\theta_{2,0} (°)'); ylabel('potencia (W)'); legend('P_{ext}','P_{cin}')
guardar('fig_torque');

%% 4) TRANSMISION HELICOIDAL (cap. 8)
mt = 1.5; z1 = 18; z2 = 36; phi = 20*pi/180; psi = 20*pi/180; bcara = 8; eta = 0.95;
mn  = mt*cos(psi);                                  % modulo normal
rp1 = mt*z1/2; rp2 = mt*z2/2; C = rp1 + rp2;
epsA = (sqrt((rp1+mt)^2-(rp1*cos(phi))^2) + sqrt((rp2+mt)^2-(rp2*cos(phi))^2) - C*sin(phi)) / (pi*mt*cos(phi));
epsB = bcara*tan(psi)/(pi*mt);                      % recubrimiento de cara
Tm  = max(abs(Tcar))/(z2/z1)/eta;
Ft  = max(abs(Tcar))/(rp2*1e-3);  Fa = Ft*tan(psi);
zv  = z1/cos(psi)^3;  Y = 0.33;                     % Lewis con dientes virtuales
sig = Ft/((bcara*1e-3)*(mn*1e-3)*Y)/1e6;
fprintf('Engranajes helicoidales: i = %.1f, C = %.1f mm, mn = %.2f mm, eps_a = %.2f, eps_b = %.2f, eps_total = %.2f\n', ...
    z2/z1, C, mn, epsA, epsB, epsA+epsB);
fprintf('Torque motor requerido = %.1f mN.m, Ft = %.2f N, Fa = %.2f N, Lewis = %.2f MPa (zv = %.1f)\n', ...
    1e3*Tm, Ft, Fa, sig, zv);

%% 5) RECONFIGURACION POR RADIO DE MANIVELA
figure('Color','w'); hold on; axis equal; grid on
for r = [16 18 20]
    Pr = Klann_Datos(r); Fr = zeros(2,N);
    for i = 1:N, qq = Klann_Posicion(th2(i), Pr); Fr(:,i) = qq.xF; end
    plot(Fr(1,:), Fr(2,:), 'DisplayName', sprintf('r = %d mm', r));
    Lr = sort([r Pr.CE Pr.BE Pr.d1]);
    fprintf('r = %2d mm: ancho = %.1f, alto = %.1f mm, margen Grashof = %.2f mm\n', ...
        r, ptp(Fr(1,:)), ptp(Fr(2,:)), (Lr(2)+Lr(3))-(Lr(1)+Lr(4)));
end
xlabel('x (mm)'); ylabel('y (mm)'); legend show
guardar('fig_reconfig');

%% ---------------- funciones locales ----------------
function dibujar(q, ~)
    pts = {q.xO,q.xC; q.xC,q.xE; q.xE,q.xK; q.xC,q.xK; q.xB,q.xE; q.xK,q.xH; q.xK,q.xF};
    for k = 1:size(pts,1)
        plot([pts{k,1}(1) pts{k,2}(1)], [pts{k,1}(2) pts{k,2}(2)], 'k', 'LineWidth', 2)
    end
    plot([q.xA(1) q.xH(1)], [q.xA(2) q.xH(2)], 'k', 'LineWidth', 2)
    plot([q.xO(1) q.xA(1) q.xB(1)], [q.xO(2) q.xA(2) q.xB(2)], 'k^', 'MarkerFaceColor', [.4 .4 .4])
    nombres = 'CEKHF'; X = [q.xC q.xE q.xK q.xH q.xF];
    plot(X(1,:), X(2,:), 'ko', 'MarkerFaceColor', 'w')
    for k = 1:5, text(X(1,k)+2, X(2,k)+4, nombres(k), 'FontWeight', 'bold'); end
    text(q.xO(1)+2, q.xO(2)-6, 'O'); text(q.xA(1)+2, q.xA(2)+4, 'A'); text(q.xB(1)-4, q.xB(2)-7, 'B');
end

function w = pesos_carga(st)
    % carga del suelo con rampas lineales del 15 % al inicio y fin del apoyo
    n = numel(st); w = zeros(1,n);
    idx = find(st); prev = mod(idx-2, n) + 1;
    i0 = idx(find(~st(prev), 1));
    m = numel(idx); nr = max(1, floor(0.15*m));
    for k = 0:m-1
        i = mod(i0-1+k, n) + 1;
        w(i) = min([1, (k+0.5)/nr, (m-k-0.5)/nr]);
    end
end

function d = ptp(v)
    % rango (max - min) sin depender de toolboxes
    d = max(v) - min(v);
end
