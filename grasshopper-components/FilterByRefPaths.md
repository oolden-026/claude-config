# FilterByRefPaths

**GUID (one of four instances):** `6e7c2356-23a7-45f2-90ce-83a6b45c9e09`  
**Other instances:** `bd411116`, `396a4358`, `f5c8b095`  
**Status:** working (4 identical copies wired to different data streams)

## Inputs
| Name | Type | Access |
|---|---|---|
| `ref` | Generic Data | tree |
| `data` | Generic Data | tree |

## Outputs
| Name | What it contains |
|---|---|
| `matched` | Branches from `data` whose leading N path indices exist in `ref` |
| `remainder` | All other branches from `data` |

## What it does
Collects all path tuples from `ref` (N = depth of ref paths, auto-detected).  
For each branch in `data`, compares the first N indices of its path against the ref set.  
Branches that match go to `matched`; everything else goes to `remainder`.  
Scalable: works for any ref depth without hardcoding.

## Code
```python
#! python3
from Grasshopper import DataTree
from Grasshopper.Kernel.Data import GH_Path

ref_path_tuples = set()
for path in ref.Paths:
    ref_path_tuples.add(tuple(path.Indices))

N = len(next(iter(ref_path_tuples))) if ref_path_tuples else 0

matched   = DataTree[object]()
remainder = DataTree[object]()

for path in data.Paths:
    branch_indices = tuple(path.Indices)
    leading = branch_indices[:N]
    if leading in ref_path_tuples:
        matched.AddRange(data.Branch(path), path)
    else:
        remainder.AddRange(data.Branch(path), path)
```
