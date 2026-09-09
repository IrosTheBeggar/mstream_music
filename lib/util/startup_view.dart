import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/browser_list.dart';
import '../singletons/file_explorer.dart';
import '../singletons/settings.dart';

/// Loads [view]'s browser section for [server] — the same loader each home-grid
/// tile / sidebar category fires. Shared by launch (main._maybeOpenStartupView)
/// and desktop server-switching, so both land on the configured default page.
/// `browser` just returns to the nav home.
Future<void> loadStartupSection(StartupView view, Server server) async {
  switch (view) {
    case StartupView.browser:
      BrowserManager().goToNavScreen();
      break;
    case StartupView.fileExplorer:
      await ApiManager().getFileList('~', useThisServer: server);
      break;
    case StartupView.playlists:
      await ApiManager().getPlaylists(useThisServer: server);
      break;
    case StartupView.albums:
      await ApiManager().getAlbums(useThisServer: server);
      break;
    case StartupView.artists:
      await ApiManager().getArtists(useThisServer: server);
      break;
    case StartupView.rated:
      await ApiManager().getRated(useThisServer: server);
      break;
    case StartupView.recent:
      await ApiManager().getRecentlyAdded(useThisServer: server);
      break;
    case StartupView.localFiles:
      await FileExplorer().getPathForServer(server);
      break;
  }
}
