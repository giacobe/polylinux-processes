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
`the external answer form`. Once the requested live state is correct, `submit` captures a
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
chmod +x install.sh level*.sh the external answer form cleanlevel levelstatus nextlevel \
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

## Build the browser VM

This lab uses the `basic-processes` configuration from
[`giacobe/buildroot-builder2`](https://github.com/giacobe/buildroot-builder2),
validated with Buildroot `2025.02.15`:

```sh
git clone https://github.com/giacobe/buildroot-builder2.git
cd buildroot-builder2
BUILDROOT_VERSION=2025.02.15 scripts/01-setup-buildroot.sh
scripts/02-build-baseline.sh --config basic-processes
scripts/03-package-payload.sh \
  --repo https://github.com/giacobe/polylinux-processes.git \
  --ref main \
  --baseline artifacts/basic-processes-<timestamp> \
  --output artifacts/polylinux-processes \
  --output-prefix polylinux-processes
```

Replace `<timestamp>` with the stage-2 artifact directory. In addition to the
manifest check, verify the `ps`, `top`, `nice`, and `renice` behavior described
in `TOOLSET.md`, then boot-test the exact generated image pair in v86.


## Standard runtime contract

The current release uses the reversible PolyBandit exercise code, the versioned `seed-v1` deterministic seed, ten concurrent level generators, staged `README.txt` readiness, unrestricted `nextlevel`/`prevlevel` navigation, and no client-side answer store or checker. See `lab.json` for the authoritative level count, theme policy, Buildroot configuration, and browser artifact names.

Do not rebuild the assigned Buildroot baseline merely to package this lab. Package the repository payload into the configuration named by `buildroot_configuration`, preserve the baseline kernel, and publish the resulting `packaged.bzImage` and `packaged.rootfs.cpio.gz`.
