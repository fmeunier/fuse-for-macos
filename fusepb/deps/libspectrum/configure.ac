dnl Process this file with autoconf to produce a configure script.
dnl Copyright (c) 1999-2026 Philip Kendall

dnl This program is free software; you can redistribute it and/or modify
dnl it under the terms of the GNU General Public License as published by
dnl the Free Software Foundation; either version 2 of the License, or
dnl (at your option) any later version.
dnl
dnl This program is distributed in the hope that it will be useful,
dnl but WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
dnl GNU General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License along
dnl with this program; if not, write to the Free Software Foundation, Inc.,
dnl 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
dnl
dnl Author contact information:
dnl
dnl E-mail: philip-fuse@shadowmagic.org.uk

dnl Package version
m4_define([libspectrum_version], [1.8.0])

dnl Product full version
m4_define([libspectrum_major_version], [1])
m4_define([libspectrum_minor_version], [8])
m4_define([libspectrum_micro_version], [0])
m4_define([libspectrum_nano_version],  [0])
m4_define([libspectrum_full_version],
          [libspectrum_major_version.libspectrum_minor_version.libspectrum_micro_version.libspectrum_nano_version])
m4_define([libspectrum_rc_version],
          [libspectrum_major_version,libspectrum_minor_version,libspectrum_micro_version,libspectrum_nano_version])

dnl Package info
m4_define([libspectrum_copyright], ["(c) 1999-2026 Philip Kendall and others"])
m4_define([libspectrum_url],
          [https://fuse-emulator.sourceforge.net/libspectrum.php])
m4_define([libspectrum_bugreport],
          [https://sourceforge.net/p/fuse-emulator/bugs/])

AC_INIT([libspectrum],[libspectrum_version],[libspectrum_bugreport],
        [libspectrum],[libspectrum_url])
AC_CONFIG_SRCDIR([libspectrum.c])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_HEADERS([config.h])
AC_CANONICAL_HOST

PKG_PROG_PKG_CONFIG
PKG_INSTALLDIR

dnl Use automake to produce `Makefile.in'
AM_INIT_AUTOMAKE([1.11 subdir-objects])
AM_SILENT_RULES([yes])

dnl Substitutions for .in files
LIBSPECTRUM_FULL_VERSION=libspectrum_full_version
LIBSPECTRUM_COPYRIGHT=libspectrum_copyright
LIBSPECTRUM_URL=libspectrum_url
AC_SUBST(LIBSPECTRUM_FULL_VERSION)
AC_SUBST(LIBSPECTRUM_COPYRIGHT)
AC_SUBST(LIBSPECTRUM_URL)

dnl Definitions for config.h
AC_DEFINE([LIBSPECTRUM_RC_VERSION], [libspectrum_rc_version],
          [Define version information for win32 dll library])
AC_DEFINE([LIBSPECTRUM_COPYRIGHT], [libspectrum_copyright],
          [Define copyright of libspectrum])

dnl Checks for programs.
AC_PROG_CC
AC_MSG_CHECKING([whether $CC supports C11 or later])
AC_COMPILE_IFELSE(
  [AC_LANG_SOURCE([[
#if !defined __STDC_VERSION__ || __STDC_VERSION__ < 201112L
#error "C11 or later is required"
#endif
int main(void) { return 0; }
  ]])],
  [AC_MSG_RESULT([yes])],
  [AC_MSG_FAILURE([a compiler with support for C11 or later is required])]
)

dnl Setup for compiling build tools (make-perl)
if test $cross_compiling = yes; then
  AC_CHECK_PROGS(CC_FOR_BUILD, gcc cc)
else
  CC_FOR_BUILD=$CC
fi
AC_MSG_CHECKING([for a C compiler for build tools])
AC_MSG_RESULT([$CC_FOR_BUILD])
AC_SUBST(CC_FOR_BUILD)

LT_INIT
AC_PATH_PROG(PERL, perl)
AC_SUBST(PERL)

dnl Checks for header files.
AC_CHECK_HEADERS(stdint.h strings.h unistd.h)

dnl Check for host specific programs
WINDRES_OBJ=
WINDRES_LDFLAGS=
case "$host_os" in
  mingw32*)
    AC_CHECK_TOOL([WINDRES], [windres], [no])
    if test "$WINDRES" != no; then
      WINDRES_OBJ="windres.o"
      WINDRES_LDFLAGS="-Xlinker windres.o"
    fi
    AC_DEFINE([WIN32_LEAN_AND_MEAN],, [Exclude rarely used stuff from Windows headers <windows.h>])
    ;;
esac
AC_SUBST(WINDRES_OBJ)
AC_SUBST(WINDRES_LDFLAGS)

dnl Check for big endianness
AC_C_BIGENDIAN

dnl Check for functions
AC_CHECK_FUNCS(_snprintf _stricmp _strnicmp snprintf strcasecmp strncasecmp)

dnl Allow the user to say that various libraries are in one place
AC_ARG_WITH(local-prefix,
[  --with-local-prefix=PFX local libraries installed in PFX (optional)],
CPPFLAGS="$CPPFLAGS -I$withval/include"; LDFLAGS="$LDFLAGS -L$withval/lib",
if test "$prefix" != "NONE"; then
  CPPFLAGS="$CPPFLAGS -I$prefix/include"; LDFLAGS="$LDFLAGS -L$prefix/lib"
fi)

dnl Optional CP1252 to UTF-8 conversion for PZX metadata.
AC_ARG_WITH(iconv,
[  --without-iconv         don't use iconv],
[], [with_iconv=yes])
ICONV_LIBS=
AS_IF([test "$with_iconv" != no], [
  AC_CHECK_HEADERS([iconv.h], [
    save_LIBS="$LIBS"
    AC_SEARCH_LIBS([iconv_open], [iconv], [
      AS_IF([test "$ac_cv_search_iconv_open" != "none required"],
            [ICONV_LIBS="$ac_cv_search_iconv_open"])
      AC_DEFINE([HAVE_ICONV], [1], [Define if iconv is available.])
      AC_CACHE_CHECK([whether iconv requires a const input pointer],
        [libspectrum_cv_iconv_const], [
        AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <iconv.h>
extern size_t iconv( iconv_t, char **, size_t *, char **, size_t * );]], [[]])],
          [libspectrum_cv_iconv_const=no], [libspectrum_cv_iconv_const=yes])
      ])
      AS_IF([test "$libspectrum_cv_iconv_const" = yes],
        [AC_DEFINE([ICONV_CONST], [const], [Input pointer qualifier for iconv.])],
        [AC_DEFINE([ICONV_CONST], [], [Input pointer qualifier for iconv.])])
    ])
    LIBS="$save_LIBS"
  ])
])
AC_SUBST([ICONV_LIBS])

dnl Check whether to use zlib (the UNIX version is called z, Win32 zdll)
AC_MSG_CHECKING(whether to use zlib)
AC_ARG_WITH(zlib,
[  --without-zlib          don't use zlib],
if test "$withval" = no; then zlib=no; else zlib=yes; fi,
zlib=yes)
AC_MSG_RESULT($zlib)
have_zlib="no"
if test "$zlib" = yes; then
  AC_CHECK_HEADERS(
    zlib.h,
    [AC_SEARCH_LIBS(compress2, z zdll)
     have_zlib="yes"]
  )
fi
AM_CONDITIONAL([HAVE_ZLIB], [test "$ac_cv_header_zlib_h" = yes])

dnl Check whether to use libgcrypt
AC_MSG_CHECKING(whether to use libgcrypt)
AC_ARG_WITH(libgcrypt,
[  --without-libgcrypt     don't use libgcrypt],
if test "$withval" = no; then libgcrypt=no; else libgcrypt=yes; fi,
libgcrypt=yes)
AC_MSG_RESULT($libgcrypt)
have_libgcrypt="no"
if test "$libgcrypt" = yes; then
  AC_CHECK_HEADERS(gcrypt.h,
  [LIBS="$LIBS -lgcrypt"
   have_libgcrypt="yes"])
fi

dnl Check whether to use libbz2 (1.0 or greater)
AC_MSG_CHECKING(whether to use libbz2)
AC_ARG_WITH(bzip2,
[  --without-bzip2         don't use libbz2],
if test "$withval" = no; then bzip2=no; else bzip2=yes; fi,
bzip2=yes)
AC_MSG_RESULT($bzip2)
have_bzip2="no"
if test "$bzip2" = yes; then
  AC_CHECK_HEADER(
    bzlib.h,
    [AC_CHECK_LIB(bz2,BZ2_bzDecompressInit)
     have_bzip2="yes"]
  )
fi

dnl Either find GLib or use the replacement
AC_MSG_CHECKING(whether to use internal GLib replacement)
AC_ARG_WITH(fake-glib,
[  --with-fake-glib        use internal GLib replacement],
if test "$withval" = no; then myglib=no; else myglib=yes; fi,
myglib=no)
AC_MSG_RESULT($myglib)
AS_IF([test "$myglib" = no], [
  PKG_CHECK_MODULES(
    GLIB,
    glib-2.0,
    AC_DEFINE([HAVE_LIB_GLIB], 1, [Defined if we've got GLib]),
    AC_MSG_ERROR([GLib not found])
  )
])
AS_IF([test "$myglib" = yes], [
  AC_MSG_CHECKING([whether C11 atomic flags are usable])
  AC_LINK_IFELSE([
    AC_LANG_PROGRAM([[
      #include <stdatomic.h>

      static atomic_flag lock = ATOMIC_FLAG_INIT;
    ]], [[
      if( !atomic_flag_test_and_set_explicit( &lock, memory_order_acquire ) )
        atomic_flag_clear_explicit( &lock, memory_order_release );
    ]])
  ], [
    AC_MSG_RESULT([yes])
  ], [
    AC_MSG_RESULT([no])
    AC_MSG_ERROR([C11 atomic flag support is required by the internal GLib replacement])
  ])
])

AM_CONDITIONAL(USE_MYGLIB, test "$myglib" = yes)

dnl If it appears we're using gcc as our compiler, turn on warnings
if test "$ac_cv_c_compiler_gnu" = yes; then
  CFLAGS="$CFLAGS -Wall -Wextra -Wsign-compare -Wwrite-strings"
  dnl And possibly lots of warnings
  AC_MSG_CHECKING(whether lots of warnings requested)
  AC_ARG_ENABLE(warnings,
  [  --enable-warnings       give lots of warnings if using gcc],
  if test "$enableval" = yes; then
    warnings=yes;
  else
    warnings=no;
  fi,
  warnings=no)
  AC_MSG_RESULT($warnings)
  if test "$warnings" = yes; then
      CFLAGS="$CFLAGS -Wstrict-prototypes -Wmissing-prototypes -Winline -Wshadow -Wpointer-arith -Wcast-qual -Wcast-align -Waggregate-return -W -Wsign-compare"
  fi
fi

AC_ARG_WITH(wav-backend,
[  --with-wav-backend=auto|pcm|macos  select WAV backend (auto uses pcm)],
[wav_backend_requested="$withval"],
[wav_backend_requested="auto"])

AS_CASE([$wav_backend_requested],
  [auto|pcm|macos], [],
  [AC_MSG_FAILURE([invalid WAV backend '$wav_backend_requested'])])

dnl Check for native macOS frameworks for WAV support
MACOS_WAV_LIBS=
have_macos_wav="no"
AS_CASE([$host_os], [darwin*], [
  AC_MSG_CHECKING([for native macOS WAV frameworks])
  save_LIBS="$LIBS"
  LIBS="$LIBS -framework AudioToolbox -framework CoreFoundation"
  AC_LINK_IFELSE([
    AC_LANG_PROGRAM([
      [#include <AudioToolbox/AudioToolbox.h>
        #include <CoreFoundation/CoreFoundation.h>]
    ], [
      ExtAudioFileRef file = NULL;
      CFURLRef url = NULL;
      return ExtAudioFileOpenURL( url, &file );
    ])
  ], [
    AC_DEFINE([HAVE_MACOS_NATIVE_WAV], 1,
              [Defined if native macOS WAV frameworks are available])
    MACOS_WAV_LIBS="-framework AudioToolbox -framework CoreFoundation"
    have_macos_wav="yes"
  ])
  LIBS="$save_LIBS"
  AC_MSG_RESULT([$have_macos_wav])
])
AC_SUBST(MACOS_WAV_LIBS)

WAV_BACKEND_CPPFLAGS=
WAV_BACKEND_LIBADD=
WAV_BACKEND_LDFLAGS=
WAV_BACKEND_PRIVATE_LIBS=

selected_wav_backend="pcm"
AS_CASE([$wav_backend_requested],
  [auto|pcm], [selected_wav_backend="pcm"],
  [macos], [
    if test "$have_macos_wav" = yes; then
      selected_wav_backend="macos"
    else
      AC_MSG_FAILURE([macOS WAV backend requested but unavailable])
    fi
  ])

AS_CASE([$selected_wav_backend],
  [pcm], [
    AC_DEFINE([WAV_INTERNAL_PCM], 1,
              [Defined if the portable PCM WAV internals are selected])
  ],
  [macos], [
    AC_DEFINE([WAV_INTERNAL_MACOS], 1,
              [Defined if the macOS WAV internals are selected])
    WAV_BACKEND_LDFLAGS="$MACOS_WAV_LIBS"
    WAV_BACKEND_PRIVATE_LIBS="$MACOS_WAV_LIBS"
  ])

AC_SUBST(WAV_BACKEND_CPPFLAGS)
AC_SUBST(WAV_BACKEND_LIBADD)
AC_SUBST(WAV_BACKEND_LDFLAGS)
AC_SUBST(WAV_BACKEND_PRIVATE_LIBS)

AM_CONDITIONAL([WAV_INTERNAL_PCM],
               [test "$selected_wav_backend" = pcm])
AM_CONDITIONAL([WAV_INTERNAL_MACOS],
               [test "$selected_wav_backend" = macos])

AM_CONDITIONAL([BUILD_TEST_ARCHIVE],
               [test "x$enable_static" != "xyes"])

AC_CONFIG_FILES([
  Makefile
  libspectrum.qpg
  libspectrum.pc
])

AC_OUTPUT

dnl Status summary
echo ""
echo "*******************************************"
echo "*** libspectrum is ready to be compiled ***"
echo "*******************************************"
echo ""
echo "zlib support: $have_zlib"
echo "bzip2 support: $have_bzip2"
echo "libgcrypt support: $have_libgcrypt"
echo "native macOS WAV support: $have_macos_wav"
echo "selected WAV backend: $selected_wav_backend"
echo "Internal GLib replacement: $myglib"
echo ""
echo "Type 'make' to compile libspectrum"
echo ""
