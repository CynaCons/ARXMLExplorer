# ARXMLExplorer Plan – Checklist

# 1. Ongoing & Upcoming (chronological order)

## 1.1 Immediate Next Actions (UI + Editing QoL)
- [x] Add visual selected-tab state for filenames when using custom Tab child
- [x] Refine Add Child UX (remember last picked child, add validation hints)
- [x] Inline SHORT-NAME display on rows (keep SHORT-NAME child collapsed by default) (PRIORITY)
- [x] Node context menu for containers: "Collapse children" and "Expand children" (ElementNodeWidget + ArxmlTreeStateNotifier)
- [ ] Reference status in tree (PRIORITY):
  - [x] Show per-row indicator for DEFINITION-REF (Found in workspace / Missing); tooltip shows target file path
  - [x] One-click "Go to definition" from row + context menu; disabled state when missing
  - [x] Reference normalization to match index (absolute/relative paths, vendor formats, leading '/'; case/namespace handling)
    - [x] Implement RefNormalizer utility: normalize raw refs to a canonical absolute key (e.g., "/Pkg/Sub/Def")
    - [x] Handle separators and variants: backslashes, repeated slashes, "::" vendor separators, trim quotes/whitespace
    - [x] Support relative refs with base package path (".", "..") and optional leading '/'
    - [x] Preserve case by default; optional namespace/prefix stripping hook available
    - [x] Integrate into Workspace index lookups and Go to Definition
    - [x] ECUC + ports/interfaces normalization hooks wired (normalizeEcuc/normalizePortRef)
- [ ] Unsaved changes indicator (PRIORITY):
  - [x] Show an asterisk/dot on modified tab titles; tooltip "Unsaved changes"
  - [x] AppBar "Save All" action; prompt on tab close when there are unsaved edits

## 1.2 XSD Workflow Improvements (remaining)
- [x] Improve traversal for nested sequences/choices/groups (deeper where safe)
- [x] Add verbose diagnostics toggle to print resolution path per element (wired in UI; expand output and docs)
- [x] Add unit tests with AUTOSAR samples for key elements (SWC, Ports, Packages)
- [x] Auto‑XSD detection enhancements (PRIORITY):
  - [x] Parse xsi:schemaLocation pairs robustly (strip scheme/fragment; prepare tokenizer)
  - [x] Map version variants (e.g., 4-3-0 ⇄ 4.3.0) handling in detection
  - [x] Search workspace for referenced XSD when not bundled; fallback to closest known XSD
  - [x] Surface detected schema in UI with quick override

## 1.3 Smart Schema & Validation
- [x] Auto-detect XSD from ARXML headers (read AUTOSAR schema/version from file preamble; no external files imported into repo)
- [x] Validate ARXML against the active XSD; produce a violations report (element path, message, quick-fix hints)
- [x] Live validation toggle in UI (off by default) + plumbing for on-change validation
- [x] Live validation while editing (toggle-able, throttled)
- [x] Parent-context disambiguation for identically named elements (e.g., ELEMENTS) to tighten suggestions (parser accepts optional context)
- [x] Validation options (PRIORITY):
  - [x] Ignore ADMIN-DATA subtree toggle in Validation view (persist per session/tab)
  - [x] Severity filters (error/warning/info)
  - [x] Search within results (filter box)
- [x] Validation results UX (PRIORITY):
  - [x] Navigable results list: click to open file (if needed) and scroll/focus the offending node
  - [x] Copy path action and basic next/prev navigation for issues
  - [x] Keyboard shortcuts for next/prev; deep-link path display; copy path from tree rows
  - [x] Row-level issue indicator: small right-side badge/icon with severity color and tooltip; aggregate count on containers
  - [x] Surface issue counts to improve findability:
    - [x] AppBar issue count badge
    - [x] Scrollbar gutter aggregate marks
  - [x] Provide per-row quick action “Go to issue” to expand/focus the first offending child (feedback)

## 1.4 Workspace & Cross‑File Features
- [x] Workspace symbol index (no auto-tab loading): parse ARXMLs in selected folder into a lightweight reference cache
- [x] Open Workspace action: choose folder, build index in background (no tabs opened automatically)
- [x] Incremental indexing: debounce FS watch + manual Refresh
- [ ] Cross-file navigation (DEFINITION-REF and other refs):
  - [x] Indicator when a reference target exists in workspace index
  - [x] Go to definition: open target file in a tab on demand and scroll to the node
  - [x] Fallback to best-effort match when multiple candidates; show disambiguation UI
- [x] LRU in-memory AST cache for last N opened files to speed navigation
- [x] Workspace refresh UI + status (files indexed, last scan time)
- [ ] Workspace Explorer view (PRIORITY):
  - [x] Left NavigationRail with views: File Editor (default), Workspace, Validation Results, Settings — basic rail added and wired; views are initial versions
  - [x] Workspace file list: show all detected ARXMLs; click to open (on-demand tab)
  - [x] Background indexing progress: global progress + per-file status (queued/processing/processed/error)
  - [x] Drag-and-drop files/folders into Workspace (desktop/web) to index
  - [x] Rail highlight style adjusted to square indicator (feedback)
  - [x] Add files action (picker) to index additional files on demand

## 1.5 Editing & Refactoring
- [ ] Convert element type (change tag to another schema‑valid alternative, migrate children when possible)
- [ ] Safe rename for SHORT-NAME with reference propagation where resolvable
- [ ] Undo/Redo for all edits
- [ ] New File templates: create files from templates (Empty, AUTOSAR skeleton, SWC sample)

## 1.6 AUTOSAR Semantics Checks
- [ ] Port/interface compatibility (verify P/R ports and interfaces across files)
- [ ] ECUC parameter/value consistency checks
- [ ] Package structure checks (duplicate short names, ownership constraints)

## 1.7 UI/UX Enhancements
- [ ] Keyboard navigation and better selection/scroll focusing
- [x] Accessibility/contrast modes and adjustable density
- [x] NavigationRail (PRIORITY): add view switching (Editor/Workspace/Validation/Settings) — basic rail implemented; views WIP
- [x] Inline SHORT-NAME display on rows (Moved to 1.1 as PRIORITY)
- [x] Resource HUD overlay (bottom-right) with Settings toggle

## 1.8 Performance & Architecture
- [ ] Schema index cache per version; lazy-load schema fragments
- [ ] Very large file optimizations (virtualization tuning, metrics, background parsing)
- [ ] Extensible validator plug-in API (project‑specific rules)

## 1.9 Testing & CI
- [ ] Stabilize file_loading_integration_test.dart (eliminate hang; replace timeout workaround with proper async settle)
- [ ] Expanded AUTOSAR tests (SWC ports, packages, ECUC cases)
- [ ] Cross‑file reference resolution tests
  - Absolute vs relative (with "/", without "/", with ".." and ".")
  - Vendor separators ("::"), backslashes, redundant slashes
  - ECUC refs, port/interface refs across packages
  - Case sensitivity behavior and optional namespace stripping
- [ ] Validation report tests + performance benchmarks
- [ ] Integration test harness: reduce animations/settling in tests (no nested ProviderScope; finite pumps)
- [ ] Auto‑XSD detection mapping tests (xsi:schemaLocation pairs, 4-3-0 variants, workspace XSD search)
- [ ] Validation UX tests: ADMIN-DATA ignore option, navigable results focus/scroll, row badge presence, tab/scrollbar counts
- [ ] Unsaved indicator tests: tab badge shows on edit, clears on save; close-with-unsaved prompts

# 1.10 Architecture & File Structure Refactor (Phase 1–3)
- Phase 1 (Views/Providers extraction)
  - [x] Extract MaterialApp/theme to lib/ui/app.dart  // Completed (Phase 1 start)
  - [x] Extract shell (Scaffold + NavigationRail) to lib/ui/home_shell.dart  // Completed
  - [x] Move Validation view to lib/features/validation/view/validation_view.dart  // Completed
  - [x] Move Workspace view (incl. DnD) to lib/features/workspace/view/workspace_view.dart  // Completed (code + removal from main.dart verified)
  - [x] Move editor tabs composition to lib/features/editor/view/editor_view.dart  // Completed
  - [x] Move providers from main.dart to:
    - [x] features/editor/state/file_tabs_provider.dart
    - [x] features/validation/state/validation_providers.dart (filter)
    - [x] keep app-wide toggles in app/app_providers.dart
  - [x] Update imports; add barrel files where useful (features/editor/editor.dart, features/validation/validation.dart, features/workspace/workspace.dart)
  - Progress note: Phase 1 finalized (barrels added)
- Phase 2 (Widget and service splits)
  - Progress note: Phase 2 completed (validation gutter extracted, workspace models moved, legacy widget stubbed for removal)
  - [x] Split ElementNodeWidget into: element_node_widget.dart, element_node_actions.dart, element_node_dialogs.dart, ref_indicator.dart, validation_badge.dart
  - [x] Extract validation gutter to features/validation/view/widgets/validation_gutter.dart
  - [x] Create features/workspace/service/workspace_models.dart and move models out of workspace_indexer.dart
  - [x] Remove legacy lib/elementnodewidget.dart (replaced by stub; pending final deletion in Phase 3 cleanup)
- Phase 3 (Core modules)
  - Progress note: Phase 3 completed (ARXML parser/serializer split, XSD parser relocated, ref specialization barrel added)
  - [x] Split ARXML I/O into core/xml/arxml_loader/{parser.dart,serializer.dart}
  - [x] Split XSD parser into core/xsd/xsd_parser/{parser.dart,index.dart,resolver.dart,tracing.dart} (shim export left at lib/xsd_parser.dart)
  - [x] Move ref specialization to core/refs/{ref_normalizer_ecuc.dart,ref_normalizer_ports.dart} and keep a barrel re-export
- Testing & verification
  - [x] flutter analyze passes; no new breaking import errors (remaining stylistic infos/warnings deferred to lint tidy pass)
  - [x] App builds and runs; no behavior/UI changes intended (smoke run OK)
  - [x] Tests compile (some functional expectations failing; triaged & moved to 1.9 Testing & CI for follow-up)
  - [x] Update .github/copilot-instructions.md to reflect new file map (verified)
  - Progress note: 1.10 Phase 1–3 complete; residual failing assertions/timeouts re-scoped to 1.9 hardening.

## 1.11 Pending Execution Plan (awaiting confirmation)
- 1.1 Reference normalization breadth (ECUC + Ports/Interfaces)
  - [ ] Implement ECUC ref normalization (e.g., ECUC-MODULE-DEF paths; PARAM-REF/REFERENCE-VALUES)
  - [ ] Implement ports/interfaces normalization (R-/P-PORT-PROTOTYPE → interface; SWC port refs)
  - [ ] Normalize/resolve more ref patterns for cross-file navigation (relative paths/vendor separators); add tests
- 1.2 Auto‑XSD detection enhancements
  - [ ] Robustly parse xsi:schemaLocation pairs (space‑separated URI + file)
  - [ ] Version mapping (4-3-0 ⇄ 4.3.0) with local XSD filename variants
  - [ ] Search workspace for referenced XSD; fallback to closest known XSD
  - [ ] UI: surface detected schema with quick override

---

# 2. Completed (reverse chronological)

## 2.1 Latest Changes (Aug 2025)
- [x] Reference normalization: RefNormalizer implemented and integrated into indicators and Go to Definition (base path + vendor/backslash/dot-segments handled); tests added for core cases
- [x] Validation groundwork: added ValidationSeverity and severity on ValidationIssue (prep for filters and colored badges)
- [x] Settings view added (Live validation, Verbose diagnostics, Ignore ADMIN-DATA)
- [x] Validation options: severity filters (chips + list filtering)
- [x] Validation results UX: row-level issue badges with severity colors and tooltip; quick “Go to issue” action (container aggregation pending)
- [x] Validation UX: added search filter in Validation view, issue count badge in AppBar, and next/prev + copy path
- [x] Live validation while editing via debounced ValidationScheduler (toggle-controlled)
- [x] Go to Definition opens target file in a tab on demand and scrolls to the node (scrollToIndex wiring)
- [x] LRU AST cache implemented and wired for open/navigate paths
- [x] XsdParser: deeper traversal defaults (particleDepthLimit=4, groupDepthLimit=3); richer diagnostics trace buffer
- [x] Diagnostics: bug toggle now shows inline trace viewer panel
- [x] Auto-detect XSD from ARXML header/version when opening/creating files; per‑tab schema set accordingly
- [x] Resource HUD overlay (bottom-right) with Settings toggle
- [x] Simple validation action (AppBar) produces violations report with element paths
- [x] Added unit test validation_report_test for invalid child detection
- [x] TabBar selected tab gets subtle pill background (with bold + underline retained)
- [x] Add Child UX: remembers last picked child per parent tag; inline validation hint when empty/invalid
- [x] Row hover highlight + animated chevron rotation for expand/collapse
- [x] Context menu editing clarified: container (e.g., SHORT-NAME) -> Rename Tag; leaf value -> Edit Value
- [x] Increased contrast for tab filenames (white text on dark AppBar)

## 2.2 Recent Accomplishments
- [x] Fixed TabController updates on provider state changes (_updateTabController in build + post-frame)
- [x] Verified real file load on Windows desktop
- [x] Improved logs for loading and state transitions
- [x] Per‑tab XSD selection UI (picker button, per‑tab indicator, default fallback)
- [x] XsdParser enhancements: namespace‑agnostic indexes, complexContent, @ref resolution, xs:all, improved attribute discovery
- [x] UI color refresh with gradient AppBar and TabBar styling

