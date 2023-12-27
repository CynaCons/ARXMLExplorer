import 'package:flutter/material.dart';

class CustomSearchDelegate extends SearchDelegate<String> {
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
    /// #1 Get the flatMap nodes from the NodeController
    /// #2 Iterate through each node, if the node contains the query word, then store the corresponding node in a separate list
    /// #3 Iterate through the sublist and serialize line by line all of their texts
    /// #4 Show the results in a side panel, either on the side or at the bottom.
    ///
    return Container(child: (Text(query)));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // TODO: Implement search suggestions based on the query
    return Container(
        // Display search suggestions here
        );
  }
}
