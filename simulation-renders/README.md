# Simulation renders

Put the simulation textures and 3D data that ship with the museum here, including slice atlases and isosurface meshes. Group them by gallery number under `simulation-renders/gallery-N/` and link to their manifests from the corresponding gallery plan. Commit the finished assets to GitHub. Keep each file **under 100 MB** (100,000,000 bytes) and aim well below that for quick exhibit loading and small desktop and Quest downloads.

Keep the original runs local in `gkeyll-data/<run>/`. When reducing a texture or simplifying a mesh, compare the exported values and coordinates at representative locations, such as the midplane and a throat, with the same diagnostic and frame. Record the source files, units, frame, saved time and any conversion or reduction in the asset manifest. [Exhibit-specific checks](../PLAN.md#platform-and-simulation-data)

Gallery 2 ships lossless dye histories for the river and whirlpool, and native bead trajectories with their wall and trapped-loss events. Its teaching-model manifest records the sources, normalizations, frames and transformations. [Between Bounces manifest](gallery-2/manifest.json) · [Exporter](../gallery-2/tools/export_gallery.py)

Gallery 3 ships twenty sampled clock rates and relative cell-integrated ion contents from frame 75 of `1x-beams`. Its manifest also records the physical coordinates, logarithmic brightness mapping, exhibit clock and illustrative damping envelope. [Time Dilation manifest](gallery-3/manifest.json) · [Exporter](../gallery-3/tools/export_lamps.py)

Gallery 4 ships three native cuts of the frame-2 beam-run loss-cone mask, the maps and field traces for probing all 6,144 cells, two samplings of the axial magnetic field and two original thesis prints. The near-midplane cut also carries 2,048 signed distribution values for the computational and physical grid comparison. The exporters verify the saved mask and the distribution’s velocity integral against the independent ion-density diagnostic. [Loss and grid manifest](gallery-4/manifest.json) · [Mask and axial grid exporter](../gallery-4/tools/export_exhibit.py) · [Velocity distribution exporter](../gallery-4/tools/velocity_grid.py)

Gallery 5 pairs the signed distributions and orbit-distributed injection of the two ratio-32 baselines, their density and potential histories, and fourteen audited scan endpoints. Its asset index links the individual source records and numerical checks. [Simple-mirror manifest](gallery-5/manifest.json)

## Plot a saved field in Python

Run this example from the project root. It uses Postgkyl to read the static magnetic field and its axial coordinate map from `gkeyll-data/1x-beams/`. Both diagnostics store linear discontinuous Galerkin coefficients. At a cell centre, only the constant coefficient contributes, with a factor of 1/√2.

```python
from math import sqrt
from pathlib import Path

import matplotlib.pyplot as plt
import postgkyl as pg

run = Path("gkeyll-data/1x-beams")


def cell_centre_values(filename):
    modes = pg.GData(str(run / filename)).get_values()
    return modes[:, 0] / sqrt(2)


z = cell_centre_values("zzim-geo_corn_mc2nu_pos_deflated.gkyl")
b = cell_centre_values("zzim-geo_int_bmag.gkyl")
plt.plot(z, b)
plt.xlabel("Axial position Z (m)")
plt.ylabel("Magnetic field strength B (T)")
plt.title("1x-beams · static geometry · frame 0, t = 0 s")
plt.show()
```
