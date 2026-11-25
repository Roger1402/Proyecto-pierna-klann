%% KLANN_POTENCIA  Balance de potencias con la carga de apoyo de 5 N
% Verificacion de fuerzas por energia (Constans & Dyer, Ej. 7.7):
%   T2*w2 + sum(m g.v) + FW.vF = sum(m a.v + I alpha omega)
% De aqui se despeja T2 sin usar la matriz S y se compara con S\t.
clear; close all; clc;
set(groot,'defaultFigureCreateFcn',@(f,~) theme(f,'light'));
P = Klann_Datos(20); w2 = P.omega2; N = 360; th = P.th2_0+(0:N-1)*360/N; x = th-P.th2_0;
Q = cell(1,N); V = Q; F = zeros(2,N); vF = F;
for i = 1:N
    Q{i} = Klann_Posicion(th(i),P); V{i} = Klann_VelAcc(Q{i},P);
    F(:,i) = Q{i}.xF; vF(:,i) = V{i}.vF*1e-3;
end
% apoyo = rama inferior de la curva; carga con rampas de 15 % (igual que Klann_Main)
[~,i0] = min(F(1,:)); [~,i1] = max(F(1,:));
a1 = mod(i0-1+(0:mod(i1-i0,N)),N)+1; a2 = mod(i1-1+(0:mod(i0-i1,N)),N)+1;
if mean(F(2,a1)) < mean(F(2,a2)), ap = a1; else, ap = a2; end
m = numel(ap); nr = max(1,floor(.15*m)); wl = zeros(1,N);
for k = 0:m-1, wl(ap(k+1)) = min([1,(k+.5)/nr,(m-k-.5)/nr]); end
FW = [zeros(1,N); P.W*wl];
[T,Pc,Pe,T0,Pc0,Pe0] = deal(zeros(1,N)); Fp = zeros(7,N);
for i = 1:N
    [T(i),pin,Pc(i),Pe(i)] = Klann_Fuerzas(Q{i},V{i},P,FW(:,i));
    [T0(i),~,Pc0(i),Pe0(i)] = Klann_Fuerzas(Q{i},V{i},P,[0;0]);
    Fp(:,i) = structfun(@norm,pin);
end
Pm = T*w2; Pw = sum(FW.*vF,1); Pg = Pe-Pm-Pw;      % motor, carga, gravedad
Te = (Pc-Pg-Pw)/w2;                                % torque por energia
err = max(abs(Pc-Pe)); errT = max(abs(Te-T)); err0 = max(abs(Pc0-Pe0));
fprintf('Balance: max|Pcin-Pext| con 5 N = %.1e W (pierna libre %.1e W)\n',err,err0);
fprintf('Relativo a la potencia maxima del motor: %.1e %%\n',100*err/max(abs(Pm)));
fprintf('T2: max|matriz| = %.2f mN.m, max|energia-matriz| = %.1e mN.m\n',1e3*max(abs(T)),1e3*errT);
fprintf('Rango T2 con carga: %.2f a %.2f mN.m; libre %.2f a %.2f\n',1e3*[min(T) max(T) min(T0) max(T0)]);
fprintf('Potencia motor: max %.3f, min %.3f W | carga: max %.3f, min %.3f W\n',max(Pm),min(Pm),max(Pw),min(Pw));
fprintf('Energia cinetica: max|Pcin| %.4f W | gravedad max %.4f W\n',max(abs(Pc)),max(abs(Pg)));
dt = (2*pi/N)/w2;
fprintf('Por vuelta: motor %.4f mJ, carga %.4f mJ, gravedad %.1e mJ, cinetica %.1e mJ\n',1e3*dt*[sum(Pm) sum(Pw) sum(Pg) sum(Pc)]);
fprintf('Suma motor+carga+gravedad-cinetica = %.1e mJ\n',1e3*dt*sum(Pm+Pw+Pg-Pc));
fprintf('Fuerza maxima por junta O C E B K H A [N]: %s\n',mat2str(max(Fp,[],2)',3));

figure('Color','w','Position',[100 100 1050 620]); tiledlayout(2,2,'TileSpacing','compact','Padding','compact')
nexttile; area(x,FW(2,:),'FaceColor',[.85 .93 .85],'EdgeColor',[.18 .55 .34]); ax(); ylabel('F_W (N)'); ylim([0 6]); title('reacción del suelo aplicada')
nexttile; hold on; plot(x,Pm,'r','LineWidth',1.4); plot(x,Pw,'Color',[.18 .55 .34],'LineWidth',1.4); plot(x,Pg,'b',x,Pc,'k--','LineWidth',1.2); ax(); ylabel('potencia (W)')
legend({'motor T_2\omega_2','carga F_W·v_F','gravedad','cinética'},'Location','best','FontSize',8); title('términos del balance')
nexttile; plot(x,1e3*Pe,'Color',[.35 .65 .9],'LineWidth',4); hold on; plot(x,1e3*Pc,'k--','LineWidth',1.2); ax(); ylabel('potencia (mW)'); xlabel('\theta_2-\theta_{2,0} (°)')
legend('P_{ext}','P_{cin}'); title('P_{ext} = P_{cin} con 5 N')
nexttile; plot(x,1e3*T,'Color',[.95 .6 .4],'LineWidth',4); hold on; plot(x,1e3*Te,'k--','LineWidth',1.2); plot(x,1e3*T0,'b'); ax(); ylabel('T_2 (mN·m)'); xlabel('\theta_2-\theta_{2,0} (°)'); ylim([-30 45])
legend('matriz S f = t (5 N)','energía (5 N)','pierna libre','Location','north','FontSize',8); title('torque por dos métodos')
exportgraphics(gcf,fullfile('..','figuras','fig_balance5N.pdf'),'ContentType','vector');
if isfolder(fullfile('..','ppt')), exportgraphics(gcf,fullfile('..','ppt','fig_balance5N.png'),'Resolution',200); end

function ax()
grid on; xlim([0 360]); xticks(0:60:360);
end
