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
