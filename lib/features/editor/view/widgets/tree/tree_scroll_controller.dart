import 'package:flutter/widgets.dart';

import 'package:arxml_explorer/features/editor/view/widgets/element_node/element_node_widget.dart';

/// Index-based scrolling over a fixed-row-height list.
///
/// Replaces `ItemScrollController` from `scrollable_positioned_list`. That
/// package was adopted for `scrollTo(index:)`, but it pays for the feature with
/// an estimated scroll extent: jumping cost 16.6 s on a 10k-row list and never
/// completed at 50k, which is what froze the app when the scrollbar was dragged.
///
/// Because every tree row is exactly [kRowHeight] tall, offset and index are
/// interchangeable — `offset = index * kRowHeight`. That gives an exact
/// `maxScrollExtent`, so a real `Scrollbar` works, scrolling is smooth pixel
/// scrolling, and jumping is O(1).
class TreeScrollController {
  TreeScrollController({this.rowHeight = kRowHeight});

  final double rowHeight;
  final ScrollController scrollController = ScrollController();

  /// True once the controller is attached to a laid-out list.
  bool get isReady =>
      scrollController.hasClients &&
      scrollController.position.hasContentDimensions;

  /// Offset that places [index] at [alignment] of the viewport.
  ///
  /// `alignment` matches the old API: 0.0 pins the row to the top of the
  /// viewport, 0.5 centres it, 1.0 puts it at the bottom.
  double offsetForIndex(int index, {double alignment = 0.0}) {
    if (!isReady) return index * rowHeight;
    final position = scrollController.position;
    final target = index * rowHeight -
        alignment * (position.viewportDimension - rowHeight);
    return target.clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  /// Scrolls [index] into view.
  ///
  /// A zero [duration] jumps. Safe to call before layout: the request is
  /// dropped rather than throwing, because the caller usually fires it from a
  /// post-frame callback that can race a tab switch.
  void scrollToIndex(
    int index, {
    Duration duration = Duration.zero,
    Curve curve = Curves.easeInOut,
    double alignment = 0.0,
  }) {
    if (!isReady) return;
    final offset = offsetForIndex(index, alignment: alignment);
    if (duration == Duration.zero) {
      scrollController.jumpTo(offset);
    } else {
      scrollController.animateTo(offset, duration: duration, curve: curve);
    }
  }

  /// Scrolls only if [index] is outside the viewport, so arrow-key navigation
  /// within the visible window does not yank the list around.
  void revealIndex(
    int index, {
    Duration duration = Duration.zero,
    Curve curve = Curves.easeOut,
    double alignment = 0.5,
  }) {
    if (!isReady) return;
    final position = scrollController.position;
    final rowTop = index * rowHeight;
    final rowBottom = rowTop + rowHeight;
    final viewTop = position.pixels;
    final viewBottom = viewTop + position.viewportDimension;
    if (rowTop >= viewTop && rowBottom <= viewBottom) return;
    scrollToIndex(index,
        duration: duration, curve: curve, alignment: alignment);
  }

  /// Index of the first row at least partly visible, or null before layout.
  int? get firstVisibleIndex {
    if (!isReady) return null;
    return (scrollController.position.pixels / rowHeight).floor();
  }

  void dispose() => scrollController.dispose();
}
