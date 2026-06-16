// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get mainRemove => '削除';

  @override
  String get playlistActionFailed => 'プレイリストを保存できませんでした。その名前は既に使われている可能性があります。';

  @override
  String get queueAddNext => '次に追加';

  @override
  String get queuePlayNow => '今すぐ再生';

  @override
  String get queueAddToEnd => 'キューの最後に追加';

  @override
  String get shuffle => 'シャッフル';

  @override
  String get variousArtists => '様々なアーティスト';

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
  String get transcodeTitle => 'トランスコード';

  @override
  String get transcodeCodec => 'コーデック';

  @override
  String get transcodeBitrate => 'ビットレート';

  @override
  String get transcodeAuto => 'サーバー既定';

  @override
  String get transcodeUnavailable =>
      'このサーバーではトランスコードが有効になっていません。曲は元の品質でストリーミングされます。';

  @override
  String get transcodeReloadQueue => '現在のキューに適用';

  @override
  String get transcodeReloadQueueSubtitle =>
      'トランスコード設定を変更したとき — オン：キュー全体を今すぐ再読み込み（再生中の曲は一瞬バッファリングします）。オフ：次以降の曲のみ変更し、再生中の曲はそのまま再生します。';

  @override
  String get settingsTapBehavior => '曲をタップしたとき';

  @override
  String get settingsStartupPage => '起動画面';

  @override
  String get settingsStartupPageSubtitle =>
      'アプリをこのブラウザー画面で開きます。戻ると、ブラウザーに戻ります。';

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
  String get searchCategoriesTooltip => 'What to search';

  @override
  String get searchCategoriesHeader => 'Search in';

  @override
  String get searchCategoryArtists => 'Artists';

  @override
  String get searchCategoryAlbums => 'Albums';

  @override
  String get searchCategorySongs => 'Songs';

  @override
  String get searchCategoryFiles => 'Files';

  @override
  String searchSubheaderResults(String term) {
    return 'Results for “$term”';
  }

  @override
  String searchSubheaderCategories(String categories) {
    return 'Searching: $categories';
  }

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
  String get nowPlaying => '再生中';

  @override
  String get playerLayoutSmall => '小';

  @override
  String get playerLayoutMedium => '中';

  @override
  String get playerLayoutLarge => '大';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => '細いバー — キューを最大化';

  @override
  String get playerLayoutMediumDesc => 'バナー — バランス型（デフォルト）';

  @override
  String get playerLayoutLargeDesc => 'コンパクト — 中央寄せのアートワーク';

  @override
  String get playerLayoutXlDesc => '特大 — フルサイズのアートワーク';

  @override
  String get queueNothingToDownloadEmpty => 'キューが空です — ダウンロードするものがありません';

  @override
  String get queueNothingToDownloadSaved => 'ダウンロードするものがありません — 曲は既に保存されています';

  @override
  String get settingsAccentColor => 'アクセントカラー';

  @override
  String get settingsAccentColorSubtitle => 'アプリ全体で使用される強調表示の色。';

  @override
  String get accentThemeDefault => 'テーマの既定';

  @override
  String get accentCustom => 'カスタム';

  @override
  String get settingsResumeQueue => '起動時にキューを復元';

  @override
  String get settingsResumeQueueSubtitle => '再生キューと再生位置を保存し、アプリを再び開いたときに復元します。';

  @override
  String get settingsRatingHalf => '半星評価';

  @override
  String get settingsRatingHalfSubtitle => '曲を半星単位で評価（星を長押し）。';

  @override
  String get ratingTitle => '評価';

  @override
  String get ratingFailed => '評価を保存できませんでした';

  @override
  String get diagnosticsTitle => '診断';

  @override
  String get diagnosticsEnable => 'ログ記録を有効にする';

  @override
  String get diagnosticsHint => 'ログは端末内にのみ保存されます。コピーや共有の前にトークンは隠されます。';

  @override
  String get diagnosticsCopy => 'コピー';

  @override
  String get diagnosticsShare => '共有';

  @override
  String get diagnosticsClear => 'クリア';

  @override
  String get diagnosticsCopied => 'ログをクリップボードにコピーしました';

  @override
  String get diagnosticsEmpty => 'まだログがありません';

  @override
  String get storageAppExternal => 'アプリ外部';

  @override
  String get selfSignedTitle => '自己署名証明書を許可';

  @override
  String get selfSignedSubtitle =>
      'このサーバーの TLS 検証をスキップします。信頼できるネットワークでのみ有効にしてください。';

  @override
  String get importedShadersTitle => 'インポートしたシェーダー';

  @override
  String get importedShadersSettingsSubtitle =>
      '独自の .glsl ファイルを Shader エンジンのローテーションに追加します。';

  @override
  String get importedShadersRescan => 'フォルダを再スキャン';

  @override
  String get importedShadersDropHint => 'このフォルダに .glsl ファイルを置き、再スキャンしてください:';

  @override
  String get importedShadersCopyPath => 'パスをコピー';

  @override
  String get importedShadersReachableHint =>
      'USB やファイルマネージャーからアクセスできます（Android/data 以下）。インポートしたシェーダーは Shader エンジンが有効なときにローテーションに加わります。';

  @override
  String get importedShadersRemove => '削除';

  @override
  String get importedShadersEmptyTitle => 'フォルダにはまだシェーダーがありません';

  @override
  String get importedShadersEmptyBody =>
      'Shadertoy スタイルの .glsl ファイルを上のフォルダにコピーし、再スキャンをタップしてください。';

  @override
  String get importedShadersInvalid =>
      '有効なシェーダーではない可能性があります — mainImage/main のエントリーポイントがありません。';

  @override
  String get importedShadersImportDownloads => 'Import .glsl from Downloads';

  @override
  String importedShadersDownloadsImported(int count) {
    return 'Imported $count shader(s) from Downloads';
  }

  @override
  String get importedShadersDownloadsNone => 'No new .glsl files in Downloads';

  @override
  String get importedShadersDownloadsNoPermission =>
      'Storage permission is needed to read Downloads';

  @override
  String get adminLogOut => 'ログアウト';

  @override
  String get adminConfigGroup => '設定';

  @override
  String get adminDirectories => 'ディレクトリ';

  @override
  String get adminUsers => 'ユーザー';

  @override
  String get adminDLNA => 'DLNA';

  @override
  String get adminSubsonicAPI => 'Subsonic API';

  @override
  String get adminMP3Player => 'MP3プレーヤー';

  @override
  String get adminTorrent => 'トレント';

  @override
  String get adminFederation => 'フェデレーション';

  @override
  String get adminServerGroup => 'サーバー';

  @override
  String get adminAbout => '情報';

  @override
  String get adminSettings => '設定';

  @override
  String get adminDatabase => 'データベース';

  @override
  String get adminBackups => 'バックアップ';

  @override
  String get adminTranscoding => 'トランスコード';

  @override
  String get adminLogs => 'ログ';

  @override
  String get adminAccess => '管理アクセス';

  @override
  String adminAppBarTitle(String label) {
    return 'mStream Admin · $label';
  }

  @override
  String get adminPanelTitle => 'mStream Admin';

  @override
  String get adminLoginErrorRequired => 'サーバーとユーザー名は必須です';

  @override
  String get adminLoginServerURL => 'サーバーURL';

  @override
  String get adminLoginUsername => 'ユーザー名';

  @override
  String get adminLoginPassword => 'パスワード';

  @override
  String get adminLoginSignIn => 'サインイン';

  @override
  String get adminRetry => '再試行';

  @override
  String get adminSaved => '保存しました';

  @override
  String get adminSave => '保存';

  @override
  String get adminClose => '閉じる';

  @override
  String get adminPanelMenuItem => '管理パネル';

  @override
  String get adminNoLibrariesYetTitle => 'ライブラリがありません';

  @override
  String get adminAddDirectoryHint => 'ディレクトリを追加すると、ライブラリへの音楽のスキャンを開始できます。';

  @override
  String get adminAddDirectoryButton => 'ディレクトリを追加';

  @override
  String adminRemoveDirectoryTitle(String name) {
    return '$nameを削除しますか?';
  }

  @override
  String get adminRemoveDirectoryWarning =>
      'ライブラリとスキャン済みのトラックをデータベースから削除します。ディスク上のファイルはそのまま残ります。';

  @override
  String get adminCancel => 'キャンセル';

  @override
  String get adminRemove => '削除';

  @override
  String get adminLibraryRemovedToast => 'ライブラリを削除しました';

  @override
  String get adminDirectoryPathLabel => 'パス';

  @override
  String get adminDirectoryTypeLabel => '種類';

  @override
  String get adminFollowSymlinksTitle => 'シンボリックリンクをたどる';

  @override
  String get adminFollowSymlinksSubtitle => '次回のスキャンから適用されます';

  @override
  String get adminPickFolderAndNameError => 'フォルダーを選択し、名前を入力してください';

  @override
  String get adminDirectoryAddedToast => 'ディレクトリを追加しました — スキャンを開始しました';

  @override
  String get adminAddDirectoryDialogTitle => 'ディレクトリを追加';

  @override
  String get adminChooseFolderButton => 'サーバー上のフォルダーを選択…';

  @override
  String get adminLibraryNameLabel => 'ライブラリ名(vpath)';

  @override
  String get adminLibraryNameHelper => '英数字とハイフン';

  @override
  String get adminGrantAllUsersAccessTitle => '全ユーザーにアクセスを許可';

  @override
  String get adminAudiobookLibraryTitle => 'オーディオブックライブラリ';

  @override
  String get adminAdd => '追加';

  @override
  String get adminChooseFolderTitle => 'フォルダーを選択';

  @override
  String get adminSelectFolderButton => 'このフォルダーを選択';

  @override
  String get adminNoUsersTitle => 'ユーザーなし';

  @override
  String get adminNoUsersSubtitle =>
      'ユーザーがいない場合、サーバーはオープン/公開モードで動作します。ログインを必須にするにはユーザーを追加してください。';

  @override
  String get adminAddUserButton => 'ユーザーを追加';

  @override
  String get adminLibraryAccessDialogTitle => 'ライブラリアクセス';

  @override
  String get adminLibraryAccessUpdatedToast => 'ライブラリアクセスを更新しました';

  @override
  String get adminSetSubsonicPasswordTitle => 'Subsonicパスワードを設定';

  @override
  String get adminSetPasswordTitle => 'パスワードを設定';

  @override
  String get adminPasswordUpdatedToast => 'パスワードを更新しました';

  @override
  String adminDeleteUserTitle(String username) {
    return '$usernameを削除しますか?';
  }

  @override
  String get adminDeleteUserWarning => 'ユーザーアカウントを完全に削除します。';

  @override
  String get adminDelete => '削除';

  @override
  String get adminUserDeletedToast => 'ユーザーを削除しました';

  @override
  String get adminStatusPillLabel => 'admin';

  @override
  String get adminDeleteUserMenuItem => 'ユーザーを削除';

  @override
  String get adminNoLibraryAccessLabel => 'ライブラリアクセスなし';

  @override
  String get adminLibrariesButton => 'ライブラリ';

  @override
  String get adminAdminToggleTitle => '管理者';

  @override
  String get adminMakeDirsToggleTitle => 'ディレクトリ作成';

  @override
  String get adminUploadToggleTitle => 'アップロード';

  @override
  String get adminModifyFilesToggleTitle => 'ファイル変更';

  @override
  String get adminServerAudioToggleTitle => 'サーバーオーディオ';

  @override
  String get adminAddUserDialogTitle => 'ユーザーを追加';

  @override
  String get adminUsername => 'ユーザー名';

  @override
  String get adminPassword => 'パスワード';

  @override
  String get adminSubsonicPasswordLabel => 'Subsonicパスワード(任意)';

  @override
  String get adminLibraryAccessHeader => 'ライブラリアクセス';

  @override
  String get adminUsernamePasswordRequiredError => 'ユーザー名とパスワードは必須です';

  @override
  String get adminUserCreatedToast => 'ユーザーを作成しました';

  @override
  String get adminAdministratorToggleTitle => '管理者';

  @override
  String get adminAllowMakeDirectoriesTitle => 'ディレクトリ作成を許可';

  @override
  String get adminAllowUploadTitle => 'アップロードを許可';

  @override
  String get adminAllowServerAudioTitle => 'サーバーオーディオを許可';

  @override
  String get adminCreate => '作成';

  @override
  String get adminNoLibrariesConfigured => 'ライブラリが設定されていません。';

  @override
  String get adminNewPasswordLabel => '新しいパスワード';

  @override
  String get adminLibraryTitle => 'ライブラリ';

  @override
  String get adminTracksInDatabase => 'データベース内のトラック数';

  @override
  String get adminScanAllButton => 'すべてスキャン';

  @override
  String get adminScanStarted => 'スキャンを開始しました';

  @override
  String get adminForceRescan => '強制再スキャン';

  @override
  String get adminFullRescanStarted => '完全再スキャンを開始しました';

  @override
  String get adminCompressImages => '画像を圧縮';

  @override
  String get adminImageCompressionStarted => '画像圧縮を開始しました';

  @override
  String get adminScanOptions => 'スキャンオプション';

  @override
  String get adminScanInterval => 'スキャン間隔(時間、0 = オフ)';

  @override
  String get adminBootScanDelay => '起動時スキャンの遅延(秒)';

  @override
  String get adminScanCommitInterval => 'スキャンコミット間隔(1〜1000)';

  @override
  String get adminScanThreads => 'スキャンスレッド数(0 = 自動)';

  @override
  String get adminSkipImageExtraction => '画像抽出をスキップ';

  @override
  String get adminCompressEmbeddedImages => '埋め込み画像を圧縮';

  @override
  String get adminGenerateWaveforms => 'スキャン後に波形を生成';

  @override
  String get adminAnalyzeBpm => 'BPM/キーを解析(非推奨、動作なし)';

  @override
  String get adminAutomaticAlbumArt => '自動アルバムアート';

  @override
  String get adminDownloadMissingAlbumArt => '不足しているアルバムアートをダウンロード';

  @override
  String get adminTargetLabel => '対象';

  @override
  String get adminMissingOnly => '不足分のみ';

  @override
  String get adminAllAlbums => 'すべてのアルバム';

  @override
  String get adminAlbumsPerRun => '1回あたりのアルバム数(1〜10000)';

  @override
  String get adminAutoDownloadedArtWriteFolder => '自動ダウンロードしたアート → フォルダーに書き込む';

  @override
  String get adminManualArtWriteFolder => '手動設定したアート → フォルダーに書き込む';

  @override
  String get adminManualArtEmbedTag => '手動設定したアート → ファイルタグに埋め込む';

  @override
  String get adminArtServices => 'アートサービス';

  @override
  String get adminArtServicesUpdated => 'アートサービスを更新しました';

  @override
  String get adminSharedPlaylists => '共有プレイリスト';

  @override
  String get adminDeleteExpired => '期限切れを削除';

  @override
  String get adminExpiredSharesDeleted => '期限切れの共有を削除しました';

  @override
  String get adminDeleteNeverExpiring => '無期限を削除';

  @override
  String get adminEternalSharesDeleted => '無期限の共有を削除しました';

  @override
  String get adminNoSharedPlaylists => '共有プレイリストはありません';

  @override
  String adminSharedPlaylistSubtitle(String user, int count, String expiry) {
    return '作成者: $user · $countトラック · 有効期限 $expiry';
  }

  @override
  String get adminShareDeleted => '共有を削除しました';

  @override
  String get adminNetwork => 'ネットワーク';

  @override
  String get adminNetworkSubtitle => 'これらを変更するとサーバーがソフト再起動されます。';

  @override
  String get adminBindAddress => 'バインドアドレス';

  @override
  String get adminPort => 'ポート';

  @override
  String get adminTrustProxyHeaders => 'プロキシヘッダーを信頼';

  @override
  String get adminTrustProxyHeadersSubtitle =>
      'リバースプロキシの背後にある場合に有効化(X-Forwarded-*)';

  @override
  String get adminPermissions => '権限';

  @override
  String get adminAllowUploads => 'アップロードを許可';

  @override
  String get adminAllowMakingDirectories => 'ディレクトリ作成を許可';

  @override
  String get adminAllowModifyingFiles => 'ファイル変更を許可';

  @override
  String get adminMaxRequestSize => '最大リクエストサイズ';

  @override
  String get adminMaxRequestSizeHelper => '例: 50MB または 512KB';

  @override
  String get adminHttpUi => 'HTTP・UI';

  @override
  String get adminResponseCompression => 'レスポンス圧縮';

  @override
  String get adminCompressionNone => 'なし';

  @override
  String get adminCompressionGzip => 'gzip';

  @override
  String get adminCompressionBrotli => 'brotli';

  @override
  String get adminWebUi => 'Web UI';

  @override
  String get adminUiDefault => 'デフォルト';

  @override
  String get adminUiVelvet => 'Velvet';

  @override
  String get adminUiSubsonic => 'Subsonic';

  @override
  String get adminDatabaseTuning => 'データベースチューニング';

  @override
  String get adminSqliteSynchronous => 'SQLite synchronous';

  @override
  String get adminSyncFull => 'FULL (safest)';

  @override
  String get adminSyncNormal => 'NORMAL (faster)';

  @override
  String get adminCacheSize => 'キャッシュサイズ(MB、1〜2048)';

  @override
  String get adminLogging => 'ログ記録';

  @override
  String get adminWriteLogsToDisk => 'ログをディスクに書き込む';

  @override
  String get adminLogBufferSize => 'ログバッファサイズ(0〜10000、0 = 無効)';

  @override
  String get adminServerAudio => 'サーバーオーディオ';

  @override
  String get adminAutoBootServerAudio => 'サーバーオーディオを自動起動(Rustプレーヤー)';

  @override
  String get adminRustPlayerPort => 'Rustプレーヤーのポート';

  @override
  String get adminActiveBackend => 'アクティブなバックエンド';

  @override
  String get adminPlayer => 'プレーヤー';

  @override
  String get adminDetectedCliPlayers => '検出されたCLIプレーヤー';

  @override
  String get adminNone => 'なし';

  @override
  String get adminReDetectPlayers => 'プレーヤーを再検出';

  @override
  String get adminReProbedCliPlayers => 'CLIプレーヤーを再検出しました';

  @override
  String get adminSslHttps => 'SSL / HTTPS';

  @override
  String get adminEnabled => '有効';

  @override
  String get adminDisabled => '無効';

  @override
  String get adminReplaceCertificate => '証明書を置き換える';

  @override
  String get adminSetCertificate => '証明書を設定';

  @override
  String get adminSetSslCertificateDialog => 'SSL証明書を設定';

  @override
  String get adminCertificatePath => '証明書のパス';

  @override
  String get adminKeyPath => 'キーのパス';

  @override
  String get adminSslConfigured => 'SSLを設定しました — 適用するには再起動してください';

  @override
  String get adminRemoveSsl => 'SSLを削除';

  @override
  String get adminSslRemoved => 'SSLを削除しました';

  @override
  String get adminSecurity => 'セキュリティ';

  @override
  String get adminJwtSecretLast4 => 'JWTシークレット(末尾4文字)';

  @override
  String get adminRegenerateSecret => 'シークレットを再生成';

  @override
  String get adminSecretRegenerated => 'シークレットを再生成しました — すべてのセッションが無効になりました';

  @override
  String get adminRegenerateJwtSecretDialog => 'JWTシークレットを再生成しますか?';

  @override
  String get adminRegenerateJwtSecretDialogBody =>
      '既存のすべてのログイン(現在のものを含む)が無効になります。全員が再度サインインする必要があります。';

  @override
  String get adminRegenerateButton => '再生成';

  @override
  String get adminAllNetworks => 'すべてのネットワーク';

  @override
  String get adminLocalhostOnly => 'ローカルホストのみ';

  @override
  String get adminIpWhitelist => 'IPホワイトリスト';

  @override
  String get adminNoneLockAdmin => 'なし(管理をロック)';

  @override
  String get adminNetworkAccess => 'ネットワークアクセス';

  @override
  String get adminNetworkAccessSubtitle => '管理APIにアクセスできるネットワークを制限します。';

  @override
  String get adminMode => 'モード';

  @override
  String get adminWhitelistedIps => 'ホワイトリストのIP / CIDR';

  @override
  String get adminNoneYet => 'まだありません';

  @override
  String get adminAddIpOrCidr => 'IPまたはCIDRを追加';

  @override
  String get adminCidrExample => '192.168.1.0/24';

  @override
  String get adminApply => '適用';

  @override
  String get adminDangerZone => '危険ゾーン';

  @override
  String get adminLockAdminApi => '管理APIをロック';

  @override
  String get adminLockAdminApiSubtitle => '管理API全体を無効にします。ここから元に戻すことはできません。';

  @override
  String get adminLockButton => 'ロック';

  @override
  String get adminLockAdminApiDialog => '管理APIをロックしますか?';

  @override
  String get adminLockAdminApiDialogBody =>
      '全員に対して/admin API全体を無効にします。このパネルから元に戻すことはできません — サーバー設定ファイルの編集と再起動が必要です。続行しますか?';

  @override
  String get adminAdminApiLocked => '管理APIをロックしました';

  @override
  String get adminAccessUpdated => '管理アクセスを更新しました';

  @override
  String get adminTranscodingFFmpegTitle => 'FFmpeg';

  @override
  String get adminFFmpegStatusReady => '準備完了';

  @override
  String get adminFFmpegStatusNotDownloaded => '未ダウンロード';

  @override
  String get adminFFmpegDownloadButton => 'ffmpegをダウンロード / 更新';

  @override
  String get adminFFmpegDownloadedToast => 'ffmpegをダウンロードしました';

  @override
  String get adminFFmpegAutoUpdateTitle => 'ffmpegを自動更新';

  @override
  String get adminFFmpegAutoUpdateSubtitle => 'バンドルされたffmpegを自動的に最新の状態に保ちます';

  @override
  String get adminTranscodingDefaultsTitle => 'デフォルト';

  @override
  String get adminDefaultCodecLabel => 'デフォルトコーデック';

  @override
  String get adminDefaultBitrateLabel => 'デフォルトビットレート';

  @override
  String get adminLogsResumeButton => '再開';

  @override
  String get adminLogsPauseButton => '一時停止';

  @override
  String get adminClear => 'クリア';

  @override
  String get adminLogsAutoScrollTitle => '自動スクロール';

  @override
  String adminLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count行',
      one: '1行',
    );
    return '$_temp0';
  }

  @override
  String get adminLogsDownloadZipButton => 'zipをダウンロード';

  @override
  String get adminLogsNoEntriesHint => 'ログエントリはまだありません';

  @override
  String get adminDlnaModeDisabled => '無効';

  @override
  String get adminSamePortAsHttp => 'HTTPと同じポート';

  @override
  String get adminSeparatePort => '別のポート';

  @override
  String get adminDlnaBrowseFlat => 'フラット(全トラック)';

  @override
  String get adminDlnaBrowseDirectories => 'ディレクトリ';

  @override
  String get adminDlnaBrowseArtist => 'アーティスト別';

  @override
  String get adminDlnaBrowseAlbum => 'アルバム別';

  @override
  String get adminDlnaBrowseGenre => 'ジャンル別';

  @override
  String get adminDlnaServerTitle => 'サーバー';

  @override
  String get adminDlnaIdentityTitle => '識別情報';

  @override
  String get adminDlnaFriendlyNameLabel => 'フレンドリー名';

  @override
  String get adminDlnaDeviceUuidLabel => 'デバイスUUID';

  @override
  String get adminDlnaDeviceUuidHelper => '標準GUID';

  @override
  String get adminDlnaBrowseLayoutTitle => 'ブラウズレイアウト';

  @override
  String get adminDlnaStructureLabel => '構造';

  @override
  String get adminMdnsLocalNetworkDiscoveryTitle => 'ローカルネットワーク検出';

  @override
  String get adminMdnsLocalNetworkDiscoverySubtitle =>
      'このサーバーを_mstream._tcp mDNSサービスとして広告します。メタデータのみを公開し、ライブラリデータや新しいルートは公開しません。';

  @override
  String get adminMdnsEnableAdvertisingTitle => '広告を有効化';

  @override
  String get adminMdnsFriendlyNameLabel => 'フレンドリー名';

  @override
  String get adminMdnsFriendlyNameHelper => '空 = ホスト名から生成(最大63バイト)';

  @override
  String get adminMdnsInstanceIdLabel => 'インスタンスID';

  @override
  String get adminSubsonicApiTitle => 'Subsonic API';

  @override
  String get adminTestConnection => '接続をテスト';

  @override
  String adminSubsonicTestSuccess(String version, String latency) {
    return 'OK · $version · ${latency}ms';
  }

  @override
  String adminSubsonicTestFailed(String reason) {
    return '失敗: $reason';
  }

  @override
  String get adminStatus => 'ステータス';

  @override
  String get adminMethodsImplemented => '実装済みメソッド';

  @override
  String get adminFullStub => '完全 / スタブ';

  @override
  String get adminNowPlaying => '再生中';

  @override
  String get adminNobody => 'なし';

  @override
  String get adminLyricsLrclib => '歌詞(LRCLib)';

  @override
  String get adminLrclibFallback => 'LRCLibフォールバック';

  @override
  String get adminWriteLrcSidecarFiles => '.lrcサイドカーファイルを書き込む';

  @override
  String get adminCache => 'キャッシュ';

  @override
  String get adminPurgeCache => 'キャッシュを削除';

  @override
  String get adminLyricsCachePurged => '歌詞キャッシュを削除しました';

  @override
  String get adminRetryFailed => '失敗分を再試行';

  @override
  String get adminTransientLyricsEntriesCleared => '一時的な歌詞エントリをクリアしました';

  @override
  String get adminJukebox => 'ジュークボックス';

  @override
  String get adminAvailable => '利用可能';

  @override
  String get adminUnavailable => '利用不可';

  @override
  String get adminState => '状態';

  @override
  String get adminPlaying => '再生中';

  @override
  String get adminPaused => '一時停止中';

  @override
  String get adminIdle => 'アイドル';

  @override
  String get adminCurrent => '現在';

  @override
  String get adminQueue => 'キュー';

  @override
  String adminQueueTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countトラック',
      one: '1トラック',
    );
    return '$_temp0';
  }

  @override
  String get adminVolume => '音量';

  @override
  String adminVolumePercent(int percent) {
    return '$percent%';
  }

  @override
  String get adminTokenAuthFailures => 'トークン認証の失敗';

  @override
  String get adminTokenAuthFailuresSubtitle =>
      'Subsonicパスワードなしでトークン認証をデフォルトとするクライアント。';

  @override
  String get adminNoRecentFailures => '最近の失敗はありません';

  @override
  String get adminCleared => 'クリアしました';

  @override
  String get adminMintApiKey => 'APIキーを発行';

  @override
  String get adminMintApiKeySubtitle => 'ユーザー用のSubsonic apiKeyを生成します(1回のみ表示)。';

  @override
  String get adminKeyNameLabel => 'キー名 / ラベル';

  @override
  String get adminMintKey => 'キーを発行';

  @override
  String get adminUsernameAndNameRequired => 'ユーザー名と名前は必須です';

  @override
  String get adminTorrentClient => 'クライアント';

  @override
  String get adminActiveClient => 'アクティブなクライアント';

  @override
  String get adminTransmission => 'Transmission';

  @override
  String get adminQbittorrent => 'qBittorrent';

  @override
  String get adminDeluge => 'Deluge';

  @override
  String get adminEnabledFor => '有効対象';

  @override
  String get adminAllUsers => '全ユーザー';

  @override
  String get adminWhitelistedUsers => 'ホワイトリストのユーザー';

  @override
  String get adminHost => 'ホスト';

  @override
  String get adminPasswordUnchangedIfBlank => '空欄の場合は変更しない';

  @override
  String get adminRpcPath => 'RPCパス';

  @override
  String get adminUseHttps => 'HTTPSを使用';

  @override
  String get adminTest => 'テスト';

  @override
  String adminReachable(String version) {
    return '到達可能$version';
  }

  @override
  String adminConnectionFailed(String error) {
    return '失敗: $error';
  }

  @override
  String get adminConnectAndSave => '接続して保存';

  @override
  String adminSaveFailed(String error) {
    return '失敗: $error';
  }

  @override
  String get adminConnectedAndSaved => '接続して保存しました';

  @override
  String get adminDisconnect => '切断';

  @override
  String get adminDisconnected => '切断済み';

  @override
  String get adminConfigured => '設定済み';

  @override
  String get adminNotConfigured => '未設定';

  @override
  String get adminTorrents => 'トレント';

  @override
  String get adminConnected => '接続済み';

  @override
  String get adminNoTorrents => 'トレントはありません';

  @override
  String get adminMstream => 'mStream';

  @override
  String get adminTorrentRemoved => 'トレントを削除しました';

  @override
  String get adminLibraryDaemonPathMapping => 'ライブラリ → デーモンパスのマッピング';

  @override
  String get adminLibraryDaemonPathMappingSubtitle =>
      '各ライブラリを、トレントデーモンから見たパスにマッピングします。';

  @override
  String get adminAutoDetectAll => 'すべて自動検出';

  @override
  String get adminAutoDetectionComplete => '自動検出が完了しました';

  @override
  String get adminVerified => '検証済み';

  @override
  String get adminUnverified => '未検証';

  @override
  String get adminSetManually => '手動で設定';

  @override
  String adminDaemonPathFor(String name) {
    return '「$name」のデーモンパス';
  }

  @override
  String get adminPathOnDaemonHost => 'デーモンホスト上のパス';

  @override
  String get adminVerifyAndSave => '検証して保存';

  @override
  String get adminVpathVerified => '検証しました';

  @override
  String get adminVpathSavedUnverified => '保存しました(未検証)';

  @override
  String get adminDownloadPathTemplates => 'ダウンロードパステンプレート';

  @override
  String adminPathTemplateVars(String vars) {
    return '変数: $vars';
  }

  @override
  String get adminNoLibraries => 'ライブラリがありません';

  @override
  String adminSuggestedTemplate(String template) {
    return '推奨: $template';
  }

  @override
  String get adminTemplateSaved => 'テンプレートを保存しました';

  @override
  String get adminNoBackupDestinations => 'バックアップ先がありません';

  @override
  String get adminBackupDestinationInfo =>
      'ライブラリを別のフォルダーにミラーするには、保存先を追加してください。';

  @override
  String get adminAddDestination => '保存先を追加';

  @override
  String get adminAddLibraryFirst => '先にライブラリを追加してください';

  @override
  String get adminBackupQueue => 'バックアップキュー';

  @override
  String adminTasksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のタスクをキューに追加',
      one: '1件のタスクをキューに追加',
    );
    return '$_temp0';
  }

  @override
  String adminBackingUp(String library) {
    return 'バックアップ中: $library';
  }

  @override
  String get adminRunning => '実行中';

  @override
  String adminBackupStats(int done, String total, String stats) {
    return '$doneファイル$total$stats';
  }

  @override
  String get adminBackupDisabled => '無効';

  @override
  String get adminDestination => '保存先';

  @override
  String get adminTrigger => 'トリガー';

  @override
  String adminDailyTriggerTime(String trigger, String hour) {
    return '$trigger @ $hour:00';
  }

  @override
  String get adminRetention => '保持期間';

  @override
  String adminRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日',
      one: '1日',
    );
    return '$_temp0';
  }

  @override
  String get adminLastRun => '前回の実行';

  @override
  String adminLastRunStatus(String status, int files) {
    return '$status · $files件コピー';
  }

  @override
  String get adminRunNow => '今すぐ実行';

  @override
  String get adminBackupQueued => 'バックアップをキューに追加しました';

  @override
  String get adminAlreadyRunningSkipped => '既に実行中 — スキップしました';

  @override
  String get adminHistory => '履歴';

  @override
  String get adminEdit => '編集';

  @override
  String get adminDestinationDeleted => '保存先を削除しました';

  @override
  String get adminBackupHistory => 'バックアップ履歴';

  @override
  String get adminNoHistoryYet => 'まだ履歴はありません';

  @override
  String get adminEditDestination => '保存先を編集';

  @override
  String get adminAddBackupDestination => 'バックアップ先を追加';

  @override
  String get adminDestinationPath => '保存先のパス';

  @override
  String get adminBrowseServer => 'サーバーを参照';

  @override
  String get adminCheckPath => 'パスを確認';

  @override
  String get adminTriggerField => 'トリガー';

  @override
  String get adminAfterEachScan => '各スキャン後';

  @override
  String get adminDaily => '毎日';

  @override
  String get adminManualOnly => '手動のみ';

  @override
  String get adminRunAtHour => '実行する時刻: ';

  @override
  String get adminRetentionFieldLabel => '保持期間(日、0 = すべて保持)';

  @override
  String get adminEnabledToggle => '有効';

  @override
  String get adminDestinationUpdated => '保存先を更新しました';

  @override
  String get adminDestinationCreated => '保存先を作成しました';

  @override
  String get adminPickLibrary => 'ライブラリを選択してください';

  @override
  String get adminPickDestinationPath => '保存先のパスを選択してください';

  @override
  String adminAboutTitle(String version) {
    return 'mStream v$version';
  }

  @override
  String get adminAboutPort => 'ポート';

  @override
  String get adminSSL => 'SSL';

  @override
  String get adminUI => 'UI';

  @override
  String get adminCompression => '圧縮';

  @override
  String get adminTrustProxy => 'プロキシを信頼';

  @override
  String get adminYes => 'はい';

  @override
  String get adminNo => 'いいえ';

  @override
  String get adminSecretLast4 => 'シークレット(末尾4文字)';

  @override
  String get adminUploads => 'アップロード';

  @override
  String get adminMakeDirs => 'ディレクトリ作成';

  @override
  String get adminFileModify => 'ファイル変更';

  @override
  String get adminSynchronous => 'Synchronous';

  @override
  String get adminCacheSizeLabel => 'キャッシュサイズ';

  @override
  String adminCacheSizeMb(int size) {
    return '$size MB';
  }

  @override
  String get adminFederationUnavailable => '利用不可';

  @override
  String get adminFederationDescription =>
      'フェデレーションは新しいローカルバックアップの仕組みを中心に再構築中で、現在サーバーでは利用できません。古いクライアントが404ではなく明確なステータスを受け取れるよう、エンドポイントはマウントされたままになっています。';

  @override
  String get adminCheckStatus => 'ステータスを確認';

  @override
  String get adminAllowed => '許可';

  @override
  String get adminBackupEnabled => '有効';

  @override
  String get adminNotAvailable => '利用不可';

  @override
  String get adminNotMapped => '未マッピング';

  @override
  String get adminExpiryNever => 'なし';

  @override
  String get adminUnknownUser => '不明';
}
