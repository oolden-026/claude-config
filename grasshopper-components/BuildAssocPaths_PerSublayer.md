# BuildAssocPaths_PerSublayer

**GUID:** `7f3a8542-fa7f-4111-a571-e0131df72337`  
**Canvas position:** x 6104, y 2865  
**Status:** working

## Inputs
| Name | Type | Access |
|---|---|---|
| `block_name` | Generic Data | tree |
| `sublayer_names` | Generic Data | tree |

## Outputs
| Name | What it contains |
|---|---|
| `P` | Flat list of path strings, one per sublayer item |
| `D` | Delimiter string `"/"` |

## What it does
Same hierarchy and lookup logic as `BuildAssocPaths`, but stops one level short —
no per-geometry expansion. Produces exactly **one path per unique (instance, sublayer)
combination**, format:
```
Building{b+1}/V{f}/{u}/{AppName}/{inst}/{layer_name}
```
`u` (unique-app index) is encoded explicitly at position 2 so the reverse component
`ParseAssocPaths_ToSublayerNames` can reconstruct it unambiguously — some block names
appear at multiple `u` indices on the same floor, so the block name alone is insufficient.

Produces ~1110 paths for a full variant (matches the total sublayer item count from
the `S-BlockExtractor` `sublayers` output).

**See also:** `BuildAssocPaths` for the version that expands to one path per geometry item.

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

# One path per sublayer item — no per-geometry expansion.
# Produces ~1110 paths (one per unique instance/sublayer combination).
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

    paths_list.append(f"Building{b + 1}/V{f}/{u}/{bn}/{inst}/{layer_name}")

P = paths_list
D = "/"
```
