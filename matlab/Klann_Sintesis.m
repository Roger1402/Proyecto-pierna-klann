%% KLANN_SINTESIS  Sintesis por optimizacion (clase 9) y analisis de sensibilidad
% Ajusta x = [r CE BE AH KH] para que el pie siga 5 marchas objetivo
% (apoyo recto de longitud S + vuelo semieliptico de altura h).
% Requiere Global Optimization Toolbox (funcion ga). Si no esta, usa
% fminsearch con varios arranques (resultado menos robusto).
clear; close all; clc;

P0 = Klann_Datos();
x0 = [P0.r P0.CE P0.BE P0.AH P0.KH];
lb = 0.85*x0; ub = 1.15*x0; ub(1) = 20.5;       % manivela <= 20.5 mm (margen de Grashof)
objetivos = [60 30; 65 35; 75 40; 70 48; 80 45];  % [S h] en mm
nombres = {'r','l_{CE}','l_{BE}','l_{AH}','l_{KH}'};

X = zeros(size(objetivos,1), numel(x0)); J = zeros(1,size(objetivos,1)); J0 = J;
tieneGA = ~isempty(ver('globaloptim'));
for k = 1:size(objetivos,1)
    T = curva_objetivo(objetivos(k,1), objetivos(k,2));
    fun = @(x) costo(x, T, P0);
    J0(k) = fun(x0);
    if tieneGA
        opts = optimoptions('ga','PopulationSize',60,'MaxGenerations',80,'Display','off', ...
                            'InitialPopulationMatrix', x0);
        [X(k,:), J(k)] = ga(fun, numel(x0), [], [], [], [], lb, ub, [], opts);
    else
        best = inf;
        for s = 1:8
            xs = lb + rand(size(x0)).*(ub - lb);
            [xx, jj] = fminsearch(@(x) fun(min(max(x,lb),ub)), xs, optimset('Display','off'));
            if jj < best, best = jj; X(k,:) = min(max(xx,lb),ub); end
        end
        J(k) = best;
    end
    fprintf('Objetivo %d (S=%d, h=%d): costo patente = %.2f mm -> optimizado = %.2f mm\n', ...
        k, objetivos(k,1), objetivos(k,2), J0(k), J(k));
end

% variacion relativa media de cada variable (como Arroyo et al., 2022)
variacion = mean(abs(X - x0)./x0, 1)*100;
figure('Color','w','Position',[100 100 900 300]);
subplot(1,2,1); bar(categorical(nombres, nombres), variacion); hold on
yline(mean(variacion), '--k'); ylabel('variación media (%)'); grid on

% elasticidad local del alto y ancho del paso (diferencias centrales de +-1 %)
g0 = paso(x0, P0); E = zeros(numel(x0), 2);
for i = 1:numel(x0)
    xp = x0; xm = x0; xp(i) = 1.01*x0(i); xm(i) = 0.99*x0(i);
    gp = paso(xp, P0); gm = paso(xm, P0);
    E(i,:) = (gp - gm)./(0.02*g0);
end
subplot(1,2,2); bar(categorical(nombres, nombres), E); grid on
ylabel('elasticidad (-)'); legend('alto del paso h','ancho del paso S')
exportgraphics(gcf, fullfile('..','figuras','fig_sensibilidad.pdf'), 'ContentType','vector');
disp(array2table(X, 'VariableNames', {'r','CE','BE','AH','KH'}))

%% ---------------- funciones locales ----------------
function T = curva_objetivo(S, h)
    t = linspace(0, 1, 120)'; a = linspace(pi, 0, 120)';
    T = [S/2 - S*t, zeros(120,1); S/2*cos(a), h*sin(a)];
end

function F = curva_pie(x, P0)
    P = P0; P.r = x(1); P.CE = x(2); P.BE = x(3); P.AH = x(4); P.KH = x(5);
    L = sort([P.r P.CE P.BE P.d1]);
    if L(1)+L(4) > L(2)+L(3) - 0.5 || L(1) ~= P.r, F = []; return, end
    th = P.th2_0 + (0:119)*3; F = zeros(120,2);
    warning('off','fourbar:noEnsamblable')
    for i = 1:120
        q = Klann_Posicion(th(i), P);
        if any(isnan(q.xF)), F = []; return, end
        F(i,:) = q.xF.';
    end
    F = F - [mean([min(F(:,1)) max(F(:,1))]), min(F(:,2))];
end

function J = costo(x, T, P0)
    F = curva_pie(x, P0);
    if isempty(F), J = 1e3; return, end
    D = sqrt((F(:,1) - T(:,1).').^2 + (F(:,2) - T(:,2).').^2);
    J = mean(min(D,[],2)) + mean(min(D,[],1));      % distancia media en ambos sentidos
end

function g = paso(x, P0)
    F = curva_pie(x, P0);
    g = [ptp(F(:,2)), ptp(F(:,1))];             % [alto ancho]
end

function d = ptp(v)
    % rango (max - min) sin depender de toolboxes
    d = max(v) - min(v);
end
