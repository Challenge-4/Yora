import 'dart:math';
import 'package:flutter/material.dart';

class MobileSwipeDownDismiss extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismissed;

  const MobileSwipeDownDismiss({super.key, required this.child, required this.onDismissed});

  @override
  State<MobileSwipeDownDismiss> createState() => MobileSwipeDownDismissState();
}

class MobileSwipeDownDismissState extends State<MobileSwipeDownDismiss> with SingleTickerProviderStateMixin {
  late final AnimationController _offset = AnimationController.unbounded(vsync: this);
  bool _dismissing = false;

  double get _height => context.size?.height ?? MediaQuery.sizeOf(context).height;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Future<void> dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    await _offset.animateTo(_height, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    if (mounted) widget.onDismissed();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    _offset.value = max(0.0, _offset.value + details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dismissing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_offset.value > _height * 0.25 || velocity > 700) {
      dismiss();
    } else {
      _offset.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) => Transform.translate(offset: Offset(0, _offset.value), child: child),
        child: widget.child,
      ),
    );
  }
}
