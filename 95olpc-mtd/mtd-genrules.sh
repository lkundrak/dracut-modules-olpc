if [ "${root%%:*}" = "mtd" ]; then
	dev=/dev/mtd${root#mtd:}
	echo "[ -e $dev ]" > /initqueue-finished/mtd.sh
fi

