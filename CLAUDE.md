# CLAUDE.md — Cordyceps / Grasshopper workflow

> Place at `~/.claude/CLAUDE.md` (global). These rules travel with me, not with a repo.
> Goal: stop rediscovering the same quirks every session, default to Python, save tokens.

## 1. Language default
- When I say "script", "code", "programming", or "scripting" **without naming a language, assume Python.**
- I name C#, Rust, etc. explicitly when I mean them. If unstated, it is Python.

## 2. Grasshopper Python via Cordyceps (apply on the FIRST attempt)
- Use the newer **Script** component. **Never** the old GHPython component — it cannot accept injected code.
- Script code **must** start with `#! python3` on **line 1**.
- Set input access to **tree** when the component consumes data trees. Don't leave it on item/list and retry.
- Do not run the "create → fail → inspect → fix" loop for these. They are known. Get them right up front.

## 3. Referring to data containers by name
- I name containers in Grasshopper (select → F2).
- Find them with `gh_canvas(action='search', query='<name>')`, then read values with `gh_inspect`.
- When I say "look at `<name>`", search by that exact name — don't scan the whole canvas.

## 3b. Data container naming convention (structured phase only)
This convention applies **only once data has been structured** — after branching, path manipulation,
sorting, etc. Raw import containers from Rhino do not follow it.

**Pattern:** `Entity/SubEntity/.../LeafEntity:DataType`

- `/` separates hierarchy levels (entity nesting)
- `:` separates the final entity from what the container holds (the data type/content)
- Each word segment uses **PascalCase** (UpperCamelCase — every word capitalised, no spaces or underscores)
- Raw import containers (pre-structure) use **snake_case** and do not follow this convention

**Examples from this project:**
```
Building/Floor/UniqueApp/Instance:BlockName
Building/Floor/UniqueApp/Instance/Sublayer:Names
Building/Floor/UniqueApp/Instance/Sublayer:Geometry
```

**Reading rule for Claude:** when scanning a script, the part before `:` tells you *where in the
data hierarchy this lives*, and the part after `:` tells you *what kind of data it contains*.
Search containers by their full name — do not guess the path from partial matches.

## 4. Token-saving rules
- Prefer one correct Script component over several native components when it's cleaner.
- Batch canvas reads: inspect what you need in as few `gh_inspect` calls as possible.
- Don't re-scan the canvas to relocate a container I've already named — search it directly.
- Geometry namespace is `import Rhino.Geometry as rg`. Assume it; don't re-derive it.

## 5. Connection (for reference)
- Rhino 8 open, Cordyceps component on canvas → server on `http://127.0.0.1:26929/mcp`.
- Add once in Claude Code: `claude mcp add --transport http cordyceps http://127.0.0.1:26929/mcp`

## 6. Grasshopper Python component catalog
- Full catalog: `~/.claude/grasshopper-components/index.md`
- Before writing a new Script component, read the index — reuse or extend existing logic where possible.
- After a Script component is confirmed working, add it to the catalog immediately.

---
*Note: CLAUDE.md is loaded as context, not hard-enforced. If a rule still gets dropped occasionally,
the only hard guarantee is a PreToolUse hook — but these rules are concrete, so compliance is usually high.*