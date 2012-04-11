#!/bin/bash
check() {
	return 255
}

depends() {
	echo "olpc-common"
	return 0
}

install() {
	# cmdline hook must be installed to run after 10parse-root-opts but before
	# 95parse-block
	inst_hook cmdline 20 "$moddir"/olpc-boot-cmdline.sh

	inst_hook pre-mount 10 "$moddir"/olpc-boot-premount.sh
	inst_hook pre-pivot 10 "$moddir"/olpc-boot-prepivot.sh

	progs="dd rm mv ln sync sleep poweroff umount readlink dirname basename mktemp"

	for i in $progs; do
			path=$(find_binary "$i")
			[ -e "$initdir/$path" ] && continue
			ln -s /sbin/busybox "$initdir/$path"
	done

	dracut_install ubiattach
	dracut_install sfdisk

	# mount points used by initramfs code
	mkdir -p "$initdir"/ofw
	mkdir -p "$initdir"/mnt/usb
	mkdir -p "$initdir"/mnt/sd

	inst /usr/lib/dracut-modules-olpc/cprl /usr/libexec/initramfs-olpc/cprl

	# Disable dracut's fstab-checking, not appropriate for us
	# http://dev.laptop.org/ticket/10394
	mkdir -p ${initdir}/etc
	echo " rd_NO_FSTAB fastboot" >> ${initdir}/etc/cmdline

	# Make "mount -t auto" behaviour the same as it would be on the real system
	inst /etc/filesystems
}
