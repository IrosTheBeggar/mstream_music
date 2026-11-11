import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../theme/velvet_theme.dart';
import '../util/browse_keep_leads.dart' show KeepSubject;
import '../util/discover_badges.dart';
import '../util/discover_copy_gate.dart' show kVariousArtistsKey;
import '../util/plan_artist_albums.dart';
import 'browse_keep_pill.dart';

/// The headers a connected server's pages gain while browsing it, each the
/// first thing its list scrolls: Keep a copy of the artist's own albums on
/// the artist page, of the open folder below a library's root. The page's
/// own bar already names the artist or the folder, and its server — so a
/// header is the pill (the full width at large text) and nothing else, or
/// with the gate closed an earlier copy's state as plain text.

/// The artist page's header (a connected server's artist only) — when
/// [showsFor] says there is one.
class ArtistPageHeader extends StatelessWidget {
  final ArtistContext artist;

  /// The artist scope's gate is open (the page's snapshot).
  final bool open;

  /// The page marks' artist job (this server's, or another's running).
  final KeepChoiceJob? pick;
  final VoidCallback onKeep;
  final FocusNode? pillFocus;

  /// The header's own node: where focus lands when the pill is gone.
  final FocusNode? headerFocus;

  const ArtistPageHeader({
    super.key,
    required this.artist,
    required this.open,
    required this.pick,
    required this.onKeep,
    this.pillFocus,
    this.headerFocus,
  });

  /// The albums of [artist]'s own an artist copy takes ("theirs"): the
  /// copy's own rule, on the page's own answer.
  static int theirsOf(ArtistContext artist) =>
      planArtistAlbums(artist.albums, artist.name).plan.length;

  /// Whether the page has a header: an artist copy can be offered at all
  /// (not Various Artists, a server that names credits), and either the
  /// gate is open and the artist has albums of their own there, or an
  /// earlier copy of theirs has a state to show.
  static bool showsFor(
    AppLocalizations l,
    ArtistContext artist, {
    required bool open,
    required KeepChoiceJob? pick,
  }) {
    if (nameKey(artist.name) == kVariousArtistsKey || !artist.namesCredits) {
      return false;
    }
    return open ? theirsOf(artist) > 0 : KeepPageAction.shows(l, false, pick);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final form = KeepPillForm.of(l, pick);
    return _HeaderFrame(
      key: const ValueKey('browse-artist-header'),
      focusNode: headerFocus,
      fraction: open && form.live ? form.fraction : null,
      child: _PillSlot(
        builder: (fullWidth) => KeepPageAction(
          open: open,
          pick: pick,
          subject: KeepSubject.artist,
          name: artist.name,
          // What the copy takes, for a screen reader (the sheet shows it).
          hint: open ? l.browseKeepTakes(theirsOf(artist), artist.name) : null,
          fullWidth: fullWidth,
          onTap: onKeep,
          focusNode: pillFocus,
        ),
      ),
    );
  }
}

/// The open folder's header (a connected server's folder below its
/// library's root). With the gate closed the page shows it only for an
/// earlier (or running) copy of the folder — the caller asks
/// [KeepPageAction.shows] first.
class FolderPageHeader extends StatelessWidget {
  /// The folder's own name.
  final String name;
  final bool open;
  final KeepChoiceJob? pick;
  final VoidCallback onKeep;
  final FocusNode? pillFocus;
  final FocusNode? headerFocus;

  const FolderPageHeader({
    super.key,
    required this.name,
    required this.open,
    required this.pick,
    required this.onKeep,
    this.pillFocus,
    this.headerFocus,
  });

  @override
  Widget build(BuildContext context) {
    final form = KeepPillForm.of(AppLocalizations.of(context), pick);
    return _HeaderFrame(
      key: const ValueKey('browse-folder-header'),
      focusNode: headerFocus,
      fraction: open && form.live ? form.fraction : null,
      child: _PillSlot(
        builder: (fullWidth) => KeepPageAction(
          open: open,
          pick: pick,
          subject: KeepSubject.folder,
          name: name,
          fullWidth: fullWidth,
          onTap: onKeep,
          focusNode: pillFocus,
        ),
      ),
    );
  }
}

/// The pill's place: at its own width, or the full width above 1.3× text
/// or where the widest words a copy reads in would not fit — measured once,
/// so the pill never changes width between states.
class _PillSlot extends StatelessWidget {
  final Widget Function(bool fullWidth) builder;
  const _PillSlot({required this.builder});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ts = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) => builder(
        ts.scale(1) > 1.3 || KeepPagePill.ownWidth(l, ts) > box.maxWidth,
      ),
    );
  }
}

/// A header's box: its padding, the 1 pt rule under it, and the 3 pt bar
/// along that edge while its own copy copies; [focusNode] is the header's
/// own node.
class _HeaderFrame extends StatelessWidget {
  final FocusNode? focusNode;
  final double? fraction;
  final Widget child;
  const _HeaderFrame({
    super.key,
    required this.focusNode,
    required this.fraction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final f = fraction;
    return Focus(
      focusNode: focusNode,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: VelvetColors.border)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: child,
            ),
            if (f != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: KeepHeaderBar(fraction: f),
              ),
          ],
        ),
      ),
    );
  }
}
