# Prevent dracut's fallback to a debug shell under all conditions
# This avoids any possibility of reaching a root shell on a secured laptop
# It can be disabled by developers by adding the olpc.emergency boot parameter

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

if ! getarg olpc.emergency; then
	echo "Emergency condition encountered, halting."
	echo
	echo "To obtain a debug shell on such conditions,"
	echo "boot with the 'olpc.emergency' kernel parameter."
	> /run/initramfs/.die
fi
