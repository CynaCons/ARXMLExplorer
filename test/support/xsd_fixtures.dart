import 'dart:io';

import 'package:arxml_explorer/core/resources/resource_locator.dart';

/// Helpers for tests that need real, licensed AUTOSAR schemas.
///
/// `lib/res/xsd/*.xsd` is gitignored (see README "Provisioning AUTOSAR XSDs"),
/// so those files are absent on CI and on any fresh clone. Tests that require
/// them must skip with a message rather than fail — otherwise the suite is red
/// for everyone who has not provisioned schemas, which trains people to ignore
/// it.
///
/// Note the directory itself always exists (it holds a tracked README), so
/// checking for the directory is not enough — check for actual `.xsd` files.

/// Schema directory that actually contains `.xsd` files, or null.
String? _resolveXsdDir() {
  for (final dir in const ResourceLocator().xsdSearchPaths()) {
    try {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      final hasSchemas = d
          .listSync(followLinks: false)
          .whereType<File>()
          .any((f) => f.path.toLowerCase().endsWith('.xsd'));
      if (hasSchemas) return dir;
    } on FileSystemException {
      continue;
    }
  }
  return null;
}

final String? bundledXsdDir = _resolveXsdDir();

/// True when no AUTOSAR schemas are provisioned.
final bool xsdsMissing = bundledXsdDir == null;

/// Reason string for `skip:`, or null when schemas are available.
///
/// Usage:
/// ```dart
/// group('AUTOSAR XSD', () { ... }, skip: skipIfNoXsds);
/// ```
final String? skipIfNoXsds = xsdsMissing
    ? 'AUTOSAR XSDs not provisioned — see README "Provisioning AUTOSAR XSDs"'
    : null;

/// Absolute path to a named bundled schema, or null when absent.
String? bundledXsd(String basename) =>
    const ResourceLocator().resolveXsd(basename);

/// Reason string for `skip:` when one specific schema is required.
String? skipIfNoXsd(String basename) => bundledXsd(basename) == null
    ? '$basename not provisioned — see README "Provisioning AUTOSAR XSDs"'
    : null;
