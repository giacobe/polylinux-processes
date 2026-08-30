# Level design

Every level requires examination or manipulation of actual running processes.
`submit` emits a live-state snapshot only after `the external answer form` confirms the
requested result.

| Level | Live objective | Submission verifier requirement |
|---|---|---|
| 1 | Identify an assigned process | Submitted PID, PPID, and state match the target's live process row |
| 2 | Terminate one worker gracefully | Target is absent, receipt exists, and every protected worker remains |
| 3 | Test an ignored signal and escalate | Target is absent, ignored-signal event exists, and protected workers remain |
| 4 | Stop and continue a heartbeat worker | Target is alive and not stopped, CONT is recorded, and protected workers remain |
| 5 | Set two shell-job states | Assigned stopped job is `T`; assigned background job remains live and not `T` |
| 6 | Reprioritize the CPU-heavy worker | Target remains live at the required nice value |
| 7 | Remove one process-tree branch | Every target-branch process is absent and the protected branch remains |
| 8 | Terminate one process group | Every target-group member is absent and the protected group remains |
| 9 | Cause a parent to reap a zombie | Zombie is absent, parent remains, and the reap event exists |
| 10 | Restore a mixed process incident | Priority, resumed state, group shutdown, escalation, and preservation all match |

## Submission invariants

- The scenario is seeded from
  `email + ISO_date + exercise_password + level_password`.
- Realistic service roles are selected without target/distractor collisions.
- PIDs and PGIDs come from the current Linux runtime.
- The snapshot is sorted by service role so incidental launch order does not
  affect record order.
- Learner identity, date, level, theme, and launch token are inside the hashed
  bytes.
- Process rows come from current `/proc`/`ps` state and are cross-checked
  against the current user's UID and launch token.
- A failed `the external answer form` produces no submission digest.
- The verifier recomputes SHA-256 before interpreting any process records.
- The old learner-readable `evidence/` directories are not generated.

