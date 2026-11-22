"""Render the six original Chapter 5 plates and record their provenance."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CHAPTER = Path("Chapter Gkeyll POA simulations")
BASELINES = ["1x-maxw", "1x-beams"]
EXTENDED = BASELINES + [f"{run}-fdp-continuation" for run in BASELINES]
# Figure number, plot master, caption source, runs, sampling and plotted diagnostic.
PLATES = [
    ("5.1", "equilibrium/equilibrium-moments", "results_lorentzian", BASELINES,
     "Frame 75, 0.500150 s", "Ion BiMaxwellianMoments and mapped axial coordinate"),
    ("5.2", "equilibrium/distribution-functions", "results_lorentzian", BASELINES,
     "Frame 75, 0.500150 s, midplane, right throat and sheath",
     "Absolute ion distribution, mapped velocity and configuration coordinates and Jacobians"),
    ("5.3", "verification/fdp-continuation", "verification", EXTENDED,
     "POA frame 75 at 0.500150 s and final frame of 300 microsecond FDP continuation",
     "Ion density, parallel flow and ion temperatures on the mapped field line"),
    ("5.4", "verification/integrated-diagnostics", "verification", EXTENDED,
     "Final 90 microseconds of POA through frame 75 and 0 to 300 microseconds of continuation",
     "Inventory, kinetic energy, midplane density, summed wall losses relative to feed, total ion wall power"),
    ("5.5", "equilibrium/potential-evolution", "confinement-scan", BASELINES[:1],
     "Frames 0 to 75 ending at 0.500150 s", "Electrostatic potential at three axial samples"),
    ("5.6", "confinement/confinement-time", "confinement-scan",
     ["All fourteen simulations identified by the scan's individual run directories in scan.json"],
     "Frame 75 at 0.500150 s in each run", "Ion inventory / injection times reference midplane scattering frequency"),
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export(thesis):
    out = ROOT / "simulation-renders/gallery-5"
    out.mkdir(exist_ok=True, parents=True)
    entries = []
    for figure, relative, caption, runs, sampling, diagnostic in PLATES:
        master = CHAPTER / "figures" / (relative + ".pdf")
        source = thesis / master
        prefix = out / f"fig-{figure.replace('.', '-')}"
        subprocess.run(["pdftoppm", "-singlefile", "-png", "-scale-to", "1536", source, prefix], check=True)
        target = prefix.with_suffix(".png")
        with Image.open(target) as image:
            entries.append(dict(figure=figure, file=target.name, pixels=image.size,
                                master=str(master), plot_script=str(master.with_suffix(".py")),
                                caption_source=str(CHAPTER / "tex-files" / (caption + ".tex")),
                                runs=runs, sampling=sampling, diagnostic=diagnostic,
                                source_sha256=digest(source), png_sha256=digest(target)))
    (out / "thesis-prints.json").write_text(json.dumps({
        "source": "Maxwell Rosen, PhD thesis, Chapter 5",
        "conversion": "Uncropped one-page print master, Poppler pdftoppm at 1536 pixels on the long edge, lossless RGB PNG. Frame uses native image aspect ratio. Native figure axes, scales, signs and legends retained.",
        "plates": entries,
    }, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("thesis", nargs="?", type=Path, default=Path.home() / "Documents/PhD-thesis-latex")
    export(parser.parse_args().thesis)
