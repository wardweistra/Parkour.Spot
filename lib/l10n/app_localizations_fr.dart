// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tabExplore => 'Explorer';

  @override
  String get tabAddSpot => 'Ajouter un spot';

  @override
  String get tabAccount => 'Compte';

  @override
  String get profileSettingsTitle => 'Réglages';

  @override
  String get profileSettingsLanguageLabel => 'Langue';

  @override
  String get profileSettingsLanguageDescription =>
      'Choisissez une langue ou suivez les réglages de l’appareil.';

  @override
  String get profileLanguageSystemDefault => 'Langue de l’appareil';

  @override
  String get profileLoadErrorDefault => 'Impossible de charger le profil.';

  @override
  String get profileRefreshPage => 'Actualiser la page';

  @override
  String get profileRetry => 'Réessayer';

  @override
  String get profileSignInTitle => 'Connectez-vous pour accéder à votre compte';

  @override
  String get profileSignInSubtitle =>
      'Connectez-vous pour gérer vos spots et noter les lieux.';

  @override
  String get profileSignInButton => 'Connexion';

  @override
  String get profileOrDivider => 'OU';

  @override
  String get profileCreateAccount => 'Créer un compte';

  @override
  String get profileDefaultDisplayName => 'Utilisateur';

  @override
  String get profileViewEditSubtitle => 'Voir et modifier votre profil';

  @override
  String get profileModeratorSectionTitle => 'Modération';

  @override
  String get profileModeratorToolsTitle => 'Outils de modération';

  @override
  String get profileModeratorToolsSubtitle =>
      'Examiner et traiter les signalements de spots';

  @override
  String get profileAdminSectionTitle => 'Administrateur';

  @override
  String get profileAdminToolsTitle => 'Outils d’administration';

  @override
  String get profileAdminToolsSubtitle =>
      'Gérer les sources et les tâches administratives';

  @override
  String get profileSignOut => 'Déconnexion';

  @override
  String get profileSignOutMessage => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get profileCancel => 'Annuler';

  @override
  String get profileAboutIntro =>
      'Parkour·Spot est une appli communautaire pour découvrir et partager des spots de parkour et de freerunning dans le monde entier. Nous simplifions la recherche de bons lieux—où que vous vous entraîniez.';

  @override
  String get profileReadMore => 'Lire la suite';

  @override
  String get profileAboutStoryBeforeName => 'Lancée par ';

  @override
  String get profileAboutStoryAfterName =>
      ' au sein de la communauté parkour d’Utrecht, l’appli rassemble les connaissances locales des cartes existantes—qu’elles soient sur Facebook, Instagram, des sites ou d’anciennes applis—afin que les bonnes données de spots ne se perdent pas.';

  @override
  String get profileAboutMapMission =>
      'C’est votre carte. Ajoutez des spots, notez ceux qui existent et enrichissez les fiches. Plus nous contribuons, plus les connaissances partagées de la communauté se renforcent.';

  @override
  String get profileAboutPrinciplesHeader => 'Nos principes :';

  @override
  String get profileAboutPrincipleTransparency =>
      '• Transparence : vous pouvez parcourir l’appli sans compte, et chaque spot indique quelles sources externes y ont contribué.';

  @override
  String get profileAboutPrinciplePortability =>
      '• Portabilité : nous développons des outils d’export pour que les données de spots puissent être utilisées au-delà de l’appli.';

  @override
  String get profileAboutPrincipleOpenSource =>
      '• Open source : l’appli appartient à la communauté, pas à une seule personne.';

  @override
  String get profileAboutEnjoy =>
      'Bonnes découvertes et partages de spots avec Parkour.spot. Des questions ou des idées ? Touchez contact—nous serons ravis de vous lire.';

  @override
  String get profileCreditsBy => 'Contributions majeures de ';

  @override
  String get profileCreditsDaphneArt => ' (illustration), ';

  @override
  String get profileCreditsComma => ', ';

  @override
  String get profileCreditsEnd => ' et beaucoup d’autres.';

  @override
  String get profileViewSourceCode => 'Voir le code source';

  @override
  String get profileContactUs => 'Nous contacter';

  @override
  String get profileReportIssue => 'Signaler un problème';

  @override
  String get profileInstallBannerTitle => 'Installer l’appli Parkour·Spot';

  @override
  String get profileInstallBannerSubtitle =>
      'Profitez de l’expérience complète';

  @override
  String get profileInstallDialogTitle => 'Installer Parkour·Spot';

  @override
  String profileInstallIntro(String device) {
    return 'Pour installer Parkour·Spot sur votre $device :';
  }

  @override
  String get profileInstallDeviceIphone => 'iPhone';

  @override
  String get profileInstallDeviceAndroid => 'appareil Android';

  @override
  String get profileInstallIosStep1 =>
      'Appuyez sur le bouton Partager en bas de l’écran';

  @override
  String get profileInstallIosStep2 =>
      'Faites défiler et appuyez sur « Sur l’écran d’accueil »';

  @override
  String get profileInstallIosStep3 =>
      'Appuyez sur « Ajouter » en haut à droite';

  @override
  String get profileInstallIosStep4 =>
      'L’appli apparaîtra sur votre écran d’accueil !';

  @override
  String get profileInstallAndroidStep1 =>
      'Appuyez sur le menu Plus (⋯) en haut à droite';

  @override
  String get profileInstallAndroidStep2 =>
      'Appuyez sur « Ajouter à l’écran d’accueil »';

  @override
  String get profileInstallAndroidStep3 =>
      'Appuyez sur « Installer l’application »';

  @override
  String get profileInstallAndroidStep4 =>
      'L’appli apparaîtra sur votre écran d’accueil !';

  @override
  String get profileInstallGotIt => 'Compris';

  @override
  String get exploreMetaDefaultTitle => 'Parkour·Spot';

  @override
  String get exploreMetaDefaultDescription =>
      'Découvrez, cartographiez et partagez les meilleurs spots de parkour dans le monde avec des photos de la communauté, des notes et des conseils locaux pour votre prochaine session.';

  @override
  String exploreMetaTitleCityCountry(String city, String country) {
    return 'Meilleurs spots de parkour à $city, $country';
  }

  @override
  String exploreMetaDescriptionCityCountry(String city, String country) {
    return 'Découvrez les meilleurs spots de parkour à $city, $country. Trouvez des lieux d’entraînement, partagez vos spots préférés et rejoignez la communauté parkour.';
  }

  @override
  String exploreMetaTitleCountry(String country) {
    return 'Meilleurs spots de parkour en $country';
  }

  @override
  String exploreMetaDescriptionCountry(String country) {
    return 'Découvrez les meilleurs spots de parkour en $country. Trouvez des lieux d’entraînement, partagez vos spots préférés et rejoignez la communauté parkour.';
  }

  @override
  String get exploreAddSpotTitle => 'Ajouter un spot';

  @override
  String get exploreAddSpotSubtitle =>
      'Partagez vos spots de parkour préférés avec la communauté';

  @override
  String get exploreSignInToAddSpot => 'Connectez-vous pour ajouter un spot';

  @override
  String get exploreLoadingProfile => 'Chargement du profil…';

  @override
  String get exploreSearchHint => 'Rechercher un lieu ou un spot…';

  @override
  String get exploreFilterBy => 'Filtrer par';

  @override
  String get exploreFilterAmenities => 'Équipements';

  @override
  String get exploreFilterSources => 'Sources';

  @override
  String get exploreSpotAccessTitle => 'Accès au spot';

  @override
  String get exploreSpotAccessSubtitle =>
      'Filtrer les spots par niveau d’accès';

  @override
  String get exploreFilterAny => 'Tous';

  @override
  String get exploreSpotFacilitiesTitle => 'Équipements du spot';

  @override
  String get exploreSpotFacilitiesSubtitle =>
      'Afficher les spots avec ces commodités';

  @override
  String get exploreAttributesTitle => 'Avec l’un de ces attributs';

  @override
  String get exploreAttributesSubtitle =>
      'Filtrer les spots qui ont au moins une des compétences ou caractéristiques sélectionnées';

  @override
  String get exploreGoodForSegment => 'Adapté pour';

  @override
  String get exploreSpotFeaturesSegment => 'Caractéristiques du spot';

  @override
  String get exploreSpotSourceLabel => 'Source du spot';

  @override
  String get exploreSourcesLoadError => 'Échec du chargement des sources';

  @override
  String get exploreAllSources => 'Toutes les sources';

  @override
  String get exploreParkourSpotNative => 'Parkour·Spot (natif)';

  @override
  String get exploreAllFolders => 'Tous les dossiers';

  @override
  String exploreLocationError(String error) {
    return 'Erreur de localisation : $error';
  }

  @override
  String get exploreCurrentLocationSnackbar => 'Voici votre position actuelle';

  @override
  String get exploreCloseTooltip => 'Fermer';

  @override
  String get exploreClearSearchTooltip => 'Effacer';

  @override
  String get exploreFiltersTooltip => 'Filtres';

  @override
  String get exploreFindingLocation => 'Recherche de la position…';

  @override
  String get exploreAddSpotHereTitle => 'Ajouter un spot à cet endroit ?';

  @override
  String exploreMapRankedTotalBar(int total) {
    return '$total spots';
  }

  @override
  String exploreMapSpotsFoundLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots trouvés',
      one: '1 spot trouvé',
    );
    return '$_temp0';
  }

  @override
  String exploreMapBestShownParenthetical(int count) {
    return ' ($count meilleurs affichés)';
  }

  @override
  String get exploreNoSpotsSearch => 'Aucun spot trouvé';

  @override
  String get exploreNoSpotsArea => 'Aucun spot dans cette zone';

  @override
  String get exploreNoSpotsSearchHint =>
      'Essayez d’ajuster vos termes de recherche';

  @override
  String get exploreNoSpotsMapHint =>
      'Déplacez la carte pour explorer d’autres zones';

  @override
  String get exploreRefreshMapTooltip =>
      'Actualiser les spots dans la vue actuelle';

  @override
  String get exploreSwitchToMap => 'Carte';

  @override
  String get exploreSwitchToSatellite => 'Satellite';

  @override
  String get exploreLocationPermissionDenied =>
      'Autorisation de localisation refusée';

  @override
  String get exploreCenterOnMyLocation => 'Centrer sur ma position';

  @override
  String get exploreFiltersDialogTitle => 'Filtres';

  @override
  String get exploreClearFilters => 'Effacer';

  @override
  String get exploreApplyFilters => 'Appliquer';

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
  String get explorePwaBannerInstall => 'Installer';
}
