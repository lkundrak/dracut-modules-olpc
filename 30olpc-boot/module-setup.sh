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
	if [[ $kernel == [34]* || "$(uname -m)" != arm* ]]; then
		inst_hook cmdline 20 "$moddir"/olpc-boot-cmdline.sh
	else
		inst_hook cmdline 20 "$moddir"/olpc-boot-cmdline-dt.sh
	fi

	inst_hook pre-mount 10 "$moddir"/olpc-boot-premount.sh
	inst_hook pre-pivot 10 "$moddir"/olpc-boot-prepivot.sh

	dracut_install ubiattach
	dracut_install sfdisk

	# mount points used by initramfs code
	mkdir -p "$initdir"/ofw
	mkdir -p "$initdir"/mnt/usb
	mkdir -p "$initdir"/mnt/sd

	inst /usr/lib/dracut-modules-olpc/cprl /usr/libexec/initramfs-olpc/cprl

	# Make "mount -t auto" behaviour the same as it would be on the real system
	inst /etc/filesystems
}
