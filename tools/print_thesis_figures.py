"""Reproduce the uncropped thesis figures on the gallery walls using Poppler."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MODELS = "Chapter POA Toy Models"
GKEYLL = "Chapter Gkeyll POA simulations"
SENSITIVITY = f"{GKEYLL}/figures/algorithm-sensitivity"

FIGURES = {
    2: [
        {
            "figure": "3.5",
            "asset": "orbit-paths",
            "source": f"{MODELS}/figures/phase-compression.pdf",
            "caption_source": f"{MODELS}/tex-files/five_equation_toy_model.tex",
            "kind": "Schematic of the five-equation model, no simulated frame.",
        },
        {
            "figure": "3.6",
            "asset": "orbit-phases",
            "source": f"{MODELS}/figures/fiveeq_modulated_vs_exact_distributed_source_distributed_loss.pdf",
            "caption_source": f"{MODELS}/tex-files/fiveeq_distS_distL.tex",
            "model": f"{MODELS}/scripts/paper_fiveeq_time_evolution_demonstration_distS_distLoss.ipynb",
            "kind": "Five-equation toy-model transient. Distributed source and coupling, S=1, nu_c=1, nu_parallel=1000, alpha=0.1. Time is in the normalized units on the published axes.",
        },
    ],
    3: [
        {
            "figure": "5.23",
            "asset": "dilation-occupancy",
            "source": f"{SENSITIVITY}/time-dilation-occupancy.pdf",
            "plot_script": f"{SENSITIVITY}/time-dilation-mask.py",
            "diagnostics": [
                "zzim-ion_75.gkyl",
                "zzim-ion_fdot_multiplier_75.gkyl",
                "zzim-ion_jacobvel.gkyl",
                "zzim-geo_int_jacobtot.gkyl",
                "zzim-geo_corn_mc2nu_pos_deflated.gkyl",
                "zzim-ion_mapc2p_vel.gkyl",
            ],
            "quantity": "Mapped phase cells with beta < 1 or |mean f_i| >= 10% of the local peak, fraction of cells and absolute ion content masked vs axial position. Dotted control curve uses undilated ion content.",
        },
        {
            "figure": "5.25",
            "asset": "dilation-comparison",
            "source": f"{SENSITIVITY}/time-dilation-comparison.pdf",
            "plot_script": f"{SENSITIVITY}/time-dilation-comparison.py",
            "diagnostics": [
                "zzim-ion_BiMaxwellianMoments_75.gkyl",
                "zzim-geo_corn_mc2nu_pos_deflated.gkyl",
                "zzim-ion_integrated_moms.gkyl",
            ],
            "quantity": "Density (m^-3), parallel flow (m/s), parallel and perpendicular ion temperatures (keV) vs each run's mapped axial position. Linear y axes for z < 0 and positive values on log y axes for z > 0.",
        },
    ],
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def render(thesis):
    for gallery, figures in FIGURES.items():
        folder = ROOT / f"simulation-renders/gallery-{gallery}"
        entries = []
        for figure in figures:
            source = thesis / figure["source"]
            target = folder / figure["asset"]
            subprocess.run(
                [
                    "pdftoppm",
                    "-singlefile",
                    "-png",
                    "-scale-to",
                    "1536",
                    str(source),
                    str(target),
                ],
                check=True,
            )
            output = target.with_suffix(".png")
            with Image.open(output) as image:
                entry = dict(
                    figure,
                    asset=output.name,
                    pixels=image.size,
                    pdf_sha256=digest(source),
                    png_sha256=digest(output),
                )
            if gallery == 3:
                entry.update(
                    caption_source=f"{GKEYLL}/tex-files/without-time-dialtion.tex",
                    runs=["1x-beams", "1x-beams-no-tdil"],
                    frame=75,
                    saved_time_s=0.500150,
                )
            entries.append(entry)
        manifest = {
            "source": "Maxwell Rosen, PhD thesis (PhD-thesis-latex)",
            "conversion": "Original one-page PDF rasterized with pdftoppm to RGB PNG at 1536 pixels on the long side. No crop, replotting or recoloring. The print quad preserves aspect ratio. Lossless Godot texture import with mipmaps.",
            "figures": entries,
        }
        (folder / "thesis-prints.json").write_text(
            json.dumps(manifest, indent=2) + "\n"
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "thesis",
        nargs="?",
        type=Path,
        default=Path.home() / "Documents/PhD-thesis-latex",
    )
    render(parser.parse_args().thesis)
