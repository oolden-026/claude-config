---
nickname: AptCoreCountsFromAssoc
file: AptCoreCountsFromAssoc.md
description: Reads all assoc path strings and derives apartment counts per floor/building and active core counts per floor. Designed for fire-safety stair logic.
---

## Purpose
Given the flat list of assoc paths from `BuildAssocPaths_PerSublayer`, counts:
- Apartments per floor (per building)
- Total apartments per building
- Active cores per floor (identified by name matching `core_names` input)

Designed as the first step in a fire-safety stair placement pipeline.

## Inputs
| Name | Type | Access | Description |
|---|---|---|---|
| `all_paths` | str | list | All path strings from `BuildAssocPaths_PerSublayer.P` |
| `core_names` | str | list | Core name identifiers (e.g. `CVK46L2`). Panel with one name per line for multiple cores. |

## Outputs
| Name | Description |
|---|---|
| `Report` | Human-readable text summary (connect to Panel) |
| `AptPerFloor` | List of strings: `"Building1 V2: 10"` |
| `AptPerBldg` | List of strings: `"Building1: 85"` |
| `CorePerFloor` | List of strings: `"Building1 V2: 1"` |

## Path format decoded
`Building{N}/V{floor}/{slot}/{name}/{instance}/{sublayer}`

- `name == core_names entry` → core (e.g. `CVK46L2`)
- `name` is apartment type code → apartment (e.g. `CV2K69T01`)
- Deduplication by `(building, floor, slot, name, instance)` before counting — each entity counted once regardless of sublayer count.

## Current results (2026-06-28)
- Building1: 85 apts, V0=13, V1–V6=10, V7–V9=4, 1 core every floor
- Building2: identical, 85 apts

## Wire connections
- Source: `BuildAssocPaths_PerSublayer.P` → `all_paths`
- Source: Panel `core_names` (value: `CVK46L2`) → `core_names`
- Output: `Report` → Panel (display on canvas)

## Extensibility
To add a second core: add its name to the `core_names` Panel (one name per line). The script picks up all names and counts any slot whose name matches.

## Code
```python
#! python3
from collections import defaultdict

def parse(path_str):
    parts = str(path_str).split("/")
    if len(parts) < 5:
        return None
    return parts[0], parts[1], parts[2], parts[3], parts[4]

core_name_set = set(str(n).strip() for n in core_names)

seen  = set()
apts  = set()
cores = set()

for item in all_paths:
    parsed = parse(item)
    if parsed is None:
        continue
    building, floor, slot, name, instance = parsed
    key = (building, floor, slot, name, instance)
    if key in seen:
        continue
    seen.add(key)
    if name in core_name_set:
        cores.add((building, floor, slot))
    else:
        apts.add((building, floor, slot, instance))

def floor_sort(f):
    try: return int(f.lstrip("V"))
    except: return 0

apt_per_floor  = defaultdict(int)
apt_per_bldg   = defaultdict(int)
for (bldg, floor, slot, inst) in apts:
    apt_per_floor[(bldg, floor)] += 1
    apt_per_bldg[bldg] += 1

core_slots_per_floor = defaultdict(set)
for (bldg, floor, slot) in cores:
    core_slots_per_floor[(bldg, floor)].add(slot)
core_per_floor = {k: len(v) for k, v in core_slots_per_floor.items()}

all_keys = sorted(
    set(list(apt_per_floor.keys()) + list(core_per_floor.keys())),
    key=lambda k: (k[0], floor_sort(k[1]))
)

lines = ["Floor breakdown:", ""]
for (bldg, floor) in all_keys:
    n_apt  = apt_per_floor.get((bldg, floor), 0)
    n_core = core_per_floor.get((bldg, floor), 0)
    lines.append(f"  {bldg}  {floor}  |  apts: {n_apt:2d}  |  cores: {n_core}")

lines.append("")
lines.append("Building totals:")
for bldg, total in sorted(apt_per_bldg.items()):
    lines.append(f"  {bldg}  →  {total} apartments")

Report = "\n".join(lines)
print(Report)

AptPerFloor  = [f"{k[0]} {k[1]}: {v}" for k, v in sorted(apt_per_floor.items(),  key=lambda x: (x[0][0], floor_sort(x[0][1])))]
AptPerBldg   = [f"{k}: {v}"            for k, v in sorted(apt_per_bldg.items())]
CorePerFloor = [f"{k[0]} {k[1]}: {v}" for k, v in sorted(core_per_floor.items(), key=lambda x: (x[0][0], floor_sort(x[0][1])))]
```
