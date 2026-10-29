#!/usr/bin/env python3
"""Render Marbly's switch sounds with mechsound and write them as WAV files.

mechsound (https://github.com/airodynamic07/mechanical-keyboard-sound) synthesises
switch sounds from a band-passed keycap "clack", a decaying bottom-out "thock",
a leaf click for clicky switches, and per-press variation.

    python3 -m venv .venv
    .venv/bin/pip install numpy
    .venv/bin/pip install --no-deps git+https://github.com/airodynamic07/mechanical-keyboard-sound
    .venv/bin/python scripts/generate_sounds.py

Output: Sources/Marbly/Resources/Sounds/<profile>/{press,release}-<n>.wav
(16-bit mono, 44.1 kHz). Only the selected profile is loaded at runtime.
"""

from pathlib import Path
import wave

import numpy as np
from mechsound.synth import PROFILES, SAMPLE_RATE, KeyKind, render_press, render_release

VARIANTS = 4
OUT = Path(__file__).resolve().parent.parent / "Sources/Marbly/Resources/Sounds"


def write_wav(path: Path, samples: np.ndarray) -> None:
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(pcm.tobytes())


def main() -> None:
    rng = np.random.default_rng(7)  # fixed seed: regenerating gives the same files
    for name, profile in PROFILES.items():
        folder = OUT / name
        folder.mkdir(parents=True, exist_ok=True)
        for i in range(VARIANTS):
            write_wav(folder / f"press-{i}.wav", render_press(profile, KeyKind.NORMAL, rng))
            write_wav(folder / f"release-{i}.wav", render_release(profile, KeyKind.NORMAL, rng))
        print(f"{name}: {VARIANTS} press + {VARIANTS} release")


if __name__ == "__main__":
    main()
