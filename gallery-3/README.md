# Gallery 3 · Time Dilation

**Which lights fall behind the beat?** Enter the second gallery on the left and turn toward the right wall. Ten amber bulbs orbit on a suspended brass mobile. The fixed lamp above the rim pulses every 3.6 exhibit seconds. Choose **Start together** and watch the brass index as the reference lamp pulses again.

The mobile opens on the right mirror throat. Seven of the ten bulbs return together. The outer three glow more faintly and take longer to come around. **Use reference beat** puts all ten clocks at full rate for comparison. **View midplane** moves the same ten velocity samples to the first cell on the positive side of the midplane. **Inspect next ring** moves the white hoop to another lamp and updates the lectern. Point and click or use the right Quest trigger. On desktop, Tab and Shift+Tab move focus at the lectern and Enter activates the selected button.

**Where does the time step form a plateau?** Continue along the right wall from the clock mobile to the mask sculpture and then to a second plinth. Its two reliefs show the CFL rate and the local step permitted by that rate. The panel opens with the saved surfaces and the reconstructed uncapped ridges visible together. [Visitor questions and source calculations](local-timestep.md)

## What the lamps measure

Each ring is a clock representing one phase-space cell in the `1x-beams` ion run, at frame 75 and saved time 0.500150 s. The equal ring spacing orders ten increasing positive parallel velocities at magnetic moment μ = 0.04437 keV/T. The lectern gives the selected velocity and axial cell centre. The radii and circular motion are sculptural.

- **Timing.** The cellwise `fdot_multiplier` gives the dimensionless local time factor β. One turn and one smooth pulse take 3.6/β exhibit seconds. In the near-midplane cut at Z = +0.014865 m every sampled β is 1. At the right throat at Z = +0.979129 m the outermost lamp has β = 0.186021 and a period of 19.35 exhibit seconds. The animation compares rates at a single saved instant.
- **Brightness.** The peak filament intensity shows the magnitude of the cell-average ion distribution |fᵢ| relative to the largest sampled value on the current cut. A logarithmic mapping covers 24 decades and retains a 15% minimum peak so the faintest lamp stays visible. This normalization compares velocities within each cut. Gkeyll chooses which cells to slow from their local numerical time-step limit.

The exporter reads the original DG coefficients with Postgkyl, evaluates the run’s coordinate maps, removes the saved Jacobians from the ion distribution and checks its full velocity integral against the saved ion density. The mobile loads twenty cell samples. [Lamp manifest](../simulation-renders/gallery-3/manifest.json) · [Conversion and checks](tools/export_lamps.py)

## Phase-space sculpture

The plinth projects from the right wall. Its sloping front edge has two selectable, ten-band colour bars. The warm bar gives the minimum ion distribution as a percentage of the peak at each axial position. The blue bar gives the upper threshold of the dimensionless time factor β. Select a colour with the mouse or right trigger to isolate the corresponding shell. Select it again to restore that family. The companion print at the far wall has the same selectors. Tab, Shift+Tab and Enter operate the bars at either location. A reading board across the aisle explains the mirror force near a throat.

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

## CFL rate and time-step sculpture

The two stepped reliefs display every axial and magnetic-moment cell at v∥ = +191.195 km/s in frame 75 of `1x-beams`. Axial position runs across each relief. Magnetic moment increases from the rear to the aisle. The left relief gives the saved CFL rate ω in 10⁹ s⁻¹. The right gives its reciprocal, the permitted local step τ in ns at unit Courant factor. Both heights use 0.32 exhibit metres per decade. The native grid has 400 × 32 cells in this cut.

The 4,031 violet cells have saved β < 1. All lie at the same rate cap of 1.902715 × 10⁹ s⁻¹ and time floor of 0.525565 ns. The amber ridges follow the highest magnetic-moment bin, μ = 67.7667 keV/T, and show the rate and step reconstructed without the cap at the same instant. The white points open on the outer left throat slope. There the uncapped step is 0.0525565 ns. Choose **Left crest** or **Midplane** to follow that cut. At the midplane, both readings give 30.1912 ns. [Relief geometry and source manifest](../simulation-renders/gallery-3/cfl-relief.json) · [Relief exporter](tools/export_relief.py)

**Phase-space contours** on the second plinth opens on the cell selected on the clock mobile. Choose **Uncapped estimate** or **Saved rate cap**. The selected button stays underlined and the probe stays on the same cell. The six swatches enclose cells at or below 0.1, 0.25, 0.5, 1, 5 or 20 ns. At 0.1 ns, the readout changes from 38,037 cells to zero. **Time floor** outlines the saved β < 1 mask. **Ion population** shows the 10% distribution contour at each Z. **Rate & step reliefs** brings the paired surfaces back. The first sculpture keeps its own colour-bar selections throughout.

The saved rate is ωₛ. The uncapped rate is ωₛ/β. The two local step limits in ns are 10⁹β/ωₛ and 10⁹/ωₛ. The exporters check the cap across all 819,200 phase cells, the mapped coordinates and three reference probes. The six time-contour meshes occupy 1.55 MB. [CFL contours and probe manifest](../simulation-renders/gallery-3/local-cfl.json) · [Contour exporter](tools/export_cfl.py)

### Rendering cost in the museum

Gallery 3 requests the installation in the background when the visitor enters. Crossing into the atrium hides and releases the reliefs, phase-space models, print, controls and plinths. A load that finishes after the visitor has left is discarded. The sculpture shader opens the display at the limits of the sampled domain and brightens a 3.75 mm band on the positive-velocity side of the zero interface. The source meshes retain the complete closed cell unions.

With both sculptures mounted, the installation added about **12.3 MiB of graphics memory** on a Radeon 760M (9.1 MiB of buffers and 3.2 MiB of textures). The tracked CPU heap grew by about 3.8 MiB. In a 1280 × 800 desktop test, the gallery overview took 6.9 ms of GPU time with the installation and 4.4 ms after unloading it. Exiting the room released the graphics allocations. These are single-view desktop measurements. The Quest build uses an ASTC wall print.

Run the room-boundary test from the project root. Add `-- --profile --pictures` on a desktop display to measure the same viewpoints with and without the installation and capture the right wall, both sculptures, colour bars and seated controls in `exports/`.

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
