%% KLANN_SECUENCIA  Cuatro poses de la pierna (figura fig_secuencia del paper)
clear; close all; clc;
set(groot,'defaultFigureCreateFcn',@(f,~) theme(f,'light'));
P = Klann_Datos(); F = zeros(2,360);
for i = 1:360, q = Klann_Posicion(179+i,P); F(:,i) = q.xF; end
figure('Color','w','Position',[100 100 1100 330]);
tiledlayout(1,4,'TileSpacing','compact','Padding','compact')
L = @(a,b) plot([a(1) b(1)],[a(2) b(2)],'k-o','LineWidth',1.5,'MarkerFaceColor','w','MarkerSize',4);
for k = 0:3
    nexttile; hold on; axis equal; grid on; box on
    q = Klann_Posicion(180+90*k,P);
    plot(F(1,:),F(2,:),'r');
    fill([q.xK(1) q.xH(1) q.xF(1)],[q.xK(2) q.xH(2) q.xF(2)],[1 .9 .8],'EdgeColor','none');
    L(q.xO,q.xC); L(q.xC,q.xE); L(q.xE,q.xK); L(q.xC,q.xK); L(q.xB,q.xE);
    L(q.xK,q.xH); L(q.xK,q.xF); L(q.xA,q.xH);
    for p = {q.xO,q.xA,q.xB}
        plot(p{1}(1),p{1}(2),'^','MarkerFaceColor',[.3 .3 .3],'MarkerEdgeColor',[.3 .3 .3]);
    end
    xlim([-132 28]); ylim([-70 90]); xlabel('x (mm)');
    if k == 0, ylabel('y (mm)'); end
    title(['\theta_2-\theta_{2,0} = ' num2str(90*k) '°']);
end
exportgraphics(gcf,fullfile('..','figuras','fig_secuencia.pdf'),'ContentType','vector');
if isfolder(fullfile('..','ppt')), exportgraphics(gcf,fullfile('..','ppt','fig_secuencia.png'),'Resolution',200); end
