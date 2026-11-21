# Gallery 3 · Time Dilation

**Does a slower clock change the final glow?** At the first station on the right, forty fixed glass lamps trace each of ten rings. **Send a pulse** starts a bright crest at the left notch on every ring. Follow the outer rim. After 3.6 exhibit seconds the seven inner crests have made one lap at the right throat. The outermost has covered only 19% of a lap.

Choose **Turn dilation off** while the wave is traveling. This shows where the same pulse would be at the same elapsed time if all ten clocks ran at full rate. Each crest fades over four laps on its own clock. Half its initial contrast remains after two laps. The full-rate rings settle in 14.4 exhibit seconds. The outer throat ring takes 77.4. The ten lamps on the lectern show the resting brightness throughout.

**See steady state** lets you examine that final pattern immediately. Switch dilation on and off there, then choose **Return to wave** to pick up at the instant you left. **View midplane** keeps the same ten velocity samples and elapsed time. **Next ring** moves the white inspection hoop at the left notch and the underline on the reference strip. Mouse, right Quest trigger, and desktop Tab, Shift+Tab and Enter all operate the lectern.

**How long is one tick inside a cell?** The third station is a tabletop relief. Move from the throat slope to the midplane and compare how far each cell advances during one shared grid step. The relief stands 3.7 m beyond the mask plinth. Nine metres farther along the same wall, the final station compares two volumes of cells at a chosen time limit. [Visitor questions and source calculations](local-timestep.md)

## What the lamps measure

The beam-source ion run `1x-beams` supplies twenty samples from frame 75 at saved time 0.500150 s. Each ring stands for one phase-space cell. Radius orders ten increasing positive parallel velocities at magnetic moment μ = 0.04437 keV/T. Angle locates a lamp on the sculpture. The lectern identifies the velocity and axial position of the selected cell.

- **Peak light measures cell content.** Integrate the ion distribution over each mapped phase-space cell, take the magnitude |Nᵢ|, and divide by the largest of the ten sampled magnitudes on that cut. The mapped velocity bins have different widths. Integrating accounts for how many ions each entire cell represents. The peak lamp drive maps this ratio logarithmically over 24 decades, with a 22% visibility floor. The outer throat cell has 8.55 × 10⁻²³ of the inner cell’s content.
- **Crest travel measures the clock rate.** The saved dimensionless multiplier β sets the local lap time to 3.6/β exhibit seconds. At Z = +0.979129 m, the outer three rings have β of 0.763, 0.484 and 0.186. Near the midplane at Z = +0.014865 m, all ten have β = 1. Gkeyll selects the slowed cells from their numerical time-step limits.
- **The wave illustrates a disturbance.** The model crest and opposite trough ride on a steady drive of half the ring’s peak. Their angular mean stays at that level as they travel and fade. Both propagation and damping use local elapsed time βt. The saved frame supplies the target brightness and clock rates. The wave shape and four-lap damping time belong to the exhibit.

Gkeyll multiplies a cell’s complete update, including transport, sources and collisions, by a positive β. At a stationary solution those terms sum to zero in each cell. Scaling their sum preserves that solution. Transient histories can differ, and the saved frame is a finite-time profile. The thesis measures the differences between the two beam runs at their recorded endpoints. [Time-dilation method](<../../PhD-thesis-latex/Chapter Gkeyll Foundations/tex-files/time-dilation.tex>) · [Beam-run comparison](<../../PhD-thesis-latex/Chapter Gkeyll POA simulations/tex-files/without-time-dialtion.tex>)

The Postgkyl exporter checks the twenty cell integrals directly against the saved DG coefficients. Integrating over all velocity cells also recovers the independent ion density diagnostic at the throat and midplane. The manifest records the files, coordinate maps, light transfer function and illustrative wave. [Lamp manifest](../simulation-renders/gallery-3/manifest.json) · [Conversion and checks](tools/export_lamps.py)

## Phase-space sculpture

The plinth projects from the right wall. Its sloping front edge has two selectable, ten-band colour bars. Each warm shell encloses cells whose distribution magnitude |fᵢ| reaches the selected percentage of the largest |fᵢ| over velocity at that same Z. The blue bar gives the upper threshold of the dimensionless time factor β. Select a colour with the mouse or right trigger to isolate the corresponding shell. Select it again to restore that family. The companion print faces the mask sculpture across the aisle and has the same selectors. Tab, Shift+Tab and Enter operate the bars at either location. A nearby reading board explains the mirror force near a throat.

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

## The time-step relief

Stand in front of the table. Left to right is position along the mirror, $Z$ (m). Front to back is parallel velocity, $v_\parallel$ (10⁶ m/s), with negative velocities nearest you. **Height is the largest step this cell permits on the shared grid clock**, $\tau$ (ns), at unit ion Courant factor. Each division up the ruler multiplies the time by ten. The controls on the front edge select five native magnetic moments $\mu$ from highest to lowest, 67.767, 50.199, 31.900, 16.096 and 0.044 keV/T.

At the highest moment, choose **Throat slope** and switch **Dilation off**. At the white probe the undilated local limit is 0.0526 ns. The lowest point in the entire grid sets one tick for every cell. Switch **Dilation on**. The valley rises into a violet shelf at 0.5256 ns. The shared tick is now ten times longer. Watch the two bars on their common time scale. The probed cell advances through 0.100 times the grid tick, still 0.0526 ns, its full stable local interval. At **Midplane** the cell can tolerate 30.1912 ns, so it advances through the entire shared tick, 0.5256 ns.

Change $\mu$ while the probe stays on the throat slope. At the lowest moment that cell can tolerate 3.1010 ns and runs at the grid clock rate. **Slice minimum** finds the most restrictive undilated cell of the selected slice, which changes position and velocity as $\mu$ decreases. The grid tick uses the minimum over all 819,200 cells in either view.

The relief joins native cell centres linearly in log time. It extends the outermost samples to the measured domain faces. Triangle edges split at the floor so the violet shelves are flat and meet the unaffected terrain continuously. One axial metre spans 0.80 exhibit m, 10⁶ m/s spans 0.084 exhibit m in depth, and a decade in time spans 0.28 exhibit m vertically. At all 128,000 displayed centres the exporter checks both serialized heights and positions against independent Postgkyl reads of the rate, multiplier and coordinate maps. [Relief manifest and probes](../simulation-renders/gallery-3/cfl-relief.json) · [Offline conversion and verification](tools/export_relief.py)

## Which cells need a short step?

The next plinth has two equal boxes. Each shows the entire sampled position and velocity domain. Choose one upper limit from 0.1, 0.25, 0.5, 1, 5 and 20 ns. A blue shell encloses the qualifying cells. The left box uses the uncapped estimate reconstructed from the saved multiplier β. The right uses the saved capped rate from the same instant. Both show counts and identify whether their common probe qualifies. The open frame keeps the domain visible even for an empty selection.

At 0.1 ns, 38,037 cells qualify on the left and zero on the right. At 1 ns both shapes coincide because the cap only raises steps below 0.526 ns. **Time floor** outlines the saved β < 1 region in violet and **10% ion core** adds the population reference in gold. **Use lamp cell** follows the selected ring and slice at the entrance station. The magnetic-moment slice, contour threshold and mask colour bars can be changed independently. [Local time contours and probe manifest](../simulation-renders/gallery-3/local-cfl.json) · [Contour exporter](tools/export_cfl.py)

## Two beam runs on the far wall

Thesis figure 5.23 compares the share of velocity cells slowed near each throat with the ion content they carry. Figure 5.25 follows the density, flow and temperature profiles after five cycles with and without full-dynamics time dilation. The 38 m room opens into a full-width reading area beyond the comparison console. Both end-wall prints reproduce the original PDF artwork at its published aspect ratio, with a caption at the lower right. The reading board opposite the two-box plinth connects its adjustable contour to the saved time floor. [Print sources and conversion](../simulation-renders/gallery-3/thesis-prints.json) · [Print exporter](../tools/print_thesis_figures.py)

### Rendering cost in the museum

The three plinths are visible from the atrium. Entering Gallery 3 starts the lamp clock and requests the scientific figures in the background. Crossing back into the atrium pauses the clock and releases the relief, both contour volumes, the mask, its companion print and their controls. Visitors can walk through the installations. A load that finishes after the visitor has left is discarded. The mask sculpture shader opens the display at the limits of the sampled domain and brightens a 3.75 mm band on the positive-velocity side of the zero interface. The trace uses pixel coverage and the nested translucent shells use a fixed outer-to-inner order within each family. The source meshes retain the complete closed cell unions.

The five relief slices share one 8.0 MB glTF. At any instant Godot draws the selected slice’s fixed terrain and either the undilated valleys or their flat shelves. All geometry is precomputed from the saved frame. The clock bars, white probe and labels update when a control changes.

Run the room-boundary test from the project root. Add `-- --profile --pictures` on a desktop display to measure the same viewpoints with and without the installation and capture the right wall, colour bars, the time-step relief with dilation on and off, the lowest magnetic moment, both contour comparisons and seated controls in `exports/`.

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

Omit `--check` to regenerate the asset. For pictures of the traveling wave, its steady state and the seated lectern, run the gallery check on a desktop display without `--headless` and append `-- --pictures`.
