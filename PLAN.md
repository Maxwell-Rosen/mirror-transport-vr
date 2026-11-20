# Walking through a magnetic mirror

## The first minute

You enter beside a five-metre mirror at roughly workbench height. Two copper-coloured rings mark the throats. A handful of field lines pass through them, pinching together where the field is strongest. Particles gyrate around the field lines, animated, bouncing back and forth, depicting the mirror confinement. A rail runs the length of the machine. Slide a bright hoop along it. At each marked position, a nearby plot opens a slice through the ion distribution at that same location. Someone seeing a mirror for the first time can follow the field lines. Someone who knows the physics can walk straight to the throat and inspect the ions.

Keep the floor and horizon stationary, with room to step back and see the whole machine. Build the apparatus at physical scale and put the enlarged data in the gallery alongside it. The outer sampled radius of the 2D run at the midplane is only 10 cm, so enlarge this dimension by a factor of 10, but make this clear in the labels. Show the radial magnification on the exhibit and offer a true-scale view. The rings are a schematic of the double-Lorentzian mirror. Derive the field lines and throat locations from the saved geometry.

![Field strength along a single field line above a mapped four-cell radial section coloured by ion density](mirror-preview.png)

I'm imagining that the geometry has around 8 field lines in angle and it's depicting a flux surface, so there are 8 total lines, with azimuthal symmetry. They go in and out radially of the mirror, and some toridal surfaces depict the coils at the mirror throat. There are particles bouncing back and forth on each field line, gyrating around the field lines, reflected by the coils, slowing down according to mu grad B forces. I would like the orbit dynamics and the equations to be realistic, showing how energy is conserved, as particles move toward the mirror throat, kinetic energy transfers from parallel to perpendicular. Think about this carefully and use real equations for a reasonably trapped particle. I would like the bounce period for the VR experience to be around 5 seconds.

The preview aligns the axial coordinates of two related runs. The upper trace samples the field at cell centres in `1x-beams`. The lower cut uses saved corner nodes and the cell-average ion density from `2x-boltz`, frame 75. The radial axis is enlarged. The uncoloured centre lies outside the sampled flux interval.

All figures must have appropriate labels for units and what everything represents.

## What to put on the floor

| Exhibit | What the visitor can do | What the figure shows |
| --- | --- | --- |
| Magnetic mirror | Move the hoop from the midplane to either throat. Beside it, watch two illustrative ions launched at different pitch angles, one turning and one passing through. | The saved field rises from about 0.53 T near the midplane to 16.7 T near each throat. Label the paths as an idealized magnetic-only demonstration. |
| Single-field-line distribution | Walk around a 2–3 m tall sculpture of the ion distribution `f(Z, v∥, μ)`. The same hoop cuts a velocity-space slice through it. The slice stays visible from the outside. | Position runs along the gallery. The other two axes are parallel velocity and magnetic moment. Use one opaque isosurface with an exposed cut face and a labelled heatmap for its interior. Put the threshold and units on the plinth. Reuse this exhibit for the tandem mirror with its own geometry and length scale. Its simulated axial span is 11 m. |
| The 2D plasma cutaway | Look into an open wedge of the mirror, select density or electrostatic potential, and step between saved times. | Map the four radial cells by 400 axial cells in `2x-boltz` into physical radius and axial position, then revolve the section under axisymmetry. Leave a face exposed with the four cell bands visible. Carry the same colour scale across time for each quantity. |
| The last 90 microseconds | Walk along a wall-sized plot of `1x-beams` ion density versus axial position and elapsed time. Point to a place where the colour hardly changes, then inspect the signed endpoint difference there. | Use frames 45–75 with their saved timestamps. Pair the heatmap with the existing thesis comparison of frames 45 and 75. A diverging difference scale centred on zero can reveal relaxation hidden by the absolute density scale. [Figure definitions](../figures/README.md) |

The single-field-line sculpture is the first exhibit to build alongside the apparatus. It brings back what visitors liked in the tandem demonstration and gives the headset a meaningful rendering test. For controls, make the default interaction pointing and pulling the trigger. Visitors can teleport to marked viewpoints or walk physically. Offer stick-controlled flight, including ascent and descent, with snap turning, a level horizon and a return-to-floor button. The laptop uses mouse and keyboard for the same movement and probe.

## Platform choice

**Start with Godot 4, GDScript and OpenXR.** Build one scene with a desktop camera and a headset rig. The Linux laptop can preview every figure and interaction, and Godot can export the same assets in a standalone Android APK. Text scenes, scripts and command-line exports suit agent-led development. Pin the engine version, matching export templates and Android build preset once the first APK works. Use Postgkyl on the cluster for the scientific transformations. The Quest can then draw ordinary game meshes and textures entirely offline. [Godot Android XR deployment](https://docs.godotengine.org/en/stable/tutorials/xr/deploying_to_android.html) · [Command-line workflow](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)

## What to export from the cluster

Run the conversion beside the raw data. The following are existing inputs relative to `a-thesis-simulations/`. Each run uses its own geometry, velocity maps and metadata. Braces below denote a choice of files.

| Purpose | Cluster inputs |
| --- | --- |
| First room, geometry and distribution | In `1x-beams/` take `sim.c`, `zzim-stat.json`, `zzim-geo_corn_nodes.gkyl`, `zzim-geo_corn_mc2nu_pos_deflated.gkyl`, `zzim-geo_int_bmag.gkyl`, `zzim-ion_75.gkyl` and `zzim-ion_M0_75.gkyl`. Include `zzim-ion_mapc2p_vel.gkyl`, `zzim-ion_jacobvel.gkyl` and the run’s `zzim-geo_int_jacob*.gkyl` for distribution reconstruction. Use the 2D run’s nodes for neighbouring flux lines. |
| 2D cutaway | In `2x-boltz/` take `sim.c`, `zzim-stat.json`, `zzim-geo_corn_nodes.gkyl`, `zzim-ion_M0_{0,45,75}.gkyl` and `zzim-field_{0,45,75}.gkyl`. All 76 density frames together are about 3.76 MiB if more times are wanted. A single raw 2D ion distribution is about 600 MiB. The density and potential exhibits use the smaller diagnostics. `2x-kinetic/` currently has only frame 0 for these fields. |
| Time wall and thesis comparison | In `1x-beams/` take `zzim-ion_M0_<frame>.gkyl` for frames 45 through 75 and the same axial map. Reuse `figures/alpha-scan/publication-figures/07_oap_fdp_density_profiles.csv` and its companion `captions_and_methods.txt` for the endpoint comparison. |
| Tandem expansion | Use the first-room file set from `1x-tandem/` with its own frame and maps. For an independent equilibrium reference, the two cases use `../generate_efit/{lorentzian_R32,tandem_R15}.geqdsk_psi.gkyl`. |

**Download to the laptop after conversion.** For the first room the proposed bundle is `mirror.glb` (field lines and geometry), `ion-f-75.glb` (isosurface), `ion-slices-75.png` (atlas of velocity-space slices), `field-profile.csv` (probe positions and field values), and `manifest.json`. For the next room add a reusable cutaway mesh and a density or potential texture per selected frame. Keep the conversion script with the project. Record the run, frame, saved time, physical axes, units, threshold, colour limits, atlas-to-value mapping and display magnification in the manifest. Package the display assets into the APK.

Before baking an ion surface, evaluate the DG basis, map both velocity axes, and establish which Jacobian factors the saved distribution includes. Check a velocity integral of the reconstructed distribution against the saved ion M0 at the midplane and throat. Check the atlas slices against the same offline cuts, and switch between saved slices at their recorded positions. This catches an axis reversal or an eye-catching surface produced by a coordinate weight.

## First playable build

Build one room with the five-metre apparatus, one frame of ion data and the linked probe. Sideload it from Linux over USB and launch unplugged with Wi-Fi off. On Quest 3, test the closest permitted view of the cut face, the whole room from the entrance, and repeated slicing after ten minutes of use. Aim for sustained native 72 fps, about 13.9 ms per frame. Measure CPU and GPU timings and dropped frames on the device. Start with opaque geometry, baked lighting and precomputed slices. Adjust mesh detail or texture resolution according to the measured bottleneck. [Godot deployment](https://docs.godotengine.org/en/stable/tutorials/xr/deploying_to_android.html) · [Meta frame-rate criteria](https://developers.meta.com/vr/resources/vrc-quest-performance-1/)

Hand the headset to a new visitor. Can they find a throat and show someone else the corresponding velocity slice without coaching? That test decides whether the next pass needs a clearer interaction or another exhibit. Agents can build the exporter, reference images, desktop controls and APK. The scientific sign-off is a comparison with the thesis diagnostics, and the comfort and scale check happens in the headset.

## Original sketch

For the thesis, I'd like to create a virtual reality experience to showcase the data. I would like people to be able to use the controlers to move around the data at their own pace. I'd like to show some cool figures in 3D of the simulation and good visuals.

Hardware: Meta quest 3 stand alone. Development is entirely on a kubuntu laptop, but I also have a bazzite desktop with an RTX 3090.

I would like to do a stand alone experience so that I don't have to move my desktop, or bring it to the office.

Thoughts:

The distribution function for the single field line simulations is good 3D data. It would be good to show some geometry plots as well.

It would be cool to have a sort of museum exhibit in VR showing the different simulations. I want the figures to be life-size, so 2-3 meters tall. My simulations for the single field line are 5 meters in length, so that's a good bigger-than-life scale

It's important to have some physical geometry figures because it shows the real geometry. I'd like a mock up geometry / experimental apperatus about the double lorentizian geometry. It would be good to have a figure about what a magnetic mirror is. 

I chatted with chatGPT and it said Godot 4 + OpenXR would be a good platform. I only have linux computers to develop on. I would love to get this working on my laptop for development, then move it over to the headset for the full experience. Performance is important, so it should run smoothly on the headset. I'm open to considering other platforms. I would really like agents to do the bulk of the development for this.

I did a VR experience for the distribution function of the tandem mirror before. That went over really well. I'd like something similar in there.

For the 2D simulations, I'm not sure what plots to make. I'm open to suggestions

Please outline the files I would need to export from the cluster and download locally.

We can make a 2D figure 3D, or 1D to 2D by putting time as an axis. Think of some more figures we can put in the experience.

For controls, I'd like for people to just be able to move around the space. we can do a flying camera.
