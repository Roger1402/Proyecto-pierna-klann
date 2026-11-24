"""Carrete de calibracion del torque del motor (nucleo r = 10 mm, eje D de 4 mm)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import klann_parts as kp  # noqa: E402


def gen_step():
    return kp.carrete_calibracion()
