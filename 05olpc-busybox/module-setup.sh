#!/bin/bash
check() {
	return 255
}

install() {
	inst busybox /sbin/busybox

	# List of shell programs that we use in other official dracut modules, that
	# must be supported by the busybox installed on the host system
	progs="echo grep usleep [ rmmod insmod mount uname umount setfont kbd_mode stty gzip bzip2 chvt readlink blkid dd losetup tr sed seq ps more cat rm free ping netstat vi ping6 fsck ip hostname basename mknod mkdir pidof sleep chroot ls cp mv dmesg mkfifo less ln modprobe flock"

	# FIXME: switch_root should be in the above list, but busybox version hangs
	# (using busybox-1.15.1-7.fc14.i686 at the time of writing)

	for i in $progs; do
		path=$(find_binary "$i")
		ln -s /sbin/busybox "$initdir/$path"
	done
}