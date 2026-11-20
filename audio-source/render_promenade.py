"""Print the museum loop from Promenade.scraft with SoundCraft CLI and ffmpeg."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    session = Path(__file__).resolve().with_name("Promenade.scraft")
    destination = session.parents[1] / "museum/audio/promenade.ogg"
    score = json.loads(session.read_text(encoding="utf-8"))
    loop_end = next(m["start"] for m in score["markers"] if m["name"] == "Loop end")
    rate = score["sample_rate"]

    cli = shutil.which("soundcraft-cli")
    command = [cli] if cli else [
        "flatpak", "run", f"--filesystem={session.parent}",
        "--command=soundcraft-cli", "ai.storyteller.soundcraft",
    ]
    with tempfile.TemporaryDirectory(dir=session.parent) as directory:
        bounce = Path(directory) / "Promenade.wav"
        encoded = Path(directory) / "promenade.ogg"
        subprocess.run([
            *command, "run", "--in", str(session), "--bounce", str(bounce),
            "--end", str(loop_end / rate + 3),
        ], check=True)

        # Fold the final room decay over the opening bow at unity gain.
        fold = (
            "[0:a]asplit[body][tail];"
            f"[body]atrim=end_sample={loop_end},asetpts=PTS-STARTPTS[phrase];"
            f"[tail]atrim=start_sample={loop_end},asetpts=PTS-STARTPTS[decay];"
            "[phrase][decay]amix=inputs=2:duration=first:normalize=0[music]"
        )
        subprocess.run([
            "ffmpeg", "-v", "error", "-i", str(bounce), "-filter_complex", fold,
            "-map", "[music]", "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "7",
            "-metadata", "title=Promenade — Mirror Transport Museum",
            "-metadata", "composer=Modest Mussorgsky",
            "-metadata", f"bpm={score['tempo']['tempos'][0]['bpm']:g}",
            "-metadata", "description=Promenade I for soft clarinet, bowed cellos and grand piano.",
            "-metadata", "copyright=Clarinet and bowed cellos from Versilian Studios Chamber Orchestra "
                         "2 Community Edition (CC0). Grand piano sampled from "
                         "Salamander Grand Piano v3 by Alexander Holm "
                         "(https://github.com/sfzinstruments/SalamanderGrandPiano), "
                         "CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/).",
            str(encoded),
        ], check=True)
        encoded.replace(destination)


if __name__ == "__main__":
    main()
