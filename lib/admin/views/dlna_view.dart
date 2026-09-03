import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "DLNA" — UPnP/DLNA media-server advertising and browse layout.
class DlnaView extends StatelessWidget {
  final AdminApi api;
  const DlnaView({super.key, required this.api});

  static String _modeLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'same-port':
        return l.adminSamePortAsHttp;
      case 'separate-port':
        return l.adminSeparatePort;
      case 'disabled':
      default:
        return l.adminDlnaModeDisabled;
    }
  }

  static const _modeKeys = ['disabled', 'same-port', 'separate-port'];

  static String _browseLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'dirs':
        return l.adminDlnaBrowseDirectories;
      case 'artist':
        return l.adminDlnaBrowseArtist;
      case 'album':
        return l.adminDlnaBrowseAlbum;
      case 'genre':
        return l.adminDlnaBrowseGenre;
      case 'flat':
      default:
        return l.adminDlnaBrowseFlat;
    }
  }

  static const _browseKeys = ['flat', 'dirs', 'artist', 'album', 'genre'];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdminAsync(
      loader: api.getDlna,
      builder: (context, d, reload) {
        final mode = _modeKeys.contains(d['mode']) ? d['mode'] : 'disabled';
        final port = (d['port'] is num) ? (d['port'] as num).toInt() : 8200;
        return AdminViewBody(children: [
          AdminCard(
            title: l.adminDlnaServerTitle,
            icon: Icons.wifi_tethering,
            children: [
              AdminDropdownRow<String>(
                label: l.adminMode,
                value: mode,
                items: [
                  for (final k in _modeKeys)
                    DropdownMenuItem(value: k, child: Text(_modeLabel(l, k))),
                ],
                onChanged: (v) async {
                  await api.setDlnaMode(v, port: v == 'separate-port' ? port : null);
                  await reload();
                },
              ),
              if (mode == 'separate-port')
                AdminSaveField(
                  label: l.adminPort,
                  number: true,
                  initialValue: '$port',
                  onSave: (v) =>
                      api.setDlnaMode('separate-port', port: int.tryParse(v) ?? port),
                ),
            ],
          ),
          AdminCard(
            title: l.adminDlnaIdentityTitle,
            icon: Icons.badge_outlined,
            children: [
              AdminSaveField(
                label: l.adminDlnaFriendlyNameLabel,
                initialValue: '${d['name'] ?? ''}',
                onSave: api.setDlnaName,
              ),
              AdminSaveField(
                label: l.adminDlnaDeviceUuidLabel,
                helperText: l.adminDlnaDeviceUuidHelper,
                initialValue: '${d['uuid'] ?? ''}',
                onSave: api.setDlnaUuid,
              ),
            ],
          ),
          AdminCard(
            title: l.adminDlnaBrowseLayoutTitle,
            icon: Icons.account_tree_outlined,
            children: [
              AdminDropdownRow<String>(
                label: l.adminDlnaStructureLabel,
                value: _browseKeys.contains(d['browse']) ? d['browse'] : 'flat',
                items: [
                  for (final k in _browseKeys)
                    DropdownMenuItem(value: k, child: Text(_browseLabel(l, k))),
                ],
                onChanged: api.setDlnaBrowse,
              ),
            ],
          ),
        ]);
      },
    );
  }
}
