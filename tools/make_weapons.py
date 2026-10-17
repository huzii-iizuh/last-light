"""Models the pistol and knife -> models/weapons.glb (+ art/weapons.blend).

Run:  blender -b -P tools/make_weapons.py -- <project>/models
Origin is the grip point. Forward is Blender -Y, which becomes Godot +Z after export.
"""
import bpy, bmesh, sys, os
from mathutils import Matrix, Vector

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)


def box(bm, size, center, rx=0.0):
    M = Matrix.Translation(center) @ Matrix.Rotation(rx, 4, "X") @ Matrix.Diagonal((*size, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)


def finish(name, bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    bpy.context.collection.objects.link(bpy.data.objects.new(name, me))


bm = bmesh.new()  # pistol: slide, frame, barrel, grip, trigger guard
box(bm, (0.032, 0.20, 0.034), (0, -0.07, 0.075))
box(bm, (0.030, 0.17, 0.026), (0, -0.055, 0.045))
box(bm, (0.014, 0.03, 0.014), (0, -0.185, 0.075))
box(bm, (0.030, 0.045, 0.11), (0, 0.0, -0.005), rx=-0.28)
box(bm, (0.008, 0.045, 0.006), (0, -0.045, 0.012))
finish("pistol", bm)

bm = bmesh.new()  # knife blade: a flat tapered spike along -Y
verts = [bm.verts.new(v) for v in [
    (-0.004, -0.03, 0.012), (0.004, -0.03, 0.012), (0.004, -0.03, -0.018), (-0.004, -0.03, -0.018),
    (0.0, -0.25, 0.010)]]
for f in [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)]:
    bm.faces.new([verts[i] for i in f])
finish("knife_blade", bm)

bm = bmesh.new()  # knife guard + handle
box(bm, (0.018, 0.012, 0.055), (0, -0.024, -0.003))
box(bm, (0.022, 0.11, 0.026), (0, 0.035, -0.003))
finish("knife_handle", bm)

bpy.ops.export_scene.gltf(filepath=os.path.join(out, "weapons.glb"), export_format="GLB", export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "..", "art", "weapons.blend"))
print("WEAPONS OK")
