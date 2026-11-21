"""Small persistent view of the opening trial, visible from the atrium."""

import json
from pathlib import Path

import matplotlib
import numpy as np
from matplotlib.colors import ListedColormap
from matplotlib.patches import Patch, Rectangle

matplotlib.use("Agg")
import matplotlib.pyplot as plt

ASSETS = Path(__file__).resolve().parents[2] / "simulation-renders/gallery-4"
EVOLVE, HOLD, ENERGY = "#407d9e", "#dba067", "#ffbd65"


def main():
    data = json.loads((ASSETS / "loss.json").read_text())
    cell = data["examples"]["cut_cell"]
    section = data["slices"][cell["slice_index"]]
    point = cell["corners"][cell["corner_index"]]
    mu = point["mu_kev_t"]
    effective = mu * np.array(data["b_t"]) + data["electric_kev"]
    mask = np.array([list(row) for row in section["mask"]], dtype=int)
    plt.style.use("dark_background")
    fig, (rail, cut) = plt.subplots(1, 2, figsize=(14.4, 4.8))
    fig.subplots_adjust(left=0.071, right=0.974, bottom=0.235, top=0.78, wspace=0.29)
    for ax in (rail, cut):
        ax.spines[["right", "top"]].set_visible(False)
        ax.spines[["bottom", "left"]].set_color("0.65")
        ax.tick_params(labelsize=12)
    rail.plot(data["z_m"], effective, color="white", lw=2.7, label="Potential energy U")
    rail.axhline(point["h_kev"], color=ENERGY, ls="--", lw=1.8, label="Ion energy H")
    rail.scatter([point["z_m"]], [point["h_kev"]], color=ENERGY, marker="D", s=52, zorder=3)
    rail.set(xlim=(-2.5, 2.5), ylim=(0, 70), xticks=[-2.5, -1, 0, 1, 2.5], yticks=range(0, 71, 10))
    rail.set_title("One corner turns back", fontfamily="DejaVu Serif", loc="left", size=21, pad=27)
    rail.set_xlabel("Axial position  Z  (m)", size=14)
    rail.set_ylabel("Energy  (keV)", size=14)
    rail.legend(loc="lower left", ncol=2, frameon=False, fontsize=10, bbox_to_anchor=(0, 1.005), borderaxespad=0)
    v = np.array(data["v_edges_m_s"]) / 1e6
    moments = np.array(data["mu_edges_kev_t"])
    cut.pcolormesh(v, moments, mask,
                   cmap=ListedColormap([HOLD, EVOLVE]), shading="flat", vmin=0, vmax=1)
    iv, im = cell["iv"], cell["im"]
    cut.add_patch(Rectangle((v[iv], moments[im]), v[iv+1] - v[iv], moments[im+1] - moments[im],
                            edgecolor="white", facecolor="none", linewidth=1.5))
    cut.scatter([point["v_m_s"] / 1e6], [mu], marker="+", s=260, lw=2, c="white")
    cut.set(xlim=(-1.6, 1.6), ylim=(0, 4), xticks=[-1.5, -1, -0.5, 0, 0.5, 1, 1.5], yticks=range(5))
    cut.set_title("Seven corners can reach a wall", loc="left", fontfamily="DejaVu Serif", size=21, pad=27)
    cut.set_xlabel("Parallel velocity  v∥  (10⁶ m/s)", size=14)
    cut.set_ylabel("Magnetic moment  μ  (keV/T)", size=14)
    cut.legend(handles=[Patch(color=EVOLVE, label="1  Evolve"), Patch(color=HOLD, label="0  Hold")],
               loc="lower left", bbox_to_anchor=(0, 1.005), borderaxespad=0, frameon=False, ncol=2)
    fig.text(0.071, 0.025, f"Cut cell on the inner slope    ·    Gkeyll  {data['run']}    ·    Frame {data['frame']}, "
             f"t = {data['time_s'] * 1000:.4f} ms    ·    Z = {point['z_m']:+.5f} m    ·    μ = {mu:.4f} keV/T",
             fontsize=13)
    fig.savefig(ASSETS / "entrance.png", dpi=100, facecolor="black")
    plt.close(fig)


if __name__ == "__main__":
    main()
