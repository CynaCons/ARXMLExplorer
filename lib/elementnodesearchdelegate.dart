import 'package:flutter/material.dart';
import 'package:arxml_explorer/elementnodecontroller.dart';
import 'package:arxml_explorer/elementnode.dart';


class CustomSearchDelegate extends SearchDelegate<String> {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final ElementNodeController nodeController;
  final bool isCaseSensitive;
  final bool isWholeWord;

  CustomSearchDelegate(this.scaffoldKey, this.nodeController, {this.isCaseSensitive = false, this.isWholeWord = false});

  bool _matchesQuery(String? text, String query) {
    if (text == null || text.isEmpty) return false;

    String searchText = isCaseSensitive ? text : text.toLowerCase();
    String searchQuery = isCaseSensitive ? query : query.toLowerCase();

    if (isWholeWord) {
      return RegExp(r'\b' + RegExp.escape(searchQuery) + r'\b').hasMatch(searchText);
    } else {
      return searchText.contains(searchQuery);
    }
  }

  List<ElementNode> _performSearch(String query) {
    if (query.isEmpty) {
      return [];
    }

    return nodeController.flatMapValues.where((node) {
      final combinedText = '${node.elementText} ${node.shortname} ${node.definitionRef}'.trim();
      return _matchesQuery(combinedText, query) || 
             _matchesQuery(node.elementText, query) ||
             _matchesQuery(node.shortname, query) ||
             _matchesQuery(node.definitionRef, query);
    }).toList();
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
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final List<ElementNode> searchResults = _performSearch(query);

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final ElementNode node = searchResults[index];
        return ListTile(
          title: Text(node.elementText),
          subtitle: Text('${node.shortname} ${node.definitionRef}'.trim()),
          onTap: () {
            // When a result is tapped, expand its parents and scroll to it
            nodeController.expandUntilNode(node.id);
            nodeController.onScrollToNode(node.id);
            close(context, node.elementText);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final List<ElementNode> suggestionList = _performSearch(query);

    return ListView.builder(
      itemCount: suggestionList.length,
      itemBuilder: (context, index) {
        final ElementNode node = suggestionList[index];
        return ListTile(
          title: Text(node.elementText),
          subtitle: Text('${node.shortname} ${node.definitionRef}'.trim()),
          onTap: () {
            // When a suggestion is tapped, expand its parents and scroll to it
            nodeController.expandUntilNode(node.id);
            nodeController.onScrollToNode(node.id);
            close(context, node.elementText);
          },
        );
      },
    );
  }
}
