#!/bin/bash
check() {
	return 255
}

install() {
	old_ifs=$IFS
	IFS="
	"
	for line in $(<"$moddir"/python-contents.txt); do
		inst $line
	done
	IFS=$old_ifs
}
