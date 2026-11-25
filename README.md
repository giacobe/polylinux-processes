# PolyLinux Processes and Job Control

This package builds ten deterministic, live process-management exercises for
the PolyLinux Buildroot image. Each learner receives different themes, service
roles, process topology, distractors, and required values from the versioned
`seed-v1` contract in `polylinux-common.sh`.

Linux assigns PIDs and PGIDs when `startlevel` launches a fresh runtime. They
are deliberately not derived from the seed and may change after every reset.

## Live workflow

Each level begins with:

```sh
cat README.txt
startlevel
ps -ww -o pid,ppid,pgid,stat,ni,comm,args
```

The learner inspects and manipulates the real processes, then runs `validate`.
Level 1 takes the selected process's current PID:

```sh
validate PID
```

Levels 2 through 10 take no argument:

```sh
validate
```

`validate` prints a ten-character key for every observed state. It never
reports correct or incorrect. The external grader derives expected keys from
the seed; it is not included in the VM payload.

## Trust boundary

The key fingerprints the learner-controlled offline VM's observed state. It
is not a remote attestation or protection against deliberate client tampering.

## Installation

Place the repository files in root's home directory and run:

```sh
chmod +x install.sh level*.sh cleanlevel nextlevel prevlevel \
  validate monitor-level4.sh verify.sh
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
