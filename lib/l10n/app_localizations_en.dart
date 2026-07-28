// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabAdd => 'Add';

  @override
  String get tabAccount => 'Account';

  @override
  String get profileSettingsTitle => 'Settings';

  @override
  String get profileSettingsSubtitle => 'Language and locations you care about';

  @override
  String get profileSettingsLanguageLabel => 'Language';

  @override
  String get profileSettingsLanguageDescription =>
      'Choose a language or follow your device settings.';

  @override
  String get profileLanguageSystemDefault =>
      'Automatic (English if unsupported)';

  @override
  String get profileLoadErrorDefault => 'Failed to load profile.';

  @override
  String get profileRefreshPage => 'Refresh page';

  @override
  String get profileRetry => 'Retry';

  @override
  String get profileSignInTitle => 'Sign in to access your account';

  @override
  String get profileSignInSubtitle =>
      'Sign in to manage your spots and rate locations.';

  @override
  String get profileSignInButton => 'Sign In';

  @override
  String get profileOrDivider => 'OR';

  @override
  String get profileCreateAccount => 'Create an Account';

  @override
  String get profileDefaultDisplayName => 'User';

  @override
  String get profileViewEditSubtitle => 'View and edit your profile';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'New spots nearby, training plans, check-ins, and other updates for you';

  @override
  String get notificationsEmptyTitle => 'All quiet for now';

  @override
  String get notificationsEmptyBody =>
      'When someone adds a spot nearby, plans training where you train, or checks in nearby, it’ll show up here.';

  @override
  String get notificationsLoadError =>
      'We couldn’t load your notifications. Check your connection and try again.';

  @override
  String get notificationsRetry => 'Try again';

  @override
  String get notificationsOpenFailedSnackbar =>
      'This notification couldn’t be opened. Please try again later.';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsMarkAllReadFailed =>
      'Couldn’t mark all as read. Try again.';

  @override
  String get notificationsMarkAsReadFailed =>
      'Couldn’t mark as read. Try again.';

  @override
  String get notificationsMarkAsUnreadFailed =>
      'Couldn’t mark as unread. Try again.';

  @override
  String get notificationsMarkAsUnreadHint => 'Long-press to mark as unread';

  @override
  String get notificationsMarkAsReadHint => 'Long-press to mark as read';

  @override
  String get notificationsShowAll => 'Show all';

  @override
  String get notificationsUnreadOnly => 'Unread only';

  @override
  String get notificationsEmptyFilteredTitle => 'You’re all caught up';

  @override
  String get notificationsEmptyFilteredBody =>
      'No unread notifications right now.';

  @override
  String get notificationsTimeUnknown => 'Recently';

  @override
  String notificationsOpenSemantic(String title) {
    return 'Open notification: $title';
  }

  @override
  String get notificationsActorSomeone => 'Someone';

  @override
  String get notificationsSpotUntitled => 'Untitled spot';

  @override
  String notificationNearbyNewSpotTitle(String spotName) {
    return 'New spot nearby: $spotName';
  }

  @override
  String notificationNearbyNewSpotBody(String actorName) {
    return '$actorName added a new parkour spot near one of your saved locations.';
  }

  @override
  String notificationNearbyCheckInTitle(String actorName, String spotName) {
    return '$actorName is training now at $spotName';
  }

  @override
  String get notificationNearbyCheckInBody =>
      'They’ve just checked in to this spot.';

  @override
  String notificationNearbyTrainingPlanTitle(
    String actorName,
    String spotName,
  ) {
    return '$actorName planned training at $spotName';
  }

  @override
  String get notificationNearbyTrainingPlanBody =>
      'They shared a public training window near one of your saved locations.';

  @override
  String notificationTrainingPlanCheckInReminderTitle(String spotName) {
    return 'Time to check in at $spotName';
  }

  @override
  String get notificationTrainingPlanCheckInReminderBody =>
      'Your planned session has started. Tap to check in.';

  @override
  String get profileModeratorSectionTitle => 'Moderator';

  @override
  String get profileModeratorToolsTitle => 'Moderator Tools';

  @override
  String get profileModeratorToolsSubtitle =>
      'Review and resolve incoming spot reports';

  @override
  String get profileAdminSectionTitle => 'Administrator';

  @override
  String get profileAdminToolsTitle => 'Admin Tools';

  @override
  String get profileAdminToolsSubtitle =>
      'Manage sources and administrative tasks';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileSignOutMessage => 'Are you sure you want to sign out?';

  @override
  String get profileCancel => 'Cancel';

  @override
  String get profileLocationAlertsTitle => 'Location alerts';

  @override
  String get profileNotificationSettingsTitle => 'Notification settings';

  @override
  String get profilePushNotificationsThisDeviceTitle =>
      'Push notifications on this browser/device';

  @override
  String get profilePushNotificationsUnsupported =>
      'Push notifications are not supported on this browser.';

  @override
  String get profilePushNotificationsLoading =>
      'Checking push notification status for this device...';

  @override
  String get profilePushNotificationsPermissionDenied =>
      'Push permission is blocked in your browser settings for this site.';

  @override
  String get profilePushNotificationsPermissionNotDetermined =>
      'Turn this on to ask for permission and subscribe this browser.';

  @override
  String get profilePushNotificationsEnabled =>
      'This browser is subscribed and can receive push alerts.';

  @override
  String get profilePushNotificationsPermissionGrantedButOff =>
      'Permission is granted, but this browser is currently unsubscribed.';

  @override
  String get profilePushNotificationsUnknown =>
      'Push status is currently unavailable. Try again shortly.';

  @override
  String get profilePushNotificationsError =>
      'We couldn\'t update push notifications on this browser. Please try again.';

  @override
  String get profileLocationAlertsDescription =>
      'Control which locations are used for nearby alerts, including check-ins, new spots, training plans, and future events.';

  @override
  String get profileLocationAlertsShareLastKnownTitle =>
      'Use last known location';

  @override
  String get profileLocationAlertsShareLastKnownSubtitle =>
      'Store your device\'s last known location in the cloud to match nearby alerts.';

  @override
  String get profileLocationAlertsNotifyNewSpotsTitle =>
      'Notify me about new spots nearby';

  @override
  String get profileLocationAlertsNotifyNewSpotsSubtitle =>
      'Get an in-app notification when someone adds a spot within about 5 km of an active saved place or your last known location.';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsTitle =>
      'Notify me about nearby check-ins';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsSubtitle =>
      'Get an in-app notification when someone checks in at a spot within about 5 km of an active saved place or your last known location.';

  @override
  String get profileLocationAlertsNotifyTrainingPlansTitle =>
      'Notify me about nearby training plans';

  @override
  String get profileLocationAlertsNotifyTrainingPlansSubtitle =>
      'Get an in-app notification when someone shares a public training plan at a spot within about 5 km of an active saved place or your last known location.';

  @override
  String get profileTrainingPlanCheckInReminderTitle =>
      'Remind me to check in for planned sessions';

  @override
  String get profileTrainingPlanCheckInReminderSubtitle =>
      'Get an in-app reminder when your planned session has started and you haven’t checked in at that spot yet.';

  @override
  String get profileLocationAlertsSavedLocationsTitle =>
      'Locations of interest';

  @override
  String get profileLocationAlertsAddLocationButton => 'Add';

  @override
  String get profileLocationAlertsNoLocationsEnabledWarning =>
      'You won’t receive any location-based notifications until you turn on “Use last known location” or enable at least one saved place.';

  @override
  String get profileLocationAlertsEmptyState =>
      'No saved locations yet. Add places like Home or Work.';

  @override
  String get profileLocationAlertsDefaultLabel => 'Saved location';

  @override
  String get profileLocationAlertsDisableTooltip => 'Disable';

  @override
  String get profileLocationAlertsEnableTooltip => 'Enable';

  @override
  String get profileLocationAlertsEditTooltip => 'Edit';

  @override
  String get profileLocationAlertsDeleteTooltip => 'Delete';

  @override
  String get profileLocationAlertsDeleteTitle => 'Delete saved location?';

  @override
  String profileLocationAlertsDeleteMessage(String label) {
    return 'Are you sure you want to delete $label?';
  }

  @override
  String get profileLocationAlertsDeleteConfirmButton => 'Delete';

  @override
  String get profileLocationAlertsDialogAddTitle => 'Add location';

  @override
  String get profileLocationAlertsDialogEditTitle => 'Edit location';

  @override
  String get profileLocationAlertsLabelFieldLabel => 'Label';

  @override
  String get profileLocationAlertsLabelFieldPlaceholder => 'Home';

  @override
  String get profileLocationAlertsEnabledLabel => 'Enabled';

  @override
  String get profileLocationAlertsLabelRequired => 'Please enter a label';

  @override
  String get profileLocationAlertsLocationRequired =>
      'Please pick a location on the map';

  @override
  String get profileAboutIntro =>
      'Parkour·Spot is a community-driven app for discovering and sharing parkour and freerunning spots worldwide. We\'re making it simple to find quality locations—wherever you train.';

  @override
  String get profileReadMore => 'Read more';

  @override
  String get profileAboutStoryBeforeName => 'Started by ';

  @override
  String get profileAboutStoryAfterName =>
      ' from the Utrecht parkour community, the app brings together local knowledge from existing city and regional maps—whether they lived on Facebook, Instagram, websites, or retired apps—so great spot data doesn\'t get lost.';

  @override
  String get profileAboutMapMission =>
      'This is your map. Add new spots, rate existing ones, and enrich listings with details. The more we contribute, the stronger the community\'s shared knowledge becomes.';

  @override
  String get profileAboutPrinciplesHeader => 'Our principles:';

  @override
  String get profileAboutPrincipleTransparency =>
      '• Transparency: you can browse the app without an account, and each spot shows which external sources contributed to it.';

  @override
  String get profileAboutPrinciplePortability =>
      '• Portability: we\'re building export tools so spot data can be used beyond the app.';

  @override
  String get profileAboutPrincipleOpenSource =>
      '• Open source: the app is community-owned, not dependent on one person.';

  @override
  String get profileAboutEnjoy =>
      'Enjoy discovering and sharing spots with Parkour.spot. Questions or ideas? Tap the contact button—we\'d love to hear from you.';

  @override
  String get profileCreditsBy => 'Major contributions by ';

  @override
  String get profileCreditsDaphneArt => ' (art), ';

  @override
  String get profileCreditsComma => ', ';

  @override
  String get profileCreditsEnd => ' and many others.';

  @override
  String get profileViewSourceCode => 'View source code';

  @override
  String get profileContactUs => 'Contact us';

  @override
  String get profileReportIssue => 'Report an issue';

  @override
  String get profileInstallBannerTitle => 'Install the Parkour·Spot app';

  @override
  String get profileInstallBannerSubtitle => 'Get the full app experience';

  @override
  String get profileInstallDialogTitle => 'Install Parkour·Spot';

  @override
  String profileInstallIntro(String device, String browser) {
    return 'To install Parkour·Spot on your $device, open this page in $browser and follow these steps:';
  }

  @override
  String get profileInstallDeviceIphone => 'iPhone';

  @override
  String get profileInstallDeviceAndroid => 'Android device';

  @override
  String get profileInstallIosStep1 =>
      'Tap the Share button at the bottom of the screen';

  @override
  String get profileInstallIosStep2 =>
      'Scroll down and tap \"Add to Home Screen\"';

  @override
  String get profileInstallIosStep3 => 'Tap \"Add\" in the top right corner';

  @override
  String get profileInstallIosStep4 =>
      'The app will appear on your home screen!';

  @override
  String get profileInstallAndroidStep1 =>
      'Tap the More menu (⋯) in the top right corner';

  @override
  String get profileInstallAndroidStep2 => 'Tap \"Add to home screen\"';

  @override
  String get profileInstallAndroidStep3 => 'Tap \"Install app\"';

  @override
  String get profileInstallAndroidStep4 =>
      'The app will appear on your home screen!';

  @override
  String get profileInstallGotIt => 'Got it';

  @override
  String get exploreMetaDefaultTitle => 'Parkour·Spot';

  @override
  String get exploreMetaDefaultDescription =>
      'Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.';

  @override
  String exploreMetaTitleCityCountry(String city, String country) {
    return 'Best parkour spots in $city, $country';
  }

  @override
  String exploreMetaDescriptionCityCountry(String city, String country) {
    return 'Discover the best parkour spots in $city, $country. Find training locations, share your favorite spots, and connect with the parkour community.';
  }

  @override
  String exploreMetaTitleCountry(String country) {
    return 'Best parkour spots in $country';
  }

  @override
  String exploreMetaDescriptionCountry(String country) {
    return 'Discover the best parkour spots in $country. Find training locations, share your favorite spots, and connect with the parkour community.';
  }

  @override
  String get exploreAddSpotTitle => 'Add New Spot';

  @override
  String get exploreAddSpotSubtitle =>
      'Share your favorite parkour spots with the community';

  @override
  String get exploreSignInToAddSpot => 'Sign in to add spots and events';

  @override
  String get exploreSignInToAddSubtitle =>
      'Contribute new spots or submit event proposals for moderator review.';

  @override
  String get addHubHeading => 'What do you want to add?';

  @override
  String get addHubSubtitle => 'Share what you know with the community map.';

  @override
  String get addHubSpotTitle => 'Add spot';

  @override
  String get addHubSpotDescription =>
      'Drop a pin, add photos, and put a new training spot on the map.';

  @override
  String get addHubSpotPublishBadge => 'Live on the map right away';

  @override
  String get addHubSpotButton => 'Create spot';

  @override
  String get addHubEventTitle => 'Add New Event';

  @override
  String get addHubEventDescription =>
      'Propose a jam, meetup, or session for others to find.';

  @override
  String get addHubEventModerationBadge => 'Reviewed by moderators';

  @override
  String get addHubEventButton => 'Add new event';

  @override
  String get addHubSignInTitle => 'Sign in to contribute';

  @override
  String get addHubSignInSubtitle =>
      'Free account. Add spots to the map or propose events for the community.';

  @override
  String get exploreLoadingProfile => 'Loading your profile…';

  @override
  String get exploreSearchHint => 'Search location or spot…';

  @override
  String get explorePickerTitleLocation => 'Pick location';

  @override
  String get explorePickerTitleSpots => 'Choose spot';

  @override
  String get explorePickerTitleEvents => 'Choose event';

  @override
  String get explorePickerTitleSpotsAndEvents => 'Choose spot or event';

  @override
  String get explorePickerSearchHintEvents => 'Search location or event…';

  @override
  String get explorePickerSearchHintLocation => 'Search location…';

  @override
  String get explorePickerConfirmSelect => 'Select';

  @override
  String get explorePickerConfirmAdd => 'Add';

  @override
  String get explorePickerAlreadyAdded => 'Added';

  @override
  String explorePickerDone(int count) {
    return 'Done ($count)';
  }

  @override
  String get explorePickerLoading => 'Loading map…';

  @override
  String get exploreFilterBy => 'Filter by';

  @override
  String get exploreFilterAmenities => 'Amenities';

  @override
  String get exploreFilterSources => 'Sources';

  @override
  String get exploreSpotAccessTitle => 'Spot Access';

  @override
  String get exploreSpotAccessSubtitle => 'Filter spots by access level';

  @override
  String get exploreFilterAny => 'Any';

  @override
  String get exploreSpotFacilitiesTitle => 'Spot Facilities';

  @override
  String get exploreSpotFacilitiesSubtitle => 'Show spots with these amenities';

  @override
  String get exploreAttributesTitle => 'With any of these attributes';

  @override
  String get exploreAttributesSubtitle =>
      'Filter spots that have any of the selected skills or features';

  @override
  String get exploreGoodForSegment => 'Good For';

  @override
  String get exploreSpotFeaturesSegment => 'Spot Features';

  @override
  String get exploreSpotSourceLabel => 'Spot Source';

  @override
  String get exploreSourcesLoadError => 'Failed to load sources';

  @override
  String get exploreAllSources => 'All Sources';

  @override
  String get exploreParkourSpotNative => 'Parkour·Spot (Native)';

  @override
  String get exploreAllFolders => 'All Folders';

  @override
  String exploreLocationError(String error) {
    return 'Error getting location: $error';
  }

  @override
  String get exploreCurrentLocationSnackbar => 'This is your current location';

  @override
  String get exploreCloseTooltip => 'Close';

  @override
  String get exploreClearSearchTooltip => 'Clear';

  @override
  String get exploreFiltersTooltip => 'Filters';

  @override
  String get exploreFindingLocation => 'Finding location...';

  @override
  String get exploreAddSpotHereTitle => 'Add spot at this location?';

  @override
  String exploreMapRankedTotalBar(int total) {
    return '$total spots';
  }

  @override
  String exploreMapSpotsFoundLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots found',
      one: '1 spot found',
    );
    return '$_temp0';
  }

  @override
  String exploreMapBestShownParenthetical(int count) {
    return ' ($count best shown)';
  }

  @override
  String get exploreMapListModeSpots => 'Spots';

  @override
  String get exploreMapListModeEvents => 'Events';

  @override
  String get exploreNoEventsArea => 'No events in this area';

  @override
  String get exploreNoEventsAreaHint =>
      'Pan the map to another area or check back later';

  @override
  String get spotCardUpcomingEventBadge => 'Event';

  @override
  String get exploreEventLocate => 'Locate';

  @override
  String get exploreNoSpotsSearch => 'No spots found';

  @override
  String get exploreNoSpotsArea => 'No spots in this area';

  @override
  String get exploreNoSpotsSearchHint => 'Try adjusting your search terms';

  @override
  String get exploreNoSpotsMapHint => 'Move the map to explore different areas';

  @override
  String get exploreRefreshMapTooltip => 'Refresh spots in current view';

  @override
  String get exploreSwitchToMap => 'Switch to Map';

  @override
  String get exploreSwitchToSatellite => 'Switch to Satellite';

  @override
  String get exploreLocationPermissionDenied => 'Location permission denied';

  @override
  String get exploreCenterOnMyLocation => 'Center on my location';

  @override
  String get exploreFiltersDialogTitle => 'Filters';

  @override
  String get exploreClearFilters => 'Clear';

  @override
  String get exploreApplyFilters => 'Apply';

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
  String get explorePwaBannerInstall => 'Install';

  @override
  String get addSpotPickImagesFailed =>
      'Failed to pick images. Please try again.';

  @override
  String get addSpotTakePhotoFailed =>
      'Failed to take photo. Please try again.';

  @override
  String get addSpotNeedPhoto => 'Please upload at least one photo of the spot';

  @override
  String get addSpotNeedLocation =>
      'Please wait for location to be determined or pick a location on the map';

  @override
  String addSpotCreateError(String error) {
    return 'Error creating spot: $error';
  }

  @override
  String get addSpotNameLabel => 'Spot Name *';

  @override
  String get addSpotNameRequired => 'Please enter a spot name';

  @override
  String get addSpotDescriptionLabel => 'Description *';

  @override
  String get addSpotDescriptionRequired => 'Please enter a description';

  @override
  String get addSpotDescriptionMinLength =>
      'Description must be at least 10 characters';

  @override
  String get addSpotCreating => 'Creating Spot...';

  @override
  String get addSpotCreateButton => 'Create Spot';

  @override
  String get addSpotLocationSectionTitle => 'Select Spot Location';

  @override
  String get addSpotGettingLocation => 'Getting your location...';

  @override
  String get addSpotLocationNotAvailable => 'Location not available';

  @override
  String get addSpotPickLocationHint => 'Pick location';

  @override
  String get addSpotImagesSectionTitle => 'Select Spot Images';

  @override
  String get addSpotGalleryButton => 'Gallery';

  @override
  String get addSpotCameraButton => 'Camera';

  @override
  String get addSpotGoodForTitle => 'Good For';

  @override
  String get addSpotGoodForSubtitle =>
      'What parkour skills can be practiced here?';

  @override
  String get addSpotFeaturesTitle => 'Spot Features';

  @override
  String get addSpotFeaturesSubtitle =>
      'What physical features does this spot have?';

  @override
  String get addSpotAccessTitle => 'Spot Access';

  @override
  String get addSpotAccessSubtitle => 'What is the access level for this spot?';

  @override
  String get addSpotFacilitiesFormTitle => 'Spot Facilities';

  @override
  String get addSpotFacilitiesSubtitle =>
      'What amenities are available at this spot?';

  @override
  String get addSpotLongPressHintSkill => 'Long press any skill for more info';

  @override
  String get addSpotLongPressHintFeature =>
      'Long press any feature for more info';

  @override
  String get addSpotLongPressHintFacility =>
      'Long press any facility for more info';

  @override
  String get addSpotPickLocationAppBarTitle => 'Pick Location';

  @override
  String get addSpotTipLongPressMobile =>
      'Tip: You can also add spots from the Explore map by long-pressing on any location.';

  @override
  String get addSpotTipRightClickDesktop =>
      'Tip: You can also add spots from the Explore map by right-clicking on any location.';

  @override
  String get addEventTipLongPressMobile =>
      'Tip: You can also add events from the Explore map by long-pressing on any location.';

  @override
  String get addEventTipRightClickDesktop =>
      'Tip: You can also add events from the Explore map by right-clicking on any location.';

  @override
  String get addSpotUseThisLocation => 'Use this location';

  @override
  String get addSpotDirectionsTooltip => 'Directions';

  @override
  String get addSpotGettingAddress => 'Getting address...';

  @override
  String get addEventTitle => 'Add New Event';

  @override
  String get addEventModerationNotice =>
      'Event proposals are reviewed by moderators before they become public.';

  @override
  String get addEventTitleLabel => 'Event title *';

  @override
  String get addEventTitleRequired => 'Title is required.';

  @override
  String get addEventTitleTooLong => 'Title is too long.';

  @override
  String get addEventDescriptionLabel => 'Description (optional)';

  @override
  String get addEventDescriptionTooLong => 'Description is too long.';

  @override
  String get addEventWebsiteLabel => 'Website URL (optional)';

  @override
  String get addEventWebsiteHint => 'https://example.com';

  @override
  String get addEventPhotosSectionTitle => 'Select Event Images';

  @override
  String get addEventAllDay => 'All-day event';

  @override
  String get addEventTimezoneLabel => 'Timezone';

  @override
  String get addEventStartLabel => 'Start';

  @override
  String get addEventEndLabel => 'End (optional)';

  @override
  String get addEventEndNotSet => 'Not set';

  @override
  String get addEventClearEndTooltip => 'Clear end';

  @override
  String get addEventSchedulePickStartDate => 'Select start date';

  @override
  String get addEventSchedulePickStartTime => 'Select start time';

  @override
  String get addEventSchedulePickEndDateOptional =>
      'Select end date (optional)';

  @override
  String get addEventSchedulePickEndTimeOptional =>
      'Select end time (optional)';

  @override
  String get addEventScheduleSkipEnd => 'Skip';

  @override
  String get addEventScheduleLabel => 'Dates';

  @override
  String get addEventLinkingSectionTitle => 'Linking';

  @override
  String get addEventWhereSectionTitle => 'Select Event Location';

  @override
  String get addEventWhenSectionTitle => 'Select Event Schedule';

  @override
  String get addEventAddressNeedsResolve =>
      'Tap the search icon next to the address to confirm it, or pick a location on the map.';

  @override
  String get addEventLinkSpotButton => 'Link spot';

  @override
  String addEventLinkedSpotLabel(String name) {
    return 'Spot: $name';
  }

  @override
  String addEventLinkedSpotListLabel(String name) {
    return 'Spot list: $name';
  }

  @override
  String get addEventLocationNotSet => 'Location not set';

  @override
  String get addEventExactLocationSet => 'Exact location set';

  @override
  String get addEventLocationSectionTitle => 'Location';

  @override
  String get addEventLocationSectionHint =>
      'Add one or more spots and/or one exact event location.';

  @override
  String get addEventAddressLabel => 'Exact address (optional)';

  @override
  String get addEventAddressHint => 'Street, number, city';

  @override
  String get addEventUseAddressButton => 'Use address';

  @override
  String get addEventPickLocationButton => 'Pick on map';

  @override
  String get addEventClearAddressTooltip => 'Clear address';

  @override
  String get addEventAddressRequiredToResolve =>
      'Enter an address to search for.';

  @override
  String get addEventAddressNotFound =>
      'Could not find coordinates for this address.';

  @override
  String get addEventPickLocationHint =>
      'Pick a location on the map (optional when linked spot/list exists).';

  @override
  String get addEventClearLocationTooltip => 'Clear location';

  @override
  String get addEventPickLocationTooltip => 'Pick location';

  @override
  String addEventApproxCoordinates(String latitude, String longitude) {
    return 'Approx. $latitude, $longitude';
  }

  @override
  String get addEventSubmitting => 'Submitting...';

  @override
  String get addEventSubmitButton => 'Submit for review';

  @override
  String get addEventWebsiteInvalid =>
      'Website URL must be a valid http(s) URL.';

  @override
  String get addEventEndBeforeStart => 'End time cannot be before start time.';

  @override
  String get addEventNeedLocationOrLink =>
      'Add a map location or link a spot before submitting.';

  @override
  String addEventMaxPhotos(int count) {
    return 'At most $count photos allowed.';
  }

  @override
  String get addEventUploadPhotosFailed =>
      'Could not upload photos. Please try again.';

  @override
  String get addEventSubmitFailed => 'Could not submit event proposal.';

  @override
  String get addEventSubmitSuccess => 'Event submitted to the moderator queue.';

  @override
  String get noImagesYet => 'No images yet';

  @override
  String get spotCardNoDescription => 'No description yet';

  @override
  String get spotCardPartOfPrefix => 'Part of ';

  @override
  String get spotCardRemoveFromListTooltip => 'Remove from list';

  @override
  String get spotCardCopiedToClipboard => 'Spot copied to clipboard!';

  @override
  String spotCardShareFailed(String error) {
    return 'Failed to share spot: $error';
  }

  @override
  String get spotCardRemovedFromSource => 'Removed from source';

  @override
  String get spotCheckInUnnamedPerson => 'This person';

  @override
  String spotCheckInTooltipPublic(String name, String time) {
    return '$name is here now until $time';
  }

  @override
  String spotCheckInTooltipPrivate(String time) {
    return 'You\'re here now until $time — only you can see this check-in';
  }

  @override
  String spotTrainingPlanTooltipPublic(String name, String timeRange) {
    return '$name plans to train here $timeRange';
  }

  @override
  String spotTrainingPlanTooltipPrivate(String timeRange) {
    return 'You plan to train here $timeRange — only you can see this plan';
  }

  @override
  String spotTrainingPlanTooltipPublicUntil(String name, String untilTime) {
    return '$name plans to train here until $untilTime';
  }

  @override
  String spotTrainingPlanTooltipPrivateUntil(String untilTime) {
    return 'You plan to train here until $untilTime — only you can see this plan';
  }

  @override
  String get spotDetailRouteErrorLoading => 'Error loading spot';

  @override
  String get spotDetailRouteTryAgainLater => 'Please try again later';

  @override
  String get spotDetailRouteNotFound => 'Spot not found';

  @override
  String get spotDetailRouteGoToExplore => 'Go to Explore';

  @override
  String get spotDetailCheckInVerifyFailed => 'Could not verify your check-ins';

  @override
  String get spotDetailCheckInEndPreviousFailed =>
      'Could not end your previous check-in';

  @override
  String get spotDetailCheckInSuccess => 'You’re checked in';

  @override
  String get spotDetailCheckInFailed => 'Check-in failed';

  @override
  String get spotDetailCheckInRemoved => 'Check-in removed';

  @override
  String get spotDetailCheckInDeleteFailed => 'Could not delete check-in';

  @override
  String get spotDetailCheckInUpdated => 'Check-in updated';

  @override
  String get spotDetailCheckInUpdateFailed => 'Could not update check-in';

  @override
  String get spotDetailCheckInFabTooltipSignIn => 'Sign in to check in';

  @override
  String get spotDetailCheckInFabTooltipEdit => 'Edit check-in';

  @override
  String get spotDetailCheckInFabTooltipCheckIn => 'Check in';

  @override
  String spotDetailSpotCreatedOnDateBy(String date) {
    return 'Spot created $date by ';
  }

  @override
  String get spotDetailSpotCreatedBy => 'Spot created by ';

  @override
  String get spotDetailUnknownSource => 'Unknown Source';

  @override
  String spotDetailSpotImportedOnDateFrom(String date) {
    return 'Spot imported $date from ';
  }

  @override
  String get spotDetailSpotImportedFrom => 'Spot imported from ';

  @override
  String get spotDetailFromFolder => ' from the folder ';

  @override
  String get spotDetailImprovedByAfterComma => ', improved by ';

  @override
  String get spotDetailImprovedByAfterAnd => ' and improved by ';

  @override
  String get spotDetailUnknownUser => 'Unknown';

  @override
  String get spotDetailListJoinAnd => ' and ';

  @override
  String get spotDetailListJoinComma => ', ';

  @override
  String spotDetailLastUpdatedAfterCommaAnd(String date) {
    return ', and last updated $date.';
  }

  @override
  String spotDetailLastUpdatedAfterAnd(String date) {
    return ' and last updated $date.';
  }

  @override
  String get spotDetailDateToday => 'today';

  @override
  String get spotDetailDateYesterday => 'yesterday';

  @override
  String get communityDateTomorrow => 'tomorrow';

  @override
  String communityActivityTrainSameDay(
    String startTime,
    String endTime,
    String day,
  ) {
    return 'From $startTime until $endTime $day';
  }

  @override
  String communityActivityTrainSpan(
    String startTime,
    String startDay,
    String endTime,
    String endDay,
  ) {
    return 'From $startTime $startDay until $endTime $endDay';
  }

  @override
  String get communityShareSpotFallbackName => 'this spot';

  @override
  String communityShareCheckInNarrative(String spotName, String untilPhrase) {
    return 'I\'m now training at $spotName until about $untilPhrase';
  }

  @override
  String communityShareTrainingPlanNarrative(
    String spotName,
    String relativeDay,
    String startTime,
  ) {
    return 'I\'m planning to train at $spotName $relativeDay from $startTime';
  }

  @override
  String get communityActivityShareCopiedToClipboard =>
      'Message copied to clipboard!';

  @override
  String communityActivityShareFailed(String error) {
    return 'Failed to share: $error';
  }

  @override
  String spotDetailDateDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String spotDetailCopySpotFailed(String error) {
    return 'Failed to copy spot: $error';
  }

  @override
  String get spotDetailAddressCopiedToClipboard =>
      'Address copied to clipboard!';

  @override
  String spotDetailCopyAddressFailed(String error) {
    return 'Failed to copy address: $error';
  }

  @override
  String spotDetailOpenMapsFailed(String error) {
    return 'Could not open maps app: $error';
  }

  @override
  String get spotDetailMoreActionsTooltip => 'More actions';

  @override
  String get spotDetailMenuLogin => 'Login';

  @override
  String get spotDetailMenuLoginSubtitle => 'Sign in to continue';

  @override
  String get spotDetailMenuFlagDuplicate => 'Flag as duplicate';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleYes =>
      'This spot is a duplicate';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleNo =>
      'Already marked as duplicate';

  @override
  String get spotDetailMenuSuggestPhoto => 'Suggest photo';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleYes =>
      'Submit photos for this spot';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleNo =>
      'Cannot suggest photos for duplicates';

  @override
  String get spotDetailMenuSuggestEdit => 'Suggest an edit';

  @override
  String get spotDetailMenuSuggestEditSubtitleYes =>
      'Propose changes to this spot';

  @override
  String get spotDetailMenuSuggestEditSubtitleNo =>
      'Cannot suggest edits for duplicates';

  @override
  String get spotDetailMenuReportSpot => 'Report spot';

  @override
  String get spotDetailMenuReportSpotSubtitle => 'Help us review this spot';

  @override
  String get spotDetailMenuEditSpot => 'Edit spot';

  @override
  String get spotDetailMenuEditSpotSubtitleNative => 'Create native spot first';

  @override
  String get spotDetailMenuEditSpotSubtitleMod => 'Moderator only';

  @override
  String get spotDetailMenuMarkDuplicate => 'Mark as duplicate';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleDup =>
      'Already marked as duplicate';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleMod => 'Moderator only';

  @override
  String get spotDetailMenuRemoveDuplicateStatus => 'Remove duplicate';

  @override
  String get spotDetailMenuRemoveDuplicateSubtitle =>
      'Restore original listing';

  @override
  String get spotDetailMenuCreateNative => 'Create native spot';

  @override
  String get spotDetailMenuCreateNativeSubtitle => 'Copy from external source';

  @override
  String get spotDetailMenuCreateEvent => 'Create event';

  @override
  String get spotDetailMenuCreateEventSubtitle => 'At this spot';

  @override
  String get spotDetailMenuHideSpot => 'Hide spot';

  @override
  String get spotDetailMenuHideSpotSubtitle => 'Hide from public view';

  @override
  String get spotDetailMenuUnhideSpot => 'Unhide spot';

  @override
  String get spotDetailMenuUnhideSpotSubtitle => 'Show in app again';

  @override
  String get spotDetailMenuDeleteSpot => 'Delete spot';

  @override
  String get spotDetailMenuDeleteSubtitleAdmin => 'Admin only';

  @override
  String get spotDetailMenuTriggerResize => 'Trigger image resize';

  @override
  String get spotDetailMenuTriggerResizeSubtitle =>
      'Re-create resized versions';

  @override
  String get spotDetailMenuImageUrls => 'Image URLs overview';

  @override
  String get spotDetailMenuImageUrlsSubtitle =>
      'Original, resized, and API URLs';

  @override
  String adminImageUrlsDialogTitle(String entityLabel) {
    return 'Image URLs — $entityLabel';
  }

  @override
  String get adminImageUrlsEmpty => 'No images to show.';

  @override
  String adminImageUrlsImageIndex(int index, int total) {
    return 'Image $index of $total';
  }

  @override
  String get adminImageUrlsLabelFirestore => 'Firestore (original)';

  @override
  String get adminImageUrlsLabel1200x1200 => 'Expected 1200×1200';

  @override
  String get adminImageUrlsLabel1200x630 => 'Expected 1200×630';

  @override
  String get adminImageUrlsLabelActualDownload => 'Actual resized download URL';

  @override
  String get adminImageUrlsLabelSpotsApi => 'Spots API URL';

  @override
  String get adminImageUrlsStatusExists => 'Exists';

  @override
  String get adminImageUrlsStatusMissing => 'Missing';

  @override
  String get adminImageUrlsStatusNotApplicable =>
      'Not a resizable Firebase Storage image.';

  @override
  String get adminImageUrlsPreviewOriginal => 'Original';

  @override
  String get adminImageUrlsPreview1200 => '1200×1200';

  @override
  String get adminImageUrlsPreview630 => '1200×630';

  @override
  String get adminImageUrlsCopyRow => 'Copy URL';

  @override
  String get adminImageUrlsCopyAll => 'Copy all';

  @override
  String get adminImageUrlsCopiedToClipboard => 'Copied to clipboard';

  @override
  String get adminImageUrlsApiFootnote =>
      'The spots API returns the Spots API URL even when the resized file is missing; clients may get a 404 until resize completes.';

  @override
  String get adminImageUrlsEventApiFootnote =>
      'There is no events API. The Spots API URL row shows the same 1200×1200 transform used for spot imageUrls.';

  @override
  String get spotDetailExternalSourceCannotEdit =>
      'Spots from external sources cannot be edited. Please create a native spot first using “Mark as Duplicate” → “Create Native Spot”.';

  @override
  String get spotDetailOk => 'OK';

  @override
  String get spotDetailUnableEditNow => 'Unable to edit this spot right now.';

  @override
  String get spotDetailOnlyAdminsDelete =>
      'Only administrators can delete spots.';

  @override
  String get spotDetailResizeAllHaveVersions =>
      'All images already have resized versions';

  @override
  String spotDetailResizeSummary(
    int triggered,
    int verified,
    String failedPart,
  ) {
    return 'Resize: $triggered triggered, $verified verified$failedPart';
  }

  @override
  String spotDetailResizeFailedPart(int failed) {
    return ', $failed failed';
  }

  @override
  String spotDetailResizeTriggerFailed(String error) {
    return 'Failed to trigger resize: $error';
  }

  @override
  String get spotDetailUnableFlagDuplicate =>
      'Unable to flag this spot as duplicate right now.';

  @override
  String get spotDetailThanksDuplicateReport =>
      'Thanks! Your duplicate report has been submitted.';

  @override
  String get spotDetailUnableSuggestPhotos =>
      'Unable to suggest photos for this spot right now.';

  @override
  String get spotDetailCannotSuggestPhotosDuplicate =>
      'Cannot suggest photos for duplicate spots.';

  @override
  String get spotDetailThanksPhotoSuggestion =>
      'Thanks! Your photo suggestion has been submitted for review.';

  @override
  String get spotDetailUnableSuggestEdits =>
      'Unable to suggest edits for this spot right now.';

  @override
  String get spotDetailCannotSuggestEditsDuplicate =>
      'Cannot suggest edits for duplicate spots.';

  @override
  String get spotDetailThanksEditSuggestion =>
      'Thanks! Your edit suggestion has been submitted for review.';

  @override
  String get spotDetailUnableReportNow =>
      'Unable to report this spot right now.';

  @override
  String get spotDetailThanksReportSubmitted =>
      'Thanks! Your report has been submitted.';

  @override
  String get spotDetailUnableAddToList =>
      'Unable to add this spot to a list right now.';

  @override
  String get spotDetailNoSpotListsAccess =>
      'You do not have access to spot lists.';

  @override
  String get spotDetailListCreatedAndAdded => 'List created and spot added!';

  @override
  String get spotDetailSpotAddedToList => 'Spot added to list!';

  @override
  String get spotDetailEditReportTooltip => 'Edit & report';

  @override
  String get spotDetailShareTooltip => 'Share';

  @override
  String get spotDetailQuickActionSave => 'Save';

  @override
  String get spotDetailQuickActionEdit => 'Edit';

  @override
  String get spotDetailQuickActionShare => 'Share';

  @override
  String get spotDetailQuickActionRate => 'Rate';

  @override
  String get spotDetailRatingTooltip => 'Community rating and your stars';

  @override
  String get spotDetailPresenceHereNow => 'Here now';

  @override
  String get spotDetailCommunitySectionTitle => 'Community';

  @override
  String get spotDetailCommunitySectionSubtitle =>
      'See who’s training or planning to be here, and share your session.';

  @override
  String get spotDetailCommunityNobodyHere =>
      'No one’s checked in yet. Check in to let others know you’re here.';

  @override
  String get spotDetailCommunityNobodyHereShort => 'No one’s here yet.';

  @override
  String get spotDetailCommunityNobodySocialShort =>
      'No one’s here or planning ahead yet.';

  @override
  String get spotDetailCommunityActivityLoadError =>
      'Could not load community activity.';

  @override
  String get spotDetailCommunityActivityEmpty => 'Nothing to show right now.';

  @override
  String get spotDetailCommunityViewAll => 'View all';

  @override
  String get spotDetailCommunityCheckInButton => 'Check in';

  @override
  String get spotDetailCommunityEditCheckInButton => 'Edit check-in';

  @override
  String get spotDetailCommunitySignInToCheckInButton => 'Sign in to check in';

  @override
  String get spotDetailCommunityPlanningVisitButton => 'Plan to train';

  @override
  String get spotDetailCommunityPlanningVisitTooltip =>
      'Set when you’ll train here.';

  @override
  String get spotDetailCommunityCheckInButtonTooltip =>
      'Show others you’re here now.';

  @override
  String get spotDetailCommunityEditCheckInButtonTooltip =>
      'Update your check-in.';

  @override
  String get spotDetailCommunitySignInToCheckInButtonTooltip =>
      'Sign in to check in here.';

  @override
  String get spotDetailCommunityPlanningToTrain => 'Planning to train';

  @override
  String get spotDetailCommunityNobodyPlanningShort => 'No upcoming plans yet.';

  @override
  String get spotDetailCommunitySignInToPlanButton => 'Sign in to plan a visit';

  @override
  String get spotDetailCommunityEditTrainingPlanButton => 'Edit plan';

  @override
  String get spotCheckInDialogTitle => 'Check in';

  @override
  String get spotCheckInDialogTitleEdit => 'Edit check-in';

  @override
  String get spotCheckInDialogIntroNew =>
      'Let others know you’re training here and roughly when you’ll finish. If you share publicly, you show on this spot’s Community strip until that time.';

  @override
  String get spotCheckInDialogIntroEdit =>
      'Change your arrival and end times, who can see this check-in, and your note.';

  @override
  String get spotCheckInDialogSharePublic => 'Share publicly';

  @override
  String get spotCheckInDialogShareSub =>
      'Turn off to keep this check-in visible only to you.';

  @override
  String get spotCheckInDialogLabelArrived => 'Arrived';

  @override
  String get spotCheckInDialogLabelHereUntil => 'Here until';

  @override
  String get spotCheckInDialogLabelUntil => 'Until';

  @override
  String get spotCheckInDialogStillHere => 'Still here';

  @override
  String get spotCheckInDialogEndNow => 'End now';

  @override
  String get spotCheckInDialogCancel => 'Cancel';

  @override
  String get spotCheckInDialogSave => 'Save';

  @override
  String get spotCheckInDialogDelete => 'Delete';

  @override
  String get spotCheckInDialogConfirmDeleteTitle => 'Delete check-in?';

  @override
  String get spotCheckInDialogConfirmDeleteBody =>
      'Deletes this visit from your history. It doesn’t remove the spot from your Been to list.';

  @override
  String get spotCheckInDialogExtendBannerText =>
      'You have a recently expired check-in here.';

  @override
  String get spotCheckInDialogExtendInstead => 'Extend that check-in instead';

  @override
  String spotCheckInDialogActiveElsewhereAtNamed(String spotName) {
    return 'You’re currently checked in at $spotName. Checking in here will end that check-in.';
  }

  @override
  String get spotCheckInDialogActiveElsewhereUnnamed =>
      'You’re checked in at another spot. Checking in here will end that check-in.';

  @override
  String get spotCheckInDialogActiveElsewhereMultiple =>
      'You have active check-ins at other spots. Checking in here will end those check-ins.';

  @override
  String get spotCheckInDialogNudgeEarlier => '15 minutes earlier';

  @override
  String get spotCheckInDialogNudgeLater => '15 minutes later';

  @override
  String get spotCheckInDialogTrainingPlanConversionBanner =>
      'Saving replaces your plan with this check-in. Your planned end time is pre-filled below.';

  @override
  String get spotDetailSessionNoteLabel => 'Note (optional)';

  @override
  String get spotDetailSessionNoteHint =>
      'e.g. skills or drills you’re working on';

  @override
  String get spotTrainingPlanDialogTitle => 'Plan to train here';

  @override
  String get spotTrainingPlanDialogTitleEdit => 'Edit training plan';

  @override
  String get spotTrainingPlanDialogCheckInCtaBody =>
      'Here now? Check in so others know you’ve arrived.';

  @override
  String get spotTrainingPlanDialogCheckInCtaBodyEarly =>
      'Here already? Check in so others know you’ve arrived.';

  @override
  String get spotTrainingPlanDialogCheckInCtaButton => 'Check in';

  @override
  String get spotTrainingPlanDialogBody =>
      'Set when you plan to start and finish. Public plans appear on this spot’s Community strip alongside other people who’ve shared.';

  @override
  String get spotTrainingPlanDialogSharePublic => 'Share publicly';

  @override
  String get spotTrainingPlanDialogShareSub =>
      'Turn off to keep this plan visible only to you.';

  @override
  String get spotTrainingPlanDialogStartLabel => 'Starts';

  @override
  String get spotTrainingPlanDialogEndLabel => 'Ends';

  @override
  String get spotTrainingPlanDialogSave => 'Save';

  @override
  String get spotTrainingPlanDialogCancel => 'Cancel';

  @override
  String get spotTrainingPlanDialogDelete => 'Remove plan';

  @override
  String get spotTrainingPlanDialogDeleteTitle => 'Remove this plan?';

  @override
  String get spotTrainingPlanDialogDeleteBody =>
      'You can create a new plan anytime.';

  @override
  String get spotTrainingPlanValidationOrder =>
      'End time must be after start time.';

  @override
  String get spotTrainingPlanValidationMinDuration =>
      'Window must be at least 15 minutes.';

  @override
  String get spotTrainingPlanValidationMaxDuration =>
      'Window cannot be longer than 12 hours.';

  @override
  String get spotTrainingPlanValidationStartTooFar =>
      'Start time cannot be more than 30 days away.';

  @override
  String get spotTrainingPlanValidationEndNotFuture =>
      'End time must be in the future.';

  @override
  String get spotTrainingPlanValidationInvalid => 'Invalid time range.';

  @override
  String get spotDetailTrainingPlanSaved => 'Training plan saved';

  @override
  String get spotDetailTrainingPlanUpdated => 'Training plan updated';

  @override
  String get spotDetailTrainingPlanFailed => 'Could not save training plan';

  @override
  String get spotDetailTrainingPlanRemoved => 'Training plan removed';

  @override
  String get spotDetailTrainingPlanDeleteFailed =>
      'Could not remove training plan';

  @override
  String get spotTrainingPlanListDialogTitle => 'Planning to train';

  @override
  String get spotTrainingPlanListDialogSubtitle =>
      'People who shared a public plan for this spot.';

  @override
  String get spotTrainingPlanListDialogClose => 'Close';

  @override
  String get spotTrainingPlanListEmpty => 'No public plans yet.';

  @override
  String get spotTrainingPlanListLoadError => 'Could not load training plans';

  @override
  String get spotTrainingPlanEditMine => 'Edit plan';

  @override
  String get spotTrainingPlanJoin => 'Join';

  @override
  String get spotTrainingPlanOnlyYou => 'Only you';

  @override
  String get spotTrainingPlanUnnamedPerson => 'Someone';

  @override
  String spotTrainingPlanTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get spotDetailHiddenBanner =>
      'This spot is hidden from public view. It likely no longer exists or doesn’t meet our policies. It will not appear in search results or on the map.';

  @override
  String spotDetailSourceRemovedBanner(String source) {
    return 'This spot is no longer listed in $source. Details might be outdated, so double-check before visiting.';
  }

  @override
  String get spotDetailSourceRemovedUnknownSource => 'its original source';

  @override
  String get spotDetailSectionFeatures => 'Features';

  @override
  String get spotDetailSectionAccess => 'Access';

  @override
  String get spotDetailSectionFacilities => 'Facilities';

  @override
  String spotDetailJumpflixFetchFailed(String error) {
    return 'Jumpflix fetch failed: $error';
  }

  @override
  String get spotDetailBrandYoutube => 'YouTube';

  @override
  String get spotDetailBrandJumpflix => 'Jumpflix';

  @override
  String get spotDetailBrandAsSeenIn => 'As seen in';

  @override
  String get spotDetailLoading => 'Loading...';

  @override
  String get spotDetailLoadingYourRating => 'Loading your rating...';

  @override
  String get spotDetailRateThisSpot => 'Rate this spot';

  @override
  String get spotDetailHeaderNoRatingsYet => 'No ratings yet';

  @override
  String get spotDetailCouldNotLoadProfile => 'Couldn’t load your profile.';

  @override
  String get spotDetailRefreshPageToRate => 'Please refresh the page to rate.';

  @override
  String get spotDetailSignInToRateTitle => 'Sign in to rate this spot';

  @override
  String get spotDetailSignInToRateSubtitle =>
      'Sign in to rate this spot and help other parkour enthusiasts.';

  @override
  String get spotDetailSignInButton => 'Sign In';

  @override
  String get spotDetailCreateAccountButton => 'Create an Account';

  @override
  String get spotDetailMapSwitchToMap => 'Switch to Map';

  @override
  String get spotDetailMapSwitchToSatellite => 'Switch to Satellite';

  @override
  String get spotDetailMapLocateOnMap => 'Locate on map';

  @override
  String get spotDetailDuplicateOf => 'Duplicate of';

  @override
  String get spotDetailOriginalSpotFallback => 'Original spot';

  @override
  String get spotDetailAlsoBasedOn => 'Also based on';

  @override
  String spotDetailGalleryPageIndicator(int current, int total) {
    return '$current / $total';
  }

  @override
  String get spotDetailSaveMenuTooltip => 'Save spot';

  @override
  String get spotDetailSaveMenuSignInTitle => 'Sign in to save spots';

  @override
  String get spotDetailSaveMenuSignInBody =>
      'Add this spot to Want to visit, Been here, or your own lists. Log in or create a free account to get started.';

  @override
  String get spotDetailSaveMenuLogInOrCreate => 'Log in or create account';

  @override
  String get spotDetailSaveTooltipUpdating => 'Updating…';

  @override
  String get spotDetailSaveTooltipWantToVisit => 'Saved: Want to visit';

  @override
  String get spotDetailSaveTooltipBeenHere => 'Saved: Been here';

  @override
  String get spotDetailSaveTooltipGeneric => 'Save spot';

  @override
  String get spotDetailRemovedFromWantToVisit => 'Removed from Want to visit';

  @override
  String get spotDetailFailedToRemove => 'Failed to remove';

  @override
  String get spotDetailAddedToWantToVisit => 'Added to Want to visit';

  @override
  String get spotDetailFailedToAdd => 'Failed to add';

  @override
  String get spotDetailRemovedFromBeenHere => 'Removed from Been here';

  @override
  String get spotDetailAddedToBeenHere => 'Added to Been here';

  @override
  String get spotDetailWantToVisit => 'Want to visit';

  @override
  String get spotDetailBeenHere => 'Been here';

  @override
  String get spotDetailViewFullListTooltip => 'View full list';

  @override
  String get spotDetailAddToCustomList => 'Add to custom list';

  @override
  String get spotDetailAddToCustomListSubtitle => 'Choose or create a list';

  @override
  String get spotDetailListNameEmpty => 'List name cannot be empty';

  @override
  String get spotDetailFailedAddToListGeneric => 'Failed to add spot to list';

  @override
  String get spotDetailFailedCreateList => 'Failed to create list';

  @override
  String get spotDetailFailedAddToSomeLists =>
      'Failed to add spot to some lists';

  @override
  String spotDetailAddToListTitle(String name) {
    return 'Add to $name';
  }

  @override
  String get spotDetailSelectSections => 'Select sections:';

  @override
  String spotDetailSectionEntryCount(int count) {
    return 'Section ($count spots)';
  }

  @override
  String get spotDetailAddToNewSection => 'Add to new section';

  @override
  String get spotDetailSectionNameOptional => 'Section name (optional)';

  @override
  String get spotDetailNoteOptional => 'Note (optional)';

  @override
  String get spotDetailSkip => 'Skip';

  @override
  String get spotDetailAdd => 'Add';

  @override
  String get spotDetailAddToListDialogTitle => 'Add to List';

  @override
  String get spotDetailAlreadyInLists => 'Already in these lists:';

  @override
  String get spotDetailNoListsYet =>
      'You don’t have any lists yet. Create one to get started!';

  @override
  String get spotDetailSelectListsPrompt => 'Select lists to add this spot to:';

  @override
  String get spotDetailCreateNewList => 'Create New List';

  @override
  String get spotDetailListNameLabel => 'List Name';

  @override
  String get spotDetailListNameHint => 'e.g., My Favorite Spots';

  @override
  String get spotDetailListDescriptionLabel => 'Description (optional)';

  @override
  String get spotDetailListDescriptionHint => 'Add a description for this list';

  @override
  String get spotDetailVisibilityLabel => 'Visibility';

  @override
  String get spotDetailCreateAndAdd => 'Create & Add';

  @override
  String get spotDetailReportDuplicateTitle => 'Report duplicate spot';

  @override
  String get spotDetailReportDuplicateIntro =>
      'Please select the spot this is a duplicate of.';

  @override
  String get spotDetailEmailInvalid => 'Enter a valid email address.';

  @override
  String get spotDetailEmailRequired => 'Please provide an email address.';

  @override
  String get spotDetailSubmitReport => 'Submit report';

  @override
  String get spotDetailReportThisSpotTitle => 'Report this spot';

  @override
  String spotDetailReportIntro(String name) {
    return 'Let us know what is wrong with $name. Moderators will review your report shortly.';
  }

  @override
  String get spotDetailReportWhatWrong => 'What is happening?';

  @override
  String get spotDetailReportCategoryLabel => 'Select a category';

  @override
  String get spotDetailReportCategoryHint => 'Choose a report category';

  @override
  String get spotDetailReportDescribeIssue => 'Describe the issue';

  @override
  String get spotDetailReportDescribeIssueHint =>
      'Tell us what does not match reality';

  @override
  String get spotDetailReportAdditionalDetails => 'Additional details';

  @override
  String get spotDetailReportAdditionalDetailsHint =>
      'Anything else we should know?';

  @override
  String get spotDetailReportEmailLabel => 'Email address';

  @override
  String get spotDetailReportEmailHelper =>
      'We will contact you only about this report.';

  @override
  String spotDetailReportReachOutAt(String email) {
    return 'We will reach out at $email if we need more info.';
  }

  @override
  String get spotDetailReportReachOutAccount =>
      'We will reach out using your account email if we need more info.';

  @override
  String get spotDetailReportCategoryOtherDescribe =>
      'Please describe the issue when selecting Other.';

  @override
  String get spotDetailReportCategoryRequired => 'Please select a category.';

  @override
  String get spotDetailReportSendFailed =>
      'Could not send your report. Please try again.';

  @override
  String get spotDetailReportCategoryClosed => 'Spot closed or removed';

  @override
  String get spotDetailReportCategoryInaccurate =>
      'Location or details seem wrong';

  @override
  String get spotDetailReportCategoryUnsafe => 'Unsafe conditions';

  @override
  String get spotDetailReportCategoryNotASpot => 'Not a spot';

  @override
  String get spotDetailReportCategoryOther => 'Other';

  @override
  String get spotDetailReportCategoryClosedDesc =>
      'The spot has been permanently closed, demolished, or removed and is no longer accessible. Please provide more details below.';

  @override
  String get spotDetailReportCategoryInaccurateDesc =>
      'Something about this spot looks wrong: the pin, name, description, or address may be incorrect. Use this when you are not sure what the correct information should be. Describe what seems off below. If you know what to change, use Suggest an edit from the spot menu instead.';

  @override
  String get spotDetailReportCategoryUnsafeDesc =>
      'The spot has become dangerous due to structural issues, environmental hazards, or other safety concerns. Please provide more details below on what is unsafe.';

  @override
  String get spotDetailReportCategoryNotASpotDesc =>
      'Only for objective issues like spam, spots in invalid locations (e.g., middle of the sea), private residences, entire cities, or other clearly invalid entries. For subjective opinions about spot quality, please use a rating instead. Please provide more details below on why this is not a spot.';

  @override
  String get spotDetailReportCategoryOtherDesc =>
      'Any other issue not covered by the categories above. Please describe the issue in the field below.';

  @override
  String get spotDetailMarkDuplicateTitle => 'Mark as Duplicate';

  @override
  String get spotDetailMarkDuplicateBody =>
      'Are you sure you want to mark this spot as a duplicate? This action can be reversed later.';

  @override
  String get spotDetailMarkDuplicateAddToOriginal =>
      'Select which items to add to the original spot:';

  @override
  String get spotDetailMarkDuplicatePhotos => 'Photos';

  @override
  String get spotDetailMarkDuplicateYoutube => 'YouTube links';

  @override
  String get spotDetailMarkDuplicateOverwrite =>
      'Select which items to overwrite in the original spot (if set):';

  @override
  String get spotDetailMarkDuplicateName => 'Name';

  @override
  String get spotDetailMarkDuplicateDescription => 'Description';

  @override
  String get spotDetailMarkDuplicateLocation => 'Location';

  @override
  String get spotDetailMarkDuplicateSpotAttributes => 'Spot attributes';

  @override
  String get spotDetailConfirm => 'Confirm';

  @override
  String get spotDetailPickImagesFailed =>
      'Failed to pick images. Please try again.';

  @override
  String get spotDetailSelectAtLeastOnePhoto =>
      'Please select at least one photo';

  @override
  String get spotDetailSuggestPhotosTitle => 'Suggest Photos';

  @override
  String get spotDetailSuggestPhotosIntro =>
      'Submit photos to be added to this spot. Photos will be reviewed by moderators before being added.';

  @override
  String get spotDetailSelectPhotos => 'Select Photos';

  @override
  String get spotDetailPickPhotos => 'Pick Photos';

  @override
  String get spotDetailAdditionalDetailsOptional =>
      'Additional Details (Optional)';

  @override
  String get spotDetailAdditionalDetailsHint =>
      'Add any additional information about these photos...';

  @override
  String get spotDetailSuggestPhotosEmailHelper =>
      'We will contact you only about this suggestion.';

  @override
  String get spotDetailSuggestPhotosSubmitFailed =>
      'Failed to submit photo suggestion. Please try again.';

  @override
  String spotDetailSuggestPhotosSubmitError(String error) {
    return 'Error submitting photo suggestion: $error';
  }

  @override
  String get spotDetailSuggestEditTitle => 'Suggest an Edit';

  @override
  String get spotDetailSuggestEditIntro =>
      'Propose changes to this spot. Moderators will review your suggestions.';

  @override
  String get spotDetailSuggestEditSuggestChange =>
      'Please suggest at least one change.';

  @override
  String get spotDetailSuggestEditSubmitFailed =>
      'Failed to submit edit suggestion. Please try again.';

  @override
  String spotDetailSuggestEditSubmitError(String error) {
    return 'Error submitting edit suggestion: $error';
  }

  @override
  String get spotDetailGeocoding => 'Geocoding...';

  @override
  String get spotDetailChangeLocationPicked => 'Change location (picked)';

  @override
  String get spotDetailPickLocationOnMap => 'Pick different location on map';

  @override
  String get spotDetailFieldTitle => 'Title';

  @override
  String get spotDetailFieldTitleHint => 'Spot title';

  @override
  String get spotDetailFieldDescription => 'Description';

  @override
  String get spotDetailFieldDescriptionHint => 'Spot description';

  @override
  String get spotDetailFieldSpotAttributes => 'Spot attributes';

  @override
  String get spotDetailSuggestEditEmailHelper =>
      'We will contact you only about this suggestion.';

  @override
  String get spotDetailMustBeLoggedInToRate =>
      'You must be logged in to rate spots';

  @override
  String spotDetailRatingSubmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rating $count stars submitted!',
      one: 'Rating 1 star submitted!',
    );
    return '$_temp0';
  }

  @override
  String get spotDetailRatingSubmitFailed =>
      'Failed to submit rating. Please try again.';

  @override
  String spotDetailRatingSubmitError(String error) {
    return 'Error submitting rating: $error';
  }

  @override
  String get spotDetailNotExternalSource =>
      'This spot is not from an external source.';

  @override
  String get spotDetailMustBeLoggedInCreateNative =>
      'You must be logged in to create a native spot.';

  @override
  String get spotDetailCreateNativeDialogTitle => 'Create Native Spot';

  @override
  String get spotDetailCreateNativeDialogBody =>
      'This will create a new native spot based on this spot and mark the current spot as a duplicate of it. All spot data (name, description, location, photos, YouTube links, and attributes) will be copied to the new native spot.\n\nNote: Admins can remove spots and duplicate links can be removed if needed.';

  @override
  String get spotDetailCreateButton => 'Create';

  @override
  String get spotDetailUnableCreateNativeNow =>
      'Unable to create native spot right now.';

  @override
  String get spotDetailFailedCreateNativeSpot => 'Failed to create native spot';

  @override
  String get spotDetailNativeCreatedDuplicateMarked =>
      'Native spot created and current spot marked as duplicate.';

  @override
  String get spotDetailFailedMarkDuplicateGeneric =>
      'Failed to mark spot as duplicate';

  @override
  String spotDetailErrorCreatingNativeSpot(String error) {
    return 'Error creating native spot: $error';
  }

  @override
  String get spotDetailUnableMarkDuplicateNow =>
      'Unable to mark this spot as duplicate right now.';

  @override
  String get spotDetailAlreadyMarkedDuplicate =>
      'This spot is already marked as a duplicate.';

  @override
  String get spotDetailSpotMarkedDuplicateSuccess =>
      'Spot marked as duplicate.';

  @override
  String spotDetailErrorMarkingDuplicateSpot(String error) {
    return 'Error marking spot as duplicate: $error';
  }

  @override
  String get spotDetailModeratorsOnlyHideUnhide =>
      'Only moderators can hide/unhide spots.';

  @override
  String get spotDetailHideSpotTitle => 'Hide Spot';

  @override
  String get spotDetailUnhideSpotTitle => 'Unhide Spot';

  @override
  String get spotDetailHideSpotMessage =>
      'This will hide the spot from public view. Hidden spots will not appear in search results or on the map, but the spot data will be preserved and can be unhidden later.';

  @override
  String get spotDetailUnhideSpotMessage =>
      'This will restore the spot to public view. The spot will appear in search results and on the map again.';

  @override
  String get spotDetailActionHide => 'Hide';

  @override
  String get spotDetailActionUnhide => 'Unhide';

  @override
  String get spotDetailUnableHideUnhideNow =>
      'Unable to hide/unhide this spot right now.';

  @override
  String get spotDetailSpotHiddenSuccess => 'Spot hidden successfully.';

  @override
  String get spotDetailSpotUnhiddenSuccess => 'Spot unhidden successfully.';

  @override
  String get spotDetailFailedHideSpot => 'Failed to hide spot';

  @override
  String get spotDetailFailedUnhideSpot => 'Failed to unhide spot';

  @override
  String spotDetailErrorHidingSpot(String error) {
    return 'Error hiding spot: $error';
  }

  @override
  String spotDetailErrorUnhidingSpot(String error) {
    return 'Error unhiding spot: $error';
  }

  @override
  String get spotDetailNotMarkedAsDuplicate =>
      'This spot is not marked as a duplicate.';

  @override
  String get spotDetailModeratorsOnlyRemoveDuplicateStatus =>
      'Only moderators can remove duplicate status.';

  @override
  String get spotDetailRemoveDuplicateDialogBody =>
      'This will remove the duplicate status from this spot. The spot will no longer be marked as a duplicate.\n\nDo you want to continue?';

  @override
  String get spotDetailRemoveButton => 'Remove';

  @override
  String get spotDetailUnableRemoveDuplicateStatusNow =>
      'Unable to remove duplicate status right now.';

  @override
  String get spotDetailDuplicateStatusRemovedSuccess =>
      'Duplicate status removed successfully.';

  @override
  String get spotDetailFailedRemoveDuplicateStatusGeneric =>
      'Failed to remove duplicate status';

  @override
  String spotDetailErrorRemovingDuplicateStatus(String error) {
    return 'Error removing duplicate status: $error';
  }

  @override
  String get spotDetailCheckingLinkedData => 'Checking linked data...';

  @override
  String get spotDetailDeleteSpotDialogTitle => 'Delete Spot';

  @override
  String get spotDetailDeleteSpotConfirmMessage =>
      'Are you sure you want to delete this spot? This action cannot be undone.';

  @override
  String get spotDetailLinkedDataHeading => 'This spot has linked data:';

  @override
  String spotDetailLinkedRatingsLine(int count) {
    return '• Ratings: $count';
  }

  @override
  String spotDetailLinkedReportsLine(int count) {
    return '• Spot reports: $count';
  }

  @override
  String spotDetailLinkedDuplicatesLine(int count) {
    return '• Duplicate spots: $count';
  }

  @override
  String get spotDetailResolveLinksBeforeDelete =>
      'Please resolve these links before deleting the spot.';

  @override
  String get spotDetailSpotDeletedSuccess => 'Spot deleted successfully';

  @override
  String get spotDetailFailedDeleteSpot => 'Failed to delete spot';

  @override
  String spotDetailErrorDeletingSpot(String error) {
    return 'Error deleting spot: $error';
  }

  @override
  String get spotDetailFlagDuplicateDialogTitle => 'Flag as duplicate';

  @override
  String get spotDetailFlagDuplicateIntro =>
      'This spot appears to be a duplicate of another spot. Please select the original spot below.';

  @override
  String get spotDetailFlagDuplicateWhichQuestion =>
      'Which spot is this a duplicate of?';

  @override
  String get spotDetailDuplicateSearchHint => 'Paste spot URL or enter spot ID';

  @override
  String get spotDetailSearch => 'Search';

  @override
  String get spotDetailNearbySpotsWithin50m => 'Nearby spots (within ~50m)';

  @override
  String get spotDetailFoundSpot => 'Found Spot';

  @override
  String spotDetailSpotIdLabel(String id) {
    return 'Spot ID: $id';
  }

  @override
  String get spotDetailRemoveSelectionTooltip => 'Remove selection';

  @override
  String get spotDetailImageFailedToLoad => 'Image failed to load';

  @override
  String get spotDetailClose => 'Close';

  @override
  String spotDetailExpandMoreCount(int count) {
    return '$count more';
  }

  @override
  String get spotDetailSubmit => 'Submit';

  @override
  String get spotDetailDuplicateReportSelectRequired =>
      'Please select the spot this is a duplicate of.';

  @override
  String get spotDetailDuplicateSearchEmpty => 'Please enter a spot ID or URL';

  @override
  String get spotDetailDuplicateInvalidUrl => 'Invalid spot ID or URL format';

  @override
  String get spotDetailDuplicateCannotSelectSelf =>
      'Cannot mark a spot as duplicate of itself';

  @override
  String get spotDetailDuplicateSpotNotFound => 'Spot not found';

  @override
  String spotDetailDuplicateFailedLoadSpot(String error) {
    return 'Failed to load spot: $error';
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
  String get eventSourceDetailsLoadingSource => 'Loading event source...';

  @override
  String get eventSourceDetailsTotalEvents => 'Total Events';

  @override
  String exploreEventCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

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
  String get detailExternalLinkCaption => 'More information';

  @override
  String detailExternalLinkOpenSemantics(String host) {
    return 'Open $host';
  }

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
  String detailUpcomingEventLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Upcoming events',
      one: 'Upcoming event',
    );
    return '$_temp0';
  }

  @override
  String detailUpcomingEventsAndMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more events',
      one: '1 more event',
    );
    return '$_temp0';
  }

  @override
  String get detailUpcomingEventsSheetTitle => 'Upcoming events';

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
  String get publicProfileMyCheckIns => 'My training activity';

  @override
  String get publicProfileMyCheckInsSubtitle =>
      'Upcoming training plans and your check-in history';

  @override
  String get myCheckInsSignInPrompt =>
      'Sign in to view your check-ins and training plans';

  @override
  String get myCheckInsLoadMore => 'Load more';

  @override
  String get myCheckInsEmptyTitle => 'No visits or plans yet';

  @override
  String get myCheckInsEmptyDescription =>
      'Open a spot to check in or plan training. Until the end time you set, others can see you as “here now” on that spot unless you keep it private.';

  @override
  String get myCheckInsIntro =>
      'Training plans list upcoming sessions you scheduled at spots. A check-in records a visit—when you arrived and until when you expect to leave. Public entries can show you on a spot until the end time you set; private ones stay visible only to you.';

  @override
  String get myCheckInsUpcomingPlansTitle => 'Upcoming training';

  @override
  String get myCheckInsPastCheckInsTitle => 'Check-ins';

  @override
  String get myCheckInsNoCheckInsYet => 'No check-ins recorded yet.';

  @override
  String get myCheckInsCheckInsLoadFailed => 'Could not load check-ins.';

  @override
  String get myCheckInsSpotFallback => 'Spot';

  @override
  String get myCheckInsPrivateOnlyYou => 'Private — only you can see this';

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

  @override
  String get eventDetailRouteErrorLoading => 'Error loading event';

  @override
  String get eventDetailRouteTryAgainLater => 'Please try again later';

  @override
  String get eventDetailRouteNotFound => 'Event not found';

  @override
  String get eventDetailRouteGoToExplore => 'Go to Explore';

  @override
  String get eventDetailStartsLabel => 'Starts';

  @override
  String get eventDetailEndsLabel => 'Ends';

  @override
  String get eventDetailLocationLabel => 'Location';

  @override
  String get eventDetailOpenInMaps => 'Open in maps';

  @override
  String get eventDetailLinkedSpotsLabel => 'Linked spots';

  @override
  String get eventDetailNoLinkedSpots => 'No linked spots found.';

  @override
  String get eventDetailLinkedSpotListsLabel => 'Linked spot lists';

  @override
  String get eventDetailNoLinkedSpotLists => 'No linked spot lists found.';

  @override
  String get eventDetailEventSpotsLabel => 'Spots for this event';

  @override
  String get eventDetailNoEventSpots => 'Event spot list not found.';

  @override
  String get eventDetailEventSpotListViewAll => 'View spot list';

  @override
  String get eventDetailEventSpotListSeeOnMap => 'See on map';

  @override
  String eventDetailEventSpotListMoreSpots(int count) {
    return '+ $count more';
  }

  @override
  String get eventDetailEventSpotLocationsLabel => 'Event locations';

  @override
  String get eventDetailNoEventSpotLocations => 'Event spots not found.';

  @override
  String get eventDetailEventSpotViewDetails => 'View spot';

  @override
  String get adminEventEditTitle => 'Edit event';

  @override
  String get adminEventEditSave => 'Save changes';

  @override
  String get adminEventExternalSyncWarningTitle => 'External calendar event';

  @override
  String get adminEventExternalSyncWarningBody =>
      'The next sync may overwrite the title, schedule, description, and venue address or coordinates from the external feed. Linked spots and spot lists are managed here and are not cleared by sync.';

  @override
  String get adminEventLinkedSpotListsTitle => 'Linked spot lists';

  @override
  String get adminEventAddSpotList => 'Add list';

  @override
  String get adminEventNoLinkedSpotLists => 'No spot lists selected yet';

  @override
  String get adminSpotListSelectionTitle => 'Select spot list';

  @override
  String get adminSpotListSelectionInputLabel => 'List ID or URL';

  @override
  String get adminSpotListSelectionInputHint =>
      'list-id or https://parkour.spot/list/…';

  @override
  String get adminSpotListSelectionLookup => 'Look up';

  @override
  String get adminSpotListSelectionSelect => 'Select';

  @override
  String get adminSpotListSelectionInvalidInput =>
      'Enter a list ID or a /list/… URL';

  @override
  String get adminSpotListSelectionNotFound =>
      'Spot list not found or not accessible';

  @override
  String get adminSpotListSelectionPrivateList =>
      'Private lists cannot be linked to events';

  @override
  String get adminSpotListSelectionLoadFailed => 'Could not load the spot list';

  @override
  String adminSpotListSelectionFoundSubtitle(String visibility, int count) {
    return '$visibility · $count spots';
  }

  @override
  String get eventDetailAdminEditEvent => 'Edit event';

  @override
  String get eventDetailMenuEditEventSubtitleNative =>
      'Create native event first';

  @override
  String get eventDetailMenuEditEventSubtitleMod => 'Moderator only';

  @override
  String get eventDetailExternalSourceCannotEdit =>
      'Events from external sources cannot be edited. Please create a native event first using “Mark as Duplicate” → “Create native event”.';

  @override
  String get eventDetailSourceLabel => 'Source';

  @override
  String get eventDetailAdminMenuTooltip => 'Admin';

  @override
  String get eventDetailStaffMenuTooltip => 'Staff';

  @override
  String get eventDetailMenuCreateNative => 'Create native event';

  @override
  String get eventDetailMenuCreateNativeSubtitle => 'Copy from external source';

  @override
  String get eventDetailMenuSuggestPhotoSubtitleYes =>
      'Submit photos for this event';

  @override
  String get eventDetailMenuSuggestPhotoSubtitleNo =>
      'Not available for duplicates';

  @override
  String get eventDetailMenuSuggestEditSubtitleYes =>
      'Propose changes to this event';

  @override
  String get eventDetailMenuSuggestEditSubtitleNo =>
      'Not available for duplicates';

  @override
  String get eventDetailMenuSuggestBlockedUnavailable =>
      'Unavailable right now';

  @override
  String get eventDetailCreateNativeDialogTitle => 'Create native event';

  @override
  String get eventDetailCreateNativeDialogBody =>
      'This will create a new native event based on this event and mark the current event as a duplicate of it. Event data (title, description, schedule, location, images, website, and linked spots) will be copied to the new native event.';

  @override
  String get eventDetailNotExternalSource =>
      'This event is not from an external source.';

  @override
  String get eventDetailMustBeLoggedInCreateNative =>
      'You must be logged in to create a native event.';

  @override
  String get eventDetailUnableCreateNativeNow =>
      'Unable to create native event right now.';

  @override
  String get eventDetailFailedCreateNative => 'Failed to create native event';

  @override
  String get eventDetailNativeCreatedDuplicateMarked =>
      'Native event created and current event marked as duplicate.';

  @override
  String get eventDetailMarkDuplicateNativeOnlyHint =>
      'Only native events can be selected. If you need to create a native event from an external source event, use \"Create native event\" from the event menu.';

  @override
  String eventDetailEventCreatedOnDateBy(String date) {
    return 'Event created $date by ';
  }

  @override
  String get eventDetailEventCreatedBy => 'Event created by ';

  @override
  String eventDetailEventCreatedOnDate(String date) {
    return 'Event created $date';
  }

  @override
  String eventDetailEventImportedOnDateFrom(String date) {
    return 'Event imported $date from ';
  }

  @override
  String get eventDetailEventImportedFrom => 'Event imported from ';

  @override
  String get eventDetailOriginalEventFallback => 'Original event';

  @override
  String get eventDetailDuplicateBannerTitle => 'Duplicate listing';

  @override
  String get eventDetailDuplicateBannerBody =>
      'This listing is marked as a duplicate. Open the main event for the canonical details.';

  @override
  String get eventDetailLinkedDuplicatesHeading => 'Duplicate listings';

  @override
  String get eventDetailMarkDuplicateStaffOnly =>
      'Only staff can manage event duplicates.';

  @override
  String get eventDetailMenuHideEvent => 'Hide event';

  @override
  String get eventDetailMenuHideEventSubtitle => 'Hide from public view';

  @override
  String get eventDetailMenuUnhideEvent => 'Unhide event';

  @override
  String get eventDetailMenuUnhideEventSubtitle => 'Show to public again';

  @override
  String get eventDetailHiddenBanner =>
      'This event is hidden from public view. It likely no longer exists or doesn’t meet our policies. It will not appear in search results or on the map.';

  @override
  String get eventDetailModeratorsOnlyHideUnhide =>
      'Only moderators can hide/unhide events.';

  @override
  String get eventDetailHideEventTitle => 'Hide Event';

  @override
  String get eventDetailUnhideEventTitle => 'Unhide Event';

  @override
  String get eventDetailHideEventMessage =>
      'This will hide the event from public view. Hidden events will not appear in search results or on the map, but the event data will be preserved and can be unhidden later.';

  @override
  String get eventDetailUnhideEventMessage =>
      'This will restore the event to public view. The event will appear in search results and on the map again.';

  @override
  String get eventDetailUnableHideUnhideNow =>
      'Unable to hide/unhide this event right now.';

  @override
  String get eventDetailEventHiddenSuccess => 'Event hidden successfully.';

  @override
  String get eventDetailEventUnhiddenSuccess => 'Event unhidden successfully.';

  @override
  String get eventDetailFailedHideEvent => 'Failed to hide event';

  @override
  String get eventDetailFailedUnhideEvent => 'Failed to unhide event';

  @override
  String get eventDetailMarkDuplicatePickNativeTitle =>
      'Mark as duplicate of native event';

  @override
  String get eventDetailMarkDuplicateSearchHint => 'Event name, URL, or ID';

  @override
  String get eventDetailMarkDuplicateNotFoundOrInvalid =>
      'Pick a matching event from the list, or enter a valid event id or /event/… link.';

  @override
  String get eventDetailMarkDuplicateTargetNotNative =>
      'That event is not a native parkour.spot event. Only native events can be the original.';

  @override
  String get eventDetailMarkDuplicateTargetIsDuplicate =>
      'That event is already marked as a duplicate of another event.';

  @override
  String get eventDetailMarkDuplicateUseButton => 'Use this event';

  @override
  String get eventDetailMarkDuplicateSuggestionsHeader =>
      'Native events around these dates';

  @override
  String get eventDetailMarkDuplicateNoSuggestions =>
      'No native events found within a week of this event\'s dates.';

  @override
  String eventDetailMarkDuplicateConfirmBody(String title) {
    return 'Mark this event as a duplicate of “$title”?';
  }

  @override
  String get eventDetailMarkDuplicateTitle => 'Mark as Duplicate';

  @override
  String eventDetailMarkDuplicateBody(String title) {
    return 'Mark this event as a duplicate of “$title”? This action can be reversed later.';
  }

  @override
  String get eventDetailMarkDuplicateAddToOriginal =>
      'Select which items to add to the original event:';

  @override
  String get eventDetailMarkDuplicatePhotos => 'Photos';

  @override
  String get eventDetailMarkDuplicateLinkedSpots => 'Linked spots';

  @override
  String get eventDetailMarkDuplicateOverwrite =>
      'Select which items to overwrite in the original event (if set):';

  @override
  String get eventDetailMarkDuplicateEventTitle => 'Title';

  @override
  String get eventDetailMarkDuplicateDescription => 'Description';

  @override
  String get eventDetailMarkDuplicateLocation => 'Location';

  @override
  String get eventDetailMarkDuplicateSchedule => 'Schedule';

  @override
  String get eventDetailMarkDuplicateWebsite => 'Website';

  @override
  String get eventDetailMarkDuplicateSuccess => 'Event marked as duplicate.';

  @override
  String get eventDetailRemoveDuplicateConfirmBody =>
      'Remove duplicate status from this event? It will no longer point to another event as its original.';

  @override
  String get eventDetailRemoveDuplicateSuccess => 'Duplicate status removed.';

  @override
  String get eventDetailCopiedToClipboard => 'Event copied to clipboard!';

  @override
  String eventDetailShareFailed(String error) {
    return 'Failed to share event: $error';
  }

  @override
  String get eventDetailQuickActionSuggestPhoto => 'Suggest photo';

  @override
  String get eventDetailQuickActionSuggestEdit => 'Suggest an edit';

  @override
  String get eventDetailUnableSuggestNow =>
      'Unable to suggest changes for this event right now.';

  @override
  String get eventDetailCannotSuggestForDuplicate =>
      'Cannot suggest changes for duplicate events.';

  @override
  String get eventDetailCannotSuggestForExternal =>
      'Cannot suggest changes for externally sourced events. Create a native event first.';

  @override
  String get eventDetailThanksPhotoSuggestion =>
      'Thanks! Your photo suggestion has been submitted for review.';

  @override
  String get eventDetailThanksEditSuggestion =>
      'Thanks! Your edit suggestion has been submitted for review.';

  @override
  String get eventDetailMenuFlagDuplicate => 'Flag as duplicate';

  @override
  String get eventDetailMenuFlagDuplicateSubtitleYes =>
      'This event is a duplicate';

  @override
  String get eventDetailMenuFlagDuplicateSubtitleNo =>
      'Already marked as duplicate';

  @override
  String get eventDetailFlagDuplicateDialogTitle => 'Flag as duplicate';

  @override
  String get eventDetailFlagDuplicateIntro =>
      'This event appears to be a duplicate of another event. Select the original event below.';

  @override
  String get eventDetailFlagDuplicateWhichQuestion =>
      'Which event is this a duplicate of?';

  @override
  String get eventDetailFlagDuplicateSuggestionsHeader =>
      'Events around these dates';

  @override
  String get eventDetailThanksDuplicateSuggestion =>
      'Thanks! Your duplicate suggestion has been submitted for review.';

  @override
  String get eventDetailUnableFlagDuplicate =>
      'Unable to flag this event as duplicate right now.';

  @override
  String get eventDetailDuplicateReportSelectRequired =>
      'Please select the original event.';

  @override
  String get eventReportQueueDuplicateSuggestion => 'Duplicate suggestion';

  @override
  String get eventReportQueueApproveDuplicate => 'Approve duplicate link';

  @override
  String get eventReportQueueOpenOriginalEvent =>
      'Open suggested original event';

  @override
  String get eventDuplicateApprovalExternalOriginalHint =>
      'The user suggested an event from an external source. Pick the native parkour.spot event that should be the canonical original.';

  @override
  String get eventDuplicateApprovalPickNativeTitle =>
      'Pick the native event to use as the canonical original.';

  @override
  String get eventDetailSuggestPhotosTitle => 'Suggest photos';

  @override
  String get eventDetailSuggestPhotosIntro =>
      'Upload photos for this event. Moderators will review your suggestion.';

  @override
  String get eventDetailSuggestPhotosPickRequired =>
      'Please add at least one photo.';

  @override
  String get eventDetailSuggestPhotosSubmitFailed =>
      'Failed to submit photo suggestion. Please try again.';

  @override
  String eventDetailSuggestPhotosSubmitError(String error) {
    return 'Error submitting photo suggestion: $error';
  }

  @override
  String get eventDetailSuggestEditTitle => 'Suggest an edit';

  @override
  String get eventDetailSuggestEditIntro =>
      'Propose updates to this event. Moderators will review your suggestion.';

  @override
  String get eventDetailSuggestEditNoChanges =>
      'Please suggest at least one change.';

  @override
  String get eventDetailSuggestEditSubmitFailed =>
      'Failed to submit edit suggestion. Please try again.';

  @override
  String eventDetailSuggestEditSubmitError(String error) {
    return 'Error submitting edit suggestion: $error';
  }

  @override
  String get eventSuggestionApprovalTitle => 'Review event suggestion';

  @override
  String get eventSuggestionCannotApproveExternalTitle =>
      'Cannot approve suggestion';

  @override
  String eventSuggestionCannotApproveExternalBody(String sourceName) {
    return 'The selected event is from an external source ($sourceName). Suggestions can only be approved for native events.\n\nTo approve this suggestion, first create a native event from the event details menu.';
  }

  @override
  String get eventSuggestionCannotApproveDuplicateTitle =>
      'Cannot approve suggestion';

  @override
  String get eventSuggestionCannotApproveDuplicateBody =>
      'The selected event is a duplicate of another event. Suggestions can only be approved for the native original event.\n\nPlease select the original event below.';

  @override
  String get eventSuggestionTargetEventLabel => 'Target event';

  @override
  String eventSuggestionCurrentEventLabel(String title) {
    return 'Reported event: $title';
  }

  @override
  String eventSuggestionOriginalEventLabel(String title) {
    return 'Original event: $title';
  }

  @override
  String eventSuggestionReportedEventDuplicateSubtitle(String title) {
    return 'The reported event (duplicate of $title)';
  }

  @override
  String eventSuggestionReportedEventExternalSubtitle(String sourceName) {
    return 'The reported event (from $sourceName)';
  }

  @override
  String get eventSuggestionReportedEventSubtitle => 'The reported event';

  @override
  String eventSuggestionOriginalEventExternalSubtitle(String sourceName) {
    return 'The original event (from $sourceName)';
  }

  @override
  String get eventSuggestionOriginalEventRecommendedSubtitle =>
      'The original event (recommended)';

  @override
  String get eventSuggestionModeratorNotesLabel => 'Comment (optional)';

  @override
  String get eventSuggestionModeratorNotesHint =>
      'Document why you approved or rejected this suggestion...';

  @override
  String get eventSuggestionApproveButton => 'Approve suggestion';

  @override
  String get eventSuggestionApprovalFailed =>
      'Could not approve this event suggestion.';

  @override
  String eventSuggestionApprovalSuccess(String eventId) {
    return 'Approved and applied to event $eventId.';
  }

  @override
  String get eventSuggestionChangedFieldsTitle => 'Suggested changes';

  @override
  String get eventSuggestionLocationRemoved => 'Remove location';

  @override
  String eventSuggestionLinkedSpotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linked spots',
      one: '1 linked spot',
      zero: 'No linked spots',
    );
    return '$_temp0';
  }
}
