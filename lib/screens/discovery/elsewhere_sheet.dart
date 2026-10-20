import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discovery_plugins_api.dart';
import 'discovery_jobs_controller.dart';
import 'keep_copy_ui.dart';
import 'keep_toast.dart';

/// "Open elsewhere" on a connected server's song sheet (the design canvas's
/// PhoneElsewhere board): a sub-sheet over the song sheet that asks the
/// links plug-in only when tapped — the exact MusicBrainz pages the song
/// carries ids for first, then the catalogue searches — every row opening
/// outside the app with the app's URL launcher. Loading keeps the list's
/// geometry; an empty answer says why; a failure shows the server's words
/// with Try again; a link the phone cannot open leaves the sheet up and
/// says so in a toast.

/// How a link leaves the app (tests answer it themselves). True when the
/// phone took it.
typedef ElsewhereLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchOutside(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The launcher the sub-sheet uses; tests swap it.
ElsewhereLauncher elsewhereLaunch = _launchOutside;

Future<void> showElsewhereSheet(
  BuildContext context,
  DiscoveryJobsController jobs,
  DiscoveryLead lead,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: VelvetColors.surface,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.of(context).size.height * 0.89,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (_) => ElsewhereSheet(jobs: jobs, lead: lead),
);

/// A link's row label: the exact pages in the user's language, the
/// catalogues by their own names, anything else as the plug-in labels it.
String elsewhereLabel(AppLocalizations l, PluginLink link) => switch (link.id) {
  'musicbrainz-recording' => l.discoverElsewhereMbRecording,
  'musicbrainz-release-group' => l.discoverElsewhereMbReleaseGroup,
  'musicbrainz-isrc' => l.discoverElsewhereMbIsrc,
  'musicbrainz-search' => 'MusicBrainz',
  'deezer-search' => 'Deezer',
  'apple-music-search' => 'Apple Music',
  'youtube-search' => 'YouTube',
  'bandcamp-search' => 'Bandcamp',
  'discogs-search' => 'Discogs',
  _ => link.label,
};

class ElsewhereSheet extends StatefulWidget {
  final DiscoveryJobsController jobs;
  final DiscoveryLead lead;
  const ElsewhereSheet({super.key, required this.jobs, required this.lead});

  @override
  State<ElsewhereSheet> createState() => _ElsewhereSheetState();
}

class _ElsewhereSheetState extends State<ElsewhereSheet> {
  List<PluginLink>? _links;
  bool _loading = true;
  String? _error;
  bool _failed = false;
  int _rid = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final rid = ++_rid;
    setState(() {
      _loading = true;
      _failed = false;
      _error = null;
    });
    try {
      // The row exactly as received.
      final links = await widget.jobs.links(widget.lead.raw);
      if (!mounted || rid != _rid) return;
      setState(() {
        _links = links;
        _loading = false;
      });
    } on DiscoveryPluginsException catch (e) {
      if (!mounted || rid != _rid) return;
      setState(() {
        _loading = false;
        _failed = true;
        _error = e.fromServer ? e.message : null;
      });
    }
  }

  Future<void> _open(PluginLink link) async {
    final l = AppLocalizations.of(context);
    var ok = false;
    try {
      final uri = Uri.parse(link.url);
      ok = await elsewhereLaunch(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) KeepToast.show(context, l.discoverToastLinkFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lead = widget.lead;
    final sub = [
      if (lead.title.trim().isNotEmpty) lead.title.trim(),
      if (lead.artist.trim().isNotEmpty) lead.artist.trim(),
    ].join(' · ');
    final Widget body;
    if (_loading) {
      body = Semantics(
        key: const ValueKey('elsewhere-loading'),
        label: l.discoverElsewhereLoading,
        container: true,
        child: const _ListSkeleton(),
      );
    } else if (_failed) {
      body = _Note(
        key: const ValueKey('elsewhere-failed'),
        icon: Icons.error_outline,
        iconColor: keepTone(VelvetColors.error),
        title: l.discoverElsewhereFailed,
        sub: _error,
        pill: KeepPill(
          l.discoverPageRetry,
          key: const ValueKey('elsewhere-try-again'),
          icon: Icons.refresh,
          onTap: () => unawaited(_load()),
        ),
      );
    } else if ((_links ?? const []).isEmpty) {
      body = _Note(
        key: const ValueKey('elsewhere-empty'),
        icon: Icons.link_off,
        iconColor: VelvetColors.textSecondary,
        title: l.discoverElsewhereEmpty,
        sub: l.discoverElsewhereEmptySub,
        pill: KeepPill(
          l.close,
          key: const ValueKey('elsewhere-close-empty'),
          onTap: () => Navigator.of(context).pop(),
        ),
      );
    } else {
      final links = _links!;
      final exact = links.where((k) => k.canonical).toList();
      final search = links.where((k) => !k.canonical).toList();
      body = SingleChildScrollView(
        key: const ValueKey('elsewhere-list'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exact.isNotEmpty) ...[
              KeepSheetLabel(l.discoverElsewhereExact),
              for (final k in exact) _row(l, k),
            ],
            if (search.isNotEmpty) ...[
              KeepSheetLabel(l.discoverElsewhereSearch),
              for (final k in search) _row(l, k),
            ],
          ],
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 12,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VelvetColors.border2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l.discoverSheetOpenElsewhere,
                            style: TextStyle(
                              color: VelvetColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 22 / 16,
                            ),
                          ),
                        ),
                        if (sub.isNotEmpty)
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: VelvetColors.textSecondary,
                              fontSize: 13,
                              height: 18 / 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('elsewhere-close'),
                    tooltip: l.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: VelvetColors.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: VelvetColors.border),
            Flexible(child: body),
          ],
        ),
      ),
    );
  }

  Widget _row(AppLocalizations l, PluginLink link) {
    final label = elsewhereLabel(l, link);
    return Semantics(
      link: true,
      button: true,
      label: label,
      hint: l.discoverElsewhereOpensOutside,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('elsewhere-link-${link.id}'),
        onTap: () => unawaited(_open(link)),
        splashColor: VelvetColors.primaryDim,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(
                  link.canonical ? Icons.link : Icons.search,
                  size: 20,
                  color: VelvetColors.textSecondary,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 15,
                      height: 20 / 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: VelvetColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? sub;
  final Widget pill;
  const _Note({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.sub,
    required this.pill,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: iconColor),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 21 / 15,
            ),
          ),
          if (sub != null && sub!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              sub!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 13,
                height: 18 / 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          pill,
        ],
      ),
    ),
  );
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(h / 2),
    ),
  );

  Widget _row(double w) => SizedBox(
    height: 52,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _bar(20, 20),
          const SizedBox(width: 20),
          Flexible(child: _bar(w, 12)),
        ],
      ),
    ),
  );

  Widget _cap(double w) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
    child: Align(alignment: Alignment.centerLeft, child: _bar(w, 10)),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _cap(84),
        for (final w in const [150.0, 196.0, 128.0]) _row(w),
        _cap(56),
        for (final w in const [104.0, 72.0, 118.0, 96.0, 88.0, 82.0]) _row(w),
      ],
    ),
  );
}
