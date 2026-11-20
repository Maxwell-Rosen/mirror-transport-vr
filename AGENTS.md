# Mirror Transport VR

Build a museum where visitors can explore magnetic mirror equilibrium and plasma transport using simulation data from Maxwell Rosen’s PhD thesis. Each exhibit should give visitors a question they can investigate. At the first mirror, for example, changing the mirror ratio lets a visitor see which particles turn back and which escape.

## Where to start

- Use [SETTING.md](SETTING.md) for the museum layout, sightlines and exhibit entrances.
- Use [CONTROLS.md](CONTROLS.md) for movement, interaction and returning to the foyer.
- Use [MUSIC.md](MUSIC.md) for the museum’s musical tone, instrument timbres and phrasing.
- Use [INTRO_MIRROR_INTERACTIVE.md](INTRO_MIRROR_INTERACTIVE.md) for the first exhibit’s particle orbits, sliders and loss-cone plot.
- Use [PLAN.md](PLAN.md) for the broader exhibit plan, simulation exports and first playable build.

## Simulation fidelity and exhibit labels

Every plot, mesh, animation and probe readout that presents simulation data must faithfully represent the original output. Use the saved run as the reference for numerical values and the thesis at `~/Documents/PhD-thesis-latex` for their physical interpretation.

- **Trace each quantity to its source.** Record the run, source file and diagnostic in the asset manifest, along with the frame and saved time for time-dependent data. Use that run’s geometry and coordinate maps. Keep the conversion script with the project and record transformations such as interpolation, normalization and isosurface thresholds.
- **Label the data where visitors see them.** Name each quantity in plain language and give its symbol and units on axes, legends, colour bars and probe readouts as applicable. Identify the run and the displayed time or slice position when relevant. Keep labels in sync when visitors change the field, frame or probe position.
- **Make visual choices explicit.** State the radial magnification or playback speed whenever the display changes physical scale or time. Mark unsampled regions, including the centre of the 2D cutaway, so visitors can distinguish missing coverage from a physical zero. Label the mirror demo’s animated orbits as idealized trajectories and explain what turning back or escaping means.
- **Verify the displayed result.** Before presenting an exhibit as simulation data, compare representative values and their coordinates with the original diagnostic or an independently generated reference cut from the same run and frame. For example, check the probe at the midplane and a throat. For a reconstructed ion distribution, also check that integrating over velocity reproduces the saved ion density at both locations. Resolve discrepancies before using the asset.

## VR and desktop

The planned stack is Godot 4, GDScript and OpenXR. Share exhibit scenes and data between the standalone Meta Quest 3 experience and the downloadable desktop build. Precompute scientific assets offline and package them with the game.

Keep labels and controls within view and reach from seated and standing positions. Make each exhibit interaction available with a mouse and keyboard as well as VR controllers. Use the desktop build to check exhibit behaviour. Verify comfort, scale and sustained performance on the headset, with 72 fps as the first playable build’s target.
