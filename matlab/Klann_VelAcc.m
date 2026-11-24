function va = Klann_VelAcc(q, P)
% KLANN_VELACC  Velocidad (cap. 5) y aceleracion (cap. 6) de Constans & Dyer.
%   Lazo 1:  [CE*n3  -BE*n4] [w3; w4] = -r*w2*n2
%   Lazo 2:  [KH*n5  -AH*n6] [w5; w6] = -vK          (vK = vC + CK*w3*nK)
%   Aceleraciones con la misma matriz y los terminos centripetos.
%   Unidades: mm/s, mm/s^2, rad/s, rad/s^2.

d2r = pi/180;
w2 = P.omega2; a2 = P.alpha2;
[e2,n2] = UnitVector(q.th2*d2r);
[e3,n3] = UnitVector(q.th3*d2r);
[e4,n4] = UnitVector(q.th4*d2r);
[eK,nK] = UnitVector((q.th3 + P.gam1)*d2r);
[e5,n5] = UnitVector(q.th5*d2r);
[e6,n6] = UnitVector(q.th6*d2r);

% ----- velocidades -----
A1 = [P.CE*n3, -P.BE*n4];
w  = A1 \ (-P.r*w2*n2);           w3 = w(1); w4 = w(2);
vC = FindVel([0;0], P.r, w2, n2);
vK = FindVel(vC, P.CK, w3, nK);
A2 = [P.KH*n5, -P.AH*n6];
w  = A2 \ (-vK);                  w5 = w(1); w6 = w(2);
vH = FindVel(vK, P.KH, w5, n5);
[eF,nF] = UnitVector((q.th5 + P.gam2)*d2r);
vF = FindVel(vK, P.KF, w5, nF);

% ----- aceleraciones -----
b1 = -P.r*a2*n2 + P.r*w2^2*e2 + P.CE*w3^2*e3 - P.BE*w4^2*e4;
al = A1 \ b1;                     a3 = al(1); a4 = al(2);
aC = FindAcc([0;0], P.r, w2, a2, e2, n2);
aK = FindAcc(aC, P.CK, w3, a3, eK, nK);
b2 = -aK + P.KH*w5^2*e5 - P.AH*w6^2*e6;
al = A2 \ b2;                     a5 = al(1); a6 = al(2);
aF = FindAcc(aK, P.KF, w5, a5, eF, nF);

va = struct('w2',w2,'w3',w3,'w4',w4,'w5',w5,'w6',w6, ...
            'a2',a2,'a3',a3,'a4',a4,'a5',a5,'a6',a6, ...
            'vC',vC,'vK',vK,'vH',vH,'vF',vF,'aC',aC,'aK',aK,'aF',aF);
end
