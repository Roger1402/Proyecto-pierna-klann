% FindAcc.m  (Constans & Dyer, cap. 6)
% aceleracion de un punto de un eslabon: a = a0 + L*alpha*n - L*omega^2*e
function a = FindAcc(a0, L, omega, alpha, e, n)
a = a0 + L*alpha*n - L*omega^2*e;
