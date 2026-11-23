# Gallery 6 · The tandem mirror

**Can the end plugs turn back an ion moving straight along the magnetic field?** Follow a field line through two short, beam-fuelled plugs and a longer central cell. The sculpture and wall prints share the geometry of the 11 m Gkeyll run `1x-tandem`.

The entrance faces two boards on end plugging and early tandem experiments. Their interpretation follows the thesis introduction’s *A Brief History and the Mirror Renaissance* and *Extension to Tandem Mirrors*. The archival photograph shows Livermore’s TMX. [LLNL history](https://www.llnl.gov/tandem-mirror-experiment) · [Photograph and public-domain credit](https://commons.wikimedia.org/wiki/File:The_Tandem_Mirror_Experiment.jpg)

## Inside the distribution

The 28 m room places the coil stand first. Beyond it, a 9.9 m podium sits flush against the west wall and faces the velocity-cut board across the aisle. Walk or teleport into the podium to inspect a surface from within. The three rulers measure axial position along the machine (0.84 exhibit metres per metre of Z), parallel velocity across the stand (0.35 m per 10⁶ m/s) and magnetic moment vertically (0.0216 m per keV/T).

**Do the ions stay where the beams inject them?** Start with the source alone and predict where the ion distribution will be strongest. Show the ion surfaces and compare the plugs with the central cell. Each coloured surface encloses native simulation cells at or above its labelled threshold. Ten ion contours span 0.001 to 1 s³/m⁶. The inferno colours measure ion distribution in s³/m⁶. Greens measure the rate at which beams add ions in s²/m⁶. The ten ion thresholds run left to right in one row. Select a colour to isolate one threshold in its family. Select it again to restore the other levels.

**Next slice** moves the podium marker, wall cuts and coil pointer together. Compare the two velocity peaks at the right plug with the distribution at the inner throat. Changing slices keeps both saved fields, the thresholds and the colour scales fixed.

## Where are the ions injected?

Predict which of the central cell, inner throat, plug midplane and expander will show peaks in the beam source. Choose a section at the distribution board. A white pointer moves to that section on the sculpture. The two plots show the saved ion distribution and the rate at which the source adds ions at each parallel velocity and magnetic moment. The velocity axes and both colour scales stay fixed while you move the cut.

The axial board divides the velocity-integrated source by the total ion density in each axial cell. At the right plug midplane the beams add 8.48 ions per second per resident ion. The right plug midplane has two source peaks. The 25.117 keV beams inject ions travelling in both directions along the field with a 200 eV spread. Injection occurs in both plugs between the throats at |Z| = 2.02 and 3.98 m. The central cell and expander have only the numerical source floor. The distribution extends beyond the source, and the expander cut shows a stream toward the right wall. Blue on the ion print identifies negative numerical cell means. Each plot uses the physical velocity coordinates of the run.

## What closes the path to the wall?

Choose **Flat potential** and **Saved potential**. The trial launches a singly charged ion near the central midplane with 1 keV of parallel kinetic energy and zero magnetic moment. At zero magnetic moment the axial magnetic force vanishes, so the trial isolates the electric force. In the flat comparison the ion can traverse the device. In the saved field it gives up parallel kinetic energy as it approaches either dense plug. It turns where its kinetic energy reaches zero. From the sampled central cell to the peak of the right plug, the potential rises by 4.96 kV, an energy barrier of 4.96 keV for this ion.

## How quickly do the beams replenish the ions?

At frame 75 (0.500150 s), the tandem beams inject 5.220 × 10²¹ ions/(Wb s) into a tube containing 4.215 × 10²⁰ ions/Wb, including both plugs. Dividing injection by inventory gives **12.39 s⁻¹**. The axial plot uses the same definition locally. The whole-tube rate weights each local rate by its ion inventory.

The board also reports the instantaneous wall-loss time of **99.6 ms**, obtained by dividing inventory by the outward loss rate at both walls. The thesis gives a wall-loss-to-injection ratio for the beam-fuelled simple mirror at nominal mirror ratio 15. Its absolute injection and inventory are needed for the corresponding rate per ion. [Requested diagnostics](../NEED_DATA.md)

Across the aisle, **Do the beams fill the central cell?** compares the saved density at the central-cell and right plug midplane samples from the velocity-cut board. Both values count ions per cubic metre at the same instant.

Activate controls with the mouse or right trigger. Near each board on desktop, use Tab or Shift+Tab and Enter. Pausing and returning retains both the selected slice and the choice of potential. [Museum controls](../CONTROLS.md)

## Data and verification

The ion distribution and potential come from frame 75 at 0.500150 s. The time-independent beam source was saved on restart in frame 43 at 0.460061 s. The sculpture traces eight azimuths of the run's one simulated field line. Copper windings mark the nominal throat locations, with illustrative bore and wire gauge. Axial scale is 0.65× and radial scale is 3.2×, giving 4.92× radial enlargement relative to the length. [Asset manifest](../simulation-renders/gallery-6/manifest.json)

Run the exporter from the repository root with Postgkyl, NumPy, Matplotlib, trimesh and Pillow installed.

```sh
python gallery-6/tools/export_tandem.py
```

The exporter reconstructs signed physical phase-volume cell means using the native velocity and configuration-space Jacobians. Integrating the full velocity grid reproduces the independently saved ion density and source density at all 1,000 axial cells. The script also checks both moments against the final integrated histories, mapped radii and axial coordinates against independent geometry diagnostics, and representative colours from each finished print. The plotted parallel-velocity window is ±3 × 10⁶ m/s. All magnetic-moment cells are shown on an inverse-hyperbolic-sine axis with a linear width of 1 keV/T. The underlying integral uses all velocity cells. [Exporter](tools/export_tandem.py) · [Thesis, Extension to Tandem Mirrors](<../../PhD-thesis-latex/Chapter Gkeyll Extensions/tex-files/tandem_mirrors.tex>)

The room test enters through arch 6, activates the controls from seated and standing eye heights, pauses, leaves, and returns. The hall shows the coil stand, podium and blank board faces. The animated markers inside use Gallery 1’s idealized gyro and bounce clock, fitted to the three cell lengths. The detailed scientific assets load on entry and are released on exit. [Visit check](tools/check_visit.gd)
