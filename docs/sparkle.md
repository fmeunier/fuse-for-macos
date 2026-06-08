# Sparkle integration

This repository keeps Sparkle update publishing separate from the existing human-facing `Fuse.zip` release archive.

## Current shape

- `make dist` produces the traditional `Fuse.zip` archive for manual distribution.
- `make sparkle-zip` produces `Fuse-<version>-sparkle.zip`, containing only `Fuse.app`.
- staging appcast metadata is generated locally and is intended for publication to GitHub Pages.
- Sparkle archive signing uses a local EdDSA key stored in the macOS login Keychain.

The current staging feed layout is:

- appcast: `https://fmeunier.github.io/fuse-for-macos/appcast-staging.xml`
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
make sparkle-zip             # build, notarize, staple, and package Fuse-<version>-sparkle.zip
make sparkle-key-setup       # generate or import the local Sparkle EdDSA key via generate_keys
make sparkle-key-public      # print the existing Sparkle EdDSA public key
make sparkle-key-check       # fail if the local Sparkle private key is missing
make sparkle-release-notes   # extract release-notes/<version>.md from changelog.md
make sparkle-stage-archive   # copy the Sparkle ZIP into the local staging tree
make sparkle-appcast-staging # generate local staging appcast metadata
make sparkle-stage-clean     # remove generated staging metadata
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

The output staging tree is:

- `.sparkle-stage/appcast-staging.xml`
- `.sparkle-stage/Fuse-<version>-sparkle.zip`
- `.sparkle-stage/release-notes/<version>.md`

The generated appcast currently defaults to these URL prefixes:

- downloads: `https://fmeunier.github.io/fuse-for-macos/`
- release notes: `https://fmeunier.github.io/fuse-for-macos/release-notes/`

If the published archive host differs from Pages, override the download prefix:

```sh
make sparkle-appcast-staging SPARKLE_DOWNLOAD_URL_PREFIX='https://example.invalid/path/'
```

## Current limitations

- `make sparkle-appcast-staging` only generates local metadata; publication to GitHub Releases and GitHub Pages is documented separately.
- the archive signing key must exist locally before `generate_appcast` can sign the Sparkle ZIP.
- signed feeds are intentionally not enabled yet; the current plan is archive signing over HTTPS only.
- the final GitHub Releases asset URL handling remains part of the staging publication workflow rather than this local generation step.
