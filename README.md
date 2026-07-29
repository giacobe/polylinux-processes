# PolyLinux Processes and Job Control — Evidence-Graded Edition

This package builds ten deterministic, live process-management exercises for
the PolyLinux Buildroot image. Each student receives different themes, process
roles, tokens, topology, distractors, filenames, and required values based on:

```text
SHA-256(email + ISO_date + exercise_password + level_password)
```

PIDs are deliberately not seeded. `startlevel` launches a fresh runtime from
the deterministic case specification, and `checklevel` validates the resulting
live state.

Each level also creates a learner-visible evidence artifact and a stable
semantic answer. The evidence answer excludes live PIDs and PGIDs, can be
recovered independently by `verify.sh`, and can be reproduced by the Microsoft
365 grader from the same seed. Canonical answers are stored root-only under
`/var/lib/process-lab/answers`.

## Installation

Place all repository files in root's home directory on the image, then run:

```sh
chmod +x install.sh level*.sh checklevel cleanlevel levelstatus nextlevel prevlevel
./install.sh
```

For non-interactive image builds:

```sh
USER_ID=student@example.edu CURRENT_DATE=2026-07-23 \
SYSTEM_PASSWORD=exercisePassword ./install.sh --non-interactive --no-login
```

The installer uses a prebuilt `./process-helper` when one is supplied.
Otherwise it compiles `process-helper.c` with `${CC:-cc}`. This supports both a
Buildroot cross-compiled artifact and installation on a development image. The
result is installed at `/usr/lib/process-lab/process-helper`; learners do not
need a compiler.

## Learner workflow

Each level begins in `/home/levelN`:

```sh
cat README.txt
startlevel
ps
checklevel
```

`startlevel` can be run again to cleanly reset a case. `nextlevel` and
`prevlevel` clean up the current runtime before switching accounts.

## Runtime safety

All exercise processes are disposable and owned by the current level account.
CPU activity is bounded to a single helper, all identities carry a
level-specific token, and cleanup uses the recorded process registry. No real
system service is targeted.

See `LEVELS.md` for the live and evidence-grading contracts,
`participant-guide.md` for the browser instructions, and `TOOLSET.md` for image
requirements.
