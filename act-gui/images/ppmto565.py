#!/usr/bin/python
"""Convert ppm-format files to XO-1 native 565 format."""
from __future__ import division, with_statement
import sys

def eat_comment(inf): # just read #, read until next EOL
    while True:
        c = inf.read(1)
        if c == '\n' or c == '\r': break # read to EOL
    return c

def read_token(inf):
    # eat up leading whitespace
    while True:
        c = inf.read(1)
        if c == '#': eat_comment(inf)
        elif not c.isspace(): break
    # now read in non-whitespace.
    s = c
    while True:
        c = inf.read(1)
        if c == '#': c = eat_comment(inf)
        if c.isspace(): break
        s += c
    # done!
    return s

def main(inf, outf, compress=False):
    import struct
    # read ppm from input
    magic = inf.read(2)
    assert magic == 'P6'
    width = int(read_token(inf))
    height = int(read_token(inf))
    maxval = int(read_token(inf))
    unpackstr = '!3B' if maxval < 256 else '!3H'
    unpacklen = struct.calcsize(unpackstr)
    # write header
    outf.write(struct.pack('@III', width, height, 1 if compress else 0))
    if compress:
        from zlib import compressobj
        off0 = outf.tell()
        # we'll come back and fill in the next field later w/ the right size.
        outf.write(struct.pack('@I', 0))
        off1 = outf.tell()
        comp = compressobj(9)
        encode_me = lambda bytes: comp.compress(bytes)
    else:
        encode_me = lambda bytes: bytes
    # read pixel data, convert, and write it to output
    def scale(x, y): return int((y*x/maxval)+0.5)
    for y in xrange(0, height):
        for x in xrange(0, width):
            red, green, blue = struct.unpack(unpackstr, inf.read(unpacklen))
            encoded = (scale(red, 0x1f) << 11) + \
                      (scale(green, 0x3f) << 5) + \
                      (scale(blue, 0x1f))
            outf.write(encode_me(struct.pack('@H', encoded)))
    if compress:
        outf.write(comp.flush())
        # go back and write the proper file size.
        off2 = outf.tell()
        outf.seek(off0)
        outf.write(struct.pack('@I', off2-off1))

if __name__ == '__main__':
    from optparse import OptionParser
    import sys
    parser = OptionParser()
    parser.add_option('-o','--output',default=None,dest='output',
                      metavar='FILE', help='output file name.')
    parser.add_option('-z','--compress',action='store_true',dest='compress',
                      help='use compressed image format')
    (options, args) = parser.parse_args()
    if options.compress and options.output is None:
        parser.error('Output file name required when writing '+
                     'compressed format.')
    infile = open(args[0]) if args else sys.stdin
    outfile = open(options.output, 'w') if options.output else sys.stdout
    main(infile, outfile, options.compress)
