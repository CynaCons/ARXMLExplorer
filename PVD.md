# Product Validation Document (PVD)

## Introduction
This document outlines a set of user-level test cases designed for smoke testing the recent changes implemented in the ARXMLExplorer application. These tests focus on core functionalities and aim to quickly verify that the application is stable and key features are working as expected from a user's perspective. More extensive and detailed testing, including edge cases and corner cases, will be covered by automated software tests.

## Test Environment
- **Application:** ARXMLExplorer (Windows desktop application)
- **Input Files:** You will need access to at least one valid AUTOSAR XML (ARXML) file, and optionally a non-ARXML file (e.g., a plain text file or an image) for error handling tests.

## Test Cases

### Test Case 1: Application Startup & Basic File Open
- **Objective:** Verify that the application launches successfully and can open a valid ARXML file without errors.
- **Steps:**
    1. Launch the ARXMLExplorer application.
    2. Click the "Open File" icon (folder icon) in the top-left corner of the application window.
    3. In the file dialog, navigate to and select a valid `.arxml` file.
    4. Click "Open".
- **Expected Result:**
    - The application window appears without crashing.
    - The content of the selected ARXML file is displayed in the main view as a hierarchical tree.
    - No error messages or dialogs are displayed.
- **Test Result**
    - PASSED

### Test Case 2: Error Handling for Invalid File Type
- **Objective:** Verify that the application correctly handles attempts to open non-ARXML files.
- **Steps:**
    1. Launch the ARXMLExplorer application.
    2. Click the "Open File" icon.
    3. In the file dialog, select a file that is *not* an ARXML file (e.g., a `.txt`, `.jpg`, or `.pdf` file).
    4. Click "Open".
- **Expected Result:**
    - An "Error" dialog box appears with a message indicating that the file failed to open or is not a valid ARXML file.
    - The application does not crash.
- **Test Result**
    - PASSED

### Test Case 3: Collapsing and Expanding Individual Nodes
- **Objective:** Verify that individual nodes in the ARXML tree can be collapsed and expanded correctly.
- **Steps:**
    1. Open a valid ARXML file (refer to Test Case 1).
    2. Locate a node in the displayed tree that has child elements (indicated by a chevron or minus icon next to it).
    3. Click the chevron/minus icon next to this node.
    4. Observe the node's children.
    5. Click the icon next to the same node again.
- **Expected Result:**
    - When clicked the first time, the node's children disappear (collapse), and the icon changes (e.g., to a right-pointing chevron).
    - When clicked the second time, the node's children reappear (expand), and the icon changes back (e.g., to a minus icon).
- **Test Result**
    - PASSED

### Test Case 4: Collapse All and Expand All Buttons
- **Objective:** Verify that the global "Collapse All" and "Expand All" buttons function as expected.
- **Steps:**
    1. Open a valid ARXML file (refer to Test Case 1).
    2. Click the "Collapse All" icon (two arrows pointing inwards) in the AppBar.
    3. Observe the entire tree.
    4. Click the "Expand All" icon (two arrows pointing outwards) in the AppBar.
- **Expected Result:**
    - After clicking "Collapse All", all nodes in the tree (except the root nodes) should collapse, showing only the top-level elements.
    - After clicking "Expand All", all nodes in the tree should expand, revealing all child elements.
- **Test Result**
    - PASSED

### Test Case 5: Default Collapsing of Specific Nodes
- **Objective:** Verify that 'DEFINITION-REF' and 'SHORT-NAME' nodes are collapsed by default upon file loading.
- **Steps:**
    1. Open an ARXML file that is known to contain 'DEFINITION-REF' and 'SHORT-NAME' elements.
    2. Observe the initial state of the displayed tree.
- **Expected Result:**
    - Any 'DEFINITION-REF' and 'SHORT-NAME' nodes within the ARXML structure should be initially displayed in a collapsed state.
- **Test Result**
    - PASSED

### Test Case 6: Basic Search Functionality
- **Objective:** Verify that the search feature can find keywords, display suggestions, and navigate to the selected result.
- **Steps:**
    1. Open a valid ARXML file (refer to Test Case 1).
    2. Click the "Search" icon (magnifying glass) in the AppBar.
    3. In the search bar that appears, type a keyword that you know exists within the ARXML file (e.g., a short-name, an element name).
    4. Observe the suggestions that appear below the search bar.
    5. Select one of the suggested results by clicking on it.
- **Expected Result:**
    - As you type, a list of relevant suggestions should appear.
    - Clicking a suggestion should close the search bar and navigate the main view to the corresponding node in the tree. The node's parents should be automatically expanded if they are collapsed.
    - The search should match text as it is displayed to the user (e.g., "CONTAINER MyContainer").
    - The navigated node should be reliably scrolled to and highlighted.
- **Test Result**
    - FAILED (User reports that scrolling is unreliable, and the search logic does not match the displayed text, causing confusion.)

