# Mirror Transport VR

Walk through the museum for Maxwell Rosen’s PhD thesis on magnetic mirror equilibrium and plasma transport. The first gallery on the left houses **The Magnetic Mirror**. The seven other galleries are under construction.

## Visit the museum

Open `project.godot` with Godot 4.7 and press **F5**. On the laptop, run this command from the project directory to launch directly with the installed Flatpak:

```sh
flatpak run org.godotengine.Godot --path . --xr-mode off
```

The desktop visitor is 1.83 m tall with a standing eye height of 1.71 m. Walk with **WASD** and look with the **mouse**. Press **Esc** to release the pointer and click the window to resume. Hold **Home** to return to the foyer. Releasing the key before the circle fills cancels the return.

On a system with an active OpenXR runtime and Touch controllers, launch with `--xr-mode on`. Walk with the left stick, snap-turn with the right stick, and aim either controller at the floor near a gallery entrance and squeeze the trigger to teleport. Hold left **X** to return. Standalone Quest deployment and headset performance checks are pending.

## Gallery layout

The 16 m wide atrium has four 10 m bays on each side. Numbering runs from the foyer toward the far wall, with odd numbers on the left. Each 4 m entrance faces a gallery extending 16 m outward with a 5 m high ceiling. The [exhibit plan](PLAN.md) describes the remaining galleries.

The shared entry scene is [museum.tscn](museum/museum.tscn). [Museum geometry](museum/museum.gd) is assembled when the scene runs. Dimensions are in metres.

## Try the magnetic mirror

Cross the broad striped threshold at the first gallery on the left. Follow ion **6 (+450 km/s)** and leave the speed, magnetic moment and potential at their opening settings. Aim at **15** on the mirror-ratio track, hold the left mouse button or either trigger, then release. Watch the ion cross the right ring, follow the expander to its tip, and reappear at the midplane. Set the ratio to **20** and it turns inside the ring.

Select any numbered point on the loss-cone plot to follow its ion. **Reset** relaunches the ions with the current settings. The trial runs throughout the gallery. Walk around either end of the 7.2 m mirror to look through the rings. Returning to the atrium pauses the trial, and crossing the threshold again resumes it. Bright blue field lines carry confined launches and dark blue-grey lines carry escaping launches.

The [geometry manifest](museum/mirror/reference/manifest.json) records the saved field and coordinate maps, comparisons at the midplane, throat, and expander ends, and the display scales. Rebuild the [400-cell reference cut](museum/mirror/reference/field-profile.csv) with `python3 tools/export_mirror_geometry.py` and Postgkyl using the raw files in `data/1x-beams/`. Run the geometry, ten-bounce and interaction checks with `flatpak run org.godotengine.Godot --headless --path . --xr-mode off --script res://tools/check_mirror.gd`.
