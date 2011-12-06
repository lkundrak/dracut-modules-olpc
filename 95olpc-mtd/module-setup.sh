#!/bin/bash
check() {
	return 255
}

install() {
	dracut_install umount
	inst_hook cmdline 95 "$moddir/parse-mtd.sh"
	inst_hook pre-udev 30 "$moddir/mtd-genrules.sh"
	inst_hook mount 99 "$moddir/mount-mtd.sh"
}
