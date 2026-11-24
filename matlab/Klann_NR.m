function err = Klann_NR(q, P)
% KLANN_NR  Comprobacion de la posicion con Newton-Raphson (Constans & Dyer 4.15).
%   Resuelve las dos ecuaciones de lazo vectorial para x = [th3 th4 th5 th6]
%   arrancando de una solucion perturbada y devuelve la maxima diferencia [rad]
%   frente al metodo geometrico.
%     Lazo 1: r e2 + CE e3 - (xB - xO) - BE e4 = 0
%     Lazo 2: r e2 + CK eK + KH e5 - (xA - xO) - AH e6 = 0

d2r = pi/180;
th2 = q.th2*d2r;
xg  = [q.th3; q.th4; q.th5; q.th6]*d2r;    % solucion geometrica
x   = xg + 0.05;                           % arranque perturbado
for it = 1:50
    [e2,~]  = UnitVector(th2);
    [e3,n3] = UnitVector(x(1));
    [e4,n4] = UnitVector(x(2));
    [eK,nK] = UnitVector(x(1) + P.gam1*d2r);
    [e5,n5] = UnitVector(x(3));
    [e6,n6] = UnitVector(x(4));
    phi = [P.r*e2 + P.CE*e3 - (P.xB - P.xO) - P.BE*e4;
           P.r*e2 + P.CK*eK + P.KH*e5 - (P.xA - P.xO) - P.AH*e6];
    J = [P.CE*n3, -P.BE*n4, [0;0],     [0;0];
         P.CK*nK,  [0;0],   P.KH*n5,  -P.AH*n6];
    dx = -J\phi;
    x  = x + dx;
    if norm(dx) < 1e-12, break, end
end
err = max(abs(mod(x - xg + pi, 2*pi) - pi));
end
