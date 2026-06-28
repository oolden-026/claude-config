---
nickname: FireStairFloorCheck_v2
file: FireStairFloorCheck_v2.md
description: Merged component — counts apts per floor from assoc paths, flags floors needing fire stair, generates corridor/core surfaces, finds corridor-exterior overlap edges, outputs FloorPaths. Top floor per building excluded from all outputs.
---

## Purpose
Single component replacing the former `AptCoreCountsFromAssoc` + `FireStairFloorCheck_v2` pair.
Reads raw assoc path strings, counts apartments per floor internally, flags floors above threshold,
builds corridor and core surfaces, finds corridor-exterior junction edges, and outputs deduplicated
floor-level path prefixes (`Building1/V0`, …) for downstream categorisation.
**The highest floor per building is stripped from all outputs** (fire safety regulation does not
require a stair at the topmost level).

## Inputs
| Name | Type | Access | Source |
|---|---|---|---|
| `all_paths` | str | list | `pcAssocToKv (d11060da).Paths` |
| `core_names` | str | list | Panel (one name per line, e.g. `CVK46L2`) |
| `apt_threshold` | int | item | Number Slider (range 1–20, default 8) |
| `corridor_curves` | geometry | tree | `Building/Floor:CorridorCurve (ae5f208b)` — 20 branches, 1–2 closed polylines/branch |
| `outline_curves` | curve | tree | `Building/Floor:OutlineCurve (1a3cf2c2)` — 20 branches, 1 closed polyline/branch |
| `core_curves` | geometry | tree | Core boundary curves — same `{bldg_idx; floor_idx}` branching as corridor_curves |

**Geometry unwrap note:** items arrive as `System.Guid`. Use `scriptcontext.doc.Objects.FindId(guid)`
(not `Rhino.RhinoDoc.ActiveDoc`) — the latter returns `None` for GH-managed references.

## Outputs
| Name | Description |
|---|---|
| `Report` | Full text summary — top floors excluded, flagged floors, building totals, branch counts |
| `NeedsStair` | List of floor labels needing a stair: `["Building1/V0", …]` — top floor excluded |
| `NeedsStairMask` | Bool list, 1 per floor in sorted order (True = flagged) — top floor excluded |
| `CorridorSurfaces` | DataTree `{bldg_idx; floor_idx}`: planar Brep per corridor curve — top floor excluded |
| `CoreSurfaces` | DataTree `{bldg_idx; floor_idx}`: planar Brep per core curve — same structure, top floor excluded |
| `ExtCorridorWalls` | DataTree `{bldg_idx; floor_idx}`: line segments where corridor boundary lies on building outline — flagged floors only, top floor excluded |
| `FloorPaths` | Flat list of `Building{N}/V{floor}` path prefixes, sorted — top floor excluded |

## Design notes

### Top floor exclusion — order matters
1. Apply threshold → `flagged_all` (floors with apt count > threshold)
2. From `flagged_all`, find the highest `V{n}` floor per building → `top_flagged_set`
3. Exclude `top_flagged_set` from `NeedsStair`, `NeedsStairMask`, `ExtCorridorWalls`
`CorridorSurfaces`, `CoreSurfaces`, and `FloorPaths` keep **all floors** — no top-floor exclusion there.

### Apt counting
Path format: `Building{N}/V{floor}/{slot}/{name}/{instance}/{sublayer}`.
Deduplication by `(building, floor, slot, name, instance)` before counting.
Cores (matched by `core_names`) are excluded from apt count.

### CorridorSurfaces / CoreSurfaces
Shared helper `tree_to_surfaces(tree)` handles both via `to_breps()`:
- If item is already a `Brep` → passed through directly (handles Remote Receiver / surface inputs)
- If item is a `Curve` → `Brep.CreatePlanarBreps` 
- If item is a `Guid` → resolved via `sc.doc.Objects.FindId`, then dispatched to Brep or Curve branch
Path `{bldg_idx; floor_idx}` (0-indexed). All floors included.

### ExtCorridorWalls
For each flagged floor (top excluded): explode corridor polyline into segments, keep any segment
whose start/midpoint/end all lie within `TOL=0.1` of the outline curve.

## Wire connections
- `pcAssocToKv (d11060da).Paths` → `all_paths`
- Panel (`fa90bd9a`) → `core_names`
- Number Slider → `apt_threshold`
- `Building/Floor:CorridorCurve (ae5f208b)` → `corridor_curves`
- `Building/Floor:OutlineCurve (1a3cf2c2)` → `outline_curves`
- Core boundary curve container → `core_curves`
- `Report` → Panel
- `CorridorSurfaces` → Panel / Geometry container
- `CoreSurfaces` → Geometry container
- `ExtCorridorWalls` → Geometry container

## Code
```python
#! python3
"""
FireStairFloorCheck v2 (merged)
Counts apts per floor from assoc path strings (absorbs AptCoreCountsFromAssoc).
Flags floors needing a fire stair, builds corridor/core surfaces, finds corridor-exterior
overlap edges, and outputs deduplicated floor-level path prefixes.
Top floor per building is excluded from all outputs.
"""
from Grasshopper.Kernel.Data import GH_Path
from Grasshopper import DataTree
from collections import defaultdict
import Rhino.Geometry as rg
import scriptcontext as sc
import System

threshold = int(apt_threshold)

# ── helpers ─────────────────────────────────────────────────────────────────
def to_curve(obj):
    if isinstance(obj, rg.Curve):
        return obj
    if hasattr(obj, 'Value') and isinstance(obj.Value, rg.Curve):
        return obj.Value
    if isinstance(obj, System.Guid):
        rhobj = sc.doc.Objects.FindId(obj)
        if rhobj and isinstance(rhobj.Geometry, rg.Curve):
            return rhobj.Geometry
    return None

def path_to_bf(path):
    if path.Length >= 2:
        return path.Indices[0], path.Indices[1]
    elif path.Length == 1:
        return divmod(path.Indices[0], 10)
    return None, None

def floor_sort(f):
    try: return int(f.lstrip("V"))
    except: return 0

# ── 1. Count apts per floor from assoc path strings ───────────────────────
core_name_set = set(str(n).strip() for n in core_names)

seen = set()
apts = set()

for item in all_paths:
    parts = str(item).split("/")
    if len(parts) < 5:
        continue
    building, floor, slot, name, instance = parts[0], parts[1], parts[2], parts[3], parts[4]
    key = (building, floor, slot, name, instance)
    if key in seen:
        continue
    seen.add(key)
    if name not in core_name_set:
        apts.add((building, floor, slot, instance))

apt_map = defaultdict(int)
apt_per_bldg = defaultdict(int)
for (bldg, floor, slot, inst) in apts:
    apt_map[(bldg, floor)] += 1
    apt_per_bldg[bldg] += 1

# ── 2. Find and exclude top floor per building ────────────────────────────
top_fi_per_bldg = {}
for (bldg, floor) in apt_map.keys():
    fi = floor_sort(floor)
    if bldg not in top_fi_per_bldg or fi > top_fi_per_bldg[bldg]:
        top_fi_per_bldg[bldg] = fi

top_floor_set = {(bldg, f"V{fi}") for bldg, fi in top_fi_per_bldg.items()}

# ── 3. Flag floors (top floor excluded) ───────────────────────────────────
all_floor_keys = [
    k for k in sorted(apt_map.keys(), key=lambda k: (k[0], floor_sort(k[1])))
    if k not in top_floor_set
]
flagged_set = {
    (b, f) for (b, f), cnt in apt_map.items()
    if cnt > threshold and (b, f) not in top_floor_set
}
flagged_sorted = sorted(flagged_set, key=lambda x: (x[0], floor_sort(x[1])))

NeedsStair     = [f"{b}/{f}" for (b, f) in flagged_sorted]
NeedsStairMask = [(apt_map.get(k, 0) > threshold) for k in all_floor_keys]

# ── 4. FloorPaths ─────────────────────────────────────────────────────────
FloorPaths = [f"{bldg}/{floor}" for (bldg, floor) in all_floor_keys]

# ── helper: build planar brep surfaces from a curve tree, skip top floors ─
def curves_to_surfaces(curve_tree):
    out = DataTree[object]()
    for i in range(curve_tree.BranchCount):
        path = curve_tree.Paths[i]
        br   = curve_tree.Branches[i]
        if not br:
            continue
        bi, fi = path_to_bf(path)
        if bi is None:
            continue
        if (f"Building{bi + 1}", f"V{fi}") in top_floor_set:
            continue
        out_path = GH_Path(bi, fi)
        for raw in br:
            crv = to_curve(raw)
            if crv is None:
                continue
            try:
                breps = rg.Brep.CreatePlanarBreps(crv, 0.001)
                if breps:
                    for brep in breps:
                        out.Add(brep, out_path)
            except:
                pass
    return out

# ── 5. Corridor surfaces ──────────────────────────────────────────────────
CorridorSurfaces = curves_to_surfaces(corridor_curves)

# ── 6. Core surfaces ──────────────────────────────────────────────────────
CoreSurfaces = curves_to_surfaces(core_curves)

# ── 7. Corridor-exterior overlap edges ────────────────────────────────────
TOL = 0.1

def overlapping_segments(corridor_crv, outline_crv, tol):
    result = []
    segs = corridor_crv.DuplicateSegments()
    if not segs:
        return result
    for seg in segs:
        check_pts = [seg.PointAtStart, seg.PointAt(seg.Domain.Mid), seg.PointAtEnd]
        on_outline = True
        for pt in check_pts:
            ok, t = outline_crv.ClosestPoint(pt)
            if not ok or pt.DistanceTo(outline_crv.PointAt(t)) > tol:
                on_outline = False
                break
        if on_outline:
            result.append(seg)
    return result

outline_by_path = {}
for i in range(outline_curves.BranchCount):
    path = outline_curves.Paths[i]
    br   = outline_curves.Branches[i]
    if br:
        curves = [to_curve(x) for x in br]
        curves = [c for c in curves if c is not None]
        if curves:
            outline_by_path[tuple(path.Indices)] = curves

ExtCorridorWalls = DataTree[object]()
for i in range(corridor_curves.BranchCount):
    path = corridor_curves.Paths[i]
    br   = corridor_curves.Branches[i]
    if not br:
        continue
    bi, fi = path_to_bf(path)
    if bi is None:
        continue
    bldg_str = f"Building{bi + 1}"
    floor_str = f"V{fi}"
    if (bldg_str, floor_str) not in flagged_set:
        continue
    outlines = outline_by_path.get(tuple(path.Indices), [])
    if not outlines:
        continue
    out_path = GH_Path(bi, fi)
    for raw in br:
        corr_crv = to_curve(raw)
        if corr_crv is None:
            continue
        for outline_crv in outlines:
            for seg in overlapping_segments(corr_crv, outline_crv, TOL):
                ExtCorridorWalls.Add(seg, out_path)

# ── 8. Report ─────────────────────────────────────────────────────────────
top_excluded = sorted(top_floor_set, key=lambda x: (x[0], floor_sort(x[1])))
lines = [f"Threshold: {threshold} apts/floor", ""]
lines.append(f"Top floors excluded: {', '.join(f'{b} {f}' for b, f in top_excluded)}")
lines.append("")
lines.append(f"Flagged floors ({len(flagged_sorted)}):")
for (b, f) in flagged_sorted:
    lines.append(f"  {b}/{f}  →  {apt_map.get((b, f), 0)} apts")
lines.append("")
for bldg, total in sorted(apt_per_bldg.items()):
    lines.append(f"  {bldg}: {total} apts total")
lines.append("")
lines.append(f"Corridor surfaces: {CorridorSurfaces.BranchCount} branches")
lines.append(f"Core surfaces: {CoreSurfaces.BranchCount} branches")
lines.append(f"Corridor-exterior overlap edges: {ExtCorridorWalls.BranchCount} branches")
lines.append(f"Floor paths: {len(FloorPaths)}")

Report = "\n".join(lines)
print(Report)
```
