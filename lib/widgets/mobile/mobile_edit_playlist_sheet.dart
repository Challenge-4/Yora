import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/playlist_display_name.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/image_picker_util.dart';

Future<void> showMobileEditPlaylistSheet(
  BuildContext context, {
  required String playlistName,
  required String? initialImage,
  required String initialDescription,
  required bool autoPickImage,
  required bool Function(String newName) isNameTaken,
  required Future<void> Function(String newName, String? imagePath, String description) onSave,
  required Future<void> Function() onDelete,
  bool canDelete = true,
}) {
  final palette = AppTheme.paletteOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _MobileEditPlaylistSheet(
      playlistName: playlistName,
      initialImage: initialImage,
      initialDescription: initialDescription,
      autoPickImage: autoPickImage,
      isNameTaken: isNameTaken,
      onSave: onSave,
      onDelete: onDelete,
      canDelete: canDelete,
      surfaceColor: Color.alphaBlend(palette.cardHover, Colors.black),
    ),
  );
}

class _MobileEditPlaylistSheet extends StatefulWidget {
  final String playlistName;
  final String? initialImage;
  final String initialDescription;
  final bool autoPickImage;
  final bool Function(String newName) isNameTaken;
  final Future<void> Function(String newName, String? imagePath, String description) onSave;
  final Future<void> Function() onDelete;
  final bool canDelete;
  final Color surfaceColor;

  const _MobileEditPlaylistSheet({
    required this.playlistName,
    required this.initialImage,
    required this.initialDescription,
    required this.autoPickImage,
    required this.isNameTaken,
    required this.onSave,
    required this.onDelete,
    required this.canDelete,
    required this.surfaceColor,
  });

  @override
  State<_MobileEditPlaylistSheet> createState() => _MobileEditPlaylistSheetState();
}

class _MobileEditPlaylistSheetState extends State<_MobileEditPlaylistSheet> {
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

  Future<void> _handleSave() async {
    final l10n = AppLocalizations.of(context);
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    if (widget.isNameTaken(newName)) {
      setState(() => _errorText = l10n.playlistNameAlreadyTakenError);
      return;
    }
    await widget.onSave(newName, _tempImagePath, _descController.text);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: Material(
        color: widget.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancelButton, style: TextStyle(color: palette.textPrimary, fontSize: 15)),
                      ),
                      Expanded(
                        child: Text(
                          l10n.editInfoButtonLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: _handleSave,
                        child: Text(
                          l10n.saveChangesButton,
                          style: TextStyle(color: AppTheme.of(context).accent, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _photoPicker(palette),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
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
                            const SizedBox(height: 10),
                            TextField(
                              controller: _descController,
                              maxLines: 3,
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
                if (widget.canDelete) ...[
                  const SizedBox(height: 12),
                  Divider(color: palette.border, height: 1),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onDelete();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: palette.textPrimary, size: 22),
                          const SizedBox(width: 18),
                          Text(l10n.deletePlaylistButtonLabel, style: TextStyle(color: palette.textPrimary, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoPicker(AppPalette palette) {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 104,
              height: 104,
              child: _tempImagePath != null
                  ? Image.file(File(_tempImagePath!), fit: BoxFit.cover)
                  : Container(color: palette.card, child: Icon(Icons.music_note, color: palette.textSecondary, size: 36)),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: AppTheme.of(context).accent, shape: BoxShape.circle),
            child: Icon(Icons.edit, color: AppTheme.of(context).accentForeground, size: 14),
          ),
        ],
      ),
    );
  }
}
