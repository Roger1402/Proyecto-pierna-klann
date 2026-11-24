# Pierna Klann reconfigurable impresa en 3D
Proyecto final MT4003 Mecanismos y Transmisión de Movimiento - UTEC 2026-2.

| Carpeta | Contenido |
|---|---|
| `matlab/` | Posición, velocidad, aceleración, fuerzas, síntesis (`Klann_Main.m`) y ensayo (`Klann_Experimental.m`) |
| `datos/` | CSV del ensayo: encoder, LED (OpenCV) y corriente leída de la fuente |
| `vision/` | Scripts OpenCV (LED y lectura de la pantalla de la fuente) |
| `interfaz/` | Interfaz web de control y medición con el ESP32 |
| `circuito/` | Firmware del ESP32-S3 y diagramas |
| `cad/`, `imprimir/` | Modelos STEP y STL |
| `figuras/` | Figuras del informe |

Uso: abrir MATLAB en `matlab/` y ejecutar `Klann_Main` y `Klann_Experimental`.
Videos: https://drive.google.com/drive/folders/179O787bA_j6KteLaKAYCUK6fODSDy65T
