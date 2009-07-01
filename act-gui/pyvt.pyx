# Python bindings for virtual terminal (vt) ioctls.

from fcntl import ioctl
import os

cdef extern from "linux/vt.h":
    enum:
        VT_GETMODE,
        VT_SETMODE,
        _VT_AUTO "VT_AUTO",
        _VT_PROCESS "VT_PROCESS",
        VT_RELDISP,
        _VT_ACKACQ "VT_ACKACQ",
        VT_ACTIVATE,
        VT_WAITACTIVE,
        VT_GETSTATE
    struct vt_mode:
        int mode
        int waitv
        int relsig
        int acqsig
        int frsig
cdef extern from "sys/ioctl.h":
    int c_ioctl "ioctl" (int fd, int req, void *)
    enum:
        TIOCCONS

def chcon(tty):
    """Change the linux console to the given TTY."""
    try:
        fd = os.open(tty, os.O_RDWR)
        ioctl(fd, TIOCCONS)
        os.close(fd)
    except:
        pass

def chvt(n):
    """Change to the given virtual console."""
    # this does the same thing as the command 'chvt n'
    # but w/o requiring that we pull in a separate binary
    fd = os.open('/dev/console', os.O_RDWR)
    ioctl(fd, VT_ACTIVATE, n)
    ioctl(fd, VT_WAITACTIVE, n)
    os.close(fd)

def vt_getmode(tty):
    """Get the mode information for the given TTY."""
    cdef vt_mode mode
    fd = os.open(tty, os.O_RDWR)
    try:
        st = c_ioctl(fd, VT_GETMODE, &mode)
        if st != 0: raise OSError, "VT_GETMODE failed"
        return { 'mode': mode.mode, 'waitv': mode.waitv, 'relsig': mode.relsig,
                 'acqsig': mode.acqsig, 'frsig': mode.frsig }
    finally:
        os.close(fd)

def vt_setmode(tty, **mode):
    """Set the mode information for the given TTY."""
    cdef vt_mode c_mode
    fd = os.open(tty, os.O_RDWR)
    try:
        st = c_ioctl(fd, VT_GETMODE, &c_mode)
        if st != 0: raise OSError, "VT_GETMODE failed"
        if 'mode' in mode: c_mode.mode = mode['mode']
        if 'waitv' in mode: c_mode.waitv = mode['waitv']
        if 'relsig' in mode: c_mode.relsig = mode['relsig']
        if 'acqsig' in mode: c_mode.acqsig = mode['acqsig']
        if 'frsig' in mode: c_mode.frsig = mode['frsig']
        st = c_ioctl(fd, VT_SETMODE, &c_mode)
        if st != 0: raise OSError, "VT_SETMODE failed"
    finally:
        os.close(fd)

VT_AUTO = _VT_AUTO
VT_PROCESS = _VT_PROCESS
VT_ACKACQ = _VT_ACKACQ

def vt_reldisp(tty, n):
    """Release the vt for a switch."""
    fd = os.open(tty, os.O_RDWR)
    try:
        st = ioctl(fd, VT_RELDISP, n)
        if st != 0: raise OSError, "VT_RELDISP failed"
    finally:
        os.close(fd)
