# Level design

The live process objective and the externally graded evidence answer are
separate. `checklevel` supplies formative feedback about live state; the
Microsoft 365 grader evaluates the stable semantic answer.

| Level | Live objective | Evidence artifact | Exact answer shape |
|---|---|---|---|
| 1 | Identify an assigned process | `process-inventory.txt` | `role|worker-id|state-class` |
| 2 | Terminate one worker gracefully | `shutdown-policy.txt` | `role|signal|receipt-name|protected-count` |
| 3 | Test an ignored signal and escalate | `signal-policy.txt` | `role|ignored-signal|final-signal` |
| 4 | Stop and continue a heartbeat worker | `heartbeat-policy.txt` | `role|stop-signal|continue-signal|heartbeat-name` |
| 5 | Set two shell-job states | `job-policy.txt` | `stopped-role|T|background-role|S` |
| 6 | Reprioritize the CPU-heavy worker | `scheduling-snapshot.txt` | `role|nice-value|lower-priority` |
| 7 | Remove one process-tree branch | `process-tree.txt` | `parent-role|target-branch|child-count|protected-branch` |
| 8 | Terminate one process group | `process-groups.txt` | `target-label|member-count|TERM|protected-label` |
| 9 | Cause a parent to reap a zombie | `zombie-snapshot.txt` | `zombie-role|parent-role|control-signal|reap` |
| 10 | Restore a mixed process incident | `incident-evidence.txt` | `hog@nice;paused@CONT;group@TERM;stubborn@TERM>KILL;protected@KEEP` |

## Generator invariants

- The exact seed bytes are
  `email + ISO_date + exercise_password + level_password`.
- Labeled SHA-256 sub-hashes independently select themes, roles, behaviors,
  filenames, counts, identities, and required values.
- Live PIDs and PGIDs never appear in an external answer.
- The canonical answer is generated before distractors and stored root-only.
- Learner-visible evidence contains every fact needed by the reference solver.
- The reference solver reads evidence rather than the seed or protected answer.
- Identical seed inputs reproduce identical evidence and answers.
- Changing the learner identity changes the intended seeded properties.
- Protected live workers are checked as well as requested target processes.
