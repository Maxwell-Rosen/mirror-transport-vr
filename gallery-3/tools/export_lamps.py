"""Export the two phase-space cuts used by the time dilation mobile."""

import argparse
import json
from pathlib import Path

import numpy as np
import postgkyl as pg
from scipy.constants import elementary_charge


ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "gkeyll-data/1x-beams"
OUTPUT = ROOT / "simulation-renders/gallery-3/manifest.json"
FRAME = 75
# The same outward-going velocity cells at both locations, from the beam to its tail.
VELOCITIES = [41, 42, 44, 45, 46, 47, 48, 52, 57, 63]
FILES = {
    "beta": f"zzim-ion_fdot_multiplier_{FRAME}.gkyl",
    "ion_distribution": f"zzim-ion_{FRAME}.gkyl",
    "axial_map": "zzim-geo_corn_mc2nu_pos_deflated.gkyl",
    "velocity_map": "zzim-ion_mapc2p_vel.gkyl",
    "velocity_jacobian": "zzim-ion_jacobvel.gkyl",
    "total_jacobian": "zzim-geo_int_jacobtot.gkyl",
    "magnetic_field": "zzim-geo_int_bmag.gkyl",
    "density_check": f"zzim-ion_M0_{FRAME}.gkyl",
    "geometry_jacobian": "zzim-geo_int_jacobgeo.gkyl",
}


def mapped_centres(coefficients):
    """Check adjoining physical faces of the piecewise-linear coordinate map."""
    middle = coefficients[:, 0] / np.sqrt(2)
    offset = coefficients[:, 1] * np.sqrt(1.5)
    left, right = middle - offset, middle + offset
    np.testing.assert_allclose(right[:-1], left[1:], rtol=1e-9, atol=1e-13 * np.max(abs(middle)))
    assert np.all(right > left)
    return (left + right) / 2


def source():
    raw = {key: pg.GData(str(RUN / name)) for key, name in FILES.items()}
    beta = raw["beta"].get_values()[..., 0]
    distribution = raw["ion_distribution"]
    coeff = distribution.get_values()
    z = mapped_centres(raw["axial_map"].get_values())
    vm = raw["velocity_map"].get_values()
    v = mapped_centres(vm[:, 0, :2])
    mu = mapped_centres(vm[0, :, 2:]) / (1e3 * elementary_charge)
    jac_vel = raw["velocity_jacobian"].get_values()[..., 0]
    jac_tot = raw["total_jacobian"].get_values()[:, 0] / np.sqrt(2)
    bmag = raw["magnetic_field"].get_values()[:, 0] / np.sqrt(2)
    assert distribution.ctx["basis_type"] == "gkhybrid" and coeff.shape == (*beta.shape, 12)
    assert raw["beta"].ctx["poly_order"] == 0 and np.all((beta > 0) & (beta <= 1))
    assert np.all(jac_vel > 0) and np.all(jac_tot > 0)
    for key in ("beta", "density_check"):
        assert raw[key].ctx["frame"] == distribution.ctx["frame"] == FRAME
        assert raw[key].ctx["time"] == distribution.ctx["time"]
    for a, b in zip(raw["beta"].get_grid(), distribution.get_grid()):
        np.testing.assert_array_equal(a, b)
    positive = np.flatnonzero(z > 0)
    locations = [("Right throat", positive[np.argmax(bmag[positive])]), ("Near midplane", positive[0])]
    dz, dv, dm = map(np.diff, distribution.get_grid())
    gyro_measure = 2 * np.pi / distribution.ctx["mass"]
    m0 = raw["density_check"].get_values()
    jac_geo = raw["geometry_jacobian"].get_values()
    slices = []
    for label, iz in locations:
        # The saved distribution carries the position and velocity Jacobians.
        f = coeff[iz, :, :, 0] / (np.sqrt(8) * jac_vel[iz] * jac_tot[iz])
        phase_volume = dz[iz] * dv[:, None] * dm[None, :] * gyro_measure * jac_vel[iz] * jac_tot[iz]
        density_count = dz[iz] * np.dot(m0[iz], jac_geo[iz]) / 2
        np.testing.assert_allclose(np.sum(f * phase_volume), density_count, rtol=1e-9)
        magnitude = abs(f[VELOCITIES, 0])
        lamps = [
            {"v_cell": j, "v_parallel_m_s": float(v[j]), "relative_f": float(q),
             "beta": float(beta[iz, j, 0])}
            for j, q in zip(VELOCITIES, magnitude / magnitude.max())
        ]
        slices.append({"name": label, "z_cell": int(iz), "z_m": float(z[iz]), "lamps": lamps})
    return {
        "run": "1x-beams", "frame": FRAME, "saved_time_s": distribution.ctx["time"], "files": FILES,
        "mu_cell": 0, "mu_keV_T": float(mu[0]), "reference_period_s": 3.6,
        "brightness_decades": 24, "brightness_floor": 0.15,
        "method": {
            "selection": "Positive-Z cell nearest the midplane and cell of maximum positive-Z cell-centre B. Ten positive parallel velocities in the lowest magnetic moment bin. Indices are zero-based.",
            "coordinates": "Cell centres from physical faces of the saved 1D p=1 axial map and separable ion velocity maps. Magnetic moment in keV/T. The equally spaced clock rings order the selected velocities and do not represent distances.",
            "beta": "Direct cellwise P0 fdot_multiplier value, dimensionless. One turn and one smooth pulse per reference_period_s / beta exhibit seconds. Reference mode uses 1 at every lamp.",
            "relative_f": "Absolute physical cell-average ion distribution, divided by the largest of the ten sampled values in each slice. Physical average = distribution constant mode / (sqrt(8) * velocity Jacobian * cell-average total configuration Jacobian).",
            "brightness": "Peak filament drive = floor + (1-floor) * clamp(1 + log10(relative_f) / brightness_decades, 0, 1). The pulse envelope modulates this between 28% and 100%.",
            "check": "Integrating the signed reconstructed distribution over all velocities recovers the saved M0 density integral in each displayed axial cell, including the configuration Jacobian, to relative tolerance 1e-9.",
        },
        "slices": slices,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="compare the shipped asset to the original diagnostics")
    options = parser.parse_args()
    expected = source()
    if not options.check:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(json.dumps(expected, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    if json.loads(OUTPUT.read_text(encoding="utf-8")) != expected:
        raise SystemExit(f"Saved lamp data differs from {RUN}")
    for cut in expected["slices"]:
        rates = [lamp["beta"] for lamp in cut["lamps"]]
        print(f'{cut["name"]}, Z = {cut["z_m"]:.6f} m: {sum(b < 1 for b in rates)}/{len(rates)} slowed; min beta = {min(rates):.8f}')
