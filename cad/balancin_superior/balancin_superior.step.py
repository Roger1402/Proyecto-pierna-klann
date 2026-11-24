"""Pieza 'balancin_superior' de la pierna Klann reconfigurable (orientacion de impresion)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import klann_parts as kp  # noqa: E402


def gen_step():
    return kp.balancin_superior()
