#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
. "$SCRIPT_DIR/autotools-common.sh"

prepend_common_paths
ROOT="$(workspace_root)"
SOURCE_DIR="$ROOT/fusepb/deps/third_party/libgpg-error"

[ -d "$SOURCE_DIR" ] || die "Missing source directory: $SOURCE_DIR"

AUTORECONF="$(command -v autoreconf || true)"
AUTOCONF="$(command -v autoconf || true)"
AUTOMAKE="$(command -v automake || true)"
PERL_BIN="$(command -v perl || true)"
LIBTOOLIZE_BIN="$(command -v glibtoolize || command -v libtoolize || true)"

[ -n "$AUTORECONF" ] || die "autoreconf is required"
[ -n "$AUTOCONF" ] || die "autoconf is required"
[ -n "$AUTOMAKE" ] || die "automake is required"
[ -n "$PERL_BIN" ] || die "perl is required"
[ -n "$LIBTOOLIZE_BIN" ] || die "glibtoolize or libtoolize is required"

export PERL="$PERL_BIN"

printf 'Bootstrapping %s\n' "$SOURCE_DIR"
autoreconf -fi "$SOURCE_DIR"
