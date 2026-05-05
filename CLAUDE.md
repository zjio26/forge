# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Forge is a Claude Code multi-agent collaborative development workflow distributed as a Claude Code plugin. It's not a traditional codebase — it's a collection of agent definitions (markdown files), a skill orchestrator, and a plugin manifest.

## Architecture

**Coordinator pattern**: `skills/forge/SKILL.md` is the central orchestrator (Coordinator) that dispatches four specialized agents via the Agent tool. The Coordinator never reads intermediate file content — it only tracks paths and status to keep its context lean.

```
Coordinator (SKILL.md)
  ├── Planner (agents/planner.md) — sonnet, decomposes requirements into subtasks
  ├── Dev     (agents/dev.md)     — sonnet, implements + writes unit tests + fixes bugs
  ├── Test    (agents/test.md)    — haiku, unit tests (must pass) + integration tests (may skip)
  └── Learner (agents/learner.md) — haiku, extracts lessons → knowledge base
```

Key flow: Planner → (Wave loop: Dev → Test → Fix) → Full Integration Test → Learner. State checkpointing (`state.json`) at every step enables crash recovery. The Coordinator resumes the same agent instances (via SendMessage + agentId) rather than creating new ones.

## Wave-Based Processing

For large requirements with many subtasks, the workflow uses **waves** to prevent context overflow:

- Planner groups subtasks into waves based on dependency order (`waves.json`)
- Each wave gets a fresh Dev + Test agent pair
- **Wave-level testing**: unit tests + local integration only (no cross-wave business flows)
- **Handoff**: each Dev agent writes a handoff file (modified files, key interfaces, decisions) for the next wave
- **Full integration test** runs after all waves, using the complete unit + business test combo
- Small projects (single wave) run identically to the original flow — zero overhead

## Test Layering

- **Unit tests**: must pass (no external deps). Dev agent writes them; Test agent verifies.
- **Integration tests**: best-effort. If skipped due to environmental constraints (network, hardware, etc.), it's informational only — does not cause overall FAIL.

## Distribution

Forge supports two installation methods:

| Method | Command | Skill invocation |
|--------|---------|------------------|
| **Plugin marketplace** (recommended) | `/plugin marketplace add zjio26/forge` then `/plugin install forge` | `/forge:forge <requirement>` |
| **install.sh** (offline) | `bash install.sh` | `/forge <requirement>` |

The plugin manifest is at `.claude-plugin/plugin.json` and the marketplace catalog at `.claude-plugin/marketplace.json`.

## Source vs Runtime Layout

When installed via **plugin marketplace**, files are auto-discovered from their repo locations. When installed via **install.sh**, files are copied:

| Repo source | install.sh target |
|---|---|
| `agents/*.md` | `~/.claude/agents/*.md` |
| `skills/forge/SKILL.md` | `~/.claude/skills/forge/SKILL.md` |
| `skills/forge/knowledge.md` | `~/.claude/skills/forge/knowledge.md` (preserved if exists) |

Runtime artifacts go to the target project's `.forge/` directory (gitignored).

## Commands

```bash
# Plugin mode (recommended)
/plugin marketplace add zjio26/forge
/plugin install forge

# Manual install (offline)
bash install.sh
CLAUDE_HOME=/path bash install.sh

# Uninstall (plugin mode)
/plugin uninstall forge

# Uninstall (manual mode)
rm -rf ~/.claude/agents/planner.md ~/.claude/agents/dev.md ~/.claude/agents/test.md ~/.claude/agents/learner.md ~/.claude/skills/forge
```

## Principles

Core design invariants of Forge. Any change to agent definitions, SKILL.md, or install.sh must respect them.

1. **Structural enforcement** — Build rules into the workflow, not the model's conscience. If a rule can't be structurally enforced, redesign the workflow
2. **Closed loops with binary verdicts** — Dev→Test→Fix is mandatory, outcomes are PASS/FAIL. No subjective quality judgments
3. **Context isolation** — Coordinator tracks paths and status only; agents return summaries, never full content
4. **Think before write** — Surface ambiguities upfront; confirm critical decisions with the user before proceeding
5. **Only do what's asked** — Every changed line traces to the plan or a bug fix. No extras, no refactoring, no speculative enhancements
6. **Single responsibility** — Each agent does exactly one thing, no cross-boundary work
7. **Recoverability first** — State checkpoint at every step transition; crashes resume from the last checkpoint
8. **Guard against bloat** — Every line in an agent definition costs tokens on every call. If it doesn't structurally change behavior, cut it

## Editing Agent Definitions

Agent definitions are markdown files with YAML frontmatter (name, description, tools, model, maxTurns, color). When editing:

- All path references inside agent files must use `.forge/`
- The Coordinator embeds agent role prompts directly in Agent tool calls (rule 10 in SKILL.md) — so changes to agent markdown files must be self-contained
- The `disable-model-invocation: true` in SKILL.md means the skill itself never makes LLM calls; it only orchestrates sub-agents
- `knowledge.md` is auto-updated by Learner — never manually edit the installed copy
