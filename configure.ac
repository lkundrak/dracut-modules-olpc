AC_INIT([dracut-modules-olpc], [0.6.1])

AM_INIT_AUTOMAKE
AC_CONFIG_SRCDIR([30olpc-boot/olpc-boot-premount.sh])
AC_PREREQ([2.59])

AM_PROG_CC_C_O

AM_PATH_PYTHON
pylib="python$am_cv_python_version"
AC_CHECK_LIB([$pylib],Py_InitModule3)
python_inc=`python -c "import distutils.sysconfig; \
	print distutils.sysconfig.get_python_inc()"`

PY_CFLAGS="-I$python_inc -fPIC"
PY_LDFLAGS="-shared"
PY_LIBS="-l$pylib"
AC_SUBST(PY_CFLAGS)
AC_SUBST(PY_LDFLAGS)
AC_SUBST(PY_LIBS)

DRACUT_MODDIR="$exec_prefix/lib/dracut/modules.d"
AC_SUBST(DRACUT_MODDIR)

DRACUT_LIBDIR="$libdir/dracut-modules-olpc"
AC_SUBST(DRACUT_LIBDIR)

AC_CONFIG_FILES([
	Makefile
	30olpc-common/Makefile
	30olpc-python/Makefile
	30olpc-boot/Makefile
	30olpc-activation/Makefile
	30olpc-customization/Makefile
	95olpc-mtd/Makefile
	cprl/Makefile
	ipv6util/Makefile
	act-gui/Makefile
	act-gui/images/Makefile])
AC_OUTPUT

