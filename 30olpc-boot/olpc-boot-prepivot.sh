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

# do we have a separate boot partition?
is_partitioned() {
	# if root device ends in p[0-9] then we're on a partitioned system
	# XXX: does this need improving?
	case $root in
		*p[0-9]) return 0 ;;
		*) return 1 ;;
	esac
}

# make root writable
writable_start() {
	mount -o remount,rw "$NEWROOT"
}

writable_done() {
	mount -o remount,ro "$NEWROOT"
}

get_boot_device() {
	case $root in
	block:/dev/mmcblk?p?)
		echo ${root#block:} | sed -e 's:.$:1:'
		return 0
		;;
	esac
	echo "UNKNOWN"
	return 1
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

# Atomically swing a symlink at $2 from its current contents to $1
rewrite_symlink()
{
	local retcode
	local dir=$(dirname "$2")
	local tmpdir=$(mktemp -d --tmpdir "$dir" sym.XXXXXXXXXX)
	local tmplnk="$tmpdir"/symlink

	ln -s "$1" "$tmplnk"
	retcode=$?
	if [ $retcode != 0 ]; then
		rm -rf "$tmpdir"
		return $retcode
	fi

	mv -f "$tmplnk" "$2"
	retcode=$?
	rm -rf "$tmpdir"
	return $retcode
}

# frob the /current symlink to start from the backup filesystem if requested
# return the 'short name' for the image we should boot, or None if the
# filesystem is not upgradable.
frob_symlink() {
	local retcode
	if is_partitioned; then
		current=$(frob_symlink_partitioned)
		retcode=$?
	else
		current=$(frob_symlink_unpartitioned)
		retcode=$?
	fi

	[ $retcode = 0 ] || return retcode

	# check that /versions/run/$current exists; create if needed.
	if ! [ -d "$NEWROOT/versions/run/$current" ]; then
		if ! [ "$writable" = "1" ]; then
			writable_start || return 1
			writable=1
		fi
		# redirect stdout to stderr so that it doesn't interfere with the
		# return value of this function (which has to be just an OS hash)
		/usr/libexec/initramfs-olpc/upfs.py $NEWROOT $current thawed >&2 || return 1
	fi

	# create 'running' symlink

	# trac #5317: only create symlink if necessary
	if [ -h "$NEWROOT/versions/running" -a "$(readlink $NEWROOT/versions/running)" = "pristine/$current" ]; then
		if [ "$writable" = "1" ]; then
			writable_done || return 1
		fi
		echo $current
		return 0
	fi

	# make symlink
	if ! [ "$writable" = "1" ]; then
		writable_start || return 1
		writable=1
	fi

	rm -f "$NEWROOT/versions/running" # ignore error
	ln -s "pristine/$current" "$NEWROOT/versions/running" || return 1
	writable_done || return 1
	echo $current
	return 0
}


_frob_symlink_partitioned() {
	local target dir current alt

	[ -h /boot/boot -a -d /boot/boot-versions ] || return 0

	# read hash from /boot/boot symlink
	target=$(readlink /boot/boot)
	dir=$(dirname "$target")
	[ "$dir" != "boot-versions" ] && return 1
	current=$(basename $target)

	if [ "$olpc_boot_backup" = "1" -a -h /boot/boot/alt ]; then
		target=$(readlink /boot/boot/alt)
		dir=$(dirname "$target")
		[ "$dir" != ".." ] && return 1
		alt=$(basename "$target")

		sync || return 1 # superstition

		# make alternate link in new configuration point to the non-backup OS
		rewrite_symlink ../"$current" /boot/boot/alt/alt || return 1

		# update /boot to point at alternate OS
		rewrite_symlink boot-versions/$alt /boot || return 1

		current=$alt
	fi

	echo $current
	return 0
}

frob_symlink_partitioned() {
	# wrap _frob_symlink_partitioned so that we're sure to unmount /boot
	# on all the exit paths
	local bdev retcode

	bdev=$(get_boot_device)
	[ $? != 0 ] && return 1

	mkdir -p /boot
	mount $bdev /boot || return 1

	_frob_symlink_partitioned
	retcode=$?

	umount /boot
	return $retcode
}


frob_symlink_unpartitioned() {
	local target dir current alt config d tmp writable=0
	[ -h "$NEWROOT/versions/boot/current" ] || return 0

	# the 'current' symlink is of the form /versions/pristine/<hash>
	# we want to return <hash>
	target=$(readlink "$NEWROOT/versions/boot/current")
	dir=$(dirname "$target")
	current=$(basename "$target")
	[ "$dir" != "/versions/pristine" -a "$dir" != "/versions/run" -a "$dir" != "../../run" ] && return 1

	if [ "$olpc_boot_backup" = "1" ]; then
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

	echo $current
	return 0
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

	NEWROOT="$newroot"
	# Note: for the "upgradable case", we leave root mounted rw (as has always
	# been done for OLPC) before entering the real system. This is because
	# when you're chrooted in the real system, you can't
	# "mount -o remount,rw /" because / isn't a real mount.
fi

unset writable_start writable_done
unset check_stolen ensure_dev start_bootanim
unset die

