# Copyright (c) 2008, Michael Stone
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#  3. The names of the authors may not be used to endorse or promote
#     products derived from this software without specific prior
#     written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import StringIO

from os import kill
from signal import SIGKILL
from subprocess import Popen, CalledProcessError, PIPE

def null():
    """open('/dev/null', 'r+')"""
    return open('/dev/null', 'r+')

def tokenize(input):
    """Take a string and split it on whitespace-strings not contained in
    matched quotes.
    """
    quotes = ''''"'''
    words = []
    state = '\0'
    current_word = StringIO.StringIO()
    for c in input:
        if state == '\0':
            if c in quotes:
                state = c
                continue
            if c.isspace():
                val = current_word.getvalue()
                if val != '':
                    words.append(val)
                    current_word.truncate(0)
                continue

        if state in quotes:
            if c == state:
                state = '\0'
                continue

        current_word.write(c)

    if state in quotes:
        current_word.write(c)

    words.append(current_word.getvalue())

    return words

def lout(cmd, input=None, safe_codes=None, log=None):
    """Run a command and optionally write a string to its stdin. Then wait for it to terminate.

    If an exception is thrown while the process may be alive, send it SIGKILL
    and wait for it to terminate, then re-raise the exception.

    If the command terminates and its return code is NOT in safe_codes, throw a
    subprocess.CalledProcessError.

    If the wait succeeds and the return code is in safe_codes (def. (0,)),
    return the lines that the process printed.

    Optionally, log the command, return code, stdout, and stderr.
    """
    if safe_codes is None:
        safe_codes = (0,)

    if isinstance(cmd, basestring):
        cmd = tokenize(cmd)

    stdin = (input is None) and null() or PIPE
    stderr = (log is None) and null() or PIPE
    proc = None
    ret = None

    try:
        proc = Popen(cmd, stdin=stdin, stdout=PIPE, stderr=stderr)

        if input is not None:
            proc.stdin.write(input)
            proc.stdin.close()

        ret = proc.wait()

    except:
        if proc:
            try:
                kill(proc.pid, SIGKILL)
                ret = proc.wait()
            except:
                pass
        raise

    if ret not in safe_codes:
        raise CalledProcessError(ret, cmd)

    out = proc.stdout.read()

    if log:
        log('[%d] %r', ret, cmd)
        log('stdout:\n%s' % out)
        log('stderr:\n%s' % proc.stderr.read())

    return out.split('\n')

