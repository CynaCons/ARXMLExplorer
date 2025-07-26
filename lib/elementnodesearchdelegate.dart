import 'package:flutter/material.dart';
import 'package:ARXMLExplorer/elementnodecontroller.dart';
import 'package:ARXMLExplorer/elementnode.dart';
import 'package:ARXMLExplorer/elementnodewidget.dart';

class CustomSearchDelegate extends SearchDelegate<String> {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final ElementNodeController nodeController;

  CustomSearchDelegate(this.scaffoldKey, this.nodeController);
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
    final List<ElementNode> searchResults = nodeController.flatMapValues
        .where((node) =>
            node.elementText.toLowerCase().contains(query.toLowerCase()) ||
            node.shortname.toLowerCase().contains(query.toLowerCase()) ||
            node.definitionRef.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final ElementNode node = searchResults[index];
        return ListTile(
          title: Text(node.elementText),
          subtitle: Text('${node.shortname} ${node.definitionRef}'.trim()),
          onTap: () {
            nodeController.scrollToNode(node.id);
            close(context, node.elementText);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final List<ElementNode> suggestionList = query.isEmpty
        ? []
        : nodeController.flatMapValues
            .where((node) =>
                node.elementText.toLowerCase().startsWith(query.toLowerCase()) ||
                node.shortname.toLowerCase().startsWith(query.toLowerCase()) ||
                node.definitionRef.toLowerCase().startsWith(query.toLowerCase()))
            .toList();

    return ListView.builder(
      itemCount: suggestionList.length,
      itemBuilder: (context, index) {
        final ElementNode node = suggestionList[index];
        return ListTile(
          title: Text(node.elementText),
          subtitle: Text('${node.shortname} ${node.definitionRef}'.trim()),
          onTap: () {
            query = node.elementText;
            showResults(context);
          },
        );
      },
    );
  }
}
