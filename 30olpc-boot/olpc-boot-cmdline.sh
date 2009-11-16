if [ -z "$root" ]; then
	# if no root device was specified, use OFW bootpath to find root
	mount -t promfs promfs /ofw || die
	bootpath=$(cat /ofw/chosen/bootpath)
	umount /ofw

	# XXX: unpartitioned XO-1.5 not supported
	# XXX: unpartitioned USB not supported
	# XXX: might get confused if more than 1 USB disk is plugged in
	#
	# FIXME: teach dracut about mtd mounts so that we can avoid using the
	# mtdblock driver
	#
	# FIXME: once away from mtdblock, should be able to handle partitioned
	# NAND using partition labels, i.e.
	# /pci/nandflash@c:root,\boot\vmlinuz//jffs2-file-system:\boot\vmlinuz
	# becomes mtd:root
	case $bootpath in
		/pci/sd@c/disk@?:*) # XO-1.5 SD card
			# extract the bus number (from disk@NUM) and decrement by 1 to
			# correlate with linux device
			tmp=${bootpath#/pci/sd@c/disk@}
			tmp=${tmp%%:*}
			((tmp--))
			root="/dev/disk/mmc/mmc${tmp}p2"
			;;
		/pci/nandflash@c:*) root="/dev/mtdblock0" ;; # XO-1 internal NAND
		/pci/usb@*) root="/dev/sda2" ;; # external USB, assume partitioned
	esac
fi

# disable atime on root mount, #9455
rflags="noatime"

