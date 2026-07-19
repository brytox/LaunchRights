// idprobe — a headless test app for LaunchRights. It writes the identity it is
// running under to /tmp/launchrights-idprobe.log and exits. No GUI, so it proves
// a `runAs` privilege drop without fighting the WindowServer limitation that
// makes real GUI apps exit when launched as a non-root user.
//
// It MUST be a compiled Mach-O (not a shell script): the ES daemon matches on
// the exec'd image's signing id, and a script would exec the interpreter (whose
// signing id is Apple's), never matching our allowlist entry.

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pwd.h>
#include <fcntl.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>

#define LOG_PATH "/tmp/launchrights-idprobe.log"

int main(void) {
    // 0666 + fchmod so whichever user runs first doesn't lock others out.
    int fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (fd < 0) { return 1; }
    fchmod(fd, 0666);
    FILE *f = fdopen(fd, "a");
    if (!f) { return 1; }

    uid_t ruid = getuid(), euid = geteuid();
    gid_t rgid = getgid(), egid = getegid();
    struct passwd *pw = getpwuid(euid);
    const char *name = pw ? pw->pw_name : "?";
    const char *home = getenv("HOME");
    const char *user = getenv("USER");

    time_t now = time(NULL);
    struct tm tm;
    char ts[32];
    localtime_r(&now, &tm);
    strftime(ts, sizeof ts, "%Y-%m-%d %H:%M:%S", &tm);

    fprintf(f, "[%s] idprobe pid=%d ruid=%u euid=%u(%s) rgid=%u egid=%u HOME=%s USER=%s",
            ts, getpid(), ruid, euid, name, rgid, egid,
            home ? home : "(unset)", user ? user : "(unset)");

    // Supplementary groups — is it in admin (gid 80)?
    int ng = getgroups(0, NULL);
    if (ng > 0) {
        gid_t *gs = calloc((size_t)ng, sizeof(gid_t));
        if (gs && getgroups(ng, gs) == ng) {
            fprintf(f, " groups=");
            int in_admin = 0;
            for (int i = 0; i < ng; i++) {
                fprintf(f, "%s%u", i ? "," : "", gs[i]);
                if (gs[i] == 80) { in_admin = 1; }
            }
            fprintf(f, " admin=%s", in_admin ? "YES" : "no");
        }
        free(gs);
    }
    fprintf(f, "\n");
    fclose(f);
    return 0;
}
