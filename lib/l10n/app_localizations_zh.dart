// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get mainRemove => '移除';

  @override
  String get playlistActionFailed => '无法保存播放列表——该名称可能已被使用。';

  @override
  String get queueAddNext => '添加为下一首';

  @override
  String get queuePlayNow => '立即播放';

  @override
  String get queueAddToEnd => '添加到队列末尾';

  @override
  String get shuffle => '随机播放';

  @override
  String get variousArtists => '群星';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => '语言';

  @override
  String get languageSystemDefault => '跟随系统';

  @override
  String get settingsLanguageSubtitle => '应用的显示语言。“跟随系统”将跟随你的设备设置。';

  @override
  String couldNotOpen(String url) {
    return '无法打开 $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个曲目',
      zero: '没有曲目',
    );
    return '$_temp0';
  }

  @override
  String get reset => '重置';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => '深色';

  @override
  String get themeLight => '浅色';

  @override
  String get tapAddToQueue => '添加到队列';

  @override
  String get tapPlayFromHere => '从此处播放';

  @override
  String get tapAppendAndJump => '添加并播放';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => '着色器';

  @override
  String get visualizerSourceSynthesized => '合成';

  @override
  String get visualizerSourceReal => '真实音频';

  @override
  String get downloadsTitle => '下载';

  @override
  String downloadProgress(String progress) {
    return '进度：$progress%';
  }

  @override
  String get songInfoTitle => '歌曲信息';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsEmpty => 'No lyrics found for this song';

  @override
  String get lyricsError => 'Couldn\'t load lyrics';

  @override
  String get lyricsRetry => 'Retry';

  @override
  String get eqTitle => '均衡器';

  @override
  String get eqOnlyAndroid => '均衡器仅在 Android 上可用。';

  @override
  String get eqNeedsPlayback =>
      '请先播放一首歌曲以配置均衡器。\n\nAndroid 的原生均衡器会随音频会话一起初始化，因此需要正在播放时才能读取频段布局。';

  @override
  String eqInitFailed(String error) {
    return '无法初始化均衡器：\n$error';
  }

  @override
  String get eqNoBands => '此设备的音频驱动未报告任何均衡器频段。';

  @override
  String get eqDisabledHint => '开启均衡器以调整频段。';

  @override
  String get eqEnabledOn => '开启 — 增益已应用到播放';

  @override
  String get eqEnabledOff => '关闭 — 旁路模式';

  @override
  String get cancel => '取消';

  @override
  String get continueLabel => '继续';

  @override
  String get openSettings => '打开设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsSectionPlayback => '播放';

  @override
  String get settingsSectionBrowse => '浏览';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsTheme => '主题';

  @override
  String get themeSubtitleVelvet => '海军蓝与紫色 — 标志性的深色主题。';

  @override
  String get themeSubtitleDark => '中性深色，琥珀色点缀。';

  @override
  String get themeSubtitleLight => '浅色背景，深色应用栏与琥珀色点缀 — 与早期版本的主题一致。';

  @override
  String get settingsTranscode => '音频转码';

  @override
  String get settingsTranscodeSubtitle =>
      '从服务器以转码副本进行流式播放（文件更小，启动略慢）。关闭时播放原始文件。';

  @override
  String get transcodeTitle => '转码';

  @override
  String get transcodeCodec => '编解码器';

  @override
  String get transcodeBitrate => '比特率';

  @override
  String get transcodeAuto => '服务器默认';

  @override
  String get transcodeUnavailable => '此服务器未启用转码，其曲目将以原始质量流式传输。';

  @override
  String get transcodeReloadQueue => '应用到当前队列';

  @override
  String get transcodeReloadQueueSubtitle =>
      '更改转码设置时 — 勾选：立即重新加载整个队列（正在播放的曲目会短暂缓冲）；取消勾选：仅更改后续曲目，当前曲目保持不变播放完毕。';

  @override
  String get settingsTapBehavior => '点击歌曲时';

  @override
  String get settingsStartupPage => '启动页面';

  @override
  String get settingsStartupPageSubtitle => '在此浏览器视图打开应用；返回键回到浏览器。';

  @override
  String get tapSubtitleAddToQueue => '点击歌曲会将其添加到队列。如果队列为空，则自动开始播放。';

  @override
  String get tapSubtitlePlayFromHere => '点击歌曲会用当前视图中的歌曲替换队列，并从所点击的歌曲开始播放。';

  @override
  String get tapSubtitleAppendAndJump => '点击歌曲会将其添加到队列并跳转播放，打断当前正在播放的内容。';

  @override
  String get settingsEqSubtitle => '调节低音、中音和高音。仅限 Android。';

  @override
  String get settingsVisualizerEngine => '可视化引擎';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      '通过 projectM 使用 Milkdrop 预设（默认）。效果更丰富，但更消耗 GPU。';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Shadertoy 风格的片段着色器。更轻量、模块化 — 将 .glsl 文件放入 assets/shaders/ 即可扩展目录。';

  @override
  String get settingsVisualizerSource => '可视化音频来源';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      '默认。可视化效果仅根据播放时间作出反应 — 无需麦克风权限。';

  @override
  String get visualizerSourceSubtitleReal =>
      '可视化效果根据实际音频输出作出反应。需要 Android 的 RECORD_AUDIO 权限。';

  @override
  String get settingsAlbumGrid => '专辑网格视图';

  @override
  String get settingsAlbumGridSubtitle => '以带封面的卡片网格显示专辑，而非普通列表。';

  @override
  String get settingsFileMetadata => '在文件浏览器中读取歌曲元数据';

  @override
  String get settingsFileMetadataSubtitle =>
      '浏览服务器文件时获取每首歌曲的标题、艺术家和专辑封面。关闭时显示原始文件名（在超大文件夹中更快）。';

  @override
  String get settingsLetterStrip => '字母滚动条阈值';

  @override
  String get settingsLetterStripSubtitle =>
      '当列表项达到此数量或更多时显示 A-Z 快速滚动条。低于此数量时隐藏滚动条，且较长的文件夹/文件名会换行显示而非截断。设为 0 可始终显示滚动条。';

  @override
  String get settingsLetterStripSide => '快速滑块位置';

  @override
  String get settingsLetterStripSideSubtitle => 'A–Z 快速条显示在哪一侧。';

  @override
  String get settingsLetterStripLeft => '左侧';

  @override
  String get settingsLetterStripRight => '右侧';

  @override
  String get settingsReset => '恢复默认设置';

  @override
  String get settingsResetSubtitle => '将此屏幕上的所有设置恢复为默认值。服务器和下载不受影响。';

  @override
  String get settingsResetDone => '设置已恢复为默认值';

  @override
  String get realAudioDialogTitle => '使用真实音频？';

  @override
  String get realAudioDialogBody =>
      '真实音频模式会读取手机正在播放的音乐波形，让可视化效果随之反应。Android 需要 RECORD_AUDIO 权限才能实现此功能 — 应用不会录制或向任何地方发送音频。你可以随时切换回合成模式。';

  @override
  String get realAudioPermPermanentlyDenied => '权限已被永久拒绝。请在系统设置中启用它以使用真实音频。';

  @override
  String get realAudioPermDenied => '权限被拒绝。将继续使用合成音频。';

  @override
  String get visualizerTapHint => '点击 = 下一个预设 · 长按关闭';

  @override
  String get visualizerFailed => '可视化启动失败';

  @override
  String get visualizerBringingUp => '正在启动渲染器…';

  @override
  String get visualizerReady => '可视化已就绪';

  @override
  String get visualizerBridgeFailed => '桥接启动失败';

  @override
  String visualizerAudioSourceLine(String source) {
    return '音频来源：$source';
  }

  @override
  String get visualizerTapToClose => '点击任意位置关闭';

  @override
  String get visualizerUnsupported => '可视化目前仅支持 Android。';

  @override
  String get aboutTitle => '关于';

  @override
  String aboutBuiltBy(String name) {
    return '由 $name 开发';
  }

  @override
  String get linkDiscordSubtitle => '社区聊天';

  @override
  String get linkGithubSubtitle => 'mStream 服务器源代码';

  @override
  String get linkHomepageSubtitle => '项目主页';

  @override
  String get aboutAttributions => '致谢';

  @override
  String get aboutAttributionsSubtitle => '许可证、着色器致谢和开源声明。';

  @override
  String get aboutSponsor => '赞助 mStream';

  @override
  String get ok => '确定';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get info => '信息';

  @override
  String get makeDefault => '设为默认';

  @override
  String get goBack => '返回';

  @override
  String get play => '播放';

  @override
  String get playAll => '全部播放';

  @override
  String get rename => '重命名';

  @override
  String get create => '创建';

  @override
  String get copy => '复制';

  @override
  String get done => '完成';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get attributionsTitle => '致谢';

  @override
  String get attributionsSectionLicense => '许可证';

  @override
  String get attributionsSectionShaders => '可视化着色器';

  @override
  String get attributionsSectionLibraries => '原生库';

  @override
  String get attributionsSectionEverythingElse => '其他';

  @override
  String get attributionsLicenseBody =>
      '依据 GNU 通用公共许可证 v3.0（GPL v3.0）发布的自由软件。你可以在该许可证条款下使用、研究、分享和修改它。';

  @override
  String get attributionsPackages => '开源软件包许可证';

  @override
  String get attributionsPackagesSubtitle => '所有捆绑的 Flutter/Dart 软件包的完整许可证文本。';

  @override
  String get manageServersTitle => '管理服务器';

  @override
  String get manageServerInfo => '服务器信息';

  @override
  String get manageServerDownloadFolder => '下载文件夹：';

  @override
  String get manageServerCopyPath => '复制下载路径';

  @override
  String get manageServerPathCopied => '路径已复制到剪贴板';

  @override
  String get confirmRemoveServerTitle => '确认移除服务器';

  @override
  String get removeSyncedFiles => '从设备中移除已同步的文件？';

  @override
  String get playlistsTitle => '播放列表';

  @override
  String get playlistsNew => '新建播放列表';

  @override
  String get playlistsEmptyTitle => '还没有播放列表';

  @override
  String get playlistsEmptyBody =>
      '使用“新建播放列表”按钮创建一个，然后在队列中使用“添加到播放列表”滑动操作来填充它。';

  @override
  String get playlistNameHint => '名称';

  @override
  String get playlistsRename => '重命名播放列表';

  @override
  String get playlistFallbackTitle => '播放列表';

  @override
  String get playlistEmptyDetail => '播放列表为空。\n通过队列添加曲目。';

  @override
  String get shareEmptyTitle => '队列为空';

  @override
  String get shareEmptyBody => '分享前请先向队列添加歌曲。';

  @override
  String get shareBlockedTitle => '无法分享此队列';

  @override
  String get shareLocalOnlyBody =>
      '队列中包含仅存在于此设备上的歌曲（不在任何服务器上）。仅当队列中的每首歌曲都来自同一服务器时才能分享。';

  @override
  String shareMultiServerBody(int count, String names) {
    return '队列中混合了来自 $count 个服务器（$names）的歌曲。仅当所有歌曲都来自同一服务器时才能分享。';
  }

  @override
  String shareServerGoneBody(String name) {
    return '服务器“$name”已不在你的服务器列表中。请重新添加它以分享其队列。';
  }

  @override
  String get shareTitle => '分享播放列表';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '来自 $url 的 $count 首歌曲',
    );
    return '$_temp0';
  }

  @override
  String get shareLinkExpires => '链接过期时间';

  @override
  String get shareExpireNever => '永不';

  @override
  String get shareExpire1Day => '1 天后';

  @override
  String get shareExpire7Days => '7 天后';

  @override
  String get shareExpire30Days => '30 天后';

  @override
  String get shareAction => '分享';

  @override
  String get shareDoneTitle => '播放列表已分享';

  @override
  String get shareDoneBody => '任何拥有此链接的人都可以播放该队列：';

  @override
  String get save => '保存';

  @override
  String get start => '开始';

  @override
  String get addServerTitle => '添加服务器';

  @override
  String get editServerTitle => '编辑服务器';

  @override
  String get fieldServerUrl => '服务器地址';

  @override
  String get fieldPublicAccess => '公开访问';

  @override
  String get publicAccessSubtitle => '服务器可公开访问 — 无需用户名或密码。';

  @override
  String get fieldUsername => '用户名';

  @override
  String get fieldPassword => '密码';

  @override
  String get fieldSdCard => '下载到 SD 卡';

  @override
  String get sdCardSubtitle => '将下载的音乐保存到可移动 SD 卡，而非内部存储。';

  @override
  String get testConnectionButton => '测试连接';

  @override
  String get testing => '正在测试…';

  @override
  String get connecting => '正在连接…';

  @override
  String get validatorUrlNeeded => '需要服务器地址';

  @override
  String get validatorUrlParse => '无法解析地址';

  @override
  String get testEnterUrl => '请先输入服务器地址。';

  @override
  String get testParseUrl => '无法解析地址。';

  @override
  String get testTimedOut => '连接超时。';

  @override
  String get connectionSuccessful => '连接成功！';

  @override
  String get couldNotReachServer => '无法访问服务器。如果需要登录，请关闭“公开访问”并添加凭据。';

  @override
  String get failedToLogin => '登录失败';

  @override
  String testConnected(String version) {
    return '已连接 — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return '无法连接：$error';
  }

  @override
  String get sleepTimerTitle => '睡眠定时器';

  @override
  String get sleepTimerHint => '选择一个时长，之后暂停播放。';

  @override
  String get sleepTimerCustom => '自定义';

  @override
  String get sleepTimerCustomHint => '分钟（1–600）';

  @override
  String get sleepTimerCancel => '取消定时器';

  @override
  String get sleepTimerInvalid => '请输入 1 到 600 之间的分钟数';

  @override
  String sleepTimerPausesIn(String time) {
    return '将在 $time 后暂停';
  }

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String sleepTimerSet(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '睡眠定时器已设为 $minutes 分钟',
    );
    return '$_temp0';
  }

  @override
  String get add => '添加';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String get autoDjAddServerFirst => '请先添加服务器。';

  @override
  String get autoDjSectionServer => '服务器';

  @override
  String get autoDjSectionSources => '来源';

  @override
  String get autoDjSectionContinuity => '连贯性';

  @override
  String get autoDjSectionFilters => '筛选';

  @override
  String get autoDjBpmTitle => 'BPM 连贯性';

  @override
  String get autoDjBpmSubtitle => '优先选择与当前歌曲速度相近的曲目。兼顾半速/倍速等价关系。';

  @override
  String get autoDjTolerance => '容差';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => '和声混音';

  @override
  String get autoDjHarmonicSubtitle => '优先选择与锁定歌曲调性相配的曲目（Camelot 轮盘相邻调）。';

  @override
  String get autoDjDurationTitle => '曲目时长';

  @override
  String get autoDjDurationSubtitle => '仅选择时长在指定范围内的曲目，跳过间奏和长混音';

  @override
  String get autoDjDurationRange => '时长';

  @override
  String get autoDjDurationAny => '不限时长';

  @override
  String autoDjDurationOver(String min) {
    return '超过 $min';
  }

  @override
  String autoDjDurationUnder(String max) {
    return '少于 $max';
  }

  @override
  String autoDjDurationBetween(String min, String max) {
    return '$min 至 $max';
  }

  @override
  String get autoDjDurationAllowUnknown => '包含时长未知的曲目';

  @override
  String get autoDjDurationAllowUnknownSub => '否则将跳过服务器未读取到时长的曲目';

  @override
  String get autoDjStatusOn => 'Auto DJ 已开启';

  @override
  String get autoDjStatusOff => 'Auto DJ 已关闭';

  @override
  String get autoDjStatusOffDetail => '点击下方开始。将使用当前服务器的曲库。';

  @override
  String get autoDjStart => '启动 Auto DJ';

  @override
  String get autoDjStop => '停止 Auto DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return '当队列即将播完时，将从 $url 挑选歌曲。';
  }

  @override
  String get autoDjOneSourceRequired => '至少需要一个来源。';

  @override
  String get autoDjMinRating => '最低评分';

  @override
  String get autoDjMinRatingSubtitle => '仅挑选评分达到或高于此值的歌曲。';

  @override
  String get autoDjRatingAny => '不限';

  @override
  String get autoDjGenreTitle => '流派筛选';

  @override
  String get autoDjGenreSubtitle => '白名单仅播放匹配的曲目；黑名单则跳过它们。';

  @override
  String get autoDjWhitelist => '白名单';

  @override
  String get autoDjBlacklist => '黑名单';

  @override
  String get autoDjNoGenres => '未选择任何流派。点击“选择流派”进行选择。';

  @override
  String get autoDjPickGenres => '选择流派';

  @override
  String get autoDjGenreLoadError => '无法加载流派';

  @override
  String get autoDjKeywordTitle => '关键词筛选';

  @override
  String get autoDjKeywordSubtitle => '跳过标题、艺术家、专辑或文件路径中包含任一这些词语的曲目。';

  @override
  String get autoDjNoKeywords => '暂无关键词。在下方添加词语即可开始筛选。';

  @override
  String get autoDjKeywordHint => '例如“live”或“remix”';

  @override
  String get autoDjSearchGenres => '搜索流派…';

  @override
  String get autoDjNoGenresOnServer => '在此服务器上未找到任何流派。';

  @override
  String autoDjSelectedCount(int count) {
    return '已选择 $count 个';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return '没有与“$query”匹配的流派。';
  }

  @override
  String get download => '下载';

  @override
  String get addAll => '全部添加';

  @override
  String get browserMoreActions => '更多操作';

  @override
  String get browserConfirmDeletePlaylist => '确认删除播放列表';

  @override
  String get browserConfirmDeleteFolder => '确认删除文件夹';

  @override
  String get browserSearchHint => '搜索数据库';

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
  String get searchCategoryLyrics => 'Lyrics';

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
      other: '已开始 $count 项下载',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已将 $count 首歌曲添加到队列',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => '媒体库';

  @override
  String get tabQueue => '队列';

  @override
  String get drawerTagline => '个人音乐流媒体';

  @override
  String get mainFailedToConnect => '连接服务器失败';

  @override
  String get mainQueueEmpty => '队列为空';

  @override
  String get visualizerTitle => '可视化';

  @override
  String get mainClearQueue => '清空队列';

  @override
  String get mainSync => '同步';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个曲目',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ 已启用';

  @override
  String get autoDjDisabled => 'Auto DJ 已禁用';

  @override
  String autoDjEnabledFor(String url) {
    return '已为 $url 启用 Auto DJ';
  }

  @override
  String get addToPlaylistTitle => '添加到播放列表';

  @override
  String get addToPlaylistEmpty => '还没有播放列表 — 点击 + 创建一个。';

  @override
  String addedToPlaylist(String name) {
    return '已添加到 $name';
  }

  @override
  String get testConnectedSignedIn => '已连接 — 登录成功。';

  @override
  String get testSignInFailed => '已连接到服务器，但登录失败 — 请检查用户名和密码。';

  @override
  String get browserFileExplorer => '文件浏览器';

  @override
  String get browserLocalFiles => '本地文件';

  @override
  String get browserPlaylists => '播放列表';

  @override
  String get browserAlbums => '专辑';

  @override
  String get browserArtists => '艺术家';

  @override
  String get browserRecent => '最近添加';

  @override
  String get browserRated => '已评分';

  @override
  String get browserSearch => '搜索';

  @override
  String get browserWelcomeTitle => '欢迎使用 mStream';

  @override
  String get browserWelcomeSubtitle => '点击这里添加服务器';

  @override
  String get settingsVisualizerKnobs => '可视化调节旋钮';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      '在可视化效果上方显示实时滑块，以调整每个着色器的音频反应强度。仅限着色器引擎。';

  @override
  String get visualizerTuningTitle => '调节';

  @override
  String get close => '关闭';

  @override
  String get migMoveStopped => '移动已停止 — 空间不足，或该位置不可用。';

  @override
  String get migMoveComplete => '移动完成';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '移动完成 — 已跳过 $count 个文件（目标位置不支持）',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return '正在移动下载… $progress — 请保持应用打开';
  }

  @override
  String get migRetry => '重试';

  @override
  String get queueDownloadAll => '全部下载';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '将下载 $count 个曲目以供离线播放。',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => '更多';

  @override
  String get commonOn => '开启';

  @override
  String get commonOff => '关闭';

  @override
  String get settingsCastQuality => '投放可视化质量';

  @override
  String get settingsCastQualitySubtitle720 => '可视化效果投放到电视的分辨率。720p — 对手机负担最轻。';

  @override
  String get settingsCastQualitySubtitle1080 =>
      '可视化效果投放到电视的分辨率。1080p — 在任何 Chromecast 上都清晰（默认）。';

  @override
  String get settingsCastQualitySubtitle4k =>
      '可视化效果投放到电视的分辨率。4K — 需要 4K Chromecast；对手机负担大得多。';

  @override
  String get eqCasting => '均衡器调节的是本设备上的音频，因此投放期间不可用。请断开连接以使用它。';

  @override
  String get browserNothingToDownload => '此列表中没有可下载的内容';

  @override
  String get browserDownloadAllTitle => '全部下载';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '将下载 $count 个文件。',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => '关闭搜索';

  @override
  String get browserSearchThisList => '搜索此列表';

  @override
  String get browserSearchList => '搜索列表';

  @override
  String browserNoMatches(String query) {
    return '没有与“$query”匹配的结果';
  }

  @override
  String get clear => '清除';

  @override
  String get dlLocationUnavailable => '下载位置不可用';

  @override
  String get dlLocationUnavailableServer => '此服务器的下载位置不可用。';

  @override
  String get dlFailed => '下载失败 — 请检查你的网络连接。';

  @override
  String get dlFatSkip => '部分曲目无法保存到此卡上 — 它们的名称不受支持。将改为流式播放。';

  @override
  String get dlServerGone => '该服务器已不再配置。';

  @override
  String get dlStorageUnavailable =>
      '存储位置不可用 — 请重新连接 SD 卡，或在“编辑服务器”中更改此服务器的存储位置。';

  @override
  String get dlCouldNotStart => '无法开始下载 — 存储不可用。';

  @override
  String get storageLocationLabel => '存储位置';

  @override
  String get storageAppLocal => '应用内部';

  @override
  String get storagePermanent => '永久';

  @override
  String get storageSdCard => 'SD 卡';

  @override
  String get storageSdSwitchTitle => 'Save to SD card';

  @override
  String get storageSdSwitchSubtitle =>
      'Stored in the SD card\'s app folder — no permission needed, but removed if you uninstall the app.';

  @override
  String get storageHelpAppLocal => '保存在应用内部。卸载或清除应用时会被删除。';

  @override
  String get storageHelpPermanent => '保存到你选择的文件夹。卸载应用后仍会保留。需要“所有文件访问权限”。';

  @override
  String get storageHelpSdCard =>
      '保存到你在 SD 卡上选择的文件夹。移除卡后可能变得不可用。部分设备不允许应用写入 SD 卡 — 如果文件夹选择持续失败，请使用“永久”或“应用内部”。';

  @override
  String get storageChooseFolder => '选择文件夹';

  @override
  String get storageNoFolderChosen => '尚未选择文件夹';

  @override
  String get storageDownloadFolderLabel => '下载文件夹';

  @override
  String get storageDownloadFolderHint => '文件夹名称';

  @override
  String get storageBrowse => '浏览';

  @override
  String get storageDownloadFolderHelp =>
      '文件将下载到此设备上的“media/<folder>”目录。重新使用先前服务器的文件夹，可在你重新添加丢失的服务器时保留其已下载的歌曲。';

  @override
  String get storageNoStorageAvailable => '没有可用的存储';

  @override
  String get storageNoDownloadFolders => '未找到现有的下载文件夹';

  @override
  String get storageExistingFolders => '现有下载文件夹';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个项目',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess => '授予“所有文件访问权限”以永久存储下载内容，然后再次选择该模式。';

  @override
  String get storageSettings => '设置';

  @override
  String get storageNoVolume => '无法定位存储卷';

  @override
  String get storageNotWritable => '该文件夹不可写 — 请选择其他文件夹。';

  @override
  String get storageNewFolder => '新建文件夹';

  @override
  String get storageFolderNameHint => '文件夹名称';

  @override
  String get storageCouldNotCreateFolder => '无法创建文件夹';

  @override
  String get storageNoSubfolders => '此处没有子文件夹';

  @override
  String get storageUseThisFolder => '使用此文件夹';

  @override
  String get storageMovedToNewFolder => '已将下载的文件移动到新文件夹。';

  @override
  String get storageMoveAlreadyRunning => '已有一项移动正在进行 — 请先让它完成。';

  @override
  String get storageMigrateTitle => '不同的存储卷';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '此服务器已下载的 $count 个文件（$size）与新位置位于不同的存储卷上。请选择如何处理：',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return '目标位置可用空间不足（剩余 $free）。移动可能中途失败 — 请先释放空间。';
  }

  @override
  String get storageMigrateMove => '移动它们';

  @override
  String get storageMigrateMoveBody => '在后台复制到新位置，并随复制进度逐个删除旧副本。请保持应用打开直至完成。';

  @override
  String get storageMigrateLeave => '保留它们';

  @override
  String get storageMigrateLeaveBody => '立即切换；旧的下载内容保持原位，并在新位置重新下载。';

  @override
  String get storageMigrateDelete => '删除旧的下载内容';

  @override
  String get storageMigrateDeleteBody => '立即切换并移除旧文件；它们将在新位置重新下载。';

  @override
  String get storageMovingBackground => '正在后台移动你的下载内容 — 请保持应用打开。';

  @override
  String get storageChooseFolderFirst => '请先选择一个下载文件夹。';

  @override
  String get storageChooseSdFolderFirst =>
      '请先在 SD 卡上选择一个文件夹。如果每个文件夹都被拒绝，你的设备可能不允许应用写入该卡 — 请改用“永久”或“应用内部”。';

  @override
  String get castPlayOn => '投放到';

  @override
  String get castPlayOnTooltip => '投放到…';

  @override
  String get castSearching => '正在搜索投放设备…';

  @override
  String get castNotSeeing => '没看到你的设备？请确认它连接的是同一个 Wi-Fi。';

  @override
  String get castVisualizer => '投放可视化';

  @override
  String get castVisualizerSubtitle => '将可视化效果投放到电视 · 仅限 Chromecast';

  @override
  String get visualizerNoKnobs => '此着色器没有可调节的旋钮。';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get playerLayoutSmall => '小';

  @override
  String get playerLayoutMedium => '中';

  @override
  String get playerLayoutLarge => '大';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => '细条 — 最大化队列';

  @override
  String get playerLayoutMediumDesc => '横幅 — 平衡（默认）';

  @override
  String get playerLayoutLargeDesc => '紧凑 — 居中封面';

  @override
  String get playerLayoutXlDesc => '大图 — 完整封面';

  @override
  String get queueNothingToDownloadEmpty => '队列为空 — 没有可下载的内容';

  @override
  String get queueNothingToDownloadSaved => '没有可下载的内容 — 曲目已保存';

  @override
  String get settingsAccentColor => '强调色';

  @override
  String get settingsAccentColorSubtitle => '整个应用中使用的高亮颜色。';

  @override
  String get accentThemeDefault => '主题默认';

  @override
  String get accentCustom => '自定义';

  @override
  String get lanOnYourNetwork => '本地网络中的服务器';

  @override
  String get lanSearching => '正在搜索服务器…';

  @override
  String get lanRefresh => '刷新';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return '登录 $name';
  }

  @override
  String get lanUnreachable => '无法在网络中连接到此服务器。';

  @override
  String get lanNoCode =>
      '此服务器已启用 Quick Connect，但未共享配对码。请以管理员身份登录，或请服务器运营者启用配对码共享。';

  @override
  String get settingsResumeQueue => '启动时恢复播放队列';

  @override
  String get settingsResumeQueueSubtitle => '保存播放队列和当前播放位置，并在重新打开应用时恢复。';

  @override
  String get settingsOfflineQueue => '保持队列离线可用';

  @override
  String get settingsOfflineQueueSubtitle => '自动将队列中的曲目下载到此设备，即使断开连接也能继续播放。';

  @override
  String get settingsOfflineQueueWifiOnly => '仅在 Wi-Fi 下下载';

  @override
  String get settingsOfflineQueueWifiOnlySubtitle => '等待连接 Wi-Fi 后再下载队列中的曲目。';

  @override
  String get settingsAutoDownloadCap => 'Auto-download limit';

  @override
  String get settingsAutoDownloadCapSubtitle => '从正在播放的歌曲开始缓存这么多首；播放过的会随之删除。';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited => '缓存整个播放队列（无限制）。';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      '从正在播放的歌曲算起，保留多少首已下载的队列歌曲。随着播放推进，落在后面的会被删除。设为 0 缓存整个队列。';

  @override
  String get downloadWaitingWifi => '等待 Wi-Fi';

  @override
  String get settingsRatingHalf => '半星评分';

  @override
  String get settingsRatingHalfSubtitle => '以半星为单位评分（长按星标）。';

  @override
  String get ratingTitle => '评分';

  @override
  String get ratingFailed => '无法保存评分';

  @override
  String get diagnosticsTitle => '诊断';

  @override
  String get diagnosticsEnable => '启用日志记录';

  @override
  String get diagnosticsHint => '日志仅保存在您的设备上。复制或分享前会隐藏令牌。';

  @override
  String get diagnosticsVerbose => 'Verbose logging';

  @override
  String get diagnosticsVerboseHint =>
      'Also logs high-frequency events like app focus changes. Only needed when diagnosing a playback issue.';

  @override
  String get diagnosticsCopy => '复制';

  @override
  String get diagnosticsShare => '分享';

  @override
  String get diagnosticsClear => '清除';

  @override
  String get diagnosticsCopied => '日志已复制到剪贴板';

  @override
  String get diagnosticsEmpty => '暂无日志';

  @override
  String get storageAppExternal => '应用外部';

  @override
  String get storageAppSdCard => '应用 SD 卡';

  @override
  String get selfSignedTitle => '允许自签名证书';

  @override
  String get selfSignedSubtitle => '跳过此服务器的 TLS 验证。仅在可信网络中启用。';

  @override
  String get importedShadersTitle => '导入的着色器';

  @override
  String get importedShadersSettingsSubtitle =>
      '将你自己的 .glsl 文件加入 Shader 引擎的轮换。';

  @override
  String get importedShadersRescan => '重新扫描文件夹';

  @override
  String get importedShadersDropHint => '将 .glsl 文件放入此文件夹，然后重新扫描：';

  @override
  String get importedShadersCopyPath => '复制路径';

  @override
  String get importedShadersReachableHint =>
      '可通过 USB 或文件管理器访问（位于 Android/data 下）。Shader 引擎处于活动状态时，导入的着色器会加入轮换。';

  @override
  String get importedShadersRemove => '移除';

  @override
  String get importedShadersEmptyTitle => '文件夹中还没有着色器';

  @override
  String get importedShadersEmptyBody =>
      '将 Shadertoy 风格的 .glsl 文件复制到上方文件夹，然后点击重新扫描。';

  @override
  String get importedShadersInvalid => '可能不是有效的着色器 — 没有 mainImage/main 入口点。';

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
  String get addServerTabUrl => 'Server URL';

  @override
  String get addServerTabQuickConnect => 'Quick Connect';

  @override
  String get irohPairingHeader => 'Connect with a pairing code';

  @override
  String get irohPairingBody =>
      'Enable Remote Access on the server, then paste its pairing code or scan the QR.';

  @override
  String get irohOneServerLimit =>
      'Only one peer-to-peer (iroh) server is supported. Remove the existing one to connect a different server.';

  @override
  String get irohPairingCodeLabel => 'Pairing code';

  @override
  String get irohPairingCodeHint =>
      'Paste the code from the server Remote Access panel';

  @override
  String get irohShowPairingCode => 'Show pairing code';

  @override
  String get irohQrBody =>
      'Scan with the mStream app on another device to connect it to this server, or copy the code and paste it there.';

  @override
  String get irohQrCaution =>
      'Anyone with this code can connect to your server.';

  @override
  String get irohScanQr => 'Scan QR';

  @override
  String get irohPaste => 'Paste';

  @override
  String get irohTestConnection => 'Test connection';

  @override
  String get irohTesting => 'Testing…';

  @override
  String get irohScannerTitle => 'Scan pairing QR';

  @override
  String get irohQrAndroidOnly =>
      'QR scanning isn\'t available on this device.';

  @override
  String get irohAndroidOnly =>
      'Quick Connect isn\'t available on this device.';

  @override
  String get irohCameraPermission =>
      'Camera permission is needed to scan a code.';

  @override
  String get irohPasteFirst => 'Paste or scan a pairing code first.';

  @override
  String get irohTestFirst => 'Test the connection first.';

  @override
  String get irohTestConnected => 'Connected through the iroh tunnel';

  @override
  String irohTestConnectedVersion(String version) {
    return 'Connected through the iroh tunnel — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · direct';

  @override
  String get irohPathSuffixRelay => ' · via relay';

  @override
  String get irohTunnelTimeout =>
      'Tunnel opened but the server did not respond in time.';

  @override
  String irohTunnelTestFailed(String error) {
    return 'Tunnel test failed: $error';
  }

  @override
  String get irohSignInHeader => 'Sign in';

  @override
  String get irohSigningIn => 'Signing in…';

  @override
  String get irohSignInSave => 'Sign in & save';

  @override
  String get irohSignInTimeout => 'Sign-in timed out.';

  @override
  String irohSignInFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return 'Sign-in failed (HTTP $status). Check your username and password.';
  }

  @override
  String get irohBannerConnecting => 'Connecting to server…';

  @override
  String get irohBannerReconnecting => 'Reconnecting to server…';

  @override
  String get irohBannerDisconnected => 'Disconnected from server.';

  @override
  String get irohBannerRelay => 'Connected via relay — slower path.';

  @override
  String get irohBannerRepair =>
      'Server pairing changed — re-pair to reconnect.';

  @override
  String get irohRepairAction => 'Re-pair';

  @override
  String get irohRetry => 'Retry';

  @override
  String get irohRepairTitle => 'Re-pair server';

  @override
  String get irohRepairBody =>
      'This server\'s pairing code changed (its secret was rotated). Paste or scan the new code from the server\'s Remote Access panel.';

  @override
  String get irohRepairFailed =>
      'Couldn\'t connect with that code — check it and try again.';

  @override
  String get irohPathDirect => 'Direct';

  @override
  String get irohPathRelay => 'Relay';

  @override
  String get irohCastUnavailable =>
      'Casting to external devices isn\'t available for peer-to-peer (iroh) servers — playback stays on this device.';

  @override
  String get irohShareUnavailable =>
      'Sharing isn\'t available for peer-to-peer (iroh) servers — they have no public URL to link to.';

  @override
  String get discoverTitle => '发现';

  @override
  String get discoverMatchedBySound => '按声音匹配';

  @override
  String get discoverSimilarTracks => '相似歌曲';

  @override
  String get discoverSimilarArtists => '相似艺术家';

  @override
  String get discoverFromNetwork => '来自网络';

  @override
  String get discoverFromPeers => '来自伙伴服务器';

  @override
  String get discoverQueueAll => '全部加入队列';

  @override
  String get discoverNewArtistsOnly => '仅新艺术家';

  @override
  String get discoverNotAnalyzed => '这首歌尚未分析 — 发现扫描处理后会显示相似歌曲。';

  @override
  String get discoverScanPendingTitle => '尚未分析任何内容';

  @override
  String get discoverScanPendingBody =>
      '此服务器已启用发现功能，但尚未分析任何音乐。发现扫描完成后即可看到相似歌曲。';

  @override
  String get discoverCheckAgain => '重新检查';

  @override
  String get discoverTurnedOff => '此服务器已关闭发现功能。';

  @override
  String get pathScanPending => '此服务器尚未分析任何音乐，因此没有可用于构建路径的曲目。发现扫描完成后即可使用。';

  @override
  String get discoverNothingFound => '未找到匹配项。';

  @override
  String get discoverNoSeed => '播放一首歌曲以发现相似音乐。';

  @override
  String get discoverLeadCopied => '已复制 — 去找找吧！';

  @override
  String get discoverOpenMusicBrainz => '在 MusicBrainz 中打开';

  @override
  String get discoverNetworkWarmingUp => '暂无网络数据 — 发现其他服务器后，伙伴音乐库会在后台下载。';

  @override
  String get discoverNetworkNothingNew => '这首歌没有新发现 — 网络中没有陌生的匹配项。';

  @override
  String get discoverPeersUnreachable => '伙伴服务器没有响应 — 它们现在可能离线。';

  @override
  String get discoverPeersNothingNew => '伙伴服务器上没有这首歌的新发现。';

  @override
  String get autoDjSonicTitle => '声音相似度';

  @override
  String get autoDjSonicSubtitle => '利用服务器的音频分析，只挑选与本次会话声音相似的歌曲。';

  @override
  String get autoDjSonicUnavailable => '此服务器没有发现数据 — 选曲保持随机。';

  @override
  String get autoDjSonicStrictness => '相似度门槛';

  @override
  String autoDjSonicStrictnessValue(int pct) {
    return '$pct% 或更相似';
  }

  @override
  String get autoDjSonicSeedLabel => '种子歌曲';

  @override
  String get autoDjSonicSeedNone => '未设置 — 以正在播放的歌曲作为会话基准。';

  @override
  String get autoDjSonicSeedBanner => '选择种子歌曲——在曲库中点按任意曲目';

  @override
  String get autoDjSonicSeedSearchHint => '搜索歌曲…';

  @override
  String get autoDjSonicSeedRandom => '随机歌曲';

  @override
  String get autoDjSonicSeedRemove => '移除种子歌曲';

  @override
  String get autoDjSonicSeedFailed => '无法从服务器获取歌曲。';

  @override
  String get autoDjSeedNoMatch => '没有歌曲符合你的 Auto DJ 筛选条件，请放宽条件';

  @override
  String get discoverFindSimilar => '查找相似歌曲';

  @override
  String get discoverStartSession => '开始声音会话';

  @override
  String get discoverStartSessionSubtitle => '无尽播放与此相似的音乐 — 将替换当前队列。';

  @override
  String get discoverStartSessionSubtitleRandom => '从随机歌曲开始无尽播放 — 将替换当前队列。';

  @override
  String get discoverSessionStarted => '声音会话已开始 — Auto DJ 已开启。';

  @override
  String get autoDjSonicAnchorLabel => '锚点';

  @override
  String get autoDjSonicAnchorRolling => '跟随氛围';

  @override
  String get autoDjSonicAnchorLocked => '固定在种子歌曲';

  @override
  String get autoDjSonicAnchorRollingHint => '每首歌都跟随会话最近的声音 — 会缓慢演变。';

  @override
  String get autoDjSonicAnchorLockedHint => '整个会话中每首歌都保持接近种子歌曲。';

  @override
  String get trackAddToPlaylist => '添加到播放列表';

  @override
  String get trackAddToPlaylistFailed => '无法添加到播放列表。';

  @override
  String get discoverPlayPathTo => '播放一条通往…的路径';

  @override
  String get pathScreenTitle => '声音路径';

  @override
  String get pathStartNotAnalyzed => '起始歌曲尚未分析 — 请等待发现扫描或选择其他歌曲。';

  @override
  String get pathEndNotAnalyzed => '目标歌曲尚未分析 — 请等待发现扫描或选择其他歌曲。';

  @override
  String get pathStartSong => '起始歌曲';

  @override
  String get pathEndSong => '结束歌曲';

  @override
  String get pathLength => '长度';

  @override
  String get pathRegenerate => '重新生成';

  @override
  String get pathSaveAsPlaylist => '保存为播放列表';

  @override
  String get pathSetupHint => '选择起点和终点歌曲——两者之间的旅程会自动填充。';

  @override
  String get pathNotSet => '未设置';

  @override
  String get pathUsePlaying => '使用正在播放的歌曲';

  @override
  String get pathSearchSong => '搜索';

  @override
  String get pathBrowseLibrary => '浏览曲库';

  @override
  String get pathBuild => '生成旅程';

  @override
  String get pathStartOver => '重新开始';

  @override
  String get pathPickBannerStart => '选择起点歌曲——在曲库中点按任意曲目';

  @override
  String get pathPickBannerEnd => '选择终点歌曲——在曲库中点按任意曲目';

  @override
  String get pathNothingPlaying => '当前没有播放内容';

  @override
  String pathPickOnServer(String server) {
    return '请选择 $server 上的曲目';
  }

  @override
  String get welcomeTranslationNote => '此语言为机器翻译，表述可能不够自然。';

  @override
  String get welcomeTranslationCta => '帮助翻译 mStream';

  @override
  String get setupTitle => '快速设置';

  @override
  String get setupSkip => '跳过';

  @override
  String get setupNext => '下一步';

  @override
  String get setupFinish => '完成';

  @override
  String get setupBack => '上一步';

  @override
  String get setupAccentTitle => '选择你的颜色';

  @override
  String get setupAccentBody => '强调色会用于按钮、滑块和播放器控件。点按任意一个即可试用。';

  @override
  String get setupVisualizerTitle => '为可视化效果使用真实音频';

  @override
  String get setupVisualizerBody => '在启用此选项之前，可视化效果将使用合成数据。';

  @override
  String get setupVisualizerWarning =>
      '开启后会请求麦克风权限——Android 会向解码设备音频流的应用要求该权限（可视化效果正是如此）。';

  @override
  String get setupPlaybackTitle => '点按歌曲时';

  @override
  String get setupOfflineTitle => '离线保留播放队列';

  @override
  String get setupVisualizerNoMic => 'mStream 绝不会使用你的麦克风。';

  @override
  String get playlistEmpty => '播放列表为空';

  @override
  String get trackRating => '评分';

  @override
  String albumDiscNumber(int n) {
    return '第 $n 张';
  }

  @override
  String get autoDjStartTitle => 'Auto DJ 从什么开始？';

  @override
  String get autoDjStartSubtitle => '队列为空，DJ 需要一首起始曲目。有队列时，它会直接沿用其中的内容。';

  @override
  String get autoDjStartRandom => '给我惊喜';

  @override
  String get autoDjStartRandomSub => '从曲库中随机选一首，并以此展开。';

  @override
  String get autoDjStartPick => '我来选';

  @override
  String get autoDjStartPickSub => '打开曲库，自己挑选起始曲目。';

  @override
  String get autoDjStartRemember => '记住此选择';

  @override
  String get autoDjStartRememberSub => '下次跳过此询问，始终以这种方式开始。';

  @override
  String get autoDjStartPickBanner => '选择起始歌曲——在曲库中点按任意曲目';

  @override
  String get autoDjOnEmptyQueue => '队列为空时';

  @override
  String get autoDjOnEmptyQueueSub => '队列为空时开启 Auto DJ 的行为。';

  @override
  String get autoDjStartAskShort => '询问';

  @override
  String serverVersionLabel(String version) {
    return '服务器 v$version';
  }

  @override
  String get serverVersionUnknown => '服务器版本未知';

  @override
  String get serverUpdateUrgent => '请更新服务器';

  @override
  String get serverUpdateAvailable => '有可用的服务器更新';

  @override
  String serverTooOldWarning(String version) {
    return '此服务器版本为 v$version。部分功能需要 v5.5 或更高版本，将不可用。';
  }

  @override
  String get autoDjNeedsNewerServer => 'BPM 连贯性、和声混音和流派筛选需要更新的服务器版本。更新后即可使用。';

  @override
  String get autoDjSonicNeedsNewerServer => '需要服务器 6.15.2 或更高版本';

  @override
  String get torrentScreenTitle => '添加种子';

  @override
  String get torrentNoServer => '尚未配置服务器。';

  @override
  String get torrentServerLabel => '服务器';

  @override
  String get torrentLibraryLabel => '曲库';

  @override
  String get torrentNoLibraries => '此服务器上没有曲库';

  @override
  String get torrentSourceLabel => '来源';

  @override
  String get torrentChooseFile => '选择 .torrent 文件';

  @override
  String get torrentOr => '或';

  @override
  String get torrentMagnetLabel => '磁力链接';

  @override
  String get torrentMagnetInvalid => '磁力链接无效';

  @override
  String torrentNotATorrent(String name) {
    return '「$name」不是 .torrent 文件';
  }

  @override
  String get torrentOpenWith => '在其他应用中打开';

  @override
  String get torrentOpenWithNone => '此设备上没有应用可以打开 .torrent 文件';

  @override
  String get torrentOpenWithFailed => '无法将种子文件交给其他应用';

  @override
  String get torrentIntentTitle => '已接收种子';

  @override
  String get torrentIntentBody => '将其添加到 mStream 服务器上的媒体库，或交给其他应用处理。';

  @override
  String get torrentIntentAdd => '添加到 mStream';

  @override
  String get torrentIntentDontAsk => '始终添加到 mStream，不再询问';

  @override
  String get settingsTorrentAskTitle => '询问如何处理种子文件';

  @override
  String get settingsTorrentAskSub => '使用 mStream 打开种子时，提供交给其他应用的选项';

  @override
  String get settingsTorrentDefaultTitle => '种子文件的默认应用';

  @override
  String get settingsTorrentDefaultSub => '打开 Android 设置，在其中选择由哪个应用处理种子文件和磁力链接';

  @override
  String get settingsTorrentDefaultFailed => '无法打开 Android 设置';

  @override
  String get torrentAutoDetect => '自动检测元数据';

  @override
  String get torrentDetecting => '检测中…';

  @override
  String get torrentDetectNoMetadata => '元数据不足——请手动填写';

  @override
  String get torrentDetected => '已检测到元数据';

  @override
  String get torrentDetectGuess => '推测结果——请核对各字段';

  @override
  String get torrentMetadataLabel => '元数据';

  @override
  String get torrentArtistLabel => '艺术家';

  @override
  String get torrentAlbumLabel => '专辑';

  @override
  String get torrentYearLabel => '年份';

  @override
  String get torrentDestinationLabel => '目标位置';

  @override
  String get torrentPathLabel => '曲库内路径';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹未选曲库›/$path';
  }

  @override
  String get torrentPreviewContents => '‹种子内容›';

  @override
  String get torrentRenameRoot => '重命名种子根文件夹';

  @override
  String get torrentRenameRootSub => '与目标文件夹名保持一致';

  @override
  String get torrentForceFresh => '强制重新下载';

  @override
  String get torrentForceFreshSub => '不检查服务器上已有的文件';

  @override
  String get torrentSubmit => '添加种子';

  @override
  String get torrentSubmitting => '添加中…';

  @override
  String get torrentUnavailable => '此服务器不支持种子。';

  @override
  String get torrentPickLibrary => '请选择曲库';

  @override
  String get torrentOneSource => '请提供磁力链接或 .torrent 文件（二选一）';

  @override
  String get torrentPathEmpty => '目标路径为空';

  @override
  String get torrentSeeded => '已在磁盘上——正在做种';

  @override
  String get torrentAlreadyInClient => '已在种子客户端中';

  @override
  String get torrentInvalidFile => '无效的种子文件';

  @override
  String get torrentSeedCheckFailed => '无法检查已有文件——将重新下载';

  @override
  String get torrentPartialTitle => '部分文件已存在';

  @override
  String get torrentPartialBody => '将种子指向已有副本进行做种，只下载缺少的文件。';

  @override
  String torrentPartialCount(String matched, String total) {
    return '此处有 $matched/$total 个文件';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · 还需下载 $missing 个';
  }

  @override
  String get torrentDownloadFresh => '仍然重新下载';

  @override
  String get torrentMatchNoFolder => '该匹配没有文件夹名——请改用「仍然重新下载」';

  @override
  String torrentAdded(String name) {
    return '已添加「$name」';
  }

  @override
  String torrentDuplicate(String name) {
    return '「$name」已在客户端中';
  }

  @override
  String serverPickerVia(String parent) {
    return 'via $parent';
  }

  @override
  String get browserFederatedReadOnly => 'Read-only server';

  @override
  String get browserFederatedReadOnlyNote =>
      'Playlists and ratings stay on your own';

  @override
  String get federatedAutoDjUnavailable =>
      'Auto DJ can\'t run on a shared server. Switch to one of your own servers first.';

  @override
  String get federatedShareUnavailable =>
      'Tracks on a shared server can\'t be shared from here — they live in someone else\'s library.';

  @override
  String get federatedForget => 'Forget';

  @override
  String get federatedHide => 'Hide from the picker';

  @override
  String get federatedShow => 'Show in the picker';

  @override
  String federatedNoLongerListed(String parent) {
    return 'No longer shared by $parent';
  }

  @override
  String get adminLogOut => '退出登录';

  @override
  String get adminConfigGroup => '配置';

  @override
  String get adminDirectories => '目录';

  @override
  String get adminUsers => '用户';

  @override
  String get adminDLNA => 'DLNA';

  @override
  String get adminTorrent => 'Torrent';

  @override
  String get adminFederation => '联邦';

  @override
  String get adminServerGroup => '服务器';

  @override
  String get adminAbout => '关于';

  @override
  String get adminSettings => '设置';

  @override
  String get adminDatabase => '数据库';

  @override
  String get adminBackups => '备份';

  @override
  String get adminTranscoding => '转码';

  @override
  String get adminLogs => '日志';

  @override
  String get adminAccess => '管理员访问';

  @override
  String adminAppBarTitle(String label) {
    return 'mStream Admin · $label';
  }

  @override
  String get adminPanelTitle => 'mStream Admin';

  @override
  String get adminLoginErrorRequired => '必须填写服务器和用户名';

  @override
  String get adminLoginServerURL => '服务器 URL';

  @override
  String get adminLoginUsername => '用户名';

  @override
  String get adminLoginPassword => '密码';

  @override
  String get adminLoginSignIn => '登录';

  @override
  String get adminRetry => '重试';

  @override
  String get adminSaved => '已保存';

  @override
  String get adminSave => '保存';

  @override
  String get adminClose => '关闭';

  @override
  String get adminPanelMenuItem => '管理面板';

  @override
  String get adminNoLibrariesYetTitle => '暂无媒体库';

  @override
  String get adminAddDirectoryHint => '添加一个目录，开始将音乐扫描入库。';

  @override
  String get adminAddDirectoryButton => '添加目录';

  @override
  String adminRemoveDirectoryTitle(String name) {
    return '移除 $name？';
  }

  @override
  String get adminRemoveDirectoryWarning =>
      '此操作会从数据库中移除该媒体库及其已扫描的曲目。磁盘上的文件不受影响。';

  @override
  String get adminCancel => '取消';

  @override
  String get adminRemove => '移除';

  @override
  String get adminLibraryRemovedToast => '已移除媒体库';

  @override
  String get adminDirectoryPathLabel => '路径';

  @override
  String get adminDirectoryTypeLabel => '类型';

  @override
  String get adminFollowSymlinksTitle => '跟随符号链接';

  @override
  String get adminFollowSymlinksSubtitle => '将在下次扫描时生效';

  @override
  String get adminPickFolderAndNameError => '请选择文件夹并输入名称';

  @override
  String get adminDirectoryAddedToast => '已添加目录 — 已开始扫描';

  @override
  String get adminAddDirectoryDialogTitle => '添加目录';

  @override
  String get adminChooseFolderButton => '在服务器上选择文件夹…';

  @override
  String get adminLibraryNameLabel => '媒体库名称（vpath）';

  @override
  String get adminLibraryNameHelper => '字母、数字和连字符';

  @override
  String get adminGrantAllUsersAccessTitle => '授予所有用户访问权限';

  @override
  String get adminAudiobookLibraryTitle => '有声书库';

  @override
  String get adminAdd => '添加';

  @override
  String get adminChooseFolderTitle => '选择文件夹';

  @override
  String get adminSelectFolderButton => '选择此文件夹';

  @override
  String get adminNoUsersTitle => '暂无用户';

  @override
  String get adminNoUsersSubtitle => '没有用户时，服务器以开放/公开模式运行。添加用户后即需登录。';

  @override
  String get adminAddUserButton => '添加用户';

  @override
  String get adminLibraryAccessDialogTitle => '媒体库访问权限';

  @override
  String get adminLibraryAccessUpdatedToast => '已更新媒体库访问权限';

  @override
  String get adminSetPasswordTitle => '设置密码';

  @override
  String get adminPasswordUpdatedToast => '已更新密码';

  @override
  String adminDeleteUserTitle(String username) {
    return '删除 $username？';
  }

  @override
  String get adminDeleteUserWarning => '此操作将永久删除该用户账户。';

  @override
  String get adminDelete => '删除';

  @override
  String get adminUserDeletedToast => '已删除用户';

  @override
  String get adminStatusPillLabel => 'admin';

  @override
  String get adminDeleteUserMenuItem => '删除用户';

  @override
  String get adminNoLibraryAccessLabel => '无媒体库访问权限';

  @override
  String get adminLibrariesButton => '媒体库';

  @override
  String get adminAdminToggleTitle => '管理员';

  @override
  String get adminMakeDirsToggleTitle => '创建目录';

  @override
  String get adminUploadToggleTitle => '上传';

  @override
  String get adminModifyFilesToggleTitle => '修改文件';

  @override
  String get adminServerAudioToggleTitle => '服务器音频';

  @override
  String get adminAddUserDialogTitle => '添加用户';

  @override
  String get adminUsername => '用户名';

  @override
  String get adminPassword => '密码';

  @override
  String get adminLibraryAccessHeader => '媒体库访问权限';

  @override
  String get adminUsernamePasswordRequiredError => '必须填写用户名和密码';

  @override
  String get adminUserCreatedToast => '已创建用户';

  @override
  String get adminAdministratorToggleTitle => '管理员';

  @override
  String get adminAllowMakeDirectoriesTitle => '允许创建目录';

  @override
  String get adminAllowUploadTitle => '允许上传';

  @override
  String get adminAllowServerAudioTitle => '允许使用服务器音频';

  @override
  String get adminCreate => '创建';

  @override
  String get adminNoLibrariesConfigured => '未配置任何媒体库。';

  @override
  String get adminNewPasswordLabel => '新密码';

  @override
  String get adminLibraryTitle => '媒体库';

  @override
  String get adminTracksInDatabase => '数据库中的曲目数';

  @override
  String get adminScanAllButton => '全部扫描';

  @override
  String get adminScanStarted => '已开始扫描';

  @override
  String get adminForceRescan => '强制重新扫描';

  @override
  String get adminFullRescanStarted => '已开始完整重新扫描';

  @override
  String get adminCompressImages => '压缩图像';

  @override
  String get adminImageCompressionStarted => '已开始压缩图像';

  @override
  String get adminScanOptions => '扫描选项';

  @override
  String get adminScanInterval => '扫描间隔（小时，0 = 关闭）';

  @override
  String get adminBootScanDelay => '启动扫描延迟（秒）';

  @override
  String get adminScanCommitInterval => '扫描提交间隔（1–1000）';

  @override
  String get adminScanThreads => '扫描线程数（0 = 自动）';

  @override
  String get adminSkipImageExtraction => '跳过图像提取';

  @override
  String get adminCompressEmbeddedImages => '压缩内嵌图像';

  @override
  String get adminGenerateWaveforms => '扫描后生成波形图';

  @override
  String get adminAnalyzeBpm => '分析 BPM/调式（已弃用，无操作）';

  @override
  String get adminAutomaticAlbumArt => '自动专辑封面';

  @override
  String get adminDownloadMissingAlbumArt => '下载缺失的专辑封面';

  @override
  String get adminTargetLabel => '目标';

  @override
  String get adminMissingOnly => '仅缺失项';

  @override
  String get adminAllAlbums => '所有专辑';

  @override
  String get adminAlbumsPerRun => '每次运行的专辑数（1–10000）';

  @override
  String get adminAutoDownloadedArtWriteFolder => '自动下载的封面 → 写入文件夹';

  @override
  String get adminManualArtWriteFolder => '手动设置的封面 → 写入文件夹';

  @override
  String get adminManualArtEmbedTag => '手动设置的封面 → 嵌入文件标签';

  @override
  String get adminArtServices => '封面服务';

  @override
  String get adminArtServicesUpdated => '已更新封面服务';

  @override
  String get adminSharedPlaylists => '共享播放列表';

  @override
  String get adminDeleteExpired => '删除已过期';

  @override
  String get adminExpiredSharesDeleted => '已删除过期分享';

  @override
  String get adminDeleteNeverExpiring => '删除永不过期';

  @override
  String get adminEternalSharesDeleted => '已删除永久分享';

  @override
  String get adminNoSharedPlaylists => '暂无共享播放列表';

  @override
  String adminSharedPlaylistSubtitle(String user, int count, String expiry) {
    return '由 $user 创建 · $count 首曲目 · $expiry 过期';
  }

  @override
  String get adminShareDeleted => '已删除分享';

  @override
  String get adminNetwork => '网络';

  @override
  String get adminNetworkSubtitle => '更改这些设置会软重启服务器。';

  @override
  String get adminBindAddress => '绑定地址';

  @override
  String get adminPort => '端口';

  @override
  String get adminTrustProxyHeaders => '信任代理标头';

  @override
  String get adminTrustProxyHeadersSubtitle => '在反向代理后方时启用（X-Forwarded-*）';

  @override
  String get adminPermissions => '权限';

  @override
  String get adminAllowUploads => '允许上传';

  @override
  String get adminAllowMakingDirectories => '允许创建目录';

  @override
  String get adminAllowModifyingFiles => '允许修改文件';

  @override
  String get adminMaxRequestSize => '最大请求大小';

  @override
  String get adminMaxRequestSizeHelper => '例如 50MB 或 512KB';

  @override
  String get adminHttpUi => 'HTTP 与 UI';

  @override
  String get adminResponseCompression => '响应压缩';

  @override
  String get adminCompressionNone => '无';

  @override
  String get adminCompressionGzip => 'gzip';

  @override
  String get adminCompressionBrotli => 'brotli';

  @override
  String get adminWebUi => 'Web UI';

  @override
  String get adminUiDefault => '默认';

  @override
  String get adminUiVelvet => 'Velvet';

  @override
  String get adminDatabaseTuning => '数据库调优';

  @override
  String get adminSqliteSynchronous => 'SQLite synchronous';

  @override
  String get adminSyncFull => 'FULL (safest)';

  @override
  String get adminSyncNormal => 'NORMAL (faster)';

  @override
  String get adminCacheSize => '缓存大小（MB，1–2048）';

  @override
  String get adminLogging => '日志记录';

  @override
  String get adminWriteLogsToDisk => '将日志写入磁盘';

  @override
  String get adminLogBufferSize => '日志缓冲区大小（0–10000，0 = 禁用）';

  @override
  String get adminServerAudio => '服务器音频';

  @override
  String get adminAutoBootServerAudio => '自动启动服务器音频（Rust 播放器）';

  @override
  String get adminRustPlayerPort => 'Rust 播放器端口';

  @override
  String get adminActiveBackend => '活动后端';

  @override
  String get adminPlayer => '播放器';

  @override
  String get adminDetectedCliPlayers => '检测到的 CLI 播放器';

  @override
  String get adminNone => '无';

  @override
  String get adminReDetectPlayers => '重新检测播放器';

  @override
  String get adminReProbedCliPlayers => '已重新探测 CLI 播放器';

  @override
  String get adminSslHttps => 'SSL / HTTPS';

  @override
  String get adminEnabled => '已启用';

  @override
  String get adminDisabled => '已禁用';

  @override
  String get adminReplaceCertificate => '替换证书';

  @override
  String get adminSetCertificate => '设置证书';

  @override
  String get adminSetSslCertificateDialog => '设置 SSL 证书';

  @override
  String get adminCertificatePath => '证书路径';

  @override
  String get adminKeyPath => '密钥路径';

  @override
  String get adminSslConfigured => '已配置 SSL — 重启后生效';

  @override
  String get adminRemoveSsl => '移除 SSL';

  @override
  String get adminSslRemoved => '已移除 SSL';

  @override
  String get adminSecurity => '安全';

  @override
  String get adminJwtSecretLast4 => 'JWT 密钥（后 4 位）';

  @override
  String get adminRegenerateSecret => '重新生成密钥';

  @override
  String get adminSecretRegenerated => '已重新生成密钥 — 所有会话已失效';

  @override
  String get adminRegenerateJwtSecretDialog => '重新生成 JWT 密钥？';

  @override
  String get adminRegenerateJwtSecretDialogBody =>
      '此操作会使所有现有登录失效（包括当前登录）。所有人需重新登录。';

  @override
  String get adminRegenerateButton => '重新生成';

  @override
  String get adminAllNetworks => '所有网络';

  @override
  String get adminLocalhostOnly => '仅本地主机';

  @override
  String get adminIpWhitelist => 'IP 白名单';

  @override
  String get adminNoneLockAdmin => '无（锁定管理员）';

  @override
  String get adminNetworkAccess => '网络访问';

  @override
  String get adminNetworkAccessSubtitle => '限制可访问管理员 API 的网络。';

  @override
  String get adminMode => '模式';

  @override
  String get adminWhitelistedIps => '已加入白名单的 IP / CIDR';

  @override
  String get adminNoneYet => '暂无';

  @override
  String get adminAddIpOrCidr => '添加 IP 或 CIDR';

  @override
  String get adminCidrExample => '192.168.1.0/24';

  @override
  String get adminApply => '应用';

  @override
  String get adminDangerZone => '危险操作区';

  @override
  String get adminLockAdminApi => '锁定管理员 API';

  @override
  String get adminLockAdminApiSubtitle => '禁用整个管理员 API。无法在此处撤销。';

  @override
  String get adminLockButton => '锁定';

  @override
  String get adminLockAdminApiDialog => '锁定管理员 API？';

  @override
  String get adminLockAdminApiDialogBody =>
      '此操作会为所有人禁用整个 /admin API。你无法从此面板撤销 — 需要编辑服务器配置文件并重启。是否继续？';

  @override
  String get adminAdminApiLocked => '已锁定管理员 API';

  @override
  String get adminAccessUpdated => '已更新管理员访问设置';

  @override
  String get adminTranscodingFFmpegTitle => 'FFmpeg';

  @override
  String get adminFFmpegStatusReady => '就绪';

  @override
  String get adminFFmpegStatusNotDownloaded => '未下载';

  @override
  String get adminFFmpegDownloadButton => '下载 / 更新 ffmpeg';

  @override
  String get adminFFmpegDownloadedToast => '已下载 ffmpeg';

  @override
  String get adminFFmpegAutoUpdateTitle => '自动更新 ffmpeg';

  @override
  String get adminFFmpegAutoUpdateSubtitle => '自动保持内置 ffmpeg 为最新版本';

  @override
  String get adminTranscodingDefaultsTitle => '默认值';

  @override
  String get adminDefaultCodecLabel => '默认编解码器';

  @override
  String get adminDefaultBitrateLabel => '默认比特率';

  @override
  String get adminLogsResumeButton => '恢复';

  @override
  String get adminLogsPauseButton => '暂停';

  @override
  String get adminClear => '清除';

  @override
  String get adminLogsAutoScrollTitle => '自动滚动';

  @override
  String adminLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 行',
      one: '1 行',
    );
    return '$_temp0';
  }

  @override
  String get adminLogsDownloadZipButton => '下载 zip';

  @override
  String get adminLogsNoEntriesHint => '暂无日志条目';

  @override
  String get adminDlnaModeDisabled => '已禁用';

  @override
  String get adminSamePortAsHttp => '与 HTTP 同端口';

  @override
  String get adminSeparatePort => '独立端口';

  @override
  String get adminDlnaBrowseFlat => '平铺（所有曲目）';

  @override
  String get adminDlnaBrowseDirectories => '目录';

  @override
  String get adminDlnaBrowseArtist => '按艺术家';

  @override
  String get adminDlnaBrowseAlbum => '按专辑';

  @override
  String get adminDlnaBrowseGenre => '按流派';

  @override
  String get adminDlnaServerTitle => '服务器';

  @override
  String get adminDlnaIdentityTitle => '标识';

  @override
  String get adminDlnaFriendlyNameLabel => '友好名称';

  @override
  String get adminDlnaDeviceUuidLabel => '设备 UUID';

  @override
  String get adminDlnaDeviceUuidHelper => '规范 GUID';

  @override
  String get adminDlnaBrowseLayoutTitle => '浏览布局';

  @override
  String get adminDlnaStructureLabel => '结构';

  @override
  String get adminTestConnection => '测试连接';

  @override
  String get adminKeyNameLabel => '密钥名称 / 标签';

  @override
  String get adminMintKey => '生成密钥';

  @override
  String get adminTorrentClient => '客户端';

  @override
  String get adminActiveClient => '活动客户端';

  @override
  String get adminTransmission => 'Transmission';

  @override
  String get adminQbittorrent => 'qBittorrent';

  @override
  String get adminDeluge => 'Deluge';

  @override
  String get adminEnabledFor => '启用对象';

  @override
  String get adminAllUsers => '所有用户';

  @override
  String get adminWhitelistedUsers => '白名单用户';

  @override
  String get adminHost => '主机';

  @override
  String get adminPasswordUnchangedIfBlank => '留空则不更改';

  @override
  String get adminRpcPath => 'RPC 路径';

  @override
  String get adminUseHttps => '使用 HTTPS';

  @override
  String get adminTest => '测试';

  @override
  String adminReachable(String version) {
    return '可连接$version';
  }

  @override
  String adminConnectionFailed(String error) {
    return '失败：$error';
  }

  @override
  String get adminConnectAndSave => '连接并保存';

  @override
  String adminSaveFailed(String error) {
    return '失败：$error';
  }

  @override
  String get adminConnectedAndSaved => '已连接并保存';

  @override
  String get adminDisconnect => '断开连接';

  @override
  String get adminDisconnected => '已断开连接';

  @override
  String get adminConfigured => '已配置';

  @override
  String get adminNotConfigured => '未配置';

  @override
  String get adminTorrents => 'Torrent';

  @override
  String get adminConnected => '已连接';

  @override
  String get adminNoTorrents => '暂无 torrent';

  @override
  String get adminMstream => 'mStream';

  @override
  String get adminTorrentRemoved => '已移除 torrent';

  @override
  String get adminLibraryDaemonPathMapping => '媒体库 → 守护进程路径映射';

  @override
  String get adminLibraryDaemonPathMappingSubtitle =>
      '将每个媒体库映射到 torrent 守护进程所见的路径。';

  @override
  String get adminAutoDetectAll => '全部自动检测';

  @override
  String get adminAutoDetectionComplete => '自动检测完成';

  @override
  String get adminVerified => '已验证';

  @override
  String get adminUnverified => '未验证';

  @override
  String get adminSetManually => '手动设置';

  @override
  String adminDaemonPathFor(String name) {
    return '“$name”的守护进程路径';
  }

  @override
  String get adminPathOnDaemonHost => '守护进程主机上的路径';

  @override
  String get adminVerifyAndSave => '验证并保存';

  @override
  String get adminVpathVerified => '已验证';

  @override
  String get adminVpathSavedUnverified => '已保存（未验证）';

  @override
  String get adminDownloadPathTemplates => '下载路径模板';

  @override
  String adminPathTemplateVars(String vars) {
    return '变量：$vars';
  }

  @override
  String get adminNoLibraries => '暂无媒体库';

  @override
  String adminSuggestedTemplate(String template) {
    return '建议：$template';
  }

  @override
  String get adminTemplateSaved => '已保存模板';

  @override
  String get adminNoBackupDestinations => '暂无备份目标';

  @override
  String get adminBackupDestinationInfo => '添加一个目标，将媒体库镜像到其他文件夹。';

  @override
  String get adminAddDestination => '添加目标';

  @override
  String get adminAddLibraryFirst => '请先添加媒体库';

  @override
  String get adminBackupQueue => '备份队列';

  @override
  String adminTasksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已排队 $count 个任务',
      one: '已排队 1 个任务',
    );
    return '$_temp0';
  }

  @override
  String adminBackingUp(String library) {
    return '正在备份：$library';
  }

  @override
  String get adminRunning => '运行中';

  @override
  String adminBackupStats(int done, String total, String stats) {
    return '$done 个文件$total$stats';
  }

  @override
  String get adminBackupDisabled => '已禁用';

  @override
  String get adminDestination => '目标';

  @override
  String get adminTrigger => '触发条件';

  @override
  String adminDailyTriggerTime(String trigger, String hour) {
    return '$trigger @ $hour:00';
  }

  @override
  String get adminRetention => '保留策略';

  @override
  String adminRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
      one: '1 天',
    );
    return '$_temp0';
  }

  @override
  String get adminLastRun => '上次运行';

  @override
  String adminLastRunStatus(String status, int files) {
    return '$status · 已复制 $files 个';
  }

  @override
  String get adminRunNow => '立即运行';

  @override
  String get adminBackupQueued => '已将备份排队';

  @override
  String get adminAlreadyRunningSkipped => '已在运行 — 已跳过';

  @override
  String get adminHistory => '历史记录';

  @override
  String get adminEdit => '编辑';

  @override
  String get adminDestinationDeleted => '已删除目标';

  @override
  String get adminBackupHistory => '备份历史记录';

  @override
  String get adminNoHistoryYet => '暂无历史记录';

  @override
  String get adminEditDestination => '编辑目标';

  @override
  String get adminAddBackupDestination => '添加备份目标';

  @override
  String get adminDestinationPath => '目标路径';

  @override
  String get adminBrowseServer => '浏览服务器';

  @override
  String get adminCheckPath => '检查路径';

  @override
  String get adminTriggerField => '触发条件';

  @override
  String get adminAfterEachScan => '每次扫描后';

  @override
  String get adminDaily => '每天';

  @override
  String get adminManualOnly => '仅手动';

  @override
  String get adminRunAtHour => '运行时间（小时）：';

  @override
  String get adminRetentionFieldLabel => '保留期（天，0 = 全部保留）';

  @override
  String get adminEnabledToggle => '已启用';

  @override
  String get adminDestinationUpdated => '已更新目标';

  @override
  String get adminDestinationCreated => '已创建目标';

  @override
  String get adminPickLibrary => '请选择媒体库';

  @override
  String get adminPickDestinationPath => '请选择目标路径';

  @override
  String adminAboutTitle(String version) {
    return 'mStream v$version';
  }

  @override
  String get adminAboutPort => '端口';

  @override
  String get adminSSL => 'SSL';

  @override
  String get adminUI => 'UI';

  @override
  String get adminCompression => '压缩';

  @override
  String get adminTrustProxy => '信任代理';

  @override
  String get adminYes => '是';

  @override
  String get adminNo => '否';

  @override
  String get adminSecretLast4 => '密钥（后 4 位）';

  @override
  String get adminUploads => '上传';

  @override
  String get adminMakeDirs => '创建目录';

  @override
  String get adminFileModify => '修改文件';

  @override
  String get adminSynchronous => 'Synchronous';

  @override
  String get adminCacheSizeLabel => '缓存大小';

  @override
  String adminCacheSizeMb(int size) {
    return '$size MB';
  }

  @override
  String get adminFederationDescription =>
      '与其他 mStream 服务器配对：签发密钥让对方读取你的库，或添加对方的票据来读取他们的库。';

  @override
  String get adminAllowed => '允许';

  @override
  String get adminBackupEnabled => '已启用';

  @override
  String get adminNotAvailable => '不可用';

  @override
  String get adminNotMapped => '未映射';

  @override
  String get adminExpiryNever => '永不';

  @override
  String get adminUnknownUser => '未知';

  @override
  String get adminFederationEnableTitle => '启用联邦';

  @override
  String get adminFederationEnableSubtitle => '允许此服务器与其他 mStream 服务器配对';

  @override
  String get adminFederationEndpointId => '端点 ID';

  @override
  String get adminFederationRelay => '中继';

  @override
  String get adminFederationOnline => '在线';

  @override
  String get adminFederationOffline => '离线';

  @override
  String get adminFederationStopped => '已停止';

  @override
  String get adminFederationUnsupportedTitle => '此平台不支持';

  @override
  String get adminFederationUnsupportedBody => '此版本没有适用于你所在平台的联邦端点，因此无法在此运行。';

  @override
  String get adminFederationCopy => '复制';

  @override
  String get adminFederationCopied => '已复制';

  @override
  String get adminFederationKeysTitle => '你签发的密钥';

  @override
  String get adminFederationKeysSubtitle => '其他服务器读取本服务器时使用的凭据';

  @override
  String get adminFederationNoKeys => '尚未签发密钥';

  @override
  String get adminFederationMintTitle => '签发密钥';

  @override
  String get adminFederationCopyTicket => '显示票据';

  @override
  String get adminFederationTicketTitle => '票据';

  @override
  String get adminFederationTicketBody => '请交给对方服务器的管理员。仅显示一次。';

  @override
  String get adminFederationNoTicket => '此密钥没有可用票据';

  @override
  String get adminFederationEditLimits => '编辑限额';

  @override
  String get adminFederationLimitsTitle => '限额';

  @override
  String get adminFederationLimitsSaved => '已保存限额';

  @override
  String get adminFederationStreamKbps => '流媒体上限 (kbps)';

  @override
  String get adminFederationDailyMb => '每日上限 (MB)';

  @override
  String get adminFederationMaxStreams => '并发流数';

  @override
  String get adminFederationUnlimitedHint => '0 表示不限';

  @override
  String get adminFederationUnlimited => '不限';

  @override
  String adminFederationKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String adminFederationMbPerDay(int mb) {
    return '$mb MB/天';
  }

  @override
  String adminFederationStreams(int count) {
    return '$count 个流';
  }

  @override
  String adminFederationUsageToday(String used) {
    return '今日：$used';
  }

  @override
  String get adminFederationExpired => '已过期';

  @override
  String get adminFederationBound => '已绑定';

  @override
  String get adminFederationUnbound => '未绑定';

  @override
  String get adminFederationResetBinding => '重置绑定';

  @override
  String get adminFederationResetBindingDone => '已重置绑定';

  @override
  String get adminFederationRevoke => '吊销';

  @override
  String adminFederationRevokeTitle(String name) {
    return '吊销 $name？';
  }

  @override
  String get adminFederationRevokeBody => '正在使用此密钥的所有流将立即中断。';

  @override
  String get adminFederationRevoked => '已吊销密钥';

  @override
  String get adminFederationPeersTitle => '你读取的服务器';

  @override
  String get adminFederationPeersSubtitle => '向你提供票据、可供你读取的服务器';

  @override
  String get adminFederationNoPeers => '尚未添加对端';

  @override
  String get adminFederationAddPeer => '添加对端';

  @override
  String get adminFederationAddPeerBody => '粘贴对方服务器给你的票据。其中包含对方地址和访问密钥。';

  @override
  String get adminFederationTicketLabel => '票据';

  @override
  String get adminFederationPeerNameLabel => '名称（可选）';

  @override
  String get adminFederationPeerAdded => '已添加对端';

  @override
  String get adminFederationPeerRemoved => '已移除对端';

  @override
  String adminFederationRemovePeerTitle(String name) {
    return '移除 $name？';
  }

  @override
  String get adminFederationTestOk => '对端可达';

  @override
  String adminFederationLastSeen(String when) {
    return '最后一次连接 $when';
  }

  @override
  String get adminFederationNeverSeen => '从未连接';

  @override
  String get adminFederationUseDiscovery => '发送发现查询';

  @override
  String get adminFederationUseDiscoverySubtitle => '与此对端共享你正在收听的内容';
}
