"""Rebuild the archived five-sample pedestal readings."""

import json
from math import sqrt
from pathlib import Path

import numpy as np
from preview_models import five_sample_trial


def step_matrix(matrix, dt, projection):
    identity = np.eye(6)
    k1 = matrix
    k2 = matrix @ projection @ (identity + dt / 2 * k1)
    k3 = matrix @ projection @ (identity + dt / 2 * k2)
    k4 = matrix @ projection @ (identity + dt * k3)
    return projection @ (identity + dt / 6 * (k1 + 2 * k2 + 2 * k3 + k4))


def advance(state, duration, coupling, supply, beta, full, average):
    fast = 1e5
    matrix = np.zeros((6, 6))
    for i in range(3):
        matrix[i, i] = -coupling[i]
        matrix[i, (i + 1) % 3] = -beta * fast
        matrix[i, (i - 1) % 3] = beta * fast
        matrix[i, 3] = coupling[i]
        matrix[i, 5] = supply[i]
    if full:
        matrix[3, :5] = [*coupling, -fast - sum(coupling), 0]
        matrix[4, 3:5] = [fast, -fast]
    projection = np.eye(6)
    if average and not full:
        projection[:3, :3] = 1 / 3
    h = 2.3 / (max(coupling) + beta * sqrt(3) * fast)
    n = int(duration / h)
    result = np.linalg.matrix_power(step_matrix(matrix, h, projection), n) @ state
    tail = duration - n * h
    if tail > 1e-14:
        result = step_matrix(matrix, tail, projection) @ result
    return result, n + int(tail > 1e-14)


def long_trial(feed=None, faster=False, average=False):
    coupling = [1.0, 1.0, 1.0] if feed is None else [3.0, 0.0, 0.0]
    supply = (
        [1.0, 1.0, 1.0]
        if feed is None
        else [3.0 if i == feed else 0.0 for i in range(3)]
    )
    alpha = (
        1 / (sqrt(3) * 1e5)
        if feed is None
        else 10 * sqrt(3) / 1e5 * (10 if faster else 1)
    )
    target = 20 if feed is None else 50
    start = np.array([0.005, 0, 0, 0, 0, 1.0])
    state = start.copy()
    t, total, full = 0.0, 0, False
    rows = [[0, "Start", state[:5].tolist(), start[:5].tolist(), 0, 0]]
    while t < target:
        dt = min(4.7 * sqrt(3) / 1e5 if full else 5.5, target - t)
        state, n = advance(
            state, dt, coupling, supply, 1 if full else alpha, full, average
        )
        t += dt
        total += n
        # Direct RK4 uses its uninterrupted small steps to this same physical time.
        direct, direct_steps = advance(start, t, coupling, supply, 1, True, False)
        rows.append(
            [
                t,
                "Full" if full else "Long",
                state[:5].tolist(),
                direct[:5].tolist(),
                total,
                direct_steps,
            ]
        )
        full = not full
    return rows


def pedestal():
    times, states, stops = five_sample_trial()
    catch = {
        "times": times.tolist(),
        "states": states.tolist(),
        "stops": stops.tolist(),
    }
    values = states[np.searchsorted(times, stops[2:])]
    assert np.array_equal(values[0, 3:], values[1, 3:])
    np.testing.assert_allclose(
        values[:, 4] * 1e5, [2.745819, 2.745819, 5.68791], rtol=2e-6
    )
    count = long_trial()
    assert count[-1][4:] == [40, 1506140]
    np.testing.assert_allclose(count[-1][2], count[-1][3], rtol=3e-7)
    sources = {}
    for feed in (0, 1):
        for faster in (False, True):
            for average in (False, True):
                key = f"{feed}-{int(faster)}-{int(average)}"
                rows = long_trial(feed, faster, average)
                if average:
                    for _, phase, y, *_ in rows:
                        if phase == "Long":
                            np.testing.assert_allclose(y[:3], [y[0]] * 3, atol=1e-13)
                sources[key] = rows
    path = Path(__file__).resolve().parents[1] / "studies/five-sample/pedestal.json"
    data = {"catch": catch, "count": count, "source": sources}
    path.write_text(json.dumps(data, separators=(",", ":"), allow_nan=False) + "\n")


if __name__ == "__main__":
    pedestal()
