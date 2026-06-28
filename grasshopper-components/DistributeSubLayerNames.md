# DistributeSubLayerNames

**GUID:** `3b222c5f-a309-420b-ab65-d450e3f179f0`  
**Canvas position:** x ?, y ?  
**Status:** working

## Inputs
| Name | Type | Access |
|---|---|---|
| `structured_data_branches` | Generic Data | tree |
| `sublayer_names` | Generic Data | tree |

## Outputs
| Name | What it contains |
|---|---|
| `distributed` | Tree with same paths as `structured_data_branches`, values looked up from `sublayer_names` |

## What it does
Each branch of `structured_data_branches` contains a single integer (stored as a string like `{211}`).  
That integer is used as the path index to look up into `sublayer_names`.  
The sublayer names found at that path are written out at the structured path.  
Effectively redistributes a flat sublayer-names lookup into a hierarchically-structured tree.

## Code
```python
#! python3
from Grasshopper import DataTree
from Grasshopper.Kernel.Data import GH_Path

result = DataTree[object]()

for i in range(structured_data_branches.BranchCount):
    new_path = structured_data_branches.Paths[i]  # e.g. {0;0;0;0}
    sdb_branch = structured_data_branches.Branches[i]
    if sdb_branch.Count == 0:
        continue

    raw = str(sdb_branch[0]).strip("{}")
    lookup_idx = int(raw)
    source_path = GH_Path(lookup_idx)

    if sublayer_names.PathExists(source_path):
        for item in sublayer_names.Branch(source_path):
            result.Add(item, new_path)

distributed = result
```
