#!/bin/bash

check() {
	return 255
}

depends() {
	echo "olpc-python olpc-common olpc-boot"
	return 0
}

install() {
	dracut_install iw
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

	instmods vfat usb_storage
	instmods usb8xxx libertas libertas_sdio mwifiex mwifiex_sdio
	instmods ohci_hcd ehci_hcd sdhci sd
	# instmods installs all Marvell firmware, but we have our own logic
	# to decide which firmware to include.
	rm -rf "$initdir"/lib/firmware/{libertas,mrvl}

	if [ -z "$OLPC_WIFI_FW_SELECT" ]; then
		OLPC_WIFI_FW_8388=1
		OLPC_WIFI_FW_8686=1
		OLPC_WIFI_FW_8787=1
	fi

	[ -n "$OLPC_WIFI_FW_8388" ] && lbs_fw+=" libertas/usb8388_olpc.bin"
	[ -n "$OLPC_WIFI_FW_8686" ] && lbs_fw+=" libertas/sd8686_v9.bin libertas/sd8686_v9_helper.bin"
	[ -n "$OLPC_WIFI_FW_8787" ] && lbs_fw+=" mrvl/sd8787_uapsta.bin"

	for fw in $lbs_fw; do
		dracut_install -o /lib/firmware/${fw}
	done

	inst "$moddir"/udhcpc.script /usr/share/udhcpc/default.script

	for _dir in "$usrlibdir/tls/$_arch" "$usrlibdir/tls" "$usrlibdir/$_arch" \
		"$usrlibdir" "$libdir"; do
		[ -e "$_dir"/libnss_dns.so.* ] && dracut_install "$_dir"/libnss_dns.so.*
	done

}
