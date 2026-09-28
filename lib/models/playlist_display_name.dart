import '../l10n/generated/app_localizations.dart';

String playlistDisplayName(String key, AppLocalizations l10n) {
  if (key == 'Titres likés') return l10n.likedTracksPlaylistName;
  if (key == 'Fichiers locaux') return l10n.localFilesPlaylistName;
  return key;
}
