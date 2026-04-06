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
}
