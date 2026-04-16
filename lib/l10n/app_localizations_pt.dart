// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get tabExplore => 'Explorar';

  @override
  String get tabAddSpot => 'Adicionar spot';

  @override
  String get tabAccount => 'Conta';

  @override
  String get profileSettingsTitle => 'Definições';

  @override
  String get profileSettingsSubtitle => 'Idioma e locais do seu interesse';

  @override
  String get profileSettingsLanguageLabel => 'Idioma';

  @override
  String get profileSettingsLanguageDescription =>
      'Escolha um idioma ou use o do dispositivo.';

  @override
  String get profileLanguageSystemDefault => 'Idioma do dispositivo';

  @override
  String get profileLoadErrorDefault => 'Não foi possível carregar o perfil.';

  @override
  String get profileRefreshPage => 'Atualizar página';

  @override
  String get profileRetry => 'Tentar novamente';

  @override
  String get profileSignInTitle => 'Inicie sessão para aceder à sua conta';

  @override
  String get profileSignInSubtitle =>
      'Inicie sessão para gerir os seus spots e avaliar locais.';

  @override
  String get profileSignInButton => 'Iniciar sessão';

  @override
  String get profileOrDivider => 'OU';

  @override
  String get profileCreateAccount => 'Criar uma conta';

  @override
  String get profileDefaultDisplayName => 'Utilizador';

  @override
  String get profileViewEditSubtitle => 'Ver e editar o seu perfil';

  @override
  String get notificationsTitle => 'Notificações';

  @override
  String get notificationsSubtitle =>
      'Novos spots por perto, quem treina e outras novidades para si';

  @override
  String get notificationsEmptyTitle => 'Ainda não há notificações';

  @override
  String get notificationsEmptyBody =>
      'Quando acontecer algo que te diga respeito, aparecerá aqui.';

  @override
  String get notificationsLoadError =>
      'Não foi possível carregar as notificações.';

  @override
  String get notificationsTimeUnknown => 'Recentemente';

  @override
  String notificationsOpenSemantic(String title) {
    return 'Abrir notificação: $title';
  }

  @override
  String get profileModeratorSectionTitle => 'Moderador';

  @override
  String get profileModeratorToolsTitle => 'Ferramentas de moderação';

  @override
  String get profileModeratorToolsSubtitle =>
      'Rever e resolver relatórios de spots';

  @override
  String get profileAdminSectionTitle => 'Administrador';

  @override
  String get profileAdminToolsTitle => 'Ferramentas de administração';

  @override
  String get profileAdminToolsSubtitle =>
      'Gerir fontes e tarefas administrativas';

  @override
  String get profileSignOut => 'Terminar sessão';

  @override
  String get profileSignOutMessage =>
      'Tem a certeza de que quer terminar a sessão?';

  @override
  String get profileCancel => 'Cancelar';

  @override
  String get profileLocationAlertsTitle => 'Alertas de localização';

  @override
  String get profileLocationAlertsDescription =>
      'Controle que locais são usados para alertas nas proximidades, incluindo check-ins, novos spots e eventos futuros.';

  @override
  String get profileLocationAlertsShareLastKnownTitle =>
      'Utilizar a última localização conhecida';

  @override
  String get profileLocationAlertsShareLastKnownSubtitle =>
      'Guarde a última localização conhecida do seu dispositivo na nuvem para corresponder alertas nas proximidades.';

  @override
  String get profileLocationAlertsSavedLocationsTitle =>
      'Os meus locais de interesse';

  @override
  String get profileLocationAlertsAddLocationButton => 'Adicionar';

  @override
  String get profileLocationAlertsNoLocationsEnabledWarning =>
      'Não receberá notificações baseadas na localização até ativar «Utilizar a última localização conhecida» ou, pelo menos, um local guardado.';

  @override
  String get profileLocationAlertsEmptyState =>
      'Ainda não tem locais guardados. Adicione sítios como Casa ou Trabalho.';

  @override
  String get profileLocationAlertsDefaultLabel => 'Local guardado';

  @override
  String get profileLocationAlertsDisableTooltip => 'Desativar';

  @override
  String get profileLocationAlertsEnableTooltip => 'Ativar';

  @override
  String get profileLocationAlertsEditTooltip => 'Editar';

  @override
  String get profileLocationAlertsDeleteTooltip => 'Eliminar';

  @override
  String get profileLocationAlertsDeleteTitle => 'Eliminar local guardado?';

  @override
  String profileLocationAlertsDeleteMessage(String label) {
    return 'Tem a certeza de que quer eliminar $label?';
  }

  @override
  String get profileLocationAlertsDeleteConfirmButton => 'Eliminar';

  @override
  String get profileLocationAlertsDialogAddTitle => 'Adicionar local';

  @override
  String get profileLocationAlertsDialogEditTitle => 'Editar local';

  @override
  String get profileLocationAlertsLabelFieldLabel => 'Nome';

  @override
  String get profileLocationAlertsLabelFieldPlaceholder => 'Casa';

  @override
  String get profileLocationAlertsEnabledLabel => 'Ativo';

  @override
  String get profileLocationAlertsLabelRequired => 'Introduza um nome';

  @override
  String get profileLocationAlertsLocationRequired =>
      'Escolha uma localização no mapa';

  @override
  String get profileAboutIntro =>
      'Parkour·Spot é uma aplicação comunitária para descobrir e partilhar spots de parkour e freerunning em todo o mundo. Queremos tornar simples encontrar bons locais—onde quer que treines.';

  @override
  String get profileReadMore => 'Ler mais';

  @override
  String get profileAboutStoryBeforeName => 'Criada por ';

  @override
  String get profileAboutStoryAfterName =>
      ' a partir da comunidade de parkour de Utrecht, a app reúne conhecimento local de mapas urbanos e regionais existentes—estejam no Facebook, Instagram, sites ou apps antigas—para que bons dados de spots não se percam.';

  @override
  String get profileAboutMapMission =>
      'Este é o teu mapa. Adiciona novos spots, avalia os existentes e enriquece as fichas com detalhes. Quanto mais contribuímos, mais forte fica o conhecimento partilhado da comunidade.';

  @override
  String get profileAboutPrinciplesHeader => 'Os nossos princípios:';

  @override
  String get profileAboutPrincipleTransparency =>
      '• Transparência: podes explorar a app sem conta, e cada spot mostra que fontes externas contribuíram.';

  @override
  String get profileAboutPrinciplePortability =>
      '• Portabilidade: estamos a criar ferramentas de exportação para os dados de spots serem usados fora da app.';

  @override
  String get profileAboutPrincipleOpenSource =>
      '• Código aberto: a app é da comunidade, não depende de uma só pessoa.';

  @override
  String get profileAboutEnjoy =>
      'Boa descoberta e partilha de spots com Parkour.spot. Dúvidas ou ideias? Toca em contacto—adoramos ouvir-te.';

  @override
  String get profileCreditsBy => 'Grandes contribuições de ';

  @override
  String get profileCreditsDaphneArt => ' (arte), ';

  @override
  String get profileCreditsComma => ', ';

  @override
  String get profileCreditsEnd => ' e muitos outros.';

  @override
  String get profileViewSourceCode => 'Ver código-fonte';

  @override
  String get profileContactUs => 'Contacto';

  @override
  String get profileReportIssue => 'Reportar um problema';

  @override
  String get profileHelpTranslate => 'Ajude a traduzir a aplicação';

  @override
  String get profileInstallBannerTitle => 'Instalar a app Parkour·Spot';

  @override
  String get profileInstallBannerSubtitle =>
      'Experiência completa da aplicação';

  @override
  String get profileInstallDialogTitle => 'Instalar Parkour·Spot';

  @override
  String profileInstallIntro(String device) {
    return 'Para instalar o Parkour·Spot no seu $device:';
  }

  @override
  String get profileInstallDeviceIphone => 'iPhone';

  @override
  String get profileInstallDeviceAndroid => 'dispositivo Android';

  @override
  String get profileInstallIosStep1 =>
      'Toque no botão Partilhar na parte inferior do ecrã';

  @override
  String get profileInstallIosStep2 =>
      'Desça e toque em «Adicionar ao ecrã principal»';

  @override
  String get profileInstallIosStep3 =>
      'Toque em «Adicionar» no canto superior direito';

  @override
  String get profileInstallIosStep4 => 'A app aparecerá no ecrã principal!';

  @override
  String get profileInstallAndroidStep1 =>
      'Toque no menu Mais (⋯) no canto superior direito';

  @override
  String get profileInstallAndroidStep2 =>
      'Toque em «Adicionar ao ecrã inicial»';

  @override
  String get profileInstallAndroidStep3 => 'Toque em «Instalar aplicação»';

  @override
  String get profileInstallAndroidStep4 => 'A app aparecerá no ecrã inicial!';

  @override
  String get profileInstallGotIt => 'Percebi';

  @override
  String get exploreMetaDefaultTitle => 'Parkour·Spot';

  @override
  String get exploreMetaDefaultDescription =>
      'Descobre, mapeia e partilha os melhores spots de parkour no mundo com fotos da comunidade, avaliações e dicas locais para o teu próximo treino.';

  @override
  String exploreMetaTitleCityCountry(String city, String country) {
    return 'Melhores spots de parkour em $city, $country';
  }

  @override
  String exploreMetaDescriptionCityCountry(String city, String country) {
    return 'Descobre os melhores spots de parkour em $city, $country. Encontra locais de treino, partilha os teus favoritos e conecta-te à comunidade.';
  }

  @override
  String exploreMetaTitleCountry(String country) {
    return 'Melhores spots de parkour em $country';
  }

  @override
  String exploreMetaDescriptionCountry(String country) {
    return 'Descobre os melhores spots de parkour em $country. Encontra locais de treino, partilha os teus favoritos e conecta-te à comunidade.';
  }

  @override
  String get exploreAddSpotTitle => 'Adicionar novo spot';

  @override
  String get exploreAddSpotSubtitle =>
      'Partilha os teus spots de parkour favoritos com a comunidade';

  @override
  String get exploreSignInToAddSpot => 'Inicia sessão para adicionar um spot';

  @override
  String get exploreLoadingProfile => 'A carregar o teu perfil…';

  @override
  String get exploreSearchHint => 'Pesquisar localização ou spot…';

  @override
  String get exploreFilterBy => 'Filtrar por';

  @override
  String get exploreFilterAmenities => 'Comodidades';

  @override
  String get exploreFilterSources => 'Fontes';

  @override
  String get exploreSpotAccessTitle => 'Acesso ao spot';

  @override
  String get exploreSpotAccessSubtitle => 'Filtrar spots por nível de acesso';

  @override
  String get exploreFilterAny => 'Qualquer';

  @override
  String get exploreSpotFacilitiesTitle => 'Instalações do spot';

  @override
  String get exploreSpotFacilitiesSubtitle =>
      'Mostrar spots com estas comodidades';

  @override
  String get exploreAttributesTitle => 'Com qualquer um destes atributos';

  @override
  String get exploreAttributesSubtitle =>
      'Filtrar spots que tenham qualquer uma das competências ou funcionalidades selecionadas';

  @override
  String get exploreGoodForSegment => 'Bom para';

  @override
  String get exploreSpotFeaturesSegment => 'Características do spot';

  @override
  String get exploreSpotSourceLabel => 'Fonte do spot';

  @override
  String get exploreSourcesLoadError => 'Falha ao carregar fontes';

  @override
  String get exploreAllSources => 'Todas as fontes';

  @override
  String get exploreParkourSpotNative => 'Parkour·Spot (nativo)';

  @override
  String get exploreAllFolders => 'Todas as pastas';

  @override
  String exploreLocationError(String error) {
    return 'Erro ao obter localização: $error';
  }

  @override
  String get exploreCurrentLocationSnackbar => 'Esta é a tua localização atual';

  @override
  String get exploreCloseTooltip => 'Fechar';

  @override
  String get exploreClearSearchTooltip => 'Limpar';

  @override
  String get exploreFiltersTooltip => 'Filtros';

  @override
  String get exploreFindingLocation => 'A localizar…';

  @override
  String get exploreAddSpotHereTitle => 'Adicionar spot neste local?';

  @override
  String exploreMapRankedTotalBar(int total) {
    return '$total spots';
  }

  @override
  String exploreMapSpotsFoundLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots encontrados',
      one: '1 spot encontrado',
    );
    return '$_temp0';
  }

  @override
  String exploreMapBestShownParenthetical(int count) {
    return ' ($count melhores mostrados)';
  }

  @override
  String get exploreNoSpotsSearch => 'Nenhum spot encontrado';

  @override
  String get exploreNoSpotsArea => 'Nenhum spot nesta área';

  @override
  String get exploreNoSpotsSearchHint => 'Tenta ajustar os termos de pesquisa';

  @override
  String get exploreNoSpotsMapHint => 'Move o mapa para explorar outras áreas';

  @override
  String get exploreRefreshMapTooltip => 'Atualizar spots na vista atual';

  @override
  String get exploreSwitchToMap => 'Ver mapa';

  @override
  String get exploreSwitchToSatellite => 'Ver satélite';

  @override
  String get exploreLocationPermissionDenied =>
      'Permissão de localização recusada';

  @override
  String get exploreCenterOnMyLocation => 'Centrar na minha localização';

  @override
  String get exploreFiltersDialogTitle => 'Filtros';

  @override
  String get exploreClearFilters => 'Limpar';

  @override
  String get exploreApplyFilters => 'Aplicar';

  @override
  String exploreSpotCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots',
      one: '1 spot',
    );
    return '$_temp0';
  }

  @override
  String get explorePwaBannerInstall => 'Instalar';

  @override
  String get addSpotPickImagesFailed =>
      'Não foi possível escolher as imagens. Tenta novamente.';

  @override
  String get addSpotTakePhotoFailed =>
      'Não foi possível tirar a foto. Tenta novamente.';

  @override
  String get addSpotNeedPhoto => 'Carrega pelo menos uma foto do spot';

  @override
  String get addSpotNeedLocation =>
      'Espera pela localização ou escolhe um ponto no mapa';

  @override
  String addSpotCreateError(String error) {
    return 'Erro ao criar o spot: $error';
  }

  @override
  String get addSpotNameLabel => 'Nome do spot *';

  @override
  String get addSpotNameRequired => 'Introduz um nome para o spot';

  @override
  String get addSpotDescriptionLabel => 'Descrição *';

  @override
  String get addSpotDescriptionRequired => 'Introduz uma descrição';

  @override
  String get addSpotDescriptionMinLength =>
      'A descrição deve ter pelo menos 10 caracteres';

  @override
  String get addSpotCreating => 'A criar spot…';

  @override
  String get addSpotCreateButton => 'Criar spot';

  @override
  String get addSpotLocationSectionTitle => 'Escolher localização do spot';

  @override
  String get addSpotGettingLocation => 'A obter a tua localização…';

  @override
  String get addSpotLocationNotAvailable => 'Localização indisponível';

  @override
  String get addSpotPickLocationHint => 'Escolher localização';

  @override
  String get addSpotImagesSectionTitle => 'Escolher imagens do spot';

  @override
  String get addSpotGalleryButton => 'Galeria';

  @override
  String get addSpotCameraButton => 'Câmara';

  @override
  String get addSpotGoodForTitle => 'Bom para';

  @override
  String get addSpotGoodForSubtitle =>
      'Que competências de parkour se podem treinar aqui?';

  @override
  String get addSpotFeaturesTitle => 'Características do spot';

  @override
  String get addSpotFeaturesSubtitle =>
      'Que características físicas tem este spot?';

  @override
  String get addSpotAccessTitle => 'Acesso ao spot';

  @override
  String get addSpotAccessSubtitle => 'Qual é o nível de acesso a este spot?';

  @override
  String get addSpotFacilitiesFormTitle => 'Instalações do spot';

  @override
  String get addSpotFacilitiesSubtitle => 'Que comodidades existem neste spot?';

  @override
  String get addSpotLongPressHintSkill =>
      'Pressiona longamente numa competência para mais informações';

  @override
  String get addSpotLongPressHintFeature =>
      'Pressiona longamente numa característica para mais informações';

  @override
  String get addSpotLongPressHintFacility =>
      'Pressiona longamente numa instalação para mais informações';

  @override
  String get addSpotPickLocationAppBarTitle => 'Escolher localização';

  @override
  String get addSpotTipLongPressMobile =>
      'Dica: também podes adicionar spots a partir do mapa Explorar com toque longo num local.';

  @override
  String get addSpotTipRightClickDesktop =>
      'Dica: também podes adicionar spots a partir do mapa Explorar com clique direito num local.';

  @override
  String get addSpotUseThisLocation => 'Usar esta localização';

  @override
  String get addSpotDirectionsTooltip => 'Direções';

  @override
  String get addSpotGettingAddress => 'A obter morada…';

  @override
  String get spotCardNoImages => 'Sem imagens';

  @override
  String get spotCardNoDescription => 'Ainda sem descrição';

  @override
  String get spotCardPartOfPrefix => 'Parte de ';

  @override
  String get spotCardRemoveFromListTooltip => 'Remover da lista';

  @override
  String get spotCardCopiedToClipboard =>
      'Spot copiado para a área de transferência!';

  @override
  String spotCardShareFailed(String error) {
    return 'Não foi possível partilhar o spot: $error';
  }

  @override
  String spotCardShareClipboardText(String name, String url) {
    return '$name 👉 $url';
  }

  @override
  String get spotCardRemovedFromSource => 'Removido da fonte';

  @override
  String get spotCheckInUnnamedPerson => 'Esta pessoa';

  @override
  String spotCheckInTooltipPublic(String name, String time) {
    return '$name está agora aqui neste spot (até $time)';
  }

  @override
  String spotCheckInTooltipPrivate(String time) {
    return 'Estás agora aqui neste spot até $time — só tu vês este check-in';
  }

  @override
  String get spotDetailRouteErrorLoading => 'Erro ao carregar o spot';

  @override
  String get spotDetailRouteTryAgainLater => 'Tenta novamente mais tarde';

  @override
  String get spotDetailRouteNotFound => 'Spot não encontrado';

  @override
  String get spotDetailRouteGoToExplore => 'Ir para Explorar';

  @override
  String get spotDetailCheckInVerifyFailed =>
      'Não foi possível verificar os teus check-ins';

  @override
  String get spotDetailCheckInEndPreviousFailed =>
      'Não foi possível terminar o check-in anterior';

  @override
  String get spotDetailCheckInSuccess => 'Fizeste check-in';

  @override
  String get spotDetailCheckInFailed => 'Check-in falhou';

  @override
  String get spotDetailCheckInRemoved => 'Check-in removido';

  @override
  String get spotDetailCheckInDeleteFailed =>
      'Não foi possível eliminar o check-in';

  @override
  String get spotDetailCheckInUpdated => 'Check-in atualizado';

  @override
  String get spotDetailCheckInUpdateFailed =>
      'Não foi possível atualizar o check-in';

  @override
  String get spotDetailCheckInFabTooltipSignIn =>
      'Inicia sessão para fazer check-in';

  @override
  String get spotDetailCheckInFabTooltipEdit => 'Editar check-in';

  @override
  String get spotDetailCheckInFabTooltipCheckIn => 'Check-in';

  @override
  String spotDetailSpotCreatedOnDateBy(String date) {
    return 'Spot criado $date por ';
  }

  @override
  String get spotDetailSpotCreatedBy => 'Spot criado por ';

  @override
  String get spotDetailUnknownSource => 'Fonte desconhecida';

  @override
  String spotDetailSpotImportedOnDateFrom(String date) {
    return 'Spot importado $date de ';
  }

  @override
  String get spotDetailSpotImportedFrom => 'Spot importado de ';

  @override
  String get spotDetailFromFolder => ' da pasta ';

  @override
  String get spotDetailImprovedByAfterComma => ', melhorado por ';

  @override
  String get spotDetailImprovedByAfterAnd => ' e melhorado por ';

  @override
  String get spotDetailUnknownUser => 'Desconhecido';

  @override
  String get spotDetailListJoinAnd => ' e ';

  @override
  String get spotDetailListJoinComma => ', ';

  @override
  String spotDetailLastUpdatedAfterCommaAnd(String date) {
    return ', e atualizado pela última vez $date.';
  }

  @override
  String spotDetailLastUpdatedAfterAnd(String date) {
    return ' e atualizado pela última vez $date.';
  }

  @override
  String get spotDetailDateToday => 'hoje';

  @override
  String get spotDetailDateYesterday => 'ontem';

  @override
  String spotDetailDateDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count dias',
      one: 'Há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count semanas',
      one: 'Há 1 semana',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count meses',
      one: 'Há 1 mês',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count anos',
      one: 'Há 1 ano',
    );
    return '$_temp0';
  }

  @override
  String spotDetailCopySpotFailed(String error) {
    return 'Não foi possível copiar o spot: $error';
  }

  @override
  String get spotDetailAddressCopiedToClipboard =>
      'Morada copiada para a área de transferência!';

  @override
  String spotDetailCopyAddressFailed(String error) {
    return 'Não foi possível copiar a morada: $error';
  }

  @override
  String spotDetailOpenMapsFailed(String error) {
    return 'Não foi possível abrir a app de mapas: $error';
  }

  @override
  String get spotDetailMoreActionsTooltip => 'Mais ações';

  @override
  String get spotDetailMenuLogin => 'Iniciar sessão';

  @override
  String get spotDetailMenuLoginSubtitle =>
      'Inicia sessão primeiro para associar alterações à tua conta';

  @override
  String get spotDetailMenuFlagDuplicate => 'Marcar como duplicado';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleYes =>
      'Este spot é um duplicado';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleNo =>
      'Já marcado como duplicado';

  @override
  String get spotDetailMenuSuggestPhoto => 'Sugerir foto';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleYes =>
      'Enviar fotos para este spot';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleNo =>
      'Não é possível sugerir fotos em duplicados';

  @override
  String get spotDetailMenuSuggestEdit => 'Sugerir edição';

  @override
  String get spotDetailMenuSuggestEditSubtitleYes =>
      'Propor alterações a este spot';

  @override
  String get spotDetailMenuSuggestEditSubtitleNo =>
      'Não é possível sugerir edições em duplicados';

  @override
  String get spotDetailMenuReportSpot => 'Reportar spot';

  @override
  String get spotDetailMenuReportSpotSubtitle => 'Ajuda-nos a rever este spot';

  @override
  String get spotDetailMenuEditSpot => 'Editar spot';

  @override
  String get spotDetailMenuEditSpotSubtitleNative =>
      'Cria primeiro um spot nativo';

  @override
  String get spotDetailMenuEditSpotSubtitleMod => 'Apenas moderadores';

  @override
  String get spotDetailMenuMarkDuplicate => 'Marcar como duplicado';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleDup =>
      'Já marcado como duplicado';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleMod => 'Apenas moderadores';

  @override
  String get spotDetailMenuRemoveDuplicateStatus =>
      'Remover estado de duplicado';

  @override
  String get spotDetailMenuCreateNative => 'Criar spot nativo';

  @override
  String get spotDetailMenuHideSpot => 'Ocultar spot';

  @override
  String get spotDetailMenuUnhideSpot => 'Mostrar spot';

  @override
  String get spotDetailMenuDeleteSpot => 'Eliminar spot';

  @override
  String get spotDetailMenuDeleteSubtitleAdmin => 'Apenas administradores';

  @override
  String get spotDetailMenuTriggerResize => 'Redimensionar imagem';

  @override
  String get spotDetailMenuTriggerResizeSubtitle =>
      'Recriar versões redimensionadas';

  @override
  String get spotDetailExternalSourceCannotEdit =>
      'Spots de fontes externas não podem ser editados. Cria primeiro um spot nativo com «Marcar como duplicado» → «Criar spot nativo».';

  @override
  String get spotDetailOk => 'OK';

  @override
  String get spotDetailUnableEditNow =>
      'Este spot não pode ser editado de momento.';

  @override
  String get spotDetailOnlyAdminsDelete =>
      'Apenas administradores podem eliminar spots.';

  @override
  String get spotDetailResizeAllHaveVersions =>
      'Todas as imagens já têm versões redimensionadas';

  @override
  String spotDetailResizeSummary(
    int triggered,
    int verified,
    String failedPart,
  ) {
    return 'Redimensionar: $triggered iniciados, $verified verificados$failedPart';
  }

  @override
  String spotDetailResizeFailedPart(int failed) {
    return ', $failed falhados';
  }

  @override
  String spotDetailResizeTriggerFailed(String error) {
    return 'Não foi possível iniciar o redimensionamento: $error';
  }

  @override
  String get spotDetailUnableFlagDuplicate =>
      'Não é possível marcar este spot como duplicado de momento.';

  @override
  String get spotDetailThanksDuplicateReport =>
      'Obrigado! O teu relatório de duplicado foi enviado.';

  @override
  String get spotDetailUnableSuggestPhotos =>
      'Não é possível sugerir fotos para este spot de momento.';

  @override
  String get spotDetailCannotSuggestPhotosDuplicate =>
      'Não é possível sugerir fotos em spots duplicados.';

  @override
  String get spotDetailThanksPhotoSuggestion =>
      'Obrigado! A tua sugestão de fotos foi enviada para revisão.';

  @override
  String get spotDetailUnableSuggestEdits =>
      'Não é possível sugerir edições para este spot de momento.';

  @override
  String get spotDetailCannotSuggestEditsDuplicate =>
      'Não é possível sugerir edições em spots duplicados.';

  @override
  String get spotDetailThanksEditSuggestion =>
      'Obrigado! A tua sugestão de edição foi enviada para revisão.';

  @override
  String get spotDetailUnableReportNow =>
      'Não é possível reportar este spot de momento.';

  @override
  String get spotDetailThanksReportSubmitted =>
      'Obrigado! O teu relatório foi enviado.';

  @override
  String get spotDetailUnableAddToList =>
      'Não é possível adicionar este spot a uma lista de momento.';

  @override
  String get spotDetailNoSpotListsAccess =>
      'Não tens acesso às listas de spots.';

  @override
  String get spotDetailListCreatedAndAdded => 'Lista criada e spot adicionado!';

  @override
  String get spotDetailSpotAddedToList => 'Spot adicionado à lista!';

  @override
  String get spotDetailEditReportTooltip => 'Editar e reportar';

  @override
  String get spotDetailShareTooltip => 'Partilhar';

  @override
  String get spotDetailPresenceHereNow => 'Aqui agora';

  @override
  String get spotDetailHiddenBanner =>
      'Este spot está oculto ao público. Provavelmente já não existe ou não cumpre as nossas regras. Não aparecerá nas pesquisas nem no mapa.';

  @override
  String spotDetailSourceRemovedBanner(String source) {
    return 'Este spot já não está listado em $source. Os dados podem estar desatualizados—confirma antes de visitares.';
  }

  @override
  String get spotDetailSourceRemovedUnknownSource => 'a fonte original';

  @override
  String get spotDetailSectionFeatures => 'Características';

  @override
  String get spotDetailSectionAccess => 'Acesso';

  @override
  String get spotDetailSectionFacilities => 'Instalações';

  @override
  String spotDetailJumpflixFetchFailed(String error) {
    return 'Falha ao obter Jumpflix: $error';
  }

  @override
  String get spotDetailBrandYoutube => 'YouTube';

  @override
  String get spotDetailBrandJumpflix => 'Jumpflix';

  @override
  String get spotDetailBrandAsSeenIn => 'Como em';

  @override
  String get spotDetailLoading => 'A carregar…';

  @override
  String get spotDetailLoadingYourRating => 'A carregar a tua avaliação…';

  @override
  String get spotDetailRateThisSpot => 'Avaliar este spot';

  @override
  String get spotDetailCouldNotLoadProfile =>
      'Não foi possível carregar o teu perfil.';

  @override
  String get spotDetailRefreshPageToRate => 'Atualiza a página para avaliar.';

  @override
  String get spotDetailSignInToRateTitle =>
      'Inicia sessão para avaliar este spot';

  @override
  String get spotDetailSignInToRateSubtitle =>
      'Inicia sessão para avaliar este spot e ajudar outros.';

  @override
  String get spotDetailSignInButton => 'Iniciar sessão';

  @override
  String get spotDetailCreateAccountButton => 'Criar conta';

  @override
  String get spotDetailMapSwitchToMap => 'Ver mapa';

  @override
  String get spotDetailMapSwitchToSatellite => 'Ver satélite';

  @override
  String get spotDetailMapLocateOnMap => 'Ver no mapa';

  @override
  String get spotDetailDuplicateOf => 'Duplicado de';

  @override
  String get spotDetailOriginalSpotFallback => 'Spot original';

  @override
  String get spotDetailAlsoBasedOn => 'Também baseado em';

  @override
  String spotDetailAlsoBasedOnCount(int count) {
    return 'Também baseado em ($count)';
  }

  @override
  String get spotDetailNoImagesAvailable => 'Sem imagens disponíveis';

  @override
  String spotDetailGalleryPageIndicator(int current, int total) {
    return '$current / $total';
  }

  @override
  String get spotDetailSaveMenuTooltip => 'Guardar spot';

  @override
  String get spotDetailSaveMenuSignInTitle =>
      'Inicia sessão para guardar spots';

  @override
  String get spotDetailSaveMenuSignInBody =>
      'Adiciona este spot a «Quero visitar», «Já estive» ou às tuas listas. Inicia sessão ou cria uma conta gratuita.';

  @override
  String get spotDetailSaveMenuLogInOrCreate => 'Iniciar sessão ou criar conta';

  @override
  String get spotDetailSaveTooltipUpdating => 'A atualizar…';

  @override
  String get spotDetailSaveTooltipWantToVisit => 'Guardado: Quero visitar';

  @override
  String get spotDetailSaveTooltipBeenHere => 'Guardado: Já estive';

  @override
  String get spotDetailSaveTooltipGeneric => 'Guardar spot';

  @override
  String get spotDetailRemovedFromWantToVisit => 'Removido de Quero visitar';

  @override
  String get spotDetailFailedToRemove => 'Falha ao remover';

  @override
  String get spotDetailAddedToWantToVisit => 'Adicionado a Quero visitar';

  @override
  String get spotDetailFailedToAdd => 'Falha ao adicionar';

  @override
  String get spotDetailRemovedFromBeenHere => 'Removido de Já estive';

  @override
  String get spotDetailAddedToBeenHere => 'Adicionado a Já estive';

  @override
  String get spotDetailWantToVisit => 'Quero visitar';

  @override
  String get spotDetailBeenHere => 'Já estive';

  @override
  String get spotDetailViewFullListTooltip => 'Ver lista completa';

  @override
  String get spotDetailAddToCustomList => 'Adicionar a lista própria';

  @override
  String get spotDetailAddToCustomListSubtitle => 'Escolhe ou cria uma lista';

  @override
  String get spotDetailListNameEmpty => 'O nome da lista não pode estar vazio';

  @override
  String get spotDetailFailedAddToListGeneric =>
      'Não foi possível adicionar o spot à lista';

  @override
  String get spotDetailFailedCreateList => 'Não foi possível criar a lista';

  @override
  String get spotDetailFailedAddToSomeLists =>
      'Não foi possível adicionar o spot a algumas listas';

  @override
  String spotDetailAddToListTitle(String name) {
    return 'Adicionar a $name';
  }

  @override
  String get spotDetailSelectSections => 'Selecionar secções:';

  @override
  String spotDetailSectionEntryCount(int count) {
    return 'Secção ($count spots)';
  }

  @override
  String get spotDetailAddToNewSection => 'Adicionar a nova secção';

  @override
  String get spotDetailSectionNameOptional => 'Nome da secção (opcional)';

  @override
  String get spotDetailNoteOptional => 'Nota (opcional)';

  @override
  String get spotDetailSkip => 'Ignorar';

  @override
  String get spotDetailAdd => 'Adicionar';

  @override
  String get spotDetailAddToListDialogTitle => 'Adicionar à lista';

  @override
  String get spotDetailAlreadyInLists => 'Já está nestas listas:';

  @override
  String get spotDetailNoListsYet =>
      'Ainda não tens listas. Cria uma para começar!';

  @override
  String get spotDetailSelectListsPrompt =>
      'Seleciona as listas a adicionar este spot:';

  @override
  String get spotDetailCreateNewList => 'Criar lista nova';

  @override
  String get spotDetailListNameLabel => 'Nome da lista';

  @override
  String get spotDetailListNameHint => 'ex.: Os meus spots favoritos';

  @override
  String get spotDetailListDescriptionLabel => 'Descrição (opcional)';

  @override
  String get spotDetailListDescriptionHint =>
      'Adiciona uma descrição para esta lista';

  @override
  String get spotDetailVisibilityLabel => 'Visibilidade';

  @override
  String get spotDetailCreateAndAdd => 'Criar e adicionar';

  @override
  String get spotDetailReportDuplicateTitle => 'Reportar spot duplicado';

  @override
  String get spotDetailReportDuplicateIntro =>
      'Seleciona o spot do qual este é duplicado.';

  @override
  String get spotDetailEmailInvalid => 'Introduz um e-mail válido.';

  @override
  String get spotDetailEmailRequired => 'Introduz um e-mail.';

  @override
  String get spotDetailSubmitReport => 'Enviar relatório';

  @override
  String get spotDetailReportThisSpotTitle => 'Reportar este spot';

  @override
  String spotDetailReportIntro(String name) {
    return 'Diz-nos o que está errado com $name. Os moderadores vão rever o relatório.';
  }

  @override
  String get spotDetailReportWhatWrong => 'O que está a acontecer?';

  @override
  String get spotDetailReportCategoryLabel => 'Escolhe uma categoria';

  @override
  String get spotDetailReportCategoryHint =>
      'Escolhe uma categoria de relatório';

  @override
  String get spotDetailReportDescribeIssue => 'Descreve o problema';

  @override
  String get spotDetailReportDescribeIssueHint =>
      'Diz-nos o que não corresponde à realidade';

  @override
  String get spotDetailReportAdditionalDetails => 'Detalhes adicionais';

  @override
  String get spotDetailReportAdditionalDetailsHint =>
      'Mais alguma coisa que devamos saber?';

  @override
  String get spotDetailReportEmailLabel => 'E-mail';

  @override
  String get spotDetailReportEmailHelper =>
      'Só te contactamos sobre este relatório.';

  @override
  String spotDetailReportReachOutAt(String email) {
    return 'Se precisarmos de mais informações, contactamos-te em $email.';
  }

  @override
  String get spotDetailReportReachOutAccount =>
      'Se precisarmos de mais informações, usamos o e-mail da tua conta.';

  @override
  String get spotDetailReportCategoryOtherDescribe =>
      'Descreve o problema ao escolheres «Outro».';

  @override
  String get spotDetailReportCategoryRequired => 'Escolhe uma categoria.';

  @override
  String get spotDetailReportSendFailed =>
      'Não foi possível enviar o relatório. Tenta novamente.';

  @override
  String get spotDetailReportCategoryClosed => 'Spot fechado ou removido';

  @override
  String get spotDetailReportCategoryInaccurate =>
      'Localização ou dados incorretos';

  @override
  String get spotDetailReportCategoryUnsafe => 'Condições inseguras';

  @override
  String get spotDetailReportCategoryNotASpot => 'Não é um spot';

  @override
  String get spotDetailReportCategoryOther => 'Outro';

  @override
  String get spotDetailReportCategoryClosedDesc =>
      'O spot foi fechado, demolido ou removido de forma permanente e já não é acessível. Dá mais detalhes abaixo.';

  @override
  String get spotDetailReportCategoryInaccurateDesc =>
      'A posição no mapa está errada ou o nome, descrição ou morada estão incorretos. Indica abaixo o que corrigir.';

  @override
  String get spotDetailReportCategoryUnsafeDesc =>
      'O spot tornou-se perigoso (estrutura, ambiente, etc.). Explica abaixo o que é inseguro.';

  @override
  String get spotDetailReportCategoryNotASpotDesc =>
      'Apenas para casos objetivos: spam, locais inválidos (ex. mar), residências privadas, cidades inteiras ou entradas claramente inválidas. Para opiniões sobre qualidade, usa a avaliação. Explica por que não é um spot.';

  @override
  String get spotDetailReportCategoryOtherDesc =>
      'Qualquer outro problema. Descreve no campo abaixo.';

  @override
  String get spotDetailMarkDuplicateTitle => 'Marcar como duplicado';

  @override
  String get spotDetailMarkDuplicateBody =>
      'Tens a certeza de que queres marcar este spot como duplicado? Podes reverter mais tarde.';

  @override
  String get spotDetailMarkDuplicateAddToOriginal =>
      'Escolhe o que adicionar ao spot original:';

  @override
  String get spotDetailMarkDuplicatePhotos => 'Fotos';

  @override
  String get spotDetailMarkDuplicateYoutube => 'Ligações do YouTube';

  @override
  String get spotDetailMarkDuplicateOverwrite =>
      'Escolhe o que substituir no spot original (se definido):';

  @override
  String get spotDetailMarkDuplicateName => 'Nome';

  @override
  String get spotDetailMarkDuplicateDescription => 'Descrição';

  @override
  String get spotDetailMarkDuplicateLocation => 'Localização';

  @override
  String get spotDetailMarkDuplicateSpotAttributes => 'Atributos do spot';

  @override
  String get spotDetailConfirm => 'Confirmar';

  @override
  String get spotDetailPickImagesFailed =>
      'Não foi possível escolher imagens. Tenta novamente.';

  @override
  String get spotDetailSelectAtLeastOnePhoto => 'Seleciona pelo menos uma foto';

  @override
  String get spotDetailSuggestPhotosTitle => 'Sugerir fotos';

  @override
  String get spotDetailSuggestPhotosIntro =>
      'Envia fotos para adicionar a este spot. Os moderadores revêem antes de publicar.';

  @override
  String get spotDetailSelectPhotos => 'Selecionar fotos';

  @override
  String get spotDetailPickPhotos => 'Escolher fotos';

  @override
  String get spotDetailAdditionalDetailsOptional =>
      'Detalhes adicionais (opcional)';

  @override
  String get spotDetailAdditionalDetailsHint =>
      'Mais informação sobre estas fotos…';

  @override
  String get spotDetailSuggestPhotosEmailHelper =>
      'Só te contactamos sobre esta sugestão.';

  @override
  String get spotDetailSuggestPhotosSubmitFailed =>
      'Não foi possível enviar a sugestão de fotos. Tenta novamente.';

  @override
  String spotDetailSuggestPhotosSubmitError(String error) {
    return 'Erro ao enviar sugestão de fotos: $error';
  }

  @override
  String get spotDetailSuggestEditTitle => 'Sugerir edição';

  @override
  String get spotDetailSuggestEditIntro =>
      'Propõe alterações a este spot. Os moderadores revêem as sugestões.';

  @override
  String get spotDetailSuggestEditSuggestChange =>
      'Sugere pelo menos uma alteração.';

  @override
  String get spotDetailSuggestEditSubmitFailed =>
      'Não foi possível enviar a sugestão de edição. Tenta novamente.';

  @override
  String spotDetailSuggestEditSubmitError(String error) {
    return 'Erro ao enviar sugestão de edição: $error';
  }

  @override
  String get spotDetailGeocoding => 'Geocodificação…';

  @override
  String get spotDetailChangeLocationPicked =>
      'Alterar localização (escolhida)';

  @override
  String get spotDetailPickLocationOnMap =>
      'Escolher outra localização no mapa';

  @override
  String get spotDetailFieldTitle => 'Título';

  @override
  String get spotDetailFieldTitleHint => 'Título do spot';

  @override
  String get spotDetailFieldDescription => 'Descrição';

  @override
  String get spotDetailFieldDescriptionHint => 'Descrição do spot';

  @override
  String get spotDetailFieldSpotAttributes => 'Atributos do spot';

  @override
  String get spotDetailSuggestEditEmailHelper =>
      'Só te contactamos sobre esta sugestão.';

  @override
  String get spotDetailMustBeLoggedInToRate =>
      'Tens de ter sessão iniciada para avaliar spots';

  @override
  String spotDetailRatingSubmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Avaliação de $count estrelas enviada!',
      one: 'Avaliação de 1 estrela enviada!',
    );
    return '$_temp0';
  }

  @override
  String get spotDetailRatingSubmitFailed =>
      'Não foi possível enviar a avaliação. Tenta novamente.';

  @override
  String spotDetailRatingSubmitError(String error) {
    return 'Erro ao enviar avaliação: $error';
  }

  @override
  String get spotDetailNotExternalSource =>
      'Este spot não vem de uma fonte externa.';

  @override
  String get spotDetailMustBeLoggedInCreateNative =>
      'Tens de ter sessão iniciada para criar um spot nativo.';

  @override
  String get spotDetailCreateNativeDialogTitle => 'Criar spot nativo';

  @override
  String get spotDetailCreateNativeDialogBody =>
      'Será criado um spot nativo com base neste e o spot atual será marcado como duplicado. Todos os dados (nome, descrição, localização, fotos, ligações YouTube, atributos) serão copiados.\n\nNota: os administradores podem remover spots e ligações de duplicado se necessário.';

  @override
  String get spotDetailCreateButton => 'Criar';

  @override
  String get spotDetailUnableCreateNativeNow =>
      'Não é possível criar um spot nativo de momento.';

  @override
  String get spotDetailFailedCreateNativeSpot =>
      'Não foi possível criar o spot nativo';

  @override
  String get spotDetailNativeCreatedDuplicateMarked =>
      'Spot nativo criado e spot atual marcado como duplicado.';

  @override
  String get spotDetailFailedMarkDuplicateGeneric =>
      'Não foi possível marcar como duplicado';

  @override
  String spotDetailErrorCreatingNativeSpot(String error) {
    return 'Erro ao criar spot nativo: $error';
  }

  @override
  String get spotDetailUnableMarkDuplicateNow =>
      'Não é possível marcar este spot como duplicado de momento.';

  @override
  String get spotDetailAlreadyMarkedDuplicate =>
      'Este spot já está marcado como duplicado.';

  @override
  String get spotDetailSpotMarkedDuplicateSuccess =>
      'Spot marcado como duplicado.';

  @override
  String spotDetailErrorMarkingDuplicateSpot(String error) {
    return 'Erro ao marcar como duplicado: $error';
  }

  @override
  String get spotDetailModeratorsOnlyHideUnhide =>
      'Apenas moderadores podem ocultar ou mostrar spots.';

  @override
  String get spotDetailHideSpotTitle => 'Ocultar spot';

  @override
  String get spotDetailUnhideSpotTitle => 'Mostrar spot';

  @override
  String get spotDetailHideSpotMessage =>
      'O spot deixa de ser visível ao público. Não aparece nas pesquisas nem no mapa, mas os dados são guardados e podem ser mostrados depois.';

  @override
  String get spotDetailUnhideSpotMessage =>
      'O spot volta a ser público e aparece nas pesquisas e no mapa.';

  @override
  String get spotDetailActionHide => 'Ocultar';

  @override
  String get spotDetailActionUnhide => 'Mostrar';

  @override
  String get spotDetailUnableHideUnhideNow =>
      'Não é possível ocultar ou mostrar este spot de momento.';

  @override
  String get spotDetailSpotHiddenSuccess => 'Spot ocultado.';

  @override
  String get spotDetailSpotUnhiddenSuccess => 'Spot visível novamente.';

  @override
  String get spotDetailFailedHideSpot => 'Não foi possível ocultar o spot';

  @override
  String get spotDetailFailedUnhideSpot => 'Não foi possível mostrar o spot';

  @override
  String spotDetailErrorHidingSpot(String error) {
    return 'Erro ao ocultar: $error';
  }

  @override
  String spotDetailErrorUnhidingSpot(String error) {
    return 'Erro ao mostrar: $error';
  }

  @override
  String get spotDetailNotMarkedAsDuplicate =>
      'Este spot não está marcado como duplicado.';

  @override
  String get spotDetailModeratorsOnlyRemoveDuplicateStatus =>
      'Apenas moderadores podem remover o estado de duplicado.';

  @override
  String get spotDetailRemoveDuplicateDialogBody =>
      'O estado de duplicado será removido; o spot deixa de ser considerado duplicado.\n\nContinuar?';

  @override
  String get spotDetailRemoveButton => 'Remover';

  @override
  String get spotDetailUnableRemoveDuplicateStatusNow =>
      'Não é possível remover o estado de duplicado de momento.';

  @override
  String get spotDetailDuplicateStatusRemovedSuccess =>
      'Estado de duplicado removido.';

  @override
  String get spotDetailFailedRemoveDuplicateStatusGeneric =>
      'Não foi possível remover o estado de duplicado';

  @override
  String spotDetailErrorRemovingDuplicateStatus(String error) {
    return 'Erro ao remover estado de duplicado: $error';
  }

  @override
  String get spotDetailCheckingLinkedData => 'A verificar dados ligados…';

  @override
  String get spotDetailDeleteSpotDialogTitle => 'Eliminar spot';

  @override
  String get spotDetailDeleteSpotConfirmMessage =>
      'Tens a certeza de que queres eliminar este spot? Esta ação não pode ser anulada.';

  @override
  String get spotDetailLinkedDataHeading => 'Este spot tem dados ligados:';

  @override
  String spotDetailLinkedRatingsLine(int count) {
    return '• Avaliações: $count';
  }

  @override
  String spotDetailLinkedReportsLine(int count) {
    return '• Relatórios: $count';
  }

  @override
  String spotDetailLinkedDuplicatesLine(int count) {
    return '• Spots duplicados: $count';
  }

  @override
  String get spotDetailResolveLinksBeforeDelete =>
      'Resolve estas ligações antes de eliminar o spot.';

  @override
  String get spotDetailSpotDeletedSuccess => 'Spot eliminado.';

  @override
  String get spotDetailFailedDeleteSpot => 'Não foi possível eliminar o spot';

  @override
  String spotDetailErrorDeletingSpot(String error) {
    return 'Erro ao eliminar o spot: $error';
  }

  @override
  String get spotDetailFlagDuplicateDialogTitle => 'Marcar como duplicado';

  @override
  String get spotDetailFlagDuplicateIntro =>
      'Este spot parece um duplicado de outro. Seleciona o spot original abaixo.';

  @override
  String get spotDetailFlagDuplicateWhichQuestion => 'De que spot é duplicado?';

  @override
  String get spotDetailDuplicateSearchHint =>
      'Cola o URL do spot ou introduz o ID';

  @override
  String get spotDetailSearch => 'Pesquisar';

  @override
  String get spotDetailNearbySpotsWithin50m =>
      'Spots próximos (num raio de ~50 m)';

  @override
  String get spotDetailFoundSpot => 'Spot encontrado';

  @override
  String spotDetailSpotIdLabel(String id) {
    return 'ID do spot: $id';
  }

  @override
  String get spotDetailRemoveSelectionTooltip => 'Remover seleção';

  @override
  String get spotDetailImageFailedToLoad =>
      'Não foi possível carregar a imagem';

  @override
  String get spotDetailClose => 'Fechar';

  @override
  String spotDetailExpandMoreCount(int count) {
    return 'mais $count';
  }

  @override
  String get spotDetailSubmit => 'Enviar';

  @override
  String get spotDetailDuplicateReportSelectRequired =>
      'Seleciona o spot do qual este é duplicado.';

  @override
  String get spotDetailDuplicateSearchEmpty => 'Introduz um ID ou URL do spot';

  @override
  String get spotDetailDuplicateInvalidUrl => 'ID ou URL do spot inválidos';

  @override
  String get spotDetailDuplicateCannotSelectSelf =>
      'Um spot não pode ser duplicado de si próprio';

  @override
  String get spotDetailDuplicateSpotNotFound => 'Spot não encontrado';

  @override
  String spotDetailDuplicateFailedLoadSpot(String error) {
    return 'Não foi possível carregar o spot: $error';
  }

  @override
  String get sourceDetailsLoadingSource => 'A carregar fonte...';

  @override
  String get sourceDetailsErrorTitle => 'Erro';

  @override
  String get sourceDetailsNotFound => 'Fonte não encontrada';

  @override
  String get sourceDetailsTotalSpots => 'Total de spots';

  @override
  String get sourceDetailsFolders => 'Pastas';

  @override
  String get sourceDetailsGoToSource => 'Ir para a fonte';

  @override
  String get sourceDetailsAdded => 'Adicionado';

  @override
  String get sourceDetailsLastImported => 'Última importação';

  @override
  String sourceDetailsRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count dias',
      one: 'Há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count horas',
      one: 'Há 1 hora',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count minutos',
      one: 'Há 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get sourceDetailsRelativeJustNow => 'Agora mesmo';

  @override
  String spotTrackingSignInToViewList(String listName) {
    return 'Inicia sessão para ver a tua lista «$listName»';
  }

  @override
  String spotTrackingNoSpotsInList(String listName) {
    return 'Sem spots em $listName';
  }

  @override
  String get spotListSaveTooltipSaveList => 'Guardar lista';

  @override
  String get spotListSaveTooltipSavedList => 'Lista guardada';

  @override
  String get spotListSaveSignInTitle => 'Inicia sessão para guardar listas';

  @override
  String get spotListSaveSignInBody =>
      'Guarda a lista de spots de outra pessoa no teu perfil para poderes abri-la novamente mais tarde.';

  @override
  String get spotListSaveSavedToProfile => 'Lista guardada no teu perfil';

  @override
  String get spotListSaveCouldNotSaveList => 'Não foi possível guardar a lista';

  @override
  String get spotListSaveRemovedFromSavedLists =>
      'Removida das listas guardadas';

  @override
  String get spotListSaveCouldNotRemoveList =>
      'Não foi possível remover a lista';

  @override
  String get spotListSaveActionSaveList => 'Guardar lista';

  @override
  String get spotListSaveActionRemoveFromSaved => 'Remover das guardadas';

  @override
  String get spotListSaveActionViewSavedLists => 'Ver listas guardadas';

  @override
  String get spotListDetailListNotFoundOrNotAccessible =>
      'Lista não encontrada ou sem acesso';

  @override
  String get spotListDetailDeleteListTitle => 'Eliminar lista';

  @override
  String spotListDetailDeleteListConfirmation(String name) {
    return 'Tens a certeza de que queres eliminar \"$name\"? Esta ação não pode ser anulada.';
  }

  @override
  String get spotListDetailDeleteAction => 'Eliminar';

  @override
  String get spotListDetailListDeleted => 'Lista eliminada';

  @override
  String get spotListDetailFailedToDeleteList =>
      'Não foi possível eliminar a lista';

  @override
  String get spotListDetailNoSpotsInThisList => 'Sem spots nesta lista';

  @override
  String get spotListDetailEditListTitle => 'Editar lista';

  @override
  String get spotListDetailMoreInfoLinkLabel =>
      'Ligação com mais informação (opcional)';

  @override
  String get spotListDetailMoreInfoLinkHint => 'https://…';

  @override
  String get spotListDetailMoreInfoLinkHelper =>
      'Uma página na web com mais informação sobre esta lista';

  @override
  String get spotListDetailMoreInfoLinkValidationError =>
      'A ligação com mais informação tem de ser um URL válido (http ou https), por exemplo example.com ou https://example.com/pagina';

  @override
  String get spotListDetailSave => 'Guardar';

  @override
  String get spotListDetailListUpdated => 'Lista atualizada';

  @override
  String get spotListDetailFailedToUpdateList =>
      'Não foi possível atualizar a lista';

  @override
  String get spotListDetailVisibilityPublicList => 'Lista pública';

  @override
  String get spotListDetailVisibilityUnlistedList => 'Lista não listada';

  @override
  String get spotListDetailVisibilityPrivateList => 'Lista privada';

  @override
  String get spotListDetailCouldNotOpenProfile =>
      'Não foi possível abrir o perfil';

  @override
  String spotListDetailCreatedPart(String visibility, String date) {
    return '$visibility criada $date';
  }

  @override
  String get spotListDetailCreatedBySuffix => ' por ';

  @override
  String spotListDetailLastUpdatedPart(String date) {
    return ', e atualizada pela última vez $date.';
  }

  @override
  String get spotListDetailMoreInformationOn => 'Mais informação em ';

  @override
  String get spotListDetailCopiedToClipboard =>
      'Lista copiada para a área de transferência!';

  @override
  String spotListDetailCopyFailed(String error) {
    return 'Não foi possível copiar a lista: $error';
  }

  @override
  String get spotListDetailHighlightListOnMap => 'Destacar lista no mapa';

  @override
  String get spotListDetailEditListTooltip => 'Editar lista';

  @override
  String get spotListDetailMenuListSettings => 'Definições da lista';

  @override
  String get spotListDetailMenuOrganizeList => 'Organizar lista';

  @override
  String get spotListDetailMenuDeleteList => 'Eliminar lista';

  @override
  String get spotListDetailPageTitle => 'Lista de spots';

  @override
  String get spotListDetailListNotFound => 'Lista não encontrada';

  @override
  String spotListDetailMetaDescriptionFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots de parkour',
      one: '1 spot de parkour',
    );
    return 'Uma lista curada de $_temp0 no Parkour·Spot';
  }

  @override
  String get publicProfilePageTitle => 'Perfil';

  @override
  String get publicProfileShareProfileTooltip => 'Partilhar perfil';

  @override
  String get publicProfileErrorLoadingProfile => 'Erro ao carregar perfil';

  @override
  String get publicProfilePleaseTryAgainLater => 'Tenta novamente mais tarde';

  @override
  String publicProfileMetaDescription(String name, String defaultDescription) {
    return 'Vê os spots e listas de parkour de $name no Parkour·Spot — $defaultDescription';
  }

  @override
  String get publicProfileProfileNotFound => 'Perfil não encontrado';

  @override
  String get publicProfileNotFoundOrPrivate =>
      'Este perfil não existe ou é privado.';

  @override
  String publicProfileMemberSince(String date) {
    return 'Membro desde $date';
  }

  @override
  String get publicProfileEditProfileTooltip => 'Editar perfil';

  @override
  String get publicProfileSpotTracking => 'Seguimento de spots';

  @override
  String get publicProfileNoSpotsYet => 'Ainda sem spots';

  @override
  String get publicProfileAddSpotsFromSpotDetailPages =>
      'Adiciona spots a partir das páginas de detalhe do spot';

  @override
  String get publicProfileBeenTo => 'Já visitados';

  @override
  String get publicProfileMyCheckIns => 'Os meus check-ins';

  @override
  String get publicProfileMyCheckInsSubtitle =>
      'O teu histórico registado de visitas a spots';

  @override
  String get myCheckInsSignInPrompt =>
      'Inicia sessão para ver os teus check-ins';

  @override
  String get myCheckInsLoadMore => 'Carregar mais';

  @override
  String get myCheckInsEmptyTitle => 'Ainda sem check-ins';

  @override
  String get myCheckInsEmptyDescription =>
      'Abre um spot e toca em Check in para registar uma visita. Até à hora de fim que definires, outras pessoas podem ver-te como «aqui agora» nesse spot, a menos que mantenhas o check-in privado.';

  @override
  String get myCheckInsIntro =>
      'Um check-in regista que visitaste um spot, quando chegaste e até quando esperas ficar lá. Check-ins públicos podem mostrar-te no «quem está aqui agora» desse spot até essa hora final; check-ins privados ficam visíveis apenas para ti.';

  @override
  String get myCheckInsSpotFallback => 'Spot';

  @override
  String get myCheckInsPrivateOnlyYou => 'Privado — só tu podes ver isto';

  @override
  String myCheckInsDurationDaysShort(int count) {
    return '${count}d';
  }

  @override
  String myCheckInsDurationHoursShort(int count) {
    return '${count}h';
  }

  @override
  String myCheckInsDurationMinutesShort(int count) {
    return '${count}m';
  }

  @override
  String get publicProfileSpotLists => 'Listas de spots';

  @override
  String get publicProfileYours => 'Tuas';

  @override
  String get publicProfileCreateYourFirstList => 'Cria a tua primeira lista';

  @override
  String get publicProfileSaved => 'Guardadas';

  @override
  String get publicProfilePublicSpotLists => 'Listas públicas de spots';

  @override
  String get publicProfileNoSavedListsYet => 'Ainda sem listas guardadas';

  @override
  String get publicProfileSaveListsHint =>
      'Guarda listas que encontrares nas páginas de listas de outros utilizadores';

  @override
  String get publicProfileSavedListsUnavailable =>
      'As tuas listas guardadas já não estão disponíveis ou foram removidas.';

  @override
  String get publicProfileListCreatedSuccessfully => 'Lista criada com sucesso';

  @override
  String get publicProfileChangeProfilePicture => 'Alterar foto de perfil';

  @override
  String get publicProfileChooseFromGallery => 'Escolher da galeria';

  @override
  String get publicProfileTakePhoto => 'Tirar foto';

  @override
  String get publicProfileRemovePicture => 'Remover foto';

  @override
  String publicProfileErrorPickingImage(String error) {
    return 'Erro ao escolher imagem: $error';
  }

  @override
  String publicProfileErrorTakingPhoto(String error) {
    return 'Erro ao tirar foto: $error';
  }

  @override
  String get publicProfileProcessingImage => 'A processar imagem...';

  @override
  String get publicProfileReadingImage => 'A ler imagem...';

  @override
  String get publicProfileUploading => 'A carregar...';

  @override
  String get publicProfileFinishing => 'A finalizar...';

  @override
  String get publicProfileUpdatingProfile => 'A atualizar perfil...';

  @override
  String get publicProfileProfilePictureUpdatedSuccessfully =>
      'Foto de perfil atualizada com sucesso';

  @override
  String get publicProfileFailedToUpdateProfilePicture =>
      'Não foi possível atualizar a foto de perfil';

  @override
  String publicProfileErrorUploadingProfilePicture(String error) {
    return 'Erro ao carregar foto de perfil: $error';
  }

  @override
  String get publicProfileRemoveProfilePicture => 'Remover foto de perfil';

  @override
  String get publicProfileRemoveProfilePictureConfirmation =>
      'Tens a certeza de que queres remover a tua foto de perfil?';

  @override
  String get publicProfileProfilePictureRemovedSuccessfully =>
      'Foto de perfil removida com sucesso';

  @override
  String get publicProfileFailedToRemoveProfilePicture =>
      'Não foi possível remover a foto de perfil';

  @override
  String publicProfileErrorRemovingProfilePicture(String error) {
    return 'Erro ao remover foto de perfil: $error';
  }

  @override
  String get publicProfileProfileCopiedToClipboard =>
      'Perfil copiado para a área de transferência!';

  @override
  String publicProfileFailedToCopyProfile(String error) {
    return 'Não foi possível copiar o perfil: $error';
  }

  @override
  String get publicProfileStatsSpots => 'Spots';

  @override
  String get publicProfileStatsRatings => 'Avaliações';

  @override
  String get publicProfileSettingsTitle => 'Definições do perfil';

  @override
  String get publicProfileEmailLabel => 'E-mail';

  @override
  String get publicProfileEmailNotShownHint =>
      'O teu e-mail não é mostrado publicamente.';

  @override
  String get publicProfileDisplayNameLabel => 'Nome de exibição';

  @override
  String get publicProfileNoDisplayNameSet => 'Sem nome de exibição definido';

  @override
  String get publicProfileEditAction => 'Editar';

  @override
  String get publicProfileDisplayNameHint => 'Introduz o teu nome';

  @override
  String publicProfileDisplayNameHelper(int max) {
    return 'Como o teu nome é mostrado aos outros';
  }

  @override
  String publicProfileDisplayNameMaxLengthError(int max) {
    return 'O nome de exibição deve ter no máximo 50 caracteres';
  }

  @override
  String get publicProfileDisplayNameUpdated => 'Nome de exibição atualizado';

  @override
  String get publicProfileDisplayNameRemoved => 'Nome de exibição removido';

  @override
  String get publicProfileDisplayNameUpdateFailed =>
      'Não foi possível atualizar o nome de exibição';

  @override
  String get publicProfileSaveAction => 'Guardar';

  @override
  String get publicProfileUsernameLabel => 'Nome de utilizador';

  @override
  String get publicProfileNoUsernameSet => 'Sem nome de utilizador definido';

  @override
  String get publicProfileUsernameHint => 'Introduz um nome de utilizador';

  @override
  String get publicProfileUsernameHelper =>
      'Único e usado no URL do teu perfil';

  @override
  String get publicProfileUsernameEmpty =>
      'O nome de utilizador não pode estar vazio';

  @override
  String get publicProfileUsernameTaken =>
      'Esse nome de utilizador já está em uso';

  @override
  String get publicProfileUsernameUpdated => 'Nome de utilizador atualizado';

  @override
  String get publicProfileUsernameUpdateFailed =>
      'Não foi possível atualizar o nome de utilizador';

  @override
  String get publicProfileInstagramLabel => 'Instagram';

  @override
  String get publicProfileNoInstagramSet => 'Sem Instagram definido';

  @override
  String get publicProfileAddAction => 'Adicionar';

  @override
  String get publicProfileInstagramLinkLabel => 'Ligação do Instagram';

  @override
  String get publicProfileInstagramLinkHint => 'https://instagram.com/teunome';

  @override
  String get publicProfileInstagramLinkHelper =>
      'URL completo para o teu perfil de Instagram';

  @override
  String get publicProfileInstagramInvalid =>
      'Introduz um URL válido de Instagram';

  @override
  String get publicProfileInstagramRemoved => 'Ligação do Instagram removida';

  @override
  String get publicProfileInstagramUpdated => 'Ligação do Instagram atualizada';

  @override
  String get publicProfileInstagramUpdateFailed =>
      'Não foi possível atualizar a ligação do Instagram';

  @override
  String get publicProfilePrivacyTitle => 'Privacidade';

  @override
  String get publicProfilePrivacyPublicLabel => 'Perfil público';

  @override
  String get publicProfilePrivacyPrivateLabel => 'Perfil privado';

  @override
  String get publicProfilePrivacyPublicDescription =>
      'Qualquer pessoa pode ver o teu perfil e listas públicas.';

  @override
  String get publicProfilePrivacyPrivateDescription =>
      'Só tu podes ver o teu perfil.';

  @override
  String get publicProfilePrivacyNowPublic => 'O teu perfil é agora público';

  @override
  String get publicProfilePrivacyNowPrivate => 'O teu perfil é agora privado';

  @override
  String get publicProfileFailedToUpdateProfilePrivacy =>
      'Não foi possível atualizar a privacidade do perfil';
}
