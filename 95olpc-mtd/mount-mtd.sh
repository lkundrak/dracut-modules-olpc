. /lib/dracut-lib.sh

if [ -n "$root" -a -z "${root%%mtd:*}" ]; then
	mount -t ${fstype:-auto} -o "$rflags" "mtd${root#mtd:}" $NEWROOT \
		&& ROOTFS_MOUNTED=yes
fi
