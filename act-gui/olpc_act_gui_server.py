#!/usr/bin/python
from __future__ import division, with_statement
import os
from pyvt import *

BLINK_TIME_MS = 500 # half a blink cycle time, in milliseconds
ICON_SPACING = 75
xoff, yoff = 0,0
xicon, yicon = 450, 570
active = None
state = None
blink = None
dcon_freeze = 0
console_log_level = None

def read_dcon():
    try:
        with open('/sys/devices/platform/dcon/freeze','r') as f:
            return int(f.read())
    except:
        return 0 # don't freeze if in doubt
def write_dcon(val):
    try:
        with open('/sys/devices/platform/dcon/freeze','w') as f:
            f.write(str(val))
    except: pass # dcon freeze is purely optional.

def initial_setup():
    import pyfb
    # turn off cursor on vt 2
    with open('/dev/tty2','w') as f:
        f.write('\x1B[?25l')
    # switch to virtual terminal 2
    chvt(2)
    # redirect kernel messages to vt 1
    chcon('/dev/tty1')
    # save old kernel log level and disable console messages pro tem
    # XXX: THIS IS A HACK, but chcon() doesn't actually seem to work =(
    global console_log_level
    with open('/proc/sys/kernel/printk') as f:
        console_log_level = f.read()
    with open('/proc/sys/kernel/printk','w') as f:
        f.write('1 4 1 7')
    # setup frame buffer and draw initial screen
    fb = pyfb.FrameBuffer('/dev/fb0')
    fb.load_default_images('act-gui/images')
    global xoff, yoff, xicon, yicon
    xoff = (fb.width - fb['startup'].width) // 2
    yoff = (fb.height - fb['startup'].height) // 2
    xicon += xoff
    yicon += yoff
    fb.draw(xoff, yoff, fb['startup'])
    # unfreeze the DCON
    global dcon_freeze
    dcon_freeze = read_dcon()
    write_dcon(0)
    return fb

def clean_up():
    import time
    # re-freeze the DCON
    global dcon_freeze
    write_dcon(dcon_freeze)
    # wait for dcon to freeze (is 50ms enough?)
    time.sleep(0.05)
    # turn on cursor on vt 2
    with open('/dev/tty2','w') as f:
        f.write('\x1B[?12l\x1B[?25h')
    # switch back to vt 1
    chvt(1)
    # redirect console output to /dev/console
    chcon('/dev/console')
    # restore console logging
    global console_log_level
    with open('/proc/sys/kernel/printk','w') as f:
        f.write(console_log_level)

def process_command(fb, cmd):
    global xoff, yoff, xicon, yicon, active, blink, state
    word = cmd.split()
    if word[0] == 'start':
        pass # ignore this command, it's just used to start the server
    elif word[0] == 'serial':
        # draw a serial number underneath the XO man
        fb.draw_text(xoff+547, yoff+546, word[1])
    elif word[0] == 'lock':
        # registration failed: draw a lock icon on the XO man
        fb.draw(xoff+551, yoff+381, fb['locked XO'])
        fb.draw(xoff+0,   yoff+0, fb['locked message'])
    elif word[0] == 'stolen':
        # registration failed: draw a stolen icon on the XO man
        fb.draw(xoff+551, yoff+381, fb['stolen XO'])
        fb.draw(xoff+0,   yoff+0, fb['stolen message'])
    elif word[0] == 'freeze':
        # a bit of a hack: ensure that display ends up frozen/unfrozen
        global dcon_freeze
        dcon_freeze = int(word[1])
    elif word[0] in ['NAND', 'SD', 'USB', 'wireless']:
        # next word is one of: start, success, state, fail, lock
        outline = False
        if word[1] == 'start':
            active = word[0]
            outline = True
            blink = 'white'
            state = None
            xicon += ICON_SPACING # new icon
        elif word[1] == 'state':
            state = word[2]
            if blink == 'white': return # don't disrupt blink pattern
        elif word[1] == 'success':
            blink = None
        elif word[1] in ['fail', 'lock', 'stolen']:
            outline = True
            blink = None
        icon = active
        if outline:
            icon += ' (outline)'
        elif state:
            icon += state
        fb.draw(xicon - (fb[icon].width // 2), yicon, fb[icon])
        if word[1] in ['lock', 'stolen']: # superimpose a lock/stolen icon
            fb.draw(xicon+11, yicon+51, fb[word[1]])
    elif word[0] == 'blink':
        # show activity by blinking currently active icon
        if blink is not None:
            outline = False
            if blink == 'white':
                blink = 'color'
            else:
                blink = 'white'
                outline = True
            icon = active
            if outline:
                icon += ' (outline)'
            elif state:
                icon += state
            fb.draw(xicon - (fb[icon].width // 2), yicon, fb[icon])
    else:
        # complain
        print "Unknown GUI command:", cmd

def server_loop(s, fb):
    import socket
    s.settimeout(BLINK_TIME_MS/1000.)
    while True:
        try:
            cmd = s.recvfrom(256)[0]
            if cmd == 'quit': return # close the server
            else: process_command(fb, cmd)
        except socket.timeout:
            process_command(fb, 'blink')

if __name__ == '__main__':
    from socket import *
    import sys
    # create the fifo given on the command-line then fork.
    SOCKET_NAME = sys.argv[1]
    s = socket(AF_UNIX, SOCK_DGRAM)
    s.bind(SOCKET_NAME)
    s.shutdown(SHUT_WR) # only reads
    # an extra command-line argument will cause us not to fork
    if len(sys.argv)>2 or os.fork() == 0:
        # i'm the child!
        server_loop(s, initial_setup())
        # clean up the socket
        os.unlink(SOCKET_NAME)
        s.close()
        # clean up other details
        clean_up()
