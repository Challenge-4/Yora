import 'package:flutter/material.dart';
import '../utils/image_picker_util.dart';
import '../widgets/modal_image_hover_widget.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/playlist_display_name.dart';

class EditPlaylistDialog extends StatefulWidget {
  final String playlistName;
  final String? initialImage;
  final String initialDescription;
  final bool autoPickImage;
  final bool Function(String newName) isNameTaken;
  final Future<void> Function(String newName, String? imagePath, String description) onSave;

  const EditPlaylistDialog({
    super.key,
    required this.playlistName,
    required this.initialImage,
    required this.initialDescription,
    required this.autoPickImage,
    required this.isNameTaken,
    required this.onSave,
  });

  @override
  State<EditPlaylistDialog> createState() => EditPlaylistDialogState();
}

class EditPlaylistDialogState extends State<EditPlaylistDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: playlistDisplayName(widget.playlistName, AppLocalizations.of(context)));
  late final TextEditingController _descController = TextEditingController(text: widget.initialDescription);
  String? _tempImagePath;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _tempImagePath = widget.initialImage;
    if (widget.autoPickImage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final path = await pickSingleImagePath();
    if (path != null) setState(() => _tempImagePath = path);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: palette.cardHover.withValues(alpha: 1.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.editPlaylistTitle, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
          IconButton(
            icon: Icon(Icons.close, color: palette.textSecondary),
            mouseCursor: SystemMouseCursors.click,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModalImageHoverWidget(
              tempImagePath: _tempImagePath,
              onPickImage: _pickImage,
              onRemoveImage: () {
                setState(() {
                  _tempImagePath = null;
                });
              },
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: palette.textPrimary),
                    onChanged: (_) {
                      if (_errorText != null) setState(() => _errorText = null);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: palette.border,
                      hintText: l10n.nameHint,
                      hintStyle: TextStyle(color: palette.textSecondary),
                      errorText: _errorText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descController,
                    maxLines: 4,
                    style: TextStyle(color: palette.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: palette.border,
                      hintText: l10n.playlistDescriptionHint,
                      hintStyle: TextStyle(color: palette.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.of(context).accent,
              foregroundColor: AppTheme.of(context).accentForeground,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () async {
              final newName = _nameController.text.trim();
              if (newName.isEmpty) return;

              if (widget.isNameTaken(newName)) {
                setState(() => _errorText = l10n.playlistNameAlreadyTakenError);
                return;
              }

              await widget.onSave(newName, _tempImagePath, _descController.text);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: Text(l10n.saveChangesButton, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
