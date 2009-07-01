"""IPv6 utility bindings."""
cdef extern from "net/if.h":
    int _if_nametoindex "if_nametoindex" (char *ifname)

def if_nametoindex(ifname):
    return _if_nametoindex(ifname)
