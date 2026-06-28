---
nickname: FireStairFloorCheck_v2
file: FireStairFloorCheck_v2.md
description: Merged component — counts apts per floor from assoc paths, flags floors needing fire stair, generates corridor surfaces, finds corridor-exterior overlap edges, outputs FloorPaths for post-processing.
---

## Purpose
Single component replacing the former `AptCoreCountsFromAssoc` + `FireStairFloorCheck_v2` pair.
Reads raw assoc path strings, counts apartments per floor internally, flags floors above threshold,
builds corridor surfaces, finds corridor-exterior junction edges, and outputs deduplicated
floor-level path prefixes (`Building1/V0`, …) for downstream categorisation.

## Inputs
| Name | Type | Access | Source |
|---|---|---|---|
| `all_paths` | str | list | `pcAssocToKv (d11060da).Paths` |
| `core_names` | str | list | Panel (one name per line, e.g. `CVK46L2`) |
| `apt_threshold` | int | item | Number Slider (range 1–20, default 8) |
| `corridor_curves` | geometry | tree | `Building/Floor:CorridorCurve (ae5f208b)` — 20 branches, 1–2 closed polylines/branch |
| `outline_curves` | curve | tree | `Building/Floor:OutlineCurve (1a3cf2c2)` — 20 branches, 1 closed polyline/branch |

**Geometry unwrap note:** items arrive as `System.Guid`. Use `scriptcontext.doc.Objects.FindId(guid)`
(not `Rhino.RhinoDoc.ActiveDoc`) — the latter returns `None` for GH-managed references.

## Outputs
| Name | Description |
|---|---|
| `Report` | Full text summary — flagged floors, building totals, branch counts |
| `NeedsStair` | List of floor labels needing a stair: `["Building1/V0", …]` — 14 items; same syntax as `FloorPaths` |
| `NeedsStairMask` | Bool list, 1 per floor in sorted order (True = flagged) — 20 items; use with Cull Pattern on `FloorPaths` |
| `CorridorSurfaces` | DataTree `{bldg_idx; floor_idx}`: planar Brep per corridor curve (all 20 floors, 38 Breps) |
| `ExtCorridorWalls` | DataTree `{bldg_idx; floor_idx}`: line segments where corridor boundary lies on building outline — flagged floors only (14 branches, 52 edges) |
| `FloorPaths` | Flat list of 20 unique `Building{N}/V{floor}` path prefixes, sorted — use as keys for downstream assoc/kv post-processing |

## Current results (threshold = 8, 2026-06-28)
- 14 floors flagged: Building1+2 V0–V6 (10–13 apts)
- 6 not flagged: Building1+2 V7–V9 (4 apts)
- Building1 + Building2: 85 apts each
- 20 corridor surfaces (38 Breps); 14 branches / 52 ExtCorridorWalls segments
- 20 FloorPaths

## Design notes

### Apt counting
Path format: `Building{N}/V{floor}/{slot}/{name}/{instance}/{sublayer}`.
Deduplication by `(building, floor, slot, name, instance)` before counting.
Cores (matched by `core_names`) are excluded from apt count.

### CorridorSurfaces
`Brep.CreatePlanarBreps` on each corridor curve. Path `{bldg_idx; floor_idx}` (0-indexed).

### ExtCorridorWalls
For each flagged floor: explode corridor polyline into segments, keep any segment
whose start/midpoint/end all lie within `TOL=0.1` of the outline curve.
Result = where corridor boundary coincides with building exterior.

### FloorPaths
Sorted unique `Building{N}/V{floor}` strings derived from the apt_map keys.
Parallel to `NeedsStairMask` — use Cull Pattern together.

## Wire connections
- `pcAssocToKv (d11060da).Paths` → `all_paths`
- Panel (`fa90bd9a`) → `core_names`
- Number Slider → `apt_threshold`
- `Building/Floor:CorridorCurve (ae5f208b)` → `corridor_curves`
- `Building/Floor:OutlineCurve (1a3cf2c2)` → `outline_curves`
- `Report` → Panel
- `CorridorSurfaces` → Panel
- `ExtCorridorWalls` → Geometry container

## Code
```python
#! python3
"""
FireStairFloorCheck v2 (merged)
Counts apts per floor from assoc path strings (absorbs AptCoreCountsFromAssoc).
Flags floors needing a fire stair, builds corridor surfaces, finds corridor-exterior
overlap edges, and outputs deduplicated floor-level path prefixes.
"""
from Grasshopper.Kernel.Data import GH_Path
from Grasshopper import DataTree
from collections import defaultdict
import Rhino.Geometry as rg
import scriptcontext as sc
import System

threshold = int(apt_threshold)

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

# ── 1. Count apts per floor ───────────────────────────────────────────────
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

# ── 2. Flag floors ────────────────────────────────────────────────────────
flagged_set = {(b, f) for (b, f), cnt in apt_map.items() if cnt > threshold}
all_floor_keys = sorted(apt_map.keys(), key=lambda k: (k[0], floor_sort(k[1])))
flagged_sorted = sorted(flagged_set, key=lambda x: (x[0], floor_sort(x[1])))

NeedsStair = [f"{b}/{f}" for (b, f) in flagged_sorted]
NeedsStairMask = [(apt_map.get(k, 0) > threshold) for k in all_floor_keys]

# ── 3. FloorPaths ─────────────────────────────────────────────────────────
FloorPaths = [f"{bldg}/{floor}" for (bldg, floor) in all_floor_keys]

# ── 4. Corridor surfaces ──────────────────────────────────────────────────
CorridorSurfaces = DataTree[object]()
for i in range(corridor_curves.BranchCount):
    path = corridor_curves.Paths[i]
    br   = corridor_curves.Branches[i]
    if not br:
        continue
    bi, fi = path_to_bf(path)
    if bi is None:
        continue
    for raw in br:
        crv = to_curve(raw)
        if crv is None:
            continue
        try:
            breps = rg.Brep.CreatePlanarBreps(crv, 0.001)
            if breps:
                out_path = GH_Path(bi, fi)
                for brep in breps:
                    CorridorSurfaces.Add(brep, out_path)
        except:
            pass

# ── 5. Corridor-exterior overlap edges ────────────────────────────────────
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

# ── 6. Report ─────────────────────────────────────────────────────────────
lines = [f"Threshold: {threshold} apts/floor", ""]
lines.append(f"Flagged floors ({len(flagged_sorted)}):")
for (b, f) in flagged_sorted:
    lines.append(f"  {b} {f}  →  {apt_map.get((b, f), 0)} apts")
lines.append("")
for bldg, total in sorted(apt_per_bldg.items()):
    lines.append(f"  {bldg}: {total} apts total")
lines.append("")
lines.append(f"Corridor surfaces: {CorridorSurfaces.BranchCount} branches")
lines.append(f"Corridor-exterior overlap edges: {ExtCorridorWalls.BranchCount} branches")
lines.append(f"Floor paths: {len(FloorPaths)}")
Report = "\n".join(lines)
print(Report)
```
