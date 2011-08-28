#!/bin/sh
# Copyright (C) 2009 One Laptop per Child
# Licensed under the GPLv2
#

echo "Hello, (children of the) world!"

exists_ofw()
{
	[ -e /proc/device-tree/$1 -o -e /ofw/$1 ]
}

read_ofw()
{
	# OFW mfg data might include \n\0 at the end of the file. but these are
	# automatically stripped by the shell.
	if [ -e /proc/device-tree/$1 ]; then
		local contents=$(cat /proc/device-tree/$1)
	else
		local contents=$(cat /ofw/$1)
	fi
	# Use printf, to avoid echo's expansion of backslash-escaped sequences.
	printf "%s" $contents
}

die() {
	if [ "$#" != "0" ]; then
		echo $*
	else
		echo "Failure condition in initramfs"
	fi
	exit 1
}

xo=1

getarg activate && do_activate=1
getarg emu && xo=0

if [ "$xo" = "1" ]; then
	if [ ! -e /proc/device-tree ]; then
		mount -t promfs promfs /ofw || die
	fi
	arch=$(read_ofw architecture)
	sn=$(read_ofw mfg-data/SN)
	uuid=$(read_ofw mfg-data/U#)
	bootpath=$(read_ofw chosen/bootpath)
	exists_ofw mfg-data/ak && ak=1

	# import bitfrost.leases.keys
	if [ ! -e /proc/device-tree ]; then
		umount /ofw || die
	fi
fi

# Might not be an XO (could be an emulator)
[ -z "$sn" -o -z "$uuid" ] && [ "$arch" != "OLPC" ] && xo=0

sn=${sn:-SHF00000000}
uuid=${uuid:-00000000-0000-0000-0000-000000000000}

# Add a bit of randomness to the pool (trac# 7134)
echo "$sn/$uuid" > /dev/urandom || die

# use the hardware RNG to generate some more (trac #7213)
[ -e /dev/hwrng ] && dd if=/dev/hwrng of=/dev/urandom bs=1k count=1 >/dev/null 2>&1

# check for activation code, perform activation if necessary

# in theory, bootpath should have the name of the *kernel* booted which would
# be actos.  But some firmwares inadvertently pass the ramdisk name instead
# (actrd).
# look for \actos.zip and \actrd.zip in the bootpath
case $bootpath in
	*\\actos.zip*|*actrd.zip*) do_activate=1 ;;
esac

[ "$xo" = "0" -o "$ak" = "1" ] && do_activate=0

if [ "$do_activate" = "1" ]; then
	olpc_write_lease=$(/usr/libexec/initramfs-olpc/activate.py $sn $uuid)
	if [ "$?" != "0" -o -z "$olpc_write_lease" ]; then
		#  This message is never seen unless the GUI failed.
		echo "Could not activate this XO."
		echo "Serial number: $sn" # don't show UUID
		# activation failed.  shutdown in 2 minutes.
		sync || die
		sleep 60
		poweroff -f || die
	fi
fi

unset die
unset exists_ofw read_ofw
