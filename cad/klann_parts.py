"""Piezas imprimibles de la pierna Klann reconfigurable (build123d).

Cada funcion devuelve la pieza en su MARCO LOCAL = orientacion de impresion
(cara de apoyo en z=0, crece hacia +z). La funcion `placement(name)` da la
ubicacion de esa pieza en el ensamble.

Marco del ensamble: plano del mecanismo XY, origen en el eje de la manivela O,
+z sale de la placa hacia el frente. Cara frontal de la placa en z=0.

Pila en z (frente de la placa = 0):
    placa            z -6 .. 0   (bosses traseros hasta -24)
    engranaje        z  1 .. 9   (rodamiento 608ZZ en la placa)
    hueco cabezas    z  9 .. 13
    capa 1           z 13 .. 18  biela + balancin superior
    capa 2           z 18.5..23.5 balancin inferior + pierna
"""
import math
from build123d import (Box, Circle, Compound, Cylinder, Face, Location, Plane, Solid,
                       Pos, RegularPolygon, Rot, SlotCenterToCenter, Vector,
                       Wire, extrude)

import klann_geom as kg

# ---------------- parametros ----------------
T_LINK = 5.0          # espesor de eslabones
W_LINK = 9.0          # ancho de eslabones (la verificacion de choques uso 9)
HOLE_M3 = 3.2         # agujero de articulacion (pasar broca de 3.2 mm)
GAP_WASHER = 0.5      # arandela M3 entre capas
Z_GEAR = 1.0
GEAR_T = 8.0
Z_L1 = 13.0
Z_L2 = Z_L1 + T_LINK + GAP_WASHER

MODULE = 1.5
Z_GEAR_TEETH = 36
Z_PINION_TEETH = 18
# Tolerancias para FDM (los dientes impresos salen ~0.1-0.2 mm mas gruesos y la punta
# se redondea): juego en la linea de paso + mayor holgura de raiz que la norma (0.25 m).
BACKLASH = 0.15       # mm que se adelgaza CADA diente en la linea de paso (x2 engranajes)
# Juego total = 2*0.15 + 2*0.2*tan(20 deg) (por CENTER_DIST +0.2) = 0.45 mm  (~1 deg de manivela)
ADDENDUM = 1.00       # x modulo
DEDENDUM = 1.35       # x modulo  -> holgura de raiz 0.35 m = 0.53 mm
CENTER_DIST = MODULE * (Z_GEAR_TEETH + Z_PINION_TEETH) / 2 + 0.2  # +0.2 por impresion
# Engranajes helicoidales: MODULE es el modulo TRANSVERSAL (mismos diametros primitivos
# que los rectos -> la placa no cambia). Modulo normal = MODULE*cos(HELIX).
HELIX_DEG = 20.0
GEAR_HAND = +1      # signo del giro de la helice en el marco LOCAL del engranaje
PINION_HAND = -1    # (el engranaje se voltea en el ensamble -> en el ensamble quedan opuestos)
MOTOR_ANGLE = math.radians(-45)
MOTOR_XY = (CENTER_DIST * math.cos(MOTOR_ANGLE), CENTER_DIST * math.sin(MOTOR_ANGLE))
CRANK_HOLES = [(20.0, 0.0), (18.0, 120.0), (16.0, 240.0)]  # (radio mm, angulo deg)

PLATE_T = 6.0
PLATE_X = (-70.0, 58.0)
PLATE_Y = (-85.0, 62.0)
BASE_Y0 = PLATE_Y[0] - 5.0          # cara inferior de la base (mesa)
BASE_HOLE_Y = PLATE_Y[0] + 8.0      # altura de los pernos placa-base
BASE_HOLES_X = (-50.0, 40.0)

BEARING_OD, BEARING_W = 22.1, 7.0   # 608ZZ (22x8x7) con 0.1 de ajuste
GEARBOX_D = 25.4                    # JGA25: caja reductora de 25 mm
MOTOR_TUBE_L = 18.0

P = kg.P0  # juntas en la pose de referencia (manivela a 180 deg, r=20)


# ---------------- utilidades 2D ----------------
def _capsule(p, q, r):
    L = math.dist(p, q)
    ang = math.degrees(math.atan2(q[1] - p[1], q[0] - p[0]))
    mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
    return Pos(mid[0], mid[1]) * Rot(0, 0, ang) * SlotCenterToCenter(L, 2 * r)


def _link(points, holes, extra=None, label="eslabon"):
    """Eslabon plano: union de capsulas por la polilinea `points`."""
    sk = None
    for a, b in zip(points[:-1], points[1:]):
        c = _capsule(P[a], P[b], W_LINK / 2)
        sk = c if sk is None else sk + c
    for (name, r) in (extra or []):
        sk += Pos(*P[name]) * Circle(r)
    solid = extrude(sk, T_LINK)
    for name, d in holes:
        solid -= Pos(*P[name], 0) * Cylinder(d / 2, 3 * T_LINK)
    solid.label = label
    return solid


def _involute_profile(module, teeth, backlash=0.0, n=8):
    rp = module * teeth / 2
    rb = rp * math.cos(math.radians(20))
    ra = rp + ADDENDUM * module
    rf = rp - DEDENDUM * module
    inv = lambda a: math.tan(a) - a
    psi = math.pi / (2 * teeth) - (backlash / 2) / rp
    def theta(r):
        return psi + inv(math.radians(20)) - inv(math.acos(min(rb / r, 1.0)))
    r0 = max(rb, rf)
    rs = [r0 + (ra - r0) * i / n for i in range(n + 1)]
    pts = []
    for i in range(teeth):
        c = 2 * math.pi * i / teeth
        flank = [(r, c - theta(r)) for r in rs]
        left = [(r, c + theta(r)) for r in reversed(rs)]
        seq = [(rf, c - math.pi / teeth * 0.5 - theta(r0) * 0.5)]
        if rb > rf:
            seq.append((rf, c - theta(r0)))
        seq += flank + left
        if rb > rf:
            seq.append((rf, c + theta(r0)))
        pts += [(r * math.cos(a), r * math.sin(a)) for r, a in seq]
    return Face(Wire.make_polygon([Vector(x, y, 0) for x, y in pts], close=True))


def _gear_body(teeth, thickness, hand):
    """Cuerpo dentado helicoidal: perfil involuta girado a lo largo del espesor.
    Giro total = thickness*tan(helice)/r_primitivo (rad)."""
    face = _involute_profile(MODULE, teeth, BACKLASH)
    if HELIX_DEG == 0:
        return extrude(face, thickness)
    rp = MODULE * teeth / 2
    twist = math.degrees(thickness * math.tan(math.radians(HELIX_DEG)) / rp) * hand
    return Solid.extrude_linear_with_rotation(face, (0, 0, 0), (0, 0, thickness), twist)


# ---------------- eslabones (capa 1 y 2) ----------------
def biela():
    """Biela ternaria C-E-K (capa 1)."""
    return _link(["C", "E", "K"], [("C", HOLE_M3), ("E", HOLE_M3), ("K", HOLE_M3)],
                 label="biela C-E-K")


def balancin_superior():
    return _link(["A", "H"], [("A", HOLE_M3), ("H", HOLE_M3)], label="balancin superior A-H")


def balancin_inferior():
    return _link(["B", "E"], [("B", HOLE_M3), ("E", HOLE_M3)], label="balancin inferior B-E")


def pierna():
    """Pierna ternaria H-K-F con agujero de 5.2 mm en el pie para un LED de 5 mm."""
    return _link(["H", "K", "F"], [("H", HOLE_M3), ("K", HOLE_M3), ("F", 5.2)],
                 extra=[("F", 6.5)], label="pierna H-K-F")


# ---------------- transmision ----------------
def engranaje_manivela():
    """Engranaje 36T m1.5 que hace de manivela.

    Local: cara frontal en z=0 (apoyo de impresion), trasera en z=8,
    boss trasero hasta z=11 que pisa la pista interna del 608ZZ.
    Bolsillo hexagonal frontal para la cabeza del perno M8 (gira con el engranaje).
    """
    g = _gear_body(Z_GEAR_TEETH, GEAR_T, GEAR_HAND)
    g += Pos(0, 0, GEAR_T) * Cylinder(5.5, 3.0, align=None)       # boss d11 x 3
    g -= Cylinder(8.3 / 2, 40)                                   # paso M8
    g -= Pos(0, 0, 0) * extrude(RegularPolygon(13.3 / math.sqrt(3), 6), 5.5)  # hex 13 AF
    for r, a in CRANK_HOLES:
        x, y = r * math.cos(math.radians(a)), r * math.sin(math.radians(a))
        g -= Pos(x, y, 0) * Cylinder(HOLE_M3 / 2, 40)
        g -= Pos(x, y, GEAR_T - 3.2) * Cylinder(3.1, 3.2, align=None)  # cabeza M3 por detras
    # aligerado: 3 ventanas entre agujeros
    for a in (60, 180, 300):
        g -= Pos(14 * math.cos(math.radians(a)), 14 * math.sin(math.radians(a)), 0) * Cylinder(4.0, 40)
    g.label = f"engranaje-manivela 36T mt1.5 helicoidal {HELIX_DEG:.0f} deg"
    return g


def pinon(bore=4.0):
    """Pinon 18T m1.5 para eje D de 4 mm (plano a 1.5 mm del centro).

    Sin prisionero: un tornillo radial atravesaria los dientes y chocaria con el
    engranaje. Se monta a presion en la D y se asegura con pegamento (epoxi o
    cianoacrilato). `bore` = diametro nominal del agujero (4.0 ajustado, 4.2 holgado).
    """
    p = _gear_body(Z_PINION_TEETH, GEAR_T, PINION_HAND)
    p -= Cylinder(bore / 2, 40)
    flat = 1.5 + (bore - 4.0) / 2                      # mismo juego en el plano de la D
    p += Pos(flat, -2.5, 0) * Box(1.5, 5, GEAR_T, align=None)
    p.label = f"pinon 18T m1.5 eje D4 (agujero {bore:.1f})"
    return p


# ---------------- estructura ----------------
def placa():
    """Placa vertical. Local (impresion): cara frontal en z=0 boca abajo,
    bosses traseros hacia +z. Ensamble: Rot X 180."""
    x0, x1 = PLATE_X
    y0, y1 = PLATE_Y
    # en el marco local la y queda invertida por el giro de 180 en X
    pl = Pos((x0 + x1) / 2, -(y0 + y1) / 2, PLATE_T / 2) * Box(x1 - x0, y1 - y0, PLATE_T)
    mx, my = MOTOR_XY[0], -MOTOR_XY[1]
    ax, ay = kg.GROUND["A"][0], -kg.GROUND["A"][1]
    bx, by = kg.GROUND["B"][0], -kg.GROUND["B"][1]
    # boss del rodamiento (detras): d30 hasta 9 mm de espesor
    pl += Pos(0, 0, PLATE_T) * Cylinder(15, 3, align=None)
    pl -= Pos(0, 0, 2) * Cylinder(BEARING_OD / 2, 20, align=None)   # bolsillo 608 desde atras
    pl -= Cylinder(7.0, 10)                                          # labio frontal d14
    # tubo del motor
    pl += Pos(mx, my, PLATE_T) * Cylinder(15.5, MOTOR_TUBE_L, align=None)
    pl -= Pos(mx, my, 2) * Cylinder(GEARBOX_D / 2, 40, align=None)
    pl -= Pos(mx, my, 0) * Cylinder(6.0, 10)
    ux, uy = math.cos(MOTOR_ANGLE), -math.sin(MOTOR_ANGLE)
    pl -= (Pos(mx + ux * 15, my + uy * 15, PLATE_T + MOTOR_TUBE_L / 2)
           * Rot(0, 0, math.degrees(math.atan2(uy, ux))) * Rot(0, 90, 0) * Cylinder(1.3, 12))
    # pivotes fijos A y B
    for x, y in ((ax, ay), (bx, by)):
        pl -= Pos(x, y, 0) * Cylinder(HOLE_M3 / 2, 40)
    # agujeros para fijar a la base
    for x in BASE_HOLES_X:
        pl -= Pos(x, -BASE_HOLE_Y, 0) * Cylinder(HOLE_M3 / 2, 40)
    pl.label = "placa"
    return pl


def base():
    """Base con canal para la placa. Local (impresion): losa en z 0..5.
    Local y = -(z del ensamble); local z = y del ensamble + 90."""
    x0, x1 = PLATE_X
    zb, zf = -60.0, 40.0            # profundidad (z del ensamble)
    slab = Pos((x0 + x1) / 2, -(zb + zf) / 2, 2.5) * Box(x1 - x0, zf - zb, 5)
    for zc in (-PLATE_T - 0.15 - 2.5, 0.15 + 2.5):       # paredes del canal (z ensamble)
        slab += Pos((x0 + x1) / 2, -zc, 5 + 6.5) * Box(x1 - x0, 5, 13)
    for x in BASE_HOLES_X:
        slab -= Pos(x, PLATE_T / 2, BASE_HOLE_Y - BASE_Y0) * Rot(90, 0, 0) * Cylinder(HOLE_M3 / 2, 40)
    slab.label = "base"
    return slab


def separador(length, label):
    s = Cylinder(3.5, length, align=None) - Cylinder(1.65, 3 * length)
    s.label = label
    return s


# ---------------- ubicacion en el ensamble ----------------
def placement(name):
    if name == "placa":
        return Rot(180, 0, 0)
    if name == "base":
        # losa local (x, y_local, z_local) -> ensamble: y_local=z, z_local=y
        return Pos(0, BASE_Y0, 0) * Rot(-90, 0, 0)
    if name == "engranaje":
        return Pos(0, 0, Z_GEAR + GEAR_T) * Rot(0, 0, math.degrees(kg.THETA0)) * Rot(180, 0, 0)
    if name == "pinon":
        return Pos(MOTOR_XY[0], MOTOR_XY[1], Z_GEAR) * Rot(0, 0, 7.25)  # fase: dientes engranados (helicoidal)
    if name in ("biela", "balancin_superior"):
        return Pos(0, 0, Z_L1)
    if name in ("balancin_inferior", "pierna"):
        return Pos(0, 0, Z_L2)
    raise KeyError(name)


# ---------------- prueba de engrane (calibra la distancia entre centros) ----------------
TEST_T = 4.0
TEST_DISTS = [(CENTER_DIST - 0.2, -60.0, 1), (CENTER_DIST, 0.0, 2), (CENTER_DIST + 0.2, 60.0, 3)]


def engranaje_prueba():
    g = _gear_body(Z_GEAR_TEETH, TEST_T, GEAR_HAND) - Cylinder(8.3 / 2, 20)
    for a in (60, 180, 300):
        g -= Pos(15 * math.cos(math.radians(a)), 15 * math.sin(math.radians(a)), 0) * Cylinder(5.0, 20)
    g.label = "engranaje de prueba 36T (4 mm)"
    return g


def pinon_prueba():
    p = _gear_body(Z_PINION_TEETH, TEST_T, PINION_HAND) - Cylinder(4.2 / 2, 20)
    p.label = "pinon de prueba 18T (4 mm)"
    return p


def base_prueba():
    """Base con perno d8.0 para el engranaje y tres pernos d4.0 para el pinon a
    CENTER_DIST-0.2 (1 punto), CENTER_DIST (2 puntos) y CENTER_DIST+0.2 (3 puntos)."""
    t, hp = 3.0, 9.0
    b = Cylinder(9.0, t, align=None)
    b += Cylinder(4.0, t + hp, align=None)                       # perno del engranaje
    for d, ang_d, n in TEST_DISTS:
        a = math.radians(ang_d)
        x, y = d * math.cos(a), d * math.sin(a)
        b += extrude(_capsule((0, 0), (x * 1.75, y * 1.75), 6.0), t)
        b += Pos(x, y, 0) * Cylinder(2.0, t + hp, align=None)    # perno del pinon
        for k in range(n):                                       # puntos de identificacion
            off = d + 20 + 4 * k
            b += Pos(off * math.cos(a), off * math.sin(a), t) * Cylinder(1.2, 1.0, align=None)
    b.label = "base de prueba de engrane"
    return b


def prueba_engrane_set():
    """Las tres piezas de la prueba, separadas para imprimirlas juntas."""
    parts = [base_prueba(), Pos(0, -95, 0) * engranaje_prueba(), Pos(50, -95, 0) * pinon_prueba()]
    labels = ["base de prueba", "engranaje de prueba 36T", "pinon de prueba 18T"]
    for s, lab in zip(parts, labels):
        s.label = lab
    return Compound(children=parts, label="prueba de engrane")


def carrete_calibracion():
    """Carrete para calibrar el torque del motor: nucleo r = 10 mm, va en el eje D."""
    core_r, flange_r, core_w, fl_t = 10.0, 15.0, 8.0, 1.6
    c = Cylinder(flange_r, fl_t, align=None)
    c += Pos(0, 0, fl_t) * Cylinder(core_r, core_w, align=None)
    c += Pos(0, 0, fl_t + core_w) * Cylinder(flange_r, fl_t, align=None)
    h = 2 * fl_t + core_w
    c -= Cylinder(2.0, 3 * h)
    c += Pos(1.5, -2.5, 0) * Box(1.5, 5, h, align=None)                     # plano de la D
    c -= Pos(0, 0, fl_t + core_w / 2) * Rot(0, 90, 0) * Cylinder(0.9, 30)   # agujero para amarrar el hilo
    c.label = "carrete de calibracion r10"
    return c
