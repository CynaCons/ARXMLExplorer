# ARXMLExplorer Implementation Plan

## Checklist

- [ ] Phase 1: Fix Current Build Issues and Basic Search
    - [X] Fix "Too many positional arguments" error in `main.dart`
    - [X] Implement `buildResults` in `elementnodesearchdelegate.dart`
    - [X] Implement `buildSuggestions` in `elementnodesearchdelegate.dart`
    - [X] Verify search functionality
- [ ] Phase 2: Enhance File Handling and Multi-File Support
    - [ ] Implement "Create New File" functionality
    - [ ] Implement "Close File" functionality
    - [ ] Implement "Remove File" functionality
    - [ ] Design and implement UI for managing multiple open files (tabs or similar)
    - [ ] Update file loading to support multiple files
- [ ] Phase 3: Implement Basic Editing Features
    - [ ] Design and implement UI for editing existing element values
    - [ ] Implement basic validation for edited values (e.g., data type checks)
- [ ] Phase 4: Advanced Editing and Schema Compliance
    - [ ] Integrate AUTOSAR meta-model and XSD for validation during editing and creation
    - [ ] Implement UI for creating new elements (schema-aware)
    - [ ] Implement UI for deleting elements
- [ ] Phase 5: Refinements and Visual Enhancements
    - [ ] Improve collapsing/uncollapsing efficiency for large files
    - [ ] Implement visual features for depth indication (e.g., spaced dots/horizontal dashes)
    - [ ] Implement visual cues for parent-child relationships
    - [ ] Implement "Collapse All" and "Expand All" buttons
    - [ ] Add loading indicator for ARXML processing
    - [ ] Optimize scrolling performance

## Detailed Plan

### Phase 1: Fix Current Build Issues and Basic Search

**Goal:** Get the application building and running, and implement the core search functionality as described in the PRD.

**Steps:**

1.  **Fix "Too many positional arguments" error in `main.dart`:**
    *   **Analysis:** Re-examine `lib/main.dart` around line 115 and the `KeyboardListener` and `showSearch` calls. The error indicates `showSearch` is being called incorrectly. It's likely that the `KeyboardListener`'s `onKeyEvent` is not the right place for this, or the `showSearch` call itself is malformed.
    *   **Proposed Change:** Remove the `KeyboardListener` and its `onKeyEvent` entirely. The search functionality is already triggered by an `IconButton` in the `AppBar`. The `KeyboardListener` was likely an attempt to add a keyboard shortcut, but it's causing a build error and is not strictly necessary for the core search feature.
    *   **Verification:** Attempt to build and run the application after this change.

2.  **Implement `buildResults` in `elementnodesearchdelegate.dart`:**
    *   **Analysis:** The `PRD.md` states: "ARXMLExplorer shall be able to search keywords within the opened documents and display search results". The `elementnodesearchdelegate.dart` file has placeholder `buildResults` and `buildSuggestions` methods. The `ElementNodeController` has a `_flatMap` which contains all nodes.
    *   **Proposed Change:**
        *   In `lib/elementnodesearchdelegate.dart`, modify `CustomSearchDelegate` to accept an `ElementNodeController` in its constructor.
        *   In `buildResults`, access the `_flatMap` from the `ElementNodeController`.
        *   Filter the `_flatMap` to find `ElementNode` objects whose `name` or `value` (or other relevant properties) contain the `query` string (case-insensitive).
        *   Return a `ListView.builder` that displays the matching `ElementNode` objects using `ElementNodeWidget`. Each search result should be clickable to jump to its location in the main tree view (this will require adding a method to `ElementNodeController` to scroll to a specific node).
    *   **Verification:** Manually test the search functionality by typing queries and verifying the results.

3.  **Implement `buildSuggestions` in `elementnodesearchdelegate.dart`:**
    *   **Analysis:** Similar to `buildResults`, but for displaying suggestions as the user types.
    *   **Proposed Change:**
        *   In `buildSuggestions`, filter the `_flatMap` based on whether the `query` is a prefix of any node's `name` or `value`.
        *   Display these suggestions in a `ListView.builder`. When a suggestion is tapped, set the `query` to the suggestion and show the results.
    *   **Verification:** Manually test by typing partial queries and observing suggestions.

4.  **Verify search functionality:**
    *   **Steps:**
        *   Run the application.
        *   Open an ARXML file.
        *   Click the search icon.
        *   Type various search queries (full words, partial words, case variations).
        *   Verify that relevant results are displayed in `buildResults`.
        *   Verify that relevant suggestions appear in `buildSuggestions`.
        *   Verify that clicking a search result navigates to the corresponding node in the main view.

### Phase 2: Enhance File Handling and Multi-File Support

**Goal:** Implement the ability to manage multiple ARXML files simultaneously, as per the PRD.

**Steps:**

1.  **Implement "Create New File" functionality:**
    *   **Design:** Add a "New File" option to the app bar or a file menu. When selected, prompt the user for a file name and location, and create a new, empty ARXML structure (e.g., a basic root element).
    *   **Implementation:** Use `file_picker` for saving the new file. Update `ElementNodeController` to manage the new file's state.
    *   **Verification:** Create a new file, save it, and verify it can be opened later.

2.  **Implement "Close File" functionality:**
    *   **Design:** Add a "Close File" option. If there are unsaved changes, prompt the user to save or discard.
    *   **Implementation:** Remove the file's state from `ElementNodeController`.
    *   **Verification:** Open a file, make changes, try to close it, and verify the save/discard prompt.

3.  **Implement "Remove File" functionality:**
    *   **Design:** This might be a more sensitive operation. It should involve a confirmation dialog.
    *   **Implementation:** Use `dart:io` to delete the file from the filesystem.
    *   **Verification:** Create a dummy file, remove it, and verify it's gone.

4.  **Design and implement UI for managing multiple open files (tabs or similar):**
    *   **Design:** Consider using a `TabBar` or similar widget to display open files as tabs. Each tab would represent a different ARXML file and its corresponding `ElementNodeController` state.
    *   **Implementation:** Refactor `MyHomePage` to manage a list of `ElementNodeController` instances, one for each open file. Update the `ListView.builder` to display the content of the currently selected tab's controller.
    *   **Verification:** Open multiple files, switch between them, and verify that their content is displayed correctly.

5.  **Update file loading to support multiple files:**
    *   **Implementation:** Modify `_openFile` to add the newly opened file's data to the list of managed files and create a new `ElementNodeController` for it.
    *   **Verification:** Open several files and ensure they are all accessible through the new multi-file UI.

### Phase 3: Implement Basic Editing Features

**Goal:** Allow users to modify existing element values within the ARXML structure.

**Steps:**

1.  **Design and implement UI for editing existing element values:**
    *   **Design:** When an `ElementNodeWidget` is tapped, display an editable field (e.g., a `TextFormField` in a dialog or inline) for its value.
    *   **Implementation:**
        *   Add an `onTap` handler to `ElementNodeWidget`.
        *   When tapped, show a dialog with a `TextFormField` pre-filled with the current value.
        *   On saving, update the `ElementNode` object and trigger a rebuild.
        *   Implement a "Save File" button in the `AppBar` to persist changes to disk.
    *   **Verification:** Open an ARXML file, edit a value, save the file, close and reopen to verify the change.

2.  **Implement basic validation for edited values (e.g., data type checks):**
    *   **Analysis:** The PRD mentions "Modifications to the ARXML document must be compliant with the AUTOSAR meta-model and XML Schema definition". For now, implement basic type validation (e.g., if a value is expected to be an integer, ensure the input is an integer). Full schema validation will come later.
    *   **Implementation:** Add validation logic to the editing UI. Display error messages to the user if validation fails.
    *   **Verification:** Attempt to enter invalid data types and verify that error messages are displayed and changes are not saved.

### Phase 4: Advanced Editing and Schema Compliance

**Goal:** Enable schema-compliant creation and modification of ARXML elements.

**Steps:**

1.  **Integrate AUTOSAR meta-model and XSD for validation during editing and creation:**
    *   **Analysis:** This is a significant undertaking. It will likely involve parsing the AUTOSAR XSD files to understand the valid structure, attributes, and data types for each element.
    *   **Implementation:**
        *   Research and select a Dart/Flutter library for XML Schema (XSD) parsing and validation, or implement a custom parser if no suitable library exists.
        *   Load the relevant AUTOSAR XSD files at application startup.
        *   Modify the editing UI to use the loaded schema for real-time validation as the user types or selects options.
        *   Provide context-sensitive suggestions for valid child elements and attributes based on the current element and the schema.
    *   **Verification:** Test with various ARXML files and attempt to make schema-invalid changes, verifying that the application prevents them.

2.  **Implement UI for creating new elements (schema-aware):**
    *   **Design:** Add a "Add Child" or "Add Sibling" option to `ElementNodeWidget` context menus. When selected, present a dialog that guides the user through creating a new element, offering only schema-compliant options.
    *   **Implementation:** Use the loaded XSD to determine valid child elements and their required attributes.
    *   **Verification:** Create new elements and verify their validity against the schema.

3.  **Implement UI for deleting elements:**
    *   **Design:** Add a "Delete" option to `ElementNodeWidget` context menus, with a confirmation dialog.
    *   **Implementation:** Remove the element from the `ElementNode` tree and update the underlying XML structure.
    *   **Verification:** Delete elements and verify they are removed from the view and the saved file.

### Phase 5: Refinements and Visual Enhancements

**Goal:** Improve the user experience and visual presentation of the ARXML Explorer.

**Steps:**

1.  **Improve collapsing/uncollapsing efficiency for large files:**
    *   **Analysis:** The `PRD.md` mentions "The OnCollapsedChange is not working for large file. Too much recursion." This indicates a performance bottleneck. The current `rebuildNodeCacheAfterNodeCollapseChange` might be inefficient for deep or wide trees.
    *   **Proposed Change:** Revisit the `ElementNodeController`'s `_nodeCache` and `_flatMap` management. Consider a more efficient data structure or algorithm for updating the visible nodes when collapsing/uncollapsing, perhaps by only updating the affected range rather than rebuilding the entire cache.
    *   **Verification:** Test with very large ARXML files and measure the performance of collapsing/uncollapsing.

2.  **Implement visual features for depth indication (e.g., spaced dots/horizontal dashes):**
    *   **Design:** Replace `SizedBox` with a more visually distinct depth indicator.
    *   **Implementation:** Modify `ElementNodeWidget` to render dots, dashes, or other visual cues based on the node's depth.
    *   **Verification:** Visually inspect the tree view to ensure depth is clearly indicated.

3.  **Implement visual cues for parent-child relationships:**
    *   **Design:** Consider using lines, connectors, or indentation guides to visually link parent and child nodes.
    *   **Implementation:** Modify `ElementNodeWidget` and potentially its parent to draw these visual connectors.
    *   **Verification:** Visually inspect the tree view.

4.  **Implement "Collapse All" and "Expand All" buttons:**
    *   **Design:** Add buttons to the `AppBar` or a dedicated toolbar.
    *   **Implementation:** Add methods to `ElementNodeController` to collapse/expand all nodes and trigger a full rebuild.
    *   **Verification:** Test the functionality of these buttons.

5.  **Add loading indicator for ARXML processing:**
    *   **Design:** Display a progress indicator (e.g., `CircularProgressIndicator`) when a file is being loaded or processed.
    *   **Implementation:** Show the indicator before `_arxmlLoader.openFile` and hide it after processing is complete.
    *   **Verification:** Open a large file and observe the loading indicator.

6.  **Optimize scrolling performance:**
    *   **Analysis:** The `PRD.md` mentions "Compare the scrolling performance of pure text VS what we do. Find a way to improve the scrolling performance but maybe loading just the text first and then the complete stuff". This suggests that rendering complex `ElementNodeWidget`s for all visible items might be slow.
    *   **Proposed Change:** Investigate Flutter's performance optimization techniques for `ListView.builder`, such as `addAutomaticKeepAlives`, `addRepaintBoundaries`, or `addSemanticIndexes`. If necessary, consider lazy loading of complex widget parts or rendering a simpler text-only view initially, then progressively enhancing it.
    *   **Verification:** Test scrolling performance with large files and compare it to a simple text view.
