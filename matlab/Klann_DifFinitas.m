%% KLANN_DIFFINITAS  Verifica velocidad y aceleracion con diferencias finitas
% La solucion analitica (Klann_VelAcc) se compara con derivadas numericas
% centradas calculadas SOLO con posiciones (Klann_Posicion):
%   x'  = (x(th+h) - x(th-h)) / (2h)        * w2
%   x'' = (x(th+h) - 2x(th) + x(th-h)) / h^2 * w2^2     (alpha2 = 0)
clear; close all; clc;
set(groot,'defaultFigureCreateFcn',@(f,~) theme(f,'light'));
P  = Klann_Datos(20);  w2 = P.omega2;
th = P.th2_0 + (0:359);
h  = 0.1;                                  % paso [deg]
Va = zeros(6,360); Aa = Va;                % filas: w3 w4 w5 w6 (rad/s), vFx vFy (mm/s)
for i = 1:360
    v = Klann_VelAcc(Klann_Posicion(th(i),P), P);
    Va(:,i) = [v.w3; v.w4; v.w5; v.w6; v.vF(:)];
    Aa(:,i) = [v.a3; v.a4; v.a5; v.a6; v.aF(:)];
end
[Vn, An] = numerica(th, h, w2, P);
eV = max(abs(Vn-Va),[],2);  eA = max(abs(An-Aa),[],2);
rV = 100*eV./max(abs(Va),[],2);  rA = 100*eA./max(abs(Aa),[],2);
nom = {'w3','w4','w5','w6','vFx','vFy'};
fprintf('Paso h = %.2f deg, w2 = %.4f rad/s\n', h, w2);
fprintf('%-4s max|anal| %9.3f  err %.2e (%.1e %%) | derivada: max %9.2f  err %.2e (%.1e %%)\n', ...
    string([nom; num2cell([max(abs(Va),[],2) eV rV max(abs(Aa),[],2) eA rA]')]));

% convergencia: en diferencias centradas el error debe bajar como h^2
hs = [4 2 1 0.5 0.2 0.1];  E = zeros(2,numel(hs));
for k = 1:numel(hs)
    [Vk,Ak] = numerica(th, hs(k), w2, P);
    E(:,k) = [max(max(abs(Vk-Va),[],2)./max(abs(Va),[],2)); max(max(abs(Ak-Aa),[],2)./max(abs(Aa),[],2))]*100;
end
pend = [polyfit(log(hs),log(E(1,:)),1); polyfit(log(hs),log(E(2,:)),1)];
fprintf('Orden de convergencia: velocidad %.2f, aceleracion %.2f (esperado 2)\n', pend(1,1), pend(2,1));
fprintf('Peor error relativo con h = %.1f deg: velocidad %.1e %%, aceleracion %.1e %%\n', h, E(1,end), E(2,end));

x = th - P.th2_0;  s = 1:15:360;  col = lines(4);
figure('Color','w','Position',[100 100 1000 620]); tiledlayout(2,3,'TileSpacing','compact','Padding','compact')
nexttile; curvas(x,Va(1:4,:),Vn(1:4,:),s,col); ylabel('\omega (rad/s)'); title('velocidad angular')
legend('biela (3)','balancín inf. (4)','pierna (5)','balancín sup. (6)','dif. finitas','Location','south','FontSize',7)
nexttile; curvas(x,Va(5:6,:),Vn(5:6,:),s,col); ylabel('v_F (mm/s)'); title('velocidad del pie')
legend('v_{Fx}','v_{Fy}','dif. finitas','Location','best','FontSize',7)
nexttile([2 1]); loglog(hs,E(1,:),'o-',hs,E(2,:),'s-','LineWidth',1.3); grid on
xlabel('paso h (°)'); ylabel('error relativo máximo (%)'); title('convergencia (pendiente 2)'); legend('velocidad','aceleración','Location','northwest')
nexttile; curvas(x,Aa(1:4,:),An(1:4,:),s,col); ylabel('\alpha (rad/s^2)'); xlabel('\theta_2-\theta_{2,0} (°)'); title('aceleración angular')
nexttile; curvas(x,Aa(5:6,:),An(5:6,:),s,col); ylabel('a_F (mm/s^2)'); xlabel('\theta_2-\theta_{2,0} (°)'); title('aceleración del pie')
exportgraphics(gcf,fullfile('..','figuras','fig_difinitas.pdf'),'ContentType','vector');
if isfolder(fullfile('..','ppt')), exportgraphics(gcf,fullfile('..','ppt','fig_difinitas.png'),'Resolution',200); end

function [V, A] = numerica(th, h, w2, P)
V = zeros(6,numel(th)); A = V; hr = h*pi/180;
for i = 1:numel(th)
    m = est(th(i)-h,P); c = est(th(i),P); p = est(th(i)+h,P);
    dp = resta(p,c); dm = resta(c,m);
    V(:,i) = (dp+dm)/(2*hr)*w2;
    A(:,i) = (dp-dm)/hr^2*w2^2;
end
end

function z = est(t, P)
q = Klann_Posicion(t,P);
z = [[q.th3; q.th4; q.th5; q.th6]*pi/180; q.xF(:)];
end

function d = resta(a, b)
d = a - b;                                        % los angulos se restan sin saltos de 360
d(1:4) = atan2(sin(d(1:4)),cos(d(1:4)));
end

function curvas(x, A, N, s, col)
hold on; grid on; n = size(A,1);
for k = 1:n, plot(x,A(k,:),'Color',col(k,:),'LineWidth',1.3); end
for k = 1:n, plot(x(s),N(k,s),'ko','MarkerSize',3); end
xlim([0 360]); xticks(0:90:360)
end
