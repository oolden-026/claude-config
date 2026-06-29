# AddFireStairsToDatabase

**GUID:** `a208825b-10d7-4ed0-a811-df4fff04cc95`  
**Canvas position:** x 12468, y 1124  
**Status:** working

## Inputs
| Name | Type | Access | Source |
|---|---|---|---|
| `all_paths` | Generic Data | tree | `pcAssocToKv` → `Paths` output |
| `all_values` | Generic Data | tree | `pcAssocToKv` → `Value` output |
| `gf_paths` | Generic Data | tree | `FireStairsGroundfloorPath` container |
| `fl_paths` | Generic Data | tree | `FireStairsFloorsPath` container |
| `gf_block` | Generic Data | item | `FireStairsGroundfloorBlockName` container (= "CBVL") |
| `fl_block` | Generic Data | item | `FireStairsFloorBlockName` container (= "CVVL") |
| `gf_geometry` | Generic Data | tree | `FireStairsGroundfloorGeometry` container (EleFrontBlock — wired, binding silently ignored) |
| `fl_geometry` | Generic Data | tree | `FireStairsFloorsGeometry` container (EleFrontBlock — wired, binding silently ignored) |

## Outputs
| Name | Description |
|---|---|
| `new_entries` | 12 new path strings: `Building/Floor/NewSlot/BlockName/0` |
| `new_values` | 12 value strings: `"Block: CBVL"` or `"Block: CVVL"` |
| `augmented_paths` | 1110 original + 12 new = 1122 total path strings (flat, 1 branch) |
| `augmented_values` | 1110 original values + 12 block name value strings = 1122 total (flat, 1 branch) |
| `Report` | Summary: slot assignments per floor |

## What it does
Flattens all input trees manually, counts the distinct unique-block slot indices
already used at each Building/Floor in `all_paths`, and assigns `new_slot = len(existing_slots)`
to each fire stair floor. Appends instance index `/0` as the 5th path segment (single
occurrence per floor). Generates value strings as `"Block: {block_name}"` — matching
the format used by the geometry containers — so no raw geometry objects need to pass
through the script (avoids Rhino 8 DataTree conversion issues with block references).

Ground floor uses `gf_block`; upper floors use `fl_block`. Processes gf first, then fl
(same order as the flattened geometry containers for downstream parallel wiring).

## Slot assignments (current data)
- Ground floors (V0): 4 existing blocks → fire stair at slot 4 (`CBVL`)
- Upper floors (V1–V5): 6 existing blocks → fire stair at slot 6 (`CVVL`)

## Note on geometry
`gf_geom` / `fl_geom` (FireStairsGroundfloorGeometry / FireStairsFloorsGeometry) are NOT
wired into this script — block reference objects in multi-branch trees cause a
`GH_Structure<IGH_Goo>` / `List<object>` conversion failure in Rhino 8 Script components.
Value strings are generated from block names instead. If actual geometry objects are
needed downstream, wire the geometry containers in parallel outside this script.

## Code
```python
#! python3
from collections import defaultdict

def flatten_tree(tree):
    items = []
    for i in range(tree.BranchCount):
        for item in tree.Branches[i]:
            items.append(item)
    return items

flat_all_paths  = [str(x).strip() for x in flatten_tree(all_paths)]
flat_all_values = list(flatten_tree(all_values))

slot_counts = defaultdict(set)
for s in flat_all_paths:
    parts = s.split("/")
    if len(parts) >= 3:
        slot_counts[(parts[0], parts[1])].add(parts[2])

flat_gf_paths = [str(x).strip() for x in flatten_tree(gf_paths)]
flat_fl_paths = [str(x).strip() for x in flatten_tree(fl_paths)]

gf_block_name = str(gf_block).strip()
fl_block_name = str(fl_block).strip()

fire_stair_pairs = (
    [(s, gf_block_name) for s in flat_gf_paths] +
    [(s, fl_block_name) for s in flat_fl_paths]
)

new_entries = []
new_values  = []
report_lines = []

for bf_str, block_name in fire_stair_pairs:
    parts = bf_str.split("/")
    if len(parts) < 2:
        continue
    building, floor = parts[0], parts[1]
    key = (building, floor)
    existing_slots = slot_counts.get(key, set())
    new_slot = len(existing_slots)
    path  = f"{building}/{floor}/{new_slot}/{block_name}/0"
    value = f"Block: {block_name}"
    new_entries.append(path)
    new_values.append(value)
    report_lines.append(
        f"  {building}/{floor}: {len(existing_slots)} existing blocks "
        f"-> slot {new_slot} ({block_name}) / instance 0"
    )

augmented_paths  = flat_all_paths  + new_entries
augmented_values = flat_all_values + new_values

Report = "\n".join([
    f"Fire stair entries added: {len(new_entries)}",
    "",
    "Assignments:",
    *report_lines,
    "",
    f"Original paths:  {len(flat_all_paths)}",
    f"Total augmented: {len(augmented_paths)}",
])
print(Report)
```
