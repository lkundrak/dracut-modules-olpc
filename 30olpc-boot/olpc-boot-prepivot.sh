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
	# XXX: does this need improving?
	case $root in
		*p[0-9]) return 0 ;; # MMC e.g. mmcblk0p2
		*sd?[0-9]) return 0 ;; # USB e.g. sda2
		block:/dev/ubi*) return 0 ;; # assume partitions if using ubifs
		*) return 1 ;;
	esac
}

get_boot_device() {
	local tmp

	case $root in
	block:/dev/mmcblk?p? | block:/dev/disk/mmc/mmc?p?)
		tmp=${root#block:}
		tmp=${tmp%p?}
		echo ${tmp}p1
		return 0
		;;
	block:/dev/sd??)
		tmp=${root#block:}
		tmp=${tmp%?}
		echo ${tmp}1
		return 0
		;;
	block:/dev/ubi*) # if root is ubifs, assume boot is partition 1 type jffs2
		echo "mtd1"
		return 0
		;;
	esac
	echo "UNKNOWN"
	return 1
}

get_boot_fstype() {
	case $root in
	block:/dev/ubi*) # if root is ubifs, assume boot is partition 1 type jffs2
		echo "jffs2"
		;;
	esac
}

mount_boot() {
	is_partitioned || return 0

	local bdev=$(get_boot_device)
	[ $? != 0 ] && return 1

	local bfstype=$(get_boot_fstype)
	[ -n "$bfstype" ] && bfstype="-t $bfstype"

	mkdir -p /bootpart
	mount $bfstype $bdev /bootpart
}

unmount_boot() {
	umount /bootpart
}

erase_lease() {
	if is_partitioned; then
		rm -f /bootpart/security/lease.sig
	else
		rm -f "$NEWROOT"/security/lease.sig
	fi
}

check_stolen() {
	# XXX: we should provide some way to delete the 'stolen' identifier to
	# XXX: recover the machine.
	if [ -e "$NEWROOT/.private/stolen" ]; then
		# this machine is stolen!  delete activation lease
		erase_lease
		sync
		poweroff -f || die
	fi

	if ! [ -d "$NEWROOT/.private" -a -d "$NEWROOT/security/.private" ]; then
		mkdir -p "$NEWROOT/.private"
		mkdir -p "$NEWROOT/security/.private"
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
	local tmpdir=$(mktemp -d --tmpdir="$dir" sym.XXXXXXXXXX)
	local tmplnk="$tmpdir"/symlink

	ln -s "$1" "$tmplnk"
	retcode=$?
	if [ $retcode != 0 ]; then
		rm -rf "$tmpdir"
		return $retcode
	fi

	mv -f -T "$tmplnk" "$2"
	retcode=$?
	rm -rf "$tmpdir"
	return $retcode
}

# cleanup a part of the versions tree
# removes all versions except the current image and any others marked as sticky
purge_versions()
{
	local current=$1 dir=$2 oIFS
	[ -d "$dir" ] || return 0

	# XXX can't use globs here because dash doesn't support null globbing
	oIFS=$IFS
	IFS="
"
	for ent in $(ls $dir); do
		[ "$ent" = "$current" ] && continue
		[ -e "$NEWROOT/versions/sticky/$ent" ] && continue
		to_purge="$to_purge $dir/$ent"
	done
	IFS=$oIFS
}

do_purge()
{
	# we do the removal in the background, so that we can move on as quick
	# as possible to kicking off the boot animation. otherwise it appears that
	# the system has frozen. we'll wait for the purging to finish before
	# switching root (see 'wait' call further down).
	[ -n "$to_purge" ] || return 0

	echo "Purging old versions, boot may be slightly delayed..."
	rm -rf $to_purge 1>&2 &

	# let the delete process get a head-start, as we might move on to
	# creating a mass of hard-links in parallel
	sleep 0.5
}

purge_configs() {
	[ -e $NEWROOT/versions/boot -a -e $NEWROOT/versions/configs ] || return

	# clean all configs except for the one being used to boot
	local boot_ver=$(basename $(readlink $NEWROOT/versions/boot))

	# XXX can't use globs here because dash doesn't support null globbing
	oIFS=$IFS
	IFS="
"
	for ent in $(ls $NEWROOT/versions/configs); do
		[ "$ent" = "$boot_ver" ] && continue
		to_purge="$to_purge $NEWROOT/versions/configs/$ent"
	done
	IFS=$oIFS
}

# Free up space for update by removing old or incomplete versions.
delete_old_versions() {
	local current=$1
	[ -e "$NEWROOT/versions/sticky/$current" ] && return 0

	to_purge=""
	purge_versions "$current" $NEWROOT/versions/pristine
	purge_versions "$current" $NEWROOT/versions/run
	purge_versions "$current" $NEWROOT/versions/contents
	purge_versions "$current" /bootpart/boot-versions
	purge_configs
	do_purge

	return 0
}

# set global variable $current to the 'short name' for the image we should
# boot, or None if the filesystem is not upgradable.
get_current() {
	local retcode
	local _current
	if is_partitioned; then
		_current=$(get_current_partitioned)
		retcode=$?
	else
		_current=$(get_current_unpartitioned)
		retcode=$?
	fi

	[ $retcode = 0 ] || return $retcode

	# empty return value means filesystem is not versioned
	[ -n "$_current" ] || return 0

	delete_old_versions "$_current"

	# check that /versions/run/$_current exists; create if needed.
	if ! [ -d "$NEWROOT/versions/run/$_current" ]; then
		# redirect stdout to stderr so that it doesn't interfere with the
		# return value of this function (which has to be just an OS hash)
		echo "Shallow-copy version $_current..." >&2
		local run_path="$NEWROOT/versions/run/$_current"
		local pristine_path="$NEWROOT/versions/pristine/$_current"
		local tmp_path="$NEWROOT/versions/run/tmp.$_current"
		rm -rf "$run_path" "$tmp_path"
		mkdir -p "$run_path"
		/usr/libexec/initramfs-olpc/cprl "$pristine_path" "$tmp_path"
		mv "$tmp_path" "$run_path"
	fi

	# create 'running' symlink

	# trac #5317: only create symlink if necessary
	if [ -h "$NEWROOT/versions/running" -a "$(readlink $NEWROOT/versions/running)" = "pristine/$_current" ]; then
		current=$_current
		return 0
	fi

	# make symlink
	rm -f "$NEWROOT/versions/running" # ignore error
	ln -s "pristine/$_current" "$NEWROOT/versions/running" || return 1
	current=$_current
	return 0
}


get_current_partitioned() {
	local target dir

	[ -h /bootpart/boot -a -d /bootpart/boot-versions ] || return 0

	# read hash from /bootpart/boot symlink
	target=$(readlink /bootpart/boot)
	dir=$(dirname "$target")
	[ "$dir" != "boot-versions" ] && return 1

	basename $target
	return 0
}

get_current_unpartitioned() {
	local target dir current
	[ -h "$NEWROOT/versions/boot/current" ] || return 0

	# the 'current' symlink is of the form /versions/pristine/<hash>
	# we want to return <hash>
	target=$(readlink "$NEWROOT/versions/boot/current")
	dir=$(dirname "$target")
	current=$(basename "$target")
	[ "$dir" != "/versions/pristine" -a "$dir" != "/versions/run" -a "$dir" != "../../run" ] && return 1

	echo $current
	return 0
}

ensure_dev() {
	# params: dev type maj min
	[ -e "$1/dev/$2" ] || mknod "$1/dev/$2" $3 $4 $5
}

start_bootanim() {
	[ -x "$1/usr/sbin/plymouthd" ] || return

	# Only enable graphical boot if DCON is frozen at this point
	local dcon_state=$(cat /sys/devices/platform/dcon/freeze)
	[ "$dcon_state" = "1" ] || return

	mount -t proc proc "$1"/proc
	mount -t sysfs syfs "$1"/sys

	# we need certain dev nodes (created below, if needed). we could just
	# remount the root partition read-write and put them on disk, but an
	# easier option is just to put our "udev" mount there insetad

	mount --bind /dev "$1"/dev
	# XXX might want to bind-mount /home here to allow early
	# bootanim customization

	ensure_dev "$1" fb0 c 29 0
	ensure_dev "$1" console c 5 1
	ensure_dev "$1" tty1 c 4 1
	ensure_dev "$1" tty2 c 4 2
	ensure_dev "$1" ptmx c 5 2

	export FRAMEBUFFER=/dev/fb0
	mkdir -p -m 0755 "$1"/run/plymouth
	chroot "$1" /sbin/plymouthd --kernel-command-line="rhgb" --pid-file /run/plymouth/pid
	chroot "$1" /bin/plymouth show-splash
	echo 0 > /sys/devices/platform/dcon/freeze

	umount "$1"/proc
	umount "$1"/sys
	umount "$1"/dev
}

should_resize_system() {
	if ! is_partitioned; then
		echo "System isn't partitioned, won't resize" > /dev/kmsg
		return 1
	fi
	if [ -e "/bootpart/security/no-resize" ]; then
		echo "Won't resize, no-resize flag exists" > /dev/kmsg
		return 1
	fi

	local root_dev=${root#block:}
	local sys_part=$(basename $(readlink -f $root_dev))
	local sys_disk=${sys_part%p?}

	if ! [ "${sys_disk:0:3}" = "mmc" ]; then
		echo "Won't resize, disk ${sys_disk} not mmc" > /dev/kmsg
		return 1
	fi

	local disk_size=$(cat /sys/class/block/$sys_disk/size)
	local part_size=$(cat /sys/class/block/$sys_part/size)
	local part_start=$(cat /sys/class/block/$sys_part/start)
	local part_end=$(( part_start + part_size ))

	echo "Dsize $disk_size Psize $part_size Pstart $part_start Pend $part_end" > /dev/kmsg

	[ "$part_end" = "$disk_size" ] && return 1
	echo "Disk should be resized." > /dev/kmsg
	return 0
}

resize_system()
{
	local sys_disk=${root#block:}
	sys_disk=${sys_disk%p?}
	local strlen=${#root}
	local offset=$(( strlen - 1 ))
	local partnum=${root:$offset}
	echo "Try resize: sfdisk -N$partnum -uS -S 32 -H 32 $sys_disk" > /dev/kmsg
	echo ",+,," | sfdisk -N$partnum -uS -S 32 -H 32 $sys_disk &>/dev/kmsg
	echo "sfdisk returned $?" > /dev/kmsg

	# Partition nodes are removed and recreated now - wait for udev to finish
	# recreating them before trying to re-mount the disk.
	udevadm settle
}

# XXX mount gives a warning if there's no fstab
echo "" >> /etc/fstab

# Dracut lands us here with $NEWROOT as read-only.
# XXX Here we should run fsck and update the boot anim accordingly, etc.
# Now make writable, since some of our stuff needs it
mount -o remount,rw "$NEWROOT" || die

# we also need the boot partition available
mount_boot

# check private security dir
check_stolen

# should we resize the system partition?
if should_resize_system; then
	echo "Will attempt resize" > /dev/kmsg
	unmount_boot
	umount "$NEWROOT"
	resize_system
	mount -t "$fstype" "${root#block:}" "$NEWROOT" || die
	mount_boot
fi

# if we're activating, we just received a lease that we should write to disk
# sooner rather than later
if [ -n "$olpc_write_lease" ]; then
	if is_partitioned; then
		dir="/bootpart/security"
	else
		dir="$NEWROOT/security"
	fi
	mkdir -p $dir || die
	if echo "$olpc_write_lease" | grep -q "^rtc" ; then
		path="rtcreset.sig"
	else
		path="lease.sig"
	fi
	echo "$olpc_write_lease" > "$dir/$path" || die

	if [ $path = "rtcreset.sig" ]; then
		is_partitioned && unmount_boot
		umount $NEWROOT
		reboot -f
	fi
fi


# launch pretty boot asap
# this covers the "regular" filesystem layout
start_bootanim "$NEWROOT"

get_current || die
if [ -n "$current" ]; then
	newroot=$NEWROOT/versions/run/$current

	# use a little magic to turn our $newroot point into an actual mount
	# point. this is needed because switch_root only works with mount
	# points, and more importantly it lets us remount / read-only during
	# shutdown (#9629)
	oldroot=$NEWROOT
	NEWROOT=/vsysroot
	mkdir -p $NEWROOT || die
	mount --bind $newroot $NEWROOT || die

	# launch pretty boot
	# this covers the "upgradable" filesytem layout with /versions etc.
	# we have to do this after sorting out the bind mount, if we run it on
	# $oldroot then the $oldroot unmount will fail below (not exactly sure why)
	start_bootanim $NEWROOT

	# now that we've indicated some progress, wait for any old version purging
	# (via delete_old_versions) to complete
	wait

	# create some bind mounts
	# we do this with the original root writable, because bind mounting copies
	# over the mount options.
	for frag in home versions; do
		# ignore failures here: a debian installation (say) may not have
		# these dirs.
		mount --bind "$oldroot/$frag" "$NEWROOT/$frag"
	done

	if is_partitioned; then
		mount --bind /bootpart/security "$NEWROOT/security"
	else
		mount --bind "$oldroot/security" "$NEWROOT/security"
	fi

	# now we don't need the old root for anything else
	umount $oldroot || die
fi

is_partitioned && unmount_boot

unset check_stolen ensure_dev start_bootanim
unset die
