"""Export the cell-integrated ion content and clocks for the wave rings."""

import argparse
import json

import numpy as np
import postgkyl as pg
from scipy.constants import elementary_charge

if __package__:
    from .ion_frame import FILES, FRAME, ROOT, RUN, load_frame
else:
    from ion_frame import FILES, FRAME, ROOT, RUN, load_frame

OUTPUT = ROOT / "simulation-renders/gallery-3/manifest.json"
# The same outward-going velocity cells at both locations, from the beam to its tail.
VELOCITIES = [41, 42, 44, 45, 46, 47, 48, 52, 57, 63]


def source():
    frame = load_frame()
    # Integrate the saved constant DG mode directly on the computational grid
    # as an independent check of the mapped cell counts used for brightness.
    raw = pg.GData(str(RUN / FILES["ion_distribution"]))
    constant_mode = raw.get_values()[..., 0]
    dz, dv, dm = map(np.diff, raw.get_grid())
    velocity_measure = 2 * np.pi / raw.ctx["mass"]
    z, v, mu = ((left + right) / 2 for left, right in frame.faces)
    mu = mu / (1e3 * elementary_charge)
    positive = np.flatnonzero(z > 0)
    locations = [("Right throat", positive[np.argmax(frame.bmag[positive])]), ("Near midplane", positive[0])]
    slices = []
    for label, iz in locations:
        content = abs(frame.count[iz, VELOCITIES, 0])
        direct = abs(constant_mode[iz, VELOCITIES, 0]) * dz[iz] * dv[VELOCITIES] * dm[0] * velocity_measure / np.sqrt(8)
        np.testing.assert_allclose(content, direct, rtol=1e-12, atol=0)
        lamps = [
            {"v_cell": j, "v_parallel_m_s": float(v[j]), "relative_content": float(q),
             "beta": float(frame.beta[iz, j, 0])}
            for j, q in zip(VELOCITIES, content / content.max(), strict=True)
        ]
        slices.append({"name": label, "z_cell": int(iz), "z_m": float(z[iz]), "lamps": lamps})
    return {
        "run": "1x-beams", "frame": FRAME, "saved_time_s": frame.time, "files": FILES,
        "mu_cell": 0, "mu_keV_T": float(mu[0]), "reference_period_s": 3.6,
        "brightness_decades": 24, "brightness_floor": 0.22, "settle_laps": 4,
        "method": {
            "selection": "Positive-Z cell nearest the midplane and cell of maximum positive-Z cell-centre B. Ten positive parallel velocities in the lowest magnetic moment bin. Indices are zero-based.",
            "coordinates": "Cell centres from physical faces of the saved 1D p=1 axial map and separable ion velocity maps. Magnetic moment in keV/T. Ring radius orders the velocity samples. Angle locates a fixed lamp on the sculpture.",
            "beta": "Direct cellwise P0 fdot_multiplier, dimensionless. Local laps q = beta * exhibit seconds / reference_period_s. With dilation off, beta = 1 in every cell.",
            "relative_content": "Magnitude of the signed ion number integrated over the entire mapped phase-space cell, normalized to the largest of the ten magnitudes on this cut (dimensionless). Includes configuration and velocity Jacobians, native cell widths and 2*pi/ion mass.",
            "brightness": "Peak drive P = floor + (1-floor) * clamp(1 + log10(relative_content) / brightness_decades, 0, 1). The steady drive is P/2. The ten reference lamps always show this profile.",
            "wave": "Illustrative disturbance about the saved profile, on an exhibit clock. Drive at clockwise angle theta from the left notch is (P/2) * (1 + A*cos(theta - 2*pi*q)^3). A = 1 - smoothstep(0, settle_laps, q). Both travel and damping advance on the same local clock. The angular mean is P/2 throughout. Frame 75 supplies the target profile and factors only.",
            "check": "Compare each selected cell count with the direct integral of its raw DG constant mode (relative tolerance 1e-12). Integrating the full signed velocity distribution recovers the saved M0 density integral including the configuration Jacobian at every axial cell (relative tolerance 1e-9).",
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
