#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
. "$SCRIPT_DIR/autotools-common.sh"

prepend_common_paths
resolve_build_context
resolve_toolchain

ROOT="$(workspace_root)"
SOURCE_DIR="$ROOT/fusepb/libspectrum"
BUILD_DIR="$TARGET_TEMP_DIR/deps/libspectrum/build"
STATE_DIR="$TARGET_TEMP_DIR/deps/libspectrum/state"
PREFIX_DIR="${LIBSPECTRUM_PREFIX:-$DERIVED_FILE_DIR/deps/libspectrum-prefix}"
LIBGCRYPT_PREFIX="${LIBGCRYPT_PREFIX:-$DERIVED_FILE_DIR/deps/libgcrypt-prefix}"
LIBGPG_ERROR_PREFIX="${LIBGPG_ERROR_PREFIX:-$DERIVED_FILE_DIR/deps/libgpg-error-prefix}"
STAMP_FILE="${STAMP_FILE:-$PREFIX_DIR/.build-libspectrum.stamp}"
SIGNATURE_NAME="configure.signature"

ensure_generated_autotools "$SOURCE_DIR"
[ -f "$LIBGCRYPT_PREFIX/include/gcrypt.h" ] || die "Missing staged libgcrypt headers. Build libgcrypt first."
[ -f "$LIBGCRYPT_PREFIX/lib/libgcrypt.a" ] || die "Missing staged libgcrypt library. Build libgcrypt first."

ensure_parent_dir "$BUILD_DIR"
ensure_parent_dir "$STATE_DIR"
ensure_parent_dir "$PREFIX_DIR/include"
ensure_parent_dir "$PREFIX_DIR/lib"

DEPENDENCY_CPPFLAGS="$DEPENDENCY_CPPFLAGS -I$LIBGCRYPT_PREFIX/include -I$LIBGPG_ERROR_PREFIX/include"
DEPENDENCY_LDFLAGS="$DEPENDENCY_LDFLAGS -L$LIBGCRYPT_PREFIX/lib -L$LIBGPG_ERROR_PREFIX/lib"
DEPENDENCY_SIGNATURE_EXTRA="PREFIX_DIR=$PREFIX_DIR LIBGCRYPT_PREFIX=$LIBGCRYPT_PREFIX LIBGPG_ERROR_PREFIX=$LIBGPG_ERROR_PREFIX CONFIGURE_ARGS=--disable-shared,--enable-static,--with-fake-glib,--without-libaudiofile"

compute_signature "$STATE_DIR/$SIGNATURE_NAME.current" \
  "$SOURCE_DIR/configure" \
  "$SOURCE_DIR/aclocal.m4" \
  "$SOURCE_DIR/Makefile.in" \
  "$SOURCE_DIR/config.h.in" \
  "$SOURCE_DIR/Makefile.am" \
  "$SOURCE_DIR/libspectrum.h.in" \
  "$SOURCE_DIR/generate.pl.in" \
  "$SOURCE_DIR/make-perl.c" \
  "$SOURCE_DIR/snap_accessors.txt" \
  "$SOURCE_DIR/tape_accessors.txt" \
  "$SOURCE_DIR/accessor.pl" \
  "$SOURCE_DIR/tape_accessors.pl" \
  "$SOURCE_DIR/tape_set.pl" \
  "$LIBGCRYPT_PREFIX/include/gcrypt.h" \
  "$LIBGCRYPT_PREFIX/lib/libgcrypt.a" \
  "$LIBGPG_ERROR_PREFIX/include/gpg-error.h" \
  "$LIBGPG_ERROR_PREFIX/lib/libgpg-error.a"

CONFIGURE_ARGS=(
  "--disable-shared"
  "--enable-static"
  "--with-fake-glib"
  "--without-libaudiofile"
  "--prefix=$PREFIX_DIR"
)

if [ ! -x "$BUILD_DIR/config.status" ] || signature_changed "$STATE_DIR" "$SIGNATURE_NAME"; then
  rm -f "$BUILD_DIR/config.cache"
  (
    cd "$BUILD_DIR"
    env \
      CC="$CC" \
      AR="$AR" \
      RANLIB="$RANLIB" \
      CC_FOR_BUILD="$CC" \
      SDKROOT="$SDKROOT" \
      CPPFLAGS="$DEPENDENCY_CPPFLAGS" \
      CFLAGS="$DEPENDENCY_CFLAGS" \
      LDFLAGS="$DEPENDENCY_LDFLAGS" \
      "$SOURCE_DIR/configure" \
      "${CONFIGURE_ARGS[@]}" \
      --cache-file="$STATE_DIR/config.cache" \
      > "$STATE_DIR/configure.log" 2>&1
  )
else
  (
    cd "$BUILD_DIR"
    ./config.status > "$STATE_DIR/config.status.log" 2>&1
  )
fi

BUILD_CC_FOR_BUILD="$CC -isysroot $SDKROOT"

(
  cd "$BUILD_DIR"
  make -j1 CC_FOR_BUILD="$BUILD_CC_FOR_BUILD" libspectrum.h snap_accessors.c tape_accessors.c tape_set.c
  make -j1 CC_FOR_BUILD="$BUILD_CC_FOR_BUILD" libspectrum.la
) > "$STATE_DIR/make.log" 2>&1

install -c -m 644 "$BUILD_DIR/libspectrum.h" "$PREFIX_DIR/include/libspectrum.h"
install -c -m 644 "$BUILD_DIR/.libs/libspectrum.a" "$PREFIX_DIR/lib/libspectrum.a"
touch "$STAMP_FILE"

commit_signature "$STATE_DIR" "$SIGNATURE_NAME"
