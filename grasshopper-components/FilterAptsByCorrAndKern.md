# FilterAptsByCorrAndKern

**GUID on canvas:** `25c3cfc5-e1f6-49c7-b4dd-9c57a506c951`

## What it does
Selects apartments that satisfy two simultaneous wall-adjacency criteria:
1. Has at least one **CorrWand** (corridor-facing wall segment)
2. Has at least one **KernWand** (kern-block-facing wall segment — i.e. adjacent to CVK46L2)

Then splits the 76 qualifying apartments into **Side1** and **Side2** based on which corridor cell (0 or 1) each apartment is topologically adjacent to — the two corridor cells sit on opposite sides of the CVK46L2 core.

Results: 76 total → 40 Side1 (`CV2K69T01` / `CBCP69`) | 36 Side2 (`CV3K69T03`).

Note: ground floor (b=0, f=0) has nc=1 (single corridor cell), so those 4 apartments go to Side1 by default.

## Inputs
| Name | Access | Source |
|---|---|---|
| `CorrWand` | tree | `ClassifyWallAdjacency` → `CorrWand` |
| `KernWand` | tree | `ClassifyWallAdjacency` → `KernWand` |
| `block_name` | tree | Remote Receiver `b3a3f1f8` (`Building/Floor/UniqueApp/Instance:BlockName`) |
| `adj` | tree | `Topology Of Adjacencies` `bdc71f1d` → `Cell→Cell` |
| `apt_walls` | tree | Graft `00b63940` → `Tree` (same source as ClassifyWallAdjacency) |
| `n_apt` | tree | List Length `661e3ab5` → `Length` |
| `n_kern` | tree | List Length `f8076066` → `Length` |
| `n_corr` | tree | List Length `1fc88928` → `Length` |

## Outputs
| Name | Content |
|---|---|
| `Names` | Flat list of 76 `"Building{b+1}/V{f}/{u}/{bn}/{inst}"` strings |
| `AptPaths` | DataTree keyed `{b;f;u;inst}`, one branch per selected apt |
| `Side1` | DataTree — 40 branches keyed `{b;f;u;inst}`, apartments on corridor cell 0 side |
| `Side2` | DataTree — 36 branches keyed `{b;f;u;inst}`, apartments on corridor cell 1 side |

## Code
```python
#! python3
from Grasshopper.Kernel.Data import GH_Path
from Grasshopper import DataTree
from collections import defaultdict

# Build per-floor sorted mapping: (b,f,u,inst) -> c index
per_floor = defaultdict(list)
for i in range(apt_walls.BranchCount):
    p = apt_walls.Paths[i]
    if p.Length >= 4:
        idx = tuple(p.Indices[j] for j in range(4))
        per_floor[(idx[0], idx[1])].append(idx)
for key in per_floor:
    per_floor[key].sort()
apt_to_c = {}
for (b, f), sorted_apts in per_floor.items():
    for c, idx in enumerate(sorted_apts):
        apt_to_c[idx] = c

# Build n_apt, n_kern, n_corr per (b, fi) using branch index convention
def floor_counts(tree):
    result = {}
    for i in range(tree.BranchCount):
        br = tree.Branches[i]
        if not br or br.Count == 0:
            continue
        b, fi = (0, i) if i < 10 else (1, i - 10)
        result[(b, fi)] = int(br[0])
    return result

na_map = floor_counts(n_apt)
nk_map = floor_counts(n_kern)
nc_map = floor_counts(n_corr)

# Collect selected apartments: CorrWand paths ∩ KernWand paths
corr_set = set()
for i in range(CorrWand.BranchCount):
    p = CorrWand.Paths[i]
    if p.Length >= 4:
        corr_set.add(tuple(p.Indices[j] for j in range(4)))

kern_set = set()
for i in range(KernWand.BranchCount):
    p = KernWand.Paths[i]
    if p.Length >= 4:
        kern_set.add(tuple(p.Indices[j] for j in range(4)))

selected = sorted(corr_set & kern_set)

# Block name lookup
bn_lookup = {}
for i in range(block_name.BranchCount):
    p = block_name.Paths[i]
    br = block_name.Branches[i]
    if p.Length >= 4 and br and br.Count > 0:
        key = tuple(p.Indices[j] for j in range(4))
        bn_lookup[key] = str(br[0])

# Assign each selected apartment to Side1 or Side2
Names = []
AptPaths = DataTree[object]()
Side1 = []
Side2 = []

for idx in selected:
    b, f, u, inst = idx
    bn = bn_lookup.get(idx, f"App{u}")
    label = f"Building{b+1}/V{f}/{u}/{bn}/{inst}"
    Names.append(label)
    AptPaths.Add(label, GH_Path(b, f, u, inst))

    c = apt_to_c.get(idx)
    if c is None:
        continue

    na = na_map.get((b, f), 0)
    nk = nk_map.get((b, f), 0)
    nc = nc_map.get((b, f), 0)
    corr_start = na + nk
    kops_start  = corr_start + nc

    adj_path = GH_Path(b, f, c)
    if not adj.PathExists(adj_path):
        continue

    neighbors = [int(nb) for nb in adj.Branch(adj_path)]
    corr_neighbors = [nb - corr_start for nb in neighbors if corr_start <= nb < kops_start]

    if not corr_neighbors:
        continue

    side = min(corr_neighbors)  # 0 = first corr cell, 1 = second corr cell
    if side == 0:
        Side1.append(label)
    else:
        Side2.append(label)

print(f"Total: {len(Names)}  |  Side1: {len(Side1)}  |  Side2: {len(Side2)}")
```
