"""Render Threshold, the 30-second title quartet, from the museum's samples."""
from fractions import Fraction
from functools import lru_cache
from pathlib import Path
import subprocess

import numpy as np
from scipy.signal import resample_poly


ROOT = Path(__file__).resolve().parent
RATE = 48000
BEAT = 60 / 44
LOOP = 30 * RATE

# Two 5/4–6/4 phrases in B-flat. Each entry gives the beat, duration in
# quarter notes, concert pitches (simultaneous for chords) and dynamics.
SCORE = {
    "Clarinet": [
        (1, 1.38, "G4", .77), (2.5, .85, "F4", .68), (3.5, 1.30, "D4", .63),
        (5, 1.40, "Eb4", .67), (6.5, .48, "G4", .75), (7, 1.72, "Bb4", .82),
        (9, .90, "A4", .66), (10, .76, "F4", .56),
        (11.5, .93, "G4", .72), (12.5, .45, "F4", .64), (13, 1.78, "D4", .64),
        (15, .76, "C4", .53), (16, 1.83, "Eb4", .64),
        (18, .88, "D4", .60), (19, .80, "C4", .53), (20, 1.57, "Bb3", .48),
    ],
    "Cello": [
        (0, 2.80, "Bb2", .88), (3, 1.85, "D3", .77), (5, 2.72, "Eb3", .85),
        (8, 1.78, "C3", .76), (10, .90, "F3", .67),
        (11, 1.85, "G3", .86), (13, 1.37, "Bb3", .82), (14.5, 1.28, "A3", .72),
        (16, 1.82, "G3", .77), (18, 1.87, "F3", .72), (20, 1.94, "Bb2", .86),
    ],
    "Piano": [
        (0.04, 2.20, "Bb2 F3 D4", .53), (3.02, 1.45, "F3 Bb3", .39),
        (5.04, 2.55, "Eb3 Bb3 G4", .52), (8.02, 1.35, "C3 G3 Bb3", .43),
        (10.03, .83, "F3 A3", .45), (11.04, 2.24, "G2 D3 Bb3", .52),
        (14.52, 1.24, "F3 C4", .40), (16.04, 1.83, "Eb3 Bb3", .47),
        (18.02, 1.78, "F2 C3 A3", .49), (20.04, 2.20, "Bb2 F3 D4", .53),
    ],
    "Harp": [
        (0, 1.10, "Bb3", .82), (.50, 1.45, "F4", .67), (1, 1.85, "Bb4", .62),
        (3.50, .90, "D4", .56), (4, .95, "F4", .64), (4.5, 1.30, "D5", .61),
        (5, 1.40, "Eb4", .72), (5.5, 1.50, "Bb4", .60), (7.5, 1.43, "G4", .55),
        (8, 1.35, "C4", .70), (8.5, 1.30, "G4", .62), (9.5, 1.50, "C5", .58),
        (11, 1.50, "G3", .77), (11.5, 1.20, "D4", .72), (12, 1.75, "Bb4", .68),
        (14, 1.35, "F4", .59), (14.5, 1.65, "C5", .62), (15.5, 1.28, "A4", .54),
        (16, 1.45, "Eb4", .69), (17, 1.40, "Bb4", .64), (18, .98, "F4", .62),
        (18.5, 1.12, "A4", .58), (19.5, 1.40, "C5", .50),
        (20, 1.60, "Bb3", .73), (20.5, 1.35, "F4", .64), (21, 1.45, "Bb4", .55),
    ],
}

# Use the same quiet grand-piano layer and chamber timbres as the promenade.
BANKS = {
    "Clarinet": {n: f"Clarinet {n}" for n in ("Bb3", "D4", "F4", "Bb4")},
    "Cello": {n: f"Cellos {n}" for n in ("G2", "D3", "F3", "A3", "C4")},
    "Piano": {n: f"Salamander/{n}v4" for n in ("F#2", "A2", "C3", "D#3", "F#3", "A3", "C4", "D#4", "F#4")},
    "Harp": {n: f"Harp {n}" for n in ("G3", "D4", "A4", "E5")},
}
PAN = {"Clarinet": .12, "Cello": .29, "Piano": -.12, "Harp": -.38}
LEVEL = {"Clarinet": .75, "Cello": .74, "Piano": .47, "Harp": .64}


def pitch(note):
    semitone = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[note[0]]
    return 12 * (int(note[-1]) + 1) + semitone + note.count("#") - note.count("b")


@lru_cache(maxsize=None)
def recording(instrument, note):
    bank = BANKS[instrument]
    nearest = min(bank, key=lambda n: abs(pitch(n) - pitch(note)))
    path = ROOT / "Audio Files" / (bank[nearest] + ".flac")
    raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-ar", str(RATE),
                                   "-ac", "2", "-f", "f32le", "-"])
    sample = np.frombuffer(raw, dtype="<f4").reshape(-1, 2)
    ratio = Fraction(2 ** ((pitch(nearest) - pitch(note)) / 12)).limit_denominator(256)
    sample = resample_poly(sample, ratio.numerator, ratio.denominator, axis=0)
    # Balance the body of each recorded note, retaining its original attack.
    rms = np.sqrt(np.mean(sample[RATE // 4:RATE] ** 2))
    return sample * (.10 / rms)


def render():
    mix = np.zeros((LOOP + 3 * RATE, 2))
    for instrument, notes in SCORE.items():
        sustained = instrument in ("Cello", "Clarinet")
        release = .18 if sustained else .72
        pan = PAN[instrument]
        gain = LEVEL[instrument] * np.sqrt([1 - pan, 1 + pan])
        for beat, length, pitches, dynamic in notes:
            start = round(beat * BEAT * RATE)
            for note in pitches.split():
                sample = recording(instrument, note)
                frames = min(len(sample), round((length * BEAT + release) * RATE), len(mix) - start)
                time = np.arange(frames) / RATE
                envelope = np.minimum(time / .006, 1) * np.clip((frames / RATE - time) / release, 0, 1) ** 2
                if sustained:
                    envelope *= .81 + .19 * np.sin(np.pi * np.minimum(time / (length * BEAT), 1))
                mix[start:start + frames] += sample[:frames] * envelope[:, None] * gain * dynamic
    dry = mix.copy()
    for delay, level in ((.049, .11), (.083, .07), (.149, .045)):
        offset = round(delay * RATE)
        mix[offset:] += dry[:-offset, ::-1] * level
    # Let the final harp and piano decay through the downbeat of the next loop.
    tail = mix[LOOP:].copy()
    loop = mix[:LOOP]
    loop[:len(tail)] += tail
    loop *= .77 / np.max(np.abs(loop))
    target = ROOT.parent / "museum/audio/threshold.ogg"
    subprocess.run([
        "ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2",
        "-i", "-", "-c:a", "libvorbis", "-q:a", "6", "-metadata", "title=Threshold",
        "-metadata", "description=Original title quartet for Mirror Transport Museum. Concert harp, clarinet, piano and cello.",
        "-metadata", "copyright=Harp, clarinet and cello samples from VSCO 2 Community Edition (CC0). "
        "Grand piano adapted from Salamander Grand Piano v3 by Alexander Holm "
        "(https://github.com/sfzinstruments/SalamanderGrandPiano), CC BY 3.0 "
        "(https://creativecommons.org/licenses/by/3.0/).",
        str(target),
    ], input=loop.astype("<f4").tobytes(), check=True)


if __name__ == "__main__":
    render()
