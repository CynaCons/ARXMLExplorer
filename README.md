# ARXMLExplorer
An AUTOSAR XML file viewer built with Flutter

## 🎉 Project Status: ⚠️ ACTIVE DEVELOPMENT

**Latest Update:** Architecture refactoring in progress with core package extraction and comprehensive testing improvements.

### 🚀 Key Features
- **ARXML File Viewer:** Interactive tree view for AUTOSAR XML files with navigation rail
- **Multi-File Workspace:** Workspace management with cross-file reference resolution
- **Live Validation:** Real-time XSD validation with contextual error reporting
- **Advanced Editing:** Schema-compliant editing with undo/redo command system
- **Search & Navigation:** Find elements with auto-scroll and keyboard navigation
- **Performance Optimized:** Handles large ARXML files with AST caching and virtualization
- **Modern UI:** Material Design with tab management and responsive layout

### ✅ Development Status
- **Architecture:** Layered design with core package separation ✅
- **Core Features:** File operations, editing, validation implemented ✅
- **Testing:** Comprehensive test suite with integration tests ⚠️ (stabilization in progress)
- **Build:** Clean compilation with analyzer compliance ✅
- **Performance:** Optimized for large files with timeout management ✅

## 🛠️ Setup & Installation

### Prerequisites
- Flutter SDK (>=3.0.0 <4.0.0)
- Dart SDK
- An IDE (VS Code, Android Studio, etc.)

### Quick Start
```bash
# Clone the repository
git clone <repository-url>
cd ARXMLExplorer

# Get dependencies
flutter pub get

# Run tests
flutter test

# Run the application
flutter run
```

## 🧪 Testing

The project includes comprehensive test coverage:

```bash
# Run all tests
flutter test

# Run specific test categories
flutter test test/core/                    # Core functionality tests
flutter test test/features/editor/         # Editor feature tests
flutter test test/integration/              # Integration tests
flutter test test/performance/              # Performance benchmarks

# Run static analysis
flutter analyze

# Fast timeout tests (for CI)
flutter test --timeout=45s
```

### Test Structure
```
test/
├── core/                           # Core layer tests
│   ├── xsd/                       # XSD parser tests
│   ├── validation/                # Validation engine tests
│   └── refs/                      # Reference normalization tests
├── features/                      # Feature module tests
│   ├── editor/                    # Editor functionality tests
│   └── workspace/                 # Workspace management tests
├── integration/                   # End-to-end integration tests
│   └── file_loading_integration_test.dart
├── performance/                   # Performance and load tests
├── app/                          # Application-level tests
├── support/                      # Test utilities and mocks
└── res/                         # Test resources
    ├── generic_ecu.arxml        # Sample ARXML files
    └── test.xsd                 # Test XSD schemas
```

### Current Test Coverage
- **Core Models & Parsing:** ElementNode, ARXML loader, XSD parser
- **Validation Engine:** Schema validation, contextual error detection  
- **Editor Features:** Add/edit/delete operations, command system
- **UI Components:** Navigation rail, tab management, tree view
- **Integration:** File loading workflows, provider state management
- **Performance:** Large file handling, timeout optimization

## 📁 Project Structure

### Application Architecture
```
lib/
├── main.dart                     # Application entry point
├── app_providers.dart           # Global Riverpod providers
├── ui/                         # Shell UI components
│   └── home_shell.dart         # Main navigation shell
├── features/                   # Feature modules
│   ├── editor/                 # ARXML editor feature
│   │   ├── view/              # Editor views and widgets
│   │   └── state/             # Editor state and providers
│   ├── workspace/             # Workspace management
│   ├── validation/            # Validation views and providers
│   └── settings/              # Application settings
├── core/                      # Core business logic (being migrated)
│   ├── models/               # ElementNode and core models
│   ├── xml/                  # ARXML parsing and serialization
│   ├── xsd/                  # XSD schema parsing
│   ├── validation/           # Validation engine
│   └── refs/                 # Reference normalization
└── packages/
    └── arxml_core/           # Extracted core package
        └── lib/src/          # Pure business logic
```

### Legacy Shims
All legacy top-level shim files under `lib/` have been removed. Use the modular paths:
- core modules under `lib/core/...`
- editor modules under `lib/features/editor/...`
- workspace modules under `lib/features/workspace/...`

### Configuration Files
```
├── pubspec.yaml              # Dependencies and local packages
├── analysis_options.yaml    # Dart analyzer + dart_code_metrics
├── dart_test.yaml           # Global test timeout configuration
├── PLAN.md                  # Detailed development roadmap
├── PRD.md                   # Product requirements
└── docs/architecture.md     # Technical architecture guide
```

## 🔧 Development Notes

### Architecture Highlights
- **Layered Design:** Presentation → Application → Core with strict dependency rules
- **Package Extraction:** Core logic extracted to `packages/arxml_core` for reusability
- **Command Pattern:** Structured editing with undo/redo support
- **Riverpod State:** Reactive state management with provider composition
- **Performance:** AST caching, incremental indexing, timeout optimization

### Recent Major Improvements
- **Modular Architecture:** Feature-based organization with barrel exports
- **Core Package Split:** Reusable `arxml_core` package with pure business logic
- **Enhanced Validation:** Context-aware XSD validation with value node filtering
- **Test Stabilization:** Timeout management and bounded pump patterns
- **UI Modernization:** Navigation rail, tab management, live validation toggles

### Current Development Focus (PLAN.md)
- **UI Polish:** Navigation rail redesign, AppBar consolidation
- **Workspace Features:** Hierarchical directory tree, cross-file indexing
- **Test Migration:** Moving tests to new feature-based structure
- **Performance:** Editor navigation improvements, smooth scrolling

## 📖 Documentation
- [Development Plan](PLAN.md) - Comprehensive implementation roadmap with completion tracking
- [Product Requirements](PRD.md) - Product requirements and feature specifications
- [Architecture Guide](docs/architecture.md) - Technical architecture and layer design
- [Coding Rules](RULES.md) - Dependency rules and coding standards

## 🤝 Contributing
1. Fork the repository
2. Create a feature branch following the modular architecture
3. Follow layer dependency rules (see `docs/architecture.md`)
4. Run tests: `flutter test`
5. Ensure analyzer compliance: `flutter analyze`
6. Submit a pull request

## 📄 License
See [LICENSE](LICENSE) file for details.

---
**Active development - production-ready core with ongoing UI enhancements! 🚀**
