"""Ensamble de la pierna Klann reconfigurable en la pose de la patente
(manivela a 180 deg, pasador en el agujero de r = 20 mm).

Origen: eje de la manivela O. Plano del mecanismo: XY. +z hacia el frente.
"""
import math
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import klann_geom as kg  # noqa: E402
import klann_parts as kp  # noqa: E402
from build123d import Compound, Cylinder, Pos, Rot  # noqa: E402


def _place(shape, loc, label):
    s = loc * shape
    s.label = label
    return s


def gen_step():
    parts = [
        _place(kp.placa(), kp.placement("placa"), "placa"),
        _place(kp.base(), kp.placement("base"), "base"),
        _place(kp.engranaje_manivela(), kp.placement("engranaje"), "engranaje-manivela 36T"),
        _place(kp.pinon(), kp.placement("pinon"), "pinon 18T"),
        _place(kp.biela(), kp.placement("biela"), "biela C-E-K (capa 1)"),
        _place(kp.balancin_superior(), kp.placement("balancin_superior"), "balancin superior A-H (capa 1)"),
        _place(kp.balancin_inferior(), kp.placement("balancin_inferior"), "balancin inferior B-E (capa 2)"),
        _place(kp.pierna(), kp.placement("pierna"), "pierna H-K-F (capa 2)"),
    ]
    A, B = kg.GROUND["A"], kg.GROUND["B"]
    parts.append(_place(kp.separador(13.0, "sepA"), Pos(A[0], A[1], 0), "separador A 13 mm"))
    parts.append(_place(kp.separador(18.5, "sepB"), Pos(B[0], B[1], 0), "separador B 18.5 mm"))
    C = kg.P0["C"]
    parts.append(_place(kp.separador(1.6, "sepC"), Pos(C[0], C[1], 9.0 + 2.4), "separador pasador C 1.6 mm"))
    # envolventes de componentes comprados (no se imprimen)
    mx, my = kp.MOTOR_XY
    motor = Pos(mx, my, -69) * Cylinder(12.5, 67, align=None)
    parts.append(_place(motor, Pos(0, 0, 0), "motor JGA25-370 con encoder (envolvente d25 x 67)"))
    rod = Pos(0, 0, -9) * (Cylinder(11, 7, align=None) - Cylinder(4, 20))
    parts.append(_place(rod, Pos(0, 0, 0), "rodamiento 608ZZ (envolvente)"))
    # Vista "de pie": la y del mecanismo pasa a ser +Z del mundo (gravedad),
    # el frente de la placa mira hacia -Y del mundo.
    upright = Rot(90, 0, 0)
    parts = [_place(p, upright, p.label) for p in parts]
    return Compound(children=parts, label="pierna Klann reconfigurable")
