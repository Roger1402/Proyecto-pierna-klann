import cv2
import numpy as np
import pandas as pd

cap = cv2.VideoCapture('video_movimeinto.mp4')
fps = cap.get(cv2.CAP_PROP_FPS)

# ROI donde se mueve el LED rojo sobre el fondo negro (evita el reflejo en la mesa y los cables rojos de la derecha)
# En 832x464: x de 200 a 480, y de 120 a 265
x1, y1, x2, y2 = 200, 120, 480, 265

records = []
frame_idx = 0

while True:
    ret, frame = cap.read()
    if not ret:
        break
    
    t_sec = frame_idx / fps
    roi = frame[y1:y2, x1:x2]
    
    # El núcleo del LED tiene saturación de rojo y brillo muy alto (canal R alto, halo rojo intenso)
    b, g, r = cv2.split(roi)
    hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv)
    
    # Combinación: píxeles brillantes con componente rojo dominante (núcleo blanco-rosado + halo rojo saturado)
    red_score = r.astype(np.float32) - 0.5 * (g.astype(np.float32) + b.astype(np.float32))
    # El núcleo central del LED tiene V > 235 y red_score > 40
    mask = ((v > 220) & (red_score > 35)) | ((red_score > 110) & (v > 150))
    mask_u8 = mask.astype(np.uint8) * 255
    
    # Limpiar ruido pequeño y hallar el componente conectado más grande/brillante
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(mask_u8)
    
    cx, cy, area = np.nan, np.nan, 0
    if num_labels > 1:
        # Ignorar fondo (label 0), elegir el componente con mayor brillo acumulado en canal R
        best_label = -1
        best_weight = -1
        for lbl in range(1, num_labels):
            a = stats[lbl, cv2.CC_STAT_AREA]
            if a >= 4:
                w = np.sum(r[labels == lbl].astype(np.float64))
                if w > best_weight:
                    best_weight = w
                    best_label = lbl
        if best_label != -1:
            comp_mask = (labels == best_label)
            ys, xs = np.where(comp_mask)
            # Centroide ponderado por intensidad en canal R (sub-píxel accuracy!)
            weights = r[ys, xs].astype(np.float64) ** 2
            cx = x1 + np.sum(xs * weights) / np.sum(weights)
            cy = y1 + np.sum(ys * weights) / np.sum(weights)
            area = stats[best_label, cv2.CC_STAT_AREA]
            
    records.append((frame_idx, t_sec, cx, cy, area))
    frame_idx += 1

cap.release()
df_raw = pd.DataFrame(records, columns=['frame', 't_sec', 'px_x', 'px_y', 'area'])
print("Total frames procesados:", len(df_raw))
print("Frames con LED detectado:", df_raw['px_x'].notna().sum())

# Detectar exactamente cuándo empieza a moverse y cuándo se detiene
df_raw['dx'] = df_raw['px_x'].diff().abs()
df_raw['dy'] = df_raw['px_y'].diff().abs()
df_raw['speed_px'] = np.hypot(df_raw['px_x'].diff(), df_raw['px_y'].diff()) * fps

# Buscar intervalos de movimiento real (velocidad sostenida > 5 px/s)
moving = df_raw[df_raw['speed_px'] > 8.0]
print("Primer movimiento detectado en t =", moving['t_sec'].min(), "s, último en t =", moving['t_sec'].max(), "s")

# Inspeccionar actividad por ventanas de 1 segundo para ver exactamente en qué segundos se mueve
df_raw['sec_int'] = df_raw['t_sec'].astype(int)
sec_summary = df_raw.groupby('sec_int').agg(
    x_range=('px_x', lambda s: s.max() - s.min()),
    y_range=('px_y', lambda s: s.max() - s.min()),
    mean_speed=('speed_px', 'mean')
)
print(sec_summary[sec_summary['x_range'] > 1.5].to_string())