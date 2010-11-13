# if we have 2 partitions and the 2nd partition is called 'system', assumed
# partitioned NAND with p1=jffs2 p2=ubifs
is_ubifs_root() {
	[ -e /sys/class/mtd/mtd3/name ] || return 1
	local name=$(cat /sys/class/mtd/mtd3/name)
	[ "$name" = "system" ]
}

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
	case $bootpath in
		/pci/sd@c/disk@?:*) # XO-1.5 SD card
			# extract the bus number (from disk@NUM) and decrement by 1 to
			# correlate with linux device
			tmp=${bootpath#/pci/sd@c/disk@}
			tmp=${tmp%%:*}
			tmp=$((tmp - 1))
			root="/dev/disk/mmc/mmc${tmp}p2"
			;;
		/pci/nandflash@c:*)
			# XO-1 internal NAND
			if is_ubifs_root; then
				ubiattach /dev/ubi_ctrl -m 3 -d 0 &
				root=/dev/ubi0_0
				fstype=ubifs
			else
				root="/dev/mtdblock0"
				fstype="jffs2"
			fi
			;;
		/pci/usb@*) root="/dev/sda2" ;; # external USB, assume partitioned
	esac
fi

