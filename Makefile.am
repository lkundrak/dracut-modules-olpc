AUTOMAKE_OPTIONS = foreign dist-bzip2 no-dist-gzip
SUBDIRS = 30olpc-boot 30olpc-customization 30olpc-python 30olpc-common cprl act-gui ipv6util
DISTCLEANFILES = dracut-modules-olpc.spec ChangeLog
CWD=$(shell pwd)

rpms:
	rpmbuild --clean --define "_specdir $(CWD)" --define "_sourcedir $(CWD)" --define "_builddir $(CWD)" --define "_srcrpmdir $(CWD)" --define "_rpmdir $(CWD)" -ba dracut-modules-olpc.spec
.PHONY: rpms

ChangeLog:
	git --git-dir $(top_srcdir)/.git log > ChangeLog || touch ChangeLog
.PHONY: ChangeLog

dist-hook: ChangeLog
