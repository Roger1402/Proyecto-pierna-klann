function P = Klann_Datos(r)
% KLANN_DATOS  Geometria y propiedades de masa de la pierna Klann.
%   P = Klann_Datos()      -> manivela de 20 mm (geometria de la patente)
%   P = Klann_Datos(r)     -> mismo mecanismo con radio de manivela r [mm]
%
% Geometria: patente US 6,260,862 (J. Klann), Tabla 1, escalada para que
% la manivela O-C mida 20 mm. Origen en el eje de la manivela O.
% Propiedades de masa: CAD (build123d) con PLA, densidad 1.24 g/cm^3.

if nargin < 1, r = []; end

% ---------- coordenadas de la Tabla 1 (unidades de la patente) ----------
pat.A = [1.366; 1.366];   % pivote fijo del balancin superior
pat.B = [1.009; 0.574];   % pivote fijo del balancin inferior
pat.O = [1.599; 0.750];   % eje de la manivela
pat.C = [1.331; 0.750];   % pasador de la manivela
pat.E = [0.741; 0.750];   % biela - balancin inferior
pat.K = [0.232; 0.866];   % rodilla: biela - pierna
pat.H = [0.866; 1.500];   % cadera: pierna - balancin superior
pat.F = [0.000; 0.000];   % pie

s = 20 / norm(pat.C - pat.O);                 % escala -> manivela de 20 mm
f = fieldnames(pat);
for i = 1:numel(f)
    X.(f{i}) = (pat.(f{i}) - pat.O) * s;      % [mm], origen en O
end
P.X0 = X;                                     % pose de referencia (theta2 = 180 deg)

ang = @(p,q) atan2(q(2)-p(2), q(1)-p(1));

% ---------- longitudes [mm] ----------
P.r   = norm(X.C - X.O);      % manivela (eslabon 2)
P.CE  = norm(X.E - X.C);      % biela, lado C-E (eslabon 3)
P.CK  = norm(X.K - X.C);      % biela, lado C-K
P.BE  = norm(X.E - X.B);      % balancin inferior (eslabon 4)
P.KH  = norm(X.H - X.K);      % pierna, lado K-H (eslabon 5)
P.KF  = norm(X.F - X.K);      % pierna, lado K-F
P.AH  = norm(X.H - X.A);      % balancin superior (eslabon 6)
P.d1  = norm(X.B - X.O);      % tierra del lazo 1 (O-B)
P.beta1 = ang(X.O, X.B)*180/pi;                          % inclinacion O->B [deg]
P.gam1  = (ang(X.C, X.K) - ang(X.C, X.E))*180/pi;        % K respecto de C->E [deg]
P.gam2  = (ang(X.K, X.F) - ang(X.K, X.H))*180/pi;        % F respecto de K->H [deg]
P.xO = X.O; P.xA = X.A; P.xB = X.B;
P.th2_0 = ang(X.O, X.C)*180/pi;                          % angulo inicial (180 deg)

% ramas del fourbar que reproducen la pose de la patente
P.config1 = 'crossed';    % lazo 1: O-C-E-B
P.config2 = 'open';       % lazo 2: C-K-H-A (fourbar virtual)

if ~isempty(r), P.r = r; end

% ---------- propiedades de masa (CAD, PLA 1.24 g/cm^3) ----------
% CG local: coordenadas [x;y] en metros medidas desde el pin de referencia,
% con el eje x local apuntando al segundo pin indicado.
P.m  = [0.019241, 0.004876, 0.001630, 0.007924, 0.002450];   % kg  (eslabones 2..6)
P.I  = [7570.7, 3232.5, 136.8, 12950.8, 425.5]*1e-9;         % kg m^2 respecto del CG
P.cg = {[0;0], ...                    % 2 engranaje-manivela: CG en O
        [41.222; -2.191]*1e-3, ...    % 3 biela (desde C, eje C->E)
        [11.964;  0.000]*1e-3, ...    % 4 balancin inferior (desde B, eje B->E)
        [ 0.659; -9.440]*1e-3, ...    % 5 pierna (desde K, eje K->H)
        [19.315;  0.000]*1e-3};       % 6 balancin superior (desde A, eje A->H)
P.g = [0; -9.81];

% ---------- operacion ----------
P.omega2 = 2*pi;       % rad/s (60 rpm en la manivela, antihorario)
P.alpha2 = 0;
P.W      = 5;          % N, reaccion vertical del suelo en el pie durante el apoyo
end
