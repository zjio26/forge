#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Forge - Claude Code Multi-Agent Workflow Installer
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve Claude Code home directory
# Priority: CLAUDE_HOME env > HOME > USERPROFILE (Windows)
# HOME takes priority over USERPROFILE because Claude Code (as a CLI tool)
# follows Unix conventions and reads from $HOME/.claude/
if [ -n "${CLAUDE_HOME:-}" ]; then
  CLAUDE_DIR="$CLAUDE_HOME/.claude"
elif [ -n "${HOME:-}" ] && [ -d "$HOME/.claude" ]; then
  CLAUDE_DIR="$HOME/.claude"
elif [ -n "${USERPROFILE:-}" ]; then
  CLAUDE_DIR="$(cygpath -u "$USERPROFILE")/.claude"
else
  CLAUDE_DIR="$HOME/.claude"
fi

echo ""
echo "  ⚒️  Forge Installer"
echo "  ─────────────────────"
echo "  Target: $CLAUDE_DIR"
echo ""

# Create directories
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/skills/forge"

# Copy agents
for agent in planner dev test learner; do
  src="$SCRIPT_DIR/agents/${agent}.md"
  dst="$CLAUDE_DIR/agents/${agent}.md"
  if [ -f "$src" ]; then
    cp "$src" "$dst"
    echo "  ✅ agents/${agent}.md"
  else
    echo "  ❌ agents/${agent}.md not found"
  fi
done

# Copy skill
src="$SCRIPT_DIR/skills/forge/SKILL.md"
dst="$CLAUDE_DIR/skills/forge/SKILL.md"
if [ -f "$src" ]; then
  cp "$src" "$dst"
  echo "  ✅ skills/forge/SKILL.md"
else
  echo "  ❌ skills/forge/SKILL.md not found"
fi

# Copy knowledge base (preserve existing if already present)
src="$SCRIPT_DIR/skills/forge/knowledge.md"
dst="$CLAUDE_DIR/skills/forge/knowledge.md"
if [ -f "$src" ]; then
  if [ -f "$dst" ]; then
    echo "  ⏭️  skills/forge/knowledge.md (preserved — already exists)"
  else
    cp "$src" "$dst"
    echo "  ✅ skills/forge/knowledge.md"
  fi
else
  echo "  ⏭️  skills/forge/knowledge.md (not in repo — will be auto-created on first run)"
fi

echo ""
echo "  ⚒️  Forge installed successfully!"
echo ""
echo "  Usage: Open any project and type /forge <requirement>"
echo "  Example: /forge implement a login page with OAuth2"
echo ""
echo "  Note: Forge writes learned knowledge to the project-local .forge/"
echo "  directory and merges to the global knowledge base at the end of"
echo "  each run. No special permission configuration is needed."
echo ""
