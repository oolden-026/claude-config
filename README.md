# Claude Code — Grasshopper / Rhino Workflow Config

Personal Claude Code configuration for Rhino 8 + Grasshopper + Cordyceps workflow.

## What's in this repo

| Path | Purpose |
|---|---|
| `CLAUDE.md` | Global Claude Code instructions (language defaults, GH rules, component catalog pointer) |
| `grasshopper-components/` | Catalog of every Python Script component built in Grasshopper |
| `memory/` | Claude's persistent memory files (project context, preferences) |
| `setup.ps1` | One-command installer — copies everything into `~/.claude/` |

## Prerequisites (install these first)

1. **Rhino 8** + Grasshopper
2. **Cordyceps** Grasshopper plugin (provides MCP server on `http://127.0.0.1:26929/mcp`)
3. **Claude Code** CLI — `winget install Anthropic.ClaudeCode` or from [claude.ai/code](https://claude.ai/code)

## Setup on a new machine

```powershell
# 1. Clone this repo
git clone https://github.com/YOUR_USERNAME/claude-config.git "$env:USERPROFILE\claude-config"

# 2. Run the installer
cd "$env:USERPROFILE\claude-config"
.\setup.ps1

# 3. Add the Cordyceps MCP server (Rhino must be open with Cordyceps loaded)
claude mcp add --transport http cordyceps http://127.0.0.1:26929/mcp
```

That's it. Open Claude Code and continue where you left off.

## Keeping in sync

```powershell
# Pull updates from GitHub
cd "$env:USERPROFILE\claude-config"
git pull
.\setup.ps1          # re-run to apply any new files

# Push your changes to GitHub
git add -A
git commit -m "update config"
git push
```

## For Claude Code (read this on a new machine)

See `SETUP.md` for step-by-step instructions Claude can execute directly.
