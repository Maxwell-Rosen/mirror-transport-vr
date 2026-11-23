"""Export Gallery 5's signed native cuts, level meshes and source energy bands."""
import hashlib
import json
import sys
from pathlib import Path

import contourpy
import matplotlib
import numpy as np
import postgkyl as pg
from PIL import Image, ImageDraw
from scipy.constants import electron_volt

from plot_source_slice import centres, faces, read

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "gallery-3/tools"))
from phase_mesh import Surface, SCALE, boundary_quads, export_glb

OUT = ROOT / "simulation-renders/gallery-5"
BUNDLE = ROOT / "gkeyll-data/1x-maxw/gallery-5"
PAPER = Path.home() / "Documents/PRE-gkeyll-poa-paper"
MU_ROWS = [20, 22, 24]
ION_LEVELS = [.08, .2, .35, .8, 1.2]
ION_COLORS = ["#8560bb", "#ae6693", "#e18653", "#ffba52", "#fff0a0"]
SOURCE_LEVEL = 8.
W, H = 512, 256
MINT = (105, 248, 198)


def beam_data():
    geo = read("geo_int_jacobgeo").get_values()
    jt = read("geo_int_jacobtot").get_values()[:, 0] / np.sqrt(2)
    jv = read("ion_jacobvel").get_values()[..., 0]
    vel = read("ion_mapc2p_vel").get_values()
    raw = read("ion_75")
    s = read("ion_source_0")
    for data, frame, time in [(raw, 75, .50015), (s, 0, 0.)]:
        assert data.ctx["frame"] == frame and data.ctx["time"] == time
        assert data.ctx["basis_type"] == "gkhybrid" and data.ctx["poly_order"] == 1
    def physical(data):
        return data.get_values()[..., 0] / (np.sqrt(8) * jt[:, None, None] * jv)
    def reference(name):
        return np.sum(read(name).get_values() * geo, axis=1) / (np.sqrt(2) * geo[:, 0])
    return dict(z_faces=faces(read("geo_corn_mc2nu_pos_deflated").get_values()),
                v_parallel_faces=faces(vel[:, 0, :2]), mu_faces=faces(vel[0, :, 2:]),
                distribution=physical(raw), source=physical(s),
                ion_mass=raw.ctx["mass"], bmag=read("geo_int_bmag").get_values()[:, 0] / np.sqrt(2),
                velocity_integration_factor=2*np.pi/raw.ctx["mass"] * jt / (geo[:, 0] / np.sqrt(2)),
                density_profiles=[reference("ion_M0_75")], source_moment=reference("ion_source_M0_0"),
                tube_measure=geo[:, 0] / np.sqrt(2) * np.diff(raw.get_grid()[0]))


def color_values(values):
    fraction = np.clip((np.log10(np.maximum(abs(values), 1e-6)) + 6) / np.log10(2e6), 0, 1)
    orange = matplotlib.colormaps["inferno"](.12 + .83 * fraction)[..., :3]
    blue = matplotlib.colormaps["Blues_r"](.14 + .70 * fraction)[..., :3]
    rgb = np.where(values[..., None] < 0, blue, orange)
    rgb[abs(values) < 1e-6] = [.025, .025, .035]
    return np.rint(rgb * 255).astype(np.uint8)


def contour(x, y, field):
    gen = contourpy.contour_generator(x=centres(x), y=centres(y), z=field.T)
    return gen.lines(SOURCE_LEVEL)


def heat_tile(x, y, f, s, xlim, ylim, asinh=False):
    # Sample native cells at physical pixel centres, retaining the sign.
    xp = xlim[0] + (np.arange(W)+.5) / W * np.ptp(xlim)
    ymin, ymax = np.arcsinh(ylim) if asinh else ylim
    yp = ymax - (np.arange(H)+.5) / H * (ymax-ymin)
    iy = np.searchsorted(y, np.sinh(yp) if asinh else yp) - 1
    ix = np.searchsorted(x, xp) - 1
    assert min(iy) >= 0 and max(iy) < len(y)-1 and min(ix) >= 0 and max(ix) < len(x)-1
    base = color_values(f[ix[None, :], iy[:, None]])
    tile = Image.fromarray(base)
    draw = ImageDraw.Draw(tile)
    for line in contour(x, y, s):
        px = (line[:, 0] - xlim[0]) / np.ptp(xlim) * W
        yy = np.arcsinh(line[:, 1]) if asinh else line[:, 1]
        py = (ymax-yy) / (ymax-ymin) * H
        draw.line(list(zip(px, py)), fill=MINT, width=2)
    # Sample through the saved PNG separately from geometry/atlas ordering.
    return tile, [(int(i), int(j), list(tile.getpixel((i,j)))) for i,j in [(113,75),(253,146),(401,211)]]


def save_rails(path, rails):
    """Build six-sided tubes around the saved contour polylines in exhibit metres."""
    from io import BytesIO
    import trimesh
    scene = trimesh.Scene()
    expected = {}
    step = np.arange(6) * np.pi/3
    scale = np.array([1.188, .0162, .245])  # station's Z, mu and v rulers
    for row in rails:
        vertices, faces = [], []
        for line in row["paths"]:
            points = np.array(line)
            mid = np.column_stack((scale[0]*points[:, 0], np.full(len(line),scale[1]*row["mu"]),
                                   -scale[2]*points[:, 1]))
            keep = np.r_[True,np.linalg.norm(np.diff(mid,axis=0),axis=1)>1e-10]
            mid = mid[keep]
            if len(mid)<2:
                continue
            tangent = np.gradient(mid,axis=0)
            side = np.cross(tangent,[0.,1.,0.])
            side /= np.linalg.norm(side,axis=1)[:,None]
            rim = mid[:,None,:] + .004 * (side[:,None,:] * np.cos(step)[None,:,None]
                                        + np.array([0.,1.,0.]) * np.sin(step)[None,:,None])
            start = len(vertices)
            vertices.extend(rim.reshape(-1,3))
            for i in range(len(mid)-1):
                for k in range(6):
                    a,b = start+6*i+k,start+6*i+(k+1)%6
                    faces.extend([[a,b,b+6],[a,b+6,a+6]])
            np.testing.assert_allclose(rim.mean(axis=1),mid,atol=1e-12)
        if vertices:
            name = "Band"+str(row["im"])
            mesh = trimesh.Trimesh(vertices=vertices,faces=faces,process=False)
            scene.add_geometry(mesh,node_name=name,geom_name=name)
            expected[name] = mesh.triangles.astype(np.float32)
    packed = trimesh.exchange.gltf.export_glb(scene,include_normals=False)
    reopened = trimesh.load_scene(BytesIO(packed),file_type="glb",process=False)
    for name, triangles in expected.items():
        np.testing.assert_array_equal(reopened.geometry[name].triangles, triangles)
    path.write_bytes(packed)
    return list(expected)


def save_case(case, d, samples, shared_measure, audit):
    z, v, mu = d["z_faces"], d["v_parallel_faces"]/1e6, d["mu_faces"]/(1000*electron_volt)
    edges = (z, v, mu)
    f, s = d["distribution"], d["source"]
    checks = {}
    area = np.diff(d["v_parallel_faces"])[:, None] * np.diff(d["mu_faces"])
    cuts = sorted(set(np.ravel(samples).tolist()))
    for name, field, ref in [("ions", f, d["density_profiles"][-1]), ("source", s, d["source_moment"])]:
        integrated = d["velocity_integration_factor"] * np.sum(field * area, axis=(1,2))
        np.testing.assert_allclose(integrated, ref, rtol=1e-9, atol=0)
        checks[name] = dict(max_relative_error=float(max(abs(integrated/ref-1))),
                            negative_cells=int((field<0).sum()),
                            cut_reference={str(i): float(ref[i]) for i in cuts})
    rate = float(shared_measure @ d["source_moment"])
    np.testing.assert_allclose(rate, audit["source_rate"], rtol=1e-9)
    checks["whole_tube_source"] = dict(integrated=rate, audited=audit["source_rate"])
    surfaces = []
    for k, level in enumerate(ION_LEVELS):
        cells = f >= level
        quads = boundary_quads(cells, edges)
        surfaces.append(Surface("Shell"+str(k), "Population", level, ION_COLORS[k], .15 + .16*k, cells, quads))
    prefix = "phase-" + case
    (OUT / (prefix+".glb")).write_bytes(export_glb(surfaces, edges, dict(run=audit["directory"],frame=75)))
    # The wire sections are sparse contours interpolated on physical centres.
    rails = []
    for im in [4, 9, 13, 16, 18, 19, 20, 21, 22, 23, 24, 25, 27, 29, 31]:
        lines = contour(z, v, s[:, :, im])
        rails.append(dict(im=im, mu=float(centres(mu)[im]), paths=[line.tolist() for line in lines]))
    rows = []
    atlas = Image.new("RGB", (3*W, (1+(len(cuts)+2)//3)*H))
    samples_to_check = []
    def place(tile_info, idx):
        tile, points = tile_info
        dx,dy = idx % 3 * W, idx // 3 * H
        atlas.paste(tile,(dx,dy))
        samples_to_check.extend([(dx+i,dy+j,rgb) for i,j,rgb in points])
    for k, im in enumerate(MU_ROWS):
        place(heat_tile(z,v,f[:,:,im],s[:,:,im],[-1.05,1.05],[-2.2,2.2]),k)
        rows.append([dict(iz=int(i), tile=3+cuts.index(i), z=float(centres(z)[i]),
                          z_bounds=z[i:i+2].tolist(), f=f[i,:,im].tolist(), s=s[i,:,im].tolist())
                     for i in samples[k]])
    for k, iz in enumerate(cuts):
        place(heat_tile(v,mu,f[iz],s[iz],[-3,3],[0,mu[-1]],True),3+k)
    atlas_path = OUT / (prefix+".png")
    atlas.save(atlas_path)
    loaded = Image.open(atlas_path)
    for i,j,rgb in samples_to_check:
        assert list(loaded.getpixel((i,j))) == rgb
    bands = save_rails(OUT/(prefix+"-rails.glb"), rails)
    return dict(run=Path(audit["directory"]).name, bands=bands, rows=rows), checks


def main():
    OUT.mkdir(exist_ok=True,parents=True)
    beam = beam_data()
    z = centres(beam["z_faces"])
    # Fixed coordinates for both cases. The turn samples the strongest injection
    # in the positive-Z, nearest-zero positive speed cell of the beam source.
    samples = []
    for im in MU_ROWS:
        turn = int(np.argmax(np.where(z>0,beam["source"][:,32,im],-np.inf)))
        samples.append([199,int(np.argmin(abs(z-z[turn]/2))),turn,298,399])
    audit = json.loads((PAPER/"audit/numbers.json").read_text())
    info = dict(mu_rows=MU_ROWS,mu=centres(beam["mu_faces"])[MU_ROWS].tolist(),
                v=centres(beam["v_parallel_faces"]).tolist(),v_faces=beam["v_parallel_faces"].tolist(),
                scale=SCALE.tolist(), levels=ION_LEVELS,colors=ION_COLORS,source_level=SOURCE_LEVEL,cases=[])
    info["mu"] = (np.array(info["mu"])/(1000*electron_volt)).tolist()
    legend_values = np.array([-.001,-.00001,0.,.00001,.001,.1,1.])
    info["heat_key"] = ["#%02x%02x%02x" % tuple(rgb) for rgb in color_values(legend_values)]
    report = json.loads((BUNDLE/"extraction_report.json").read_text())
    maxw = np.load(BUNDLE/"native.npz")
    for key in ["z_faces","v_parallel_faces","mu_faces","bmag","velocity_integration_factor"]:
        np.testing.assert_allclose(maxw[key],beam[key],rtol=1e-11,
                                   atol=1e-14*np.max(abs(beam[key])))
    checks = {}
    for case, label, data in [("beam","beam",beam),("maxw","maxwellian",maxw)]:
        row, = [r for r in audit[label]["scan"] if r["R"]==32]
        assert row["time_s"] == .500150 and row["frame"] == 75
        entry, checks[case] = save_case(case,data,samples,beam["tube_measure"],row)
        info["cases"].append(entry)
    (OUT/"phase.json").write_text(json.dumps(info,separators=(",",":"),allow_nan=False)+"\n")
    manifest = dict(converter="gallery-5/tools/phase_export.py", runs=["1x-beams","1x-maxw"],
        quantity="Signed physical cell means f_i (s^3/m^6, frame 75, t=.500150 s) and static S_i (s^2/m^6, frame 0, t=0 s).",
        source_files=["zzim-"+s+".gkyl" for s in ["ion_75","ion_source_0","ion_M0_75","ion_source_M0_0","ion_jacobvel",
            "ion_mapc2p_vel","geo_int_jacobtot","geo_int_jacobgeo","geo_int_bmag","geo_corn_mc2nu_pos_deflated"]],
        maxwellian=dict(bundle="gkeyll-data/1x-maxw/gallery-5/native.npz",input_sha256=report["sha256"],
                       extractor="gallery-5/tools/phase_extract_maxwellian.py",
                       bundle_sha256=hashlib.sha256((BUNDLE/"native.npz").read_bytes()).hexdigest()),
        method="Divide hybrid DG constant mode by sqrt(8), cell mean Jtot and Jvel. Signed gyrokinetic velocity integral compared with geometry-weighted independent M0 for all 400 axial cells. Use common flux-tube measure for inventory of injected ions after checking both maps, B and Jtot/Jgeo across baselines.",
        meshes="Native cell-face boundary of f at or above each threshold in phase.json (s^3/m^6), all three physical axes linear. Reopened GLB triangles match expected float32 coordinates and each enclosed volume matches the integrated native cell volume to relative tolerance 1e-6. Locations mapped as (+X=Z, +Y=mu, -Z=v_parallel).",
        presentation="Default central Z frame spans ±1.1 m at 2.8 exhibit m per axial m. Full tube spans ±2.5 m at 1.188 exhibit m per axial m. The sheath uses the full frame. Both views map mu linearly at .0162 exhibit m per keV/T and v_parallel at .50 exhibit m per 10^6 m/s, with a depth ruler spanning ±2×10^6 m/s. The selected band and bead can be seen through the shell.",
        source="Interpolated S=8 contours on selected native fixed-mu planes. Interpolate between physical cell centres. No electrostatic correction in the input source prescription. Near-zero-speed beam maximum sets positive-Z turn sample, held fixed for both cases.",
        prints="PNG atlas of native cell values: orange positive, blue negative; log10|f| over [1e-6,2] s^3/m^6, smaller magnitudes dark. Mint source contour at 8 s^2/m^6. Band crop Z=±1.05 m, v=±2.2e6 m/s; velocity cuts v=±3e6 m/s, mu=0..70.99 keV/T on asinh(mu/1 keV/T) axis. Cut probe and curves retain signed numbers independent of display mapping.",
        checks=checks,assets={})
    for path in sorted(OUT.glob("phase*")):
        if path.suffix in {".glb",".png",".json"} and path.name!="phase-manifest.json":
            manifest["assets"][path.name] = dict(bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    (OUT/"phase-manifest.json").write_text(json.dumps(manifest,indent=2,allow_nan=False)+"\n")
    print(json.dumps(checks,indent=2))

if __name__ == "__main__":
    main()
