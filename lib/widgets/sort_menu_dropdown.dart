import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sort_criterion_labels.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class SortMenuDropdown extends StatelessWidget {
  final LayerLink layerLink;
  final String? currentCriterion;
  final VoidCallback onDismiss;
  final void Function(String? criterion) onSelectCriterion;
  final VoidCallback onReset;

  const SortMenuDropdown({
    super.key,
    required this.layerLink,
    required this.currentCriterion,
    required this.onDismiss,
    required this.onSelectCriterion,
    required this.onReset,
  });

  Widget _option(BuildContext context, String? key, String label) {
    final palette = AppTheme.paletteOf(context);
    final isSelected = key == currentCriterion;
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      hoverColor: palette.textPrimary.withValues(alpha: 0.08),
      onTap: () => onSelectCriterion(key),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: palette.textPrimary)),
            if (isSelected) Icon(Icons.check, color: AppTheme.of(context).accent, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: Align(
            alignment: Alignment.topRight,
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.keyF &&
                    HardwareKeyboard.instance.isControlPressed) {
                  onDismiss();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
                ),
                child: Material(
                  color: Color.alphaBlend(AppTheme.paletteOf(context).cardHover, Colors.black),
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        mouseCursor: SystemMouseCursors.click,
                        hoverColor: palette.textPrimary.withValues(alpha: 0.08),
                        onTap: onReset,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(AppLocalizations.of(context).sortByMenuTitle, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                              Icon(Icons.restart_alt, color: palette.textSecondary, size: 18),
                            ],
                          ),
                        ),
                      ),
                      Divider(color: palette.border, height: 1),
                      _option(context, null, AppLocalizations.of(context).sortByCustomOption),
                      ...sortCriterionLabelsFor(AppLocalizations.of(context)).entries.map((e) => _option(context, e.key, e.value)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
