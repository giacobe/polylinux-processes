---
title: "PolyLinux Processes and Job Control"
short_title: "Processes"
panel_title: "Learning Path"
form_url: ""

---

# PolyLinux Processes and Job Control

Practice inspecting and managing real, disposable Linux processes. Each level
creates its own process scenario. Names, roles, and clues vary with your email
address and exercise date. Linux assigns new PIDs whenever you restart a level.

## Get on the machine

Wait for the virtual machine to boot, then log in as `root` with no password.
The installer asks for your email address and prepares ten level accounts. It
opens `level1` when that level is ready. Later levels may still be building.

Read the briefing for each level before acting:

```sh
cat README.txt
```

Start or reset the current scenario, then inspect its processes:

```sh
startlevel
ps -ww -o pid,ppid,pgid,stat,ni,comm,args
```

`-ww` keeps long command arguments visible in the narrow terminal. Keep the
field names together after `-o`: spaces after the commas make the `ps` output
list invalid. Match all the assigned clues before choosing a
process. Use `grep` with a role or token from the briefing to narrow a list.

## Navigate and reset

Run `nextlevel` or `prevlevel` to move between accounts. Navigation cleans up
processes from the level you leave. Run `startlevel` again to reset a damaged
scenario. A reset creates new PIDs, so inspect the process table again before
using a PID you wrote down earlier.

## Process and job commands

| Task | Command |
| --- | --- |
| Inspect processes | `ps -ww -o pid,ppid,pgid,stat,ni,comm,args` |
| Watch CPU and nice values | `top` (press `q` to leave) |
| Send normal termination | `kill -TERM PID` |
| Send a hangup signal | `kill -HUP PID` |
| Stop or continue a process | `kill -STOP PID`, `kill -CONT PID` |
| Signal one process group | `kill -TERM -- -PGID` |
| Inspect jobs in your shell | `jobs -l` |
| Resume a stopped job in the background | `bg %N` |
| Bring a job to the foreground | `fg %N` |
| Set a running process's nice value | `renice VALUE -p PID` |

`PID` names one process; `PGID` names a process group. A negative PGID after
`--` signals the entire group. A shell job number uses `%N` and belongs to the
current interactive shell; it is not a PID. The first letter of `STAT` is the
state: `R` runnable, `S` sleeping, `T` stopped, or `Z` zombie.

## Submission keys

After completing each level, run `validate` and record its ten-character key.
For Level 1, find the assigned process and run `validate PID` with its current
PID. The command fingerprints what it observes; it does not say whether your
work is correct. A separate grading form will compare your key with the
expected key. Resetting a level gives its workers new PIDs.

## Level guidance

### Level 1: Process roll call

The briefing gives a target role and token. `startlevel` launches that worker
and four to seven distractors. Find the process whose arguments match both
clues. Run `validate PID` with its current PID. PIDs change after a reset.

### Level 2: Graceful shutdown

Identify the assigned worker by role and token. Send `TERM` to that PID and
leave its peers running. Check the named receipt in `runtime/` and inspect the
process list again.

### Level 3: The stubborn worker

HUP means "hangup"; it originally indicated that a terminal connection had
closed. If your briefing says the worker ignores HUP, send `kill -HUP PID`
to its current PID, then use `ps` to confirm it is still alive. Send the
briefing's required final signal and check that it exits. Other learners may
receive an `INT` or `TERM` variant; follow the signal sequence in your own
briefing and preserve the other workers.

Plain `kill PID` sends `TERM`, so it skips a required HUP or INT test.
`kill -9 PID` sends `KILL`, which the worker cannot catch or handle for a
clean shutdown. Use it only when your briefing requires KILL after the first
signal test. `validate` returns a key even if you skipped a required step;
the external grader determines whether that key matches the expected state.

### Level 4: Pause and resume

Stop the assigned heartbeat worker and confirm its state begins with `T`.
Leave it stopped for at least two seconds so the observer records the state.
Continue it with `CONT`, then confirm it is alive and no longer stopped.

### Level 5: Foreground and background jobs

Use `jobs -l` in the same shell where you ran `startlevel`. Leave the first
named job stopped and the second running in the background. Job numbers may
change after a reset.

### Level 6: Control the resource hog

Use `top` to identify the CPU-heavy worker. Set its nice value to the number
in the briefing with `renice`; keep every worker alive.

### Level 7: Parent, child, and branch

Use PID and PPID to map the tree below the named parent. Terminate every
member of the assigned branch while preserving the other branch.

### Level 8: Pipeline and process group

Find the PGID shared by members of the target label. Send `TERM` to that
group as a unit and leave the protected group alive.

### Level 9: The zombie mystery

Find the process whose `STAT` begins with `Z`, then identify its parent from
PPID. Signal the parent as directed so it reaps the zombie. Keep the parent
and live sibling alive.

### Level 10: Process incident response

Combine the earlier skills: reprioritize the CPU worker, resume the stopped
worker, terminate the target group, handle the worker that ignores `TERM`, and
preserve the protected worker. Recheck the full process table after each step.

## Safety and troubleshooting

Act only on processes created for the current level. Avoid broad commands
such as `killall sh` or `pkill process-helper`. Never signal PID 1 or an
unrelated system process. Prefer `TERM` before `KILL` when the briefing calls
for escalation.

If the expected workers are absent from `ps`, run `startlevel`. If a PID
from your notes is missing, reset or level navigation may have replaced it;
inspect the current listing. If installation reports a helper smoke-test
failure, the image needs repair before the lab can run.

## Submitting work

The lab page does not yet have a configured answer form. Record the key printed
by `validate` for each level and retain it for your instructor. The terminal
does not issue a graded completion result.
