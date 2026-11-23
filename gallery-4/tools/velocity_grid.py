"""Export the signed distribution in the Gallery 4 midplane-adjacent phase-space cut."""

import json
from pathlib import Path

import numpy as np
import postgkyl as pg
from export_exhibit import make_loss
from loss_mask import FILES as MASK_FILES
from loss_mask import FRAME, RUN, SLICES, mesh_edges, traces
from scipy.constants import electron_volt

OUT = Path(__file__).resolve().parents[2] / "simulation-renders/gallery-4"
SOURCES = {
    "distribution": f"zzim-ion_{FRAME}.gkyl",
    "density": f"zzim-ion_M0_{FRAME}.gkyl",
    "mask": MASK_FILES["mask"],
    "velocity_map": MASK_FILES["velocity"],
    "axial_map": MASK_FILES["position"],
    "velocity_jacobian": "zzim-ion_jacobvel.gkyl",
    "total_jacobian": "zzim-geo_int_jacobtot.gkyl",
    "geometry_jacobian": "zzim-geo_int_jacobgeo.gkyl",
}


def export(frame):
    sources = {key: name.replace(f"_{FRAME}.gkyl", f"_{frame}.gkyl") for key, name in SOURCES.items()}
    files = {key: name.replace(f"_{FRAME}.gkyl", f"_{frame}.gkyl") for key, name in MASK_FILES.items()}
    fields = {key: pg.GData(str(RUN / name)) for key, name in files.items()}
    loss = make_loss(fields, fields["nodes"].get_values()[:, 1], frame)
    suffix = "" if frame == FRAME else f"-{frame}"
    (OUT / f"loss{suffix}.json").write_text(json.dumps(loss, separators=(",", ":")) + "\n")
    raw = {key: pg.GData(str(RUN / name)) for key, name in sources.items()}
    distribution = raw["distribution"]
    zeta, eta = distribution.get_grid()[1:]
    iz = SLICES[0]
    time = distribution.ctx["time"]
    assert distribution.ctx["basis_type"] == "gkhybrid" and distribution.ctx["poly_order"] == 1
    for key in ("distribution", "mask", "density"):
        assert raw[key].ctx["frame"] == frame and raw[key].ctx["time"] == time
    for axis, mask_axis in zip(distribution.get_grid(), raw["mask"].get_grid(), strict=True):
        np.testing.assert_array_equal(axis, mask_axis)
    cut = loss["slices"][0]
    assert loss["run"] == RUN.name and loss["frame"] == frame and loss["time_s"] == time and cut["iz"] == iz
    flags = np.array([[int(bit) for bit in row] for row in cut["mask"]]).T
    if loss["mask_origin"] == "saved":
        np.testing.assert_array_equal(flags, raw["mask"].get_values()[iz, :, :, 0])

    vm = raw["velocity_map"].get_values()
    v = mesh_edges(traces(vm[:, 0, :2]))
    mu = mesh_edges(traces(vm[0, :, 2:]))
    z = mesh_edges(traces(raw["axial_map"].get_values()))
    np.testing.assert_allclose(v, loss["v_edges_m_s"], atol=1e-12, rtol=1e-12)
    np.testing.assert_allclose(mu / (1000 * electron_volt), loss["mu_edges_kev_t"], atol=1e-14, rtol=1e-12)
    np.testing.assert_allclose(z[iz:iz+2], cut["z_bounds_m"], atol=1e-12)
    jac_v = raw["velocity_jacobian"].get_values()[..., 0]
    jac_total = raw["total_jacobian"].get_values()[:, 0] / np.sqrt(2)
    assert np.all(jac_v > 0) and np.all(jac_total > 0)
    # Verify the velocity Jacobian independently from the physical and computational face widths.
    expected_jv = (np.diff(v) / np.diff(zeta))[:, None] * (np.diff(mu) / np.diff(eta))[None, :]
    np.testing.assert_allclose(jac_v / expected_jv, 1.0, rtol=1e-11)
    weighted = distribution.get_values()[..., 0] / np.sqrt(8)
    f = weighted / (jac_v * jac_total[:, None, None])
    assert np.all(np.isfinite(f))

    # The volume-averaged density uses the DG product of M0 with the geometry Jacobian.
    jac_geo_coeff = raw["geometry_jacobian"].get_values()
    jac_geo = jac_geo_coeff[:, 0] / np.sqrt(2)
    saved_density = np.sum(raw["density"].get_values() * jac_geo_coeff, axis=1) / (2 * jac_geo)
    vel_integral = np.einsum('zvm,v,m->z', f, np.diff(v), np.diff(mu))
    density = (2 * np.pi / distribution.ctx["mass"]) * (jac_total / jac_geo) * vel_integral
    np.testing.assert_allclose(density, saved_density, rtol=1e-11, atol=0)
    result = {
        "run": RUN.name, "frame": frame, "time_s": time, "axial_cell": iz,
        "zeta_edges": zeta.tolist(), "eta_edges": eta.tolist(),
        "f_rows": f[iz].T.tolist(), "peak_abs_f": float(np.max(np.abs(f[iz]))),
        "provenance": {
            "converter": "gallery-4/tools/velocity_grid.py", "sources": sources | files,
            "quantity": "Signed physical ion distribution cell average in s^3/m^6. Array indices [i_mu][i_v]. Divide hybrid DG constant mode by sqrt(8), the velocity Jacobian and the cell-mean total configuration Jacobian.",
            "coordinates": "Computational coordinates zeta and eta are the native dimensionless grid faces. The physical faces, z bounds in m and classification are shared with the matching loss asset (slices[0]).",
            "display": "Flat native-cell colour uses log10(abs(f)/reference), clamped to [-6,0]. Reference is the largest midplane absolute cell mean across the three displayed frames. All signed cell averages are retained here. The cyan staircase traces changes of the two-wall classification. Zoom selects native faces iv=24..40 and im=0..8 inclusive, with unchanged cell values.",
            "reference": "Rosen thesis, ch. 4, Velocity-Space Maps (nonuniform-grids.tex).",
        },
        "verification": {
            "native_mask_bits_checked": int(flags.size),
            "signed_negative_cells": int((f[iz] < 0).sum()),
            "density_unit": "m^-3, physical-volume-weighted average in each axial cell",
            "density_check": {str(i): {"integrated": density[i], "saved": saved_density[i]}
                              for i in (iz, SLICES[-1])},
            "all_axial_cells_checked": len(density),
            "max_relative_density_error": float(np.max(np.abs(density / saved_density - 1))),
        },
    }
    path = OUT / f"velocity{suffix}.json"
    path.write_text(json.dumps(result, separators=(",", ":"), allow_nan=False) + "\n")
    shipped = json.loads(path.read_text())
    np.testing.assert_array_equal(shipped["f_rows"], f[iz].T)
    np.testing.assert_array_equal(shipped["zeta_edges"], zeta)
    np.testing.assert_array_equal(shipped["eta_edges"], eta)
    return {"frame": frame, "time_s": time, "velocity": path.name, "loss": f"loss{suffix}.json",
            "mask_origin": loss["mask_origin"], "sources": sources | files,
            "max_relative_density_error": result["verification"]["max_relative_density_error"]}


if __name__ == "__main__":
    from hashlib import sha256
    snapshots = [export(frame) for frame in (2, 40, 75)]
    path = OUT / "manifest.json"
    manifest = json.loads(path.read_text())
    manifest["velocity_grid"]["snapshots"] = snapshots
    manifest["loss"]["sha256"] = sha256((OUT / "loss.json").read_bytes()).hexdigest()
    path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(snapshots)
