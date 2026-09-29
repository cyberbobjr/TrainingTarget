"""Training Target tiles (batman_training_01, tiledef 7173) for Build 42.21.

Contract: docs/assets-spec.md (the Lua code uses these indices; never renumber).

  0-1     paper target on a wall (S = north wall, E = west wall), MoveType=WallObject
  2-5     target stand (easel), S E N W
  8-11    can stand (plank on cinder blocks), S E N W, empty
  12-27   training dummy, 4 wear states x S E N W
  32-55   overlays: impacts on the wall target (S 32-43, E 44-55), slots 0-11
  56-103  overlays: impacts on the stand (S 56, E 68, N 80, W 92), slots 0-11
  104-127 overlays: one can on the can stand (S 104, E 110, N 116, W 122), slots 0-5

Impact slots 0-3 lie in the black bull, 4-7 in the inner ring, 8-11 in the outer
ring. An overlay cell holds only the impact (or the can): it is rendered with the
same camera while the base object is a holdout, so it lands exactly on the base
sprite of the same facing and is hidden where the base covers it.

Needs pz-sprite-forge (MIT, https://github.com/Leeheejin/pz-sprite-forge).
1. Render every cell, headless (the forge rig uses global object names: never in a
   Blender file that already holds another forge rig):
       set PZ_FORGE=<path to your pz-sprite-forge clone>
       blender -b --factory-startup -P source/training_targets/build_training_targets.py -- <cells-dir> [<group>... preview]
   (optional group keys, e.g. "stand hole_stand_03 preview", render a subset while iterating)
   Writes <cells-dir>/<group>/ (forge cells + manifest.json per group) and
   <cells-dir>/preview.png (512x512 perspective of the four objects).
2. Style and package (Python with Pillow; runs `pzforge build` per group, then
   writes the 128-cell sheet with the pzforge codecs and per-tile properties):
       python source/training_targets/build_training_targets.py package <cells-dir> <project-root> [--no-preview]
   (--no-preview leaves preview.png and poster.png untouched)
   -> Contents/mods/batman_TrainingTarget/common/media/texturepacks/batman_training_01.pack
      Contents/mods/batman_TrainingTarget/common/media/batman_training_01.tiles
      preview.png and Contents/mods/batman_TrainingTarget/42.21/poster.png
3. Depth map (the author's build_depthmap.py and save_blend.py helpers, not included here;
   this recipe exposes tile_groups() for them):
       blender -b --factory-startup -P <scripts>/build_depthmap.py -- <this script> depth.json
       python <scripts>/build_depthmap.py depth.json <mod>/common/media/texturepacks/batman_training_01.pack
           batman_training_01 <mod>/common/media/depthmaps/DEPTH_batman_training_01.png
Editable copy (showcase of the four objects, not versioned): batman_training_01.blend, from
       blender -b --factory-startup -P <scripts>/save_blend.py -- <this script> batman_training_01.blend batman_training_01
"""
from __future__ import annotations

import json
import math
import os
import random
import sys
from pathlib import Path

try:
    import bpy
    from mathutils import Vector
except ImportError:  # packaging step, plain Python
    bpy = None

FORGE = Path(os.environ.get("PZ_FORGE", "pz-sprite-forge"))
sys.path.insert(0, str(FORGE / "blender"))
sys.path.insert(0, str(FORGE))
if bpy is not None:
    import pz_sprite_forge as F  # noqa: E402

SHEET = "batman_training_01"
TILEDEF_ID = 7173
MOD_ID = "batman_TrainingTarget"

# --------------------------------------------------------------------------- #
# Measurements (metres; 1 m = 1 tile, a storey = 2.449 m)
# --------------------------------------------------------------------------- #
#: Printed target sheet, shared by the wall target and the stand. Vanilla's
#: circular target (location_military_generic_01_69) spans 0.73 m x 0.64 m.
SHEET_W, SHEET_H, SHEET_T = 0.58, 0.66, 0.003
R_BULL, R_INNER, R_OUTER = 0.105, 0.180, 0.255
#: Wall target: board centre height and gap between the board and the tile edge
#: (the wall sprite's face), checked with compose_check on walls_exterior_house_01.
WALL_Z, WALL_GAP = 1.30, 0.035
BOARD_W, BOARD_H, BOARD_T = 0.68, 0.76, 0.018
#: Target stand: sheet centre height (chest), easel lean.
STAND_Z, STAND_LEAN = 1.28, math.radians(-8.0)
#: Can stand: cinder block stacks and plank; six can slots, left to right.
PLANK_TOP = 0.415
CAN_R, CAN_H = 0.055, 0.140
CAN_X = [-0.375 + 0.15 * k for k in range(6)]

#: Impact slots (sheet coordinates: radius, angle in degrees from +u, CCW).
IMPACTS = [(0.055, 20), (0.058, 110), (0.053, 200), (0.056, 290),
           (0.142, 65), (0.145, 155), (0.140, 245), (0.144, 335),
           (0.219, 40), (0.216, 130), (0.221, 220), (0.217, 310)]

PAINTS = {
    "pine": ("wood", (0.50, 0.28, 0.11)),       # stand, plank
    "plywood": ("wood", (0.56, 0.37, 0.17)),    # wall board
    "oak": ("wood", (0.40, 0.19, 0.075)),       # dummy post, arms, feet
    "paper": ("fabric", (0.86, 0.85, 0.80)),
    "paperback": ("fabric", (0.74, 0.72, 0.66)),
    "ink": ("fabric", (0.025, 0.025, 0.028)),
    "hole": ("fabric", (0.012, 0.010, 0.009)),
    "torn": ("fabric", (0.76, 0.72, 0.64)),   # frayed paper around a hole
    "pin": ("metal", (0.70, 0.10, 0.08)),
    "nail": ("metal", (0.30, 0.30, 0.32)),
    "cinder": ("brick", (0.50, 0.50, 0.48)),
    "tin": ("metal", (0.64, 0.65, 0.67)),
    "burlap": ("fabric", (0.52, 0.40, 0.23)),
    "straw": ("fabric", (0.90, 0.74, 0.30)),
    "burlap_in": ("fabric", (0.26, 0.18, 0.10)),  # inside of torn burlap
    "rope": ("fabric", (0.58, 0.47, 0.30)),
    "slit": ("fabric", (0.07, 0.05, 0.035)),
    "redpaint": ("fabric", (0.62, 0.07, 0.05)),
    "label0": ("fabric", (0.66, 0.08, 0.06)),
    "label1": ("fabric", (0.10, 0.38, 0.13)),
    "label2": ("fabric", (0.82, 0.60, 0.08)),
    "label3": ("fabric", (0.08, 0.22, 0.55)),
    "label4": ("fabric", (0.80, 0.32, 0.05)),
    "label5": ("fabric", (0.82, 0.80, 0.72)),
    "stripe": ("fabric", (0.90, 0.89, 0.84)),
}


def materials() -> dict:
    return {key: F.forge_material(f"batman_tt_{key}", cls, paint)
            for key, (cls, paint) in PAINTS.items()}


# --------------------------------------------------------------------------- #
# Mesh kit (data API only: works headless and in a dedicated MCP scene)
# --------------------------------------------------------------------------- #

class Kit:
    """Parts parented to an anchor (the forge subject or a sub-empty)."""

    def __init__(self, anchor, mats):
        self.anchor, self.mats = anchor, mats

    def empty(self, name, loc=(0, 0, 0), rot=(0, 0, 0)) -> "Kit":
        obj = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent, obj.location, obj.rotation_euler = self.anchor, loc, rot
        return Kit(obj, self.mats)

    def mesh(self, name, verts, faces, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=False):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in verts], [], faces)
        me.update()
        if smooth:
            for poly in me.polygons:
                poly.use_smooth = True
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(self.mats[mat])
        obj.parent, obj.location, obj.rotation_euler = self.anchor, loc, rot
        return obj

    def box(self, name, c, size, mat, rot=(0, 0, 0), bevel=0.0):
        sx, sy, sz = (s / 2 for s in size)
        verts = [(x, y, z) for z in (-sz, sz) for y in (-sy, sy) for x in (-sx, sx)]
        faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
        obj = self.mesh(name, verts, faces, mat, c, rot)
        if bevel:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width, mod.segments = min(size) * bevel, 2
        return obj

    def lathe(self, name, profile, mat, loc=(0, 0, 0), sx=1.0, sy=1.0, segs=32,
              skip=None, smooth=True):
        """Surface of revolution; profile = [(radius, z)] bottom to top, open ends.
        ``skip(i_ring, j_seg, phi, z)`` removes faces (torn cloth)."""
        verts, faces = [], []
        for r, z in profile:
            for j in range(segs):
                a = 2 * math.pi * j / segs
                verts.append((r * sx * math.cos(a), r * sy * math.sin(a), z))
        for i in range(len(profile) - 1):
            for j in range(segs):
                a = 2 * math.pi * (j + 0.5) / segs
                zc = (profile[i][1] + profile[i + 1][1]) / 2
                if skip and skip(i, j, a, zc):
                    continue
                j2 = (j + 1) % segs
                faces.append((i * segs + j, i * segs + j2, (i + 1) * segs + j2, (i + 1) * segs + j))
        return self.mesh(name, verts, faces, mat, loc, smooth=smooth)

    def cyl(self, name, c, r, depth, mat, rot=(0, 0, 0), segs=24, caps=True):
        verts = [(r * math.cos(2 * math.pi * j / segs), r * math.sin(2 * math.pi * j / segs), z)
                 for z in (-depth / 2, depth / 2) for j in range(segs)]
        faces = [(j, (j + 1) % segs, segs + (j + 1) % segs, segs + j) for j in range(segs)]
        if caps:
            faces += [tuple(reversed(range(segs))), tuple(range(segs, 2 * segs))]
        return self.mesh(name, verts, faces, mat, c, rot)

    def torus(self, name, c, major, minor, mat, sx=1.0, sy=1.0, segs=32, tube=8):
        verts, faces = [], []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            for k in range(tube):
                b = 2 * math.pi * k / tube
                rr = major + minor * math.cos(b)
                verts.append((rr * sx * math.cos(a), rr * sy * math.sin(a), minor * math.sin(b)))
        for i in range(segs):
            for k in range(tube):
                i2, k2 = (i + 1) % segs, (k + 1) % tube
                faces.append((i * tube + k, i2 * tube + k, i2 * tube + k2, i * tube + k2))
        return self.mesh(name, verts, faces, mat, c, smooth=True)

    def _aligned(self, obj, p0, p1):
        a, b = Vector(p0), Vector(p1)
        obj.location = (a + b) / 2
        obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
        return obj

    def rod(self, name, p0, p1, r, mat, segs=8):
        length = (Vector(p1) - Vector(p0)).length
        return self._aligned(self.cyl(name, (0, 0, 0), r, length, mat, segs=segs), p0, p1)

    def beam(self, name, p0, p1, w, d, mat, bevel=0.12):
        length = (Vector(p1) - Vector(p0)).length
        return self._aligned(self.box(name, (0, 0, 0), (w, d, length), mat, bevel=bevel), p0, p1)

    # -- flat shapes in the local XZ plane (u = x, v = z) ------------------- #
    def flat(self, name, loops_uv, y, mat, back=False, quads=None):
        """Polygon (single loop) or ring (quads between loops) at depth y.
        Faces -Y (front) unless ``back``."""
        verts = [(u, y, v) for loop in loops_uv for (u, v) in loop]
        if quads is None:
            faces = [tuple(range(len(verts)))]
        else:
            faces = quads
        if back:
            faces = [tuple(reversed(f)) for f in faces]
        return self.mesh(name, verts, faces, mat)

    def disc(self, name, cu, cv, radii, y, mat, back=False):
        n = len(radii)
        loop = [(cu + radii[j] * math.cos(2 * math.pi * j / n),
                 cv + radii[j] * math.sin(2 * math.pi * j / n)) for j in range(n)]
        return self.flat(name, [loop], y, mat, back)

    def annulus(self, name, cu, cv, r_in, r_out, y, mat, back=False, segs=64):
        r_out = r_out if isinstance(r_out, list) else [r_out] * segs
        r_in = r_in if isinstance(r_in, list) else [r_in] * len(r_out)
        n = len(r_out)
        inner = [(cu + r_in[j] * math.cos(2 * math.pi * j / n), cv + r_in[j] * math.sin(2 * math.pi * j / n))
                 for j in range(n)]
        outer = [(cu + r_out[j] * math.cos(2 * math.pi * j / n), cv + r_out[j] * math.sin(2 * math.pi * j / n))
                 for j in range(n)]
        quads = [(j, n + j, n + (j + 1) % n, (j + 1) % n) for j in range(n)]
        return self.flat(name, [inner, outer], y, mat, back, quads)


def mark_holdout(root) -> None:
    stack = list(root.children)
    while stack:
        obj = stack.pop()
        stack.extend(obj.children)
        obj.is_holdout = True


def clear_subject(subject) -> None:
    stack, doomed = list(subject.children), []
    while stack:
        obj = stack.pop()
        stack.extend(obj.children)
        doomed.append(obj)
    for obj in doomed:
        data = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)


# --------------------------------------------------------------------------- #
# Printed target sheet and impacts
# --------------------------------------------------------------------------- #

def target_sheet(k: Kit, yf: float, back_paint: str | None) -> None:
    """Sheet centred on (0, 0) of the kit, front face at y = yf facing -Y."""
    w, h = SHEET_W / 2, SHEET_H / 2
    k.box("sheet_paper", (0, yf + SHEET_T / 2, 0), (SHEET_W, SHEET_T, SHEET_H), "paper")
    if back_paint:  # visible back of the sheet (stand seen from N or W)
        k.flat("sheet_back", [[(-w, -h), (w, -h), (w, h), (-w, h)]], yf + SHEET_T + 0.0004,
               back_paint, back=True)
    y1, y2 = yf - 0.0004, yf - 0.0008
    k.disc("print_bull", 0, 0, [R_BULL] * 64, y1, "ink")
    k.annulus("print_x_ring", 0, 0, 0.050, 0.058, y2, "paper")
    k.disc("print_x_dot", 0, 0, [0.014] * 24, y2, "paper")
    for name, r, width in (("print_ring_inner", R_INNER, 0.010), ("print_ring_outer", R_OUTER, 0.010),
                           ("print_line_a", 0.1425, 0.005), ("print_line_b", 0.2175, 0.005)):
        k.annulus(name, 0, 0, r - width / 2, r + width / 2, y1, "ink")
    # Border line and header bar, as on a printed range target.
    b = 0.012
    frame_in = [(-w + b, -h + b), (w - b, -h + b), (w - b, h - b), (-w + b, h - b)]
    frame_out = [(-w + b - 0.006, -h + b - 0.006), (w - b + 0.006, -h + b - 0.006),
                 (w - b + 0.006, h - b + 0.006), (-w + b - 0.006, h - b + 0.006)]
    k.flat("print_border", [frame_in, frame_out], y1, "ink",
           quads=[(j, 4 + j, 4 + (j + 1) % 4, (j + 1) % 4) for j in range(4)])
    top = h - 0.045
    k.flat("print_header", [[(-0.12, top - 0.012), (0.12, top - 0.012), (0.12, top + 0.012),
                             (-0.12, top + 0.012)]], y1, "ink")


def impact(k: Kit, slot: int, yf: float, through: bool) -> None:
    """Torn hole at a slot: dark core, frayed grey rim; on both faces if ``through``."""
    r, ang = IMPACTS[slot]
    cu, cv = r * math.cos(math.radians(ang)), r * math.sin(math.radians(ang))
    rng = random.Random(1000 + slot)
    n = 12
    core = [0.013 + 0.003 * rng.random() for _ in range(n)]
    rim = [0.024 + 0.008 * rng.random() if j % 2 else 0.020 + 0.003 * rng.random() for j in range(n)]
    faces = [(yf - 0.0012, yf - 0.0016, False)]
    if through:
        yb = yf + SHEET_T
        faces.append((yb + 0.0012, yb + 0.0016, True))
    for side, (y_rim, y_core, back) in enumerate(faces):
        k.annulus(f"impact{slot}_rim{side}", cu, cv, [c * 0.9 for c in core], rim, y_rim, "torn", back)
        k.disc(f"impact{slot}_core{side}", cu, cv, core, y_core, "hole", back)


# --------------------------------------------------------------------------- #
# Objects (front toward -Y = south)
# --------------------------------------------------------------------------- #

def build_wall_target(k: Kit, slot: int | None = None, overlay_only=False):
    """Plywood board hung on the north wall; the printed sheet pinned on it."""
    yb = 0.5 - WALL_GAP
    board_front = yb - BOARD_T
    yf = board_front - SHEET_T
    base = k.empty("wall_target", (0, 0, WALL_Z))
    base.box("board", (0, yb - BOARD_T / 2, 0), (BOARD_W, BOARD_T, BOARD_H), "plywood", bevel=0.25)
    for sx in (-1, 1):
        base.cyl(f"screw_{sx}", (sx * (BOARD_W / 2 - 0.03), board_front - 0.002, BOARD_H / 2 - 0.03),
                 0.009, 0.006, "nail", rot=(math.pi / 2, 0, 0), segs=12)
    target_sheet(base, yf, None)
    for i, (su, sv) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        base.cyl(f"pin_{i}", (su * (SHEET_W / 2 - 0.022), yf - 0.006, sv * (SHEET_H / 2 - 0.022)),
                 0.011, 0.012, "pin", rot=(math.pi / 2, 0, 0), segs=12)
    overlay = []
    if slot is not None:
        hole = k.empty("wall_impact", (0, 0, WALL_Z))
        impact(hole, slot, yf, through=False)
        overlay = [hole]
        mark_holdout(base.anchor)
    return overlay


def build_stand(k: Kit, slot: int | None = None, holes=()):
    """Easel: two uprights and a rear leg; a batten frame carries the sheet."""
    front = k.empty("stand_front", (0, -0.17, 0), (STAND_LEAN, 0, 0))
    for sx in (-1, 1):
        front.box(f"upright_{sx}", (sx * 0.25, 0, 0.86), (0.045, 0.035, 1.72), "pine", bevel=0.15)
    front.box("low_rail", (0, 0.0, 0.34), (0.54, 0.03, 0.05), "pine", bevel=0.15)
    front.box("top_rail", (0, 0.0, 1.66), (0.54, 0.03, 0.05), "pine", bevel=0.15)
    front.box("ledge", (0, -0.045, STAND_Z - SHEET_H / 2 - 0.05), (0.66, 0.075, 0.03), "pine", bevel=0.15)
    fw, fh, bw = 0.63, 0.72, 0.035
    yfr = -0.0175 - 0.011
    for name, c, size in (("frame_top", (0, yfr, STAND_Z + fh / 2 - bw / 2), (fw, 0.022, bw)),
                          ("frame_bot", (0, yfr, STAND_Z - fh / 2 + bw / 2), (fw, 0.022, bw)),
                          ("frame_l", (-fw / 2 + bw / 2, yfr, STAND_Z), (bw, 0.022, fh)),
                          ("frame_r", (fw / 2 - bw / 2, yfr, STAND_Z), (bw, 0.022, fh))):
        front.box(name, c, size, "pine", bevel=0.15)
    yf = yfr - 0.011 - SHEET_T
    sheet = front.empty("stand_sheet", (0, 0, STAND_Z))
    target_sheet(sheet, yf, "paperback")
    for i, (su, sv) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1), (0, 1), (0, -1))):
        sheet.box(f"staple_{i}", (su * (SHEET_W / 2 - 0.012), yf - 0.001, sv * (SHEET_H / 2 - 0.012)),
                  (0.016, 0.002, 0.004), "nail")
    # Rear leg hinged under the top rail (world frame of the subject).
    c, s = math.cos(STAND_LEAN), math.sin(STAND_LEAN)
    hinge = Vector((0, -0.17 + 0.03 * c - 1.63 * s, 0.03 * s + 1.63 * c))
    foot = Vector((0, 0.40, 0.0))
    k.beam("rear_leg", hinge, foot, 0.045, 0.035, "pine")
    k.beam("spreader", (0, -0.17 - 0.34 * s, 0.34 * c), foot + Vector((0, -0.05, 0.30)), 0.03, 0.02, "pine")
    k.cyl("hinge", hinge, 0.012, 0.09, "nail", rot=(0, math.pi / 2, 0), segs=12)
    for sl in holes:  # showcase only
        impact(sheet, sl, yf, through=True)
    if slot is None:
        return []
    mark_holdout(k.anchor)
    hole = front.empty("stand_impact", (0, 0, STAND_Z))
    impact(hole, slot, yf, through=True)
    return [hole]


def cinder_block(k: Kit, name, c):
    """Cinder block (0.26 x 0.19 x 0.19) with its two cells open to the front."""
    x, y, z = c
    w, d, h, wall = 0.26, 0.19, 0.19, 0.032
    k.box(f"{name}_bottom", (x, y, z - h / 2 + wall / 2), (w, d, wall), "cinder", bevel=0.1)
    k.box(f"{name}_top", (x, y, z + h / 2 - wall / 2), (w, d, wall), "cinder", bevel=0.1)
    for i, dx in enumerate((-w / 2 + wall / 2, 0, w / 2 - wall / 2)):
        k.box(f"{name}_web{i}", (x + dx, y, z), (wall, d, h - 2 * wall + 0.002), "cinder")
    k.box(f"{name}_shadow", (x, y, z), (w - 0.01, 0.006, h - 0.01), "slit")


def can(k: Kit, slot: int, x: float):
    z0 = PLANK_TOP
    c = k.empty(f"can_{slot}", (x, 0.0, z0))
    c.cyl("body", (0, 0, CAN_H / 2), CAN_R, CAN_H, "tin", segs=28)
    c.cyl("label", (0, 0, CAN_H * 0.48), CAN_R + 0.0015, CAN_H * 0.68, f"label{slot}", segs=28, caps=False)
    c.cyl("stripe", (0, 0, CAN_H * 0.50), CAN_R + 0.0025, CAN_H * 0.14, "stripe", segs=28, caps=False)
    c.torus("rim_top", (0, 0, CAN_H - 0.003), CAN_R - 0.002, 0.0035, "tin", segs=28, tube=6)
    c.torus("rim_bot", (0, 0, 0.003), CAN_R - 0.002, 0.0035, "tin", segs=28, tube=6)
    return c


def build_can_stand(k: Kit, slot: int | None = None, cans=()):
    """Pine plank on two stacks of cinder blocks."""
    for sx in (-1, 1):
        for level in range(2):
            cinder_block(k, f"block_{sx}_{level}", (sx * 0.30, 0.0, 0.095 + 0.19 * level + 0.0005 * level))
    k.box("plank", (0, 0, PLANK_TOP - 0.0175), (0.95, 0.22, 0.035), "pine", bevel=0.15)
    for i, x in enumerate((-0.30, 0.30)):
        for j, y in enumerate((-0.06, 0.06)):
            k.cyl(f"nailhead_{i}{j}", (x, y, PLANK_TOP + 0.0005), 0.007, 0.002, "nail", segs=10)
    for sl in cans:  # showcase only
        can(k, sl, CAN_X[sl])
    if slot is None:
        return []
    mark_holdout(k.anchor)
    return [can(k, slot, CAN_X[slot])]


# -- training dummy ---------------------------------------------------------- #
TORSO = [(0.050, 0.80), (0.120, 0.83), (0.150, 0.88), (0.160, 0.98), (0.168, 1.10),
         (0.182, 1.22), (0.190, 1.32), (0.178, 1.40), (0.125, 1.450), (0.050, 1.475)]
TORSO_SX, TORSO_SY = 1.18, 0.86
HEAD = [(0.030, 1.505), (0.070, 1.52), (0.098, 1.56), (0.106, 1.62), (0.098, 1.68),
        (0.072, 1.72), (0.030, 1.74), (0.004, 1.745)]


def _torso_radius(z: float) -> float:
    for (r0, z0), (r1, z1) in zip(TORSO, TORSO[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return TORSO[-1][0]


def torso_point(phi_deg: float, z: float, out: float = 0.0) -> tuple[Vector, Vector]:
    """Point on the burlap torso and its outward normal; phi -90 = front (-Y)."""
    a = math.radians(phi_deg)
    r = _torso_radius(z) + out
    p = Vector((r * TORSO_SX * math.cos(a), r * TORSO_SY * math.sin(a), z))
    n = Vector((math.cos(a) / TORSO_SX, math.sin(a) / TORSO_SY, 0)).normalized()
    return p, n


def straw_tuft(k: Kit, name: str, p: Vector, n: Vector, size: float, seed: int, count=9, radius=0.0045):
    rng = random.Random(seed)
    for i in range(count):
        d = (n + Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), rng.uniform(-0.5, 0.9)))).normalized()
        length = size * rng.uniform(0.5, 1.0)
        start = p - n * 0.012
        k.rod(f"{name}_{i}", start, start + d * length, radius, "straw", segs=5)


def slit(k: Kit, name: str, surface, phi: float, z: float, length: float, angle: float, at=None, width=0.022):
    """Dark cut in the burlap, wrapped onto the torso (subdivided quad + shrinkwrap)."""
    p, n = at if at is not None else torso_point(phi, z, 0.02)
    steps, w = 6, width
    verts = []
    for i in range(steps + 1):
        t = (i / steps - 0.5) * length
        for s in (-w / 2, w / 2):
            verts.append((t * math.cos(angle) - s * math.sin(angle), 0, t * math.sin(angle) + s * math.cos(angle)))
    faces = [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(steps)]
    obj = k.mesh(name, verts, faces, "slit", tuple(p), (0, 0, math.atan2(n.y, n.x) + math.pi / 2))
    mod = obj.modifiers.new("wrap", "SHRINKWRAP")
    mod.target, mod.wrap_method, mod.offset = surface, "NEAREST_SURFACEPOINT", 0.003
    return obj


def chest_mark(k: Kit, surface):
    """Painted red ring and dot on the chest, wrapped onto the burlap."""
    p, _n = torso_point(-90, 1.18, 0.02)
    for name, r_in, r_out in (("mark_ring", 0.050, 0.068), ("mark_dot", 0.0, 0.022)):
        obj = k.annulus(name, 0, 0, max(r_in, 0.001), r_out, 0, "redpaint", segs=40)
        obj.location = tuple(p)
        mod = obj.modifiers.new("wrap", "SHRINKWRAP")
        mod.target, mod.wrap_method, mod.offset = surface, "NEAREST_SURFACEPOINT", 0.0025


def _deg(a: float) -> float:
    """Lathe angle (radians, 0..2pi) to degrees in (-180, 180]; -90 = front."""
    d = math.degrees(a) % 360.0
    return d - 360.0 if d > 180.0 else d


def _in_holes(holes, i, j, a, z, seed) -> bool:
    """Inside one of the (phi0, phi1, z0, z1) holes, with a ragged edge."""
    r = random.Random(seed * 7919 + i * 97 + j)
    deg, jp, jz = _deg(a), r.uniform(-11, 11), r.uniform(-0.035, 0.035)
    return any(p0 + jp < deg < p1 + jp and z0 + jz < z < z1 + jz for p0, p1, z0, z1 in holes)


def sack(k: Kit, name, profile, skip, sx=TORSO_SX, sy=TORSO_SY, segs=36, loc=(0, 0, 0)):
    """Burlap shell with its torn faces removed; the inner side is darker."""
    obj = k.lathe(name, profile, "burlap", loc=loc, sx=sx, sy=sy, segs=segs, skip=skip)
    obj.data.materials.append(k.mats["burlap_in"])
    solid = obj.modifiers.new("cloth", "SOLIDIFY")
    solid.thickness, solid.offset, solid.material_offset = 0.014, -1, 1
    return obj


def straw_blob(k: Kit, name, p: Vector, n: Vector, r: float, seed: int, count=10):
    """Clump of straw bursting out along n: a lumpy mound and loose stalks."""
    blob = k.lathe(name, [(0.001, -0.6 * r), (0.8 * r, -0.45 * r), (r, 0.0), (0.75 * r, 0.55 * r), (0.001, 0.8 * r)],
                   "straw", loc=tuple(p), segs=14)
    blob.rotation_euler = n.to_track_quat("Z", "Y").to_euler()
    straw_tuft(k, f"{name}_t", p + n * 0.3 * r, n, 2.2 * r, seed, count=count, radius=0.006)


def flap(k: Kit, name, phi: float, z: float, width: float, length: float, seed: int, out=0.05):
    """Torn panel of burlap hanging from the torso: bent strip with a ragged end."""
    p, n = torso_point(phi, z, 0.006)
    t = Vector((-n.y, n.x, 0.0)).normalized() * (width / 2)
    r = random.Random(seed)
    rows = [(p, 1.0), (p + n * out - Vector((0, 0, 0.45 * length)), 0.95),
            (p + n * out * 1.5 - Vector((0, 0, length)), 0.85)]
    verts = []
    for c, s in rows:
        verts += [tuple(c - t * s), tuple(c + t * s)]
    tip = rows[-1][0] - Vector((0, 0, r.uniform(0.03, 0.07)))
    verts.append(tuple(tip + t * r.uniform(-0.4, 0.4)))
    faces = [(0, 1, 3, 2), (2, 3, 5, 4), (4, 5, 6)]
    obj = k.mesh(name, verts, faces, "burlap")
    obj.data.materials.append(k.mats["burlap_in"])
    solid = obj.modifiers.new("cloth", "SOLIDIFY")
    solid.thickness, solid.material_offset = 0.008, 1
    return obj


def floor_litter(k: Kit, name, center, radius, straw_bits, scraps, seed, pile=0.0):
    """Straw pile, loose stalks and burlap scraps at the foot of the dummy."""
    r = random.Random(seed)
    cx, cy = center
    if pile:
        k.lathe(f"{name}_pile", [(pile, 0.0), (0.9 * pile, 0.03), (0.6 * pile, 0.07), (0.001, 0.09 * pile / 0.2)],
                "straw", loc=(cx, cy, 0.0), sx=1.15, sy=0.85, segs=20)
    for i in range(straw_bits):
        a, d = r.uniform(0, 2 * math.pi), r.uniform(0.35, 1.0) * radius
        p0 = Vector((cx + d * math.cos(a), cy + d * math.sin(a), 0.008))
        k.rod(f"{name}_bit{i}", p0, p0 + Vector((r.uniform(-.09, .09), r.uniform(-.09, .09), 0.01)),
              0.006, "straw", segs=5)
    for i in range(scraps):
        a, d = r.uniform(0, 2 * math.pi), r.uniform(0.3, 1.0) * radius
        w, h = r.uniform(0.07, 0.13), r.uniform(0.05, 0.10)
        k.box(f"{name}_scrap{i}", (cx + d * math.cos(a), cy + d * math.sin(a), 0.004), (w, h, 0.006),
              "burlap", rot=(r.uniform(-0.15, 0.15), r.uniform(-0.15, 0.15), r.uniform(0, math.pi)))


def splinters(k: Kit, name, p1: Vector, d: Vector, rng, count=4, radius=0.009):
    for i in range(count):
        tip = p1 + d * rng.uniform(0.03, 0.08) + Vector(tuple(rng.uniform(-.02, .02) for _ in range(3)))
        k.rod(f"{name}_{i}", p1 - d * 0.01, tip, radius, "oak", segs=5)


def arm(k: Kit, sx: int, mode: str, rng):
    """Oak arm: full, splintered (tip broken), hang (broken, lower half hangs by a
    rope), stub (short splintered stump) or none (torn socket only)."""
    p0 = Vector((sx * 0.12, -0.03, 1.33))
    d = Vector((sx * 0.85, -0.50, -0.12)).normalized()
    reach = {"full": 0.40, "splint": 0.29, "hang": 0.17, "stub": 0.11, "none": 0.0}[mode]
    if mode == "none":
        return
    p1 = p0 + d * reach
    k.rod(f"arm_{sx}", p0, p1, 0.026, "oak", segs=12)
    if mode == "full":
        band = k.torus(f"arm_band_{sx}", (0, 0, 0), 0.026, 0.006, "rope", segs=16, tube=6)
        k._aligned(band, p1 - d * 0.10, p1 - d * 0.10 + d * 0.001)
        k.rod(f"arm_cap_{sx}", p1 - d * 0.005, p1 + d * 0.012, 0.030, "oak", segs=12)
        return
    splinters(k, f"splinter_{sx}", p1, d, rng)
    if mode == "hang":
        knot = p1 + d * 0.02
        k.torus(f"arm_knot_{sx}", tuple(knot), 0.030, 0.008, "rope", segs=16, tube=6)
        low = knot + Vector((sx * 0.05, -0.04, -0.27))
        k.rod(f"arm_hanging_{sx}", knot + Vector((0, 0, -0.02)), low, 0.025, "oak", segs=12)
        splinters(k, f"splinter_low_{sx}", knot + Vector((0, 0, -0.02)), Vector((0, 0, 1)), rng, 3, 0.008)
        k.rod(f"arm_hanging_cap_{sx}", low, low + (low - knot).normalized() * 0.015, 0.030, "oak", segs=12)


def core(k: Kit, name, scale, skip=None):
    obj = k.lathe(name, [(r * scale, z) for r, z in TORSO[1:-1]], "straw", sx=TORSO_SX, sy=TORSO_SY,
                  segs=36, skip=skip)
    obj.modifiers.new("wrap", "SOLIDIFY").thickness = 0.02
    return obj


def _dummy_intact(k: Kit):
    torso = k.lathe("torso", TORSO, "burlap", sx=TORSO_SX, sy=TORSO_SY, segs=36)
    solid = torso.modifiers.new("cloth", "SOLIDIFY")
    solid.thickness, solid.offset = 0.012, -1
    k.torus("tie_waist", (0, 0, 0.845), 0.118, 0.012, "rope", sx=TORSO_SX, sy=TORSO_SY)
    k.torus("tie_neck", (0, 0, 1.462), 0.085, 0.011, "rope", sx=TORSO_SX, sy=TORSO_SY)
    k.cyl("neck", (0, 0, 1.49), 0.045, 0.05, "burlap", segs=16)
    k.lathe("head", HEAD, "burlap", sx=1.0, sy=0.92, segs=28)
    k.torus("tie_head", (0, 0, 1.522), 0.068, 0.010, "rope")
    for sx in (1, -1):
        p0 = Vector((sx * 0.12, -0.03, 1.33))
        d = Vector((sx * 0.85, -0.50, -0.12)).normalized()
        p1 = p0 + d * 0.40
        k.rod(f"arm_{sx}", p0, p1, 0.026, "oak", segs=12)
        band = k.torus(f"arm_band_{sx}", (0, 0, 0), 0.026, 0.006, "rope", segs=16, tube=6)
        k._aligned(band, p1 - d * 0.10, p1 - d * 0.10 + d * 0.001)
        k.rod(f"arm_cap_{sx}", p1 - d * 0.005, p1 + d * 0.012, 0.030, "oak", segs=12)
    chest_mark(k, torso)


#: Wear states: holes in the sack (phi0, phi1, z0, z1; phi -90 = front, 90 = back),
#: straw bursts (phi, z, radius), hanging flaps (phi, z, width, length), cuts
#: (phi, z, length, angle), arms (right, left), floor litter.
WEAR = {
    1: {"holes": [(-148, -100, 0.90, 1.19), (46, 108, 0.98, 1.28), (140, 180, 0.92, 1.14)],
        "bursts": [(-124, 1.05, 0.08), (77, 1.14, 0.08), (160, 1.03, 0.065)],
        "flaps": [(-124, 0.92, 0.13, 0.24), (77, 1.00, 0.14, 0.23), (160, 0.94, 0.10, 0.18)],
        "cuts": [(-68, 1.28, 0.19, 0.6), (-58, 1.00, 0.16, 1.2), (118, 1.30, 0.18, 0.4), (35, 1.10, 0.15, 1.3)],
        "cut_tufts": [(-68, 1.28, 0.08), (118, 1.30, 0.08), (35, 1.10, 0.07)],
        "arms": ("full", "splint"), "litter": (10, 1, 0.0)},
    2: {"holes": [(-152, -52, 0.92, 1.33), (48, 142, 0.97, 1.35), (-24, 22, 1.07, 1.27)],
        "bursts": [(-120, 1.05, 0.08), (-80, 1.22, 0.075), (-70, 0.99, 0.07), (95, 1.15, 0.085),
                   (70, 1.28, 0.065), (125, 1.02, 0.07), (0, 1.17, 0.065)],
        "flaps": [(-130, 1.33, 0.12, 0.26), (-65, 1.34, 0.11, 0.22), (-100, 0.93, 0.10, 0.18),
                  (70, 1.36, 0.12, 0.25), (125, 1.35, 0.11, 0.22), (0, 1.28, 0.09, 0.20)],
        "cuts": [(170, 1.22, 0.18, 0.9), (-170, 1.00, 0.16, -0.5)],
        "cut_tufts": [(170, 1.22, 0.09)],
        "arms": ("full", "hang"), "litter": (18, 4, 0.19)},
}


def _wear_common(k: Kit, w: dict, state: int):
    for i, (phi, z, r) in enumerate(w["bursts"]):
        p, n = torso_point(phi, z, -0.03)
        straw_blob(k, f"burst_{i}", p, n, r, 500 + 20 * state + i)
    for i, (phi, z, width, length) in enumerate(w["flaps"]):
        flap(k, f"flap_{i}", phi, z, width, length, 600 + 20 * state + i)


def _dummy_worn(k: Kit, state: int, rng):
    """States 1 and 2: torn sack over a straw core, flaps, bursts, damaged arms."""
    w = WEAR[state]
    torso = sack(k, "torso", TORSO, lambda i, j, a, z: _in_holes(w["holes"], i, j, a, z, state))
    core(k, "straw_core", 0.86)
    k.torus("tie_waist", (0, 0, 0.845), 0.118, 0.012, "rope", sx=TORSO_SX, sy=TORSO_SY)
    k.torus("tie_neck", (0, 0, 1.462), 0.085, 0.011, "rope", sx=TORSO_SX, sy=TORSO_SY)
    k.cyl("neck", (0, 0, 1.49), 0.045, 0.05, "burlap", segs=16)
    if state == 1:
        chest_mark(k, torso)
        head = k.lathe("head", HEAD, "burlap", sx=1.0, sy=0.92, segs=28)
        slit(k, "head_cut", head, -90, 1.64, 0.08, 0.3, at=(Vector((0.0, -0.12, 1.64)), Vector((0, -1, 0))))
    else:  # head split open on the front and top, half emptied
        split = [(-175, -5, 1.585, 1.80), (-60, 20, 1.62, 1.80)]
        sack(k, "head", HEAD, lambda i, j, a, z: _in_holes(split, i, j, a, z, 9), sx=1.0, sy=0.92, segs=28)
        k.lathe("head_straw", [(0.001, 1.53), (0.07, 1.56), (0.075, 1.60), (0.05, 1.64), (0.001, 1.655)],
                "straw", sy=0.9, segs=16)
        straw_tuft(k, "head_tuft", Vector((0.0, -0.04, 1.64)), Vector((0.1, -0.7, 0.7)).normalized(), 0.13, 460,
                   count=12, radius=0.006)
    k.torus("tie_head", (0, 0, 1.522), 0.068, 0.010, "rope")
    for i, (phi, z, length, angle) in enumerate(w["cuts"]):
        slit(k, f"slit_{i}", torso, phi, z, length, angle, width=0.032)
    for i, (phi, z, size) in enumerate(w["cut_tufts"]):
        p, n = torso_point(phi, z, 0.004)
        straw_tuft(k, f"tuft_{i}", p, n, size, 100 * state + i, count=12, radius=0.006)
    _wear_common(k, w, state)
    for sx, mode in zip((1, -1), w["arms"]):
        arm(k, sx, mode, rng)
    bits, scraps, pile = w["litter"]
    floor_litter(k, "litter", (0.05, -0.12), 0.36, bits, scraps, 700 + state, pile)


def _shreds_keep(i, j, a, z) -> bool:
    """Tattered sack: shoulder yoke, a skirt at the back and dangling strips."""
    r = random.Random(3 * 7919 + i * 97 + j)
    deg = _deg(a)
    if z > 1.385:
        return r.random() > 0.2
    if z < 0.90:
        return not (-140 < deg < -40) and r.random() > 0.25
    for k0, centre in enumerate((-155, -100, -35, 25, 80, 140)):
        bottom = 1.02 + 0.05 * (k0 % 3)
        if abs(deg - centre) < 8 + r.uniform(-3, 3) and z > bottom:
            return True
    return False


def _dummy_shredded(k: Kit, rng):
    """State 3: sack in tatters, armature bare, head torn off, arms broken."""
    sack(k, "torso", TORSO, lambda i, j, a, z: not _shreds_keep(i, j, a, z))
    k.box("shoulder_bar", (0, 0, 1.36), (0.34, 0.055, 0.05), "oak", bevel=0.15)
    k.box("waist_bar", (0, 0, 1.00), (0.26, 0.05, 0.045), "oak", rot=(0, 0, math.pi / 2), bevel=0.15)
    k.beam("rib_l", (-0.16, 0, 1.34), (-0.05, 0, 1.02), 0.035, 0.03, "oak")
    k.beam("rib_r", (0.16, 0, 1.34), (0.05, 0, 1.02), 0.035, 0.03, "oak")
    core(k, "straw_rest", 0.55, skip=lambda i, j, a, z: random.Random(i * 31 + j).random() < 0.45 or z > 1.30)
    for i, (phi, z, r) in enumerate(((-110, 1.10, 0.06), (60, 1.20, 0.06), (150, 1.05, 0.05))):
        p, n = torso_point(phi, z, -0.08)
        straw_blob(k, f"burst_{i}", p, n, r, 800 + i)
    for i, phi in enumerate((-150, -95, -35, 30, 85, 140, 180)):
        flap(k, f"rag_{i}", phi, 1.37, 0.07 + 0.02 * (i % 2), 0.22 + 0.05 * (i % 3), 900 + i, out=0.03)
    k.torus("tie_neck", (0, 0, 1.462), 0.085, 0.011, "rope", sx=TORSO_SX, sy=TORSO_SY)
    k.cyl("neck", (0, 0, 1.49), 0.045, 0.05, "burlap", segs=16)
    straw_tuft(k, "neck_tuft", Vector((0, 0, 1.51)), Vector((0, 0, 1)), 0.12, 910, count=14, radius=0.006)
    # Head torn off, lying gutted on the floor.
    head = k.empty("fallen_head", (0.24, -0.20, 0.095), (math.pi / 2 - 0.3, 0, 0.7))
    sack(head, "head", [(r, z - 1.625) for r, z in HEAD],
         lambda i, j, a, z: _in_holes([(-180, 180, 0.05, 0.2)], i, j, a, z, 11), sx=1.0, sy=0.92, segs=28)
    head.lathe("head_straw", [(0.001, -0.07), (0.07, -0.04), (0.075, 0.02), (0.05, 0.08), (0.001, 0.10)],
               "straw", segs=16)
    straw_tuft(head, "head_tuft", Vector((0, 0, 0.08)), Vector((0, 0, 1)), 0.12, 920, count=12, radius=0.006)
    arm(k, 1, "stub", rng)
    arm(k, -1, "none", rng)
    stick = Vector((-0.30, 0.10, 0.03))
    k.rod("arm_on_floor", stick, stick + Vector((0.20, 0.17, 0.0)), 0.026, "oak", segs=12)
    splinters(k, "floor_splinter", stick, Vector((-0.76, -0.65, 0)), rng, 3)
    floor_litter(k, "litter", (0.02, -0.10), 0.42, 26, 7, 703, pile=0.26)


def build_dummy(k: Kit, state: int):
    rng = random.Random(40 + state)
    # Base: crossed feet, braces, post.
    for i, rot in enumerate((0.0, math.pi / 2)):
        k.box(f"foot_{i}", (0, 0, 0.035), (0.72, 0.09, 0.07), "oak", rot=(0, 0, rot), bevel=0.15)
    for i, (dx, dy) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
        k.beam(f"brace_{i}", (dx * 0.26, dy * 0.26, 0.07), (dx * 0.03, dy * 0.03, 0.36), 0.035, 0.03, "oak")
    k.box("post", (0, 0, 0.80), (0.075, 0.075, 1.50), "oak", bevel=0.12)
    if state == 0:
        _dummy_intact(k)
    elif state in WEAR:
        _dummy_worn(k, state, rng)
    else:
        _dummy_shredded(k, rng)
    return []


# --------------------------------------------------------------------------- #
# Tile groups (contract with docs/assets-spec.md)
# --------------------------------------------------------------------------- #

def _builder(key: str):
    """Builder of a group key (see _index_map)."""
    if key in ("wall", "stand", "cans"):
        return {"wall": build_wall_target, "stand": build_stand, "cans": build_can_stand}[key]
    if key.startswith("dummy"):
        return lambda k, s=int(key[5:]): build_dummy(k, s)
    slot = int(key.rsplit("_", 1)[1])
    base = {"hole_wall": build_wall_target, "hole_stand": build_stand, "can": build_can_stand}[key.rsplit("_", 1)[0]]
    return lambda k: base(k, slot)


def tile_groups() -> list[dict]:
    """Every render group: key, sprite indices in facing order (S, E[, N, W]), builder.
    The builder returns the overlay parts (empty for a base object)."""
    return [{"key": key, "indices": indices, "overlay": key.startswith(("hole", "can_")),
             "build": _builder(key)} for key, indices in _index_map().items()]


def build_group(subject, mats, group) -> list:
    """Clear the subject and build one group; returns the overlay objects' names."""
    clear_subject(subject)
    overlay = group["build"](Kit(subject, mats))
    names = set()
    stack = [getattr(part, "anchor", part) for part in overlay]
    while stack:
        obj = stack.pop()
        names.add(obj.name)
        stack.extend(obj.children)
    return sorted(names)


def build(subject, mats) -> None:
    """Showcase of the four objects (editable .blend, preview)."""
    k = Kit(subject, mats)
    wall = k.empty("show_wall", (-1.20, 0.95, 0))
    build_wall_target(wall)
    hole = wall.empty("show_wall_holes", (0, 0, WALL_Z))
    for sl in (1, 5, 7, 10):
        impact(hole, sl, 0.5 - WALL_GAP - BOARD_T - SHEET_T, through=False)
    build_stand(k.empty("show_stand", (0.05, 0.45, 0), (0, 0, math.radians(-15))), holes=(0, 4, 9, 11))
    build_can_stand(k.empty("show_cans", (0.55, -0.55, 0), (0, 0, math.radians(8))), cans=(0, 2, 3, 5))
    build_dummy(k.empty("show_dummy", (1.45, 0.60, 0), (0, 0, math.radians(-25))), 1)


# --------------------------------------------------------------------------- #
# Rendering (Blender)
# --------------------------------------------------------------------------- #

def render_preview(scene, subject, mats, out: str) -> None:
    """512x512 perspective of the four objects on a sober floor and wall."""
    clear_subject(subject)
    build(subject, mats)
    k = Kit(subject, mats)
    floor_mat = F.forge_material("batman_tt_floor", "wood", (0.30, 0.29, 0.26))
    wall_mat = F.forge_material("batman_tt_wallpv", "brick", (0.55, 0.55, 0.52))
    k.mats = dict(mats, floor=floor_mat, wallpv=wall_mat)
    k.box("pv_floor", (0.2, 0.0, -0.01), (12.0, 9.0, 0.02), "floor")
    k.box("pv_wall", (0.2, 1.5, 1.6), (12.0, 0.1, 3.2), "wallpv")
    cam = bpy.data.objects.new("TT_PreviewCam", bpy.data.cameras.new("TT_PreviewCam"))
    scene.collection.objects.link(cam)
    cam.data.lens = 50
    target = Vector((0.20, 0.25, 0.85))
    cam.location = target + Vector((1.0, -2.0, 0.95)).normalized() * 5.6
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    saved = (scene.camera, scene.render.resolution_x, scene.render.resolution_y, scene.render.filepath,
             scene.render.film_transparent)
    try:
        scene.camera = cam
        scene.render.resolution_x = scene.render.resolution_y = 512
        scene.render.film_transparent = False
        scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
    finally:
        (scene.camera, scene.render.resolution_x, scene.render.resolution_y, scene.render.filepath,
         scene.render.film_transparent) = saved


def main() -> None:
    out = Path(sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "build/training_cells")
    only = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
    if not bpy.app.background:
        raise SystemExit("render headless only (forge rig names are global)")
    scene = bpy.context.scene
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    F.register()
    scene.render.engine = "CYCLES"
    props = scene.pz_forge
    props.footprint_x = props.footprint_y = 1
    props.show_guide = False
    props.contrast_boost = 1.0
    props.toon_shading = True
    F.build_rig(bpy.context)
    # The toon beauty renders in EEVEE; the Cycles light pass is unused for toon
    # cells (pzforge build skips relight), so it runs at low quality.
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    subject = bpy.data.objects[F.SUBJECT_NAME]
    mats = materials()
    for group in tile_groups():
        if only and group["key"] not in only:
            continue
        build_group(subject, mats, group)
        props.sheet_name = group["key"]
        props.facings = str(len(group["indices"]))
        props.output_dir = str(out / group["key"])
        manifest = F.render_cells(bpy.context)
        print(f"rendered {group['key']}: {len(manifest['cells'])} cells")
    if not only or "preview" in only:
        render_preview(scene, subject, mats, str(out / "preview.png"))
        print(f"rendered preview to {out / 'preview.png'}")


# --------------------------------------------------------------------------- #
# Packaging (plain Python with Pillow + pzforge)
# --------------------------------------------------------------------------- #

PROPS = [
    (range(0, 2), {"CustomName": "Paper Target", "MoveType": "WallObject", "Material": "Paper",
                   "PickUpWeight": "10", "CanScrap": "", "ScrapSize": "Small"}),
    # Tools and weight copied from the vanilla wooden lectern (location_community_church_small_01_44).
    (range(2, 6), {"CustomName": "Target Stand", "solidtrans": "", "BlocksPlacement": "", "CanScrap": "",
                   "Material": "Wood", "PickUpWeight": "75", "PickUpTool": "Hammer", "PlaceTool": "Hammer"}),
    (range(8, 12), {"CustomName": "Can Stand", "solidtrans": "", "BlocksPlacement": "", "IsLow": "",
                    "container": "batmanTTCans", "ContainerCapacity": "3", "ContainerPosition": "Low",
                    "Material": "Wood", "CanScrap": "", "PickUpWeight": "60"}),
    (range(12, 28), {"CustomName": "Dummy", "solidtrans": "", "BlocksPlacement": "", "Material": "Wood",
                     "CanScrap": "", "PickUpWeight": "120"}),
]
FACING_NAMES = ["S", "E", "N", "W"]


def styled_cells(group_dir: Path, work: Path, overlay: bool) -> list:
    """Run pzforge build on one group; return its styled cells in facing order."""
    from PIL import Image
    from pzforge import cli
    dist = work / group_dir.name
    args = ["build", str(group_dir), "--out", str(dist), "--mod-id", "tt", "--tiledef-id", str(TILEDEF_ID)]
    if overlay:
        # Impacts and cans are tiny: tone matching and contour weight are tuned
        # on whole objects and would wash a black hole grey. Keep the toon render.
        args += ["--no-style"] if group_dir.name.startswith("hole") else ["--style-strength", "0"]
    if cli.main(args) != 0:
        raise RuntimeError(f"pzforge build failed for {group_dir}")
    sheet = Image.open(next(dist.rglob(f"{group_dir.name}.png"))).convert("RGBA")
    count = len(json.loads((group_dir / "manifest.json").read_text())["cells"])
    return [sheet.crop(((i % 8) * 128, (i // 8) * 256, (i % 8) * 128 + 128, (i // 8) * 256 + 256))
            for i in range(count)]


def package(cells_dir: Path, project: Path, write_preview: bool = True) -> None:
    from PIL import Image
    from pzforge.modgen import used_tiledef_ids
    from pzforge.sheet import Cell, Sheet, pack_sheet
    from pzforge.tiledef import TileDefinitions, Tile, Tileset

    # Installed mods checked for tiledef collisions: PZ_TILEDEF_ROOTS (os.pathsep-separated),
    # e.g. the game's Steam Workshop folder (steamapps/workshop/content/108600).
    roots = [Path(p) for p in os.environ.get("PZ_TILEDEF_ROOTS", "").split(os.pathsep) if p]
    taken = used_tiledef_ids(roots + [Path.home() / "Zomboid" / "mods", Path.home() / "Zomboid" / "Workshop"])
    owners = [o for o in taken.get(TILEDEF_ID, []) if SHEET not in o]
    if owners:
        raise SystemExit(f"tiledef {TILEDEF_ID} already used by {owners}")
    work = cells_dir / "_styled"
    images: dict[int, Image.Image] = {}
    index_map = _index_map()
    missing = [key for key in index_map if not (cells_dir / key / "manifest.json").exists()]
    if missing:
        raise SystemExit(f"groups not rendered: {missing}")
    for key in index_map:
        overlay = key.startswith(("hole", "can_"))
        for facing, img in enumerate(styled_cells(cells_dir / key, work, overlay)):
            images[index_map[key][facing]] = img
    total = 128
    blank = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
    cells = [Cell(images.get(i, blank), index=i) for i in range(total)]
    sheet = Sheet(SHEET, 128, 256, 8, cells)
    tiles = []
    for i in range(total):
        props = {}
        for rng_, extra in PROPS:
            if i in rng_:
                props = {"GroupName": "Training", "IsMoveAble": "", **extra,
                         "Facing": FACING_NAMES[(i - rng_.start) % (2 if rng_.start == 0 else 4)]}
        tiles.append(Tile(props))
    tdefs = TileDefinitions([Tileset(SHEET, f"{SHEET}.png", 8, total // 8, 1, tiles)])
    media = project / "Contents" / "mods" / MOD_ID / "common" / "media"
    (media / "texturepacks").mkdir(parents=True, exist_ok=True)
    pack_sheet(sheet).write(media / "texturepacks" / f"{SHEET}.pack")
    tdefs.write(media / f"{SHEET}.tiles")
    (cells_dir / f"{SHEET}.tiles.txt").write_text(tdefs.to_text(), encoding="ascii")
    sheet.image().save(cells_dir / f"{SHEET}_sheet.png")
    geometry = media / "tileGeometry.txt"
    geometry.write_text("tileGeometry\n{\n    VERSION = 2,\n}\n", encoding="ascii")
    if not write_preview:
        print(f"packed {len(images)} sprites into {media} (preview and poster left untouched)")
        return
    preview = Image.open(cells_dir / "preview.png").convert("RGB")
    for path in (project / "preview.png", project / "Contents" / "mods" / MOD_ID / "42.21" / "poster.png"):
        path.parent.mkdir(parents=True, exist_ok=True)
        preview.save(path, optimize=True)
    print(f"packed {len(images)} sprites into {media}")


def _index_map() -> dict:
    """Group key -> sprite indices, without Blender (mirror of tile_groups)."""
    m = {"wall": [0, 1], "stand": [2, 3, 4, 5], "cans": [8, 9, 10, 11]}
    for s in range(4):
        m[f"dummy{s}"] = list(range(12 + 4 * s, 16 + 4 * s))
    for sl in range(12):
        m[f"hole_wall_{sl:02d}"] = [32 + sl, 44 + sl]
        m[f"hole_stand_{sl:02d}"] = [56 + sl, 68 + sl, 80 + sl, 92 + sl]
    for sl in range(6):
        m[f"can_{sl}"] = [104 + sl, 110 + sl, 116 + sl, 122 + sl]
    return m


if __name__ == "__main__":
    if bpy is None:
        if len(sys.argv) not in (4, 5) or sys.argv[1] != "package" or sys.argv[4:] not in ([], ["--no-preview"]):
            raise SystemExit("usage: python build_training_targets.py package <cells-dir> <project-root> [--no-preview]")
        package(Path(sys.argv[2]), Path(sys.argv[3]), write_preview="--no-preview" not in sys.argv)
    else:
        main()
