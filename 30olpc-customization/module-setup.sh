#!/bin/bash
check() {
	return 255
}

depends() {
	echo "olpc-python olpc-common udev-rules"
}

install() {
	dracut_install poweroff mount umount unzip modprobe

	mkdir -p "$initdir"/sysroot
	mkdir -p "$initdir"/sys
	mkdir -p "$initdir"/mnt/usb

	instmods vfat usb_storage ohci_hcd ehci_hcd sdhci sd

	inst "$moddir"/unpack.py /init
	inst "$moddir"/process.py /process.py
}
