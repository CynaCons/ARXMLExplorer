import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/arxml_validator.dart';

// Live validation toggle (off by default)
final liveValidationProvider = StateProvider<bool>((ref) => false);

// Latest validation issues (for status panels, etc.)
final validationIssuesProvider =
    StateProvider<List<ValidationIssue>>((ref) => const []);
