dmoddir = $(DRACUT_MODDIR)/30olpc-activation
dist_dmod_SCRIPTS = check_ install_ activate.py greplease.py

# Ugh. automake doesnt like files called "install" or "check" because it
# provides default rules with those names.
install-data-hook:
	mv $(DESTDIR)/$(dmoddir)/check{_,}
	mv $(DESTDIR)/$(dmoddir)/install{_,}

uninstall-hook:
	rm -f $(DESTDIR)/$(dmoddir)/{check,install}

