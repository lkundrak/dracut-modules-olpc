if [ "${root%%:*}" = "mtd" ]; then
	dev=/dev/mtd${root#mtd:}
	echo '[ -e $dev ]' > $hookdir/initqueue/finished/block.sh
fi

