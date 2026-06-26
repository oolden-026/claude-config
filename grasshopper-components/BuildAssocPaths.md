# BuildAssocPaths

**GUID:** `01ec5683-a3a2-4792-b400-920d897c7725`  
**Canvas position:** x 6104, y 2615  
**Status:** working

## Inputs
| Name | Type | Access |
|---|---|---|
| `block_name` | Generic Data | tree |
| `sublayer_names` | Generic Data | tree |
| `geom_counts` | Generic Data | tree |

## Outputs
| Name | What it contains |
|---|---|
| `P` | Flat list of path strings, one per geometry item |
| `D` | Delimiter string `"/"` |

## What it does
Builds association path strings in the format:
```
Building{b+1}/V{f}/{AppName}/{inst}/{layer_name}/{j}
```
Where `b,f,u,inst` come from the 5-level path indices of `sublayer_names`, `AppName` is looked
up from `block_name` by `(b,f,u,inst)`, and `j` iterates `0..geom_count-1`.

Produces **one path per geometry object** — total ~5000+ paths for a full variant.

**See also:** `BuildAssocPaths_PerSublayer` for the one-path-per-sublayer variant (~1110 paths).

## Code
```python
#! python3
from Grasshopper.Kernel.Data import GH_Path

bn_lookup = {}
for i in range(block_name.BranchCount):
    p = block_name.Paths[i]
    br = block_name.Branches[i]
    if br and br.Count > 0:
        bn_lookup[tuple(p.Indices)] = str(br[0])

paths_list = []

for i in range(sublayer_names.BranchCount):
    p = sublayer_names.Paths[i]
    idx = tuple(p.Indices)
    if len(idx) < 5:
        continue
    b, f, u, inst = idx[0], idx[1], idx[2], idx[3]

    br = sublayer_names.Branches[i]
    if not br or br.Count == 0:
        continue
    layer_name = str(br[0])
    bn = bn_lookup.get((b, f, u, inst), f"App{u}")

    if geom_counts.PathExists(p):
        count_br = geom_counts.Branch(p)
        count = int(count_br[0]) if count_br.Count > 0 else 0
    else:
        count = 0

    for j in range(count):
        paths_list.append(f"Building{b + 1}/V{f}/{bn}/{inst}/{layer_name}/{j}")

P = paths_list
D = "/"
```
