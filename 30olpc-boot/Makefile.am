dmoddir = $(DRACUT_MODDIR)
dist_dmod_SCRIPTS = check_ install_ activate.py
dist_dmod_DATA = python-contents.txt \
	olpc-boot-premount.sh olpc-boot-prepivot.sh \
	upfs.py

dist_noinst_SCRIPTS = list-python-files.sh

# Ugh. automake doesnt like files called "install" or "check" because it
# provides default rules with those names.
install-data-hook:
	mv $(DESTDIR)/$(DRACUT_MODDIR)/check{_,}
	mv $(DESTDIR)/$(DRACUT_MODDIR)/install{_,}

uninstall-hook:
	rm -f $(DESTDIR)/$(DRACUT_MODDIR)/{check,install}

