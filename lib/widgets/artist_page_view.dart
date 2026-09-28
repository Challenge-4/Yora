import 'package:flutter/material.dart';
import '../services/charts_service.dart';
import '../services/yt_dlp_service.dart';
import '../state/artist_state.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'horizontal_card_row.dart';
import 'release_card.dart';

class ArtistPageView extends StatelessWidget {
  final ArtistState artistState;
  final Widget Function(YtSearchResult video, {bool large}) resultRowBuilder;
  final void Function(NewRelease release) onOpenRelease;
  final VoidCallback onCloseReleaseDetail;
  final VoidCallback onClose;

  const ArtistPageView({
    super.key,
    required this.artistState,
    required this.resultRowBuilder,
    required this.onOpenRelease,
    required this.onCloseReleaseDetail,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final openReleaseId = artistState.openReleasePlaylistId;
    if (openReleaseId != null) {
      return _buildReleaseDetail(context, openReleaseId);
    }
    return _buildArtistPage(context);
  }

  String _releaseTitle(String playlistId) {
    final page = artistState.artistPages[artistState.openArtistName];
    if (page == null) return '';
    for (final r in [...page.albums, ...page.singles]) {
      if (r.playlistId == playlistId) return r.title;
    }
    return '';
  }

  Widget _buildHeader(BuildContext context, {required String title, required VoidCallback onBack}) {
    final palette = AppTheme.paletteOf(context);
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
          mouseCursor: SystemMouseCursors.click,
          onPressed: onBack,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildReleaseDetail(BuildContext context, String playlistId) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final loading = artistState.releaseTracksLoading.contains(playlistId);
    final tracks = artistState.tracksByRelease[playlistId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, title: _releaseTitle(playlistId), onBack: onCloseReleaseDetail),
        const SizedBox(height: 12),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : tracks == null || tracks.isEmpty
                  ? Center(child: Text(l10n.noTracksForChartMessage, style: TextStyle(color: palette.textSecondary)))
                  : ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (context, index) => resultRowBuilder(tracks[index], large: true),
                    ),
        ),
      ],
    );
  }

  Widget _buildArtistPage(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final artistName = artistState.openArtistName ?? '';
    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 24, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, title: artistName, onBack: onClose),
            const SizedBox(height: 24),
            _buildArtistContent(context, artistName, l10n, palette),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistContent(BuildContext context, String artistName, AppLocalizations l10n, AppPalette palette) {
    if (artistState.artistLoading.contains(artistName)) {
      return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
    }
    if (artistState.artistNamesUnavailable.contains(artistName)) {
      return Text(l10n.artistNotFoundMessage, style: TextStyle(color: palette.textSecondary));
    }
    final page = artistState.artistPages[artistName];
    if (page == null) {
      return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
    }
    if (page.topSongs.isEmpty && page.albums.isEmpty && page.singles.isEmpty) {
      return Text(l10n.unavailableLabel, style: TextStyle(color: palette.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (page.topSongs.isNotEmpty) ...[
          Text(l10n.topSongsLabel, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: page.topSongs.length,
            itemBuilder: (context, index) => resultRowBuilder(page.topSongs[index]),
          ),
        ],
        if (page.albums.isNotEmpty) ...[
          const SizedBox(height: 40),
          Text(l10n.albumsLabel, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 16),
          HorizontalCardRow<NewRelease>(
            items: page.albums,
            cardBuilder: (release) => ReleaseCard(release: release, onTap: () => onOpenRelease(release)),
          ),
        ],
        if (page.singles.isNotEmpty) ...[
          const SizedBox(height: 40),
          Text(l10n.singlesAndEpsLabel, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 16),
          HorizontalCardRow<NewRelease>(
            items: page.singles,
            cardBuilder: (release) => ReleaseCard(release: release, onTap: () => onOpenRelease(release)),
          ),
        ],
      ],
    );
  }
}
