#!/usr/bin/env python
# Copyright (C) 2009 One Laptop per Child
# Licensed under the GPLv2

"""activate.py contains the laptop activation routines."""
from __future__ import division, with_statement
import os, os.path, sys, time
from initutil import blk_mounted, SD_MNT, USB_MNT
from initutil import sd_init, usb_init, net_init
from socket import *
from ipv6util import if_nametoindex
from subprocess import check_call, call
sys.path += [ '/act-gui' ] # gui_client is in a subdir
from gui_client import send

def try_blk(device, mnt, fstype='msdos'):
    """Try to mount a block device and read keylist from it."""
    try:
        with blk_mounted(device, mnt, fstype):
            with open(os.path.join(mnt,'lease.sig')) as f:
                return f.read()
    except:
        return None

def select_network_channel (channel):
    check_call(['/sbin/iwconfig','eth0','mode','ad-hoc','essid','dontcare'])
    check_call(['/sbin/iwconfig','msh0','channel',str(channel)])
    check_call(['/bin/ip','link','set','dev','msh0','up']) # rely on ipv6 autoconfig
    # set up link-local address
    mac = open('/sys/class/net/msh0/address').read().strip().split(':')
    top = int(mac[0], 16) ^ 2 # universal/local bit complemented
    ll = 'fe80::%02x%s:%sff:fe%s:%s%s' % \
         (top, mac[1], mac[2], mac[3], mac[4], mac[5])
    call(['/bin/ip', 'addr', 'add', '%s/64' % ll, 'dev', 'msh0'])
    a = 2+(ord(os.urandom(1)[0])%250)
    call(['/bin/ip', 'addr', 'add', '172.18.16.%d' % a, 'dev', 'msh0'])
    # XXX: BSSIDs of all 0, F, or 4 are invalid
    # set up route to 172.18.0.1
    call(['/bin/ip', 'route', 'add', '172.18.0.0/23', 'dev', 'msh0'])
    call(['/bin/ip', 'route', 'add', 'default', 'via', '172.18.0.1'])
    # should be able to ping 172.18.0.1 after this point.
    # the IPv4 address is a little hacky, prefer ipv6

def try_to_get_lease(family, addr, serial_num):
    s = socket(family, SOCK_STREAM)
    try:
        s.settimeout(3)
        s.connect(addr)
        s.sendall(serial_num)
        s.shutdown(SHUT_WR)
        s.setblocking(1)
        f = s.makefile('r+',0)
        try:
            lease = f.read()
            return lease
        finally:
            f.close()
    finally:
        s.close()

def try_network (channel, serial_num):
    """Try to get a keylist from the server on the given wireless channel."""
    select_network_channel(channel)
    try:
        time.sleep(4) # let network settle down
        # try to contact the school server.
        for family, addr in [ (AF_INET6,('fe80::abcd:ef01',191,
                                         0, if_nametoindex('msh0'))),
                              (AF_INET, ('172.18.0.1',191)), ] * 4:
            try:
                l = try_to_get_lease(family, addr, serial_num)
                if l is not None: return l
            except: pass
        return None # unsuccessful.
    finally:
        call(['/bin/ip','link','set','dev','msh0','down'])


def activate (serial_num, uuid):
    """Try to perform activation.

    We first check a USB device, then an SD device.  If neither is present,
    we set up networking and try to get a lease from the school server
    on wireless channels 1, 6, and 11."""

    print "********************************************************"
    print "Activating...."
    print "********************************************************"

    # must be imported late, to avoid loading keys before OFW is mounted
    from bitfrost.leases.core import find_lease

    send('start')
    send('serial '+serial_num)
    try:
        # check SD card. #####################
        send('SD start')
        sd_init()
        keylist = try_blk('/dev/mmcblk0p1', SD_MNT)
        if not keylist:
            keylist = try_blk('/dev/mmcblk0', SD_MNT) # unpartitioned SD card
        if keylist:
            send('SD success')
            try:
                # return minimized lease
                return find_lease(serial_num, uuid, keylist)
            except:
                send('SD fail')
                send('SD lock')
        else:
            send('SD fail')
        # Check USB stick ####################
        send('USB start')
        usb_init()
        if not keylist:
            for suf in ['a1','a','b1','b','c1','c','b1','b','a1','a']:
                keylist = try_blk('/dev/sd'+suf, USB_MNT)
                if keylist: break
                # some USB keys take a while to come up
                time.sleep(1)
        if keylist:
            send('USB success')
            try:
                # return minimized lease
                return find_lease(serial_num, uuid, keylist)
            except:
                send('USB fail')
                send('USB lock')
        else:
            send('USB fail')
        # Check network #######################
        try:
            send('wireless start')
            net_init()
            for chan in [1, 6, 11, 1, 6, 11]:
                send('wireless state '+str(chan))
                keylist = try_network(chan, serial_num)
                if keylist:
                    send('wireless success')
                    if keylist == 'STOLEN':
                        send('wireless fail')
                        send('wireless stolen')
                        send('stolen')
                        send('freeze 1')
                        return None # machine's been reported STOLEN!
                    try:
                        # return minimized lease
                        return find_lease(serial_num, uuid, keylist)
                    except:
                        send('wireless fail')
                        send('wireless lock')
            else:
                send('wireless fail')
        except:
            pass # networking is borked
        # we lose. activation failed.
        send('lock')
        send('freeze 1') # a bit of a hack: make sure screen ends up frozen
        return None
    finally:
        send('quit')
    # XXX: we should keep retrying for, say, 30 seconds?
    # XXX: we need to provide more feedback on devices tried/failed
    # XXX: distinguish between "couldn't init/find usb/sd/network" and
    # XXX:  "found the device but it didn't have a key for you"

def main():
    # program to find lease and print it to stdout

    if len(sys.argv) != 3:
        print >> sys.stderr, "Usage: %s SN UUID" % sys.argv[0]
        sys.exit(1)

    print activate(sys.argv[1], sys.argv[2])
    sys.exit(0)

if __name__ == "__main__":
    main()
