# Level design

Every level requires examination or manipulation of actual running processes.
`validate` emits a ten-character state fingerprint without evaluating correctness.
Level 1 uses `validate PID`; levels 2–10 use `validate`.

| Level | Live objective | Canonical expected observation |
|---|---|---|
| 1 | Identify an assigned process | Selected PID resolves to the seeded target role and token; PID is omitted from the key |
| 2 | Terminate one worker gracefully | Target is absent, receipt exists, and every protected worker remains |
| 3 | Test an ignored signal and escalate | Target is absent, ignored-signal event and required final outcome exist, and peers remain |
| 4 | Stop and continue a heartbeat worker | Target is alive, observed stop/resume transition and CONT are recorded, and peers remain |
| 5 | Set two shell-job states | Assigned stopped job is `T`; `jobs -l` in the current shell shows the other job running in background |
| 6 | Reprioritize the CPU-heavy worker | Target remains live at the required nice value |
| 7 | Remove one process-tree branch | Every target-branch process is absent and the protected branch remains |
| 8 | Terminate one process group | Every target-group member is absent and the protected group remains |
| 9 | Cause a parent to reap a zombie | Zombie is absent, parent remains, and the reap event exists |
| 10 | Restore a mixed process incident | Priority, resumed state, group shutdown, escalation, and preservation all match |

## Submission invariants

- The scenario uses the NUL-delimited `seed-v1` contract in `polylinux-common.sh`.
- Realistic service roles are selected without target/distractor collisions.
- PIDs and PGIDs come from the current Linux runtime.
- The snapshot uses role-sorted logical states; numeric process identifiers,
  timestamps, and momentary running/sleeping states are omitted.
- Learner identity, date, and level are inside the hashed bytes.
- The independent grader derives the expected snapshot from the seed.
- The VM does not contain expected codes or a correctness check.
- The old learner-readable `evidence/` directories are not generated.

