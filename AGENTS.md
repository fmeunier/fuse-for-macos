# AGENTS.md
This repository builds the macOS Cocoa port of Fuse for Apple Silicon.
Primary areas:
- `fuse/`: upstream emulator core and most C code
- `fusepb/`: macOS app wrapper, Xcode project, plugins, and staged deps
Use this file as the main root-level guide.
Also read `fuse/AGENTS.md` when changing upstream emulator code.

## Rules Sources
- Main style reference: `fuse/hacking/coding_style.txt`
- Useful upstream context: `fuse/AGENTS.md`

## Repository Layout
- `Makefile`: preferred top-level build entry point
- `fusepb/Fuse.xcodeproj`: app project
- `fusepb/Makefile`: regenerates derived files
- `fusepb/scripts/`: dependency/bootstrap scripts
- `fuse/unittests/`: built-in emulator unit tests
- `fuse/z80/`: Z80 core and standalone core test
- `fuse/hacking/`: coding style and maintainer docs

## Build Commands
Run commands from the repo root unless noted otherwise.

### Main build
```sh
make fuse
```
Preferred command. It regenerates Perl-derived files via `make -C fusepb`, builds `Fuse.app`, stages dependencies/plugins, and re-signs nested bundles.
Output: `fusepb/build/Deployment/Fuse.app`

### Clean
```sh
make clean
```

### Regenerate generated sources only
```sh
make -C fusepb
```
Use this after editing `.dat` or Perl generator inputs.

### Faster local Xcode build
```sh
xcodebuild -project fusepb/Fuse.xcodeproj -scheme Fuse -configuration Development -destination 'platform=macOS' build
```
Use this for a faster dev loop. Prefer `make fuse` for full verification.

### Lint / static analysis
There is no dedicated linter. Use Xcode's analyzer:
```sh
xcodebuild -project fusepb/Fuse.xcodeproj -scheme Fuse -configuration Development -destination 'platform=macOS' analyze
```

## Test Commands
### Xcode tests
`Fuse.xcscheme` currently has no XCTest bundles. `xcodebuild test` is not the main automated test path.

### Z80 core test
From `fuse/`:
```sh
make test
```
This builds and runs `z80/coretest` and diffs against `z80/tests/tests.expected`.

### Built-in emulator unit tests
After building the binary, run:
```sh
./fuse --unittests
```
Unit-test source lives in `fuse/unittests/unittests.c` and is compiled into the app.

### Running a single test
There is no built-in single-test filter.
To run one unit test:
1. Edit `fuse/unittests/unittests.c`.
2. In `unittests_run()`, temporarily call only the target test.
3. Rebuild.
4. Run `./fuse --unittests`.
Current top-level test functions include:
- `contention_test()`
- `floating_bus_test()`
- `floating_bus_merge_test()`
- `mempool_test()`
- `paging_test()`
- `debugger_disassemble_unittest()`
There is likewise no documented single-case selector for `make test` in `fuse/z80/`.

## Formatting
- Use 2-space indentation.
- Do not use tabs for indentation.
- Do not reformat entire files unless the task is explicitly a formatting pass.
- Match surrounding legacy style for small edits.
- Prefer `foo( a, b )` and `foo()` for no-argument C calls.
- Control-flow opening braces stay on the same line.
- Function definition opening braces go on the next line.
- Prefer cuddled `else`: `} else {`.
- In C, avoid `//` comments; use `/* ... */`.

## Imports And Includes
- In C files, include `#include <config.h>` first when applicable.
- Then include system headers, then third-party headers, then local headers.
- In Objective-C files, keep `#import` groups together and keep C `#include`s separate.
- Do not reorder large legacy include blocks unless needed for correctness.
- Prefer the file's local convention over imposing a new ordering style.

## Types And Language Use
- Most core code is C with older, conservative style expectations.
- Even though Xcode uses `gnu99`, prefer changes that fit the existing C89-era style.
- Objective-C code in `fusepb/` uses ARC-enabled targets.
- Use existing typedefs and `libspectrum_*` types where appropriate.
- In Cocoa layers, prefer `BOOL`, `NSInteger`, `NSUInteger`, `NSString *`, and `NSArray *`.
- Avoid introducing Swift, C++, or new tooling layers.

## SwiftUI Design Principles
Apply these when SwiftUI is already in use for a view or pane.

### Clarity over precision
- Prefer simple structure.
- Prefer standard SwiftUI layouts.
- Prefer maintainable code.
- Do not chase pixel-perfect matching.
- Avoid layout hacks.
- Avoid excessive constants.

### Native SwiftUI patterns only
- Prefer `Form`, `Grid`, `VStack`, and `HStack`.
- Avoid `offset`.
- Avoid absolute positioning.
- Avoid spacer hacks used only for alignment.
- Avoid geometry-based layout tricks.
- Avoid `NSViewRepresentable` bridging unless there is a concrete need that SwiftUI cannot handle cleanly.

## Naming
- C variables and functions: `lower_case_with_underscores`
- Macros and enum constants: `UPPER_CASE_WITH_UNDERSCORES`
- Objective-C classes: `UpperCamelCase`
- Objective-C methods: normal Cocoa selector style
- Keep new names descriptive but minimal

## Error Handling
- In core C code, `0` usually means success and non-zero means failure.
- Prefer direct propagation: `if( error ) return error;`
- Use `ui_error()` for user-visible emulator errors.
- Use `fprintf( stderr, ... )` or `NSLog(...)` only where that subsystem already does so.
- Do not add exceptions for normal flow.
- Do not use `abort()` or `fuse_abort()` for recoverable failures.

## Generated Files
Do not hand-edit generated files unless you are intentionally editing generated output.
Examples:
- `fusepb/settings.m`, `fusepb/settings.h`, `fusepb/settings_cocoa.h` from `fuse/settings.dat`
- `fusepb/options.m`, `fusepb/options.h`, `fusepb/options_cocoa.h` from `fuse/ui/options.dat`
- `fuse/z80/opcodes_base.c`, `fuse/z80/z80_cb.c`, `fuse/z80/z80_ddfd.c`, `fuse/z80/z80_ddfdcb.c`, `fuse/z80/z80_ed.c` from `.dat` files via `fuse/z80/z80.pl`
If behavior is generated, edit the source `.dat` or `.pl` files and regenerate with `make -C fusepb` or the relevant upstream build command.

## macOS-Specific Rules
- The emulator runs on a background thread in `fusepb/models/Emulator.m`.
- AppKit and OpenGL work must stay on the main thread.
- Use `dispatch_async`, `dispatch_sync`, or `performSelectorOnMainThread:withObject:waitUntilDone:` as already established.
- Box raw C pointers when passing them through Objective-C APIs.

## Warnings And Verification
- Keep warnings clean; the Xcode project enables many warning flags.
- After changing C or Objective-C code, prefer verifying with `make fuse`.
- After changing emulator behavior, also run the relevant upstream test command.
- After changing build scripts or dependency wiring, verify with the narrowest useful command.

## Practical Agent Guidance
- Prefer small, local changes.
- Do not replace existing patterns with modern abstractions without a concrete need.
- Do not touch vendored third-party code under `fusepb/deps/` unless required.
- When changing `fuse/`, consult `fuse/AGENTS.md` for deeper subsystem notes.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
