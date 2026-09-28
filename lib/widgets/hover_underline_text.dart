import 'package:flutter/material.dart';
import '../utils/artist_names.dart';

class HoverUnderlineText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final void Function(String artistName) onTap;

  const HoverUnderlineText({
    super.key,
    required this.text,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final names = splitArtistNames(text);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < names.length; i++) ...[
          if (i > 0) Text(', ', style: style),
          Flexible(child: _HoverableArtistName(name: names[i], style: style, onTap: onTap)),
        ],
      ],
    );
  }
}

class _HoverableArtistName extends StatefulWidget {
  final String name;
  final TextStyle style;
  final void Function(String artistName) onTap;

  const _HoverableArtistName({required this.name, required this.style, required this.onTap});

  @override
  State<_HoverableArtistName> createState() => _HoverableArtistNameState();
}

class _HoverableArtistNameState extends State<_HoverableArtistName> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.name),
        child: Text(
          widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style.copyWith(decoration: _hovered ? TextDecoration.underline : TextDecoration.none),
        ),
      ),
    );
  }
}
