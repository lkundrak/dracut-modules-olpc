# On a recent enough kernel, we cold match the bootpath against MMC controller's of_node
if [ -z "$root" ]; then
	tmp=$(sed 's,\(/.*\)/disk:.*,\1,' </sys/firmware/devicetree/base/chosen/bootpath)
	tmp=$(udevadm trigger --dry-run --verbose --property-match=OF_FULLNAME="${tmp}")
	tmp=$(find "${tmp}" -name block -exec ls '{}' \;)
	test -b "/dev/${tmp}p2" && root="/dev/${tmp}p2"
fi
