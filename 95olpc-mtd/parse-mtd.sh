case "$root" in
	mtd:*)
		rootok=1 ;;
	mtd[0-9]*)
		root="mtd:${root#mtd}"
		rootok=1 ;;
esac

