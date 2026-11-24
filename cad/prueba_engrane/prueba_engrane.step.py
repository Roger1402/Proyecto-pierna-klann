"""Prueba de engrane helicoidal: base con 3 distancias entre centros + engranajes delgados."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import klann_parts as kp  # noqa: E402


def gen_step():
    return kp.prueba_engrane_set()
