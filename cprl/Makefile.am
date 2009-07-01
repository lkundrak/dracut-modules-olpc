cprldir = $(DRACUT_MODDIR)
cprl_PROGRAMS = cprl.so

cprl_so_SOURCES = cprl.h
nodist_cprl_so_SOURCES = cprl.c
cprl_so_LDADD = $(PY_LIBS)
cprl_so_LDFLAGS = $(PY_LDFLAGS) $(AM_LDFLAGS)
cprl_so_CFLAGS = $(PY_CFLAGS) $(AM_CFLAGS)

cprl.c: cprl.pyx
	pyrexc -o $@ $<

EXTRA_DIST = cprl.pyx
MOSTLYCLEANFILES = cprl.c
