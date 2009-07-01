from __future__ import division, with_statement
from socket import *
import os, os.path

SOCKET_NAME = '/tmp/gui-sock'

def send(cmd):
    # first, find a running instance of the server.  If there isn't one, start
    # one.
    if not os.path.exists(SOCKET_NAME):
        SERVER_NAME = "/act-gui/gui_server.py"
        pid = os.spawnlp(os.P_WAIT, SERVER_NAME, SERVER_NAME, SOCKET_NAME)
    # now send the command down the socket.
    try:
        s = socket(AF_UNIX, SOCK_DGRAM)
        s.settimeout(5) # 5s timeout as fail-safe if GUI dies
        s.sendto(cmd, 0, SOCKET_NAME)
        s.close()
    except: pass # GUI is optional!

if __name__ == '__main__':
    import sys
    send(sys.argv[1])
