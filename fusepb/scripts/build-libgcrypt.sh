#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
. "$SCRIPT_DIR/autotools-common.sh"

prepend_common_paths
resolve_build_context
resolve_toolchain

ROOT="$(workspace_root)"
SOURCE_DIR="$ROOT/fusepb/deps/third_party/libgcrypt"
BUILD_DIR="$TARGET_TEMP_DIR/deps/libgcrypt/build"
STATE_DIR="$TARGET_TEMP_DIR/deps/libgcrypt/state"
SOURCE_DIR_FILE="$STATE_DIR/source-dir"
PREFIX_DIR="${LIBGCRYPT_PREFIX:-$DERIVED_FILE_DIR/deps/libgcrypt-prefix}"
GPG_ERROR_PREFIX="${LIBGPG_ERROR_PREFIX:-$DERIVED_FILE_DIR/deps/libgpg-error-prefix}"
GPG_ERROR_CONFIG="$GPG_ERROR_PREFIX/bin/gpg-error-config"
STAMP_FILE="${STAMP_FILE:-$PREFIX_DIR/.build-libgcrypt.stamp}"
SIGNATURE_NAME="configure.signature"

ensure_generated_autotools "$SOURCE_DIR"
[ -x "$GPG_ERROR_CONFIG" ] || die "Missing $GPG_ERROR_CONFIG. Build libgpg-error first."

if [ -d "$BUILD_DIR" ] && { [ ! -f "$SOURCE_DIR_FILE" ] || [ "$(cat "$SOURCE_DIR_FILE")" != "$SOURCE_DIR" ]; }; then
  rm -rf "$BUILD_DIR" "$STATE_DIR"
fi

ensure_parent_dir "$BUILD_DIR"
ensure_parent_dir "$STATE_DIR"
printf '%s\n' "$SOURCE_DIR" > "$SOURCE_DIR_FILE"
ensure_parent_dir "$PREFIX_DIR/include"
ensure_parent_dir "$PREFIX_DIR/lib"

DEPENDENCY_CPPFLAGS="$DEPENDENCY_CPPFLAGS -I$GPG_ERROR_PREFIX/include"
DEPENDENCY_LDFLAGS="$DEPENDENCY_LDFLAGS -L$GPG_ERROR_PREFIX/lib"
DEPENDENCY_SIGNATURE_EXTRA="PREFIX_DIR=$PREFIX_DIR GPG_ERROR_PREFIX=$GPG_ERROR_PREFIX CONFIGURE_ARGS=--disable-shared,--enable-static,--disable-asm"

compute_signature "$STATE_DIR/$SIGNATURE_NAME.current" \
  "$SOURCE_DIR/configure" \
  "$SOURCE_DIR/aclocal.m4" \
  "$SOURCE_DIR/Makefile.in" \
  "$SOURCE_DIR/config.h.in" \
  "$SOURCE_DIR/src/Makefile.in" \
  "$GPG_ERROR_CONFIG"

CONFIGURE_ARGS=(
  "--disable-shared"
  "--enable-static"
  "--disable-asm"
  "--prefix=$PREFIX_DIR"
)

if [ ! -x "$BUILD_DIR/config.status" ] || signature_changed "$STATE_DIR" "$SIGNATURE_NAME"; then
  rm -f "$BUILD_DIR/config.cache"
  (
    cd "$BUILD_DIR"
    env \
      PATH="$GPG_ERROR_PREFIX/bin:$PATH" \
      CC="$CC" \
      AR="$AR" \
      RANLIB="$RANLIB" \
      CC_FOR_BUILD="$CC_FOR_BUILD" \
      SDKROOT="$SDKROOT" \
      CPPFLAGS="$DEPENDENCY_CPPFLAGS" \
      CFLAGS="$DEPENDENCY_CFLAGS" \
      LDFLAGS="$DEPENDENCY_LDFLAGS" \
      GPG_ERROR_CONFIG="$GPG_ERROR_CONFIG" \
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
  env PATH="$GPG_ERROR_PREFIX/bin:$PATH" GPG_ERROR_CONFIG="$GPG_ERROR_CONFIG" \
    make -C "$BUILD_DIR/mpi" -j1 all-am
  env PATH="$GPG_ERROR_PREFIX/bin:$PATH" GPG_ERROR_CONFIG="$GPG_ERROR_CONFIG" \
    make -C "$BUILD_DIR/cipher" -j1 all-am
  env PATH="$GPG_ERROR_PREFIX/bin:$PATH" GPG_ERROR_CONFIG="$GPG_ERROR_CONFIG" \
    make -C "$BUILD_DIR/src" -j1 all-am
) > "$STATE_DIR/make.log" 2>&1

install -c -m 644 "$BUILD_DIR/src/gcrypt.h" "$PREFIX_DIR/include/gcrypt.h"
install -c -m 644 "$SOURCE_DIR/src/gcrypt-module.h" "$PREFIX_DIR/include/gcrypt-module.h"
install -c -m 644 "$BUILD_DIR/src/.libs/libgcrypt.a" "$PREFIX_DIR/lib/libgcrypt.a"
touch "$STAMP_FILE"

commit_signature "$STATE_DIR" "$SIGNATURE_NAME"
