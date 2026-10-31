// Recently played: the third way to give Auto DJ its opening song, beside
// Random and Choose. A dropdown of the songs this phone played last on the
// DJ's server (util/auto_dj_recent.dart); picking one starts the DJ from it.
// Used by the first-song sheet (widgets/auto_dj_start_sheet.dart) and by the
// queue's empty-queue prompt (widgets/queue_list.dart).

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/play_event.dart';
import '../theme/velvet_theme.dart';

/// Wraps a trigger — [builder] gets the callback that opens the dropdown —
/// and drops the menu down from under it, as wide as the trigger (at least
/// [minMenuWidth]).
class RecentlyPlayedMenu extends StatefulWidget {
  const RecentlyPlayedMenu({
    super.key,
    required this.songs,
    required this.onPicked,
    required this.builder,
    this.openAtStart = false,
    this.minMenuWidth = 260,
  });

  /// Newest first; see recentlyPlayedOn.
  final List<TrackFacts> songs;
  final ValueChanged<TrackFacts> onPicked;
  final Widget Function(BuildContext context, VoidCallback open) builder;

  /// Open the dropdown as soon as the route showing it has finished coming
  /// in: First song is set to Recently played, so the song is what is asked.
  final bool openAtStart;
  final double minMenuWidth;

  @override
  State<RecentlyPlayedMenu> createState() => _RecentlyPlayedMenuState();
}

class _RecentlyPlayedMenuState extends State<RecentlyPlayedMenu> {
  bool _openedAtStart = false;
  bool _open = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.openAtStart || _openedAtStart || widget.songs.isEmpty) return;
    _openedAtStart = true;
    // The menu is placed from where the trigger is when it opens, so it
    // waits for a sheet's slide-in to finish.
    final animation = ModalRoute.of(context)?.animation;
    void openSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _show();
        });
    if (animation == null || animation.status == AnimationStatus.completed) {
      openSoon();
      return;
    }
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(listener);
      openSoon();
    };
    animation.addStatusListener(listener);
  }

  Future<void> _show() async {
    if (_open || widget.songs.isEmpty) return;
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset(0, box.size.height),
        ancestor: overlay);
    final width = box.size.width < widget.minMenuWidth
        ? widget.minMenuWidth
        : box.size.width;
    _open = true;
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
          Rect.fromLTWH(topLeft.dx, topLeft.dy, width, 0),
          Offset.zero & overlay.size),
      // Outlined, so the list reads as a layer over the sheet it opens on (a
      // shadow doesn't show on a dark sheet, and a lighter fill costs the
      // artist line its contrast); named for screen readers, who hear it open.
      color: VelvetColors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        side: BorderSide(color: VelvetColors.border2),
      ),
      semanticLabel: AppLocalizations.of(context).autoDjRecentlyPlayed,
      constraints: BoxConstraints(minWidth: width, maxWidth: width),
      items: [
        for (var i = 0; i < widget.songs.length; i++)
          PopupMenuItem<int>(
            key: ValueKey('auto-dj-recent-$i'),
            value: i,
            height: 56,
            child: _SongLabel(widget.songs[i]),
          ),
      ],
    );
    _open = false;
    if (picked != null && mounted) widget.onPicked(widget.songs[picked]);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _show);
}

/// A song in the dropdown: its title, and its artist under it.
class _SongLabel extends StatelessWidget {
  const _SongLabel(this.song);

  final TrackFacts song;

  @override
  Widget build(BuildContext context) {
    final title = song.title ?? song.path.split('/').last;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: VelvetColors.textPrimary)),
        if (song.artist case final artist? when artist.isNotEmpty)
          Text(artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 13, color: VelvetColors.textSecondary)),
      ],
    );
  }
}
