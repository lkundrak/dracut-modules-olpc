AUTOMAKE_OPTIONS = foreign dist-bzip2 no-dist-gzip
SUBDIRS = 30olpc-boot 30olpc-customization 30olpc-python 30olpc-common 30olpc-activation 95olpc-mtd cprl act-gui ipv6util
DISTCLEANFILES = ChangeLog
dist_sysconf_DATA = dracut-olpc-actrd.conf dracut-olpc-runrd.conf

ChangeLog:
	git --git-dir $(top_srcdir)/.git log > ChangeLog || touch ChangeLog
.PHONY: ChangeLog

dist-hook: ChangeLog
