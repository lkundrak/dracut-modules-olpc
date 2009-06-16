/* for *at functions */
#ifndef _ATFILE_SOURCE
# define _ATFILE_SOURCE
#endif
/* for O_DIRECTORY, O_NOFOLLOW, O_NOATIME */
#ifndef _GNU_SOURCE
# define _GNU_SOURCE
#endif
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>

#define CWDMAX 512
#define LINKMAX 512

#define OPEN_FLAGS O_RDONLY|O_NOATIME|O_NOFOLLOW

/* CWD is src, dfd is file descriptor of destination. */

typedef typeof(&alphasort) scandir_sort_t;
static int simplesort(const struct dirent ** a, const struct dirent ** b) {
    /* i'd just return '1' here if I thought I could get away with it */
    return strcmp((*a)->d_name, (*b)->d_name);
}

static int transfer_perms(int fd, struct stat *stat) {
    struct timeval tv[2];
#define ATIME 0
#define MTIME 1
    int st;
    /* mode */
    st = fchmod(fd, stat->st_mode);
    if (st) return errno;
    /* times */
    tv[ATIME].tv_usec = tv[MTIME].tv_usec = 0; /* suck */
    tv[ATIME].tv_sec = stat->st_atime;
    tv[MTIME].tv_sec = stat->st_mtime;
    st = futimes(fd, tv);
    if (st) return errno;
    /* owner, group */
    st = fchown(fd, stat->st_uid, stat->st_gid);
    if (st) return errno; /* XXX should be silent failure here? */
    /* done */
    return 0;
}

static int transfer_symlink_perms(int dfd, char *name, struct stat *stat) {
    /* only owner and group are relevant for symlinks */
    int st;
    st = fchownat(dfd, name, stat->st_uid, stat->st_gid, AT_SYMLINK_NOFOLLOW);
    if (st) return errno; /* XXX should be silent failure here? */
    return 0;
}

static int clonedir(int dfd) {
    struct dirent **namelist;
    struct stat stat;
    int n, st;

    n = scandir(".", &namelist, NULL, (scandir_sort_t) simplesort);
    if (n < 0) return errno;
    while (n--) {
	char *name = namelist[n]->d_name;
	/* skip . and .. */
	if (strcmp(name, ".")==0 ||
	    strcmp(name, "..")==0)
	    continue;
	/* get the stat of this entry. */
	st = fstatat(AT_FDCWD, name, &stat, AT_SYMLINK_NOFOLLOW);
	if (st) return errno; /* bail, leaking memory. */
	/* is this a directory? */
	if (S_ISDIR(stat.st_mode)) {
	    int ndfd;
	    /* make the directory. */
	    mkdirat(dfd, name, 0777);
	    /* recurse! */
	    ndfd = openat(dfd, name, O_DIRECTORY|OPEN_FLAGS);
	    if (ndfd < 0) return errno;
	    st = chdir(name); /* XXX may fail if doesn't have x perms */
	    if (st) return errno;
	    st = clonedir(ndfd);
	    if (st) return st;
	    st = chdir("..");
	    if (st) return errno;
	    /* set permissions */
	    st = transfer_perms(ndfd, &stat);
	    if (st) return errno;
	    close(ndfd);
	} else if (S_ISLNK(stat.st_mode)) {
	    /* symlink: recreate at dest */
	    char contents[LINKMAX];
	    ssize_t size;
	    size = readlink(name, contents, sizeof(contents));
	    if (st < 0) return errno;
	    if (size >= sizeof(contents))
		return ENAMETOOLONG; /* link contents didn't fit */
	    contents[size] = '\0'; /* null-terminate the contents */
	    /* recreate symlink */
	    st = symlinkat(contents, dfd, name);
	    if (st) return errno;
	    /* set permissions */
	    st = transfer_symlink_perms(dfd, name, &stat);
	    if (st) return errno;
	} else {
	    /* other file type: hard link */
	    st = linkat(AT_FDCWD, name, dfd, name, 0);
	    if (st) return errno;
	    /* no need to set permissions on hard linked files. */
	}
	/* free this entry. */
	free(namelist[n]);
    }
    free(namelist);
    return 0; /* success */
}

int cprl(char *src, char *dst) {
    /* cwd is set to src; dst gets openfd for new dir */
    struct stat stat;
    int srcfd, dstfd, cwdfd;
    int st;

    cwdfd = open(".", O_DIRECTORY|OPEN_FLAGS);
    if (cwdfd < 0) return errno;
    srcfd = open(src, O_DIRECTORY|OPEN_FLAGS);
    if (srcfd < 0) return errno;
    st = fstat(srcfd, &stat);
    if (st) return errno;
    st = mkdir(dst, 0777);
    if (st) return errno;
    dstfd = open(dst, O_DIRECTORY|OPEN_FLAGS);
    if (dstfd < 0) return errno;

    st = fchdir(srcfd); /* XXX may fail if srcfd doesn't have x perms */
    if (st) return errno;
    close(srcfd);
    st = clonedir(dstfd);
    if (st) return errno;
    st = transfer_perms(dstfd, &stat);
    if (st) return errno;
    close(dstfd);

    fchdir(cwdfd);
    close(cwdfd);
    return 0;
}

#ifdef WITH_MAIN
int main(int argc, char **argv) {
    int st;
    if (argc < 3) {
	printf("Usage: %s [src dir] [dst dir]\n", argv[0]);
	exit(1);
    }
    st = cprl(argv[1], argv[2]);
    if (st) { perror("clone failed"); exit(2); }
    return 0;
}
#endif
