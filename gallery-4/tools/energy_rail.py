"""Plot the three proposed speed settings on the saved frame-2 energy profile."""

import matplotlib
import numpy as np
import postgkyl as pg
from loss_mask import FILES, FRAME, GALLERY, RUN, traces
from scipy.constants import electron_volt

matplotlib.use("Agg")
import matplotlib.pyplot as plt

KEV = 1000 * electron_volt


def main():
    phi_file = pg.GData(str(RUN / FILES["potential"]))
    mask_file = pg.GData(str(RUN / FILES["mask"]))
    assert phi_file.ctx["time"] == mask_file.ctx["time"]
    z = traces(pg.GData(str(RUN / FILES["position"])).get_values())
    bmag = traces(pg.GData(str(RUN / FILES["bmag"])).get_values())
    phi = traces(phi_file.get_values())
    vm = pg.GData(str(RUN / FILES["velocity"])).get_values()
    velocities = traces(vm[:, 0, :2])
    moments = traces(vm[0, :, 2:])
    mask = mask_file.get_values()[..., 0]
    mass, charge = mask_file.ctx["mass"], mask_file.ctx["charge"]
    iz, im = 200, 8
    mu = moments[im].mean()
    u = (mu * bmag + charge * phi) / KEV
    walls = mu * bmag[[0, -1], [0, -1]] / KEV  # Grounded endpoints
    barriers = (max(u[:iz + 1].max(), walls[0]), max(u[iz:].max(), walls[1]))
    np.testing.assert_allclose(barriers, 22.91619, atol=1e-5)

    plt.style.use("dark_background")
    fig, axes = plt.subplots(1, 3, figsize=(13, 5), sharex=True, sharey=True)
    fig.subplots_adjust(left=.065, right=.98, bottom=.27, top=.72, wspace=.12)
    fig.text(.065, .91, "Can this ion clear the ridge?", fontsize=23, weight="bold")
    fig.text(.065, .82, f"1x-beams  ·  frame {FRAME}  ·  t = {phi_file.ctx['time'] * 1000:.6f} ms"
             f"  ·  Z = {z[iz].mean():+.5f} m  ·  μ = {mu / KEV:.4f} keV/T")
    settings = ((40, "Starting ion", 8), (48, "Faster ion", 0), (45, "Inspect edge cell", 6))
    for ax, (iv, label, expected_count) in zip(axes, settings, strict=True):
        speed = velocities[iv].mean()
        energy = .5 * mass * speed**2 / KEV + u[iz].mean()
        count = 0
        for moment in moments[im]:
            profile = (moment * bmag + charge * phi) / KEV
            for side in (0, 1):
                k = 2 * iz + side
                path = profile.ravel()
                barrier = min(max(path[:k + 1].max(), moment * bmag[0, 0] / KEV),
                              max(path[k:].max(), moment * bmag[-1, 1] / KEV))
                count += np.count_nonzero(path[k] + .5 * mass * velocities[iv]**2 / KEV < barrier)
        assert count == expected_count and mask[iz, iv, im] == int(count == 8)
        ax.plot(z.ravel(), u.ravel(), color="white", lw=2)
        ax.axhline(energy, color="#ffb95f", ls="--", lw=1.8)
        ax.plot(z[iz].mean(), energy, "o", color="#ffb95f")
        ax.set(xlim=(-2.5, 2.5), ylim=(0, 34), xticks=[-2.5, 0, 2.5],
               xlabel="Axial position Z (m)")
        ax.set_title(f"{label}   ·   {energy:.2f} keV", fontsize=12)
        ax.text(.5, -.33, f"{count}/8 trapped corners   ·   {'Evolve' if count == 8 else 'Hold'}",
                transform=ax.transAxes, ha="center", weight="bold")
    axes[0].set_ylabel("Energy (keV)")
    fig.text(.065, .034, "White ridge   Effective potential U at the selected cell’s central μ"
             "       Dashed line   Total energy H at the cell centre", fontsize=10)
    target = GALLERY / "sketches/energy-rail.png"
    target.parent.mkdir(exist_ok=True)
    fig.savefig(target, dpi=140, metadata={"Description": "Native mapped Z faces and P1 traces. "
                "Corner counts tested against frame-2 saved bits. " + ", ".join(FILES.values())})
    plt.close(fig)


if __name__ == "__main__":
    main()
