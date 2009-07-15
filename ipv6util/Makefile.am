dmoddir = $(DRACUT_LIBDIR)
dmod_PROGRAMS = ipv6util.so

nodist_ipv6util_so_SOURCES = ipv6util.c
ipv6util_so_LDADD = $(PY_LIBS)
ipv6util_so_LDFLAGS = $(PY_LDFLAGS) $(AM_LDFLAGS)
ipv6util_so_CFLAGS = $(PY_CFLAGS) $(AM_CFLAGS)

ipv6util.c: ipv6util.pyx
	pyrexc -o $@ $<

EXTRA_DIST = ipv6util.pyx
MOSTLYCLEANFILES = ipv6util.c
