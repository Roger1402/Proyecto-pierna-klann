% FindVel.m  (Constans & Dyer, cap. 5)
% velocidad de un punto de un eslabon: v = v0 + omega*L*n
function v = FindVel(v0, L, omega, n)
v = v0 + omega * L * n;
