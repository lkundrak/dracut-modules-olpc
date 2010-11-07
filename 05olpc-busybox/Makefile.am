dmoddir = $(DRACUT_MODDIR)/05olpc-busybox
dist_dmod_SCRIPTS = check_ install_

# Ugh. automake doesnt like files called "install" or "check" because it
# provides default rules with those names.
install-data-hook:
	mv $(DESTDIR)/$(dmoddir)/check{_,}
	mv $(DESTDIR)/$(dmoddir)/install{_,}

uninstall-hook:
	rm -f $(DESTDIR)/$(dmoddir)/{check,install}

