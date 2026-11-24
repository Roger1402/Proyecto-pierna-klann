"""Diagrama de conexiones de la pierna Klann (Arduino Nano + L298N + INA219 + JGA25-370)."""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

OUT = Path(__file__).resolve().parent
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 8})
fig, ax = plt.subplots(figsize=(12, 8))
ax.set_xlim(0, 120); ax.set_ylim(0, 80); ax.axis("off")
COL = {"12V": "#d62728", "GND": "#222222", "5V": "#ff7f0e", "PWM": "#1f77b4", "DIR": "#17becf",
       "ENC": "#9467bd", "I2C": "#2ca02c", "MOT": "#8c564b", "POT": "#b8a800"}


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
        lx, ly = at
        ax.text(lx, ly, label, color=COL[kind], fontsize=7, fontweight="bold", ha="center", zorder=5,
                bbox=dict(fc="white", ec="none", pad=0.6))


def netlabel(p, text, kind, dx):
    x, y = p
    ax.plot([x, x + dx], [y, y], color=COL[kind], lw=1.9)
    ax.text(x + dx + (0.6 if dx > 0 else -0.6), y, text, color=COL[kind], fontsize=7.5, fontweight="bold",
            ha="left" if dx > 0 else "right", va="center")


# ---------------- bloques y pines ----------------
block(2, 58, 16, 16, "Fuente DC", "12 V, 2 A\n(o 6 V, según el motor)", "#fdecea")
Fp = pin(18, 66, "+V", "R"); Fg = pin(18, 61, "GND", "R")

block(28, 58, 18, 16, "INA219", "sensor de corriente (I2C)", "#e8f6ec")
Iin = pin(28, 66, "VIN+", "L"); Iout = pin(46, 66, "VIN−", "R")
Ivcc = pin(30, 58, "VCC", "B", 90); Ignd = pin(33, 58, "GND", "B", 90); Isda = pin(36, 58, "SDA", "B", 90); Iscl = pin(39.5, 58, "SCL", "B", 90)

block(58, 34, 22, 40, "Driver L298N", "quitar el jumper de ENA\nno usar su salida de 5 V", "#eaf2fb")
L12 = pin(58, 66, "+12V", "L"); Lg = pin(58, 61, "GND", "L")
Len = pin(58, 50, "ENA", "L"); Li1 = pin(58, 45, "IN1", "L"); Li2 = pin(58, 40, "IN2", "L")
Lo1 = pin(80, 64, "OUT1", "R"); Lo2 = pin(80, 58, "OUT2", "R")

block(92, 26, 22, 48, "Motor JGA25-370", "con encoder: usar las\netiquetas impresas en su placa", "#f5efe6")
M1 = pin(92, 64, "M1 (motor +)", "L"); M2 = pin(92, 58, "M2 (motor −)", "L")
Mv = pin(92, 48, "VCC (3.3–5 V)", "L"); Mg = pin(92, 42, "GND", "L")
Ma = pin(92, 36, "C1 / A", "L"); Mb = pin(92, 30, "C2 / B", "L")

block(26, 2, 34, 20, "Arduino Nano", "alimentado por USB (laptop):\nregistra datos por Serial", "#f0f0f8", tdy=6.5)
A5v = pin(29, 22, "5V", "T"); Ag = pin(32.5, 22, "GND", "T"); A4 = pin(36, 22, "A4", "T"); Ascl = pin(39.5, 22, "A5", "T")
A9 = pin(43, 22, "D9", "T"); A7 = pin(46.5, 22, "D7", "T"); A8 = pin(50, 22, "D8", "T")
A2 = pin(60, 17, "D2", "R"); A3 = pin(60, 12, "D3", "R"); A0 = pin(26, 11, "A0", "L")
block(2, 4, 14, 16, "Potenciómetro", "10 kΩ (velocidad)", "#fbfbe8")
P1 = pin(16, 14, "ext. 1", "R"); Pc = pin(16, 11, "cursor", "R"); P2 = pin(16, 8, "ext. 2", "R")

# ---------------- cables ----------------
wire([Fp, Iin], "12V", "+12 V", (23, 67.2))
wire([Iout, (52, 66), L12], "12V", "+12 V (medido)", (52, 68.4))
# bus de tierra (y = 27) y bus de 5 V (y = 25)
wire([(20, 27), (88, 27)], "GND")
wire([Fg, (20, 61), (20, 27)], "GND")
wire([Ignd, (33, 27)], "GND")
wire([Lg, (56.8, 61), (56.8, 27)], "GND")
wire([Mg, (88, 42), (88, 27)], "GND")
wire([Ag, (32.5, 27)], "GND", "GND común (obligatorio)", (74, 28.0))
for x in (20, 32.5, 33, 56.8, 88):
    ax.plot(x, 27, "o", ms=3.5, color=COL["GND"], zorder=3)
wire([(29, 25), (86, 25)], "5V")
wire([A5v, (29, 25)], "5V")
wire([Ivcc, (30, 25)], "5V", "5 V", (24.8, 40))
wire([Mv, (86, 48), (86, 25)], "5V", "5 V encoder", (74, 23.2))
for x in (29, 30, 86):
    ax.plot(x, 25, "o", ms=3.5, color=COL["5V"], zorder=3)
# I2C
wire([Isda, A4], "I2C", "SDA", (36, 44))
wire([Iscl, Ascl], "I2C", "SCL", (39.5, 50))
# control del driver
wire([A9, (43, 30), (55.6, 30), (55.6, 50), Len], "PWM", "PWM", (49, 30.9))
wire([A7, (46.5, 31.5), (54.4, 31.5), (54.4, 45), Li1], "DIR")
wire([A8, (50, 33), (53.2, 33), (53.2, 40), Li2], "DIR", "dirección", (50.5, 36.5))
# motor
wire([Lo1, M1], "MOT", "motor +", (86, 65.2))
wire([Lo2, M2], "MOT", "motor −", (86, 59.2))
# encoder
wire([A2, (89.2, 17), (89.2, 36), Ma], "ENC", "encoder A → D2 (INT0)", (74, 18.2))
wire([A3, (90.6, 12), (90.6, 30), Mb], "ENC", "encoder B → D3 (INT1)", (74, 13.2))
# potenciometro (etiquetas de red)
wire([Pc, A0], "POT", "A0", (21, 12.2))
netlabel(P1, "GND", "GND", 3.0)
netlabel(P2, "5V", "5V", 3.0)

# LED del pie
ax.add_patch(FancyBboxPatch((93, 3), 26, 11, boxstyle="round,pad=0.3", fc="#fffde7", ec="#333", lw=1.0, ls="--"))
ax.text(106, 12.6, "LED del pie (circuito aparte)", ha="center", va="top", fontsize=8.5, fontweight="bold")
ax.text(106, 7.6, "LED 5 mm + pila CR2032,\nsin resistencia, pegados al pie.\nNo se conecta al Arduino.", ha="center", va="center", fontsize=7)

# leyenda
items = [("12V", "potencia +12 V"), ("GND", "tierra"), ("5V", "5 V lógica"), ("PWM", "PWM (velocidad)"),
         ("DIR", "dirección"), ("ENC", "encoder"), ("I2C", "I2C"), ("MOT", "bobina del motor")]
ax.text(93, 24.2, "Colores", fontsize=8, fontweight="bold")
for k, (c, t) in enumerate(items):
    col, row = k % 2, k // 2
    xx, yy = 93 + col * 13.5, 22 - row * 1.9
    ax.plot([xx, xx + 2.2], [yy, yy], color=COL[c], lw=2.6)
    ax.text(xx + 2.8, yy, t, va="center", fontsize=6.8)
ax.text(2, 78.5, "Pierna Klann: diagrama de conexiones", fontsize=13, fontweight="bold", va="top")
ax.text(2, 75.6, "El INA219 va en serie en el +12 V del motor: mide la corriente para estimar el torque.",
        fontsize=8, color="#444", va="top")
fig.savefig(OUT / "diagrama_circuito.png", dpi=170, bbox_inches="tight")
fig.savefig(OUT / "diagrama_circuito.pdf", bbox_inches="tight")
print("ok")
