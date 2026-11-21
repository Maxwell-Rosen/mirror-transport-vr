# Gallery 3 · Time Dilation

**Which lights fall behind the beat?** Enter the second gallery on the left. Ten amber bulbs orbit on a suspended brass mobile. The fixed lamp above the rim pulses every 3.6 exhibit seconds. Choose **Start together** and watch the brass index as the reference lamp pulses again.

The mobile opens on the right mirror throat. Seven of the ten bulbs return together. The outer three glow more faintly and take longer to come around. **Use reference beat** puts all ten clocks at full rate for comparison. **View midplane** moves the same ten velocity samples to the first cell on the positive side of the midplane. **Inspect next ring** moves the white hoop to another lamp and updates the lectern. Point and click or use the right Quest trigger. On desktop, Tab and Shift+Tab move focus at the lectern and Enter activates the selected button.

## What the lamps measure

Each ring is a clock representing one phase-space cell in the `1x-beams` ion run, at frame 75 and saved time 0.500150 s. The equal ring spacing orders ten increasing positive parallel velocities at magnetic moment μ = 0.04437 keV/T. The lectern gives the selected velocity and axial cell centre. The radii and circular motion are sculptural.

- **Timing.** The cellwise `fdot_multiplier` gives the dimensionless local time factor β. One turn and one smooth pulse take 3.6/β exhibit seconds. In the near-midplane cut at Z = +0.014865 m every sampled β is 1. At the right throat at Z = +0.979129 m the outermost lamp has β = 0.186021 and a period of 19.35 exhibit seconds. The animation compares rates at a single saved instant.
- **Brightness.** The peak filament intensity shows the magnitude of the cell-average ion distribution |fᵢ| relative to the largest sampled value on the current cut. A logarithmic mapping covers 24 decades and retains a 15% minimum peak so the faintest lamp stays visible. This normalization compares velocities within each cut. Gkeyll chooses which cells to slow from their local numerical time-step limit.

The exporter reads the original DG coefficients with Postgkyl, evaluates the run’s coordinate maps, removes the saved Jacobians from the ion distribution and checks its full velocity integral against the saved ion density. The mobile loads twenty cell samples. [Lamp manifest](../simulation-renders/gallery-3/manifest.json) · [Conversion and checks](tools/export_lamps.py)

## Phase-space sculpture

Walk past the mobile to the plinth and blackboard at the back of Gallery 3. Both open with all twenty contours. Select a coloured swatch on the print with the mouse or right trigger to isolate that level on the sculpture. Select it again to show its family. At the board, Tab and Shift+Tab move through the swatches and Enter selects one. The two families can be explored independently.

**How much of the ion distribution sits in cells whose update Gkeyll slows?** In frame 75, the local time factor β is below one in 366,226 of 819,200 cells (44.7%). These cells carry 0.00555% of the total absolute ion content. The largest distribution magnitude in a slowed cell is 6.52% of the velocity-space peak at the same axial position. The velocity slice at Z = −0.866 m shows where the slowed fraction of local absolute ion content is largest (5.86%). [Full-size sketch](sketches/time-dilation.png)

Both signs of parallel velocity come from the saved run, spanning −10.09 to +10.09 million m/s. The ten **Inferno** surfaces enclose cells at or above successive distribution thresholds, from 10⁻⁵ to 0.316 of the peak at each Z, in half-decade steps. The ten **blue** surfaces enclose cells with β below 0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 and 1. Lighter blues mark stronger slowing. The contour lines inside the 3D sketch trace the faces of the first positive-velocity cells at the zero-velocity interface. In the enlarged velocity slice, dots mark the slowed side of the β = 1 boundary.

Run the Python figure from the repository root. Drag the 3D axes to rotate. Click a colour swatch to isolate that level within its family, then click it again to restore the family. The figure uses Postgkyl, NumPy, SciPy and Matplotlib. Rebuilding the binary glTF also uses Trimesh (tested with 5.2.1).

```sh
python3 gallery-3/gkeyll-data-sculpture.py --show
python3 gallery-3/gkeyll-data-sculpture.py --figure gallery-3/sketches/time-dilation.png --glb
```

To try a smaller selection, run `python3 gallery-3/gkeyll-data-sculpture.py --f-levels .001 .01 .1 --beta-levels .25 .5 1 --show`. Passing a path after `--glb` saves a separate model, matching wall print and manifest. The manifest records the swatch bounds used by the in-game controls.

In Godot, drag `res://simulation-renders/gallery-3/time-dilation.glb` into a 3D scene. Its `IonDistribution` and `TimeFactor` groups each contain one mesh per threshold. The unlit materials carry the same colormaps as the figure. The model uses 0.60 exhibit m per metre of Z along +X, 0.070 exhibit m per 10⁶ m/s of parallel velocity along −Z, and 0.018 exhibit m per keV/T of magnetic moment along +Y. [Godot’s glTF import guide](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)

The meshes follow the exterior faces of the selected cells. Joining coplanar faces and sharing vertices packs all twenty levels into a 6.8 MB model. Godot 4.7.2 imported it as a 2.12 MB scene with 344,368 triangles across all levels. The sketch omits the flat caps at the limits of the sampled domain. The GLB includes them so each level encloses its full region. The exporter checks the signed velocity integral against the saved ion density in all 400 axial cells, then reloads the GLB and compares its triangle coordinates and enclosed volumes with the mapped grid. [Mesh](../simulation-renders/gallery-3/time-dilation.glb) · [Source files, thresholds and checks](../simulation-renders/gallery-3/time-dilation.json) · [Python figure](gkeyll-data-sculpture.py)

### Rendering cost in the museum

Gallery 3 requests the installation in the background when the visitor enters. Crossing into the atrium hides and releases the sculpture, print, marks and plinth. A load that finishes after the visitor has left is discarded. The sculpture shader opens the display at the limits of the sampled domain and brightens a 3 mm band on the positive-velocity side of the zero interface. The source meshes retain the complete closed cell unions.

With all levels visible, the complete installation added **7.69 MiB of graphics memory** on a Radeon 760M (4.52 MiB of buffers and 3.17 MiB of mipmapped print texture). Godot’s tracked CPU heap grew by about **0.9 MiB**. At 1280 × 800, the median GPU time increased by **0.23–0.30 ms** from the gallery overview and **1.60 ms** close to the plinth. These are desktop, single-view measurements. The more of the screen the translucent surfaces cover, the more pixels the GPU blends. The graphics allocations returned to baseline after exit. The Quest build uses an ASTC wall texture. The largest colour-channel difference at the twenty printed swatch centres was zero on ASTC and one 8-bit step on desktop BPTC.

Run the room-boundary test from the project root. Add `-- --profile --pictures` on a desktop display to measure the same viewpoints with and without the installation and write the in-game screenshot to `exports/Gallery3-contours.png`.

```sh
godot --headless --path . --xr-mode off --script res://gallery-3/tools/check_figure.gd
godot --path . --xr-mode off --disable-vsync --resolution 1280x800 --script res://gallery-3/tools/check_figure.gd -- --profile --pictures
```

## Reproduce and check

From the repository root, run the following commands with Postgkyl and Godot 4.7 available.

```sh
python3 gallery-3/tools/export_lamps.py --check
godot --headless --path . --xr-mode off --script res://gallery-3/tools/check_lamps.gd
godot --headless --path . --xr-mode off --script res://tools/check_quest_controls.gd
```

Omit `--check` to regenerate the asset. For pictures of the installed mobile and the seated lectern, run the gallery check on a desktop display without `--headless` and append `-- --pictures`.
