# SETUP — Instructions for Claude Code on a new machine

> **Claude:** Read this file when asked to set up this config on a new machine.
> Execute each step in order using your Bash/PowerShell tools.

## Step 1 — Check prerequisites

Verify these are installed before proceeding:
- `claude --version` (Claude Code CLI)
- Rhino 8 is installed (check `C:\Program Files\Rhino 8\`)
- Cordyceps plugin exists in Rhino's plugin folder

If Claude Code is missing: ask the user to install it first from https://claude.ai/code

## Step 2 — Copy config files into ~/.claude/

Run `setup.ps1` from the repo root:

```powershell
cd "$env:USERPROFILE\claude-config"
.\setup.ps1
```

This copies:
- `CLAUDE.md` → `~/.claude/CLAUDE.md`
- `grasshopper-components/` → `~/.claude/grasshopper-components/`
- `memory/` → `~/.claude/projects/[encoded-path]/memory/`

## Step 3 — Add the Cordyceps MCP server

Rhino 8 must be open with the Cordyceps component on a Grasshopper canvas first.
Then run:

```powershell
claude mcp add --transport http cordyceps http://127.0.0.1:26929/mcp
```

Verify with: `claude mcp list` — you should see `cordyceps` listed.

## Step 4 — Verify

Open Claude Code and run a quick test:
- Ask Claude: "What Grasshopper Python components do we have?"
- Claude should read `~/.claude/grasshopper-components/index.md` and list them correctly.

## What each config file does

**`CLAUDE.md`**  
Global instructions Claude reads at the start of every session. Contains:
- Language default (Python unless stated otherwise)
- Grasshopper scripting rules (Script component, not GHPython; `#! python3` header; tree access)
- Data container naming conventions (`Entity/Sub:DataType`)
- Token-saving rules
- Pointer to the component catalog

**`grasshopper-components/index.md`**  
Table of contents for all Python Script components built in Grasshopper.
Each component has its own `.md` file with GUID, inputs, outputs, and full code.
Check this before building a new script — reuse existing logic where possible.

**`memory/`**  
Claude's persistent memory. Contains project context, user preferences, and references.
The `MEMORY.md` index is loaded automatically by Claude Code.
