# RenameAssocPaths

Applies find/replace to all Assoc path strings in a single regex pass — no cascading, no duplicates. Each unique find string is replaced exactly once regardless of how many times it appears in the input tree.

## Inputs
| Name | Type | Access | Description |
|---|---|---|---|
| all_paths | Generic Data | List | Flat path strings from `pcAssocToKv` Paths output (1110 items) |
| all_values | Generic Data | List | Corresponding values from `pcAssocToKv` Value output (1110 items) |
| find | Generic Data | Tree | Words/strings to find — one item per branch (e.g. 78 apartment type codes) |
| replace | Generic Data | Tree | Replacement strings — paired with `find`, one item per branch |

## Outputs
| Name | Description |
|---|---|
| Paths | 1110 path strings with substitutions applied (1 branch) |
| Values | Pass-through of all_values unchanged |

## Key design decisions
- `find` and `replace` use **tree** access so GH does not solve the script once per branch (which would produce 78 × 1110 = 86,580 outputs instead of 1110).
- All find/replace pairs are compiled into a **single regex alternation** (`re.compile('|'.join(...))`), so all substitutions happen in one pass — no risk of a replacement string being matched by a later find pattern.
- Duplicates in the input tree are deduplicated (first occurrence wins) before building the regex.

## Code
```python
#! python3
import re

find_list    = [str(x) for b in find.Branches    for x in b]
replace_list = [str(x) for b in replace.Branches for x in b]

# Build lookup (first occurrence wins, deduplicates)
lookup = {}
for f, r in zip(find_list, replace_list):
    if f and f not in lookup:
        lookup[f] = r

if lookup:
    pattern = re.compile('|'.join(re.escape(k) for k in lookup))
    paths_out = [pattern.sub(lambda m: lookup[m.group(0)], p) for p in all_paths]
else:
    paths_out = list(all_paths)

Paths  = paths_out
Values = list(all_values)
```

## Wiring notes
- `all_paths` ← `pcAssocToKv` Paths
- `all_values` ← `pcAssocToKv` Value
- `find` ← tree of apartment type codes (original names), one per branch
- `replace` ← tree of replacement names (e.g. from Concatenate), one per branch
- `Paths` + `Values` → `pcKvToAssoc` to rebuild the Assoc
