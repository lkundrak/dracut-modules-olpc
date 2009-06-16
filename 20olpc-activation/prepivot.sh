#!/bin/sh
# Copyright (C) 2009 One Laptop per Child
# Licensed under the GPLv2
#

check_stolen() {
	# FIXME need write access here

	# XXX: we should provide some way to delete the 'stolen' identifier to
	# XXX: recover the machine.
	if [ -e "$NEWROOT/.private/stolen" ]; then
		# this machine is stolen!  delete activation lease
		rm $NEWROOT/.private/stolen
		sync
		# FIXME test this
		poweroff
	fi
	[ -d "$NEWROOT/.private" ] || mkdir "$NEWROOT/.private"
	[ -d "$NEWROOT/security/.private" ] || mkdir "$NEWROOT/security/.private"
	# mount OATC's private scratch space
	# FIXME: currently never used, so why mount it?
	# mount --bind "$NEWROOT/.private" "$NEWROOT/security/.private"
}

# frob the /current symlink to start from the backup filesystem if requested
# return the 'short name' for the image we should boot, or None if the
# filesystem is not upgradable.
frob_symlink() {
	local target dir current alt config d tmp
	[ -h "$NEWROOT/versions/boot/current" ] || return

	# the 'current' symlink is of the form /versions/pristine/<hash>
	# we want to return <hash>
	target=$(readlink "$NEWROOT/versions/boot/current")
	dir=$(dirname "$target")
	current=$(basename "$target")
	[ "$dir" != "/versions/pristine" -a "$dir" != "/versions/run" -a "$dir" != "../../run" ] && die

	if [[ "$olpc_boot_backup" == "1" ]]; then
		target=$(readlink "$NEWROOT/versions/boot/alt")
		dir=$(dirname "$target")
		alt=$(basename "$target")
		[ "$dir" != "/versions/pristine" -a "$dir" != "/versions/run" -a "$dir" != "../../run" ] && die

		# atomically swap current and alt.
		# FIXME need writable root
		config=$(readlink "$NEWROOT/versions/boot")
		d=$(mktemp -d --tmpdir="$NEWROOT/versions/configs" cfg.XXXXXXXXXX )
		ln -s "/versions/pristine/$alt" "$d/current" || die
		ln -s "/versions/pristine/$current" "$d/alt" || die
		ln -s "${d#$NEWROOT/versions/}" "$NEWROOT/versions/boot.tmp" || die
		sync || die # superstition
		mv "$NEWROOT/versions/boot.tmp" "$NEWROOT/versions/boot" || die
		sync || die # superstition

		# remove old config
		rm -rf "$NEWROOT/$config" || die
		tmp=$current
		current=$alt
		alt=$tmp
	fi

	# check that /versions/run/$current exists; create if needed.
	if ! [ -d "$NEWROOT/versions/run/$current" ]; then
		/usr/libexec/initramfs-olpc/upfs.py $NEWROOT $current thawed || die
	fi

	# create 'running' symlink

	# trac #5317: only create symlink if necessary
	[ -h "$NEWROOT/versions/running" -a "$(readlink $NEWROOT/versions/running)" == "pristine/$current" ] && return

	rm -f "$NEWROOT/versions/running" # ignore error
	ln -s "pristine/$current" "$NEWROOT/versions/running" || die
	echo $current
	return
}

# check private security dir
check_stolen

# launch pretty boot just as soon as possible
# FIXME: how will this fit into everything?
# start_boot_animation('/sysroot')

current=$(frob_symlink)
if [ -n "$current" ]; then
	newroot=$NEWROOT/versions/run/$current
	# launch pretty boot just as soon as possible (upgradable case)
	# FIXME
	# start_boot_animation(newroot)

	# boot_run_xo()
	# FIXME need writable root
	# okay, do the boot!
	# create some bind mounts
	# (do this after making root writable, because newer kernels will
	#  otherwise end up with ro bind mounts against the writable root)
	for frag in home security versions; do
		# ignore failures here: a debian installation (say) may not have
		# these dirs.
		mount --bind "$NEWROOT/$frag" "$NEWROOT/versions/run/$current/$frag"
	done

	NEWROOT="$NEWROOT/versions/run/$current"
fi

