# FuseGenerator

`FuseGenerator` is the Quick Look generator plugin used by the macOS Fuse ecosystem for ZX Spectrum files. It builds a `.qlgenerator` bundle so Finder can render previews and thumbnails for supported file types.

## What this project is

- A macOS Quick Look plugin (`FuseGenerator.qlgenerator`) written in Objective-C/C.
- A component used by the Fuse macOS app packaging flow.
- A consumer of vendored `libspectrum` sources for ZX Spectrum file parsing.

## Repository layout

- `GeneratePreviewForURL.m` and `GenerateThumbnailForURL.m`: Quick Look entry points.
- `LibspectrumSCRExtractor.*`: screen extraction glue around libspectrum APIs.
- `libspectrum/`: vendored upstream libspectrum source (managed as a squashed subtree).
- `FuseGenerator.xcodeproj/`: Xcode project for building the plugin bundle.

## Requirements

- macOS with Xcode command-line tools.
- Apple Silicon/macOS target environment used by this repository.

## Build

From this directory:

```sh
xcodebuild -configuration Release
```

The resulting plugin bundle is produced by Xcode under the build products path.

## Development workflow

Typical cycle:

```sh
xcodebuild clean -configuration Release
xcodebuild -configuration Release
```

Run a Release build before pushing migration or dependency updates.

## Release process

Releases are built by GitHub Actions using `FuseGenerator/.github/workflows/release.yml`.

### Trigger

- Push a tag that matches `fuse-generator-*` (for example `fuse-generator-1.5.6`).

### What the workflow does

1. Checks out the repository.
2. Builds `FuseGenerator` in `Release` configuration.
3. Packages `FuseGenerator.qlgenerator` as `FuseGenerator-<version>.qlgenerator.zip` (for tag `fuse-generator-1.5.0`, asset is `FuseGenerator-1.5.0.qlgenerator.zip`).
4. Computes SHA-256 for the zip.
5. Creates a GitHub Release for the tag and uploads the zip.
6. Writes the checksum in the release body.

### Running a release

```sh
git tag fuse-generator-1.5.6
git push origin fuse-generator-1.5.6
```

After the workflow completes, verify on GitHub:

- The release exists for the pushed tag.
- The zip asset is attached.
- The SHA-256 value appears in release notes.

### Update `Package.swift` for each release

`Package.swift` declares a binary target that points at the published release zip and checksum.

After publishing a new release tag:

1. Copy the new asset URL from the release page.
2. Copy the SHA-256 from release notes (or asset digest).
3. Update `url` and `checksum` in `Package.swift`.
4. Commit and push the `Package.swift` update.

Current bootstrap state: `Package.swift` points at `fuse-generator-1.5.0-rc3` until a final non-RC tag is published.

### Testing the workflow safely

Use a throwaway pre-release style tag first (still matches `fuse-generator-*`):

```sh
git tag fuse-generator-1.5.6-rc1
git push origin fuse-generator-1.5.6-rc1
```

After validation, delete the test tag and release in GitHub UI (or CLI), then create the real release tag.

## Updating libspectrum

`libspectrum/` is vendored as a **squashed git subtree** (not a submodule).

### One-time remote setup

```sh
git remote add libspectrum git@github.com:fmeunier/libspectrum.git
```

If GitHub migration is not complete for `libspectrum`, use the SourceForge URL instead.

### Pull a newer upstream tag/commit

```sh
git fetch libspectrum --tags
git subtree pull --prefix=libspectrum libspectrum <tag-or-commit> --squash
```

### Required local patch sync

These files are lightly modified relative to upstream `libspectrum` and must be reviewed and patched in sync during every `libspectrum` upgrade:

- `config.h`
- `generate.pl`
- `libspectrum.h`

After updating `libspectrum/`, reconcile those three files against upstream changes before committing.

### Verify and commit

```sh
xcodebuild -configuration Release
git commit -m "Update libspectrum subtree to <tag-or-commit>"
```

## Notes

- Keep `libspectrum` updates squashed to maintain a compact history in this repository.
- Do not reintroduce `libspectrum` as a git submodule.
