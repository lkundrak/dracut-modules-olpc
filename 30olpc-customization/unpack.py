#!/usr/bin/python
## Add an '-i' to the #! line to enable the interactive shell.
## Remove the -i for deployment, to ensure that an
## error in the script doesn't land us in an interactive shell.

from __future__ import with_statement
from os.path import exists, join, isdir, splitext
from os import fork, _exit, waitpid, setuid, setgid, chmod, umask, walk, system
import os
import stat
from time import sleep
from traceback import print_exc as trace
from subprocess import check_call, call

from process import lout, tokenize

class Mounted(object):
    def __init__(self, path, opts):
        self.path = path
        self.opts = opts

    def __enter__(self):
        if not self.opts: self.opts = []
        lout(['/bin/mount'] + tokenize(self.opts) + [self.path])

    def __exit__(self, type, value, traceback):
        lout(['/bin/umount', self.path])
        return True

def do_in_child(work):
    pid = fork()
    if not pid:
        status = 0
        try: work()
        except:
            status = 1
            trace()
        finally: _exit(status)
    else:
        pid, status = waitpid(pid, 0)
        if status:
            raise RuntimeError('Child process failed.')

def unpack_bundles():
    tgt = {}
    tgt['.xol'] = '/sysroot/home/olpc/Library'
    tgt['.xo']  = '/sysroot/home/olpc/Activities'
    tgt['.pb']  = '/sysroot/home/olpc/.bootanim'

    setgid(500)
    setuid(500)
    umask(0022)

    for k,v in tgt.iteritems():
        if not exists(v):
            os.makedirs(v)

    open('/sysroot/home/olpc/.usb-customizations', 'w').write('1')

    print '_: skipped; +: success; !: failure'
    for (r, ds, fs) in walk('/mnt/usb/bundles'):
        for f in fs:
            ext = splitext(f.lower())[1]
            if ext in ('.xol', '.xo', '.pb'):
                try:    lout(['/usr/bin/unzip', '-o', '-qq', join(r,f), '-d', tgt[ext]])
                except: print '! ' + f
                else:   print '+ ' + f
            else:
                print '_ ' + f

def check_bundles_dir():
    assert exists('/mnt/usb/bundles') and isdir('/mnt/usb/bundles')

def check_adequate_version():
    version_file = '/sysroot/.content-irfs-adequate-version'
    if exists(version_file):
        assert int(open(version_file, 'r').read(10)) < 1

def get_xo_version():
    name = open('/sys/class/dmi/id/product_name', 'r').read().strip()
    version = open('/sys/class/dmi/id/product_version', 'r').read().strip()

    if name != "XO":
        raise Exception("Not an XO laptop?")
    if version == "1":
        return "1"
    elif version == "1.5":
        return "1.5"
    else:
        raise Exception("Unrecognised version number: %s" % version)

def mknod(dev, maj, min):
    if not exists(dev):
        os.mknod(dev, stat.S_IFCHR | 0700, os.makedev(maj, min))

def setup_sysmounts():
    open("/etc/fstab", "w").close() # create empty file
    mknod("/dev/null", 1, 3)
    check_call(['/bin/mount', '-t', 'proc', '/proc', '/proc'])
    check_call(['/bin/mount', '-t', 'sysfs', '/sys', '/sys'])
    check_call(['/bin/mount', '-t', 'tmpfs', '-omode=0755', 'udev', '/dev'])
    mknod("/dev/null", 1, 3)
    mknod("/dev/ptmx", 5, 2)
    mknod("/dev/console", 5, 1)
    mknod("/dev/kmsg", 1, 11)

def run_udev():
    check_call(['/sbin/udevd', '--daemon'])
    check_call(['/sbin/udevadm', 'trigger'])
    check_call(['/sbin/udevadm', 'settle', '--timeout=30'])

def main():
    print "Hello, (deployment people of the) world!"

    setup_sysmounts()

    try:
        # unfreeze dcon if it is frozen.
        open('/sys/devices/platform/dcon/freeze','w').write('0')
    except:
        pass

    run_udev()

    # Let the USB stack win the race...
    sleep(5)

    mntopts = ""
    xo_ver = get_xo_version()
    print "Detected XO-%s" % xo_ver
    if xo_ver == "1":
        mntopts = "-o rw -t jffs2 mtd0"
    elif xo_ver == "1.5":
        if exists("/dev/disk/mmc/mmc2p2"):
            # XO-1.5 B3 and newer has internal disk here
            # (mmc2 is wifi on earlier models, we'll never see a disk here)
            mntopts = "-o rw /dev/disk/mmc/mmc2p2"
        else:
            # XO-1.5 B2 and older has internal disk here
            # XO-1.5 B3 and newer has external SD card here
            mntopts = "-o rw /dev/disk/mmc/mmc0p2"

    with Mounted(path='/mnt/usb', opts='-t vfat -o ro /dev/sda1'):
        check_bundles_dir()
        with Mounted(path='/sysroot', opts=mntopts):
            check_adequate_version()
            chmod('/sysroot', 0777)
            chmod('/dev/null', 0777)

            do_in_child(unpack_bundles)

    print 'Bundle installation complete; powering off in five seconds.'
    sleep(5)
    call(["/sbin/poweroff", "-f"])
    return

if __name__ == '__main__': main()
