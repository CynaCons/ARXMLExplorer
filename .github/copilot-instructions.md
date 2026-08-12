# ARXMLExplorer — Copilot Instructions

See [AGENTS.md](../AGENTS.md) in the repository root for the full build, run,
test and architecture guidance. It is the single source of truth for all agent
tooling; this file exists only so GitHub Copilot picks it up.

## Build and run

```bash
flutter pub get
flutter analyze          # must be 0 errors, 0 warnings
flutter test             # must be green
flutter run -d windows   # or -d linux / -d macos
```

## Non-negotiables

- Done means `flutter analyze` clean **and** `flutter test` green. Info-level
  lints are an accepted backlog; errors and warnings are not.
- `lib/core` is pure Dart — no Flutter, no plugins, no `features/` or `ui/`
  imports. CI enforces this.
- `PLAN.md` is written by the powerplan MCP, never by hand.
- No `print()` in `lib/` (use `core/diagnostics/Log`), no bare `catch (_) {}`,
  and never hard-code `lib/res/xsd/...` (use `core/resources/ResourceLocator`).
- In widget tests, wrap `dart:io` work in `tester.runAsync()` and open files via
  `test/support/open_fixture.dart`.
