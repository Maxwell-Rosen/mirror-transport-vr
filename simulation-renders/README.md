# Simulation renders

Put the textures and 3D data that ship with the museum here, including slice atlases and isosurface meshes. Commit the finished assets to GitHub. Keep each file **under 100 MB** (100,000,000 bytes) and aim well below that for quick exhibit loading and small desktop and Quest downloads.

Keep the original runs local in `gkeyll-data/<run>/`. When reducing a texture or simplifying a mesh, compare the exported values and coordinates at representative locations, such as the midplane and a throat, with the same diagnostic and frame. Record the source files, units, frame, saved time and any conversion or reduction in the asset manifest. [Exhibit-specific checks](../PLAN.md#platform-and-simulation-data)

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
