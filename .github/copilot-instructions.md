# ARXMLExplorer — Copilot Instructions for AI Coding Agents

You are implementing an ARXML Explorer Flutter-based application based on user prompts and requests.

## Project Conventions
  - The user communicates you requests and feedback. You incorporate them in PLAN.md in the form of checklist items, categorized by features. 
  - You then implement the features and checklist elements as per user request.
  - Do not stop, until the user request is complete
  - Never request user approval - do what the user asks. Do it fully and completely. 
  - Update `PLAN.md` in realtime whenever something is ongoing or completed.

## Documentation Sources
- Primary planning & execution checklist: `PLAN.md` (always update statuses here in real time).
- Product requirements & scope narrative: `PRD.md`.
- Vision / directional documents: `PVD.md` (if present) and `RULES.md` for coding/interaction rules.
- Architectural / feature rationale should reference these docs; do not duplicate – link back instead.

## Project Structure Overview
- `lib/` Flutter/Dart source
  - `main.dart` (app entry) now delegates to modular feature barrels.
  - `features/` high-level verticals:
    - `editor/` (views, widgets, file tab state, commands integration)
    - `validation/` (validation view, widgets, providers)
    - `workspace/` (workspace indexing, models, view)
  - `core/` (after refactor) foundational subsystems:
    - `xml/arxml_loader/` parsing & serialization
    - `xsd/xsd_parser/` schema parsing & resolution
    - `refs/` reference normalization helpers
  - Legacy single-file utilities retained at top-level (e.g., `elementnode.dart`) until fully migrated.
  - State management: Riverpod `StateNotifier` + providers colocated with features.
- `test/` unit & widget tests grouped by concern:
  - `arxml_loader_test.dart` parser basics
  - `editing_schema_test.dart` schema-driven editing
  - `file_handling_test.dart` open/save flows
  - `collapse_expand_test.dart` tree UI expand/collapse
  - `search_*` / `performance_test.dart` behavior & perf
  - Add new tests mirroring feature area naming; keep fast & deterministic.
- `doc/api/` generated API documentation (do not hand-edit).
- Platform folders (`android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`) standard Flutter targets.

## Test & Feature Implementation Notes
- Every new feature or editing capability added to `PLAN.md` must also include at least one corresponding test in `test/` (unit or widget) before marking complete.
- Undo/Redo, Safe Rename, Type Conversion, Templates each require command coverage and state mutation assertions.

## Workflow Reminder
1. Parse user request → translate into `PLAN.md` checklist items (create if missing).
2. Implement code & tests iteratively; keep analyzer clean.
3. Update `PLAN.md` status (e.g., `[x]`) as soon as a subtask is done.
4. Avoid asking for confirmation; proceed unless conflict with higher system instructions.

