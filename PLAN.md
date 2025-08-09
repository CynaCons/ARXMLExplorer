# ARXMLExplorer Plan – Checklist

# 1. Ongoing & Upcoming (chronological order)

## 1.1 Immediate Next Actions (UI + Editing QoL)
- [x] Add visual selected-tab state for filenames when using custom Tab child
- [x] Refine Add Child UX (remember last picked child, add validation hints)
- [ ] Inline SHORT-NAME display on rows (keep SHORT-NAME child collapsed by default) (PRIORITY)
- [ ] Node context menu for containers: "Collapse children" and "Expand children" (ElementNodeWidget + ArxmlTreeStateNotifier)
- [ ] Reference status in tree (PRIORITY):
  - [ ] Show per-row indicator for DEFINITION-REF (Found in workspace / Missing); tooltip shows target file path
  - [ ] One-click "Go to definition" from row + context menu; disabled state when missing
  - [ ] Reference normalization to match index (absolute/relative paths, vendor formats, leading '/'; case/namespace handling)
- [ ] Unsaved changes indicator (PRIORITY):
  - [ ] Show an asterisk/dot on modified tab titles; tooltip "Unsaved changes"
  - [ ] AppBar "Save All" action; prompt on tab close when there are unsaved edits

## 1.2 XSD Workflow Improvements (remaining)
- [x] Improve traversal for nested sequences/choices/groups (deeper where safe)
- [x] Add verbose diagnostics toggle to print resolution path per element (wired in UI; expand output and docs)
- [x] Add unit tests with AUTOSAR samples for key elements (SWC, Ports, Packages)
- [ ] Auto‑XSD detection enhancements (PRIORITY):
  - [ ] Parse xsi:schemaLocation pairs robustly (handle space‑separated URI + file name)
  - [ ] Map version variants (e.g., 4-3-0 ⇄ 4.3.0); support AUTOSAR_4-3-0.xsd
  - [ ] Search workspace for referenced XSD when not bundled; fallback to closest known XSD
  - [ ] Surface detected schema in UI with quick override; add tests

## 1.3 Smart Schema & Validation
- [x] Auto-detect XSD from ARXML headers (read AUTOSAR schema/version from file preamble; no external files imported into repo)
- [x] Validate ARXML against the active XSD; produce a violations report (element path, message, quick-fix hints)
- [x] Live validation toggle in UI (off by default) + plumbing for on-change validation
- [x] Live validation while editing (toggle-able, throttled)
- [x] Parent-context disambiguation for identically named elements (e.g., ELEMENTS) to tighten suggestions (parser accepts optional context)
- [ ] Validation options (PRIORITY):
  - [ ] Ignore ADMIN-DATA subtree toggle in Validation view (persist per session/tab)
  - [ ] Severity filters (error/warning/info) and search within results
- [ ] Validation results UX (PRIORITY):
  - [ ] Navigable results list: click to open file (if needed) and scroll/focus the offending node
  - [ ] Keyboard navigation (next/prev issue); deep-link path display; copy path
  - [ ] Row-level issue indicator: small right-side badge/icon with severity color and tooltip; aggregate count on containers

## 1.4 Workspace & Cross‑File Features
- [x] Workspace symbol index (no auto-tab loading): parse ARXMLs in selected folder into a lightweight reference cache
- [x] Open Workspace action: choose folder, build index in background (no tabs opened automatically)
- [x] Incremental indexing: debounce FS watch + manual Refresh
- [ ] Cross-file navigation (DEFINITION-REF and other refs):
  - [x] Indicator when a reference target exists in workspace index
  - [x] Go to definition: open target file into a tab on demand and scroll to the node
  - [ ] Normalize/resolve more ref patterns (relative paths, ECUC, ports/interfaces); add tests
- [x] LRU in-memory AST cache for last N opened files to speed navigation
- [x] Workspace refresh UI + status (files indexed, last scan time)
- [ ] Workspace Explorer view (PRIORITY):
  - [ ] Left NavigationRail with views: File Editor (default), Workspace, Validation Results, Settings
  - [ ] Workspace file list: show all detected ARXMLs; click to open (on-demand tab)
  - [ ] Background indexing progress: global progress + per-file status (queued/processing/processed/error)
  - [ ] Drag-and-drop files/folders into Workspace (desktop/web) to index
- [ ] Web compatibility for workspace ingestion (PRIORITY):
  - [ ] Open directory on web (fallback to multi-file selection) and index all ARXMLs
  - [ ] Persist workspace session in-memory; no auto-tabs; manual refresh

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
- [ ] Accessibility/contrast modes and adjustable density
- [ ] NavigationRail (PRIORITY): add view switching (File Editor, Workspace, Validation, Settings)
- [ ] Inline SHORT-NAME display on rows (Moved to 1.1 as PRIORITY)

## 1.8 Performance & Architecture
- [ ] Schema index cache per version; lazy-load schema fragments
- [ ] Very large file optimizations (virtualization tuning, metrics, background parsing)
- [ ] Extensible validator plug-in API (project‑specific rules)

## 1.9 Testing & CI
- [ ] Stabilize file_loading_integration_test.dart (eliminate hang; replace timeout workaround with proper async settle)
- [ ] Expanded AUTOSAR tests (SWC ports, packages, ECUC cases)
- [ ] Cross‑file reference resolution tests
- [ ] Validation report tests + performance benchmarks
- [ ] Integration test harness: reduce animations/settling in tests (no nested ProviderScope; finite pumps)
- [ ] Auto‑XSD detection mapping tests (xsi:schemaLocation pairs, 4-3-0 variants, workspace XSD search)
- [ ] Validation UX tests: ADMIN-DATA ignore option, navigable results focus/scroll, row badge presence
- [ ] Unsaved indicator tests: tab badge shows on edit, clears on save; close-with-unsaved prompts

## 1.10 Optional Enhancements (Backlog)
- [ ] XSD schema selection UI
  - [x] AppBar action to pick .xsd via file picker
  - [x] Per-tab selected schema with status indicator
  - [x] Persist last-used XSD path (per session)
  - [x] Fallback to built-in AUTOSAR_00050.xsd
- [ ] Add more integration tests for save/load round‑trip
- [ ] Performance monitoring/metrics for large files
- [ ] UI polish and micro‑animations

---

# 2. Completed (reverse chronological)

## 2.1 Latest Changes (Aug 2025)
- [x] Live validation while editing via debounced ValidationScheduler (toggle-controlled)
- [x] Go to Definition opens target file in a tab on demand and scrolls to the node (scrollToIndex wiring)
- [x] LRU AST cache implemented and wired for open/navigate paths
- [x] XsdParser: deeper traversal defaults (particleDepthLimit=4, groupDepthLimit=3); richer diagnostics trace buffer
- [x] Diagnostics: bug toggle now shows inline trace viewer panel
- [x] Auto-detect XSD from ARXML header/version when opening/creating files; per‑tab schema set accordingly
- [x] Simple validation action (AppBar) produces violations report with element paths
- [x] Added unit test validation_report_test for invalid child detection
- [x] TabBar selected tab gets subtle pill background (with bold + underline retained)
- [x] Add Child UX: remembers last picked child per parent tag; inline validation hint when empty/invalid
- [x] Row hover highlight + animated chevron rotation for expand/collapse
- [x] Context menu editing clarified: container (e.g., SHORT-NAME) -> Rename Tag; leaf value -> Edit Value
- [x] Increased contrast for tab filenames (white text on dark AppBar)
- [x] Edit Value fixed: available for leaf nodes and nodes with a single text child; value saved reliably
- [x] Add Child always available; supports manual custom element entry in addition to XSD-derived options
- [x] Chevron expand/collapse icon size increased for better clickability

## 2.2 Recent Accomplishments
- [x] Fixed TabController updates on provider state changes (_updateTabController in build + post-frame)
- [x] Verified real file load on Windows desktop
- [x] Improved logs for loading and state transitions
- [x] Per‑tab XSD selection UI (picker button, per‑tab indicator, default fallback)
- [x] XsdParser enhancements: namespace‑agnostic indexes, complexContent, @ref resolution, xs:all, improved attribute discovery
- [x] UI color refresh with gradient AppBar and TabBar styling
