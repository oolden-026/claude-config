# S — Pattern Matcher

**GUID:** `20cf7584-4c53-4a96-8ef3-e2877aff9054`  
**Canvas position:** x ?, y ?  
**Status:** working

## Inputs
| Name | Type | Access |
|---|---|---|
| `patterns` | string list | list |
| `sublayers` | Generic Data | tree |

## Outputs
| Name | What it contains |
|---|---|
| `match_branches` | Tree `{p}` — block instance indices that matched pattern p |
| `match_indices` | Tree `{p}` — sublayer index within that block for each match (parallel to match_branches) |

## What it does
For each pattern string (compiled as regex, case-insensitive), scans every branch of the
sublayers tree. For each branch (= one block instance), finds the first sublayer name
matching that pattern and records the instance index and sublayer index.  
Branches with no match for a given pattern are absent from the output.

## Code
```python
#! python3
import re
from Grasshopper import DataTree
from Grasshopper.Kernel.Data import GH_Path

match_branches = DataTree[object]()
match_indices  = DataTree[object]()

if patterns and sublayers is not None:
    compiled = [(p, re.compile(pat, re.IGNORECASE)) for p, pat in enumerate(patterns)]

    for branch_idx in range(sublayers.BranchCount):
        branch = sublayers.Branches[branch_idx]
        path   = sublayers.Paths[branch_idx]
        i      = path[0]   # block instance index

        for p, regex in compiled:
            p_path = GH_Path(p)
            for j, name in enumerate(branch):
                if regex.search(str(name)):
                    match_branches.Add(i, p_path)
                    match_indices.Add(j, p_path)
                    break  # first match per branch per pattern
```
