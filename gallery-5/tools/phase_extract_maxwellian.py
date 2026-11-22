"""Run with: python extract.py /path/to/1x-maxw /path/to/output"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
import postgkyl as pg


FRAMES = [0, 10, 20, 30, 40, 50, 75]
PROBES = [0., 0.98, 2.5]
SHA256 = '5e1253b7bae9d882b6b91d3427848d606b1b0c0bd091fcca4423cb97db417e55'
MAP = 'geo_corn_mc2nu_pos_deflated'


def faces(coeff):
    """Join the left/right p=1 traces of a continuous, separable map."""
    center, slope = coeff.T / np.sqrt(2.)
    half_width = np.sqrt(3.) * slope
    left, right = center - half_width, center + half_width
    eps = np.finfo(float).eps * np.max(abs(center)) * 16
    np.testing.assert_allclose(left[1:], right[:-1], rtol=0, atol=eps)
    result = np.r_[left[0], (right[:-1] + left[1:]) / 2, right[-1]]
    if np.any(np.diff(result) <= 0):
        raise ValueError('Non-increasing map')
    return result


def moment(coeff, geo):
    """Integrate the DG product using orthonormality in the reference cell."""
    return np.sum(coeff * geo, axis=1) / (np.sqrt(2.) * geo[:, 0])


def extract(run, output):
    if hashlib.sha256((run / 'sim.c').read_bytes()).hexdigest() != SHA256:
        raise ValueError('sim.c does not match the audited campaign')
    inputs = {}
    def read(quantity, frame=None):
        name = 'zzim-' + quantity + ('' if frame is None else f'_{frame}') + '.gkyl'
        d = pg.load(str(run / name))
        saved_frame, time = d.ctx.get('frame'), d.ctx.get('time')
        if frame is not None and (saved_frame != frame or time is None):
            raise ValueError(f'Unexpected header in {name}')
        inputs[name] = dict(frame=saved_frame, time_s=time)
        return d

    z_edges = faces(read(MAP).values)
    vmap = read('ion_mapc2p_vel').values
    v_edges = faces(vmap[:, 0, :2])
    mu_edges = faces(vmap[0, :, 2:])
    vel_j = read('ion_jacobvel').values[..., 0]
    total_j = read('geo_int_jacobtot').values[:, 0] / np.sqrt(2.)
    geo = read('geo_int_jacobgeo').values
    bmag = read('geo_int_bmag').values[:, 0] / np.sqrt(2.)

    dist = read('ion', 75)
    if (dist.values.shape != (400, 64, 32, 12) or dist.ctx['time'] != 0.500150
            or dist.ctx['basis_type'] != 'gkhybrid' or dist.ctx['poly_order'] != 1):
        raise ValueError('Unexpected phase-space grid, basis, or saved time')
    mass = dist.ctx['mass']
    joules_per_ev = abs(dist.ctx['charge'])  # This run uses singly charged ions.
    def physical_mean(d):
        return d.values[..., 0] / np.sqrt(8.) / vel_j / total_j[:, None, None]
    f = physical_mean(dist)
    del dist
    source = physical_mean(read('ion_source', 0))
    factor = (2 * np.pi / mass) * total_j / (geo[:, 0] / np.sqrt(2.))
    area = np.diff(v_edges)[:, None] * np.diff(mu_edges)
    profiles, times = [], []
    for frame in FRAMES:
        d = read('ion_M0', frame)
        profiles.append(moment(d.values, geo))
        times.append(d.ctx['time'])
    source_ref = moment(read('ion_source_M0', 0).values, geo)

    checks = {}
    for name, values, ref, unit in [('density', f, profiles[-1], 'm^-3'),
                                    ('source_moment', source, source_ref, 'm^-3 s^-1')]:
        integral = factor * np.sum(values * area, axis=(1, 2))
        residual = np.abs((integral - ref) / ref)
        if not np.all(residual <= 1e-9):
            raise ValueError(f'{name} moment check failed: {residual.max()}')
        checks[name] = dict(unit=unit, max_relative_residual=residual.max(),
                            worst_cell=int(residual.argmax()), probes=[])
        for z in PROBES:
            i = int(np.clip(np.searchsorted(z_edges, z, side='right') - 1, 0, len(ref)-1))
            checks[name]['probes'].append(dict(target_m=z, cell=i,
                bounds_m=z_edges[i:i+2].tolist(), integrated=integral[i], reference=ref[i]))

    primitive = read('ion_BiMaxwellianMoments', 75).values[:, ::2] / np.sqrt(2.)
    rows = []
    for frame in range(76):
        field = read('field', frame)
        mapped = field.interpolate().map(str(run / f'zzim-{MAP}.gkyl'), space='conf')
        samples = [mapped.select(z0=z) for z in PROBES]
        coords = [dict(target_m=z, bounds_m=s.grid[0].tolist(), sample_m=s.grid[0].mean())
                  for z, s in zip(PROBES, samples)]
        if frame == 0:
            probe_coords = coords
        elif probe_coords != coords:
            raise ValueError('Probe coordinates changed during run')
        rows.append([frame, field.ctx['time'], *(s.values.item() for s in samples)])
    drops = -np.diff(rows[-1][2:]) / 940.
    expected = np.array([7.6215, 6.0376])
    matches = np.array_equal(np.round(drops, 4), expected)

    output.mkdir(parents=True, exist_ok=True)
    arrays = {}
    schema = {}
    def add(key, values, unit, axes):
        values = np.asarray(values)
        if not np.isfinite(values).all():
            raise ValueError(f'Nonfinite values in {key}')
        arrays[key] = values
        schema[key] = dict(unit=unit, axes=axes, shape=list(values.shape), dtype=str(values.dtype))

    add('distribution', f, 's^3 m^-6', ['Z', 'v_parallel', 'mu'])
    add('source', source, 's^2 m^-6', ['Z', 'v_parallel', 'mu'])
    add('z_faces', z_edges, 'm', ['Z_face'])
    add('v_parallel_faces', v_edges, 'm s^-1', ['v_parallel_face'])
    add('mu_faces', mu_edges, 'J T^-1', ['mu_face'])
    add('z_centres', (z_edges[1:] + z_edges[:-1]) / 2, 'm', ['Z'])
    add('ion_mass', mass, 'kg', [])
    add('bmag', bmag, 'T', ['Z'])
    add('velocity_integration_factor', factor, 'T kg^-1', ['Z'])
    add('profile_frames', FRAMES, '1', ['frame'])
    add('profile_times', times, 's', ['frame'])
    add('density_profiles', profiles, 'm^-3', ['frame', 'Z'])
    add('source_moment', source_ref, 'm^-3 s^-1', ['Z'])
    add('parallel_flow', primitive[:, 1], 'm s^-1', ['Z'])
    add('parallel_temperature', primitive[:, 2] * mass / joules_per_ev, 'eV', ['Z'])
    add('perpendicular_temperature', primitive[:, 3] * mass / joules_per_ev, 'eV', ['Z'])
    add('potential', field.values[:, 0] / np.sqrt(2.), 'V', ['Z'])
    np.savez_compressed(output / 'native.npz', **arrays)
    columns = ['frame', 'time_s', 'midplane_V', 'right_throat_V', 'right_sheath_V']
    with (output / 'potential_traces.csv').open('w', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow(columns)
        writer.writerows(rows)

    report = dict(run='1x-maxw', nominal_mirror_ratio=32, input='sim.c', sha256=SHA256,
        postgkyl_version=pg.__version__, inputs=inputs, arrays=schema, trace_columns=columns,
        final_frame=75, source_time_s=inputs['zzim-ion_source_0.gkyl']['time_s'],
        ion_mass_kg=mass, joules_per_eV=joules_per_ev, final_midplane_collision_frequency_s_inv=17.285659,
        time_axis='Multiply time_s by final_midplane_collision_frequency_s_inv.',
        reductions=dict(
            faces='For each mapped coordinate, evaluate (c0 +/- sqrt(3)*c1)/sqrt(2) and average adjoining traces. The velocity map stores two 1D modal pairs.',
            phase_space='Signed physical cell means = hybrid constant mode / sqrt(8) / nodal Jvel / mean(Jtot). All phase cells retained as float64.',
            velocity_sum='Multiply each cell mean by delta(v_parallel)*delta(mu), sum both velocity axes, then multiply by velocity_integration_factor = (2*pi/ion_mass)*mean(Jtot)/mean(Jgeo).',
            moments='All seven density profiles and the source M0 use integral(M0*Jgeo)/integral(Jgeo), with the full DG product. density_profiles[-1] is the final independent density reference.',
            bmag='Native p=1 constant mode / sqrt(2).',
            final_profiles='On z_centres, use native p=1 constant modes / sqrt(2) for potential and BiMaxwellian flow and thermal speeds squared (physical components 1, 2, 3). Convert each thermal speed squared by ion_mass/joules_per_eV.',
            traces='PRE field.py: interpolate(), map(configuration map, space="conf"), select(z0=target). Each selected value samples the mapped subcell centre. Bounds and centres below apply to every frame.',
            probes='Checks use the native cell containing the target and clamp at the domain edge. Relative residual = abs(integrated-reference)/abs(reference).'),
        trace_probes=probe_coords, moment_checks=checks,
        final_potential_check=dict(order=['midplane minus right throat', 'right throat minus right sheath'],
            normalization_V=940., measured=drops.tolist(), published=expected.tolist(),
            measured_minus_published=(drops-expected).tolist(), matches_at_published_precision=bool(matches),
            explanation=('Both differences are due to the published four-decimal rounding.'
                         if matches else 'Mismatch exceeds published rounding; verify probe selection before exhibit use.')))
    (output / 'extraction_report.json').write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    extract(args.run, args.output)
