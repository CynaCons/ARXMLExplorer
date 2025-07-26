import 'package:flutter/material.dart';
import 'package:ARXMLExplorer/elementnodearxmlprocessor.dart';
import 'dart:developer' as developer;
import 'package:ARXMLExplorer/elementnodecontroller.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Self-made packages
import 'elementnode.dart';
import 'elementnodewidget.dart';
import 'arxmlloader.dart';
import 'elementnodesearchdelegate.dart';

/// TASKLIST
///
/// TODO Collapse the DefinitionRef and ShortName nodes
///
///
/// Devlog: next features should focus on better displaying
///
/// Examples:
/// Feature #1
/// If container contains a DEFINITION REF, then collapse it by default and
/// append the defining ref on the right of the shortname
///
/// Feature #2
/// THe SizedBox should be replaced by spaced dots or by horiwontal dashes
/// The goal here would be to have a more clearly identifiable depth
///
/// Feature #3
/// Find a visual way to express the relation between a parent node and its children nodes
///
/// Feature #4
/// If a container contains a SHORT-NAME element, then collapse the shortname
/// and display the shortname next to the container type
///
/// Feature #5
/// Add a loading visual indicator at the start of the applicaion when the ARXML is being
/// processed and the cache data constructed
///
/// Feature #6
/// Try to find something to be updated with asynchronous workers
///
/// Feature #7
/// Compare the scrolling performance of pure text VS what we do.
/// Find a way to improve the scrolling performance but maybe loading just the text first and then the complete stuff
///
/// Feature #8
/// Add a butter for collapseAll and a button for expandAll
///
/// Feature #9
/// Check how to build menus in Flutter. If elegant, then add a menu for the File-Open and Filw->Save
///
/// Feature #10
/// Add a search feature to be able to jump to a desired keyword. Use controller.jumpTo or
/// something similar on the listview scroll controller
///
/// Feature #11
/// Package into an MSI but restrict usage to only some users (me)
///
/// The OnCollapsedChange is not woring for large file. Too much recursion. The CollapseChange state should probably be flattened out
/// This would allow instant change for the State
/// This implies that the getNode(id) should maybe use a flat list of node ?
///

/// Once concept would be to askthe higher-level nodes for the nodeId
/// Each node holds the range of nodeId which he has as childs, and if not found, he asks the parent node.
///
/// Another concept, probably better would be to have a global node cache with immediate and deterministic time access.
/// Nodes only need to know the NodeController

void main() {
  runApp(const XmlExplorerApp());
}

class XmlExplorerApp extends StatelessWidget {
  const XmlExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARXML Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'ARXML Explorer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int fabDepth = 1;
  List<ElementNode> _rootNodesList = [];
  final ElementNodeController _nodeController = ElementNodeController();
  final ARXMLFileLoader _arxmlLoader = const ARXMLFileLoader();
  final ElementNodeARXMLProcessor _elementNodeArxmlProcessor =
      const ElementNodeARXMLProcessor();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late CustomSearchDelegate _searchDelegate;

  @override
  void initState() {
    super.initState();
    _searchDelegate = CustomSearchDelegate(widget.scaffoldKey, _nodeController);
  }

  /// Callback function called from the ElementNodeController to trigger a rebuild
  void requestRebuildCallback() {
    setState(() {});
  }

  void _openFile() async {
    List<ElementNode> lList = await _arxmlLoader.openFile(_nodeController);
    requestRebuildCallback();
    setState(() {
      _rootNodesList = lList;
      _nodeController.init(_rootNodesList, requestRebuildCallback, _scrollController);
    });
    _elementNodeArxmlProcessor.processNodes(_nodeController);
    setState(() {});
  }

  void _saveFile() async {
    developer.log("Saving the file");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ARXML Explorer"), actions: [
        IconButton(icon: const Icon(Icons.file_open), onPressed: _openFile),
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: _saveFile,
        ),
        IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: _searchDelegate);
            })
      ]),
      body: KeyboardListener(
          autofocus: true,
          focusNode: _focusNode,
          
          child: ListView.builder(
            controller: _scrollController,
            // ignore: unnecessary_null_in_if_null_operators
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _nodeController.itemCount,
            itemBuilder: (context, index) {
              return ElementNodeWidget(_nodeController.getNode(index));
            },
          )),
      key: widget.scaffoldKey,
    );
  }
}
