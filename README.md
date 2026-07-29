# PolyLinux Processes and Job Control — Live-State Submission Edition

This package builds ten deterministic, live process-management exercises for
the PolyLinux Buildroot image. Each learner receives different themes, service
roles, process topology, distractors, and required values based on:

```text
SHA-256(email + ISO_date + exercise_password + level_password)
```

Linux assigns PIDs and PGIDs when `startlevel` launches a fresh runtime. They
are deliberately not derived from the seed and may change after every reset.

## Live workflow

Each level begins with:

```sh
cat README.txt
startlevel
ps -o pid,ppid,pgid,stat,ni,comm,args
```

The learner inspects and manipulates the real processes, then runs
`checklevel`. Once the requested live state is correct, `submit` captures a
canonical report from `/proc`, runtime events, and shutdown receipts.

The report includes:

- learner email and exercise date;
- level, scenario theme, and launch identifier;
- every registered process's PID, PPID, PGID, state, nice value, command, and
  launch-token match;
- signal events and graceful-shutdown receipts; and
- a SHA-256 digest over the exact report bytes.

The report is written to `~/submission-levelN.txt` and printed to the terminal.
Level 1 uses:

```sh
submit 'PID|PPID|STATE'
```

Levels 2 through 10 use:

```sh
submit
```

`verify-submission.sh` independently recomputes the digest, binds the report to
the generated learner/date case, and checks the level-specific state
requirements.

## Trust boundary

The SHA-256 detects alteration of a captured report. It does not turn a
learner-controlled offline VM into a trusted remote attestation device. A
server-side verifier can validate the report's structure and semantics, but
strong proof against a participant who rewrites the local client would require
an external signing service or hardware-backed secret.

## Installation

Place the repository files in root's home directory and run:

```sh
chmod +x install.sh level*.sh checklevel cleanlevel levelstatus nextlevel \
  prevlevel submit verify.sh verify-submission.sh
./install.sh
```

For non-interactive image builds:

```sh
USER_ID=student@example.edu CURRENT_DATE=2026-07-23 \
SYSTEM_PASSWORD=exercisePassword ./install.sh --non-interactive --no-login
```

The prebuilt target-architecture `process-helper` is installed at
`/usr/lib/process-lab/process-helper`.

## Runtime safety

All exercise processes are disposable and owned by the current level account.
CPU activity is bounded to one helper, identities carry a level-specific launch
token, and cleanup uses the recorded process roster. No real system service is
targeted.

