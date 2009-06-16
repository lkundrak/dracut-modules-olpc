#!/bin/sh
# Copyright (C) 2009 One Laptop per Child
# Licensed under the GPLv2
#

echo "Hello, (children of the) world!"

exists_ofw()
{
	[ -e /ofw/$1 ]
}

read_ofw()
{
	# FIXME: trim off \n\0 if it exists
	echo $(</ofw/$1)
}

#FIXME die ok?

xo=1

getarg activate && do_activate=1
getarg altboot && olpc_boot_backup=1
# int arg
getarg emu && xo=0

if [ "$xo" == "1" ]; then
	mount -t promfs promfs /ofw || die
	arch=$(read_ofw architecture)
	sn=$(read_ofw mfg-data/SN)
	uuid=$(read_ofw mfg-data/U#)
	bootpath=$(read_ofw chosen/bootpath)
	ak=$(exists_ofw mfg-data/ak)

	# import bitfrost.leases.keys
	umount /ofw || die
fi

# Might not be an XO (could be an emulator)
if [ -z "$sn" -o -z "$uuid" ] && [ "$arch" != "OLPC" ] && xo=0

sn=${sn:-SHF00000000}
uuid=${uuid:-00000000-0000-0000-0000-000000000000}

# Add a bit of randomness to the pool (trac# 7134)
echo "$sn/$uuid" > /dev/urandom || die

# use the hardware RNG to generate some more (trac #7213)
[ -e /dev/hwrng ] && dd if=/dev/hwrng of=/dev/urandom bs=1k count=1

# are we booting from an alternate image?
[ -n "$bootpath" -a -z "${bootpath%%*\\boot-alt\\*}" ] && olpc_boot_backup=1

# check for activation code, perform activation if necessary

# in theory, bootpath should have the name of the *kernel* booted which would
# be actos.  But some firmwares inadvertently pass the ramdisk name instead
# (actrd).
# look for \actos.zip and \actrd.zip in the bootpath
[ -n "$bootpath" ] && [[ -z "${bootpath%%*\\actos.zip*}" -o -z "${bootpath%%*\\actrd.zip*}" ]] && do_activate=1
[ "$xo" == "0" -o "$ak" == "1" ] && do_activate=0

if [ "$do_activate" == "1" ]; then
	# def lease writer()
	# def run_init()
	# antitheft.run(!do_activate, sn, uuid, 'schooserver.laptop.org', lease_writer, run_init)
	do_activate $sn $uuid 'schoolserver.laptop.org' || die
fi

# unfreeze DCON
# become interactive shell

