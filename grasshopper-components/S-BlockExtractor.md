# S — Block Instance Extractor

**GUID:** `9d6c4264-407f-4ba0-8390-987339ffdb58`  
**Canvas position:** x 670, y 1233  
**Status:** working

## Inputs
| Name | Type | Access |
|---|---|---|
| `variant_name` | string | item |

## Outputs
| Name | What it contains |
|---|---|
| `block_names` | Tree `{i}` — name of each block definition (one per instance) |
| `sublayers` | Tree `{i}` — list of `Visualisatie::*` sublayer names present in that instance |
| `geometry` | Tree `{i;j}` — geometry per (instance, sublayer); transforms already applied |
| `nested_block_inst` | Tree `{i;j}` — geometry from nested block instances, transforms applied |

## What it does
Queries the Rhino document for all objects under `Varianten::{variant_name}`.  
Finds every block instance (InstanceReference) inside that layer subtree.  
For each instance, inspects the block definition to collect:
- which `Visualisatie::*` sublayers contain useful geometry (closed curves, Breps, Extrusions, Meshes, etc.)
- the actual geometry, duplicated and transformed to world space

Skips open curves, text, annotations, points.  
Caches block-definition info so repeated instances of the same definition don't re-process.  
Outputs empty trees silently when `variant_name` is empty (the "skip" behaviour).

## Code
```python
#! python3
import Rhino
import scriptcontext as sc
from Grasshopper import DataTree
from Grasshopper.Kernel.Data import GH_Path

sc.doc = Rhino.RhinoDoc.ActiveDoc
doc = sc.doc

def is_useful(obj):
    ot = obj.ObjectType
    if ot == Rhino.DocObjects.ObjectType.Curve:
        g = obj.Geometry
        return g is not None and g.IsClosed
    return ot in (
        Rhino.DocObjects.ObjectType.Brep,
        Rhino.DocObjects.ObjectType.Extrusion,
        Rhino.DocObjects.ObjectType.Surface,
        Rhino.DocObjects.ObjectType.Mesh,
        Rhino.DocObjects.ObjectType.SubD,
        Rhino.DocObjects.ObjectType.Hatch,
    )

try:
    block_names        = DataTree[object]()
    sublayers          = DataTree[object]()
    geometry           = DataTree[object]()
    nested_block_names = DataTree[object]()
    nested_block_inst  = DataTree[object]()

    if not variant_name:
        pass
    else:
        full_layer_path = f"Varianten::{variant_name}"
        layer_index = doc.Layers.FindByFullPath(full_layer_path, True)

        if layer_index >= 0:
            layer_obj = doc.Layers[layer_index]

            def collect_objects(layer):
                objs = list(doc.Objects.FindByLayer(layer) or [])
                children = layer.GetChildren()
                if children:
                    for child in children:
                        objs.extend(collect_objects(child))
                return objs

            all_objects = collect_objects(layer_obj)
            InstanceRef = Rhino.DocObjects.ObjectType.InstanceReference
            block_instances = [o for o in all_objects if o.ObjectType == InstanceRef]

            layer_path_cache = {}
            def layer_path(idx):
                if idx not in layer_path_cache:
                    layer_path_cache[idx] = doc.Layers[idx].FullPath
                return layer_path_cache[idx]

            idef_info_cache = {}

            def get_idef_info(idef):
                key = str(idef.Id)
                if key in idef_info_cache:
                    return idef_info_cache[key]

                sublayer_any   = set()
                sublayer_geoms = {}
                sublayer_blocks = {}

                objs = idef.GetObjects()
                if objs:
                    for obj in objs:
                        lyr = layer_path(obj.Attributes.LayerIndex)

                        if obj.ObjectType == InstanceRef:
                            nested_iref_geom = obj.Geometry
                            nested_id  = nested_iref_geom.ParentIdefId
                            nested_def = doc.InstanceDefinitions.Find(nested_id, True)
                            if nested_def is None:
                                continue
                            nested_xform = nested_iref_geom.Xform

                            inner_geoms = []
                            inner_objs  = nested_def.GetObjects()
                            if inner_objs:
                                for io in inner_objs:
                                    if is_useful(io):
                                        inner_geoms.append(io.Geometry)

                            entry = (nested_def.Name, nested_xform, inner_geoms)

                            if lyr.startswith("Visualisatie::"):
                                if inner_geoms:
                                    sublayer_any.add(lyr)
                                    sublayer_blocks.setdefault(lyr, []).append(entry)
                            else:
                                if inner_objs:
                                    vis_lyrs = set()
                                    for io in inner_objs:
                                        if is_useful(io):
                                            il = layer_path(io.Attributes.LayerIndex)
                                            if il.startswith("Visualisatie::"):
                                                vis_lyrs.add(il)
                                    for vl in vis_lyrs:
                                        sublayer_any.add(vl)
                                        sublayer_blocks.setdefault(vl, []).append(entry)
                        else:
                            if lyr.startswith("Visualisatie::"):
                                if is_useful(obj):
                                    sublayer_any.add(lyr)
                                    sublayer_geoms.setdefault(lyr, []).append(obj.Geometry)

                result = {
                    'name':      idef.Name,
                    'sublayers': sorted(sublayer_any),
                    'geoms':     sublayer_geoms,
                    'blocks':    sublayer_blocks,
                }
                idef_info_cache[key] = result
                return result

            idef_lookup = {}
            for i, inst_obj in enumerate(block_instances):
                iref_geom = inst_obj.Geometry
                parent_id = iref_geom.ParentIdefId
                pid_key   = str(parent_id)
                if pid_key not in idef_lookup:
                    idef_lookup[pid_key] = doc.InstanceDefinitions.Find(parent_id, True)
                idef = idef_lookup[pid_key]
                if idef is None:
                    continue

                xform     = iref_geom.Xform
                info      = get_idef_info(idef)
                inst_path = GH_Path(i)
                block_names.Add(info['name'], inst_path)

                for j, lyr in enumerate(info['sublayers']):
                    sublayers.Add(lyr, inst_path)
                    geom_path = GH_Path(i, j)

                    for g in info['geoms'].get(lyr, []):
                        gc = g.Duplicate()
                        gc.Transform(xform)
                        geometry.Add(gc, geom_path)

                    for (blk_name, nested_xform, inner_geoms) in info['blocks'].get(lyr, []):
                        nested_block_names.Add(blk_name, geom_path)
                        combined = xform * nested_xform
                        for g in inner_geoms:
                            gc = g.Duplicate()
                            gc.Transform(combined)
                            nested_block_inst.Add(gc, geom_path)

finally:
    sc.doc = ghdoc
```
