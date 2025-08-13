# ARXMLExplorer Plan – Checklist

# ITERATION 1 - UI, Navigation, Workspace & XSD Remediation (Aug 2025 Active Work)

## NavigationRail Remediation & Redesign
- [ ] Remove stray "ARXML" element appearing at top of rail (identify source widget & delete)
- [ ] Ensure only intended destinations: Editor / Workspace / Validation / Settings
- [ ] Increase icon size (target ~28px) with consistent padding
- [ ] Change selection highlight to square (no rounded corners) behind icon+label
- [ ] Refine highlight color (accessible contrast; light/dark & high contrast modes)
- [ ] Enforce single-line labels (overflow ellipsis, no wrap)
- [ ] Align icon + label vertically centered; consistent spacing
- [ ] Hover & pressed states updated for square highlight (separate from selected state)
- [ ] High contrast mode variant of square highlight (outline or solid depending on theme)
- [ ] Code cleanup: extract NavRail destination builder to a dedicated helper/widget

## AppBar / Top Toolbar Consolidation
- [ ] Inventory current icons (list & purpose)
- [ ] Define primary always-visible actions (e.g., Open, Save, Undo, Redo)
- [ ] Move secondary/rare actions (Diagnostics toggle, Live Validation toggle, High Contrast, Settings) into overflow menu
- [ ] Introduce overflow (3‑dot) menu with labeled actions + shortcuts in tooltips
- [ ] Group related actions (Save/Save All; Validation toggles) logically
- [ ] Remove redundant or low-value icons after consolidation
- [ ] Provide keyboard shortcut cheat sheet entry (modal or menu section)

## Accessibility & Layout Enhancements
- [ ] Minimum tap target >= 44x44 for rail destinations and toolbar icons
- [ ] Focus outline & keyboard navigation order for rail & overflow menu
- [ ] Color contrast audit for new square indicator (WCAG AA)
- [ ] Tooltip text audit (clear, consistent verbs)

## Testing & Validation (post-implementation)
- [ ] Golden test for updated NavigationRail (light/dark + high contrast)
- [ ] Widget test: selecting each destination updates active view
- [ ] Widget test: overflow menu opens & triggers actions (e.g., toggle diagnostics)
- [ ] Accessibility test: focus traversal sequence includes rail then toolbar then editor
- [ ] Regression test: stray "ARXML" element no longer present

## Workspace View Refactor (Hierarchical + Status)
- [ ] Remove duplicate lists (identify both sources, consolidate to single data model)
- [ ] Represent workspace as directory tree (folders first, then files) reflecting actual FS structure
- [ ] Collapsible directories with expand/collapse state persistence per session
- [ ] Index status indicators per file (queued, processing, processed, error) via colored dot + tooltip
- [ ] Directory aggregate status (e.g., spinner if any child processing, warning if any error)
- [ ] Show file count per directory (badge) & processed/total fraction in tooltip
- [ ] Lazy build children on expand for performance (avoid building entire large tree up front)
- [ ] Sorting: directories alphabetically, files alphabetically (case-insensitive)
- [ ] Filter/search box (scopes to file + folder names, highlights matches, auto-expands containing branches)
- [ ] Selection opens file tab (double‑click or Enter) and scrolls to first SHORT-NAME
- [x] Double-click switches to Editor view automatically after opening
- [ ] Context menu: Refresh Directory, Reveal in OS, Remove From Index (if implemented)
- [ ] Error state styling (red icon + message tooltip) for parse/index failures
- [ ] Performance: virtualization / limited render for long sibling lists (>500) with chunked loading
- [ ] Provider/state redesign: single WorkspaceTreeNode model (folder/file) with status & children
- [ ] Migrate existing index results into hierarchical structure builder
- [ ] Tests: tree build from sample nested structure
- [ ] Tests: status indicator transitions (queued -> processing -> processed)
- [ ] Tests: filter narrows & highlights results, expands correct ancestors
- [ ] Regression test: only one list rendered (assert single Scrollable)

## Editor Navigation & Selection Fixes
- [ ] Center active element on keyboard navigation (auto scroll so selected row ~middle of viewport)
- [ ] Remove dual highlighting (unify mouse & keyboard selection state; clear stale mouse highlight on key press)
- [ ] Single authoritative selection style (high-contrast friendly)
- [ ] Smooth scroll animation (configurable on/off for tests)
- [ ] Provide API: ensureNodeCentered(nodeId)
- [ ] Test: keyboard ArrowDown keeps node centered after initial centering window
- [ ] Test: switching from mouse-click highlight to keyboard removes prior hover/active style

## NavigationRail Alignment & Visual Corrections
- [ ] Fix square (future) / current indicator alignment to exactly overlay icon bounds
- [ ] Adjust padding so indicator encloses icon+label without vertical drift
- [ ] Verify high contrast mode outline alignment
- [ ] Test: golden diff for indicator alignment (selected vs unselected)

## XSD Schema Picker & Styling
- [ ] Fix XSD selector visibility (white-on-white) by applying contrasting background or text color
- [ ] Add explicit schema badge (version + file basename) in AppBar
- [ ] Hover tooltip: full schema path
- [ ] Fallback style in high contrast mode
- [ ] Test: schema badge visible in light & dark themes (contrast >= 4.5)

## XSD Auto-Detection & Validation Reliability
- [ ] Reproduce current detection failure (log header + parsed tokens)
- [ ] Add verbose detection logging (guarded by diagnostics toggle)
- [ ] Harden xsi:schemaLocation parsing (handle line breaks, multiple spaces, odd token counts)
- [ ] Normalize version variants (4-3-0 / 4.3.0) before file lookup (re-verify existing logic)
- [ ] Workspace search fallback ordering (prefer nearest version, then default)
- [ ] Cache detection per file (invalidate on file save)
- [ ] Visual warning if validation running without schema (badge / snackbar)
- [ ] Validation: ensure parser indexes built before validate (await readiness)
- [ ] Add regression test: file with schemaLocation resolves expected XSD
- [ ] Add regression test: version-only header resolves variant file name
- [ ] Add validation test: known invalid child still reported after detection rewrite

---

# ITERATION 0 - Consolidated History (Pre-reset Accomplishments)

## Architecture, Parsing & Schema
- XSD parser relocation to core/xsd/xsd_parser (parser/index/resolver/tracing)
- ARXML loader split into core/xml/arxml_loader/{parser.dart, serializer.dart}
- Namespace‑agnostic XSD indexes, complexContent + restriction/extension handling
- Deeper traversal defaults (particleDepthLimit=4, groupDepthLimit=3), groupDepthLimit logic
- Substitution group resolution & child element caching
- Attribute discovery improvements
- Schema element definition map (buildElementIndex) for future versioned caching
- Auto‑detect XSD from ARXML header/version (schemaLocation + version variants)
- Per‑tab schema selection + detection override UI
- Fallback & workspace search for referenced XSDs

## Editing & Refactoring Features
- Convert element type (schema‑driven with child migration & pruning)
- Safe SHORT-NAME rename with sibling conflict detection
- Undo/Redo command stack (dirty flag recalculation)
- Add Child UX improvements (remember last choice, validation hint)
- Inline SHORT-NAME row display (SHORT-NAME child collapsed)
- Context menu: collapse / expand children, edit value / rename tag
- New File creation (templates scope removed per direction)

## Tree Navigation & UI/UX
- Keyboard navigation: arrows, left/right collapse/expand, Home/End, PageUp/PageDown
- Enter: edit leaf / toggle container; ESC clears selection
- Ctrl+F search delegate integration
- Selection + scroll focusing (ensure visible)
- NavigationRail redesign (pill indicator, adaptive labels, hover/press animation, high contrast outline)
- Accessibility: high contrast mode & adjustable density groundwork
- Resource HUD overlay + settings toggle
- Tab bar styling (selected pill, contrast boost, hover highlights)
- Row hover highlight + animated chevron rotation

## Validation & Diagnostics
- Validation engine (child legality, issues with severity)
- Validation options: ignore ADMIN-DATA, severity filters, in‑list search filter
- Live validation (debounced scheduler, toggle)
- Validation results UX: navigable list, copy path, next/prev shortcuts
- Row‑level issue badges & aggregated counts
- AppBar issue count badge + scrollbar gutter marks
- Quick “Go to issue” action for first offending descendant
- Diagnostics verbose trace toggle + inline trace viewer panel

## Workspace & Cross‑File
- Workspace picker & indexing (symbol/short-name reference index)
- Incremental indexing with FS watch debounce
- LRU AST cache (speed reopening & navigation)
- Cross‑file go‑to definition (opens tab, navigates to node)
- Reference normalization (absolute/relative, vendor separators, backslashes, dot segments, ECUC + port/interface hooks)
- Reference indicator + disambiguation handling
- Workspace Explorer view (file list, progress, DnD add files)

## State & Providers Refactor
- Extraction of views to feature modules (editor, validation, workspace)
- Providers relocated (file_tabs_provider, validation_providers, app_providers)
- ElementNodeWidget decomposition (actions, dialogs, ref_indicator, validation_badge)
- Validation gutter extraction
- Workspace models split from indexer
- Legacy widget stubbing & cleanup phases

## Miscellaneous UX & Quality
- Unsaved changes indicator (tab badge, Save All, close prompt)
- Improved loading/log output & real file load verification (Windows)
- Increased filename contrast
- Settings view (Live validation, Verbose diagnostics, Ignore ADMIN-DATA toggles)
- Simple validation action producing violations report

## Testing (Implemented So Far)
- AUTOSAR sample XSD child extraction tests (SWC, BSW, namespace)
- Schema validation basic test (invalid child detection)
- Ref normalization core case tests

---

# NEXT ITERATIONS (Pipeline Placeholder)
- (Add ITERATION 2 when scope approved)

