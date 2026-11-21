# Gallery 6 · The tandem mirror

**Can the end plugs turn back an ion moving straight along the magnetic field?** Follow a field line through two short, beam-fuelled plugs and a longer central cell. The sculpture and wall prints share the geometry of the 11 m Gkeyll run `1x-tandem`.

## Where are the ions injected?

Predict which of the central cell, inner throat, plug midplane and expander will show peaks in the beam source. Choose a section at the distribution board. A white pointer moves to that section on the sculpture. The two plots show the saved ion distribution and the rate at which the source adds ions at each parallel velocity and magnetic moment. The velocity axes and both colour scales stay fixed while you move the cut.

The right plug midplane has two source peaks. The 25.117 keV beams inject ions travelling in both directions along the field with a 200 eV spread. Injection occurs in both plugs between the throats at |Z| = 2.02 and 3.98 m. The central cell and expander have only the numerical source floor. The distribution extends beyond the source, and the expander cut shows a stream toward the right wall. Blue on the ion print identifies negative numerical cell means. Each plot uses the physical velocity coordinates of the run.

## What closes the path to the wall?

Choose **Flat potential** and **Saved potential**. The trial launches a singly charged ion near the central midplane with 1 keV of parallel kinetic energy and zero magnetic moment. At zero magnetic moment the axial magnetic force vanishes, so the trial isolates the electric force. In the flat comparison the ion can traverse the device. In the saved field it gives up parallel kinetic energy as it approaches either dense plug. It turns where its kinetic energy reaches zero. From the sampled central cell to the peak of the right plug, the potential rises by 4.96 kV, an energy barrier of 4.96 keV for this ion.

Blocking these paths reduces the number of central ions that can escape on each pass. Collisions can repopulate the escaping states. For the same inventory, reducing the outward flux increases the confinement time. At the final saved instant the whole tube contains 4.215 × 10²⁰ ions per Wb of poloidal flux label and both ends lose a combined 4.231 × 10²¹ ions/(Wb s). Their ratio gives an instantaneous confinement estimate of **99.6 ms**. It includes the plug populations. The injection rate exceeds the loss rate at this instant, with a loss/source ratio of 0.811. The flat-field trajectory is a single-particle comparison. A measured lifetime enhancement factor would require a matched second plasma run.

Activate controls with the mouse or right trigger. Near each board on desktop, use Tab or Shift+Tab and Enter. Pausing and returning retains both the selected slice and the choice of potential. [Museum controls](../CONTROLS.md)

## Data and verification

The ion distribution and potential come from frame 75 at 0.500150 s. The time-independent beam source was saved on restart in frame 43 at 0.460061 s. The sculpture traces eight azimuths of the run's one simulated field line. Copper windings mark the nominal throat locations, with illustrative bore and wire gauge. Axial scale is 0.65× and radial scale is 3.2×, giving 4.92× radial enlargement relative to the length. [Asset manifest](../simulation-renders/gallery-6/manifest.json)

Run the exporter from the repository root with Postgkyl, NumPy, Matplotlib and Pillow installed.

```sh
python gallery-6/tools/export_tandem.py
```

The exporter reconstructs signed physical phase-volume cell means using the native velocity and configuration-space Jacobians. Integrating the full velocity grid reproduces the independently saved ion density and source density at all 1,000 axial cells. The script also checks both moments against the final integrated histories, mapped radii and axial coordinates against independent geometry diagnostics, and representative colours from each finished print. The plotted parallel-velocity window is ±3 × 10⁶ m/s. All magnetic-moment cells are shown on an inverse-hyperbolic-sine axis with a linear width of 1 keV/T. The underlying integral uses all velocity cells. [Exporter](tools/export_tandem.py) · [Thesis, Extension to Tandem Mirrors](<../../PhD-thesis-latex/Chapter Gkeyll Extensions/tex-files/tandem_mirrors.tex>)

The room test enters through arch 6, activates the controls from seated and standing eye heights, pauses, leaves, and returns. The entry sign stays in view from the hall. The detailed scientific assets load on entry and are released on exit. [Visit check](tools/check_visit.gd)
