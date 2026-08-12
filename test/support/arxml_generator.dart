/// Generates synthetic ARXML documents of a controlled size for benchmarking.
///
/// Shapes mirror what real AUTOSAR ECU configuration looks like: packages
/// containing module configurations, containing containers, containing
/// parameter values — each with a SHORT-NAME and most with a DEFINITION-REF, so
/// the per-row work (SHORT-NAME inlining, reference indicators) is exercised
/// rather than optimised away by an unrealistically flat tree.
library;

/// Builds an ARXML document with roughly [targetNodes] elements.
///
/// Returns the XML text. The exact node count is approximate — the generator
/// fills whole containers rather than truncating mid-element.
String generateArxml(
    {required int targetNodes, bool withDefinitionRefs = true}) {
  // Per container: ECUC-CONTAINER-VALUE + SHORT-NAME(+text) + DEFINITION-REF
  // (+text) + PARAMETER-VALUES + 3 params x (elem + SHORT-NAME(+text) +
  // VALUE(+text)) ~= 26 nodes.
  const nodesPerContainer = 26;
  const containersPerModule = 20;

  final containers = (targetNodes / nodesPerContainer).ceil().clamp(1, 1 << 24);
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
        ..writeln('              <SHORT-NAME>Container${m}_$c</SHORT-NAME>');
      if (withDefinitionRefs) {
        b.writeln('              <DEFINITION-REF>'
            '/GenericModule/Module$m/Container$c</DEFINITION-REF>');
      }
      b.writeln('              <PARAMETER-VALUES>');
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
  return b.toString();
}
