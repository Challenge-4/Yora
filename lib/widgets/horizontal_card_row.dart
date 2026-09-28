import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/platform_paths.dart';

class HorizontalCardRow<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(T item) cardBuilder;
  final double cardWidth;
  final double cardHeight;

  const HorizontalCardRow({
    super.key,
    required this.items,
    required this.cardBuilder,
    this.cardWidth = 150,
    this.cardHeight = 220,
  });

  @override
  State<HorizontalCardRow<T>> createState() => _HorizontalCardRowState<T>();
}

class _HorizontalCardRowState<T> extends State<HorizontalCardRow<T>> {
  final _scrollController = ScrollController();
  static const _spacing = 12.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(int itemDelta) {
    final itemExtent = widget.cardWidth + _spacing;
    final currentIndex = (_scrollController.offset / itemExtent).round();
    final targetIndex = (currentIndex + itemDelta).clamp(0, widget.items.length - 1);
    final target = (targetIndex * itemExtent).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.cardHeight,
      child: Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: _SnapToItemScrollPhysics(itemExtent: widget.cardWidth + _spacing),
            itemCount: widget.items.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(right: index == widget.items.length - 1 ? 0 : _spacing),
              child: SizedBox(width: widget.cardWidth, child: widget.cardBuilder(widget.items[index])),
            ),
          ),
          if (!isMobile)
            Positioned(
              left: 4,
              top: 0,
              height: widget.cardWidth,
              child: _ScrollArrow(icon: Icons.chevron_left, onTap: () => _scrollBy(-3)),
            ),
          if (!isMobile)
            Positioned(
              right: 4,
              top: 0,
              height: widget.cardWidth,
              child: _ScrollArrow(icon: Icons.chevron_right, onTap: () => _scrollBy(3)),
            ),
        ],
      ),
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ScrollArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return Center(
      child: Material(
        color: palette.cardHover,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, color: palette.textPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}

class _SnapToItemScrollPhysics extends ScrollPhysics {
  final double itemExtent;
  const _SnapToItemScrollPhysics({required this.itemExtent, super.parent});

  @override
  _SnapToItemScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnapToItemScrollPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));
  }

  double _snappedTarget(ScrollMetrics position, double velocity, Tolerance tolerance) {
    var page = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return page.roundToDouble() * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = _snappedTarget(position, velocity, tolerance).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) {
      return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
