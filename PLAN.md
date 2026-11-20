# Walking through a magnetic mirror

## The first minute

Visitors start on the level floor of the entry foyer, facing an open doorway. A welcome panel stands on one side and a controls graphic for the current device on the other, both readable from a chair. Beyond them, octagonal columns frame the view down the low-poly museum’s skylit atrium to a spring fountain. Eight numbered galleries open off the hall, four on each side. Try a 16 m wide atrium with 4 m openings and at least 3 m of clear passage on either side of the fountain. Set benches and planters back from the approaches. Mark unfinished galleries with waist-high yellow-and-black tape across the doorway and an **Under construction** sign. [Museum layout and sightlines](SETTING.md)

The first entrance on the left reads **1 · The Magnetic Mirror**. From the hall, visitors see two copper-coloured throat rings in profile with blue field lines passing through them. The pedestal faces the entrance and asks **“Which particles turn back, and which escape through the ends?”** With the other controls at their opening settings, follow the ion marked **+450 km/s**. At mirror ratio 15 it crosses the right-hand ring. Raise the ratio to 20 and release the slider. The same launch now turns before the ring and travels back through the midplane. [Mirror exhibit](INTRO_MIRROR_INTERACTIVE.md)

## Music and water

The first Promenade from Modest Mussorgsky’s *Pictures at an Exhibition* plays at the same level in the foyer, atrium and every gallery. Walking, teleporting or returning Home preserves the phrase in progress. A low bowed B-flat swells for two beats before the clarinet enters with G–F. The clarinet carries the melody through all 24 bars at a steady 40 bpm. The cellos sustain the harmony beneath it. The first soft piano chord comes about 20 seconds in, after the opening statement. The final B-flat rings out before the opening bow returns. [Chamber recording](museum/audio/promenade.ogg) · [Piano score](https://www.ibiblio.org/mutopia/ftp/MussorgskyM/promenade/promenade-a4.pdf)

The soft clarinet and bowed cellos use recordings from the Versilian Studios Chamber Orchestra 2 Community Edition (CC0). Within each clarinet phrase, the connected notes draw on the sustained portion of the same recordings. The piano uses the soft v4 strikes from Alexander Holm’s Salamander Grand Piano v3 (CC BY 3.0). [Clarinet and cello recordings](https://github.com/sgossner/VSCO-2-CE/tree/440300901dfe9275fd84e0b7763af1f8443ae62e) · [Salamander recordings](https://github.com/sfzinstruments/SalamanderGrandPiano/tree/3382bf9496bba2486f5ab0de55a264d1dfc38404) · [Piano sample license](https://creativecommons.org/licenses/by/3.0/)

Edit the notes and phrase dynamics in the SoundCraft session. Run `python3 audio-source/render_promenade.py` to bounce the session and carry the room decay across the **Loop end** marker. [Session](audio-source/Promenade.scraft) · [Loop renderer](audio-source/render_promenade.py)

The fountain has its own quiet sound source at the basin. Visitors hear the running water beneath the music as they approach and can locate it by turning their head. Its sound carries up to 16.5 m through the atrium. Inside each gallery it falls a further 8 dB over the first 4 m past the doorway. Check the balance on desktop speakers and Quest headphones from the foyer, beside the fountain, inside a gallery and at the far end of the atrium.

## The tabletop mirror

Display the double-Lorentzian reference geometry from the saved lower boundary at −2.5 m to the upper boundary at +2.5 m. Compute the field and orbits in physical coordinates, then draw them at 1.44× axial and 5.4× radial scale. Label the 7.2 m mirror with its **3.75× relative radial enlargement**. Space eight field lines 45° apart on the flux surface through a midplane radius of 0.10 m. On each line, release five deuterium ions at staggered times with the same launch velocity and short, fading trails. Give each group a colour and a matching numbered launch point on the plot.

| Pedestal slider | Range | Opening setting |
| --- | --- | --- |
| Mirror ratio $R_m=B_t/B_0$ (dimensionless) | 1–50 | **Thesis geometry (nominal R32)**, displayed as 31.41 |
| Launch parallel speed spread $V$ | 0–1,400 km/s | 1,050 km/s |
| Magnetic moment $\mu$ | 0–1.00 keV/T | 0.25 keV/T |
| Midplane potential relative to the throats $\Delta\phi$ | −5 to +5 kV | 0 kV |

The field lines are straight at ratio 1. Blend into the ratio-3 profile, then narrow the two Lorentzians as the ratio rises to 50. Keep the midplane field at 0.53062 T. Show it beside the ratio slider with the current throat field, which reaches 16.6649 T at the thesis setting. Label the animation **Idealized deuterium ion trajectories**. An ion turns when its motion along the field stops and reverses. It escapes the central cell when it crosses a throat moving outward. Show an escaping ion through the full expander, then fade it at the tip and relaunch it at the midplane. Use dark blue-grey for lines carrying escaping ions and bright blue for lines carrying confined ions.

Keep both plots on fixed axes. The loss-cone plot shows signed launch parallel velocity $v_{\parallel0}$ (km/s) horizontally and magnetic moment $\mu$ (keV/T) vertically, with eight launch points and regions labelled **turns back** and **escapes**. Beside it, plot the parabolic **model ambipolar potential** $\phi$ (kV) against axial position $Z$ (m), with zero potential at both throats.

Conserve total energy and magnetic moment along each guiding-centre orbit. At zero potential, an ion moving into stronger field gains perpendicular kinetic energy at the expense of parallel motion. For the plotted escape threshold, use the rise from the midplane to the highest effective potential $\mu B+q\phi$ anywhere on the path to the throat. [Field model, equations and plot definitions](INTRO_MIRROR_INTERACTIVE.md)

Label the clock **1 exhibit second = 2.315 µs of ion motion**. The +450 km/s ion completes a full bounce in four exhibit seconds at the opening settings. Use this clock for every trial and label the visible gyro rotation **1/64 speed relative to ion motion**. Mark the doorway with a broad yellow-and-black floor stripe. Put the starting instruction on the floor along its atrium edge. Crossing its inner edge starts the orbits, which run throughout the gallery. Leaving for the atrium freezes the clock and trails. Re-entry resumes the same trial. [Playback and visible gyration](INTRO_MIRROR_INTERACTIVE.md#playback-and-visible-gyration)

## Moving and using exhibits

- **Quest 3.** Walk with the left stick, turn your head to look and flick the right stick to snap turn. Visitors can also lean and step physically. Point a controller and squeeze the trigger to use an exhibit button or teleport to a viewpoint by aiming at the floor near a gallery entrance. Make every exhibit reachable from a chair using the controllers alone.
- **Desktop.** Walk with WASD, look and aim with the mouse, and left-click to interact.
- **Sliders and probes.** Hold the trigger or left mouse button, drag along the track, then release. At the mirror, hold the ions at the midplane during a drag while the geometry, launch points and plots update. Releasing the slider starts a fresh trial. The pedestal’s **Reset** clears the trails and returns the ions to the midplane with the current settings.
- **Return to the foyer.** Hold **Select** until the circular progress indicator fills. Releasing early cancels. A completed hold returns the visitor to the foyer facing the atrium doorway. The proposed bindings are **X** on the left Quest controller and **Home** on the keyboard.

Keep the floor and horizon level. For the taller data displays, plan optional flight with ascent, descent and a control to return to the floor beneath the visitor. [Movement and interaction bindings](CONTROLS.md)

## Galleries after the tabletop

| Gallery and visitor question | Interaction and data |
| --- | --- |
| **Single-field-line distribution.** How does the ion velocity distribution change between the midplane and a throat? | Pair the full five-metre `1x-beams` geometry with a 2–3 m tall sculpture of $f(Z,v_\parallel,\mu)$ at frame 75. Slide a hoop along the rail to a saved axial position. Show the field there and a velocity-space heatmap on the exposed face of one opaque isosurface. Keep the slice visible from outside and put the threshold and units on the plinth. |
| **2D plasma cutaway.** How do density and electrostatic potential vary across the mirror and over time? | Map the four radial by 400 axial cells of `2x-boltz` to physical coordinates and revolve the section under axisymmetry. Leave a wedge open to expose the four cell bands. Switch quantities and step through frames 0, 45 and 75 with a fixed colour scale per quantity. Label the unsampled centre. Show the 10 cm outer midplane radius at a labelled 10× radial magnification and offer a true-scale view. |
| **The last 90 microseconds.** Where does the ion density continue to change late in the run? | Walk along a wall of `1x-beams` density versus axial position and elapsed time using frames 45–75 and their saved timestamps. Point at a position to read the signed density difference, frame 75 minus frame 45. Use a diverging scale centred on zero and pair it with the thesis endpoint profiles. |
| **Tandem mirror.** How does the distribution vary along the tandem mirror’s 11 m simulated span? | Reuse the sculpture and hoop interaction with `1x-tandem` data, its own geometry, velocity maps and length scale. |

For the two-run preview, align the `1x-beams` field trace and the `2x-boltz` frame-75 density cut by physical axial position. Sample the field at its own cell centres and draw the cell-average density using the 2D run’s corner nodes. Label each run on its panel.

## Platform and simulation data

Use Godot 4, GDScript and OpenXR. Share exhibit scenes and data between the downloadable desktop build and the standalone Quest 3 Android APK. Develop on the Kubuntu laptop, with the Bazzite RTX 3090 desktop available for desktop testing. Pin the engine version, matching export templates and Android build preset once the first APK works. [Godot Android XR deployment](https://docs.godotengine.org/en/stable/tutorials/xr/deploying_to_android.html) · [Command-line workflow](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)

The Gkeyll input decks for these runs are in `/home/maxwell-rosen/Documents/gkylmax/a-thesis-simulations/<run>/sim.c`. Consult the deck to identify the geometry, species and diagnostics. The saved simulation outputs live on the cluster. Downloaded `.gkyl` files belong in this museum repository, grouped by run (for example, `data/1x-beams/`).

When an exhibit needs data, first check which files for that run and frame are already in the repository. Ask the user to download the missing files from the cluster, giving the run, filenames or patterns, frames and repository destination. Request only what the current exhibit needs. The user supplies the raw files. The agent reads them locally with Postgkyl, analyzes the diagnostics, interprets them using the thesis at `~/Documents/PhD-thesis-latex`, and constructs the plots, meshes, textures and probe readouts. Keep the conversion scripts in this project.

| Exhibit | Files to request for its analysis |
| --- | --- |
| Tabletop reference geometry | From `1x-beams/`, request `zzim-geo_int_bmag.gkyl`, `zzim-geo_corn_mc2nu_pos_deflated.gkyl` and `zzim-geo_corn_nodes.gkyl`, with `zzim-stat.json` for run metadata. Use the field and its coordinate maps to check the opening analytic model. |
| Single-field-line distribution and probe | Reuse the tabletop geometry. From `1x-beams/`, request `zzim-ion_75.gkyl`, `zzim-ion_M0_75.gkyl`, `zzim-ion_mapc2p_vel.gkyl`, `zzim-ion_jacobvel.gkyl` and the relevant `zzim-geo_int_jacob*.gkyl` files. |
| 2D cutaway | From `2x-boltz/`, request `zzim-stat.json`, `zzim-geo_corn_nodes.gkyl`, and both `zzim-ion_M0_<frame>.gkyl` and `zzim-field_<frame>.gkyl` for frames 0, 45 and 75. The density and potential diagnostics suffice for this exhibit. |
| Time wall and thesis comparison | From `1x-beams/`, request `zzim-ion_M0_<frame>.gkyl` for frames 45–75 and reuse its axial map. Compare the endpoints with the thesis profiles in `figures/alpha-scan/publication-figures/07_oap_fdp_density_profiles.csv` and the companion `captions_and_methods.txt`. |
| Tandem expansion | For the selected `1x-tandem/` frame, request the distribution, matching M0, and that run’s geometry, velocity maps and Jacobians. If an independent equilibrium comparison is needed, request the matching reference from `generate_efit/` (`lorentzian_R32.geqdsk_psi.gkyl` or `tandem_R15.geqdsk_psi.gkyl`). |

For the first playable build, export the reference positions and field values in `field-profile.csv` with `manifest.json`. Generate the tabletop field lines, launches, model potential and plots from the current sliders. For the distribution gallery, add `mirror.glb` for the full geometry, `ion-f-75.glb` for the isosurface and `ion-slices-75.png` for the atlas of saved slices. For the cutaway, add a reusable mesh and a texture for each selected quantity at each saved frame. Package the converted assets with both builds for offline use.

Record each asset’s run, source file, diagnostic, coordinate maps, units, frame and saved time as applicable. For the tabletop, record the analytic slider model, display scales and playback factors. For converted data, record interpolation, normalization, isosurface threshold, colour limits and atlas-to-value mapping where used. Label axes, legends, colour bars and probe readouts with quantity names, symbols and units. Keep the run, time and slice position in sync with the displayed data. Use the saved run for numerical values and Maxwell Rosen’s thesis for their physical interpretation.

Before baking a distribution, evaluate the DG basis, map both velocity axes and establish which Jacobian factors the saved distribution includes. At the midplane and a throat, check that integrating the reconstructed distribution over velocity reproduces the saved ion density (M0). Compare the probe values and atlas slices at their recorded positions with independent cuts from the same run and frame. Check the cutaway coordinates and values against its source cells and the time-wall endpoints against the saved profiles before opening those galleries.

## First playable build

Deliver the foyer, walkable atrium and working tabletop mirror on desktop and Quest 3. Mark the other seven entrances under construction. The next playable milestone adds the full-length distribution gallery and linked probe.

1. **Check the opening geometry.** Compare the model with the saved `1x-beams` field at the same physical cell centres. At $Z=0.010876$ m expect 0.53087 T, and at $Z=0.979165$ m expect 16.66235 T, both within 0.1%. Check the node radii of 0.10000 m at the midplane and 0.01785 m nearest the positive throat. [Geometry and orbit checks](INTRO_MIRROR_INTERACTIVE.md#checks-for-the-first-build)
2. **Check the desktop trial.** At the opening settings the loss-cone threshold is 619.4 km/s. The ±150 and ±450 km/s launches turn, and the ±750 and ±1,050 km/s launches escape. Check the straight-field, zero-potential case and the positive-potential interior barrier against the orbit specification. Over ten full reference bounces, check energy drift below 0.1% of launch kinetic energy, turn positions within 1 mm and the four-second return within 1%. [Reference trials](INTRO_MIRROR_INTERACTIVE.md#checks-for-the-first-build)
3. **Test the visit.** Hand a new visitor the controls. Can they find Exhibit 1, use the plot to predict what the +450 km/s ion will do at ratios 15 and 20, and show both outcomes without coaching? Try the slider, pedestal reset and hold-to-return on both devices. In the headset, check seated and standing sightlines, teleport landings, label reach and the pause and resume at the floor line.
4. **Measure on the headset.** Sideload the APK from Linux over USB and launch unplugged with Wi-Fi off. Test the atrium sightline and spend at least ten minutes at the active pedestal with all 40 markers and trails. Target sustained native 72 fps (about 13.9 ms per frame). Record CPU and GPU timings and dropped frames. Start with opaque geometry and baked lighting, then adjust detail according to the measured bottleneck.
