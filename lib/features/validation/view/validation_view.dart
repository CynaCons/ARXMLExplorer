import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/arxml_validator.dart';
import 'package:arxml_explorer/features/validation/state/validation_providers.dart';
import 'package:arxml_explorer/ui/home_shell.dart' show navRailIndexProvider;
import 'package:arxml_explorer/main.dart'
    show activeTabProvider; // reduced temp coupling
import 'widgets/validation_gutter.dart';

class ValidationView extends ConsumerWidget {
  final ItemScrollController itemScrollController;
  const ValidationView({super.key, required this.itemScrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(validationIssuesProvider);
    final filter = ref.watch(validationFilterProvider);
    final selectedSeverities = ref.watch(severityFiltersProvider);

    final filtered = (filter.trim().isEmpty
            ? issues
            : issues
                .where((i) =>
                    i.message.toLowerCase().contains(filter.toLowerCase()) ||
                    i.path.toLowerCase().contains(filter.toLowerCase()))
                .toList())
        .where((i) => selectedSeverities.contains(i.severity))
        .toList();

    if (issues.isEmpty) {
      return const Center(child: Text('No validation issues to display'));
    }
    final selectedIdx = ref.watch(selectedIssueIndexProvider);
    return Stack(
      children: [
        FocusableActionDetector(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.arrowDown):
                const NextFocusIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowUp):
                const PreviousFocusIntent(),
            LogicalKeySet(LogicalKeyboardKey.keyN): const NextFocusIntent(),
            LogicalKeySet(LogicalKeyboardKey.keyP): const PreviousFocusIntent(),
          },
          actions: <Type, Action<Intent>>{
            NextFocusIntent: CallbackAction<NextFocusIntent>(
              onInvoke: (intent) {
                final next =
                    ((selectedIdx ?? -1) + 1).clamp(0, filtered.length - 1);
                ref.read(selectedIssueIndexProvider.notifier).state = next;
                return null;
              },
            ),
            PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
              onInvoke: (intent) {
                final prev = ((selectedIdx ?? filtered.length) - 1)
                    .clamp(0, filtered.length - 1);
                ref.read(selectedIssueIndexProvider.notifier).state = prev;
                return null;
              },
            ),
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Filter issues by text or path',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    ref.read(validationFilterProvider.notifier).state = v;
                    ref.read(selectedIssueIndexProvider.notifier).state = null;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _severityChip(ref, 'Errors', ValidationSeverity.error,
                        Colors.redAccent),
                    _severityChip(ref, 'Warnings', ValidationSeverity.warning,
                        Colors.amber),
                    _severityChip(ref, 'Info', ValidationSeverity.info,
                        Colors.blueAccent),
                  ],
                ),
              ),
              if (selectedIdx != null &&
                  selectedIdx >= 0 &&
                  selectedIdx < filtered.length)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          filtered[selectedIdx].path,
                          style: const TextStyle(fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy path'),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: filtered[selectedIdx].path));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Path copied')),
                          );
                        },
                      )
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final issue = filtered[i];
                    final iconData = issue.severity == ValidationSeverity.error
                        ? Icons.error_outline
                        : issue.severity == ValidationSeverity.warning
                            ? Icons.warning_amber_outlined
                            : Icons.info_outline;
                    final iconColor = issue.severity == ValidationSeverity.error
                        ? Colors.redAccent
                        : issue.severity == ValidationSeverity.warning
                            ? Colors.amber
                            : Colors.blueAccent;
                    final selected = i == selectedIdx;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withOpacity(0.2),
                      leading: Icon(iconData, color: iconColor),
                      title: Text(issue.message),
                      subtitle: Text(issue.path),
                      onTap: () {
                        ref.read(selectedIssueIndexProvider.notifier).state = i;
                        final tab = ref.read(activeTabProvider);
                        if (tab == null) return;
                        final parts = issue.path
                            .split('/')
                            .where((e) => e.isNotEmpty)
                            .toList();
                        int? targetId;
                        void search(ElementNode node, int idx) {
                          if (idx >= parts.length) {
                            targetId = node.id;
                            return;
                          }
                          for (final c in node.children) {
                            if (c.elementText == parts[idx]) {
                              search(c, idx + 1);
                              if (targetId != null) return;
                            } else {
                              search(c, idx);
                              if (targetId != null) return;
                            }
                          }
                        }

                        final tree = ref.read(tab.treeStateProvider);
                        for (final r in tree.rootNodes) {
                          if (targetId != null) break;
                          if (parts.isEmpty || r.elementText == parts.first) {
                            search(r, parts.isEmpty ? 0 : 1);
                          }
                        }
                        if (targetId != null) {
                          final notifier =
                              ref.read(tab.treeStateProvider.notifier);
                          notifier.expandUntilNode(targetId!);
                          final updated = ref.read(tab.treeStateProvider);
                          final index = updated.visibleNodes
                              .indexWhere((n) => n.id == targetId);
                          if (index != -1) {
                            itemScrollController.scrollTo(
                              index: index,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                            ref.read(navRailIndexProvider.notifier).state =
                                0; // switch to editor
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 2,
          top: 0,
          bottom: 0,
          width: 6,
          child: ValidationGutter(issues: filtered),
        ),
      ],
    );
  }

  Widget _severityChip(
      WidgetRef ref, String label, ValidationSeverity sev, Color color) {
    final selected = ref.watch(severityFiltersProvider).contains(sev);
    return FilterChip(
      selected: selected,
      onSelected: (v) {
        final set = {...ref.read(severityFiltersProvider)};
        if (v) {
          set.add(sev);
        } else {
          set.remove(sev);
        }
        if (set.isEmpty) set.add(sev);
        ref.read(severityFiltersProvider.notifier).state = set;
      },
      label: Text(label),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      side: BorderSide(color: color),
    );
  }
}
