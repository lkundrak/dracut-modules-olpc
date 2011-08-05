dmoddir = $(DRACUT_MODDIR)/95olpc-mtd
dist_dmod_SCRIPTS = install_ check_
dist_dmod_DATA = mount-mtd.sh  mtd-genrules.sh  parse-mtd.sh

# Ugh. automake doesnt like files called "install" or "check" because it
# provides default rules with those names.
install-data-hook:
	mv $(DESTDIR)/$(dmoddir)/check{_,}
	mv $(DESTDIR)/$(dmoddir)/install{_,}

uninstall-hook:
	rm -f $(DESTDIR)/$(dmoddir)/{check,install}

