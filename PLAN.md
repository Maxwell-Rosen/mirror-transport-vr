# Walking through a magnetic mirror

## The first minute

From the title screen, visitors enter on the level floor of the entry foyer, facing an open doorway. A welcome panel stands on one side and a controls graphic for the current device on the other, both readable from a chair. Beyond them, octagonal columns frame the view down the low-poly museum’s skylit atrium to a spring fountain. Eight numbered galleries open off the hall, four on each side. Try a 16 m wide atrium with 4 m openings and at least 3 m of clear passage on either side of the fountain. Set benches and planters back from the approaches. Mark unfinished galleries with waist-high yellow-and-black tape across the doorway and an **Under construction** sign. [Museum layout and sightlines](SETTING.md)

The first entrance on the left reads **1 · The Magnetic Mirror**. From the hall, visitors see two copper-coloured throat rings in profile with blue field lines passing through them. The pedestal faces the entrance and asks **“Which particles turn back, and which escape through the ends?”** [Gallery 1 layout and opening trial](gallery-1/README.md)

## Music and water

The first Promenade from Modest Mussorgsky’s *Pictures at an Exhibition* plays at the same level in the foyer, atrium and every gallery. Walking or teleporting preserves the phrase in progress. A low bowed B-flat swells for two beats before the clarinet enters with G–F. At a steady 40 bpm, the harp places quiet chord tones on beats one and four. The piano enters around 20 seconds. At 1:09 the harp takes up the opening theme in D-flat and follows it with the A-flat verse. The clarinet plays a quiet line beneath the harp over the bowed cellos, then takes the melody back at 1:51. The final B-flat rings out before the opening bow returns. [Chamber recording](museum/audio/promenade.ogg) · [Piano score](https://www.ibiblio.org/mutopia/ftp/MussorgskyM/promenade/promenade-a4.pdf)

The soft clarinet, bowed cellos and concert harp use recordings from the Versilian Studios Chamber Orchestra 2 Community Edition (CC0). Within each clarinet phrase, the connected notes draw on the sustained portion of the same recordings. The piano uses the soft v4 strikes from Alexander Holm’s Salamander Grand Piano v3 (CC BY 3.0). [Clarinet, cello and harp recordings](https://github.com/sgossner/VSCO-2-CE/tree/440300901dfe9275fd84e0b7763af1f8443ae62e) · [Salamander recordings](https://github.com/sfzinstruments/SalamanderGrandPiano/tree/3382bf9496bba2486f5ab0de55a264d1dfc38404) · [Piano sample license](https://creativecommons.org/licenses/by/3.0/)

Edit the notes and phrase dynamics in the SoundCraft session. Run `python3 audio-source/render_promenade.py` to bounce the session and carry the room decay across the **Loop end** marker. [Session](audio-source/Promenade.scraft) · [Loop renderer](audio-source/render_promenade.py)

The fountain has its own quiet sound source at the basin. Visitors hear the running water beneath the music as they approach and can locate it by turning their head. Its sound carries up to 16.5 m through the atrium. Inside each gallery it falls a further 8 dB over the first 4 m past the doorway. Check the balance on desktop speakers and Quest headphones from the foyer, beside the fountain, inside a gallery and at the far end of the atrium.

## Moving and using exhibits

- **Quest 3.** Turn your head to look, lean or take physical steps. Tilt the right thumbstick in any direction to show the controller’s arc. Aim at clear floor within 4 m and release the stick to teleport to the circle. Pull the right index trigger to select or drag. Make every exhibit reachable from a chair with the right controller.
- **Desktop.** Walk with WASD or the arrow keys and hold Shift to sprint. Look and aim with the mouse and left-click to interact.
- **Sliders and probes.** Hold the trigger or left mouse button, drag along the track, then release.
- **Reset the visit.** Open the pause menu with right **A** on Quest or **Esc** on desktop. Choose **Reset to title** to start a fresh visit.

Keep the floor and horizon level. For the taller data displays, plan optional flight with ascent, descent and a control to return to the floor beneath the visitor. [Movement and interaction bindings](CONTROLS.md)

## Designing a visitor trial

Start a gallery README with a short visit someone can actually try. Give the visitor a starting view, something specific to follow, one change to make and an outcome they can recognize. At the mirror, ask them to predict whether particle 6 will cross the right throat. Change the mirror ratio from 1 to 31.41 with the same launch settings. Crossing the ring in the first trial and turning before it in the second give the visitor a way to answer the question by looking. [Mirror trial](gallery-1/README.md)

Keep the subject recognizable when the visitor turns from the sculpture to a plot. In the dye river a white ring picks out the same parcel on the graph. At the bead stand the halo lets the visitor follow one bead into a passing orbit, see where it waits during the hold, and follow it to a collector after release. When a brief event carries the explanation, give visitors a way to revisit it. **Next phase** takes them to the event and **Pause** gives them time to inspect it. [Between Bounces](gallery-2/README.md)

Decide what a comparison holds fixed. In the lamp rings, switching dilation preserves the selected sample and elapsed time. A visitor can attribute the difference in crest position to the clock rate. Explain each visible effect where it appears, especially when the sculpture combines evidence and analogy. Here the saved frame supplies the clock multiplier and cell content. The travelling crest and its damping belong to the teaching model. A caption that calls the whole animation “frame 75” would imply a measured time history. [What the lamps measure](gallery-3/README.md#what-the-lamps-measure)

Try the proposed visit without coaching. Ask the visitor to show what changed and point to the evidence. If they can work the control but lose the particle, inspect the selection marker and the view from the control. If they can follow the motion but misread its meaning, revisit the label or the comparison. Record the repeatable trial beside the gallery’s numerical reference checks so later changes can be tested against both. [Gallery 1 visitor and reference checks](gallery-1/README.md#checks-for-the-first-build)

## Galleries

| Gallery and visitor question | Interaction and data |
| --- | --- |
| **1 · The Magnetic Mirror.** Which particles turn back, and which escape through the ends? | Vary the mirror ratio at the pedestal and follow the selected ion on the loss-cone and energy plots. [Gallery 1 model, controls and checks](gallery-1/README.md) |
| **2 · Between Bounces.** Can you predict how much plasma escapes without computing every bounce? | Compare the dye river with the whirlpool’s orbit-distributed feed and loss. At the bead rings, watch collisions spread beads toward two open paths and step between phases to see when beads reach the walls. [Exhibit plan and sketches](gallery-2/exhibit-2-POA.md) |
| **3 · Time Dilation.** Does a slower clock change the final glow? | Send a wave around ten fixed rings, switch between full and saved clock rates, and compare the result with the steady ion-content profile. [Wave rings, controls and reference checks](gallery-3/README.md) |
| **4 · Which ions can reach a wall?** | Pick a velocity cell and compare its eight pointwise wall-access tests with its single saved flag. Find electrostatic trapping near the midplane. Compare physical and computational velocity coordinates over the same distribution, then test the 400-cell axial grid. [Playable trial and simulation checks](gallery-4/README.md) |
| **6 · The tandem mirror.** Can an end plug turn a field-aligned ion? | Follow a selected slice on the four-coil sculpture, compare ion and source distributions, then switch the potential for a 1 keV test ion. Read the whole-tube confinement estimate from the saved inventory and wall flux. [Gallery 6 trial and data](gallery-6/README.md) |
| **Single-field-line distribution.** How does the ion velocity distribution change between the midplane and a throat? | Pair the full five-metre `1x-beams` geometry with a 2–3 m tall sculpture of $f(Z,v_\parallel,\mu)$ at frame 75. Slide a hoop along the rail to a saved axial position. Show the field there and a velocity-space heatmap on the exposed face of one opaque isosurface. Keep the slice visible from outside and put the threshold and units on the plinth. |
| **2D plasma cutaway.** How do density and electrostatic potential vary across the mirror and over time? | Map the four radial by 400 axial cells of `2x-boltz` to physical coordinates and revolve the section under axisymmetry. Leave a wedge open to expose the four cell bands. Switch quantities and step through frames 0, 45 and 75 with a fixed colour scale per quantity. Label the unsampled centre. Show the 10 cm outer midplane radius at a labelled 10× radial magnification and offer a true-scale view. |
| **The last 90 microseconds.** Where does the ion density continue to change late in the run? | Walk along a wall of `1x-beams` density versus axial position and elapsed time using frames 45–75 and their saved timestamps. Point at a position to read the signed density difference, frame 75 minus frame 45. Use a diverging scale centred on zero and pair it with the thesis endpoint profiles. |
| **Future tandem probe.** How does the distribution vary between the four featured cuts? | Extend Gallery 6’s slice pointer into a movable hoop along the 11 m field line, using the same geometry and velocity maps. |

For the two-run preview, align the `1x-beams` field trace and the `2x-boltz` frame-75 density cut by physical axial position. Sample the field at its own cell centres and draw the cell-average density using the 2D run’s corner nodes. Label each run on its panel.

## Platform and simulation data

Share the Godot scenes, GDScript and exhibit data between the downloadable desktop build and the standalone Quest 3 APK. Develop on the Kubuntu laptop, with the Bazzite RTX 3090 desktop available for desktop testing. Run `./build_apk` on the laptop to export with Godot 4.7.2, its matching Android template and Meta support from OpenXR Vendors 5.2.0. [Project build and installation instructions](README.md#build-and-install-the-quest-3-apk) · [Godot Android XR deployment](https://docs.godotengine.org/en/stable/tutorials/xr/deploying_to_android.html)

Read the original simulation output from `gkeyll-data/<run>/` in the project directory. Keep these raw runs local. The Gkeyll input decks are in `/home/maxwell-rosen/Documents/gkylmax/a-thesis-simulations/<run>/sim.c`. Consult the deck to identify the geometry, species and diagnostics. If a required diagnostic is missing locally, ask the user to download just the missing files from the cluster, specifying the run, filenames, frames and destination under `gkeyll-data/`.

Use Postgkyl (`import postgkyl as pg`) in Python to load the saved `.gkyl` diagnostics and plot reference cuts in the run’s physical coordinates. Use the cuts to check the exported plots, meshes, textures and probe readouts. Keep the conversion scripts in this project.

| Exhibit | Source diagnostics |
| --- | --- |
| Tabletop reference geometry | The 400-cell magnetic field cut and radii come from the pinned `data/1x-beams/` snapshot at frame 0. [Source diagnostics and field checks](gallery-1/README.md#checks-for-the-first-build) |
| Single-field-line distribution and probe | From `gkeyll-data/1x-beams/`, use the run’s own magnetic field and coordinate maps with `zzim-ion_75.gkyl`, `zzim-ion_M0_75.gkyl`, `zzim-ion_mapc2p_vel.gkyl`, `zzim-ion_jacobvel.gkyl` and the relevant `zzim-geo_int_jacob*.gkyl` files. |
| 2D cutaway | From `gkeyll-data/2x-boltz/`, use `zzim-stat.json`, `zzim-geo_corn_nodes.gkyl`, and both `zzim-ion_M0_<frame>.gkyl` and `zzim-field_<frame>.gkyl` for frames 0, 45 and 75. The density and potential diagnostics suffice for this exhibit. |
| Time wall and thesis comparison | From `gkeyll-data/1x-beams/`, use `zzim-ion_M0_<frame>.gkyl` for frames 45–75 and its axial map. Compare the endpoints with the thesis profiles in `figures/alpha-scan/publication-figures/07_oap_fdp_density_profiles.csv` and the companion `captions_and_methods.txt`. |
| Tandem expansion | For the selected `gkeyll-data/1x-tandem/` frame, use the distribution, matching M0, and that run’s geometry, velocity maps and Jacobians. If an independent equilibrium comparison is needed, use the matching reference from `generate_efit/` (`lorentzian_R32.geqdsk_psi.gkyl` or `tandem_R15.geqdsk_psi.gkyl`). |

Store the game’s simulation textures and 3D data in `simulation-renders/`. Commit the finished assets to GitHub and package them with both builds for offline use. Each file must be **under 100 MB**. Keep the total small for quick downloads and exhibit loading by reusing geometry and exporting only the frames and resolution visitors can inspect. For the distribution gallery, export `mirror.glb` for the full geometry, `ion-f-75.glb` for the isosurface and `ion-slices-75.png` for the atlas of saved slices. For the cutaway, export one texture per selected quantity and frame and share one mesh across them. Check the final texture values and mesh coordinates against the original diagnostic after any compression or downsampling. [Simulation asset guide](simulation-renders/README.md)

Record each asset’s run, source file, diagnostic, coordinate maps, units, frame and saved time as applicable. For the tabletop, record the analytic slider model, display scales and playback factors. For converted data, record interpolation, normalization, isosurface threshold, colour limits and atlas-to-value mapping where used. Label axes, legends, colour bars and probe readouts with quantity names, symbols and units. Keep the run, time and slice position in sync with the displayed data. Use the saved run for numerical values and Maxwell Rosen’s thesis at `~/Documents/PhD-thesis-latex` for their physical interpretation.

Before baking a distribution, evaluate the DG basis, map both velocity axes and establish which Jacobian factors the saved distribution includes. At the midplane and a throat, check that integrating the reconstructed distribution over velocity reproduces the saved ion density (M0). Compare the probe values and atlas slices at their recorded positions with independent cuts from the same run and frame. Check the cutaway coordinates and values against its source cells and the time-wall endpoints against the saved profiles before opening those galleries.

## First playable build

Deliver the foyer, walkable atrium and working tabletop mirror on desktop and Quest 3. The opposite doorway opens into Gallery 2, Between Bounces. The next pair opens into Gallery 3, Time Dilation, and Gallery 4, Which ions can reach a wall? The third arch on the right opens into Gallery 6, The tandem mirror. Three galleries are under construction. The full-length distribution gallery and linked probe are a later milestone.

1. **Check the tabletop on desktop.** Compare the opening geometry with the saved field cut and run the orbit and interaction checks. [Gallery 1 reference and commands](gallery-1/README.md#game-files-and-reference-checks)
2. **Test the visit.** Check that a new visitor can find the mirror and demonstrate a turning and an escaping launch using both sets of controls. [Gallery 1 visitor trial](gallery-1/README.md#checks-for-the-first-build)
3. **Measure on the headset.** Sideload the APK from Linux over USB and launch unplugged with Wi-Fi off. Test the atrium sightline and spend at least ten minutes at the active pedestal with all 40 markers and trails. Target sustained native 72 fps (about 13.9 ms per frame). Record CPU and GPU timings and dropped frames. Start with opaque geometry and baked lighting, then adjust detail according to the measured bottleneck.
