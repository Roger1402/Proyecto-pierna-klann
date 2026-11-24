function R = Klann_EnsayoGraficas(archivo)
% KLANN_ENSAYOGRAFICAS  Lee un CSV de la interfaz y dibuja el ensayo.
D = readtable(archivo);
t = D.t_s;  th = D.angulo_acum_deg;
[t, iu] = unique(t);  th = th(iu);          % por si se repite una marca de tiempo
if numel(t) < 20, error('El ensayo tiene muy pocas muestras (%d).', numel(t)); end

% ---------- calidad del registro ----------
R.duracion = t(end) - t(1);
R.vueltas  = (th(end) - th(1))/360;
R.errores  = D.err(end) - D.err(1);
R.hueco    = max(diff(t));                  % normal: 0.010 s
fprintf('Ensayo: %s\n', archivo);
fprintf('Duracion %.2f s | %.2f vueltas | errores del encoder %g | hueco maximo %.0f ms\n', ...
        R.duracion, R.vueltas, R.errores, 1e3*R.hueco);
if R.hueco > 0.05, warning('Faltan muestras en el registro (hueco de %.0f ms).', 1e3*R.hueco); end
if R.vueltas < 0, warning('El angulo disminuye: marca "invertir lectura del encoder" si giraba antihorario.'); end

% ---------- velocidad: derivada del angulo suavizado 150 ms ----------
ths = smoothdata(th, 'movmean', 0.15, 'SamplePoints', t);
rpm = gradient(ths, t)/6;                   % deg/s -> rpm
ang = mod(th, 360);
R.t = t; R.angulo = ang; R.rpm = rpm; R.rpm_media = R.vueltas/R.duracion*60;
fprintf('Velocidad media de la manivela = %.1f rpm\n', R.rpm_media);

[~, nombre] = fileparts(archivo);
figure('Color','w','Position',[80 80 1000 650]);
subplot(2,2,1); plot(t, th, 'LineWidth', 1.2); grid on
xlabel('t (s)'); ylabel('\theta_2-\theta_{2,0} (°)'); title('Ángulo medido (encoder)')
subplot(2,2,2); plot(t, rpm, 'LineWidth', 1.2); grid on
xlabel('t (s)'); ylabel('manivela (rpm)'); title('Velocidad medida')

% ---------- velocidad segun el angulo (promedio de las vueltas) ----------
edges = 0:5:360;  c = edges(1:end-1) + 2.5;
k = discretize(ang, edges);
R.angBins = c(:);
R.rpmMedia = accumarray(k, rpm, [numel(c) 1], @mean, NaN);
subplot(2,2,3); plot(ang, rpm, '.', 'Color', [.8 .8 .8]); hold on
plot(c, R.rpmMedia, 'r.-'); grid on; xlim([0 360]); xticks(0:60:360)
xlabel('\theta_2-\theta_{2,0} (°)'); ylabel('manivela (rpm)'); title('Velocidad según el ángulo')
legend('muestras', 'promedio cada 5°', 'Location', 'best')

% ---------- pie calculado con el angulo medido ----------
P = Klann_Datos(D.radio_mm(1));
g = 0:359;  Fg = zeros(2, 360);
for i = 1:360, q = Klann_Posicion(P.th2_0 + g(i), P); Fg(:,i) = q.xF; end
R.pie = interp1([g 360], [Fg Fg(:,1)]', ang);
subplot(2,2,4); plot(Fg(1,[1:end 1]), Fg(2,[1:end 1]), 'k--'); hold on; axis equal; grid on
plot(R.pie(:,1), R.pie(:,2), 'r.', 'MarkerSize', 5)
xlabel('x (mm)'); ylabel('y (mm)'); title('Pie calculado con el ángulo medido')
legend('curva teórica', 'posiciones recorridas', 'Location', 'best')
sgtitle(strrep(nombre, '_', '\_'))
exportgraphics(gcf, fullfile(fileparts(archivo), [nombre '.png']), 'Resolution', 200);
fprintf('Figura guardada junto al CSV.\n');
end
