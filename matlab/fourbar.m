function [theta3, theta4, xB, xC, xP, delta] = fourbar(theta2, a, b, c, d, beta, config, p, gamma, x0)

% ---------- argumentos opcionales ----------
if nargin < 6  || isempty(beta),   beta   = 0;      end
if nargin < 7  || isempty(config), config = 'open'; end
if nargin < 8  || isempty(p),      p      = 0;      end
if nargin < 9  || isempty(gamma),  gamma  = 0;      end
if nargin < 10 || isempty(x0),     x0     = [0;0];  end

% ---------- signo de delta: abierto o cruzado (Ec. 4.121) ----------
if ischar(config) || isstring(config)
    switch lower(char(config))
        case {'open','abierto','abierta','o'},            signo = +1;
        case {'crossed','cruzado','cruzada','cross','x'}, signo = -1;
        otherwise, error('fourbar: config debe ser ''open'' o ''crossed''.')
    end
else
    signo = sign(config);
    if signo == 0, signo = +1; end
end

% ---------- conversion a radianes ----------
theta2 = theta2(:).';            % forzar vector fila
th2    = theta2 * pi/180;
bet    = beta   * pi/180;
gam    = gamma  * pi/180;
x0     = x0(:);                  % forzar vector columna

N = numel(th2);
[xB,xC,xP]            = deal(zeros(2,N));   % allocate space for positions
[theta3,theta4,delta] = deal(zeros(1,N));   % allocate space for angles

% pivotes fijos (el ground esta girado un angulo beta)
[e1,n1] = UnitVector(bet);
xD = FindPos(x0, d, e1);         % ground pin at D

% ---------- lazo principal (secciones 4.8.2 y 4.8.3 del libro) ----------
for i = 1:N

    th2loc = th2(i) - bet;

    r  = d - a*cos(th2loc);                  % Ec. (4.100)
    s  = a*sin(th2loc);
    f2 = r^2 + s^2;                          % f squared, Ecs. (4.99)/(4.101)

    arg = (b^2 + c^2 - f2)/(2*b*c);          % Ec. (4.103)

    if abs(arg) > 1                          % fuera del rango de movimiento
        warning('fourbar:noEnsamblable', ...
            'theta2 = %.3f deg queda fuera del rango de movimiento (no ensamblable).', theta2(i));
        [theta3(i), theta4(i), delta(i)] = deal(NaN);
        xB(:,i) = [NaN;NaN];  xC(:,i) = [NaN;NaN];  xP(:,i) = [NaN;NaN];
        continue
    end

    del = signo * acos(arg);                 % Ec. (4.121): + abierto, - cruzado

    g = b - c*cos(del);                      % Ec. (4.105)
    h = c*sin(del);

    th3loc = atan2((h*r - g*s),(g*r + h*s)); % Ec. (4.112)
    th4loc = th3loc + del;                   % Ec. (4.104)

    % de vuelta al marco global (deshacemos la rotacion beta)
    th3 = th3loc + bet;
    th4 = th4loc + bet;
    
    

    % calculate unit vectors
    [e2,n2]   = UnitVector(th2(i));
    [e3,n3]   = UnitVector(th3);
    [e4,n4]   = UnitVector(th4);
    [eBP,nBP] = UnitVector(th3 + gam);

    % solve for positions of points B, C and P on the linkage
    xB(:,i) = FindPos(      x0, a, e2);
    xC(:,i) = FindPos(      xD, c, e4);      % Ec. (4.128): xC = d*e1 + c*e4
    xP(:,i) = FindPos(xB(:,i), p, eBP);      % Ec. (4.126): xP = a*e2 + p*eBP

    theta3(i) = th3 * 180/pi;
    theta4(i) = th4 * 180/pi;
    delta(i)  = del * 180/pi;
end
