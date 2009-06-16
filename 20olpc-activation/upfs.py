#!/usr/bin/env python
# Copyright (C) 2009 One Laptop per Child
# Licensed under the GPLv2
#

import os
import sys
from subprocess import call
from os.path import join
import traceback
from cprl import clone

debug = False

def log(msg, *args):
    if len(args) > 0:
        print msg % tuple(args)
    else:
        print msg

    if debug:
        x = raw_input('[y],n: ')
        if x.startswith('n'):
            os.abort()
        
def setup_tree(root, x):
    """Legacy algorithm for constructing tree $x's image in
    $root/versions/pristine/$x."""
    log("Setting up tree `%s'.", x)

    log("Make sure our target exists.")
    os.makedirs(join(root, 'versions', 'pristine', x), 0755)
    
    log("Make a linked copy of / in /versions/pristine/%s", x)
    for frag in os.listdir(root):
        src = join(root, frag)
        dst = join(root, 'versions', 'pristine', x, frag)
        if frag in [ 'versions', 'lost+found', 'security']:
            pass # skip these
        elif os.path.islink(src):
            os.symlink(os.readlink(src), dst)
        elif os.path.isdir(src):
            clone(src, dst)
        elif os.path.isfile(src):
            os.link(src, dst)

    log("Remove things that should be externally mounted or unavailable.")
    for frag in ['versions', 'home', 'security']:
        if os.path.lexists(join(root, 'versions', 'pristine', x, frag)):
            call(['rm', '-rf', join(root, 'versions', 'pristine', x, frag)])
        os.mkdir(join(root, 'versions', 'pristine', x, frag))

    log('Tree set up.')


class Tree(object):
    """
    A tree's `mode' is one of [`frozen', `thawed'].
    * In `frozen' mode, the tree will be mostly read-only (i.e. P_SF_RUN is
      engaged.)
    * In `thawed' mode, the tree will use copy-on-write semantics (i.e.
      P_SF_RUN is disengaged.)
    """
    def __init__(self, name, mode):
        self.name = name
        self.mode = mode 

    def install(self, root='/'):
        """Installs the tree `x' with the mode specified in `x.mode'."""
        log("Installing tree `%s' with mode `%s'.", self.name, self.mode)
        getattr(self, self.mode, self.unknown_mode)(root)
        log('Installed.')

    def unknown_mode(self, root):
        raise RuntimeError, "Tree cannot be installed with unknown mode: `%s'." % self.mode

    def thawed(self, root):
        """Install the tree named $x into '/versions/run/$x' with copy-on-write
        semantics."""
        x = self.name
        
        log('Wiping old /versions/run/%s.', x)
        call(['rm', '-rf', join(root, 'versions', 'run', x)])

        log('Shallow-copy /versions/pristine/%s into /versions/run/%s',
            self.name, self.name)
        if not os.path.isdir(join(root, 'versions', 'run')):
            os.makedirs(join(root, 'versions', 'run'), 0755)
        # clean up first in case we were previously interrupted.
        call(['rm', '-rf', join(root, 'versions', 'run', 'tmp.%s' % x)])
        # okay, now do the clone.
        clone(join(root, 'versions', 'pristine', x),
              join(root, 'versions', 'run', 'tmp.%s' % x))
        # atomically install.
        os.rename(join(root, 'versions', 'run', 'tmp.%s' % x),
                  join(root, 'versions', 'run', x))
       
        # XXX: VSERVER COW IS BROKEN! =(
        #log('Set immutable+unlink or immutable attributes')
        #call(['/usr/sbin/setattr', '-R', '--iunlink',
        #      join(root, 'versions', 'run', x)])


    def frozen(self, root):
        """Install the tree named $x into '/versions/run/$x' with read-only
        semantics."""
        x = self.name

        log('Wiping old /versions/run/%s.', x)
        call(['rm', '-rf', join(root, 'versions', 'run', x)])
        os.makedirs(join(root, 'versions', 'run', x), 0755)
        
        log('Make and connect up contents.')
        for frag in os.listdir(join(root, 'versions', 'pristine', x)):
            src = join(root, 'versions', 'pristine', x, frag)
            tgt = join(root, 'versions', 'run', x, frag)
            if os.path.isdir(src):
                try:
                    os.mkdir(tgt)
                    call(['mount', '--bind', '-o', 'ro', src, tgt])
                except:
                    log(traceback.format_exc())
        

def main():
	if len(sys.argv) != 4:
		print "Usage: %s SYSROOT NAME MODE" % sys.argv[0]
		sys.exit(1)
	Tree(sys.argv[2], mode=sys.argv[3]).install(sys.argv[1])
	sys.exit(0)

if __name__ == "__main__":
	main()

# os.umask(0755)

# log('Removing old /versions and /versions/run.')
# call(['rm', '-rf', '/versions', '/versions/run'])

# os.mkdir('/versions')
# os.mkdir('/versions/run')

# current = 'a'

# a = Tree('a', mode='thawed')
# b = Tree('b', mode='frozen')

# log('Setting up trees.')

# setup_tree(a)
# setup_tree(b)

# log('Installing trees.')

# a.install()
# b.install()



