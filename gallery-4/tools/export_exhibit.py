"""Build and verify the Gallery 4 instrument data and original thesis prints."""

import argparse
import hashlib
import itertools
import json
import subprocess
from pathlib import Path

import numpy as np
import postgkyl as pg
from grid_comparison import SOURCES, load_geometry
from loss_mask import FILES, FRAME, GALLERY, RUN, SLICES, classify, mesh_edges, traces
from PIL import Image
from scipy.constants import electron_volt

KEV = 1000 * electron_volt
OUT = GALLERY.parent / "simulation-renders/gallery-4"
VELOCITY_CELLS = (40, 48, 45)
MOMENT_CELL = 8
# Axial, parallel velocity, magnetic moment cell indices, then the highlighted corner.
EXAMPLES = {"cut_cell": (291, 37, 11, 1), "beam_well": (200, 32, 0, 2)}
PRINTS = {
    "phase-compression": (
        "4.2",
        "phase-compression.pdf",
        (1536, 768),
        (
            "Constant-energy contours in the published magnetic-only model "
            "B(ℓ)=ℓ⁶, μ=m=1, H=0.1 through 0.6 in model units."
        ),
    ),
    "magnetic-field-coordinates": (
        "4.5",
        "lorentzian-sims/magnetic-field-coordinates.pdf",
        (1536, 692),
        (
            "Published Maxwellian baseline geometry. "
            "The physical and computational rulers locate the same field crest."
        ),
    ),
}


def write_json(path, data, pretty=False):
    path.write_text(
        json.dumps(
            data,
            allow_nan=False,
            indent=2 if pretty else None,
            separators=None if pretty else (",", ":"),
        )
        + "\n",
        encoding="utf-8",
    )


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def path_to_wall(z, u, h):
    """Walk from launch to endpoint through successive P1 traces and the sheath step."""
    peak = int(np.argmax(u))
    forbidden = np.flatnonzero(u > h)
    if len(forbidden):
        i = int(forbidden[0])
        assert i > 0  # The starting point is accessible by construction.
        fraction = (h - u[i - 1]) / (u[i] - u[i - 1])
        stop = z[i - 1] + fraction * (z[i] - z[i - 1])
    else:
        stop = z[-1]
    return float(u[peak]), float(z[peak]), len(forbidden) == 0, float(stop)


def point_record(z, b, electric, mass, iz, fraction, speed, mu):
    """fraction is 0, 1/2, or 1 within axial cell iz. mu is in keV/T."""
    j = 2 * iz
    u = mu * b + electric
    z0 = z[j] + fraction * (z[j + 1] - z[j])
    u0 = u[j] + fraction * (u[j + 1] - u[j])
    h = u0 + 0.5 * mass * speed**2 / KEV
    # Both incident DG traces at each interior face must be retained. Add one
    # more endpoint at the same wall position to represent its prescribed 0 V.
    left = path_to_wall(np.r_[z0, z[j::-1], z[0]], np.r_[u0, u[j::-1], mu * b[0]], h)
    right = path_to_wall(np.r_[z0, z[j + 1 :], z[-1]], np.r_[u0, u[j + 1 :], mu * b[-1]], h)
    return {
        "z_m": float(z0),
        "v_m_s": float(speed),
        "mu_kev_t": float(mu),
        "h_kev": float(h),
        "barrier_kev": [left[0], right[0]],
        "crest_z_m": [left[1], right[1]],
        "open": [left[2], right[2]],
        "reach_z_m": [left[3], right[3]],
    }


def corner_bits(b, electric, v_faces, mu_faces, kinetic_coefficient):
    """Bit k is 1 for a trapped corner k. All energies must share a unit."""
    answer = np.zeros((len(SLICES), len(v_faces), len(mu_faces)), dtype=np.uint8)
    launches = 2 * np.array(SLICES)
    for mu_side in (0, 1):
        mu = mu_faces[:, mu_side]
        u = b[:, None] * mu + electric[:, None]
        left = np.maximum(np.maximum.accumulate(u, axis=0), b[0] * mu)
        right = np.maximum(np.maximum.accumulate(u[::-1], axis=0)[::-1], b[-1] * mu)
        barrier = np.minimum(left, right)
        for z_side, v_side in itertools.product((0, 1), repeat=2):
            traces_at_launch = launches + z_side
            kinetic = kinetic_coefficient * v_faces[:, v_side] ** 2
            h = u[traces_at_launch, None, :] + kinetic[None, :, None]
            trapped = h < barrier[traces_at_launch, None, :]
            bit = 4 * z_side + 2 * v_side + mu_side
            answer |= trapped.astype(np.uint8) << bit
    return answer


def make_loss(data, nodes):
    meta = data["mask"].ctx
    mask = data["mask"].get_values()[..., 0]
    assert mask.shape == (400, 64, 32) and meta["changeset"] == "3e32cda94b0d"
    assert data["potential"].ctx["frame"] == meta["frame"] == FRAME
    assert data["potential"].ctx["time"] == meta["time"]
    assert meta["value_form"] == "nodal" and meta["poly_order"] == 0
    for key in ("position", "bmag", "nodes"):
        assert data[key].ctx["frame"] == 0 and data[key].ctx["time"] == 0.0
    np.testing.assert_array_equal(np.unique(mask), (0, 1))
    vm = data["velocity"].get_values()
    v, moments = traces(vm[:, 0, :2]), traces(vm[0, :, 2:])
    b, phi = traces(data["bmag"].get_values()), traces(data["potential"].get_values())
    predicted = classify(meta["mass"], meta["charge"], b, phi, v, moments)
    np.testing.assert_array_equal(mask, predicted)
    z = np.column_stack((nodes[:-1], nodes[1:])).ravel()
    np.testing.assert_allclose(z, traces(data["position"].get_values()).ravel(), atol=1e-13)
    electric = meta["charge"] * phi.ravel() / KEV
    output = {
        "run": RUN.name,
        "frame": FRAME,
        "time_s": meta["time"],
        "z_m": z.tolist(),
        "b_t": b.ravel().tolist(),
        "electric_kev": electric.tolist(),
        "kinetic_kev_per_v2": 0.5 * meta["mass"] / KEV,
        "v_faces_m_s": v.tolist(),
        "mu_faces_kev_t": (moments / KEV).tolist(),
        "v_edges_m_s": mesh_edges(v).tolist(),
        "mu_edges_kev_t": (mesh_edges(moments) / KEV).tolist(),
        "slices": [],
    }

    def sample(iz, fraction, speed, moment):
        return point_record(z, b.ravel(), electric, meta["mass"], iz, fraction, speed, moment / KEV)

    def cell_record(iz, iv, im):
        center = sample(iz, 0.5, v[iv].mean(), moments[im].mean())
        corners = [
            sample(iz, float(side), speed, moment)
            for side, speed, moment in itertools.product((0, 1), v[iv], moments[im])
        ]
        trapped = sum(not any(corner["open"]) for corner in corners)
        flag = int(mask[iz, iv, im])
        assert (trapped == 8) == bool(flag)
        return {
            "iv": iv,
            "im": im,
            "flag": flag,
            "center": center,
            "corners": corners,
            "trapped_corners": trapped,
        }

    for iz in SLICES:
        section = {
            "iz": iz,
            "z_bounds_m": nodes[iz : iz + 2].tolist(),
            "evolved": int(mask[iz].sum()),
            "mask": ["".join(str(int(bit)) for bit in row) for row in mask[iz].T],
            "presets": [],
            "negative_presets": [],
        }
        for key in ("presets", "negative_presets"):
            for positive_iv in VELOCITY_CELLS:
                iv = positive_iv if key == "presets" else len(v) - 1 - positive_iv
                section[key].append(cell_record(iz, iv, MOMENT_CELL))
        output["slices"].append(section)
    output["examples"] = {
        name: dict(cell_record(iz, iv, im), iz=iz, slice_index=SLICES.index(iz), corner_index=corner)
        for name, (iz, iv, im, corner) in EXAMPLES.items()
    }
    reference = corner_bits(b.ravel(), meta["charge"] * phi.ravel(), v, moments, 0.5 * meta["mass"])
    output["corner_bits_sha256"] = hashlib.sha256(reference.tobytes()).hexdigest()
    return output


def make_grid(edges, field):
    uniform = np.linspace(edges[0], edges[-1], len(edges))
    variation = np.r_[0, np.cumsum(np.abs(np.diff(field)))]
    partitions = {"mapped": edges, "uniform": uniform}
    output = {"run": RUN.name, "frame": 0, "time_s": 0.0, "b_t": field.tolist(), "probes": []}
    for label, faces in partitions.items():
        output[label + "_z_m"] = faces.tolist()
        output[label + "_variation_t"] = np.diff(np.interp(faces, edges, variation)).tolist()
    for z in (0.0, 0.9):
        probe = {"z_m": z, "b_t": float(np.interp(z, edges, field))}
        for label, faces in partitions.items():
            # Choose the right cell if the requested probe falls on a face to map precision.
            probe[label + "_index"] = int(np.searchsorted(faces, z + 1e-12, side="right") - 1)
        output["probes"].append(probe)
    return output


def check_disk(out, data, edges, field):
    loss = json.loads((out / "loss.json").read_text())
    grid = json.loads((out / "grid.json").read_text())
    raw = data["mask"].get_values()[..., 0]
    vm = data["velocity"].get_values()
    np.testing.assert_array_equal(loss["v_faces_m_s"], traces(vm[:, 0, :2]))
    np.testing.assert_array_equal(loss["mu_faces_kev_t"], traces(vm[0, :, 2:]) / KEV)
    assert loss["kinetic_kev_per_v2"] == 0.5 * data["mask"].ctx["mass"] / KEV
    np.testing.assert_array_equal(loss["v_edges_m_s"], mesh_edges(traces(vm[:, 0, :2])))
    np.testing.assert_array_equal(loss["mu_edges_kev_t"], mesh_edges(traces(vm[0, :, 2:])) / KEV)
    np.testing.assert_allclose(loss["z_m"], traces(data["position"].get_values()).ravel(), atol=1e-13)
    np.testing.assert_array_equal(loss["b_t"], traces(data["bmag"].get_values()).ravel())
    np.testing.assert_allclose(
        loss["electric_kev"],
        data["mask"].ctx["charge"] / KEV * traces(data["potential"].get_values()).ravel(),
        rtol=1e-15,
    )
    corner_reference = corner_bits(
        np.array(loss["b_t"]),
        np.array(loss["electric_kev"]),
        np.array(loss["v_faces_m_s"]),
        np.array(loss["mu_faces_kev_t"]),
        loss["kinetic_kev_per_v2"],
    )
    assert hashlib.sha256(corner_reference.tobytes()).hexdigest() == loss["corner_bits_sha256"]
    for index, section in enumerate(loss["slices"]):
        iz = section["iz"]
        decoded = np.array([list(row) for row in section["mask"]], dtype=int).T
        np.testing.assert_array_equal(decoded, raw[iz])
        np.testing.assert_array_equal(corner_reference[index] == 255, decoded)
        np.testing.assert_array_equal(section["z_bounds_m"], edges[iz : iz + 2])
        assert decoded.sum() == section["evolved"]
        examples = [ex for ex in loss["examples"].values() if ex["slice_index"] == index]
        for preset in section["presets"] + section["negative_presets"] + examples:
            iv, im = preset["iv"], preset["im"]
            center = preset["center"]
            # Independent reference at cell centre from constant modes, and unrounded raw bits.
            kinetic = 0.5 * data["mask"].ctx["mass"] * (vm[iv, im, 0] / np.sqrt(2)) ** 2 / KEV
            mu = vm[iv, im, 2] / np.sqrt(2) / KEV
            electric = (
                data["mask"].ctx["charge"] * data["potential"].get_values()[iz, 0] / np.sqrt(2) / KEV
            )
            h = kinetic + mu * data["bmag"].get_values()[iz, 0] / np.sqrt(2) + electric
            np.testing.assert_allclose(
                [center["z_m"], center["v_m_s"], center["mu_kev_t"], center["h_kev"]],
                [edges[iz : iz + 2].mean(), vm[iv, im, 0] / np.sqrt(2), mu, h],
                rtol=2e-14,
                atol=1e-14,
            )
            assert preset["flag"] == int(decoded[iv, im]) == int(raw[iz, iv, im])
            corner_mask = sum(1 << k for k, c in enumerate(preset["corners"]) if not any(c["open"]))
            assert corner_mask == corner_reference[index, iv, im]
            for pt in [center] + preset["corners"]:
                assert pt["reach_z_m"][0] <= pt["z_m"] <= pt["reach_z_m"][1]
                np.testing.assert_array_equal(pt["open"], pt["h_kev"] >= np.array(pt["barrier_kev"]))
                for direction, wall in enumerate((edges[0], edges[-1])):
                    stop = pt["reach_z_m"][direction]
                    if pt["open"][direction]:
                        assert stop == wall
                    else:
                        # For this run all selected reflected paths turn within a P1 interval.
                        cell = np.searchsorted(edges, stop, side="right") - 1
                        frac = (stop - edges[cell]) / (edges[cell + 1] - edges[cell])
                        local_u = pt["mu_kev_t"] * np.array(
                            loss["b_t"][2 * cell : 2 * cell + 2]
                        ) + np.array(loss["electric_kev"][2 * cell : 2 * cell + 2])
                        np.testing.assert_allclose(
                            pt["h_kev"], np.interp(frac, (0, 1), local_u), atol=2e-9
                        )
    np.testing.assert_array_equal([s["evolved"] for s in loss["slices"]], [1318, 450, 0])
    np.testing.assert_array_equal(
        [p["trapped_corners"] for p in loss["slices"][0]["presets"]], [8, 0, 6]
    )
    cut = loss["examples"]["cut_cell"]
    assert cut["flag"] == 0 and cut["trapped_corners"] == 1
    assert not any(cut["corners"][cut["corner_index"]]["open"])
    # On the near axial face the energy boundary cuts a visible wedge from
    # the mapped velocity cell. The fraction is a face area, not an ion count.
    iz, iv, im = cut["iz"], cut["iv"], cut["im"]
    moment = np.linspace(*loss["mu_faces_kev_t"][im], 1001)
    field_trace = np.array(loss["b_t"])
    u = field_trace[:, None] * moment + np.array(loss["electric_kev"])[:, None]
    left = np.maximum(u[: 2 * iz + 1].max(axis=0), field_trace[0] * moment)
    right = np.maximum(u[2 * iz :].max(axis=0), field_trace[-1] * moment)
    delta = np.minimum(left, right) - u[2 * iz]
    v_critical = np.sqrt(np.maximum(0.0, delta) / loss["kinetic_kev_per_v2"])
    v0, v1 = loss["v_faces_m_s"][iv]
    fraction = np.trapezoid(np.clip((v_critical - v0) / (v1 - v0), 0, 1)) / (len(moment) - 1)
    assert 0.1723 < fraction < 0.1725
    beam = loss["examples"]["beam_well"]
    assert beam["flag"] == 1 and beam["trapped_corners"] == 8
    probe = beam["corners"][beam["corner_index"]]
    assert abs(probe["mu_kev_t"]) < 1e-15 and abs(probe["z_m"]) < 1e-12
    # Repeat the test on the electric field alone. This lowest-moment face
    # demonstrates trapping by the off-centre potential peaks of the beam run.
    electric_trace = data["mask"].ctx["charge"] * traces(data["potential"].get_values()).ravel() / KEV
    electric_only = point_record(
        np.array(loss["z_m"]),
        np.array(loss["b_t"]),
        electric_trace,
        data["mask"].ctx["mass"],
        beam["iz"],
        0,
        probe["v_m_s"],
        0.0,
    )
    assert not any(electric_only["open"])
    for key in ("barrier_kev", "reach_z_m"):
        np.testing.assert_allclose(probe[key], electric_only[key], atol=1e-12, rtol=0)
    np.testing.assert_allclose(probe["reach_z_m"], [-0.1045322733, 0.1045322733], atol=1e-9)
    np.testing.assert_array_equal(grid["mapped_z_m"], edges)
    np.testing.assert_array_equal(grid["b_t"], field)
    for label in ("uniform", "mapped"):
        faces = np.array(grid[label + "_z_m"])
        delta = np.array(grid[label + "_variation_t"])
        assert len(faces) == 401 and (np.diff(faces) > 0).all()
        np.testing.assert_array_equal(faces[[0, -1]], edges[[0, -1]])
        # Integrate each cell directly instead of differencing cumulative variation.
        for i, (lo, hi) in enumerate(itertools.pairwise(faces)):
            inside = edges[(edges > lo) & (edges < hi)]
            b = np.interp(np.r_[lo, inside, hi], edges, field)
            np.testing.assert_allclose(np.abs(np.diff(b)).sum(), delta[i], rtol=0, atol=2e-14)
        for probe in grid["probes"]:
            i, z = probe[label + "_index"], probe["z_m"]
            assert faces[i] <= z + 1e-12 < faces[i + 1]
            np.testing.assert_allclose(probe["b_t"], np.interp(z, edges, field), atol=1e-13)
    return {
        "phase_cells_checked": int(raw.size),
        "evolved_cells": int(raw.sum()),
        "held_cells": int(raw.size - raw.sum()),
        "shipped_mask_bits_checked": len(SLICES) * 64 * 32,
        "mapped_and_equal_grid_cells_checked": 800,
        "phase_cell_corners_checked_in_joules_and_kev": int(corner_reference.size * 8),
        "probe_states_checked": 20,
    }


def make_prints(thesis, out):
    result = []
    for name, (number, filename, size, description) in PRINTS.items():
        relative = Path("Chapter Gkeyll POA simulations/figures") / filename
        source = thesis / relative
        subprocess.run(
            ["pdftoppm", "-singlefile", "-png", "-scale-to", "1536", str(source), str(out / name)],
            check=True,
        )
        png = out / f"{name}.png"
        with Image.open(png) as image:
            image.load()
            assert image.size == size
        result.append(
            {
                "asset": png.name,
                "figure": number,
                "source": str(relative),
                "pdf_sha256": sha256(source),
                "png_sha256": sha256(png),
                "pixels": size,
                "quantity": description,
            }
        )
    return result


def main(source, thesis, out):
    out.mkdir(exist_ok=True, parents=True)
    data = {key: pg.GData(str(source / filename)) for key, filename in FILES.items()}
    edges, field = load_geometry(source)
    write_json(out / "loss.json", make_loss(data, edges))
    write_json(out / "grid.json", make_grid(edges, field))
    checks = check_disk(out, data, edges, field)
    figures = make_prints(thesis, out)
    manifest = {
        "run": RUN.name,
        "solver_changeset": data["mask"].ctx["changeset"],
        "converter": "gallery-4/tools/export_exhibit.py",
        "source_directory": "gkeyll-data/1x-beams/",
        "loss": {
            "asset": "loss.json",
            "sha256": sha256(out / "loss.json"),
            "frame": FRAME,
            "saved_time_s": data["mask"].ctx["time"],
            "species": "ion",
            "mass_kg": data["mask"].ctx["mass"],
            "charge_c": data["mask"].ctx["charge"],
            "phase": "First orbit-average phase. sim.c and slurm-7132.out identify the Loss cone multiplier.",
            "sources": FILES,
            "quantity": "Cellwise-constant ion distribution time-derivative multiplier, nodal order 0. "
            "1 = evolve (all corners trapped), 0 = hold (at least one corner reaches a wall).",
            "sampling": "Three unfiltered native cuts in (signed v_parallel, mu). Each mask[im][iv] "
            "character is the exact bit at (iz,iv,im). Z[m], v_parallel[m/s], mu[keV/T].",
            "selected_axial_cells": SLICES,
            "positive_velocity_cells": VELOCITY_CELLS,
            "negative_velocity_cells": [63 - i for i in VELOCITY_CELLS],
            "magnetic_moment_cell": MOMENT_CELL,
            "linked_probe": "Every one of the 6,144 cells on the three cuts can be selected. "
            "Bounds use the stitched physical map edges. Computations use both incident native "
            "velocity-map traces and the saved mass via kinetic_kev_per_v2 = m_i/(2 keV in joules). "
            "The reference SHA-256 covers 6,144 bytes in [slice,iv,im] order, one trapped bit per corner.",
            "cut_cell": "Inner slope, (iz,iv,im)=(291,37,11). Only corner 1 is trapped. "
            "The other seven can reach a wall, so the saved flag is passing (0). On the lower "
            "axial face the Hamiltonian-trapped region covers about 17.24% of the physical "
            "velocity-cell area (trapezoidal integration of the critical speed at 1,001 moment samples).",
            "beam_well": "Midplane, (iz,iv,im)=(200,32,0). All eight corners are trapped. Corner 2 "
            "has zero magnetic moment to roundoff and turns on both electrostatic shoulders. "
            "Off-centre density peaks near the injected beams’ turning points produce the well, "
            "as described in Chapter Gkeyll POA simulations/tex-files/results_lorentzian.tex.",
            "profiles": "Flattened left and right P1 traces in increasing Z, both field traces kept at shared faces. "
            "Static physical Z and magnetic field B[T] from geometry frame 0 (0 s), q_i phi[keV] "
            "from the frame-2 DG electrostatic potential. The run-wide velocity map stores no frame or time. "
            "Modal endpoint values are c0/sqrt(2) +/- sqrt(3/2) c1.",
            "classifier": "H = m_i v_parallel^2/2 + mu B + q_i phi. Use piecewise-linear U=mu B + q_i phi. "
            "Take its maximum on each path, including its launch point, both DG traces, and the "
            "grounded conducting-sheath endpoint mu B_wall + q_i * 0 V. H >= E_wall opens that path. "
            "The first forbidden segment gives the turning Z by linear interpolation.",
            "corners": "Index = 4*z_side + 2*v_side + mu_side. Side 0 means the lower physical face, side 1 the "
            "upper. Center probes use the midpoint of each mapped cell. No population weighting.",
            "display": "The route reveal is exhibit time within one frozen snapshot. Point energies and wall "
            "access do not represent a time-resolved orbit or particle flux. The cut-cell detail plots native "
            "traces within 0.020 m of the right crest on an independent linear energy axis in keV.",
        },
        "entrance": {
            "asset": "entrance.png",
            "source": "loss.json",
            "converter": "gallery-4/tools/entrance_print.py",
            "run": RUN.name,
            "frame": FRAME,
            "saved_time_s": data["mask"].ctx["time"],
            "cell": EXAMPLES["cut_cell"][:3],
            "corner_index": EXAMPLES["cut_cell"][3],
            "quantities": "Only trapped corner of the inner-slope cut cell and native ion multiplier. Physical axial "
            "position (m), signed velocity (m/s), magnetic moment (keV/T), H and U (keV).",
        },
        "grid": {
            "asset": "grid.json",
            "sha256": sha256(out / "grid.json"),
            "frame": 0,
            "saved_time_s": 0.0,
            "sources": SOURCES,
            "units": {"mapped_z_m": "m", "uniform_z_m": "m", "b_t": "T", "variation": "T"},
            "sampling": "401 native axial Z nodes checked against both traces of the coordinate map. "
            "B(Z) interpolates the continuous corner-field P1 traces in physical metres. "
            "The independent surface diagnostic agrees with the field at left faces to 2 nT.",
            "comparison": "The uniform reference resamples B(Z) in 400 equal physical cells with the same endpoints. "
            "For each cell variation sums absolute field increments across all interior native faces. "
            "A probe within 1 pm of a face uses the cell on its right. Width in mm is 1000*(Zright-Zleft).",
            "display": "Motion between the two grids diagrams cell placement at fixed B(Z). The mapped grid remains "
            "static in the simulation. The local face magnifier has a physical Z ruler.",
        },
        "velocity_grid": {
            "asset": "velocity.json",
            "converter": "gallery-4/tools/velocity_grid.py",
            "provenance": "The asset records its diagnostic sources, dimensions, transformations and verification.",
        },
        "prints": {
            "source": "Maxwell Rosen, PhD thesis, PhD-thesis-latex",
            "caption_source": "Chapter Gkeyll Foundations/tex-files/nonuniform-grids.tex",
            "conversion": "Full original single-page PDFs rasterized without cropping at 1536 pixels on "
            "the long edge with pdftoppm. RGB PNGs retain the published axes and scales.",
            "figures": figures,
        },
        "verification": checks,
    }
    write_json(out / "manifest.json", manifest, pretty=True)
    print(json.dumps(checks, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=RUN)
    parser.add_argument("--thesis", type=Path, default=Path.home() / "Documents/PhD-thesis-latex")
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    main(args.source, args.thesis, args.out)
