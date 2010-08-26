#!/usr/bin/python

import re, mmap

# grep through a JSON-formatted file with mmap
# and return the appropriate leases
# for a given sn.
# Avoids huge in-memory footprint of
# reading large JSON files -- lease.sig
# files can be very large.
def grep(fpath, sn):
    """Search a potentially larger-than-mem cjson file for
       something that looks like a lease or a series of leases.

       Uses mmap.

       returns a string or False
       """
    import mmap
    fh = open(fpath, 'r')
    m = mmap.mmap(fh.fileno(), 0, mmap.MAP_SHARED, mmap.PROT_READ)

    # find the start of it
    rx = re.compile('"'+sn+'":"')
    objkey = rx.search(m)

    if objkey:
        # find the tail - the first non-escaped
        # doublequotes. This relies on sigs not
        # having escape chars themselves.
        # TODO: Negative look-behind assertion to handle
        # escaped values.
        rx = re.compile('"')
        objend = rx.search(m, objkey.end())

    if objkey and objend:
        found = m[objkey.end():objend.start()]
    else:
        found = False

    m.close()
    fh.close()

    return found





