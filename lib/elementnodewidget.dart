import 'package:flutter/material.dart';

import 'elementnode.dart';

/// Constants
const double constIconSize = 12.0;
const double constSizedBoxWidth = 10.0;
const double constIconPadding = 4.0;

class ElementNodeWidget extends StatefulWidget {
  final ElementNode? node;
  const ElementNodeWidget(this.node, {super.key});

  @override
  State<ElementNodeWidget> createState() => _ElementNodeWidgetState();
}

class _ElementNodeWidgetState extends State<ElementNodeWidget> {
  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    Text text;

    // Build the (optional) debug text
    String debugText =
        "(NodeId=${widget.node!.id} IsCollapsed=${widget.node!.isCollapsed} IsVisible=${widget.node!.isVisible} UncollapseLength=${widget.node!.uncollapsedLength}) VisibleLength=${widget.node!.visibleLength}";

    String widgetText =
        "${widget.node!.elementText} ${widget.node!.shortname} ${widget.node!.definitionRef} $debugText";

    // Add the SizedBox
    // If there is a node
    if (widget.node != null) {
      double sizedBoxWidth = 0;
      if (widget.node!.children.isNotEmpty) {
        // If the node has childrens, then it needs the collapse Icon
        sizedBoxWidth = widget.node!.depth * constSizedBoxWidth;
      } else {
        // The node has no children. Increase the box size due to no Icon
        sizedBoxWidth = widget.node!.depth * constSizedBoxWidth + 50;
      }
      children.add(SizedBox(width: sizedBoxWidth));
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
            onPressed: (() => {
                  setState(() {
                    // First process the collapse event
                    widget.node?.onCollapseStateChange!(
                        widget.node!.id, widget.node!.isCollapsed);

                    // Then update the state
                    // widget.node!.isCollapsed = !widget.node!.isCollapsed;
                  }),
                })));

        text = Text(widgetText);
      } else {
        text = Text(widgetText);
      }
    } else {
      text = const Text("Unexpected Widget built. Index out of range");
    }

    // Add the Text and wrap it in an Expanded to avoid collisions for long text
    children.add(Expanded(child: text));

    Color lNodeColor = Colors.white;
    if (widget.node!.isSelected == true) lNodeColor = Colors.grey;

    return GestureDetector(
        onTap: ((() => {
              setState((() {
                // Call the onNodeSelected handler
                widget.node!.onSelected!(
                    widget.node!.id, !widget.node!.isSelected);
              }))
            })),
        child: Container(color: lNodeColor, child: Row(children: children)));
  }
}
