#!/bin/bash

check() {
	return 255
}

depends() {
	echo "olpc-python olpc-common olpc-boot"
	return 0
}

install() {
	dracut_install iwconfig
	dracut_install iwlist
	dracut_install ip

	python_libdir=$(python -c "from distutils.sysconfig import get_python_lib; print get_python_lib(1)")

	for i in activate.py greplease.py olpc_act_gui_server.py; do
		inst "$moddir"/"$i" /usr/libexec/initramfs-olpc/"$i"
	done

	inst "$moddir"/olpc_act_gui_client.py "$python_libdir"/olpc_act_gui_client.py

	for i in pyvt.so pyfb.so ipv6util.so; do
		inst /usr/lib/dracut-modules-olpc/"$i" "$python_libdir"/"$i"
	done

	for i in "$moddir"/act-gui-images/*; do
		inst "$i" /usr/share/olpc-act-gui/images/$(basename "$i")
	done

	dracut_install "$python_libdir"/bitfrost/__init__.py
	dracut_install "$python_libdir"/bitfrost/leases/__init__.py
	dracut_install "$python_libdir"/bitfrost/leases/core.py
	dracut_install "$python_libdir"/bitfrost/leases/keys.py
	dracut_install "$python_libdir"/bitfrost/leases/crypto.py
	dracut_install "$python_libdir"/bitfrost/leases/errors.py
	dracut_install "$python_libdir"/bitfrost/util/__init__.py
	dracut_install "$python_libdir"/bitfrost/util/json.py
	dracut_install "$python_libdir"/bitfrost/util/pyverify.so

	instmods vfat usb_storage usb8xxx libertas libertas_sdio ohci_hcd ehci_hcd sdhci sd
	dracut_install -o /lib/firmware/usb8388.bin
	dracut_install -o /lib/firmware/sd8686.bin
	dracut_install -o /lib/firmware/sd8686_helper.bin

	inst "$moddir"/filesystems /etc/filesystems
	inst "$moddir"/udhcpc.script /usr/share/udhcpc/default.script

	for _dir in "$usrlibdir/tls/$_arch" "$usrlibdir/tls" "$usrlibdir/$_arch" \
		"$usrlibdir" "$libdir"; do
		[ -e "$_dir"/libnss_dns.so.* ] && dracut_install "$_dir"/libnss_dns.so.*
	done

}
