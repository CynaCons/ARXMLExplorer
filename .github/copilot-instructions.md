# ARXMLExplorer — Copilot Instructions for AI Coding Agents

Purpose: Make you productive fast in this Flutter/Riverpod AUTOSAR XML (ARXML) explorer by capturing the project’s architecture, workflows, and conventions.

## Big Picture Architecture
- UI Shell: `lib/main.dart`
  - AppBar actions (open/create/save, search, expand/collapse, XSD pick, diagnostics toggle).
  - Tabs via `FileTabsNotifier` + `TabBar/TabBarView`. Per-tab schema and provider wiring live in `FileTabState`.
  - Validation View: filters, keyboard nav, deep-link, issue list.
  - Workspace View: index progress, per-file status, open-on-click.
- Tree State & Data: `lib/arxml_tree_view_state.dart`
  - `ArxmlTreeStateNotifier` builds a `flatMap` of nodes, `visibleNodes`, and handles edits (add/delete, rename, edit value, collapse/expand). Structural mutations often re-init via `_initState(...)`.
- Node Model: `lib/elementnode.dart`
  - `ElementNode` with children, depth, flags, parent pointer, and helpers (`getShortName`, `getDefinitionRef`).
- XML I/O: `lib/arxmlloader.dart`
  - Parses ARXML into nodes and serializes nodes back to XML.
- XSD Integration: `lib/xsd_parser.dart`
  - Indexes elements/types/groups; resolves `@ref/@type`, complexContent, groups, substitutionGroup. `getValidChildElements(tag)` used to propose children in UI. Verbose tracing toggled via diagnostics.
- Tree UI: `lib/elementnodewidget.dart`
  - Renders each node row with inline SHORT-NAME, context menu (Edit/Add/Delete), ref indicator, and micro-animations.
- Validation engine: `lib/arxml_validator.dart`
  - `ArxmlValidator.validate` returns `ValidationIssue`s with severity; options via `ValidationOptions`.
- Workspace index: `lib/workspace_indexer.dart`
  - Background indexing, per-file status, go-to-definition, alternative ref keys.
- Ref normalization: `lib/ref_normalizer.dart`
  - Canonicalizes refs (slashes, ::, backslashes, quotes, ./.., namespace prefixes). ECUC/ports helpers.
- App-wide providers: `lib/app_providers.dart`
  - Live validation toggle, resource HUD, validation options and results state.

## State & UI Patterns
- Riverpod is used throughout: tabs (`fileTabsProvider`), active tab index, loading/diagnostics flags, and per-tab `treeStateProvider`.
- When changing structure (add/delete child), call `_initState(...)` to recompute `flatMap`/`visibleNodes`.
- Editing rules:
  - Container-with-text (e.g., `SHORT-NAME`): use `renameNodeTag(nodeId, newTag)`.
  - Leaf text node: use `editNodeValue(nodeId, newValue)`.
- Context menu wiring lives in `ElementNodeWidget` (PopupMenuItem + `_handleMenuSelection`). Add state methods in `ArxmlTreeStateNotifier` as needed.

## XSD & Diagnostics
- Default schema: `lib/res/xsd/AUTOSAR_00050.xsd` loaded for session. Per-tab schema via AppBar action.
- Toggle verbose XSD tracing (bug icon) -> rebuilds parsers with `verbose: true` for resolution logs.
- Typical usage: `widget.xsdParser?.getValidChildElements(node.elementText)` to populate Add-Child options.

## Developer Workflows
- Install deps: `flutter pub get`
- Run app: `flutter run`
- Run tests: `flutter test` (see `test/*.dart` for categories like search, editing, performance).
- Static analysis: `flutter analyze`
- Windows shell is common here; commands above work in PowerShell.

## Project Conventions
- Follow `RULES.md`:
  - Confirm before starting a PLAN step.
  - Update `PLAN.md` first with the step you’ll do.
  - Implement tests for each step and run them before asking for user validation.
  - Provide user validation steps when asking for review.
- UI theming: Material 3 with palette set in `main.dart`. Prefer small, performant animations (`AnimatedContainer`, `AnimatedRotation`).
- Tabs: Don’t break TabController/provider sync; updates happen via `activeTabIndexProvider`.
- Schema-aware UI: keep XSD lookups fast by using existing parser caches and visited-depth protections.

## File-to-Feature Map (where to implement what)
- `lib/main.dart`
  - State: `fileTabsProvider`, `activeTabIndexProvider`, `activeTabProvider`, `validationSchedulerProvider`, `navRailIndexProvider`, `scrollToIndexProvider`, `validationFilterProvider`.
  - File ops: `openNewFile()`, `createNewFile()`, `saveActiveFile()`, `saveAllFiles()`, `openFileAndNavigate()`, `_navigateToShortPath()`.
  - XSD: `_loadXsdSchema()`, `_detectSchemaPathFromArxml()`, `_findInWorkspace()`, `pickXsdForActiveTab()`, `resetXsdForActiveTabToSession()`, `_rebuildParsersWithVerbose()`.
  - UI: AppBar actions, NavigationRail, Editor/Workspace/Validation/Settings views, Resource HUD.
- `lib/arxml_tree_view_state.dart`
  - Model state: `ArxmlTreeState`, `arxmlTreeStateProvider`.
  - Mutations: `toggleNodeCollapse`, `collapseAll/expandAll`, `collapseChildrenOf/expandChildrenOf`, `deleteNode`, `editNodeValue`, `renameNodeTag`, `addChildNode`, `expandUntilNode`.
- `lib/elementnodewidget.dart`
  - Row UI + context menu: `_showEditDialog`, `_showRenameTagDialog`, `_showAddChildDialog`, `_handleMenuSelection`.
  - Live validation trigger: `_maybeRunLiveValidation()`.
  - Ref indicator + go-to-definition using `WorkspaceIndexNotifier.goToDefinition` and `RefNormalizer` (including ECUC/Ports variants).
- `lib/arxmlloader.dart`
  - Parse XML into `ElementNode` tree: `parseXmlContent`, `_parseXmlElement`.
  - Serialize back: `toXmlString`, `_buildXml`.
- `lib/xsd_parser.dart`
  - Core: `getValidChildElements(parent, {contextElementName})`.
  - Internals: `_ensureIndexes`, `_findElementDef*`, `_findGroupDef`, `_findTypeDef`, traversal helpers; verbose trace via `getLastResolutionTrace()`.
- `lib/arxml_validator.dart`
  - Types: `ValidationSeverity`, `ValidationIssue`, `ValidationOptions`.
  - Engine: `validate(roots, parser, options)`; path builder; ADMIN-DATA ignore; severity assignment.
- `lib/workspace_indexer.dart`
  - State: `WorkspaceIndexState` (progress, statuses, targets map).
  - Ops: `pickAndIndexWorkspace()`, `indexFolder()`, `refresh()`, `addFiles()`, `goToDefinition()`.
  - Target extraction: `_extractTargets(XmlDocument)` emits canonical and alternative keys via `RefNormalizer`.
- `lib/ref_normalizer.dart`
  - `normalize(raw, {basePath, stripNamespacePrefixes})`, `normalizeEcuc`, `normalizePortRef`.
- `lib/app_providers.dart`
  - App-level providers for validation/live flags and selected issue index.

## Tips
- When adding features that touch multiple files (e.g., reference resolution), update both UI (ElementNodeWidget) and backend (workspace_indexer + ref_normalizer).
- For schema-aware UI, prefer passing `contextElementName` to `getValidChildElements` for precision.
- When changing structure (add/delete), prefer using `_initState` to rebuild IDs and visibility.

---

## Planned Target Structure (for refactor phases)
- lib/core
  - xml/
    - arxml_loader/
      - parser.dart (parseXmlContent, _parseXmlElement)
      - serializer.dart (toXmlString, _buildXml)
  - xsd/
    - xsd_parser/
      - parser.dart (public API getValidChildElements)
      - index.dart (_ensureIndexes)
      - resolver.dart (_findElementDef*, groups/types traversal)
      - tracing.dart (verbose diagnostics, getLastResolutionTrace)
  - refs/
    - ref_normalizer.dart (barrel re-export)
    - ref_normalizer_ecuc.dart
    - ref_normalizer_ports.dart
- lib/features/editor
  - state/
    - file_tabs_provider.dart (fileTabsProvider, activeTab*, save actions)
    - arxml_tree_state.dart (data model)
    - arxml_tree_notifier.dart (mutations, _initState)
  - view/
    - editor_view.dart (TabBar/TabBarView composition)
    - widgets/
      - element_node/
        - element_node_widget.dart (compose children)
        - element_node_actions.dart (context menu + handlers)
        - element_node_dialogs.dart (edit/rename/add)
        - ref_indicator.dart (DEFINITION-REF indicator + nav)
        - validation_badge.dart
      - depth_indicator.dart
- lib/features/validation
  - model/
    - validation_types.dart (ValidationSeverity, ValidationIssue, ValidationOptions)
  - service/
    - arxml_validator.dart (validate engine)
  - state/
    - validation_providers.dart (live toggle, filters, results)
  - view/
    - validation_view.dart (results list, keyboard nav)
    - widgets/validation_gutter.dart (_ValidationGutter, _GutterPainter)
- lib/features/workspace
  - service/
    - workspace_models.dart (WorkspaceTarget, IndexStatus, WorkspaceIndexState)
    - workspace_indexer.dart (notifier; uses models)
  - view/
    - workspace_view.dart (Workspace UI)
    - widgets/{workspace_toolbar.dart, workspace_file_list.dart, workspace_status_list.dart, workspace_dnd_target.dart}
- lib/features/settings/view/settings_view.dart
- lib/ui
  - app.dart (MaterialApp + theme)
  - home_shell.dart (Scaffold + NavigationRail + view switching)
  - hud/resource_hud.dart
- lib/app/app_providers.dart (only truly app-wide providers; others move to features)
