# CLAUDE.md

Instructions for Claude Code working in this repository.

**Read [AGENTS.md](AGENTS.md) first** — it holds the full build, run, test and
architecture guidance, and it is kept in sync for every agent tool. This file
only repeats the essentials.

## Build and run

```bash
flutter pub get
flutter analyze          # must be 0 errors, 0 warnings
flutter test             # must be green (~20s)
flutter run -d windows   # or -d linux / -d macos
```

## Non-negotiables

- **Definition of done** = `flutter analyze` clean (0 errors, 0 warnings) *and*
  `flutter test` green. Info-level lints are an accepted backlog. Report the real
  numbers, including failures.
- **`lib/core` is pure Dart.** No `flutter`, no plugins, no imports from
  `features/` or `ui/`. CI enforces this in the `layering` job.
- **`PLAN.md` is written by the powerplan MCP**, never by hand.
- **No `print()`** in `lib/` — use `core/diagnostics/Log`.
- **No bare `catch (_) {}`** — log it, and set `FileTabsNotifier.lastError` when
  the user should see it.
- **Never hard-code `lib/res/xsd/...`** — go through
  `core/resources/ResourceLocator`.

## Widget tests

- Wrap anything touching `dart:io` in `tester.runAsync()` — `testWidgets` uses
  fake async and real I/O futures never complete, so the test hangs rather than
  failing.
- Open files via `test/support/open_fixture.dart` (`pumpShell` / `openFixture`).
  It sets a 1280x900 surface; the rail's actions do not fit 800x600 and taps miss
  silently.
- Schema parsing is off by default in tests (a real AUTOSAR XSD takes seconds).
  Opt in with `autoAttachSchema: true` only when testing validation.

See AGENTS.md for the rest.
