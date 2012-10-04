#!/bin/bash
check() {
	return 255
}

install() {
	mkdir -p "$initdir"/etc/udev/rules.d
	inst "$moddir"/olpc-sd.rules /etc/udev/rules.d/10-olpc-sd.rules
	inst "$moddir"/olpc-net.rules /etc/udev/rules.d/10-olpc-net.rules
	inst "$moddir"/olpc_eth_namer /lib/udev/olpc_eth_namer

	# Disable dracut's fstab-checking, not appropriate for us (#10394)
	# Disable emergency shell by default.
	mkdir -p ${initdir}/etc
	echo " rd.fstab=0 rd.shell=0 fastboot" >> ${initdir}/etc/cmdline
}
