"""Render or orbit the freestanding Gallery 2 planning models. See gallery-2/README.md."""

import argparse
import math
import subprocess
import time
from pathlib import Path

import numpy as np
import vtk
from PIL import Image, ImageDraw, ImageFont
from preview_models import Transport, dye_level, five_sample_trial
from scipy.spatial import cKDTree
from vtk.util.numpy_support import numpy_to_vtk, vtk_to_numpy

W, H = 960, 454
TAU = 2 * math.pi
ASSETS = Path(__file__).resolve().parents[1] / "sketches"
BRASS = (0.68, 0.49, 0.28)
LIGHT_BRASS = (0.87, 0.71, 0.46)
IRON = (0.18, 0.23, 0.22)
STONE = (0.57, 0.53, 0.45)
IVORY = (0.91, 0.91, 0.80)
BLUE = (0.21, 0.61, 0.74)
COPPER = (0.91, 0.41, 0.22)
# A fixed albedo scale, identical in every shot. Extra stops resolve the small near-unity split.
DYE_STOPS = np.array([0, 0.55, 0.84, 0.90, 1, 1.10, 1.20])
DYE_RGB = np.array(
    [
        [24, 120, 150],
        [61, 107, 157],
        [58, 99, 163],
        [65, 99, 166],
        [143, 82, 136],
        [196, 59, 81],
        [222, 57, 64],
    ]
)


def dye_rgb(level):
    return np.stack(
        [np.interp(level, DYE_STOPS, channel) for channel in DYE_RGB.T], axis=-1
    )


def font(size, bold=False):
    names = (
        ["IBMPlexSans-SemiBold.ttf", "DejaVuSans-Bold.ttf"]
        if bold
        else ["IBMPlexSans-Regular.ttf", "DejaVuSans.ttf"]
    )
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)


def material(actor, color, metallic=False):
    p = actor.GetProperty()
    p.SetColor(*color)
    p.SetAmbient(0.24)
    p.SetDiffuse(0.76)
    p.SetSpecular(0.55 if metallic else 0.11)
    p.SetSpecularPower(49 if metallic else 18)
    p.SetInterpolationToPhong()
    return actor


def actor_from(ren, source, color, metallic=False):
    mapper = vtk.vtkPolyDataMapper()
    mapper.SetInputConnection(source.GetOutputPort())
    actor = vtk.vtkActor()
    actor.SetMapper(mapper)
    ren.AddActor(actor)
    return material(actor, color, metallic)


def box(ren, center, size, color, metallic=False):
    cube = vtk.vtkCubeSource()
    cube.SetXLength(size[0])
    cube.SetYLength(size[1])
    cube.SetZLength(size[2])
    actor = actor_from(ren, cube, color, metallic)
    actor.SetPosition(center)
    return actor


def sphere(ren, pos, radii, color, metallic=False):
    ball = vtk.vtkSphereSource()
    ball.SetRadius(1)
    ball.SetThetaResolution(24)
    ball.SetPhiResolution(16)
    actor = actor_from(ren, ball, color, metallic)
    actor.SetScale(radii)
    actor.SetPosition(pos)
    return actor


def tube(ren, points, radius, color, sides=12):
    points = np.asarray(points, dtype=float)
    coords = vtk.vtkPoints()
    coords.SetData(numpy_to_vtk(points, deep=True))
    line = vtk.vtkCellArray()
    line.InsertNextCell(len(points))
    for i in range(len(points)):
        line.InsertCellPoint(i)
    data = vtk.vtkPolyData()
    data.SetPoints(coords)
    data.SetLines(line)
    pipe = vtk.vtkTubeFilter()
    pipe.SetInputData(data)
    pipe.SetRadius(radius)
    pipe.SetNumberOfSides(sides)
    pipe.CappingOn()
    return actor_from(ren, pipe, color, True)


def line(ren, a, b, r, color, sides=12):
    return tube(ren, [a, b], r, color, sides)


def mesh(ren, xyz, triangles, colors, normals=None):
    vertices = vtk.vtkPoints()
    vertices.SetData(
        numpy_to_vtk(np.ascontiguousarray(xyz, dtype="f").reshape(-1, 3), deep=True)
    )
    faces = np.ascontiguousarray(triangles, dtype=np.int64).reshape(-1, 3)
    cells = vtk.vtkCellArray()
    cells.SetData(
        numpy_to_vtk(
            np.arange(0, 3 * len(faces) + 1, 3, dtype=np.int64),
            deep=True,
            array_type=vtk.VTK_ID_TYPE,
        ),
        numpy_to_vtk(faces.ravel(), deep=True, array_type=vtk.VTK_ID_TYPE),
    )
    data = vtk.vtkPolyData()
    data.SetPoints(vertices)
    data.SetPolys(cells)
    data.GetPointData().SetScalars(
        numpy_to_vtk(
            np.ascontiguousarray(colors, dtype=np.uint8).reshape(-1, 3), deep=True
        )
    )
    if normals is None:
        calc = vtk.vtkPolyDataNormals()
        calc.SetInputData(data)
        calc.SplittingOff()
        calc.ConsistencyOn()
        calc.Update()
        data = calc.GetOutput()
    else:
        data.GetPointData().SetNormals(
            numpy_to_vtk(np.asarray(normals, dtype="f").reshape(-1, 3), deep=True)
        )
    mapper = vtk.vtkPolyDataMapper()
    mapper.SetInputData(data)
    mapper.SetColorModeToDirectScalars()
    actor = vtk.vtkActor()
    actor.SetMapper(mapper)
    ren.AddActor(actor)
    material(actor, (1, 1, 1))
    return actor, data


def faces(n, m):
    i, j = np.meshgrid(np.arange(n - 1), np.arange(m - 1), indexing="ij")
    a = (i * m + j).ravel()
    return np.vstack(
        [np.stack([a, a + m, a + 1], 1), np.stack([a + m, a + m + 1, a + 1], 1)]
    )


def plaque(ren, center, width, height, lines):
    # A real, sloping, two-sided matte black board. The texture carries white type.
    a = np.array(center) - np.array([width / 2, 0, 0])
    plane = vtk.vtkPlaneSource()
    plane.SetOrigin(a)
    plane.SetPoint1(a + [width, 0, 0])
    plane.SetPoint2(a + [0, 0.38 * height, 0.925 * height])
    sign = actor_from(ren, plane, (1, 1, 1))
    im = Image.new("RGB", (640, max(110, round(640 * height / width))))
    d = ImageDraw.Draw(im)
    fsize = min(
        70, int(im.height / (1.55 * len(lines))), int(990 / max(map(len, lines)))
    )
    for i, s in enumerate(lines):
        d.text(
            (im.width / 2, im.height * (i + 0.5) / len(lines)),
            s,
            font=font(fsize, i == 0),
            fill="white",
            anchor="mm",
        )
    pixels = np.flipud(np.asarray(im)).copy()
    img = vtk.vtkImageData()
    img.SetDimensions(im.width, im.height, 1)
    img.GetPointData().SetScalars(numpy_to_vtk(pixels.reshape(-1, 3), deep=True))
    tex = vtk.vtkTexture()
    tex.SetInputData(img)
    tex.InterpolateOn()
    tex.MipmapOn()
    tex.SetMaximumAnisotropicFiltering(8)
    sign.SetTexture(tex)
    sign.GetProperty().LightingOff()
    return sign


class Studio:
    def __init__(self, inspect=False):
        self.inspect = inspect
        self.ren = vtk.vtkRenderer()
        self.win = vtk.vtkRenderWindow() if inspect else vtk.vtkEGLRenderWindow()
        if not inspect:
            self.win.SetOffScreenRendering(1)
        self.win.SetSize(W, H)
        self.win.SetMultiSamples(0)
        self.win.AddRenderer(self.ren)
        self.ren.UseFXAAOn()
        self.ren.UseSSAOOn()
        self.ren.SetSSAORadius(0.22)
        self.ren.SetSSAOBias(0.009)
        self.ren.SetSSAOKernelSize(32)
        self.ren.SetBackground(0.65, 0.65, 0.59)
        self.ren.SetBackground2(0.80, 0.79, 0.72)
        self.ren.GradientBackgroundOn()
        self.ren.AutomaticLightCreationOff()
        for pos, color, amp in [
            ((-4, -6, 9), (1, 0.95, 0.85), 0.88),
            ((4, 2, 7), (0.82, 0.90, 1), 0.53),
            ((-5, 5, 5), (1, 0.92, 0.78), 0.25),
        ]:
            lamp = vtk.vtkLight()
            lamp.SetLightTypeToSceneLight()
            lamp.SetPosition(pos)
            lamp.SetFocalPoint(0, 0, 0)
            lamp.SetColor(color)
            lamp.SetIntensity(amp)
            self.ren.AddLight(lamp)
        box(self.ren, (0, 0, -0.19), (170, 170, 0.28), (0.59, 0.58, 0.53))
        for x in np.arange(-12, 14, 2.5):
            box(self.ren, (x, 0, -0.044), (0.012, 27, 0.002), (0.47, 0.46, 0.42))
        for y in np.arange(-12, 14, 2.5):
            box(self.ren, (0, y, -0.044), (27, 0.012, 0.002), (0.47, 0.46, 0.42))
        self.capture = vtk.vtkWindowToImageFilter()
        self.capture.SetInput(self.win)
        self.capture.ReadFrontBufferOff()
        self.capture.SetInputBufferTypeToRGB()
        self.capture.ShouldRerenderOff()

    def camera(self, pos, focus, scale):
        cam = self.ren.GetActiveCamera()
        cam.SetPosition(pos)
        cam.SetFocalPoint(focus)
        cam.SetViewUp(0, 0, 1)
        cam.ParallelProjectionOn()
        cam.SetParallelScale(scale)
        self.ren.ResetCameraClippingRange()

    def frame(self):
        self.win.Render()
        self.capture.Modified()
        self.capture.Update()
        a = vtk_to_numpy(self.capture.GetOutput().GetPointData().GetScalars())
        return Image.fromarray(np.flipud(a.reshape(H, W, 3)).copy())


def base(ren, width, depth, height=0.60):
    box(ren, (0, 0, height * 0.27), (width * 0.89, depth * 0.86, height * 0.54), IRON)
    box(ren, (0, 0, height * 0.67), (width, depth, height * 0.43), STONE)
    box(ren, (0, 0, height * 0.91), (width * 0.997, depth * 0.996, 0.025), BRASS)
    box(ren, (0, 0, height * 0.96), (width, depth, height * 0.08), (0.33, 0.38, 0.36))


class Pendulums:
    name = "Two pendulums, one damping time"
    duration = 16

    def __init__(self, studio):
        r = studio.ren
        self.moving = []
        self.guides = []
        base(r, 4.5, 1.8, 0.38)
        for x in [-1.99, 1.99]:
            for y in [-0.53, 0.53]:
                line(r, (x, y, 0.37), (x, 0, 3.04), 0.052, IRON)
                sphere(r, (x, y, 0.40), (0.12, 0.12, 0.047), BRASS, True)
        line(r, (-2.12, 0, 3.00), (2.12, 0, 3.00), 0.086, BRASS, 20)
        for x, label in [(-0.91, "Full rate"), (0.91, "Quarter rate")]:
            sphere(r, (x, 0, 2.99), (0.118, 0.116, 0.118), LIGHT_BRASS, True)
            rod = line(r, (0, 0, 0), (0, 0, -2), 0.026, BRASS)
            bob = sphere(r, (0, 0, -2), (0.159, 0.16, 0.16), LIGHT_BRASS, True)
            group = vtk.vtkAssembly()
            group.AddPart(rod)
            group.AddPart(bob)
            r.RemoveActor(rod)
            r.RemoveActor(bob)
            r.AddActor(group)
            group.SetPosition(x, 0, 2.99)
            self.moving.append(group)
            self.guides.append(
                [
                    sphere(r, (0, 0, 0), (0.048, 0.043, 0.043), IVORY, True)
                    for _ in (-1, 1)
                ]
            )
            arc = np.linspace(-0.178, 0.178, 40)
            tube(
                r,
                np.c_[
                    x + 2 * np.sin(arc),
                    np.full(40, -0.15),
                    2.99 - 2 * np.cos(arc) - 0.20,
                ],
                0.017,
                BRASS,
            )
            for a in [-10, -5, 0, 5, 10]:
                a = math.radians(a)
                xx = x + 2 * math.sin(a)
                zz = 2.99 - 2 * math.cos(a) - 0.20
                line(r, (xx, -0.19, zz), (xx, -0.12, zz), 0.012, LIGHT_BRASS)
            plaque(r, (x, -0.79, 0.41), 0.92, 0.22, [label])
        studio.camera((3.0, -11, 3.85), (0, 0, 1.6), 1.83)

    def update(self, t):
        s = t / 16
        amp = 10 * math.exp(-s)
        for group, cycles in zip(self.moving, (16, 4)):
            group.SetOrientation(0, -amp * math.cos(TAU * cycles * s), 0)
        for x, pair in zip((-0.91, 0.91), self.guides):
            for side, marker in zip((-1, 1), pair):
                a = math.radians(side * amp)
                marker.SetPosition(
                    x + 2 * math.sin(a), -0.15, 2.99 - 2 * math.cos(a) - 0.20
                )
        return (
            "Shared amplitude envelope",
            f"{amp:.2f}° left from 10.00°     |     model time  {s:.2f} damping times",
            None,
        )


def river_path(kind, q):
    q = np.asarray(q)
    a = TAU * q
    if kind == "ring":
        x = 2.07 * np.sin(a) + 0.21 * np.sin(2 * a - 0.22) + 0.10 * np.sin(3 * a + 0.6)
        y = 0.48 + 1.06 * np.cos(a) + 0.11 * np.cos(2 * a + 0.7) - 0.075 * np.sin(3 * a)
        w = 0.32 + 0.055 * np.sin(a + 1.25) + 0.035 * np.cos(3 * a - 0.35)
    elif kind == "stream":
        x = -3.65 + 7.3 * q
        y = -1.56 + 0.15 * np.sin(1.47 * x) + 0.06 * np.cos(2.35 * x + 0.6)
        w = 0.37 + 0.06 * np.cos(1.5 * x) + 0.035 * np.sin(2.9 * x)
    else:
        inlet = river_path("ring", 0.5)[0]
        outlet = river_path("stream", 0.5)[0]
        x = inlet[0] * (1 - q) + outlet[0] * q + 0.065 * np.sin(np.pi * q)
        y = inlet[1] * (1 - q) + outlet[1] * q
        w = 0.13 + 0.12 * q
    return np.stack([x, y], axis=-1), w


class Water:
    """A curved, bank-to-bank surface. Phase advects the height field and its normals."""

    def __init__(self, ren, kind, q):
        self.kind = kind
        self.q = np.asarray(q)
        self.v = np.linspace(-1, 1, 27)
        centers, width = river_path(kind, self.q)
        tang = river_path(kind, self.q + 1e-4)[0] - river_path(kind, self.q - 1e-4)[0]
        tang /= np.linalg.norm(tang, axis=1, keepdims=True)
        normal = np.stack([-tang[:, 1], tang[:, 0]], axis=1)
        xy = (
            centers[:, None, :]
            + (width[:, None, None] * self.v[None, :, None]) * normal[:, None, :]
        )
        self.xyz = np.zeros((*xy.shape[:2], 3), dtype="f")
        self.xyz[:, :, :2] = xy
        self.u = self.q[:, None]
        self.cross = self.v[None, :]
        zeros = np.zeros_like(self.xyz)
        zeros[:, :, 2] = 1
        self.actor, self.data = mesh(
            ren, self.xyz, faces(len(q), len(self.v)), np.zeros_like(self.xyz), zeros
        )
        p = self.actor.GetProperty()
        p.SetAmbient(0.73)
        p.SetDiffuse(0.29)
        p.SetSpecular(0.35)
        p.SetSpecularPower(78)
        # Concentration colours and optical detail are combined only at material evaluation.
        # The phase axis runs horizontally across this image of reflected light.
        self.optics = (
            np.asarray(
                Image.open(ASSETS / "water-reflections.webp").convert("L"), dtype=float
            )
            / 255
        )
        self.tx_w = 560 if kind == "ring" else 420
        self.tx_h = 96
        self.tex_u = np.linspace(
            self.q[0], np.nextafter(self.q[-1], self.q[0]), self.tx_w
        )[None, :]
        self.tex_v = np.linspace(-1, 1, self.tx_h)[:, None]
        self.tex_img = vtk.vtkImageData()
        self.tex_img.SetDimensions(self.tx_w, self.tx_h, 1)
        texture = vtk.vtkTexture()
        texture.SetInputData(self.tex_img)
        texture.InterpolateOn()
        texture.RepeatOff()
        texcoords = np.stack(
            np.meshgrid(
                np.linspace(0, 1, len(q)), np.linspace(0, 1, len(self.v)), indexing="ij"
            ),
            axis=-1,
        )
        self.data.GetPointData().SetTCoords(
            numpy_to_vtk(texcoords.astype("f").reshape(-1, 2), deep=True)
        )
        self.actor.GetMapper().ScalarVisibilityOff()
        self.actor.SetTexture(texture)

    def update(self, travel, levels):
        u = self.u - travel
        v = self.cross
        # Intersecting wave trains, bent by the channel edges. Fine bands follow the
        # same phase as broad crests, so water speed has the same meaning at both scales.
        bend = 0.45 * np.sin(TAU * (2 * u) + 1.75 * v) + 0.30 * np.sin(
            TAU * u - 3.1 * v
        )
        a = TAU * 5 * u + 3.3 * v + 1.8 * v * v + bend
        b = TAU * 9 * u - 2.8 * v + 1.7 * np.sin(TAU * 2 * u + v)
        c = TAU * 15 * u + 4.5 * v + 1.3 * np.sin(TAU * 3 * u - 2 * v)
        z = 0.017 * np.sin(a) + 0.008 * np.sin(b) + 0.0045 * np.sin(c)
        if self.kind == "gate":
            z *= 0.6
        surface = {"ring": 0.839, "stream": 0.793}.get(self.kind)
        if surface is None:
            surface = 0.839 - 0.046 * self.u - 0.015
        self.xyz[:, :, 2] = surface + z
        du = np.gradient(self.xyz, axis=0)
        dv = np.gradient(self.xyz, axis=1)
        norm = np.cross(du, dv)
        norm /= np.maximum(np.linalg.norm(norm, axis=2, keepdims=True), 1e-8)
        norm *= np.where(norm[:, :, 2:] < 0, -1, 1)
        # Sample continuous reflected-light streaks in advecting local coordinates.
        # Using one phase for height and optics also freezes both exactly on a held reach.
        utex = self.tex_u - travel
        vtex = self.tex_v
        xp = (2.0 * utex + 0.044 * np.sin(TAU * utex + 2 * vtex)) % 1
        yp = (
            0.20 * vtex
            + 0.10 * np.sin(TAU * 2 * utex + vtex)
            + 0.031 * np.sin(TAU * 4 * utex + 2 * vtex)
            + 0.5
        ) % 1
        oh, ow = self.optics.shape
        optical = self.optics[(yp * oh).astype(int) % oh, (xp * ow).astype(int) % ow]
        tint = dye_rgb(np.broadcast_to(levels, (self.tx_w,)))[None, :, :]
        illum = 0.65 + 0.50 * optical
        glint = np.clip((optical - 0.44) * 1.59, 0, 0.79) ** 1.11
        tex = np.clip(
            tint * illum[:, :, None] * (1 - glint[:, :, None])
            + np.array([227, 240, 244]) * glint[:, :, None],
            0,
            255,
        )
        self.tex_img.GetPointData().SetScalars(
            numpy_to_vtk(np.ascontiguousarray(tex, dtype="B").reshape(-1, 3), deep=True)
        )
        self.tex_img.Modified()
        self.data.GetPoints().SetData(numpy_to_vtk(self.xyz.reshape(-1, 3), deep=True))
        self.data.GetPointData().SetNormals(
            numpy_to_vtk(
                np.ascontiguousarray(norm, dtype="f").reshape(-1, 3), deep=True
            )
        )
        self.data.Modified()


def make_bank(ren):
    # Distance to each watercourse cuts a real bed into the terrain. Its edge intersects
    # the water surface, including at the one narrow outlet from the oxbow.
    queries = []
    for kind in ["ring", "stream", "gate"]:
        pts, w = river_path(kind, np.linspace(0, 1, 700))
        queries.append((cKDTree(pts), w))

    def bank_height(x, y):
        coords = np.stack(np.broadcast_arrays(x, y), axis=-1)
        margins = []
        for tree, w in queries:
            d, idx = tree.query(coords)
            margins.append(d - w[idx])
        margin = np.min(margins, axis=0)
        undulation = (
            0.50 * np.sin(3.4 * x + 2.1 * y)
            + 0.34 * np.cos(4.7 * y - 1.5 * x)
            + 0.22 * np.sin(9 * x + 3.2 * np.sin(2 * y))
            + 0.08 * np.cos(21 * y - 8 * x)
        )
        ramp = np.clip((margin + 0.11) / 0.40, 0, 1)
        z = 0.70 + 0.31 * (ramp * ramp * (3 - 2 * ramp)) + 0.076 * undulation
        return z, margin, undulation

    xs = np.linspace(-3.64, 3.64, 195)
    ys = np.linspace(-2.19, 2.20, 131)
    x, y = np.meshgrid(xs, ys, indexing="ij")
    # Taper the corners, then chip the edges to break up the cut face.
    x *= 1 - 0.046 * (abs(y) / 2.20) ** 5
    x += 0.048 * (abs(x) / 3.64) ** 3 * np.sin(4 * y + 2 * x)
    y += 0.05 * (abs(y) / 2.2) ** 3 * np.sin(3.6 * x)
    z, m, g = bank_height(x, y)
    rnd = np.random.default_rng(201)
    tone = (
        9 * g
        + rnd.normal(0, 7, z.shape)
        + 6 * np.sin(17 * y + np.sin(5 * x))
        - 17 * np.clip(1 - abs(m) / 0.22, 0, 1)
    )
    colors = np.clip(np.array([151, 137, 113]) + tone[:, :, None], 0, 255)
    shore_xyz = np.stack([x, y, z], axis=2)
    mesh(ren, shore_xyz, faces(*x.shape), colors)
    edge = np.vstack(
        [
            shore_xyz[:, 0],
            shore_xyz[-1, 1:],
            shore_xyz[-2::-1, -1],
            shore_xyz[0, -2:0:-1],
            shore_xyz[0, 0],
        ]
    )
    sides = []
    cols = []
    for depth, rgb in [
        (0, (135, 123, 100)),
        (0.16, (160, 145, 119)),
        (0.31, (116, 106, 88)),
        (0.42, (143, 129, 104)),
        (0.57, (96, 92, 80)),
    ]:
        row = edge.copy()
        row[:, 2] = edge[:, 2] - depth
        row[:, :2] *= (
            1 - 0.022 * depth + 0.004 * np.sin(row[:, 0, None] * 4 + depth * 24)
        )
        sides.append(row)
        cols.append(
            np.clip(
                np.asarray(rgb)
                + 7 * np.sin(4 * row[:, 0] + row[:, 1] + depth)[:, None],
                0,
                255,
            )
        )
    rockxyz = np.stack(sides, axis=1)
    mesh(ren, rockxyz, faces(*rockxyz.shape[:2])[:, ::-1], np.stack(cols, axis=1))
    box(ren, (0, 0, 0.18), (6.65, 3.68, 0.41), (0.27, 0.29, 0.27))
    # Unequal cobbles are actual 3D meshes, batched to keep rendering time small.
    n = 600
    xx = rnd.uniform(-3.46, 3.46, n)
    yy = rnd.uniform(-2.1, 2.08, n)
    zz, mm, _ = bank_height(xx, yy)
    choose = (mm > -0.065) & (mm < 0.50)
    rocks = vtk.vtkAppendPolyData()
    ico = vtk.vtkPlatonicSolidSource()
    ico.SetSolidTypeToIcosahedron()
    subdiv = vtk.vtkLoopSubdivisionFilter()
    subdiv.SetNumberOfSubdivisions(1)
    subdiv.SetInputConnection(ico.GetOutputPort())
    subdiv.Update()
    unit = vtk_to_numpy(subdiv.GetOutput().GetPoints().GetData()).copy()
    unit /= np.linalg.norm(unit, axis=1, keepdims=True)
    for px, py, pz in zip(xx[choose], yy[choose], zz[choose]):
        data = vtk.vtkPolyData()
        data.DeepCopy(subdiv.GetOutput())
        scale = rnd.uniform(0.038, 0.165)
        a = rnd.uniform(0, TAU)
        xy = unit[:, :2] * [scale * 1.40, scale * 0.90]
        xy = xy @ np.array([[np.cos(a), -np.sin(a)], [np.sin(a), np.cos(a)]])
        coords = np.c_[px + xy[:, 0], py + xy[:, 1], pz + unit[:, 2] * scale * 0.52]
        points = vtk.vtkPoints()
        points.SetData(numpy_to_vtk(coords, deep=True))
        data.SetPoints(points)
        tone = rnd.choice([-20, -11, 0, 10, 24])
        rgb = np.clip(
            np.array([155, 148, 131]) + tone + 12 * unit[:, 2, None], 0, 255
        ).astype("B")
        data.GetPointData().SetScalars(numpy_to_vtk(rgb, deep=True))
        rocks.AddInputData(data)
    smooth = vtk.vtkPolyDataNormals()
    smooth.SetInputConnection(rocks.GetOutputPort())
    smooth.SplittingOff()
    actor_from(ren, smooth, (1, 1, 1))
    for px, py in [(-1.65, 1.70), (2.19, 0.80), (-1.19, -0.18), (1.7, 1.60)]:
        pz, margin, _ = bank_height(px, py)
        if margin < -0.03:
            continue
        for _ in range(9):
            dx, dy = rnd.uniform(-0.11, 0.11, 2)
            h = rnd.uniform(0.12, 0.29)
            tube(
                ren,
                [
                    (px + dx, py + dy, pz),
                    (px + 1.30 * dx, py + 1.25 * dy, pz + h * 0.7),
                    (px + 1.8 * dx, py + 1.55 * dy, pz + h),
                ],
                0.009,
                (0.29, 0.36, 0.21),
                6,
            )


class River:
    name = "The dye river"
    duration = 23

    def __init__(self, studio):
        self.studio = studio
        self.mode = None
        r = studio.ren
        make_bank(r)
        # Keep the tap and gate as duplicated mesh edges, preserving sharp analytic jumps.
        self.ring = [
            Water(r, "ring", np.linspace(a, b, 171)) for a, b in [(0, 0.5), (0.5, 1)]
        ]
        self.stream = [
            Water(r, "stream", np.linspace(a, b, 111)) for a, b in [(0, 0.5), (0.5, 1)]
        ]
        self.gate = Water(r, "gate", np.linspace(0.21, 0.82, 45))
        self.taps = []
        for pos in (river_path("stream", 0.5)[0], river_path("ring", 0.0)[0]):
            xx, yy = pos
            faucet = tube(
                r,
                [
                    (xx, yy + 0.56, 0.97),
                    (xx, yy + 0.56, 1.24),
                    (xx, yy + 0.49, 1.33),
                    (xx, yy + 0.21, 1.33),
                    (xx, yy + 0.13, 1.28),
                    (xx, yy + 0.10, 1.18),
                ],
                0.062,
                BRASS,
                20,
            )
            dye = line(
                r, (xx, yy + 0.10, 1.18), (xx, yy, 0.80), 0.027, (0.64, 0.14, 0.21)
            )
            self.taps.append((faucet, dye))
        sx, sy = river_path("gate", 0.45)[0]
        for dx in [-0.24, 0.24]:
            box(r, (sx + dx, sy, 0.87), (0.105, 0.27, 0.28), (0.44, 0.41, 0.35))
        for side, q in [(-1, 0.005), (1, 0.995)]:
            center, wd = river_path("stream", q)
            for sign in [-1, 1]:
                sphere(
                    r,
                    (center[0] - side * 0.06, center[1] + sign * (wd + 0.02), 0.84),
                    (0.13, 0.18, 0.14),
                    (0.42, 0.40, 0.36),
                )
        self.last_stream = None
        studio.camera((3.1, -9.8, 7.4), (0, 0, 0.70), 2.53)

    def update(self, t):
        calibration = t < 7
        if calibration != self.mode:
            self.mode = calibration
            for idx, parts in enumerate(self.taps):
                for part in parts:
                    part.SetVisibility(idx == (0 if calibration else 1))
            for part in [*self.ring, self.gate]:
                part.actor.SetVisibility(not calibration)
            if not self.studio.inspect:
                if calibration:
                    self.studio.camera((1.1, -9, 5.05), (0, -1.13, 0.83), 1.91)
                else:
                    self.studio.camera((3.1, -9.8, 7.4), (0, 0, 0.70), 2.53)
        if calibration:
            # In three seconds a full-speed parcel covers the entire open reach.
            # After halving u, the new inlet concentration propagates from the tap.
            slowed = t >= 3
            open_clock = t / 3 if not slowed else 1 + (t - 3) / 6
            front = 0.5 + max(0, (t - 3) / 6)
            for i, w in enumerate(self.stream):
                levels = (
                    0
                    if i == 0
                    else np.where((w.tex_u.ravel() < front) & slowed, 1.1, 0.55)
                )
                w.update(open_clock, levels)
            outlet = 1.10 if t >= 6 else 0.55
            phase = (
                "Fixed dye feed  ·  half-speed current"
                if slowed
                else "Fixed dye feed  ·  full-speed current"
            )
            return (
                phase,
                f"Source on the straight reach     |     outlet dye level  {outlet:.2f}",
                "dye",
            )
        # Match the two profiles at the switch, then make an explicit cut to the
        # slow equilibrium. The stream latches geometry, optics and dye together.
        s = t - 7
        travel = s / 2 if s < 4 else 2 + (s - 4) / 20
        for w in self.ring:
            w.update(travel, dye_level(w.tex_u.ravel(), s))
        open_clock = min(s, 4) / 3
        if self.last_stream != open_clock:
            for w, level in zip(self.stream, (0, 0.55)):
                w.update(open_clock, level)
            self.last_stream = open_clock
        incoming, outgoing = dye_level(np.array([np.nextafter(0.5, 0), 0.5]), s)
        self.gate.update(s / 2, (incoming + outgoing) / 2)
        if s < 4:
            phase = "Full dynamics  ·  steady state"
            caption = "One lap in 2 s    |    outlet flowing"
        elif s < 10:
            phase = "Long phase  ·  after the switch"
            caption = "One lap in 20 s    |    outlet held"
        else:
            phase = "Long phase  ·  equilibrium cut"
            caption = "One lap in 20 s    |    outlet held"
        a, b = dye_level(np.array([0.25, 0.75]), s)
        return phase, f"{caption}    |    probes  {a:.2f}  /  {b:.2f}", "dye"


RINGS = (0.77, 1.21, 1.68)
TRACK_Z = (1.11, 1.03, 0.95, 0.94, 0.94)


def on_wire(track, q):
    if track < 3:
        a = TAU * q
        return np.array(
            [RINGS[track] * np.sin(a), 0.42 + RINGS[track] * np.cos(a), TRACK_Z[track]]
        )
    return np.array([-2.41 + 4.82 * q, -1.50 if track == 3 else -2.0, TRACK_Z[track]])


class Wires:
    name = "Which beads reach the second wire?"
    duration = 20

    def __init__(self, studio, collision_rate=0.5):
        r = studio.ren
        self.model = Transport(collision_rate=collision_rate)
        self.ren = r
        base(r, 5.8, 4.78, 0.45)
        for k in range(3):
            pts = np.stack([on_wire(k, q) for q in np.linspace(0, 1, 151)])
            tube(r, pts, 0.023, LIGHT_BRASS, 14)
            for q in (0.14, 0.49, 0.82):
                p = on_wire(k, q)
                line(r, (p[0], p[1], 0.45), p, 0.020, IRON)
        # A recessed annular source under the inner track marks all possible birth phases.
        inner = np.stack([on_wire(0, q) for q in np.linspace(0, 1, 101)])
        inner[:, :2] = (inner[:, :2] - [0, 0.42]) * 0.89 + [0, 0.42]
        inner[:, 2] -= 0.09
        tube(r, inner, 0.025, (0.63, 0.30, 0.16))
        plaque(r, (-0.10, 0.42, 0.48), 1.04, 0.24, ["Inner source"])
        for k in (3, 4):
            p0, p1 = on_wire(k, 0), on_wire(k, 1)
            line(r, p0, p1, 0.027, BRASS if k == 3 else COPPER)
            for f in (0.02, 0.98):
                p = on_wire(k, f)
                line(r, (p[0], p[1], 0.45), p, 0.030, IRON)
            box(r, (p1[0] + 0.07, p1[1], 0.78), (0.12, 0.29, 0.59), IRON)
            plaque(r, (p1[0] + 0.20, p1[1] - 0.11, 0.98), 0.40, 0.25, [str(k - 2)])
        self.balls = {}
        self.edge_flash = [
            sphere(r, (0, 0, 0), (0.095, 0.095, 0.035), COPPER, True) for _ in range(6)
        ]
        for a in self.edge_flash:
            a.SetVisibility(False)
        self.shock = []
        for _ in range(9):
            seg = vtk.vtkLineSource()
            pip = vtk.vtkTubeFilter()
            pip.SetInputConnection(seg.GetOutputPort())
            pip.SetNumberOfSides(8)
            pip.SetRadius(0.014)
            act = actor_from(r, pip, (1, 0.69, 0.26))
            act.SetVisibility(False)
            self.shock.append((seg, act))
        studio.camera((3.0, -9.6, 7.1), (0, -0.04, 0.82), 2.42)

    def update(self, t):
        model_t = t / 2
        sat = self.model.samples(model_t)
        for i in self.balls.keys() - sat.keys():
            self.balls[i].SetVisibility(False)
        recent = [e for e in self.model.events if model_t - 0.19 < e.t <= model_t]
        newborn = {e.bead for e in recent if e.old == -1}
        jumped = {e.bead for e in recent if e.old >= 0 and e.new < 5}
        for i, (k, q) in sat.items():
            if i not in self.balls:
                self.balls[i] = sphere(self.ren, (0, 0, 0), (0.067,) * 3, IVORY, True)
            actor = self.balls[i]
            actor.SetVisibility(True)
            actor.SetPosition(on_wire(k, q))
            color = (
                (0.98, 0.64, 0.21)
                if k < 3 and (i in newborn or i in jumped)
                else (IVORY if k < 3 else BLUE if k == 3 else (1, 0.42, 0.19))
            )
            actor.GetProperty().SetColor(color)
        transfers = [e for e in recent if e.old == 2 and e.new == 3]
        for j, a in enumerate(self.edge_flash):
            a.SetVisibility(j < 2 * len(transfers))
            if j < 2 * len(transfers):
                e = transfers[j // 2]
                a.SetPosition(on_wire(e.old if j % 2 == 0 else e.new, e.phase))
        marks = [e for e in recent if e.old >= 0 and not (e.old == 2 and e.new == 3)]
        for j, (src, act) in enumerate(self.shock):
            act.SetVisibility(j < len(marks))
            if j >= len(marks):
                continue
            e = marks[j]
            old = on_wire(e.old, e.phase)
            if e.new < 5:
                end = on_wire(e.new, e.phase)
            elif e.new == 6:
                end = old + [0, 0, 0.23]
            else:
                end = old + [0.16, 0, 0]
            src.SetPoint1(old)
            src.SetPoint2(end)
        all_events = [e for e in self.model.events if e.t <= model_t]
        removed = sum(e.new == 6 for e in all_events)
        wall = sum(e.new == 5 for e in all_events)
        late = sum(e.new == 5 and e.old == 4 for e in all_events)
        if model_t < 3:
            name = "Full dynamics  ·  stationary source"
        elif model_t < 7:
            name = "Long phase  ·  passing profile held"
        else:
            name = "Full dynamics  ·  outlet moving again"
        return (
            name,
            f"k = {self.model.collision_rate:.2f} per model s     |     wall exits {wall} (wire 2: {late})     |     removed at ring edge {removed}",
            None,
        )


class Pedestal:
    name = "Catch the outlet"
    duration = 19.90

    def __init__(self, studio):
        r = studio.ren
        self.t, self.y, self.stops = five_sample_trial()
        self.lo = -0.005
        self.span = 0.030
        self.corner = np.array([-1.45, -0.42, 0.81])
        self.edge = 1.75
        base(r, 4.3, 2.6, 0.74)
        from itertools import product

        for idx in product([0, 1], repeat=3):
            p = self.corner + self.edge * np.array(idx)
            for axis in range(3):
                if not idx[axis]:
                    q = p.copy()
                    q[axis] += self.edge
                    line(r, p, q, 0.013, IRON)
        line(r, self.corner, self.corner + self.edge, 0.031, BRASS, 16)
        tube(r, [self.loc(y[:3]) for y in self.y], 0.009, (0.71, 0.46, 0.25), 8)
        self.ball = sphere(r, (0, 0, 0), (0.078,) * 3, IVORY, True)
        self.collar = sphere(r, (0, 0, 0), (0.06, 0.06, 0.06), BRASS, True)
        self.arm = vtk.vtkLineSource()
        pipe = vtk.vtkTubeFilter()
        pipe.SetInputConnection(self.arm.GetOutputPort())
        pipe.SetRadius(0.013)
        pipe.SetNumberOfSides(10)
        actor_from(r, pipe, IVORY)
        self.needle = []
        for i, x in enumerate([0.91, 1.56]):
            line(r, (x, 0.13, 0.78), (x, 0.13, 2.31), 0.026, IRON)
            for z in np.linspace(0.84, 2.16, 7):
                line(r, (x - 0.11, 0.13, z), (x + 0.11, 0.13, z), 0.013, BRASS)
            mark = sphere(
                r,
                (x, 0.13, 0.84),
                (0.145, 0.09, 0.048),
                BLUE if i == 0 else COPPER,
                True,
            )
            self.needle.append(mark)
            plaque(r, (x, -0.38, 0.755), 0.56, 0.25, [f"Pass {i + 1}"])
        self.pin = box(
            r, (1.56, 0.15, 0.84 + 2.74581939 * 0.22), (0.46, 0.035, 0.023), IVORY
        )
        plaque(r, (-0.58, -0.97, 0.755), 1.17, 0.24, ["Three trapped samples"])
        studio.camera((4.7, -8.6, 4.3), (0, 0.04, 1.26), 1.96)

    def loc(self, y):
        return self.corner + self.edge * (np.asarray(y) - self.lo) / self.span

    def update(self, t):
        s = 0.001 * t
        y = np.array([np.interp(s, self.t, self.y[:, i]) for i in range(5)])
        point = self.loc(y[:3])
        mean = self.loc(np.repeat(np.mean(y[:3]), 3))
        self.ball.SetPosition(point)
        self.collar.SetPosition(mean)
        self.arm.SetPoint1(point)
        self.arm.SetPoint2(mean)
        for mark, x, p in zip(self.needle, [0.91, 1.56], y[3:]):
            mark.SetPosition(x, 0.13, 0.84 + 1e5 * 0.22 * p)
        idx = np.searchsorted(self.stops[1:], s, side="right")
        self.pin.SetVisibility(bool(s >= self.stops[2]))
        name = (
            "Long phase  ·  passing samples held",
            "Full dynamics  ·  both passing samples evolve",
        )[idx % 2]
        return (
            name,
            f"Collision times  {s:.5f}     |     trapped mean / f*  {y[:3].mean():.5f}     |     outlet / f*  {y[4]:.8f}",
            None,
        )


SCENES = {
    "pendulums": Pendulums,
    "river": River,
    "transport": Wires,
    "pedestal": Pedestal,
}
COLLISION_PRESETS = (0.25, 0.50, 1.00)
SUBTITLES = {
    "pendulums": "Damped pendulum analogy",
    "river": "Analytic dye analogy  ·  colour measures concentration across the water",
    "transport": "Stochastic transport analogy  ·  the near straight track is wire 2",
    "pedestal": "Thesis five-equation model  ·  short uniform-source trial",
}


def annotated(scene, key, view, info):
    phase, readout, legend = info
    im = Image.new("RGB", (W, 600))
    im.paste(view, (0, 70))
    draw = ImageDraw.Draw(im)
    draw.text((23, 9), scene.name, font=font(29, True), fill="white")
    draw.text((25, 46), SUBTITLES[key], font=font(15), fill="white")
    draw.text((24, 532), phase, font=font(19, True), fill="white")
    draw.text((24, 564), readout, font=font(16), fill="white")
    if legend == "dye":
        x0, x1 = 709, 934
        draw.text((x0, 528), "Dye level  f / f*", font=font(14), fill="white")
        for x in range(x0, x1):
            v = 1.2 * (x - x0) / (x1 - x0)
            draw.line((x, 549, x, 558), fill=tuple(dye_rgb(v).astype(int)))
        for value, y in [(0, 562), (0.9, 562), (1.1, 562), (1.2, 579)]:
            x = x0 + int((x1 - x0) * value / 1.2)
            draw.text((x, y), f"{value:g}", font=font(12), fill="white", anchor="mt")
    return im


def motion_preview(key, output):
    """Embed a lightweight moving excerpt in the plan; keep the full-resolution film linked."""
    src = output / (key + "-3d.mp4")
    dst = output / (key + "-3d.webp")
    start = "7" if key == "river" else "0"
    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-ss",
            start,
            "-i",
            str(src),
            "-an",
            "-vf",
            "fps=8,scale=720:-2",
            "-c:v",
            "libwebp_anim",
            "-compression_level",
            "4",
            "-quality",
            "69",
            "-loop",
            "0",
            str(dst),
        ],
        check=True,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene", choices=SCENES)
    parser.add_argument("--inspect", action="store_true")
    parser.add_argument(
        "--collision-rate",
        type=float,
        choices=COLLISION_PRESETS,
        help="Per-neighbour rate in the transport preview, in inverse model seconds.",
    )
    parser.add_argument("--output", type=Path, default=ASSETS)
    parser.add_argument("--still", type=float, metavar="SECONDS")
    args = parser.parse_args()
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    studio = Studio(args.inspect)
    if args.collision_rate is not None and args.scene != "transport":
        parser.error("--collision-rate belongs to the transport model")
    scene = (
        Wires(studio, args.collision_rate or 0.5)
        if args.scene == "transport"
        else SCENES[args.scene](studio)
    )
    if args.inspect:
        inter = vtk.vtkRenderWindowInteractor()
        inter.SetRenderWindow(studio.win)
        inter.SetInteractorStyle(vtk.vtkInteractorStyleTrackballCamera())
        label = vtk.vtkTextActor()
        label.GetTextProperty().SetFontSize(16)
        label.GetTextProperty().SetBackgroundOpacity(1.0)
        label.SetPosition(12, 12)
        studio.ren.AddViewProp(label)
        studio.win.SetWindowName(scene.name)
        position = 0.0
        paused = False
        previous = time.monotonic()

        def tick(*_):
            nonlocal previous, position
            now = time.monotonic()
            if not paused:
                position = (position + now - previous) % scene.duration
            previous = now
            name, reading, _ = scene.update(position)
            label.SetInput(name + "\n" + reading)
            studio.win.Render()

        def keypress(*_):
            nonlocal paused, position, previous
            key = inter.GetKeySym()
            if key == "space":
                paused = not paused
            elif isinstance(scene, Wires) and key in ("bracketleft", "bracketright"):
                index = COLLISION_PRESETS.index(scene.model.collision_rate)
                index = (index + (1 if key == "bracketright" else -1)) % len(
                    COLLISION_PRESETS
                )
                scene.model = Transport(collision_rate=COLLISION_PRESETS[index])
                position = 0.0
            elif isinstance(scene, Pedestal) and key == "n":
                endpoints = scene.stops[1:] * 1000
                later = endpoints[endpoints > position + 0.001]
                position = float(later[0]) if len(later) else 0.0
                paused = True
            previous = time.monotonic()
            tick()

        inter.AddObserver("KeyPressEvent", keypress)
        inter.Initialize()
        inter.AddObserver("TimerEvent", tick)
        inter.CreateRepeatingTimer(40)
        tick()
        inter.Start()
        return

    def frame(t):
        info = scene.update(t)
        return annotated(scene, args.scene, studio.frame(), info)

    if args.still is not None:
        frame(args.still).save(out / (args.scene + "-3d.png"))
        return
    fps = 20
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgb24",
        "-s",
        f"{W}x600",
        "-r",
        str(fps),
        "-i",
        "-",
        "-an",
        "-c:v",
        "libx264",
        "-threads",
        "2",
        "-preset",
        "fast",
        "-crf",
        "20",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        str(out / (args.scene + "-3d.mp4")),
    ]
    with subprocess.Popen(cmd, stdin=subprocess.PIPE) as encoder:
        for i in range(round(scene.duration * fps)):
            encoder.stdin.write(frame(i / fps).tobytes())
        encoder.stdin.close()
        if encoder.wait():
            raise SystemExit("ffmpeg could not finish the film")
    motion_preview(args.scene, out)


if __name__ == "__main__":
    main()
