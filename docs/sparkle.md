# Sparkle integration

Use this document to prepare and publish Sparkle updates.

The Sparkle update archive is different from the `Fuse.zip` archive:

- `make dist` creates `Fuse.zip` for manual distribution.
- `make sparkle-zip` creates `Fuse-<version>-sparkle.zip` for Sparkle. This archive contains only `Fuse.app`.

Sparkle appcast metadata is generated on the release Mac. Publish this metadata with GitHub Pages. Sparkle signs the update archive with a local EdDSA key in the macOS login keychain.

## Feed locations

Use these feed locations:

- Staging appcast: `https://fmeunier.github.io/fuse-for-macos/appcast-staging.xml`
- Production appcast: `https://fmeunier.github.io/fuse-for-macos/appcast.xml`
- Release notes: `https://fmeunier.github.io/fuse-for-macos/release-notes/<version>.md`

## Prerequisites

Make sure that the release Mac has these items:

- Xcode and the command-line tools
- A Developer ID Application certificate
- A `notarytool` keychain profile for notarization
- The Sparkle tools in the Xcode DerivedData directory
- A Sparkle EdDSA private key in the login keychain

If the Sparkle package artifacts are not available, resolve the package dependencies:

```sh
xcodebuild -resolvePackageDependencies -project fusepb/Fuse.xcodeproj -scheme Fuse
```

Make sure that `fusepb/LocalSigning.xcconfig` or the environment specifies a valid `DEVELOPMENT_TEAM`.

## Makefile targets

Use these targets from the repository root:

```sh
make sparkle-zip                    # Build, notarize, staple, and package the Sparkle ZIP.
make sparkle-key-setup              # Generate or import the Sparkle EdDSA key.
make sparkle-key-public             # Print the Sparkle EdDSA public key.
make sparkle-key-check              # Make sure that the Sparkle private key is available.
make sparkle-release-notes          # Extract the release notes from the changelog.
make sparkle-stage-archive          # Copy the Sparkle ZIP to the staging directory.
make sparkle-github-release         # Create or update a GitHub release and upload the Sparkle ZIP.
make sparkle-appcast                # Generate the local Sparkle appcast metadata.
make sparkle-appcast-github         # Upload the Sparkle ZIP and generate the appcast.
make sparkle-github-release-staging # Run sparkle-github-release for staging.
make sparkle-appcast-staging        # Run sparkle-appcast for staging.
make sparkle-appcast-staging-github # Run sparkle-appcast-github for staging.
make sparkle-stage-clean            # Remove generated staging metadata.
```

## Set up the Sparkle signing key

Do this procedure one time on each release Mac.

1. Generate or import the EdDSA key:

   ```sh
   make sparkle-key-setup
   ```

2. Print the public key when you must copy it:

   ```sh
   make sparkle-key-public
   ```

3. Put the public key in `SUPublicEDKey` in `fusepb/Info-Fuse.plist` or in the applicable build setting when you enable the updater.

> **Important:** Do not commit the private EdDSA key. The `generate_keys` tool keeps this key in the login keychain.

## Generate release notes

The release-notes source is `fusepb/FuseHelp/_English.lproj/changelog.md`.

The changelog must contain this heading for the release version:

```text
## What's new in Fuse for macOS <version>
```

Generate the release notes:

```sh
make sparkle-release-notes
```

The command reads `CFBundleShortVersionString` from `fusepb/Info-Fuse.plist`. If this value is not available, the command reads `CFBundleVersion`.

To specify a different version, set `VERSION`:

```sh
make sparkle-release-notes VERSION=1.8.0
```

The command creates `.sparkle-stage/release-notes/<version>.md`.

## Generate a local staging appcast

Generate the local staging metadata:

```sh
make sparkle-appcast-staging
```

This command does these operations:

1. Build and notarize `Fuse.app` if necessary.
2. Make sure that the local EdDSA key is available.
3. Copy `Fuse-<version>-sparkle.zip` to `.sparkle-stage/`.
4. Extract `.sparkle-stage/release-notes/<version>.md`.
5. Run the Sparkle `generate_appcast` tool.
6. Change the generated release-notes links to the GitHub Pages URLs.

The command creates these files:

- `.sparkle-stage/appcast-staging.xml`
- `.sparkle-stage/Fuse-<version>-sparkle.zip`
- `.sparkle-stage/release-notes/<version>.md`

The default URL prefixes are:

- Downloads: `https://fmeunier.github.io/fuse-for-macos/`
- Release notes: `https://fmeunier.github.io/fuse-for-macos/release-notes/`

If a different host supplies the archive, specify its URL prefix:

```sh
make sparkle-appcast SPARKLE_DOWNLOAD_URL_PREFIX='https://example.invalid/path/'
```

## Publish a staging GitHub release

Create or update the staging prerelease:

```sh
make sparkle-github-release-staging
```

This command does these operations:

1. Use the staged `Fuse-<version>-sparkle.zip`.
2. Create the `sparkle-staging-<version>` prerelease if it does not exist.
3. Update the title and notes if the prerelease exists.
4. Upload the Sparkle ZIP with `gh release upload --clobber`.
5. Print the GitHub Releases download URL prefix.

The default repository is `fmeunier/fuse-for-macos`.

To change the repository, tag, or title, set the applicable variables:

```sh
make sparkle-github-release-staging \
  SPARKLE_GITHUB_REPO=owner/repo \
  SPARKLE_GITHUB_RELEASE_TAG=custom-staging-tag \
  SPARKLE_GITHUB_RELEASE_TITLE='Fuse 1.8.0 staging update'
```

To upload the ZIP and generate the staging appcast in one operation, use:

```sh
make sparkle-appcast-staging-github
```

This command uses these URL prefixes:

- Downloads: `https://github.com/<owner>/<repo>/releases/download/<tag>/`
- Release notes: `https://fmeunier.github.io/fuse-for-macos/release-notes/`

The enclosure URL points directly to the GitHub Releases asset. The command does not rebuild or package the app between the upload and appcast operations. Thus, the uploaded ZIP agrees with the signed appcast metadata.

> **Warning:** Do not replace an existing GitHub asset at the same URL. GitHub can supply the old ZIP from its cache. Sparkle will reject the update if the cached ZIP does not agree with the appcast length or signature. Use a new tag or a new asset name.

## Publish a staging update

Use this procedure to publish a staging update.

For the standard procedure, run:

```sh
scripts/release-staging-sparkle.sh
```

The script uses a new temporary staging directory by default. This prevents `generate_appcast` from finding duplicate archives from previous tests. The script builds `Fuse.zip` and the Sparkle ZIP from the same notarized `Fuse.app`. It also publishes the staging appcast and release notes to `gh-pages`.

Use these options when necessary:

```sh
scripts/release-staging-sparkle.sh --tag sparkle-staging-1.9.0-r1
scripts/release-staging-sparkle.sh --skip-pages-publish
scripts/release-staging-sparkle.sh --staging-dir /tmp/fuse-sparkle-stage
```

### 1. Check the prerequisites

1. Resolve the Sparkle package dependencies:

   ```sh
   xcodebuild -resolvePackageDependencies -project fusepb/Fuse.xcodeproj -scheme Fuse
   ```

2. Make sure that the Sparkle private key is available:

   ```sh
   make sparkle-key-check
   ```

3. Make sure that the notarization profile is valid:

   ```sh
   xcrun notarytool history --keychain-profile fuse-notarize >/dev/null
   ```

4. Make sure that GitHub CLI authentication is valid:

   ```sh
   gh auth status
   ```

5. Make sure that the `gh-pages` branch exists.

6. Make sure that GitHub Pages publishes from the root of the `gh-pages` branch.

7. Make sure that the changelog contains release notes for the version.

### 2. Build and upload the staging archive

1. Remove old staging files:

   ```sh
   make sparkle-stage-clean
   ```

2. Build, notarize, upload, and generate the appcast:

   ```sh
   make sparkle-appcast-staging-github
   ```

   To use a different staging directory, run:

   ```sh
   make sparkle-appcast-staging-github SPARKLE_STAGING_DIR=/tmp/fuse-sparkle-stage
   ```

3. Make sure that these files exist:

   - `.sparkle-stage/appcast-staging.xml`
   - `.sparkle-stage/Fuse-<version>-sparkle.zip`
   - `.sparkle-stage/release-notes/<version>.md`

### 3. Publish the staging metadata

Skip this procedure if the release script published the GitHub Pages files.

1. Set the version and worktree paths:

   ```sh
   VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' fusepb/Info-Fuse.plist 2>/dev/null || \
     /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' fusepb/Info-Fuse.plist)
   PAGES_DIR=/tmp/fuse-gh-pages
   ```

2. Add a worktree for the `gh-pages` branch:

   ```sh
   git worktree add "$PAGES_DIR" gh-pages
   ```

3. Copy the appcast to the branch root:

   ```sh
   cp .sparkle-stage/appcast-staging.xml "$PAGES_DIR"/
   ```

4. Copy the release notes:

   ```sh
   mkdir -p "$PAGES_DIR"/release-notes
   cp ".sparkle-stage/release-notes/${VERSION}.md" "$PAGES_DIR"/release-notes/
   ```

5. Commit and push the metadata:

   ```sh
   cd "$PAGES_DIR"
   touch .nojekyll
   git add appcast-staging.xml release-notes .nojekyll
   git commit -m "Publish staging Sparkle metadata"
   git push origin gh-pages
   cd -
   ```

6. Remove the worktree:

   ```sh
   git worktree remove "$PAGES_DIR"
   ```

The branch root must contain these files:

- `appcast-staging.xml`
- `release-notes/<version>.md`
- `.nojekyll`

If you have a local checkout of `gh-pages`, update that checkout instead.

### 4. Verify the staging update

1. Get the published appcast:

   ```sh
   curl -fsSL https://fmeunier.github.io/fuse-for-macos/appcast-staging.xml
   ```

2. Get the published release notes:

   ```sh
   curl -fsSL "https://fmeunier.github.io/fuse-for-macos/release-notes/${VERSION}.md"
   ```

3. Get the GitHub prerelease information:

   ```sh
   gh release view "sparkle-staging-${VERSION}" -R fmeunier/fuse-for-macos
   ```

4. Make sure that the enclosure URL has this form:

   ```text
   https://github.com/fmeunier/fuse-for-macos/releases/download/sparkle-staging-<version>/Fuse-<version>-sparkle.zip
   ```

5. Make sure that the release-notes URL has this form:

   ```text
   https://fmeunier.github.io/fuse-for-macos/release-notes/<version>.md
   ```

6. Make sure that the appcast and release-notes URLs return HTTP status 200.

7. Make sure that the GitHub asset size is equal to the appcast enclosure `length`.

8. Use a staging build to check for the update.

> **Note:** GitHub Pages can take time to publish the files. If `curl` returns HTTP status 404 immediately after the push, wait and try again.

## Publish a production update

Use this procedure only after the staging update passes all tests.

For the standard procedure, run:

```sh
scripts/release-public-sparkle.sh
```

The script publishes these items:

- `appcast.xml`
- A normal GitHub release
- `release-notes/<version>.md`

The script uses these defaults:

- Git tag: `fuse-for-macos-<version>`
- GitHub release title: `Fuse for macOS <version>`
- Appcast path: `appcast.xml`
- Feed override: `SPARKLE_FEED_URL=https://fmeunier.github.io/fuse-for-macos/appcast.xml`

Use these options when necessary:

```sh
scripts/release-public-sparkle.sh --tag fuse-for-macos-1.9.0
scripts/release-public-sparkle.sh --title 'Fuse for macOS 1.9.0'
scripts/release-public-sparkle.sh --skip-pages-publish
scripts/release-public-sparkle.sh --staging-dir /tmp/fuse-sparkle-public
```

### 1. Check the production tag

1. Set `VERSION` to the app version.

2. Make sure that the `fuse-for-macos-$VERSION` tag exists.

The production script uses `gh release create --verify-tag`. The command stops if the tag does not exist. It does not create the tag.

### 2. Build and publish the production update

Run:

```sh
make dist sparkle-appcast-github \
  SPARKLE_APPCAST=appcast.xml \
  SPARKLE_GITHUB_RELEASE_TAG="fuse-for-macos-$VERSION" \
  SPARKLE_GITHUB_RELEASE_TITLE="Fuse for macOS $VERSION" \
  SPARKLE_GITHUB_RELEASE_PRERELEASE=0 \
  SPARKLE_GITHUB_VERIFY_TAG=1
```

This command builds the distribution archives, creates the GitHub release, uploads the Sparkle ZIP, and generates `appcast.xml`.

Publish `appcast.xml` and `release-notes/<version>.md` to the root of the `gh-pages` branch. Use the same GitHub Pages procedure as for staging, but replace `appcast-staging.xml` with `appcast.xml`.

### 3. Verify the production update

1. Get the production appcast:

   ```sh
   curl -fsSL https://fmeunier.github.io/fuse-for-macos/appcast.xml
   ```

2. Get the release notes:

   ```sh
   curl -fsSL "https://fmeunier.github.io/fuse-for-macos/release-notes/${VERSION}.md"
   ```

3. Get the GitHub release information:

   ```sh
   gh release view "fuse-for-macos-${VERSION}" -R fmeunier/fuse-for-macos
   ```

4. Install an older build that uses `appcast.xml`.

5. Select **Help > Check for Updates…**.

6. Make sure that Sparkle finds the new version.

7. Make sure that Sparkle displays the correct release notes.

8. Make sure that Sparkle downloads the update.

9. Make sure that Sparkle validates the signature.

10. Make sure that Sparkle installs the update.

11. Make sure that the app starts again.

12. Make sure that the app shows the new version.

13. Make sure that Gatekeeper permits the updated app to start.

## Troubleshooting

### Sparkle reports an incorrect signature

First, examine the macOS log:

```sh
log show --last 15m --predicate 'process == "Fuse" OR subsystem == "org.sparkle-project.Sparkle"' --style compact
```

Look for this type of message:

```text
expected content length ... differs from the downloaded file length ...
```

This message usually means that GitHub supplied an old asset from its cache.

1. Upload the corrected ZIP with a new asset name or a new tag.
2. Generate the appcast again.
3. Make sure that the enclosure URL changes.
4. Publish the appcast again.

### The appcast has incorrect links

Use `make sparkle-appcast-staging-github` when GitHub Releases supplies the archive. This command generates the appcast with the final download URL.

Use `make sparkle-appcast-staging` only for local tests or for archives that are not on GitHub Releases. Set the final `SPARKLE_DOWNLOAD_URL_PREFIX` when necessary.

If you must change links after appcast generation, use `fusepb/scripts/patch_sparkle_appcast.py`. Do not edit the XML manually.

## Limitations

- The EdDSA private key must be available before `generate_appcast` can sign the Sparkle ZIP.
- Signed feeds are not enabled. Sparkle uses archive signing over HTTPS.
- GitHub Pages publication is a manual Git operation on the `gh-pages` branch.
- GitHub can cache a replaced release asset. Use a new URL for each corrected archive.
