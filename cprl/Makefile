cprl.so: cprl.o
	$(CC) $(CFLAGS) -shared $^ -o $@

cprl.o: cprl.c cprl.h
	$(CC) -c -fPIC -I/usr/include/python2.6 $(CFLAGS) $<

cprl.c: cprl.pyx
	pyrexc $<

clean:
	-rm -f cprl.c cprl.o cprl.so

