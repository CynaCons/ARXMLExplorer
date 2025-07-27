import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/depth_indicator.dart';
import 'package:arxml_explorer/xsd_parser.dart';
import 'package:flutter/material.dart';



/// Constants
const double constIconSize = 12.0;
const double constSizedBoxWidth = 10.0;
const double constIconPadding = 4.0;

class ElementNodeWidget extends StatefulWidget {
  final ElementNode? node;
  final XsdParser? xsdParser;
  const ElementNodeWidget(this.node, this.xsdParser, {Key? key})
      : super(key: key);

  @override
  State<ElementNodeWidget> createState() => _ElementNodeWidgetState();
}

class _ElementNodeWidgetState extends State<ElementNodeWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Add this line
    List<Widget> children = [];
    Text text;

    String widgetText =
        "${widget.node!.elementText} ${widget.node!.shortname} ${widget.node!.definitionRef}";

    // Add the SizedBox
    // If there is a node
    if (widget.node != null) {
      children.add(DepthIndicator(
        depth: widget.node!.depth,
        isLastChild: widget.node!.parent?.children.last == widget.node,
      ));
    } else {
      // If there is no Node, use a default SizedBox size
      children.add(const SizedBox(width: constSizedBoxWidth));
    }

    if (widget.node != null) {
      if (widget.node!.children.isNotEmpty) {
        // Handle IconButton in case there are children
        children.add(IconButton(
            iconSize: constIconSize,
            padding: const EdgeInsets.all(constIconPadding),
            icon: widget.node!.isCollapsed
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.minimize),
            onPressed: () => widget.node?.onCollapseStateChange!(
                widget.node!.id, widget.node!.isCollapsed)));

        text = Text(widgetText);
      } else {
        text = Text(widgetText);
      }
    } else {
      text = const Text("Unexpected Widget built. Index out of range");
    }

    // Add the Text and wrap it in an Expanded to avoid collisions for long text
    children.add(Expanded(child: text));

    // Add the "Add Child" button
    if (widget.xsdParser != null) {
      children.add(IconButton(
        icon: const Icon(Icons.add),
        onPressed: () {
          _showAddChildDialog(context, widget.node!);
        },
      ));
    }

    // Add the "Delete" button
    children.add(IconButton(
      icon: const Icon(Icons.delete),
      onPressed: () {
        _showDeleteDialog(context, widget.node!);
      },
    ));

    Color lNodeColor = Colors.white;
    if (widget.node!.isSelected == true) lNodeColor = Colors.grey;

    return GestureDetector(
        onTap: () {
          if (widget.node!.children.isEmpty) {
            _showEditDialog(context, widget.node!);
          } else {
            setState(() {
              // Call the onNodeSelected handler
              widget.node!
                  .onSelected!(widget.node!.id, !widget.node!.isSelected);
            });
          }
        },
        child: Container(color: lNodeColor, child: Row(children: children)));
  }

  void _showDeleteDialog(BuildContext context, ElementNode node) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Node'),
          content: const Text('Are you sure you want to delete this node?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                setState(() {
                  node.parent?.children.remove(node);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddChildDialog(BuildContext context, ElementNode node) {
    final validChildElements =
        widget.xsdParser!.getValidChildElements(node.elementText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Child Node'),
          content: DropdownButton<String>(
            items: validChildElements
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  node.children.add(ElementNode(
                    elementText: value,
                    depth: node.depth + 1,
                    nodeController: node.nodeController,
                  ));
                });
                Navigator.of(context).pop();
              }
            },
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, ElementNode node) {
    final TextEditingController controller =
        TextEditingController(text: node.elementText);
    final bool isNumeric = int.tryParse(node.elementText) != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Node'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              errorText: (isNumeric && int.tryParse(controller.text) == null)
                  ? 'Must be a number'
                  : null,
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (isNumeric && int.tryParse(controller.text) == null) {
                  return;
                }
                setState(() {
                  node.elementText = controller.text;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
