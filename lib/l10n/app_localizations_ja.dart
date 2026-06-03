// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => '言語';

  @override
  String get languageSystemDefault => 'システムのデフォルト';

  @override
  String get settingsLanguageSubtitle =>
      'アプリの表示言語です。「システムのデフォルト」を選ぶと端末の設定に従います。';

  @override
  String couldNotOpen(String url) {
    return '$url を開けませんでした';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 曲',
      zero: 'トラックなし',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'リセット';

  @override
  String get themeVelvet => 'ベルベット';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themeLight => 'ライト';

  @override
  String get tapAddToQueue => 'キューに追加';

  @override
  String get tapPlayFromHere => 'ここから再生';

  @override
  String get tapAppendAndJump => '追加して再生';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'シェーダー';

  @override
  String get visualizerSourceSynthesized => 'シンセサイズ';

  @override
  String get visualizerSourceReal => '実音声';

  @override
  String get downloadsTitle => 'ダウンロード';

  @override
  String downloadProgress(String progress) {
    return '進捗: $progress%';
  }

  @override
  String get songInfoTitle => '曲の情報';

  @override
  String get eqTitle => 'イコライザー';

  @override
  String get eqOnlyAndroid => 'イコライザーは Android でのみ利用できます。';

  @override
  String get eqNeedsPlayback =>
      '曲を再生してからイコライザーを設定してください。\n\nAndroid のネイティブイコライザーはオーディオセッションとともに初期化されるため、バンド構成を読み取るには再生が有効になっている必要があります。';

  @override
  String eqInitFailed(String error) {
    return 'イコライザーを初期化できませんでした:\n$error';
  }

  @override
  String get eqNoBands => 'この端末のオーディオドライバーは EQ バンドを報告していません。';

  @override
  String get eqEnabledOn => 'オン — ゲインを再生に適用中';

  @override
  String get eqEnabledOff => 'オフ — バイパスモード';

  @override
  String get cancel => 'キャンセル';

  @override
  String get continueLabel => '続行';

  @override
  String get openSettings => '設定を開く';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionAppearance => '外観';

  @override
  String get settingsSectionPlayback => '再生';

  @override
  String get settingsSectionBrowse => 'ブラウズ';

  @override
  String get settingsSectionAbout => '情報';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get themeSubtitleVelvet => 'ネイビーとパープル — 定番のダークテーマです。';

  @override
  String get themeSubtitleDark => 'アンバーのアクセントを添えたニュートラルなダークです。';

  @override
  String get themeSubtitleLight =>
      '明るい本体にダークなアプリバーとアンバーのアクセント — 以前のテーマに合わせています。';

  @override
  String get settingsTranscode => '音声をトランスコード';

  @override
  String get settingsTranscodeSubtitle =>
      'サーバーからトランスコードしたコピーをストリーミングします（ファイルが小さくなり、開始がやや遅くなります）。オフのときは元のファイルを再生します。';

  @override
  String get settingsTapBehavior => '曲をタップしたとき';

  @override
  String get tapSubtitleAddToQueue =>
      '曲をタップするとキューに追加されます。キューが空の場合は自動的に再生が始まります。';

  @override
  String get tapSubtitlePlayFromHere =>
      '曲をタップすると、現在のビューにある曲でキューを置き換え、タップした曲から再生を開始します。';

  @override
  String get tapSubtitleAppendAndJump =>
      '曲をタップするとキューに追加し、再生中の曲を中断してその曲へ再生を移します。';

  @override
  String get settingsEqSubtitle => '低音・中音・高音を調整します。Android のみ。';

  @override
  String get settingsVisualizerEngine => 'ビジュアライザーエンジン';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'projectM による Milkdrop プリセット（デフォルト）。効果が豊かで、GPU への負荷が高めです。';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Shadertoy スタイルのフラグメントシェーダー。軽量でモジュール式 — assets/shaders/ に .glsl ファイルを置くとカタログを拡張できます。';

  @override
  String get settingsVisualizerSource => 'ビジュアライザーの音声ソース';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'デフォルト。ビジュアライザーは再生タイミングのみに反応します — マイクの権限は不要です。';

  @override
  String get visualizerSourceSubtitleReal =>
      'ビジュアライザーが実際の音声出力に反応します。Android では RECORD_AUDIO 権限が必要です。';

  @override
  String get settingsAlbumGrid => 'アルバムのグリッド表示';

  @override
  String get settingsAlbumGridSubtitle =>
      'アルバムを単純なリストではなく、ジャケット付きのカードのグリッドで表示します。';

  @override
  String get settingsFileMetadata => 'ファイルエクスプローラーで曲のメタデータを読み取る';

  @override
  String get settingsFileMetadataSubtitle =>
      'サーバーのファイルを閲覧する際、各曲のタイトル・アーティスト・ジャケットを取得します。オフのときは生のファイル名を表示します（大きなフォルダでは高速）。';

  @override
  String get settingsLetterStrip => '頭文字スクラバーのしきい値';

  @override
  String get settingsLetterStripSubtitle =>
      'リストの項目数がこの値以上のとき、A〜Z のクイックスクラブ用ストリップを表示します。これより少ない場合はストリップを隠し、長いフォルダ名やファイル名を省略せず複数行に折り返します。0 に設定すると常にストリップを表示します。';

  @override
  String get settingsReset => 'デフォルトにリセット';

  @override
  String get settingsResetSubtitle =>
      'この画面のすべての設定をデフォルト値に戻します。サーバーとダウンロードには影響しません。';

  @override
  String get settingsResetDone => '設定をデフォルトに戻しました';

  @override
  String get realAudioDialogTitle => '実音声を使用しますか？';

  @override
  String get realAudioDialogBody =>
      '実音声モードでは、ビジュアライザーが反応できるよう、スマートフォンが再生中の音楽の波形を読み取ります。Android ではこのために RECORD_AUDIO 権限が必要です — アプリが音声を録音したり、どこかに送信したりすることはありません。いつでもシンセサイズ音声に戻せます。';

  @override
  String get realAudioPermPermanentlyDenied =>
      '権限が完全に拒否されました。実音声を使用するにはシステム設定で有効にしてください。';

  @override
  String get realAudioPermDenied => '権限が拒否されました。シンセサイズ音声のままにします。';

  @override
  String get visualizerTapHint => 'タップ = 次のプリセット · 左上の戻る矢印または長押しで終了';

  @override
  String get visualizerFailed => 'ビジュアライザーを開始できませんでした';

  @override
  String get visualizerBringingUp => 'レンダラーを起動中…';

  @override
  String get visualizerReady => 'ビジュアライザーの準備ができました';

  @override
  String get visualizerBridgeFailed => 'ブリッジを開始できませんでした';

  @override
  String visualizerAudioSourceLine(String source) {
    return '音声ソース: $source';
  }

  @override
  String get visualizerTapToClose => 'どこかをタップして閉じる';

  @override
  String get visualizerUnsupported => 'ビジュアライザーは現在 Android でのみ対応しています。';

  @override
  String get aboutTitle => '情報';

  @override
  String aboutBuiltBy(String name) {
    return '$name 制作';
  }

  @override
  String get linkDiscordSubtitle => 'コミュニティチャット';

  @override
  String get linkGithubSubtitle => 'mStream サーバーのソース';

  @override
  String get linkHomepageSubtitle => 'プロジェクトのホームページ';

  @override
  String get aboutAttributions => 'クレジット';

  @override
  String get aboutAttributionsSubtitle => 'ライセンス、シェーダーのクレジット、オープンソースのお知らせ。';

  @override
  String get ok => 'OK';

  @override
  String get delete => '削除';

  @override
  String get edit => '編集';

  @override
  String get info => '情報';

  @override
  String get makeDefault => 'デフォルトに設定';

  @override
  String get goBack => '戻る';

  @override
  String get play => '再生';

  @override
  String get playAll => 'すべて再生';

  @override
  String get rename => '名前を変更';

  @override
  String get create => '作成';

  @override
  String get copy => 'コピー';

  @override
  String get done => '完了';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get attributionsTitle => 'クレジット';

  @override
  String get attributionsSectionLicense => 'ライセンス';

  @override
  String get attributionsSectionShaders => 'ビジュアライザーのシェーダー';

  @override
  String get attributionsSectionLibraries => 'ネイティブライブラリ';

  @override
  String get attributionsSectionEverythingElse => 'その他すべて';

  @override
  String get attributionsLicenseBody =>
      'GNU General Public License v3.0 に基づくフリーソフトウェアです。これらの条件のもとで使用・研究・共有・改変ができます。';

  @override
  String get attributionsPackages => 'オープンソースパッケージのライセンス';

  @override
  String get attributionsPackagesSubtitle =>
      '同梱されているすべての Flutter/Dart パッケージのライセンス全文。';

  @override
  String get manageServersTitle => 'サーバーの管理';

  @override
  String get manageServerInfo => 'サーバー情報';

  @override
  String get manageServerDownloadFolder => 'ダウンロードフォルダ:';

  @override
  String get manageServerCopyPath => 'ダウンロードパスをコピー';

  @override
  String get manageServerPathCopied => 'パスをクリップボードにコピーしました';

  @override
  String get confirmRemoveServerTitle => 'サーバー削除の確認';

  @override
  String get removeSyncedFiles => '同期したファイルを端末から削除しますか？';

  @override
  String get playlistsTitle => 'プレイリスト';

  @override
  String get playlistsNew => '新しいプレイリスト';

  @override
  String get playlistsEmptyTitle => 'プレイリストはまだありません';

  @override
  String get playlistsEmptyBody =>
      '「新しいプレイリスト」ボタンで作成し、キューのスワイプ操作「プレイリストに追加」で曲を追加してください。';

  @override
  String get playlistNameHint => '名前';

  @override
  String get playlistsRename => 'プレイリスト名を変更';

  @override
  String get playlistFallbackTitle => 'プレイリスト';

  @override
  String get playlistEmptyDetail => 'プレイリストが空です。\nキューからトラックを追加してください。';

  @override
  String get shareEmptyTitle => 'キューが空です';

  @override
  String get shareEmptyBody => '共有する前にキューに曲を追加してください。';

  @override
  String get shareBlockedTitle => 'このキューは共有できません';

  @override
  String get shareLocalOnlyBody =>
      'キューにこの端末にのみある曲（どのサーバーにもない曲）が含まれています。共有はキュー内のすべての曲が単一のサーバーのものである場合にのみ機能します。';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'キューには $count 台のサーバー（$names）の曲が混在しています。共有はすべての曲が単一のサーバーのものである場合にのみ機能します。';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'サーバー「$name」はサーバー一覧にありません。そのキューを共有するには再度追加してください。';
  }

  @override
  String get shareTitle => 'プレイリストを共有';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 曲',
    );
    return '$_temp0 （$url から）';
  }

  @override
  String get shareLinkExpires => 'リンクの有効期限';

  @override
  String get shareExpireNever => 'なし';

  @override
  String get shareExpire1Day => '1 日後';

  @override
  String get shareExpire7Days => '7 日後';

  @override
  String get shareExpire30Days => '30 日後';

  @override
  String get shareAction => '共有';

  @override
  String get shareDoneTitle => 'プレイリストを共有しました';

  @override
  String get shareDoneBody => 'このリンクを知っている人は誰でもキューを再生できます:';

  @override
  String get save => '保存';

  @override
  String get start => '開始';

  @override
  String get addServerTitle => 'サーバーを追加';

  @override
  String get editServerTitle => 'サーバーを編集';

  @override
  String get fieldServerUrl => 'サーバー URL';

  @override
  String get fieldPublicAccess => 'パブリックアクセス';

  @override
  String get publicAccessSubtitle => 'サーバーは公開アクセス可能です — ユーザー名やパスワードは不要です。';

  @override
  String get fieldUsername => 'ユーザー名';

  @override
  String get fieldPassword => 'パスワード';

  @override
  String get fieldSdCard => 'SD カードにダウンロード';

  @override
  String get sdCardSubtitle => 'ダウンロードした音楽を内部ストレージではなく、取り外し可能な SD カードに保存します。';

  @override
  String get testConnectionButton => '接続をテスト';

  @override
  String get testing => 'テスト中…';

  @override
  String get connecting => '接続中…';

  @override
  String get validatorUrlNeeded => 'サーバー URL が必要です';

  @override
  String get validatorUrlParse => 'URL を解析できません';

  @override
  String get testEnterUrl => '先にサーバー URL を入力してください。';

  @override
  String get testParseUrl => 'URL を解析できませんでした。';

  @override
  String get testCouldNotConnect => '接続できませんでした。URL を確認してもう一度お試しください。';

  @override
  String get testTimedOut => '接続がタイムアウトしました。';

  @override
  String get connectFailedSnack => 'サーバーに接続できませんでした。URL を確認してもう一度お試しください。';

  @override
  String get connectionSuccessful => '接続に成功しました！';

  @override
  String get couldNotReachServer =>
      'サーバーに到達できませんでした。ログインが必要な場合は「パブリックアクセス」をオフにして認証情報を追加してください。';

  @override
  String get failedToLogin => 'ログインに失敗しました';

  @override
  String testConnected(String version) {
    return '接続しました — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return '接続できませんでした: $error';
  }

  @override
  String get sleepTimerTitle => 'スリープタイマー';

  @override
  String get sleepTimerHint => '再生を一時停止するまでの時間を選んでください。';

  @override
  String get sleepTimerCustom => 'カスタム';

  @override
  String get sleepTimerCustomHint => '分（1〜600）';

  @override
  String get sleepTimerCancel => 'タイマーを解除';

  @override
  String get sleepTimerInvalid => '1〜600 分の数値を入力してください';

  @override
  String sleepTimerPausesIn(String time) {
    return '$time 後に一時停止します';
  }

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes 分';
  }

  @override
  String sleepTimerSet(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分後にスリープタイマーを設定しました',
    );
    return '$_temp0';
  }

  @override
  String get add => '追加';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String get autoDjAddServerFirst => '先にサーバーを追加してください。';

  @override
  String get autoDjSectionServer => 'サーバー';

  @override
  String get autoDjSectionSources => 'ソース';

  @override
  String get autoDjSectionContinuity => '連続性';

  @override
  String get autoDjSectionFilters => 'フィルター';

  @override
  String get autoDjBpmTitle => 'BPM の連続性';

  @override
  String get autoDjBpmSubtitle => '現在の曲のテンポ範囲内の候補を優先します。半分/倍テンポの等価性も考慮します。';

  @override
  String get autoDjTolerance => '許容範囲';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'ハーモニックミキシング';

  @override
  String get autoDjHarmonicSubtitle =>
      '固定した曲とよく調和するキーの候補を優先します（Camelot ホイールの隣接キー）。';

  @override
  String get autoDjStatusOn => 'Auto DJ はオンです';

  @override
  String get autoDjStatusOff => 'Auto DJ はオフです';

  @override
  String get autoDjStatusOffDetail => '下をタップして開始します。現在のサーバーのライブラリが使用されます。';

  @override
  String get autoDjStart => 'Auto DJ を開始';

  @override
  String get autoDjStop => 'Auto DJ を停止';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'キューが少なくなると $url から曲が選ばれます。';
  }

  @override
  String get autoDjActiveSource => 'アクティブなソース';

  @override
  String get autoDjActiveSourceTap => 'アクティブなソース — タップで切り替え';

  @override
  String get autoDjSwitch => '切り替え';

  @override
  String get autoDjOneSourceRequired => 'ソースが少なくとも 1 つ必要です。';

  @override
  String get autoDjMinRating => '最低評価';

  @override
  String get autoDjMinRatingSubtitle => 'この評価以上の曲のみを選びます。';

  @override
  String get autoDjRatingAny => '指定なし';

  @override
  String get autoDjGenreTitle => 'ジャンルフィルター';

  @override
  String get autoDjGenreSubtitle =>
      'ホワイトリストは一致するトラックのみを再生し、ブラックリストはそれらをスキップします。';

  @override
  String get autoDjWhitelist => 'ホワイトリスト';

  @override
  String get autoDjBlacklist => 'ブラックリスト';

  @override
  String get autoDjNoGenres => 'ジャンルが選択されていません。「ジャンルを選択」をタップして選んでください。';

  @override
  String get autoDjPickGenres => 'ジャンルを選択';

  @override
  String get autoDjGenreLoadError => 'ジャンルを読み込めませんでした';

  @override
  String get autoDjKeywordTitle => 'キーワードフィルター';

  @override
  String get autoDjKeywordSubtitle =>
      'タイトル・アーティスト・アルバム・ファイルパスにこれらの語のいずれかを含む候補をスキップします。';

  @override
  String get autoDjNoKeywords => 'キーワードがありません。下に語を追加してフィルタリングを始めてください。';

  @override
  String get autoDjKeywordHint => '例:「live」や「remix」';

  @override
  String get autoDjSearchGenres => 'ジャンルを検索…';

  @override
  String get autoDjNoGenresOnServer => 'このサーバーにジャンルが見つかりませんでした。';

  @override
  String autoDjSelectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return '「$query」に一致するジャンルはありません。';
  }

  @override
  String get download => 'ダウンロード';

  @override
  String get addAll => 'すべて追加';

  @override
  String get browserConfirmDeletePlaylist => 'プレイリスト削除の確認';

  @override
  String get browserConfirmDeleteFolder => 'フォルダ削除の確認';

  @override
  String get browserSearchHint => 'データベースを検索';

  @override
  String browserDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のダウンロードを開始しました',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 曲をキューに追加しました',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'ブラウザ';

  @override
  String get tabQueue => 'キュー';

  @override
  String get drawerTagline => 'パーソナル音楽ストリーミング';

  @override
  String get mainFailedToConnect => 'サーバーへの接続に失敗しました';

  @override
  String get mainQueueEmpty => 'キューが空です';

  @override
  String get visualizerTitle => 'ビジュアライザー';

  @override
  String get mainClearQueue => 'キューをクリア';

  @override
  String get mainSync => '同期';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'キューに $count 曲',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ を有効にしました';

  @override
  String get autoDjDisabled => 'Auto DJ を無効にしました';

  @override
  String autoDjEnabledFor(String url) {
    return '$url で Auto DJ を有効にしました';
  }

  @override
  String get addToPlaylistTitle => 'プレイリストに追加';

  @override
  String get addToPlaylistEmpty => 'プレイリストはまだありません — + をタップして作成してください。';

  @override
  String addedToPlaylist(String name) {
    return '$name に追加しました';
  }

  @override
  String get testConnectedSignedIn => '接続しました — サインインに成功しました。';

  @override
  String get testSignInFailed =>
      'サーバーには到達しましたが、サインインに失敗しました — ユーザー名とパスワードを確認してください。';

  @override
  String get browserFileExplorer => 'ファイルエクスプローラー';

  @override
  String get browserLocalFiles => 'ローカルファイル';

  @override
  String get browserPlaylists => 'プレイリスト';

  @override
  String get browserAlbums => 'アルバム';

  @override
  String get browserArtists => 'アーティスト';

  @override
  String get browserRecent => '最近';

  @override
  String get browserRated => '評価済み';

  @override
  String get browserSearch => '検索';

  @override
  String get browserWelcomeTitle => 'mStream へようこそ';

  @override
  String get browserWelcomeSubtitle => 'ここをタップしてサーバーを追加';

  @override
  String get settingsVisualizerKnobs => 'ビジュアライザーの調整つまみ';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      '各シェーダーの音声反応をその場で調整できるスライダーをビジュアライザー上に表示します。シェーダーエンジンのみ。';

  @override
  String get visualizerTuningTitle => '調整';

  @override
  String get close => '閉じる';

  @override
  String get migMoveStopped => '移動を停止しました — 空き容量が不足しているか、保存先が利用できません。';

  @override
  String get migMoveComplete => '移動が完了しました';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '移動が完了しました — $count 件のファイルをスキップしました（移動先で非対応）',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'ダウンロードを移動中… $progress — アプリを開いたままにしてください';
  }

  @override
  String get migRetry => '再試行';

  @override
  String get queueDownloadAll => 'すべてダウンロード';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 曲をオフライン再生用にダウンロードします。',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'その他';

  @override
  String get commonOn => 'オン';

  @override
  String get commonOff => 'オフ';

  @override
  String get settingsCastQuality => 'キャストするビジュアライザーの画質';

  @override
  String get settingsCastQualitySubtitle720 =>
      'ビジュアライザーをテレビにストリーミングする解像度です。720p — スマートフォンへの負荷が最も軽い。';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'ビジュアライザーをテレビにストリーミングする解像度です。1080p — どの Chromecast でも鮮明（デフォルト）。';

  @override
  String get settingsCastQualitySubtitle4k =>
      'ビジュアライザーをテレビにストリーミングする解像度です。4K — 4K 対応の Chromecast が必要で、スマートフォンへの負荷がはるかに重い。';

  @override
  String get eqCasting =>
      'イコライザーはこの端末で音声を調整するため、キャスト中は利用できません。使用するには接続を解除してください。';

  @override
  String get browserNothingToDownload => 'このリストにダウンロードできるものはありません';

  @override
  String get browserDownloadAllTitle => 'すべてダウンロード';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のファイルをダウンロードします。',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => '検索を閉じる';

  @override
  String get browserSearchThisList => 'このリストを検索';

  @override
  String get browserSearchList => 'リストを検索';

  @override
  String browserNoMatches(String query) {
    return '「$query」に一致するものはありません';
  }

  @override
  String get clear => 'クリア';

  @override
  String get dlLocationUnavailable => 'ダウンロード先が利用できません';

  @override
  String get dlLocationUnavailableServer => 'このサーバーのダウンロード先が利用できません。';

  @override
  String get dlFailed => 'ダウンロードに失敗しました — 接続を確認してください。';

  @override
  String get dlFatSkip =>
      '一部のトラックはこのカードに保存できません — 名前が対応していません。代わりにストリーミングされます。';

  @override
  String get dlServerGone => 'そのサーバーは設定されていません。';

  @override
  String get dlStorageUnavailable =>
      'ストレージの保存先が利用できません — SD カードを接続し直すか、「サーバーを編集」でこのサーバーのストレージ保存先を変更してください。';

  @override
  String get dlCouldNotStart => 'ダウンロードを開始できませんでした — ストレージが利用できません。';

  @override
  String get storageLocationLabel => 'ストレージの保存先';

  @override
  String get storageAppLocal => 'アプリ内';

  @override
  String get storagePermanent => '永続';

  @override
  String get storageSdCard => 'SD カード';

  @override
  String get storageHelpAppLocal => 'アプリ内に保存されます。アンインストールまたはアプリのデータ消去で削除されます。';

  @override
  String get storageHelpPermanent =>
      '選んだフォルダに保存されます。アプリをアンインストールしても残ります。「すべてのファイルへのアクセス」が必要です。';

  @override
  String get storageHelpSdCard =>
      'SD カード上の選んだフォルダに保存されます。カードを取り外すと利用できなくなることがあります。一部の端末ではアプリが SD カードに書き込めません — フォルダの選択が繰り返し失敗する場合は「永続」または「アプリ内」を使用してください。';

  @override
  String get storageChooseFolder => 'フォルダを選択';

  @override
  String get storageNoFolderChosen => 'フォルダがまだ選ばれていません';

  @override
  String get storageDownloadFolderLabel => 'ダウンロードフォルダ';

  @override
  String get storageDownloadFolderHint => 'フォルダ名';

  @override
  String get storageBrowse => '参照';

  @override
  String get storageDownloadFolderHelp =>
      'ファイルはこの端末の \'media/<folder>\' ディレクトリにダウンロードされます。以前のサーバーのフォルダを再利用すると、失われたサーバーを再追加したときにダウンロード済みの曲を保持できます。';

  @override
  String get storageNoStorageAvailable => '利用できるストレージがありません';

  @override
  String get storageNoDownloadFolders => '既存のダウンロードフォルダが見つかりません';

  @override
  String get storageExistingFolders => '既存のダウンロードフォルダ';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の項目',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'ダウンロードを永続的に保存するには「すべてのファイルへのアクセス」を許可し、もう一度モードを選んでください。';

  @override
  String get storageSettings => '設定';

  @override
  String get storageNoVolume => 'ストレージボリュームを特定できませんでした';

  @override
  String get storageNotWritable => 'そのフォルダは書き込めません — 別のフォルダを選んでください。';

  @override
  String get storageNewFolder => '新しいフォルダ';

  @override
  String get storageFolderNameHint => 'フォルダ名';

  @override
  String get storageCouldNotCreateFolder => 'フォルダを作成できませんでした';

  @override
  String get storageNoSubfolders => 'ここにサブフォルダはありません';

  @override
  String get storageUseThisFolder => 'このフォルダを使用';

  @override
  String get storageMovedToNewFolder => 'ダウンロードしたファイルを新しいフォルダに移動しました。';

  @override
  String get storageMoveAlreadyRunning => 'すでに移動が進行中です — まず完了させてください。';

  @override
  String get storageMigrateTitle => 'ストレージボリュームが異なります';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'このサーバーのダウンロード済みファイル $count 個（$size）は、新しい保存先とは別のストレージボリュームにあります。操作を選んでください:',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return '移動先の空き容量が不足しています（空き $free）。移動が途中で失敗することがあります — 先に空き容量を確保してください。';
  }

  @override
  String get storageMigrateMove => '移動する';

  @override
  String get storageMigrateMoveBody =>
      'バックグラウンドで新しい保存先にコピーし、進むにつれて古いコピーを削除します。完了するまでアプリを開いたままにしてください。';

  @override
  String get storageMigrateLeave => 'そのままにする';

  @override
  String get storageMigrateLeaveBody =>
      '今すぐ切り替えます。古いダウンロードはそのまま残り、新しい保存先で再ダウンロードされます。';

  @override
  String get storageMigrateDelete => '古いダウンロードを削除';

  @override
  String get storageMigrateDeleteBody =>
      '今すぐ切り替えて古いファイルを削除します。新しい保存先で再ダウンロードされます。';

  @override
  String get storageMovingBackground =>
      'ダウンロードをバックグラウンドで移動中です — アプリを開いたままにしてください。';

  @override
  String get storageChooseFolderFirst => '先にダウンロードフォルダを選んでください。';

  @override
  String get storageChooseSdFolderFirst =>
      '先に SD カード上のフォルダを選んでください。すべてのフォルダが拒否される場合、端末がアプリによるカードへの書き込みを許可していない可能性があります — 代わりに「永続」または「アプリ内」を使用してください。';

  @override
  String get castPlayOn => '再生先';

  @override
  String get castPlayOnTooltip => '再生先…';

  @override
  String get castSearching => 'キャストデバイスを検索中…';

  @override
  String get castNotSeeing => 'デバイスが表示されませんか？ 同じ Wi-Fi に接続されているか確認してください。';

  @override
  String get castVisualizer => 'ビジュアライザーをキャスト';

  @override
  String get castVisualizerSubtitle => 'ビジュアライザーをテレビにストリーミング · Chromecast のみ';

  @override
  String get visualizerNoKnobs => 'このシェーダーにはつまみがありません。';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get playerLayoutSmall => 'Small';

  @override
  String get playerLayoutMedium => 'Medium';

  @override
  String get playerLayoutLarge => 'Large';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Slim bar — maximum queue';

  @override
  String get playerLayoutMediumDesc => 'Banner — balanced (default)';

  @override
  String get playerLayoutLargeDesc => 'Compact — centered art';

  @override
  String get playerLayoutXlDesc => 'Hero — full album art';

  @override
  String get queueNothingToDownloadEmpty =>
      'Queue is empty — nothing to download';

  @override
  String get queueNothingToDownloadSaved =>
      'Nothing to download — tracks are already saved';
}
