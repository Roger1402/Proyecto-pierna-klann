"""Diagrama de conexiones: ESP32-S3 + L298N + JGA25-370 (con encoder) + fuente."""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

OUT = Path(__file__).resolve().parent
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 8})
fig, ax = plt.subplots(figsize=(12, 8))
ax.set_xlim(0, 120); ax.set_ylim(0, 80); ax.axis("off")
COL = {"12V": "#d62728", "GND": "#222222", "3V3": "#ff7f0e", "PWM": "#1f77b4", "DIR": "#17becf",
       "ENC": "#9467bd", "MOT": "#8c564b"}


def block(x, y, w, h, title, sub, fc, tdy=1.2):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.3", fc=fc, ec="#333", lw=1.2, zorder=2))
    ax.text(x + w / 2, y + h - tdy, title, ha="center", va="top", fontsize=10, fontweight="bold", zorder=3)
    if sub:
        ax.text(x + w / 2, y + h - tdy - 2.8, sub, ha="center", va="top", fontsize=7, color="#555", zorder=3)


def pin(x, y, name, side, rot=0):
    ax.plot(x, y, "o", ms=4.5, color="#333", zorder=4)
    off = {"L": (1.0, 0, "left", "center"), "R": (-1.0, 0, "right", "center"),
           "T": (0, -1.2, "center", "top"), "B": (0, 1.2, "center", "bottom")}[side]
    ax.text(x + off[0], y + off[1], name, ha=off[2], va=off[3], fontsize=7.5, zorder=4, rotation=rot)
    return (x, y)


def wire(pts, kind, label=None, at=None):
    xs, ys = zip(*pts)
    ax.plot(xs, ys, color=COL[kind], lw=1.9, solid_capstyle="round", zorder=1)
    if label:
        ax.text(at[0], at[1], label, color=COL[kind], fontsize=7, fontweight="bold", ha="center", zorder=5,
                bbox=dict(fc="white", ec="none", pad=0.6))


# ---------------- bloques ----------------
block(2, 58, 17, 16, "Fuente DC", "12 V o 6 V (según\nel motor), 2 A", "#fdecea")
Fp = pin(19, 66, "+V", "R"); Fg = pin(19, 61, "GND", "R")

block(48, 34, 22, 40, "Driver L298N", "quitar el jumper de ENA\nNO usar su salida de 5 V", "#eaf2fb")
L12 = pin(48, 66, "+12V", "L"); Lg = pin(48, 61, "GND", "L")
Len = pin(48, 50, "ENA", "L"); Li1 = pin(48, 45, "IN1", "L"); Li2 = pin(48, 40, "IN2", "L")
Lo1 = pin(70, 64, "OUT1", "R"); Lo2 = pin(70, 58, "OUT2", "R")

block(90, 26, 24, 48, "Motor JGA25-370", "encoder: usar las etiquetas\nimpresas en su placa", "#f5efe6")
M1 = pin(90, 64, "M1 (motor +)", "L"); M2 = pin(90, 58, "M2 (motor −)", "L")
Mv = pin(90, 48, "VCC  → 3.3 V", "L"); Mg = pin(90, 42, "GND", "L")
Ma = pin(90, 36, "C1 / A", "L"); Mb = pin(90, 30, "C2 / B", "L")

block(24, 2, 40, 18, "ESP32-S3 DevKit", "alimentado por USB (laptop):\nvelocidad y datos por el Monitor Serie", "#f0f0f8", tdy=7.0)
Eg = pin(27, 20, "GND", "T", 90); E33 = pin(31, 20, "3V3", "T", 90)
E4 = pin(37.5, 20, "GPIO4", "T", 90); E5 = pin(40.5, 20, "GPIO5", "T", 90); E6 = pin(43.5, 20, "GPIO6", "T", 90)
E15 = pin(64, 14, "GPIO15", "R"); E16 = pin(64, 9, "GPIO16", "R")

# ---------------- cables ----------------
wire([Fp, (30, 66), L12], "12V", "+12 V (o 6 V)", (30, 67.2))
# bus de tierra y = 27
wire([(21, 27), (86, 27)], "GND")
wire([Fg, (21, 61), (21, 27)], "GND")
wire([Lg, (35, 61), (35, 27)], "GND")
wire([Mg, (86, 42), (86, 27)], "GND")
wire([Eg, (27, 27)], "GND", "GND común (obligatorio)", (60, 28.0))
for x in (21, 27, 35, 86):
    ax.plot(x, 27, "o", ms=3.5, color=COL["GND"], zorder=3)
# 3.3 V al encoder (y = 24)
wire([E33, (31, 24), (83, 24), (83, 48), Mv], "3V3", "3.3 V al encoder (NO 5 V)", (60, 22.6))
# control del driver
wire([E4, (37.5, 50), Len], "PWM", "PWM", (37.5, 52))
wire([E5, (40.5, 45), Li1], "DIR")
wire([E6, (43.5, 40), Li2], "DIR", "dirección", (44.5, 35.5))
# motor
wire([Lo1, M1], "MOT", "motor +", (80, 65.2))
wire([Lo2, M2], "MOT", "motor −", (80, 59.2))
# encoder
wire([E15, (87.2, 14), (87.2, 36), Ma], "ENC", "encoder A → GPIO15", (75, 15.2))
wire([E16, (88.6, 9), (88.6, 30), Mb], "ENC", "encoder B → GPIO16", (75, 10.2))

# notas
ax.add_patch(FancyBboxPatch((1, 29), 18, 25, boxstyle="round,pad=0.3", fc="#fffde7", ec="#999", lw=0.9, ls="--"))
ax.text(10, 52.8, "Por qué así", ha="center", va="top", fontsize=8.5, fontweight="bold")
ax.text(1.8, 50.0,
        "• El ESP32-S3 es de 3.3 V\n  y no tolera 5 V: el\n  encoder va a 3V3.\n"
        "• El L298N entiende\n  3.3 V como \"alto\".\n"
        "• Todas las tierras\n  unidas; si no, el motor\n  no responde.\n"
        "• GPIO 4/5/6/15/16 no son\n  de arranque, USB ni\n  memoria.",
        va="top", fontsize=6.6, linespacing=1.3)
ax.add_patch(FancyBboxPatch((93, 3), 26, 11, boxstyle="round,pad=0.3", fc="#fffde7", ec="#333", lw=1.0, ls="--"))
ax.text(106, 12.6, "LED del pie (circuito aparte)", ha="center", va="top", fontsize=8.5, fontweight="bold")
ax.text(106, 7.6, "LED 5 mm + pila CR2032,\nsin resistencia, pegados al pie.\nNo se conecta al ESP32.", ha="center", va="center", fontsize=7)

items = [("12V", "potencia"), ("GND", "tierra"), ("3V3", "3.3 V lógica"), ("PWM", "PWM (velocidad)"),
         ("DIR", "dirección"), ("ENC", "encoder"), ("MOT", "bobina del motor")]
ax.text(93, 24.2, "Colores", fontsize=8, fontweight="bold")
for k, (c, t) in enumerate(items):
    col, row = k % 2, k // 2
    xx, yy = 93 + col * 13.5, 22 - row * 1.9
    ax.plot([xx, xx + 2.2], [yy, yy], color=COL[c], lw=2.6)
    ax.text(xx + 2.8, yy, t, va="center", fontsize=6.8)
ax.text(2, 78.5, "Pierna Klann: diagrama de conexiones (ESP32-S3)", fontsize=13, fontweight="bold", va="top")
ax.text(2, 75.6, "Componentes: fuente DC, driver L298N, motor JGA25-370 con encoder y ESP32-S3.", fontsize=8, color="#444", va="top")
fig.savefig(OUT / "diagrama_circuito_esp32.png", dpi=170, bbox_inches="tight")
fig.savefig(OUT / "diagrama_circuito_esp32.pdf", bbox_inches="tight")
print("ok")
