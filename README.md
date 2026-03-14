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
