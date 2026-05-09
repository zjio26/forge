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

Scan `.forge/` for interrupted workflows before starting a new one:

1. Run `ls .forge/*-state.json 2>/dev/null` to find all state files
2. For each state file, read it and check its `status`
3. Collect all state files with `status: "in_progress"` — these are candidate interrupted workflows
4. **Auto-detect completed workflows**: For each candidate with `status: "in_progress"`, check if the workflow's key output files already exist:
   - Read the state file to get `paths` and `wave_plan`
   - Check for the existence of: the plan file, all dev records (`.forge/{slug}-dev-W{1..N}.md` where N comes from `wave_plan.total_waves`), and the integration test report (`.forge/{slug}-test-integration.md`) if total_waves > 1
   - If ALL expected files exist, the workflow actually completed — the Coordinator crashed before finalizing state. **Auto-update the state file** to `status: "completed"` and remove it from the interrupted list
5. After auto-detection, if genuinely interrupted workflows remain:
   - List them to the user:
     ```
     ⚠️ Found interrupted workflow(s):
       1. {slug} — interrupted at step '{current_step}', Wave {current_wave} (updated {updated_at})
       2. {slug2} — interrupted at step '{current_step2}' (updated {updated_at2})
     ```
   - Use **AskUserQuestion** to ask: "Resume an interrupted workflow?" with options for each interrupted slug plus "Start fresh: {new slug from current requirement}"
   - If the user chooses to resume, **discard the current requirement's slug** and adopt the chosen workflow's slug, paths, and all state variables, then proceed to **Resume from interrupted state** (step 7 below)
   - If the user chooses to start fresh, proceed with the current slug normally
6. **If no interrupted workflows remain, or user chose fresh start**, check `.forge/{slug}-state.json`:
   - **No state file**: fresh run. Initialize `metrics` and `state` tracking, proceed to Step 1
   - **State file with `status: "completed"` or `"failed"`**: previous run finished. Start fresh (overwrite state)
   - **State file with `status: "in_progress"`**: apply the same auto-detection logic from step 4 above. If key outputs exist, auto-complete it; otherwise resume from the recorded step — proceed to **Resume from interrupted state** (step 7 below)
7. **Resume from interrupted state**:
   1. Read the state file to get: `current_step`, `current_wave`, `wave_plan`, `fix_round`, `integration_fix_round`, `current_bugs`, `paths`, `agent_ids`
   2. Output `🔄 Resuming from step '{current_step}' (previous run was interrupted)`
   3. Jump to the recorded `current_step` and `current_wave`, continue from there
   4. If agent IDs are present but the agent is no longer reachable (SendMessage fails), create a new agent in Recovery Mode (see agent definitions) with the relevant file paths so it can rebuild context from the written records. For Dev Recovery, include the handoff context path for the current wave. For Test Recovery, include the dev record path
   5. If resuming at Step 1 (Plan) and no planner agent ID exists, create a new planner agent in Recovery Mode with the existing plan and waves paths
   6. If resuming at Step 4 (Learn) and no learner agent ID exists, create a new learner agent in Recovery Mode with the dev/test record paths and local knowledge output path
   7. If resuming in the fix loop (Step 2c or 3b), restore `current_bugs` from the state file. If `current_bugs` is empty but `current_step` is `"retest"` or `"fix"`, read the latest test report (wave-level or integration) to rebuild the bug list

**Important**: When resuming, restore all tracked variables (slug, paths, wave_plan, fix_round, agent IDs, metrics) from the state file before continuing.

### Step 1: Plan

Call the **planner** agent with:
- The full requirement description
- The slug
- The plan file path
- The waves.json path
- **The knowledge context** from Step 0 (past lessons learned)

After the planner returns:
- **Check for truncated reply** — if the reply is missing the plan file path or waves.json path, the planner likely hit maxTurns. Create a new planner agent in Recovery Mode with the existing plan and waves paths, up to 2 retries (3 total attempts). If all attempts fail, output an error and stop
- **Read the waves.json** — the planner always outputs waves.json. Read it to get the wave plan (task groupings, dependencies, complexity). Store this in memory for Step 1.5, do not re-read
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
- **Save state**: write `.forge/{slug}-state.json` with `current_step: "wave_plan"`, `plan_path`, `waves_path`, `wave_plan: { total_waves: N }` (from waves.json), and `status: "in_progress"`
- Move to Step 1.5

### Step 1.5: Wave Planning

1. Use the wave plan already read in Step 1 (do not re-read waves.json). If resuming from a crash where the wave plan is not in memory, reconstruct it by re-reading the waves.json file from the stored path
2. **Validate wave efficiency** — check for over-splitting:
   - Compute `total_complexity_sum` from the waves.json task list (M=2, L=4)
   - Compute `total_tasks` from the waves.json task list
   - Count waves with only 1 task (`single_task_waves`)
   - If `total_waves > 1` AND (`single_task_waves > 0` OR `total_waves > total_tasks / 2` OR `total_complexity_sum <= 15`), warn the user:
     ```
     ⚠️ Wave plan may be over-split:
       - {N} waves for {M} tasks (avg {M/N:.1f} tasks/wave)
       - {K} single-task wave(s)
       - Total complexity sum: {X} (≤15 suggests 1 wave is sufficient)
       Recommendation: merge waves to reduce overhead. Each wave costs 2 agent invocations + handoff + integration test.
     ```
     Use **AskUserQuestion** to ask: "Wave plan has {N} waves for {M} tasks. Merge into fewer waves?" with options:
     - "Re-plan with fewer waves" — re-invoke the planner with the same requirement and a note to minimize waves
     - "Continue as-is" — proceed with the current wave plan
   - If `total_waves >= 3` AND `total_complexity_sum <= 20`, warn the user:
     ```
     ⚠️ 3 waves for complexity {X} suggests over-splitting. Consider merging waves.
     ```
   - If `total_waves > 3`, this exceeds the hard limit. Re-invoke the planner with a note to reduce to 3 waves or fewer — do not ask the user
3. Output the wave grouping to the user:
   ```
   📊 Wave plan: {N} waves
     Wave 1: T1, T3
     Wave 2: T2, T4
     Wave 3: T5
   ```
4. If there is only **1 wave** (all tasks in a single group), the wave loop in Step 2 will execute exactly once — no special handling needed
5. **Save state**: update `.forge/{slug}-state.json` with `current_step: "dev"`, `current_wave: 1`, and `wave_plan: { total_waves: N, current_wave: 1 }` where N is the number of waves
   - Move to Step 2

### Step 2: Develop

For each wave W from 1 to total_waves:

#### 2a: Develop Wave W

Build the Dev agent prompt with:
- The plan file path
- The slug
- **Wave tasks**: the task ID list for this wave (from waves.json)
- **Wave number**: W
- **Handoff context**: path to `.forge/{slug}-handoff-W{W-1}.md` (empty for Wave 1)
- Dev record path: `.forge/{slug}-dev-W{W}.md`

After the dev agent returns:
- **Check for truncated reply** — if the reply is missing the status field or the dev record path, the dev agent likely hit maxTurns. Create a new dev agent in Recovery Mode with the plan file path, wave tasks, wave number (W), dev record path, and handoff context path (`.forge/{slug}-handoff-W{W-1}.md` if W > 1), up to 2 retries (3 total attempts). If all attempts fail, mark the wave as failed and move to the next wave
- Record the dev agent ID, status, unit test stats, and handoff path
- **Do NOT read the dev record content**
- **Save state**: update `.forge/{slug}-state.json` with `current_step: "test"`, `current_wave: W`, `agent_ids.dev_W{W}`, `handoff_paths.W{W}`
- Move to 2b

#### 2b: Test Wave W

Build the Test agent prompt with:
- The plan file path
- The dev record path (`.forge/{slug}-dev-W{W}.md`)
- The slug
- **Wave tasks**: the task ID list for this wave
- **Wave number**: W
- Test report path: `.forge/{slug}-test-W{W}.md`

After the test agent returns:
- **Check for truncated reply** — if the reply is missing the result field (pass/fail) OR the test report path, the test agent likely hit maxTurns. Also check: if the result is "fail" but the bug list is empty or missing, the reply is likely truncated (a failed test must have bugs). **You MUST retry**: create a new test agent in Recovery Mode with the plan file, dev record, and test report paths, up to 2 retries (3 total attempts). **Do NOT skip to "self-verify" or "proceed" — always retry via Recovery Mode first.** If all 3 attempts fail, treat the wave as PASS with a warning (incomplete test coverage) and note this clearly in the output
- Record the test result (pass/fail), unit test stats, integration test stats, bug count, bug list, skipped integration tests, and test agent ID
- **Do NOT read the full test report content** — exception: when resuming from a crash in the fix loop (Step 2c), read the bug list from the test report if the bug list is not in memory
- **Save state**: update `.forge/{slug}-state.json` with test result, bug info, `agent_ids.test_W{W}`. When in the fix loop (Step 2c), also save `current_bugs` (the bug list from the test agent's reply) so crash recovery can resume the fix loop
- If **PASS**: move to next wave (2a for W+1), or if this was the last wave, move to Step 3
- If **FAIL**: move to 2c (fix loop for this wave)
- If there are **skipped integration tests**, output a note to the user

#### 2c: Fix & Re-test Loop (within Wave W)

Initialize `fix_round = 1` (max 3 rounds).

**2c-i: Fix (Resume Dev Agent for Wave W)**

Resume the same dev agent using SendMessage with its recorded agent ID (`dev_W{W}`). Send:
- Mode 2: Bug Fix
- The bug list from the test agent's reply (only unit test bugs and non-environmental integration bugs — **exclude SKIPPED integration tests**)
- The dev record path for Wave W
- **Reminder**: update the handoff file (`.forge/{slug}-handoff-W{W}.md`) if any fixes change interfaces or signatures that downstream waves depend on

After the dev agent returns:
- Record the fix status
- **Save state**: update state with `current_step: "retest"`, `fix_round`
- Move to 2c-ii

**2c-ii: Re-test (Resume Test Agent for Wave W)**

Resume the same test agent using SendMessage with its recorded agent ID (`test_W{W}`). Send:
- Mode 2: Re-test
- The bug list that was reported as fixed
- The test report path for Wave W
- The plan file path (`.forge/{slug}-plan.md`)
- **Wave tasks** and **Wave number** (W)

After the test agent returns:
- **Save state**: update state with current step, test result, bug info
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

After the test agent returns:
- **Check for truncated reply** — if the reply is missing the result field (pass/fail) OR the integration test report path, the test agent likely hit maxTurns. Also check: if the result is "fail" but the bug list is empty or missing, the reply is likely truncated (a failed test must have bugs). **You MUST retry**: create a new test agent in Recovery Mode for the full integration test (include the plan file, all wave dev records, and test report paths), up to 2 retries (3 total attempts). **Do NOT skip to "self-verify" or "proceed" — always retry via Recovery Mode first.** If all 3 attempts fail, treat as PASS with a warning (incomplete integration test coverage) and note this clearly in the output
- Record the full integration test result, unit test stats, integration test stats, bug count, bug list
- If **PASS**: move to Step 4
- If **FAIL**: move to Step 3b (integration fix loop)
- If there are **skipped integration tests**, output a note to the user

#### Step 3b: Integration Fix Loop

Initialize `integration_fix_round = 1` (max 3 rounds).

**3b-i: Fix**

Group bugs by their `wave` field from the test report. For each wave group, resume the corresponding Dev agent for that wave (or create a new one in Recovery Mode if the ID is unreachable) with:
- Mode 2: Bug Fix
- The bug list for that wave (only unit test bugs and non-environmental integration bugs — **exclude SKIPPED integration tests**)
- The wave's dev record path

For bugs marked `wave: "cross-wave"`, resume the Dev agent of the earliest wave involved (based on file locations).

After the dev agent(s) return:
- **Save state**: update state
- Move to 3b-ii

**3b-ii: Re-test**

Resume the full integration test agent (or create a new one if unreachable) with:
- Mode 2: Re-test
- The bug list that was reported as fixed
- The integration test report path
- The plan file path

After the test agent returns:
- If **PASS**: move to Step 4
- If **FAIL** and `integration_fix_round < 3`: increment, go to 3b-i
- If **FAIL** and `integration_fix_round >= 3`: stop, move to Step 4 (Learn still runs)

### Step 4: Learn (after completion or failure)

**After all testing ends** (regardless of success or failure), call the **learner** agent to extract lessons from this cycle.

Call the learner agent with:
- All wave dev record paths (`.forge/{slug}-dev-W{1..N}.md`)
- All wave test report paths (`.forge/{slug}-test-W{1..N}.md`) and the integration test report path (`.forge/{slug}-test-integration.md`, if total_waves > 1)
- The global knowledge base path (`{knowledge_dir}/knowledge.md`) — read-only for the learner
- The local knowledge output path (`.forge/{slug}-knowledge.md`)
- The slug

After the learner agent returns:
- **Check for truncated reply** — if the reply is missing the local knowledge path, create a new learner agent in Recovery Mode, up to 2 retries. If all attempts fail, skip the learning step with a warning (knowledge not updated this run)
- Record how many new lessons were added and the local knowledge file path
- **Merge to global knowledge base**: read `.forge/{slug}-knowledge.md` and `{knowledge_dir}/knowledge.md`, merge new lessons into the global file (avoid duplicates). Write the updated global file
- **Finalize state**: update `.forge/{slug}-state.json` with `status: "completed"` or `status: "failed"`
- **Finalize metrics**: write `.forge/{slug}-metrics.json` (see format below)
- Move to final output

## State File Format

Write `.forge/{slug}-state.json` at every step transition. Only include fields needed for crash recovery and workflow resumption:

```json
{
  "slug": "feature-name",
  "status": "in_progress",
  "current_step": "dev",
  "current_wave": 1,
  "fix_round": 0,
  "integration_fix_round": 0,
  "current_bugs": [],
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
      "test_report": ".forge/feature-name-test-W1.md",
      "handoff": ".forge/feature-name-handoff-W1.md"
    }
  },
  "wave_plan": {
    "total_waves": 3,
    "current_wave": 1
  },
  "agent_ids": {
    "dev_W1": "a1b2c3d4",
    "test_W1": "e5f6g7h8"
  }
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
  "total_waves": 1,
  "bugs_found": 2,
  "bugs_fixed": 2,
  "knowledge_lessons_added": 1,
  "wave_efficiency": {
    "total_tasks": 4,
    "total_waves": 1,
    "tasks_per_wave": 4.0,
    "single_task_waves": 0,
    "complexity_sum": 10
  }
}
```

## Output to User

### On Success
```
Forge completed successfully!
- Plan: .forge/{slug}-plan.md
- Dev:  .forge/{slug}-dev-W{1..N}.md
- Test: .forge/{slug}-test-W{1..N}.md
- Full integration: .forge/{slug}-test-integration.md (if N > 1)
- Unit tests: X/Y passed
- Integration tests: X/Y passed, Z skipped
- Fix rounds: W1={n}, W2={n}, ...
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
- Dev:  .forge/{slug}-dev-W{1..N}.md
- Test:  .forge/{slug}-test-W{1..N}.md
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
- `📊 Step 1.5: Wave plan — {N} wave(s)`
- `🟩 Wave {W}/{N}: Developing [T1, T3]...`
- `🟨 Wave {W}/{N}: Testing [T1, T3]...`
- `🟩 Wave {W}/{N}: Fixing bugs (round {n}/3)...`
- `🟨 Wave {W}/{N}: Re-testing (round {n}/3)...`
- `🟨 Full Integration Test...`
- `🟪 Step 4: Learning...`

After each agent returns, output a one-line status:
- `✅ Plan complete → .forge/{slug}-plan.md`
- `✅ Dev complete → .forge/{slug}-dev-W{W}.md` (include unit test file count if reported)
- `✅ Wave {W} test passed (unit: X/Y, integration: X/Y, Z skipped)`
- `❌ Wave {W} test failed — {n} bugs found`
- `⚠️ {N} integration test(s) skipped` (if any were skipped)
- `✅ Bugs fixed` or `❌ Fixes incomplete`
- `✅ Full integration test passed` or `❌ Full integration test failed — {n} bugs found`
- `🟪 {n} new lessons learned`
- `💾 State saved` (after each state file update)
- `⚠️ {Agent} hit maxTurns, retrying in Recovery Mode (attempt {n}/3)` (when truncated reply detected)
- `❌ {Agent} failed after 3 attempts — step skipped` (when all retries exhausted)

## Critical Rules

1. **Each agent's reply contains the essential info** you need (status, paths, bug summaries) — no need to read their files
2. **Logs are for user inspection only** — you don't need to read them
3. **Embed full role prompt in each Agent call** — do NOT set `subagent_type` (leave it unset so the default `general-purpose` is used). Since the prompt contains the complete role definition from `agents/*.md`, agent type matching is unnecessary. Each agent call is self-contained via the embedded prompt
4. **All agents must run in foreground** (DO NOT use run_in_background) — background agents break the sequential workflow, prevent progress output, and make resume unreliable
5. **Interactive only at planning phase** — you MAY use AskUserQuestion during Step 1 (Plan). Once Step 2 (Develop) begins, the workflow runs autonomously with no further user interaction until completion
6. **MaxTurns exhaustion handling** — After each agent call, check if the reply contains a complete status line. If the reply is truncated (missing status, missing paths, or incomplete output), the agent likely hit its maxTurns limit. Create a new agent in Recovery Mode with the relevant file paths to continue. If recovery also fails after 2 attempts (3 total tries), mark the step as failed, output a warning to the user, and move on
