# ParseAssocPaths_ToSublayerNames

**Reverse of `BuildAssocPaths_PerSublayer`.** Parses flat path strings back into a structured GH data tree of sublayer names.

## Inputs
| Name | Type | Access | Description |
|---|---|---|---|
| P | Text | List | Flat list of path strings, e.g. `Building1/V0/CVK46L2/0/Visualisatie::00: Top` |

## Outputs
| Name | Description |
|---|---|
| Names | Data tree `{b, f, u, inst, sublayer_idx}` → sublayer name string — mirrors the `sublayer_names` input of `BuildAssocPaths_PerSublayer` |

## Logic
`u` is read directly from segment[2] of the path string — no reconstruction needed.
For each path string, parse all 6 segments, assign a sequential `sublayer_idx` per
`(b, f, u, inst)` group, and write `layer_name` into `GH_Path(b, f, u, inst, sublayer_idx)`.

**Why u must be explicit:** 15 `(b, f, block_name)` combinations map to multiple `u` indices
on the same floor. Reconstructing `u` from block-name first-appearance order silently
assigns the wrong index for those cases, leaving 150/1110 items mismatched.

Path format assumed: `Building{b+1}/V{f}/{u}/{block_name}/{inst}/{sublayer_name}`

## Code
```python
#! python3
from Grasshopper import DataTree
from Grasshopper.Kernel.Data import GH_Path

# Path format: Building{b+1}/V{f}/{u}/{block_name}/{inst}/{sublayer_name}
# u is encoded directly — no reconstruction needed.

tree = DataTree[object]()
sl_counter = {}  # (b, f, u, inst) -> next sublayer index

for path_str in P:
    parts = path_str.split("/")
    if len(parts) < 6:
        continue
    b          = int(parts[0][8:]) - 1
    f          = int(parts[1][1:])
    u          = int(parts[2])
    inst       = int(parts[4])
    layer_name = "/".join(parts[5:])

    group_key = (b, f, u, inst)
    sl_idx    = sl_counter.get(group_key, 0)
    sl_counter[group_key] = sl_idx + 1

    tree.Add(layer_name, GH_Path(b, f, u, inst, sl_idx))

Names = tree
```

## Wiring notes
- Wire directly from `P` output of `BuildAssocPaths_PerSublayer`
- Output `Names` can be used anywhere the original `sublayer_names` container is expected
- Produces 1110 items across 1110 branches — one branch per item, matching the original `sublayer_names` tree exactly
