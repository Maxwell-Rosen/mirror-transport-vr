"""Read the mapped phase cells shared by Gallery 3's mobile and sculpture."""

from dataclasses import dataclass
from pathlib import Path

import numpy as np
import postgkyl as pg

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "gkeyll-data/1x-beams"
FRAME = 75
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


def mapped_faces(coefficients):
    """Evaluate both faces of each 1D p=1 DG map, in native SI units."""
    middle = coefficients[:, 0] / np.sqrt(2)
    offset = coefficients[:, 1] * np.sqrt(1.5)
    left, right = middle - offset, middle + offset
    np.testing.assert_allclose(right[:-1], left[1:], rtol=1e-9, atol=1e-13 * np.max(abs(middle)))
    assert np.all(right > left)
    return left, right


@dataclass
class IonFrame:
    time: float
    faces: tuple  # (left, right) per axis in Z [m], v_parallel [m/s], mu [J/T]
    beta: np.ndarray
    f: np.ndarray  # signed physical cell average [s^3/m^6]
    count: np.ndarray  # signed ion content per phase-space cell
    bmag: np.ndarray
    density_relative_error: np.ndarray


def load_frame():
    raw = {key: pg.GData(str(RUN / name)) for key, name in FILES.items()}
    distribution = raw["ion_distribution"]
    coeff = distribution.get_values()
    beta = raw["beta"].get_values()[..., 0]
    assert distribution.ctx["basis_type"] == "gkhybrid" and distribution.ctx["poly_order"] == 1
    assert coeff.shape == (*beta.shape, 12) and np.all(np.isfinite(coeff[..., 0]))
    assert raw["beta"].ctx["poly_order"] == 0 and np.all((beta > 0) & (beta <= 1))
    for key in ("beta", "density_check"):
        assert raw[key].ctx["frame"] == distribution.ctx["frame"] == FRAME
        assert raw[key].ctx["time"] == distribution.ctx["time"]
    for a, b in zip(raw["beta"].get_grid(), distribution.get_grid(), strict=True):
        np.testing.assert_array_equal(a, b)

    vm = raw["velocity_map"].get_values()
    faces = (mapped_faces(raw["axial_map"].get_values()),
             mapped_faces(vm[:, 0, :2]), mapped_faces(vm[0, :, 2:]))
    assert tuple(len(left) for left, _ in faces) == beta.shape
    jac_vel = raw["velocity_jacobian"].get_values()[..., 0]
    jac_tot = raw["total_jacobian"].get_values()[:, 0] / np.sqrt(2)
    assert np.all(jac_vel > 0) and np.all(jac_tot > 0)
    f = coeff[..., 0] / (np.sqrt(8) * jac_vel * jac_tot[:, None, None])

    dz, dv, dm = map(np.diff, distribution.get_grid())
    measure = dz[:, None, None] * dv[None, :, None] * dm[None, None, :] * (2 * np.pi / distribution.ctx["mass"])
    count = f * (measure * jac_vel * jac_tot[:, None, None])
    m0 = raw["density_check"].get_values()
    jac_geo = raw["geometry_jacobian"].get_values()
    # The DG product integral includes both the constant and linear spatial modes.
    density_count = dz * np.sum(m0 * jac_geo, axis=1) / 2
    integrated = count.sum(axis=(1, 2))
    np.testing.assert_allclose(integrated, density_count, rtol=1e-9, atol=0)
    return IonFrame(
        distribution.ctx["time"], faces, beta, f, count,
        raw["magnetic_field"].get_values()[:, 0] / np.sqrt(2),
        np.abs(integrated - density_count) / np.abs(density_count),
    )
