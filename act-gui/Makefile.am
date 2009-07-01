SUBDIRS = images
dmoddir = $(DRACUT_MODDIR)
dmod_PROGRAMS = pyfb.so pyvt.so
dist_dmod_SCRIPTS = olpc_act_gui_server.py
dist_dmod_DATA = olpc_act_gui_client.py

nodist_pyfb_so_SOURCES = pyfb.c
pyfb_so_SOURCES = fbutil.c fbutil.h
pyfb_so_LDADD = $(PY_LIBS)
pyfb_so_LDFLAGS = $(PY_LDFLAGS) $(AM_LDFLAGS)
pyfb_so_CFLAGS = $(PY_CFLAGS) $(AM_CFLAGS)

nodist_pyvt_so_SOURCES = pyvt.c
pyvt_so_LDADD = $(PY_LIBS)
pyvt_so_LDFLAGS = $(PY_LDFLAGS) $(AM_LDFLAGS)
pyvt_so_CFLAGS = $(PY_CFLAGS) $(AM_CFLAGS)

pyfb.c: pyfb.pyx
	pyrexc -o $@ $<

pyvt.c: pyvt.pyx
	pyrexc -o $@ $<

EXTRA_DIST = pyfb.pyx pyvt.pyx
MOSTLYCLEANFILES = pyfb.c pyvt.c

