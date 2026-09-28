import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

Future<void> showCustomColorPickerDialog(
  BuildContext context, {
  required Color initialColor,
  required ValueChanged<Color> onColorSelected,
}) async {
  final selected = await showDialog<Color>(
    context: context,
    builder: (context) => _CustomColorPickerDialog(initialColor: initialColor),
  );
  if (selected != null) onColorSelected(selected);
}

class _CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const _CustomColorPickerDialog({required this.initialColor});

  @override
  State<_CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initialColor);
  late final TextEditingController _hexController = TextEditingController(text: _hexOf(widget.initialColor));
  final FocusNode _hexFocusNode = FocusNode();

  @override
  void dispose() {
    _hexController.dispose();
    _hexFocusNode.dispose();
    super.dispose();
  }

  String _hexOf(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _updateHsv(HSVColor next) {
    setState(() => _hsv = next);
    if (!_hexFocusNode.hasFocus) {
      _hexController.text = _hexOf(next.toColor());
    }
  }

  void _onHexChanged(String value) {
    var hex = value.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length != 6) return;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return;
    setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | parsed)));
  }

  void _onSaturationValuePan(Offset localPosition, Size size) {
    final saturation = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final value = 1.0 - (localPosition.dy / size.height).clamp(0.0, 1.0);
    _updateHsv(_hsv.withSaturation(saturation).withValue(value));
  }

  void _onHuePan(Offset localPosition, double width) {
    final hue = (localPosition.dx / width).clamp(0.0, 1.0) * 360.0;
    _updateHsv(_hsv.withHue(hue));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final color = _hsv.toColor();
    final pureHue = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();

    return AlertDialog(
      backgroundColor: palette.card.withValues(alpha: 1.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(AppLocalizations.of(context).customAccentTooltip, style: TextStyle(color: palette.textPrimary)),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, 160);
                  return GestureDetector(
                    onPanDown: (details) => _onSaturationValuePan(details.localPosition, size),
                    onPanUpdate: (details) => _onSaturationValuePan(details.localPosition, size),
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: Stack(
                        children: [
                          Container(color: pureHue),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.white, Color(0x00FFFFFF)]),
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00000000), Colors.black],
                              ),
                            ),
                          ),
                          Positioned(
                            left: _hsv.saturation * size.width - 7,
                            top: (1 - _hsv.value) * size.height - 7,
                            child: _PickerThumb(color: color),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  onPanDown: (details) => _onHuePan(details.localPosition, width),
                  onPanUpdate: (details) => _onHuePan(details.localPosition, width),
                  child: SizedBox(
                    height: 24,
                    width: width,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Color(0xFFFF0000),
                                Color(0xFFFFFF00),
                                Color(0xFF00FF00),
                                Color(0xFF00FFFF),
                                Color(0xFF0000FF),
                                Color(0xFFFF00FF),
                                Color(0xFFFF0000),
                              ]),
                            ),
                          ),
                        ),
                        Positioned(
                          left: (_hsv.hue / 360.0) * width - 7,
                          top: -3,
                          child: _PickerThumb(color: pureHue, size: 30),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.border),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    focusNode: _hexFocusNode,
                    onChanged: _onHexChanged,
                    style: TextStyle(color: palette.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: palette.inputBackground,
                      hintText: '#RRGGBB',
                      hintStyle: TextStyle(color: palette.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancelButton),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor:
                ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => Navigator.pop(context, color),
          child: Text(AppLocalizations.of(context).chooseButtonLabel),
        ),
      ],
    );
  }
}

class _PickerThumb extends StatelessWidget {
  final Color color;
  final double size;
  const _PickerThumb({required this.color, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
      ),
    );
  }
}
