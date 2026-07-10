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
  String get autoDjActiveSource => '当前来源';

  @override
  String get autoDjActiveSourceTap => '当前来源 — 点击切换';

  @override
  String get autoDjSwitch => '切换';

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
      other: '队列中有 $count 个曲目',
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
  String get settingsAutoDownloadCapSubtitle =>
      'Keep the newest this many auto-downloads; older ones no longer in your queue are removed.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Keep every auto-downloaded track (no limit).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Automatically downloaded tracks kept for offline play. When you go over, the oldest ones that aren\'t in your queue are deleted. Set to 0 to keep everything.';

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
  String get irohConnectHeader => 'Connect peer-to-peer';

  @override
  String get irohPairingHeader => 'Connect with a pairing code';

  @override
  String get irohConnectBody =>
      'Reach your server from anywhere — no port-forwarding, DNS, or public IP needed.';

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
}
