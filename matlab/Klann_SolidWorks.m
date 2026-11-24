%% KLANN_SOLIDWORKS  Trayectoria del pie del ensamble de SolidWorks contra MATLAB
clear; close all; clc;
set(groot,'defaultFigureCreateFcn',@(f,~) theme(f,'light'));
S = readtable(fullfile('..','solidworks','pie_solidworks.csv'));
P = Klann_Datos(20);  F = zeros(height(S),2);
for i = 1:height(S), q = Klann_Posicion(S.theta2_deg(i), P); F(i,:) = q.xF'; end
d = hypot(S.Fx_mm-F(:,1), S.Fy_mm-F(:,2));
fprintf('SolidWorks: ancho %.2f, alto %.2f mm | diferencia con MATLAB: media %.4f, max %.4f mm\n', ...
    max(S.Fx_mm)-min(S.Fx_mm), max(S.Fy_mm)-min(S.Fy_mm), mean(d), max(d));
[t,k] = sort(mod(S.theta2_deg,360));
figure('Color','w','Position',[100 100 900 330]);
subplot(1,2,1); hold on; axis equal; grid on
plot(F(:,1),F(:,2),'b','LineWidth',1.5); plot(S.Fx_mm,S.Fy_mm,'ro','MarkerSize',3)
xlabel('x (mm)'); ylabel('y (mm)'); legend('MATLAB','SolidWorks','Location','southoutside')
subplot(1,2,2); plot(t,F(k,1),'b',t,S.Fx_mm(k),'r.',t,F(k,2),'b',t,S.Fy_mm(k),'r.'); grid on
xlim([0 360]); xticks(0:60:360); ylim([-130 15]); xlabel('\theta_2 (°)'); ylabel('coordenadas del pie (mm)')
legend('MATLAB','SolidWorks','Location','north','Orientation','horizontal')
exportgraphics(gcf, fullfile('..','figuras','fig_solidworks.pdf'),'ContentType','vector');
