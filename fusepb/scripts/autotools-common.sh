#!/bin/bash

set -euo pipefail

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

script_dir() {
  local source_path

  source_path="${BASH_SOURCE[0]}"
  while [ -h "$source_path" ]; do
    source_path="$(readlink "$source_path")"
  done

  cd -- "$(dirname -- "$source_path")" && pwd -P
}

workspace_root() {
  if [ -n "${FUSE_REPO_ROOT:-}" ]; then
    cd -- "$FUSE_REPO_ROOT" && pwd -P
    return
  fi

  cd -- "$(script_dir)/../.." && pwd -P
}

prepend_common_paths() {
  local root

  root="$(workspace_root)"

  PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$PATH"
  PATH="$root/fusepb/scripts:$PATH"
  export PATH
}

resolve_build_context() {
  local root default_temp default_derived

  root="$(workspace_root)"
  default_temp="$root/build/tmp"
  default_derived="$root/build/derived"

  SRCROOT="${SRCROOT:-$root}"
  TARGET_TEMP_DIR="${TARGET_TEMP_DIR:-$default_temp}"
  DERIVED_FILE_DIR="${DERIVED_FILE_DIR:-$default_derived}"

  export SRCROOT TARGET_TEMP_DIR DERIVED_FILE_DIR
}

resolve_arch() {
  if [ -n "${CURRENT_ARCH:-}" ] && [ "${CURRENT_ARCH}" != "undefined_arch" ]; then
    printf '%s\n' "$CURRENT_ARCH"
    return
  fi

  if [ -n "${ARCHS:-}" ]; then
    set -- ${ARCHS}
    printf '%s\n' "$1"
    return
  fi

  uname -m
}

resolve_toolchain() {
  local arch deployment_target sdkroot

  arch="$(resolve_arch)"
  deployment_target="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
  sdkroot="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"

  SDKROOT="$sdkroot"
  CC="${CC:-$(xcrun --sdk macosx -find clang)}"
  AR="${AR:-$(xcrun --sdk macosx -find ar)}"
  RANLIB="${RANLIB:-$(xcrun --sdk macosx -find ranlib)}"
  STRIP="${STRIP:-$(xcrun --sdk macosx -find strip)}"
  CC_FOR_BUILD="${CC_FOR_BUILD:-$CC}"

  DEPENDENCY_ARCH="$arch"
  DEPENDENCY_DEPLOYMENT_TARGET="$deployment_target"
  DEPENDENCY_CPPFLAGS="${CPPFLAGS:-} -isysroot $SDKROOT"
  DEPENDENCY_CFLAGS="${CFLAGS:-} -arch $DEPENDENCY_ARCH -isysroot $SDKROOT -mmacosx-version-min=$DEPENDENCY_DEPLOYMENT_TARGET"
  DEPENDENCY_LDFLAGS="${LDFLAGS:-} -arch $DEPENDENCY_ARCH -isysroot $SDKROOT -mmacosx-version-min=$DEPENDENCY_DEPLOYMENT_TARGET"

  export SDKROOT CC AR RANLIB STRIP CC_FOR_BUILD
  export DEPENDENCY_ARCH DEPENDENCY_DEPLOYMENT_TARGET
  export DEPENDENCY_CPPFLAGS DEPENDENCY_CFLAGS DEPENDENCY_LDFLAGS
}

ensure_generated_autotools() {
  local source_dir

  source_dir="$1"

  [ -f "$source_dir/configure" ] || die "Missing $source_dir/configure. Run the bootstrap script first."
}

ensure_parent_dir() {
  local path

  path="$1"
  mkdir -p "$path"
}

compute_signature() {
  local signature_file

  signature_file="$1"
  shift

  {
    printf 'CC=%s\n' "$CC"
    printf 'AR=%s\n' "$AR"
    printf 'RANLIB=%s\n' "$RANLIB"
    printf 'CC_FOR_BUILD=%s\n' "$CC_FOR_BUILD"
    printf 'SDKROOT=%s\n' "$SDKROOT"
    printf 'ARCH=%s\n' "$DEPENDENCY_ARCH"
    printf 'DEPLOYMENT_TARGET=%s\n' "$DEPENDENCY_DEPLOYMENT_TARGET"
    printf 'CPPFLAGS=%s\n' "$DEPENDENCY_CPPFLAGS"
    printf 'CFLAGS=%s\n' "$DEPENDENCY_CFLAGS"
    printf 'LDFLAGS=%s\n' "$DEPENDENCY_LDFLAGS"
    printf 'EXTRA=%s\n' "${DEPENDENCY_SIGNATURE_EXTRA:-}"
    while [ "$#" -gt 0 ]; do
      if [ -e "$1" ]; then
        shasum "$1"
      else
        printf 'missing %s\n' "$1"
      fi
      shift
    done
  } | shasum | awk '{ print $1 }' > "$signature_file.tmp"

  mv "$signature_file.tmp" "$signature_file"
}

signature_changed() {
  local state_dir name current previous

  state_dir="$1"
  name="$2"
  current="$state_dir/$name.current"
  previous="$state_dir/$name.last"

  if [ ! -f "$previous" ]; then
    return 0
  fi

  ! cmp -s "$current" "$previous"
}

commit_signature() {
  local state_dir name current previous

  state_dir="$1"
  name="$2"
  current="$state_dir/$name.current"
  previous="$state_dir/$name.last"

  mv "$current" "$previous"
}

default_make_jobs() {
  sysctl -n hw.ncpu 2>/dev/null || printf '4\n'
}
