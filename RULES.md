# Coding and Dependency Rules

These rules enforce the layered architecture and keep modules decoupled. See docs/architecture.md for rationale and diagrams.

## Layering
- Presentation (Flutter UI) → Application (feature state/commands) → Core (pure logic).
- No reverse dependencies. Core must not import Application or Presentation.
- Features may depend on Core, but not directly on other features.
- **`lib/core` is pure Dart.** No `flutter`, no plugins (`file_picker`,
  `flutter_riverpod`, `shared_preferences`, `desktop_drop`, …), no imports from
  `features/` or `ui/`. If core needs a Riverpod binding, declare the provider in
  `lib/app_providers.dart` and keep the implementation in core.
- Enforced by `.github/workflows/ci.yml` (`layering` job). The
  `dart_code_metrics` `banned-imports` block in `analysis_options.yaml` only
  runs under the DCM CLI — `flutter analyze` never checked it, which is how the
  violations accumulated.

## Imports
- Prefer barrel imports for cross-feature usage:
  - `package:arxml_explorer/core/core.dart`
  - `package:arxml_explorer/features/editor/editor.dart`
  - `package:arxml_explorer/features/workspace/workspace.dart`
  - `package:arxml_explorer/features/validation/validation.dart`
- Use relative imports inside a feature module.
- Do not import UI from state or core.

## State Management
- Use Riverpod throughout (`flutter_riverpod`). Do not mix with `provider`.

## Planning
- `PLAN.md` is owned by the **powerplan** MCP server (see `.mcp.json`). Do not
  hand-edit it — use `create_iteration` / `add_task` / `complete_task` /
  `start_iteration` / `close_iteration`, and run `check_plan` before reporting
  work done. Attach every iteration to its major explicitly
  (`major: "v0.4"` for `v0.4.2`) or it lands top-level.
- Keep task text ASCII: non-ASCII characters do not survive the MCP round-trip.

## Testing
- Keep tests fast by default; prefer bounded pumps and short timeouts.
- Widget tests should not depend on platform plugins when possible.
- Anything touching `dart:io` from a `testWidgets` body must run inside
  `tester.runAsync()`. `testWidgets` uses fake async, so real I/O futures never
  complete and the test hangs to its timeout rather than failing usefully.
- Use `test/support/open_fixture.dart` (`pumpShell` / `openFixture`) to open a
  file in widget tests. It sets a desktop-sized surface — the rail's action
  column does not fit the default 800x600 and taps miss silently.
- Schema attachment is off by default in `pumpShell`; opt in with
  `autoAttachSchema: true` only when the test is about validation. Parsing a
  real AUTOSAR XSD costs seconds.

## Resources (XSDs)
- Large AUTOSAR XSDs are not committed. Resolution goes through
  `core/resources/ResourceLocator` — never a bare `lib/res/xsd/...` string,
  which only resolves when the process CWD happens to be the repo root.
- See README “Provisioning AUTOSAR XSDs” for the full search order.

## Diagnostics
- No `print()` in `lib/`. Use `core/diagnostics/Log`
  (`debug` / `verbose` / `warn` / `error`).
- No bare `catch (_) {}`. Log the failure, and set
  `FileTabsNotifier.lastError` when the user needs to know.

