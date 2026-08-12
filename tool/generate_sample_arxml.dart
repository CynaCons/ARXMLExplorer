import 'dart:io';

/// Generates a large synthetic ARXML file for manual performance inspection.
///
///   dart run tool/generate_sample_arxml.dart [nodes] [outPath]
///
/// Defaults to ~50,000 nodes at build/sample_large.arxml.
/// The automated benchmarks use the same shape — see
/// test/support/arxml_generator.dart and
/// test/performance/large_file_benchmark_test.dart.
void main(List<String> args) {
  final targetNodes = args.isNotEmpty ? int.parse(args[0]) : 50000;
  final outPath = args.length > 1 ? args[1] : 'build/sample_large.arxml';

  const nodesPerContainer = 26;
  const containersPerModule = 20;
  final containers = (targetNodes / nodesPerContainer).ceil();
  final modules = (containers / containersPerModule).ceil();

  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<AUTOSAR xmlns="http://autosar.org/schema/r4.0" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:schemaLocation="http://autosar.org/schema/r4.0 AUTOSAR_00050.xsd">')
    ..writeln('  <AR-PACKAGES>');

  var remaining = containers;
  for (var m = 0; m < modules && remaining > 0; m++) {
    b
      ..writeln('    <AR-PACKAGE>')
      ..writeln('      <SHORT-NAME>Package$m</SHORT-NAME>')
      ..writeln('      <ELEMENTS>')
      ..writeln('        <ECUC-MODULE-CONFIGURATION-VALUES>')
      ..writeln('          <SHORT-NAME>Module$m</SHORT-NAME>')
      ..writeln('          <CONTAINERS>');

    final count =
        remaining < containersPerModule ? remaining : containersPerModule;
    for (var c = 0; c < count; c++) {
      b
        ..writeln('            <ECUC-CONTAINER-VALUE>')
        ..writeln('              <SHORT-NAME>Container${m}_$c</SHORT-NAME>')
        ..writeln('              <DEFINITION-REF>'
            '/GenericModule/Module$m/Container$c</DEFINITION-REF>')
        ..writeln('              <PARAMETER-VALUES>');
      for (var pIdx = 0; pIdx < 3; pIdx++) {
        b
          ..writeln('                <ECUC-NUMERICAL-PARAM-VALUE>')
          ..writeln(
              '                  <SHORT-NAME>Param${c}_$pIdx</SHORT-NAME>')
          ..writeln('                  <VALUE>${pIdx * 7}</VALUE>')
          ..writeln('                </ECUC-NUMERICAL-PARAM-VALUE>');
      }
      b
        ..writeln('              </PARAMETER-VALUES>')
        ..writeln('            </ECUC-CONTAINER-VALUE>');
    }
    remaining -= count;

    b
      ..writeln('          </CONTAINERS>')
      ..writeln('        </ECUC-MODULE-CONFIGURATION-VALUES>')
      ..writeln('      </ELEMENTS>')
      ..writeln('    </AR-PACKAGE>');
  }

  b
    ..writeln('  </AR-PACKAGES>')
    ..writeln('</AUTOSAR>');

  final out = File(outPath);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(b.toString());

  final kb = (out.lengthSync() / 1024).toStringAsFixed(0);
  // ignore: avoid_print
  print('Wrote ${out.path} (~$targetNodes nodes, $kb KB)');
}
