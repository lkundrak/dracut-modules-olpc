#!/bin/bash
check() {
	return 255
}

install() {
	mkdir -p "$initdir"/etc/udev/rules.d
	inst "$moddir"/olpc-sd.rules /etc/udev/rules.d/10-olpc-sd.rules
	inst "$moddir"/olpc-net.rules /etc/udev/rules.d/10-olpc-net.rules
}