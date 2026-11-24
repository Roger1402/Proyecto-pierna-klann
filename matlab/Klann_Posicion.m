function q = Klann_Posicion(theta2, P)
% KLANN_POSICION  Posicion de la pierna Klann para un angulo de manivela.
%   theta2 en grados. Usa dos veces el fourbar geometrico (Constans & Dyer 4.8):
%     Lazo 1 (real)    : manivela O-C, biela C-E, balancin B-E, tierra O-B.
%                        El punto de biela K sale como punto P (p = CK, gamma = gam1).
%     Lazo 2 (virtual) : "manivela" C-K (ya conocida), acoplador K-H (pierna),
%                        balancin A-H, "tierra" C-A (cambia con theta2).
%                        El pie F sale como punto P (p = KF, gamma = gam2).
%   Es el mismo truco del fourbar virtual del hexapodo de Gutarra et al. (2021).

% ----- lazo 1 -----
[th3, th4, xC, xE, xK] = fourbar(theta2, P.r, P.CE, P.BE, P.d1, P.beta1, ...
                                 P.config1, P.CK, P.gam1, P.xO);
% ----- lazo 2 (fourbar virtual con origen en C) -----
thCK  = th3 + P.gam1;                                    % angulo de C->K [deg]
dA    = norm(P.xA - xC);                                 % "tierra" virtual C-A
betaA = atan2(P.xA(2)-xC(2), P.xA(1)-xC(1))*180/pi;
[th5, th6, ~, xH, xF] = fourbar(thCK, P.CK, P.KH, P.AH, dA, betaA, ...
                                P.config2, P.KF, P.gam2, xC);

q.th2 = theta2; q.th3 = th3; q.th4 = th4; q.th5 = th5; q.th6 = th6;   % [deg]
q.xO = P.xO; q.xA = P.xA; q.xB = P.xB;
q.xC = xC; q.xE = xE; q.xK = xK; q.xH = xH; q.xF = xF;                % [mm]
end
