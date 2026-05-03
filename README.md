[English](README.md) | [中文](README_CN.md) | [日本語](README_JA.md) | [Español](README_ES.md)

# Forge

> Forge — a solid harness-engineered workflow for Claude Code. Quality enforced by structure, not prompt discipline.

![License](https://img.shields.io/github/license/zjio26/forge) ![GitHub stars](https://img.shields.io/github/stars/zjio26/forge?style=social)

```
┌─────────────────────────────────────────────────────────┐
│  $ /forge:forge Build a rate-limited API gateway with    │
│            JWT auth, Redis token revocation, request     │
│            dedup, and Prometheus metrics                 │
│                                                         │
│  🟦 Planning...      ✅ Plan complete                   │
│  🟩 Wave 1/3 Dev...  ✅ 12 unit tests passed            │
│  🟨 Wave 1/3 Test... ✅ PASS (unit: 12/12, int: 3/4)   │
│  🟩 Wave 2/3 Dev...  ✅ 8 unit tests passed             │
│  🟨 Wave 2/3 Test... ❌ 2 bugs → 🟩 Fix → ✅ PASS      │
│  🟩 Wave 3/3 Dev...  ✅ 6 unit tests passed             │
│  🟨 Wave 3/3 Test... ✅ PASS                            │
│  🟨 Integration...   ✅ Full integration PASS            │
│  🟪 Learning...      4 new lessons → knowledge.md       │
│                                                         │
│  Forge completed! 26/26 unit tests passed.              │
└─────────────────────────────────────────────────────────┘
```

---

## Vanilla Claude Code Hurts — Forge Fixes It Structurally

You've been there:

- **Code without tests** — or tests that exist only on paper. If humans skip tests, models will too
- **Context drift** — halfway through a task, it forgets what it started with
- **Fix A, break B** — no closed-loop verification, bugs cascade
- **Same pitfalls, every run** — zero learning from past mistakes
- **Crash = start over** — no checkpoint, no recovery, all work gone

Forge doesn't ask the model to "be careful." It welds engineering discipline into the workflow:

| Superpower | How It Works |
|------------|--------------|
| **Closed-Loop Dev→Test→Fix** | Dev must pass Test. Fails? Fix. Fails again? Fix again, up to 3 rounds. Verdict: PASS/FAIL — no "looks fine" |
| **Wave-Based Scaling** | Large requirements auto-split into Waves. Each wave gets a fresh Dev+Test pair. Cross-wave handoff via handoff files |
| **Experience Accumulation** | Learner extracts lessons into knowledge.md. Planner references them next time. Smarter with every run |
| **Crash Recovery** | Every step writes a checkpoint to state.json. Re-run the same command, resume from where you left off. Zero lines lost |
| **Think Before Code** | Planner spots ambiguities and asks you first. No more coding in the wrong direction for an hour |
| **Context Isolation** | Coordinator tracks paths and status only — never reads intermediate content. Context stays lean |

## Architecture

```
User ──"/forge requirement"──▶ Coordinator
                                  │
                       ┌──────────┤
                       ▼          │
                  🟦 Planner     │
                  plan + waves   │
                       │          │
                       ▼          │
               ┌─── Wave Loop ──────────────────┐
               │                                │
               │  🟩 Dev W1 ──▶ 🟨 Test W1     │
               │       ▲              │         │
               │       │           FAIL?        │
               │       └── Fix ──────┘          │
               │       (same agent,             │
               │        context preserved)      │
               │              │                 │
               │            PASS ──▶ next wave  │
               │                                │
               └────────────────────────────────┘
                                  │
                                  ▼
                       🟨 Full Integration Test
                                  │
                                  ▼
                       🟪 Learner ──▶ 📚 knowledge.md
```

| Agent | Model | Role |
|-------|-------|------|
| Coordinator | — | Dispatches agents, tracks paths and status — never reads intermediate content |
| Planner | sonnet | Decomposes requirements, defines acceptance criteria, surfaces ambiguities |
| Dev | sonnet | Implements features, writes unit tests, fixes bugs — only what's in the plan |
| Test | haiku | Unit tests must pass, integration tests best-effort, bug reports precise |
| Learner | haiku | Extracts lessons, deduplicates, max 5 per run |

---

## Design Philosophy: Harness Engineering

Quality through structural constraints, not model self-discipline:

- **Structure > Willpower** — Rules live in the workflow, not in prompts. If a rule can't be structurally enforced, redesign the workflow
- **Closed Loop > Open Loop** — Dev→Test→Fix is mandatory. Verdicts are PASS/FAIL only, no "should be fine"
- **Isolation > Bloat** — Coordinator tracks paths and status, never content. Each wave gets independent context
- **Recoverable > Retryable** — State checkpoint at every step. Resume from breakpoint after crash, don't start over
- **Only What's Asked** — Every changed line traces back to the plan or a bug fix. No extras, no speculative enhancements

---

## 5-Minute Quick Start

**Prerequisite**: [Claude Code CLI](https://docs.anthropics.com/en/docs/claude-code) installed.

**Plugin install (recommended):**

```
/plugin marketplace add zjio26/forge
/plugin install forge@forge
```

**Offline install:**

```bash
git clone https://github.com/zjio26/forge.git && cd forge && bash install.sh
```

**Fire:**

```
/forge:forge Build a rate-limited API gateway with JWT auth, Redis token revocation, request dedup, and Prometheus metrics
```

> Plugin mode uses `/forge:forge`, manual install uses `/forge`. That's the only difference.

---

## Usage Examples

**Build a non-trivial feature:**

> **You**: `/forge:forge Implement a full user registration→login→order→payment flow with JWT auth, inventory locking, and timeout auto-release`
>
> **Forge**: Planner decomposes into 5 subtasks, 3 waves → Wave 1 builds data models and auth → Wave 2 handles orders and inventory → Wave 3 handles payments and timeouts → full integration test → Learner extracts 3 lessons

**Refactor with a safety net:**

> **You**: `/forge:forge Refactor the database layer to use connection pooling, compatible with all existing callers`
>
> **Forge**: Planner identifies affected modules → Dev makes surgical changes → Test runs full unit + integration suite → regression caught by auto-Fix → zero manual intervention

**Crashed? Resume:**

> **You**: `/forge:forge` (just re-run the same command)
>
> **Forge**: Reads state.json → resumes from last checkpoint → not a single line lost

---

## Project Structure

```
forge/
├── agents/                  # Specialized agent definitions
│   ├── planner.md           # Requirement decomposition — sonnet, defines acceptance criteria
│   ├── dev.md               # Implementation + unit tests + bug fixes — sonnet, only planned work
│   ├── test.md              # Test verification — haiku, unit test fail = FAIL
│   └── learner.md           # Experience extraction — haiku, dedup, max 5 per run
├── skills/forge/
│   ├── SKILL.md             # Coordinator orchestrator — tracks paths and status only
│   └── knowledge.md         # Experience knowledge base — auto-updated by Learner
├── install.sh               # Offline installer
└── CLAUDE.md                # Project instructions
```

Runtime artifacts (in target project's `.forge/` directory, gitignored):

```
.forge/
├── {slug}-plan.md              # Development plan
├── {slug}-waves.json           # Wave grouping
├── {slug}-dev-W{n}.md          # Wave dev record
├── {slug}-test-W{n}.md         # Wave test report
├── {slug}-handoff-W{n}.md      # Wave handoff file
├── {slug}-test-integration.md  # Full integration test report
├── {slug}-state.json           # State checkpoint (crash recovery)
└── {slug}-metrics.json         # Runtime metrics
```

---

## Contributing & License

PRs welcome. Agent definitions and orchestration logic are the core — read CLAUDE.md's design principles before modifying.

- Modifying agent definitions: each file must be self-contained, path references use `.forge/`
- Modifying SKILL.md: Coordinator tracks paths and status only, never reads content
- Modifying install.sh: keep source-to-target path mappings in sync

[MIT License](LICENSE)
