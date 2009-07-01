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
    # Trim off the \n\0 on OFW mfg data device tree nodes.  According to
    # OLPC trac #2085, this is a bug that will eventually be fixed -- but
    # it doesn't hurt to try to strip them off in any case
	# Note that bash strips the \0 so we just have to remove any trailing \n
	local contents=$(</ofw/$1)
	echo ${contents%\\n}
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
getarg altboot && olpc_boot_backup=1
getarg emu && xo=0

if [ "$xo" == "1" ]; then
	mkdir -p /ofw
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
[ -z "$sn" -o -z "$uuid" ] && [ "$arch" != "OLPC" ] && xo=0

sn=${sn:-SHF00000000}
uuid=${uuid:-00000000-0000-0000-0000-000000000000}

# Add a bit of randomness to the pool (trac# 7134)
echo "$sn/$uuid" > /dev/urandom || die

# use the hardware RNG to generate some more (trac #7213)
[ -e /dev/hwrng ] && dd if=/dev/hwrng of=/dev/urandom bs=1k count=1 >/dev/null 2>&1

# are we booting from an alternate image?
[ -n "$bootpath" -a -z "${bootpath%%*\\boot-alt\\*}" ] && olpc_boot_backup=1

# check for activation code, perform activation if necessary

# in theory, bootpath should have the name of the *kernel* booted which would
# be actos.  But some firmwares inadvertently pass the ramdisk name instead
# (actrd).
# look for \actos.zip and \actrd.zip in the bootpath
[ -n "$bootpath" ] && [[ -z "${bootpath%%*\\actos.zip*}" || -z "${bootpath%%*\\actrd.zip*}" ]] && do_activate=1
[ "$xo" == "0" -o "$ak" == "1" ] && do_activate=0

if [ "$do_activate" == "1" ]; then
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
