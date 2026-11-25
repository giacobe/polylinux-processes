#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#ifdef __linux__
#include <sys/prctl.h>
#endif

static const char *run_dir;
static const char *role;
static volatile sig_atomic_t running = 1;
static volatile sig_atomic_t reap_now = 0;
static int graceful = 0;
static const char *receipt_name = "receipt";

static void append_file(const char *name, const char *fmt, ...) {
    char path[512], line[512];
    va_list ap;
    int fd, n;
    snprintf(path, sizeof(path), "%s/%s", run_dir, name);
    va_start(ap, fmt);
    n = vsnprintf(line, sizeof(line), fmt, ap);
    va_end(ap);
    fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd >= 0) {
        if (n > 0) {
            ssize_t written = write(fd, line, (size_t)n);
            (void)written;
        }
        close(fd);
    }
}

static void identify(const char *label) {
    char name[16];
    snprintf(name, sizeof(name), "%.15s", label);
#ifdef __linux__
    (void)prctl(PR_SET_NAME, name, 0, 0, 0);
#endif
    append_file("registry", "%s %ld %ld %ld\n", label, (long)getpid(),
                (long)getppid(), (long)getpgrp());
}

static void on_term(int sig) {
    append_file("events", "%s %ld signal=%d\n", role, (long)getpid(), sig);
    if (graceful) append_file(receipt_name, "role=%s pid=%ld signal=%d clean=yes\n",
                              role, (long)getpid(), sig);
    running = 0;
}
static void on_cont(int sig) {
    (void)sig;
    append_file("events", "%s %ld signal=CONT\n", role, (long)getpid());
}
static void on_ignored(int sig) {
    append_file("events", "%s %ld ignored=%d\n", role, (long)getpid(), sig);
}
static void on_reap(int sig) { (void)sig; reap_now = 1; }

static void install_handler(int sig, void (*fn)(int)) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = fn;
    sigemptyset(&sa.sa_mask);
    sigaction(sig, &sa, NULL);
}

static void worker_loop(const char *mode, int interval) {
    struct timespec nap = {0, 250000000L};
    unsigned long spin = 0;
    time_t next_beat = 0;
    if (!strcmp(mode, "graceful")) graceful = 1;
    install_handler(SIGTERM, on_term);
    install_handler(SIGINT, on_term);
    install_handler(SIGHUP, on_term);
    install_handler(SIGCONT, on_cont);
    if (!strcmp(mode, "ignore-term")) install_handler(SIGTERM, on_ignored);
    if (!strcmp(mode, "ignore-int")) install_handler(SIGINT, on_ignored);
    if (!strcmp(mode, "ignore-hup")) install_handler(SIGHUP, on_ignored);

    while (running) {
        if (!strcmp(mode, "cpu")) {
            unsigned long i;
            for (i = 0; i < 5000000UL; i++) spin = spin * 33UL + i;
            if ((spin & 7UL) == 0) nanosleep(&nap, NULL);
        } else {
            time_t now = time(NULL);
            if (!strcmp(mode, "heartbeat") && now >= next_beat) {
                append_file("heartbeat", "%s %ld %ld\n", role, (long)getpid(), (long)now);
                next_beat = now + interval;
            }
            nanosleep(&nap, NULL);
        }
    }
}

static void leaf(const char *label) {
    role = label;
    identify(label);
    worker_loop("normal", 1);
    _exit(0);
}

static int tree_mode(int argc, char **argv) {
    int children, branch, i;
    const char *parent, *target, *protect;
    if (argc < 8) return 2;
    run_dir = argv[2]; parent = argv[3]; target = argv[4];
    protect = argv[5]; children = atoi(argv[6]);
    role = parent; identify(parent);
    signal(SIGCHLD, SIG_IGN);
    for (branch = 0; branch < 2; branch++) {
        const char *branch_name = branch == 0 ? target : protect;
        pid_t p = fork();
        if (p == 0) {
            role = branch_name; identify(branch_name);
            for (i = 0; i < children; i++) {
                p = fork();
                if (p == 0) {
                    char child[96];
                    snprintf(child, sizeof(child), "%s-child%d", branch_name, i + 1);
                    leaf(child);
                }
            }
            worker_loop("normal", 1);
            _exit(0);
        }
    }
    worker_loop("normal", 1);
    return 0;
}

static void group_child(const char *label, int index, pid_t pgid) {
    char member[96];
    if (pgid == 0) pgid = getpid();
    (void)setpgid(0, pgid);
    snprintf(member, sizeof(member), "%s-member%d", label, index);
    leaf(member);
}

static int groups_mode(int argc, char **argv) {
    int stages, g, i;
    const char *labels[2];
    if (argc < 7) return 2;
    run_dir = argv[2]; labels[0] = argv[3]; labels[1] = argv[4];
    stages = atoi(argv[5]);
    role = "group-supervisor"; identify(role);
    signal(SIGCHLD, SIG_IGN);
    for (g = 0; g < 2; g++) {
        pid_t leader = 0;
        for (i = 1; i <= stages; i++) {
            pid_t p = fork();
            if (p == 0) group_child(labels[g], i, leader);
            if (leader == 0) leader = p;
            (void)setpgid(p, leader);
        }
    }
    worker_loop("normal", 1);
    return 0;
}

static int zombie_mode(int argc, char **argv) {
    pid_t child, sibling;
    int status;
    const char *parent, *zombie;
    int control;
    if (argc < 7) return 2;
    run_dir = argv[2]; parent = argv[3]; zombie = argv[4];
    control = !strcmp(argv[5], "USR1") ? SIGUSR1 : SIGCONT;
    role = parent; identify(parent);
    child = fork();
    if (child == 0) {
        role = zombie; identify(zombie);
        _exit(0);
    }
    sibling = fork();
    if (sibling == 0) leaf("live-sibling");
    install_handler(control, on_reap);
    install_handler(SIGTERM, on_term);
    while (running) {
        if (reap_now) {
            if (waitpid(child, &status, 0) == child)
                append_file("events", "%s reaped=%ld\n", parent, (long)child);
            reap_now = 0;
        }
        sleep(1);
    }
    kill(sibling, SIGTERM);
    waitpid(sibling, NULL, 0);
    return 0;
}

int main(int argc, char **argv) {
    const char *mode;
    char hidden_mode[32];
    int interval = 1;
    if (argc < 2) return 2;
    if (!strcmp(argv[1], "tree")) return tree_mode(argc, argv);
    if (!strcmp(argv[1], "groups")) return groups_mode(argc, argv);
    if (!strcmp(argv[1], "zombie")) return zombie_mode(argc, argv);
    if (argc < 6 || strcmp(argv[1], "worker")) return 2;
    run_dir = argv[2]; role = argv[3]; mode = argv[5];
    if (!strcmp(mode, "-")) {
        if (!fgets(hidden_mode, sizeof(hidden_mode), stdin)) return 2;
        hidden_mode[strcspn(hidden_mode, "\r\n")] = '\0';
        if (strcmp(hidden_mode, "normal") && strcmp(hidden_mode, "cpu") &&
            strcmp(hidden_mode, "ignore-term") && strcmp(hidden_mode, "ignore-int") &&
            strcmp(hidden_mode, "ignore-hup")) return 2;
        mode = hidden_mode;
        fclose(stdin);
    }
    if (argc > 6) interval = atoi(argv[6]);
    if (argc > 7) receipt_name = argv[7];
    identify(role);
    worker_loop(mode, interval);
    return 0;
}
