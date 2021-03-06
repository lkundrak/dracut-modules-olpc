#!/bin/bash
# Generate a list of files from the python package that we want in the
# initramfs

lines=$(rpm -q --filesbypkg python python-libs)

IFS="
"
for line in $lines; do
	file="/${line#python*/}"

	# directories
	[ -d "$file" ] && continue

	# documentation
	[[ $file =~ ^/usr/share/(doc|man|systemtap) ]] && continue

	# stuff we don't need
	[[ $file =~ ^/usr/lib/python2\..*/(idlelib|distutils|compiler|email|xml|multiprocessing|json|bsddb|hotshot|logging|wsgiref|curses|plat-linux2|sqlite3|unittest|lib2to3)/ ]] && continue

	# dynload stuff
	[[ $file =~ ^/usr/lib/python2\..*/lib-dynload/(pyexpat|nismodule|dbm|cryptmodule|bz2|_sqlite3|_cursesmodule|_curses_panel|_bsddb|readline|gdbmmodule|_ssl|unicodedata|_codecs_..)\.so ]] && continue

	# pyo objects
	[[ $file =~ \.py[co]$ ]] && continue

	# pydoc
	[ "$file" == "/usr/bin/pydoc" ] && continue

	# misc
	[[ $file =~ (regen|README|logfix|pydoc_topics.py|decimal.py|doctest.py|pydoc.py|python-config|python2\..*-config)$ ]] && continue

	echo $file
done

