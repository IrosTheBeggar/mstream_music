// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystemDefault => 'Padrão do sistema';

  @override
  String get settingsLanguageSubtitle =>
      'O idioma de exibição do app. \"Padrão do sistema\" segue o seu dispositivo.';

  @override
  String couldNotOpen(String url) {
    return 'Não foi possível abrir $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
      zero: 'Nenhuma faixa',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Redefinir';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get tapAddToQueue => 'Adicionar à fila';

  @override
  String get tapPlayFromHere => 'Tocar a partir daqui';

  @override
  String get tapAppendAndJump => 'Adicionar e tocar';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Shaders';

  @override
  String get visualizerSourceSynthesized => 'Sintetizado';

  @override
  String get visualizerSourceReal => 'Áudio real';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String downloadProgress(String progress) {
    return 'progresso: $progress%';
  }

  @override
  String get songInfoTitle => 'Informações da música';

  @override
  String get eqTitle => 'Equalizador';

  @override
  String get eqOnlyAndroid => 'O equalizador só está disponível no Android.';

  @override
  String get eqNeedsPlayback =>
      'Inicie uma música para configurar o equalizador.\n\nO equalizador nativo do Android é inicializado junto com a sessão de áudio, então é preciso ter a reprodução ativa antes de conseguir ler o layout das bandas.';

  @override
  String eqInitFailed(String error) {
    return 'Não foi possível inicializar o equalizador:\n$error';
  }

  @override
  String get eqNoBands =>
      'Nenhuma banda de equalização informada pelo driver de áudio deste dispositivo.';

  @override
  String get eqEnabledOn => 'Ligado — ganhos aplicados à reprodução';

  @override
  String get eqEnabledOff => 'Desligado — modo bypass';

  @override
  String get cancel => 'Cancelar';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get openSettings => 'Abrir configurações';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsSectionAppearance => 'Aparência';

  @override
  String get settingsSectionPlayback => 'Reprodução';

  @override
  String get settingsSectionBrowse => 'Navegar';

  @override
  String get settingsSectionAbout => 'Sobre';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSubtitleVelvet =>
      'Azul-marinho e roxo — o tema escuro característico.';

  @override
  String get themeSubtitleDark => 'Escuro neutro com detalhes em âmbar.';

  @override
  String get themeSubtitleLight =>
      'Corpo claro com barra superior escura e detalhes em âmbar — combina com o tema antigo.';

  @override
  String get settingsTranscode => 'Transcodificar áudio';

  @override
  String get settingsTranscodeSubtitle =>
      'Transmite uma cópia transcodificada do servidor (arquivos menores, início um pouco mais lento). Desligado, toca os arquivos originais.';

  @override
  String get settingsTapBehavior => 'Ao tocar em uma música';

  @override
  String get tapSubtitleAddToQueue =>
      'Tocar em uma música a adiciona à fila. Se a fila estiver vazia, a reprodução começa automaticamente.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Tocar em uma música substitui a fila pelas músicas da visualização atual e inicia a reprodução pela música tocada.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Tocar em uma música a adiciona à fila e pula a reprodução para ela, interrompendo o que estava tocando.';

  @override
  String get settingsEqSubtitle =>
      'Ajuste graves, médios e agudos. Apenas no Android.';

  @override
  String get settingsVisualizerEngine => 'Motor do visualizador';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Predefinições do Milkdrop via projectM (padrão). Efeitos mais ricos, mais pesados para a GPU.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Shaders de fragmento no estilo Shadertoy. Mais leves e modulares — coloque arquivos .glsl em assets/shaders/ para ampliar o catálogo.';

  @override
  String get settingsVisualizerSource => 'Fonte de áudio do visualizador';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'Padrão. O visualizador reage apenas ao tempo da reprodução — não exige permissão de microfone.';

  @override
  String get visualizerSourceSubtitleReal =>
      'O visualizador reage à saída de áudio real. Exige a permissão RECORD_AUDIO no Android.';

  @override
  String get settingsAlbumGrid => 'Visualização em grade de álbuns';

  @override
  String get settingsAlbumGridSubtitle =>
      'Mostra os álbuns como uma grade de cartões com capas em vez de uma lista simples.';

  @override
  String get settingsFileMetadata =>
      'Ler metadados das músicas no explorador de arquivos';

  @override
  String get settingsFileMetadataSubtitle =>
      'Busca título, artista e capa de cada música ao navegar pelos arquivos do servidor. Desligado, mostra os nomes brutos dos arquivos (mais rápido em pastas enormes).';

  @override
  String get settingsLetterStrip => 'Limite do scrubber de letras';

  @override
  String get settingsLetterStripSubtitle =>
      'Mostra a barra de navegação rápida A-Z quando uma lista tiver esta quantidade de itens ou mais. Abaixo disso, a barra fica oculta e nomes longos de pastas/arquivos quebram em várias linhas em vez de serem cortados. Defina 0 para sempre mostrar a barra.';

  @override
  String get settingsReset => 'Restaurar padrões';

  @override
  String get settingsResetSubtitle =>
      'Restaura todas as configurações desta tela aos valores padrão. Servidores e downloads não são afetados.';

  @override
  String get settingsResetDone => 'Configurações restauradas aos padrões';

  @override
  String get realAudioDialogTitle => 'Usar áudio real?';

  @override
  String get realAudioDialogBody =>
      'O modo de áudio real lê a forma de onda da música que o seu celular está tocando para que o visualizador possa reagir a ela. O Android exige a permissão RECORD_AUDIO para isso — o app não grava nem envia áudio a lugar nenhum. Você pode voltar para o sintetizado a qualquer momento.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Permissão negada permanentemente. Ative-a nas configurações do sistema para usar áudio real.';

  @override
  String get realAudioPermDenied =>
      'Permissão negada. Mantendo o áudio sintetizado.';

  @override
  String get visualizerTapHint =>
      'Toque = próxima predefinição · pressione e segure para fechar';

  @override
  String get visualizerFailed => 'Falha ao iniciar o visualizador';

  @override
  String get visualizerBringingUp => 'Inicializando o renderizador…';

  @override
  String get visualizerReady => 'Visualizador pronto';

  @override
  String get visualizerBridgeFailed => 'Falha ao iniciar a ponte';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Fonte de áudio: $source';
  }

  @override
  String get visualizerTapToClose => 'Toque em qualquer lugar para fechar';

  @override
  String get visualizerUnsupported =>
      'O visualizador só é compatível com o Android no momento.';

  @override
  String get aboutTitle => 'Sobre';

  @override
  String aboutBuiltBy(String name) {
    return 'Criado por $name';
  }

  @override
  String get linkDiscordSubtitle => 'Bate-papo da comunidade';

  @override
  String get linkGithubSubtitle => 'Código-fonte do servidor mStream';

  @override
  String get linkHomepageSubtitle => 'Página do projeto';

  @override
  String get aboutAttributions => 'Créditos';

  @override
  String get aboutAttributionsSubtitle =>
      'Licença, créditos de shaders e avisos de código aberto.';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Excluir';

  @override
  String get edit => 'Editar';

  @override
  String get info => 'Informações';

  @override
  String get makeDefault => 'Tornar padrão';

  @override
  String get goBack => 'Voltar';

  @override
  String get play => 'Tocar';

  @override
  String get playAll => 'Tocar tudo';

  @override
  String get rename => 'Renomear';

  @override
  String get create => 'Criar';

  @override
  String get copy => 'Copiar';

  @override
  String get done => 'Concluído';

  @override
  String get copiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get attributionsTitle => 'Créditos';

  @override
  String get attributionsSectionLicense => 'Licença';

  @override
  String get attributionsSectionShaders => 'Shaders do visualizador';

  @override
  String get attributionsSectionLibraries => 'Bibliotecas nativas';

  @override
  String get attributionsSectionEverythingElse => 'Tudo o mais';

  @override
  String get attributionsLicenseBody =>
      'Software livre sob a GNU General Public License v3.0. Você pode usá-lo, estudá-lo, compartilhá-lo e modificá-lo sob esses termos.';

  @override
  String get attributionsPackages => 'Licenças de pacotes de código aberto';

  @override
  String get attributionsPackagesSubtitle =>
      'Textos completos das licenças de todos os pacotes Flutter/Dart incluídos.';

  @override
  String get manageServersTitle => 'Gerenciar servidores';

  @override
  String get manageServerInfo => 'Informações do servidor';

  @override
  String get manageServerDownloadFolder => 'Pasta de download:';

  @override
  String get manageServerCopyPath => 'Copiar caminho de download';

  @override
  String get manageServerPathCopied =>
      'Caminho copiado para a área de transferência';

  @override
  String get confirmRemoveServerTitle => 'Confirmar remoção do servidor';

  @override
  String get removeSyncedFiles =>
      'Remover arquivos sincronizados do dispositivo?';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistsNew => 'Nova playlist';

  @override
  String get playlistsEmptyTitle => 'Nenhuma playlist ainda';

  @override
  String get playlistsEmptyBody =>
      'Crie uma com o botão Nova playlist e depois use o gesto de deslizar Adicionar à playlist na fila para preenchê-la.';

  @override
  String get playlistNameHint => 'Nome';

  @override
  String get playlistsRename => 'Renomear playlist';

  @override
  String get playlistFallbackTitle => 'Playlist';

  @override
  String get playlistEmptyDetail =>
      'A playlist está vazia.\nAdicione faixas pela fila.';

  @override
  String get shareEmptyTitle => 'Fila vazia';

  @override
  String get shareEmptyBody => 'Adicione músicas à fila antes de compartilhar.';

  @override
  String get shareBlockedTitle => 'Não é possível compartilhar esta fila';

  @override
  String get shareLocalOnlyBody =>
      'A fila contém músicas que estão apenas neste dispositivo (não em nenhum servidor). O compartilhamento só funciona quando todas as músicas da fila vêm de um único servidor.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'A fila mistura músicas de $count servidores ($names). O compartilhamento só funciona quando todas as músicas vêm de um único servidor.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'O servidor \"$name\" não está mais na sua lista de servidores. Adicione-o novamente para compartilhar a fila dele.';
  }

  @override
  String get shareTitle => 'Compartilhar playlist';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$_temp0 de $url';
  }

  @override
  String get shareLinkExpires => 'O link expira';

  @override
  String get shareExpireNever => 'Nunca';

  @override
  String get shareExpire1Day => 'Após 1 dia';

  @override
  String get shareExpire7Days => 'Após 7 dias';

  @override
  String get shareExpire30Days => 'Após 30 dias';

  @override
  String get shareAction => 'Compartilhar';

  @override
  String get shareDoneTitle => 'Playlist compartilhada';

  @override
  String get shareDoneBody =>
      'Qualquer pessoa com este link pode tocar a fila:';

  @override
  String get save => 'Salvar';

  @override
  String get start => 'Iniciar';

  @override
  String get addServerTitle => 'Adicionar servidor';

  @override
  String get editServerTitle => 'Editar servidor';

  @override
  String get fieldServerUrl => 'URL do servidor';

  @override
  String get fieldPublicAccess => 'Acesso público';

  @override
  String get publicAccessSubtitle =>
      'O servidor é acessível publicamente — não é preciso usuário nem senha.';

  @override
  String get fieldUsername => 'Usuário';

  @override
  String get fieldPassword => 'Senha';

  @override
  String get fieldSdCard => 'Baixar para o cartão SD';

  @override
  String get sdCardSubtitle =>
      'Salva a música baixada no cartão SD removível em vez do armazenamento interno.';

  @override
  String get testConnectionButton => 'Testar conexão';

  @override
  String get testing => 'Testando…';

  @override
  String get connecting => 'Conectando…';

  @override
  String get validatorUrlNeeded => 'A URL do servidor é necessária';

  @override
  String get validatorUrlParse => 'Não foi possível interpretar a URL';

  @override
  String get testEnterUrl => 'Informe uma URL de servidor primeiro.';

  @override
  String get testParseUrl => 'Não foi possível interpretar a URL.';

  @override
  String get testCouldNotConnect =>
      'Não foi possível conectar. Verifique a URL e tente novamente.';

  @override
  String get testTimedOut => 'Tempo de conexão esgotado.';

  @override
  String get connectFailedSnack =>
      'Não foi possível conectar ao servidor. Verifique a URL e tente novamente.';

  @override
  String get connectionSuccessful => 'Conexão bem-sucedida!';

  @override
  String get couldNotReachServer =>
      'Não foi possível acessar o servidor. Se ele exigir login, desative o \"Acesso público\" e adicione as credenciais.';

  @override
  String get failedToLogin => 'Falha ao fazer login';

  @override
  String testConnected(String version) {
    return 'Conectado — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Não foi possível conectar: $error';
  }

  @override
  String get sleepTimerTitle => 'Temporizador para dormir';

  @override
  String get sleepTimerHint =>
      'Escolha uma duração para pausar a reprodução depois.';

  @override
  String get sleepTimerCustom => 'Personalizado';

  @override
  String get sleepTimerCustomHint => 'minutos (1–600)';

  @override
  String get sleepTimerCancel => 'Cancelar temporizador';

  @override
  String get sleepTimerInvalid => 'Informe um número entre 1 e 600 minutos';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Pausa em $time';
  }

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String sleepTimerSet(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Temporizador definido para $minutes minutos',
      one: 'Temporizador definido para 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Adicionar';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String get autoDjAddServerFirst => 'Adicione um servidor primeiro.';

  @override
  String get autoDjSectionServer => 'Servidor';

  @override
  String get autoDjSectionSources => 'Fontes';

  @override
  String get autoDjSectionContinuity => 'Continuidade';

  @override
  String get autoDjSectionFilters => 'Filtros';

  @override
  String get autoDjBpmTitle => 'Continuidade de BPM';

  @override
  String get autoDjBpmSubtitle =>
      'Prefere escolhas dentro de uma faixa de andamento da música atual. Considera a equivalência de meio/dobro de andamento.';

  @override
  String get autoDjTolerance => 'Tolerância';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Mixagem harmônica';

  @override
  String get autoDjHarmonicSubtitle =>
      'Prefere escolhas em tons que combinam bem com a música travada (vizinhos na roda Camelot).';

  @override
  String get autoDjStatusOn => 'O Auto DJ está ligado';

  @override
  String get autoDjStatusOff => 'O Auto DJ está desligado';

  @override
  String get autoDjStatusOffDetail =>
      'Toque abaixo para iniciar. A biblioteca do servidor atual será usada.';

  @override
  String get autoDjStart => 'Iniciar Auto DJ';

  @override
  String get autoDjStop => 'Parar Auto DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'As músicas são escolhidas de $url quando a fila fica curta.';
  }

  @override
  String get autoDjActiveSource => 'Fonte ativa';

  @override
  String get autoDjActiveSourceTap => 'Fonte ativa — toque para trocar';

  @override
  String get autoDjSwitch => 'Trocar';

  @override
  String get autoDjOneSourceRequired => 'É necessária pelo menos uma fonte.';

  @override
  String get autoDjMinRating => 'Avaliação mínima';

  @override
  String get autoDjMinRatingSubtitle =>
      'Escolhe apenas músicas com esta avaliação ou superior.';

  @override
  String get autoDjRatingAny => 'Qualquer';

  @override
  String get autoDjGenreTitle => 'Filtro de gênero';

  @override
  String get autoDjGenreSubtitle =>
      'A lista de permissões toca só faixas correspondentes; a lista de bloqueios as ignora.';

  @override
  String get autoDjWhitelist => 'Lista de permissões';

  @override
  String get autoDjBlacklist => 'Lista de bloqueios';

  @override
  String get autoDjNoGenres =>
      'Nenhum gênero selecionado. Toque em \"Escolher gêneros\" para selecionar.';

  @override
  String get autoDjPickGenres => 'Escolher gêneros';

  @override
  String get autoDjGenreLoadError => 'Não foi possível carregar os gêneros';

  @override
  String get autoDjKeywordTitle => 'Filtro de palavras-chave';

  @override
  String get autoDjKeywordSubtitle =>
      'Ignora escolhas cujo título, artista, álbum ou caminho contenha qualquer uma destas palavras.';

  @override
  String get autoDjNoKeywords =>
      'Nenhuma palavra-chave. Adicione palavras abaixo para começar a filtrar.';

  @override
  String get autoDjKeywordHint => 'ex.: \"live\" ou \"remix\"';

  @override
  String get autoDjSearchGenres => 'Pesquisar gêneros…';

  @override
  String get autoDjNoGenresOnServer =>
      'Nenhum gênero encontrado neste servidor.';

  @override
  String autoDjSelectedCount(int count) {
    return '$count selecionado(s)';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'Nenhum gênero corresponde a \"$query\".';
  }

  @override
  String get download => 'Baixar';

  @override
  String get addAll => 'Adicionar tudo';

  @override
  String get browserConfirmDeletePlaylist => 'Confirmar exclusão da playlist';

  @override
  String get browserConfirmDeleteFolder => 'Confirmar exclusão da pasta';

  @override
  String get browserSearchHint => 'Pesquisar no banco de dados';

  @override
  String browserDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads iniciados',
      one: '1 download iniciado',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas adicionadas à fila',
      one: '1 música adicionada à fila',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Navegador';

  @override
  String get tabQueue => 'Fila';

  @override
  String get drawerTagline => 'Streaming pessoal de música';

  @override
  String get mainFailedToConnect => 'Falha ao conectar ao servidor';

  @override
  String get mainQueueEmpty => 'A fila está vazia';

  @override
  String get visualizerTitle => 'Visualizador';

  @override
  String get mainClearQueue => 'Limpar fila';

  @override
  String get mainSync => 'Sincronizar';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas na fila',
      one: '1 faixa na fila',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ ativado';

  @override
  String get autoDjDisabled => 'Auto DJ desativado';

  @override
  String autoDjEnabledFor(String url) {
    return 'Auto DJ ativado para $url';
  }

  @override
  String get addToPlaylistTitle => 'Adicionar à playlist';

  @override
  String get addToPlaylistEmpty =>
      'Nenhuma playlist ainda — toque em + para criar uma.';

  @override
  String addedToPlaylist(String name) {
    return 'Adicionado a $name';
  }

  @override
  String get testConnectedSignedIn => 'Conectado — login efetuado com sucesso.';

  @override
  String get testSignInFailed =>
      'Servidor acessível, mas o login falhou — verifique seu usuário e senha.';

  @override
  String get browserFileExplorer => 'Explorador de arquivos';

  @override
  String get browserLocalFiles => 'Arquivos locais';

  @override
  String get browserPlaylists => 'Playlists';

  @override
  String get browserAlbums => 'Álbuns';

  @override
  String get browserArtists => 'Artistas';

  @override
  String get browserRecent => 'Recentes';

  @override
  String get browserRated => 'Avaliadas';

  @override
  String get browserSearch => 'Pesquisar';

  @override
  String get browserWelcomeTitle => 'Bem-vindo ao mStream';

  @override
  String get browserWelcomeSubtitle => 'Toque aqui para adicionar um servidor';

  @override
  String get settingsVisualizerKnobs => 'Controles de ajuste do visualizador';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Mostra controles deslizantes sobre o visualizador para ajustar a reatividade de áudio de cada shader. Apenas no motor de shaders.';

  @override
  String get visualizerTuningTitle => 'Ajuste';

  @override
  String get close => 'Fechar';
}
