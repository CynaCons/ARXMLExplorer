# Coding and Dependency Rules

These rules enforce the layered architecture and keep modules decoupled. See docs/architecture.md for rationale and diagrams.

## Layering
- Presentation (Flutter UI) → Application (feature state/commands) → Core (pure logic).
- No reverse dependencies. Core must not import Application or Presentation.
- Features may depend on Core, but not directly on other features.

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

## Testing
- Keep tests fast by default; prefer bounded pumps and short timeouts.
- Widget tests should not depend on platform plugins when possible.

## Resources (XSDs)
- Large AUTOSAR XSDs are not committed. Place them under `lib/res/xsd/` as needed. See README “Provisioning AUTOSAR XSDs”.

