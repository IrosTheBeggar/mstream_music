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
  String get fieldPasswordShow => 'Show password';

  @override
  String get fieldPasswordHide => 'Hide password';

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
  String get autoDjMultiServerTitle => '从所有服务器播放';

  @override
  String get autoDjMultiServerSubtitle => 'Auto DJ 同时从所有服务器挑选，匹配当前播放的声音';

  @override
  String get autoDjMultiServerNeedsSonic => '需要在下方开启“声音相似度”';

  @override
  String get autoDjSectionShared => '本次会话';

  @override
  String get autoDjSectionPerServer => '各个媒体库';

  @override
  String get autoDjEditingServer => '设置对象';

  @override
  String autoDjMultiServerAllIn(int count) {
    return '$count 台服务器正在参与';
  }

  @override
  String autoDjMultiServerConnecting(int count) {
    return '$count 台仍在连接';
  }

  @override
  String autoDjMultiServerSomeExcluded(int count, int total) {
    return '$total 台中有 $count 台参与 — 其余缺少 discovery、匹配的嵌入模型或足够新的服务器版本';
  }

  @override
  String get autoDjSectionQueue => '队列';

  @override
  String get autoDjSongsPerFetchTitle => '每次获取的歌曲数';

  @override
  String get autoDjSongsPerFetchSubtitle =>
      'Auto DJ 每次运行时加入队列的歌曲数量。连续性过滤器以获取时正在播放的歌曲为基准评判整批歌曲。';

  @override
  String autoDjSongsPerFetchValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首歌',
      one: '1 首歌',
    );
    return '$_temp0';
  }

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
  String get browserSectionLibrary => '资料库';

  @override
  String get browserSectionListen => '聆听';

  @override
  String get browserSectionNetwork => '网络';

  @override
  String get browserSectionServer => '服务器';

  @override
  String get browserFederation => '联合';

  @override
  String get browserAutoDjOn => '已开启';

  @override
  String get browserAutoDjOff => '已关闭';

  @override
  String browserSharedLibraries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个共享资料库',
    );
    return '$_temp0';
  }

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
  String get mirrorRootLabel => '本地副本文件夹（可选）';

  @override
  String get mirrorRootHelp =>
      '一个已经包含此音乐库副本的文件夹，由其他工具（Syncthing、rclone、NAS）保持同步。在其中找到的文件将从磁盘播放。应用永远不会向其中写入。';

  @override
  String get libraryCopyTitle => '音乐库副本';

  @override
  String get libraryCopyKeepSection => '在此设备上保留完整副本';

  @override
  String get libraryCopyKeepHelp =>
      '每首曲目都会以原始音质下载并保持同步：新增文件会被下载，更改的文件会被替换，服务器上删除的文件会暂时移入回收站文件夹。';

  @override
  String get libraryCopyUnsupported => '此服务器不支持音乐库同步，需要 mStream 6.27 或更高版本。';

  @override
  String get libraryCopyNoLibraries => '尚未获取到音乐库——请先打开该服务器一次，然后再回来。';

  @override
  String get libraryCopyNeverSynced => '尚未同步';

  @override
  String libraryCopyStatus(String when, int files, String size) {
    return '上次同步 $when · $files 个文件 · $size';
  }

  @override
  String libraryCopySyncing(int done, int total) {
    return '正在同步… $done / $total';
  }

  @override
  String get libraryCopyPreparing => '正在检查服务器…';

  @override
  String get libraryCopySyncNow => '立即同步';

  @override
  String libraryCopyFailed(int n) {
    return '$n 个文件失败';
  }

  @override
  String get libraryCopyFailedTitle => '失败的文件';

  @override
  String libraryCopyLastRunError(String error) {
    return '上次同步失败：$error';
  }

  @override
  String get libraryCopyRetention => '已删除文件的保留时间';

  @override
  String libraryCopyRetentionDays(int n) {
    return '$n 天';
  }

  @override
  String get libraryCopyRetentionForever => '永久';

  @override
  String get libraryCopyWifiOnly => '仅限 Wi-Fi';

  @override
  String get libraryCopyDesktopNote => '应用打开时会进行同步。';

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
  String get addServerTabUrl => '服务器地址';

  @override
  String get addServerTabQuickConnect => '快速连接';

  @override
  String get irohPairingHeader => '使用配对码连接';

  @override
  String get irohPairingBody => '在服务器上启用“Remote Access”（远程访问），然后粘贴其配对码或扫描二维码。';

  @override
  String get irohPairingCodeLabel => '配对码';

  @override
  String get irohPairingCodeHint => '粘贴服务器 Remote Access 面板中的配对码';

  @override
  String get irohShowPairingCode => '显示配对码';

  @override
  String get irohQrBody => '在另一台设备上用 mStream 应用扫描以连接到此服务器，或复制配对码并在那里粘贴。';

  @override
  String get irohQrCaution => '任何拥有此配对码的人都可以连接到你的服务器。';

  @override
  String get irohScanQr => '扫描二维码';

  @override
  String get irohPaste => '粘贴';

  @override
  String get irohTestConnection => '测试连接';

  @override
  String get irohTesting => '正在测试…';

  @override
  String get irohScannerTitle => '扫描配对二维码';

  @override
  String get irohQrAndroidOnly => '此设备不支持扫描二维码。';

  @override
  String get irohAndroidOnly => '此设备不支持快速连接。';

  @override
  String get irohCameraPermission => '扫描二维码需要相机权限。';

  @override
  String get irohPasteFirst => '请先粘贴或扫描配对码。';

  @override
  String get irohTestFirst => '请先测试连接。';

  @override
  String get irohTestConnected => '已通过 iroh 隧道连接';

  @override
  String irohTestConnectedVersion(String version) {
    return '已通过 iroh 隧道连接 — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · 直连';

  @override
  String get irohPathSuffixRelay => ' · 经中继';

  @override
  String get irohTunnelTimeout => '隧道已打开，但服务器未及时响应。';

  @override
  String irohTunnelTestFailed(String error) {
    return '隧道测试失败：$error';
  }

  @override
  String get irohSignInHeader => '登录';

  @override
  String get irohSigningIn => '正在登录…';

  @override
  String get irohSignInSave => '登录并保存';

  @override
  String get irohSignInTimeout => '登录超时。';

  @override
  String irohSignInFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return '登录失败（HTTP $status）。请检查用户名和密码。';
  }

  @override
  String get irohBannerConnecting => '正在连接服务器…';

  @override
  String get irohBannerReconnecting => '正在重新连接服务器…';

  @override
  String get irohBannerDisconnected => '已与服务器断开连接。';

  @override
  String get irohBannerRelay => '已通过中继连接 — 路径较慢。';

  @override
  String get irohBannerRepair => '服务器配对已更改 — 请重新配对以重新连接。';

  @override
  String get irohRepairAction => '重新配对';

  @override
  String get irohRetry => '重试';

  @override
  String get irohRepairTitle => '重新配对服务器';

  @override
  String get irohRepairBody =>
      '此服务器的配对码已更改（其密钥已轮换）。请从服务器的 Remote Access 面板粘贴或扫描新的配对码。';

  @override
  String get irohRepairFailed => '无法使用该配对码连接 — 请检查后重试。';

  @override
  String get irohPathDirect => '直连';

  @override
  String get irohPathRelay => '中继';

  @override
  String get irohCastUnavailable => '点对点 (iroh) 服务器不支持投放到外部设备 — 播放将保留在此设备上。';

  @override
  String get irohShareUnavailable => '点对点 (iroh) 服务器不支持分享 — 它们没有可链接的公开地址。';

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
  String get autoDjSonicNotReady => '发现功能已开启，但扫描尚未产生数据 — 在此之前选曲保持随机。';

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
  String get federationTitle => '联合';

  @override
  String get federationStatusOn => '已开启 · 已连接中继';

  @override
  String get federationStatusConnecting => '已开启 · 连接中…';

  @override
  String get federationStatusOff => '已关闭';

  @override
  String get federationStatusUnavailable => '此平台不可用';

  @override
  String get federationSharedWithYou => '与你共享的';

  @override
  String get federationRequestsSection => '请求';

  @override
  String get federationYourSharedLibraries => '你共享的曲库';

  @override
  String get federationAddPeer => '添加对等服务器';

  @override
  String get federationShareLibrary => '共享曲库';

  @override
  String get federationNoPeersYet => '还没有人与此服务器共享任何内容。';

  @override
  String get federationNoKeysYet => '还没有票据 — 共享一个曲库来创建票据。';

  @override
  String get federationNoRequests => '还没有请求 — 发现网络中的服务器可以在这里找到你。';

  @override
  String get federationClipboardTicket => '剪贴板中有票据';

  @override
  String federationTicketPreview(String name, String libraries) {
    return '$name · 共享 $libraries';
  }

  @override
  String federationTicketPreviewNoLibraries(String name) {
    return '$name';
  }

  @override
  String get federationUnnamedServer => '未命名服务器';

  @override
  String get federationAddPeerAction => '添加';

  @override
  String get federationPeerLive => '在线';

  @override
  String get federationPeerConnecting => '连接中…';

  @override
  String get federationPeerDirectTunnel => '直连隧道';

  @override
  String federationPeerViaParent(String parent) {
    return '经由 $parent';
  }

  @override
  String federationPeerViaTunnel(String parent) {
    return '经由 $parent 的隧道';
  }

  @override
  String get federationPeerMissing => '已停止共享';

  @override
  String get federationPeerHidden => '已在选择器中隐藏';

  @override
  String federationMemberNote(String server) {
    return '共享由管理员负责。创建票据、添加对等服务器和回复配对请求都需要以管理员身份登录 $server — 与打开管理面板所用的登录相同。';
  }

  @override
  String get federationRestrictedNote => '此服务器只接受来自其自身网络的管理调用。请在家中连接以在此管理共享。';

  @override
  String get federationDisabledNote => '此服务器已关闭管理 API。';

  @override
  String get federationUnsupportedNote => '此服务器版本过旧，无法从应用中管理联合。请更新 mStream。';

  @override
  String get federationLoadFailed => '无法连接服务器。';

  @override
  String get federationRetry => '重试';

  @override
  String get federationOffTitle => '与朋友的服务器共享曲库';

  @override
  String get federationOffBody =>
      '配对两台 mStream 服务器，互相收听对方的音乐。交换的是票据 — 用短信发送、扫码或粘贴。';

  @override
  String get federationOffPoint1Title => '只读，端到端加密';

  @override
  String get federationOffPoint1Body => '播放列表和评分永远不会离开你的服务器';

  @override
  String get federationOffPoint2Title => '无需端口转发或 DNS';

  @override
  String get federationOffPoint2Body => 'iroh 会找到路径 — 能直连就直连，需要时走中继';

  @override
  String get federationOffPoint3Title => '可撤销的票据';

  @override
  String get federationOffPoint3Body => '每张只能兑换一次，随时可以切断';

  @override
  String get federationOffAdminOnly => '只有服务器管理员能开启。';

  @override
  String federationOffMemberNote(String server) {
    return '$server 上的联合已关闭。其管理员可以开启。';
  }

  @override
  String get federationTurnOn => '开启联合';

  @override
  String get federationUnavailableNote =>
      'iroh 组件没有适用于此服务器操作系统/CPU 的构建，联合端点无法在这里运行。';

  @override
  String get federationTurnedOn => '联合已开启';

  @override
  String get federationTurnedOff => '联合已关闭';

  @override
  String get federationToggleFailed => '无法更新联合设置。';

  @override
  String get federationSettingsTitle => '联合设置';

  @override
  String get federationSwitchSubtitle => '点对点，端到端加密。无需端口转发，无需 DNS。';

  @override
  String get federationStatusSection => '状态';

  @override
  String get federationConnectedRelay => '已连接中继';

  @override
  String get federationNotRunning => '端点未运行';

  @override
  String get federationEndpointId => '端点 ID';

  @override
  String get federationEndpointCopied => '已复制端点 ID';

  @override
  String get federationPairingRequestsSection => '配对请求';

  @override
  String get federationRequestsInboxTitle => '接受来自发现网络的请求';

  @override
  String get federationRequestsInboxSubtitle =>
      '默认关闭。关闭时，新请求会在传输层被拒绝；你自己发出的请求的回复仍会送达。';

  @override
  String get federationInboxFailed => '无法更新请求收件箱。';

  @override
  String get federationDefaultsSection => '新票据的默认值';

  @override
  String get federationDefaultsNote => '来自服务器配置 — 每张票据都可以更改';

  @override
  String get federationOffWarning =>
      '关闭联合会断开所有对等连接，并隐藏你的票据直到重新开启。对等服务器会保留它们的票据。';

  @override
  String federationRequestWantsToPair(String name) {
    return '$name 想要配对';
  }

  @override
  String federationRequestToName(String name) {
    return '发给 $name 的请求';
  }

  @override
  String federationRequestOffers(String libraries) {
    return '提供 $libraries';
  }

  @override
  String get federationRequestOffersNothing => '未提供任何曲库';

  @override
  String federationRequestYouOffered(String libraries) {
    return '你提供了 $libraries';
  }

  @override
  String get federationRequestYouOfferedNothing => '你未提供任何曲库';

  @override
  String get federationReqSending => '发送中…';

  @override
  String get federationReqWaiting => '等待对方';

  @override
  String get federationReqSharingBack => '正在回共享…';

  @override
  String get federationReqNeedsAnswer => '需要你的回复';

  @override
  String get federationReqSendingTicket => '正在发送你的票据…';

  @override
  String get federationReqWaitingShare => '等待对方共享';

  @override
  String get federationReqDeclined => '已被拒绝';

  @override
  String get federationReqYouDeclined => '你已拒绝';

  @override
  String get federationReqInboxClosed => '对方收件箱已关闭';

  @override
  String get federationReqFederated => '已联合';

  @override
  String get federationReqWithdrawn => '已撤回';

  @override
  String get federationReqExpired => '已过期';

  @override
  String get federationAccept => '接受…';

  @override
  String get federationAcceptAndShare => '接受并共享';

  @override
  String get federationDecline => '拒绝';

  @override
  String get federationCancelRequest => '撤回请求';

  @override
  String get federationDismiss => '移除';

  @override
  String get federationRequestTitle => '配对请求';

  @override
  String federationRequestReceived(String ago) {
    return '$ago通过发现网络收到';
  }

  @override
  String federationRequestSent(String ago) {
    return '$ago通过发现网络发出';
  }

  @override
  String get federationShareBack => '回共享';

  @override
  String get federationShareBackNote => '接受之前不会有任何变化。对方将获得你勾选的曲库（至少一个）的只读访问权限。';

  @override
  String get federationTheirLimits => '对方的限制';

  @override
  String get federationChange => '更改';

  @override
  String get federationRequestIgnored => '来自此服务器的请求将被忽略 7 天';

  @override
  String get federationRequestAccepted => '已接受请求';

  @override
  String get federationRequestDeclined => '已拒绝请求';

  @override
  String get federationRequestCancelled => '已撤回请求';

  @override
  String get federationRequestActionFailed => '无法更新请求。';

  @override
  String get federationTicketNameLabel => '这是给谁的？';

  @override
  String get federationTicketNameHint => '只有你能看到这个名字 — 它用来在列表中标记票据。';

  @override
  String get federationLibrariesTheyCanRead => '对方可读取的曲库';

  @override
  String get federationLimitsSection => '限制';

  @override
  String get federationExactNumbers => '精确数值';

  @override
  String get federationPresets => '预设';

  @override
  String get federationLimitStreamRate => '串流速率';

  @override
  String get federationLimitPerDay => '每日';

  @override
  String get federationLimitStreams => '同时串流数';

  @override
  String get federationLimitExpires => '有效期';

  @override
  String get federationUnlimited => '不限';

  @override
  String get federationNever => '永不';

  @override
  String federationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String get federationOneYear => '1 年';

  @override
  String federationKbps(int n) {
    return '$n kbps';
  }

  @override
  String federationMbps(int n) {
    return '$n Mbps';
  }

  @override
  String federationMbPerDay(int n) {
    return '每日 $n MB';
  }

  @override
  String federationGbPerDay(int n) {
    return '每日 $n GB';
  }

  @override
  String federationStreamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 路串流',
    );
    return '$_temp0';
  }

  @override
  String get federationNeverExpires => '永不过期';

  @override
  String federationExpiresIn(String when) {
    return '$when过期';
  }

  @override
  String get federationExpired => '已过期';

  @override
  String federationInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天后',
    );
    return '$_temp0';
  }

  @override
  String federationInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时后',
    );
    return '$_temp0';
  }

  @override
  String get federationStreamRateField => '串流速率（kbps，0 = 不限）';

  @override
  String get federationPerDayField => '每日配额（MB，0 = 不限）';

  @override
  String get federationStreamsField => '最大串流数（0 = 不限）';

  @override
  String get federationExpiresField => '有效天数（0 = 永不过期）';

  @override
  String get federationCreateTicket => '创建票据';

  @override
  String get federationMintFailed => '无法创建票据。';

  @override
  String get federationNoLibraries => '此服务器没有可共享的曲库。';

  @override
  String get federationTicketTitle => '你的票据';

  @override
  String federationTicketFor(String name) {
    return '给 $name 的票据';
  }

  @override
  String federationTicketReads(String libraries) {
    return '可读取 $libraries';
  }

  @override
  String get federationTicketQrHint => '在同一个房间？让对方扫描这个。';

  @override
  String get federationTicketWarning =>
      '持有此票据的任何人都能读取这些曲库，直到它被兑换或撤销。请通过私密渠道发送 — 第一个使用它的服务器将占有它。';

  @override
  String get federationCopyTicket => '复制票据';

  @override
  String get federationTicketCopied => '已复制票据';

  @override
  String get federationSendByText => '用短信发送…';

  @override
  String get federationTicketRevokeNote =>
      '随时可在“联合”中撤销。如果对方重装了，“重置兑换”可让票据再次被兑换。';

  @override
  String get federationTicketNotRunning => '联合端点未运行，所以还没有可发送的票据。开启联合后再回来。';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return '我把我的 mStream 音乐曲库共享给你 — $libraries，只读。在 mStream 应用中打开“联合 → 添加对等服务器”，粘贴这张票据：\n\n$ticket\n\n它只能用一次 — 我随时可以撤销。';
  }

  @override
  String get federationShareSubject => 'mStream 联合票据';

  @override
  String get federationKeyClaimed => '已兑换';

  @override
  String get federationKeyNotClaimed => '尚未兑换';

  @override
  String federationKeyTodayUsage(String amount) {
    return '今日 $amount';
  }

  @override
  String federationKeyLastUsed(String ago) {
    return '上次使用：$ago';
  }

  @override
  String get federationKeyNeverUsed => '从未使用';

  @override
  String federationKeyClaimedAgo(String ago) {
    return '兑换于$ago';
  }

  @override
  String get federationResetBinding => '重置兑换';

  @override
  String get federationResetBindingNote => '对方重装了？让票据可以再次兑换。';

  @override
  String get federationBindingReset => '票据可以再次兑换了';

  @override
  String get federationRevoke => '撤销';

  @override
  String federationRevokeConfirm(String name) {
    return '撤销这张票据？$name 将立即失去访问权限。';
  }

  @override
  String get federationRevoked => '已撤销票据';

  @override
  String get federationSaveLimits => '保存限制';

  @override
  String get federationLimitsSaved => '已保存限制';

  @override
  String get federationLimitsFailed => '无法保存限制。';

  @override
  String get federationSend => '发送';

  @override
  String get federationKeyTitle => '共享的曲库';

  @override
  String federationActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get federationTheirTicket => '对方的票据';

  @override
  String get federationScanQr => '扫描二维码';

  @override
  String get federationScannerTitle => '扫描联合票据';

  @override
  String get federationPaste => '粘贴';

  @override
  String get federationTicketPasted => '已从剪贴板粘贴。';

  @override
  String get federationNotATicket => '这看起来不像联合票据。';

  @override
  String get federationTicketTooNew => '这张票据来自比本应用更新的 mStream 版本。';

  @override
  String get federationTicketExpiredNote => '这张票据已过期。';

  @override
  String get federationDisplayName => '显示名称';

  @override
  String get federationDisplayNameHint => '可选 — 在服务器选择器中的显示方式。';

  @override
  String federationSharesLibraries(String libraries) {
    return '共享 $libraries';
  }

  @override
  String get federationSharesUnknown => '票据中未列出曲库';

  @override
  String federationValidUntil(String date) {
    return '有效期至 $date';
  }

  @override
  String federationAddPeerShowsUnder(String server) {
    return '将显示在 $server 之下';
  }

  @override
  String federationAddPeerReadOnly(String branch, String name) {
    return '只读 · 在选择器中显示为 $branch $name';
  }

  @override
  String get federationAddPeerDials => '你的服务器通过 iroh 连接它';

  @override
  String get federationAddPeerEncrypted => '端到端加密 · 无需端口转发';

  @override
  String get federationAddPeerNoTicket => '还没有票据？让对方用短信发一张给你。';

  @override
  String federationPeerAdded(String name) {
    return '已添加 $name';
  }

  @override
  String get federationAddPeerFailed => '无法添加对等服务器。';

  @override
  String get federationPeerAlreadyAdded => '这张票据已作为对等服务器添加。';

  @override
  String get federationLibrariesYouCanRead => '你可以读取的曲库';

  @override
  String get federationDiscoverySection => '发现';

  @override
  String get federationAskPeerSimilar => '向此对等服务器询问相似音乐';

  @override
  String get federationAskPeerSimilarNote => '会发送你正在听的内容 — 仅发给此对等服务器。';

  @override
  String get federationAutoDjSection => 'Auto DJ';

  @override
  String get federationAutoDjParticipates => '参与多服务器 Auto DJ';

  @override
  String get federationAutoDjParticipatesNote => 'DJ 开启时用它自己的曲库作答';

  @override
  String get federationAutoDjNotCandidate => '不是 Auto DJ 候选';

  @override
  String get federationAutoDjNotCandidateNote => '需要能回应音色选曲的服务器';

  @override
  String get federationTest => '测试';

  @override
  String get federationTesting => '测试中…';

  @override
  String get federationTestOk => '可达';

  @override
  String federationTestFailed(String error) {
    return '无法连接：$error';
  }

  @override
  String federationCheckedAgo(String ago) {
    return '检查于$ago';
  }

  @override
  String get federationNeverTested => '从未测试';

  @override
  String federationLastSeen(String ago) {
    return '上次在线：$ago';
  }

  @override
  String get federationBrowseLibrary => '浏览此曲库';

  @override
  String get federationRemovePeer => '移除对等服务器';

  @override
  String federationRemovePeerConfirm(String name) {
    return '移除 $name？从它加入队列的曲目将停止播放。';
  }

  @override
  String federationPeerRemoved(String name) {
    return '已移除 $name';
  }

  @override
  String get federationShowInPicker => '在服务器选择器中显示';

  @override
  String get federationShowInPickerNote => '隐藏的对等服务器仍会播放你从它们加入队列的内容。';

  @override
  String get federationPeerReadOnlyNote => '只读 — 播放列表和评分保留在你自己的服务器上。';

  @override
  String get federationPeerLibrariesUnknown => '尚未列出 — 打开一次以加载它的曲库。';

  @override
  String get federationTransportDirect => '从此手机直连的隧道';

  @override
  String get federationTransportRelay => '中继待命';

  @override
  String federationTransportViaParent(String parent) {
    return '经由 $parent';
  }

  @override
  String federationTransportViaParentTunnel(String parent) {
    return '经由 $parent 的隧道';
  }

  @override
  String get federationDiscoveryFailed => '无法更新发现设置。';

  @override
  String get agoJustNow => '刚刚';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String get browserP2pNetwork => 'P2P 网络';

  @override
  String get browserP2pOn => '已开启';

  @override
  String get browserP2pOff => '已关闭';

  @override
  String get p2pTitle => 'P2P 网络';

  @override
  String get p2pStatusConnected => '已连接';

  @override
  String p2pNeighborsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个邻居',
    );
    return '$_temp0';
  }

  @override
  String p2pAnnouncingAs(String name) {
    return '以 $name 的名义公布';
  }

  @override
  String get p2pStatusSearching => '已加入 · 等待邻居';

  @override
  String p2pStatusReconnecting(int n) {
    return '重新连接中 · 第 $n 次';
  }

  @override
  String get p2pStatusNotJoined => '尚未加入';

  @override
  String get p2pStatusOff => '已关闭';

  @override
  String get p2pStatusUnavailable => '此平台不可用';

  @override
  String get p2pStatNeighbors => '网状邻居';

  @override
  String get p2pStatNeighborsSub => '活跃的 gossip 连接';

  @override
  String get p2pStatKnown => '已知服务器';

  @override
  String p2pStatKnownSub(int hidden, int blocked) {
    return '$hidden 个已隐藏 · $blocked 个已屏蔽';
  }

  @override
  String get p2pStatHeld => '已保存的快照';

  @override
  String p2pStatHeldOf(int held, int max) {
    return '$held / $max';
  }

  @override
  String p2pStatStorage(String used, String cap) {
    return '$used / $cap';
  }

  @override
  String get p2pStatTracks => '对等曲目';

  @override
  String p2pStatTracksSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '可搜索，$count 个曲库',
    );
    return '$_temp0';
  }

  @override
  String get p2pActivity => '活动';

  @override
  String get p2pActivitySubtitle => '最新在前 · 仅保存在内存中';

  @override
  String get p2pActivityEmpty => '还没有内容 — 加入网状网络、获取快照、轮换和恢复等事件会在发生时显示在这里。';

  @override
  String get p2pActivityNote => '完整历史记录在服务器日志中。';

  @override
  String get p2pFromNetwork => '来自网络';

  @override
  String get p2pFindSimilar => '在网络中寻找相似音乐';

  @override
  String p2pFindSimilarSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '为正在播放的曲目打开“发现” · 来自 $count 个已下载曲库的线索',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying => '请先播放一首歌 — “发现”会跟随当前曲目';

  @override
  String get p2pNewArtistsOnlySub => '隐藏此曲库中已有艺术家的线索';

  @override
  String get p2pServersYouFollow => '你关注的服务器';

  @override
  String get p2pServersOnNetwork => '网络上的服务器';

  @override
  String get p2pNoServersYet => '还没有听到任何服务器 — 用朋友的票据添加一个，或者给 gossip 一分钟。';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已隐藏 $count 个服务器 — 模型不兼容',
    );
    return '$_temp0';
  }

  @override
  String get p2pShow => '显示';

  @override
  String get p2pHide => '隐藏';

  @override
  String get p2pBefriend => '添加好友服务器';

  @override
  String get p2pOnline => '在线';

  @override
  String p2pOfflineFor(String ago) {
    return '离线 $ago';
  }

  @override
  String p2pTracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首曲目',
    );
    return '$_temp0';
  }

  @override
  String p2pSeedersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个做种者',
    );
    return '$_temp0';
  }

  @override
  String get p2pChipDownloaded => '已下载';

  @override
  String get p2pChipUpdate => '有更新';

  @override
  String get p2pChipNotDownloaded => '未下载';

  @override
  String get p2pChipPinned => '已固定';

  @override
  String get p2pChipIncompatible => '模型不兼容';

  @override
  String get p2pChipFederated => '已联合';

  @override
  String get p2pChipTheyAsked => '对方向你请求';

  @override
  String get p2pChipRequestSent => '已发送请求';

  @override
  String get p2pSearchingTitle => '正在寻找对等服务器';

  @override
  String get p2pSearchingBody => '网状网络大约需要一分钟形成。此屏幕会自动更新。';

  @override
  String get p2pReconnectingTitle => '重新连接中';

  @override
  String p2pReconnectingBody(int n) {
    return 'sidecar 已退出，正在重新启动（第 $n 次）— 无需操作。';
  }

  @override
  String get p2pJoinTitle => '来自他人曲库的推荐';

  @override
  String get p2pWhatShared => '共享的内容';

  @override
  String get p2pShared1 => '仅含元数据的快照';

  @override
  String get p2pShared1Sub => '艺术家、标题、时长、声音指纹 — 绝不包含音频文件';

  @override
  String get p2pShared2 => '你服务器的名称和描述';

  @override
  String get p2pShared2Sub => '网络上所有人可见，默认公布到公共社区网络';

  @override
  String get p2pHowYouAppear => '你的显示方式';

  @override
  String get p2pServerName => '服务器名称';

  @override
  String get p2pServerNameHint => '在 18,000 个“mStream”旁边再叫“mStream”，是最先要改的东西。';

  @override
  String get p2pDescription => '描述';

  @override
  String get p2pDescriptionHint => '最多 180 个字符，可选。';

  @override
  String get p2pAlsoAcceptRequests => '同时接受联合请求';

  @override
  String get p2pAlsoAcceptRequestsSub => '共享曲库的邀请 — 每一个都需要你批准后才会共享。会开启联合。';

  @override
  String get p2pJoin => '加入网络';

  @override
  String get p2pJoining => '加入中…';

  @override
  String get p2pJoined => '已加入发现网络 — 给网状网络一分钟时间。';

  @override
  String p2pJoinFailed(String error) {
    return '无法加入网络：$error';
  }

  @override
  String p2pInboxFailed(String error) {
    return '发现已开启，但请求收件箱未能启动：$error';
  }

  @override
  String get p2pUnavailableNote =>
      '未找到此平台的 p2p-sidecar 二进制文件，也没有可下载的版本 — 网络不可用。';

  @override
  String get p2pWillDownloadNote => 'sidecar 尚未安装；加入时会先下载。';

  @override
  String get p2pAdminOnlyNote => '只有服务器管理员可以加入。';

  @override
  String p2pMemberOffNote(String server) {
    return '$server 上的发现网络已关闭。其管理员可以加入。';
  }

  @override
  String p2pMemberNote(String server) {
    return '加入、邀请和快照管理由管理员负责。以管理员身份登录 $server 即可在这里管理网络。';
  }

  @override
  String get p2pSnapshotSection => '快照';

  @override
  String p2pDownloadedSize(String size) {
    return '已下载 · $size';
  }

  @override
  String p2pSnapshotSeq(int seq) {
    return '快照 $seq';
  }

  @override
  String p2pNewerAnnounced(int seq) {
    return '已公布更新的版本（$seq）';
  }

  @override
  String get p2pNotDownloaded => '未下载';

  @override
  String get p2pNotDownloadedSub => '下载后即可在“发现”中搜索';

  @override
  String get p2pDownload => '下载';

  @override
  String get p2pUpdate => '更新';

  @override
  String get p2pDownloading => '下载中…';

  @override
  String get p2pDownloaded => '快照已下载';

  @override
  String p2pDownloadFailed(String error) {
    return '无法下载快照：$error';
  }

  @override
  String get p2pPin => '固定此快照';

  @override
  String p2pPinSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '轮换会在 $count 天后释放最少使用的快照；固定的快照会保留。',
    );
    return '$_temp0';
  }

  @override
  String get p2pPinSubNoRotation => '轮换已关闭；固定的快照在空间不足时也会保留。';

  @override
  String get p2pRemoveSnapshot => '移除快照';

  @override
  String get p2pSnapshotRemoved => '快照已移除';

  @override
  String get p2pHeldSince => '保存自';

  @override
  String get p2pTracksLabel => '曲目';

  @override
  String get p2pSeedersLabel => '做种者';

  @override
  String get p2pSeedersSub => '正在提供快照';

  @override
  String get p2pFederatedWithYou => '已与你联合';

  @override
  String get p2pFederatedWithYouSub => '打开“联合”查看你们互相读取的内容';

  @override
  String get p2pTheyAskedYou => '对方请求联合';

  @override
  String get p2pTheyAskedYouSub => '在“联合”中查看请求';

  @override
  String get p2pRequestSentTitle => '请求已发送';

  @override
  String get p2pRequestSentSub => '等待对方 · 在“联合”中跟踪';

  @override
  String get p2pAskToFederate => '请求共享曲库';

  @override
  String get p2pAskToFederateSub => '通过网络发送请求 — 现在不会有任何变化';

  @override
  String get p2pOpen => '打开';

  @override
  String get p2pReview => '查看';

  @override
  String get p2pForget => '忘记此服务器';

  @override
  String get p2pForgetSub => '离线且未下载任何内容；再次听到时会回来';

  @override
  String p2pForgotten(String name) {
    return '已忘记 $name';
  }

  @override
  String get p2pBlockServer => '屏蔽服务器';

  @override
  String p2pBlockConfirm(String name) {
    return '屏蔽 $name？将忽略其公布并移除其快照。';
  }

  @override
  String p2pBlocked(String name) {
    return '已屏蔽 $name';
  }

  @override
  String get p2pUnblock => '取消屏蔽';

  @override
  String get p2pUnblocked => '已取消屏蔽服务器';

  @override
  String get p2pIncompatibleNote => '嵌入模型不兼容 — 其曲库无法用于此服务器的相似搜索。';

  @override
  String get p2pCompatible => '模型兼容';

  @override
  String get p2pModelUnknown => '模型未知';

  @override
  String get p2pNoDescription => '没有描述。';

  @override
  String get p2pUnnamedServer => '未命名服务器';

  @override
  String get p2pFederateTitle => '请求联合';

  @override
  String get p2pFederateNote =>
      '通过发现网络发送请求。现在不会交换任何访问权限 — 对方会看到你的名称、消息和提供的内容；只有对方接受后才会共享曲库。';

  @override
  String get p2pMessage => '消息';

  @override
  String p2pMessageHint(int n) {
    return '可选 · $n / 500';
  }

  @override
  String get p2pShareBackLibraries => '对方接受后你将回共享的曲库';

  @override
  String get p2pShareBackNote => '全部取消勾选则为单向请求 — 你只读取对方的曲库。';

  @override
  String get p2pSendRequest => '发送请求';

  @override
  String get p2pRequestSent => '请求已发送 — 在“联合”中跟踪';

  @override
  String p2pRequestFailed(String error) {
    return '无法发送请求：$error';
  }

  @override
  String get p2pTheirTicket => '对方的票据';

  @override
  String get p2pTheirTicketHint => '朋友可以在其 P2P 网络屏幕的“邀请朋友”下找到自己的票据。';

  @override
  String get p2pTicketPasted => '已从剪贴板粘贴。';

  @override
  String get p2pRememberFriend => '记住此朋友';

  @override
  String get p2pRememberFriendSub => '保存到服务器配置中，重启后友谊依然保留。';

  @override
  String get p2pJoinFriend => '加入';

  @override
  String get p2pJoinedFriend => '已加入 — 网状网络会在一分钟内形成';

  @override
  String p2pJoinFriendFailed(String error) {
    return '无法加入：$error';
  }

  @override
  String get p2pNotATicket => '这看起来不像端点票据。';

  @override
  String get p2pScanQr => '扫描二维码';

  @override
  String get p2pScannerTitle => '扫描网络票据';

  @override
  String get p2pInviteFriend => '邀请朋友';

  @override
  String p2pYourTicketNote(String name) {
    return '你的票据 — 朋友在手机上粘贴到这里即可添加 $name。这是一个地址，不是凭据。';
  }

  @override
  String get p2pTicketCopied => '已复制票据';

  @override
  String p2pShareMessage(String ticket) {
    return '在发现网络上添加我的 mStream 服务器 — 在 mStream 应用中打开“P2P 网络 → 添加好友服务器”并粘贴这张票据：\n\n$ticket';
  }

  @override
  String get p2pShareSubject => 'mStream 发现网络票据';

  @override
  String get p2pTicketNotReady => 'sidecar 尚未运行，所以还没有可分享的票据。';

  @override
  String get p2pSettingsTitle => '网络设置';

  @override
  String get p2pSwitchTitle => '发现网络';

  @override
  String get p2pSwitchSub => '向网络公布仅含元数据的快照。关闭即退出 — 收集的数据保留在本地。';

  @override
  String get p2pLeaveConfirm => '退出发现网络？你的服务器将停止公布和下载快照。本地发现功能继续可用。';

  @override
  String get p2pLeave => '退出';

  @override
  String get p2pLeft => '已退出发现网络';

  @override
  String p2pLeaveFailed(String error) {
    return '无法退出网络：$error';
  }

  @override
  String get p2pEditIdentity => '名称和描述';

  @override
  String get p2pIdentitySaved => '已保存 — 已向网络公布';

  @override
  String p2pSaveFailed(String error) {
    return '无法保存：$error';
  }

  @override
  String get p2pSnapshotsSection => '快照';

  @override
  String get p2pAutoDownload => '自动下载上限';

  @override
  String p2pServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个服务器',
    );
    return '$_temp0';
  }

  @override
  String get p2pStorageCap => '存储上限';

  @override
  String get p2pRotate => '轮换下载';

  @override
  String get p2pForgetOffline => '忘记离线服务器';

  @override
  String get p2pMeshSection => '网状网络';

  @override
  String get p2pCommunitySeeds => '社区种子';

  @override
  String get p2pCommunitySeedsOn => '通过公共种子服务器引导';

  @override
  String get p2pCommunitySeedsOff => '已关闭 — 仅好友服务器；在服务器配置中设置';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个已屏蔽的服务器',
      zero: '没有已屏蔽的服务器',
    );
    return '$_temp0';
  }

  @override
  String get p2pBlockedSub => '忽略其公布，绝不获取其快照';

  @override
  String get p2pBlockedTitle => '已屏蔽的服务器';

  @override
  String get p2pSaved => '已保存';

  @override
  String get p2pOff => '关闭';

  @override
  String get p2pSave => '保存';

  @override
  String get p2pSearchServers => '搜索服务器 — 名称或描述';

  @override
  String federationInboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个联合请求待处理',
    );
    return '$_temp0';
  }

  @override
  String get federationInboxBannerSub => '点按以接受或拒绝';

  @override
  String federationInboxNotificationTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 个联合请求待处理',
    );
    return '$_temp0';
  }

  @override
  String federationInboxNotificationBody(String server) {
    return '来自 $server。打开以接受或拒绝。';
  }

  @override
  String get federationInboxChannelName => '联合请求';

  @override
  String get federationInboxChannelDescription => '你的某台服务器收到了共享媒体库的请求';

  @override
  String get federationNotifyTitle => '有请求时通知我';

  @override
  String get federationNotifySubtitle => '应用打开或播放时收到请求，会在手机上发出通知';
}
