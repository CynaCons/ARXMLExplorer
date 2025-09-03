import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:path/path.dart' as p;

import '../state/xsd_catalog.dart';

class XsdCatalogView extends ConsumerStatefulWidget {
  const XsdCatalogView({super.key});

  @override
  ConsumerState<XsdCatalogView> createState() => _XsdCatalogViewState();
}

class _XsdCatalogViewState extends ConsumerState<XsdCatalogView> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Initialize catalog on first build to ensure bundled res is included
      Future.microtask(() async {
        await ref.read(xsdCatalogProvider.notifier).initialize();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(xsdCatalogProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schema),
              const SizedBox(width: 8),
              Text(
                'XSD Catalog',
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              if (state.scanning)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Text('${state.count} file(s)')
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder),
                      const SizedBox(width: 8),
                      Text('Sources', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final dir = await fp.FilePicker.platform.getDirectoryPath();
                          if (dir != null) {
                            await ref
                                .read(xsdCatalogProvider.notifier)
                                .addSource(dir);
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Source'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(xsdCatalogProvider.notifier).rescan();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Rescan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.sources.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No sources configured yet'),
                    )
                  else
                    ...state.sources.map((s) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder_open),
                          title: Text(s),
                          trailing: IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await ref
                                  .read(xsdCatalogProvider.notifier)
                                  .removeSource(s);
                            },
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.list),
                        const SizedBox(width: 8),
                        Text('Discovered Schemas',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: state.byBasename.isEmpty
                          ? const Center(
                              child: Text('No schemas discovered yet'),
                            )
                          : Builder(builder: (context) {
                              final entries = state.byBasename.entries
                                  .toList()
                                ..sort((a, b) => a.key.compareTo(b.key));
                              final tiles = entries
                                  .map((e) => ListTile(
                                        dense: true,
                                        title: Text(e.key),
                                        subtitle: Text(
                                          e.value,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        trailing: Text(
                                          _versionOf(e.key),
                                          style: theme.textTheme.labelSmall,
                                        ),
                                      ))
                                  .toList();
                              return ListView(children: tiles);
                            }),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  String _versionOf(String basename) {
    final m = RegExp(r'(\d+[.-]\d+[.-]\d+)').firstMatch(basename);
    return m == null ? '' : m.group(1)!.replaceAll('-', '.');
  }
}
