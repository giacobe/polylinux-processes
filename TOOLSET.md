# Buildroot command requirements

Installation and generation require:

```text
adduser awk basename cat chmod chown cp cut date grep head id kill ln mkdir
mv nice passwd ps renice rm sed sha256sum sleep su tail tr wc
```

Learners use:

```text
ps top jobs fg bg kill nice renice grep awk tail
```

The `ps` implementation must support:

```text
ps -o pid,ppid,pgid,stat,ni,comm,args
ps -o stat= -p PID
ps -o ni= -p PID
```

BusyBox builds should enable job control in `ash`, `top`, `renice`, and the
extended `ps` column support. Supply a target-architecture `process-helper`
binary beside `install.sh`, or make a C compiler available and set `CC` if
needed.
