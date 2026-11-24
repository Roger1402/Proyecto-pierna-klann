function [T2, pin, Pcin, Pext] = Klann_Fuerzas(q, va, P, FW)
% KLANN_FUERZAS  Analisis de fuerzas S*f = t (Constans & Dyer 7.8 y 7.13).
%   Cuerpos: 2 engranaje-manivela (O,C), 3 biela (C,E,K), 4 balancin inf. (B,E),
%            5 pierna (K,H,F), 6 balancin sup. (A,H).
%   Incognitas f = [FO FC FE FB FK FH FA T2]  (14 componentes + torque = 15)
%     FO: tierra sobre 2   FC: 2 sobre 3   FE: 3 sobre 4   FB: tierra sobre 4
%     FK: 3 sobre 5        FH: 5 sobre 6   FA: tierra sobre 6
%   FW: fuerza externa en el pie [N] (reaccion del suelo), 2x1.
%   Incluye gravedad: m*(aG - g). Devuelve tambien el balance de potencias
%   (Pcin debe ser igual a Pext, como en el ejemplo 7.7 del libro).

if nargin < 4, FW = [0;0]; end
d2r = pi/180; mm = 1e-3;
X = @(v) v*mm;                                % mm -> m
xO = X(q.xO); xA = X(q.xA); xB = X(q.xB); xC = X(q.xC);
xE = X(q.xE); xK = X(q.xK); xH = X(q.xH); xF = X(q.xF);
w  = [va.w2 va.w3 va.w4 va.w5 va.w6];         % indices 1..5 -> cuerpos 2..6
al = [va.a2 va.a3 va.a4 va.a5 va.a6];
th = [q.th2, q.th3, q.th4, q.th5, q.th6]*d2r; % angulo del eje local de cada cuerpo
ref = {xO, xC, xB, xK, xA};                   % pin de referencia de cada cuerpo
vref = {[0;0], X(va.vC), [0;0], X(va.vK), [0;0]};
aref = {[0;0], X(va.aC), [0;0], X(va.aK), [0;0]};

% centros de masa, velocidad y aceleracion del CG
[G, vG, aG] = deal(cell(1,5));
for j = 1:5
    c = P.cg{j}; t = th(j);
    rg = [c(1)*cos(t) - c(2)*sin(t); c(1)*sin(t) + c(2)*cos(t)];
    k  = [-rg(2); rg(1)];                     % k x rg
    G{j}  = ref{j} + rg;
    vG{j} = vref{j} + w(j)*k;
    aG{j} = aref{j} + al(j)*k - w(j)^2*rg;
end
s = @(j, x) [-(x(2)-G{j}(2)), (x(1)-G{j}(1))];   % fila s^T: momento = s^T F

U = eye(2); Z = zeros(2); z = zeros(1,2);
%      FO   FC   FE   FB   FK   FH   FA   T2
S = [  U   -U    Z    Z    Z    Z    Z   [0;0];     % cuerpo 2 (fuerzas)
       Z    U   -U    Z   -U    Z    Z   [0;0];     % cuerpo 3
       Z    Z    U    U    Z    Z    Z   [0;0];     % cuerpo 4
       Z    Z    Z    Z    U   -U    Z   [0;0];     % cuerpo 5
       Z    Z    Z    Z    Z    U    U   [0;0];     % cuerpo 6
     s(1,xO) -s(1,xC)  z  z  z  z  z    1;           % cuerpo 2 (momento)
       z  s(2,xC) -s(2,xE) z -s(2,xK) z z  0;        % cuerpo 3
       z  z  s(3,xE) s(3,xB)  z  z  z    0;          % cuerpo 4
       z  z  z  z  s(4,xK) -s(4,xH)  z   0;          % cuerpo 5
       z  z  z  z  z  s(5,xH) s(5,xA)    0];         % cuerpo 6
t = zeros(15,1);
for j = 1:5
    t(2*j-1:2*j) = P.m(j)*(aG{j} - P.g);
    t(10+j)      = P.I(j)*al(j);
end
t(7:8) = t(7:8) - FW;                         % fuerza del suelo en el pie (cuerpo 5)
t(14)  = t(14) - s(4, xF)*FW;                 % su momento

f  = S \ t;
T2 = f(15);
pin = struct('O',f(1:2),'C',f(3:4),'E',f(5:6),'B',f(7:8), ...
             'K',f(9:10),'H',f(11:12),'A',f(13:14));

% balance de potencias
Pcin = 0; Pg = 0;
for j = 1:5
    Pcin = Pcin + P.m(j)*aG{j}.'*vG{j} + P.I(j)*al(j)*w(j);
    Pg   = Pg   + P.m(j)*P.g.'*vG{j};
end
Pext = T2*w(1) + Pg + FW.'*X(va.vF);
end
