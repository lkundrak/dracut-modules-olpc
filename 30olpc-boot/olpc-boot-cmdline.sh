# if we have 2 partitions and the 2nd partition is called 'system', assumed
# partitioned NAND with p1=jffs2 p2=ubifs
is_ubifs_root() {
	[ -e /sys/class/mtd/mtd2/name ] || return 1
	local name=$(cat /sys/class/mtd/mtd2/name)
	[ "$name" = "system" ]
}

if [ -z "$root" ]; then
	# if no root device was specified, use OFW bootpath to find root
	if [ -e /proc/device-tree ]; then
		bootpath=$(cat /proc/device-tree/chosen/bootpath)
	else
		mount -t promfs promfs /ofw || die
		bootpath=$(cat /ofw/chosen/bootpath)
		umount /ofw
	fi

	# XXX: unpartitioned XO-1.5 not supported
	# XXX: unpartitioned USB not supported
	# XXX: might get confused if more than 1 USB disk is plugged in

	# $bootpath refers to a DT node, which assumes that new firmware versions
	# will not change DT layout/naming. However, change has happened, in the
	# work to move to DT-only upstream kernels on ARM, but we have shipped
	# non-DT kernels/firmwares for XO-1.75.
	#
	# As such, new XO-1.75 firmware versions scan the initramfs and look for
	# the string "$bootpath in\n\t\t/sd@", and if found, hack the bootpath
	# node to have the old "sd@" value.
	#
	# This initramfs code must be maintained to continue meeting that match
	# until we are ready to handle DT-based bootpaths for XO-1.75, which
	# requires some attention to do it right.
	case $bootpath in
		/sd@d4280000/disk@?:*) # XO-1.75
			# extract the bus number (from disk@NUM) and decrement by 1 to
			# correlate with linux device
			tmp=${bootpath#/sd@d4280000/disk@}
			tmp=${tmp%%:*}
			tmp=$((tmp - 1))
			root="/dev/disk/mmc/mmc${tmp}p2"
			;;
		/sd/sdhci@d4280000/disk:*) # device tree
			# FIXME: XO-4 ext SD, might break for XO-1.75
			root="/dev/disk/mmc/mmc2p2"
			;;
		/sd/sdhci@d4281000/disk:*) # device tree
			# FIXME: XO-4 eMMC, might break for XO-1.75
			root="/dev/disk/mmc/mmc1p2"
			;;
		/pci/sd@c/disk@?:*) # XO-1.5 SD card
			# Same calculation as XO-1.75
			tmp=${bootpath#/pci/sd@c/disk@}
			tmp=${tmp%%:*}
			tmp=$((tmp - 1))
			root="/dev/disk/mmc/mmc${tmp}p2"
			;;
		/pci/sd@c,1/disk@?:*) # XO-1 SD card
			tmp=${bootpath#/pci/sd@c,1/disk@}
			tmp=${tmp%%:*}
			tmp=$((tmp - 1))
			root="/dev/disk/mmc/mmc${tmp}p2"
			;;
		/pci/nandflash@c:*)
			# XO-1 internal NAND
			if is_ubifs_root; then
				ubiattach /dev/ubi_ctrl -m 2 -d 0 &
				root=/dev/ubi0_0
				fstype=ubifs
			else
				root="mtd0"
				fstype="jffs2"
				rflags="rp_size=4096"
			fi
			;;
		/pci/usb@*) root="/dev/sda2" ;; # external USB, assume partitioned
	esac
fi

