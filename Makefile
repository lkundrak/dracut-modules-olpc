PACKAGE=dracut-modules-olpc
MOCK=./mock-wrapper -r fedora-11-i386 --resultdir=$(MOCKDIR)
MOCKDIR=./rpms
VERSION=0.1
VERSION_RELEASE=1
PKGVER=$(PACKAGE)-$(VERSION)
CWD=$(shell pwd)

# note that this builds the tarball from *committed git bits* only.
# do a git commit before invoking this.
$(PKGVER).tar.bz2:
	git diff --shortstat --exit-code # check that our working copy is clean
	git diff --cached --shortstat --exit-code # uncommitted changes?
	git archive --format=tar --prefix=$(PKGVER)/ HEAD | bzip2 > $@
.PHONY: $(PKGVER).tar.bz2 # force refresh

# make the SRPM.
rpms: $(PKGVER).tar.bz2
	rpmbuild --define "_specdir $(CWD)" --define "_sourcedir $(CWD)" --define "_builddir $(CWD)" --define "_srcrpmdir $(CWD)" --define "_rpmdir $(CWD)" -ba $(PACKAGE).spec

