import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';



import 'package:arxml_explorer/elementnodecontroller.dart';
import 'package:arxml_explorer/xsd_parser.dart';

// Self-made packages
import 'elementnode.dart';
import 'elementnodewidget.dart';
import 'arxmlloader.dart';
import 'elementnodesearchdelegate.dart';

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
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  int fabDepth = 1;

  final List<ElementNodeController> _nodeControllers = [];
  final List<String> _filePaths = [];
  TabController? _tabController;
  XsdParser? _xsdParser;
  bool _isLoading = false;

  final ARXMLFileLoader _arxmlLoader = const ARXMLFileLoader();

  final ScrollController scrollController = ScrollController();

  final Map<int, GlobalKey> _nodeKeys = {};

  late final CustomSearchDelegate searchDelegate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _nodeControllers.length, vsync: this);
    searchDelegate = CustomSearchDelegate(
      widget.scaffoldKey,
      _nodeControllers.isNotEmpty
          ? _nodeControllers[_tabController!.index]
          : ElementNodeController(),
      isCaseSensitive: false,
      isWholeWord: false,
    );
  }

  void _loadXsdFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xsd'],
    );

    if (result != null) {
      String? filePath = result.files.single.path;
      if (filePath != null) {
        File file = File(filePath);
        final fileContent = file.readAsStringSync();
        setState(() {
          _xsdParser = XsdParser(fileContent);
        });
      }
    }
  }

  /// Callback function called from the ElementNodeController to trigger a rebuild
  void requestRebuildCallback() {
    setState(() {});
  }

  void _openFile([String? filePath]) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final nodeController = ElementNodeController();
      List<ElementNode> lList =
          await _arxmlLoader.openFile(nodeController, filePath);

      setState(() {
        _nodeControllers.add(nodeController);
        _filePaths.add(filePath ?? "new file");
        _tabController =
            TabController(length: _nodeControllers.length, vsync: this);
        nodeController.init(
            lList, requestRebuildCallback, (id) => _scrollToNode(id));
      });
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Error"),
            content: Text("Failed to open file: ${e.toString()}"),
            actions: <Widget>[
              TextButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeFile(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Remove File"),
          content: Text("Are you sure you want to remove ${_filePaths[index]}?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Remove"),
              onPressed: () {
                File(_filePaths[index]).delete();
                _closeFile(index);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _closeFile(int index) {
    setState(() {
      _nodeControllers.removeAt(index);
      _filePaths.removeAt(index);
      _tabController =
          TabController(length: _nodeControllers.length, vsync: this);
    });
  }

  void _saveFile() async {
    if (_tabController == null || _nodeControllers.isEmpty) return;
    final controller = _nodeControllers[_tabController!.index];
    final filePath = _filePaths[_tabController!.index];
    final xmlString = _arxmlLoader.toXmlString(controller.rootNodesList);
    await File(filePath).writeAsString(xmlString);
  }

  void _createFile() async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'new_file.arxml',
    );

    if (outputFile != null) {
      File file = File(outputFile);
      const String defaultContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<AUTOSAR>
</AUTOSAR>
''';
      await file.writeAsString(defaultContent);
      _openFile(outputFile);
    }
  }

  Future<void> _scrollToNode(int id) async {
    if (_tabController == null || _nodeControllers.isEmpty) return;
    final controller = _nodeControllers[_tabController!.index];
    // Ensure the node is visible before scrolling by expanding its parents.
    controller.expandUntilNode(id);
    // Select the node to highlight it.
    controller.onSelected(id, true);

    // Schedule the scroll to happen after the UI has finished rebuilding.
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _nodeKeys[id];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(key.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut).whenComplete(() => completer.complete());
      } else {
        completer.complete();
      }
    });
    return completer.future;
  }

  void _collapseAll() {
    if (_tabController == null || _nodeControllers.isEmpty) return;
    _nodeControllers[_tabController!.index].collapseAll();
  }

  void _expandAll() {
    if (_tabController == null || _nodeControllers.isEmpty) return;
    _nodeControllers[_tabController!.index].expandAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ARXML Explorer"),
        actions: [
          IconButton(icon: const Icon(Icons.file_open), onPressed: _openFile),
          IconButton(
              icon: const Icon(Icons.create_new_folder),
              onPressed: _createFile),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveFile,
          ),
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                showSearch(context: context, delegate: searchDelegate);
              }),
          IconButton(
            icon: const Icon(Icons.unfold_less),
            onPressed: _collapseAll,
          ),
          IconButton(
            icon: const Icon(Icons.unfold_more),
            onPressed: _expandAll,
          ),
          IconButton(
            icon: const Icon(Icons.schema),
            onPressed: _loadXsdFile,
          ),
        ],
        bottom: _nodeControllers.isNotEmpty
            ? TabBar(
                controller: _tabController,
                tabs: _filePaths
                    .map((path) => Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(path),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    _closeFile(_filePaths.indexOf(path)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    _removeFile(_filePaths.indexOf(path)),
                              )
                            ],
                          ),
                        ))
                    .toList(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _nodeControllers.isNotEmpty
              ? TabBarView(
                  controller: _tabController,
                  children: _nodeControllers.map((controller) {
                    return ListView.builder(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: controller.itemCount,
                      itemBuilder: (context, index) {
                        final node = controller.getNode(index);
                        if (node == null) return Container();
                        final key = GlobalKey();
                        _nodeKeys[node.id] = key;
                        return ElementNodeWidget(node, _xsdParser, key: key);
                      },
                    );
                  }).toList(),
                )
              : const Center(
                  child: Text("Open a file to begin"),
                ),
      key: widget.scaffoldKey,
    );
  }
}