# Gallery 3 · Time Dilation

**Which lights fall behind the beat?** Enter the second gallery on the left and turn toward the right wall. Ten amber bulbs orbit on a suspended brass mobile. The fixed lamp above the rim pulses every 3.6 exhibit seconds. Choose **Start together** and watch the brass index as the reference lamp pulses again.

The mobile opens on the right mirror throat. Seven of the ten bulbs return together. The outer three glow more faintly and take longer to come around. **Use reference beat** puts all ten clocks at full rate for comparison. **View midplane** moves the same ten velocity samples to the first cell on the positive side of the midplane. **Inspect next ring** moves the white hoop to another lamp and updates the lectern. Point and click or use the right Quest trigger. On desktop, Tab and Shift+Tab move focus at the lectern and Enter activates the selected button.

**What sets the time step for the whole grid?** Gallery 3 extends 34 m from the atrium. Along the right wall, the mask sculpture and the paired rate and step maps have 3.7 m of open floor between their plinths. Nine metres farther along the wall, a separate station compares two volumes of cells at a chosen time limit. Each station has its own controls. Across all the scientific sculptures, axial position Z runs left to right, magnetic moment μ increases upward and positive parallel velocity v∥ runs into the stand. [Visitor questions and source calculations](local-timestep.md)

## What the lamps measure

Each ring is a clock representing one phase-space cell in the `1x-beams` ion run, at frame 75 and saved time 0.500150 s. The equal ring spacing orders ten increasing positive parallel velocities at magnetic moment μ = 0.04437 keV/T. The lectern gives the selected velocity and axial cell centre. The radii and circular motion are sculptural.

- **Timing.** The cellwise `fdot_multiplier` gives the dimensionless local time factor β. One turn and one smooth pulse take 3.6/β exhibit seconds. In the near-midplane cut at Z = +0.014865 m every sampled β is 1. At the right throat at Z = +0.979129 m the outermost lamp has β = 0.186021 and a period of 19.35 exhibit seconds. The animation compares rates at a single saved instant.
- **Brightness.** The peak filament intensity shows the magnitude of the cell-average ion distribution |fᵢ| relative to the largest sampled value on the current cut. A logarithmic mapping covers 24 decades and retains a 15% minimum peak so the faintest lamp stays visible. This normalization compares velocities within each cut. Gkeyll chooses which cells to slow from their local numerical time-step limit.

The exporter reads the original DG coefficients with Postgkyl, evaluates the run’s coordinate maps, removes the saved Jacobians from the ion distribution and checks its full velocity integral against the saved ion density. The mobile loads twenty cell samples. [Lamp manifest](../simulation-renders/gallery-3/manifest.json) · [Conversion and checks](tools/export_lamps.py)

## Phase-space sculpture

The plinth projects from the right wall. Its sloping front edge has two selectable, ten-band colour bars. The warm bar gives the minimum ion distribution as a percentage of the peak at each axial position. The blue bar gives the upper threshold of the dimensionless time factor β. Select a colour with the mouse or right trigger to isolate the corresponding shell. Select it again to restore that family. The companion print faces the mask sculpture across the aisle and has the same selectors. Tab, Shift+Tab and Enter operate the bars at either location. A nearby reading board explains the mirror force near a throat.

**How much of the ion distribution sits in cells whose update Gkeyll slows?** In frame 75, the local time factor β is below one in 366,226 of 819,200 cells (44.7%). These cells carry 0.00555% of the total absolute ion content. The largest distribution magnitude in a slowed cell is 6.52% of the velocity-space peak at the same axial position. The velocity slice at Z = −0.866 m shows where the slowed fraction of local absolute ion content is largest (5.86%). [Full-size sketch](sketches/time-dilation.png)

Both signs of parallel velocity come from the saved run, spanning −10.09 to +10.09 million m/s. The ten **Inferno** surfaces enclose cells at or above successive distribution thresholds, from 10⁻⁵ to 0.316 of the peak at each Z, in half-decade steps. The ten **blue** surfaces enclose cells with β below 0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 and 1. Lighter blues mark stronger slowing. The contour lines inside the 3D sketch trace the faces of the first positive-velocity cells at the zero-velocity interface. In the enlarged velocity slice, dots mark the slowed side of the β = 1 boundary.

Run the Python figure from the repository root. Drag the 3D axes to rotate. Click a colour swatch to isolate that level within its family, then click it again to restore the family. The figure uses Postgkyl, NumPy, SciPy and Matplotlib. Rebuilding the binary glTF also uses Trimesh (tested with 5.2.1).

```sh
python3 gallery-3/gkeyll-data-sculpture.py --show
python3 gallery-3/gkeyll-data-sculpture.py --figure gallery-3/sketches/time-dilation.png --glb
```

To try a smaller selection, run `python3 gallery-3/gkeyll-data-sculpture.py --f-levels .001 .01 .1 --beta-levels .25 .5 1 --show`. Passing a path after `--glb` saves a separate model, matching wall print and manifest. The manifest records the swatch bounds used by the in-game controls.

In Godot, drag `res://simulation-renders/gallery-3/time-dilation.glb` into a 3D scene. Its `IonDistribution` and `TimeFactor` groups each contain one mesh per threshold. The unlit materials carry the same colormaps as the figure. The gallery enlarges the mask and distribution sculpture uniformly by 25%. On the installed rulers, one metre of axial position spans 0.75 exhibit m, 10⁶ m/s of parallel velocity spans 0.0875 exhibit m and 1 keV/T of magnetic moment spans 0.0225 exhibit m. The axial span from −2.5 to +2.5 m measures 3.75 m on the plinth. [Mesh mapping and source scale](tools/phase_mesh.py)

The meshes follow the exterior faces of the selected cells. Joining coplanar faces and sharing vertices packs all twenty levels into a 6.8 MB model. Godot 4.7.2 imported it as a 2.12 MB scene with 344,368 triangles across all levels. The sketch omits the flat caps at the limits of the sampled domain. The GLB includes them so each level encloses its full region. The exporter checks the signed velocity integral against the saved ion density in all 400 axial cells, then reloads the GLB and compares its triangle coordinates and enclosed volumes with the mapped grid. [Mesh](../simulation-renders/gallery-3/time-dilation.glb) · [Source files, thresholds and checks](../simulation-renders/gallery-3/time-dilation.json) · [Python figure](gkeyll-data-sculpture.py)

## Five velocity slices of CFL rate and time step

The left map colours each native cell by its saved CFL rate ω in 10⁹ s⁻¹. The right colours the same cells by their permitted step τ in nanoseconds. At unit Courant factor, the step is the reciprocal of the rate. Each map has a numerical colour bar. Violet marks every cell slowed to the rate cap, 1.902715 × 10⁹ s⁻¹, and the corresponding step floor, 0.525565 ns.

Select one of five signed parallel velocities, −7.287, −2.389, +0.191, +2.389 or +7.287 × 10⁶ m/s. Each cut moves to the depth of its native velocity bin. **Compare all five cuts** keeps the selected plane filled and traces the numerical colour-band boundaries on the other four planes. The violet outlines mark the slowed cells at each velocity. On both this station and the contour station, a metre along the mirror spans 0.43 exhibit m, a velocity interval of 10⁶ m/s spans 0.093 m in depth and a magnetic moment of 1 keV/T spans 0.0185 m vertically.

Each flat line chart on the front of the plinth follows the top row of its map, at μ = 67.7667 keV/T. The charts plot rate and step against Z on logarithmic vertical scales (0.158 exhibit m per decade). White and violet trace the saved values. Amber appears where the reconstructed uncapped profile differs. A white point on each map marks the probed cell. The white point and amber ring on each chart mark its two values. On the initial +191.195 km/s slice, 4,031 cells are slowed. At its shortest-step cell the uncapped estimate is 0.0526 ns and the saved step is 0.5256 ns. Choose **Midplane** for a cell where both give 30.1912 ns. [Velocity cuts, colours and probes](../simulation-renders/gallery-3/cfl-relief.json) · [Offline conversion and verification](tools/export_relief.py)

## Which cells need a short step?

The next plinth has two equal boxes. Each shows the entire sampled position and velocity domain. Choose one upper limit from 0.1, 0.25, 0.5, 1, 5 and 20 ns. A blue shell encloses the qualifying cells. The left box uses the uncapped estimate reconstructed from the saved multiplier β. The right uses the saved capped rate from the same instant. Both show counts and identify whether their common probe qualifies. The open frame keeps the domain visible even for an empty selection.

At 0.1 ns, 38,037 cells qualify on the left and zero on the right. At 1 ns both shapes coincide because the cap only raises steps below 0.526 ns. **Time floor** outlines the saved β < 1 region in violet and **10% ion core** adds the population reference in gold. **Use lamp cell** follows the selected ring and slice at the entrance station. The map slice, contour threshold and mask colour bars can be changed independently. [Local time contours and probe manifest](../simulation-renders/gallery-3/local-cfl.json) · [Contour exporter](tools/export_cfl.py)

### Rendering cost in the museum

Gallery 3 requests the installation in the background when the visitor enters. Crossing into the atrium releases the five cuts, both contour volumes, the mask, print, controls and plinths. A load that finishes after the visitor has left is discarded. The mask sculpture shader opens the display at the limits of the sampled domain and brightens a 3.75 mm band on the positive-velocity side of the zero interface. The source meshes retain the complete closed cell unions.

With the mask, maps and contour comparison mounted, the installation added about **10.5 MiB of graphics memory** on a Radeon 760M (7.3 MiB of buffers and 3.2 MiB of textures). The tracked CPU heap grew by about 6.1 MiB. The 1280 × 800 overview took 2.3 ms of GPU time with the exhibits and 2.1 ms after unloading them. These are single-view desktop measurements. The Quest build uses an ASTC wall print.

Run the room-boundary test from the project root. Add `-- --profile --pictures` on a desktop display to measure the same viewpoints with and without the installation and capture the right wall, colour bars, five velocity cuts, both contour comparisons and seated controls in `exports/`.

```sh
godot --headless --path . --xr-mode off --script res://gallery-3/tools/check_figure.gd
godot --path . --xr-mode off --disable-vsync --resolution 1280x800 --script res://gallery-3/tools/check_figure.gd -- --profile --pictures
```

## Reproduce and check

From the repository root, run the following commands with Postgkyl and Godot 4.7 available.

```sh
python3 gallery-3/tools/export_lamps.py --check
python3 gallery-3/tools/export_cfl.py --check
python3 gallery-3/tools/export_relief.py --check
godot --headless --path . --xr-mode off --script res://gallery-3/tools/check_lamps.gd
godot --headless --path . --xr-mode off --script res://tools/check_quest_controls.gd
```

Omit `--check` to regenerate the asset. For pictures of the installed mobile and the seated lectern, run the gallery check on a desktop display without `--headless` and append `-- --pictures`.
