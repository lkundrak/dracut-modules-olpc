dmoddir = $(DRACUT_MODDIR)/30olpc-boot
dist_dmod_SCRIPTS = check_ install_ activate.py greplease.py
dist_dmod_DATA = olpc-boot-premount.sh olpc-boot-prepivot.sh \
	olpc-boot-cmdline.sh

# Ugh. automake doesnt like files called "install" or "check" because it
# provides default rules with those names.
install-data-hook:
	mv $(DESTDIR)/$(dmoddir)/check{_,}
	mv $(DESTDIR)/$(dmoddir)/install{_,}

uninstall-hook:
	rm -f $(DESTDIR)/$(dmoddir)/{check,install}

