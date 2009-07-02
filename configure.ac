AC_INIT([dracut-modules-olpc], [0.1.1])
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

DRACUT_MODDIR="$datadir/dracut/modules.d/30olpc-boot"
AC_SUBST(DRACUT_MODDIR)

AC_CONFIG_FILES([dracut-modules-olpc.spec Makefile 30olpc-boot/Makefile cprl/Makefile ipv6util/Makefile act-gui/Makefile act-gui/images/Makefile])
AC_OUTPUT
