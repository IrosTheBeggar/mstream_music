import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery_plugins.dart';
import '../../theme/velvet_theme.dart';
import '../../util/browse_keep_leads.dart' show FolderRef;
import '../../util/discover_jobs.dart';
import 'destination_sheet.dart' show KeepLibraryChip;
import 'keep_copy_ui.dart';
import 'keep_folder_facts.dart';

/// Keep a copy's folder card (the phone spec's folder focus, entered from a
/// connected server's file explorer): "Where it lands" — as on that server,
/// into a folder the user picks for this copy only, or by the layout like
/// any other copy — and the bodies under it: the file list a folder's
/// preview shows, "Into a folder…"'s group (the libraries, where the files
/// go, the user's own folders to pick from, a new one to name), and the
/// line that replaces it all when the folder holds more songs than one copy
/// takes here.
///
/// What is chosen lives in a [KeepFolderChoice], kept by the Keep card: the
/// start sends its landing ([KeepFolderChoice.landingFor]). Nothing here is
/// made on disk — a folder named here is created by the first file.

/// The most folders "Into a folder…" lists before "Show all {n} folders".
const int kIntoFoldersInline = 8;

/// A line a path segment never breaks inside (the line breaks only between
/// the › separators — and anywhere in a segment too long for one line).
String _hold(String s) => s.replaceAll(' ', '\u00A0');

/// Large text (the spec's "above 1.3×"): what shares a row at 1.0 stacks.
bool _large(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) > 1.3;

/// What a folder card has chosen: its landing ([landing]) and, once "Into
/// a folder…" was chosen, the place there — the saved library and the
/// pressed folder's name at its root until the user goes elsewhere
/// ([folderIntoDefault], decision 2). A folder the user named here is known
/// not to exist ([named]: nothing to list, the first file creates it); a
/// listed folder whose name a layout would read as a variable is not gone
/// into ([braced]: the card says why).
class KeepFolderChoice extends ChangeNotifier {
  final FolderRef folder;
  KeepFolderChoice(this.folder);

  FolderLanding _landing = FolderLanding.mirror;
  ({String? vpath, String path})? _into;
  bool _named = false;
  String? _braced;
  bool _naming = false;
  String _typed = '';
  bool _showAll = false;

  FolderLanding get landing => _landing;

  /// "Into a folder…"'s place: the one chosen, else the first.
  ({String? vpath, String path}) into(CollectionDestination? destination) {
    final at = _into ?? folderIntoDefault(destination, folder.path);
    // A place with no library of its own is the saved one's.
    return at.vpath == null && destination != null
        ? (vpath: destination.vpath, path: at.path)
        : at;
  }

  /// The place was named here (New folder…), so it is not there yet.
  bool get named => _named;

  /// A name is being typed for a new folder ([typed]: what it reads now).
  bool get naming => _naming;
  String get typed => _typed;
  set typed(String v) {
    if (v == _typed) return;
    _typed = v;
    notifyListeners();
  }

  /// Every folder listed, past the first [kIntoFoldersInline].
  bool get showAll => _showAll;

  /// The landing a start sends (none for a mirror, `{vpath, path}`,
  /// `{tags: true}`).
  Map<String, dynamic>? landingFor(CollectionDestination? destination) {
    final at = into(destination);
    return folderLanding(_landing, vpath: at.vpath, path: at.path);
  }

  /// The folder whose name has a brace that the card says so of: one being
  /// typed ([typed]), one pressed in the list, else the chosen place's own
  /// (a pressed folder named "Tapes {2019}" names its first place so) —
  /// while it shows, both Adds wait. Null for none.
  String? braced(CollectionDestination? destination) {
    if (_landing != FolderLanding.folder) return null;
    if (_naming) return bracedFolder(sanitizeSegment(_typed));
    return _braced ?? bracedFolder(into(destination).path);
  }

  void choose(FolderLanding mode) {
    if (mode == _landing) return;
    _landing = mode;
    if (mode != FolderLanding.folder) _naming = false;
    notifyListeners();
  }

  /// A library chip: its root, a folder named as the pressed one there.
  void chooseLibrary(String vpath) {
    _into = (vpath: vpath, path: folderIntoDefault(null, folder.path).path);
    _named = false;
    _braced = null;
    _naming = false;
    _showAll = false;
    notifyListeners();
  }

  /// A listed folder: gone into and chosen by its name as listed (a real
  /// folder's name is a valid segment there, "AC:DC" too — made safe it
  /// would name a new one beside it) — unless its name has a brace.
  void goInto(String name, CollectionDestination? destination) {
    final seg = name.trim();
    if (seg.isEmpty) return;
    if (bracedFolder(seg) != null) {
      _braced = seg;
      notifyListeners();
      return;
    }
    final at = into(destination);
    _into = (
      vpath: at.vpath,
      path: [at.path, seg].where((s) => s.isNotEmpty).join('/'),
    );
    _named = false;
    _braced = null;
    _naming = false;
    _showAll = false;
    notifyListeners();
  }

  /// "Up to …": the folder above (the library's root at most).
  void up(CollectionDestination? destination) {
    final at = into(destination);
    final parts = pathCrumbs(at.path)..removeLast();
    _into = (vpath: at.vpath, path: parts.join('/'));
    _named = false;
    _braced = null;
    _naming = false;
    _showAll = false;
    notifyListeners();
  }

  /// New folder…: the field, [name] in it (the pressed folder's).
  void startNaming(String name) {
    _naming = true;
    _typed = name;
    _braced = null;
    notifyListeners();
  }

  void cancelNaming() {
    _naming = false;
    notifyListeners();
  }

  /// "Add" beside the name: the folder [name] under the chosen place,
  /// chosen. False (nothing chosen) for a name that is empty once made safe
  /// or has a brace.
  bool addNamed(String name, CollectionDestination? destination,
      {List<String> listed = const []}) {
    // A typed name is made safe; a listed one is gone into as it is.
    final seg = sanitizeSegment(name);
    if (seg.isEmpty || bracedFolder(seg) != null) return false;
    final known = listed.contains(seg);
    goInto(seg, destination);
    // One the list did not hold is not there yet.
    _named = !known;
    notifyListeners();
    return true;
  }

  void expand() {
    _showAll = true;
    notifyListeners();
  }
}

/// "Where it lands" and its three landings (the destination sheet's layout
/// rows): as on [peerName]'s server, into a folder, by the layout.
class KeepLandingGroup extends StatelessWidget {
  final FolderLanding chosen;
  final String peerName;
  final ValueChanged<FolderLanding> onChoose;
  const KeepLandingGroup({
    super.key,
    required this.chosen,
    required this.peerName,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = [
      (
        FolderLanding.mirror,
        l.discoverKeepLandingMirror(peerName),
        l.discoverKeepLandingMirrorSub,
      ),
      (
        FolderLanding.folder,
        l.discoverKeepLandingFolder,
        l.discoverKeepLandingFolderSub,
      ),
      (
        FolderLanding.tags,
        l.discoverKeepLandingTags,
        l.discoverKeepLandingTagsSub,
      ),
    ];
    return Column(
      key: const ValueKey('keep-landings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drawn only: the group's own node says it (once, before its
        // radios).
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: ExcludeSemantics(
            child: Text(
              l.discoverKeepLanding,
              style: TextStyle(
                color: keepQuiet(VelvetColors.textSecondary),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Semantics(
          container: true,
          label: l.discoverKeepLanding,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _LandingRow(
                    key: ValueKey('keep-landing-${r.$1.name}'),
                    label: r.$2,
                    sub: r.$3,
                    selected: r.$1 == chosen,
                    onTap: () => onChoose(r.$1),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One landing: a 20 px radio, its name over what it does; the chosen one
/// primary-dim with a 1.5 px edge, its ring and dot in the primary's text
/// colour ([keepInk]: Light's amber reads on white, raw it would not).
class _LandingRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _LandingRow({
    super.key,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      hint: sub,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? VelvetColors.primaryDim : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: VelvetColors.primaryDim,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? keepInk() : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? keepInk()
                          : VelvetColors.textSecondary,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: keepInk(),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: VelvetColors.textPrimary,
                          fontSize: 15,
                          height: 20 / 15,
                        ),
                      ),
                      Text(
                        sub,
                        style: TextStyle(
                          color: keepQuiet(VelvetColors.textSecondary),
                          fontSize: 13,
                          height: 18 / 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The first files of a folder's preview, one a line, where each lands
/// below the path drawn ("Harbour Lights/01 - Tide.mp3"), then "and 6 more
/// songs" — one node for a screen reader. [ground] is what it is drawn on
/// (the card, or the preview's raised box): its quiet greys read there.
class KeepFolderFileList extends StatelessWidget {
  final FolderFiles files;
  final Color? ground;
  const KeepFolderFileList(this.files, {super.key, this.ground});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (files.lines.isEmpty) return const SizedBox.shrink();
    final more = files.more > 0 ? l.discoverKeepMoreFiles(files.more) : null;
    return Semantics(
      container: true,
      label: l.discoverKeepFilesAria(
        files.lines.length + files.more,
        [...files.lines, ?more].join(', '),
      ),
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey('keep-folder-files'),
        padding: const EdgeInsets.only(left: 22, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in files.lines)
              Text(
                line,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: kMonoFallback,
                  fontSize: 11.5,
                  height: 16 / 11.5,
                  color: keepQuiet(VelvetColors.textSecondary, ground),
                ),
              ),
            if (more != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  more,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: keepQuiet(VelvetColors.textTertiary, ground),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A quiet line under a folder's path: its foot ("Its path inside
/// “music” on Stage Peer B"), "For this copy only…", the missing note — or,
/// with [icon], the straight-in line. [ground] is what it is drawn on (the
/// card, or the preview's raised box): its grey reads there.
class KeepFolderNote extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  final Color? ground;
  const KeepFolderNote(this.text,
      {super.key, this.icon, this.color, this.ground});

  @override
  Widget build(BuildContext context) {
    final c = color ?? keepQuiet(VelvetColors.textTertiary, ground);
    final words = Text(
      text,
      style: TextStyle(color: c, fontSize: 12, height: 16 / 12),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: icon == null
          ? words
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 6),
                  child: Icon(icon, size: 14, color: c),
                ),
                Expanded(child: words),
              ],
            ),
    );
  }
}

/// Over the cap: the one line a folder card holds when the folder has more
/// songs than one copy takes here ("…Keep its folders one at a time.").
class KeepFolderCapLine extends StatelessWidget {
  final String text;
  const KeepFolderCapLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('keep-folder-cap'),
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: keepTone(VelvetColors.warning),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: keepQuiet(VelvetColors.textSecondary, VelvetColors.raised),
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
        ),
      ],
    ),
  );
}

/// "Into a folder…": the libraries the account may add files to, where the
/// files go ([target], the card's own — what the start sends), the chosen
/// folder's folders on the user's own server ([lister]: one folder at a
/// time; Up, each folder going in, "Show all", New folder…), and that
/// nothing is saved to the account. A folder name with a brace says why it
/// cannot be used, and the sheet's Add waits ([KeepFolderChoice.braced]).
class KeepIntoFolder extends StatefulWidget {
  final KeepFolderChoice choice;
  final DestinationView? destination;
  final OwnFolderLister lister;
  final ScopeTarget? target;

  const KeepIntoFolder({
    super.key,
    required this.choice,
    required this.destination,
    required this.lister,
    required this.target,
  });

  @override
  State<KeepIntoFolder> createState() => _KeepIntoFolderState();
}

class _KeepIntoFolderState extends State<KeepIntoFolder> {
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _newFolder = FocusNode();

  KeepFolderChoice get choice => widget.choice;
  CollectionDestination? get _place => widget.destination?.destination;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onTyping);
  }

  @override
  void dispose() {
    _name.removeListener(_onTyping);
    _name.dispose();
    _nameFocus.dispose();
    _newFolder.dispose();
    super.dispose();
  }

  /// The name typed is the choice's: the card's Add follows its brace.
  void _onTyping() {
    if (choice.naming) choice.typed = _name.text;
  }

  /// "New folder…": the field, the pressed folder's name in it, all of it
  /// selected.
  void _startNaming() {
    final name = choice.folder.name;
    choice.startNaming(name);
    _name.value = TextEditingValue(
      text: name,
      selection: TextSelection(baseOffset: 0, extentOffset: name.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && choice.naming) _nameFocus.requestFocus();
    });
  }

  void _cancelNaming() {
    choice.cancelNaming();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _newFolder.requestFocus();
    });
  }

  void _add(List<String> listed) {
    choice.addNamed(_name.text, _place, listed: listed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final view = widget.destination;
    final at = choice.into(_place);
    final vpath = at.vpath ?? '';
    final libs = [
      for (final w in view?.libraries ?? const <WritableLibrary>[]) w.vpath,
      if (vpath.isNotEmpty &&
          !(view?.libraries ?? const <WritableLibrary>[])
              .any((w) => w.vpath == vpath))
        vpath,
    ];
    final crumbs = pathCrumbs(at.path);
    final here = crumbs.isEmpty ? vpath : crumbs.last;
    final listing = choice.named || vpath.isEmpty
        ? const OwnFolders([], missing: true)
        : widget.lister.folders(vpath, at.path);
    final braced = choice.braced(_place);
    final large = _large(context);
    final group = <Widget>[
      // Drawn only: the chips' group says it.
      _GroupLabel(l.discoverDestLibrary, said: false),
      Semantics(
        container: true,
        label: l.discoverDestLibrary,
        explicitChildNodes: true,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final lib in libs)
              KeepLibraryChip(
                key: ValueKey('keep-into-library-$lib'),
                name: lib,
                selected: lib == vpath,
                onTap: () => choice.chooseLibrary(lib),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _preview(l, listing),
      const SizedBox(height: 12),
      _GroupLabel(l.discoverKeepFoldersIn(here)),
      if (crumbs.isNotEmpty)
        _FolderRow(
          key: const ValueKey('keep-into-up'),
          icon: Icons.arrow_upward,
          label: l.discoverKeepUpTo(
            crumbs.length == 1 ? vpath : crumbs[crumbs.length - 2],
          ),
          onTap: () => choice.up(_place),
        ),
      ..._folders(l, listing),
      if (choice.naming)
        _naming(l, listing?.names ?? const [], braced, large)
      else
        _FolderRow(
          key: const ValueKey('keep-into-new'),
          focusNode: _newFolder,
          icon: Icons.create_new_folder_outlined,
          label: l.discoverKeepNewFolder,
          ink: true,
          onTap: _startNaming,
        ),
      // Said as it appears: the Adds wait on it, and a screen reader
      // typing the name hears why.
      if (braced != null)
        Semantics(
          liveRegion: true,
          container: true,
          child: KeepFolderNote(
            l.discoverKeepFolderBraces(braced),
            key: const ValueKey('keep-into-braces'),
            icon: Icons.warning_amber_rounded,
            color: keepTone(VelvetColors.error),
          ),
        ),
      KeepFolderNote(l.discoverKeepLandingThisCopyOnly),
    ];
    return Container(
      key: const ValueKey('keep-into'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VelvetColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: group,
      ),
    );
  }

  /// Where the files go, the first of them, and what the place is: not
  /// there yet (the first file creates it) — never the library itself —
  /// and, when it is not named as the pressed folder, that its files go
  /// straight in.
  Widget _preview(AppLocalizations l, OwnFolders? listing) {
    final t = widget.target;
    final at = choice.into(_place);
    final soft = TextStyle(
      color: keepQuiet(VelvetColors.textSecondary, VelvetColors.raised),
      fontSize: 13,
      height: 1.4,
    );
    final strong = soft.copyWith(
      color: VelvetColors.textPrimary,
      fontWeight: FontWeight.w500,
    );
    final crumbs = t != null && t.valid
        ? t.crumbs
        : [?at.vpath, ...pathCrumbs(at.path)];
    final spans = <InlineSpan>[
      TextSpan(text: '${l.discoverKeepFilesGoTo} ', style: soft),
      for (var i = 0; i < crumbs.length; i++) ...[
        if (i > 0) TextSpan(text: ' › ', style: soft),
        ...keepCrumbSpans(l, crumbs[i], style: strong, hold: _hold),
      ],
    ];
    final files = t?.files;
    final missing =
        at.path.isNotEmpty && listing != null && listing.missing;
    final straight = t?.straightIn;
    return Container(
      key: const ValueKey('keep-into-preview'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: spans),
              key: const ValueKey('keep-into-path'),
            ),
            if (files != null)
              KeepFolderFileList(files, ground: VelvetColors.raised),
            if (missing)
              KeepFolderNote(
                l.discoverKeepFolderWillCreate,
                key: const ValueKey('keep-into-missing'),
                ground: VelvetColors.raised,
              ),
            if (straight != null)
              KeepFolderNote(
                l.discoverKeepLandingStraightIn(straight.folder, straight.name),
                key: const ValueKey('keep-into-straight'),
                icon: Icons.info_outline,
                ground: VelvetColors.raised,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _folders(AppLocalizations l, OwnFolders? listing) {
    if (listing == null) {
      return [
        Padding(
          key: const ValueKey('keep-into-looking'),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            l.discoverKeepLookingUp,
            style: TextStyle(
                color: keepQuiet(VelvetColors.textSecondary), fontSize: 13),
          ),
        ),
      ];
    }
    final names = listing.names;
    if (names.isEmpty) {
      return [
        Padding(
          key: const ValueKey('keep-into-none'),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            l.storageNoSubfolders,
            style: TextStyle(
                color: keepQuiet(VelvetColors.textSecondary), fontSize: 13),
          ),
        ),
      ];
    }
    // No nested scroll: the first 8, then the rest in place when asked.
    final shown = choice.showAll || names.length <= kIntoFoldersInline
        ? names
        : names.take(kIntoFoldersInline).toList();
    return [
      for (final n in shown)
        _FolderRow(
          key: ValueKey('keep-into-folder-$n'),
          icon: Icons.folder,
          label: n,
          onTap: () => choice.goInto(n, _place),
        ),
      if (shown.length < names.length)
        _FolderRow(
          key: const ValueKey('keep-into-show-all'),
          icon: Icons.expand_more,
          label: l.discoverKeepShowAllFolders(names.length),
          ink: true,
          onTap: choice.expand,
        ),
    ];
  }

  /// New folder… as a name being typed: the field — 48 px at least, as
  /// tall as its text at large text — Add, and ✕ (on one row; stacked at
  /// large text).
  Widget _naming(
    AppLocalizations l,
    List<String> listed,
    String? braced,
    bool large,
  ) {
    final empty = sanitizeSegment(_name.text).isEmpty;
    final ok = !empty && braced == null;
    // The floating label straddles the outline's top edge: room above for
    // its upper half (its 14 px at 75 %, at the text's scale), so it never
    // runs into the row above.
    final overhang = MediaQuery.textScalerOf(context).scale(14) * 0.75 / 2;
    final field = Padding(
      key: const ValueKey('keep-into-name-box'),
      padding: EdgeInsets.only(top: overhang),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: TextField(
          key: const ValueKey('keep-into-name'),
          controller: _name,
          focusNode: _nameFocus,
          maxLength: 200,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (ok) _add(listed);
          },
          style: TextStyle(color: VelvetColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            labelText: l.storageFolderNameHint,
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: VelvetColors.raised,
            labelStyle: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: VelvetColors.border2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: VelvetColors.border2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: VelvetColors.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
    final add = Opacity(
      opacity: ok ? 1 : 0.45,
      child: KeepPill(
        l.add,
        key: const ValueKey('keep-into-add'),
        onTap: ok ? () => _add(listed) : null,
      ),
    );
    final cancel = Semantics(
      button: true,
      label: l.cancel,
      excludeSemantics: true,
      child: InkResponse(
        key: const ValueKey('keep-into-cancel'),
        onTap: _cancelNaming,
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.close, size: 20, color: VelvetColors.textSecondary),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 6),
                Row(children: [add, const Spacer(), cancel]),
              ],
            )
          : Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: 8),
                add,
                cancel,
              ],
            ),
    );
  }
}

/// A group's own small label (11/700 caps, tertiary) — inside the bordered
/// group, where KeepSheetLabel's sheet margins do not belong. [said] false
/// draws it only: a group's own node already says it.
class _GroupLabel extends StatelessWidget {
  final String text;
  final bool said;
  const _GroupLabel(this.text, {this.said = true});

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(
        color: keepQuiet(VelvetColors.textTertiary),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: said ? label : ExcludeSemantics(child: label),
    );
  }
}

/// One row of "Into a folder…"'s list: a 20 px glyph and the name, 52 px at
/// least; [ink] draws it in the primary's text colour (New folder…, Show
/// all).
class _FolderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ink;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  const _FolderRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.ink = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final c = ink ? keepInk() : VelvetColors.textPrimary;
    // One node: its name here, its tap and focus the InkWell's (focus
    // coming back to New folder… is the node a screen reader is on).
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: InkWell(
        focusNode: focusNode,
        onTap: onTap,
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: ink ? c : keepTone(VelvetColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: c, fontSize: 15, height: 20 / 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
