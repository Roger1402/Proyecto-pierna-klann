%% KLANN_ENSAYO  Graficas reales a partir de un CSV grabado con la interfaz
% Uso: 1) en la interfaz: Iniciar medicion ... Detener y guardar
%      2) correr este script y elegir el CSV (queda en Descargas)
% Se MIDE: el angulo de la manivela (encoder) y, derivando, su velocidad.
% Se CALCULA: la posicion del pie, metiendo ese angulo medido en el modelo.
% Ojo: por eso la trayectoria del pie siempre caera sobre la curva teorica;
% la validacion real de la trayectoria sale del video del LED.
clear; close all; clc;

dirDesc = fullfile(getenv('USERPROFILE'), 'Downloads');
[f, d] = uigetfile(fullfile(dirDesc, 'klann_*.csv'), 'Elige el ensayo');
if isequal(f, 0), return; end
Klann_EnsayoGraficas(fullfile(d, f));
