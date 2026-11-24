%% KLANN_TORQUE  Torque medido SOLO con el encoder (sin sensor de corriente)
% Idea: a PWM y voltaje fijos, un motor DC baja su velocidad casi linealmente
% con la carga:  T_m = a - b*rpm_motor   (curva torque-velocidad).
%
% Paso 1 - CALIBRACION (carrete en el eje del motor, SIN el pinon ni la pierna):
%   - mismo PWM y misma fuente que se usaran en la marcha (ej. 60 %)
%   - colgar masas conocidas del hilo del carrete (0, 100, 200, 300, 500 g)
%   - anotar la velocidad media del motor (columna rpm_motor) mientras sube cada masa
%   - torque en el eje del motor: T = m*g*(r_carrete + d_hilo/2)
% Paso 2 - MARCHA (pierna armada, mismo PWM): guardar el CSV del ESP32 y
%   convertir la velocidad en cada angulo a torque.
% Opcional: con un multimetro en serie en el +V se puede verificar la
% corriente media, pero no hace falta para este metodo.
clear; close all; clc;

%% ---------- 1) calibracion (COMPLETAR con tus mediciones) ----------
r_carrete = 10e-3;      % m, radio del carrete impreso
d_hilo    = 0.8e-3;     % m, diametro del hilo
m_kg      = [0     0.100 0.200 0.300 0.500];   % masas colgadas
rpm_motor = [NaN   NaN   NaN   NaN   NaN  ];   % <-- velocidad media medida en cada ensayo
if any(isnan(rpm_motor)), error('Completa rpm_motor con tus mediciones de calibracion.'); end
T_cal = m_kg*9.81*(r_carrete + d_hilo/2);           % N.m en el eje del motor
p = polyfit(rpm_motor, T_cal, 1);                   % T = p(1)*rpm + p(2)   (p(1) < 0)
fprintf('Curva del motor: T = %.4f %+.6f*rpm  [N.m]\n', p(2), p(1));
fprintf('Torque de arranque estimado = %.1f mN.m, velocidad en vacio = %.0f rpm\n', ...
        1e3*p(2), -p(2)/p(1));
figure('Color','w'); plot(rpm_motor, 1e3*T_cal, 'o', rpm_motor, 1e3*polyval(p, rpm_motor), '-'); grid on
xlabel('velocidad del motor (rpm)'); ylabel('torque en el eje del motor (mN·m)'); title('Curva torque-velocidad')

%% ---------- 2) marcha con la pierna ----------
archivo = 'marcha_r20.csv';           % <-- CSV copiado del Monitor Serie
D = readtable(archivo);
D = D(D.rpm_motor > 0, :);            % descartar arranque
% suavizado: media movil de 5 muestras (50 ms)
rpm = movmean(D.rpm_motor, 5);
i_gear = 2; eta = 0.95;
Tm = polyval(p, rpm);                 % torque del motor
T2 = i_gear*eta*Tm;                   % torque en la manivela
% promedio por angulo (bins de 5 grados) sobre todas las vueltas registradas
edges = 0:5:360; c = edges(1:end-1) + 2.5;
T2m = arrayfun(@(k) mean(T2(D.angulo_deg >= edges(k) & D.angulo_deg < edges(k+1))), 1:numel(c));
figure('Color','w'); plot(c, 1e3*T2m, 'k.-'); grid on; xlim([0 360]); xticks(0:60:360)
xlabel('ángulo de manivela (°)'); ylabel('T_2 medido (mN·m)')
title('Torque medido en la manivela (comparar con fig\_torque del paper)')
fprintf('Torque medio en la manivela = %.1f mN.m\n', 1e3*mean(T2m, 'omitnan'));
