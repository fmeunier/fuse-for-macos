/* Downstream macOS config shim derived from upstream Autotools output. */
/* This file is maintained manually for the Cocoa/Xcode build and omits */
/* staged dependency-specific configuration such as libspectrum-only probes. */

/* Defined if we support spectranet */
#define BUILD_SPECTRANET 1

/* Define copyright of Fuse */
#define FUSE_COPYRIGHT "(c) 1999-2026 Philip Kendall and others"

/* Define version information for win32 executables */
#define FUSE_RC_VERSION 1,7,0,0

/* Define to 1 if you have the `dirname' function. */
#define HAVE_DIRNAME 1

/* Defined if we've got enough memory to compile z80_ops.c */
#define HAVE_ENOUGH_MEMORY 1

/* Define to 1 if you have the `fsync' function. */
#define HAVE_FSYNC 1

/* Define to 1 if you have the `geteuid' function. */
#define HAVE_GETEUID 1

/* Define to 1 if you have the `getopt_long' function. */
#define HAVE_GETOPT_LONG 1

/* Defined if gpm in use */
/* #undef HAVE_GPM_H */

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define to 1 if you have the <jsw.h> header file. */
/* #undef HAVE_JSW_H */

/* Define to 1 if you have the <libgen.h> header file. */
#define HAVE_LIBGEN_H 1

/* Defined if we've got glib */
/* #undef HAVE_LIB_GLIB */

/* Defined if we've got libxml2 */
/* #undef HAVE_LIB_XML2 */

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Define to 1 if you have the `mkstemp' function. */
#define HAVE_MKSTEMP 1

/* Define if you have POSIX threads libraries and header files. */
/* #undef HAVE_PTHREAD */

/* Have PTHREAD_PRIO_INHERIT. */
#define HAVE_PTHREAD_PRIO_INHERIT 1

/* Define to 1 if you have the <siginfo.h> header file. */
/* #undef HAVE_SIGINFO_H */

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define to 1 if you have the <sys/audioio.h> header file. */
/* #undef HAVE_SYS_AUDIOIO_H */

/* Define to 1 if you have the <sys/audio.h> header file. */
/* #undef HAVE_SYS_AUDIO_H */

/* Define to 1 if you have the <sys/soundcard.h> header file. */
/* #undef HAVE_SYS_SOUNDCARD_H */

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* Define to 1 if you have the <X11/extensions/XShm.h> header file. */
/* #undef HAVE_X11_EXTENSIONS_XSHM_H */

/* Define to 1 if you have the <zlib.h> header file. */
#define HAVE_ZLIB_H 1

/* Define to 1 if Linux TAP devices are supported. */
/* #undef LINUX_TAP */

/* Defined if no sound code is present */
/* #undef NO_SOUND */

/* Name of package */
#define PACKAGE "fuse"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "http://sourceforge.net/p/fuse-emulator/bugs/"

/* Define to the full name of this package. */
#define PACKAGE_NAME "fuse"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "fuse 1.7.0"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "fuse"

/* Define to the version of this package. */
#define PACKAGE_VERSION "1.7.0"

/* Location of the ROM images */
/* #undef ROMSDIR */

/* Defined if the sound code uses a fifo */
#define SOUND_FIFO 1

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Defined if framebuffer UI in use */
/* #undef UI_FB */

/* Defined if GTK+ UI (either 1.2 or 2.x) is in use */
/* #undef UI_GTK */

/* Defined if the SDL UI in use */
/* #undef UI_SDL */

/* Defined if svgalib UI in use */
/* #undef UI_SVGA */

/* Defined if Win32 UI in use */
/* #undef UI_WIN32 */

/* Defined if Xlib UI in use */
/* #undef UI_X */

/* Defined if we're using hardware joysticks */
#define USE_JOYSTICK 1

/* Defined if we're going to be using the installed libpng */
/* #undef USE_LIBPNG */

/* Defined if we're using a widget-based UI */
/* #undef USE_WIDGET */

/* Version number of package */
#define VERSION "1.7.0"

/* Define to 1 if your processor stores words with the most significant byte
   first (like Motorola and SPARC, unlike Intel and VAX). */
#ifdef __BIG_ENDIAN__
#define WORDS_BIGENDIAN 1
#endif

/* Define to 1 if the X Window System is missing or not being used. */
#define X_DISPLAY_MISSING 1

/* Define to 1 if `lex' declares `yytext' as a `char *' by default, not a
   `char[]'. */
#define YYTEXT_POINTER 1

/* Define to empty if `const' does not conform to ANSI C. */
/* #undef const */

/* Define to `__inline__' or `__inline' if that's what the C compiler
   calls it, or to nothing if 'inline' is not supported under any name.  */
#ifndef __cplusplus
/* #undef inline */
#endif
