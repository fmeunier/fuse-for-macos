#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release-staging-sparkle.sh [--tag TAG] [--pages-dir DIR] [--staging-dir DIR] [--skip-pages-publish]

Build the manual and Sparkle staging release artifacts from the same notarized
Fuse.app, then optionally publish the staging appcast and release notes to the
local gh-pages worktree.

Options:
  --tag TAG             Override the GitHub prerelease tag.
  --pages-dir DIR       Temporary gh-pages worktree path.
                        Default: /tmp/fuse-gh-pages
  --staging-dir DIR     Sparkle staging metadata directory.
                        Default: temporary directory under /tmp
  --skip-pages-publish  Stop after generating staging metadata.
  -h, --help            Show this help.
EOF
}

TAG=
PAGES_DIR=/tmp/fuse-gh-pages
STAGING_DIR=
SKIP_PAGES_PUBLISH=0
WORKTREE_ADDED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --tag)
      [ $# -ge 2 ] || { echo "error: --tag requires a value" >&2; exit 2; }
      TAG="$2"
      shift 2
      ;;
    --pages-dir)
      [ $# -ge 2 ] || { echo "error: --pages-dir requires a value" >&2; exit 2; }
      PAGES_DIR="$2"
      shift 2
      ;;
    --staging-dir)
      [ $# -ge 2 ] || { echo "error: --staging-dir requires a value" >&2; exit 2; }
      STAGING_DIR="$2"
      shift 2
      ;;
    --skip-pages-publish)
      SKIP_PAGES_PUBLISH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cleanup() {
  if [ "$WORKTREE_ADDED" -eq 1 ] && [ -d "$PAGES_DIR" ]; then
    git -C "$PAGES_DIR" status --short || true
    git worktree remove --force "$PAGES_DIR" || true
  fi
}
trap cleanup EXIT

wait_for_url() {
  local url=$1
  local attempts=${2:-12}
  local sleep_seconds=${3:-10}
  local i

  for i in $(seq 1 "$attempts"); do
    if curl -fsSL "$url" >/dev/null; then
      return 0
    fi
    printf '    waiting for %s (%s/%s)\n' "$url" "$i" "$attempts"
    sleep "$sleep_seconds"
  done

  echo "error: timed out waiting for $url" >&2
  return 1
}

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "error: run this script from inside the repository" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

if [ -z "$STAGING_DIR" ]; then
  STAGING_DIR=$(mktemp -d /tmp/fuse-sparkle-stage.XXXXXX)
else
  mkdir -p "$STAGING_DIR"
fi

VERSION=$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' fusepb/Info-Fuse.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' fusepb/Info-Fuse.plist
)

if [ -z "$TAG" ]; then
  TAG="sparkle-staging-${VERSION}"
fi

APPCAST="$STAGING_DIR/appcast-staging.xml"
RELEASE_NOTES="$STAGING_DIR/release-notes/${VERSION}.md"

printf '==> Repository: %s\n' "$REPO_ROOT"
printf '==> Version: %s\n' "$VERSION"
printf '==> Staging tag: %s\n' "$TAG"
printf '==> Staging dir: %s\n' "$STAGING_DIR"

printf '==> Checking prerequisites\n'
xcodebuild -resolvePackageDependencies -project fusepb/Fuse.xcodeproj -scheme Fuse
make sparkle-key-check
xcrun notarytool history --keychain-profile fuse-notarize >/dev/null
gh auth status >/dev/null

printf '==> Building manual and Sparkle staging artifacts from the same notarized app\n'
make dist sparkle-appcast-staging-github \
  SPARKLE_GITHUB_RELEASE_TAG="$TAG" \
  SPARKLE_STAGING_DIR="$STAGING_DIR"

printf '==> Generated artifacts\n'
printf '    %s/Fuse.zip\n' "$REPO_ROOT"
printf '    %s/Fuse-%s-sparkle.zip\n' "$REPO_ROOT" "$VERSION"
printf '    %s\n' "$APPCAST"
printf '    %s\n' "$RELEASE_NOTES"

if [ "$SKIP_PAGES_PUBLISH" -eq 1 ]; then
  printf '==> Skipping gh-pages publication as requested\n'
  exit 0
fi

printf '==> Publishing staging metadata to gh-pages via %s\n' "$PAGES_DIR"
if [ -e "$PAGES_DIR" ]; then
  echo "error: pages dir already exists: $PAGES_DIR" >&2
  echo "       remove it, choose --pages-dir, or rerun with --skip-pages-publish" >&2
  exit 1
fi

git worktree add "$PAGES_DIR" gh-pages
WORKTREE_ADDED=1
cp "$APPCAST" "$PAGES_DIR/"
mkdir -p "$PAGES_DIR/release-notes"
cp "$RELEASE_NOTES" "$PAGES_DIR/release-notes/"
: > "$PAGES_DIR/.nojekyll"

git -C "$PAGES_DIR" add appcast-staging.xml release-notes .nojekyll
if git -C "$PAGES_DIR" diff --cached --quiet; then
  printf '==> No gh-pages metadata changes to commit\n'
else
  git -C "$PAGES_DIR" commit -m "Publish ${VERSION} staging Sparkle metadata"
  git -C "$PAGES_DIR" push origin gh-pages
fi

printf '==> Verifying published metadata\n'
wait_for_url https://fmeunier.github.io/fuse-for-macos/appcast-staging.xml
wait_for_url "https://fmeunier.github.io/fuse-for-macos/release-notes/${VERSION}.md"
gh release view "$TAG" -R fmeunier/fuse-for-macos >/dev/null

printf '==> Done\n'
printf 'Manual update test remains a human step: Help > Check for Updates…\n'
