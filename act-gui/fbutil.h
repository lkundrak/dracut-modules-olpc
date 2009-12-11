#ifndef FBUTIL_INCLUDED
#define FBUTIL_INCLUDED

#include <stdint.h>
#include <linux/fb.h>

/* convert from 565 to ARGB */
#define TOARGB(s)  (0xff070307 | (((s) >> 11) << 19) | ((s & 0x07e0) << 5) | ((s & 0x001f) << 3))

struct fbinfo {
    int fd;
    void *map;
    struct fb_var_screeninfo vinfo;
    struct fb_fix_screeninfo finfo;
};
struct image {
    unsigned int width;
    unsigned int height;
    unsigned int flags;
    uint16_t pixel_data[0];
};
#define IMAGE_IS_COMPRESSED(img) (((img)->flags)&1)

int fb_open(char *devname, struct fbinfo *fbi);
void fb_put(struct fbinfo *fbi, int xoff, int yoff, struct image *image);
void fb_close(struct fbinfo *fbi);

#endif /* FBUTIL_INCLUDED */
