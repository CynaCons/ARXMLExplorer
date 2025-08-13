# ARXMLExplorer Plan – Checklist

# 1. Active Plan (Reset – Aug 2025)

## 1.1 NavigationRail Remediation & Redesign
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

## 1.2 AppBar / Top Toolbar Consolidation
- [ ] Inventory current icons (list & purpose)
- [ ] Define primary always-visible actions (e.g., Open, Save, Undo, Redo)
- [ ] Move secondary/rare actions (Diagnostics toggle, Live Validation toggle, High Contrast, Settings) into overflow menu
- [ ] Introduce overflow (3‑dot) menu with labeled actions + shortcuts in tooltips
- [ ] Group related actions (Save/Save All; Validation toggles) logically
- [ ] Remove redundant or low-value icons after consolidation
- [ ] Provide keyboard shortcut cheat sheet entry (modal or menu section)

## 1.3 Accessibility & Layout Enhancements
- [ ] Minimum tap target >= 44x44 for rail destinations and toolbar icons
- [ ] Focus outline & keyboard navigation order for rail & overflow menu
- [ ] Color contrast audit for new square indicator (WCAG AA)
- [ ] Tooltip text audit (clear, consistent verbs)

## 1.4 Testing & Validation (to integrate after implementation)
- [ ] Golden test for updated NavigationRail (light/dark + high contrast)
- [ ] Widget test: selecting each destination updates active view
- [ ] Widget test: overflow menu opens & triggers actions (e.g., toggle diagnostics)
- [ ] Accessibility test: focus traversal sequence includes rail then toolbar then editor
- [ ] Regression test: stray "ARXML" element no longer present

## 1.5 Workspace View Refactor (Hierarchical + Status)
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

---

# 2. Completed (Consolidated History)

## 2.1 Architecture, Parsing & Schema
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

## 2.2 Editing & Refactoring Features
- Convert element type (schema‑driven with child migration & pruning)
- Safe SHORT-NAME rename with sibling conflict detection
- Undo/Redo command stack (dirty flag recalculation)
- Add Child UX improvements (remember last choice, validation hint)
- Inline SHORT-NAME row display (SHORT-NAME child collapsed)
- Context menu: collapse / expand children, edit value / rename tag
- New File creation (templates scope removed per direction)

## 2.3 Tree Navigation & UI/UX
- Keyboard navigation: arrows, left/right collapse/expand, Home/End, PageUp/PageDown
- Enter: edit leaf / toggle container; ESC clears selection
- Ctrl+F search delegate integration
- Selection + scroll focusing (ensure visible)
- NavigationRail redesign (pill indicator, adaptive labels, hover/press animation, high contrast outline)
- Accessibility: high contrast mode & adjustable density groundwork
- Resource HUD overlay + settings toggle
- Tab bar styling (selected pill, contrast boost, hover highlights)
- Row hover highlight + animated chevron rotation

## 2.4 Validation & Diagnostics
- Validation engine (child legality, issues with severity)
- Validation options: ignore ADMIN-DATA, severity filters, in‑list search filter
- Live validation (debounced scheduler, toggle)
- Validation results UX: navigable list, copy path, next/prev shortcuts
- Row‑level issue badges & aggregated counts
- AppBar issue count badge + scrollbar gutter marks
- Quick “Go to issue” action for first offending descendant
- Diagnostics verbose trace toggle + inline trace viewer panel

## 2.5 Workspace & Cross‑File
- Workspace picker & indexing (symbol/short-name reference index)
- Incremental indexing with FS watch debounce
- LRU AST cache (speed reopening & navigation)
- Cross‑file go‑to definition (opens tab, navigates to node)
- Reference normalization (absolute/relative, vendor separators, backslashes, dot segments, ECUC + port/interface hooks)
- Reference indicator + disambiguation handling
- Workspace Explorer view (file list, progress, DnD add files)

## 2.6 State & Providers Refactor
- Extraction of views to feature modules (editor, validation, workspace)
- Providers relocated (file_tabs_provider, validation_providers, app_providers)
- ElementNodeWidget decomposition (actions, dialogs, ref_indicator, validation_badge)
- Validation gutter extraction
- Workspace models split from indexer
- Legacy widget stubbing & cleanup phases

## 2.7 Miscellaneous UX & Quality
- Unsaved changes indicator (tab badge, Save All, close prompt)
- Improved loading/log output & real file load verification (Windows)
- Increased filename contrast
- Settings view (Live validation, Verbose diagnostics, Ignore ADMIN-DATA toggles)
- Simple validation action producing violations report

## 2.8 Testing (Implemented So Far)
- AUTOSAR sample XSD child extraction tests (SWC, BSW, namespace)
- Schema validation basic test (invalid child detection)
- Ref normalization core case tests

---

# 3. Change Log Notes
- Plan fully reset on Aug 2025; all prior completed items consolidated above.

---

# 4. Next Steps (Add Here When New Work Identified)
- _<placeholder>_

