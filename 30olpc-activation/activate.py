#!/usr/bin/env python
# Copyright (C) 2009 One Laptop per Child
# Licensed under the GPLv2

"""activate.py contains the laptop activation routines."""
from __future__ import division, with_statement
import os, os.path, sys, time
from socket import *
from ipv6util import if_nametoindex
import subprocess
from subprocess import check_call, call
from olpc_act_gui_client import send
import greplease

SD_MNT = '/mnt/sd'
USB_MNT = '/mnt/usb'
bootpath = ''

def blk_mounted(device, mnt, fstype=None):
    """Mount a block device."""
    class blk_mgr(object):
        def __enter__(self):
            cmd = ['/bin/mount']
            if fstype is not None:
                cmd.extend(['-t', fstype])
            cmd.extend(['-o', 'ro', device, mnt])
            check_call(cmd)
        def __exit__(self, type, value, traceback):
            call(['/bin/umount',mnt])
    return blk_mgr()

def lease_from_file(fname, serial_num):
    """Find the appropriate lease in a file that may be
       a bare lease ("singleton") or a -- perhaps huge --
       CJSON file.
    """
    fh = open(fname, 'r')
    head = fh.read(5)
    fh.close()
    if head == '[1,{"':
        # Matches the start of a well-formed v1 leases file.
        # Use greplease.grep() here to handle large lease files
        return greplease.grep(fname, serial_num)
    fh = open(fname, 'r')
    fc = fh.read()
    fh.close()
    print >> sys.stderr, "lease.sig successfully read."
    return fc

def try_blk(device, mnt, serial_num, fstype=None):
    """Try to mount a block device and read keylist from it."""
    try:
        print >> sys.stderr, "Trying " + device + "...",
        with blk_mounted(device, mnt, fstype):
            print >> sys.stderr, "mounted...",
            return lease_from_file(os.path.join(mnt,'lease.sig'), serial_num)
    except:
        return None

def set_addresses_bss ():
    # set up link-local address
    mac = open('/sys/class/net/eth0/address').read().strip().split(':')
    top = int(mac[0], 16) ^ 2 # universal/local bit complemented
    ll = 'fe80::%02x%s:%sff:fe%s:%s%s' % \
         (top, mac[1], mac[2], mac[3], mac[4], mac[5])
    call(['/sbin/ip', 'addr', 'add', '%s/64' % ll, 'dev', 'eth0'])
    a = 2+(ord(os.urandom(1)[0])%250)
    call(['/sbin/ip', 'addr', 'add', '172.18.127.%d/19' % a,
          'brd', '172.18.127.255', 'dev', 'eth0'])
    # XXX: BSSIDs of all 0, F, or 4 are invalid
    call(['/sbin/ip', 'route', 'add', 'default', 'via', '172.18.96.1', 'dev', 'eth0'])
    # should be able to ping 172.18.0.1 after this point.
    # the IPv4 address is a little hacky, prefer ipv6

def mesh_device_exists ():
    return os.path.exists('/sys/class/net/msh0')

def set_addresses_mesh ():
    # set up link-local address
    mac = open('/sys/class/net/msh0/address').read().strip().split(':')
    top = int(mac[0], 16) ^ 2 # universal/local bit complemented
    ll = 'fe80::%02x%s:%sff:fe%s:%s%s' % \
         (top, mac[1], mac[2], mac[3], mac[4], mac[5])
    a = 2+(ord(os.urandom(1)[0])%250)
    call(['/sbin/ip', 'addr', 'add', '172.18.16.%d/24' % a,
          'brd', '172.18.16.255', 'dev', 'msh0'])
    call(['/sbin/ip', 'addr', 'add', '172.18.16.%d' % a, 'dev', 'msh0'])
    # XXX: BSSIDs of all 0, F, or 4 are invalid
    # set up route to 172.18.0.1
    call(['/sbin/ip', 'route', 'add', '172.18.0.0/23', 'dev', 'msh0'])
    call(['/sbin/ip', 'route', 'add', 'default', 'via', '172.18.0.1', 'dev', 'msh0'])
    # should be able to ping 172.18.0.1 after this point.
    # the IPv4 address is a little hacky, prefer ipv6

_sd_first = True
def sd_init():
    """Ensure necessary modules are loaded for sd."""
    global _sd_first
    # ignore modprobe failures, since older kernels don't have
    # modular sd (trac #7369).
    call(['/sbin/modprobe','sdhci'])
    call(['/sbin/modprobe','mmc_block'])
    if _sd_first:
        _sd_first = False
        time.sleep(3) # CAFE takes a bit to wake up

def sd_get_disk():
    """Return device name of SD disk"""
    # e.g. /pci/sd@c/disk@1:\boot\vmlinuz...
    if bootpath.startswith("/pci/sd@c/disk@") and bootpath[15:16].isdigit():
        # XO-1.5: determine SD bus number from OFW bootpath, and correlate to
        # Linux device for external SD card
        disknum = int(bootpath[15:16])

        if disknum == 3:
            # XO-1.5 B3 or newer booting from internal SD, so return address
            # of external SD card (on first mmc bus)
            return "/dev/disk/mmc/mmc0"
        elif disknum == 1:
            # XO-1.5 B2 booting from internal SD, return address of external
            # SD (2nd mmc bus)
            return "/dev/disk/mmc/mmc1"
            # oops, this if branch will also trigger for XO-1.5 B3 when booting
            # from external SD. but if you're doing that then you arent going
            # to be expecting to find a lease on SD, I hope.

    # XO-1, or fallback:
    return "/dev/mmcblk0"

def select_mesh_channel (channel):
    check_call(['/sbin/iwconfig','eth0','mode','ad-hoc','essid','dontcare'])
    check_call(['/sbin/iwconfig','msh0','channel',str(channel)])
    check_call(['/sbin/ip','link','set','dev','msh0','up']) # rely on ipv6 autoconfig
    set_addresses_mesh()

def select_bss (ssid):
    print >> sys.stderr, "attempting connection to open BSS", ssid
    check_call(['/sbin/ip','link','set','dev','eth0','up']) # rely on ipv6 autoconfig
    check_call(['/sbin/iwconfig','eth0','mode','managed','essid',ssid])

    # wait for association, max 5 secs
    for i in range(0, 10):
        time.sleep(0.5)
        output = subprocess.Popen(["/sbin/iwconfig", "eth0"],
                                  stdout=subprocess.PIPE).communicate()[0]
        lines = output.split("\n")
        if len(lines) < 2:
            print >> sys.stderr, "bad iwconfig output?"
            return False

        ssidpos = lines[0].index("ESSID:")
        iw_ssid = lines[0][ssidpos + 6:].strip()
        if iw_ssid != '"' + ssid + '"':
            if iw_ssid != '""':
                print >> sys.stderr, "unexpected ESSID value:", iw_ssid
            continue

        appos = lines[1].find("Access Point: ")
        if appos == -1:
            continue
        iw_ap = lines[1][appos+14:].strip()
        if iw_ap[0].isdigit():
            print >> sys.stderr, "connected!"
            set_addresses_bss()
            return True

    return False

def try_bss_network (ssid, serial_num):
    """Try to get a keylist from the server on a given BSS network."""
    try:
        associated = select_bss(ssid)
        if associated:
            time.sleep(4) # let network settle down
            return contact_lease_server('eth0', serial_num)
        else:
            return None
    finally:
        call(['/sbin/ip','link','set','dev','eth0','down'])

def _find_open_bss_nets(iface):
    output = subprocess.Popen(["/sbin/iwlist", iface, "scan"], stdout=subprocess.PIPE).communicate()[0]
    nets = []
    this_essid = ""

    for line in output.split("\n"):
        line = line.strip()

        if line.startswith("ESSID:\""):
            this_essid = line[7:-1]
            continue

        if line.startswith("Mode:"):
            if line != "Mode:Master" and line != "Mode:Managed":
                # ignore non-BSS networks
                this_essid = ""
            continue

        if line == "Encryption key:off":
            if len(this_essid) > 0:
                if this_essid not in nets:
                    nets.append(this_essid)
                this_essid = ""

    return nets

def find_open_bss_nets (iface="eth0"):
    """
    Scans for networks and returns list of SSIDs for open BSSs
    """

    check_call(['/sbin/ip','link','set','dev','eth0','up'])
    try:
        return _find_open_bss_nets(iface)
    finally:
        call(['/sbin/ip','link','set','dev','eth0','down'])

def check_stolen(keylist):
    if keylist != 'STOLEN':
        return False

    send('wireless fail')
    send('wireless stolen')
    send('stolen')
    send('freeze 1')
    return True

_usb_first = True
def usb_init():
    """Ensure necessary modules are loaded for usb."""
    global _usb_first
    # ignore modprobe failures, since older kernels don't have
    # modular usb (trac #7113).
    print >> sys.stderr, "Loading USB modules..."
    call(['/sbin/modprobe','ohci-hcd'])
    call(['/sbin/modprobe','usb-storage'])
    if _usb_first:
        _usb_first = False
        time.sleep(5) # usb disks take a while to spin up

def net_init():
    """Ensure necessary modules are loaded for network access."""
    call(['/sbin/modprobe', 'usb8xxx']) # XO-1
    call(['/sbin/modprobe', 'libertas_sdio']) # XO-1.5
    call(['/sbin/modprobe','ipv6']) # ipv6 is built statically in recent kernels

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

def contact_lease_server (iface, serial_num):
    # try to contact the lease server
    if iface.startswith("msh"):
        xs6addr = 'fe80::abcd:ef01'
    else:
        xs6addr = 'fe80::abcd:ef02'

    for family, addr in [ (AF_INET6,(xs6addr,191,
                                     0, if_nametoindex(iface))),
                          (AF_INET, ('172.18.0.1',191)), ] * 4:
        try:
            l = try_to_get_lease(family, addr, serial_num)
            if l is not None:
                return l
        except:
            pass
    return None # unsuccessful

def try_mesh_network (channel, serial_num):
    """Try to get a keylist from the server on the given wireless channel."""
    select_mesh_channel(channel)
    try:
        time.sleep(4) # let network settle down
        return contact_lease_server('msh0', serial_num)
    finally:
        call(['/sbin/ip','link','set','dev','msh0','down'])


def activate (serial_num, uuid):
    """Try to perform activation.

    We first check a USB device, then an SD device.  If neither is present,
    we set up networking and try to get a lease from the school server
    on wireless channels 1, 6, and 11."""

    print >> sys.stderr, "********************************************************"
    print >> sys.stderr, "Activating...."
    print >> sys.stderr, "********************************************************"

    # must be imported late, to avoid loading keys before OFW is mounted
    from bitfrost.leases.core import find_lease

    send('start')
    send('serial '+serial_num)
    try:
        # check SD card. #####################
        send('SD start')
        sd_init()
        sd_disk = sd_get_disk()
        keylist = try_blk(sd_disk + 'p1', SD_MNT, serial_num)
        if not keylist:
            keylist = try_blk(sd_disk, SD_MNT, serial_num) # unpartitioned SD card
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
        keylist = None
        for suf in ['a1','a','b1','b','c1','c','b1','b','a1','a']:
            keylist = try_blk('/dev/sd'+suf, USB_MNT, serial_num)
            if keylist: break
            # some USB keys take a while to come up
            time.sleep(1)
        if keylist:
            send('USB success')
            try:
                # return minimized lease
                print >> sys.stderr, "Checking lease..."
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

            candidates = find_open_bss_nets()
            print >> sys.stderr, "open BSS candidates:", candidates
            for ssid in candidates:
                keylist = try_bss_network(ssid, serial_num)
                if not keylist:
                    continue
                if check_stolen(keylist):
                    return None
                try:
                    # return minimized lease
                    return find_lease(serial_num, uuid, keylist)
                except:
                    continue

            if mesh_device_exists():
                for chan in [1, 6, 11, 1, 6, 11]:
                    send('wireless state '+str(chan))
                    keylist = try_mesh_network(chan, serial_num)
                    if keylist:
                        send('wireless success')
                        if check_stolen(keylist):
                            return None # machine's been reported STOLEN!
                        try:
                            # return minimized lease
                            return find_lease(serial_num, uuid, keylist)
                        except:
                            continue
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
    global bootpath
    # program to find lease and print it to stdout

    if len(sys.argv) != 3:
        print >> sys.stderr, "Usage: %s SN UUID" % sys.argv[0]
        sys.exit(1)

    # read extra deployment keys and bootpath
    check_call(['/bin/mount','-t','promfs','promfs','/ofw'])
    import bitfrost.leases.keys
    bootpath = open('/ofw/chosen/bootpath').read().rstrip("\n\0")
    check_call(['/bin/umount','/ofw'])

    ret = activate(sys.argv[1], sys.argv[2])
    if ret is not None:
        print ret
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
