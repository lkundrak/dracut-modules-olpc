AUTOMAKE_OPTIONS = foreign dist-bzip2 no-dist-gzip
SUBDIRS = 05olpc-busybox 30olpc-boot 30olpc-customization 30olpc-python 30olpc-common 30olpc-activation cprl act-gui ipv6util
DISTCLEANFILES = ChangeLog
CWD=$(shell pwd)

ChangeLog:
	git --git-dir $(top_srcdir)/.git log > ChangeLog || touch ChangeLog
.PHONY: ChangeLog

dist-hook: ChangeLog
