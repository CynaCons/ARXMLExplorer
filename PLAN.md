# ARXMLExplorer Implementation Plan

## Checklist

- [X] **Urgent: Fix Collapsing/Search Bug**
    - [X] Enhance tests to cover node ID assignment and child node collapsing.
    - [X] Fix the root cause in the `ElementNodeController` by assigning unique IDs to all nodes.
    - [X] Validate the fix with the enhanced tests.
- [ ] Phase 0: Codebase Cleanup & Stability
    - [X] Remove redundant code/comments (`TASKLIST`, unused `_focusNode`)
    - [X] Refactor `scrollToNode` for accurate scrolling
    - [X] Add basic error handling for file operations
    - [X] Introduce basic testing framework/first test
        - [X] Refactor `ARXMLFileLoader` to separate file picking and XML parsing
        - [X] Write unit test for XML parsing logic
- [ ] Phase 1: Enhance Search & Navigation
    - [X] Improve search functionality (e.g., case sensitivity, whole word, regex)
    - [X] Improve collapsing/uncollapsing efficiency for large files
    - [X] Implement "Collapse All" and "Expand All" buttons
    - [X] Implement default collapsing of 'DEFINITION-REF' and 'SHORT-NAME' nodes
- [ ] Phase 2: Enhance File Handling and Multi-File Support
    - [X] Implement "Create New File" functionality
    - [X] Implement "Close File" functionality
    - [X] Implement "Remove File" functionality
    - [X] Design and implement UI for managing multiple open files (tabs or similar)
    - [X] Update file loading to support multiple files
- [ ] Phase 3: Implement Basic Editing Features
    - [X] Design and implement UI for editing existing element values
    - [X] Implement basic validation for edited values (e.g., data type checks)
- [ ] Phase 4: Advanced Editing and Schema Compliance
    - [X] Integrate AUTOSAR meta-model and XSD for validation during editing and creation
    - [X] Implement UI for creating new elements (schema-aware)
    - [X] Implement UI for deleting elements
- [ ] Phase 5: Refinements and Visual Enhancements
    - [X] Implement visual features for depth indication (e.g., spaced dots/horizontal dashes)
    - [X] Implement visual cues for parent-child relationships
    - [X] Add loading indicator for ARXML processing
    - [X] Optimize scrolling performance

## Detailed Plan

### Phase 0: Codebase Cleanup & Stability

**Goal:** Address immediate code quality issues, improve stability, and lay the groundwork for more robust development.

**Steps:**

1.  **Remove redundant code/comments (`TASKLIST`, unused `_focusNode`):**
    *   **Analysis:** The `TASKLIST` comments in `lib/main.dart` are now redundant with the `PRD.md` and `PLAN.md`. The `_focusNode` in `lib/main.dart` is declared but unused after the `KeyboardListener` was removed.
    *   **Proposed Change:**
        *   Delete the `TASKLIST` block from `lib/main.dart`.
        *   Remove the `_focusNode` declaration from `lib/main.dart`.
    *   **Verification:** Ensure the application still builds and runs without errors.

2.  **Refactor `scrollToNode` for accurate scrolling:**
    *   **Analysis:** The current `scrollToNode` in `elementnodecontroller.dart` uses a hardcoded `id * 50.0` for scrolling, which is brittle and assumes a fixed item height.
    *   **Proposed Change:**
        *   In `lib/main.dart`, when building the `ListView.builder`, assign a `GlobalKey` to each `ElementNodeWidget` or use `Scrollable.ensureVisible` if appropriate for the context.
        *   In `lib/elementnodecontroller.dart`, modify `scrollToNode` to use `_scrollController.position.ensureVisible` or calculate the exact offset based on the `RenderBox` of the target `ElementNodeWidget`.
    *   **Verification:** Test scrolling to various nodes, especially in files with varying content, to ensure accurate and smooth navigation.

3.  **Add basic error handling for file operations:**
    *   **Analysis:** The current file loading (`_openFile` in `lib/main.dart`) lacks explicit error handling for scenarios like file not found, permission issues, or malformed XML.
    *   **Proposed Change:**
        *   Wrap the `_arxmlLoader.openFile` call in `_openFile` with a `try-catch` block.
        *   Display user-friendly error messages (e.g., using a `SnackBar` or `AlertDialog`) if an error occurs during file loading.
    *   **Verification:** Test by attempting to open non-existent files, files with incorrect permissions, and malformed XML files.

4.  **Introduce basic testing framework/first test:**
    *   **Analysis:** The project currently lacks comprehensive automated tests, making refactoring and new feature development risky.
    *   **Proposed Change:**
        *   Set up a basic unit testing structure (if not already present beyond `widget_test.dart`).
        *   Write a simple unit test for a core component, e.g., `ARXMLFileLoader` (to test its `openFile` method with a mock file) or `ElementNodeController` (to test `init` or `getNode`).
    *   **Verification:** Run the newly created test and ensure it passes.

### Phase 1: Enhance Search & Navigation

**Goal:** Improve the search experience and implement advanced navigation features.

**Steps:**

1.  **Improve search functionality (e.g., case sensitivity, whole word, regex):**
    *   **Analysis:** The current search is basic string matching.
    *   **Proposed Change:** Add options to the search UI (e.g., checkboxes or a dropdown) for case-sensitive search, whole-word matching, and potentially regular expression search. Update the filtering logic in `elementnodesearchdelegate.dart` accordingly.
    *   **Verification:** Test all new search options with various queries.

2.  **Improve collapsing/uncollapsing efficiency for large files:**
    *   **Analysis:** The `PRD.md` mentions "The OnCollapsedChange is not working for large file. Too much recursion." This indicates a performance bottleneck.
    *   **Proposed Change:** Revisit the `ElementNodeController`'s `_nodeCache` and `_flatMap` management. Consider a more efficient data structure or algorithm for updating the visible nodes when collapsing/uncollapsing, perhaps by only updating the affected range rather than rebuilding the entire cache.
    *   **Verification:** Test with very large ARXML files and measure the performance of collapsing/uncollapsing.

3.  **Implement "Collapse All" and "Expand All" buttons:**
    *   **Analysis:** These are common features for tree views.
    *   **Proposed Change:** Add buttons to the `AppBar` or a dedicated toolbar. Implement methods in `ElementNodeController` to set all nodes to collapsed or expanded state and trigger a full rebuild.
    *   **Verification:** Test the functionality of these buttons.

4.  **Implement default collapsing of 'DEFINITION-REF' and 'SHORT-NAME' nodes:**
    *   **Analysis:** This is a specific visual enhancement requested in the PRD.
    *   **Proposed Change:** Modify the ARXML parsing logic in `arxmlloader.dart` or the node processing in `elementnodearxmlprocessor.dart` to identify these specific node types and set their `isCollapsed` property to `true` by default during initialization.
    *   **Verification:** Open ARXML files containing these node types and verify they are collapsed by default.

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

1.  **Implement visual features for depth indication (e.g., spaced dots/horizontal dashes):**
    *   **Design:** Replace `SizedBox` with a more visually distinct depth indicator.
    *   **Implementation:** Modify `ElementNodeWidget` to render dots, dashes, or other visual cues based on the node's depth.
    *   **Verification:** Visually inspect the tree view to ensure depth is clearly indicated.

2.  **Implement visual cues for parent-child relationships:**
    *   **Design:** Consider using lines, connectors, or indentation guides to visually link parent and child nodes.
    *   **Implementation:** Modify `ElementNodeWidget` and potentially its parent to draw these visual connectors.
    *   **Verification:** Visually inspect the tree view.

3.  **Add loading indicator for ARXML processing:**
    *   **Design:** Display a progress indicator (e.g., `CircularProgressIndicator`) when a file is being loaded or processed.
    *   **Implementation:** Show the indicator before `_arxmlLoader.openFile` and hide it after processing is complete.
    *   **Verification:** Open a large file and observe the loading indicator.

4.  **Optimize scrolling performance:**
    *   **Analysis:** The `PRD.md` mentions "Compare the scrolling performance of pure text VS what we do. Find a way to improve the scrolling performance but maybe loading just the text first and then the complete stuff".
    *   **Proposed Change:** Investigate Flutter's performance optimization techniques for `ListView.builder`, such as `addAutomaticKeepAlives`, `addRepaintBoundaries`, or `addSemanticIndexes`. If necessary, consider lazy loading of complex widget parts or rendering a simpler text-only view initially, then progressively enhancing it.
    *   **Verification:** Test scrolling performance with large files and compare it to a simple text view.