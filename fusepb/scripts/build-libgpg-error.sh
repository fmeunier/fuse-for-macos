#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
. "$SCRIPT_DIR/autotools-common.sh"

prepend_common_paths
resolve_build_context
resolve_toolchain

ROOT="$(workspace_root)"
SOURCE_DIR="$ROOT/fusepb/deps/third_party/libgpg-error"
BUILD_DIR="$TARGET_TEMP_DIR/deps/libgpg-error/build"
STATE_DIR="$TARGET_TEMP_DIR/deps/libgpg-error/state"
SOURCE_DIR_FILE="$STATE_DIR/source-dir"
PREFIX_DIR="${LIBGPG_ERROR_PREFIX:-$DERIVED_FILE_DIR/deps/libgpg-error-prefix}"
STAMP_FILE="${STAMP_FILE:-$PREFIX_DIR/.build-libgpg-error.stamp}"
SIGNATURE_NAME="configure.signature"

ensure_generated_autotools "$SOURCE_DIR"

if [ -d "$BUILD_DIR" ] && { [ ! -f "$SOURCE_DIR_FILE" ] || [ "$(cat "$SOURCE_DIR_FILE")" != "$SOURCE_DIR" ]; }; then
  rm -rf "$BUILD_DIR" "$STATE_DIR"
fi

ensure_parent_dir "$BUILD_DIR"
ensure_parent_dir "$STATE_DIR"
printf '%s\n' "$SOURCE_DIR" > "$SOURCE_DIR_FILE"
ensure_parent_dir "$PREFIX_DIR/include"
ensure_parent_dir "$PREFIX_DIR/lib"
ensure_parent_dir "$PREFIX_DIR/bin"

DEPENDENCY_SIGNATURE_EXTRA="PREFIX_DIR=$PREFIX_DIR CONFIGURE_ARGS=--disable-shared,--enable-static,--disable-nls"

compute_signature "$STATE_DIR/$SIGNATURE_NAME.current" \
  "$SOURCE_DIR/configure" \
  "$SOURCE_DIR/aclocal.m4" \
  "$SOURCE_DIR/Makefile.in" \
  "$SOURCE_DIR/config.h.in" \
  "$SOURCE_DIR/src/Makefile.in"

CONFIGURE_ARGS=(
  "--disable-shared"
  "--enable-static"
  "--disable-nls"
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
      CC_FOR_BUILD="$CC_FOR_BUILD" \
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

(
  make -C "$BUILD_DIR/src" -j1 \
    err-sources.h err-codes.h code-to-errno.h code-from-errno.h \
    err-sources-sym.h err-codes-sym.h errnos-sym.h gpg-error.h \
    gpg-error-config
  make -C "$BUILD_DIR/src" -j1 all-am
) > "$STATE_DIR/make.log" 2>&1

install -c -m 644 "$BUILD_DIR/src/gpg-error.h" "$PREFIX_DIR/include/gpg-error.h"
install -c -m 644 "$BUILD_DIR/src/.libs/libgpg-error.a" "$PREFIX_DIR/lib/libgpg-error.a"
install -c -m 755 "$BUILD_DIR/src/gpg-error-config" "$PREFIX_DIR/bin/gpg-error-config"
touch "$STAMP_FILE"

commit_signature "$STATE_DIR" "$SIGNATURE_NAME"
