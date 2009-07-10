#!/bin/sh
# Copyright (C) 2009 One Laptop per Child
# Licensed under the GPLv2
#

die() {
	if [ "$#" != "0" ]; then
		echo $*
	else
		echo "Failure condition in initramfs"
	fi
	exit 1
}

# make root writable
writable_start() {
	mount -o remount,rw "$NEWROOT"
}

writable_done() {
	mount -o remount,ro "$NEWROOT"
}

check_stolen() {
	# XXX: we should provide some way to delete the 'stolen' identifier to
	# XXX: recover the machine.
	if [ -e "$NEWROOT/.private/stolen" ]; then
		# this machine is stolen!  delete activation lease
		writable_start
		rm -f "$NEWROOT"/security/lease.sig
		writable_done
		sync
		poweroff -f || die
	fi

	if ! [ -d "$NEWROOT/.private" -a -d "$NEWROOT/security/.private" ]; then
		writable_start || die
		mkdir -p "$NEWROOT/.private"
		mkdir -p "$NEWROOT/security/.private"
		writable_done || die
	fi

	# mount OATC's private scratch space
	# XXX: currently never used, so why mount it?
	# mount --bind "$NEWROOT/.private" "$NEWROOT/security/.private"
}

# frob the /current symlink to start from the backup filesystem if requested
# return the 'short name' for the image we should boot, or None if the
# filesystem is not upgradable.
frob_symlink() {
	local target dir current alt config d tmp writable=0
	[ -h "$NEWROOT/versions/boot/current" ] || return 0

	# the 'current' symlink is of the form /versions/pristine/<hash>
	# we want to return <hash>
	target=$(readlink "$NEWROOT/versions/boot/current")
	dir=$(dirname "$target")
	current=$(basename "$target")
	[ "$dir" != "/versions/pristine" -a "$dir" != "/versions/run" -a "$dir" != "../../run" ] && return 1

	if [[ "$olpc_boot_backup" == "1" ]]; then
		target=$(readlink "$NEWROOT/versions/boot/alt")
		dir=$(dirname "$target")
		alt=$(basename "$target")
		[ "$dir" != "/versions/pristine" -a "$dir" != "/versions/run" -a "$dir" != "../../run" ] && return 1

		# atomically swap current and alt.
		writable_start || return 1
		writable=1
		config=$(readlink "$NEWROOT/versions/boot")
		d=$(mktemp -d --tmpdir="$NEWROOT/versions/configs" cfg.XXXXXXXXXX )
		ln -s "/versions/pristine/$alt" "$d/current" || return 1
		ln -s "/versions/pristine/$current" "$d/alt" || return 1
		ln -s "${d#$NEWROOT/versions/}" "$NEWROOT/versions/boot.tmp" || return 1
		sync || return 1 # superstition
		mv "$NEWROOT/versions/boot.tmp" "$NEWROOT/versions/boot" || return 1
		sync || return 1 # superstition

		# remove old config
		rm -rf "$NEWROOT/$config" || return 1
		tmp=$current
		current=$alt
		alt=$tmp
	fi

	# check that /versions/run/$current exists; create if needed.
	if ! [ -d "$NEWROOT/versions/run/$current" ]; then
		if ! [ "$writable" == "1" ]; then
			writable_start || return 1
			writable=1
		fi
		/usr/libexec/initramfs-olpc/upfs.py $NEWROOT $current thawed || return 1
	fi

	# create 'running' symlink

	# trac #5317: only create symlink if necessary
	if [ -h "$NEWROOT/versions/running" -a "$(readlink $NEWROOT/versions/running)" == "pristine/$current" ]; then
		if [ "$writable" == "1" ]; then
			writable_done || return 1
		fi
		return
	fi

	if ! [ "$writable" == "1" ]; then
		writable_start || return 1
		writable=1
	fi

	rm -f "$NEWROOT/versions/running" # ignore error
	ln -s "pristine/$current" "$NEWROOT/versions/running" || return 1
	writable_done || return 1
	echo $current
}

ensure_dev() {
	# params: dev type maj min
	[ -e "$1/dev/$2" ] || mknod "$1/dev/$2" $3 $4 $5
}

start_bootanim() {
	[ -x "$1/usr/sbin/boot-anim-start" ] || return

	mount -t proc proc "$1"/proc
	mount -t sysfs syfs "$1"/sys
    # XXX might want to bind-mount /home here to allow early
    # bootanim customization

	writable_start || die
	ensure_dev "$1" fb0 c 29 0
	ensure_dev "$1" console c 5 1
	ensure_dev "$1" tty1 c 4 1
	ensure_dev "$1" tty2 c 4 2
	chroot "$1" /usr/sbin/boot-anim-start
	umount "$1"/proc
	umount "$1"/sys
	writable_done || die
}

# XXX mount gives a warning in writable_start() if there's no fstab
echo "" >> /etc/fstab

# check private security dir
check_stolen

# if we're activating, we just received a lease that we should write to disk
# sooner rather than later
if [ -n "$olpc_write_lease" ]; then
	writable_start || die
	mkdir -p $NEWROOT/security || die
	echo "$olpc_write_lease" > "$NEWROOT/security/lease.sig" || die
	writable_done || die
fi


# launch pretty boot asap
# this covers the "regular" filesystem layout
start_bootanim "$NEWROOT"

current=$(frob_symlink)
[ "$?" != "0" ] && die

if [ -n "$current" ]; then
	newroot=$NEWROOT/versions/run/$current
	# launch pretty boot asap
	# this covers the "upgradable" filesytem layout with /versions etc.
	start_bootanim $newroot

	# okay, do the boot!
	# create some bind mounts
	# (do this after making root writable, because newer kernels will
	#  otherwise end up with ro bind mounts against the writable root)
	writable_start || die
	for frag in home security versions; do
		# ignore failures here: a debian installation (say) may not have
		# these dirs.
		mount --bind "$NEWROOT/$frag" "$NEWROOT/versions/run/$current/$frag"
	done
	writable_done || die

	NEWROOT="$newroot"
fi

unset writable_start writable_done
unset check_stolen ensure_dev start_bootanim
unset die

