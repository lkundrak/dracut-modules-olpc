AUTOMAKE_OPTIONS = foreign dist-bzip2 no-dist-gzip
SUBDIRS = 30olpc-boot cprl act-gui
DISTCLEANFILES = dracut-modules-olpc.spec
CWD=$(shell pwd)

rpms: dist
	rpmbuild --clean --define "_specdir $(CWD)" --define "_sourcedir $(CWD)" --define "_builddir $(CWD)" --define "_srcrpmdir $(CWD)" --define "_rpmdir $(CWD)" -ba dracut-modules-olpc.spec
.PHONY: rpms

