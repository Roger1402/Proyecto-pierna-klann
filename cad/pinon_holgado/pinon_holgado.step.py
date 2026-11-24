"""Pinon 18T con agujero D holgado (4.2 mm) por si el ajustado no entra."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import klann_parts as kp  # noqa: E402


def gen_step():
    return kp.pinon(4.2)
