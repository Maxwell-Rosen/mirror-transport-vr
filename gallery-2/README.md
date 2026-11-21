# Gallery 2 · Between Bounces

**Can you predict how much plasma escapes without computing every bounce?** Cross the first doorway on the right to start the twin pendulums, dye river, whirlpool and bead rings together. The two water sculptures share a clock, so you can compare them during the same hold. [Exhibit plan and sketches](exhibit-2-POA.md)

| Station | What to look for |
| --- | --- |
| Twin pendulums | Follow each bob’s angle on the live graph. The gold bob makes 16 swings while the mint bob makes four. Both settle straight down. The rulers show how far one time step can go at each speed. [Animated swings](sketches/pendulums.svg) · [The mirror analogy](sketches/pendulum-key.svg) |
| Dye river | Watch one bank redden while the sluice holds, then follow the fading patch around the loop. In the straight river, follow a dyed parcel from the tap opposite the sluice mouth to the outlet. The white ring marks the same parcel on the graph. [Cycle and dye equations](model-notes.md#river-with-gradual-exchange) |
| Dye whirlpool | Compare probes A and B on opposite sides of one spinning disk. Dye enters around the central opening, diffuses from disk to disk and drains along the whole rim. During the hold the outlet freezes and both probes keep changing together. [Whirlpool model](model-notes.md#the-dye-whirlpool) |
| Bead rings | Follow the white halo from a closed orbit onto the blue and orange paths to the wall. [Motion study](sketches/transport.mp4) |

## At the bead stand

Start with the dense inner ring. It receives new beads. A collision can carry a bead to either neighbouring ring anywhere around a lap. The two open paths wrap halfway around the outside and turn toward their collectors. Each bead carries equal weight, so the crowding and the three live counts show how the trapped population falls toward the edge.

Watch the halo reach orange in full dynamics. Choose **Next phase**. The solver slows the rings to one third speed and holds the passing beads in place. Feeding and collisions continue on the rings, so their counts can change while the wall counts hold. Choose **Next phase** again and follow the same bead from its held position to Wall 2. **Pause** lets you inspect any frame. **Replay** returns to the opening population. [Mouse, keyboard and Quest controls](../CONTROLS.md#use-an-exhibit)

## The walk from the atrium

The four stands occupy the right side of a 20 × 10 m room. Turn across the aisle from any stand to find its blackboard. The pendulum board relates the bounce period to the collision time. The river board gives the orbit-averaged equation. The whirlpool board plots one lap of both water sculptures at release. The bead board shows when a passing ion can reach a wall. The animations keep playing as you move between stands. Leaving the room or pausing the visit holds their clocks until you return. [The equations on the wall](exhibit-2-POA.md#the-blackboards) · [Dimensions and placement](exhibit-2-POA.md#the-walk-from-the-atrium)

Past the bead stand, a 4.5 m stretch of open floor gives a full view of the end wall. Thesis figure 3.5 traces the closed and open paths that inspired the beads. Figure 3.6 compares full dynamics with pseudo-orbit averaging in that five-equation model. The label below each print gives visitors a feature to follow. [Print sources and conversion](../simulation-renders/gallery-2/thesis-prints.json)

## Reproduce the exhibit

Run these commands from the museum root with Python, NumPy, Matplotlib, Pillow and Godot 4.7. The check exercises the gallery entrance, pendulum and water references, the whirlpool's rim, exhaust and two probes, continuous bead transfers, wall arrivals, playback controls and seated and standing blackboard sightlines. On a desktop display, omit `--headless` and append `-- --pictures` to the Godot command to save room, station and blackboard views. [Model notes](model-notes.md) · [Packaged data and provenance](../simulation-renders/gallery-2/manifest.json)

```sh
python gallery-2/tools/export_gallery.py
python gallery-2/tools/print_blackboards.py
godot --headless --path . --xr-mode off --import
godot --headless --path . --xr-mode off --script res://gallery-2/tools/check_bounces.gd
```
