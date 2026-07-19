#include "CLaunchRightsSession.h"

#include <bsm/audit.h>
#include <bsm/audit_session.h>
#include <mach/mach.h>
#include <unistd.h>
#include <errno.h>
#include <pwd.h>
#include <grp.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

extern char **environ;

static void free_environ(char **envp) {
    if (!envp) { return; }
    for (char **e = envp; *e; e++) { free(*e); }
    free(envp);
}

// Build a NULL-terminated environment for `pw`: a strdup'd copy of `environ`
// with HOME/USER/LOGNAME overridden. Every entry is heap-allocated so the whole
// thing can be freed uniformly with free_environ(). Built in the parent before
// fork (getpwnam/malloc are not safe in the child); the child only reads it.
// Returns NULL on allocation failure.
static char **build_user_environ(const struct passwd *pw) {
    size_t n = 0;
    for (char **e = environ; *e; e++) { n++; }

    char **envp = calloc(n + 4, sizeof(char *));   // kept vars + HOME/USER/LOGNAME + NULL
    if (!envp) { return NULL; }

    size_t out = 0;
    for (char **e = environ; *e; e++) {
        if (strncmp(*e, "HOME=", 5) == 0) { continue; }
        if (strncmp(*e, "USER=", 5) == 0) { continue; }
        if (strncmp(*e, "LOGNAME=", 8) == 0) { continue; }
        if (!(envp[out] = strdup(*e))) { free_environ(envp); return NULL; }
        out++;
    }

    if (asprintf(&envp[out], "HOME=%s", pw->pw_dir) < 0)     { free_environ(envp); return NULL; }
    out++;
    if (asprintf(&envp[out], "USER=%s", pw->pw_name) < 0)    { free_environ(envp); return NULL; }
    out++;
    if (asprintf(&envp[out], "LOGNAME=%s", pw->pw_name) < 0) { free_environ(envp); return NULL; }
    out++;
    envp[out] = NULL;
    return envp;
}

pid_t lr_spawn_elevated(const char *path,
                        char *const argv[],
                        int asid,
                        const char *run_as_user,
                        int *out_err) {
    if (out_err) { *out_err = 0; }

    // Resolve the target user (if any) BEFORE forking — getpwnam is not
    // async-signal-safe, so it must not run in the child.
    int drop_privs = (run_as_user && run_as_user[0] != '\0'
                      && strcmp(run_as_user, "root") != 0);

    uid_t target_uid = 0;
    gid_t target_gid = 0;
    char *namebuf = NULL;       // strdup'd username for initgroups() in the child
    char **child_env = environ; // default: inherit the daemon's environment (root case)

    if (drop_privs) {
        struct passwd *pw = getpwnam(run_as_user);
        if (!pw) { if (out_err) { *out_err = EINVAL; } return -1; }
        target_uid = pw->pw_uid;
        target_gid = pw->pw_gid;
        namebuf = strdup(pw->pw_name);
        child_env = build_user_environ(pw);   // may reference pw; done before any other getpw call
        if (!namebuf || !child_env) {
            if (out_err) { *out_err = ENOMEM; }
            free(namebuf);
            if (child_env && child_env != environ) { free_environ(child_env); }
            return -1;
        }
    }

    // Acquire a send right to the target session's port BEFORE forking, so the
    // child inherits the port name and can join. Best-effort.
    mach_port_name_t session_port = MACH_PORT_NULL;
    int have_session = 0;
    if (asid > 0 && audit_session_port((au_asid_t)asid, &session_port) == 0) {
        have_session = 1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        if (out_err) { *out_err = errno; }
        if (have_session) { mach_port_deallocate(mach_task_self(), session_port); }
        free(namebuf);
        if (child_env != environ) { free_environ(child_env); }
        return -1;
    }

    if (pid == 0) {
        // CHILD: async-signal-safe work only until exec.
        // 1) Join the login session WHILE STILL ROOT (a non-root join is denied).
        if (have_session) { audit_session_join(session_port); }
        // 2) Drop privileges, if requested. Order matters: supplementary groups
        //    and gid must be set before the setuid that gives up the power to.
        if (drop_privs) {
            if (initgroups(namebuf, (int)target_gid) != 0) { _exit(126); }
            if (setgid(target_gid) != 0) { _exit(126); }
            if (setuid(target_uid) != 0) { _exit(126); }
        }
        // 3) Exec with the (possibly user-specific) environment.
        execve(path, argv, child_env);
        _exit(127);   // exec failed
    }

    // PARENT: the child holds its own inherited copies (port name / heap).
    if (have_session) { mach_port_deallocate(mach_task_self(), session_port); }
    free(namebuf);
    if (child_env != environ) { free_environ(child_env); }
    return pid;
}
