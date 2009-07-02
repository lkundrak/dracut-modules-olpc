#!/usr/bin/python2.5
## Add an '-i' to the #! line to enable the interactive shell.
## Remove the -i for deployment, to ensure that an
## error in the script doesn't land us in an interactive shell.

from __future__ import with_statement
from os.path import exists, join, isdir, splitext
from os import fork, _exit, waitpid, setuid, setgid, chmod, umask, walk, system
from time import sleep
from traceback import print_exc as trace

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
        lout(['/bin/mkdir', '-p', v])

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

def main():
    print "Hello, (deployment people of the) world!"

    try:
        # unfreeze dcon if it is frozen.
        open('/sys/devices/platform/dcon/freeze','w').write('0')
    except:
        pass

    # Let the USB stack win the race...
    sleep(5)

    # This next chunk needs some serious generalization.
    # FIXME: detect XO version from OFW? or DMI?
    mntopts = ""
    if os.path.exists("/dev/mtdblock0"):
        mntopts = "-o rw -t jffs2 /dev/mtdblock0"
    else:
        # XO-1.5? FIXME
        mntopts = "-o rw /dev/hda1"

    with Mounted(path='/mnt/usb', opts='-t vfat -o ro /dev/sda1'):
        check_bundles_dir()
        with Mounted(path='/sysroot', mntopts):
            check_adequate_version()
            chmod('/sysroot', 0777)
            chmod('/dev/null', 0777)

            do_in_child(unpack_bundles)

    print 'Bundle installation complete; powering off in five seconds.'
    sleep(5)
    system("poweroff -f")
    return

if __name__ == '__main__': main()
