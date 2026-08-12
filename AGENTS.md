# ARXMLExplorer — Instructions for AI Coding Agents

A Flutter desktop application for exploring and editing AUTOSAR ARXML files with
schema-aware validation. This file is the entry point for any agent working in
this repo. Read it before touching code.

---

## Quick start

```bash
flutter pub get          # install dependencies
flutter analyze          # must report 0 errors and 0 warnings
flutter test             # must be green (~20s)
flutter run -d windows   # or -d linux / -d macos
```

If `flutter run` cannot find a device, list them with `flutter devices` and
enable the desktop target you need (see **Platform setup** below).

---

## Environment

| | |
|---|---|
| Flutter | `>=3.0.0 <4.0.0` — developed against 3.35.0 (beta) |
| Dart | bundled with Flutter |
| State | `flutter_riverpod` — do **not** mix in `provider` |
| Primary target | Windows desktop; Linux is in progress (PLAN.md v0.5) |

Verify your toolchain with `flutter doctor`.

### Platform setup

**Windows** — needs Visual Studio with the "Desktop development with C++"
workload.

```bash
flutter config --enable-windows-desktop
flutter build windows --debug
```

**Linux** — needs GTK and a C++ toolchain:

```bash
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
flutter config --enable-linux-desktop
flutter build linux --release
```

The `linux/` runner exists but is stale (generated Dec 2023; its plugin
registrant lists only `desktop_drop`). See PLAN.md v0.5.0 before assuming a
Linux build works.

---

## Build, test, run

```bash
flutter analyze --no-pub                 # analyzer only, no dependency resolution
flutter test --no-pub                    # full suite
flutter test --no-pub test/foo_test.dart # one file
flutter test --no-pub --plain-name "Save writes"   # one test by name
flutter build windows --debug            # real desktop build
flutter run -d windows                   # launch with hot reload
```

**Definition of done:** `flutter analyze` reports 0 errors and 0 warnings, and
`flutter test` is fully green. Info-level lints are tolerated (there is a
backlog of them); errors and warnings are not. A task marked `[x]` with a red
analyzer is a lie — CI enforces this.

### CI

`.github/workflows/ci.yml` runs three jobs on every push and PR:

- **analyze** — fails on any analyzer error or warning; reports info counts.
- **layering** — greps for layer violations (see **Architecture** below). The
  `dart_code_metrics` `banned-imports` block in `analysis_options.yaml` only
  runs under the DCM CLI, so `flutter analyze` never enforced it.
- **test** — matrix over `ubuntu-latest` and `windows-latest`.

Run the layering check locally before pushing:

```bash
grep -rnE "^import 'package:(flutter|flutter_riverpod|file_picker|desktop_drop|shared_preferences|scrollable_positioned_list|arxml_explorer/(ui|features))/" lib/core
grep -rnE "^import 'package:arxml_explorer/ui/" lib/features
```

Both must return nothing.

---

## AUTOSAR schemas (XSDs)

Licensed AUTOSAR XSDs are **not committed** (`lib/res/xsd/*.xsd` is gitignored).
The app resolves them through `core/resources/ResourceLocator`, which searches,
first hit wins:

1. `$ARXML_XSD_DIR` — explicit override
2. `<cwd>/lib/res/xsd` — source checkout
3. `<executable dir>/data/flutter_assets/lib/res/xsd` — Flutter asset bundle
4. `<executable dir>/res/xsd`, then `<executable dir>/../res/xsd`
5. Per-user data dir — `%APPDATA%/ARXMLExplorer/xsd`,
   `$XDG_DATA_HOME/arxml_explorer/xsd`, `~/.local/share/arxml_explorer/xsd`,
   or `~/Library/Application Support/ARXMLExplorer/xsd`

**Never hard-code `lib/res/xsd/...` as a string** — it only resolves when the
process working directory happens to be the repo root, which is false for every
installed build.

Check what is present:

```bash
dart run tool/verify_xsds.dart
```

Tests that need real schemas call `markTestSkipped` with a message when they are
absent, so `flutter test` is green on a bare checkout.

---

## Architecture

```
lib/
  main.dart              # entry point
  app_providers.dart     # global Riverpod providers (incl. astCacheProvider)
  ui/home_shell.dart     # navigation shell, toolbar actions, shortcuts
  features/              # editor / workspace / validation / xsd
    <feature>/view/      # widgets
    <feature>/state/     # notifiers, providers, commands
  core/                  # PURE DART — no Flutter, no plugins
    models/ xml/ xsd/ validation/ refs/ cache/ diagnostics/ resources/
```

**Layering: Presentation → Application → Core.** No reverse dependencies.
`lib/core` must not import `flutter`, any Flutter plugin, or anything under
`features/` or `ui/`. If core needs a Riverpod binding, declare the provider in
`lib/app_providers.dart` and keep the implementation pure. See RULES.md.

Editing goes through a command pattern (`features/editor/state/commands/`) so
undo/redo works. `ArxmlTreeState` publishes `canUndo` / `canRedo` so toolbar
buttons can `ref.watch` them.

---

## Conventions

- **No `print()` in `lib/`.** Use `core/diagnostics/Log`
  (`debug` / `verbose` / `warn` / `error`). It routes through `dart:developer`
  and compiles out of release builds.
- **No bare `catch (_) {}`.** Log the failure; set
  `FileTabsNotifier.lastError` when the user needs to know.
- Prefer barrel imports across features (`package:arxml_explorer/core/core.dart`),
  relative imports inside a feature.
- Use `package:path` (`p.basename`, `p.join`, `p.isWithin`) rather than
  splitting on `Platform.pathSeparator` — the app must work on Linux.

### Testing gotchas

These have each cost real debugging time. Read them before writing widget tests.

- **`dart:io` inside a `testWidgets` body must be wrapped in
  `tester.runAsync()`.** `testWidgets` runs under fake async, so real I/O futures
  never complete — the test hangs to its timeout instead of failing usefully.
- **Use `test/support/open_fixture.dart`** (`pumpShell` / `openFixture`) to open
  a file. `pumpShell` sets a 1280x900 surface: the rail's action column does not
  fit the default 800x600 and taps land off-screen silently.
- **Schema attachment is off by default in tests.** Parsing a real AUTOSAR XSD
  costs seconds. Pass `autoAttachSchema: true` only when the test is about
  validation, or await `FileTabsNotifier.schemaWarmup`.
- Prefer bounded pumps over `pumpAndSettle`, and key-based finders
  (`find.byKey(const Key('action-save'))`) over icon lookups.
- Avoid wall-clock assertions with tight bounds; they flake under load.

---

## Tooling (MCP)

Registered in `.mcp.json` (takes effect in a new session):

- **powerplan** — the *sanctioned writer* for `PLAN.md`. Do not hand-edit the
  plan. Prefer `get_current_iteration` / `get_iteration` over reading the whole
  file. Use `create_iteration` / `add_task` / `complete_task` /
  `start_iteration` / `close_iteration`, and run `check_plan` before reporting
  done. Attach every iteration to its major explicitly (`major: "v0.4"` for
  `v0.4.2`) or it lands top-level. Keep task text ASCII — non-ASCII does not
  survive the MCP round-trip.
- **powerspawn** — sub-agent delegation (`spawn_claude`, `spawn_codex`,
  `spawn_copilot`, `spawn_gemini`, `spawn_grok`, `spawn_mistral`,
  `wait_for_agents`).

Both are separate local repos; adjust the paths in `.mcp.json` if yours differ.

---

## Documentation

| File | Purpose |
|---|---|
| PLAN.md | Iteration checklist — **owned by powerplan**, not hand-edited |
| PRD.md | Product requirements and scope |
| RULES.md | Dependency rules and coding standards |
| docs/architecture.md | Architecture guide |
| README.md | User-facing setup and features |

Reference these rather than duplicating them; link back instead.

---

## Workflow

1. Parse the request → `add_task` / `create_iteration` via powerplan.
2. Implement code and tests iteratively; keep the analyzer clean.
3. `complete_task` via powerplan as soon as a subtask is genuinely done.
4. Run `flutter analyze` **and** `flutter test` before reporting completion, and
   report the real numbers — including failures.
5. `check_plan` before you finish.
