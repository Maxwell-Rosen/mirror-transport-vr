# Gallery 5 cluster request · Maxwellian-source simple mirror

**Received and verified.** The reduced arrays, field traces, extraction report and script are in `gkeyll-data/1x-maxw/gallery-5/`. The four playable stations use this delivery. [Gallery 5](gallery-5/README.md)

The original request was for one reduced bundle from `/scratch/gpfs/CSD/mr1884/gkylmax/a-thesis-simulations/1x-maxw/`. This is the nominal mirror-ratio 32 POA baseline with a Maxwellian source, 400 × 64 × 32 cells and frame 75 at **0.500150 s**. The audited input `sim.c` has SHA-256 `5e1253b7bae9d882b6b91d3427848d606b1b0c0bd091fcca4423cb97db417e55`. Use the saved frame headers to identify the campaign. An older local run also has the name `1x-maxw`.

## Quantities to extract

Use Python and Postgkyl (`import postgkyl as pg`) on the cluster. Return compressed numerical arrays (e.g. NPZ), a small CSV for the traces, the extraction script and a JSON record of units, axes, run-relative input filenames, frame IDs, header times in seconds and reductions. The local destination is `gkeyll-data/1x-maxw/gallery-5/`.

| Exhibit use | Cluster inputs within this run | Data to return |
| --- | --- | --- |
| Sculpture of the equilibrium and its orbit-distributed source, with three linked velocity cuts | `zzim-ion_75.gkyl` and static `zzim-ion_source_0.gkyl` | One signed physical cell mean per native cell for each quantity, ordered `[Z, v_parallel, mu]`. Units are s³/m⁶ for the distribution and s²/m⁶ for the injection rate density. Include physical cell faces (m, m/s, J/T), ion mass (kg), and the source diagnostic's own time. Two float64 arrays occupy 12.5 MiB total before compression. |
| Native geometry and independent moment checks for the sculpture | `zzim-geo_corn_mc2nu_pos_deflated.gkyl`, `zzim-ion_mapc2p_vel.gkyl`, `zzim-ion_jacobvel.gkyl`, `zzim-geo_int_jacobtot.gkyl`, `zzim-geo_int_jacobgeo.gkyl`, `zzim-geo_int_bmag.gkyl`, `zzim-ion_M0_75.gkyl`, `zzim-ion_source_M0_0.gkyl` | Save the physical axial centres, cell-mean magnetic field (T), the per-axial-cell velocity integration factor below, and independently evaluated density (m⁻³) and source moment (m⁻³ s⁻¹). Preserve negative cell means and the numerical source floor. |
| Growth toward equilibrium and the phase clock | `zzim-ion_M0_{k}.gkyl`, for `k = 0, 10, 20, 30, 40, 50, 75` | Seven 1-D ion-density profiles on the native axial cells with individual frame times. These sample the first available state, the five cycle ends and the end of the extended full-dynamics phase. Read the actual time for frame 0. Use the frame-75 density once for both the profile and the integral check. |
| Final spatial probes of flow, heating and electrostatic potential | `zzim-ion_BiMaxwellianMoments_75.gkyl`, `zzim-field_75.gkyl` | One final profile each of parallel flow (m/s), parallel and perpendicular ion temperatures (eV) and electrostatic potential (V). Use the run's ion mass to convert the saved temperature-per-mass components. Record the mapped sample positions and the averaging or interpolation used. |
| Fig. 5.5 potential history at the midplane, right throat and right sheath entrance | `zzim-field_{k}.gkyl`, `k = 0…75`, and the run's configuration map | One row per frame with frame ID, saved time (s), and three potentials (V). Reproduce the PRE `field.py` sampling: interpolate the DG field, map with `geo_corn_mc2nu_pos_deflated`, then select nominal positions 0, 0.98 and 2.5 m. Record the sample coordinates. The stored final Maxwellian total midplane ion Dougherty frequency for the time-axis conversion is 17.285659 s⁻¹. |

## Check on the cluster

For both phase-space arrays, the p=1 gyrokinetic hybrid constant mode divided by √8 gives the cell mean of the Jacobian-weighted field. Divide by the native velocity Jacobian and cell-mean total configuration Jacobian. Reconstruct the map faces from their modal traces. On these cells, the signed velocity sum is

```text
n[iz] = (2π/m_i) (mean_Jtot[iz] / mean_Jgeo[iz]) × Σ f[iz,iv,im] Δv_parallel[iv] Δmu[im]
```

Apply the same sum to the source to recover its injection-rate moment. Evaluate the reference as the cell integral of the *DG product* of the independently saved M0 and geometry Jacobian, divided by the cell integral of that Jacobian. This gives a volume-weighted reference consistent with the exported cells. The Gallery 5 cluster extractor implements these reductions in `faces` and `moment`. [Extractor](gallery-5/tools/phase_extract_maxwellian.py)

Return the largest relative residual over the 400 cells for each array, plus the actual axial cell bounds, integrated values and references near 0, +0.98 and +2.5 m. Use the last in-domain cell at the sheath entrance. With lossless float64 cell means the expected relative agreement is within 10⁻⁹. For the separately interpolated potential traces, the final normalized drops (Δφ in volts divided by 940 V) should reproduce 7.6215 from midplane to throat and 6.0376 from throat to sheath entrance. Keep a discrepancy and its source visible in the extraction report before using those values in an exhibit.

## Already on the museum workstation

The complete matching beam baseline, its source and its maps are in `gkeyll-data/1x-beams/`. The PRE checkout's `audit/numbers.json` has the two completed seven-point scans with inventory, injection rate, collision normalization, both exit measurements, run, frame and time for every point. Its `ion-collision-time-analysis/inputs.json` also has the positive-side field profiles for the scan. The thesis and PRE figures supply the continuation comparison. These cover the remaining Gallery 5 exhibits.
