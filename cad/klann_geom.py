"""Geometria y cinematica de la pierna Klann (patente US 6,260,862, Tabla 1).

Modulo compartido por la simulacion y por los generadores CAD.
Unidades: mm. Plano del mecanismo: XY. Origen: eje de la manivela O.
"""
import math

# --- Coordenadas de la Tabla 1 de la patente (unidades de la patente) ---
PATENT = {
    "A": (1.366, 1.366),  # pivote fijo del balancin superior
    "B": (1.009, 0.574),  # pivote fijo del balancin inferior
    "O": (1.599, 0.750),  # eje fijo de la manivela
    "C": (1.331, 0.750),  # pasador de la manivela
    "E": (0.741, 0.750),  # union biela - balancin inferior
    "K": (0.232, 0.866),  # rodilla: union biela - pierna
    "H": (0.866, 1.500),  # cadera: union pierna - balancin superior
    "F": (0.000, 0.000),  # pie
}

CRANK_R = 20.0                       # radio de manivela elegido [mm]
SCALE = CRANK_R / math.dist(PATENT["O"], PATENT["C"])


def _pt(name):
    ox, oy = PATENT["O"]
    x, y = PATENT[name]
    return ((x - ox) * SCALE, (y - oy) * SCALE)


# Posicion inicial (angulo de manivela de la patente = 180 deg) con origen en O
P0 = {k: _pt(k) for k in PATENT}
GROUND = {"O": P0["O"], "A": P0["A"], "B": P0["B"]}


def d(a, b):
    return math.dist(P0[a], P0[b])


# Longitudes (eslabones binarios) y lados de los ternarios
L = {
    "crank": d("O", "C"),        # manivela O-C
    "lower": d("B", "E"),        # balancin inferior B-E
    "upper": d("A", "H"),        # balancin superior A-H
    "CE": d("C", "E"), "CK": d("C", "K"), "EK": d("E", "K"),   # biela ternaria
    "HK": d("H", "K"), "HF": d("H", "F"), "KF": d("K", "F"),   # pierna ternaria
}
THETA0 = math.atan2(P0["C"][1], P0["C"][0])   # angulo inicial de la manivela


def _circ(p, r1, q, r2, ref):
    """Interseccion de circulos (p,r1) y (q,r2); devuelve la mas cercana a ref."""
    dx, dy = q[0] - p[0], q[1] - p[1]
    D = math.hypot(dx, dy)
    if D > r1 + r2 or D < abs(r1 - r2):
        return None
    a = (r1 * r1 - r2 * r2 + D * D) / (2 * D)
    h = math.sqrt(max(r1 * r1 - a * a, 0.0))
    mx, my = p[0] + a * dx / D, p[1] + a * dy / D
    s1 = (mx - h * dy / D, my + h * dx / D)
    s2 = (mx + h * dy / D, my - h * dx / D)
    return min((s1, s2), key=lambda s: math.dist(s, ref))


def _place(p1, q1, p2, q2, r):
    """Transforma el punto r rigido con el segmento p1->q1 llevado a p2->q2."""
    a1 = math.atan2(q1[1] - p1[1], q1[0] - p1[0])
    a2 = math.atan2(q2[1] - p2[1], q2[0] - p2[0])
    c, s = math.cos(a2 - a1), math.sin(a2 - a1)
    x, y = r[0] - p1[0], r[1] - p1[1]
    return (p2[0] + c * x - s * y, p2[1] + s * x + c * y)


def solve(theta, lengths=None, prev=None):
    """Posicion de todas las juntas para un angulo de manivela theta [rad].

    lengths: dict opcional que reemplaza longitudes (para sensibilidad).
    prev: solucion previa (para seguir la misma rama del mecanismo).
    """
    Lx = dict(L)
    if lengths:
        Lx.update(lengths)
    ref = prev or P0
    O, A, B = GROUND["O"], GROUND["A"], GROUND["B"]
    C = (Lx["crank"] * math.cos(theta), Lx["crank"] * math.sin(theta))
    E = _circ(C, Lx["CE"], B, Lx["lower"], ref["E"])            # lazo 1
    if E is None:
        return None
    # K es rigido con C-E en la biela (triangulo C,E,K de la patente)
    K = _place(P0["C"], P0["E"], C, E, P0["K"])
    if lengths:  # si se cambian lados de la biela, recalcular K por circulos
        K = _circ(C, Lx["CK"], E, Lx["EK"], ref["K"])
        if K is None:
            return None
    H = _circ(K, Lx["HK"], A, Lx["upper"], ref["H"])            # lazo 2
    if H is None:
        return None
    F = _circ(H, Lx["HF"], K, Lx["KF"], ref["F"])
    if F is None:
        return None
    return {"O": O, "A": A, "B": B, "C": C, "E": E, "K": K, "H": H, "F": F}


def cycle(n=360, lengths=None):
    """Recorre una vuelta completa partiendo de la posicion de la patente."""
    sols, prev = [], None
    for i in range(n):
        th = THETA0 - 2 * math.pi * i / n   # sentido horario: el pie avanza hacia -x en apoyo
        s = solve(th, lengths, prev)
        if s is None:
            return None
        sols.append(s)
        prev = s
    return sols
