import 'package:flutter/material.dart';
import '../../../../../core/models/element_node.dart';
import '../../../editor.dart'; // For ARXMLTreeViewState

class CustomSearchDelegate extends SearchDelegate<int?> {
  final ArxmlTreeState treeState;
  final bool isCaseSensitive;
  final bool isWholeWord;
  CustomSearchDelegate(this.treeState,
      {this.isCaseSensitive = false, this.isWholeWord = false});

  bool _matchesQuery(String? text, String query) {
    if (text == null || text.isEmpty) return false;
    String searchText = isCaseSensitive ? text : text.toLowerCase();
    String searchQuery = isCaseSensitive ? query : query.toLowerCase();
    if (isWholeWord) {
      return RegExp(r'\\b' + RegExp.escape(searchQuery) + r'\\b')
          .hasMatch(searchText);
    }
    return searchText.contains(searchQuery);
  }

  List<ElementNode> performSearch(String query) {
    if (query.isEmpty) return [];
    final results = <ElementNode>{};
    for (final node in treeState.flatMap.values) {
      if (_matchesQuery(node.elementText, query)) {
        results.add(node);
      }
      if (node.children.length == 1 && node.children.first.children.isEmpty) {
        if (_matchesQuery(node.children.first.elementText, query)) {
          results.add(node);
        }
      }
    }
    return results.toList();
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) {
    final results = performSearch(query);
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final node = results[index];
        return ListTile(
          title: Text(node.elementText),
          onTap: () => close(context, node.id),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = performSearch(query);
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final node = suggestions[index];
        return ListTile(
          title: Text(node.elementText),
          onTap: () => close(context, node.id),
        );
      },
    );
  }
}
