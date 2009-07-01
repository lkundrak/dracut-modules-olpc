#include <assert.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <sys/mman.h>
#include <zlib.h>
#include "fbutil.h"

/* object-oriented-ish abstraction for writing compressed image
 * formats as if they were uncompressed. */
struct _put_ops {
    /* set up any local state for decompression, returning it via 'state' */
    int (*init)(void **state, struct image *image);
    /* write 'n' bytes starting at 'dest' from offset 'src-image->pixel_data'
     * of the source image. */
    int (*copy)(void *state, void *dest, const void *src, size_t n);
    /* deallocate & clean up 'state'. */
    int (*finish)(void *state);
};
extern struct _put_ops _std_ops, _z_ops; /* forward declaration. */

int fb_open(char *devname, struct fbinfo *fbi) {
    unsigned long screensize;
    int st;
    /* Open the file for reading and writing */
    fbi->fd = open(devname, O_RDWR);
    assert(fbi->fd);
    /* Get fixed screen information */
    st = ioctl(fbi->fd, FBIOGET_FSCREENINFO, &fbi->finfo);
    assert(!st);
    assert(fbi->finfo.type == FB_TYPE_PACKED_PIXELS);
    assert(fbi->finfo.visual == FB_VISUAL_TRUECOLOR);
    /* Get variable screen information */
    st = ioctl(fbi->fd, FBIOGET_VSCREENINFO, &fbi->vinfo);
    assert(!st);
    assert(fbi->vinfo.bits_per_pixel == 16);
    assert(!fbi->vinfo.grayscale);
    /* 565 color */
    assert(fbi->vinfo.red.offset == 11);
    assert(fbi->vinfo.red.length == 5);
    assert(!fbi->vinfo.red.msb_right);
    assert(fbi->vinfo.green.offset == 5);
    assert(fbi->vinfo.green.length == 6);
    assert(!fbi->vinfo.green.msb_right);
    assert(fbi->vinfo.blue.offset == 0);
    assert(fbi->vinfo.blue.length == 5);
    assert(!fbi->vinfo.blue.msb_right);
    assert(fbi->vinfo.transp.length == 0); /* no alpha */
    /* Figure out the size of the screen in bytes */
    screensize =
	fbi->vinfo.xres * fbi->vinfo.yres * fbi->vinfo.bits_per_pixel / 8;
    /* Map the device to memory */
    fbi->map = mmap(0, screensize, PROT_READ | PROT_WRITE, MAP_SHARED,
		   fbi->fd, 0);
    assert(fbi->map != MAP_FAILED);
    /* success! */
    return 0;
}

void fb_put(struct fbinfo *fbi, int xoff, int yoff, struct image *image) {
    int y;
    void *put_state;
    struct _put_ops *ops;
    int st;
    ops = IMAGE_IS_COMPRESSED(image) ? (&_z_ops) : (&_std_ops);
    st = ops->init(&put_state, image);
    if (st) return; /* error, bail. */
    /* copy the pic */
    for (y=0; y < image->height; y++) {
	int len, x0, x1, sx0, sx1, sy;
	sy = y + yoff;
	if (sy < 0 || sy >= fbi->vinfo.yres) continue;
	/* memcpy a full row */
	x0 = 0; sx0 = x0 + xoff;
	x1 = image->width; sx1 = x1 + xoff;
	if (sx0 < 0) { x0 -= sx0; sx0 = 0; }
	if (sx1 > fbi->vinfo.xres) { int diff = sx1 - fbi->vinfo.xres; x1 -= diff; sx1 -= diff; }
	st = ops->copy
	    (put_state,
	     fbi->map +
	     (sx0 + fbi->vinfo.xoffset) * (fbi->vinfo.bits_per_pixel/8) +
	     (sy + fbi->vinfo.yoffset) * fbi->finfo.line_length,
	     image->pixel_data + x0 + y * image->width,
	     sizeof(uint16_t) * (x1 - x0));
	if (st) break; /* error, bail. */
    }
    ops->finish(put_state); /* deallocate; clean up. */
}

void fb_close(struct fbinfo *fbi) {
    unsigned long screensize;
    screensize =
	fbi->vinfo.xres * fbi->vinfo.yres * fbi->vinfo.bits_per_pixel / 8;
    munmap(fbi->map, screensize);
    close(fbi->fd);
}

/* ------- operations on uncompressed images (booooring) -------- */
static int _ps_init(void **state, struct image *image) {
    return 0; /* no-op */
}
static int _ps_copy(void *state, void *dest, const void *src, size_t n) {
    memcpy(dest, src, n); /* simply wrap memcpy */
    return 0; /* always successful. */
}
static int _ps_finish(void *state) {
    return 0; /* no-op. */
}
struct _put_ops _std_ops = {
    .init = _ps_init,
    .copy = _ps_copy,
    .finish=_ps_finish,
};

/* ------- operations on compressed images (zlib, yay!) -------- */
struct _z_state {
    z_stream strm; /* zlib context */
    const void *lastread; /* allows copy to 'skip ahead' in the image */
};
static int _ps_finish_z(void *state); /* forward declaration */
static int _ps_init_z(void **state, struct image *image) {
    struct _z_state *zs;
    unsigned int image_zsize;
    int st;
    *state = zs = malloc(sizeof(*zs));
    assert(zs);
    memset(zs, 0, sizeof(*zs));
    image_zsize = ((unsigned int *) image->pixel_data)[0];
    zs->strm.next_in = (void*) &(((unsigned int *) image->pixel_data)[1]);
    zs->strm.avail_in = image_zsize;
    zs->lastread = image->pixel_data; /* virtual stream pointer */
    st = inflateInit(&(zs->strm));
    if (st != Z_OK) {
	/* yuck, clean up */
	_ps_finish_z(zs);
	return 1; /* bail! */
    }
    return 0; /* success */
}
static int _ps_copy_z(void *state, void *dest, const void *src, size_t n) {
    struct _z_state *zs = (struct _z_state *) state;
    char buf[n]; /* temporary storage for decompressed image data */
    int st;
    assert(zs->lastread);
    assert(src >= zs->lastread);
    if (src > zs->lastread) {
	/* need to discard some data */
	char buf2[src - zs->lastread];
	zs->strm.next_out = buf2;
	zs->strm.avail_out = sizeof(buf2);
	st = inflate(&(zs->strm), Z_SYNC_FLUSH);
	if (st != Z_OK) return 1; /* error */
	zs->lastread = src;
    }
    /* although it might seem like it would be faster to set
     * zs->strm.next_out directly to 'dest' and decompress directly
     * to the screen, in actual fact unaligned byte-wise writes to the
     * frame buffer are slooow and it's faster if we decompress to a buffer
     * and then memcpy the buffer to the screen. */
    zs->strm.next_out = buf;
    zs->strm.avail_out = n;
    st = inflate(&(zs->strm), Z_SYNC_FLUSH);
    if (st == Z_STREAM_END)
	zs->lastread = NULL; /* indicate no more image data. */
    else if (st != Z_OK) return 1; /* error */
    /* update zs->lastread */
    zs->lastread = src + n;
    /* finally, blit to screen */
    memcpy(dest, buf, n);
    return 0; /* success. */
}
static int _ps_finish_z(void *state) {
    struct _z_state *zs = (struct _z_state *) state;
    inflateEnd(&(zs->strm));
    free(zs);
    return 0; /* always successful. */
}

struct _put_ops _z_ops = {
    .init = _ps_init_z,
    .copy = _ps_copy_z,
    .finish=_ps_finish_z,
};
