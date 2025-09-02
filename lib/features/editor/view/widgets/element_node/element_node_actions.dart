import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/core/models/element_node.dart';
import 'package:arxml_explorer/features/editor/editor.dart'; // For ARXMLTreeViewState
import 'package:arxml_explorer/core/xsd/xsd_parser/parser.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart'
    show validationSchedulerProvider, fileTabsProvider;
import 'package:arxml_explorer/app_providers.dart';
import 'element_node_dialogs.dart';

mixin ElementNodeActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
      get treeStateProvider;
  ElementNode get node;
  XsdParser? get xsdParser; // for add child dialog
  Future<void> maybeRunLiveValidation(WidgetRef ref) async {
    if (!ref.read(liveValidationProvider)) return;
    ref.read(validationSchedulerProvider.notifier).schedule();
  }

  bool canEditValue(ElementNode node) {
    return node.children.isEmpty ||
        (node.children.length == 1 && node.children.first.children.isEmpty);
  }

  void handleMenuSelection(BuildContext context, String value, WidgetRef ref) {
    final notifier = ref.read(treeStateProvider.notifier);
    switch (value) {
      case 'edit_value':
        ElementNodeDialogs.showEditDialog(context, ref, node, treeStateProvider,
            () => maybeRunLiveValidation(ref));
        break;
      case 'edit_tag':
        ElementNodeDialogs.showRenameTagDialog(context, ref, node,
            treeStateProvider, () => maybeRunLiveValidation(ref));
        break;
      case 'add':
        ElementNodeDialogs.showAddChildDialog(context, ref, node, xsdParser,
            treeStateProvider, () => maybeRunLiveValidation(ref));
        break;
      case 'convert_type':
        ElementNodeDialogs.showConvertTypeDialog(context, ref, node, xsdParser,
            treeStateProvider, () => maybeRunLiveValidation(ref));
        break;
      case 'safe_rename_short':
        ElementNodeDialogs.showSafeRenameShortNameDialog(
            context,
            ref,
            node, // node expected to be SHORT-NAME container
            treeStateProvider,
            () => maybeRunLiveValidation(ref));
        break;
      case 'collapse_children':
        notifier.collapseChildrenOf(node.id);
        ref
            .read(fileTabsProvider.notifier)
            .markDirtyForTreeProvider(treeStateProvider);
        break;
      case 'expand_children':
        notifier.expandChildrenOf(node.id);
        break;
      case 'delete':
        notifier.deleteNode(node.id);
        ref
            .read(fileTabsProvider.notifier)
            .markDirtyForTreeProvider(treeStateProvider);
        maybeRunLiveValidation(ref);
        break;
      case 'copy_path':
        final path = buildElementPath(node);
        Clipboard.setData(ClipboardData(text: path));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Path copied: $path'),
              duration: const Duration(seconds: 1)),
        );
        break;
    }
  }

  String buildElementPath(ElementNode node) {
    final segs = <String>[];
    ElementNode? cur = node;
    while (cur != null) {
      segs.add(cur.elementText);
      cur = cur.parent;
    }
    return '/' + segs.reversed.join('/');
  }
}
