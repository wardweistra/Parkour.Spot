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
  String get tabAddSpot => 'Spot toevoegen';

  @override
  String get tabAccount => 'Account';

  @override
  String get profileSettingsTitle => 'Instellingen';

  @override
  String get profileSettingsLanguageLabel => 'Taal';

  @override
  String get profileSettingsLanguageDescription =>
      'Kies een taal of volg je apparaatinstellingen.';

  @override
  String get profileLanguageSystemDefault => 'Apparaattaal';

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
  String get profileHelpTranslate => 'Help mee met vertalen';

  @override
  String get profileInstallBannerTitle => 'Installeer de Parkour·Spot-app';

  @override
  String get profileInstallBannerSubtitle => 'De volledige app-ervaring';

  @override
  String get profileInstallDialogTitle => 'Parkour·Spot installeren';

  @override
  String profileInstallIntro(String device) {
    return 'Om Parkour·Spot op je $device te installeren:';
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
  String get exploreSignInToAddSpot => 'Log in om een spot toe te voegen';

  @override
  String get exploreLoadingProfile => 'Profiel laden…';

  @override
  String get exploreSearchHint => 'Zoek locatie of spot…';

  @override
  String get exploreFilterBy => 'Filteren op';

  @override
  String get exploreFilterAmenities => 'Voorzieningen';

  @override
  String get exploreFilterSources => 'Bronnen';

  @override
  String get exploreSpotAccessTitle => 'Spottoegang';

  @override
  String get exploreSpotAccessSubtitle => 'Filter spots op toegangsniveau';

  @override
  String get exploreFilterAny => 'Alle';

  @override
  String get exploreSpotFacilitiesTitle => 'Spotvoorzieningen';

  @override
  String get exploreSpotFacilitiesSubtitle =>
      'Toon spots met deze voorzieningen';

  @override
  String get exploreAttributesTitle => 'Met een van deze kenmerken';

  @override
  String get exploreAttributesSubtitle =>
      'Filter spots die minstens een van de gekozen skills of features hebben';

  @override
  String get exploreGoodForSegment => 'Geschikt voor';

  @override
  String get exploreSpotFeaturesSegment => 'Spotfeatures';

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
  String get exploreApplyFilters => 'Toepassen';

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
  String get addSpotDescriptionLabel => 'Beschrijving *';

  @override
  String get addSpotDescriptionRequired => 'Voer een beschrijving in';

  @override
  String get addSpotDescriptionMinLength =>
      'Beschrijving moet minstens 10 tekens zijn';

  @override
  String get addSpotCreating => 'Spot wordt aangemaakt…';

  @override
  String get addSpotCreateButton => 'Spot aanmaken';

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
  String get addSpotUseThisLocation => 'Deze locatie gebruiken';

  @override
  String get addSpotDirectionsTooltip => 'Route';

  @override
  String get addSpotGettingAddress => 'Adres ophalen…';

  @override
  String get spotCardNoImages => 'Geen afbeeldingen';

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
  String spotCardShareClipboardText(String name, String url) {
    return '$name 👉 $url';
  }

  @override
  String get spotCardRemovedFromSource => 'Verwijderd uit bron';

  @override
  String get spotCheckInUnnamedPerson => 'Deze persoon';

  @override
  String spotCheckInTooltipPublic(String name, String time) {
    return '$name is nu hier op deze spot (tot $time)';
  }

  @override
  String spotCheckInTooltipPrivate(String time) {
    return 'Je bent nu hier op deze spot tot $time — alleen jij ziet deze check-in';
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
    return ', en voor het laatst bijgewerkt op $date.';
  }

  @override
  String spotDetailLastUpdatedAfterAnd(String date) {
    return ' en voor het laatst bijgewerkt op $date.';
  }

  @override
  String get spotDetailDateToday => 'vandaag';

  @override
  String get spotDetailDateYesterday => 'gisteren';

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
  String get spotDetailMenuLoginSubtitle =>
      'Log eerst in om bewerkingen aan je account te koppelen';

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
  String get spotDetailMenuRemoveDuplicateStatus =>
      'Duplicaatstatus verwijderen';

  @override
  String get spotDetailMenuCreateNative => 'Native spot aanmaken';

  @override
  String get spotDetailMenuHideSpot => 'Spot verbergen';

  @override
  String get spotDetailMenuUnhideSpot => 'Spot tonen';

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
  String get spotDetailPresenceHereNow => 'Nu hier';

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
  String spotDetailAlsoBasedOnCount(int count) {
    return 'Ook gebaseerd op ($count)';
  }

  @override
  String get spotDetailNoImagesAvailable => 'Geen afbeeldingen beschikbaar';

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
  String get spotDetailAddToCustomList => 'Toevoegen aan eigen lijst';

  @override
  String get spotDetailAddToCustomListSubtitle => 'Kies of maak een lijst';

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
  String get spotDetailSelectSections => 'Selecteer secties:';

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
  String get spotDetailSelectListsPrompt =>
      'Selecteer lijsten om deze spot aan toe te voegen:';

  @override
  String get spotDetailCreateNewList => 'Nieuwe lijst maken';

  @override
  String get spotDetailListNameLabel => 'Lijstnaam';

  @override
  String get spotDetailListNameHint => 'bijv. Mijn favoriete spots';

  @override
  String get spotDetailListDescriptionLabel => 'Beschrijving (optioneel)';

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
      'Onjuiste locatie of gegevens';

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
      'De locatie op de kaart klopt niet, of gegevens zoals naam, beschrijving of adres zijn fout. Geef hieronder aan wat gecorrigeerd moet worden.';

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
  String get sourceDetailsLoadingSource => 'Loading source...';

  @override
  String get sourceDetailsErrorTitle => 'Error';

  @override
  String get sourceDetailsNotFound => 'Source not found';

  @override
  String get sourceDetailsTotalSpots => 'Total Spots';

  @override
  String get sourceDetailsFolders => 'Folders';

  @override
  String get sourceDetailsGoToSource => 'Go to Source';

  @override
  String get sourceDetailsAdded => 'Added';

  @override
  String get sourceDetailsLastImported => 'Last Imported';

  @override
  String sourceDetailsRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String get sourceDetailsRelativeJustNow => 'Just now';

  @override
  String spotTrackingSignInToViewList(String listName) {
    return 'Sign in to view your $listName list';
  }

  @override
  String spotTrackingNoSpotsInList(String listName) {
    return 'No spots in $listName';
  }

  @override
  String get spotListSaveTooltipSaveList => 'Save list';

  @override
  String get spotListSaveTooltipSavedList => 'Saved list';

  @override
  String get spotListSaveSignInTitle => 'Sign in to save lists';

  @override
  String get spotListSaveSignInBody =>
      'Save someone else’s spot list to your profile so you can open it again later.';

  @override
  String get spotListSaveSavedToProfile => 'List saved to your profile';

  @override
  String get spotListSaveCouldNotSaveList => 'Could not save list';

  @override
  String get spotListSaveRemovedFromSavedLists => 'Removed from saved lists';

  @override
  String get spotListSaveCouldNotRemoveList => 'Could not remove list';

  @override
  String get spotListSaveActionSaveList => 'Save list';

  @override
  String get spotListSaveActionRemoveFromSaved => 'Remove from saved';

  @override
  String get spotListSaveActionViewSavedLists => 'View saved lists';

  @override
  String get spotListDetailListNotFoundOrNotAccessible =>
      'List not found or not accessible';

  @override
  String get spotListDetailDeleteListTitle => 'Delete List';

  @override
  String spotListDetailDeleteListConfirmation(String name) {
    return 'Are you sure you want to delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get spotListDetailDeleteAction => 'Delete';

  @override
  String get spotListDetailListDeleted => 'List deleted';

  @override
  String get spotListDetailFailedToDeleteList => 'Failed to delete list';

  @override
  String get spotListDetailNoSpotsInThisList => 'No spots in this list';

  @override
  String get spotListDetailEditListTitle => 'Edit List';

  @override
  String get spotListDetailMoreInfoLinkLabel => 'More info link (optional)';

  @override
  String get spotListDetailMoreInfoLinkHint => 'https://…';

  @override
  String get spotListDetailMoreInfoLinkHelper =>
      'A page elsewhere on the web with more about this list';

  @override
  String get spotListDetailMoreInfoLinkValidationError =>
      'More info link must be a valid URL (http or https), e.g. example.com or https://example.com/page';

  @override
  String get spotListDetailSave => 'Save';

  @override
  String get spotListDetailListUpdated => 'List updated';

  @override
  String get spotListDetailFailedToUpdateList => 'Failed to update list';

  @override
  String get spotListDetailVisibilityPublicList => 'Public list';

  @override
  String get spotListDetailVisibilityUnlistedList => 'Unlisted list';

  @override
  String get spotListDetailVisibilityPrivateList => 'Private list';

  @override
  String get spotListDetailCouldNotOpenProfile => 'Could not open profile';

  @override
  String spotListDetailCreatedPart(String visibility, String date) {
    return '$visibility created $date';
  }

  @override
  String get spotListDetailCreatedBySuffix => ' by ';

  @override
  String spotListDetailLastUpdatedPart(String date) {
    return ', and last updated $date.';
  }

  @override
  String get spotListDetailMoreInformationOn => 'More information on ';

  @override
  String get spotListDetailCopiedToClipboard => 'List copied to clipboard!';

  @override
  String spotListDetailCopyFailed(String error) {
    return 'Failed to copy list: $error';
  }

  @override
  String get spotListDetailHighlightListOnMap => 'Highlight list on map';

  @override
  String get spotListDetailEditListTooltip => 'Edit list';

  @override
  String get spotListDetailMenuListSettings => 'List Settings';

  @override
  String get spotListDetailMenuOrganizeList => 'Organize List';

  @override
  String get spotListDetailMenuDeleteList => 'Delete List';

  @override
  String get spotListDetailPageTitle => 'Spot List';

  @override
  String get spotListDetailListNotFound => 'List not found';

  @override
  String spotListDetailMetaDescriptionFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parkour spots',
      one: '1 parkour spot',
    );
    return 'A curated list of $_temp0 on Parkour·Spot';
  }

  @override
  String get publicProfilePageTitle => 'Profile';

  @override
  String get publicProfileShareProfileTooltip => 'Share Profile';

  @override
  String get publicProfileErrorLoadingProfile => 'Error loading profile';

  @override
  String get publicProfilePleaseTryAgainLater => 'Please try again later';

  @override
  String publicProfileMetaDescription(String name, String defaultDescription) {
    return 'View $name\'s parkour spots and lists on Parkour·Spot — $defaultDescription';
  }

  @override
  String get publicProfileProfileNotFound => 'Profile not found';

  @override
  String get publicProfileNotFoundOrPrivate =>
      'This profile does not exist or is private.';

  @override
  String publicProfileMemberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get publicProfileEditProfileTooltip => 'Edit Profile';

  @override
  String get publicProfileSpotTracking => 'Spot tracking';

  @override
  String get publicProfileNoSpotsYet => 'No spots yet';

  @override
  String get publicProfileAddSpotsFromSpotDetailPages =>
      'Add spots from spot detail pages';

  @override
  String get publicProfileBeenTo => 'Been to';

  @override
  String get publicProfileMyCheckIns => 'My check-ins';

  @override
  String get publicProfileMyCheckInsSubtitle =>
      'Your recorded history of visits to spots';

  @override
  String get publicProfileSpotLists => 'Spot lists';

  @override
  String get publicProfileYours => 'Yours';

  @override
  String get publicProfileCreateYourFirstList => 'Create your first list';

  @override
  String get publicProfileSaved => 'Saved';

  @override
  String get publicProfilePublicSpotLists => 'Public Spot Lists';

  @override
  String get publicProfileNoSavedListsYet => 'No saved lists yet';

  @override
  String get publicProfileSaveListsHint =>
      'Save lists you find on other users’ list pages';

  @override
  String get publicProfileSavedListsUnavailable =>
      'Your saved lists are no longer available or were removed.';

  @override
  String get publicProfileListCreatedSuccessfully =>
      'List created successfully';

  @override
  String get publicProfileChangeProfilePicture => 'Change Profile Picture';

  @override
  String get publicProfileChooseFromGallery => 'Choose from Gallery';

  @override
  String get publicProfileTakePhoto => 'Take Photo';

  @override
  String get publicProfileRemovePicture => 'Remove Picture';

  @override
  String publicProfileErrorPickingImage(String error) {
    return 'Error picking image: $error';
  }

  @override
  String publicProfileErrorTakingPhoto(String error) {
    return 'Error taking photo: $error';
  }

  @override
  String get publicProfileProcessingImage => 'Processing image...';

  @override
  String get publicProfileReadingImage => 'Reading image...';

  @override
  String get publicProfileUploading => 'Uploading...';

  @override
  String get publicProfileFinishing => 'Finishing...';

  @override
  String get publicProfileUpdatingProfile => 'Updating profile...';

  @override
  String get publicProfileProfilePictureUpdatedSuccessfully =>
      'Profile picture updated successfully';

  @override
  String get publicProfileFailedToUpdateProfilePicture =>
      'Failed to update profile picture';

  @override
  String publicProfileErrorUploadingProfilePicture(String error) {
    return 'Error uploading profile picture: $error';
  }

  @override
  String get publicProfileRemoveProfilePicture => 'Remove Profile Picture';

  @override
  String get publicProfileRemoveProfilePictureConfirmation =>
      'Are you sure you want to remove your profile picture?';

  @override
  String get publicProfileProfilePictureRemovedSuccessfully =>
      'Profile picture removed successfully';

  @override
  String get publicProfileFailedToRemoveProfilePicture =>
      'Failed to remove profile picture';

  @override
  String publicProfileErrorRemovingProfilePicture(String error) {
    return 'Error removing profile picture: $error';
  }

  @override
  String get publicProfileProfileCopiedToClipboard =>
      'Profile copied to clipboard!';

  @override
  String publicProfileFailedToCopyProfile(String error) {
    return 'Failed to copy profile: $error';
  }

  @override
  String get publicProfileStatsSpots => 'Spots';

  @override
  String get publicProfileStatsRatings => 'Ratings';

  @override
  String get publicProfileSettingsTitle => 'Profile Settings';

  @override
  String get publicProfileEmailLabel => 'Email';

  @override
  String get publicProfileEmailNotShownHint =>
      'Your email is not shown on your public profile.';

  @override
  String get publicProfileDisplayNameLabel => 'Display Name';

  @override
  String get publicProfileNoDisplayNameSet => 'No display name set';

  @override
  String get publicProfileEditAction => 'Edit';

  @override
  String get publicProfileDisplayNameHint => 'Enter your display name';

  @override
  String publicProfileDisplayNameHelper(int max) {
    return 'Shown on your profile and spots you create (max $max characters)';
  }

  @override
  String publicProfileDisplayNameMaxLengthError(int max) {
    return 'Display name must be at most $max characters';
  }

  @override
  String get publicProfileDisplayNameUpdated =>
      'Display name updated successfully';

  @override
  String get publicProfileDisplayNameRemoved => 'Display name removed';

  @override
  String get publicProfileDisplayNameUpdateFailed =>
      'Failed to update display name';

  @override
  String get publicProfileSaveAction => 'Save';

  @override
  String get publicProfileUsernameLabel => 'Username';

  @override
  String get publicProfileNoUsernameSet => 'No username set';

  @override
  String get publicProfileUsernameHint => 'Enter username';

  @override
  String get publicProfileUsernameHelper =>
      '3-27 characters, letters, numbers, underscores, and hyphens only';

  @override
  String get publicProfileUsernameEmpty => 'Username cannot be empty';

  @override
  String get publicProfileUsernameTaken => 'Username is already taken';

  @override
  String get publicProfileUsernameUpdated => 'Username updated successfully';

  @override
  String get publicProfileUsernameUpdateFailed => 'Failed to update username';

  @override
  String get publicProfileInstagramLabel => 'Instagram';

  @override
  String get publicProfileNoInstagramSet => 'No Instagram link set';

  @override
  String get publicProfileAddAction => 'Add';

  @override
  String get publicProfileInstagramLinkLabel => 'Instagram Link';

  @override
  String get publicProfileInstagramLinkHint =>
      'https://www.instagram.com/your_handle/';

  @override
  String get publicProfileInstagramLinkHelper =>
      'You can also paste @handle or just the handle';

  @override
  String get publicProfileInstagramInvalid =>
      'Enter a valid Instagram profile URL or handle';

  @override
  String get publicProfileInstagramRemoved => 'Instagram link removed';

  @override
  String get publicProfileInstagramUpdated =>
      'Instagram link updated successfully';

  @override
  String get publicProfileInstagramUpdateFailed =>
      'Failed to update Instagram link';

  @override
  String get publicProfilePrivacyTitle => 'Profile Privacy';

  @override
  String get publicProfilePrivacyPublicLabel => 'Public Profile';

  @override
  String get publicProfilePrivacyPrivateLabel => 'Private Profile';

  @override
  String get publicProfilePrivacyPublicDescription =>
      'Your profile is visible to everyone';

  @override
  String get publicProfilePrivacyPrivateDescription =>
      'Your profile is private and not visible to others';

  @override
  String get publicProfilePrivacyNowPublic => 'Profile is now public';

  @override
  String get publicProfilePrivacyNowPrivate => 'Profile is now private';

  @override
  String get publicProfileFailedToUpdateProfilePrivacy =>
      'Failed to update profile privacy';
}
