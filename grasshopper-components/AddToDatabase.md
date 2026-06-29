# AddToDatabase

**GUID:** `088fffca-750b-4e2f-b2eb-568e1efeff9c`  
**Canvas position:** x 12468, y 1450  
**Status:** working (unconnected — runs clean with 0 entries when no inputs wired)

## Inputs
| Name | Type | Access | Source |
|---|---|---|---|
| `all_paths` | Generic Data | tree | `pcAssocToKv` → `Paths` output |
| `all_values` | Generic Data | tree | `pcAssocToKv` → `Value` output |
| `new_geometry` | Generic Data | tree | `NewGeom` container |
| `new_paths` | Generic Data | tree | `NewPath` container (3-segment strings: `Building/Floor/AppName`) |

## Outputs
| Name | Description |
|---|---|
| `new_entries` | N new path strings: `Building/Floor/NewSlot/AppName/0` |
| `augmented_paths` | all_paths + new_entries (flat, 1 branch) |
| `augmented_values` | all_values + new geometry objects (or string proxies if geometry can't bind) |
| `Report` | Summary: slot assignments per new entry |

## What it does
General-purpose "add to database" component. Reads all existing paths from the
PancakeDatabase via `pcAssocToKv`, counts unique slot indices at each `(Building, Floor)`,
then for each entry in `new_paths` assigns `new_slot = len(existing_slots)` — the next
available position. Builds path strings as `Building/Floor/{new_slot}/{AppName}/0` and
appends them alongside the new geometry values to the existing lists.

`new_paths` format: 3-segment strings `Building/Floor/AppName` (e.g. `Building1/V0/CBVL`).
Instance index `/0` is appended automatically (single occurrence per floor assumed).

## Geometry note
`new_geometry` is wired as tree access. If the container holds standard Rhino geometry
(Breps, curves, meshes) it passes through fine and is used directly as values.
If it holds an Elefront type (`EleFrontInstanceDefinition`, `EleFrontBlock`), the Script
component will throw a binding error — disconnect the wire and handle geometry outside
via a `pcKvToAssoc` component using `new_entries` as P and geometry as V.

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

flat_new_paths = [str(x).strip() for x in flatten_tree(new_paths)]
flat_new_geom  = list(flatten_tree(new_geometry))

new_entries = []
augmented_values_new = []
report_lines = []

for i, path_str in enumerate(flat_new_paths):
    parts = path_str.split("/")
    if len(parts) < 3:
        continue
    building, floor, app_name = parts[0], parts[1], parts[2]
    key = (building, floor)
    existing_slots = slot_counts.get(key, set())
    new_slot = len(existing_slots)
    new_path = f"{building}/{floor}/{new_slot}/{app_name}/0"
    new_entries.append(new_path)

    geom = flat_new_geom[i] if i < len(flat_new_geom) else f"Block: {app_name}"
    augmented_values_new.append(geom)

    report_lines.append(
        f"  {building}/{floor}: {len(existing_slots)} existing -> slot {new_slot} ({app_name})"
    )

augmented_paths  = flat_all_paths  + new_entries
augmented_values = flat_all_values + augmented_values_new

Report = "\n".join([
    f"New entries added: {len(new_entries)}",
    "",
    "Assignments:",
    *report_lines,
    "",
    f"Original paths:  {len(flat_all_paths)}",
    f"Total augmented: {len(augmented_paths)}",
])
print(Report)
```
