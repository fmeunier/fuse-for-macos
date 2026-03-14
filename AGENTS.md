# AGENTS.md

Guidance for coding agents working in `FuseGenerator`.

## Project Snapshot

- This repo builds a macOS Quick Look generator bundle: `FuseGenerator.qlgenerator`.
- Primary languages: Objective-C (manual memory management) and C.
- Build system: Xcode project at `FuseGenerator.xcodeproj`.
- Vendored dependency: `libspectrum/` (squashed subtree; not a submodule).

## Source Layout

- `GeneratePreviewForURL.m`: Quick Look preview entrypoint.
- `GenerateThumbnailForURL.m`: Quick Look thumbnail entrypoint.
- `LibspectrumSCRExtractor.{h,m}`: file loading and screen extraction bridge.
- `JWSpectrumScreen/`: screen decoding/rendering helpers.
- `main.c`: generic Apple plugin glue (treat as template code).
- `libspectrum/`: upstream code plus tests and autotools config.
- `config.h`, `generate.pl`, `libspectrum.h`: local sync-sensitive files.

## Cursor / Copilot Rules

- Checked `.cursorrules`: not present.
- Checked `.cursor/rules/`: not present.
- Checked `.github/copilot-instructions.md`: not present.
- No repository-local Cursor/Copilot policy files are currently defined.

## Build Commands

Run from repository root unless stated otherwise.

- Default release build:
  - `xcodebuild -project FuseGenerator.xcodeproj -target FuseGenerator -configuration Release`
- Default debug build:
  - `xcodebuild -project FuseGenerator.xcodeproj -target FuseGenerator -configuration Debug`
- Clean + release build:
  - `xcodebuild -project FuseGenerator.xcodeproj -target FuseGenerator -configuration Release clean build`
- Build for Apple Silicon explicitly:
  - `xcodebuild -project FuseGenerator.xcodeproj -target FuseGenerator -configuration Release -arch arm64`

## Lint / Static Analysis

There is no dedicated linter config (`.clang-format`, `.editorconfig`, SwiftLint, etc.).

- Use compiler warnings as the baseline quality gate:
  - `xcodebuild -project FuseGenerator.xcodeproj -target FuseGenerator -configuration Release build`
- Optional static analysis pass:
  - `xcodebuild -project FuseGenerator.xcodeproj -target FuseGenerator -configuration Release analyze`

## Test Commands

There is no XCTest target in `FuseGenerator.xcodeproj`.
Testing is done via vendored `libspectrum` tests.

### Full libspectrum test run

Run from `libspectrum/`:

- First-time setup from git checkout:
  - `./autogen.sh`
  - `./configure`
- Build:
  - `make -j$(sysctl -n hw.ncpu)`
- Run all tests:
  - `make check`

### Run a single libspectrum test (important)

The test binary accepts test numbers and ranges.

- Build the test binary (from `libspectrum/`):
  - `make test/test`
- Run one test by number:
  - `./test/test 24`
- Run a range:
  - `./test/test 24-30`
- Run selected tests:
  - `./test/test 1 15 24 74`

Notes:

- Test names are defined in `libspectrum/test/test.c` (`tests[]` table).
- If run with no args, `./test/test` executes all tests.

## Quick Look Manual Verification

After building, manual smoke checks are useful:

- Reload Quick Look plugins:
  - `qlmanage -r`
- Optionally clear cache:
  - `qlmanage -r cache`
- Preview a sample file:
  - `qlmanage -p /path/to/sample.sna`

## Style And Conventions

Follow existing local style over personal preference. This repo intentionally mixes older C/ObjC styles.

### Imports / Includes

- C system headers: `#include <...>`.
- Project headers: `#include "..."`.
- Objective-C headers: `#import "..."` (or framework import where used).
- Keep include groups stable and avoid unnecessary reorder churn.

### Formatting

- Do not apply broad reformatting.
- Preserve file-local indentation style:
  - `JWSpectrumScreen/*` uses tabs heavily.
  - `LibspectrumSCRExtractor.m` mostly uses two-space indentation.
- Prefer existing brace/spacing style (`if( cond )`, `switch( x )`, etc.) in each file.
- Keep line wrapping consistent with surrounding code.

### Types

- C code targets C99 (`GCC_C_LANGUAGE_STANDARD = c99`).
- Use project/native types where already established:
  - `size_t`, `int`, `unsigned char`, `libspectrum_*` types.
  - Cocoa/CoreFoundation types in ObjC entrypoints.
- Do not introduce C++ features or Objective-C ARC-only constructs.

### Naming

- Objective-C classes: `PascalCase` (`LibspectrumSCRExtractor`, `JWSpectrumScreen`).
- Objective-C methods: lower camel case with selector labels.
- C functions/variables: `snake_case` in libspectrum-facing code.
- Macros/constants: `UPPER_SNAKE_CASE` (`STANDARD_SCR_SIZE`, `HIRESCOLMASK`).
- Keep compatibility naming when touching vendored libspectrum code.

### Memory Management

- This codebase uses manual retain/release (non-ARC).
- Use `NSAutoreleasePool` in plugin callbacks as done today.
- Balance ownership calls (`alloc/init`, `retain`, `release`, `autorelease`).
- For C allocations/mappings, always free/unmap on all error paths.

### Error Handling

- Prefer early returns on failure.
- Check return codes from libspectrum and POSIX calls.
- Log meaningful failures using existing patterns (`NSLog`, `fprintf`).
- Preserve silent-no-op behavior where intentional (eg unsupported classes, no preview for tape).

### Control Flow

- Keep `switch` handling explicit for machine/class enums.
- Maintain existing fallthrough behavior only when deliberate.
- Avoid clever refactors that obscure compatibility logic.

## Files Requiring Extra Care

- `main.c`: header explicitly says not to modify; avoid edits unless user asks.
- `libspectrum/`: vendored subtree; keep changes minimal and intentional.
- `config.h`, `generate.pl`, `libspectrum.h`: must stay synchronized during libspectrum upgrades.

## Patch Scope Expectations

- Prefer focused diffs; avoid unrelated cleanup.
- Keep generated artifacts out of commits unless regeneration is the purpose.
- When updating vendored code, document upstream source/tag in commit or PR text.
