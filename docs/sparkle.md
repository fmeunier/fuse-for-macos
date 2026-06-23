# Sparkle integration

This repository keeps Sparkle update publishing separate from the existing human-facing `Fuse.zip` release archive.

## Current shape

- `make dist` produces the traditional `Fuse.zip` archive for manual distribution.
- `make sparkle-zip` produces `Fuse-<version>-sparkle.zip`, containing only `Fuse.app`.
- Sparkle appcast metadata is generated locally and is intended for publication to GitHub Pages.
- Sparkle archive signing uses a local EdDSA key stored in the macOS login Keychain.

The feed layouts are:

- staging appcast: `https://fmeunier.github.io/fuse-for-macos/appcast-staging.xml`
- production appcast: `https://fmeunier.github.io/fuse-for-macos/appcast.xml`
- release notes: `https://fmeunier.github.io/fuse-for-macos/release-notes/<version>.md`

## Local prerequisites

You need all of the following on the release machine:

- Xcode and command line tools
- a local Developer ID Application certificate for code signing
- a configured `notarytool` keychain profile for notarization
- Sparkle tools resolved via Swift Package Manager in Xcode DerivedData
- a local Sparkle EdDSA private key in the login Keychain

If Sparkle package artifacts are missing, resolve them with:

```sh
xcodebuild -resolvePackageDependencies -project fusepb/Fuse.xcodeproj -scheme Fuse
```

## Sparkle Makefile targets

These targets are available in the root `Makefile`:

```sh
make sparkle-zip                    # build, notarize, staple, and package Fuse-<version>-sparkle.zip
make sparkle-key-setup              # generate or import the local Sparkle EdDSA key via generate_keys
make sparkle-key-public             # print the existing Sparkle EdDSA public key
make sparkle-key-check              # fail if the local Sparkle private key is missing
make sparkle-release-notes          # extract release-notes/<version>.md from changelog.md
make sparkle-stage-archive          # copy the Sparkle ZIP into the local metadata tree
make sparkle-github-release         # create/update a GitHub release and upload the Sparkle ZIP
make sparkle-appcast                # generate local Sparkle appcast metadata
make sparkle-appcast-github         # upload the Sparkle ZIP and generate the appcast in one step
make sparkle-github-release-staging # staging alias for sparkle-github-release
make sparkle-appcast-staging        # staging alias for sparkle-appcast
make sparkle-appcast-staging-github # staging alias for sparkle-appcast-github
make sparkle-stage-clean            # remove generated local metadata
```

## Sparkle signing key setup

Run this once per Mac:

```sh
make sparkle-key-setup
```

This uses Sparkle's `generate_keys` tool. The private EdDSA key stays in the login Keychain and must not be committed to the repository.

To print the existing public key again:

```sh
make sparkle-key-public
```

When updater wiring is enabled in the app, copy that public key into `SUPublicEDKey` in `fusepb/Info-Fuse.plist` or the eventual substituted build setting.

## Release notes extraction

The source of truth for Sparkle release notes is:

- `fusepb/FuseHelp/_English.lproj/changelog.md`

Per-version notes are extracted from the heading:

- `## What's new in Fuse for macOS <version>`

Generate staged notes with:

```sh
make sparkle-release-notes
```

By default, `VERSION` comes from `CFBundleShortVersionString` in `fusepb/Info-Fuse.plist` and falls back to `CFBundleVersion`.

Override it explicitly if needed:

```sh
make sparkle-release-notes VERSION=1.8.0
```

The generated file is written to:

- `.sparkle-stage/release-notes/<version>.md`

## Local staging appcast generation

Generate local staging metadata with:

```sh
make sparkle-appcast-staging
```

This target currently:

1. builds and notarizes `Fuse.app` if needed via `make sparkle-zip`
2. verifies that the local Sparkle EdDSA key exists
3. stages `Fuse-<version>-sparkle.zip` in `.sparkle-stage/`
4. extracts `.sparkle-stage/release-notes/<version>.md`
5. runs Sparkle `generate_appcast`
6. patches the generated release-notes links back to the published Pages URL shape

The output staging tree is:

- `.sparkle-stage/appcast-staging.xml`
- `.sparkle-stage/Fuse-<version>-sparkle.zip`
- `.sparkle-stage/release-notes/<version>.md`

The generated appcast currently defaults to these URL prefixes:

- downloads: `https://fmeunier.github.io/fuse-for-macos/`
- release notes: `https://fmeunier.github.io/fuse-for-macos/release-notes/`

If the published archive host differs from Pages, override the download prefix:

```sh
make sparkle-appcast SPARKLE_DOWNLOAD_URL_PREFIX='https://example.invalid/path/'
```

## Staging GitHub Release publication

Create or update the staging GitHub prerelease and upload the Sparkle ZIP with:

```sh
make sparkle-github-release-staging
```

This target currently:

1. reuses the staged `Fuse-<version>-sparkle.zip`
2. creates `sparkle-staging-<version>` as a GitHub prerelease when it does not exist yet
3. updates the prerelease title and notes when it already exists
4. uploads the Sparkle ZIP asset with `gh release upload --clobber`
5. prints the GitHub Releases download URL prefix used by the staging appcast flow

By default the target publishes to `fmeunier/fuse-for-macos`.
Override any of these if needed:

```sh
make sparkle-github-release-staging \
  SPARKLE_GITHUB_REPO=owner/repo \
  SPARKLE_GITHUB_RELEASE_TAG=custom-staging-tag \
  SPARKLE_GITHUB_RELEASE_TITLE='Fuse 1.8.0 staging update'
```

Generate the staging appcast for the GitHub Releases staging path in one step with:

```sh
make sparkle-appcast-staging-github
```

This runs the GitHub upload flow first and then regenerates the local staging appcast from the already-staged archive and release notes with:

- downloads: `https://github.com/<owner>/<repo>/releases/download/<tag>/`
- release notes: `https://fmeunier.github.io/fuse-for-macos/release-notes/`

The generated enclosure URL matches the published GitHub Releases asset path directly, so no manual post-generation enclosure rewrite is needed when you use this target. The Makefile now avoids rebuilding or repackaging between the GitHub upload step and the appcast generation step, which keeps the uploaded ZIP and the signed appcast metadata in sync.

Important: if you need to republish the same version after fixing the archive, prefer a new asset name or a new release tag instead of replacing the existing GitHub asset in place. GitHub's CDN may continue serving the older ZIP for a while at the original URL, which will make Sparkle reject the update if the appcast length/signature was generated from the newer ZIP.

## Staging publication procedure

Use this end-to-end order for a staging publish.

If you want the deterministic steps wrapped in one command, use:

```sh
scripts/release-staging-sparkle.sh
```

Useful options:

```sh
scripts/release-staging-sparkle.sh --tag sparkle-staging-1.9.0-r1
scripts/release-staging-sparkle.sh --skip-pages-publish
scripts/release-staging-sparkle.sh --staging-dir /tmp/fuse-sparkle-stage
```

The script runs the prerequisite checks, uses a fresh temporary staging directory by default so `generate_appcast` does not see old duplicate archives from earlier rehearsals, builds both `Fuse.zip` and the Sparkle ZIP from the same notarized `Fuse.app`, generates staging metadata, and publishes the staging appcast plus release notes to `gh-pages` unless `--skip-pages-publish` is used.

### 1. Check local prerequisites

Verify the release machine is ready:

```sh
xcodebuild -resolvePackageDependencies -project fusepb/Fuse.xcodeproj -scheme Fuse
make sparkle-key-check
xcrun notarytool history --keychain-profile fuse-notarize >/dev/null
gh auth status
```

Also confirm that:

- `fusepb/LocalSigning.xcconfig` or your environment provides a valid `DEVELOPMENT_TEAM`
- the `gh-pages` branch exists and is configured as the GitHub Pages source, published from the branch root
- the release notes for the version you are publishing exist in `fusepb/FuseHelp/_English.lproj/changelog.md`

### 2. Build, notarize, upload, and generate staging metadata

The normal staging command is:

```sh
make sparkle-stage-clean
make sparkle-appcast-staging-github
```

If you want to avoid reusing `.sparkle-stage` entirely, override the staging directory for the run:

```sh
make sparkle-appcast-staging-github SPARKLE_STAGING_DIR=/tmp/fuse-sparkle-stage
```

That performs the release steps in this order:

1. build `Fuse.app`
2. notarize it and staple the notarization ticket
3. create `Fuse-<version>-sparkle.zip`
4. extract `.sparkle-stage/release-notes/<version>.md`
5. create or update the GitHub prerelease `sparkle-staging-<version>`
6. upload the Sparkle ZIP asset to that prerelease
7. regenerate `.sparkle-stage/appcast-staging.xml` with the final GitHub Releases download URL prefix

Expected local outputs:

- `.sparkle-stage/appcast-staging.xml`
- `.sparkle-stage/Fuse-<version>-sparkle.zip`
- `.sparkle-stage/release-notes/<version>.md`

### 3. Publish the Pages content

Publish only the metadata files to the `gh-pages` branch root:

```sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' fusepb/Info-Fuse.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' fusepb/Info-Fuse.plist)
PAGES_DIR=/tmp/fuse-gh-pages

git worktree add "$PAGES_DIR" gh-pages
cp .sparkle-stage/appcast-staging.xml "$PAGES_DIR"/
mkdir -p "$PAGES_DIR"/release-notes
cp ".sparkle-stage/release-notes/${VERSION}.md" "$PAGES_DIR"/release-notes/
cd "$PAGES_DIR"
touch .nojekyll
git add appcast-staging.xml release-notes .nojekyll
git commit -m "Publish staging Sparkle metadata"
git push origin gh-pages
cd -
git worktree remove "$PAGES_DIR"
```

If you already have a local checkout of `gh-pages`, update that instead. The branch root should contain:

- `appcast-staging.xml`
- `release-notes/<version>.md`
- `.nojekyll`

### 4. Verify the published staging feed

Check both the Pages content and the GitHub Release asset:

```sh
curl -fsSL https://fmeunier.github.io/fuse-for-macos/appcast-staging.xml
curl -fsSL "https://fmeunier.github.io/fuse-for-macos/release-notes/${VERSION}.md"
gh release view "sparkle-staging-${VERSION}" -R fmeunier/fuse-for-macos
```

Confirm that:

- the appcast enclosure URL points at `https://github.com/fmeunier/fuse-for-macos/releases/download/sparkle-staging-<version>/Fuse-<version>-sparkle.zip`
- the release notes URL points at `https://fmeunier.github.io/fuse-for-macos/release-notes/<version>.md`
- the appcast and release-notes URLs return HTTP 200
- the downloaded GitHub release asset size matches the appcast enclosure `length`
- Sparkle update testing with a staging-wired build sees the new item

GitHub Pages publication can lag briefly after the `gh-pages` push. If the first `curl` returns 404, wait a little and retry instead of assuming the publish failed immediately.

If Sparkle reports that the update is improperly signed, check the macOS log for a length mismatch first:

```sh
log show --last 15m --predicate 'process == "Fuse" OR subsystem == "org.sparkle-project.Sparkle"' --style compact
```

A stale GitHub/CDN asset usually shows up as "expected content length ... differs from the downloaded file length ...". In that case, upload the corrected ZIP under a new asset name, regenerate the appcast so the enclosure URL changes, and republish `appcast-staging.xml`.

## Production publication procedure

Use this end-to-end order for the first public rollout after staging signoff.

If you want the deterministic steps wrapped in one command, use:

```sh
scripts/release-public-sparkle.sh
```

Useful options:

```sh
scripts/release-public-sparkle.sh --tag fuse-for-macos-1.9.0
scripts/release-public-sparkle.sh --title 'Fuse for macOS 1.9.0'
scripts/release-public-sparkle.sh --skip-pages-publish
scripts/release-public-sparkle.sh --staging-dir /tmp/fuse-sparkle-public
```

The production helper mirrors the staging helper but publishes:

- `appcast.xml`
- a normal GitHub release instead of a prerelease
- the same shared `release-notes/<version>.md`

The default production assumptions are:

- Git tag: `fuse-for-macos-<version>`
- GitHub release title: `Fuse for macOS <version>`
- Pages appcast path: `appcast.xml`
- local updater feed override: `SPARKLE_FEED_URL=https://fmeunier.github.io/fuse-for-macos/appcast.xml`

The production helper expects that tag to already exist before it creates the GitHub release. It passes `--verify-tag` through `gh release create`, so it will fail rather than creating a new tag implicitly.

The production command path is:

```sh
make dist sparkle-appcast-github \
  SPARKLE_APPCAST=appcast.xml \
  SPARKLE_GITHUB_RELEASE_TAG="fuse-for-macos-$VERSION" \
  SPARKLE_GITHUB_RELEASE_TITLE="Fuse for macOS $VERSION" \
  SPARKLE_GITHUB_RELEASE_PRERELEASE=0 \
  SPARKLE_GITHUB_VERIFY_TAG=1
```

After publishing, verify:

```sh
curl -fsSL https://fmeunier.github.io/fuse-for-macos/appcast.xml
curl -fsSL "https://fmeunier.github.io/fuse-for-macos/release-notes/${VERSION}.md"
gh release view "$VERSION" -R fmeunier/fuse-for-macos
```

Then do the conservative manual client validation against the production feed:

- install an older build that points at `appcast.xml`
- run `Help > Check for Updates…`
- confirm discovery, notes, download, signature validation, install, relaunch, and resulting version
- confirm launch/Gatekeeper behavior after update

## Manual patching notes

- Preferred path: use `make sparkle-appcast-staging-github`. It uploads first, then generates the appcast with the final GitHub Releases URL prefix, so manual enclosure URL patching should not be needed.
- `make sparkle-appcast-staging` alone is mainly for local or non-GitHub-hosted archive testing unless you explicitly pass the final `SPARKLE_DOWNLOAD_URL_PREFIX`.
- If you do need to rewrite links after generation, use `fusepb/scripts/patch_sparkle_appcast.py` instead of hand-editing XML.

## Current limitations

- the archive signing key must exist locally before `generate_appcast` can sign the Sparkle ZIP.
- signed feeds are intentionally not enabled yet; the current plan is archive signing over HTTPS only.
- Pages publication is still a manual git step on the `gh-pages` branch.
- Replacing an existing GitHub release asset in place is risky for rehearsal retries because CDN caches can keep serving the older ZIP at the same URL for a while.
