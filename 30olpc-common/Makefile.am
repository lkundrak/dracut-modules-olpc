dmoddir = $(DRACUT_MODDIR)/30olpc-common
dist_dmod_SCRIPTS = install_
dist_dmod_DATA = olpc-sd.rules olpc-net.rules

# Ugh. automake doesnt like files called "install" or "check" because it
# provides default rules with those names.
install-data-hook:
	mv $(DESTDIR)/$(dmoddir)/install{_,}

uninstall-hook:
	rm -f $(DESTDIR)/$(dmoddir)/{install}

