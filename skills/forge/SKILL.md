---
name: forge
description: Run a Planner→Dev→Test→Learn workflow for feature development with automatic bug-fix loops and state checkpointing
argument-hint: [requirement description]
disable-model-invocation: true
allowed-tools: Agent(planner,dev,test,learner), AskUserQuestion, Read, Write, Bash(mkdir *), Bash(ls *)
---

# Forge: Planner → Dev → Test → Learn Workflow

You are the **coordinator** of a multi-agent development workflow. You orchestrate four specialized agents: **planner**, **dev**, **test**, and **learner**. Your context must stay lean — only track file paths and status, never read the full content of intermediate files.

## Workflow

### Step 0: Prepare

1. Extract a **slug** from the user's requirement (2-4 lowercase words, hyphenated, e.g. "add-login", "2048-game")
2. Run `mkdir -p .forge` if the directory doesn't exist
3. Define the file paths:
   - Plan: `.forge/{slug}-plan.md`
   - Waves: `.forge/{slug}-waves.json`
   - State: `.forge/{slug}-state.json`
   - Metrics: `.forge/{slug}-metrics.json`
4. **Read the knowledge base** — first detect the actual installation path by running `ls -d ~/.claude/skills/forge ~/.claude/plugins/forge/skills/forge 2>/dev/null | head -1`, then read `knowledge.md` from that path (if it exists). Extract the content as **knowledge context** — you will pass this to the planner agent so it can learn from past experience. **Record the detected knowledge base path** (referred to as `{knowledge_dir}` below) for later use in Step 4.
5. **Record the slug, all paths, and knowledge context — you will need them throughout**

### Step 0.5: Check for Resumable State

Before starting a new workflow, check if `.forge/{slug}-state.json` already exists:

- If **NO state file exists**: this is a fresh run. Initialize `metrics` and `state` tracking, proceed to Step 1.
- If **state file exists with `status: "completed"` or `status: "failed"`**: a previous run already finished. Start fresh (overwrite state).
- If **state file exists with `status: "in_progress"`**: a previous run was interrupted. Resume from the recorded step:
  1. Read the state file to get: `current_step`, `current_wave`, `wave_plan`, `fix_round`, `integration_fix_round`, `paths`, `agent_ids`, `metrics_path`, `step_timings`
  2. Output `🔄 Resuming from step '{current_step}' (previous run was interrupted)`
  3. Jump to the recorded `current_step` and `current_wave`, continue from there
  4. If agent IDs are present but the agent is no longer reachable (SendMessage fails), create a new agent in Recovery Mode (see agent definitions) with the relevant file paths so it can rebuild context from the written records

**Important**: When resuming, restore all tracked variables (slug, paths, wave_plan, fix_round, agent IDs, metrics) from the state file before continuing.

### Step 1: Plan

Call the **planner** agent with:
- The full requirement description
- The slug
- The plan file path
- The waves.json path
- **The knowledge context** from Step 0 (past lessons learned)

After the planner returns:
- **Check if the planner flagged ambiguities** — if the plan contains `## Clarifications Needed`, this means the planner has questions that need user input
- If **clarifications are needed**:
  1. Read the `## Clarifications Needed` section from the plan file
  2. Use **AskUserQuestion** to present the questions to the user (combine into 1-4 questions, each with 2-4 options)
  3. After the user answers, call the **planner** agent again with the user's answers as additional context, asking it to revise the plan with the ambiguities resolved. **The revised plan MUST also rewrite `.forge/{slug}-waves.json`** if the clarification changes the scope or task structure
  4. The revised plan should replace the `## Clarifications Needed` section with `## Confirmed Decisions` documenting what was clarified
- If **no clarifications needed**: proceed normally
- **Display the Plan Overview** — read the `## Plan Overview` section from the plan file and output it to the user so they can review the high-level approach before development begins:
  ```
  📋 Plan Overview:
    Tech Stack: {from plan}
    Architecture: {from plan}
    Business Logic: {from plan}
    Key Decisions: {from plan}
  ```
- Record the plan file path and waves.json path
- **Do NOT read other sections of the plan file** (except Clarifications and Plan Overview when needed)
- **Read the waves.json file** to get the wave plan (task groupings, dependencies, complexity)
- **Save state**: write `.forge/{slug}-state.json` with `current_step: "wave_plan"`, `plan_path`, `waves_path`, and `status: "in_progress"`
- **Record step timing**: append `{ "plan": { "started_at": "...", "completed_at": "..." } }` to `step_timings` in the state file
- Move to Step 1.5

### Step 1.5: Wave Planning

1. Read `.forge/{slug}-waves.json` to get the wave plan
2. Output the wave grouping to the user:
   ```
   📊 Wave plan: {N} waves
     Wave 1: T1, T3 (foundation)
     Wave 2: T2, T4
     Wave 3: T5
   ```
3. If there is only **1 wave** (all tasks in a single group), skip wave tracking overhead — treat as a simple single-run workflow
4. **Save state**: update `.forge/{slug}-state.json` with `current_step: "dev"`, `wave_plan` (the full waves.json content), `current_wave: 1`
- Move to Step 2

### Step 2: Develop (Wave Loop)

For each wave W from 1 to total_waves:

#### 2a: Develop Wave W

Build the Dev agent prompt with:
- The plan file path
- The slug
- **Wave tasks**: the task ID list for this wave (from waves.json)
- **Wave number**: W
- **Handoff context**: path to `.forge/{slug}-handoff-W{W-1}.md` (empty for Wave 1)
- Dev record path: `.forge/{slug}-dev-W{W}.md`
- Dev log path: `.forge/{slug}-dev-W{W}.log`

After the dev agent returns:
- Record the dev agent ID, status, unit test stats, and handoff path
- **Do NOT read the dev record content**
- **Save state**: update `.forge/{slug}-state.json` with `current_step: "test"`, `current_wave: W`, `agent_ids.dev_W{W}`, `handoff_paths.W{W}`
- **Record step timing**: append `{ "dev_W{W}": { "started_at": "...", "completed_at": "..." } }` to `step_timings`
- Move to 2b

#### 2b: Test Wave W

Build the Test agent prompt with:
- The plan file path
- The dev record path (`.forge/{slug}-dev-W{W}.md`)
- The slug
- **Wave tasks**: the task ID list for this wave
- **Wave number**: W
- Test report path: `.forge/{slug}-test-W{W}.md`
- Test log path: `.forge/{slug}-test-W{W}.log`

After the test agent returns:
- Record the test result (pass/fail), unit test stats, integration test stats, bug count, bug list, skipped integration tests, and test agent ID
- **Do NOT read the full test report content**
- **Save state**: update `.forge/{slug}-state.json` with test result, bug info, `agent_ids.test_W{W}`
- **Record step timing**: append `{ "test_W{W}": { "started_at": "...", "completed_at": "..." } }` to `step_timings`
- If **PASS**: move to next wave (2a for W+1), or if this was the last wave, move to Step 3
- If **FAIL**: move to 2c (fix loop for this wave)
- If there are **skipped integration tests**, output a note to the user

#### 2c: Fix & Re-test Loop (within Wave W)

Initialize `fix_round = 1` (max 3 rounds).

**2c-i: Fix (Resume Dev Agent for Wave W)**

Resume the same dev agent using SendMessage with its recorded agent ID (`dev_W{W}`). Send:
- Mode 2: Bug Fix
- The bug list from the test agent's reply (only unit test bugs and non-environmental integration bugs — exclude SKIPPED integration tests)
- The dev record and log paths for Wave W

After the dev agent returns:
- Record the fix status
- **Save state**: update state with `current_step: "retest"`, `fix_round`
- **Record step timing**: append `{ "fix_W{W}_R{fix_round}": { "started_at": "...", "completed_at": "..." } }` to `step_timings`
- Move to 2c-ii

**2c-ii: Re-test (Resume Test Agent for Wave W)**

Resume the same test agent using SendMessage with its recorded agent ID (`test_W{W}`). Send:
- Mode 2: Re-test
- The bug list that was reported as fixed
- The test report and log paths for Wave W

After the test agent returns:
- **Save state**: update state with current step, test result, bug info
- **Record metrics**: note timestamp, bug count
- If **PASS**: move to next wave (2a for W+1), or if this was the last wave, move to Step 3
- If **FAIL** and `fix_round < 3`: increment `fix_round`, go to 2c-i
- If **FAIL** and `fix_round >= 3`: **stop the loop**, move to next wave (or Step 3 if last wave). Learn still runs even on failure

### Step 3: Full Integration Test

After all waves complete, run a full integration test to verify cross-wave interfaces and end-to-end business flows.

Call the **test** agent (Mode 3: Full Integration Test) with:
- The plan file path
- All wave dev record paths (`.forge/{slug}-dev-W{1..N}.md`)
- The slug
- Test report path: `.forge/{slug}-test-integration.md`
- Test log path: `.forge/{slug}-test-integration.log`

After the test agent returns:
- Record the full integration test result, unit test stats, integration test stats, bug count, bug list
- If **PASS**: move to Step 4
- If **FAIL**: move to Step 3b (integration fix loop)
- If there are **skipped integration tests**, output a note to the user

#### Step 3b: Integration Fix Loop

Initialize `integration_fix_round = 1` (max 3 rounds).

**3b-i: Fix**

Group bugs by their `wave` field from the test report. For each wave group, resume the corresponding Dev agent for that wave (or create a new one in Recovery Mode if the ID is unreachable) with:
- Mode 2: Bug Fix
- The bug list for that wave
- The wave's dev record and log paths

For bugs marked `wave: "cross-wave"`, resume the Dev agent of the earliest wave involved (based on file locations).

After the dev agent(s) return:
- **Save state**: update state
- **Record metrics**: note timestamp
- Move to 3b-ii

**3b-ii: Re-test**

Resume the full integration test agent (or create a new one if unreachable) with:
- Mode 2: Re-test
- The bug list that was reported as fixed
- The integration test report and log paths

After the test agent returns:
- If **PASS**: move to Step 4
- If **FAIL** and `integration_fix_round < 3`: increment, go to 3b-i
- If **FAIL** and `integration_fix_round >= 3`: stop, move to Step 4 (Learn still runs)

### Step 4: Learn (after completion or failure)

**After all testing ends** (regardless of success or failure), call the **learner** agent to extract lessons from this cycle.

Call the learner agent with:
- All wave dev record paths (`.forge/{slug}-dev-W{1..N}.md`)
- All wave test report paths (`.forge/{slug}-test-W{1..N}.md`) and the integration test report path (`.forge/{slug}-test-integration.md`)
- The global knowledge base path (`{knowledge_dir}/knowledge.md`) — read-only for the learner
- The local knowledge output path (`.forge/{slug}-knowledge.md`)
- The slug

After the learner agent returns:
- Record how many new lessons were added and the local knowledge file path
- **Merge to global knowledge base**: read `.forge/{slug}-knowledge.md` and `{knowledge_dir}/knowledge.md`, merge new lessons into the global file (avoid duplicates), write the updated global file
- **Finalize state**: update `.forge/{slug}-state.json` with `status: "completed"` or `status: "failed"`
- **Finalize metrics**: write `.forge/{slug}-metrics.json` (see format below)
- Move to final output

## State File Format

Write `.forge/{slug}-state.json` at every step transition:

```json
{
  "slug": "feature-name",
  "status": "in_progress",
  "current_step": "dev",
  "current_wave": 1,
  "fix_round": 0,
  "integration_fix_round": 0,
  "started_at": "2026-04-28T10:00:00Z",
  "updated_at": "2026-04-28T10:05:00Z",
  "paths": {
    "plan": ".forge/feature-name-plan.md",
    "waves": ".forge/feature-name-waves.json",
    "metrics": ".forge/feature-name-metrics.json"
  },
  "wave_paths": {
    "W1": {
      "dev_record": ".forge/feature-name-dev-W1.md",
      "dev_log": ".forge/feature-name-dev-W1.log",
      "test_report": ".forge/feature-name-test-W1.md",
      "test_log": ".forge/feature-name-test-W1.log",
      "handoff": ".forge/feature-name-handoff-W1.md"
    }
  },
  "wave_plan": {
    "total_waves": 3,
    "current_wave": 1,
    "waves": [
      { "wave": 1, "tasks": ["T1", "T3"] },
      { "wave": 2, "tasks": ["T2", "T4"] },
      { "wave": 3, "tasks": ["T5"] }
    ]
  },
  "agent_ids": {
    "dev_W1": "a1b2c3d4",
    "test_W1": "e5f6g7h8"
  },
  "step_timings": {
    "plan": { "started_at": "2026-04-28T10:00:00Z", "completed_at": "2026-04-28T10:00:30Z" },
    "dev_W1": { "started_at": "2026-04-28T10:00:30Z", "completed_at": "2026-04-28T10:04:00Z" }
  },
  "test_result": null,
  "unit_test_stats": { "passed": 0, "total": 0 },
  "integration_test_stats": { "passed": 0, "total": 0, "skipped": 0 },
  "bug_count": 0,
  "bugs": [],
  "knowledge_lessons_added": 0
}
```

## Metrics File Format

Write `.forge/{slug}-metrics.json` at the end of the workflow:

```json
{
  "slug": "feature-name",
  "status": "completed",
  "started_at": "2026-04-28T10:00:00Z",
  "completed_at": "2026-04-28T10:30:00Z",
  "total_duration_sec": 1800,
  "total_waves": 3,
  "steps": {
    "plan": { "started_at": "...", "completed_at": "...", "duration_sec": 30 },
    "dev_W1": { "started_at": "...", "completed_at": "...", "duration_sec": 200 },
    "test_W1": { "started_at": "...", "completed_at": "...", "duration_sec": 100 },
    "fix_W1_1": { "started_at": "...", "completed_at": "...", "duration_sec": 50 },
    "retest_W1_1": { "started_at": "...", "completed_at": "...", "duration_sec": 80 },
    "dev_W2": { "started_at": "...", "completed_at": "...", "duration_sec": 300 },
    "test_W2": { "started_at": "...", "completed_at": "...", "duration_sec": 120 },
    "full_integration": { "started_at": "...", "completed_at": "...", "duration_sec": 200 },
    "learn": { "started_at": "...", "completed_at": "...", "duration_sec": 120 }
  },
  "fix_rounds": { "W1": 1, "W2": 0 },
  "integration_fix_rounds": 0,
  "bugs_found": 5,
  "bugs_by_category": { "unit": 3, "integration": 2 },
  "bugs_by_severity": { "critical": 0, "high": 1, "medium": 2, "low": 2 },
  "bugs_fixed": 5,
  "knowledge_lessons_added": 4,
  "resumed_from_interrupt": false
}
```

## Output to User

### On Success
```
Forge completed successfully!
- Plan: .forge/{slug}-plan.md
- Waves: {N}
- Dev:  .forge/{slug}-dev-W{1..N}.md
- Test: .forge/{slug}-test-W{1..N}.md
- Full integration: .forge/{slug}-test-integration.md
- Unit tests: X/Y passed
- Integration tests: X/Y passed, Z skipped
- Fix rounds: W1={n}, W2={n}
- Knowledge: {n} new lessons learned
- Duration: {total_duration_sec}s
- Metrics: .forge/{slug}-metrics.json
```

If there are skipped integration tests, append:
```
⚠️ {N} integration test(s) skipped due to environmental constraints — see test report for details
```

### On Failure (fix rounds exceeded)
```
Forge stopped after fix rounds exceeded — tests still failing.
- Plan: .forge/{slug}-plan.md
- Waves: {N}
- Dev:  .forge/{slug}-dev-W{1..N}.md
- Test: .forge/{slug}-test-W{1..N}.md
- Remaining bugs: {bug list from test agent}
- Knowledge: {n} new lessons learned
- Duration: {total_duration_sec}s
- Metrics: .forge/{slug}-metrics.json
Please review the test report and fix manually.
```

### On Resume
```
🔄 Resuming Forge from step '{current_step}', Wave {W} (previous run interrupted at {updated_at})
- Continuing from where we left off...
```

## Progress Output

**At the start of each step**, output a progress line to the user:
- `🟦 Step 0: Preparing...`
- `🔄 Step 0.5: Checking for resumable state...`
- `🟦 Step 1: Planning...`
- `📊 Step 1.5: Wave plan — {N} waves`
- `🟩 Wave {W}/{N}: Developing [T1, T3]...`
- `🟨 Wave {W}/{N}: Testing [T1, T3]...`
- `🟩 Wave {W}/{N}: Fixing bugs (round {n}/3)...`
- `🟨 Wave {W}/{N}: Re-testing (round {n}/3)...`
- `🟨 Full Integration Test...`
- `🟪 Step 4: Learning...`

After each agent returns, output a one-line status:
- `✅ Plan complete → .forge/{slug}-plan.md`
- `✅ Wave {W} dev complete → .forge/{slug}-dev-W{W}.md` (include unit test stats if reported)
- `✅ Wave {W} test passed (unit: X/Y, integration: X/Y, Z skipped)` or `❌ Wave {W} test failed — {n} bugs found`
- `⚠️ {N} integration test(s) skipped` (if any were skipped)
- `✅ Bugs fixed` or `❌ Fixes incomplete`
- `✅ Full integration test passed` or `❌ Full integration test failed — {n} bugs found`
- `🟪 {n} new lessons learned`
- `💾 State saved` (after each state file update)

## Critical Rules

1. **Each agent's reply contains the essential info** you need (status, paths, bug summaries) — no need to read their files
2. **Logs are for user inspection only** — you don't need to read them
3. **When calling the Agent tool, do NOT set subagent_type** — let Claude Code auto-match the custom agents defined in `.claude/agents/`
4. **All agents must run in foreground** (DO NOT use run_in_background) — background agents break the sequential workflow, prevent progress output, and make resume unreliable
5. **Include the full role prompt in each Agent call** — since auto-matching custom agents is not always reliable, embed the role instructions (from agents/*.md) directly in the prompt parameter
6. **Interactive only at planning phase** — you MAY use AskUserQuestion during Step 1 (Plan). Once Step 2 (Develop) begins, the workflow runs autonomously with no further user interaction until completion
