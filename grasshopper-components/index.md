# Grasshopper Python Component Catalog

One file per component. Read the file for full code + wire details.

| Nickname | File | What it does |
|---|---|---|
| S (block extractor) | [S-BlockExtractor.md](S-BlockExtractor.md) | Reads block instances from Rhino `Varianten::{variant_name}` layer; outputs geometry + sublayers per instance |
| S (pattern matcher) | [S-PatternMatcher.md](S-PatternMatcher.md) | Regex-matches a list of patterns against a sublayers tree; outputs parallel branch/index lists |
| FilterByRefPaths | [FilterByRefPaths.md](FilterByRefPaths.md) | Splits a data tree into matched / remainder based on leading path indices from a reference tree |
| DistributeSubLayerNames | [DistributeSubLayerNames.md](DistributeSubLayerNames.md) | Re-maps sublayer names from a flat lookup tree into a structured path tree |
| BuildAssocPaths | [BuildAssocPaths.md](BuildAssocPaths.md) | Builds path strings `Building/Floor/App/Inst/Layer/GeomIdx` — one path **per geometry item** (~5000+) |
| BuildAssocPaths_PerSublayer | [BuildAssocPaths_PerSublayer.md](BuildAssocPaths_PerSublayer.md) | Same as above but **one path per sublayer** (no geometry expansion) — produces ~1110 paths |
| ParseAssocPaths_ToSublayerNames | [ParseAssocPaths_ToSublayerNames.md](ParseAssocPaths_ToSublayerNames.md) | **Reverse of BuildAssocPaths_PerSublayer** — parses flat path strings back into a `{b,f,u,inst}` data tree of sublayer names |
| RenameAssocPaths | [RenameAssocPaths.md](RenameAssocPaths.md) | Single-pass regex find/replace across all 1110 Assoc path strings — find/replace inputs are trees (one item per branch), no cascading, feeds directly into `pcKvToAssoc` |
| ClassifyWallAdjacency | [ClassifyWallAdjacency.md](ClassifyWallAdjacency.md) | Classifies apt wall curves into WoningWand/KernWand/CorrWand/KopsWand/LangsWand using Topology Of Adjacencies output — replaces ~70 native components |
| FilterAptsByCorrAndKern | [FilterAptsByCorrAndKern.md](FilterAptsByCorrAndKern.md) | Selects apartments with BOTH a corridor wall AND a kern-block wall — outputs 76 matching assoc path strings and a `{b;f;u;inst}` DataTree |
| BottomBrepsToTopoFaces | [BottomBrepsToTopoFaces.md](BottomBrepsToTopoFaces.md) | Filters SubLayer:Geometry for `06: Bottom` sublayer and converts each planar Brep floor surface to a `topologicpy.Face` object |
| FireStairFloorCheck_v2 | [FireStairFloorCheck_v2.md](FireStairFloorCheck_v2.md) | Merged: counts apts from assoc paths, flags floors needing fire stair, generates corridor surfaces, finds corridor-exterior overlap edges, outputs FloorPaths |
