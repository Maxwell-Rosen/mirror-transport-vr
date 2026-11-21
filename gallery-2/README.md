# Gallery 2 · Between Bounces

**Can you predict how much plasma escapes without computing every bounce?** Enter the first doorway on the right. The twin pendulums, dye river and bead rings each have a clock that starts when you approach. The rings let you switch between the two phases of pseudo-orbit averaging. [Exhibit plan and sketches](exhibit-2-POA.md)

| Station | What to look for |
| --- | --- |
| Twin pendulums | Follow each bob’s angle on the live graph. The gold bob makes 16 swings while the mint bob makes four. Both settle straight down. The rulers show how far one time step can go at each speed. [Animated swings](sketches/pendulums.svg) · [The mirror analogy](sketches/pendulum-key.svg) |
| Dye river | Watch one bank redden while the sluice holds, then follow the fading patch around the loop. Track a parcel from tap to outlet in the separate straight river and on its live graph. [Cycle and dye equations](model-notes.md#river-with-gradual-exchange) |
| Bead rings | Follow the white halo from a closed orbit onto the blue and orange paths to the wall. [Motion study](sketches/transport.mp4) |

## At the bead stand

Start with the dense inner ring. It receives new beads. A collision can carry a bead to either neighbouring ring anywhere around a lap. The two open paths wrap halfway around the outside and turn toward their collectors. Each bead carries equal weight, so the crowding and the three live counts show how the trapped population falls toward the edge.

Watch the halo reach orange in full dynamics. Choose **Next phase**. The solver slows the rings to one third speed and holds the passing beads in place. Feeding and collisions continue on the rings, so their counts can change while the wall counts hold. Choose **Next phase** again and follow the same bead from its held position to Wall 2. **Pause** lets you inspect any frame. **Replay** returns to the opening population. [Mouse, keyboard and Quest controls](../CONTROLS.md#use-an-exhibit)

## The walk from the atrium

The three stands occupy the right side of a 16 × 10 m room. Each clock holds its place when you walk away or pause the visit. [Scale drawing](sketches/room.svg) · [Dimensions and placement](exhibit-2-POA.md#the-walk-from-the-atrium)

## Reproduce the exhibit

Run these commands from the museum root with Python, NumPy, Pillow and Godot 4.7. The check exercises the gallery entrance, pendulum and river references, continuous bead transfers, the radial gradient, the passing hold, wall arrivals and the playback controls. On a desktop display, omit `--headless` and append `-- --pictures` to the Godot command to save room and station views, including a seated view of the rings. [Model notes](model-notes.md) · [Packaged data and provenance](../simulation-renders/gallery-2/manifest.json)

```sh
python gallery-2/tools/export_gallery.py
godot --headless --path . --xr-mode off --script res://gallery-2/tools/check_bounces.gd
```
