#ifndef CLAUNCHRIGHTS_SESSION_H
#define CLAUNCHRIGHTS_SESSION_H

#include <sys/types.h>

/// Spawn `path` with `argv` (a NULL-terminated argument vector), optionally
/// dropping from the (root) caller to another user, and optionally joining a
/// login session so a GUI app reaches that session's WindowServer.
///
/// `asid`        > 0: join that audit session before exec (done while still root,
///               so it's permitted). <= 0: skip — child inherits the caller's
///               session (correct for an interactive dev run inside the GUI).
///
/// `run_as_user` NULL or "": stay as the caller (root) — the original behavior.
///               Otherwise the child drops to this user (initgroups + setgid +
///               setuid) and runs with HOME/USER/LOGNAME set for them.
///
/// IMPORTANT: a GUI app launched as a NON-root user generally cannot connect to
/// the console user's WindowServer (macOS restricts GUI to the session owner or
/// root), so it will run but show no window. Use `run_as_user` for command-line
/// / admin tasks; keep root for GUI apps. Session-join does NOT lift this.
///
/// Returns the child pid on success, or -1 on a pre-fork/fork failure with
/// *out_err set to a POSIX errno. Failures that can only occur in the child
/// (a setgid/setuid/initgroups/exec failure) surface as the child exiting with a
/// distinct status: 126 = privilege drop failed, 127 = exec failed.
pid_t lr_spawn_elevated(const char *path,
                        char *const argv[],
                        int asid,
                        const char *run_as_user,
                        int *out_err);

#endif /* CLAUNCHRIGHTS_SESSION_H */
