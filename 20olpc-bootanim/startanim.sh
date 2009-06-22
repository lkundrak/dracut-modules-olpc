#!/bin/sh
# Pre-pivot hook for starting the boot animation ASAP

ensure_dev() {
	# params: dev type maj min
	[ -e "$NEWROOT/dev/$1" ] || mknod "$NEWROOT/dev/$1" $2 $3 $4
}

if [ -e "$NEWROOT/usr/sbin/boot-anim-start" ]; then
	mount -t proc proc $NEWROOT/proc
	mount -t sysfs syfs $NEWROOT/sys
    # XXX might want to bind-mount /home here to allow early
    # bootanim customization

	# FIXME to avoid some warnings
	touch /etc/fstab

	mount -o remount,rw $NEWROOT || exit 1
	ensure_dev fb0 c 29 0
	ensure_dev console c 5 1
	ensure_dev tty1 c 4 1
	ensure_dev tty2 c 4 2
	chroot $NEWROOT /usr/sbin/boot-anim-start
	umount $NEWROOT/proc
	umount $NEWROOT/sys

	mount -o remount,ro $NEWROOT || exit 1
fi

unset ensure_dev

