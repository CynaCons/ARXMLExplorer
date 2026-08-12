# ARXMLExplorer — Implementation Plan

**Goal:** Ship a cross-platform AUTOSAR ARXML explorer and editor with schema-aware validation, multi-file workspace indexing and cross-file reference resolution. See [PRD.md](PRD.md).

**Philosophy:** Single writer: powerplan owns PLAN.md. Layered architecture (presentation -> application -> core), enforced not just documented. Green build and green tests are the definition of done; a stamped task with a red analyzer is a lie. Tests prefer fixtures over licensed AUTOSAR schemas so the suite runs anywhere.

---

## v0.1 — Foundation & Core Engine
> Historical: pre-powerplan accomplishments, consolidated and closed.

### v0.1.0 — Architecture, parsing & schema (COMPLETE)
**Goal:** Establish the ARXML/XSD parsing core.
- [x] XSD parser relocation to core/xsd/xsd_parser (parser/index/resolver/tracing)
- [x] ARXML loader split into core/xml/arxml_loader/{parser.dart, serializer.dart}
- [x] Namespace-agnostic XSD indexes, complexContent + restriction/extension handling
- [x] Deeper traversal defaults (particleDepthLimit=4, groupDepthLimit=3)
- [x] Substitution group resolution & child element caching
- [x] Attribute discovery improvements
- [x] Schema element definition map (buildElementIndex) for versioned caching
- [x] Auto-detect XSD from ARXML header/version (schemaLocation + version variants)
- [x] Per-tab schema selection + detection override UI
- [x] Fallback & workspace search for referenced XSDs

### v0.1.1 — Editing & refactoring features (COMPLETE)
**Goal:** Schema-driven editing with undo/redo.
- [x] Convert element type (schema-driven with child migration & pruning)
- [x] Safe SHORT-NAME rename with sibling conflict detection
- [x] Undo/Redo command stack (dirty flag recalculation)
- [x] Add Child UX improvements (remember last choice, validation hint)
- [x] Inline SHORT-NAME row display (SHORT-NAME child collapsed)
- [x] Context menu: collapse / expand children, edit value / rename tag
- [x] New File creation (templates scope removed per direction)

### v0.1.2 — Tree navigation & UI/UX (COMPLETE)
**Goal:** Keyboard-first tree navigation.
- [x] Keyboard navigation: arrows, left/right collapse/expand, Home/End, PageUp/PageDown
- [x] Enter: edit leaf / toggle container; ESC clears selection
- [x] Ctrl+F search delegate integration
- [x] Selection + scroll focusing (ensure visible)
- [x] NavigationRail redesign (pill indicator, adaptive labels, hover/press animation)
- [x] Resource HUD overlay + settings toggle
- [x] Tab bar styling (selected pill, contrast boost, hover highlights)
- [x] Row hover highlight + animated chevron rotation

### v0.1.3 — Validation & diagnostics (COMPLETE)
**Goal:** Schema validation with navigable results.
- [x] Validation engine (child legality, issues with severity)
- [x] Validation options: ignore ADMIN-DATA, severity filters, in-list search filter
- [x] Live validation (debounced scheduler, toggle)
- [x] Validation results UX: navigable list, copy path, next/prev shortcuts
- [x] Row-level issue badges & aggregated counts
- [x] Issue count badge + scrollbar gutter marks
- [x] Quick 'Go to issue' action for first offending descendant
- [x] Diagnostics verbose trace toggle + inline trace viewer panel

### v0.1.4 — Workspace & cross-file (COMPLETE)
**Goal:** Multi-file indexing and go-to-definition.
- [x] Workspace picker & indexing (symbol/short-name reference index)
- [x] Incremental indexing with FS watch debounce
- [x] LRU AST cache (speed reopening & navigation)
- [x] Cross-file go-to definition (opens tab, navigates to node)
- [x] Reference normalization (absolute/relative, vendor separators, ECUC + port hooks)
- [x] Reference indicator + disambiguation handling
- [x] Workspace Explorer view (file list, progress, DnD add files)

### v0.1.5 — State & providers refactor (COMPLETE)
**Goal:** Feature-module extraction and Riverpod composition.
- [x] Extraction of views to feature modules (editor, validation, workspace)
- [x] Providers relocated (file_tabs_provider, validation_providers, app_providers)
- [x] ElementNodeWidget decomposition (actions, dialogs, ref_indicator, validation_badge)
- [x] Validation gutter extraction
- [x] Workspace models split from indexer
- [x] Unsaved changes indicator (tab badge, Save All, close prompt)
- [x] Settings view (Live validation, Verbose diagnostics, Ignore ADMIN-DATA toggles)

## v0.2 — UI, Navigation, Workspace & XSD Remediation
> The long Aug-Sep 2025 remediation arc: nav rail, toolbar, modular migration, workspace tree, XSD catalog and detection.

### v0.2.0 — Documentation & cleanup (COMPLETE)
**Goal:** Make the docs match the code.
- [x] Create RULES.md with dependency rules
- [x] Refresh README (remove mojibake, add XSD provisioning)
- [x] Fix mojibake in AGENTS.md and docs/architecture.md
- [x] Update pubspec description
- [x] Prune unused deps (provider, fluent_ui, flutter_simple_treeview, plugin_platform_interface)
- [x] Add coverage/ to .gitignore
- [x] Add tool to verify XSD presence (tool/verify_xsds.dart)
- [x] Default-collapse ADMIN-DATA containers in ARXML parse tree
- [x] Test: ADMIN-DATA nodes start collapsed by default

### v0.2.1 — NavigationRail remediation & redesign (COMPLETE)
**Goal:** A rail that is legible, accessible and actually clickable.
- [x] Remove stray 'ARXML' element appearing at top of rail
- [x] Ensure only intended destinations: Editor / Workspace / Validation / XSDs / Settings
- [x] Increase icon size (~28px) with consistent padding
- [x] Square selection highlight behind icon+label
- [x] Refine highlight color (accessible contrast; light/dark)
- [x] Enforce single-line labels (overflow ellipsis, no wrap)
- [x] Align icon + label vertically centered; consistent spacing
- [x] Hover & pressed states updated for square highlight
- [x] Remove broken High Contrast mode variant (deprecated toggle & styling)
- [x] Extract NavRail destination builder to a dedicated helper/widget
- [x] Add app logo/name in leading section
- [x] Fix rail taps blocked by inner GestureDetector intercepting them

### v0.2.2 — AppBar / top toolbar consolidation (COMPLETE)
**Goal:** Reclaim vertical space by moving actions into the rail.
- [x] Inventory current icons (list & purpose)
- [x] Group related actions (Save/Save All; Validation; Schema; App) logically
- [x] Remove redundant or low-value icons after consolidation
- [x] Remove AppBar title/gradient to maximize vertical space
- [x] Relocate actions to NavigationRail trailing
- [x] Improve tab text contrast (dark text on light surface)
- [x] Add material surface & outline/elevation to distinguish tab boundaries
- [x] Preserve dirty indicator & schema icon styling

### v0.2.3 — Modular architecture migration (COMPLETE)
**Goal:** Move every legacy top-level lib file into the layered structure.
- [x] Inventory legacy top-level libs to migrate
- [x] Create core/models/ (move ElementNode + related value objects)
- [x] Create core/validation/ (split arxml_validator.dart into services + issue models)
- [x] Convert root xsd_parser.dart into barrel exporting core/xsd/xsd_parser/*
- [x] Move element node UI helpers under features/editor/view/widgets
- [x] Extract command classes into features/editor/state/commands/ (one file per command)
- [x] Introduce layering: core (pure), application (state/providers), presentation (widgets/views)
- [x] Add dependency rules to RULES.md (presentation -> application -> core only)
- [x] Remove backward-compatible shim files from lib/
- [x] Update barrel exports in core.dart, editor.dart, workspace.dart
- [x] Evaluate splitting core into separate Dart package (packages/arxml_core scaffolded)
- [x] Add architecture diagram (docs/architecture.md) referencing PRD & RULES

### v0.2.4 — Editing workflow & editor navigation (COMPLETE)
**Goal:** Add-child and keyboard navigation that keep the user oriented.
- [x] Successive Add Child: expand parent if collapsed when adding
- [x] Auto-select newly added child node after add
- [x] Center newly added child (ensureNodeCentered + pendingCenter consumption)
- [x] Test: addChild selects new node & parent expanded
- [x] Center active element on keyboard navigation (alignment 0.5)
- [x] Remove dual highlighting (clear hover on key press via keyboardNavTick)
- [x] Single authoritative selection style (selectedNodeId-driven)
- [x] Smooth scroll animation (configurable via smoothScrollingProvider)
- [x] Provide API: ensureNodeCentered(nodeId)

### v0.2.5 — Workspace view refactor (COMPLETE)
**Goal:** One hierarchical tree with real per-file status.
- [x] Remove duplicate lists (single hierarchical data model in state)
- [x] Represent workspace as directory tree (folders first, then files)
- [x] Collapsible directories with expand/collapse state persistence per session
- [x] Index status indicators per file (icons reflect status)
- [x] Directory aggregate status (based on children)
- [x] Show file count per directory (badge) & processed/total fraction in tooltip
- [x] Sorting: directories alphabetically, files alphabetically (case-insensitive)
- [x] Filter box (scopes to names; simple match; branches included)
- [x] Selection/double-click opens file and switches to Editor view
- [x] Context menu: Refresh Directory, Reveal in OS, Remove From Index
- [x] Error state styling (red icon + message tooltip) for parse/index failures
- [x] Provider/state redesign: WorkspaceTreeNode with status & children
- [x] Lazy build children on expand (UI skips collapsed folders; state hydrates on demand)
- [x] Tests: tree build from sample nested structure
- [x] Tests: status indicator transitions (queued -> processing -> processed)

### v0.2.6 — XSD discovery & catalog (COMPLETE)
**Goal:** Discover, merge and expose available schemas.
- [x] Discover XSDs at startup from bundled res/ (recursive scan)
- [x] Allow user to add additional XSD directories
- [x] Persist sources list across restarts (settings storage)
- [x] Manual 'Rescan XSDs' action (Settings and/or XSD view)
- [x] Build versioned XSD catalog (map versions/aliases -> file paths)
- [x] Merge duplicates/variants (normalize 4-3-0 vs 4.3.0, prefer bundled)
- [x] Settings section controls (list, add/remove dirs, rescan)
- [x] Dedicated XSD view in NavigationRail (catalog list)
- [x] Integration: auto-detect uses catalog as primary lookup source
- [x] Tests: discovery from res, user dir add/remove, rescan updates catalog
- [x] Tests: auto-detect resolves via catalog fallback chain

### v0.2.7 — XSD auto-detection & validation reliability (COMPLETE)
**Goal:** Deterministic detection that never validates against the wrong schema.
- [x] Extract header parsing into parseSchemaHeader(xml) helper
- [x] Harden xsi:schemaLocation parsing (newlines, tabs, multiple spaces)
- [x] Support odd/mismatched token counts (drop dangling token gracefully)
- [x] Accept both single URL (noNamespace) and pair list (namespaced)
- [x] Normalize version variants prior to lookup (4-3-0 <-> 4.3.0, case-insensitive basename)
- [x] Strict fallback ordering: catalog exact -> nearest -> bundled -> workspace -> AUTOSAR_00050
- [x] Cache detected schema per open file/tab (content hash based)
- [x] Invalidate cache on save, content change, or catalog rescan
- [x] Verbose detection logging guarded by diagnostics toggle
- [x] Surface detection source in schema badge tooltip
- [x] Non-blocking warning when validation runs without a detected schema
- [x] Tests: header parsing (newlines/tabs, odd tokens, noNamespaceSchemaLocation)
- [x] Tests: selection order (catalog exact > nearest > bundled > workspace > default)

## v0.3 — Polishing & Stabilization
> Editor tab affordances and nav rail visuals.

### v0.3.0 — Editor & nav rail polishing (COMPLETE)
**Goal:** Tab close affordances and square rail visuals.
- [x] Enable closing editor tabs via inline close icon
- [x] Support closing editor tabs via context menu action
- [x] Redesign navigation rail icons as square visuals
- [x] Align selected-state highlight with icon square dimensions
- [x] Ensure workspace file open switches to editor view
- [x] Add regression test for nav switching when opening workspace file

## v0.4 — Build Recovery & Hardening
> Repair the broken build, restore unreachable editor actions, make resource resolution shippable, consolidate the duplicated core, and put CI in front of all of it.

### v0.4.0 — Restore the build (COMPLETE)
**Goal:** lib/ compiles clean and the whole suite runs again.
- [x] Fix validation_view.dart import: the `show navRailIndexProvider` clause hid validationIssuesProvider, severityFiltersProvider and selectedIssueIndexProvider (11 analyzer errors)
- [x] Finish the navRailIndexProvider move: it now lives in app_providers.dart, not home_shell.dart
- [x] flutter analyze reports 0 errors and 0 warnings
- [x] flutter test: the 10 widget test files that could not compile now load and run
- [x] Correct the stale test and analyzer claims in README.md

### v0.4.1 — Restore core editor actions (COMPLETE)
**Goal:** Save, Save All, Undo and Redo are reachable from the UI again.
- [x] Wire Save (Ctrl+S) to FileTabsNotifier.saveActiveFile()
- [x] Wire Save All (Ctrl+Shift+S) to FileTabsNotifier.saveAllFiles()
- [x] Wire Undo (Ctrl+Z) and Redo (Ctrl+Y) to the ArxmlTreeStateNotifier command stack
- [x] Publish canUndo/canRedo on ArxmlTreeState so the buttons disable reactively
- [x] Add the actions to the NavigationRail trailing group with tooltips, widget keys and shortcuts
- [x] FIX: saveActiveFile read activeTabProvider from inside FileTabsNotifier, which is a Riverpod cycle. Every save threw CircularDependencyError; undetected because Save had no UI.
- [x] saveAllFiles: only clear the dirty flag on files that actually reached disk
- [x] Widget test: edit then Save clears the dirty indicator and writes the tree
- [x] Widget test: edit then Undo restores the prior value; Redo reapplies it
- [x] Widget test: Undo and Redo start disabled on a freshly opened file

### v0.4.2 — Resource resolution & packaging correctness (COMPLETE)
**Goal:** Schemas and file dialogs work outside the repo working directory.
- [x] Remove the test/res/generic_ecu.arxml shortcut from openNewFile() so Open File always prompts
- [x] Add core/resources/ResourceLocator: env override, cwd, executable dir, asset bundle, per-user data dir
- [x] Declare lib/res/xsd/ under the flutter assets section in pubspec.yaml
- [x] Replace the three hard-coded lib/res/xsd literals in file_tabs_provider.dart
- [x] Index AUTOSAR_000NN.xsd by version: the old regex required separators, so the 9 newest bundled schemas never entered byVersion
- [x] findByVersion tolerates zero padding (50 vs 00050); findByBasename tolerates case
- [x] pickXsdForActiveTab takes a chooser callback instead of grabbing catalog.byBasename.values.first
- [x] Initialize the XSD catalog at app start rather than lazily on first detection
- [x] Defer schema attachment so opening a file no longer blocks on a 9 MB XSD parse
- [x] Test: ResourceLocator search paths, basename resolution, separator-agnostic bundled detection

### v0.4.3 — Core consolidation & layering (COMPLETE)
**Goal:** One core, and the layering rules actually enforced.
- [x] Delete packages/arxml_core: a declared dependency no lib/ file imported, diverged from lib/core (its parser used name.toString() instead of name.local and lacked the ADMIN-DATA collapse rule)
- [x] Point ref_normalizer_test at lib/core and drop arxml_core from pubspec.yaml
- [x] Move file_picker out of core/loaders/arxmlloader.dart: ARXMLFileLoader now takes a path or content
- [x] Move astCacheProvider into app_providers.dart so core stops importing flutter_riverpod
- [x] core/diagnostics/log.dart uses a plain-Dart isDebug constant instead of Flutter kDebugMode
- [x] Enforce layering in CI: the dart_code_metrics banned-imports config never ran under flutter analyze
- [x] closeFile invalidates the tab tree provider; the autoDispose family calls keepAlive, so ASTs were retained for the life of the process
- [x] ElementNode.invalidateLength() now invalidates ancestors, not just the node itself

### v0.4.4 — Observability & error handling (COMPLETE)
**Goal:** Replace print-debugging and silent failures with real diagnostics.
- [x] Add core/diagnostics/Log with debug/verbose/warn/error over dart:developer, compiled out of release builds
- [x] Remove all 20 print() calls in lib/, including the per-frame EditorView.build print and the FileTabsNotifier state-setter print
- [x] Replace the bare catch-all blocks in the open, save and schema paths with logged handling
- [x] Surface open, save and schema failures through FileTabsNotifier.lastError and a snackbar instead of swallowing them
- [x] Fix _EditorResourceHud._countNodes(): it called ref.watch outside build, from a Timer

### v0.4.5 — CI & repo hygiene (COMPLETE)
**Goal:** A pipeline that would have caught the broken build.
- [x] Add .github/workflows/ci.yml: analyze, layer-boundary check, and a ubuntu plus windows test matrix
- [x] Fail CI on analyzer errors and warnings; report info-level counts in the job summary
- [x] Tests skip themselves with a message when AUTOSAR XSDs are absent, so a bare checkout is green
- [x] Remove tracked junk: test_report.jsonl (166 KB) and __tmp.txt
- [x] Untrack coverage/lcov.info, which was already covered by .gitignore
- [x] Add .editorconfig (UTF-8, LF)

### v0.4.6 — Test harness correctness (COMPLETE)
**Goal:** Widget tests that drive the real providers instead of a fixture shortcut.
- [x] Add test/support/open_fixture.dart with pumpShell and openFixture helpers
- [x] FIX: openNewFile performs real dart:io reads, so tests must call it inside tester.runAsync; awaiting it under fake async hangs until the test times out
- [x] FIX: pumpShell sets a 1280x900 surface. The rail action column does not fit the default 800x600, so taps silently landed off-screen
- [x] Add autoAttachSchemaProvider so tests skip the multi-second XSD parse unless they are about validation
- [x] Rewrite search_and_scroll_test to drive the provider rather than tapping Open File
- [x] Widen the parser performance ceiling: a 1000 ms wall-clock bound flaked at 1019 ms under load
- [x] Result: 90 passed, 1 skipped, 0 failed; suite runtime down from over 3 minutes to about 15 seconds

## v0.5 — Linux Support
> Bring the desktop app up on Linux: runner state, path and filesystem correctness, CI matrix and packaging.

### v0.5.0 — Linux build & runtime bring-up (ACTIVE)
**Goal:** flutter build linux succeeds and the app runs from a clean checkout.
- [ ] Refresh the linux/ runner: it exists but was generated in Dec 2023 and generated_plugin_registrant.cc still registers only desktop_drop
- [ ] Regenerate plugin registration for the current dependency set: file_picker (file_selector_linux), shared_preferences_linux, path_provider_linux
- [ ] Replace the placeholder APPLICATION_ID com.example.ARXMLExplorer in linux/CMakeLists.txt
- [ ] Enable linux-desktop and confirm flutter build linux --release succeeds
- [ ] Verify file_picker on Linux: it needs zenity or kdialog at runtime, so detect and message when neither is installed
- [ ] Verify desktop_drop drag-and-drop under both X11 and Wayland
- [ ] Confirm shared_preferences writes under the XDG config directory
- [ ] Document Linux prerequisites (clang, cmake, ninja-build, libgtk-3-dev, pkg-config, liblzma-dev) in README

### v0.5.1 — Path & filesystem correctness on Linux (PLANNED)
**Goal:** No Windows-shaped path assumptions survive.
- [x] Replace tab.path.split(Platform.pathSeparator).last with p.basename() in home_shell.dart
- [x] _findInWorkspace compares on p.basename instead of splitting on Platform.pathSeparator
- [x] ResourceLocator.isBundledPath uses p.isWithin instead of matching the literal substring for the bundled directory
- [x] XSD basename lookup falls back to a case-insensitive match for case-sensitive filesystems
- [x] Bundled resources resolve relative to the executable via ResourceLocator
- [ ] Audit the remaining Platform.pathSeparator and backslash literals across lib/
- [ ] Test: path handling unit tests run green under both separators

### v0.5.2 — Linux CI matrix & packaging (PLANNED)
**Goal:** Linux is a first-class, continuously verified target.
- [x] CI test job runs a ubuntu-latest plus windows-latest matrix
- [x] CI build-linux job is defined and self-enables once linux/CMakeLists.txt is present
- [ ] Install Linux build deps in CI and confirm the build-linux job goes green
- [ ] Publish the tar.gz bundle artifact per build
- [ ] Evaluate AppImage or Flatpak packaging for distribution
- [ ] Document the Linux XSD provisioning path (~/.local/share/arxml_explorer/xsd or ARXML_XSD_DIR)

## v0.6 — UI Declutter & Editor Performance
> Reduce visual noise in the navigation rail, and make large ARXML files scrollable.

### v0.6.0 — Performance measurement harness (COMPLETE)
**Goal:** A repeatable baseline before optimising anything.
- [x] Add test/support/arxml_generator.dart: synthetic ARXML at a controlled node count, shaped like real ECU config
- [x] Add test/performance/large_file_benchmark_test.dart sweeping 5k / 20k / 50k nodes
- [x] Measure parse, full tree walk, tree state init, expandAll, collapseAll and single toggle
- [x] Measure the 40-row (one screenful) rebuild cost, with and without validation issues
- [x] Warm up before measuring: the first pump pays JIT and cold caches, which made whichever case ran second look artificially fast and once reported a negative badge overhead
- [x] Baseline at ~41k nodes: parse 107 ms, tree init 20 ms, expandAll 9 ms, 40-row rebuild 53 ms (71 ms with issues) against a 16.6 ms frame budget

### v0.6.1 — Editor scroll performance (COMPLETE)
**Goal:** A screenful of rows rebuilds inside the frame budget.
- [x] ROOT CAUSE: every row called ref.watch(treeStateProvider), so any state change rebuilt every visible row. Use select() for just isSelected / isContextMenuTarget.
- [x] ROOT CAUSE: ValidationBadge walked its whole subtree and rescanned every issue per row, per frame - a row near the root walked the entire document
- [x] Add nodeIssueIndexProvider: one post-order walk builds node id -> aggregated severity, count and messages; rows just look themselves up
- [x] nodeIssueIndexProvider watches only rootNodes, so selection and hover changes do not invalidate it
- [x] Replace per-row ListTile + AnimatedContainer with Row + ColoredBox; the implicit animation allocated a ticker per row
- [x] Replace AnimatedRotation with Transform.rotate on the chevron
- [x] Wrap rows in RepaintBoundary so hover and selection repaints do not dirty the viewport
- [x] Fixed row height (kRowHeight) so the list can skip per-row layout measurement
- [x] Drop ScrollablePositionedList.separated: a Divider between every row doubled the widget count for a hairline
- [x] Key rows by node id so elements are reused as the visible window shifts
- [x] RefIndicator bails before computeBasePath and three RefNormalizer calls when no workspace is indexed
- [x] DepthIndicator skips CustomPaint at depth <= 1 and shares one Paint instead of allocating per row
- [x] RESULT: 40-row rebuild 53 ms -> 4.6 ms (12x); with validation issues 71 ms -> 6.9 ms (10x). Both inside the 16.6 ms budget.

### v0.6.2 — Navigation rail declutter (COMPLETE)
**Goal:** One clear focal point instead of competing boxes and a stack of buttons.
- [x] Remove the 44x44 outlined box around every destination icon - five boxes competed for attention at once
- [x] Use Material 3's own NavigationRail indicator for the selected destination
- [x] Simplify the leading block from a two-line logo to a single tooltipped icon
- [x] Keep four primary actions on the rail (Open, Save, Undo, Redo); move New File, Save All and Search into an overflow menu
- [x] Remove both rail dividers
- [x] Update tests for the relocated actions and give them a desktop-sized surface

## Future (Backlog)
- [ ] Accessibility: minimum 44x44 tap target for rail destinations and toolbar icons
- [ ] Accessibility: focus outline & keyboard navigation order for rail & overflow menu
- [ ] Accessibility: colour contrast audit for the rail indicator (WCAG AA)
- [ ] Accessibility: focus traversal test covering rail -> toolbar -> editor
- [ ] Accessibility: tooltip text audit (clear, consistent verbs)
- [ ] Fix XSD selector visibility (white-on-white) with a contrasting background or text colour
- [ ] Test: schema badge visible in light & dark themes (contrast >= 4.5)
- [ ] Golden test for the NavigationRail (light/dark)
- [ ] Golden diff test for NavigationRail indicator alignment (selected vs unselected)
- [ ] Fix NavigationRail indicator alignment to exactly overlay icon bounds
- [ ] Widget test: overflow menu opens & triggers actions (e.g. toggle diagnostics)
- [ ] Regression test: stray 'ARXML' element no longer present in the rail
- [ ] Add semantic keys to NavigationRail destinations and toolbar actions; prefer key-based finders in tests
- [ ] Replace real-schema dependency in non-essential tests with fixtures; keep AUTOSAR XSD tests optional
- [ ] autosar_xsd_children_test: AR-PACKAGE/ELEMENTS should include APPLICATION-INTERFACE (XSD children resolution)
- [ ] search_and_scroll_test: stabilise with deterministic provider-driven paths and bounded pumps
- [ ] Optional 'loop add' UX (Add Another...) for the editing workflow
- [ ] Workspace: virtualization / chunked rendering for sibling lists over 500 entries
- [ ] Workspace: test that the filter narrows, highlights and expands correct ancestors
- [ ] Workspace: regression test asserting a single Scrollable is rendered
- [ ] Debounce schema detection while typing when live validation is on
- [ ] Gate live validation on detection readiness so it never runs against a stale parser
- [ ] Ensure parser and indexes are built before validation runs after a detection change
- [ ] Document the XSD auto-detection fallback ordering in inline docstrings and link to the PRD
- [ ] Test: known invalid child still reported after the detection rewrite
- [ ] Test: warning appears when no schema is available; clears after picking one
- [ ] Split large files: file_tabs_provider.dart (659), arxml_tree_view_state.dart (613), xsd_parser/parser.dart (798)
- [ ] Expand keyboard navigation test: ArrowDown keeps the node centred beyond the initial window
- [ ] Test: switching from mouse-click highlight to keyboard removes prior hover styling
- [ ] MSI packaging for Windows distribution
- [ ] Parse and build the XSD parser off the main isolate: a 9 MB AUTOSAR schema still costs ~seconds
- [ ] Chunked / windowed loading for documents beyond ~200k nodes
