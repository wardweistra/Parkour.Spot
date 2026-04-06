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
}
