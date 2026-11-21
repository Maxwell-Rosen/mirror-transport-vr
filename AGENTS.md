# Mirror Transport VR

Build a museum where visitors can explore magnetic mirror equilibrium and plasma transport using simulation data from Maxwell Rosen’s PhD thesis. Each exhibit should give visitors a question they can investigate. At the first mirror, for example, changing the mirror ratio lets a visitor see which particles turn back and which escape.

## Where to start

- Use [SETTING.md](SETTING.md) for the museum layout, sightlines and exhibit entrances.
- Use [CONTROLS.md](CONTROLS.md) for movement, interaction and returning to the foyer.
- Use [MUSIC.md](MUSIC.md) for the museum’s musical tone, instrument timbres and phrasing.
- Use [Gallery 1 · The Magnetic Mirror](gallery-1/README.md) for the first exhibit’s layout, particle orbits, sliders, loss-cone plot and reference checks.
- Use [Gallery 2 · Between Bounces](gallery-2/README.md) for the current room plan, sketches and pseudo-orbit averaging trials.
- Use [Gallery 3 · Time Dilation](gallery-3/README.md) for comparisons at a shared instant, linked probes and checks on exported phase-space geometry.
- Use [Designing a visitor trial](PLAN.md#designing-a-visitor-trial) when proposing or reviewing an exhibit. Write down what a visitor can predict, change and observe, and which conditions stay fixed during the comparison.
- Use [GALLERIES.md](GALLERIES.md) for the intended subject of each numbered room.
- Use [PLAN.md](PLAN.md) for the broader exhibit plan, simulation exports and first playable build.

Give each gallery a top-level `gallery-N/` folder matching its entrance number. Keep its notes and plans in that folder, its Godot scenes, scripts and resources in `game/`, and its sketches and gallery-specific tools alongside them. The shared foyer, atrium, controls and menus live in `museum/`.

## Blackboards and lettering

Use matte black faces (`#000000`) with white lettering (`#ffffff`) for all museum boards on desktop and in VR. Apply the shared palette to the title and pause menus, foyer and gallery signs, floor instructions, exhibit controls, plot labels and readouts. Show particle groups and field-line outcomes with coloured markers, curves and legend swatches. [Shared board palette](museum/board_style.gd)

## Simulation fidelity and exhibit labels

Every plot, mesh, animation and probe readout that presents simulation data must faithfully represent the original output. Find the saved Gkeyll runs in `gkeyll-data/<run>/` and keep the raw files local. Use Postgkyl (`import postgkyl as pg`) in Python to load and plot the diagnostics. Use the saved run as the reference for numerical values and the thesis at `~/Documents/PhD-thesis-latex` for their physical interpretation.

- **Keep game assets small.** Put the simulation textures and 3D data the game loads in `simulation-renders/` and commit them to GitHub. Each file must be under 100 MB. Use only the frames and detail the exhibit needs to keep load times short and both builds small. Check the final texture values and mesh coordinates against the source after compression or downsampling. [Simulation asset guide](simulation-renders/README.md)
- **Trace each quantity to its source.** Record the run, source file and diagnostic in the asset manifest, along with the frame and saved time for time-dependent data. Use that run’s geometry and coordinate maps. Keep the conversion script with the project and record transformations such as interpolation, normalization and isosurface thresholds.
- **Label the data where visitors see them.** Name each quantity in plain language and give its symbol and units on axes, legends, colour bars and probe readouts as applicable. Identify the run and the displayed time or slice position when relevant. Keep labels in sync when visitors change the field, frame or probe position.
- **Make visual choices explicit.** State the radial magnification or playback speed whenever the display changes physical scale or time. Mark unsampled regions, including the centre of the 2D cutaway, so visitors can distinguish missing coverage from a physical zero. Label the mirror demo’s animated orbits as idealized trajectories and explain what turning back or escaping means.
- **Verify the displayed result.** Before presenting an exhibit as simulation data, compare representative values and their coordinates with the original diagnostic or an independently generated reference cut from the same run and frame. For example, check the probe at the midplane and a throat. For a reconstructed ion distribution, also check that integrating over velocity reproduces the saved ion density at both locations. Resolve discrepancies before using the asset.

## VR and desktop

The planned stack is Godot 4, GDScript and OpenXR. Share exhibit scenes and data between the standalone Meta Quest 3 experience and the downloadable desktop build. Precompute scientific assets offline and package them with the game.

Deliver the standalone Quest game as `exports/MirrorTransport.apk`. Run `./build_apk` from the repository root. For a requested USB installation, use `./build_apk --install-only` with the verified APK, or `./build_apk --install` to build and deploy an update. Keep the same package ID and signing key across updates. Both the APK and the optional on-headset editor ZIP collect numbered galleries’ `gallery-N/game/` folders automatically. Register new shared runtime folders in `tools/quest_project.py`. [Quest build and installation](README.md#build-and-install-the-quest-3-apk)

Keep labels and controls within view and reach from seated and standing positions. Make each exhibit interaction available with a mouse and keyboard as well as VR controllers. Use the desktop build to check exhibit behaviour. Verify comfort, scale and sustained performance on the headset, with 72 fps as the first playable build’s target.

Exercise a room from the atrium as well as at the controls. Walk and teleport across its threshold, pause during a trial, then leave and return. Verify which clocks should resume and which resources should still be active. Gallery 3 keeps its plinths visible from the hall, loads its detailed figures on entry and discards a pending load if the visitor has already left. Use its boundary check and fixed viewpoints when investigating the cost of a similar installation. [Gallery 3 rendering and checks](gallery-3/README.md#rendering-cost-in-the-museum)
