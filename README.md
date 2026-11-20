# Mirror Transport VR

Walk through the museum for Maxwell Rosen’s PhD thesis on magnetic mirror equilibrium and plasma transport. The first gallery on the left houses **The Magnetic Mirror**. The seven other galleries are under construction.

## Visit the museum

Open `project.godot` with Godot 4.7 and press **F5**. On the laptop, run this command from the project directory to launch directly with the installed Flatpak:

```sh
flatpak run org.godotengine.Godot --path . --xr-mode off
```

Choose **Enter the museum** from the title screen. The desktop visitor is 1.83 m tall with a standing eye height of 1.71 m. Walk with **WASD** and look with the **mouse**. Press **Esc** to pause, see the controls, and adjust or mute the audio. Choose **Resume visit** to continue, or **Reset to title** to start a fresh visit. Hold **Home** to return to the foyer. Releasing the key before the circle fills cancels the return.

On a system with an active OpenXR runtime and Touch controllers, launch with `--xr-mode on`. Walk with the left stick, snap-turn with the right stick, and aim either controller at the floor near a gallery entrance and squeeze the trigger to teleport. Hold left **X** to return to the foyer. Press right **A** for the pause menu and use either trigger to select a menu button. Standalone Quest deployment and headset performance checks are pending.

## Gallery layout

The 16 m wide atrium has four 10 m bays on each side. Numbering runs from the foyer toward the far wall, with odd numbers on the left. Each 4 m entrance faces a gallery extending 16 m outward with a 5 m high ceiling. The [exhibit plan](PLAN.md) describes the remaining galleries.

The shared entry scene is [museum.tscn](museum/museum.tscn). [Museum geometry](museum/museum.gd) is assembled when the scene runs. Dimensions are in metres.

## Try the magnetic mirror

Cross the broad striped threshold at the first gallery on the left. Follow **particle 6 (+171.4 km/s)** with the opening speed spread of **400 km/s**, magnetic moment of **1.00 keV/T**, and midplane potential of **0.0 kV**. Lower the mirror ratio to **1** and watch it cross the right ring. Return to the **31.41** thesis mark and it turns inside the ring. Each particle carries one positive elementary charge.

Select a numbered point on the loss-cone plot. A soft white glow follows the first marker on that line. From a step back and left of the controls, you can watch it bounce and read its parallel and perpendicular kinetic energies on the low lectern. One exhibit second advances 2 µs of particle motion, including gyromotion. Drag a slider to compare the new trajectories at the same launch ages. **Reset** restores all four opening settings, selects particle 6, and restarts the releases. The trial runs throughout the gallery. Walk around either end of the 7.2 m mirror to look through the rings. Returning to the atrium pauses the trial, and crossing the threshold again resumes it. Bright blue field lines carry confined launches and dark blue-grey lines carry escaping launches.

## Simulation data

The original Gkeyll runs live locally in `gkeyll-data/<run>/`. Use Postgkyl (`import postgkyl as pg`) in Python to load and plot their diagnostics. Store the simulation textures and 3D data for desktop and Quest in `simulation-renders/` and commit them to GitHub. Keep each file under 100 MB for quick loading and a small game download. Check that each export reproduces the source values and geometry at the positions visitors can inspect. [Asset guide and Python plotting example](simulation-renders/README.md)

To reproduce the tabletop’s 400-cell reference cut, run `python3 tools/export_mirror_geometry.py` with the specific `data/1x-beams/` snapshot identified by its manifest. The manifest records the input hashes, field and coordinate checks at the midplane, throat and expander ends, and display scales. Run the geometry, ten-bounce and interaction checks with `flatpak run org.godotengine.Godot --headless --path . --xr-mode off --script res://tools/check_mirror.gd`. [Geometry manifest](museum/mirror/reference/manifest.json) · [Reference cut](museum/mirror/reference/field-profile.csv)
