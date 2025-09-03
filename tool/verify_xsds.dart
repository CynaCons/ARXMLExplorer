import 'dart:io';

void main(List<String> args) async {
  final dir = Directory('lib/res/xsd');
  if (!await dir.exists()) {
    stderr.writeln('XSD directory not found: lib/res/xsd');
    stderr.writeln('Create it and place AUTOSAR XSD files inside.');
    exitCode = 1;
    return;
  }

  final entries = await dir
      .list()
      .where((e) => e is File && e.path.toLowerCase().endsWith('.xsd'))
      .toList();

  if (entries.isEmpty) {
    stderr.writeln('No XSD files found under lib/res/xsd');
    stderr.writeln('Place AUTOSAR_00050.xsd (and others) under lib/res/xsd.');
    stderr.writeln('See README section: Provisioning AUTOSAR XSDs.');
    exitCode = 1;
    return;
  }

  final names = entries.map((e) => e.path.split(Platform.pathSeparator).last).toList()
    ..sort();
  stdout.writeln('Found ${names.length} XSD file(s):');
  for (final n in names) {
    stdout.writeln(' - $n');
  }

  final required = ['AUTOSAR_00050.xsd'];
  final missing = required.where((r) => !names.contains(r)).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('\nMissing recommended XSD(s): ${missing.join(', ')}');
    stderr.writeln('Some tests may be skipped or fail without these.');
    exitCode = 2;
  }
}

