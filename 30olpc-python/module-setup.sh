#!/bin/bash
check() {
	return 255
}

install() {
	old_ifs=$IFS
	new_ifs="
	"
	IFS=$new_ifs
	for line in $(<"$moddir"/python-contents.txt); do
		# Must restore regular IFS inside loop as it is used by inst
		IFS=$old_ifs
		inst $line
		IFS=$new_ifs
	done
	IFS=$old_ifs
}
