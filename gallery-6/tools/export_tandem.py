"""Export the tandem field line, final ion inventory and phase-space cuts with Postgkyl."""

import json
from pathlib import Path

import numpy as np
import postgkyl as pg
from velocity_print import draw_cut
from phase_podium import export_podium

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "gkeyll-data/1x-tandem"
OUT = ROOT / "simulation-renders/gallery-6"
FRAME = 75
SOURCE_FRAME = 43  # Static source saved again on restart.
FILES = {
    "distribution": f"ion_{FRAME}", "density": f"ion_M0_{FRAME}", "potential": f"field_{FRAME}",
    "source": f"ion_source_{SOURCE_FRAME}", "source_density": f"ion_source_M0_{SOURCE_FRAME}",
    "geometry": "geo_corn_nodes", "geometry_check": "geo_corn_mapc2p",
    "axial_map": "geo_corn_mc2nu_pos_deflated", "field": "geo_int_bmag",
    "velocity_map": "ion_mapc2p_vel", "j_vel": "ion_jacobvel",
    "j_total": "geo_int_jacobtot", "j_geo": "geo_int_jacobgeo",
    "inventory": "ion_integrated_moms", "injection": "ion_source_integrated_moms",
    "lower_wall": "ion_bflux_xlower_integrated_HamiltonianMoments",
    "upper_wall": "ion_bflux_xupper_integrated_HamiltonianMoments",
}
CUTS = (("Central cell", 0), ("Inner throat", 2.02), ("Plug midplane", 3), ("Expander", 5))


def read(key):
    return pg.GData(str(RUN / f"zzim-{FILES[key]}.gkyl"))


def edges(coeff):
    mid = coeff[:, 0] / np.sqrt(2)
    offset = coeff[:, 1] * np.sqrt(1.5)
    np.testing.assert_allclose((mid + offset)[:-1], (mid - offset)[1:], rtol=0,
                               atol=abs(mid).max() * 1e-12)
    return np.r_[mid - offset, mid[-1] + offset[-1]]


def moment(cuts, field_name, moment_name, jac_total, geo, j_vel, v, mu):
    """Integrate the signed mean distributions over all physical velocity cells."""
    field = read(field_name)
    saved = read(moment_name)
    assert field.ctx["basis_type"] == "gkhybrid" and field.ctx["poly_order"] == 1
    for key in ("frame", "time", "mass", "charge"):
        assert field.ctx[key] == saved.ctx[key]
    zeta, eta = field.get_grid()[1:]
    expected_jac = (np.diff(v) / np.diff(zeta))[:, None] * (np.diff(mu) / np.diff(eta))
    np.testing.assert_allclose(j_vel / expected_jac, 1.0, rtol=1e-10)

    # The constant DG mode represents the cell mean of J_total J_vel f.
    planes = field.get_values()[..., 0] / (np.sqrt(8) * jac_total[:, None, None] * j_vel)
    geo_mean = geo[:, 0] / np.sqrt(2)
    integrated = np.einsum("zvm,v,m->z", planes, np.diff(v), np.diff(mu))
    integrated *= (2 * np.pi / field.ctx["mass"]) * jac_total / geo_mean
    reference = np.sum(saved.get_values() * geo, axis=1) / (2 * geo_mean)
    np.testing.assert_allclose(integrated, reference, rtol=1e-9, atol=0)
    check = {
        "max_relative_m0_error": float(np.max(abs(integrated / reference - 1))),
        "axial_cells_checked": len(reference),
        "cut_moments": [{"iz": int(i), "reconstructed": integrated[i], "saved": reference[i]}
                        for i in cuts],
    }
    return planes, reference, field.ctx, check


def endpoint(key, time, run=RUN):
    history = pg.GData(str(run / f"zzim-{FILES[key]}.gkyl"))
    # Use the last (restarted) branch; all four histories saved this exact endpoint.
    np.testing.assert_allclose(history.get_grid()[0][-1], time, atol=1e-12, rtol=0)
    return float(history.get_values()[-1, 0])


def simple_mirror_comparison(time):
    """Read the beam-sourced R=15 scan endpoint when its diagnostics are available."""
    run_id = "1x-beams-R-scan/R-scan/R-15"
    run = ROOT / "gkeyll-data" / run_id
    comparison = {"run": run_id, "frame": FRAME, "time_s": time,
                  "source_per_ion_s": None, "tau_loss_s": None, "loss_source_ratio": 0.835}
    provenance = {"run": run_id, "frame": FRAME, "time_s": time,
                  "thesis": "Chapter Gkeyll Extensions/tex-files/tandem_mirrors.tex, final continuous FDP",
                  "thesis_reported_loss_source_ratio": 0.835}
    sources = {key: f"zzim-{FILES[key]}.gkyl" for key in
               ("inventory", "lower_wall", "upper_wall", "injection", "density", "j_geo")}
    missing = [filename for filename in sources.values() if not (run / filename).is_file()]
    if missing:
        provenance["status"] = "Only the thesis-reported loss/source ratio is available. See NEED_DATA.md."
        provenance["missing"] = missing
        return comparison, provenance

    count = endpoint("inventory", time, run)
    wall = endpoint("lower_wall", time, run) + endpoint("upper_wall", time, run)
    injection = endpoint("injection", time, run)
    m0 = pg.GData(str(run / f"zzim-{FILES['density']}.gkyl"))
    jac = pg.GData(str(run / f"zzim-{FILES['j_geo']}.gkyl"))
    assert m0.ctx["frame"] == FRAME
    np.testing.assert_allclose(m0.ctx["time"], time, rtol=0, atol=1e-12)
    # Exact integral of the saved P1 density and configuration-space Jacobian.
    m0_count = np.diff(m0.get_grid()[0]) @ np.sum(m0.get_values() * jac.get_values(), axis=1) / 2
    np.testing.assert_allclose(m0_count, count, rtol=1e-9)
    assert min(count, wall, injection) > 0
    np.testing.assert_allclose(wall / injection, 0.835, rtol=0, atol=0.0005)
    comparison.update(source_per_ion_s=injection / count, tau_loss_s=count / wall, loss_source_ratio=wall / injection,
                      inventory_per_wb=2*np.pi*count, wall_rate_per_wb_s=2*np.pi*wall)
    provenance.update(status="Computed from saved endpoints with the same convention as the tandem.",
                      sources=sources,
                      reconstructed_inventory_per_wb=2*np.pi*m0_count)
    return comparison, provenance


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    nodes = read("geometry").get_values()
    z_map = read("axial_map").get_values()
    z = z_map[:, 0] / np.sqrt(2)
    z_nodes = edges(z_map)
    r = nodes[:, 0]
    np.testing.assert_allclose(z_nodes, nodes[:, 1], atol=1e-12, rtol=1e-12)
    np.testing.assert_allclose(r, edges(read("geometry_check").get_values()[:, :2]), atol=1e-12)
    np.testing.assert_allclose(z_nodes[[0, -1]], [-5.5, 5.5], atol=1e-8)
    assert np.all(np.diff(z_nodes) > 0) and np.all(r > 0)
    geo = read("j_geo").get_values()
    total = read("j_total").get_values()[:, 0] / np.sqrt(2)
    j_vel = read("j_vel").get_values()[..., 0]
    vm = read("velocity_map").get_values()
    v, mu = edges(vm[:, 0, :2]), edges(vm[0, :, 2:])
    assert np.all(np.diff(v) > 0) and np.all(np.diff(mu) > 0)

    positive = np.flatnonzero(z > 0)
    cuts = [positive[np.argmin(abs(z[positive] - target))] for _, target in CUTS]
    f, density, meta, fcheck = moment(cuts, "distribution", "density", total, geo, j_vel, v, mu)
    s, source, src, scheck = moment(cuts, "source", "source_density", total, geo, j_vel, v, mu)
    assert meta["frame"] == FRAME and src["frame"] == SOURCE_FRAME
    phi = read("potential")
    assert phi.ctx["frame"] == FRAME and phi.ctx["time"] == meta["time"]
    b = read("field").get_values()[:, 0] / np.sqrt(2)

    time = meta["time"]
    count = endpoint("inventory", time)
    wall = endpoint("lower_wall", time) + endpoint("upper_wall", time)
    injection = endpoint("injection", time)
    measure = geo[:, 0] / np.sqrt(2) * np.diff(phi.get_grid()[0])
    np.testing.assert_allclose(measure @ density, count, rtol=1e-9)
    np.testing.assert_allclose(measure @ source, injection, rtol=1e-9)

    assert np.all(density > 0) and count > 0
    result = {
        "run": RUN.name, "frame": FRAME, "time_s": time, "source_frame": SOURCE_FRAME,
        "source_time_s": src["time"], "cuts": [],
        "geometry": {"z_nodes_m": z_nodes.tolist(), "r_nodes_m": r.tolist(),
                     "coil_z_m": [-3.98, -2.02, 2.02, 3.98]},
        "profiles": {"z_m": z.tolist(), "b_t": b.tolist(),
                     "phi_v": (phi.get_values()[:, 0] / np.sqrt(2)).tolist(),
                     "density_m3": density.tolist(), "source_m3_s": source.tolist(),
                     "source_per_ion_s": (source / density).tolist()},
        "confinement": {"source_per_ion_s": injection / count, "tau_loss_s": count / wall, "inventory_per_wb": 2*np.pi*count,
                        "wall_rate_per_wb_s": 2*np.pi*wall, "source_rate_per_wb_s": 2*np.pi*injection,
                        "loss_source_ratio": wall / injection},
    }
    result["confinement"]["simple_mirror"], simple_provenance = simple_mirror_comparison(time)
    print_checks = {}
    for n, ((label, _), iz) in enumerate(zip(CUTS, cuts, strict=True)):
        filename = f"cut-{n}.png"
        print_checks[filename] = draw_cut(
            OUT / filename, label, z[iz], f[iz], s[iz], v * 1e-6, mu / (1e3 * meta["charge"]),
            time, src["time"], FRAME, SOURCE_FRAME)
        result["cuts"].append({"label": label, "z_m": z[iz], "iz": int(iz),
                               "texture": f"res://simulation-renders/gallery-6/{filename}"})

    result["podium"] = export_podium(OUT, [z_nodes, v * 1e-6, mu / (1000 * meta["charge"])], cuts, f, s)
    path = OUT / "tandem.json"
    path.write_text(json.dumps(result, separators=(",", ":"), allow_nan=False) + "\n")
    shipped = json.loads(path.read_text())
    for group in ("geometry", "profiles"):
        for key, values in result[group].items():
            np.testing.assert_array_equal(shipped[group][key], values)
    drawn = np.r_[np.arange(0, len(r) - 1, 4), len(r) - 1]
    mesh_error = np.max(np.abs(r - np.interp(z_nodes, z_nodes[drawn], r[drawn])))
    assert mesh_error < .000407
    manifest = {
        "run": RUN.name, "frame": FRAME, "time_s": time,
        "static_source_frame": SOURCE_FRAME, "static_source_time_s": src["time"],
        "gkeyll_changeset": meta["changeset"], "converter": "gallery-6/tools/export_tandem.py",
        "sources": {key: f"zzim-{name}.gkyl" for key, name in FILES.items()},
        "geometry_and_beam_input": "gkeyll-data/1x-tandem/sim.c",
        "interpretation": "PhD-thesis-latex/Chapter Gkeyll Extensions/tex-files/tandem_mirrors.tex",
        "assets": {
            "tandem.json": "Native corner R and Z (m), 1001 points. Coil Z marks the nominal sim.c throat locations, winding dimensions schematic. All 1000 mapped cell centres and |B| (T), phi (V) use P1 constant coefficient/sqrt(2). Density and source M0 are physical-volume-weighted means. The local injection frequency divides static ion source M0 (frame 43) by total ion M0 (frame 75) in each native axial cell. Static geometry frame 0 at 0 s. Velocity mapping/Jv diagnostics have no frame/time.",
            "phase.glb": "Native cell faces enclose f_i >= each listed Ions level (s^3/m^6, frame 75) and S_i >= each Source level (s^2/m^6, static source frame 43). Absolute thresholds and sRGB colours are recorded in tandem.json under podium.levels and podium.colors. The palettes are sampled from the same physical-value normalizations used in cut-*.png. Axes map (Z, v_parallel, mu) to (+X, -Z, +Y) using podium.scale before scene placement. Full native grid, no smoothing. phase_podium.py checks serialized triangles and enclosed volumes. Podium probe reports the largest signed mean on the selected native Z slice for each field.",
            "sculpture": "Eight azimuths of one saved axisymmetric field line. The 3D tube joins every fourth node and both endpoints, axial scale 0.65 and radial scale 3.2 (4.92 relative). The selectable pointer follows each cut's physical Z. Geometry check in gallery-6/tools/check_sculpture.gd.",
            "cut-*.png": "Side-by-side signed velocity distributions on native physical cell faces, full mu range shown on asinh axis (linear width 1 keV/T), v_parallel cropped to ±3e6 m/s. No interpolation. f is phase-volume-weighted hybrid DG constant mode divided by sqrt(8) J_total_cellmean J_vel. Same formula for S. Signed symlog colour for f from -0.002 to 2 s³/m⁶ with a linear core at ±1e-4 s³/m⁶. Negative numerical means use blue, positive means use Matplotlib inferno. Source colour varies from dark to pale green on a log scale from 1e-5 to 200 s²/m⁶, all lower values dark. Scales fixed across cuts. Source floor from sim.c is 1e-20 s²/m⁶. Source independent of time.",
            "confinement": "Whole-tube injection frequency is integrated injection divided by integrated inventory (s^-1). Loss time is inventory divided by total outward loss rate at final FDP endpoint. Take component 0 of final sample in both outward-positive boundary histories, inventory and injection. Multiply raw numbers/rates by 2π for axisymmetric quantities per unit poloidal flux label; this factor cancels in ratios.",
            "simple_mirror_comparison": simple_provenance,
        },
        "verification": {"distribution": fcheck, "source": scheck,
                         "maximum_sculpture_radius_interpolation_error_m": mesh_error,
                         "printed_cell_centres": print_checks,
                         "inventory_reconstructed_per_wb": 2*np.pi*(measure @ density),
                         "injection_reconstructed_per_wb_s": 2*np.pi*(measure @ source)},
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False,
                                                   allow_nan=False) + "\n")
    print(json.dumps(result["confinement"], indent=2))
    print("Full-grid maximum relative M0 residuals", fcheck["max_relative_m0_error"],
          scheck["max_relative_m0_error"])


if __name__ == "__main__":
    main()
