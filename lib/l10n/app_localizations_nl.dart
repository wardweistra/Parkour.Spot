// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get tabExplore => 'Verkennen';

  @override
  String get tabAdd => 'Toevoegen';

  @override
  String get tabAccount => 'Account';

  @override
  String get profileSettingsTitle => 'Instellingen';

  @override
  String get profileSettingsSubtitle => 'Taal en locaties die je interesseren';

  @override
  String get profileSettingsLanguageLabel => 'Taal';

  @override
  String get profileSettingsLanguageDescription =>
      'Kies een taal of volg je apparaatinstellingen.';

  @override
  String get profileLanguageSystemDefault =>
      'Automatisch (Engels als niet ondersteund)';

  @override
  String get profileLoadErrorDefault => 'Profiel laden mislukt.';

  @override
  String get profileRefreshPage => 'Pagina vernieuwen';

  @override
  String get profileRetry => 'Opnieuw proberen';

  @override
  String get profileSignInTitle => 'Log in om je account te gebruiken';

  @override
  String get profileSignInSubtitle =>
      'Log in om je spots te beheren en locaties te beoordelen.';

  @override
  String get profileSignInButton => 'Inloggen';

  @override
  String get profileOrDivider => 'OF';

  @override
  String get profileCreateAccount => 'Account aanmaken';

  @override
  String get profileDefaultDisplayName => 'Gebruiker';

  @override
  String get profileViewEditSubtitle => 'Profiel bekijken en bewerken';

  @override
  String get accountSpotListsSubtitle =>
      'Wil ik bezoeken, al geweest, spots die je hebt toegevoegd en lijsten die je maakt of opslaat';

  @override
  String get spotListsHubSignInPrompt =>
      'Log in om je lijsten te bekijken en te beheren';

  @override
  String get spotListsHubCouldNotLoad =>
      'Lijsten konden niet worden geladen. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get spotListsHubAddedByYou => 'Door jou toegevoegd';

  @override
  String publicProfileAddedByUser(String name) {
    return 'Toegevoegd door $name';
  }

  @override
  String get notificationsTitle => 'Meldingen';

  @override
  String get notificationsSubtitle =>
      'Nieuwe spots in de buurt, trainingsplannen, check-ins en andere updates voor jou';

  @override
  String get notificationsEmptyTitle => 'Hier is het nog stil';

  @override
  String get notificationsEmptyBody =>
      'Als iemand een spot in de buurt toevoegt, training plant of incheckt waar jij traint, zie je het hier.';

  @override
  String get notificationsLoadError =>
      'We konden je meldingen niet laden. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get notificationsRetry => 'Opnieuw proberen';

  @override
  String get notificationsOpenFailedSnackbar =>
      'Deze melding kon niet worden geopend. Probeer het later opnieuw.';

  @override
  String get notificationsMarkAllRead => 'Alles als gelezen markeren';

  @override
  String get notificationsMarkAllReadFailed =>
      'Kon niet alles als gelezen markeren. Probeer het opnieuw.';

  @override
  String get notificationsMarkAsReadFailed =>
      'Kon niet als gelezen markeren. Probeer het opnieuw.';

  @override
  String get notificationsMarkAsUnreadFailed =>
      'Kon niet als ongelezen markeren. Probeer het opnieuw.';

  @override
  String get notificationsMarkAsUnreadHint =>
      'Lang indrukken om als ongelezen te markeren';

  @override
  String get notificationsMarkAsReadHint =>
      'Lang indrukken om als gelezen te markeren';

  @override
  String get notificationsShowAll => 'Alles tonen';

  @override
  String get notificationsUnreadOnly => 'Alleen ongelezen';

  @override
  String get notificationsEmptyFilteredTitle => 'Je bent bij';

  @override
  String get notificationsEmptyFilteredBody =>
      'Geen ongelezen meldingen op dit moment.';

  @override
  String get notificationsPushPromptEmptyHelper =>
      'Hoor over spots en check-ins in de buurt, ook als je niet in de app bent.';

  @override
  String get notificationsPushPromptListTitle => 'Meldingen in deze browser';

  @override
  String get notificationsPushPromptListBody =>
      'Hoor over activiteit in de buurt, ook als je niet in de app bent.';

  @override
  String get notificationsPushPromptTurnOnEmpty =>
      'Meldingen in deze browser inschakelen';

  @override
  String get notificationsPushPromptTurnOn => 'Inschakelen';

  @override
  String get notificationsPushPromptNotNow => 'Niet nu';

  @override
  String get notificationsPushPromptBlockedTitle =>
      'Pushmeldingen zijn geblokkeerd in deze browser';

  @override
  String get notificationsPushPromptBlockedBody =>
      'Sta meldingen voor Parkour·Spot toe in je browserinstellingen om alerts te krijgen wanneer je niet in de app bent.';

  @override
  String get notificationsTimeUnknown => 'Recent';

  @override
  String notificationsOpenSemantic(String title) {
    return 'Melding openen: $title';
  }

  @override
  String get notificationsActorSomeone => 'Iemand';

  @override
  String get notificationsSpotUntitled => 'Spot zonder naam';

  @override
  String get notificationsEventUntitled => 'Evenement zonder naam';

  @override
  String notificationNearbyNewSpotTitle(String spotName) {
    return 'Nieuwe spot in de buurt: $spotName';
  }

  @override
  String notificationNearbyNewSpotBody(String actorName) {
    return '$actorName heeft een nieuwe parkourspot toegevoegd nabij een van je opgeslagen locaties.';
  }

  @override
  String notificationNearbyCheckInTitle(String actorName, String spotName) {
    return '$actorName traint nu bij $spotName';
  }

  @override
  String get notificationNearbyCheckInBody => 'Net ingecheckt bij deze spot.';

  @override
  String notificationNearbyTrainingPlanTitle(
    String actorName,
    String spotName,
  ) {
    return '$actorName plant training bij $spotName';
  }

  @override
  String get notificationNearbyTrainingPlanBody =>
      'Ze deelden een openbaar trainingsvenster nabij een van je opgeslagen locaties.';

  @override
  String notificationTrainingPlanCheckInReminderTitle(String spotName) {
    return 'Tijd om in te checken bij $spotName';
  }

  @override
  String get notificationTrainingPlanCheckInReminderBody =>
      'Je geplande sessie is begonnen. Tik om in te checken.';

  @override
  String notificationNearbyNewEventTitle(String eventName) {
    return 'Nieuw evenement in de buurt: $eventName';
  }

  @override
  String get notificationNearbyNewEventBody =>
      'Er is een evenement toegevoegd nabij een van je opgeslagen locaties.';

  @override
  String get profileModeratorSectionTitle => 'Moderator';

  @override
  String get profileModeratorToolsTitle => 'Moderatortools';

  @override
  String get profileModeratorToolsSubtitle =>
      'Inkomende spotmeldingen bekijken en afhandelen';

  @override
  String get profileAdminSectionTitle => 'Beheerder';

  @override
  String get profileAdminToolsTitle => 'Beheerderstools';

  @override
  String get profileAdminToolsSubtitle => 'Bronnen en beheertaken beheren';

  @override
  String get profileSignOut => 'Uitloggen';

  @override
  String get profileSignOutMessage => 'Weet je zeker dat je wilt uitloggen?';

  @override
  String get profileCancel => 'Annuleren';

  @override
  String get profileLocationAlertsTitle => 'Locatiemeldingen';

  @override
  String get profileNotificationSettingsTitle => 'Meldingsinstellingen';

  @override
  String get profileNotificationSettingsThisDeviceGroupTitle => 'Dit apparaat';

  @override
  String get profileNotificationSettingsThisDeviceGroupHelper =>
      'Meldingen blijven in deze browser. Andere ingelogde apparaten behouden hun eigen instelling.';

  @override
  String get profileNotificationSettingsEveryDeviceGroupTitle =>
      'Op elk apparaat';

  @override
  String get profileNotificationSettingsEveryDeviceGroupHelper =>
      'Deze gelden overal waar je bent ingelogd.';

  @override
  String get profilePushNotificationsThisDeviceTitle => 'Pushmeldingen';

  @override
  String get profilePushNotificationsUnsupported =>
      'Pushmeldingen worden niet ondersteund in deze browser.';

  @override
  String get profilePushNotificationsLoading =>
      'Pushmeldingsstatus voor dit apparaat controleren…';

  @override
  String get profilePushNotificationsPermissionDenied =>
      'Pushmachtiging is geblokkeerd in de browserinstellingen voor deze site.';

  @override
  String get profilePushNotificationsPermissionNotDetermined =>
      'Schakel dit in om toestemming te vragen en deze browser te abonneren.';

  @override
  String get profilePushNotificationsEnabled =>
      'Deze browser is geabonneerd en kan pushmeldingen ontvangen.';

  @override
  String get profilePushNotificationsPermissionGrantedButOff =>
      'Toestemming is verleend, maar deze browser is momenteel niet geabonneerd.';

  @override
  String get profilePushNotificationsUnknown =>
      'Pushstatus is nu niet beschikbaar. Probeer het over enkele ogenblikken opnieuw.';

  @override
  String get profilePushNotificationsError =>
      'Pushmeldingen konden niet worden bijgewerkt in deze browser. Probeer het opnieuw.';

  @override
  String get profileLocationAlertsDescription =>
      'Bepaal welke locaties worden gebruikt voor meldingen in de buurt, waaronder check-ins, nieuwe spots, trainingsplannen en evenementen.';

  @override
  String get profileLocationAlertsShareLastKnownTitle =>
      'Laatst bekende locatie';

  @override
  String get profileLocationAlertsShareLastKnownSubtitle =>
      'Als dit aan staat, wordt deze locatie in de cloud opgeslagen voor meldingen in de buurt.';

  @override
  String get profileLocationAlertsShareLastKnownOnSubtitle =>
      'Zet dit uit om deze locatie niet meer op te slaan.';

  @override
  String profileLocationAlertsLastKnownActiveSubtitle(String details) {
    return '$details. Zet dit uit om deze locatie niet meer op te slaan.';
  }

  @override
  String get profileLocationAlertsLastKnownLabel => 'Laatst bekende locatie';

  @override
  String get profileLocationAlertsNotifyNewSpotsTitle =>
      'Melding bij nieuwe spots in de buurt';

  @override
  String get profileLocationAlertsNotifyNewSpotsSubtitle =>
      'Ontvang een melding wanneer iemand een spot toevoegt binnen de meldingsstraal van een actieve opgeslagen plek of je laatst bekende locatie.';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsTitle =>
      'Melding bij check-ins in de buurt';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsSubtitle =>
      'Ontvang een melding wanneer iemand incheckt op een spot binnen de meldingsstraal van een actieve opgeslagen plek of je laatst bekende locatie.';

  @override
  String get profileLocationAlertsNotifyTrainingPlansTitle =>
      'Melding bij trainingsplannen in de buurt';

  @override
  String get profileLocationAlertsNotifyTrainingPlansSubtitle =>
      'Ontvang een melding wanneer iemand een openbaar trainingsvenster deelt op een spot binnen de meldingsstraal van een actieve opgeslagen plek of je laatst bekende locatie.';

  @override
  String get profileLocationAlertsNotifyEventsTitle =>
      'Melding bij evenementen in de buurt';

  @override
  String get profileLocationAlertsNotifyEventsSubtitle =>
      'Ontvang een melding wanneer een evenement wordt toegevoegd binnen de meldingsstraal van een actieve opgeslagen plek of je laatst bekende locatie.';

  @override
  String get profileTrainingPlanCheckInReminderTitle =>
      'Herinner me om in te checken voor geplande sessies';

  @override
  String get profileTrainingPlanCheckInReminderSubtitle =>
      'Ontvang een herinnering wanneer je geplande sessie is begonnen en je nog niet bent ingecheckt op die spot.';

  @override
  String get profileLocationAlertsSavedLocationsTitle =>
      'Mijn locaties van interesse';

  @override
  String get profileLocationAlertsAddLocationButton => 'Toevoegen';

  @override
  String get profileLocationAlertsNoLocationsEnabledWarning =>
      'Je ontvangt geen meldingen op basis van locatie totdat je de laatst bekende locatie inschakelt of minstens één opgeslagen plek activeert.';

  @override
  String get profileLocationAlertsEmptyState =>
      'Nog geen opgeslagen locaties. Voeg plekken toe, zoals Thuis of Werk.';

  @override
  String get profileLocationAlertsDefaultLabel => 'Opgeslagen locatie';

  @override
  String get profileLocationAlertsDisableTooltip => 'Uitschakelen';

  @override
  String get profileLocationAlertsEnableTooltip => 'Inschakelen';

  @override
  String get profileLocationAlertsEditTooltip => 'Bewerken';

  @override
  String get profileLocationAlertsDeleteTooltip => 'Verwijderen';

  @override
  String get profileLocationAlertsDeleteTitle =>
      'Opgeslagen locatie verwijderen?';

  @override
  String profileLocationAlertsDeleteMessage(String label) {
    return 'Weet je zeker dat je $label wilt verwijderen?';
  }

  @override
  String get profileLocationAlertsDeleteConfirmButton => 'Verwijderen';

  @override
  String get profileLocationAlertsDialogAddTitle => 'Locatie toevoegen';

  @override
  String get profileLocationAlertsDialogEditTitle => 'Locatie bewerken';

  @override
  String get profileLocationAlertsDialogEditLastKnownTitle =>
      'Laatst bekende locatie bewerken';

  @override
  String get profileLocationAlertsLabelFieldLabel => 'Label';

  @override
  String get profileLocationAlertsLabelFieldPlaceholder => 'Thuis';

  @override
  String get profileLocationAlertsEnabledLabel => 'Ingeschakeld';

  @override
  String get profileLocationAlertsRadiusFieldLabel => 'Meldingsstraal';

  @override
  String profileLocationAlertsRadiusOption(int km) {
    return '$km km';
  }

  @override
  String get profileLocationAlertsLabelRequired =>
      'Voer een label in alsjeblieft';

  @override
  String get profileLocationAlertsLocationRequired =>
      'Kies een locatie op de kaart';

  @override
  String get profileLocationAlertsSaveButton => 'Opslaan';

  @override
  String get profileAboutIntro =>
      'Parkour·Spot is een community-app om parkour- en freerunningspots wereldwijd te ontdekken en te delen. We maken het eenvoudig om goede locaties te vinden—waar je ook traint.';

  @override
  String get profileReadMore => 'Meer lezen';

  @override
  String get profileAboutStoryBeforeName => 'Begonnen door ';

  @override
  String get profileAboutStoryAfterName =>
      ' uit de Utrechtse parkourcommunity: de app brengt lokale kennis van bestaande stads- en regionale kaarten samen—of die nu op Facebook, Instagram, websites of in oude apps stonden—zodat goede spotdata niet verloren gaat.';

  @override
  String get profileAboutMapMission =>
      'Dit is jouw kaart. Voeg nieuwe spots toe, beoordeel bestaande en verrijk vermeldingen met details. Hoe meer we bijdragen, hoe sterker de gedeelde kennis van de community wordt.';

  @override
  String get profileAboutPrinciplesHeader => 'Onze principes:';

  @override
  String get profileAboutPrincipleTransparency =>
      '• Transparantie: je kunt de app doorbladeren zonder account, en elke spot toont welke externe bronnen hebben bijgedragen.';

  @override
  String get profileAboutPrinciplePortability =>
      '• Draagbaarheid: we bouwen exporttools zodat spotdata ook buiten de app bruikbaar is.';

  @override
  String get profileAboutPrincipleOpenSource =>
      '• Open source: de app is van de community, niet afhankelijk van één persoon.';

  @override
  String get profileAboutEnjoy =>
      'Veel plezier met het ontdekken en delen van spots met Parkour.spot. Vragen of ideeën? Tik op contact—we horen graag van je.';

  @override
  String get profileCreditsBy => 'Grote bijdragen van ';

  @override
  String get profileCreditsDaphneArt => ' (illustratie), ';

  @override
  String get profileCreditsComma => ', ';

  @override
  String get profileCreditsEnd => ' en vele anderen.';

  @override
  String get profileViewSourceCode => 'Broncode bekijken';

  @override
  String get profileContactUs => 'Contact';

  @override
  String get profileReportIssue => 'Probleem melden';

  @override
  String get profileInstallBannerTitle => 'Installeer de Parkour·Spot-app';

  @override
  String get profileInstallBannerSubtitle => 'De volledige app-ervaring';

  @override
  String get profileInstallDialogTitle => 'Parkour·Spot installeren';

  @override
  String profileInstallIntro(String device, String browser) {
    return 'Open deze pagina in $browser en volg deze stappen om Parkour·Spot op je $device te installeren:';
  }

  @override
  String get profileInstallDeviceIphone => 'iPhone';

  @override
  String get profileInstallDeviceAndroid => 'Android-apparaat';

  @override
  String get profileInstallIosStep1 => 'Tik onderaan op de Deel-knop';

  @override
  String get profileInstallIosStep2 =>
      'Scroll naar beneden en tik op ‘Zet op beginscherm’';

  @override
  String get profileInstallIosStep3 => 'Tik rechtsboven op ‘Voeg toe’';

  @override
  String get profileInstallIosStep4 => 'De app verschijnt op je beginscherm!';

  @override
  String get profileInstallAndroidStep1 => 'Tik rechtsboven op het menu (⋯)';

  @override
  String get profileInstallAndroidStep2 => 'Tik op ‘Toevoegen aan startscherm’';

  @override
  String get profileInstallAndroidStep3 => 'Tik op ‘App installeren’';

  @override
  String get profileInstallAndroidStep4 =>
      'De app verschijnt op je startscherm!';

  @override
  String get profileInstallGotIt => 'Begrepen';

  @override
  String get exploreMetaDefaultTitle => 'Parkour·Spot';

  @override
  String get exploreMetaDefaultDescription =>
      'Ontdek, breng in kaart en deel de beste parkour-spots wereldwijd met communityfoto\'s, beoordelingen en lokale tips voor je volgende training.';

  @override
  String exploreMetaTitleCityCountry(String city, String country) {
    return 'Beste parkour-spots in $city, $country';
  }

  @override
  String exploreMetaDescriptionCityCountry(String city, String country) {
    return 'Ontdek de beste parkour-spots in $city, $country. Vind trainingsplekken, deel je favoriete spots en maak contact met de parkour-community.';
  }

  @override
  String exploreMetaTitleCountry(String country) {
    return 'Beste parkour-spots in $country';
  }

  @override
  String exploreMetaDescriptionCountry(String country) {
    return 'Ontdek de beste parkour-spots in $country. Vind trainingsplekken, deel je favoriete spots en maak contact met de parkour-community.';
  }

  @override
  String get exploreAddSpotTitle => 'Nieuwe spot toevoegen';

  @override
  String get exploreAddSpotSubtitle =>
      'Deel je favoriete parkour-spots met de community';

  @override
  String get exploreSignInToAddSpot =>
      'Log in om spots en evenementen toe te voegen';

  @override
  String get exploreSignInToAddSubtitle =>
      'Draag nieuwe spots bij of dien evenementvoorstellen in ter beoordeling door moderators.';

  @override
  String get addHubHeading => 'Wat wil je toevoegen?';

  @override
  String get addHubSubtitle => 'Deel wat je weet op de communitykaart.';

  @override
  String get addHubSpotTitle => 'Nieuwe spot toevoegen';

  @override
  String get addHubSpotDescription =>
      'Zet een pin, voeg foto\'s toe en plaats een nieuwe trainingspot op de kaart.';

  @override
  String get addHubSpotPublishBadge => 'Direct live op de kaart';

  @override
  String get addHubSpotButton => 'Nieuwe spot toevoegen';

  @override
  String get addHubEventTitle => 'Nieuw evenement toevoegen';

  @override
  String get addHubEventDescription =>
      'Stel een jam, meetup of sessie voor die anderen kunnen vinden.';

  @override
  String get addHubEventModerationBadge => 'Beoordeeld door moderators';

  @override
  String get addHubEventButton => 'Nieuw evenement toevoegen';

  @override
  String get addHubSignInTitle => 'Log in om bij te dragen';

  @override
  String get addHubSignInSubtitle =>
      'Gratis account. Voeg spots toe aan de kaart of stel evenementen voor de community voor.';

  @override
  String get exploreLoadingProfile => 'Profiel laden…';

  @override
  String get exploreSearchHint => 'Zoek locatie of spot…';

  @override
  String get explorePickerTitleLocation => 'Locatie kiezen';

  @override
  String get explorePickerTitleSpots => 'Spot kiezen';

  @override
  String get explorePickerTitleEvents => 'Event kiezen';

  @override
  String get explorePickerTitleSpotsAndEvents => 'Spot of event kiezen';

  @override
  String get explorePickerTitleEventWhere => 'Locatie of spots kiezen';

  @override
  String get explorePickerSearchHintEvents => 'Zoek locatie of event…';

  @override
  String get explorePickerSearchHintLocation => 'Zoek locatie…';

  @override
  String get explorePickerConfirmSelect => 'Selecteren';

  @override
  String get explorePickerConfirmAdd => 'Toevoegen';

  @override
  String get explorePickerReplaceSpotsTitle => 'Deze locatie gebruiken?';

  @override
  String explorePickerReplaceSpotsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dit vervangt $count geselecteerde spots.',
      one: 'Dit vervangt de geselecteerde spot.',
    );
    return '$_temp0';
  }

  @override
  String get explorePickerKeepSpots => 'Spots behouden';

  @override
  String get explorePickerUseLocation => 'Locatie gebruiken';

  @override
  String get explorePickerReplaceLocationBody =>
      'Dit vervangt de exacte locatie.';

  @override
  String get explorePickerKeepLocation => 'Locatie behouden';

  @override
  String get explorePickerUseSpotInstead => 'Spot toevoegen';

  @override
  String get explorePickerEventWhereHint =>
      'Kies een exacte locatie, of een of meer spots.';

  @override
  String explorePickerEventWhereReplacesListHint(String name) {
    return 'Als je een locatie of spots kiest, wordt $name vervangen.';
  }

  @override
  String explorePickerEventWhereListLinked(String name) {
    return 'Gekoppelde lijst: $name';
  }

  @override
  String get explorePickerEventWhereNone => 'Nog niets geselecteerd.';

  @override
  String get explorePickerEventWherePin => 'Exacte locatie ingesteld.';

  @override
  String explorePickerEventWhereSpots(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots geselecteerd',
      one: '$name',
    );
    return '$_temp0';
  }

  @override
  String get explorePickerMultiSpotsHint =>
      'Tik spots op de kaart om ze toe te voegen. Bevestig als je klaar bent.';

  @override
  String explorePickerMultiSpotsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots geselecteerd',
      one: '$name',
    );
    return '$_temp0';
  }

  @override
  String get explorePickerConfirmDone => 'Klaar';

  @override
  String get explorePickerAlreadyAdded => 'Toegevoegd';

  @override
  String explorePickerDone(int count) {
    return 'Klaar ($count)';
  }

  @override
  String get explorePickerLoading => 'Kaart laden…';

  @override
  String get exploreFilterBy => 'Spots filteren op';

  @override
  String get exploreFilterHasImages => 'Met foto\'s';

  @override
  String get exploreFilterAmenities => 'Kenmerken';

  @override
  String get exploreFilterSources => 'Bronnen';

  @override
  String get exploreSpotPhotosTitle => 'Foto\'s';

  @override
  String get exploreSpotAccessTitle => 'Toegang';

  @override
  String get exploreSpotFacilitiesTitle => 'Voorzieningen';

  @override
  String get exploreFacilitiesMatchAllHint => 'Moet alle geselecteerde hebben';

  @override
  String get exploreAttributesMatchAnyHint =>
      'Eén van de geselecteerde volstaat';

  @override
  String get exploreGoodForSegment => 'Geschikt voor';

  @override
  String get exploreSpotFeaturesSegment => 'Features';

  @override
  String get exploreSpotSourceLabel => 'Spotbron';

  @override
  String get exploreSourcesLoadError => 'Bronnen laden mislukt';

  @override
  String get exploreAllSources => 'Alle bronnen';

  @override
  String get exploreParkourSpotNative => 'Parkour·Spot (native)';

  @override
  String get exploreAllFolders => 'Alle mappen';

  @override
  String exploreLocationError(String error) {
    return 'Fout bij ophalen locatie: $error';
  }

  @override
  String get exploreCurrentLocationSnackbar => 'Dit is je huidige locatie';

  @override
  String get exploreCloseTooltip => 'Sluiten';

  @override
  String get exploreClearSearchTooltip => 'Wissen';

  @override
  String get exploreFiltersTooltip => 'Filters';

  @override
  String get exploreFindingLocation => 'Locatie zoeken…';

  @override
  String get exploreAddSpotHereTitle => 'Spot op deze locatie toevoegen?';

  @override
  String exploreMapRankedTotalBar(int total) {
    return '$total spots';
  }

  @override
  String exploreMapSpotsFoundLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots gevonden',
      one: '1 spot gevonden',
    );
    return '$_temp0';
  }

  @override
  String exploreMapBestShownParenthetical(int count) {
    return ' ($count beste getoond)';
  }

  @override
  String get exploreMapListModeSpots => 'Spots';

  @override
  String get exploreMapListModeEvents => 'Evenementen';

  @override
  String get exploreNoEventsArea => 'Geen evenementen in dit gebied';

  @override
  String get exploreNoEventsAreaHint => 'Verschuif de kaart of kom later terug';

  @override
  String get spotCardUpcomingEventBadge => 'Evenement';

  @override
  String get exploreEventLocate => 'Lokaliseren';

  @override
  String get exploreNoSpotsSearch => 'Geen spots gevonden';

  @override
  String get exploreNoSpotsArea => 'Geen spots in dit gebied';

  @override
  String get exploreNoSpotsSearchHint => 'Pas je zoektermen aan';

  @override
  String get exploreNoSpotsMapHint =>
      'Verplaats de kaart om andere gebieden te verkennen';

  @override
  String get exploreRefreshMapTooltip => 'Spots in huidig beeld vernieuwen';

  @override
  String get exploreSwitchToMap => 'Naar kaart';

  @override
  String get exploreSwitchToSatellite => 'Naar satelliet';

  @override
  String get exploreLocationPermissionDenied => 'Locatietoegang geweigerd';

  @override
  String get exploreCenterOnMyLocation => 'Centreren op mijn locatie';

  @override
  String get exploreFiltersDialogTitle => 'Filters';

  @override
  String get exploreClearFilters => 'Wissen';

  @override
  String get exploreDoneFilters => 'Klaar';

  @override
  String exploreDoneFiltersWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Klaar · $count spots',
      one: 'Klaar · 1 spot',
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
  String get explorePwaBannerInstall => 'Installeren';

  @override
  String get addSpotPickImagesFailed =>
      'Foto\'s kiezen mislukt. Probeer het opnieuw.';

  @override
  String get addSpotTakePhotoFailed =>
      'Foto maken mislukt. Probeer het opnieuw.';

  @override
  String get addSpotNeedPhoto => 'Upload minstens één foto van de spot';

  @override
  String get addSpotNeedLocation =>
      'Wacht tot de locatie bekend is of kies een locatie op de kaart';

  @override
  String addSpotCreateError(String error) {
    return 'Spot aanmaken mislukt: $error';
  }

  @override
  String get addSpotNameLabel => 'Spotnaam *';

  @override
  String get addSpotNameRequired => 'Voer een spotnaam in';

  @override
  String get addSpotDescriptionLabel => 'Beschrijving';

  @override
  String get addSpotDescriptionRequired => 'Voer een beschrijving in';

  @override
  String get addSpotDescriptionMinLength =>
      'Beschrijving moet minstens 10 tekens zijn';

  @override
  String get addSpotCreating => 'Spot wordt toegevoegd…';

  @override
  String get addSpotCreateButton => 'Spot toevoegen';

  @override
  String get addSpotLocationSectionTitle => 'Spotlocatie kiezen';

  @override
  String get addSpotGettingLocation => 'Je locatie ophalen…';

  @override
  String get addSpotLocationNotAvailable => 'Locatie niet beschikbaar';

  @override
  String get addSpotPickLocationHint => 'Locatie kiezen';

  @override
  String get addSpotImagesSectionTitle => 'Spotfoto\'s kiezen';

  @override
  String get addSpotGalleryButton => 'Galerij';

  @override
  String get addSpotCameraButton => 'Camera';

  @override
  String get addSpotGoodForTitle => 'Geschikt voor';

  @override
  String get addSpotGoodForSubtitle =>
      'Welke parkour-vaardigheden kun je hier trainen?';

  @override
  String get addSpotFeaturesTitle => 'Spotfeatures';

  @override
  String get addSpotFeaturesSubtitle =>
      'Welke fysieke kenmerken heeft deze spot?';

  @override
  String get addSpotAccessTitle => 'Spottoegang';

  @override
  String get addSpotAccessSubtitle =>
      'Wat is het toegangsniveau voor deze spot?';

  @override
  String get addSpotFacilitiesFormTitle => 'Spotvoorzieningen';

  @override
  String get addSpotFacilitiesSubtitle =>
      'Welke voorzieningen zijn er op deze spot?';

  @override
  String get addSpotLongPressHintSkill =>
      'Lang indrukken op een vaardigheid voor meer info';

  @override
  String get addSpotLongPressHintFeature =>
      'Lang indrukken op een feature voor meer info';

  @override
  String get addSpotLongPressHintFacility =>
      'Lang indrukken op een voorziening voor meer info';

  @override
  String get addSpotPickLocationAppBarTitle => 'Locatie kiezen';

  @override
  String get addSpotTipLongPressMobile =>
      'Tip: je kunt ook spots toevoegen vanaf de Verkennen-kaart door lang op een plek te drukken.';

  @override
  String get addSpotTipRightClickDesktop =>
      'Tip: je kunt ook spots toevoegen vanaf de Verkennen-kaart door ergens rechts te klikken.';

  @override
  String get addEventTipLongPressMobile =>
      'Tip: je kunt ook evenementen toevoegen vanaf de Verkennen-kaart door lang op een plek te drukken.';

  @override
  String get addEventTipRightClickDesktop =>
      'Tip: je kunt ook evenementen toevoegen vanaf de Verkennen-kaart door ergens rechts te klikken.';

  @override
  String get addSpotUseThisLocation => 'Deze locatie gebruiken';

  @override
  String get addSpotDirectionsTooltip => 'Route';

  @override
  String get addSpotGettingAddress => 'Adres ophalen…';

  @override
  String get addEventTitle => 'Nieuw evenement toevoegen';

  @override
  String get addEventTitleLabel => 'Evenementtitel *';

  @override
  String get addEventTitleRequired => 'Titel is verplicht.';

  @override
  String get addEventTitleTooLong => 'Titel is te lang.';

  @override
  String get addEventDescriptionLabel => 'Beschrijving';

  @override
  String get addEventDescriptionTooLong => 'Beschrijving is te lang.';

  @override
  String get addEventWebsiteLabel => 'Website-URL';

  @override
  String get addEventWebsiteHint => 'https://example.com';

  @override
  String get addEventPhotosSectionTitle => 'Evenementafbeeldingen kiezen';

  @override
  String get addEventAllDay => 'Hele-dag-evenement';

  @override
  String get addEventTimezoneLabel => 'Tijdzone';

  @override
  String get addEventStartLabel => 'Start';

  @override
  String get addEventEndLabel => 'Einde';

  @override
  String get addEventEndNotSet => 'Niet ingesteld';

  @override
  String get addEventClearEndTooltip => 'Einde wissen';

  @override
  String get addEventSchedulePickStartDate => 'Kies startdatum';

  @override
  String get addEventSchedulePickStartTime => 'Kies starttijd';

  @override
  String get addEventSchedulePickEndDateOptional => 'Kies einddatum';

  @override
  String get addEventSchedulePickEndTimeOptional => 'Kies eindtijd';

  @override
  String get addEventScheduleSkipEnd => 'Overslaan';

  @override
  String get addEventScheduleLabel => 'Datums';

  @override
  String get addEventLinkingSectionTitle => 'Koppeling';

  @override
  String get addEventWhereSectionTitle => 'Evenementlocatie kiezen';

  @override
  String get addEventWhenSectionTitle => 'Evenementplanning kiezen';

  @override
  String get addEventAddressNeedsResolve =>
      'Tik op het zoekpictogram naast het adres om het te bevestigen, of kies een locatie op de kaart.';

  @override
  String get addEventLinkSpotButton => 'Spot koppelen';

  @override
  String addEventLinkedSpotLabel(String name) {
    return 'Spot: $name';
  }

  @override
  String addEventLinkedSpotListLabel(String name) {
    return 'Spotlijst: $name';
  }

  @override
  String get addEventLocationNotSet => 'Locatie niet ingesteld';

  @override
  String get addEventExactLocationSet => 'Exacte locatie ingesteld';

  @override
  String get addEventLocationSectionTitle => 'Locatie';

  @override
  String get addEventLocationSectionHint =>
      'Kies een exacte locatie, een of meer spots, of een spotlijst.';

  @override
  String get addEventChooseOnMapHint => 'Kies op de kaart';

  @override
  String get addEventLinkListButton => 'Lijst koppelen';

  @override
  String get addEventWhereReplacedSpots =>
      'Exacte locatie heeft de gekoppelde spots vervangen.';

  @override
  String get addEventWhereReplacedLocation =>
      'Gekoppelde spots hebben de exacte locatie vervangen.';

  @override
  String get addEventWhereReplacedWithList =>
      'Spotlijst heeft de vorige locatie vervangen.';

  @override
  String addEventWhereReplacedListWithLocation(String name) {
    return 'Exacte locatie heeft $name vervangen.';
  }

  @override
  String addEventWhereReplacedListWithSpots(String name) {
    return 'Gekoppelde spots hebben $name vervangen.';
  }

  @override
  String get addEventAddressLabel => 'Exact adres';

  @override
  String get addEventAddressHint => 'Straat, huisnummer, plaats';

  @override
  String get addEventUseAddressButton => 'Adres gebruiken';

  @override
  String get addEventPickLocationButton => 'Kies op kaart';

  @override
  String get addEventClearAddressTooltip => 'Adres wissen';

  @override
  String get addEventAddressRequiredToResolve =>
      'Voer een adres in om te zoeken.';

  @override
  String get addEventAddressNotFound =>
      'Geen coördinaten gevonden voor dit adres.';

  @override
  String get addEventPickLocationHint => 'Kies een locatie op de kaart.';

  @override
  String get addEventClearLocationTooltip => 'Locatie wissen';

  @override
  String get addEventPickLocationTooltip => 'Locatie kiezen';

  @override
  String addEventApproxCoordinates(String latitude, String longitude) {
    return 'Ca. $latitude, $longitude';
  }

  @override
  String get addEventSubmitting => 'Indienen…';

  @override
  String get addEventSubmitButton => 'Indienen ter beoordeling';

  @override
  String get addEventWebsiteInvalid =>
      'Website-URL moet een geldige http(s)-URL zijn.';

  @override
  String get addEventEndBeforeStart =>
      'Eindtijd mag niet vóór starttijd liggen.';

  @override
  String get addEventNeedLocationOrLink => 'Locatie is verplicht.';

  @override
  String addEventMaxPhotos(int count) {
    return 'Maximaal $count foto\'s toegestaan.';
  }

  @override
  String get addEventUploadPhotosFailed =>
      'Foto\'s konden niet worden geüpload. Probeer het opnieuw.';

  @override
  String get addEventSubmitFailed =>
      'Evenementvoorstel kon niet worden ingediend.';

  @override
  String get addEventSubmitSuccess =>
      'Evenement ingediend in de moderatorwachtrij.';

  @override
  String get noImagesYet => 'Nog geen afbeeldingen';

  @override
  String get spotCardNoDescription => 'Nog geen beschrijving';

  @override
  String get spotCardPartOfPrefix => 'Onderdeel van ';

  @override
  String get spotCardRemoveFromListTooltip => 'Uit lijst verwijderen';

  @override
  String get spotCardCopiedToClipboard => 'Spot gekopieerd naar klembord!';

  @override
  String spotCardShareFailed(String error) {
    return 'Spot delen mislukt: $error';
  }

  @override
  String get spotCardRemovedFromSource => 'Verwijderd uit bron';

  @override
  String get spotCheckInUnnamedPerson => 'Deze persoon';

  @override
  String spotCheckInTooltipPublic(String name, String time) {
    return '$name is nu hier tot $time';
  }

  @override
  String spotCheckInTooltipPrivate(String time) {
    return 'Je bent nu hier tot $time — alleen jij ziet deze check-in';
  }

  @override
  String spotTrainingPlanTooltipPublic(String name, String timeRange) {
    return '$name plant hier te trainen $timeRange';
  }

  @override
  String spotTrainingPlanTooltipPrivate(String timeRange) {
    return 'Je plant hier te trainen $timeRange — alleen jij ziet dit plan';
  }

  @override
  String spotTrainingPlanTooltipPublicUntil(String name, String untilTime) {
    return '$name plant hier te trainen tot $untilTime';
  }

  @override
  String spotTrainingPlanTooltipPrivateUntil(String untilTime) {
    return 'Je plant hier te trainen tot $untilTime — alleen jij ziet dit plan';
  }

  @override
  String get spotDetailRouteErrorLoading => 'Fout bij laden van spot';

  @override
  String get spotDetailRouteTryAgainLater => 'Probeer het later opnieuw';

  @override
  String get spotDetailRouteNotFound => 'Spot niet gevonden';

  @override
  String get spotDetailRouteGoToExplore => 'Naar Verkennen';

  @override
  String get spotDetailCheckInVerifyFailed =>
      'Je check-ins konden niet worden gecontroleerd';

  @override
  String get spotDetailCheckInEndPreviousFailed =>
      'Je vorige check-in kon niet worden beëindigd';

  @override
  String get spotDetailCheckInSuccess => 'Je bent ingecheckt';

  @override
  String get spotDetailCheckInFailed => 'Check-in mislukt';

  @override
  String get spotDetailCheckInRemoved => 'Check-in verwijderd';

  @override
  String get spotDetailCheckInDeleteFailed =>
      'Check-in kon niet worden verwijderd';

  @override
  String get spotDetailCheckInUpdated => 'Check-in bijgewerkt';

  @override
  String get spotDetailCheckInUpdateFailed => 'Check-in bijwerken mislukt';

  @override
  String get spotDetailCheckInFabTooltipSignIn => 'Log in om in te checken';

  @override
  String get spotDetailCheckInFabTooltipEdit => 'Check-in bewerken';

  @override
  String get spotDetailCheckInFabTooltipCheckIn => 'Inchecken';

  @override
  String spotDetailSpotCreatedOnDateBy(String date) {
    return 'Spot aangemaakt $date door ';
  }

  @override
  String get spotDetailSpotCreatedBy => 'Spot aangemaakt door ';

  @override
  String get spotDetailUnknownSource => 'Onbekende bron';

  @override
  String spotDetailSpotImportedOnDateFrom(String date) {
    return 'Spot geïmporteerd $date van ';
  }

  @override
  String get spotDetailSpotImportedFrom => 'Spot geïmporteerd van ';

  @override
  String get spotDetailFromFolder => ' uit de map ';

  @override
  String get spotDetailImprovedByAfterComma => ', verbeterd door ';

  @override
  String get spotDetailImprovedByAfterAnd => ' en verbeterd door ';

  @override
  String get spotDetailUnknownUser => 'Onbekend';

  @override
  String get spotDetailListJoinAnd => ' en ';

  @override
  String get spotDetailListJoinComma => ', ';

  @override
  String spotDetailLastUpdatedAfterCommaAnd(String date) {
    return ', en voor het laatst bijgewerkt $date.';
  }

  @override
  String spotDetailLastUpdatedAfterAnd(String date) {
    return ' en voor het laatst bijgewerkt $date.';
  }

  @override
  String get spotDetailDateToday => 'vandaag';

  @override
  String get spotDetailDateYesterday => 'gisteren';

  @override
  String get communityDateTomorrow => 'morgen';

  @override
  String communityActivityTrainSameDay(
    String startTime,
    String endTime,
    String day,
  ) {
    return 'Van $startTime tot $endTime $day';
  }

  @override
  String communityActivityTrainSpan(
    String startTime,
    String startDay,
    String endTime,
    String endDay,
  ) {
    return 'Van $startTime $startDay tot $endTime $endDay';
  }

  @override
  String get communityShareSpotFallbackName => 'deze spot';

  @override
  String communityShareCheckInNarrative(String spotName, String untilPhrase) {
    return 'Ik train nu bij $spotName tot ongeveer $untilPhrase';
  }

  @override
  String communityShareTrainingPlanNarrative(
    String spotName,
    String relativeDay,
    String startTime,
  ) {
    return 'Ik plan om te trainen bij $spotName $relativeDay vanaf $startTime';
  }

  @override
  String get communityActivityShareCopiedToClipboard =>
      'Bericht gekopieerd naar klembord!';

  @override
  String communityActivityShareFailed(String error) {
    return 'Delen mislukt: $error';
  }

  @override
  String spotDetailDateDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagen geleden',
      one: '1 dag geleden',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weken geleden',
      one: '1 week geleden',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count maanden geleden',
      one: '1 maand geleden',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jaar geleden',
      one: '1 jaar geleden',
    );
    return '$_temp0';
  }

  @override
  String spotDetailCopySpotFailed(String error) {
    return 'Spot kopiëren mislukt: $error';
  }

  @override
  String get spotDetailAddressCopiedToClipboard =>
      'Adres gekopieerd naar klembord!';

  @override
  String spotDetailCopyAddressFailed(String error) {
    return 'Adres kopiëren mislukt: $error';
  }

  @override
  String spotDetailOpenMapsFailed(String error) {
    return 'Kaarten-app kon niet worden geopend: $error';
  }

  @override
  String get spotDetailMoreActionsTooltip => 'Meer acties';

  @override
  String get spotDetailMenuLogin => 'Inloggen';

  @override
  String get spotDetailMenuLoginSubtitle => 'Log in om door te gaan';

  @override
  String get spotDetailMenuFlagDuplicate => 'Markeer als duplicaat';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleYes =>
      'Deze spot is een duplicaat';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleNo =>
      'Al gemarkeerd als duplicaat';

  @override
  String get spotDetailMenuSuggestPhoto => 'Foto voorstellen';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleYes =>
      'Stel foto’s voor deze spot voor';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleNo =>
      'Geen foto’s voor duplicaatspots';

  @override
  String get spotDetailMenuSuggestEdit => 'Bewerking voorstellen';

  @override
  String get spotDetailMenuSuggestEditSubtitleYes =>
      'Stel wijzigingen voor deze spot voor';

  @override
  String get spotDetailMenuSuggestEditSubtitleNo =>
      'Geen bewerkingen voor duplicaatspots';

  @override
  String get spotDetailMenuReportSpot => 'Spot melden';

  @override
  String get spotDetailMenuReportSpotSubtitle =>
      'Help ons deze spot te beoordelen';

  @override
  String get spotDetailMenuEditSpot => 'Spot bewerken';

  @override
  String get spotDetailMenuEditSpotSubtitleNative =>
      'Maak eerst een native spot';

  @override
  String get spotDetailMenuEditSpotSubtitleMod => 'Alleen moderators';

  @override
  String get spotDetailMenuMarkDuplicate => 'Markeer als duplicaat';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleDup =>
      'Al gemarkeerd als duplicaat';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleMod => 'Alleen moderators';

  @override
  String get spotDetailMenuRemoveDuplicateStatus => 'Duplicaat verwijderen';

  @override
  String get spotDetailMenuRemoveDuplicateSubtitle =>
      'Originele vermelding herstellen';

  @override
  String get spotDetailMenuCreateNative => 'Native spot aanmaken';

  @override
  String get spotDetailMenuCreateNativeSubtitle => 'Kopiëren van externe bron';

  @override
  String get spotDetailMenuCreateEvent => 'Evenement aanmaken';

  @override
  String get spotDetailMenuCreateEventSubtitle => 'Op deze spot';

  @override
  String get spotDetailMenuHideSpot => 'Spot verbergen';

  @override
  String get spotDetailMenuHideSpotSubtitle => 'Verbergen voor publiek';

  @override
  String get spotDetailMenuUnhideSpot => 'Spot tonen';

  @override
  String get spotDetailMenuUnhideSpotSubtitle => 'Tonen in de app';

  @override
  String get spotDetailMenuDeleteSpot => 'Spot verwijderen';

  @override
  String get spotDetailMenuDeleteSubtitleAdmin => 'Alleen beheerders';

  @override
  String get spotDetailMenuTriggerResize => 'Afbeeldingsresize starten';

  @override
  String get spotDetailMenuTriggerResizeSubtitle =>
      'Opnieuw verkleinde versies maken';

  @override
  String get spotDetailMenuImageUrls => 'Overzicht afbeeldings-URL\'s';

  @override
  String get spotDetailMenuImageUrlsSubtitle =>
      'Origineel, verkleind en API-URL\'s';

  @override
  String adminImageUrlsDialogTitle(String entityLabel) {
    return 'Afbeeldings-URL\'s — $entityLabel';
  }

  @override
  String get adminImageUrlsEmpty => 'Geen afbeeldingen om te tonen.';

  @override
  String adminImageUrlsImageIndex(int index, int total) {
    return 'Afbeelding $index van $total';
  }

  @override
  String get adminImageUrlsLabelFirestore => 'Firestore (origineel)';

  @override
  String get adminImageUrlsLabel1200x1200 => 'Verwacht 1200×1200';

  @override
  String get adminImageUrlsLabel1200x630 => 'Verwacht 1200×630';

  @override
  String get adminImageUrlsLabelActualDownload =>
      'Werkelijke download-URL verkleind';

  @override
  String get adminImageUrlsLabelSpotsApi => 'Spots API-URL';

  @override
  String get adminImageUrlsStatusExists => 'Aanwezig';

  @override
  String get adminImageUrlsStatusMissing => 'Ontbreekt';

  @override
  String get adminImageUrlsStatusNotApplicable =>
      'Geen verkleinbare Firebase Storage-afbeelding.';

  @override
  String get adminImageUrlsPreviewOriginal => 'Origineel';

  @override
  String get adminImageUrlsPreview1200 => '1200×1200';

  @override
  String get adminImageUrlsPreview630 => '1200×630';

  @override
  String get adminImageUrlsCopyRow => 'URL kopiëren';

  @override
  String get adminImageUrlsCopyAll => 'Alles kopiëren';

  @override
  String get adminImageUrlsCopiedToClipboard => 'Gekopieerd naar klembord';

  @override
  String get adminImageUrlsApiFootnote =>
      'De spots API geeft de Spots API-URL terug ook als het verkleinde bestand ontbreekt; clients kunnen een 404 krijgen tot de resize klaar is.';

  @override
  String get adminImageUrlsEventApiFootnote =>
      'Er is geen events API. De Spots API-URL gebruikt dezelfde 1200×1200-transform als voor spot imageUrls.';

  @override
  String get spotDetailExternalSourceCannotEdit =>
      'Spots van externe bronnen kunnen niet worden bewerkt. Maak eerst een native spot via ‘Markeer als duplicaat’ → ‘Native spot aanmaken’.';

  @override
  String get spotDetailOk => 'OK';

  @override
  String get spotDetailUnableEditNow => 'Deze spot kan nu niet worden bewerkt.';

  @override
  String get spotDetailOnlyAdminsDelete =>
      'Alleen beheerders kunnen spots verwijderen.';

  @override
  String get spotDetailResizeAllHaveVersions =>
      'Alle afbeeldingen hebben al verkleinde versies';

  @override
  String spotDetailResizeSummary(
    int triggered,
    int verified,
    String failedPart,
  ) {
    return 'Resize: $triggered gestart, $verified gecontroleerd$failedPart';
  }

  @override
  String spotDetailResizeFailedPart(int failed) {
    return ', $failed mislukt';
  }

  @override
  String spotDetailResizeTriggerFailed(String error) {
    return 'Resize starten mislukt: $error';
  }

  @override
  String get spotDetailUnableFlagDuplicate =>
      'Deze spot kan nu niet als duplicaat worden gemarkeerd.';

  @override
  String get spotDetailThanksDuplicateReport =>
      'Bedankt! Je duplicaatmelding is verstuurd.';

  @override
  String get spotDetailUnableSuggestPhotos =>
      'Je kunt nu geen foto’s voor deze spot voorstellen.';

  @override
  String get spotDetailCannotSuggestPhotosDuplicate =>
      'Geen foto’s voor duplicaatspots.';

  @override
  String get spotDetailThanksPhotoSuggestion =>
      'Bedankt! Je fotovoorstel is ingediend voor beoordeling.';

  @override
  String get spotDetailUnableSuggestEdits =>
      'Je kunt nu geen bewerkingen voor deze spot voorstellen.';

  @override
  String get spotDetailCannotSuggestEditsDuplicate =>
      'Geen bewerkingen voor duplicaatspots.';

  @override
  String get spotDetailThanksEditSuggestion =>
      'Bedankt! Je bewerkingsvoorstel is ingediend voor beoordeling.';

  @override
  String get spotDetailUnableReportNow => 'Je kunt deze spot nu niet melden.';

  @override
  String get spotDetailThanksReportSubmitted =>
      'Bedankt! Je melding is verstuurd.';

  @override
  String get spotDetailUnableAddToList =>
      'Deze spot kan nu niet aan een lijst worden toegevoegd.';

  @override
  String get spotDetailNoSpotListsAccess =>
      'Je hebt geen toegang tot spotlijsten.';

  @override
  String get spotDetailListCreatedAndAdded =>
      'Lijst aangemaakt en spot toegevoegd!';

  @override
  String get spotDetailSpotAddedToList => 'Spot toegevoegd aan lijst!';

  @override
  String get spotDetailEditReportTooltip => 'Bewerken en melden';

  @override
  String get spotDetailShareTooltip => 'Delen';

  @override
  String get spotDetailQuickActionSave => 'Opslaan';

  @override
  String get spotDetailQuickActionEdit => 'Bewerken';

  @override
  String get spotDetailQuickActionShare => 'Delen';

  @override
  String get spotDetailQuickActionRate => 'Beoordeel';

  @override
  String get spotDetailRatingTooltip =>
      'Gemiddelde van de community en jouw sterren';

  @override
  String get spotDetailPresenceHereNow => 'Nu hier';

  @override
  String get spotDetailCommunitySectionTitle => 'Community';

  @override
  String get spotDetailCommunitySectionSubtitle =>
      'Zie wie hier traint of komt trainen, en deel je sessie.';

  @override
  String get spotDetailCommunityNobodyHere =>
      'Nog niemand ingecheckt. Check in zodat anderen weten dat je er bent.';

  @override
  String get spotDetailCommunityNobodyHereShort => 'Nog niemand hier.';

  @override
  String get spotDetailCommunityNobodySocialShort =>
      'Nog niemand hier of met een plan.';

  @override
  String get spotDetailCommunityActivityLoadError =>
      'Kon activiteit niet laden.';

  @override
  String get spotDetailCommunityActivityEmpty => 'Niks om te tonen.';

  @override
  String get spotDetailCommunityViewAll => 'Alles tonen';

  @override
  String get spotDetailCommunityCheckInButton => 'Check in';

  @override
  String get spotDetailCommunityEditCheckInButton => 'Check-in bewerken';

  @override
  String get spotDetailCommunitySignInToCheckInButton =>
      'Log in om in te checken';

  @override
  String get spotDetailCommunityPlanningVisitButton => 'Training plannen';

  @override
  String get spotDetailCommunityPlanningVisitTooltip =>
      'Stel in wanneer je hier gaat trainen.';

  @override
  String get spotDetailCommunityCheckInButtonTooltip =>
      'Laat anderen zien dat je nu hier bent.';

  @override
  String get spotDetailCommunityEditCheckInButtonTooltip =>
      'Je check-in aanpassen.';

  @override
  String get spotDetailCommunitySignInToCheckInButtonTooltip =>
      'Log in om in te checken.';

  @override
  String get spotDetailCommunityPlanningToTrain => 'Plant te trainen';

  @override
  String get spotDetailCommunityNobodyPlanningShort => 'Nog geen plannen.';

  @override
  String get spotDetailCommunitySignInToPlanButton => 'Log in om te plannen';

  @override
  String get spotDetailCommunityEditTrainingPlanButton => 'Plan bewerken';

  @override
  String get spotCheckInDialogTitle => 'Check in';

  @override
  String get spotCheckInDialogTitleEdit => 'Check-in bewerken';

  @override
  String get spotCheckInDialogIntroNew =>
      'Laat anderen weten dat je hier traint en ongeveer tot wanneer. Bij openbaar delen verschijn je op de community van deze spot tot je eindtijd.';

  @override
  String get spotCheckInDialogIntroEdit =>
      'Pas aankomst- en eindtijd, zichtbaarheid en je notitie aan.';

  @override
  String get spotCheckInDialogSharePublic => 'Openbaar delen';

  @override
  String get spotCheckInDialogShareSub =>
      'Zet uit zodat alleen jij deze check-in ziet.';

  @override
  String get spotCheckInDialogLabelArrived => 'Aangekomen';

  @override
  String get spotCheckInDialogLabelHereUntil => 'Hier tot';

  @override
  String get spotCheckInDialogLabelUntil => 'Tot';

  @override
  String get spotCheckInDialogStillHere => 'Nog hier';

  @override
  String get spotCheckInDialogEndNow => 'Nu beëindigen';

  @override
  String get spotCheckInDialogCancel => 'Annuleren';

  @override
  String get spotCheckInDialogSave => 'Opslaan';

  @override
  String get spotCheckInDialogDelete => 'Verwijderen';

  @override
  String get spotCheckInDialogConfirmDeleteTitle => 'Check-in verwijderen?';

  @override
  String get spotCheckInDialogConfirmDeleteBody =>
      'Verwijdert dit bezoek uit je geschiedenis. De spot blijft op je lijst ‘Geweest’ staan.';

  @override
  String get spotCheckInDialogExtendBannerText =>
      'Je hebt hier onlangs een verlopen check-in.';

  @override
  String get spotCheckInDialogExtendInstead => 'Die check-in verlengen';

  @override
  String spotCheckInDialogActiveElsewhereAtNamed(String spotName) {
    return 'Je bent nu ingecheckt bij $spotName. Inchecken hier beëindigt die check-in.';
  }

  @override
  String get spotCheckInDialogActiveElsewhereUnnamed =>
      'Je bent op een andere plek ingecheckt. Inchecken hier beëindigt die check-in.';

  @override
  String get spotCheckInDialogActiveElsewhereMultiple =>
      'Je hebt actieve check-ins op andere plekken. Inchecken hier beëindigt die check-ins.';

  @override
  String get spotCheckInDialogNudgeEarlier => '15 minuten eerder';

  @override
  String get spotCheckInDialogNudgeLater => '15 minuten later';

  @override
  String get spotCheckInDialogTrainingPlanConversionBanner =>
      'Opslaan vervangt je plan door deze check-in. Je geplande eindtijd staat hieronder ingevuld.';

  @override
  String get spotDetailSessionNoteLabel => 'Notitie (optioneel)';

  @override
  String get spotDetailSessionNoteHint => 'bijv. skills of oefeningen';

  @override
  String get spotTrainingPlanDialogTitle => 'Training hier plannen';

  @override
  String get spotTrainingPlanDialogTitleEdit => 'Trainingsplan bewerken';

  @override
  String get spotTrainingPlanDialogCheckInCtaBody =>
      'Nu hier? Check in zodat anderen weten dat je er bent.';

  @override
  String get spotTrainingPlanDialogCheckInCtaBodyEarly =>
      'Al hier? Check in zodat anderen weten dat je er bent.';

  @override
  String get spotTrainingPlanDialogCheckInCtaButton => 'Check in';

  @override
  String get spotTrainingPlanDialogBody =>
      'Stel in wanneer je wilt beginnen en eindigen. Openbare plannen verschijnen op de community van deze spot naast anderen die delen.';

  @override
  String get spotTrainingPlanDialogSharePublic => 'Openbaar delen';

  @override
  String get spotTrainingPlanDialogShareSub =>
      'Zet uit zodat alleen jij dit plan ziet.';

  @override
  String get spotTrainingPlanDialogStartLabel => 'Start';

  @override
  String get spotTrainingPlanDialogEndLabel => 'Einde';

  @override
  String get spotTrainingPlanDialogSave => 'Opslaan';

  @override
  String get spotTrainingPlanDialogCancel => 'Annuleren';

  @override
  String get spotTrainingPlanDialogDelete => 'Plan verwijderen';

  @override
  String get spotTrainingPlanDialogDeleteTitle => 'Dit plan verwijderen?';

  @override
  String get spotTrainingPlanDialogDeleteBody =>
      'Je kunt later altijd een nieuw plan maken.';

  @override
  String get spotTrainingPlanValidationOrder => 'Einde moet na de start zijn.';

  @override
  String get spotTrainingPlanValidationMinDuration => 'Minimaal 15 minuten.';

  @override
  String get spotTrainingPlanValidationMaxDuration => 'Maximaal 12 uur.';

  @override
  String get spotTrainingPlanValidationStartTooFar =>
      'Start mag niet meer dan 30 dagen vooruit zijn.';

  @override
  String get spotTrainingPlanValidationEndNotFuture =>
      'Einde moet in de toekomst liggen.';

  @override
  String get spotTrainingPlanValidationInvalid => 'Ongeldig tijdsbereik.';

  @override
  String get spotDetailTrainingPlanSaved => 'Trainingsplan opgeslagen';

  @override
  String get spotDetailTrainingPlanUpdated => 'Trainingsplan bijgewerkt';

  @override
  String get spotDetailTrainingPlanFailed => 'Trainingsplan opslaan mislukt';

  @override
  String get spotDetailTrainingPlanRemoved => 'Trainingsplan verwijderd';

  @override
  String get spotDetailTrainingPlanDeleteFailed =>
      'Trainingsplan verwijderen mislukt';

  @override
  String get spotTrainingPlanListDialogTitle => 'Plant te trainen';

  @override
  String get spotTrainingPlanListDialogSubtitle =>
      'Mensen met een openbaar plan voor deze spot.';

  @override
  String get spotTrainingPlanListDialogClose => 'Sluiten';

  @override
  String get spotTrainingPlanListEmpty => 'Nog geen openbare plannen.';

  @override
  String get spotTrainingPlanListLoadError => 'Kon trainingsplannen niet laden';

  @override
  String get spotTrainingPlanEditMine => 'Plan bewerken';

  @override
  String get spotTrainingPlanJoin => 'Aansluiten';

  @override
  String get spotTrainingPlanOnlyYou => 'Alleen jij';

  @override
  String get spotTrainingPlanUnnamedPerson => 'Iemand';

  @override
  String spotTrainingPlanTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get spotDetailHiddenBanner =>
      'Deze spot is verborgen voor het publiek. Hij bestaat waarschijnlijk niet meer of voldoet niet aan ons beleid. Hij verschijnt niet in zoekresultaten of op de kaart.';

  @override
  String spotDetailSourceRemovedBanner(String source) {
    return 'Deze spot staat niet meer vermeld in $source. Details kunnen verouderd zijn—controleer voor je bezoek.';
  }

  @override
  String get spotDetailSourceRemovedUnknownSource => 'de oorspronkelijke bron';

  @override
  String get spotDetailSectionFeatures => 'Kenmerken';

  @override
  String get spotDetailSectionAccess => 'Toegang';

  @override
  String get spotDetailSectionFacilities => 'Voorzieningen';

  @override
  String spotDetailJumpflixFetchFailed(String error) {
    return 'Jumpflix ophalen mislukt: $error';
  }

  @override
  String get spotDetailBrandYoutube => 'YouTube';

  @override
  String get spotDetailBrandJumpflix => 'Jumpflix';

  @override
  String get spotDetailBrandAsSeenIn => 'Zoals te zien in';

  @override
  String get spotDetailLoading => 'Laden…';

  @override
  String get spotDetailLoadingYourRating => 'Je beoordeling laden…';

  @override
  String get spotDetailRateThisSpot => 'Beoordeel deze spot';

  @override
  String get spotDetailHeaderNoRatingsYet => 'Nog geen beoordelingen';

  @override
  String get spotDetailCouldNotLoadProfile =>
      'Je profiel kon niet worden geladen.';

  @override
  String get spotDetailRefreshPageToRate =>
      'Vernieuw de pagina om te beoordelen.';

  @override
  String get spotDetailSignInToRateTitle => 'Log in om deze spot te beoordelen';

  @override
  String get spotDetailSignInToRateSubtitle =>
      'Log in om deze spot te beoordelen en andere parkoursporters te helpen.';

  @override
  String get spotDetailSignInButton => 'Inloggen';

  @override
  String get spotDetailCreateAccountButton => 'Account aanmaken';

  @override
  String get spotDetailMapSwitchToMap => 'Naar kaart';

  @override
  String get spotDetailMapSwitchToSatellite => 'Naar satelliet';

  @override
  String get spotDetailMapLocateOnMap => 'Op kaart tonen';

  @override
  String get spotDetailDuplicateOf => 'Duplicaat van';

  @override
  String get spotDetailOriginalSpotFallback => 'Originele spot';

  @override
  String get spotDetailAlsoBasedOn => 'Ook gebaseerd op';

  @override
  String spotDetailGalleryPageIndicator(int current, int total) {
    return '$current / $total';
  }

  @override
  String get spotDetailSaveMenuTooltip => 'Spot opslaan';

  @override
  String get spotDetailSaveMenuSignInTitle => 'Log in om spots op te slaan';

  @override
  String get spotDetailSaveMenuSignInBody =>
      'Voeg deze spot toe aan Wil ik bezoeken, Ben ik geweest of je eigen lijsten. Log in of maak een gratis account om te beginnen.';

  @override
  String get spotDetailSaveMenuLogInOrCreate => 'Inloggen of account aanmaken';

  @override
  String get spotDetailSaveTooltipUpdating => 'Bijwerken…';

  @override
  String get spotDetailSaveTooltipWantToVisit => 'Opgeslagen: Wil ik bezoeken';

  @override
  String get spotDetailSaveTooltipBeenHere => 'Opgeslagen: Ben ik geweest';

  @override
  String get spotDetailSaveTooltipGeneric => 'Spot opslaan';

  @override
  String get spotDetailRemovedFromWantToVisit =>
      'Verwijderd uit Wil ik bezoeken';

  @override
  String get spotDetailFailedToRemove => 'Verwijderen mislukt';

  @override
  String get spotDetailAddedToWantToVisit => 'Toegevoegd aan Wil ik bezoeken';

  @override
  String get spotDetailFailedToAdd => 'Toevoegen mislukt';

  @override
  String get spotDetailRemovedFromBeenHere => 'Verwijderd uit Ben ik geweest';

  @override
  String get spotDetailAddedToBeenHere => 'Toegevoegd aan Ben ik geweest';

  @override
  String get spotDetailWantToVisit => 'Wil ik bezoeken';

  @override
  String get spotDetailBeenHere => 'Ben ik geweest';

  @override
  String get spotDetailViewFullListTooltip => 'Volledige lijst bekijken';

  @override
  String get spotDetailAddToCustomList => 'Toevoegen aan een lijst';

  @override
  String get spotDetailListNameEmpty => 'Lijstnaam mag niet leeg zijn';

  @override
  String get spotDetailFailedAddToListGeneric =>
      'Spot toevoegen aan lijst mislukt';

  @override
  String get spotDetailFailedCreateList => 'Lijst aanmaken mislukt';

  @override
  String get spotDetailFailedAddToSomeLists =>
      'Spot toevoegen aan sommige lijsten mislukt';

  @override
  String spotDetailAddToListTitle(String name) {
    return 'Toevoegen aan $name';
  }

  @override
  String get spotDetailSelectSections => 'Kies een sectie';

  @override
  String spotDetailSectionEntryCount(int count) {
    return 'Sectie ($count spots)';
  }

  @override
  String get spotDetailAddToNewSection => 'Toevoegen aan nieuwe sectie';

  @override
  String get spotDetailSectionNameOptional => 'Sectienaam (optioneel)';

  @override
  String get spotDetailNoteOptional => 'Notitie (optioneel)';

  @override
  String get spotDetailSkip => 'Overslaan';

  @override
  String get spotDetailAdd => 'Toevoegen';

  @override
  String get spotDetailAddToListDialogTitle => 'Toevoegen aan lijst';

  @override
  String get spotDetailAlreadyInLists => 'Al in deze lijsten:';

  @override
  String get spotDetailNoListsYet =>
      'Je hebt nog geen lijsten. Maak er een om te beginnen!';

  @override
  String get spotDetailSelectListsPrompt => 'Kies een lijst';

  @override
  String get spotDetailCreateNewList => 'Nieuwe lijst maken';

  @override
  String get spotDetailListNameLabel => 'Lijstnaam';

  @override
  String get spotDetailListNameHint => 'bijv. Mijn favoriete spots';

  @override
  String get spotDetailListDescriptionLabel => 'Beschrijving';

  @override
  String get spotDetailListDescriptionHint =>
      'Voeg een beschrijving voor deze lijst toe';

  @override
  String get spotDetailVisibilityLabel => 'Zichtbaarheid';

  @override
  String get spotDetailCreateAndAdd => 'Maken en toevoegen';

  @override
  String get spotDetailReportDuplicateTitle => 'Duplicaatspot melden';

  @override
  String get spotDetailReportDuplicateIntro =>
      'Selecteer de spot waarvan dit een duplicaat is.';

  @override
  String get spotDetailEmailInvalid => 'Voer een geldig e-mailadres in.';

  @override
  String get spotDetailEmailRequired => 'Voer een e-mailadres in.';

  @override
  String get spotDetailSubmitReport => 'Melding versturen';

  @override
  String get spotDetailReportThisSpotTitle => 'Deze spot melden';

  @override
  String spotDetailReportIntro(String name) {
    return 'Laat weten wat er mis is met $name. Moderators bekijken je melding binnenkort.';
  }

  @override
  String get spotDetailReportWhatWrong => 'Wat is er aan de hand?';

  @override
  String get spotDetailReportCategoryLabel => 'Kies een categorie';

  @override
  String get spotDetailReportCategoryHint => 'Kies een meldcategorie';

  @override
  String get spotDetailReportDescribeIssue => 'Beschrijf het probleem';

  @override
  String get spotDetailReportDescribeIssueHint =>
      'Vertel wat niet klopt met de werkelijkheid';

  @override
  String get spotDetailReportAdditionalDetails => 'Extra details';

  @override
  String get spotDetailReportAdditionalDetailsHint =>
      'Nog iets dat we moeten weten?';

  @override
  String get spotDetailReportEmailLabel => 'E-mailadres';

  @override
  String get spotDetailReportEmailHelper =>
      'We nemen alleen contact op over deze melding.';

  @override
  String spotDetailReportReachOutAt(String email) {
    return 'We nemen zo nodig contact op via $email.';
  }

  @override
  String get spotDetailReportReachOutAccount =>
      'We nemen zo nodig contact op via het e-mailadres van je account.';

  @override
  String get spotDetailReportCategoryOtherDescribe =>
      'Beschrijf het probleem als je ‘Overig’ kiest.';

  @override
  String get spotDetailReportCategoryRequired => 'Kies een categorie.';

  @override
  String get spotDetailReportSendFailed =>
      'Melding kon niet worden verstuurd. Probeer het opnieuw.';

  @override
  String get spotDetailReportCategoryClosed => 'Spot gesloten of verwijderd';

  @override
  String get spotDetailReportCategoryInaccurate =>
      'Locatie of gegevens lijken onjuist';

  @override
  String get spotDetailReportCategoryUnsafe => 'Onveilige omstandigheden';

  @override
  String get spotDetailReportCategoryNotASpot => 'Geen spot';

  @override
  String get spotDetailReportCategoryOther => 'Overig';

  @override
  String get spotDetailReportCategoryClosedDesc =>
      'De spot is permanent gesloten, gesloopt of verwijderd en is niet meer toegankelijk. Geef hieronder meer details.';

  @override
  String get spotDetailReportCategoryInaccurateDesc =>
      'Iets aan deze spot lijkt niet te kloppen: de pin, naam, beschrijving of het adres kan fout zijn. Gebruik dit als je niet zeker weet wat de juiste informatie is. Beschrijf hieronder wat er mis lijkt. Weet je wat er moet veranderen? Gebruik dan «Bewerking voorstellen» in het spotmenu.';

  @override
  String get spotDetailReportCategoryUnsafeDesc =>
      'De spot is gevaarlijk geworden door constructie, omgeving of andere risico’s. Geef hieronder aan wat onveilig is.';

  @override
  String get spotDetailReportCategoryNotASpotDesc =>
      'Alleen voor objectieve issues zoals spam, ongeldige locaties (bijv. midden op zee), privéwoningen, hele steden of duidelijk ongeldige entries. Voor mening over kwaliteit: gebruik een beoordeling. Leg hieronder uit waarom dit geen spot is.';

  @override
  String get spotDetailReportCategoryOtherDesc =>
      'Elk ander probleem dat hierboven niet past. Beschrijf het in het veld hieronder.';

  @override
  String get spotDetailMarkDuplicateTitle => 'Markeer als duplicaat';

  @override
  String get spotDetailMarkDuplicateBody =>
      'Weet je zeker dat je deze spot als duplicaat wilt markeren? Dit kan later weer ongedaan worden gemaakt.';

  @override
  String get spotDetailMarkDuplicateAddToOriginal =>
      'Kies wat je aan de originele spot wilt toevoegen:';

  @override
  String get spotDetailMarkDuplicatePhotos => 'Foto’s';

  @override
  String get spotDetailMarkDuplicateYoutube => 'YouTube-links';

  @override
  String get spotDetailMarkDuplicateOverwrite =>
      'Kies wat je in de originele spot wilt overschrijven (indien ingesteld):';

  @override
  String get spotDetailMarkDuplicateName => 'Naam';

  @override
  String get spotDetailMarkDuplicateDescription => 'Beschrijving';

  @override
  String get spotDetailMarkDuplicateLocation => 'Locatie';

  @override
  String get spotDetailMarkDuplicateSpotAttributes => 'Spotkenmerken';

  @override
  String get spotDetailConfirm => 'Bevestigen';

  @override
  String get spotDetailPickImagesFailed =>
      'Foto’s kiezen mislukt. Probeer het opnieuw.';

  @override
  String get spotDetailSelectAtLeastOnePhoto => 'Selecteer minstens één foto';

  @override
  String get spotDetailSuggestPhotosTitle => 'Foto’s voorstellen';

  @override
  String get spotDetailSuggestPhotosIntro =>
      'Stel foto’s voor om toe te voegen aan deze spot. Moderators beoordelen ze voordat ze worden toegevoegd.';

  @override
  String get spotDetailSelectPhotos => 'Foto’s selecteren';

  @override
  String get spotDetailPickPhotos => 'Foto’s kiezen';

  @override
  String get spotDetailAdditionalDetailsOptional => 'Extra details (optioneel)';

  @override
  String get spotDetailAdditionalDetailsHint =>
      'Voeg extra informatie over deze foto’s toe…';

  @override
  String get spotDetailSuggestPhotosEmailHelper =>
      'We nemen alleen contact op over dit voorstel.';

  @override
  String get spotDetailSuggestPhotosSubmitFailed =>
      'Fotovoorstel versturen mislukt. Probeer het opnieuw.';

  @override
  String spotDetailSuggestPhotosSubmitError(String error) {
    return 'Fout bij fotovoorstel: $error';
  }

  @override
  String get spotDetailSuggestEditTitle => 'Bewerking voorstellen';

  @override
  String get spotDetailSuggestEditIntro =>
      'Stel wijzigingen voor deze spot voor. Moderators beoordelen je voorstellen.';

  @override
  String get spotDetailSuggestEditSuggestChange =>
      'Stel minstens één wijziging voor.';

  @override
  String get spotDetailSuggestEditSubmitFailed =>
      'Bewerkingsvoorstel versturen mislukt. Probeer het opnieuw.';

  @override
  String spotDetailSuggestEditSubmitError(String error) {
    return 'Fout bij bewerkingsvoorstel: $error';
  }

  @override
  String get spotDetailGeocoding => 'Geocoding…';

  @override
  String get spotDetailChangeLocationPicked => 'Locatie wijzigen (gekozen)';

  @override
  String get spotDetailPickLocationOnMap => 'Andere locatie op kaart kiezen';

  @override
  String get spotDetailFieldTitle => 'Titel';

  @override
  String get spotDetailFieldTitleHint => 'Spotnaam';

  @override
  String get spotDetailFieldDescription => 'Beschrijving';

  @override
  String get spotDetailFieldDescriptionHint => 'Spotbeschrijving';

  @override
  String get spotDetailFieldSpotAttributes => 'Spotkenmerken';

  @override
  String get spotDetailSuggestEditEmailHelper =>
      'We nemen alleen contact op over dit voorstel.';

  @override
  String get spotDetailMustBeLoggedInToRate =>
      'Je moet ingelogd zijn om spots te beoordelen';

  @override
  String spotDetailRatingSubmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Beoordeling $count sterren verstuurd!',
      one: 'Beoordeling 1 ster verstuurd!',
    );
    return '$_temp0';
  }

  @override
  String get spotDetailRatingSubmitFailed =>
      'Beoordeling versturen mislukt. Probeer het opnieuw.';

  @override
  String spotDetailRatingSubmitError(String error) {
    return 'Fout bij beoordeling: $error';
  }

  @override
  String get spotDetailNotExternalSource =>
      'Deze spot komt niet van een externe bron.';

  @override
  String get spotDetailMustBeLoggedInCreateNative =>
      'Je moet ingelogd zijn om een native spot aan te maken.';

  @override
  String get spotDetailCreateNativeDialogTitle => 'Native spot aanmaken';

  @override
  String get spotDetailCreateNativeDialogBody =>
      'Hiermee maak je een nieuwe native spot op basis van deze spot en markeer je de huidige spot als duplicaat daarvan. Alle spotgegevens (naam, beschrijving, locatie, foto’s, YouTube-links en kenmerken) worden gekopieerd naar de nieuwe native spot.\n\nLet op: beheerders kunnen spots verwijderen en duplicaatlinks kunnen indien nodig worden verwijderd.';

  @override
  String get spotDetailCreateButton => 'Aanmaken';

  @override
  String get spotDetailUnableCreateNativeNow =>
      'Native spot kan nu niet worden aangemaakt.';

  @override
  String get spotDetailFailedCreateNativeSpot => 'Native spot aanmaken mislukt';

  @override
  String get spotDetailNativeCreatedDuplicateMarked =>
      'Native spot aangemaakt en huidige spot als duplicaat gemarkeerd.';

  @override
  String get spotDetailFailedMarkDuplicateGeneric =>
      'Spot als duplicaat markeren mislukt';

  @override
  String spotDetailErrorCreatingNativeSpot(String error) {
    return 'Fout bij aanmaken native spot: $error';
  }

  @override
  String get spotDetailUnableMarkDuplicateNow =>
      'Deze spot kan nu niet als duplicaat worden gemarkeerd.';

  @override
  String get spotDetailAlreadyMarkedDuplicate =>
      'Deze spot is al als duplicaat gemarkeerd.';

  @override
  String get spotDetailSpotMarkedDuplicateSuccess =>
      'Spot als duplicaat gemarkeerd.';

  @override
  String spotDetailErrorMarkingDuplicateSpot(String error) {
    return 'Fout bij markeren als duplicaat: $error';
  }

  @override
  String get spotDetailModeratorsOnlyHideUnhide =>
      'Alleen moderators kunnen spots verbergen/tonen.';

  @override
  String get spotDetailHideSpotTitle => 'Spot verbergen';

  @override
  String get spotDetailUnhideSpotTitle => 'Spot tonen';

  @override
  String get spotDetailHideSpotMessage =>
      'Hiermee verberg je de spot voor het publiek. Verborgen spots verschijnen niet in zoekresultaten of op de kaart, maar de gegevens blijven bewaard en kunnen later weer zichtbaar worden gemaakt.';

  @override
  String get spotDetailUnhideSpotMessage =>
      'Hiermee zet je de spot weer publiek. Hij verschijnt weer in zoekresultaten en op de kaart.';

  @override
  String get spotDetailActionHide => 'Verbergen';

  @override
  String get spotDetailActionUnhide => 'Tonen';

  @override
  String get spotDetailUnableHideUnhideNow =>
      'Deze spot kan nu niet verborgen/getoond worden.';

  @override
  String get spotDetailSpotHiddenSuccess => 'Spot verborgen.';

  @override
  String get spotDetailSpotUnhiddenSuccess => 'Spot weer zichtbaar.';

  @override
  String get spotDetailFailedHideSpot => 'Spot verbergen mislukt';

  @override
  String get spotDetailFailedUnhideSpot => 'Spot tonen mislukt';

  @override
  String spotDetailErrorHidingSpot(String error) {
    return 'Fout bij verbergen spot: $error';
  }

  @override
  String spotDetailErrorUnhidingSpot(String error) {
    return 'Fout bij tonen spot: $error';
  }

  @override
  String get spotDetailNotMarkedAsDuplicate =>
      'Deze spot is niet als duplicaat gemarkeerd.';

  @override
  String get spotDetailModeratorsOnlyRemoveDuplicateStatus =>
      'Alleen moderators kunnen de duplicaatstatus verwijderen.';

  @override
  String get spotDetailRemoveDuplicateDialogBody =>
      'Hiermee verwijder je de duplicaatstatus van deze spot. De spot wordt niet langer als duplicaat getoond.\n\nWil je doorgaan?';

  @override
  String get spotDetailRemoveButton => 'Verwijderen';

  @override
  String get spotDetailUnableRemoveDuplicateStatusNow =>
      'Duplicaatstatus kan nu niet worden verwijderd.';

  @override
  String get spotDetailDuplicateStatusRemovedSuccess =>
      'Duplicaatstatus verwijderd.';

  @override
  String get spotDetailFailedRemoveDuplicateStatusGeneric =>
      'Duplicaatstatus verwijderen mislukt';

  @override
  String spotDetailErrorRemovingDuplicateStatus(String error) {
    return 'Fout bij verwijderen duplicaatstatus: $error';
  }

  @override
  String get spotDetailCheckingLinkedData => 'Gekoppelde gegevens controleren…';

  @override
  String get spotDetailDeleteSpotDialogTitle => 'Spot verwijderen';

  @override
  String get spotDetailDeleteSpotConfirmMessage =>
      'Weet je zeker dat je deze spot wilt verwijderen? Dit kan niet ongedaan worden gemaakt.';

  @override
  String get spotDetailLinkedDataHeading =>
      'Deze spot heeft gekoppelde gegevens:';

  @override
  String spotDetailLinkedRatingsLine(int count) {
    return '• Beoordelingen: $count';
  }

  @override
  String spotDetailLinkedReportsLine(int count) {
    return '• Spotmeldingen: $count';
  }

  @override
  String spotDetailLinkedDuplicatesLine(int count) {
    return '• Duplicaatspots: $count';
  }

  @override
  String get spotDetailResolveLinksBeforeDelete =>
      'Los deze koppelingen op voordat je de spot verwijdert.';

  @override
  String get spotDetailSpotDeletedSuccess => 'Spot verwijderd.';

  @override
  String get spotDetailFailedDeleteSpot => 'Spot verwijderen mislukt';

  @override
  String spotDetailErrorDeletingSpot(String error) {
    return 'Fout bij verwijderen spot: $error';
  }

  @override
  String get spotDetailFlagDuplicateDialogTitle => 'Markeer als duplicaat';

  @override
  String get spotDetailFlagDuplicateIntro =>
      'Deze spot lijkt een duplicaat van een andere spot. Selecteer hieronder de originele spot.';

  @override
  String get spotDetailFlagDuplicateWhichQuestion =>
      'Van welke spot is dit een duplicaat?';

  @override
  String get spotDetailDuplicateSearchHint =>
      'Plak spot-URL of voer spot-ID in';

  @override
  String get spotDetailSearch => 'Zoeken';

  @override
  String get spotDetailNearbySpotsWithin50m =>
      'Spots in de buurt (binnen ~50 m)';

  @override
  String get spotDetailFoundSpot => 'Gevonden spot';

  @override
  String spotDetailSpotIdLabel(String id) {
    return 'Spot-ID: $id';
  }

  @override
  String get spotDetailRemoveSelectionTooltip => 'Selectie verwijderen';

  @override
  String get spotDetailImageFailedToLoad => 'Afbeelding laden mislukt';

  @override
  String get spotDetailClose => 'Sluiten';

  @override
  String spotDetailExpandMoreCount(int count) {
    return 'nog $count';
  }

  @override
  String get spotDetailSubmit => 'Versturen';

  @override
  String get spotDetailDuplicateReportSelectRequired =>
      'Selecteer de spot waarvan dit een duplicaat is.';

  @override
  String get spotDetailDuplicateSearchEmpty => 'Voer een spot-ID of URL in';

  @override
  String get spotDetailDuplicateInvalidUrl => 'Ongeldig spot-ID of URL-formaat';

  @override
  String get spotDetailDuplicateCannotSelectSelf =>
      'Een spot kan geen duplicaat van zichzelf zijn';

  @override
  String get spotDetailDuplicateSpotNotFound => 'Spot niet gevonden';

  @override
  String spotDetailDuplicateFailedLoadSpot(String error) {
    return 'Spot laden mislukt: $error';
  }

  @override
  String get sourceDetailsLoadingSource => 'Bron laden...';

  @override
  String get sourceDetailsErrorTitle => 'Fout';

  @override
  String get sourceDetailsNotFound => 'Bron niet gevonden';

  @override
  String get sourceDetailsTotalSpots => 'Totaal aantal spots';

  @override
  String get sourceDetailsFolders => 'Mappen';

  @override
  String get sourceDetailsGoToSource => 'Ga naar bron';

  @override
  String get sourceDetailsAdded => 'Toegevoegd';

  @override
  String get sourceDetailsLastImported => 'Laatst geïmporteerd';

  @override
  String sourceDetailsRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagen geleden',
      one: '1 dag geleden',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uur geleden',
      one: '1 uur geleden',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuten geleden',
      one: '1 minuut geleden',
    );
    return '$_temp0';
  }

  @override
  String get sourceDetailsRelativeJustNow => 'Zojuist';

  @override
  String get eventSourceDetailsLoadingSource => 'Evenementbron laden...';

  @override
  String get eventSourceDetailsTotalEvents => 'Totaal aantal evenementen';

  @override
  String exploreEventCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count evenementen',
      one: '1 evenement',
    );
    return '$_temp0';
  }

  @override
  String spotTrackingSignInToViewList(String listName) {
    return 'Log in om je $listName-lijst te bekijken';
  }

  @override
  String spotTrackingNoSpotsInList(String listName) {
    return 'Geen spots in $listName';
  }

  @override
  String get spotTrackingAddedEmptyHint =>
      'Spots die je aan de kaart toevoegt, verschijnen hier';

  @override
  String get spotTrackingAddedVisibilityUpdateFailed =>
      'Lijstzichtbaarheid kon niet worden bijgewerkt';

  @override
  String get spotListSaveTooltipSaveList => 'Lijst opslaan';

  @override
  String get spotListSaveTooltipSavedList => 'Lijst opgeslagen';

  @override
  String get spotListSaveSignInTitle => 'Log in om lijsten op te slaan';

  @override
  String get spotListSaveSignInBody =>
      'Sla iemands spotlijst op in je lijsten zodat je die later opnieuw kunt openen.';

  @override
  String get spotListSaveSavedToProfile => 'Lijst opgeslagen in je lijsten';

  @override
  String get spotListSaveCouldNotSaveList => 'Lijst kon niet worden opgeslagen';

  @override
  String get spotListSaveRemovedFromSavedLists =>
      'Verwijderd uit opgeslagen lijsten';

  @override
  String get spotListSaveCouldNotRemoveList =>
      'Lijst kon niet worden verwijderd';

  @override
  String get spotListSaveActionSaveList => 'Lijst opslaan';

  @override
  String get spotListSaveActionRemoveFromSaved => 'Verwijderen uit opgeslagen';

  @override
  String get spotListSaveActionViewSavedLists => 'Opgeslagen lijsten bekijken';

  @override
  String get spotListDetailListNotFoundOrNotAccessible =>
      'Lijst niet gevonden of niet toegankelijk';

  @override
  String get spotListDetailDeleteListTitle => 'Lijst verwijderen';

  @override
  String spotListDetailDeleteListConfirmation(String name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';
  }

  @override
  String get spotListDetailDeleteAction => 'Verwijderen';

  @override
  String get spotListDetailListDeleted => 'Lijst verwijderd';

  @override
  String get spotListDetailFailedToDeleteList => 'Lijst verwijderen mislukt';

  @override
  String get spotListDetailNoSpotsInThisList => 'Geen spots in deze lijst';

  @override
  String get spotListDetailEditListTitle => 'Lijst bewerken';

  @override
  String get spotListEditNameLabel => 'Lijstnaam *';

  @override
  String get spotListDetailMoreInfoLinkLabel => 'Meer-infolink';

  @override
  String get spotListDetailMoreInfoLinkHint => 'https://…';

  @override
  String get spotListDetailMoreInfoLinkHelper =>
      'Een pagina elders op het web met meer informatie over deze lijst';

  @override
  String get spotListDetailMoreInfoLinkValidationError =>
      'Meer-infolink moet een geldige URL zijn (http of https), bijvoorbeeld example.com of https://example.com/pagina';

  @override
  String get spotListDetailSave => 'Opslaan';

  @override
  String get spotListDetailListUpdated => 'Lijst bijgewerkt';

  @override
  String get spotListDetailFailedToUpdateList => 'Lijst bijwerken mislukt';

  @override
  String get spotListDetailVisibilityPublicList => 'Openbare lijst';

  @override
  String get spotListDetailVisibilityUnlistedList => 'Niet-vermelde lijst';

  @override
  String get spotListDetailVisibilityPrivateList => 'Privélijst';

  @override
  String get spotListDetailCouldNotOpenProfile =>
      'Profiel kon niet worden geopend';

  @override
  String spotListDetailCreatedPart(String visibility, String date) {
    return '$visibility aangemaakt $date';
  }

  @override
  String get spotListDetailCreatedBySuffix => ' door ';

  @override
  String spotListDetailLastUpdatedPart(String date) {
    return ', en laatst bijgewerkt $date.';
  }

  @override
  String get spotListDetailMoreInformationOn => 'Meer informatie op ';

  @override
  String get detailExternalLinkCaption => 'Meer informatie';

  @override
  String detailExternalLinkOpenSemantics(String host) {
    return 'Open $host';
  }

  @override
  String get spotListDetailCopiedToClipboard =>
      'Lijst gekopieerd naar klembord!';

  @override
  String spotListDetailCopyFailed(String error) {
    return 'Lijst kopiëren mislukt: $error';
  }

  @override
  String get spotListDetailHighlightListOnMap => 'Lijst markeren op kaart';

  @override
  String get spotListDetailEditListTooltip => 'Lijst bewerken';

  @override
  String get spotListDetailMenuEditList => 'Lijst bewerken';

  @override
  String get spotListEditDiscardTitle => 'Wijzigingen verwerpen?';

  @override
  String get spotListEditDiscardMessage =>
      'Je bewerkingen aan deze lijst gaan verloren.';

  @override
  String get spotListEditDiscardAction => 'Verwerpen';

  @override
  String get spotListEditAddSection => 'Sectie toevoegen';

  @override
  String get spotListEditAddSpots => 'Spots toevoegen';

  @override
  String get spotListEditAddSpotsTooltip => 'Spots aan deze sectie toevoegen';

  @override
  String get spotListEditAddSpotsToListTooltip => 'Spots toevoegen';

  @override
  String get spotListEditNoSpotsInList => 'Nog geen spots in deze lijst';

  @override
  String get spotListEditSectionTitleLabel => 'Sectietitel';

  @override
  String get spotListEditSectionTextLabel => 'Sectietekst';

  @override
  String get spotListEditAddSectionTitle => 'Titel toevoegen';

  @override
  String get spotListEditEditSectionTooltip => 'Sectie bewerken';

  @override
  String get spotListEditDoneSectionTooltip => 'Klaar';

  @override
  String get spotListEditNoSpotsInSection => 'Geen spots in deze sectie';

  @override
  String get spotListEditEmptySectionsRemovedOnSave =>
      'Lege secties worden verwijderd als je opslaat';

  @override
  String get spotListEditRemoveSpotTitle => 'Verwijderen uit lijst';

  @override
  String spotListEditRemoveSpotMessage(String name) {
    return '\"$name\" uit deze lijst verwijderen?';
  }

  @override
  String get spotListEditRemoveSpotAction => 'Verwijderen';

  @override
  String get spotListEditRemoveSpotTooltip => 'Verwijderen uit lijst';

  @override
  String get spotListEditAddNoteTooltip => 'Notitie toevoegen';

  @override
  String get spotListEditEditNoteTooltip => 'Notitie bewerken';

  @override
  String get spotListEditNoteLabel => 'Notitie bij deze spot';

  @override
  String get spotListEditRemoveNoteTooltip => 'Notitie verwijderen';

  @override
  String get spotListEditDoneNoteTooltip => 'Klaar';

  @override
  String get spotListEditDeleteSectionTooltip => 'Sectie verwijderen';

  @override
  String get spotListEditDeleteSectionTitle => 'Sectie verwijderen?';

  @override
  String get spotListEditDeleteSectionMessage =>
      'Spots in deze sectie worden uit de lijst verwijderd.';

  @override
  String get spotListEditDragHandleTooltip => 'Sleep om te herschikken';

  @override
  String get spotListEditVisibilityPublic => 'Openbaar';

  @override
  String get spotListEditVisibilityUnlisted => 'Niet vermeld';

  @override
  String get spotListEditVisibilityPrivate => 'Privé';

  @override
  String get spotListEditVisibilityPublicHelp =>
      'Zichtbaar op je profiel en voor iedereen';

  @override
  String get spotListEditVisibilityUnlistedHelp =>
      'Zichtbaar via een directe link, maar verborgen op je profiel';

  @override
  String get spotListEditVisibilityPrivateHelp => 'Alleen zichtbaar voor jou';

  @override
  String get spotListDetailMenuDeleteList => 'Lijst verwijderen';

  @override
  String get spotListDetailPageTitle => 'Spotlijst';

  @override
  String get spotListDetailListNotFound => 'Lijst niet gevonden';

  @override
  String spotListDetailMetaDescriptionFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parkourspots',
      one: '1 parkourspot',
    );
    return 'Een samengestelde lijst met $_temp0 op Parkour·Spot';
  }

  @override
  String detailUpcomingEventLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aankomende evenementen',
      one: 'Aankomend evenement',
    );
    return '$_temp0';
  }

  @override
  String detailUpcomingEventsAndMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count andere',
      one: '1 ander',
    );
    return '$_temp0';
  }

  @override
  String get detailUpcomingEventsSheetTitle => 'Evenementen';

  @override
  String detailPastEventLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Afgelopen evenementen',
      one: 'Afgelopen evenement',
    );
    return '$_temp0';
  }

  @override
  String detailPastEventsAndMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count afgelopen evenementen',
      one: '1 afgelopen evenement',
    );
    return '$_temp0';
  }

  @override
  String get detailLinkedEventHappeningLabel => 'Nu bezig';

  @override
  String get detailLinkedEventPastLabel => 'Afgelopen';

  @override
  String get publicProfilePageTitle => 'Profiel';

  @override
  String get publicProfileShareProfileTooltip => 'Profiel delen';

  @override
  String get publicProfileErrorLoadingProfile => 'Fout bij laden van profiel';

  @override
  String get publicProfilePleaseTryAgainLater => 'Probeer het later opnieuw';

  @override
  String publicProfileMetaDescription(String name, String defaultDescription) {
    return 'Bekijk de parkourspots en lijsten van $name op Parkour·Spot — $defaultDescription';
  }

  @override
  String get publicProfileProfileNotFound => 'Profiel niet gevonden';

  @override
  String get publicProfileNotFoundOrPrivate =>
      'Dit profiel bestaat niet of is privé.';

  @override
  String publicProfileMemberSince(String date) {
    return 'Lid sinds $date';
  }

  @override
  String get publicProfileEditProfileTooltip => 'Profiel bewerken';

  @override
  String get publicProfileSpotTracking => 'Spottracking';

  @override
  String get publicProfileNoSpotsYet => 'Nog geen spots';

  @override
  String get publicProfileAddSpotsFromSpotDetailPages =>
      'Voeg spots toe vanaf spotdetailpagina’s';

  @override
  String get publicProfileBeenTo => 'Geweest';

  @override
  String get publicProfileMyCheckIns => 'Trainingsactiviteit';

  @override
  String get publicProfileMyCheckInsSubtitle =>
      'Je komende plannen en je check-inhistorie';

  @override
  String get myCheckInsSignInPrompt =>
      'Log in om je check-ins en trainingsplannen te bekijken';

  @override
  String get myCheckInsLoadMore => 'Meer laden';

  @override
  String get myCheckInsEmptyTitle => 'Nog geen bezoeken of plannen';

  @override
  String get myCheckInsEmptyDescription =>
      'Open een spot om in te checken of training te plannen. Tot de door jou ingestelde eindtijd kunnen anderen je op die spot als ‘nu hier’ zien, tenzij je het privé houdt.';

  @override
  String get myCheckInsIntro =>
      'Trainingsplannen tonen aankomende sessies die je op spots hebt gepland. Een check-in legt een bezoek vast — wanneer je aankwam en tot wanneer je verwacht te blijven. Openbare items kunnen je op een spot tonen tot je eindtijd; privé-items zijn alleen voor jou zichtbaar.';

  @override
  String get myCheckInsUpcomingPlansTitle => 'Geplande training';

  @override
  String get myCheckInsPastCheckInsTitle => 'Check-ins';

  @override
  String get myCheckInsNoCheckInsYet => 'Nog geen check-ins vastgelegd.';

  @override
  String get myCheckInsCheckInsLoadFailed =>
      'Check-ins konden niet worden geladen.';

  @override
  String get myCheckInsSpotFallback => 'Spot';

  @override
  String get myCheckInsPrivateOnlyYou => 'Privé — alleen jij kunt dit zien';

  @override
  String myCheckInsDurationDaysShort(int count) {
    return '${count}d';
  }

  @override
  String myCheckInsDurationHoursShort(int count) {
    return '${count}u';
  }

  @override
  String myCheckInsDurationMinutesShort(int count) {
    return '${count}m';
  }

  @override
  String get publicProfileSpotLists => 'Spotlijsten';

  @override
  String get publicProfileYours => 'Van jou';

  @override
  String get publicProfileCreateYourFirstList => 'Maak je eerste lijst';

  @override
  String get publicProfileSaved => 'Opgeslagen';

  @override
  String get publicProfilePublicSpotLists => 'Openbare spotlijsten';

  @override
  String get publicProfileManageLists => 'Lijsten beheren';

  @override
  String get publicProfileNoSavedListsYet => 'Nog geen opgeslagen lijsten';

  @override
  String get publicProfileSaveListsHint =>
      'Sla lijsten op die je vindt op lijstpagina’s van andere gebruikers';

  @override
  String get publicProfileSavedListsUnavailable =>
      'Je opgeslagen lijsten zijn niet meer beschikbaar of zijn verwijderd.';

  @override
  String get publicProfileListCreatedSuccessfully =>
      'Lijst succesvol aangemaakt';

  @override
  String get publicProfileChangeProfilePicture => 'Profielfoto wijzigen';

  @override
  String get publicProfileChooseFromGallery => 'Kies uit galerij';

  @override
  String get publicProfileTakePhoto => 'Foto maken';

  @override
  String get publicProfileRemovePicture => 'Foto verwijderen';

  @override
  String publicProfileErrorPickingImage(String error) {
    return 'Fout bij kiezen van afbeelding: $error';
  }

  @override
  String publicProfileErrorTakingPhoto(String error) {
    return 'Fout bij maken van foto: $error';
  }

  @override
  String get publicProfileProcessingImage => 'Afbeelding verwerken...';

  @override
  String get publicProfileReadingImage => 'Afbeelding lezen...';

  @override
  String get publicProfileUploading => 'Uploaden...';

  @override
  String get publicProfileFinishing => 'Afronden...';

  @override
  String get publicProfileUpdatingProfile => 'Profiel bijwerken...';

  @override
  String get publicProfileProfilePictureUpdatedSuccessfully =>
      'Profielfoto succesvol bijgewerkt';

  @override
  String get publicProfileFailedToUpdateProfilePicture =>
      'Bijwerken van profielfoto mislukt';

  @override
  String publicProfileErrorUploadingProfilePicture(String error) {
    return 'Fout bij uploaden van profielfoto: $error';
  }

  @override
  String get publicProfileRemoveProfilePicture => 'Profielfoto verwijderen';

  @override
  String get publicProfileRemoveProfilePictureConfirmation =>
      'Weet je zeker dat je je profielfoto wilt verwijderen?';

  @override
  String get publicProfileProfilePictureRemovedSuccessfully =>
      'Profielfoto succesvol verwijderd';

  @override
  String get publicProfileFailedToRemoveProfilePicture =>
      'Verwijderen van profielfoto mislukt';

  @override
  String publicProfileErrorRemovingProfilePicture(String error) {
    return 'Fout bij verwijderen van profielfoto: $error';
  }

  @override
  String get publicProfileProfileCopiedToClipboard =>
      'Profiel gekopieerd naar klembord!';

  @override
  String publicProfileFailedToCopyProfile(String error) {
    return 'Profiel kopiëren mislukt: $error';
  }

  @override
  String get publicProfileStatsSpots => 'Spots';

  @override
  String get publicProfileStatsRatings => 'Beoordelingen';

  @override
  String get publicProfileSettingsTitle => 'Profielinstellingen';

  @override
  String get publicProfileEmailLabel => 'E-mail';

  @override
  String get publicProfileEmailNotShownHint =>
      'Je e-mail wordt niet openbaar getoond.';

  @override
  String get publicProfileDisplayNameLabel => 'Weergavenaam';

  @override
  String get publicProfileNoDisplayNameSet => 'Geen weergavenaam ingesteld';

  @override
  String get publicProfileEditAction => 'Bewerken';

  @override
  String get publicProfileDisplayNameHint => 'Voer je naam in';

  @override
  String publicProfileDisplayNameHelper(int max) {
    return 'Hoe je naam aan anderen wordt getoond';
  }

  @override
  String publicProfileDisplayNameMaxLengthError(int max) {
    return 'Weergavenaam mag maximaal 50 tekens bevatten';
  }

  @override
  String get publicProfileDisplayNameUpdated => 'Weergavenaam bijgewerkt';

  @override
  String get publicProfileDisplayNameRemoved => 'Weergavenaam verwijderd';

  @override
  String get publicProfileDisplayNameUpdateFailed =>
      'Bijwerken van weergavenaam mislukt';

  @override
  String get publicProfileSaveAction => 'Opslaan';

  @override
  String get publicProfileUsernameLabel => 'Gebruikersnaam';

  @override
  String get publicProfileNoUsernameSet => 'Geen gebruikersnaam ingesteld';

  @override
  String get publicProfileUsernameHint => 'Voer een gebruikersnaam in';

  @override
  String get publicProfileUsernameHelper =>
      'Uniek en gebruikt in je profiel-URL';

  @override
  String get publicProfileUsernameEmpty => 'Gebruikersnaam mag niet leeg zijn';

  @override
  String get publicProfileUsernameTaken =>
      'Deze gebruikersnaam is al in gebruik';

  @override
  String get publicProfileUsernameUpdated => 'Gebruikersnaam bijgewerkt';

  @override
  String get publicProfileUsernameUpdateFailed =>
      'Bijwerken van gebruikersnaam mislukt';

  @override
  String get publicProfileInstagramLabel => 'Instagram';

  @override
  String get publicProfileNoInstagramSet => 'Geen Instagram ingesteld';

  @override
  String get publicProfileAddAction => 'Toevoegen';

  @override
  String get publicProfileInstagramLinkLabel => 'Instagram-link';

  @override
  String get publicProfileInstagramLinkHint => 'https://instagram.com/jouwnaam';

  @override
  String get publicProfileInstagramLinkHelper =>
      'Volledige URL naar je Instagram-profiel';

  @override
  String get publicProfileInstagramInvalid =>
      'Voer een geldige Instagram-URL in';

  @override
  String get publicProfileInstagramRemoved => 'Instagram-link verwijderd';

  @override
  String get publicProfileInstagramUpdated => 'Instagram-link bijgewerkt';

  @override
  String get publicProfileInstagramUpdateFailed =>
      'Bijwerken van Instagram-link mislukt';

  @override
  String get publicProfilePrivacyTitle => 'Privacy';

  @override
  String get publicProfilePrivacyPublicLabel => 'Openbaar profiel';

  @override
  String get publicProfilePrivacyPrivateLabel => 'Privéprofiel';

  @override
  String get publicProfilePrivacyPublicDescription =>
      'Iedereen kan je profiel en openbare lijsten bekijken.';

  @override
  String get publicProfilePrivacyPrivateDescription =>
      'Alleen jij kunt je profiel bekijken.';

  @override
  String get publicProfilePrivacyNowPublic => 'Je profiel is nu openbaar';

  @override
  String get publicProfilePrivacyNowPrivate => 'Je profiel is nu privé';

  @override
  String get publicProfileFailedToUpdateProfilePrivacy =>
      'Bijwerken van profielprivacy mislukt';

  @override
  String get eventDetailRouteErrorLoading => 'Fout bij laden van event';

  @override
  String get eventDetailRouteTryAgainLater => 'Probeer het later opnieuw';

  @override
  String get eventDetailRouteNotFound => 'Event niet gevonden';

  @override
  String get eventDetailRouteGoToExplore => 'Naar Ontdekken';

  @override
  String get eventDetailStartsLabel => 'Start';

  @override
  String get eventDetailEndsLabel => 'Eindigt';

  @override
  String get eventDetailLocationLabel => 'Locatie';

  @override
  String get eventDetailOpenInMaps => 'Openen in kaarten';

  @override
  String get eventDetailLinkedSpotsLabel => 'Gekoppelde spots';

  @override
  String get eventDetailNoLinkedSpots => 'Geen gekoppelde spots gevonden.';

  @override
  String get eventDetailLinkedSpotListsLabel => 'Gekoppelde spotlijsten';

  @override
  String get eventDetailNoLinkedSpotLists =>
      'Geen gekoppelde spotlijsten gevonden.';

  @override
  String get eventDetailEventSpotsLabel => 'Spots voor dit evenement';

  @override
  String get eventDetailNoEventSpots =>
      'Spotlijst voor evenement niet gevonden.';

  @override
  String get eventDetailEventSpotListViewAll => 'Spotlijst bekijken';

  @override
  String get eventDetailEventSpotListSeeOnMap => 'Op kaart bekijken';

  @override
  String eventDetailEventSpotListMoreSpots(int count) {
    return '+ $count extra';
  }

  @override
  String get eventDetailEventSpotLocationsLabel => 'Locaties van het evenement';

  @override
  String get eventDetailNoEventSpotLocations => 'Evenementspots niet gevonden.';

  @override
  String get eventDetailEventSpotViewDetails => 'Spot bekijken';

  @override
  String get adminEventEditTitle => 'Evenement bewerken';

  @override
  String get adminEventEditSave => 'Wijzigingen opslaan';

  @override
  String get adminEventExternalSyncWarningTitle => 'Extern kalender-evenement';

  @override
  String get adminEventExternalSyncWarningBody =>
      'De volgende sync kan titel, planning, beschrijving en locatie uit de externe feed overschrijven. Gekoppelde spots en lijsten beheer je hier en worden niet gewist bij sync.';

  @override
  String get adminEventLinkedSpotListsTitle => 'Gekoppelde spotlijsten';

  @override
  String get adminEventAddSpotList => 'Lijst toevoegen';

  @override
  String get adminEventNoLinkedSpotLists => 'Nog geen lijsten geselecteerd';

  @override
  String get adminSpotListSelectionTitle => 'Spotlijst kiezen';

  @override
  String get adminSpotListSelectionInputLabel => 'Lijst-ID of URL';

  @override
  String get adminSpotListSelectionInputHint =>
      'lijst-id of https://parkour.spot/list/…';

  @override
  String get adminSpotListSelectionLookup => 'Zoeken';

  @override
  String get adminSpotListSelectionSelect => 'Selecteren';

  @override
  String get adminSpotListSelectionInvalidInput =>
      'Voer een lijst-ID of /list/…-URL in';

  @override
  String get adminSpotListSelectionNotFound =>
      'Spotlijst niet gevonden of niet toegankelijk';

  @override
  String get adminSpotListSelectionPrivateList =>
      'Privélijsten kunnen niet aan evenementen worden gekoppeld';

  @override
  String get adminSpotListSelectionLoadFailed => 'Kon de spotlijst niet laden';

  @override
  String adminSpotListSelectionFoundSubtitle(String visibility, int count) {
    return '$visibility · $count spots';
  }

  @override
  String get eventDetailAdminEditEvent => 'Evenement bewerken';

  @override
  String get eventDetailMenuEditEventSubtitleNative =>
      'Maak eerst een native evenement';

  @override
  String get eventDetailMenuEditEventSubtitleMod => 'Alleen moderator';

  @override
  String get eventDetailExternalSourceCannotEdit =>
      'Evenementen van externe bronnen kunnen niet worden bewerkt. Maak eerst een native evenement via ‘Markeer als duplicaat’ → ‘Native evenement aanmaken’.';

  @override
  String get eventDetailSourceLabel => 'Bron';

  @override
  String get eventDetailAdminMenuTooltip => 'Beheer';

  @override
  String get eventDetailStaffMenuTooltip => 'Team';

  @override
  String get eventDetailMenuCreateNative => 'Native evenement aanmaken';

  @override
  String get eventDetailMenuCreateNativeSubtitle => 'Kopiëren van externe bron';

  @override
  String get eventDetailMenuSuggestPhotoSubtitleYes =>
      'Foto’s voor dit evenement indienen';

  @override
  String get eventDetailMenuSuggestPhotoSubtitleNo =>
      'Niet beschikbaar voor duplicaten';

  @override
  String get eventDetailMenuSuggestEditSubtitleYes =>
      'Wijzigingen voor dit evenement voorstellen';

  @override
  String get eventDetailMenuSuggestEditSubtitleNo =>
      'Niet beschikbaar voor duplicaten';

  @override
  String get eventDetailMenuSuggestBlockedUnavailable => 'Nu niet beschikbaar';

  @override
  String get eventDetailCreateNativeDialogTitle => 'Native evenement aanmaken';

  @override
  String get eventDetailCreateNativeDialogBody =>
      'Dit maakt een nieuw native evenement op basis van dit evenement en markeert het huidige evenement als duplicaat. Evenementgegevens (titel, beschrijving, schema, locatie, afbeeldingen, website en gekoppelde spots) worden naar het nieuwe native evenement gekopieerd.';

  @override
  String get eventDetailNotExternalSource =>
      'Dit evenement komt niet van een externe bron.';

  @override
  String get eventDetailMustBeLoggedInCreateNative =>
      'Je moet ingelogd zijn om een native evenement aan te maken.';

  @override
  String get eventDetailUnableCreateNativeNow =>
      'Kan nu geen native evenement aanmaken.';

  @override
  String get eventDetailFailedCreateNative =>
      'Native evenement aanmaken mislukt';

  @override
  String get eventDetailNativeCreatedDuplicateMarked =>
      'Native evenement aangemaakt en huidig evenement als duplicaat gemarkeerd.';

  @override
  String get eventDetailMarkDuplicateNativeOnlyHint =>
      'Alleen native evenementen kunnen worden geselecteerd. Gebruik \"Native evenement aanmaken\" in het evenementmenu om een native evenement van een extern evenement te maken.';

  @override
  String eventDetailEventCreatedOnDateBy(String date) {
    return 'Event aangemaakt $date door ';
  }

  @override
  String get eventDetailEventCreatedBy => 'Event aangemaakt door ';

  @override
  String eventDetailEventCreatedOnDate(String date) {
    return 'Event aangemaakt $date';
  }

  @override
  String eventDetailEventImportedOnDateFrom(String date) {
    return 'Event geïmporteerd $date van ';
  }

  @override
  String get eventDetailEventImportedFrom => 'Event geïmporteerd van ';

  @override
  String get eventDetailOriginalEventFallback => 'Bronevent';

  @override
  String get eventDetailDuplicateBannerTitle => 'Dubbele vermelding';

  @override
  String get eventDetailDuplicateBannerBody =>
      'Deze vermelding is als duplicaat gemarkeerd. Open het hoofdevenement voor de canonieke details.';

  @override
  String get eventDetailLinkedDuplicatesHeading => 'Dubbele vermeldingen';

  @override
  String get eventDetailMarkDuplicateStaffOnly =>
      'Alleen teamleden kunnen eventduplicaten beheren.';

  @override
  String get eventDetailMenuHideEvent => 'Event verbergen';

  @override
  String get eventDetailMenuHideEventSubtitle => 'Verbergen voor publiek';

  @override
  String get eventDetailMenuUnhideEvent => 'Event zichtbaar maken';

  @override
  String get eventDetailMenuUnhideEventSubtitle => 'Weer publiek tonen';

  @override
  String get eventDetailHiddenBanner =>
      'Dit event is verborgen voor het publiek. Het bestaat waarschijnlijk niet meer of voldoet niet aan ons beleid. Het verschijnt niet in zoekresultaten of op de kaart.';

  @override
  String get eventDetailModeratorsOnlyHideUnhide =>
      'Alleen moderators kunnen events verbergen of zichtbaar maken.';

  @override
  String get eventDetailHideEventTitle => 'Event verbergen';

  @override
  String get eventDetailUnhideEventTitle => 'Event zichtbaar maken';

  @override
  String get eventDetailHideEventMessage =>
      'Hiermee verberg je het event voor het publiek. Verborgen events verschijnen niet in zoekresultaten of op de kaart, maar de gegevens blijven bewaard en kunnen later weer zichtbaar worden gemaakt.';

  @override
  String get eventDetailUnhideEventMessage =>
      'Het event wordt weer publiek zichtbaar en verschijnt opnieuw in zoekresultaten en op de kaart.';

  @override
  String get eventDetailUnableHideUnhideNow =>
      'Dit event kan nu niet verborgen of zichtbaar worden gemaakt.';

  @override
  String get eventDetailEventHiddenSuccess => 'Event succesvol verborgen.';

  @override
  String get eventDetailEventUnhiddenSuccess =>
      'Event succesvol zichtbaar gemaakt.';

  @override
  String get eventDetailFailedHideEvent => 'Event verbergen mislukt';

  @override
  String get eventDetailFailedUnhideEvent => 'Event zichtbaar maken mislukt';

  @override
  String get eventDetailMarkDuplicatePickNativeTitle =>
      'Als duplicaat van een native event markeren';

  @override
  String get eventDetailMarkDuplicateSearchHint => 'Eventnaam, URL of ID';

  @override
  String get eventDetailMarkDuplicateNotFoundOrInvalid =>
      'Kies een passend event uit de lijst of voer een geldige event-ID of /event/…-link in.';

  @override
  String get eventDetailMarkDuplicateTargetNotNative =>
      'Dat event is geen native parkour.spot-event. Alleen native events kunnen het origineel zijn.';

  @override
  String get eventDetailMarkDuplicateTargetIsDuplicate =>
      'Dat event is al als duplicaat van een ander event gemarkeerd.';

  @override
  String get eventDetailMarkDuplicateUseButton => 'Dit event gebruiken';

  @override
  String get eventDetailMarkDuplicateSuggestionsHeader =>
      'Events in de buurt rond deze data';

  @override
  String get eventDetailMarkDuplicateNoSuggestions =>
      'Geen events in de buurt gevonden binnen een week van de data van dit event.';

  @override
  String get eventDetailDuplicatePickerNativeChip => 'Native';

  @override
  String get eventDetailMarkDuplicateSuggestionNotSelectable =>
      'Kan niet worden geselecteerd. Maak eerst een native event.';

  @override
  String eventDetailMarkDuplicateConfirmBody(String title) {
    return 'Dit event als duplicaat van «$title» markeren?';
  }

  @override
  String get eventDetailMarkDuplicateTitle => 'Markeer als duplicaat';

  @override
  String eventDetailMarkDuplicateBody(String title) {
    return 'Dit event als duplicaat van «$title» markeren? Dit kan later weer ongedaan worden gemaakt.';
  }

  @override
  String get eventDetailMarkDuplicateAddToOriginal =>
      'Kies wat je aan het originele event wilt toevoegen:';

  @override
  String get eventDetailMarkDuplicatePhotos => 'Foto’s';

  @override
  String get eventDetailMarkDuplicateLinkedSpots => 'Gekoppelde spots';

  @override
  String get eventDetailMarkDuplicateOverwrite =>
      'Kies wat je in het originele event wilt overschrijven (indien ingesteld):';

  @override
  String get eventDetailMarkDuplicateEventTitle => 'Titel';

  @override
  String get eventDetailMarkDuplicateDescription => 'Beschrijving';

  @override
  String get eventDetailMarkDuplicateLocation => 'Locatie';

  @override
  String get eventDetailMarkDuplicateSchedule => 'Planning';

  @override
  String get eventDetailMarkDuplicateWebsite => 'Website';

  @override
  String get eventDetailMarkDuplicateSuccess =>
      'Event als duplicaat gemarkeerd.';

  @override
  String get eventDuplicateChangesTitle => 'Duplicaat bijgewerkt';

  @override
  String eventDuplicateChangesBody(String title) {
    return 'Dit duplicaat is gewijzigd nadat het als zodanig is gemarkeerd. Kies waarden om naar «$title» te kopiëren, of negeer ze.';
  }

  @override
  String get eventDuplicateChangesReview => 'Wijzigingen beoordelen';

  @override
  String get eventDuplicateChangesApply => 'Toepassen';

  @override
  String get eventDuplicateChangesDismiss => 'Negeren';

  @override
  String get eventDuplicateChangesApplySuccess => 'Origineel event bijgewerkt.';

  @override
  String get eventDuplicateChangesDismissSuccess =>
      'Duplicaatwijzigingen genegeerd.';

  @override
  String get eventDuplicateChangesChip => 'Duplicaat bijgewerkt';

  @override
  String get eventDuplicateChangesQueueTitle => 'Duplicaatupdates';

  @override
  String get eventDuplicateChangesQueueSubtitle =>
      'Beoordeel duplicaten die na koppeling zijn gewijzigd';

  @override
  String get eventDuplicateChangesQueueEmpty =>
      'Geen duplicaatevents met openstaande wijzigingen';

  @override
  String get eventDuplicateChangesBannerTitle => 'Duplicaat bijgewerkt';

  @override
  String get eventDuplicateChangesBannerBody =>
      'Velden zijn gewijzigd nadat dit event als duplicaat is gemarkeerd.';

  @override
  String get eventDuplicateChangesMenuItem => 'Duplicaatwijzigingen beoordelen';

  @override
  String get eventDuplicateChangesMenuSubtitle =>
      'Kopieer bijgewerkte velden naar het origineel, of negeer ze';

  @override
  String get eventDuplicateChangesFailed =>
      'Duplicaatwijzigingen bijwerken mislukt';

  @override
  String eventDuplicateChangesPhotosValue(int count) {
    return '$count foto’s';
  }

  @override
  String eventDuplicateChangesLinkedSpotsValue(int count) {
    return '$count gekoppelde spots';
  }

  @override
  String get eventDuplicateChangesNoValue => '(leeg)';

  @override
  String get spotDuplicateChangesTitle => 'Duplicaat bijgewerkt';

  @override
  String spotDuplicateChangesBody(String name) {
    return 'Dit duplicaat is gewijzigd nadat het als zodanig is gemarkeerd. Kies waarden om naar «$name» te kopiëren, of negeer ze.';
  }

  @override
  String get spotDuplicateChangesReview => 'Wijzigingen beoordelen';

  @override
  String get spotDuplicateChangesApply => 'Toepassen';

  @override
  String get spotDuplicateChangesDismiss => 'Negeren';

  @override
  String get spotDuplicateChangesApplySuccess => 'Originele spot bijgewerkt.';

  @override
  String get spotDuplicateChangesDismissSuccess =>
      'Duplicaatwijzigingen genegeerd.';

  @override
  String get spotDuplicateChangesChip => 'Duplicaat bijgewerkt';

  @override
  String get spotDuplicateChangesQueueTitle => 'Duplicaatupdates';

  @override
  String get spotDuplicateChangesQueueSubtitle =>
      'Beoordeel duplicaten die na koppeling zijn gewijzigd';

  @override
  String get spotDuplicateChangesQueueEmpty =>
      'Geen duplicaatspots met openstaande wijzigingen';

  @override
  String get spotDuplicateChangesBannerTitle => 'Duplicaat bijgewerkt';

  @override
  String get spotDuplicateChangesBannerBody =>
      'Velden zijn gewijzigd nadat deze spot als duplicaat is gemarkeerd.';

  @override
  String get spotDuplicateChangesMenuItem => 'Duplicaatwijzigingen beoordelen';

  @override
  String get spotDuplicateChangesMenuSubtitle =>
      'Kopieer bijgewerkte velden naar het origineel, of negeer ze';

  @override
  String get spotDuplicateChangesFailed =>
      'Duplicaatwijzigingen bijwerken mislukt';

  @override
  String spotDuplicateChangesPhotosValue(int count) {
    return '$count foto’s';
  }

  @override
  String spotDuplicateChangesYoutubeValue(int count) {
    return '$count YouTube-links';
  }

  @override
  String get spotDuplicateChangesNoValue => '(leeg)';

  @override
  String get spotDuplicateChangesOpenSpot => 'Spotpagina openen';

  @override
  String get eventDetailRemoveDuplicateConfirmBody =>
      'Duplicaatstatus van dit event verwijderen? Het wijst dan niet meer naar een ander event als origineel.';

  @override
  String get eventDetailRemoveDuplicateSuccess => 'Duplicaatstatus verwijderd.';

  @override
  String get eventDetailCopiedToClipboard => 'Event gekopieerd naar klembord!';

  @override
  String eventDetailShareFailed(String error) {
    return 'Delen mislukt: $error';
  }

  @override
  String get eventDetailQuickActionSuggestPhoto => 'Foto voorstellen';

  @override
  String get eventDetailQuickActionSuggestEdit => 'Bewerking voorstellen';

  @override
  String get eventDetailUnableSuggestNow =>
      'Er kunnen nu geen wijzigingen voor dit evenement worden voorgesteld.';

  @override
  String get eventDetailCannotSuggestForDuplicate =>
      'Er kunnen geen wijzigingen worden voorgesteld voor duplicaatevenementen.';

  @override
  String get eventDetailCannotSuggestForExternal =>
      'Er kunnen geen wijzigingen worden voorgesteld voor externe evenementen. Maak eerst een native evenement aan.';

  @override
  String get eventDetailThanksPhotoSuggestion =>
      'Bedankt! Je fotovoorstel is ingediend ter beoordeling.';

  @override
  String get eventDetailThanksEditSuggestion =>
      'Bedankt! Je bewerkingsvoorstel is ingediend ter beoordeling.';

  @override
  String get eventDetailMenuFlagDuplicate => 'Markeer als duplicaat';

  @override
  String get eventDetailMenuFlagDuplicateSubtitleYes =>
      'Dit event is een duplicaat';

  @override
  String get eventDetailMenuFlagDuplicateSubtitleNo =>
      'Al gemarkeerd als duplicaat';

  @override
  String get eventDetailFlagDuplicateDialogTitle => 'Markeer als duplicaat';

  @override
  String get eventDetailFlagDuplicateIntro =>
      'Dit event lijkt een duplicaat van een ander. Selecteer hieronder het originele event.';

  @override
  String get eventDetailFlagDuplicateWhichQuestion =>
      'Van welk event is dit een duplicaat?';

  @override
  String get eventDetailFlagDuplicateSuggestionsHeader =>
      'Events in de buurt rond deze data';

  @override
  String get eventDetailThanksDuplicateSuggestion =>
      'Bedankt! Je duplicaatvoorstel is ingediend ter beoordeling.';

  @override
  String get eventDetailUnableFlagDuplicate =>
      'Dit event kan nu niet als duplicaat worden gemarkeerd.';

  @override
  String get eventDetailDuplicateReportSelectRequired =>
      'Selecteer het originele event.';

  @override
  String get eventReportQueueDuplicateSuggestion => 'Duplicaatvoorstel';

  @override
  String get eventReportQueueApproveDuplicate =>
      'Duplicaatkoppeling goedkeuren';

  @override
  String get eventReportQueueOpenOriginalEvent =>
      'Voorgesteld origineel event openen';

  @override
  String get eventDuplicateApprovalExternalOriginalHint =>
      'De gebruiker stelde een event van een externe bron voor. Kies het native parkour.spot-event als canoniek origineel.';

  @override
  String get eventDuplicateApprovalPickNativeTitle =>
      'Kies het native event als canoniek origineel.';

  @override
  String get eventDetailSuggestPhotosTitle => 'Foto’s voorstellen';

  @override
  String get eventDetailSuggestPhotosIntro =>
      'Upload foto’s voor dit evenement. Moderators beoordelen je voorstel.';

  @override
  String get eventDetailSuggestPhotosPickRequired =>
      'Voeg minstens één foto toe.';

  @override
  String get eventDetailSuggestPhotosSubmitFailed =>
      'Fotovoorstel versturen mislukt. Probeer het opnieuw.';

  @override
  String eventDetailSuggestPhotosSubmitError(String error) {
    return 'Fout bij fotovoorstel: $error';
  }

  @override
  String get eventDetailSuggestEditTitle => 'Bewerking voorstellen';

  @override
  String get eventDetailSuggestEditIntro =>
      'Stel updates voor dit evenement voor. Moderators beoordelen je voorstel.';

  @override
  String get eventDetailSuggestEditNoChanges =>
      'Stel minstens één wijziging voor.';

  @override
  String get eventDetailSuggestEditSubmitFailed =>
      'Bewerkingsvoorstel versturen mislukt. Probeer het opnieuw.';

  @override
  String eventDetailSuggestEditSubmitError(String error) {
    return 'Fout bij bewerkingsvoorstel: $error';
  }

  @override
  String get eventSuggestionApprovalTitle => 'Evenementvoorstel beoordelen';

  @override
  String get eventSuggestionCannotApproveExternalTitle =>
      'Voorstel kan niet worden goedgekeurd';

  @override
  String eventSuggestionCannotApproveExternalBody(String sourceName) {
    return 'Het geselecteerde evenement komt uit een externe bron ($sourceName). Voorstellen kunnen alleen worden goedgekeurd voor native evenementen.\n\nOm dit voorstel goed te keuren, maak je eerst een native evenement aan via het evenementmenu.';
  }

  @override
  String get eventSuggestionCannotApproveDuplicateTitle =>
      'Voorstel kan niet worden goedgekeurd';

  @override
  String get eventSuggestionCannotApproveDuplicateBody =>
      'Het geselecteerde evenement is een duplicaat van een ander evenement. Voorstellen kunnen alleen worden goedgekeurd voor het native bronevenement.\n\nSelecteer hieronder het bronevenement.';

  @override
  String get eventSuggestionTargetEventLabel => 'Doel-evenement';

  @override
  String eventSuggestionCurrentEventLabel(String title) {
    return 'Gemeld evenement: $title';
  }

  @override
  String eventSuggestionOriginalEventLabel(String title) {
    return 'Bronevenement: $title';
  }

  @override
  String eventSuggestionReportedEventDuplicateSubtitle(String title) {
    return 'Het gemelde evenement (duplicaat van $title)';
  }

  @override
  String eventSuggestionReportedEventExternalSubtitle(String sourceName) {
    return 'Het gemelde evenement (van $sourceName)';
  }

  @override
  String get eventSuggestionReportedEventSubtitle => 'Het gemelde evenement';

  @override
  String eventSuggestionOriginalEventExternalSubtitle(String sourceName) {
    return 'Het bronevenement (van $sourceName)';
  }

  @override
  String get eventSuggestionOriginalEventRecommendedSubtitle =>
      'Het bronevenement (aanbevolen)';

  @override
  String get eventSuggestionModeratorNotesLabel => 'Opmerking (optioneel)';

  @override
  String get eventSuggestionModeratorNotesHint =>
      'Documenteer waarom je dit voorstel hebt goedgekeurd of afgewezen…';

  @override
  String get eventSuggestionApproveButton => 'Voorstel goedkeuren';

  @override
  String get eventSuggestionApprovalFailed =>
      'Dit evenementvoorstel kon niet worden goedgekeurd.';

  @override
  String eventSuggestionApprovalSuccess(String eventId) {
    return 'Goedgekeurd en toegepast op evenement $eventId.';
  }

  @override
  String get eventSuggestionChangedFieldsTitle => 'Voorgestelde wijzigingen';

  @override
  String get eventSuggestionLocationRemoved => 'Locatie verwijderen';

  @override
  String eventSuggestionLinkedSpotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gekoppelde spots',
      one: '1 gekoppelde spot',
      zero: 'Geen gekoppelde spots',
    );
    return '$_temp0';
  }
}
