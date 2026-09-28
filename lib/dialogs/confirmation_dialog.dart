import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  Color confirmColor = Colors.redAccent,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.paletteOf(context).card.withValues(alpha: 1.0),
      title: Text(title, style: TextStyle(color: AppTheme.paletteOf(context).textPrimary)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Text(content, style: TextStyle(color: AppTheme.paletteOf(context).textSecondary)),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.paletteOf(context).inputBackground,
            foregroundColor: AppTheme.paletteOf(context).textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context).cancelButton),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
