import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:flutter/material.dart';
import 'package:arxml_explorer/elementnode.dart';

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
      return RegExp(r'\b' + RegExp.escape(searchQuery) + r'\b')
          .hasMatch(searchText);
    } else {
      return searchText.contains(searchQuery);
    }
  }

  List<ElementNode> performSearch(String query) {
    if (query.isEmpty) {
      return [];
    }

    final results = <ElementNode>{};

    for (final node in treeState.flatMap.values) {
      // Case 1: The node's own text matches. Add it.
      if (_matchesQuery(node.elementText, query) ||
          _matchesQuery(node.shortname, query) ||
          _matchesQuery(node.definitionRef, query)) {
        results.add(node);
      }

      // Case 2: A direct child is a text node and it matches. Add the current node.
      if (node.children.length == 1 && node.children.first.children.isEmpty) {
        if (_matchesQuery(node.children.first.elementText, query)) {
          results.add(node);
        }
      }
    }
    return results.toList();
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final List<ElementNode> searchResults = performSearch(query);

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final ElementNode node = searchResults[index];
        return ListTile(
          title: Text(node.elementText),
          subtitle: Text('${node.shortname} ${node.definitionRef}'.trim()),
          onTap: () {
            close(context, node.id);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final List<ElementNode> suggestionList = performSearch(query);

    return ListView.builder(
      itemCount: suggestionList.length,
      itemBuilder: (context, index) {
        final ElementNode node = suggestionList[index];
        return ListTile(
          title: Text(node.elementText),
          subtitle: Text('${node.shortname} ${node.definitionRef}'.trim()),
          onTap: () {
            close(context, node.id);
          },
        );
      },
    );
  }
}
