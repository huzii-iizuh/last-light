"""Models every prop in The Last Ember and exports them to models/props.glb (+ props.blend).

Run:  blender -b -P tools/make_models.py -- <project>/models
Units are metres. Blender is Z-up; glTF export converts to Godot's Y-up, so Blender -Y
becomes Godot +Z (towards the camera). Each object keeps its origin at its base or centre.
"""
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, Matrix, noise

out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
random.seed(11)
bpy.ops.wm.read_factory_settings(use_empty=True)
objects = []


def finish(name, bm, smooth=False):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = smooth
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    objects.append(ob)


def box(bm, size, center=(0, 0, 0), M=Matrix(), cuts=0):
    T = M @ Matrix.Translation(center) @ Matrix.Diagonal((*size, 1.0))
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=T)
    if cuts:
        edges = list({e for v in r["verts"] for e in v.link_edges})
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=cuts, use_grid_fill=True)


def chip(bm, amp, freq, top=None):
    """Noise-displace every vertex so edges look broken; a flat walkable top stays flat."""
    seed = Vector((random.uniform(0, 100), random.uniform(0, 100), random.uniform(0, 100)))
    for v in bm.verts:
        d = noise.noise_vector(v.co * freq + seed) * amp
        if top is not None and v.co.z > top - 1e-4:
            d.z = min(d.z, 0.0) * 0.3
        v.co += d


def lathe(bm, prof, segs=12, M=Matrix(), jitter=0.0, jag=0.0, twist=0.0, curl=0.0, closed=False):
    """Revolve a (radius, z) profile around Z. r=0 makes a single apex vertex."""
    zs = [z for _, z in prof]
    zmin, zmax = min(zs), max(zs)
    rings = []
    for i, (r, z) in enumerate(prof):
        if r <= 1e-6:
            rings.append([bm.verts.new(M @ Vector((0, 0, z)))])
            continue
        h = (z - zmin) / max(zmax - zmin, 1e-6)
        ring = []
        for s in range(segs):
            a = 2 * math.pi * s / segs + twist * h
            rr = r * (1 + random.uniform(-jitter, jitter))
            zz = z - (random.uniform(0, jag) if jag and i == len(prof) - 1 else 0)
            x = math.cos(a) * rr + curl * math.sin(h * math.pi)
            ring.append(bm.verts.new(M @ Vector((x, math.sin(a) * rr, zz))))
        rings.append(ring)
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for A, B in pairs:
        if len(A) == 1 and len(B) == 1:
            continue
        for s in range(segs):
            n = (s + 1) % segs
            if len(A) == 1:
                bm.faces.new((A[0], B[n], B[s]))
            elif len(B) == 1:
                bm.faces.new((A[s], A[n], B[0]))
            else:
                bm.faces.new((A[s], A[n], B[n], B[s]))
    if not closed:
        if len(rings[0]) > 1:
            bm.faces.new(list(reversed(rings[0])))
        if len(rings[-1]) > 1:
            bm.faces.new(rings[-1])


def band(bm, r, z, h, t=0.1, segs=16):
    lathe(bm, [(r, z), (r + t, z), (r + t, z + h), (r, z + h)], segs, closed=True)


# --- Ruined stone ------------------------------------------------------------------------
for name in ("cap_a", "cap_b", "cap_c"):  # walkable top stones, 2 wide x 3.2 deep, top at 0
    bm = bmesh.new()
    box(bm, (2.0, 3.2, 0.6), (0, 0, -0.3), cuts=5)
    chip(bm, 0.07, 1.6, top=0.0)
    finish(name, bm)

for name in ("rock_a", "rock_b", "rock_c"):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.3)
    chip(bm, 0.08, 4.0)
    for v in bm.verts:
        v.co.z = max(v.co.z * 0.7, -0.1)
    finish(name, bm)

bm = bmesh.new()  # slab: slider platform / revealed stones, 2.5 x 2.5 x 0.5
box(bm, (2.5, 2.5, 0.5), cuts=4)
chip(bm, 0.05, 1.8, top=0.25)
finish("slab", bm)

bm = bmesh.new()  # tall broken column
box(bm, (1.4, 1.4, 0.4), (0, 0, 0.2), cuts=1)
lathe(bm, [(0.6, 0.4), (0.52, 0.55), (0.48, 6.0)], 10, jitter=0.03, jag=1.4)
finish("pillar_a", bm)

bm = bmesh.new()  # short stump
box(bm, (1.2, 1.2, 0.35), (0, 0, 0.175))
lathe(bm, [(0.5, 0.35), (0.44, 0.5), (0.42, 3.0)], 10, jitter=0.04, jag=1.0)
finish("pillar_b", bm)

bm = bmesh.new()  # half-fallen arch
box(bm, (0.8, 0.8, 5.0), (-2.2, 0, 2.5), cuts=2)
box(bm, (0.8, 0.8, 3.6), (2.2, 0, 1.8), cuts=2)
for k in range(3, 11):
    a = math.pi * k / 10
    M = Matrix.Translation((math.cos(a) * 2.2, 0, 5.0 + math.sin(a) * 2.2)) @ Matrix.Rotation(math.pi / 2 - a, 4, "Y")
    if k != 6:
        box(bm, (0.75, 0.8, 0.55), M=M)
chip(bm, 0.06, 1.5)
finish("arch", bm)

bm = bmesh.new()  # broken wall chunk
box(bm, (3.0, 0.8, 4.0), (0, 0, 2.0), cuts=4)
for v in bm.verts:
    if v.co.z > 1.9:
        v.co.z -= random.uniform(0.0, 1.6) * (0.5 + 0.5 * math.sin(v.co.x * 2.1))
chip(bm, 0.08, 1.4)
finish("wall", bm)

# --- Lighthouse (base at 0, lamp room at 13.3-15) ----------------------------------------
bm = bmesh.new()
lathe(bm, [(2.1, 0.0), (1.4, 13.0)], 16, jitter=0.01)
for z in (0.0, 3.0, 7.0, 11.0):
    band(bm, 2.1 - z / 13.0 * 0.7 + 0.02, z, 0.4)
lathe(bm, [(0.0, 13.0), (1.9, 13.0), (1.9, 13.3), (0.0, 13.3)], 16)
box(bm, (1.6, 0.4, 2.6), (0, -2.0, 1.3))          # door frame
box(bm, (1.0, 0.4, 0.9), (0, -1.75, 6.5))          # window
finish("lh_stone", bm)

bm = bmesh.new()
for k in range(16):
    a = 2 * math.pi * k / 16
    box(bm, (0.07, 0.07, 0.8), (math.cos(a) * 1.8, math.sin(a) * 1.8, 13.7))
band(bm, 1.78, 14.05, 0.06, 0.06)
for k in range(8):
    a = 2 * math.pi * k / 8
    box(bm, (0.09, 0.09, 1.7), (math.cos(a) * 1.02, math.sin(a) * 1.02, 14.15))
lathe(bm, [(1.35, 15.0), (0.0, 16.4)], 16)
lathe(bm, [(0.12, 16.3), (0.0, 17.1)], 8)
finish("lh_metal", bm)

bm = bmesh.new()
lathe(bm, [(1.0, 13.3), (1.0, 15.0)], 16)
finish("lh_glass", bm, smooth=True)

bm = bmesh.new()  # dark doorway, a separate mesh so it can glow
box(bm, (1.1, 0.1, 2.1), (0, -2.15, 1.05))
finish("lh_door", bm)

# --- Fire shrine and street lamp ---------------------------------------------------------
bm = bmesh.new()
lathe(bm, [(0.6, 0.0), (0.6, 0.15), (0.45, 0.15), (0.45, 0.3), (0.28, 0.3), (0.24, 0.9),
           (0.42, 0.95), (0.5, 1.15), (0.4, 1.15), (0.0, 1.02)], 12, jitter=0.02)
finish("shrine", bm)

bm = bmesh.new()
lathe(bm, [(0.13, 0.0), (0.13, 0.2), (0.06, 0.28), (0.05, 2.25), (0.09, 2.3), (0.0, 2.32)], 8)
for k in range(4):
    a = math.pi / 2 * k + math.pi / 4
    box(bm, (0.035, 0.035, 0.55), (math.cos(a) * 0.17, math.sin(a) * 0.17, 2.6))
lathe(bm, [(0.24, 2.86), (0.0, 3.12)], 8)
finish("lamp_metal", bm)

bm = bmesh.new()
lathe(bm, [(0.0, 2.32), (0.13, 2.4), (0.15, 2.6), (0.13, 2.8), (0.0, 2.88)], 10)
finish("lamp_glass", bm, smooth=True)

# --- The Ember's flame tongue (base at 0, ~1.1 tall) --------------------------------------
bm = bmesh.new()
lathe(bm, [(0.0, 0.0), (0.3, 0.05), (0.45, 0.2), (0.48, 0.35), (0.42, 0.55), (0.3, 0.75),
           (0.15, 0.92), (0.0, 1.1)], 14, twist=1.2, curl=0.07)
finish("flame", bm, smooth=True)

# --- Hazards ------------------------------------------------------------------------------
bm = bmesh.new()  # crescent blade in the X/Z plane, thin along Y
pts = [Vector((math.sin(a) * 0.95, -0.07, math.cos(a) * 0.95 - 0.55))
       for a in (math.radians(-75 + k * 150 / 8) for k in range(9))]
pts += [Vector((math.sin(a) * 0.7, -0.07, math.cos(a) * 0.62 - 0.45))
        for a in (math.radians(-75 + k * 150 / 8) for k in reversed(range(9)))]
face = bm.faces.new([bm.verts.new(p) for p in pts])
ext = bmesh.ops.extrude_face_region(bm, geom=[face])
bmesh.ops.translate(bm, vec=(0, 0.14, 0), verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)])
finish("blade", bm)

bm = bmesh.new()
box(bm, (2.0, 2.4, 1.6), cuts=4)
chip(bm, 0.06, 1.6)
finish("crusher_block", bm)

bm = bmesh.new()
for i in range(5):
    for j in range(3):
        lathe(bm, [(0.14, 0.0), (0.0, -0.45)], 6, M=Matrix.Translation((-0.8 + i * 0.4, -0.7 + j * 0.7, -0.8)))
finish("crusher_spikes", bm)

bm = bmesh.new()  # shadow thorns: a 1.5 x 2 cluster of crystal shards
for k in range(30):
    M = (Matrix.Translation((random.uniform(-0.7, 0.7), random.uniform(-0.95, 0.95), 0))
         @ Matrix.Rotation(random.uniform(-0.45, 0.45), 4, "X") @ Matrix.Rotation(random.uniform(-0.45, 0.45), 4, "Y"))
    lathe(bm, [(random.uniform(0.06, 0.11), 0.0), (0.0, random.uniform(0.28, 0.6))], 5, M=M)
finish("thorns", bm)

# --- Export ------------------------------------------------------------------------------
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "props.glb"), export_format="GLB", export_apply=True)
for i, ob in enumerate(objects):  # spread out only in the .blend, so it is easy to browse
    ob.location = ((i % 6) * 6.0, (i // 6) * 6.0, 0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "..", "art", "props.blend"))
print("MODELS OK", len(objects))
