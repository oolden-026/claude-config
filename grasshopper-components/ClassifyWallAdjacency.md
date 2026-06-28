# ClassifyWallAdjacency

Classifies each apartment wall curve into one of five adjacency categories by probing the `Topology Of Adjacencies` cell→cell output. Replaces ~70 native Grasshopper components (the parallel per-category `Adjacency → DeVec → CSet → MIndex → … → PathMapper` chains).

Canvas GUID: `96f2b373-2ff3-498b-ab81-ee7c8954c7cb`

## Inputs
| Name | Type | Access | Description |
|---|---|---|---|
| adj | Generic Data | Tree | `Cell→Cell` output of Topology Of Adjacencies (1022 branches, paths `{block; floor; cell}`) |
| apt_walls | Generic Data | Tree | Grafted apt wall curves — paths `{B; F; U; I; item}`, one curve per branch |
| n_apt | Generic Data | Tree | List Length of ShiftPaths(-3) on apt_walls — 20 branches `{0;0}..{0;9},{1;0}..{1;9}`, one count per (block, floor) |
| n_kern | Generic Data | Tree | Same structure as n_apt, for kern curves |
| n_corr | Generic Data | Tree | Same structure as n_apt, for corr curves |
| n_kops | Generic Data | Tree | Same structure as n_apt, for kops curves |

## Outputs
| Name | Description |
|---|---|
| WoningWand | Apt curves with no special adjacency (exterior/party walls between apartments) |
| KernWand | Apt curves adjacent to a kern cell |
| CorrWand | Apt curves adjacent to a corridor cell |
| KopsWand | Apt curves adjacent to a kops cell |
| LangsWand | Apt curves adjacent to a langs cell (any cell beyond kops range) |

Output paths: `{B; F; U; I}` (drops the graft leaf from the input path).

## Key design decisions

### adj path structure is `{block; floor; cell}`
The Topology Of Adjacencies component receives the Merge output, which is organised **per block per floor** (not both blocks combined per floor). So adj has paths `{0; fi; c}` for block 0 and `{1; fi; c}` for block 1, where fi=0..9 and c=0..N-1. This means each (block, floor) pair must be processed independently with its own cell count offsets.

### Cell ordering within each (block, floor)
Merge concatenates inputs in this order: apt curves, kern curves, corr curves, kops curves, langs curves. So within `adj{b; fi; *}`:
- Cells `0..na-1`: apt
- Cells `na..na+nk-1`: kern
- Cells `na+nk..na+nk+nc-1`: corr
- Cells `na+nk+nc..na+nk+nc+nkp-1`: kops
- Cells `na+nk+nc+nkp..end`: langs (no explicit n_langs needed — anything ≥ langs_start)

### n_apt branch layout
- Branches 0..9 (paths `{0;0}..{0;9}`): block 0, floors 0..9
- Branches 10..19 (paths `{1;0}..{1;9}`): block 1, floors 0..9

Loop uses `for b, nfi in [(0, fi), (1, fi+10)]` to process both blocks per physical floor.

### per_floor keyed by (block, floor)
`per_floor[(b, fi)]` contains apt_walls items where `Indices[0]==b` and `Indices[1]==fi`, sorted by full path tuple so the order matches adj cell ordering.

## Code
```python
#! python3
from Grasshopper.Kernel.Data import GH_Path
from Grasshopper import DataTree

def path_indices(path):
    return tuple(path.Indices[i] for i in range(len(path.Indices)))

per_floor = {}
for i in range(apt_walls.BranchCount):
    path = apt_walls.Paths[i]
    items = list(apt_walls.Branches[i])
    if not items:
        continue
    key = (path.Indices[0], path.Indices[1])
    idx = path_indices(path)
    per_floor.setdefault(key, []).append((idx, items[0]))

for key in per_floor:
    per_floor[key].sort(key=lambda x: x[0])

WoningWand = DataTree[object]()
KernWand   = DataTree[object]()
CorrWand   = DataTree[object]()
KopsWand   = DataTree[object]()
LangsWand  = DataTree[object]()

for fi in range(10):
    for b, nfi in [(0, fi), (1, fi + 10)]:
        na  = int(n_apt.Branches[nfi][0])
        nk  = int(n_kern.Branches[nfi][0])
        nc  = int(n_corr.Branches[nfi][0])
        nkp = int(n_kops.Branches[nfi][0])

        kern_start  = na
        corr_start  = kern_start + nk
        kops_start  = corr_start + nc
        langs_start = kops_start + nkp

        floor_walls = per_floor.get((b, fi), [])
        if len(floor_walls) != na:
            print(f"WARNING b={b} fi={fi}: {len(floor_walls)} walls but na={na}")
            continue

        for c in range(na):
            adj_path = GH_Path(b, fi, c)
            if not adj.PathExists(adj_path):
                continue
            neighbors = [int(nb) for nb in adj.Branch(adj_path)]
            has_kern  = any(kern_start  <= nb < corr_start  for nb in neighbors)
            has_corr  = any(corr_start  <= nb < kops_start  for nb in neighbors)
            has_kops  = any(kops_start  <= nb < langs_start for nb in neighbors)
            has_langs = any(nb >= langs_start               for nb in neighbors)

            orig_idx, curve = floor_walls[c]
            out_path = GH_Path(orig_idx[0], orig_idx[1], orig_idx[2], orig_idx[3])

            if has_kern:
                KernWand.Add(curve, out_path)
            if has_corr:
                CorrWand.Add(curve, out_path)
            if has_kops:
                KopsWand.Add(curve, out_path)
            if has_langs:
                LangsWand.Add(curve, out_path)
            if not (has_kern or has_corr or has_kops or has_langs):
                WoningWand.Add(curve, out_path)
```

## Wiring notes
- `adj` ← `Topology Of Adjacencies` Cell→Cell output
- `apt_walls` ← `Graft Tree` of apt curves (paths `{B;F;U;I;item}`)
- `n_apt` ← `List Length` of `Shift Paths -3` on apt curves (20 branches)
- `n_kern`, `n_corr`, `n_kops` ← same pattern applied to kern/corr/kops curves respectively
- All inputs use **Tree** access

## Verified output counts (2026-06-27)
| Output | Count | Branches |
|---|---|---|
| WoningWand | 236 | 158 |
| KernWand | 122 | 78 |
| CorrWand | 276 | 168 |
| KopsWand | 78 | 78 |
| LangsWand | 172 | 170 |
