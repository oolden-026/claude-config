# BottomBrepsToTopoFaces

Filters `Building/Floor/UniqueApp/Instance/SubLayer:Geometry` for the `Visualisatie::06: Bottom` sublayer and converts each planar Brep floor surface to a `topologicpy.Face` object.

## Inputs

| Name | Type | Access | Source |
|---|---|---|---|
| `geometry` | Generic Data | Tree | `Building/Floor/UniqueApp/Instance/SubLayer:Geometry` |
| `names` | Generic Data | Tree | `Building/Floor/UniqueApp/Instance/Sublayer:Names` |

## Outputs

| Name | Description |
|---|---|
| `faces` | `topologic_core.Face` objects (one per apartment instance) |
| `breps` | Filtered Rhino Breps — untrimmed or trimmed planar surfaces |
| `info` | Status / error messages |

## Notes

- Geometry branches are `List[Object]` containing `Rhino.Geometry.Brep` directly (no `.Value` wrapper).
- Extracts the outer BrepLoop, converts to polyline, builds topologicpy `Vertex` list → `Face.ByVertices()`.
- Falls back to 64-point curve division if boundary is not already a polyline.
- Some `Wire.ByVertices - Warning: Degenerate edge` messages are normal for near-zero-length edges; faces are still created.
- Produces 190 Faces from 190 Breps on the current dataset (mix of untrimmed and trimmed surfaces).
- Requires `topologicpy` installed in Rhino's Python env: `& "C:\Users\olol1\.rhinocode\py39-rh8\python.exe" -m pip install topologicpy`

## Code

```python
#! python3
import Rhino.Geometry as rg

try:
    from topologicpy.Vertex import Vertex
    from topologicpy.Face import Face
    _topo_ok = True
except Exception as e:
    _topo_ok = False
    _topo_err = str(e)

BOTTOM_MARKER = "06: Bottom"

def _extract_brep(item):
    try:
        for sub in item:
            if isinstance(sub, rg.Brep):
                return sub
            if hasattr(sub, 'Value') and isinstance(sub.Value, rg.Brep):
                return sub.Value
    except TypeError:
        pass
    if isinstance(item, rg.Brep):
        return item
    return None

def _brep_to_face(brep):
    if brep.Faces.Count == 0:
        return None
    rf = brep.Faces[0]
    outer = next((lp for lp in rf.Loops if lp.LoopType == rg.BrepLoopType.Outer), None)
    if outer is None:
        return None
    curve = outer.To3dCurve()
    ok, poly = curve.TryGetPolyline()
    if ok:
        pts = list(poly)
    else:
        pts = [curve.PointAt(t) for t in curve.DivideByCount(64, True)]
    if pts and pts[0].DistanceTo(pts[-1]) < 1e-4:
        pts = pts[:-1]
    if len(pts) < 3:
        return None
    verts = [Vertex.ByCoordinates(p.X, p.Y, p.Z) for p in pts]
    return Face.ByVertices(verts)

faces = []
breps = []
messages = []

if not _topo_ok:
    messages.append("topologicpy import failed: " + _topo_err)
else:
    for path in names.Paths:
        name_branch = names.Branch(path)
        if not name_branch or BOTTOM_MARKER not in str(name_branch[0]):
            continue
        geom_branch = geometry.Branch(path)
        if not geom_branch:
            continue
        for item in geom_branch:
            brep = _extract_brep(item)
            if brep is None:
                messages.append(f"No Brep at {path}")
                continue
            breps.append(brep)
            f = _brep_to_face(brep)
            if f is not None:
                faces.append(f)
            else:
                messages.append(f"Face conversion failed at {path}")

    messages.append(f"OK — {len(faces)} topologicpy Faces from {len(breps)} Breps")

info = messages
```
