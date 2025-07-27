# Project Fix and Test Enhancement Plan

## Checklist

- [ ] **Phase 1: Stabilize the Application**
    - [ ] Fix all compilation errors and static analysis issues.
    - [ ] Refactor code for testability (remove filePicker injection).
    - [ ] Verify stabilization with `flutter analyze` and `flutter test`.
- [ ] **Phase 2: Enhance Test Suite**
    - [ ] Implement correct `FilePicker` mocking strategy using the platform setter.
    - [ ] Create generic and large ARXML test files.
    - [ ] Implement tests for File Handling features.
    - [ ] Implement tests for Editing and Schema features.
    - [ ] Implement tests for Visuals and UX features.
    - [ ] Implement tests for Performance.
- [ ] **Phase 3: Final Verification**
    - [ ] Run all tests and analysis to ensure the project is stable.
    - [ ] Build and run the application for final evaluation.

## Phase 1: Stabilize the Application

**Goal:** Fix all compilation errors and static analysis issues to get the application into a runnable state.

1.  **Fix Missing Imports:**
    *   Add `import 'dart:io';` to `lib/main.dart`.
    *   Add `import 'package:file_picker/file_picker.dart';` to `lib/main.dart`.
2.  **Fix Code Structure:**
    *   Move the `import 'package:arxml_explorer/xsd_parser.dart';` directive to the top of `lib/main.dart` to resolve the `directive_after_declaration` error.
3.  **Fix Test Files:**
    *   Reinstate the `searchDelegate` field in `MyHomePageState` in `lib/main.dart` to resolve the `undefined_getter` errors in `test/search_and_scroll_test.dart`.
4.  **Address SDK Version Warnings:**
    *   Update the SDK constraints in `pubspec.yaml` to a version that supports the used APIs (e.g., `'>=3.0.0 <4.0.0'`).
5.  **Verification:**
    *   Run `flutter analyze` and ensure there are no errors.
    *   Run `flutter test` and ensure all existing tests pass.

## Phase 2: Enhance Test Suite

**Goal:** Achieve comprehensive test coverage for all implemented features, using robust and compliant test data.

1.  **Refactor for Testability:**
    *   Remove the `filePicker` parameter from the `XmlExplorerApp` and `MyHomePage` widgets.
    *   Update the `ARXMLFileLoader.openFile` method to remove the `filePicker` parameter. The application code will consistently use the static `FilePicker.platform`.
2.  **Mock `FilePicker` using the Platform Setter:**
    *   In the `setUp` block of all relevant test files, set `FilePicker.platform` to a mock instance.
    *   Configure the mock to return appropriate `Future` values for `pickFiles` and `saveFile` to prevent system dialogs and test different scenarios.
3.  **Update Test ARXML Data:**
    *   Create a generic, compliant ARXML file for testing: `test/res/generic_ecu.arxml`.
4.  **Create Large ARXML Test File:**
    *   Generate a large, compliant ARXML file (`test/res/large_generic_ecu.arxml`) with 500-1000 lines to test performance.
5.  **Implement Feature-Specific Tests:**
    *   Update and enable all previously written tests for File Handling, Editing, Schema, Visuals, and Performance to use the new mocking strategy.
    *   Ensure tests cover all success and failure cases for file operations.

## Phase 3: Final Verification

**Goal:** Ensure the application is stable, fully tested, and ready for user evaluation.

1.  **Iterative Analysis and Testing:**
    *   Continuously run `flutter analyze` and `flutter test` after each major change, fixing any new issues that arise.
2.  **Final Build and Run:**
    *   Execute the `flutter run` command to build and start the application.
    *   Provide instructions for the user to evaluate the final, stable application.
