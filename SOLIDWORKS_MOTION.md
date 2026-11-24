# Simular la pierna en SolidWorks 2021 (Motion)

1. Abrir `cad/ensamble/ensamble.step` (tipo STEP). Guardar como ensamble.
2. Fijar solo la placa/base. En las demás piezas: clic derecho > Flotar.
3. Relaciones de posición (concéntrica + coincidente de caras) en estas 7 juntas:
   O engranaje-placa, C engranaje-biela, E biela-balancín inferior, B balancín inferior-placa,
   K biela-pierna, H pierna-balancín superior, A balancín superior-placa.
   Piñón: concéntrico con el eje del motor; relación mecánica **Engranaje** 18:36.
   Comprobar arrastrando el engranaje: debe moverse toda la pierna (1 GDL).
4. Complementos > SOLIDWORKS Motion. Pestaña "Estudio de movimiento 1" > tipo **Análisis de movimiento**.
5. Motor > Giratorio sobre el engranaje grande, velocidad constante **37.3 rpm** (antihorario). Gravedad −Y.
6. Propiedades: 60 cuadros por segundo, duración 1.61 s (una vuelta). Calcular.
7. Resultados y trazados:
   - Desplazamiento/Velocidad/Aceleración > **Trazar trayectoria** > vértice o agujero del pie F.
   - Desplazamiento lineal X e Y del pie. Fuerzas > Par motor > magnitud.
   - Clic derecho en el trazado > Exportar CSV.
8. Video: botón "Guardar animación" (.avi/.mp4).

Deben salir unos 75.3 x 39.4 mm, igual que MATLAB.
