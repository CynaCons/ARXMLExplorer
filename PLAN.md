# ARXMLExplorer Plan – Checklist

## Status
- [x] All core features complete (11/11)
- [x] Production ready
- [x] Major bug fixed: TabController sync with provider
- [x] AUTOSAR XSD integration
- [x] Strong test coverage

## Core Functionality
- [x] ARXML File Loading
- [x] Hierarchical Viewing (tree)
- [x] File Management (multi-tab)
- [x] File Persistence (Save/Create) – AppBar buttons wired
- [x] Searching (case sensitivity, scroll-to-result)

## Editing Capabilities
- [x] Element Modification (edit text/nodes)
- [x] Element Creation & Deletion (CRUD)
- [x] Schema‑Compliant Editing & Creation (XsdParser caching, limits, timeouts)

## UI/UX & Performance
- [x] Collapsing/Uncollapsing
- [x] Default Node Collapsing
- [x] Visual Enhancements (DepthIndicator, cues)
- [x] Loading Indicator (provider-driven)
- [x] Collapse/Expand All (AppBar buttons)
- [x] Optimized Scrolling & Performance
- [x] Subtle color theming (brand-inspired palette, gradient AppBar, styled TabBar)

## Testing
- [x] Search tests (3/3)
- [x] Schema validation tests (6/6)
- [x] XSD parser tests (namespaces, groups/choices, caching/perf)
- [x] File management tests
- [x] Editing features tests
- [x] File loading integration tests
- [x] TabController debug tests (verified fix)
- [x] Performance protections (timeouts, caching, limits)

## Recent Accomplishments
- [x] Fixed TabController updates on provider state changes (_updateTabController in build + post-frame)
- [x] Verified real file load on Windows desktop
- [x] Improved logs for loading and state transitions
- [x] Per‑tab XSD selection UI (picker button, per‑tab indicator, default fallback)
- [x] XsdParser enhancements: namespace‑agnostic indexes, complexContent, @ref resolution, xs:all, improved attribute discovery
- [x] UI color refresh with gradient AppBar and TabBar styling
- [x] Basic diagnostics toggle (verbose flag) added to UI and parser

## Latest Changes (Aug 2025)
- [x] Increased contrast for tab filenames (white text on dark AppBar)
- [x] Edit Value fixed: available for leaf nodes and nodes with a single text child; value saved reliably
- [x] Add Child always available; supports manual custom element entry in addition to XSD-derived options
- [x] Chevron expand/collapse icon size increased for better clickability

## XSD Workflow Improvements
- [x] Namespace-agnostic matching (use localName + resolve prefixes/URIs)
- [x] Follow xs:complexContent (extension/restriction) to sequences/choices
- [x] Resolve xs:element @ref and @type properly (strip prefixes, index first)
- [x] Handle xs:all
- [x] Increase traversal depth/limits for AUTOSAR (configurable) with visited set
- [x] Build indexes on load: elementsByName, groupsByName, typesByName
- [x] Support substitutionGroup (collect concrete substitutable elements)
- [ ] Improve traversal for nested sequences/choices/groups (deeper where safe)
- [ ] Add verbose diagnostics toggle to print resolution path per element
- [ ] Add unit tests with AUTOSAR samples for key elements (SWC, Ports, Packages)

## Optional Enhancements (Backlog)
- [ ] XSD schema selection UI
  - [x] AppBar action to pick .xsd via file picker
  - [x] Per-tab selected schema with status indicator
  - [x] Persist last-used XSD path (per session)
  - [x] Fallback to built-in AUTOSAR_00050.xsd
- [ ] Add more integration tests for save/load round‑trip
- [ ] Performance monitoring/metrics for large files
- [ ] UI polish and micro‑animations

## Next Actions (UI + Editing QoL)
- [ ] Add visual selected-tab state for filenames when using custom Tab child
- [ ] Refine Add Child UX (remember last picked child, add validation hints)

## Future Roadmap (Grouped)

1) Smart Schema & Validation
- [ ] Auto-detect XSD from ARXML headers (read AUTOSAR schema/version from file preamble; no external files imported into repo)
- [ ] Validate ARXML against the active XSD; produce a violations report (element path, message, quick-fix hints)
- [ ] Live validation while editing (toggle-able, throttled)
- [ ] Parent-context disambiguation for identically named elements (e.g., ELEMENTS) to tighten suggestions

2) Editing & Refactoring
- [ ] Convert element type (change tag to another schema‑valid alternative, migrate children when possible)
- [ ] Safe rename for SHORT-NAME with reference propagation where resolvable
- [ ] Undo/Redo for all edits

3) Workspace & Cross‑File Features
- [ ] File Manager: open a folder, index ARXMLs recursively, background load into tabs
- [ ] Follow references across files (e.g., DEFINITION-REF):
  - [ ] Indicator (icon/color) when a reference target is available in open workspace
  - [ ] Click to navigate and open target, else show not-found state
- [ ] Workspace refresh + incremental indexing

4) AUTOSAR Semantics Checks
- [ ] Port/interface compatibility (verify P/R ports and interfaces across files)
- [ ] ECUC parameter/value consistency checks
- [ ] Package structure checks (duplicate short names, ownership constraints)

5) UI/UX Enhancements
- [ ] Inline SHORT-NAME display on rows (keep SHORT-NAME child collapsed by default)
- [ ] Keyboard navigation and better selection/scroll focusing
- [ ] Accessibility/contrast modes and adjustable density

6) Performance & Architecture
- [ ] Schema index cache per version; lazy-load schema fragments
- [ ] Very large file optimizations (virtualization tuning, metrics, background parsing)
- [ ] Extensible validator plug-in API (project‑specific rules)

7) Testing & CI
- [ ] Expanded AUTOSAR tests (SWC ports, packages, ECUC cases)
- [ ] Cross‑file reference resolution tests
- [ ] Validation report tests + performance benchmarks
