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
  String get tabAdd => 'Ajouter';

  @override
  String get tabAccount => 'Compte';

  @override
  String get profileSettingsTitle => 'Réglages';

  @override
  String get profileSettingsSubtitle => 'Langue et lieux qui vous intéressent';

  @override
  String get profileSettingsLanguageLabel => 'Langue';

  @override
  String get profileSettingsLanguageDescription =>
      'Choisissez une langue ou suivez les réglages de l’appareil.';

  @override
  String get profileLanguageSystemDefault =>
      'Automatique (anglais si non pris en charge)';

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
  String get accountSpotListsSubtitle =>
      'À visiter, déjà visité, spots que vous avez ajoutés, et listes que vous créez ou enregistrez';

  @override
  String get spotListsHubSignInPrompt =>
      'Connectez-vous pour voir et gérer vos listes';

  @override
  String get spotListsHubCouldNotLoad =>
      'Impossible de charger les listes. Vérifiez votre connexion et réessayez.';

  @override
  String get spotListsHubAddedByYou => 'Ajoutés par vous';

  @override
  String publicProfileAddedByUser(String name) {
    return 'Ajoutés par $name';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'Nouveaux spots à proximité, séances planifiées, check-ins et autres nouvelles pour vous';

  @override
  String get notificationsEmptyTitle => 'Tout est calme pour l’instant';

  @override
  String get notificationsEmptyBody =>
      'Quand quelqu’un ajoute un spot à proximité, planifie une séance où vous vous entraînez ou fait un check-in à proximité, vous le verrez ici.';

  @override
  String get notificationsLoadError =>
      'Impossible de charger vos notifications. Vérifiez votre connexion et réessayez.';

  @override
  String get notificationsRetry => 'Réessayer';

  @override
  String get notificationsOpenFailedSnackbar =>
      'Impossible d’ouvrir cette notification. Réessayez plus tard.';

  @override
  String get notificationsMarkAllRead => 'Tout marquer comme lu';

  @override
  String get notificationsMarkAllReadFailed =>
      'Impossible de tout marquer comme lu. Réessayez.';

  @override
  String get notificationsMarkAsReadFailed =>
      'Impossible de marquer comme lu. Réessayez.';

  @override
  String get notificationsMarkAsUnreadFailed =>
      'Impossible de marquer comme non lu. Réessayez.';

  @override
  String get notificationsMarkAsUnreadHint =>
      'Appui long pour marquer comme non lu';

  @override
  String get notificationsMarkAsReadHint => 'Appui long pour marquer comme lu';

  @override
  String get notificationsShowAll => 'Tout afficher';

  @override
  String get notificationsUnreadOnly => 'Non lues seulement';

  @override
  String get notificationsEmptyFilteredTitle => 'Vous êtes à jour';

  @override
  String get notificationsEmptyFilteredBody =>
      'Aucune notification non lue pour le moment.';

  @override
  String get notificationsTimeUnknown => 'Récemment';

  @override
  String notificationsOpenSemantic(String title) {
    return 'Ouvrir la notification : $title';
  }

  @override
  String get notificationsActorSomeone => 'Quelqu’un';

  @override
  String get notificationsSpotUntitled => 'Spot sans titre';

  @override
  String get notificationsEventUntitled => 'Événement sans titre';

  @override
  String notificationNearbyNewSpotTitle(String spotName) {
    return 'Nouveau spot à proximité : $spotName';
  }

  @override
  String notificationNearbyNewSpotBody(String actorName) {
    return '$actorName a ajouté un nouveau spot de parkour près d’un de vos lieux enregistrés.';
  }

  @override
  String notificationNearbyCheckInTitle(String actorName, String spotName) {
    return '$actorName s’entraîne maintenant à $spotName';
  }

  @override
  String get notificationNearbyCheckInBody =>
      'Vient de s’enregistrer sur ce spot.';

  @override
  String notificationNearbyTrainingPlanTitle(
    String actorName,
    String spotName,
  ) {
    return '$actorName a planifié un entraînement à $spotName';
  }

  @override
  String get notificationNearbyTrainingPlanBody =>
      'Une fenêtre d’entraînement publique a été partagée près de l’un de vos lieux enregistrés.';

  @override
  String notificationTrainingPlanCheckInReminderTitle(String spotName) {
    return 'C’est l’heure du check-in à $spotName';
  }

  @override
  String get notificationTrainingPlanCheckInReminderBody =>
      'Votre séance prévue a commencé. Touchez pour vous enregistrer.';

  @override
  String notificationNearbyNewEventTitle(String eventName) {
    return 'Nouvel événement à proximité : $eventName';
  }

  @override
  String get notificationNearbyNewEventBody =>
      'Un événement a été ajouté près de l’un de vos lieux enregistrés.';

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
  String get profileLocationAlertsTitle => 'Alertes de localisation';

  @override
  String get profileNotificationSettingsTitle => 'Paramètres de notification';

  @override
  String get profilePushNotificationsThisDeviceTitle =>
      'Notifications push sur ce navigateur/cet appareil';

  @override
  String get profilePushNotificationsUnsupported =>
      'Les notifications push ne sont pas prises en charge par ce navigateur.';

  @override
  String get profilePushNotificationsLoading =>
      'Vérification de l’état des notifications push sur cet appareil…';

  @override
  String get profilePushNotificationsPermissionDenied =>
      'L’autorisation push est bloquée dans les paramètres du navigateur pour ce site.';

  @override
  String get profilePushNotificationsPermissionNotDetermined =>
      'Activez cette option pour demander l’autorisation et abonner ce navigateur.';

  @override
  String get profilePushNotificationsEnabled =>
      'Ce navigateur est abonné et peut recevoir des alertes push.';

  @override
  String get profilePushNotificationsPermissionGrantedButOff =>
      'L’autorisation est accordée, mais ce navigateur n’est pas abonné actuellement.';

  @override
  String get profilePushNotificationsUnknown =>
      'L’état push est indisponible pour le moment. Réessayez bientôt.';

  @override
  String get profilePushNotificationsError =>
      'Impossible de mettre à jour les notifications push sur ce navigateur. Réessayez.';

  @override
  String get profileLocationAlertsDescription =>
      'Choisissez les lieux utilisés pour les alertes à proximité, y compris les enregistrements, les nouveaux spots, les séances planifiées et les événements.';

  @override
  String get profileLocationAlertsShareLastKnownTitle =>
      'Dernière position connue';

  @override
  String get profileLocationAlertsShareLastKnownSubtitle =>
      'Lorsque cette option est activée, cette position est enregistrée dans le cloud pour les alertes à proximité.';

  @override
  String get profileLocationAlertsShareLastKnownOnSubtitle =>
      'Désactivez cette option pour arrêter d’enregistrer cette position.';

  @override
  String profileLocationAlertsLastKnownActiveSubtitle(String details) {
    return '$details. Désactivez cette option pour arrêter d’enregistrer cette position.';
  }

  @override
  String get profileLocationAlertsLastKnownLabel => 'Dernière position connue';

  @override
  String get profileLocationAlertsNotifyNewSpotsTitle =>
      'Me prévenir des nouveaux spots à proximité';

  @override
  String get profileLocationAlertsNotifyNewSpotsSubtitle =>
      'Recevez une notification lorsqu’un spot est ajouté dans le rayon d’alerte d’un lieu enregistré actif ou de votre dernière position connue.';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsTitle =>
      'Me prévenir des check-ins à proximité';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsSubtitle =>
      'Recevez une notification lorsque quelqu’un fait un check-in sur un spot dans le rayon d’alerte d’un lieu enregistré actif ou de votre dernière position connue.';

  @override
  String get profileLocationAlertsNotifyTrainingPlansTitle =>
      'Me prévenir des séances planifiées à proximité';

  @override
  String get profileLocationAlertsNotifyTrainingPlansSubtitle =>
      'Recevez une notification lorsque quelqu’un partage une fenêtre d’entraînement publique sur un spot dans le rayon d’alerte d’un lieu enregistré actif ou de votre dernière position connue.';

  @override
  String get profileLocationAlertsNotifyEventsTitle =>
      'Me prévenir des événements à proximité';

  @override
  String get profileLocationAlertsNotifyEventsSubtitle =>
      'Recevez une notification lorsqu’un événement est ajouté dans le rayon d’alerte d’un lieu enregistré actif ou de votre dernière position connue.';

  @override
  String get profileTrainingPlanCheckInReminderTitle =>
      'Me rappeler de faire un check-in pour les séances planifiées';

  @override
  String get profileTrainingPlanCheckInReminderSubtitle =>
      'Recevez un rappel lorsque votre séance prévue a commencé et que vous n’avez pas encore fait de check-in sur ce spot.';

  @override
  String get profileLocationAlertsSavedLocationsTitle => 'Mes lieux d’intérêt';

  @override
  String get profileLocationAlertsAddLocationButton => 'Ajouter';

  @override
  String get profileLocationAlertsNoLocationsEnabledWarning =>
      'Vous ne recevrez aucune notification basée sur la localisation tant que la dernière position connue est désactivée et qu’aucun lieu enregistré n’est activé.';

  @override
  String get profileLocationAlertsEmptyState =>
      'Aucun lieu enregistré pour le moment. Ajoutez des endroits comme Domicile ou Travail.';

  @override
  String get profileLocationAlertsDefaultLabel => 'Lieu enregistré';

  @override
  String get profileLocationAlertsDisableTooltip => 'Désactiver';

  @override
  String get profileLocationAlertsEnableTooltip => 'Activer';

  @override
  String get profileLocationAlertsEditTooltip => 'Modifier';

  @override
  String get profileLocationAlertsDeleteTooltip => 'Supprimer';

  @override
  String get profileLocationAlertsDeleteTitle =>
      'Supprimer le lieu enregistré ?';

  @override
  String profileLocationAlertsDeleteMessage(String label) {
    return 'Voulez-vous vraiment supprimer $label ?';
  }

  @override
  String get profileLocationAlertsDeleteConfirmButton => 'Supprimer';

  @override
  String get profileLocationAlertsDialogAddTitle => 'Ajouter un lieu';

  @override
  String get profileLocationAlertsDialogEditTitle => 'Modifier le lieu';

  @override
  String get profileLocationAlertsDialogEditLastKnownTitle =>
      'Modifier la dernière position connue';

  @override
  String get profileLocationAlertsLabelFieldLabel => 'Libellé';

  @override
  String get profileLocationAlertsLabelFieldPlaceholder => 'Domicile';

  @override
  String get profileLocationAlertsEnabledLabel => 'Activé';

  @override
  String get profileLocationAlertsRadiusFieldLabel => 'Rayon d’alerte';

  @override
  String profileLocationAlertsRadiusOption(int km) {
    return '$km km';
  }

  @override
  String get profileLocationAlertsLabelRequired => 'Veuillez saisir un libellé';

  @override
  String get profileLocationAlertsLocationRequired =>
      'Veuillez choisir un lieu sur la carte';

  @override
  String get profileLocationAlertsSaveButton => 'Enregistrer';

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
  String profileInstallIntro(String device, String browser) {
    return 'Pour installer Parkour·Spot sur votre $device, ouvrez cette page dans $browser, puis suivez ces étapes :';
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
  String get exploreSignInToAddSpot =>
      'Connectez-vous pour ajouter des spots et des événements';

  @override
  String get exploreSignInToAddSubtitle =>
      'Contribuez avec de nouveaux spots ou soumettez des propositions d\'événements pour examen par les modérateurs.';

  @override
  String get addHubHeading => 'Que voulez-vous ajouter ?';

  @override
  String get addHubSubtitle =>
      'Partagez ce que vous savez sur la carte de la communauté.';

  @override
  String get addHubSpotTitle => 'Ajouter un spot';

  @override
  String get addHubSpotDescription =>
      'Posez une épingle, ajoutez des photos et placez un nouveau spot d\'entraînement sur la carte.';

  @override
  String get addHubSpotPublishBadge => 'En ligne sur la carte tout de suite';

  @override
  String get addHubSpotButton => 'Ajouter un spot';

  @override
  String get addHubEventTitle => 'Ajouter un nouvel événement';

  @override
  String get addHubEventDescription =>
      'Proposez un jam, une rencontre ou une session pour que d\'autres le trouvent.';

  @override
  String get addHubEventModerationBadge => 'Examiné par les modérateurs';

  @override
  String get addHubEventButton => 'Ajouter un nouvel événement';

  @override
  String get addHubSignInTitle => 'Connectez-vous pour contribuer';

  @override
  String get addHubSignInSubtitle =>
      'Compte gratuit. Ajoutez des spots à la carte ou proposez des événements pour la communauté.';

  @override
  String get exploreLoadingProfile => 'Chargement du profil…';

  @override
  String get exploreSearchHint => 'Rechercher un lieu ou un spot…';

  @override
  String get explorePickerTitleLocation => 'Choisir un lieu';

  @override
  String get explorePickerTitleSpots => 'Choisir un spot';

  @override
  String get explorePickerTitleEvents => 'Choisir un événement';

  @override
  String get explorePickerTitleSpotsAndEvents =>
      'Choisir un spot ou un événement';

  @override
  String get explorePickerTitleEventWhere =>
      'Choisir un emplacement ou des spots';

  @override
  String get explorePickerSearchHintEvents =>
      'Rechercher un lieu ou un événement…';

  @override
  String get explorePickerSearchHintLocation => 'Rechercher un lieu…';

  @override
  String get explorePickerConfirmSelect => 'Sélectionner';

  @override
  String get explorePickerConfirmAdd => 'Ajouter';

  @override
  String get explorePickerReplaceSpotsTitle => 'Utiliser cet emplacement ?';

  @override
  String explorePickerReplaceSpotsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cela remplace $count spots sélectionnés.',
      one: 'Cela remplace le spot sélectionné.',
    );
    return '$_temp0';
  }

  @override
  String get explorePickerKeepSpots => 'Garder les spots';

  @override
  String get explorePickerUseLocation => 'Utiliser l’emplacement';

  @override
  String get explorePickerReplaceLocationBody =>
      'Cela remplace l’emplacement exact.';

  @override
  String get explorePickerKeepLocation => 'Garder l’emplacement';

  @override
  String get explorePickerUseSpotInstead => 'Ajouter le spot';

  @override
  String get explorePickerEventWhereHint =>
      'Choisissez un emplacement exact, ou un ou plusieurs spots.';

  @override
  String explorePickerEventWhereReplacesListHint(String name) {
    return 'Choisir un emplacement ou des spots remplacera $name.';
  }

  @override
  String explorePickerEventWhereListLinked(String name) {
    return 'Liste liée : $name';
  }

  @override
  String get explorePickerEventWhereNone => 'Rien n’est sélectionné.';

  @override
  String get explorePickerEventWherePin => 'Emplacement exact défini.';

  @override
  String explorePickerEventWhereSpots(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots sélectionnés',
      one: '$name',
    );
    return '$_temp0';
  }

  @override
  String get explorePickerMultiSpotsHint =>
      'Touche des spots sur la carte pour les ajouter. Confirme quand tu as fini.';

  @override
  String explorePickerMultiSpotsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots sélectionnés',
      one: '$name',
    );
    return '$_temp0';
  }

  @override
  String get explorePickerConfirmDone => 'Terminé';

  @override
  String get explorePickerAlreadyAdded => 'Ajouté';

  @override
  String explorePickerDone(int count) {
    return 'Terminé ($count)';
  }

  @override
  String get explorePickerLoading => 'Chargement de la carte…';

  @override
  String get exploreFilterBy => 'Filtrer les spots par';

  @override
  String get exploreFilterHasImages => 'Avec photos';

  @override
  String get exploreFilterAmenities => 'Attributs';

  @override
  String get exploreFilterSources => 'Sources';

  @override
  String get exploreSpotPhotosTitle => 'Photos';

  @override
  String get exploreSpotAccessTitle => 'Accès';

  @override
  String get exploreSpotFacilitiesTitle => 'Équipements';

  @override
  String get exploreFacilitiesMatchAllHint =>
      'Doit avoir tous les éléments sélectionnés';

  @override
  String get exploreAttributesMatchAnyHint => 'Correspond à n’importe lequel';

  @override
  String get exploreGoodForSegment => 'Adapté pour';

  @override
  String get exploreSpotFeaturesSegment => 'Caractéristiques';

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
  String get exploreMapListModeSpots => 'Spots';

  @override
  String get exploreMapListModeEvents => 'Événements';

  @override
  String get exploreNoEventsArea => 'Aucun événement dans cette zone';

  @override
  String get exploreNoEventsAreaHint =>
      'Déplacez la carte ou revenez plus tard';

  @override
  String get spotCardUpcomingEventBadge => 'Événement';

  @override
  String get exploreEventLocate => 'Localiser';

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
  String get exploreDoneFilters => 'Terminé';

  @override
  String exploreDoneFiltersWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Terminé · $count spots',
      one: 'Terminé · 1 spot',
    );
    return '$_temp0';
  }

  @override
  String exploreSpotCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots',
      one: '$count spot',
    );
    return '$_temp0';
  }

  @override
  String get explorePwaBannerInstall => 'Installer';

  @override
  String get addSpotPickImagesFailed =>
      'Impossible de choisir les images. Réessayez.';

  @override
  String get addSpotTakePhotoFailed =>
      'Impossible de prendre la photo. Réessayez.';

  @override
  String get addSpotNeedPhoto => 'Ajoutez au moins une photo du spot';

  @override
  String get addSpotNeedLocation =>
      'Attendez la localisation ou choisissez un point sur la carte';

  @override
  String addSpotCreateError(String error) {
    return 'Erreur lors de la création du spot : $error';
  }

  @override
  String get addSpotNameLabel => 'Nom du spot *';

  @override
  String get addSpotNameRequired => 'Saisissez un nom de spot';

  @override
  String get addSpotDescriptionLabel => 'Description';

  @override
  String get addSpotDescriptionRequired => 'Saisissez une description';

  @override
  String get addSpotDescriptionMinLength =>
      'La description doit contenir au moins 10 caractères';

  @override
  String get addSpotCreating => 'Ajout du spot…';

  @override
  String get addSpotCreateButton => 'Ajouter un spot';

  @override
  String get addSpotLocationSectionTitle => 'Choisir l’emplacement du spot';

  @override
  String get addSpotGettingLocation => 'Localisation en cours…';

  @override
  String get addSpotLocationNotAvailable => 'Localisation indisponible';

  @override
  String get addSpotPickLocationHint => 'Choisir l’emplacement';

  @override
  String get addSpotImagesSectionTitle => 'Choisir les images du spot';

  @override
  String get addSpotGalleryButton => 'Galerie';

  @override
  String get addSpotCameraButton => 'Appareil photo';

  @override
  String get addSpotGoodForTitle => 'Adapté pour';

  @override
  String get addSpotGoodForSubtitle =>
      'Quelles compétences de parkour peut-on y travailler ?';

  @override
  String get addSpotFeaturesTitle => 'Caractéristiques du spot';

  @override
  String get addSpotFeaturesSubtitle =>
      'Quelles caractéristiques physiques ce spot offre-t-il ?';

  @override
  String get addSpotAccessTitle => 'Accès au spot';

  @override
  String get addSpotAccessSubtitle => 'Quel est le niveau d’accès à ce spot ?';

  @override
  String get addSpotFacilitiesFormTitle => 'Équipements du spot';

  @override
  String get addSpotFacilitiesSubtitle =>
      'Quels services sont disponibles sur ce spot ?';

  @override
  String get addSpotLongPressHintSkill =>
      'Appui long sur une compétence pour plus d’infos';

  @override
  String get addSpotLongPressHintFeature =>
      'Appui long sur une caractéristique pour plus d’infos';

  @override
  String get addSpotLongPressHintFacility =>
      'Appui long sur un équipement pour plus d’infos';

  @override
  String get addSpotPickLocationAppBarTitle => 'Choisir l’emplacement';

  @override
  String get addSpotTipLongPressMobile =>
      'Astuce : vous pouvez aussi ajouter des spots depuis la carte Explorer en appuyant longuement sur un lieu.';

  @override
  String get addSpotTipRightClickDesktop =>
      'Astuce : vous pouvez aussi ajouter des spots depuis la carte Explorer en cliquant droit sur un lieu.';

  @override
  String get addEventTipLongPressMobile =>
      'Astuce : vous pouvez aussi ajouter des événements depuis la carte Explorer en appuyant longuement sur un lieu.';

  @override
  String get addEventTipRightClickDesktop =>
      'Astuce : vous pouvez aussi ajouter des événements depuis la carte Explorer en cliquant droit sur un lieu.';

  @override
  String get addSpotUseThisLocation => 'Utiliser cet emplacement';

  @override
  String get addSpotDirectionsTooltip => 'Itinéraire';

  @override
  String get addSpotGettingAddress => 'Récupération de l’adresse…';

  @override
  String get addEventTitle => 'Ajouter un nouvel événement';

  @override
  String get addEventTitleLabel => 'Titre de l\'événement *';

  @override
  String get addEventTitleRequired => 'Le titre est obligatoire.';

  @override
  String get addEventTitleTooLong => 'Le titre est trop long.';

  @override
  String get addEventDescriptionLabel => 'Description';

  @override
  String get addEventDescriptionTooLong => 'La description est trop longue.';

  @override
  String get addEventWebsiteLabel => 'URL du site web';

  @override
  String get addEventWebsiteHint => 'https://example.com';

  @override
  String get addEventPhotosSectionTitle => 'Choisir les images de l\'événement';

  @override
  String get addEventAllDay => 'Événement sur toute la journée';

  @override
  String get addEventTimezoneLabel => 'Fuseau horaire';

  @override
  String get addEventStartLabel => 'Début';

  @override
  String get addEventEndLabel => 'Fin';

  @override
  String get addEventEndNotSet => 'Non défini';

  @override
  String get addEventClearEndTooltip => 'Effacer la fin';

  @override
  String get addEventSchedulePickStartDate => 'Choisir la date de début';

  @override
  String get addEventSchedulePickStartTime => 'Choisir l\'heure de début';

  @override
  String get addEventSchedulePickEndDateOptional => 'Choisir la date de fin';

  @override
  String get addEventSchedulePickEndTimeOptional => 'Choisir l\'heure de fin';

  @override
  String get addEventScheduleSkipEnd => 'Ignorer';

  @override
  String get addEventScheduleLabel => 'Dates';

  @override
  String get addEventLinkingSectionTitle => 'Liaison';

  @override
  String get addEventWhereSectionTitle =>
      'Choisir l\'emplacement de l\'événement';

  @override
  String get addEventWhenSectionTitle =>
      'Choisir le calendrier de l\'événement';

  @override
  String get addEventAddressNeedsResolve =>
      'Appuie sur l\'icône de recherche à côté de l\'adresse pour la confirmer, ou choisis un lieu sur la carte.';

  @override
  String get addEventLinkSpotButton => 'Lier un spot';

  @override
  String addEventLinkedSpotLabel(String name) {
    return 'Spot : $name';
  }

  @override
  String addEventLinkedSpotListLabel(String name) {
    return 'Liste de spots : $name';
  }

  @override
  String get addEventLocationNotSet => 'Emplacement non défini';

  @override
  String get addEventExactLocationSet => 'Emplacement exact défini';

  @override
  String get addEventLocationSectionTitle => 'Emplacement';

  @override
  String get addEventLocationSectionHint =>
      'Choisissez un emplacement exact, un ou plusieurs spots, ou une liste de spots.';

  @override
  String get addEventChooseOnMapHint => 'Choisir sur la carte';

  @override
  String get addEventLinkListButton => 'Lier une liste';

  @override
  String get addEventWhereReplacedSpots =>
      'L’emplacement exact a remplacé les spots liés.';

  @override
  String get addEventWhereReplacedLocation =>
      'Les spots liés ont remplacé l’emplacement exact.';

  @override
  String get addEventWhereReplacedWithList =>
      'La liste de spots a remplacé l’emplacement précédent.';

  @override
  String addEventWhereReplacedListWithLocation(String name) {
    return 'L’emplacement exact a remplacé $name.';
  }

  @override
  String addEventWhereReplacedListWithSpots(String name) {
    return 'Les spots liés ont remplacé $name.';
  }

  @override
  String get addEventAddressLabel => 'Adresse exacte';

  @override
  String get addEventAddressHint => 'Rue, numéro, ville';

  @override
  String get addEventUseAddressButton => 'Utiliser l\'adresse';

  @override
  String get addEventPickLocationButton => 'Choisir sur la carte';

  @override
  String get addEventClearAddressTooltip => 'Effacer l\'adresse';

  @override
  String get addEventAddressRequiredToResolve =>
      'Saisissez une adresse à rechercher.';

  @override
  String get addEventAddressNotFound =>
      'Impossible de trouver les coordonnées de cette adresse.';

  @override
  String get addEventPickLocationHint =>
      'Choisissez un emplacement sur la carte.';

  @override
  String get addEventClearLocationTooltip => 'Effacer l\'emplacement';

  @override
  String get addEventPickLocationTooltip => 'Choisir un emplacement';

  @override
  String addEventApproxCoordinates(String latitude, String longitude) {
    return 'Environ $latitude, $longitude';
  }

  @override
  String get addEventSubmitting => 'Envoi…';

  @override
  String get addEventSubmitButton => 'Soumettre pour examen';

  @override
  String get addEventWebsiteInvalid =>
      'L\'URL du site web doit être une URL http(s) valide.';

  @override
  String get addEventEndBeforeStart =>
      'L\'heure de fin ne peut pas être antérieure à l\'heure de début.';

  @override
  String get addEventNeedLocationOrLink => 'L\'emplacement est obligatoire.';

  @override
  String addEventMaxPhotos(int count) {
    return 'Maximum $count photos autorisées.';
  }

  @override
  String get addEventUploadPhotosFailed =>
      'Impossible de téléverser les photos. Veuillez réessayer.';

  @override
  String get addEventSubmitFailed =>
      'Impossible de soumettre la proposition d\'événement.';

  @override
  String get addEventSubmitSuccess =>
      'Événement soumis à la file d\'attente des modérateurs.';

  @override
  String get noImagesYet => 'Pas encore d’images';

  @override
  String get spotCardNoDescription => 'Pas encore de description';

  @override
  String get spotCardPartOfPrefix => 'Fait partie de ';

  @override
  String get spotCardRemoveFromListTooltip => 'Retirer de la liste';

  @override
  String get spotCardCopiedToClipboard => 'Spot copié dans le presse-papiers !';

  @override
  String spotCardShareFailed(String error) {
    return 'Impossible de partager le spot : $error';
  }

  @override
  String get spotCardRemovedFromSource => 'Retiré de la source';

  @override
  String get spotCheckInUnnamedPerson => 'Cette personne';

  @override
  String spotCheckInTooltipPublic(String name, String time) {
    return '$name est ici maintenant jusqu’à $time';
  }

  @override
  String spotCheckInTooltipPrivate(String time) {
    return 'Vous êtes ici maintenant jusqu’à $time — vous seul voyez ce check-in';
  }

  @override
  String spotTrainingPlanTooltipPublic(String name, String timeRange) {
    return '$name prévoit de s’entraîner ici $timeRange';
  }

  @override
  String spotTrainingPlanTooltipPrivate(String timeRange) {
    return 'Vous prévoyez de vous entraîner ici $timeRange — vous seul voyez ce plan';
  }

  @override
  String spotTrainingPlanTooltipPublicUntil(String name, String untilTime) {
    return '$name prévoit de s’entraîner ici jusqu’à $untilTime';
  }

  @override
  String spotTrainingPlanTooltipPrivateUntil(String untilTime) {
    return 'Vous prévoyez de vous entraîner ici jusqu’à $untilTime — vous seul voyez ce plan';
  }

  @override
  String get spotDetailRouteErrorLoading => 'Erreur lors du chargement du spot';

  @override
  String get spotDetailRouteTryAgainLater => 'Réessayez plus tard';

  @override
  String get spotDetailRouteNotFound => 'Spot introuvable';

  @override
  String get spotDetailRouteGoToExplore => 'Aller à Explorer';

  @override
  String get spotDetailCheckInVerifyFailed =>
      'Impossible de vérifier vos check-ins';

  @override
  String get spotDetailCheckInEndPreviousFailed =>
      'Impossible de terminer le check-in précédent';

  @override
  String get spotDetailCheckInSuccess => 'Vous êtes enregistré·e';

  @override
  String get spotDetailCheckInFailed => 'Échec du check-in';

  @override
  String get spotDetailCheckInRemoved => 'Check-in supprimé';

  @override
  String get spotDetailCheckInDeleteFailed =>
      'Impossible de supprimer le check-in';

  @override
  String get spotDetailCheckInUpdated => 'Check-in mis à jour';

  @override
  String get spotDetailCheckInUpdateFailed =>
      'Impossible de mettre à jour le check-in';

  @override
  String get spotDetailCheckInFabTooltipSignIn =>
      'Connectez-vous pour vous enregistrer';

  @override
  String get spotDetailCheckInFabTooltipEdit => 'Modifier le check-in';

  @override
  String get spotDetailCheckInFabTooltipCheckIn => 'S’enregistrer';

  @override
  String spotDetailSpotCreatedOnDateBy(String date) {
    return 'Spot créé $date par ';
  }

  @override
  String get spotDetailSpotCreatedBy => 'Spot créé par ';

  @override
  String get spotDetailUnknownSource => 'Source inconnue';

  @override
  String spotDetailSpotImportedOnDateFrom(String date) {
    return 'Spot importé $date depuis ';
  }

  @override
  String get spotDetailSpotImportedFrom => 'Spot importé depuis ';

  @override
  String get spotDetailFromFolder => ' du dossier ';

  @override
  String get spotDetailImprovedByAfterComma => ', amélioré par ';

  @override
  String get spotDetailImprovedByAfterAnd => ' et amélioré par ';

  @override
  String get spotDetailUnknownUser => 'Inconnu';

  @override
  String get spotDetailListJoinAnd => ' et ';

  @override
  String get spotDetailListJoinComma => ', ';

  @override
  String spotDetailLastUpdatedAfterCommaAnd(String date) {
    return ', et mis à jour pour la dernière fois $date.';
  }

  @override
  String spotDetailLastUpdatedAfterAnd(String date) {
    return ' et mis à jour pour la dernière fois $date.';
  }

  @override
  String get spotDetailDateToday => 'aujourd’hui';

  @override
  String get spotDetailDateYesterday => 'hier';

  @override
  String get communityDateTomorrow => 'demain';

  @override
  String communityActivityTrainSameDay(
    String startTime,
    String endTime,
    String day,
  ) {
    return 'De $startTime à $endTime $day';
  }

  @override
  String communityActivityTrainSpan(
    String startTime,
    String startDay,
    String endTime,
    String endDay,
  ) {
    return 'De $startTime $startDay à $endTime $endDay';
  }

  @override
  String get communityShareSpotFallbackName => 'ce spot';

  @override
  String communityShareCheckInNarrative(String spotName, String untilPhrase) {
    return 'Je m\'entraîne en ce moment à $spotName jusqu\'à environ $untilPhrase';
  }

  @override
  String communityShareTrainingPlanNarrative(
    String spotName,
    String relativeDay,
    String startTime,
  ) {
    return 'Je prévois de m\'entraîner à $spotName $relativeDay à partir de $startTime';
  }

  @override
  String get communityActivityShareCopiedToClipboard =>
      'Message copié dans le presse-papiers !';

  @override
  String communityActivityShareFailed(String error) {
    return 'Impossible de partager : $error';
  }

  @override
  String spotDetailDateDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count jours',
      one: 'Il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count semaines',
      one: 'Il y a 1 semaine',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count mois',
      one: 'Il y a 1 mois',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count ans',
      one: 'Il y a 1 an',
    );
    return '$_temp0';
  }

  @override
  String spotDetailCopySpotFailed(String error) {
    return 'Impossible de copier le spot : $error';
  }

  @override
  String get spotDetailAddressCopiedToClipboard =>
      'Adresse copiée dans le presse-papiers !';

  @override
  String spotDetailCopyAddressFailed(String error) {
    return 'Impossible de copier l’adresse : $error';
  }

  @override
  String spotDetailOpenMapsFailed(String error) {
    return 'Impossible d’ouvrir l’app cartes : $error';
  }

  @override
  String get spotDetailMoreActionsTooltip => 'Plus d’actions';

  @override
  String get spotDetailMenuLogin => 'Connexion';

  @override
  String get spotDetailMenuLoginSubtitle => 'Connectez-vous pour continuer';

  @override
  String get spotDetailMenuFlagDuplicate => 'Marquer comme doublon';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleYes => 'Ce spot est un doublon';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleNo =>
      'Déjà marqué comme doublon';

  @override
  String get spotDetailMenuSuggestPhoto => 'Suggérer une photo';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleYes =>
      'Envoyer des photos pour ce spot';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleNo =>
      'Pas de photos pour les doublons';

  @override
  String get spotDetailMenuSuggestEdit => 'Suggérer une modification';

  @override
  String get spotDetailMenuSuggestEditSubtitleYes =>
      'Proposer des changements pour ce spot';

  @override
  String get spotDetailMenuSuggestEditSubtitleNo =>
      'Pas de modifications pour les doublons';

  @override
  String get spotDetailMenuReportSpot => 'Signaler le spot';

  @override
  String get spotDetailMenuReportSpotSubtitle =>
      'Aidez-nous à examiner ce spot';

  @override
  String get spotDetailMenuEditSpot => 'Modifier le spot';

  @override
  String get spotDetailMenuEditSpotSubtitleNative =>
      'Créez d’abord un spot natif';

  @override
  String get spotDetailMenuEditSpotSubtitleMod => 'Modérateurs uniquement';

  @override
  String get spotDetailMenuMarkDuplicate => 'Marquer comme doublon';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleDup =>
      'Déjà marqué comme doublon';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleMod => 'Modérateurs uniquement';

  @override
  String get spotDetailMenuRemoveDuplicateStatus => 'Retirer le doublon';

  @override
  String get spotDetailMenuRemoveDuplicateSubtitle =>
      'Restaurer la fiche d’origine';

  @override
  String get spotDetailMenuCreateNative => 'Créer un spot natif';

  @override
  String get spotDetailMenuCreateNativeSubtitle =>
      'Copier depuis une source externe';

  @override
  String get spotDetailMenuCreateEvent => 'Créer un événement';

  @override
  String get spotDetailMenuCreateEventSubtitle => 'À ce spot';

  @override
  String get spotDetailMenuHideSpot => 'Masquer le spot';

  @override
  String get spotDetailMenuHideSpotSubtitle => 'Masquer du public';

  @override
  String get spotDetailMenuUnhideSpot => 'Afficher le spot';

  @override
  String get spotDetailMenuUnhideSpotSubtitle => 'Afficher dans l’app';

  @override
  String get spotDetailMenuDeleteSpot => 'Supprimer le spot';

  @override
  String get spotDetailMenuDeleteSubtitleAdmin => 'Administrateurs uniquement';

  @override
  String get spotDetailMenuTriggerResize => 'Déclencher le redimensionnement';

  @override
  String get spotDetailMenuTriggerResizeSubtitle =>
      'Recréer les versions redimensionnées';

  @override
  String get spotDetailMenuImageUrls => 'Aperçu des URL d\'images';

  @override
  String get spotDetailMenuImageUrlsSubtitle =>
      'Original, redimensionné et URL API';

  @override
  String adminImageUrlsDialogTitle(String entityLabel) {
    return 'URL d\'images — $entityLabel';
  }

  @override
  String get adminImageUrlsEmpty => 'Aucune image à afficher.';

  @override
  String adminImageUrlsImageIndex(int index, int total) {
    return 'Image $index sur $total';
  }

  @override
  String get adminImageUrlsLabelFirestore => 'Firestore (original)';

  @override
  String get adminImageUrlsLabel1200x1200 => '1200×1200 attendu';

  @override
  String get adminImageUrlsLabel1200x630 => '1200×630 attendu';

  @override
  String get adminImageUrlsLabelActualDownload =>
      'URL de téléchargement redimensionnée';

  @override
  String get adminImageUrlsLabelSpotsApi => 'URL API Spots';

  @override
  String get adminImageUrlsStatusExists => 'Présent';

  @override
  String get adminImageUrlsStatusMissing => 'Absent';

  @override
  String get adminImageUrlsStatusNotApplicable =>
      'Image Firebase Storage non redimensionnable.';

  @override
  String get adminImageUrlsPreviewOriginal => 'Original';

  @override
  String get adminImageUrlsPreview1200 => '1200×1200';

  @override
  String get adminImageUrlsPreview630 => '1200×630';

  @override
  String get adminImageUrlsCopyRow => 'Copier l\'URL';

  @override
  String get adminImageUrlsCopyAll => 'Tout copier';

  @override
  String get adminImageUrlsCopiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get adminImageUrlsApiFootnote =>
      'L\'API spots renvoie l\'URL API même si le fichier redimensionné manque ; les clients peuvent recevoir une 404 jusqu\'à la fin du redimensionnement.';

  @override
  String get adminImageUrlsEventApiFootnote =>
      'Il n\'y a pas d\'API events. L\'URL API Spots utilise la même transformation 1200×1200 que pour les imageUrls des spots.';

  @override
  String get spotDetailExternalSourceCannotEdit =>
      'Les spots issus de sources externes ne peuvent pas être modifiés. Créez d’abord un spot natif via « Marquer comme doublon » → « Créer un spot natif ».';

  @override
  String get spotDetailOk => 'OK';

  @override
  String get spotDetailUnableEditNow =>
      'Ce spot ne peut pas être modifié pour le moment.';

  @override
  String get spotDetailOnlyAdminsDelete =>
      'Seuls les administrateurs peuvent supprimer des spots.';

  @override
  String get spotDetailResizeAllHaveVersions =>
      'Toutes les images ont déjà des versions redimensionnées';

  @override
  String spotDetailResizeSummary(
    int triggered,
    int verified,
    String failedPart,
  ) {
    return 'Redimensionnement : $triggered lancés, $verified vérifiés$failedPart';
  }

  @override
  String spotDetailResizeFailedPart(int failed) {
    return ', $failed échoués';
  }

  @override
  String spotDetailResizeTriggerFailed(String error) {
    return 'Impossible de lancer le redimensionnement : $error';
  }

  @override
  String get spotDetailUnableFlagDuplicate =>
      'Impossible de signaler ce spot comme doublon pour le moment.';

  @override
  String get spotDetailThanksDuplicateReport =>
      'Merci ! Votre signalement de doublon a été envoyé.';

  @override
  String get spotDetailUnableSuggestPhotos =>
      'Impossible de suggérer des photos pour ce spot pour le moment.';

  @override
  String get spotDetailCannotSuggestPhotosDuplicate =>
      'Pas de photos pour les spots doublons.';

  @override
  String get spotDetailThanksPhotoSuggestion =>
      'Merci ! Votre suggestion de photo a été envoyée pour examen.';

  @override
  String get spotDetailUnableSuggestEdits =>
      'Impossible de suggérer des modifications pour ce spot pour le moment.';

  @override
  String get spotDetailCannotSuggestEditsDuplicate =>
      'Pas de modifications pour les spots doublons.';

  @override
  String get spotDetailThanksEditSuggestion =>
      'Merci ! Votre suggestion de modification a été envoyée pour examen.';

  @override
  String get spotDetailUnableReportNow =>
      'Impossible de signaler ce spot pour le moment.';

  @override
  String get spotDetailThanksReportSubmitted =>
      'Merci ! Votre signalement a été envoyé.';

  @override
  String get spotDetailUnableAddToList =>
      'Impossible d’ajouter ce spot à une liste pour le moment.';

  @override
  String get spotDetailNoSpotListsAccess =>
      'Vous n’avez pas accès aux listes de spots.';

  @override
  String get spotDetailListCreatedAndAdded => 'Liste créée et spot ajouté !';

  @override
  String get spotDetailSpotAddedToList => 'Spot ajouté à la liste !';

  @override
  String get spotDetailEditReportTooltip => 'Modifier et signaler';

  @override
  String get spotDetailShareTooltip => 'Partager';

  @override
  String get spotDetailQuickActionSave => 'Enregistrer';

  @override
  String get spotDetailQuickActionEdit => 'Modifier';

  @override
  String get spotDetailQuickActionShare => 'Partager';

  @override
  String get spotDetailQuickActionRate => 'Noter';

  @override
  String get spotDetailRatingTooltip => 'Note de la communauté et tes étoiles';

  @override
  String get spotDetailPresenceHereNow => 'Ici maintenant';

  @override
  String get spotDetailCommunitySectionTitle => 'Communauté';

  @override
  String get spotDetailCommunitySectionSubtitle =>
      'Voyez qui s’entraîne ou prévoit de s’entraîner ici, et partagez votre séance.';

  @override
  String get spotDetailCommunityNobodyHere =>
      'Personne n’a encore pointé. Pointez pour indiquer que vous êtes là.';

  @override
  String get spotDetailCommunityNobodyHereShort => 'Personne pour l’instant.';

  @override
  String get spotDetailCommunityNobodySocialShort =>
      'Personne ici ni de passage prévu pour l’instant.';

  @override
  String get spotDetailCommunityActivityLoadError =>
      'Impossible de charger l’activité.';

  @override
  String get spotDetailCommunityActivityEmpty =>
      'Rien à afficher pour le moment.';

  @override
  String get spotDetailCommunityViewAll => 'Tout voir';

  @override
  String get spotDetailCommunityCheckInButton => 'Pointer';

  @override
  String get spotDetailCommunityEditCheckInButton => 'Modifier le pointage';

  @override
  String get spotDetailCommunitySignInToCheckInButton =>
      'Se connecter pour pointer';

  @override
  String get spotDetailCommunityPlanningVisitButton => 'Planifier une séance';

  @override
  String get spotDetailCommunityPlanningVisitTooltip =>
      'Indiquez quand vous vous entraînerez ici.';

  @override
  String get spotDetailCommunityCheckInButtonTooltip =>
      'Montrez aux autres que vous êtes là maintenant.';

  @override
  String get spotDetailCommunityEditCheckInButtonTooltip =>
      'Modifier votre pointage.';

  @override
  String get spotDetailCommunitySignInToCheckInButtonTooltip =>
      'Connectez-vous pour pointer.';

  @override
  String get spotDetailCommunityPlanningToTrain => 'Prévoit de s’entraîner';

  @override
  String get spotDetailCommunityNobodyPlanningShort => 'Pas encore de plans.';

  @override
  String get spotDetailCommunitySignInToPlanButton =>
      'Connectez-vous pour planifier';

  @override
  String get spotDetailCommunityEditTrainingPlanButton => 'Modifier le plan';

  @override
  String get spotCheckInDialogTitle => 'Pointer';

  @override
  String get spotCheckInDialogTitleEdit => 'Modifier le pointage';

  @override
  String get spotCheckInDialogIntroNew =>
      'Indiquez que vous vous entraînez ici et environ jusqu’à quand. Si vous partagez publiquement, vous apparaissez sur la communauté de ce spot jusqu’à l’heure de fin.';

  @override
  String get spotCheckInDialogIntroEdit =>
      'Modifiez les heures d’arrivée et de fin, la visibilité et votre note.';

  @override
  String get spotCheckInDialogSharePublic => 'Partager publiquement';

  @override
  String get spotCheckInDialogShareSub =>
      'Désactivez pour que vous seul·e voyiez ce pointage.';

  @override
  String get spotCheckInDialogLabelArrived => 'Arrivée';

  @override
  String get spotCheckInDialogLabelHereUntil => 'Ici jusqu’à';

  @override
  String get spotCheckInDialogLabelUntil => 'Jusqu’à';

  @override
  String get spotCheckInDialogStillHere => 'Toujours là';

  @override
  String get spotCheckInDialogEndNow => 'Terminer maintenant';

  @override
  String get spotCheckInDialogCancel => 'Annuler';

  @override
  String get spotCheckInDialogSave => 'Enregistrer';

  @override
  String get spotCheckInDialogDelete => 'Supprimer';

  @override
  String get spotCheckInDialogConfirmDeleteTitle => 'Supprimer le pointage ?';

  @override
  String get spotCheckInDialogConfirmDeleteBody =>
      'Supprime cette visite de votre historique. Le spot reste dans votre liste des lieux visités.';

  @override
  String get spotCheckInDialogExtendBannerText =>
      'Vous avez un pointage récemment expiré ici.';

  @override
  String get spotCheckInDialogExtendInstead =>
      'Prolonger ce pointage à la place';

  @override
  String spotCheckInDialogActiveElsewhereAtNamed(String spotName) {
    return 'Vous êtes actuellement pointé·e à $spotName. Pointer ici mettra fin à ce pointage.';
  }

  @override
  String get spotCheckInDialogActiveElsewhereUnnamed =>
      'Vous êtes pointé·e sur un autre spot. Pointer ici mettra fin à ce pointage.';

  @override
  String get spotCheckInDialogActiveElsewhereMultiple =>
      'Vous avez des pointages actifs sur d’autres spots. Pointer ici mettra fin à ces pointages.';

  @override
  String get spotCheckInDialogNudgeEarlier => '15 minutes plus tôt';

  @override
  String get spotCheckInDialogNudgeLater => '15 minutes plus tard';

  @override
  String get spotCheckInDialogTrainingPlanConversionBanner =>
      'En enregistrant, votre plan est remplacé par ce check-in. La fin prévue est préremplie ci-dessous.';

  @override
  String get spotDetailSessionNoteLabel => 'Note (facultatif)';

  @override
  String get spotDetailSessionNoteHint => 'ex. figures ou objectifs de séance';

  @override
  String get spotTrainingPlanDialogTitle => 'Planifier une séance ici';

  @override
  String get spotTrainingPlanDialogTitleEdit =>
      'Modifier le plan d’entraînement';

  @override
  String get spotTrainingPlanDialogCheckInCtaBody =>
      'Vous êtes sur place ? Enregistrez-vous pour indiquer votre arrivée.';

  @override
  String get spotTrainingPlanDialogCheckInCtaBodyEarly =>
      'Déjà là ? Enregistrez-vous pour indiquer votre arrivée.';

  @override
  String get spotTrainingPlanDialogCheckInCtaButton => 'S’enregistrer';

  @override
  String get spotTrainingPlanDialogBody =>
      'Indiquez le début et la fin prévus. Les plans publics apparaissent sur la communauté de ce spot avec les autres personnes qui partagent.';

  @override
  String get spotTrainingPlanDialogSharePublic => 'Partager publiquement';

  @override
  String get spotTrainingPlanDialogShareSub =>
      'Désactivez pour que vous seul·e voyiez le plan.';

  @override
  String get spotTrainingPlanDialogStartLabel => 'Début';

  @override
  String get spotTrainingPlanDialogEndLabel => 'Fin';

  @override
  String get spotTrainingPlanDialogSave => 'Enregistrer';

  @override
  String get spotTrainingPlanDialogCancel => 'Annuler';

  @override
  String get spotTrainingPlanDialogDelete => 'Retirer le plan';

  @override
  String get spotTrainingPlanDialogDeleteTitle => 'Retirer ce plan ?';

  @override
  String get spotTrainingPlanDialogDeleteBody =>
      'Vous pourrez en créer un nouveau à tout moment.';

  @override
  String get spotTrainingPlanValidationOrder =>
      'La fin doit être après le début.';

  @override
  String get spotTrainingPlanValidationMinDuration => 'Au moins 15 minutes.';

  @override
  String get spotTrainingPlanValidationMaxDuration => 'Au plus 12 heures.';

  @override
  String get spotTrainingPlanValidationStartTooFar =>
      'Le début ne peut pas dépasser 30 jours.';

  @override
  String get spotTrainingPlanValidationEndNotFuture =>
      'La fin doit être dans le futur.';

  @override
  String get spotTrainingPlanValidationInvalid => 'Plage horaire invalide.';

  @override
  String get spotDetailTrainingPlanSaved => 'Plan d’entraînement enregistré';

  @override
  String get spotDetailTrainingPlanUpdated => 'Plan d’entraînement mis à jour';

  @override
  String get spotDetailTrainingPlanFailed => 'Impossible d’enregistrer le plan';

  @override
  String get spotDetailTrainingPlanRemoved => 'Plan d’entraînement supprimé';

  @override
  String get spotDetailTrainingPlanDeleteFailed =>
      'Impossible de supprimer le plan';

  @override
  String get spotTrainingPlanListDialogTitle => 'Prévoit de s’entraîner';

  @override
  String get spotTrainingPlanListDialogSubtitle =>
      'Personnes ayant un plan public pour ce spot.';

  @override
  String get spotTrainingPlanListDialogClose => 'Fermer';

  @override
  String get spotTrainingPlanListEmpty => 'Pas encore de plans publics.';

  @override
  String get spotTrainingPlanListLoadError => 'Impossible de charger les plans';

  @override
  String get spotTrainingPlanEditMine => 'Modifier le plan';

  @override
  String get spotTrainingPlanJoin => 'Rejoindre';

  @override
  String get spotTrainingPlanOnlyYou => 'Seulement vous';

  @override
  String get spotTrainingPlanUnnamedPerson => 'Quelqu’un';

  @override
  String spotTrainingPlanTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get spotDetailHiddenBanner =>
      'Ce spot est masqué au public. Il n’existe probablement plus ou ne respecte pas nos règles. Il n’apparaîtra pas dans les recherches ni sur la carte.';

  @override
  String spotDetailSourceRemovedBanner(String source) {
    return 'Ce spot n’est plus listé dans $source. Les infos peuvent être obsolètes — vérifiez avant de vous rendre sur place.';
  }

  @override
  String get spotDetailSourceRemovedUnknownSource => 'sa source d’origine';

  @override
  String get spotDetailSectionFeatures => 'Caractéristiques';

  @override
  String get spotDetailSectionAccess => 'Accès';

  @override
  String get spotDetailSectionFacilities => 'Équipements';

  @override
  String spotDetailJumpflixFetchFailed(String error) {
    return 'Échec de récupération Jumpflix : $error';
  }

  @override
  String get spotDetailBrandYoutube => 'YouTube';

  @override
  String get spotDetailBrandJumpflix => 'Jumpflix';

  @override
  String get spotDetailBrandAsSeenIn => 'Comme vu dans';

  @override
  String get spotDetailLoading => 'Chargement…';

  @override
  String get spotDetailLoadingYourRating => 'Chargement de votre note…';

  @override
  String get spotDetailRateThisSpot => 'Noter ce spot';

  @override
  String get spotDetailHeaderNoRatingsYet => 'Pas encore de notes';

  @override
  String get spotDetailCouldNotLoadProfile =>
      'Impossible de charger votre profil.';

  @override
  String get spotDetailRefreshPageToRate => 'Actualisez la page pour noter.';

  @override
  String get spotDetailSignInToRateTitle => 'Connectez-vous pour noter ce spot';

  @override
  String get spotDetailSignInToRateSubtitle =>
      'Connectez-vous pour noter ce spot et aider la communauté.';

  @override
  String get spotDetailSignInButton => 'Connexion';

  @override
  String get spotDetailCreateAccountButton => 'Créer un compte';

  @override
  String get spotDetailMapSwitchToMap => 'Voir la carte';

  @override
  String get spotDetailMapSwitchToSatellite => 'Voir le satellite';

  @override
  String get spotDetailMapLocateOnMap => 'Voir sur la carte';

  @override
  String get spotDetailDuplicateOf => 'Doublon de';

  @override
  String get spotDetailOriginalSpotFallback => 'Spot d’origine';

  @override
  String get spotDetailAlsoBasedOn => 'Également basé sur';

  @override
  String spotDetailGalleryPageIndicator(int current, int total) {
    return '$current / $total';
  }

  @override
  String get spotDetailSaveMenuTooltip => 'Enregistrer le spot';

  @override
  String get spotDetailSaveMenuSignInTitle =>
      'Connectez-vous pour enregistrer des spots';

  @override
  String get spotDetailSaveMenuSignInBody =>
      'Ajoutez ce spot à « À visiter », « Déjà venu » ou vos listes. Connectez-vous ou créez un compte gratuit.';

  @override
  String get spotDetailSaveMenuLogInOrCreate =>
      'Connexion ou création de compte';

  @override
  String get spotDetailSaveTooltipUpdating => 'Mise à jour…';

  @override
  String get spotDetailSaveTooltipWantToVisit => 'Enregistré : À visiter';

  @override
  String get spotDetailSaveTooltipBeenHere => 'Enregistré : Déjà venu';

  @override
  String get spotDetailSaveTooltipGeneric => 'Enregistrer le spot';

  @override
  String get spotDetailRemovedFromWantToVisit => 'Retiré de À visiter';

  @override
  String get spotDetailFailedToRemove => 'Échec du retrait';

  @override
  String get spotDetailAddedToWantToVisit => 'Ajouté à À visiter';

  @override
  String get spotDetailFailedToAdd => 'Échec de l’ajout';

  @override
  String get spotDetailRemovedFromBeenHere => 'Retiré de Déjà venu';

  @override
  String get spotDetailAddedToBeenHere => 'Ajouté à Déjà venu';

  @override
  String get spotDetailWantToVisit => 'À visiter';

  @override
  String get spotDetailBeenHere => 'Déjà venu';

  @override
  String get spotDetailViewFullListTooltip => 'Voir la liste complète';

  @override
  String get spotDetailAddToCustomList => 'Ajouter à une liste';

  @override
  String get spotDetailListNameEmpty =>
      'Le nom de la liste ne peut pas être vide';

  @override
  String get spotDetailFailedAddToListGeneric =>
      'Impossible d’ajouter le spot à la liste';

  @override
  String get spotDetailFailedCreateList => 'Impossible de créer la liste';

  @override
  String get spotDetailFailedAddToSomeLists =>
      'Impossible d’ajouter le spot à certaines listes';

  @override
  String spotDetailAddToListTitle(String name) {
    return 'Ajouter à $name';
  }

  @override
  String get spotDetailSelectSections => 'Choisir une section';

  @override
  String spotDetailSectionEntryCount(int count) {
    return 'Section ($count spots)';
  }

  @override
  String get spotDetailAddToNewSection => 'Ajouter à une nouvelle section';

  @override
  String get spotDetailSectionNameOptional => 'Nom de section (optionnel)';

  @override
  String get spotDetailNoteOptional => 'Note (optionnelle)';

  @override
  String get spotDetailSkip => 'Passer';

  @override
  String get spotDetailAdd => 'Ajouter';

  @override
  String get spotDetailAddToListDialogTitle => 'Ajouter à la liste';

  @override
  String get spotDetailAlreadyInLists => 'Déjà dans ces listes :';

  @override
  String get spotDetailNoListsYet =>
      'Vous n’avez pas encore de listes. Créez-en une pour commencer !';

  @override
  String get spotDetailSelectListsPrompt => 'Choisir une liste';

  @override
  String get spotDetailCreateNewList => 'Créer une nouvelle liste';

  @override
  String get spotDetailListNameLabel => 'Nom de la liste';

  @override
  String get spotDetailListNameHint => 'ex. : Mes spots favoris';

  @override
  String get spotDetailListDescriptionLabel => 'Description';

  @override
  String get spotDetailListDescriptionHint =>
      'Ajoutez une description pour cette liste';

  @override
  String get spotDetailVisibilityLabel => 'Visibilité';

  @override
  String get spotDetailCreateAndAdd => 'Créer et ajouter';

  @override
  String get spotDetailReportDuplicateTitle => 'Signaler un spot en double';

  @override
  String get spotDetailReportDuplicateIntro =>
      'Sélectionnez le spot dont celui-ci est le doublon.';

  @override
  String get spotDetailEmailInvalid => 'Saisissez une adresse e-mail valide.';

  @override
  String get spotDetailEmailRequired => 'Saisissez une adresse e-mail.';

  @override
  String get spotDetailSubmitReport => 'Envoyer le signalement';

  @override
  String get spotDetailReportThisSpotTitle => 'Signaler ce spot';

  @override
  String spotDetailReportIntro(String name) {
    return 'Indiquez ce qui ne va pas avec $name. Les modérateurs examineront votre signalement.';
  }

  @override
  String get spotDetailReportWhatWrong => 'Que se passe-t-il ?';

  @override
  String get spotDetailReportCategoryLabel => 'Choisir une catégorie';

  @override
  String get spotDetailReportCategoryHint =>
      'Choisir une catégorie de signalement';

  @override
  String get spotDetailReportDescribeIssue => 'Décrire le problème';

  @override
  String get spotDetailReportDescribeIssueHint =>
      'Dites-nous ce qui ne correspond pas à la réalité';

  @override
  String get spotDetailReportAdditionalDetails => 'Détails supplémentaires';

  @override
  String get spotDetailReportAdditionalDetailsHint => 'Autre chose à savoir ?';

  @override
  String get spotDetailReportEmailLabel => 'Adresse e-mail';

  @override
  String get spotDetailReportEmailHelper =>
      'Nous vous contacterons uniquement pour ce signalement.';

  @override
  String spotDetailReportReachOutAt(String email) {
    return 'Si besoin, nous vous écrirons à $email.';
  }

  @override
  String get spotDetailReportReachOutAccount =>
      'Si besoin, nous utiliserons l’e-mail de votre compte.';

  @override
  String get spotDetailReportCategoryOtherDescribe =>
      'Décrivez le problème si vous choisissez « Autre ».';

  @override
  String get spotDetailReportCategoryRequired =>
      'Veuillez choisir une catégorie.';

  @override
  String get spotDetailReportSendFailed =>
      'Impossible d’envoyer le signalement. Réessayez.';

  @override
  String get spotDetailReportCategoryClosed => 'Spot fermé ou supprimé';

  @override
  String get spotDetailReportCategoryInaccurate =>
      'L\'emplacement ou les infos semblent incorrects';

  @override
  String get spotDetailReportCategoryUnsafe => 'Conditions dangereuses';

  @override
  String get spotDetailReportCategoryNotASpot => 'Pas un spot';

  @override
  String get spotDetailReportCategoryOther => 'Autre';

  @override
  String get spotDetailReportCategoryClosedDesc =>
      'Le spot a été définitivement fermé, démoli ou supprimé et n’est plus accessible. Précisez ci-dessous.';

  @override
  String get spotDetailReportCategoryInaccurateDesc =>
      'Quelque chose semble erroné sur ce spot : l\'épingle, le nom, la description ou l\'adresse peuvent être incorrects. Utilisez ceci si vous n\'êtes pas sûr de la bonne information. Décrivez ci-dessous ce qui semble faux. Si vous savez quoi modifier, utilisez « Suggérer une modification » dans le menu du spot.';

  @override
  String get spotDetailReportCategoryUnsafeDesc =>
      'Le spot est devenu dangereux (structure, environnement, etc.). Précisez ci-dessous ce qui est risqué.';

  @override
  String get spotDetailReportCategoryNotASpotDesc =>
      'Uniquement pour des cas objectifs : spam, lieux invalides (ex. mer), résidences privées, villes entières, entrées manifestement invalides. Pour un avis sur la qualité, utilisez une note. Expliquez pourquoi ce n’est pas un spot.';

  @override
  String get spotDetailReportCategoryOtherDesc =>
      'Tout autre problème non couvert ci-dessus. Décrivez-le dans le champ ci-dessous.';

  @override
  String get spotDetailMarkDuplicateTitle => 'Marquer comme doublon';

  @override
  String get spotDetailMarkDuplicateBody =>
      'Voulez-vous vraiment marquer ce spot comme doublon ? Cette action peut être annulée plus tard.';

  @override
  String get spotDetailMarkDuplicateAddToOriginal =>
      'Choisissez quoi ajouter au spot d’origine :';

  @override
  String get spotDetailMarkDuplicatePhotos => 'Photos';

  @override
  String get spotDetailMarkDuplicateYoutube => 'Liens YouTube';

  @override
  String get spotDetailMarkDuplicateOverwrite =>
      'Choisissez quoi écraser sur le spot d’origine (si défini) :';

  @override
  String get spotDetailMarkDuplicateName => 'Nom';

  @override
  String get spotDetailMarkDuplicateDescription => 'Description';

  @override
  String get spotDetailMarkDuplicateLocation => 'Emplacement';

  @override
  String get spotDetailMarkDuplicateSpotAttributes => 'Attributs du spot';

  @override
  String get spotDetailConfirm => 'Confirmer';

  @override
  String get spotDetailPickImagesFailed =>
      'Impossible de choisir des images. Réessayez.';

  @override
  String get spotDetailSelectAtLeastOnePhoto =>
      'Sélectionnez au moins une photo';

  @override
  String get spotDetailSuggestPhotosTitle => 'Suggérer des photos';

  @override
  String get spotDetailSuggestPhotosIntro =>
      'Proposez des photos à ajouter à ce spot. Les modérateurs les examineront avant publication.';

  @override
  String get spotDetailSelectPhotos => 'Sélectionner des photos';

  @override
  String get spotDetailPickPhotos => 'Choisir des photos';

  @override
  String get spotDetailAdditionalDetailsOptional =>
      'Détails supplémentaires (optionnel)';

  @override
  String get spotDetailAdditionalDetailsHint =>
      'Ajoutez des informations sur ces photos…';

  @override
  String get spotDetailSuggestPhotosEmailHelper =>
      'Nous vous contacterons uniquement pour cette suggestion.';

  @override
  String get spotDetailSuggestPhotosSubmitFailed =>
      'Impossible d’envoyer la suggestion de photos. Réessayez.';

  @override
  String spotDetailSuggestPhotosSubmitError(String error) {
    return 'Erreur lors de l’envoi suggestion photos : $error';
  }

  @override
  String get spotDetailSuggestEditTitle => 'Suggérer une modification';

  @override
  String get spotDetailSuggestEditIntro =>
      'Proposez des changements pour ce spot. Les modérateurs examineront vos suggestions.';

  @override
  String get spotDetailSuggestEditSuggestChange =>
      'Suggérez au moins une modification.';

  @override
  String get spotDetailSuggestEditSubmitFailed =>
      'Impossible d’envoyer la suggestion de modification. Réessayez.';

  @override
  String spotDetailSuggestEditSubmitError(String error) {
    return 'Erreur lors de l’envoi suggestion modification : $error';
  }

  @override
  String get spotDetailGeocoding => 'Géocodage…';

  @override
  String get spotDetailChangeLocationPicked => 'Changer l’emplacement (choisi)';

  @override
  String get spotDetailPickLocationOnMap =>
      'Choisir un autre emplacement sur la carte';

  @override
  String get spotDetailFieldTitle => 'Titre';

  @override
  String get spotDetailFieldTitleHint => 'Titre du spot';

  @override
  String get spotDetailFieldDescription => 'Description';

  @override
  String get spotDetailFieldDescriptionHint => 'Description du spot';

  @override
  String get spotDetailFieldSpotAttributes => 'Attributs du spot';

  @override
  String get spotDetailSuggestEditEmailHelper =>
      'Nous vous contacterons uniquement pour cette suggestion.';

  @override
  String get spotDetailMustBeLoggedInToRate =>
      'Vous devez être connecté·e pour noter des spots';

  @override
  String spotDetailRatingSubmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Note $count étoiles envoyée !',
      one: 'Note 1 étoile envoyée !',
    );
    return '$_temp0';
  }

  @override
  String get spotDetailRatingSubmitFailed =>
      'Impossible d’envoyer la note. Réessayez.';

  @override
  String spotDetailRatingSubmitError(String error) {
    return 'Erreur lors de l’envoi de la note : $error';
  }

  @override
  String get spotDetailNotExternalSource =>
      'Ce spot ne provient pas d’une source externe.';

  @override
  String get spotDetailMustBeLoggedInCreateNative =>
      'Vous devez être connecté·e pour créer un spot natif.';

  @override
  String get spotDetailCreateNativeDialogTitle => 'Créer un spot natif';

  @override
  String get spotDetailCreateNativeDialogBody =>
      'Un nouveau spot natif sera créé à partir de celui-ci et le spot actuel sera marqué comme son doublon. Toutes les données (nom, description, emplacement, photos, liens YouTube, attributs) seront copiées.\n\nNote : les administrateurs peuvent supprimer des spots et des liens de doublon si nécessaire.';

  @override
  String get spotDetailCreateButton => 'Créer';

  @override
  String get spotDetailUnableCreateNativeNow =>
      'Impossible de créer un spot natif pour le moment.';

  @override
  String get spotDetailFailedCreateNativeSpot =>
      'Échec de la création du spot natif';

  @override
  String get spotDetailNativeCreatedDuplicateMarked =>
      'Spot natif créé et spot actuel marqué comme doublon.';

  @override
  String get spotDetailFailedMarkDuplicateGeneric =>
      'Échec du marquage comme doublon';

  @override
  String spotDetailErrorCreatingNativeSpot(String error) {
    return 'Erreur lors de la création du spot natif : $error';
  }

  @override
  String get spotDetailUnableMarkDuplicateNow =>
      'Impossible de marquer ce spot comme doublon pour le moment.';

  @override
  String get spotDetailAlreadyMarkedDuplicate =>
      'Ce spot est déjà marqué comme doublon.';

  @override
  String get spotDetailSpotMarkedDuplicateSuccess =>
      'Spot marqué comme doublon.';

  @override
  String spotDetailErrorMarkingDuplicateSpot(String error) {
    return 'Erreur lors du marquage doublon : $error';
  }

  @override
  String get spotDetailModeratorsOnlyHideUnhide =>
      'Seuls les modérateurs peuvent masquer ou afficher des spots.';

  @override
  String get spotDetailHideSpotTitle => 'Masquer le spot';

  @override
  String get spotDetailUnhideSpotTitle => 'Afficher le spot';

  @override
  String get spotDetailHideSpotMessage =>
      'Le spot sera masqué au public. Il n’apparaîtra pas dans les recherches ni sur la carte, mais les données sont conservées et peuvent être réaffichées.';

  @override
  String get spotDetailUnhideSpotMessage =>
      'Le spot redeviendra public et visible dans les recherches et sur la carte.';

  @override
  String get spotDetailActionHide => 'Masquer';

  @override
  String get spotDetailActionUnhide => 'Afficher';

  @override
  String get spotDetailUnableHideUnhideNow =>
      'Impossible de masquer ou afficher ce spot pour le moment.';

  @override
  String get spotDetailSpotHiddenSuccess => 'Spot masqué.';

  @override
  String get spotDetailSpotUnhiddenSuccess => 'Spot à nouveau visible.';

  @override
  String get spotDetailFailedHideSpot => 'Échec du masquage du spot';

  @override
  String get spotDetailFailedUnhideSpot => 'Échec de l’affichage du spot';

  @override
  String spotDetailErrorHidingSpot(String error) {
    return 'Erreur lors du masquage : $error';
  }

  @override
  String spotDetailErrorUnhidingSpot(String error) {
    return 'Erreur lors de l’affichage : $error';
  }

  @override
  String get spotDetailNotMarkedAsDuplicate =>
      'Ce spot n’est pas marqué comme doublon.';

  @override
  String get spotDetailModeratorsOnlyRemoveDuplicateStatus =>
      'Seuls les modérateurs peuvent retirer le statut de doublon.';

  @override
  String get spotDetailRemoveDuplicateDialogBody =>
      'Le statut de doublon sera retiré ; ce spot ne sera plus considéré comme doublon.\n\nContinuer ?';

  @override
  String get spotDetailRemoveButton => 'Retirer';

  @override
  String get spotDetailUnableRemoveDuplicateStatusNow =>
      'Impossible de retirer le statut de doublon pour le moment.';

  @override
  String get spotDetailDuplicateStatusRemovedSuccess =>
      'Statut de doublon retiré.';

  @override
  String get spotDetailFailedRemoveDuplicateStatusGeneric =>
      'Échec du retrait du statut de doublon';

  @override
  String spotDetailErrorRemovingDuplicateStatus(String error) {
    return 'Erreur lors du retrait du statut de doublon : $error';
  }

  @override
  String get spotDetailCheckingLinkedData => 'Vérification des données liées…';

  @override
  String get spotDetailDeleteSpotDialogTitle => 'Supprimer le spot';

  @override
  String get spotDetailDeleteSpotConfirmMessage =>
      'Voulez-vous vraiment supprimer ce spot ? Cette action est irréversible.';

  @override
  String get spotDetailLinkedDataHeading => 'Ce spot a des données liées :';

  @override
  String spotDetailLinkedRatingsLine(int count) {
    return '• Notes : $count';
  }

  @override
  String spotDetailLinkedReportsLine(int count) {
    return '• Signalements : $count';
  }

  @override
  String spotDetailLinkedDuplicatesLine(int count) {
    return '• Spots en double : $count';
  }

  @override
  String get spotDetailResolveLinksBeforeDelete =>
      'Résolvez ces liens avant de supprimer le spot.';

  @override
  String get spotDetailSpotDeletedSuccess => 'Spot supprimé.';

  @override
  String get spotDetailFailedDeleteSpot => 'Échec de la suppression du spot';

  @override
  String spotDetailErrorDeletingSpot(String error) {
    return 'Erreur lors de la suppression : $error';
  }

  @override
  String get spotDetailFlagDuplicateDialogTitle => 'Marquer comme doublon';

  @override
  String get spotDetailFlagDuplicateIntro =>
      'Ce spot semble être un doublon d’un autre. Sélectionnez le spot d’origine ci-dessous.';

  @override
  String get spotDetailFlagDuplicateWhichQuestion =>
      'De quel spot est-ce le doublon ?';

  @override
  String get spotDetailDuplicateSearchHint =>
      'Collez l’URL du spot ou saisissez l’ID';

  @override
  String get spotDetailSearch => 'Rechercher';

  @override
  String get spotDetailNearbySpotsWithin50m => 'Spots à proximité (dans ~50 m)';

  @override
  String get spotDetailFoundSpot => 'Spot trouvé';

  @override
  String spotDetailSpotIdLabel(String id) {
    return 'ID du spot : $id';
  }

  @override
  String get spotDetailRemoveSelectionTooltip => 'Retirer la sélection';

  @override
  String get spotDetailImageFailedToLoad => 'Impossible de charger l’image';

  @override
  String get spotDetailClose => 'Fermer';

  @override
  String spotDetailExpandMoreCount(int count) {
    return '$count de plus';
  }

  @override
  String get spotDetailSubmit => 'Envoyer';

  @override
  String get spotDetailDuplicateReportSelectRequired =>
      'Sélectionnez le spot dont celui-ci est le doublon.';

  @override
  String get spotDetailDuplicateSearchEmpty =>
      'Saisissez un ID ou une URL de spot';

  @override
  String get spotDetailDuplicateInvalidUrl => 'ID ou URL de spot invalide';

  @override
  String get spotDetailDuplicateCannotSelectSelf =>
      'Un spot ne peut pas être doublon de lui-même';

  @override
  String get spotDetailDuplicateSpotNotFound => 'Spot introuvable';

  @override
  String spotDetailDuplicateFailedLoadSpot(String error) {
    return 'Impossible de charger le spot : $error';
  }

  @override
  String get sourceDetailsLoadingSource => 'Chargement de la source...';

  @override
  String get sourceDetailsErrorTitle => 'Erreur';

  @override
  String get sourceDetailsNotFound => 'Source introuvable';

  @override
  String get sourceDetailsTotalSpots => 'Spots au total';

  @override
  String get sourceDetailsFolders => 'Dossiers';

  @override
  String get sourceDetailsGoToSource => 'Aller à la source';

  @override
  String get sourceDetailsAdded => 'Ajouté';

  @override
  String get sourceDetailsLastImported => 'Dernière importation';

  @override
  String sourceDetailsRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count jours',
      one: 'Il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count heures',
      one: 'Il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count minutes',
      one: 'Il y a 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get sourceDetailsRelativeJustNow => 'À l\'instant';

  @override
  String get eventSourceDetailsLoadingSource =>
      'Chargement de la source d\'événements...';

  @override
  String get eventSourceDetailsTotalEvents => 'Événements au total';

  @override
  String exploreEventCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '1 événement',
    );
    return '$_temp0';
  }

  @override
  String spotTrackingSignInToViewList(String listName) {
    return 'Connectez-vous pour voir votre liste « $listName »';
  }

  @override
  String spotTrackingNoSpotsInList(String listName) {
    return 'Aucun spot dans $listName';
  }

  @override
  String get spotTrackingAddedEmptyHint =>
      'Les spots que vous ajoutez à la carte apparaissent ici';

  @override
  String get spotTrackingAddedVisibilityUpdateFailed =>
      'Impossible de mettre à jour la visibilité de la liste';

  @override
  String get spotListSaveTooltipSaveList => 'Enregistrer la liste';

  @override
  String get spotListSaveTooltipSavedList => 'Liste enregistrée';

  @override
  String get spotListSaveSignInTitle =>
      'Connectez-vous pour enregistrer des listes';

  @override
  String get spotListSaveSignInBody =>
      'Enregistrez la liste de spots de quelqu\'un dans vos listes pour pouvoir la rouvrir plus tard.';

  @override
  String get spotListSaveSavedToProfile => 'Liste enregistrée dans vos listes';

  @override
  String get spotListSaveCouldNotSaveList =>
      'Impossible d\'enregistrer la liste';

  @override
  String get spotListSaveRemovedFromSavedLists =>
      'Retirée des listes enregistrées';

  @override
  String get spotListSaveCouldNotRemoveList => 'Impossible de retirer la liste';

  @override
  String get spotListSaveActionSaveList => 'Enregistrer la liste';

  @override
  String get spotListSaveActionRemoveFromSaved => 'Retirer des enregistrées';

  @override
  String get spotListSaveActionViewSavedLists => 'Voir les listes enregistrées';

  @override
  String get spotListDetailListNotFoundOrNotAccessible =>
      'Liste introuvable ou inaccessible';

  @override
  String get spotListDetailDeleteListTitle => 'Supprimer la liste';

  @override
  String spotListDetailDeleteListConfirmation(String name) {
    return 'Voulez-vous vraiment supprimer « $name » ? Cette action est irréversible.';
  }

  @override
  String get spotListDetailDeleteAction => 'Supprimer';

  @override
  String get spotListDetailListDeleted => 'Liste supprimée';

  @override
  String get spotListDetailFailedToDeleteList =>
      'Impossible de supprimer la liste';

  @override
  String get spotListDetailNoSpotsInThisList => 'Aucun spot dans cette liste';

  @override
  String get spotListDetailEditListTitle => 'Modifier la liste';

  @override
  String get spotListEditNameLabel => 'Nom de la liste *';

  @override
  String get spotListDetailMoreInfoLinkLabel => 'Lien d\'infos supplémentaires';

  @override
  String get spotListDetailMoreInfoLinkHint => 'https://…';

  @override
  String get spotListDetailMoreInfoLinkHelper =>
      'Une page sur le web avec plus d\'informations sur cette liste';

  @override
  String get spotListDetailMoreInfoLinkValidationError =>
      'Le lien d\'infos supplémentaires doit être une URL valide (http ou https), par ex. example.com ou https://example.com/page';

  @override
  String get spotListDetailSave => 'Enregistrer';

  @override
  String get spotListDetailListUpdated => 'Liste mise à jour';

  @override
  String get spotListDetailFailedToUpdateList =>
      'Impossible de mettre à jour la liste';

  @override
  String get spotListDetailVisibilityPublicList => 'Liste publique';

  @override
  String get spotListDetailVisibilityUnlistedList => 'Liste non répertoriée';

  @override
  String get spotListDetailVisibilityPrivateList => 'Liste privée';

  @override
  String get spotListDetailCouldNotOpenProfile =>
      'Impossible d’ouvrir le profil';

  @override
  String spotListDetailCreatedPart(String visibility, String date) {
    return '$visibility créée $date';
  }

  @override
  String get spotListDetailCreatedBySuffix => ' par ';

  @override
  String spotListDetailLastUpdatedPart(String date) {
    return ', et mise à jour pour la dernière fois $date.';
  }

  @override
  String get spotListDetailMoreInformationOn => 'Plus d’informations sur ';

  @override
  String get detailExternalLinkCaption => 'Plus d’informations';

  @override
  String detailExternalLinkOpenSemantics(String host) {
    return 'Ouvrir $host';
  }

  @override
  String get spotListDetailCopiedToClipboard =>
      'Liste copiée dans le presse-papiers !';

  @override
  String spotListDetailCopyFailed(String error) {
    return 'Impossible de copier la liste : $error';
  }

  @override
  String get spotListDetailHighlightListOnMap =>
      'Mettre en évidence la liste sur la carte';

  @override
  String get spotListDetailEditListTooltip => 'Modifier la liste';

  @override
  String get spotListDetailMenuEditList => 'Modifier la liste';

  @override
  String get spotListEditDiscardTitle => 'Abandonner les modifications ?';

  @override
  String get spotListEditDiscardMessage =>
      'Tes modifications de cette liste seront perdues.';

  @override
  String get spotListEditDiscardAction => 'Abandonner';

  @override
  String get spotListEditAddSection => 'Ajouter une section';

  @override
  String get spotListEditAddSpots => 'Ajouter des spots';

  @override
  String get spotListEditAddSpotsTooltip => 'Ajouter des spots à cette section';

  @override
  String get spotListEditAddSpotsToListTooltip => 'Ajouter des spots';

  @override
  String get spotListEditNoSpotsInList =>
      'Pas encore de spots dans cette liste';

  @override
  String get spotListEditSectionTitleLabel => 'Titre de la section';

  @override
  String get spotListEditSectionTextLabel => 'Texte de la section';

  @override
  String get spotListEditAddSectionTitle => 'Ajouter un titre';

  @override
  String get spotListEditEditSectionTooltip => 'Modifier la section';

  @override
  String get spotListEditDoneSectionTooltip => 'Terminé';

  @override
  String get spotListEditNoSpotsInSection => 'Aucun spot dans cette section';

  @override
  String get spotListEditEmptySectionsRemovedOnSave =>
      'Les sections vides seront retirées à l’enregistrement';

  @override
  String get spotListEditRemoveSpotTitle => 'Retirer de la liste';

  @override
  String spotListEditRemoveSpotMessage(String name) {
    return 'Retirer « $name » de cette liste ?';
  }

  @override
  String get spotListEditRemoveSpotAction => 'Retirer';

  @override
  String get spotListEditRemoveSpotTooltip => 'Retirer de la liste';

  @override
  String get spotListEditAddNoteTooltip => 'Ajouter une note';

  @override
  String get spotListEditEditNoteTooltip => 'Modifier la note';

  @override
  String get spotListEditNoteLabel => 'Note pour ce spot';

  @override
  String get spotListEditRemoveNoteTooltip => 'Supprimer la note';

  @override
  String get spotListEditDoneNoteTooltip => 'Terminé';

  @override
  String get spotListEditDeleteSectionTooltip => 'Supprimer la section';

  @override
  String get spotListEditDeleteSectionTitle => 'Supprimer la section ?';

  @override
  String get spotListEditDeleteSectionMessage =>
      'Les spots de cette section seront retirés de la liste.';

  @override
  String get spotListEditDragHandleTooltip => 'Glisser pour réordonner';

  @override
  String get spotListEditVisibilityPublic => 'Publique';

  @override
  String get spotListEditVisibilityUnlisted => 'Non répertoriée';

  @override
  String get spotListEditVisibilityPrivate => 'Privée';

  @override
  String get spotListEditVisibilityPublicHelp =>
      'Affichée sur ton profil et visible par tout le monde';

  @override
  String get spotListEditVisibilityUnlistedHelp =>
      'Visible avec un lien direct, mais masquée sur ton profil';

  @override
  String get spotListEditVisibilityPrivateHelp => 'Visible uniquement par toi';

  @override
  String get spotListDetailMenuDeleteList => 'Supprimer la liste';

  @override
  String get spotListDetailPageTitle => 'Liste de spots';

  @override
  String get spotListDetailListNotFound => 'Liste introuvable';

  @override
  String spotListDetailMetaDescriptionFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots de parkour',
      one: '1 spot de parkour',
    );
    return 'Une liste organisée de $_temp0 sur Parkour·Spot';
  }

  @override
  String detailUpcomingEventLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Événements à venir',
      one: 'Événement à venir',
    );
    return '$_temp0';
  }

  @override
  String detailUpcomingEventsAndMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres',
      one: '1 autre',
    );
    return '$_temp0';
  }

  @override
  String get detailUpcomingEventsSheetTitle => 'Événements';

  @override
  String detailPastEventLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Événements passés',
      one: 'Événement passé',
    );
    return '$_temp0';
  }

  @override
  String detailPastEventsAndMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements passés',
      one: '1 événement passé',
    );
    return '$_temp0';
  }

  @override
  String get detailLinkedEventHappeningLabel => 'En cours';

  @override
  String get detailLinkedEventPastLabel => 'Passé';

  @override
  String get publicProfilePageTitle => 'Profil';

  @override
  String get publicProfileShareProfileTooltip => 'Partager le profil';

  @override
  String get publicProfileErrorLoadingProfile =>
      'Erreur lors du chargement du profil';

  @override
  String get publicProfilePleaseTryAgainLater => 'Veuillez réessayer plus tard';

  @override
  String publicProfileMetaDescription(String name, String defaultDescription) {
    return 'Découvrez les spots et listes de parkour de $name sur Parkour·Spot — $defaultDescription';
  }

  @override
  String get publicProfileProfileNotFound => 'Profil introuvable';

  @override
  String get publicProfileNotFoundOrPrivate =>
      'Ce profil n\'existe pas ou est privé.';

  @override
  String publicProfileMemberSince(String date) {
    return 'Membre depuis $date';
  }

  @override
  String get publicProfileEditProfileTooltip => 'Modifier le profil';

  @override
  String get publicProfileSpotTracking => 'Suivi des spots';

  @override
  String get publicProfileNoSpotsYet => 'Pas encore de spots';

  @override
  String get publicProfileAddSpotsFromSpotDetailPages =>
      'Ajoutez des spots depuis les pages de détail des spots';

  @override
  String get publicProfileBeenTo => 'Déjà visité';

  @override
  String get publicProfileMyCheckIns => 'Activité d\'entraînement';

  @override
  String get publicProfileMyCheckInsSubtitle =>
      'Vos plans à venir et votre historique de check-ins';

  @override
  String get myCheckInsSignInPrompt =>
      'Connectez-vous pour voir vos check-ins et plans d’entraînement';

  @override
  String get myCheckInsLoadMore => 'Charger plus';

  @override
  String get myCheckInsEmptyTitle => 'Pas encore de visites ni de plans';

  @override
  String get myCheckInsEmptyDescription =>
      'Ouvrez un spot pour vous enregistrer ou planifier une séance. Jusqu’à l’heure de fin définie, les autres peuvent vous voir comme « ici maintenant » sur ce spot sauf si vous gardez l’entrée privée.';

  @override
  String get myCheckInsIntro =>
      'Les plans d’entraînement listent les séances à venir que vous avez planifiées sur des spots. Un check-in enregistre une visite — quand vous êtes arrivé et jusqu’à quand vous prévoyez de partir. Les entrées publiques peuvent vous afficher sur un spot jusqu’à cette heure de fin ; les privées restent visibles uniquement pour vous.';

  @override
  String get myCheckInsUpcomingPlansTitle => 'Entraînement à venir';

  @override
  String get myCheckInsPastCheckInsTitle => 'Check-ins';

  @override
  String get myCheckInsNoCheckInsYet =>
      'Aucun check-in enregistré pour le moment.';

  @override
  String get myCheckInsCheckInsLoadFailed =>
      'Impossible de charger les check-ins.';

  @override
  String get myCheckInsSpotFallback => 'Spot';

  @override
  String get myCheckInsPrivateOnlyYou => 'Privé — visible uniquement par vous';

  @override
  String myCheckInsDurationDaysShort(int count) {
    return '${count}j';
  }

  @override
  String myCheckInsDurationHoursShort(int count) {
    return '${count}h';
  }

  @override
  String myCheckInsDurationMinutesShort(int count) {
    return '${count}min';
  }

  @override
  String get publicProfileSpotLists => 'Listes de spots';

  @override
  String get publicProfileYours => 'Les vôtres';

  @override
  String get publicProfileCreateYourFirstList => 'Créez votre première liste';

  @override
  String get publicProfileSaved => 'Enregistrées';

  @override
  String get publicProfilePublicSpotLists => 'Listes publiques de spots';

  @override
  String get publicProfileManageLists => 'Gérer les listes';

  @override
  String get publicProfileNoSavedListsYet =>
      'Aucune liste enregistrée pour le moment';

  @override
  String get publicProfileSaveListsHint =>
      'Enregistrez les listes trouvées sur les pages de listes d\'autres utilisateurs';

  @override
  String get publicProfileSavedListsUnavailable =>
      'Vos listes enregistrées ne sont plus disponibles ou ont été supprimées.';

  @override
  String get publicProfileListCreatedSuccessfully => 'Liste créée avec succès';

  @override
  String get publicProfileChangeProfilePicture => 'Modifier la photo de profil';

  @override
  String get publicProfileChooseFromGallery => 'Choisir depuis la galerie';

  @override
  String get publicProfileTakePhoto => 'Prendre une photo';

  @override
  String get publicProfileRemovePicture => 'Supprimer la photo';

  @override
  String publicProfileErrorPickingImage(String error) {
    return 'Erreur lors du choix de l\'image : $error';
  }

  @override
  String publicProfileErrorTakingPhoto(String error) {
    return 'Erreur lors de la prise de photo : $error';
  }

  @override
  String get publicProfileProcessingImage => 'Traitement de l\'image...';

  @override
  String get publicProfileReadingImage => 'Lecture de l\'image...';

  @override
  String get publicProfileUploading => 'Téléversement...';

  @override
  String get publicProfileFinishing => 'Finalisation...';

  @override
  String get publicProfileUpdatingProfile => 'Mise à jour du profil...';

  @override
  String get publicProfileProfilePictureUpdatedSuccessfully =>
      'Photo de profil mise à jour avec succès';

  @override
  String get publicProfileFailedToUpdateProfilePicture =>
      'Impossible de mettre à jour la photo de profil';

  @override
  String publicProfileErrorUploadingProfilePicture(String error) {
    return 'Erreur lors du téléversement de la photo de profil : $error';
  }

  @override
  String get publicProfileRemoveProfilePicture =>
      'Supprimer la photo de profil';

  @override
  String get publicProfileRemoveProfilePictureConfirmation =>
      'Voulez-vous vraiment supprimer votre photo de profil ?';

  @override
  String get publicProfileProfilePictureRemovedSuccessfully =>
      'Photo de profil supprimée avec succès';

  @override
  String get publicProfileFailedToRemoveProfilePicture =>
      'Impossible de supprimer la photo de profil';

  @override
  String publicProfileErrorRemovingProfilePicture(String error) {
    return 'Erreur lors de la suppression de la photo de profil : $error';
  }

  @override
  String get publicProfileProfileCopiedToClipboard =>
      'Profil copié dans le presse-papiers !';

  @override
  String publicProfileFailedToCopyProfile(String error) {
    return 'Impossible de copier le profil : $error';
  }

  @override
  String get publicProfileStatsSpots => 'Spots';

  @override
  String get publicProfileStatsRatings => 'Notes';

  @override
  String get publicProfileSettingsTitle => 'Paramètres du profil';

  @override
  String get publicProfileEmailLabel => 'E-mail';

  @override
  String get publicProfileEmailNotShownHint =>
      'Votre e-mail n\'est pas affiché publiquement.';

  @override
  String get publicProfileDisplayNameLabel => 'Nom affiché';

  @override
  String get publicProfileNoDisplayNameSet => 'Aucun nom affiché défini';

  @override
  String get publicProfileEditAction => 'Modifier';

  @override
  String get publicProfileDisplayNameHint => 'Entrez votre nom';

  @override
  String publicProfileDisplayNameHelper(int max) {
    return 'Comment votre nom s\'affichera pour les autres';
  }

  @override
  String publicProfileDisplayNameMaxLengthError(int max) {
    return 'Le nom affiché doit comporter au maximum 50 caractères';
  }

  @override
  String get publicProfileDisplayNameUpdated => 'Nom affiché mis à jour';

  @override
  String get publicProfileDisplayNameRemoved => 'Nom affiché supprimé';

  @override
  String get publicProfileDisplayNameUpdateFailed =>
      'Impossible de mettre à jour le nom affiché';

  @override
  String get publicProfileSaveAction => 'Enregistrer';

  @override
  String get publicProfileUsernameLabel => 'Nom d\'utilisateur';

  @override
  String get publicProfileNoUsernameSet => 'Aucun nom d\'utilisateur défini';

  @override
  String get publicProfileUsernameHint => 'Entrez un nom d\'utilisateur';

  @override
  String get publicProfileUsernameHelper =>
      'Unique et utilisé dans l\'URL de votre profil';

  @override
  String get publicProfileUsernameEmpty =>
      'Le nom d\'utilisateur ne peut pas être vide';

  @override
  String get publicProfileUsernameTaken =>
      'Ce nom d\'utilisateur est déjà utilisé';

  @override
  String get publicProfileUsernameUpdated => 'Nom d\'utilisateur mis à jour';

  @override
  String get publicProfileUsernameUpdateFailed =>
      'Impossible de mettre à jour le nom d\'utilisateur';

  @override
  String get publicProfileInstagramLabel => 'Instagram';

  @override
  String get publicProfileNoInstagramSet => 'Aucun Instagram défini';

  @override
  String get publicProfileAddAction => 'Ajouter';

  @override
  String get publicProfileInstagramLinkLabel => 'Lien Instagram';

  @override
  String get publicProfileInstagramLinkHint => 'https://instagram.com/votrenom';

  @override
  String get publicProfileInstagramLinkHelper =>
      'URL complète de votre profil Instagram';

  @override
  String get publicProfileInstagramInvalid =>
      'Veuillez entrer une URL Instagram valide';

  @override
  String get publicProfileInstagramRemoved => 'Lien Instagram supprimé';

  @override
  String get publicProfileInstagramUpdated => 'Lien Instagram mis à jour';

  @override
  String get publicProfileInstagramUpdateFailed =>
      'Impossible de mettre à jour le lien Instagram';

  @override
  String get publicProfilePrivacyTitle => 'Confidentialité';

  @override
  String get publicProfilePrivacyPublicLabel => 'Profil public';

  @override
  String get publicProfilePrivacyPrivateLabel => 'Profil privé';

  @override
  String get publicProfilePrivacyPublicDescription =>
      'Tout le monde peut voir votre profil et vos listes publiques.';

  @override
  String get publicProfilePrivacyPrivateDescription =>
      'Vous seul pouvez voir votre profil.';

  @override
  String get publicProfilePrivacyNowPublic =>
      'Votre profil est maintenant public';

  @override
  String get publicProfilePrivacyNowPrivate =>
      'Votre profil est maintenant privé';

  @override
  String get publicProfileFailedToUpdateProfilePrivacy =>
      'Impossible de mettre à jour la confidentialité du profil';

  @override
  String get eventDetailRouteErrorLoading =>
      'Erreur lors du chargement de l’événement';

  @override
  String get eventDetailRouteTryAgainLater => 'Veuillez réessayer plus tard';

  @override
  String get eventDetailRouteNotFound => 'Événement introuvable';

  @override
  String get eventDetailRouteGoToExplore => 'Aller à Explorer';

  @override
  String get eventDetailStartsLabel => 'Début';

  @override
  String get eventDetailEndsLabel => 'Fin';

  @override
  String get eventDetailLocationLabel => 'Lieu';

  @override
  String get eventDetailOpenInMaps => 'Ouvrir dans Plans';

  @override
  String get eventDetailLinkedSpotsLabel => 'Spots liés';

  @override
  String get eventDetailNoLinkedSpots => 'Aucun spot lié trouvé.';

  @override
  String get eventDetailLinkedSpotListsLabel => 'Listes de spots liées';

  @override
  String get eventDetailNoLinkedSpotLists =>
      'Aucune liste de spots liée trouvée.';

  @override
  String get eventDetailEventSpotsLabel => 'Spots pour cet événement';

  @override
  String get eventDetailNoEventSpots =>
      'Liste de spots de l\'événement introuvable.';

  @override
  String get eventDetailEventSpotListViewAll => 'Voir la liste de spots';

  @override
  String get eventDetailEventSpotListSeeOnMap => 'Voir sur la carte';

  @override
  String eventDetailEventSpotListMoreSpots(int count) {
    return '+ $count de plus';
  }

  @override
  String get eventDetailEventSpotLocationsLabel => 'Lieux de l\'événement';

  @override
  String get eventDetailNoEventSpotLocations =>
      'Spots de l\'événement introuvables.';

  @override
  String get eventDetailEventSpotViewDetails => 'Voir le spot';

  @override
  String get adminEventEditTitle => 'Modifier l\'événement';

  @override
  String get adminEventEditSave => 'Enregistrer';

  @override
  String get adminEventExternalSyncWarningTitle =>
      'Événement de calendrier externe';

  @override
  String get adminEventExternalSyncWarningBody =>
      'La prochaine synchronisation peut écraser le titre, le planning, la description et le lieu depuis le flux externe. Les spots et listes liés sont gérés ici et ne sont pas supprimés par la synchronisation.';

  @override
  String get adminEventLinkedSpotListsTitle => 'Listes de spots liées';

  @override
  String get adminEventAddSpotList => 'Ajouter une liste';

  @override
  String get adminEventNoLinkedSpotLists => 'Aucune liste sélectionnée';

  @override
  String get adminSpotListSelectionTitle => 'Sélectionner une liste';

  @override
  String get adminSpotListSelectionInputLabel => 'ID ou URL de liste';

  @override
  String get adminSpotListSelectionInputHint =>
      'id-liste ou https://parkour.spot/list/…';

  @override
  String get adminSpotListSelectionLookup => 'Rechercher';

  @override
  String get adminSpotListSelectionSelect => 'Sélectionner';

  @override
  String get adminSpotListSelectionInvalidInput =>
      'Saisissez un ID ou une URL /list/…';

  @override
  String get adminSpotListSelectionNotFound =>
      'Liste introuvable ou inaccessible';

  @override
  String get adminSpotListSelectionPrivateList =>
      'Les listes privées ne peuvent pas être liées aux événements';

  @override
  String get adminSpotListSelectionLoadFailed =>
      'Impossible de charger la liste';

  @override
  String adminSpotListSelectionFoundSubtitle(String visibility, int count) {
    return '$visibility · $count spots';
  }

  @override
  String get eventDetailAdminEditEvent => 'Modifier l\'événement';

  @override
  String get eventDetailMenuEditEventSubtitleNative =>
      'Créez d’abord un événement natif';

  @override
  String get eventDetailMenuEditEventSubtitleMod => 'Modérateur uniquement';

  @override
  String get eventDetailExternalSourceCannotEdit =>
      'Les événements issus de sources externes ne peuvent pas être modifiés. Créez d’abord un événement natif via « Marquer comme doublon » → « Créer un événement natif ».';

  @override
  String get eventDetailSourceLabel => 'Source';

  @override
  String get eventDetailAdminMenuTooltip => 'Admin';

  @override
  String get eventDetailStaffMenuTooltip => 'Équipe';

  @override
  String get eventDetailMenuCreateNative => 'Créer un événement natif';

  @override
  String get eventDetailMenuCreateNativeSubtitle =>
      'Copier depuis une source externe';

  @override
  String get eventDetailMenuSuggestPhotoSubtitleYes =>
      'Envoyer des photos pour cet événement';

  @override
  String get eventDetailMenuSuggestPhotoSubtitleNo =>
      'Indisponible pour les doublons';

  @override
  String get eventDetailMenuSuggestEditSubtitleYes =>
      'Proposer des changements pour cet événement';

  @override
  String get eventDetailMenuSuggestEditSubtitleNo =>
      'Indisponible pour les doublons';

  @override
  String get eventDetailMenuSuggestBlockedUnavailable =>
      'Indisponible pour le moment';

  @override
  String get eventDetailCreateNativeDialogTitle => 'Créer un événement natif';

  @override
  String get eventDetailCreateNativeDialogBody =>
      'Cela créera un nouvel événement natif basé sur cet événement et marquera l\'événement actuel comme doublon. Les données (titre, description, horaires, lieu, images, site web et spots liés) seront copiées vers le nouvel événement natif.';

  @override
  String get eventDetailNotExternalSource =>
      'Cet événement ne provient pas d\'une source externe.';

  @override
  String get eventDetailMustBeLoggedInCreateNative =>
      'Vous devez être connecté pour créer un événement natif.';

  @override
  String get eventDetailUnableCreateNativeNow =>
      'Impossible de créer un événement natif pour le moment.';

  @override
  String get eventDetailFailedCreateNative =>
      'Échec de la création de l\'événement natif';

  @override
  String get eventDetailNativeCreatedDuplicateMarked =>
      'Événement natif créé et événement actuel marqué comme doublon.';

  @override
  String get eventDetailMarkDuplicateNativeOnlyHint =>
      'Seuls les événements natifs peuvent être sélectionnés. Pour créer un événement natif à partir d\'un événement externe, utilisez « Créer un événement natif » dans le menu de l\'événement.';

  @override
  String eventDetailEventCreatedOnDateBy(String date) {
    return 'Événement créé $date par ';
  }

  @override
  String get eventDetailEventCreatedBy => 'Événement créé par ';

  @override
  String eventDetailEventCreatedOnDate(String date) {
    return 'Événement créé $date';
  }

  @override
  String eventDetailEventImportedOnDateFrom(String date) {
    return 'Événement importé $date depuis ';
  }

  @override
  String get eventDetailEventImportedFrom => 'Événement importé depuis ';

  @override
  String get eventDetailOriginalEventFallback => 'Événement d’origine';

  @override
  String get eventDetailDuplicateBannerTitle => 'Fiche en double';

  @override
  String get eventDetailDuplicateBannerBody =>
      'Cette fiche est marquée comme doublon. Ouvrez l’événement principal pour les détails de référence.';

  @override
  String get eventDetailLinkedDuplicatesHeading => 'Fiches en double';

  @override
  String get eventDetailMarkDuplicateStaffOnly =>
      'Seule l\'équipe peut gérer les doublons d\'événements.';

  @override
  String get eventDetailMenuHideEvent => 'Masquer l\'événement';

  @override
  String get eventDetailMenuHideEventSubtitle => 'Masquer du public';

  @override
  String get eventDetailMenuUnhideEvent => 'Afficher l\'événement';

  @override
  String get eventDetailMenuUnhideEventSubtitle => 'Rendre public à nouveau';

  @override
  String get eventDetailHiddenBanner =>
      'Cet événement est masqué au public. Il n\'existe probablement plus ou ne respecte pas nos règles. Il n\'apparaîtra pas dans les recherches ni sur la carte.';

  @override
  String get eventDetailModeratorsOnlyHideUnhide =>
      'Seuls les modérateurs peuvent masquer ou afficher des événements.';

  @override
  String get eventDetailHideEventTitle => 'Masquer l\'événement';

  @override
  String get eventDetailUnhideEventTitle => 'Afficher l\'événement';

  @override
  String get eventDetailHideEventMessage =>
      'L\'événement sera masqué au public. Il n\'apparaîtra pas dans les recherches ni sur la carte, mais les données sont conservées et peuvent être réaffichées.';

  @override
  String get eventDetailUnhideEventMessage =>
      'L\'événement sera à nouveau visible au public et réapparaîtra dans les recherches et sur la carte.';

  @override
  String get eventDetailUnableHideUnhideNow =>
      'Impossible de masquer ou d\'afficher cet événement pour le moment.';

  @override
  String get eventDetailEventHiddenSuccess => 'Événement masqué avec succès.';

  @override
  String get eventDetailEventUnhiddenSuccess =>
      'Événement affiché avec succès.';

  @override
  String get eventDetailFailedHideEvent => 'Échec du masquage de l\'événement';

  @override
  String get eventDetailFailedUnhideEvent =>
      'Échec de l\'affichage de l\'événement';

  @override
  String get eventDetailMarkDuplicatePickNativeTitle =>
      'Marquer comme doublon d’un événement natif';

  @override
  String get eventDetailMarkDuplicateSearchHint =>
      'Nom de l’événement, URL ou ID';

  @override
  String get eventDetailMarkDuplicateNotFoundOrInvalid =>
      'Choisissez un événement dans la liste ou saisissez un ID valide ou un lien /event/…';

  @override
  String get eventDetailMarkDuplicateTargetNotNative =>
      'Cet événement n’est pas un événement natif parkour.spot. Seuls les événements natifs peuvent être l’original.';

  @override
  String get eventDetailMarkDuplicateTargetIsDuplicate =>
      'Cet événement est déjà marqué comme doublon d’un autre événement.';

  @override
  String get eventDetailMarkDuplicateUseButton => 'Utiliser cet événement';

  @override
  String get eventDetailMarkDuplicateSuggestionsHeader =>
      'Événements à proximité autour de ces dates';

  @override
  String get eventDetailMarkDuplicateNoSuggestions =>
      'Aucun événement à proximité trouvé dans la semaine autour des dates de cet événement.';

  @override
  String get eventDetailDuplicatePickerNativeChip => 'Natif';

  @override
  String get eventDetailMarkDuplicateSuggestionNotSelectable =>
      'Impossible de sélectionner. Créez d\'abord un événement natif.';

  @override
  String eventDetailMarkDuplicateConfirmBody(String title) {
    return 'Marquer cet événement comme doublon de « $title » ?';
  }

  @override
  String get eventDetailMarkDuplicateTitle => 'Marquer comme doublon';

  @override
  String eventDetailMarkDuplicateBody(String title) {
    return 'Marquer cet événement comme doublon de « $title » ? Cette action peut être annulée plus tard.';
  }

  @override
  String get eventDetailMarkDuplicateAddToOriginal =>
      'Choisissez quoi ajouter à l’événement d’origine :';

  @override
  String get eventDetailMarkDuplicatePhotos => 'Photos';

  @override
  String get eventDetailMarkDuplicateLinkedSpots => 'Spots liés';

  @override
  String get eventDetailMarkDuplicateOverwrite =>
      'Choisissez quoi écraser sur l’événement d’origine (si défini) :';

  @override
  String get eventDetailMarkDuplicateEventTitle => 'Titre';

  @override
  String get eventDetailMarkDuplicateDescription => 'Description';

  @override
  String get eventDetailMarkDuplicateLocation => 'Emplacement';

  @override
  String get eventDetailMarkDuplicateSchedule => 'Horaires';

  @override
  String get eventDetailMarkDuplicateWebsite => 'Site web';

  @override
  String get eventDetailMarkDuplicateSuccess =>
      'Événement marqué comme doublon.';

  @override
  String get eventDuplicateChangesTitle => 'Doublon mis à jour';

  @override
  String eventDuplicateChangesBody(String title) {
    return 'Ce doublon a changé après avoir été marqué. Choisissez les valeurs à copier vers « $title », ou ignorez-les.';
  }

  @override
  String get eventDuplicateChangesReview => 'Examiner les modifications';

  @override
  String get eventDuplicateChangesApply => 'Appliquer';

  @override
  String get eventDuplicateChangesDismiss => 'Ignorer';

  @override
  String get eventDuplicateChangesApplySuccess =>
      'Événement original mis à jour.';

  @override
  String get eventDuplicateChangesDismissSuccess =>
      'Modifications du doublon ignorées.';

  @override
  String get eventDuplicateChangesChip => 'Doublon mis à jour';

  @override
  String get eventDuplicateChangesQueueTitle => 'Mises à jour de doublons';

  @override
  String get eventDuplicateChangesQueueSubtitle =>
      'Examiner les doublons modifiés après leur liaison';

  @override
  String get eventDuplicateChangesQueueEmpty =>
      'Aucun événement doublon avec des modifications en attente';

  @override
  String get eventDuplicateChangesBannerTitle => 'Doublon mis à jour';

  @override
  String get eventDuplicateChangesBannerBody =>
      'Des champs ont changé après que cet événement a été marqué comme doublon.';

  @override
  String get eventDuplicateChangesMenuItem =>
      'Examiner les modifications du doublon';

  @override
  String get eventDuplicateChangesMenuSubtitle =>
      'Copier les champs mis à jour vers l’original, ou les ignorer';

  @override
  String get eventDuplicateChangesFailed =>
      'Impossible de mettre à jour les modifications du doublon';

  @override
  String eventDuplicateChangesPhotosValue(int count) {
    return '$count photos';
  }

  @override
  String eventDuplicateChangesLinkedSpotsValue(int count) {
    return '$count spots liés';
  }

  @override
  String get eventDuplicateChangesNoValue => '(vide)';

  @override
  String get spotDuplicateChangesTitle => 'Doublon mis à jour';

  @override
  String spotDuplicateChangesBody(String name) {
    return 'Ce doublon a changé après avoir été marqué. Choisissez les valeurs à copier vers « $name », ou ignorez-les.';
  }

  @override
  String get spotDuplicateChangesReview => 'Examiner les modifications';

  @override
  String get spotDuplicateChangesApply => 'Appliquer';

  @override
  String get spotDuplicateChangesDismiss => 'Ignorer';

  @override
  String get spotDuplicateChangesApplySuccess => 'Spot original mis à jour.';

  @override
  String get spotDuplicateChangesDismissSuccess =>
      'Modifications du doublon ignorées.';

  @override
  String get spotDuplicateChangesChip => 'Doublon mis à jour';

  @override
  String get spotDuplicateChangesQueueTitle => 'Mises à jour de doublons';

  @override
  String get spotDuplicateChangesQueueSubtitle =>
      'Examiner les doublons modifiés après leur liaison';

  @override
  String get spotDuplicateChangesQueueEmpty =>
      'Aucun spot doublon avec des modifications en attente';

  @override
  String get spotDuplicateChangesBannerTitle => 'Doublon mis à jour';

  @override
  String get spotDuplicateChangesBannerBody =>
      'Des champs ont changé après que ce spot a été marqué comme doublon.';

  @override
  String get spotDuplicateChangesMenuItem =>
      'Examiner les modifications du doublon';

  @override
  String get spotDuplicateChangesMenuSubtitle =>
      'Copier les champs mis à jour vers l’original, ou les ignorer';

  @override
  String get spotDuplicateChangesFailed =>
      'Impossible de mettre à jour les modifications du doublon';

  @override
  String spotDuplicateChangesPhotosValue(int count) {
    return '$count photos';
  }

  @override
  String spotDuplicateChangesYoutubeValue(int count) {
    return '$count liens YouTube';
  }

  @override
  String get spotDuplicateChangesNoValue => '(vide)';

  @override
  String get spotDuplicateChangesOpenSpot => 'Ouvrir la page du spot';

  @override
  String get eventDetailRemoveDuplicateConfirmBody =>
      'Retirer le statut de doublon pour cet événement ? Il ne pointera plus vers un autre événement comme original.';

  @override
  String get eventDetailRemoveDuplicateSuccess => 'Statut de doublon retiré.';

  @override
  String get eventDetailCopiedToClipboard =>
      'Événement copié dans le presse-papiers !';

  @override
  String eventDetailShareFailed(String error) {
    return 'Échec du partage de l’événement : $error';
  }

  @override
  String get eventDetailQuickActionSuggestPhoto => 'Suggérer une photo';

  @override
  String get eventDetailQuickActionSuggestEdit => 'Suggérer une modification';

  @override
  String get eventDetailUnableSuggestNow =>
      'Impossible de suggérer des modifications pour cet événement pour le moment.';

  @override
  String get eventDetailCannotSuggestForDuplicate =>
      'Impossible de suggérer des modifications pour un événement en doublon.';

  @override
  String get eventDetailCannotSuggestForExternal =>
      'Impossible de suggérer des modifications pour un événement externe. Créez d’abord un événement natif.';

  @override
  String get eventDetailThanksPhotoSuggestion =>
      'Merci ! Votre suggestion de photos a été soumise pour examen.';

  @override
  String get eventDetailThanksEditSuggestion =>
      'Merci ! Votre suggestion de modification a été soumise pour examen.';

  @override
  String get eventDetailMenuFlagDuplicate => 'Marquer comme doublon';

  @override
  String get eventDetailMenuFlagDuplicateSubtitleYes =>
      'Cet événement est un doublon';

  @override
  String get eventDetailMenuFlagDuplicateSubtitleNo =>
      'Déjà marqué comme doublon';

  @override
  String get eventDetailFlagDuplicateDialogTitle => 'Marquer comme doublon';

  @override
  String get eventDetailFlagDuplicateIntro =>
      'Cet événement semble être un doublon d\'un autre. Sélectionnez l\'événement d\'origine ci-dessous.';

  @override
  String get eventDetailFlagDuplicateWhichQuestion =>
      'De quel événement s\'agit-il du doublon ?';

  @override
  String get eventDetailFlagDuplicateSuggestionsHeader =>
      'Événements à proximité autour de ces dates';

  @override
  String get eventDetailThanksDuplicateSuggestion =>
      'Merci ! Votre suggestion de doublon a été soumise pour examen.';

  @override
  String get eventDetailUnableFlagDuplicate =>
      'Impossible de signaler cet événement comme doublon pour le moment.';

  @override
  String get eventDetailDuplicateReportSelectRequired =>
      'Veuillez sélectionner l\'événement d\'origine.';

  @override
  String get eventReportQueueDuplicateSuggestion => 'Suggestion de doublon';

  @override
  String get eventReportQueueApproveDuplicate => 'Approuver le lien de doublon';

  @override
  String get eventReportQueueOpenOriginalEvent =>
      'Ouvrir l\'événement d\'origine suggéré';

  @override
  String get eventDuplicateApprovalExternalOriginalHint =>
      'L\'utilisateur a suggéré un événement d\'une source externe. Choisissez l\'événement natif parkour.spot comme original canonique.';

  @override
  String get eventDuplicateApprovalPickNativeTitle =>
      'Choisissez l\'événement natif comme original canonique.';

  @override
  String get eventDetailSuggestPhotosTitle => 'Suggérer des photos';

  @override
  String get eventDetailSuggestPhotosIntro =>
      'Ajoutez des photos pour cet événement. Les modérateurs examineront votre suggestion.';

  @override
  String get eventDetailSuggestPhotosPickRequired =>
      'Ajoutez au moins une photo.';

  @override
  String get eventDetailSuggestPhotosSubmitFailed =>
      'Échec de l’envoi de la suggestion de photo. Réessayez.';

  @override
  String eventDetailSuggestPhotosSubmitError(String error) {
    return 'Erreur lors de l’envoi de la suggestion de photo : $error';
  }

  @override
  String get eventDetailSuggestEditTitle => 'Suggérer une modification';

  @override
  String get eventDetailSuggestEditIntro =>
      'Proposez des modifications pour cet événement. Les modérateurs examineront votre suggestion.';

  @override
  String get eventDetailSuggestEditNoChanges =>
      'Veuillez suggérer au moins une modification.';

  @override
  String get eventDetailSuggestEditSubmitFailed =>
      'Échec de l’envoi de la suggestion de modification. Réessayez.';

  @override
  String eventDetailSuggestEditSubmitError(String error) {
    return 'Erreur lors de l’envoi de la suggestion de modification : $error';
  }

  @override
  String get eventSuggestionApprovalTitle =>
      'Examiner la suggestion d’événement';

  @override
  String get eventSuggestionCannotApproveExternalTitle =>
      'Impossible d’approuver la suggestion';

  @override
  String eventSuggestionCannotApproveExternalBody(String sourceName) {
    return 'L’événement sélectionné provient d’une source externe ($sourceName). Les suggestions ne peuvent être approuvées que pour les événements natifs.\n\nPour approuver cette suggestion, créez d’abord un événement natif depuis le menu de l’événement.';
  }

  @override
  String get eventSuggestionCannotApproveDuplicateTitle =>
      'Impossible d’approuver la suggestion';

  @override
  String get eventSuggestionCannotApproveDuplicateBody =>
      'L’événement sélectionné est un doublon d’un autre événement. Les suggestions ne peuvent être approuvées que pour l’événement original natif.\n\nVeuillez sélectionner l’événement original ci-dessous.';

  @override
  String get eventSuggestionTargetEventLabel => 'Événement cible';

  @override
  String eventSuggestionCurrentEventLabel(String title) {
    return 'Événement signalé : $title';
  }

  @override
  String eventSuggestionOriginalEventLabel(String title) {
    return 'Événement d’origine : $title';
  }

  @override
  String eventSuggestionReportedEventDuplicateSubtitle(String title) {
    return 'L’événement signalé (doublon de $title)';
  }

  @override
  String eventSuggestionReportedEventExternalSubtitle(String sourceName) {
    return 'L’événement signalé (de $sourceName)';
  }

  @override
  String get eventSuggestionReportedEventSubtitle => 'L’événement signalé';

  @override
  String eventSuggestionOriginalEventExternalSubtitle(String sourceName) {
    return 'L’événement d’origine (de $sourceName)';
  }

  @override
  String get eventSuggestionOriginalEventRecommendedSubtitle =>
      'L’événement d’origine (recommandé)';

  @override
  String get eventSuggestionModeratorNotesLabel => 'Commentaire (optionnel)';

  @override
  String get eventSuggestionModeratorNotesHint =>
      'Documentez pourquoi vous avez approuvé ou rejeté cette suggestion…';

  @override
  String get eventSuggestionApproveButton => 'Approuver la suggestion';

  @override
  String get eventSuggestionApprovalFailed =>
      'Impossible d’approuver cette suggestion d’événement.';

  @override
  String eventSuggestionApprovalSuccess(String eventId) {
    return 'Approuvée et appliquée à l’événement $eventId.';
  }

  @override
  String get eventSuggestionChangedFieldsTitle => 'Modifications suggérées';

  @override
  String get eventSuggestionLocationRemoved => 'Supprimer l’emplacement';

  @override
  String eventSuggestionLinkedSpotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots liés',
      one: '1 spot lié',
      zero: 'Aucun spot lié',
    );
    return '$_temp0';
  }
}
