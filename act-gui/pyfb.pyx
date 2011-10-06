import os
cdef extern from "fbutil.h":
    struct fb_var_screeninfo:
        int xres
        int yres
        int xres_virtual
        int yres_virtual
    struct fbinfo:
        fb_var_screeninfo vinfo
    struct image:
        int width
        int height
        int flags
        void *pixel_data

    int fb_open(char *devname, fbinfo *fbi)
    void fb_put(fbinfo *fbi, int xoff, int yoff, image *image)
    void fb_close(fbinfo *fbi)

cdef extern from "sys/mman.h":
    ctypedef int size_t
    ctypedef int off_t
    enum:
        MAP_FAILED
        PROT_READ
        MAP_SHARED
    void *mmap(void *start, size_t length, int prot, int flags,
               int fd, off_t offset)
    int munmap(void *start, size_t length)

cdef class Image:
    """Image wrapper."""
    cdef image *i
    #"""Width of the image, in pixels."""
    cdef readonly int width
    #"""Height of the image, in pixels."""
    cdef readonly int height
    #"""Name of this object (python string)."""
    cdef readonly object name
    ###### private ######
    cdef int fd
    cdef int len

    def __cinit__(self, filename, name):
        """Create a wrapped reference to the named image."""
        self.fd, self.i = -1, NULL
        self.fd = os.open(filename, os.O_RDONLY)
        self.len = os.fstat(self.fd).st_size
        self.i = <image *> mmap(NULL, self.len, PROT_READ, MAP_SHARED, self.fd, 0)
        if self.i == <image *>MAP_FAILED: raise RuntimeError('mmap failed')
        self.width = self.i.width
        self.height = self.i.height
        self.name = name
        if (self.i.flags & 1) == 1: # compressed image, verify len
            if (<int *> self.i.pixel_data)[0] != (self.len - 16):
                self.i = NULL
                self.width = 0
                self.height = 0
                raise RuntimeError('bad image data')
        elif self.width * self.height * 2 > self.len:
            # protect ourselves from malformed image files
            self.i = NULL
            self.width = 0
            self.height = 0
            raise RuntimeError('bad image data')
    def __dealloc__(self):
        if self.i != NULL and self.fd != -1:
            munmap(self.i, self.len)
        if self.fd != -1:
            os.close(self.fd)
        
cdef class FrameBuffer:
    """Basic framebuffer code."""
    cdef fbinfo fbi
    #"""Map of built-in Image objects."""
    cdef readonly object imagemap
    #"""Width of the screen, in pixels."""
    cdef readonly int width
    #"""Height of the screen, in pixels."""
    cdef readonly int height
    def __cinit__(self, devname):
        """Open the framebuffer at the given devicename."""
        rc = fb_open(devname, &self.fbi)
        if rc != 0: raise OSError
        self.width = self.fbi.vinfo.xres
        self.height = self.fbi.vinfo.yres
        self.imagemap = {}
    def __dealloc__(self):
        """Close the framebuffer."""
        fb_close(&self.fbi)

    # image lookup functions
    def load_default_images(self, *paths):
        default_images = [ ('startup', 'startup'),
                           ('locked_XO', 'locked XO'),
                           ('stolen_XO', 'stolen XO'),
                           ('NAND_flash', 'NAND'),
                           ('NAND_flash_outline', 'NAND (outline)'),
                           ('SD_card', 'SD'),
                           ('SD_card_outline', 'SD (outline)'),
                           ('USB_key', 'USB'),
                           ('USB_key_outline', 'USB (outline)'),
                           ('wireless', 'wireless'),
                           ('wireless1', 'wireless1'),
                           ('wireless6', 'wireless6'),
                           ('wireless11', 'wireless11'),
                           ('wireless_outline', 'wireless (outline)'),
                           ('lock', 'lock'),
                           ('stolen', 'stolen'),
                           ('locked_msg', 'locked message'),
                           ('stolen_msg', 'stolen message'),
                           ('_0', '0'),
                           ('_1', '1'),
                           ('_2', '2'),
                           ('_3', '3'),
                           ('_4', '4'),
                           ('_5', '5'),
                           ('_6', '6'),
                           ('_7', '7'),
                           ('_8', '8'),
                           ('_9', '9'),
                           ('_A', 'A'),
                           ('_B', 'B'),
                           ('_C', 'C'),
                           ('_D', 'D'),
                           ('_E', 'E'),
                           ('_F', 'F'),
                           ('_S', 'S'),
                           ('_H', 'H'),
                           ('_N', 'N'),
                           ('question', '?') ]
        import os.path
        for filename, name in default_images:
            for path in paths:
                try:
                    self.load(name, os.path.join(path, filename+".565"))
                    break # next filename
                except OSError: pass # frame not found
                except RuntimeError: pass # frame not in proper format
        # fill in rest of character set w/ question marks
        question = self.imagemap['?']
        for k in xrange(0, 255):
            self.imagemap.setdefault(chr(k), question)
        
    def load(self, name, path):
        """Load an image from the given path and add it to the set of
        built-in images."""
        self.imagemap[name] = Image(path, name)
    def lookup(self, imagename):
        """Return a built-in Image object for the given image name."""
        return self[imagename]
    def __len__(self): return len(self.imagemap)
    def __getitem__(self, x): return self.imagemap[x]
    def __contains__(self, x): return x in self.imagemap
    def __iter__(self): return self.imagemap.__iter__()
        
    def draw(self, int x, int y, Image imageobj not None):
        """Draw the given image onto the screen at the given x and y offset."""
        fb_put(&self.fbi, x, y, imageobj.i)
    def draw_text(self, int x, int y, text):
        """Draw the given text onto the screen at the given x and y offset."""
        cdef Image i
        for c in text:
            i = self.imagemap[c]
            if x + i.width > self.width: x, y = 0, y+i.height
            self.draw(x, y, i)
            x = x + i.width
