"""Separadores impresos (tubo d7 / d3.3): A=13 mm, B=18.5 mm, pasador C=1.6 mm."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import klann_parts as kp  # noqa: E402
from build123d import Compound, Pos  # noqa: E402


def gen_step():
    a = Pos(0, 0, 0) * kp.separador(13.0, "separador A 13 mm")
    b = Pos(12, 0, 0) * kp.separador(18.5, "separador B 18.5 mm")
    c = Pos(24, 0, 0) * kp.separador(1.6, "separador pasador C 1.6 mm")
    for s, lab in ((a, "separador A 13 mm"), (b, "separador B 18.5 mm"), (c, "separador pasador C 1.6 mm")):
        s.label = lab
    return Compound(children=[a, b, c], label="separadores")
