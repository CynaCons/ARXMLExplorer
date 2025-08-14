# Product Requirements Document: ARXMLExplorer

## 1. Introduction
The ARXMLExplorer is a cross-platform tool designed to explore, view, modify, and manage AUTOSAR XML (ARXML) files. It aims to provide an intuitive and efficient way for users to interact with complex ARXML structures, ensuring compliance with AUTOSAR meta-models and XML Schema Definitions.

## 2. User Stories
As a user, I want to:
- Open and view the hierarchical structure of an ARXML file.
- Easily navigate through large ARXML files by collapsing and expanding elements.
- Search for specific keywords within the opened ARXML files and quickly jump to the results.
- Modify existing elements in an ARXML file, with validation against the AUTOSAR schema.
- Create new elements in an ARXML file, ensuring schema compliance.
- Manage multiple ARXML files simultaneously (open, close, remove).
- Have a visually clear representation of the ARXML structure, including depth and parent-child relationships.
- Experience smooth performance, even with very large ARXML files.
- Save modified ARXML files back to disk.

## 3. Features

### Core Functionality
- **ARXML File Loading:** Ability to load and parse AUTOSAR XML files.
- **Hierarchical Viewing:** Display the ARXML content in a tree-like structure.
- **File Management:**
    - Create new ARXML files.
    - Load existing ARXML files.
    - Close opened ARXML files.
    - Remove ARXML files from the application (and optionally from disk).
    - Manage multiple opened ARXML files concurrently (e.g., via tabs).
- **Searching:**
    - Search for keywords within opened ARXML documents.
    - Display search results.
    - Allow jumping to a specific node from search results.
    - Provide search suggestions as the user types.

### Editing Capabilities
- **Element Modification:** Allow users to modify the values of existing elements.
- **Schema-Compliant Editing:** Ensure all modifications adhere to the AUTOSAR meta-model and XML Schema Definition of the chosen AUTOSAR release. The editor should only present valid modification options.
- **Element Creation:** Support the creation of new elements within the existing document.
- **Schema-Compliant Creation:** The creation editor should only show options compliant with the AUTOSAR schema.

### Visual Enhancements & User Experience
- **Collapsing/Uncollapsing:** Support collapsing and uncollapsing of ARXML content elements.
- **Default Node Collapsing:** Automatically collapse 'DEFINITION-REF' and 'SHORT-NAME' nodes by default, appending their defining references or shortnames next to the container type for conciseness.
- **Depth Indication:** Replace simple spacing with more visually distinct depth indicators (e.g., spaced dots or horizontal dashes).
- **Parent-Child Visual Cues:** Implement visual ways to express the relationship between parent and child nodes.
- **Loading Indicator:** Display a visual loading indicator when ARXML files are being processed and cache data is constructed.
- **Collapse/Expand All:** Provide buttons to collapse all nodes or expand all nodes.
- **File Menu:** Implement a standard file menu for operations like "File-Open" and "File-Save".

### Performance
- **Efficient Collapsing/Uncollapsing:** Ensure efficient handling of collapsing and uncollapsing for large files, addressing potential recursion issues by flattening the collapse state management.
- **Optimized Scrolling:** Compare and improve scrolling performance, potentially by loading text content first and then progressively rendering complete details for large files.

### Advanced Features
- **Workspace Management:** Multi-file workspace with cross-file reference resolution and indexing.
- **Validation Engine:** Real-time XSD validation with contextual error reporting and suggestions.
- **Navigation Rail:** Modern UI with dedicated views for Editor, Workspace, Validation, and Settings.
- **Live Validation:** Background validation with debounced updates and severity filtering.
- **Reference Normalization:** Cross-file go-to-definition with ECUC and port-specific reference handling.
- **Command System:** Undo/redo support with structural change detection.
- **Schema Detection:** Automatic XSD detection from ARXML headers with version fallback.
- **Performance Optimization:** AST caching, incremental indexing, and virtualized rendering for large files.

### Other
- **MSI Packaging:** Ability to package the application into an MSI installer (with restricted usage).
- **Asynchronous Workers:** Utilize asynchronous workers for tasks that can be updated in the background.

## 4. Architecture
Implemented as a layered architecture with clear separation of concerns:
- **Presentation Layer:** Flutter widgets and views (`ui/`, `features/*/view`)
- **Application Layer:** State management, providers, and commands (`features/*/state`)
- **Core Layer:** Pure models, parsers, validation, and utilities (`core/`, `packages/arxml_core`)
- **State Management:** Riverpod for reactive state and provider composition
- **Command Pattern:** Structured editing with undo/redo and validation integration
- **Modular Design:** Feature-based organization with barrel exports and dependency rules
