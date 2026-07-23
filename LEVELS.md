# Level design

| Level | Scenario | Hash-derived variation | Verified result |
|---|---|---|---|
| 1 | Process roll call | theme, target role, token, distractor count | correct live `PID|PPID|STATE` |
| 2 | Graceful shutdown | role, receipt filename, distractors | target exited by TERM, receipt present, peers alive |
| 3 | Stubborn worker | role, ignored signal, final signal | ignored signal tested, correct shutdown, peers alive |
| 4 | Pause and resume | role, heartbeat filename and interval | CONT observed, target running, peers preserved |
| 5 | Shell jobs | two role names and target states | first job stopped, second running |
| 6 | Resource hog | hidden target role, worker count, required nice | CPU worker alive at required niceness |
| 7 | Process tree | parent, target branch, protected branch, fanout | target branch gone, protected branch alive |
| 8 | Process groups | group labels and stage count | complete target group gone, protected group alive |
| 9 | Zombie | parent/child roles and control signal | parent reaped zombie and remains alive |
| 10 | Incident response | all roles, group label, nice value | mixed remediation state completed |

## Generator invariants

- Correct targets and required states are derived before distractors.
- Labeled sub-hashes independently select theme, names, behavior, and layout.
- Live PIDs are discovered after launch and never treated as deterministic.
- Target and distractor identities cannot collide.
- Every runtime writes a registry containing label, PID, PPID, and PGID.
- Verification checks protected processes as well as requested targets.
- Reset, navigation, and reinstall clean up recorded processes.
- No level requires root privileges.
