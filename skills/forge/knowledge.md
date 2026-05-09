# Forge Knowledge Base

Lessons learned from past dev-test cycles. Auto-updated by the Learner agent.

## Wave Efficiency
- Prefer fewer waves: each wave costs 2 agent invocations + handoff + integration test. Complexity sum ≤ 15 should always be 1 wave
- Never create single-task waves — merge into adjacent waves
- Batch independent small tasks together rather than splitting into separate waves
- Maximum 3 waves; if grouping requires more, merge related tasks to stay within the limit
