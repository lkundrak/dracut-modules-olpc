"""Pyrex binding for fast C implementation of rclone (cp -rl)"""
# To build:
# $ pyrexc cprl.pyx
# $ gcc -c -fPIC -I/usr/include/python2.5 cprl.c
# $ gcc -shared cprl.o -o cprl.so

cdef extern from "cprl.h":
    int cprl(char *src, char *dst)
cdef extern from "errno.h":
    int errno
cdef extern from "string.h":
    char *strerror(int errnum)
    
def clone (object src, object dst):
    """cp -rl src dst"""
    if 0 != cprl(src, dst):
        raise OSError, (errno, strerror(errno))
