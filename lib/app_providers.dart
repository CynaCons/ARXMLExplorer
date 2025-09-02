import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/core/validation/issues.dart';

// Live validation toggle (off by default)
final liveValidationProvider = StateProvider<bool>((ref) => false);

// Show resource HUD overlay (off by default)
final showResourceHudProvider = StateProvider<bool>((ref) => false);

// Smooth scrolling toggle (on by default; tests can disable)
final smoothScrollingProvider = StateProvider<bool>((ref) => true);

// Keyboard navigation tick: increment on any keyboard-based selection change
final keyboardNavTickProvider = StateProvider<int>((ref) => 0);

// Validation options (per session for now)
final validationOptionsProvider =
    StateProvider<ValidationOptions>((ref) => const ValidationOptions());

// Latest validation issues (for status panels, etc.)
final validationIssuesProvider =
    StateProvider<List<ValidationIssue>>((ref) => const []);

// Selected severities for filtering in Validation view (default: all)
final severityFiltersProvider =
    StateProvider<Set<ValidationSeverity>>((ref) => {
          ValidationSeverity.error,
          ValidationSeverity.warning,
          ValidationSeverity.info,
        });

// Currently selected issue index in Validation view
final selectedIssueIndexProvider = StateProvider<int?>((ref) => null);
