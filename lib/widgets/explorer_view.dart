import 'package:flutter/material.dart';
import '../services/charts_service.dart';
import '../services/yt_dlp_service.dart';
import '../state/charts_state.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'horizontal_card_row.dart';
import 'release_card.dart';

class ExplorerView extends StatelessWidget {
  final ChartsState chartsState;
  final Widget Function(YtSearchResult video, {bool large}) resultRowBuilder;
  final void Function(YtMusicGenre genre) onOpenGenre;
  final void Function(YtMusicCountryChart country) onOpenCountry;
  final void Function(NewRelease release) onOpenRelease;
  final VoidCallback onOpenAllNewReleases;
  final VoidCallback onCloseDetail;

  const ExplorerView({
    super.key,
    required this.chartsState,
    required this.resultRowBuilder,
    required this.onOpenGenre,
    required this.onOpenCountry,
    required this.onOpenRelease,
    required this.onOpenAllNewReleases,
    required this.onCloseDetail,
  });

  static const _genreImages = {
    'ggMPOg1uX0UzWGxlRE5jMDVk': 'assets/genres/african.jpg',
    'ggMPOg1uX3VOQWxsblVZTFNE': 'assets/genres/arabic.jpg',
    'ggMPOg1uX2NXUkgxdW0zUHJp': 'assets/genres/blues.jpg',
    'ggMPOg1uX0JrcUJGUHhxaTFV': 'assets/genres/bollywood_indian.jpg',
    'ggMPOg1uX1N4VmduTmdUR3dm': 'assets/genres/classical.jpg',
    'ggMPOg1uX1RXcFlyZEpRb1d3': 'assets/genres/country_americana.jpg',
    'ggMPOg1uX1NPTld3SDN3WGs4': 'assets/genres/dance_electronic.jpg',
    'ggMPOg1uX3pGYTJ3bFVha3Fu': 'assets/genres/decades.jpg',
    'ggMPOg1uXzMyY3J2SGM0bVh5': 'assets/genres/family.jpg',
    'ggMPOg1uXzBTRFBmQ3N4b0R6': 'assets/genres/folk_acoustic.jpg',
    'ggMPOg1uX25wZ25rYWJ0VldR': 'assets/genres/french_pop.jpg',
    'ggMPOg1uX3FVSEdOQWQxRU56': 'assets/genres/french_rap.jpg',
    'ggMPOg1uX1RKTlVlZVVNVVho': 'assets/genres/french_urban_pop.jpg',
    'ggMPOg1uX05RVU1pbTltSHd1': 'assets/genres/hiphop.jpg',
    'ggMPOg1uXzRPeVZhZGc1YXhS': 'assets/genres/indie_alternative.jpg',
    'ggMPOg1uXzAwSjVITDBZckJR': 'assets/genres/jpop.jpg',
    'ggMPOg1uX3lPcDFRaE9wM1BS': 'assets/genres/jazz.jpg',
    'ggMPOg1uX0JrbjBDOFFPSzJW': 'assets/genres/kpop.jpg',
    'ggMPOg1uX29wWTRjMHV1dWN5': 'assets/genres/latin.jpg',
    'ggMPOg1uXzdlSXhKZ0hMV1Z4': 'assets/genres/metal.jpg',
    'ggMPOg1uX3FRMkJJeFJtZk9z': 'assets/genres/pop.jpg',
    'ggMPOg1uX2JxQ2hxc2J5UFhR': 'assets/genres/rnb_soul.jpg',
    'ggMPOg1uX1JUc2lFcDFuUUth': 'assets/genres/reggae_caribbean.jpg',
    'ggMPOg1uXzJKTm5jUEZ5Uzlu': 'assets/genres/rock.jpg',
    'ggMPOg1uX2tWZXBsRm05cHNR': 'assets/genres/soundtracks_musicals.jpg',
  };

  @override
  Widget build(BuildContext context) {
    final openGenreParams = chartsState.openGenreParams;
    final openCountryName = chartsState.openCountryName;
    final openReleasePlaylistId = chartsState.openReleasePlaylistId;
    if (openGenreParams != null) {
      return _buildDetail(
        context,
        title: _genreName(openGenreParams),
        tracks: chartsState.tracksByGenre[openGenreParams],
        loading: chartsState.genreTracksLoading.contains(openGenreParams),
      );
    }
    if (openCountryName != null) {
      return _buildDetail(
        context,
        title: AppLocalizations.of(context).top100InCountryLabel(openCountryName),
        tracks: chartsState.tracksByCountry[openCountryName],
        loading: chartsState.countryTracksLoading.contains(openCountryName),
      );
    }
    if (openReleasePlaylistId != null) {
      return _buildDetail(
        context,
        title: _releaseTitle(openReleasePlaylistId),
        tracks: chartsState.tracksByRelease[openReleasePlaylistId],
        loading: chartsState.releaseTracksLoading.contains(openReleasePlaylistId),
        largeRows: true,
      );
    }
    if (chartsState.showingAllNewReleases) {
      return _buildAllNewReleasesPage(context);
    }
    return _buildBrowse(context);
  }

  String _genreName(String params) {
    for (final g in chartsState.genres ?? const <YtMusicGenre>[]) {
      if (g.params == params) return g.name;
    }
    return '';
  }

  String _releaseTitle(String playlistId) {
    for (final r in chartsState.newReleases ?? const <NewRelease>[]) {
      if (r.playlistId == playlistId) return '${r.title} · ${r.artist}';
    }
    return '';
  }

  Widget _buildBrowse(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 24, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(AppLocalizations.of(context).topByCountryTitle, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                _buildCountryPicker(context),
              ],
            ),
            const SizedBox(height: 56),
            Text(AppLocalizations.of(context).genresTitle, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 16),
            _buildGenreList(context),
            const SizedBox(height: 56),
            _buildNewReleasesTeaser(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryPicker(BuildContext context) {
    if (chartsState.countriesLoading && chartsState.countries == null) {
      return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    }
    final countries = chartsState.countries ?? const [];
    if (countries.isEmpty) {
      return Text(AppLocalizations.of(context).unavailableLabel, style: TextStyle(color: AppTheme.paletteOf(context).textSecondary, fontSize: 13));
    }
    final selected = chartsState.openCountryName;
    return Builder(
      builder: (buttonContext) => InkWell(
        borderRadius: BorderRadius.circular(20),
        mouseCursor: SystemMouseCursors.click,
        onTap: () => _showCountryPicker(buttonContext, countries, selected),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.paletteOf(buttonContext).card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selected ?? AppLocalizations.of(buttonContext).chooseCountryLabel, style: TextStyle(color: AppTheme.paletteOf(buttonContext).textPrimary, fontSize: 13)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_drop_down, color: AppTheme.paletteOf(buttonContext).textPrimary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCountryPicker(
    BuildContext context,
    List<YtMusicCountryChart> countries,
    String? selected,
  ) async {
    final button = context.findRenderObject() as RenderBox;
    final palette = AppTheme.paletteOf(context);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height + 4), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset(0, button.size.height + 4)), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final selectedCountry = await showMenu<YtMusicCountryChart>(
      context: context,
      position: position,
      color: palette.cardHover,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      constraints: const BoxConstraints(maxWidth: 260),
      items: [
        PopupMenuItem<YtMusicCountryChart>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(AppLocalizations.of(context).selectCountryLabel, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<YtMusicCountryChart>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 260,
            height: 300,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: countries.length,
              itemBuilder: (context, index) {
                final country = countries[index];
                final isSelected = country.countryName == selected;
                return InkWell(
                  onTap: () => Navigator.of(context).pop(country),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(country.countryName, style: TextStyle(color: palette.textPrimary, fontSize: 13)),
                        ),
                        if (isSelected) Icon(Icons.check, color: AppTheme.of(context).accent, size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
    if (selectedCountry != null) onOpenCountry(selectedCountry);
  }

  Widget _buildGenreList(BuildContext context) {
    if (chartsState.genresLoading && chartsState.genres == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final genres = chartsState.genres ?? const [];
    if (genres.isEmpty) {
      return Text(AppLocalizations.of(context).genresUnavailableMessage, style: TextStyle(color: AppTheme.paletteOf(context).textSecondary));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 170 / 96,
      ),
      itemCount: genres.length,
      itemBuilder: (context, index) => _buildGenreChip(context, genres[index]),
    );
  }

  Widget _buildGenreChip(BuildContext context, YtMusicGenre genre) {
    final imagePath = _genreImages[genre.params];
    final palette = AppTheme.paletteOf(context);
    return InkWell(
      onTap: () => onOpenGenre(genre),
      borderRadius: BorderRadius.circular(8),
      mouseCursor: SystemMouseCursors.click,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imagePath == null
                ? Container(color: palette.card)
                : Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: palette.card),
                  ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Text(
                genre.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewReleasesTeaser(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(AppLocalizations.of(context).newReleasesTitle, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            TextButton(
              onPressed: onOpenAllNewReleases,
              style: TextButton.styleFrom(
                foregroundColor: palette.textPrimary,
                backgroundColor: palette.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(AppLocalizations.of(context).moreButtonLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildNewReleasesTeaserRow(context),
      ],
    );
  }

  Widget _buildNewReleasesTeaserRow(BuildContext context) {
    if (chartsState.newReleasesLoading && chartsState.newReleases == null) {
      return const SizedBox(height: 176, child: Center(child: CircularProgressIndicator()));
    }
    final releases = chartsState.newReleases ?? const [];
    if (releases.isEmpty) {
      return Text(AppLocalizations.of(context).newReleasesUnavailableMessage, style: TextStyle(color: AppTheme.paletteOf(context).textSecondary));
    }
    return HorizontalCardRow<NewRelease>(
      items: releases,
      cardBuilder: (release) => ReleaseCard(release: release, onTap: () => onOpenRelease(release)),
    );
  }

  Widget _buildAllNewReleasesPage(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return SizedBox.expand(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: palette.textPrimary),
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: onCloseDetail,
                ),
                const SizedBox(width: 4),
                Text(AppLocalizations.of(context).newReleasesTitle, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          _buildNewReleasesSliverGrid(context),
        ],
      ),
    );
  }

  Widget _buildNewReleasesSliverGrid(BuildContext context) {
    if (chartsState.newReleasesLoading && chartsState.newReleases == null) {
      return const SliverToBoxAdapter(
        child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      );
    }
    final releases = chartsState.newReleases ?? const [];
    if (releases.isEmpty) {
      return SliverToBoxAdapter(
        child: Text(AppLocalizations.of(context).newReleasesUnavailableMessage, style: TextStyle(color: AppTheme.paletteOf(context).textSecondary)),
      );
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => ReleaseCard(release: releases[index], onTap: () => onOpenRelease(releases[index])),
        childCount: releases.length,
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context, {
    required String title,
    required List<YtSearchResult>? tracks,
    required bool loading,
    bool largeRows = false,
  }) {
    final palette = AppTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: palette.textPrimary),
              mouseCursor: SystemMouseCursors.click,
              onPressed: onCloseDetail,
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
        ),
        const SizedBox(height: 12),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : tracks == null || tracks.isEmpty
                  ? Center(child: Text(AppLocalizations.of(context).noTracksForChartMessage, style: TextStyle(color: palette.textSecondary)))
                  : ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (context, index) => resultRowBuilder(tracks[index], large: largeRows),
                    ),
        ),
      ],
    );
  }
}
