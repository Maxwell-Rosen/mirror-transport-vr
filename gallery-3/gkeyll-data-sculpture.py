"""Plot the frame-75 ion distribution and time-dilation mask, or export them to Godot."""

import argparse
import hashlib
import json
from io import BytesIO
from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import LineCollection
from matplotlib.colors import LogNorm, to_hex, to_rgba
from matplotlib.lines import Line2D
from matplotlib.patches import Rectangle
from mpl_toolkits.mplot3d.art3d import Line3DCollection, Poly3DCollection
from scipy.constants import elementary_charge

from tools.ion_frame import FILES, FRAME, ROOT, RUN, load_frame
from tools.phase_mesh import SCALE, Surface, boundary_quads, export_glb

ASSET = ROOT / "simulation-renders/gallery-3/time-dilation.glb"
AXES = ("Axial position Z (m)", "Parallel velocity $v_\\parallel$ ($10^6$ m/s)", "Magnetic moment μ (keV/T)")
F_LEVELS = 10.0 ** np.arange(-5, 0, .5)
BETA_LEVELS = [.15, .2, .3, .4, .5, .6, .7, .8, .9, 1.]
F_NORM = LogNorm(1e-8, 1, clip=True)
KEY_BOUNDS = [[.215, .745, .36, .015], [.215, .684, .36, .015]]


def compare_cells(frame):
    peak = np.abs(frame.f).max(axis=(1, 2), keepdims=True)
    if np.any(peak == 0):
        raise ValueError("A spatial cell has no ion distribution to normalize")
    relative_f = np.abs(frame.f) / peak
    core = relative_f >= .1
    slowed = frame.beta < 1
    weight = abs(frame.count)
    local_fraction = (weight * slowed).sum(axis=(1, 2)) / weight.sum(axis=(1, 2))
    worst = int(local_fraction.argmax())
    left, right = frame.faces[0]
    stats = {
        "total_cells": slowed.size,
        "slowed_cells": int(slowed.sum()),
        "core_cells": int(core.sum()),
        "overlap_cells": int((slowed & core).sum()),
        "slowed_cell_fraction": float(slowed.mean()),
        "slowed_absolute_ion_fraction": float(weight[slowed].sum() / weight.sum()),
        "max_relative_f_in_slowed_cells": float(relative_f[slowed].max()),
        "max_local_slowed_absolute_ion_fraction": float(local_fraction[worst]),
        "max_local_z_cell": worst,
        "max_local_z_m": float((left[worst] + right[worst]) / 2),
    }
    return relative_f, stats


def make_surfaces(relative_f, beta, edges, f_levels, beta_levels):
    surfaces = []
    for family, levels in (("IonDistribution", f_levels), ("TimeFactor", beta_levels)):
        for index, level in enumerate(levels, start=1):
            if family == "IonDistribution":
                cells = relative_f >= level
                color = mpl.colormaps["inferno"](F_NORM(level))
                alpha = .055 + .45 * F_NORM(level) ** 6
                prefix = f"F{index:02d}_ge_"
            else:
                cells = beta < level
                color = mpl.colormaps["Blues"](.32 + .55 * (level - .1) / .9)
                alpha = .075 + .18 * ((1 - level) / .9) ** 2
                prefix = f"B{index:02d}_lt_"
            name = prefix + f"{level:.4g}".replace(".", "p")
            surfaces.append(Surface(name, family, float(level), color, float(alpha),
                                    cells, boundary_quads(cells, edges)))
    return surfaces


def boundary_segments(x, y, mask):
    """The mapped cell edges separating the two sides of a 2D mask."""
    i, j = np.nonzero(mask[1:] != mask[:-1])
    vertical = np.stack((np.c_[x[i+1], y[j]], np.c_[x[i+1], y[j+1]]), axis=1)
    i, j = np.nonzero(mask[:, 1:] != mask[:, :-1])
    horizontal = np.stack((np.c_[x[i], y[j+1]], np.c_[x[i+1], y[j+1]]), axis=1)
    return np.concatenate((vertical, horizontal))


def surface_and_profile(layer, edges, mid):
    """Show both velocity halves, with the positive-side trace at the shared zero face."""
    quads = layer.quads
    keep = np.ones(len(quads), dtype=bool)
    # The plotting box already marks its limits. Draw the internal threshold faces.
    for axis, coordinate in enumerate(edges):
        for end in coordinate[[0, -1]]:
            keep &= ~(quads[:, :, axis] == end).all(axis=1)
    profile = boundary_segments(edges[0], edges[2], layer.cells[:, mid, :])
    lines = np.empty((len(profile), 2, 3))
    lines[:, :, 0], lines[:, :, 1], lines[:, :, 2] = profile[:, :, 0], edges[1][mid], profile[:, :, 1]
    return quads[keep], lines


def level_key(fig, bounds, layers, labels):
    key = fig.add_axes(bounds)
    key.imshow([[s.color for s in layers]], extent=(0, len(layers), 0, 1), aspect="auto", interpolation="nearest")
    key.set(yticks=[], xticks=np.arange(len(layers)) + .5, xticklabels=labels)
    key.tick_params(length=0, labelsize=8, pad=2)
    for spine in key.spines.values():
        spine.set_visible(False)
    marker = Rectangle((0, 0), 1, 1, fill=False, edgecolor="white", lw=2, visible=False)
    key.add_patch(marker)
    return key, marker


def plot_figure(edges, surfaces, relative_f, beta, stats, time):
    groups = [[s for s in surfaces if s.family == group] for group in ("IonDistribution", "TimeFactor")]
    fig = plt.figure(figsize=(13, 7.5), facecolor="black")
    fig.text(.055, .928, "Where does time dilation act?", size=25, weight="bold")
    fig.text(.056, .88, f"{RUN.name}   ·   Ion phase space   ·   Frame {FRAME}   ·   t = {time:.6f} s", size=13)
    for y in (.847, .164):
        fig.add_artist(Line2D([.055, .96], [y, y], transform=fig.transFigure, color="white", alpha=.35, lw=.8))

    ax = fig.add_axes([.009, .18, .605, .51], projection="3d", proj_type="ortho", computed_zorder=False)
    mesh = Poly3DCollection([], linewidths=0, edgecolors="none", rasterized=True)
    ax.add_collection3d(mesh)
    profiles = Line3DCollection(np.empty((0, 2, 3)), linewidths=.9)
    ax.add_collection3d(profiles, autolim=False)
    z, v, mu = edges
    mid = int(np.argmin(abs(v)))
    ax.set(xlim=z[[0, -1]], ylim=v[[0, -1]], zlim=mu[[0, -1]],
           xlabel=AXES[0], ylabel=r"$v_\parallel$ ($10^6$ m/s)", zlabel=AXES[2])
    ax.set(xticks=[-2, -1, 0, 1, 2], yticks=[-10, -5, 0, 5, 10], zticks=[0, 30, 60])
    for axis in (ax.xaxis, ax.yaxis, ax.zaxis):
        axis.pane.fill = False
        axis.pane.set_edgecolor((1, 1, 1, .26))
    ax.grid(False)
    ax.view_init(elev=26, azim=-55)
    ax.set_box_aspect(np.array([np.ptp(e) for e in edges]) * SCALE, zoom=1.23)
    fig.text(.055, .792, "Full phase space", size=15, weight="bold")
    fig.text(.246, .792, r"Lines trace the $v_\parallel = 0$ section", size=11)
    fig.text(.055, .738, r"$|\langle f_i\rangle|$ / local peak", size=11)
    fig.text(.055, .677, "Time factor β (unitless)", size=11)
    f_labels = [f"$10^{{{np.log10(s.level):g}}}$" if s.level in F_LEVELS else f"{s.level:.3g}" for s in groups[0]]
    keys = [level_key(fig, KEY_BOUNDS[0], groups[0], f_labels),
            level_key(fig, KEY_BOUNDS[1], groups[1], [f"{s.level:g}" for s in groups[1]])]

    i = stats["max_local_z_cell"]
    fig.text(.658, .792, f"Velocity slice at Z = {stats['max_local_z_m']:+.3f} m", size=15, weight="bold")
    fig.text(.658, .749, f"Largest local share of ion content slowed ({stats['max_local_slowed_absolute_ion_fraction']:.2%})",
             size=10.5)
    detail = fig.add_axes([.666, .383, .293, .31])
    heat = detail.pcolormesh(v, mu, np.maximum(relative_f[i].T, F_NORM.vmin),
                             cmap="inferno", norm=F_NORM, shading="flat", rasterized=True)
    outlines = []
    for layer in groups[1]:
        line = LineCollection(boundary_segments(v, mu, layer.cells[i]), colors=[layer.color], linewidths=1.35)
        detail.add_collection(line)
        outlines.append(line)
    # Enlarge the weakly dilated edge. Dots identify the slowed side of its boundary.
    detail.set(xlim=(-2.5, 2.5), ylim=(0, 12), xlabel=AXES[1], ylabel=AXES[2])
    vx, my = np.meshgrid(np.linspace(-2.45, 2.45, 25), np.linspace(.3, 11.7, 14))
    dots = beta[i, np.searchsorted(v, vx) - 1, np.searchsorted(mu, my) - 1] < 1
    detail.scatter(vx[dots], my[dots], s=3, linewidths=0, color=mpl.colormaps["Blues"](.38))
    detail.set_title("Blue lines trace β levels. Dots mark β < 1.", loc="left", size=10, pad=5)
    cax = fig.add_axes([.666, .259, .293, .017])
    ticks = [1e-8, 1e-6, 1e-4, 1e-2, 1]
    bar = fig.colorbar(heat, cax=cax, orientation="horizontal", ticks=ticks)
    bar.set_ticklabels([r"$\leq10^{-8}$", r"$10^{-6}$", r"$10^{-4}$", r"$10^{-2}$", "1"])
    bar.set_label(r"Ion distribution $|\langle f_i\rangle|$ / peak at this Z")

    measures = [
        (.055, f"{stats['slowed_cell_fraction']:.1%}", "of phase-space cells slowed"),
        (.367, f"{100 * stats['slowed_absolute_ion_fraction']:.3g}%", "of absolute ion content slowed"),
        (.676, f"{stats['max_relative_f_in_slowed_cells']:.2%}", "of the local peak, at most, in a slowed cell"),
    ]
    for x, value, label in measures:
        fig.text(x, .085, value, size=23, weight="bold")
        fig.text(x, .048, label, size=10.5)

    sections = {s.name: surface_and_profile(s, edges, mid) for s in surfaces}
    selected = [None, None]

    def refresh():
        visible = [s for group, index in zip(groups, selected)
                   for s in (group if index is None else [group[index]])]
        faces, colors, lines, inks = [], [], [], []
        for layer in visible:
            quads, profile = sections[layer.name]
            faces.append(quads)
            colors.append(np.tile(to_rgba(layer.color, layer.alpha), (len(quads), 1)))
            lines.append(profile)
            inks.append(np.tile(layer.color, (len(profile), 1)))
        mesh.set_verts(np.concatenate(faces))
        mesh.set_facecolor(np.concatenate(colors))
        profiles.set_segments(np.concatenate(lines))
        profiles.set_color(np.concatenate(inks))
        for j, line in enumerate(outlines):
            line.set_visible(selected[1] is None or selected[1] == j)

    def choose(event):
        for i, (key, marker) in enumerate(keys):
            if event.inaxes is key and event.xdata is not None:
                index = min(int(event.xdata), len(groups[i]) - 1)
                selected[i] = None if index == selected[i] else index
                marker.set_x(index)
                marker.set_visible(selected[i] is not None)
                refresh()
                fig.canvas.draw_idle()

    refresh()
    fig.canvas.mpl_connect("button_press_event", choose)
    return fig


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--f-levels", type=float, nargs="+", default=F_LEVELS,
                        help="distribution contours as fractions of the peak at each Z")
    parser.add_argument("--beta-levels", type=float, nargs="+", default=BETA_LEVELS,
                        help="time-factor contours, each selecting cells strictly below its value")
    parser.add_argument("--figure", type=Path, help="save the labelled figure, e.g. a PNG or PDF")
    parser.add_argument("--glb", type=Path, nargs="?", const=ASSET, help="save a Godot mesh, wall print and JSON manifest")
    parser.add_argument("--show", action="store_true", help="open the rotatable figure (default with no output paths)")
    args = parser.parse_args()
    if args.glb and args.glb.suffix.lower() != ".glb":
        parser.error("--glb requires a .glb file")

    frame = load_frame()
    units = (1, 1e6, 1e3 * elementary_charge)
    edges = [np.r_[left, right[-1]] / unit for (left, right), unit in zip(frame.faces, units)]
    if not all(0 < level <= 1 for level in args.f_levels):
        parser.error("Distribution levels must be in (0, 1]")
    if not all(frame.beta.min() < level <= 1 for level in args.beta_levels):
        parser.error(f"Time-factor levels must be above the saved minimum {frame.beta.min():g} and at most 1")
    relative_f, stats = compare_cells(frame)
    layers = make_surfaces(relative_f, frame.beta, edges, sorted(set(args.f_levels)), sorted(set(args.beta_levels)))
    print(f"{stats['slowed_cells']:,}/{stats['total_cells']:,} cells slowed "
          f"({stats['slowed_cell_fraction']:.2%}), {stats['slowed_absolute_ion_fraction']:.5%} of absolute ion content. "
          f"{stats['overlap_cells']:,} slowed cells reach 10% of their local distribution peak.")
    show = args.show or not (args.glb or args.figure)
    with plt.style.context("dark_background"):
        fig = plot_figure(edges, layers, relative_f, frame.beta, stats, frame.time)
        if args.glb:
            png = BytesIO()
            fig.savefig(png, format="png", dpi=160, facecolor="black")
            print_bytes = png.getvalue()
        if args.figure:
            args.figure.parent.mkdir(parents=True, exist_ok=True)
            if args.glb and args.figure.suffix.lower() == ".png":
                args.figure.write_bytes(print_bytes)
            else:
                fig.savefig(args.figure, dpi=160, facecolor="black")
    if args.glb:
        manifest = {
            "run": RUN.name, "frame": FRAME, "saved_time_s": frame.time, "files": FILES,
            "grid_shape_Z_vparallel_mu": list(frame.beta.shape),
            "IonDistribution": {"threshold": "relative_f >= level", "colormap": "Matplotlib inferno, log10 from 1e-8 to 1",
                                "quantity": "Magnitude of the physical cell-average ion distribution [s^3/m^6], divided by its velocity-space maximum magnitude at the same Z."},
            "TimeFactor": {"threshold": "beta < level", "colormap": "Matplotlib Blues at 0.32 + 0.55*(beta_level-0.1)/0.9",
                           "quantity": "Local update factor beta [1], saved cellwise P0 fdot_multiplier."},
            "contours": [{"node": s.name, "family": s.family, "level": s.level, "sRGB": to_hex(s.color),
                          "opacity": s.alpha, "selected_cells": int(s.cells.sum()), "triangles": 2 * len(s.quads)}
                         for s in layers],
            "distribution": "Divide the constant DG mode by sqrt(8), the velocity Jacobian and the cell-average total configuration Jacobian.",
            "absolute_ion_content": "Sum of absolute signed phase-cell integrals. Each integral uses the mapped phase-space volume including 2*pi/m_i.",
            "coordinates": "Evaluate both faces of the saved p=1 axial and separable velocity maps. Use Z [m], v_parallel [10^6 m/s] and mu [keV/T].",
            "godot_axes": {"+X": "Z [m]", "-Z": "v_parallel [10^6 m/s]", "+Y": "mu [keV/T]"},
            "exhibit_metres_per_axis_unit_Z_vparallel_mu": SCALE.tolist(),
            "domain_min_xyz_m": [edges[0][0] * SCALE[0], edges[2][0] * SCALE[2], -edges[1][-1] * SCALE[1]],
            "domain_max_xyz_m": [edges[0][-1] * SCALE[0], edges[2][-1] * SCALE[2], -edges[1][0] * SCALE[1]],
            "surface": "Exterior faces of the thresholded native cell unions, capped at sampled domain boundaries. Adjacent coplanar faces are merged. No subsampling or interpolation.",
            "statistics_reference": "Slowed cells have beta < 1. Core cells have relative_f >= 0.1.",
            "statistics": stats,
            "wall_print": {"file": args.glb.with_suffix(".png").name,
                           "sha256": hashlib.sha256(print_bytes).hexdigest(),
                           "key_bounds_xywh_from_bottom_left": KEY_BOUNDS,
                           "slice_z_m": stats["max_local_z_m"], "velocity_slice_limits_1e6_m_s": [-2.5, 2.5],
                           "mu_slice_limits_keV_T": [0, 12], "distribution_colour_floor_relative": F_NORM.vmin},
            "verification": {
                "density": "Signed velocity integral against the saved M0 times geometry Jacobian in every axial cell.",
                "max_density_relative_error": float(frame.density_relative_error.max()),
                "mesh": "Reload GLB. Check every triangle corner against mapped face positions within 1e-7 exhibit m and each enclosed volume against the sum of selected cell volumes to 1e-6 relative.",
            },
        }
        try:
            payload = export_glb(layers, edges, manifest)
        except ModuleNotFoundError as exc:
            if exc.name != "trimesh":
                raise
            parser.error("GLB export needs Trimesh. Install it in this Python environment with python -m pip install trimesh")
        manifest["asset"] = {"file": args.glb.name, "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest(),
                             "triangles": sum(2 * len(s.quads) for s in layers)}
        args.glb.parent.mkdir(parents=True, exist_ok=True)
        args.glb.write_bytes(payload)
        args.glb.with_suffix(".png").write_bytes(print_bytes)
        args.glb.with_suffix(".json").write_text(json.dumps(manifest, indent=2, allow_nan=False) + "\n", encoding="utf-8")
        print(f"{args.glb}  ·  {len(payload):,} bytes  ·  {len(layers)} contours  ·  {manifest['asset']['triangles']:,} triangles")

    if show:
        plt.show()
    plt.close(fig)


if __name__ == "__main__":
    main()
