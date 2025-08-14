import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/core/models/element_node.dart';
import '../../../editor.dart'; // For ARXMLTreeViewState
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/xsd_parser.dart';

class ElementNodeDialogs {
  static final Map<String, String> _lastPickedByParent = {};

  static void showEditDialog(
      BuildContext context,
      WidgetRef ref,
      ElementNode node,
      AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
          treeStateProvider,
      void Function() onPostEdit) {
    final hasTextChild =
        node.children.length == 1 && node.children.first.children.isEmpty;
    final initialText =
        hasTextChild ? node.children.first.elementText : node.elementText;
    final controller = TextEditingController(text: initialText);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Value'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                ref
                    .read(treeStateProvider.notifier)
                    .editNodeValue(node.id, controller.text);
                ref
                    .read(fileTabsProvider.notifier)
                    .markDirtyForTreeProvider(treeStateProvider);
                Navigator.pop(context);
                onPostEdit();
              },
              child: const Text('Save')),
        ],
      ),
    );
  }

  static void showRenameTagDialog(
      BuildContext context,
      WidgetRef ref,
      ElementNode node,
      AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
          treeStateProvider,
      void Function() onPostEdit) {
    final controller = TextEditingController(text: node.elementText);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Tag'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'New tag name', border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                ref
                    .read(treeStateProvider.notifier)
                    .renameNodeTag(node.id, controller.text.trim());
                ref
                    .read(fileTabsProvider.notifier)
                    .markDirtyForTreeProvider(treeStateProvider);
                Navigator.pop(context);
                onPostEdit();
              },
              child: const Text('Save')),
        ],
      ),
    );
  }

  static void showAddChildDialog(
      BuildContext context,
      WidgetRef ref,
      ElementNode node,
      XsdParser? parser,
      AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
          treeStateProvider,
      void Function() onPostEdit) {
    String? selectedElement = _lastPickedByParent[node.elementText];
    final validChildren = parser?.getValidChildElements(node.elementText,
            contextElementName: node.parent?.elementText) ??
        [];
    final customController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) {
        final canAdd =
            (selectedElement != null && selectedElement!.isNotEmpty) ||
                customController.text.trim().isNotEmpty;
        final errorText =
            canAdd ? null : 'Pick a valid element or enter a name';
        return AlertDialog(
          title: const Text('Add Child Node'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Valid children for: ${node.elementText}'),
            const SizedBox(height: 16),
            if (validChildren.isNotEmpty)
              DropdownButton<String>(
                hint: const Text('Select a valid element'),
                value: selectedElement,
                isExpanded: true,
                onChanged: (v) => setState(() => selectedElement = v),
                items: validChildren
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
              )
            else
              const Text('No valid child elements found in schema'),
            const SizedBox(height: 12),
            TextField(
                controller: customController,
                decoration: InputDecoration(
                    labelText: 'Custom element name (optional)',
                    border: const OutlineInputBorder(),
                    errorText: errorText),
                onChanged: (_) => setState(() {})),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
                onPressed: canAdd
                    ? () {
                        final name = selectedElement?.trim().isNotEmpty == true
                            ? selectedElement!
                            : customController.text.trim();
                        if (name.isNotEmpty) {
                          _lastPickedByParent[node.elementText] = name;
                          ref
                              .read(treeStateProvider.notifier)
                              .addChildNode(node.id, name);
                          ref
                              .read(fileTabsProvider.notifier)
                              .markDirtyForTreeProvider(treeStateProvider);
                          onPostEdit();
                        }
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('Add')),
          ],
        );
      }),
    );
  }

  static void showConvertTypeDialog(
      BuildContext context,
      WidgetRef ref,
      ElementNode node,
      XsdParser? parser,
      AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
          treeStateProvider,
      void Function() onPostEdit) {
    final parentTag = node.parent?.elementText;
    final candidates = parser?.getValidChildElements(parentTag ?? '') ?? [];
    final filtered = candidates.where((c) => c != node.elementText).toList();
    String? selected = filtered.isNotEmpty ? filtered.first : null;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: Text('Convert ${node.elementText} type'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (filtered.isEmpty)
              const Text('No alternative types available from schema')
            else
              DropdownButton<String>(
                value: selected,
                isExpanded: true,
                onChanged: (v) => setState(() => selected = v),
                items: filtered
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
              ),
            const SizedBox(height: 12),
            const Text(
                'Children incompatible with the new type will be pruned (SHORT-NAME preserved).'),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
                onPressed: selected == null
                    ? null
                    : () {
                        ref.read(treeStateProvider.notifier).convertNodeType(
                            node.id, selected!,
                            parser: parser);
                        ref
                            .read(fileTabsProvider.notifier)
                            .markDirtyForTreeProvider(treeStateProvider);
                        onPostEdit();
                        Navigator.pop(context);
                      },
                child: const Text('Convert')),
          ],
        );
      }),
    );
  }

  static void showSafeRenameShortNameDialog(
      BuildContext context,
      WidgetRef ref,
      ElementNode shortNameContainer, // node whose elementText == 'SHORT-NAME'
      AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
          treeStateProvider,
      void Function() onPostEdit) {
    if (shortNameContainer.children.isEmpty) return;
    final initial = shortNameContainer.children.first.elementText.trim();
    final controller = TextEditingController(text: initial);
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) {
        final notifier = ref.read(treeStateProvider.notifier);
        final proposed = controller.text.trim();
        final conflict = proposed.isNotEmpty &&
            proposed != initial &&
            notifier.isShortNameConflict(shortNameContainer.id, proposed);
        return AlertDialog(
          title: const Text('Safe Rename SHORT-NAME'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                  labelText: 'New SHORT-NAME',
                  border: const OutlineInputBorder(),
                  errorText:
                      conflict ? 'Duplicate SHORT-NAME in this scope' : null),
              onChanged: (_) => setState(() {}),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
                onPressed: proposed.isEmpty || conflict
                    ? null
                    : () {
                        ref
                            .read(treeStateProvider.notifier)
                            .safeRenameShortName(
                                shortNameContainer.id, proposed);
                        ref
                            .read(fileTabsProvider.notifier)
                            .markDirtyForTreeProvider(treeStateProvider);
                        onPostEdit();
                        Navigator.pop(context);
                      },
                child: const Text('Rename')),
          ],
        );
      }),
    );
  }
}
