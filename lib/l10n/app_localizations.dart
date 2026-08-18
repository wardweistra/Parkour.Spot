import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
    Locale('nl'),
    Locale('pt'),
  ];

  /// Bottom navigation: map and search tab
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get tabExplore;

  /// Bottom navigation: add spot or event
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get tabAdd;

  /// Bottom navigation: profile and settings
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tabAccount;

  /// Profile: settings card title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettingsTitle;

  /// Account tab: settings cover language and locations of interest
  ///
  /// In en, this message translates to:
  /// **'Language and locations you care about'**
  String get profileSettingsSubtitle;

  /// Profile settings: language row label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileSettingsLanguageLabel;

  /// Profile settings: short hint for language control
  ///
  /// In en, this message translates to:
  /// **'Choose a language or follow your device settings.'**
  String get profileSettingsLanguageDescription;

  /// Use OS/browser locale resolution instead of a fixed app language
  ///
  /// In en, this message translates to:
  /// **'Automatic (English if unsupported)'**
  String get profileLanguageSystemDefault;

  /// Account tab: shown when profile could not be loaded
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile.'**
  String get profileLoadErrorDefault;

  /// Account tab error: reload on web
  ///
  /// In en, this message translates to:
  /// **'Refresh page'**
  String get profileRefreshPage;

  /// Account tab error: retry loading profile on native
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get profileRetry;

  /// Account tab signed-out: card heading
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your account'**
  String get profileSignInTitle;

  /// Account tab signed-out: supporting text
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your spots and rate locations.'**
  String get profileSignInSubtitle;

  /// Account tab: primary sign-in button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get profileSignInButton;

  /// Account tab: divider between sign-in and sign-up
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get profileOrDivider;

  /// Account tab: secondary sign-up button
  ///
  /// In en, this message translates to:
  /// **'Create an Account'**
  String get profileCreateAccount;

  /// Fallback display name when missing
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileDefaultDisplayName;

  /// Account card subtitle linking to full profile
  ///
  /// In en, this message translates to:
  /// **'View and edit your profile'**
  String get profileViewEditSubtitle;

  /// Notifications inbox screen title and Account tab row
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Account tab: hint that notifications reflect nearby map/community activity
  ///
  /// In en, this message translates to:
  /// **'New spots nearby, training plans, check-ins, and other updates for you'**
  String get notificationsSubtitle;

  /// Notifications inbox empty state heading
  ///
  /// In en, this message translates to:
  /// **'All quiet for now'**
  String get notificationsEmptyTitle;

  /// Notifications inbox empty state supporting text
  ///
  /// In en, this message translates to:
  /// **'When someone adds a spot nearby, plans training where you train, or checks in nearby, it’ll show up here.'**
  String get notificationsEmptyBody;

  /// Notifications inbox error message
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load your notifications. Check your connection and try again.'**
  String get notificationsLoadError;

  /// Notifications inbox: retry after load error
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get notificationsRetry;

  /// Shown when a notification row has no valid link target
  ///
  /// In en, this message translates to:
  /// **'This notification couldn’t be opened. Please try again later.'**
  String get notificationsOpenFailedSnackbar;

  /// App bar: mark every notification read
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// Snack bar when batch mark-as-read fails
  ///
  /// In en, this message translates to:
  /// **'Couldn’t mark all as read. Try again.'**
  String get notificationsMarkAllReadFailed;

  /// Snack bar when single mark-as-read fails
  ///
  /// In en, this message translates to:
  /// **'Couldn’t mark as read. Try again.'**
  String get notificationsMarkAsReadFailed;

  /// Snack bar when mark-as-unread fails
  ///
  /// In en, this message translates to:
  /// **'Couldn’t mark as unread. Try again.'**
  String get notificationsMarkAsUnreadFailed;

  /// Semantics hint on read notification rows
  ///
  /// In en, this message translates to:
  /// **'Long-press to mark as unread'**
  String get notificationsMarkAsUnreadHint;

  /// Semantics hint on unread notification rows
  ///
  /// In en, this message translates to:
  /// **'Long-press to mark as read'**
  String get notificationsMarkAsReadHint;

  /// Tooltip: disable unread-only filter
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get notificationsShowAll;

  /// Tooltip: show only unread notifications
  ///
  /// In en, this message translates to:
  /// **'Unread only'**
  String get notificationsUnreadOnly;

  /// Empty state when unread filter is on but there are no unread items
  ///
  /// In en, this message translates to:
  /// **'You’re all caught up'**
  String get notificationsEmptyFilteredTitle;

  /// Supporting text for filtered empty inbox
  ///
  /// In en, this message translates to:
  /// **'No unread notifications right now.'**
  String get notificationsEmptyFilteredBody;

  /// Fallback timestamp when createdAt is missing
  ///
  /// In en, this message translates to:
  /// **'Recently'**
  String get notificationsTimeUnknown;

  /// Accessibility label for a notification list row
  ///
  /// In en, this message translates to:
  /// **'Open notification: {title}'**
  String notificationsOpenSemantic(String title);

  /// Fallback when a notification has no person display name
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get notificationsActorSomeone;

  /// Fallback spot name in notifications when the spot title is empty
  ///
  /// In en, this message translates to:
  /// **'Untitled spot'**
  String get notificationsSpotUntitled;

  /// In-app notification title when a new spot was added near a saved location
  ///
  /// In en, this message translates to:
  /// **'New spot nearby: {spotName}'**
  String notificationNearbyNewSpotTitle(String spotName);

  /// In-app notification body for nearby new spot
  ///
  /// In en, this message translates to:
  /// **'{actorName} added a new parkour spot near one of your saved locations.'**
  String notificationNearbyNewSpotBody(String actorName);

  /// In-app notification title when someone checked in at a spot nearby
  ///
  /// In en, this message translates to:
  /// **'{actorName} is training now at {spotName}'**
  String notificationNearbyCheckInTitle(String actorName, String spotName);

  /// In-app notification body for nearby public check-in (actor is in the title)
  ///
  /// In en, this message translates to:
  /// **'They’ve just checked in to this spot.'**
  String get notificationNearbyCheckInBody;

  /// In-app notification title when someone created a public training plan at a spot nearby
  ///
  /// In en, this message translates to:
  /// **'{actorName} planned training at {spotName}'**
  String notificationNearbyTrainingPlanTitle(String actorName, String spotName);

  /// In-app notification body for nearby public training plan (names are in the title)
  ///
  /// In en, this message translates to:
  /// **'They shared a public training window near one of your saved locations.'**
  String get notificationNearbyTrainingPlanBody;

  /// In-app notification when the user's planned training window has started but they have not checked in
  ///
  /// In en, this message translates to:
  /// **'Time to check in at {spotName}'**
  String notificationTrainingPlanCheckInReminderTitle(String spotName);

  /// In-app notification body for training plan check-in reminder
  ///
  /// In en, this message translates to:
  /// **'Your planned session has started. Tap to check in.'**
  String get notificationTrainingPlanCheckInReminderBody;

  /// Account tab: moderator section heading
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get profileModeratorSectionTitle;

  /// Account tab: moderator tools row title
  ///
  /// In en, this message translates to:
  /// **'Moderator Tools'**
  String get profileModeratorToolsTitle;

  /// Account tab: moderator tools row subtitle
  ///
  /// In en, this message translates to:
  /// **'Review and resolve incoming spot reports'**
  String get profileModeratorToolsSubtitle;

  /// Account tab: admin section heading
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get profileAdminSectionTitle;

  /// Account tab: admin tools row title
  ///
  /// In en, this message translates to:
  /// **'Admin Tools'**
  String get profileAdminToolsTitle;

  /// Account tab: admin tools row subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage sources and administrative tasks'**
  String get profileAdminToolsSubtitle;

  /// Account tab: sign out button and dialog action
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// Account tab: sign out confirmation body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get profileSignOutMessage;

  /// Dismiss dialog without action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel;

  /// Account settings: location alerts section title
  ///
  /// In en, this message translates to:
  /// **'Location alerts'**
  String get profileLocationAlertsTitle;

  /// Account settings: notification settings section title
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get profileNotificationSettingsTitle;

  /// Account settings: toggle title for browser-specific push subscription
  ///
  /// In en, this message translates to:
  /// **'Push notifications on this browser/device'**
  String get profilePushNotificationsThisDeviceTitle;

  /// Account settings: status text when push API/FCM is unavailable
  ///
  /// In en, this message translates to:
  /// **'Push notifications are not supported on this browser.'**
  String get profilePushNotificationsUnsupported;

  /// Account settings: temporary status while push subscription state is loading
  ///
  /// In en, this message translates to:
  /// **'Checking push notification status for this device...'**
  String get profilePushNotificationsLoading;

  /// Account settings: status text when browser notification permission is denied
  ///
  /// In en, this message translates to:
  /// **'Push permission is blocked in your browser settings for this site.'**
  String get profilePushNotificationsPermissionDenied;

  /// Account settings: status text before permission has been requested
  ///
  /// In en, this message translates to:
  /// **'Turn this on to ask for permission and subscribe this browser.'**
  String get profilePushNotificationsPermissionNotDetermined;

  /// Account settings: status text when current device is subscribed
  ///
  /// In en, this message translates to:
  /// **'This browser is subscribed and can receive push alerts.'**
  String get profilePushNotificationsEnabled;

  /// Account settings: status text when permission is granted but no active token/subscription
  ///
  /// In en, this message translates to:
  /// **'Permission is granted, but this browser is currently unsubscribed.'**
  String get profilePushNotificationsPermissionGrantedButOff;

  /// Account settings: fallback status text for unknown permission/subscription state
  ///
  /// In en, this message translates to:
  /// **'Push status is currently unavailable. Try again shortly.'**
  String get profilePushNotificationsUnknown;

  /// Account settings: generic error shown under push subscription toggle
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t update push notifications on this browser. Please try again.'**
  String get profilePushNotificationsError;

  /// Account settings: location alerts section description
  ///
  /// In en, this message translates to:
  /// **'Control which locations are used for nearby alerts, including check-ins, new spots, training plans, and future events.'**
  String get profileLocationAlertsDescription;

  /// Account settings: toggle title for using last known location in alerts
  ///
  /// In en, this message translates to:
  /// **'Use last known location'**
  String get profileLocationAlertsShareLastKnownTitle;

  /// Account settings: toggle subtitle for using last known location in alerts
  ///
  /// In en, this message translates to:
  /// **'Store your device\'s last known location in the cloud to match nearby alerts.'**
  String get profileLocationAlertsShareLastKnownSubtitle;

  /// Account settings: toggle for in-app notifications when a new spot is added near an enabled location of interest
  ///
  /// In en, this message translates to:
  /// **'Notify me about new spots nearby'**
  String get profileLocationAlertsNotifyNewSpotsTitle;

  /// Account settings: explains new spot notification opt-in and range
  ///
  /// In en, this message translates to:
  /// **'Get an in-app notification when someone adds a spot within about 5 km of an active saved place or your last known location.'**
  String get profileLocationAlertsNotifyNewSpotsSubtitle;

  /// Account settings: toggle for in-app notifications when someone checks in near an enabled location of interest
  ///
  /// In en, this message translates to:
  /// **'Notify me about nearby check-ins'**
  String get profileLocationAlertsNotifyNearbyCheckInsTitle;

  /// Account settings: explains nearby check-in notification opt-in and range
  ///
  /// In en, this message translates to:
  /// **'Get an in-app notification when someone checks in at a spot within about 5 km of an active saved place or your last known location.'**
  String get profileLocationAlertsNotifyNearbyCheckInsSubtitle;

  /// Account settings: toggle for in-app notifications when someone creates a public training plan near an enabled location of interest
  ///
  /// In en, this message translates to:
  /// **'Notify me about nearby training plans'**
  String get profileLocationAlertsNotifyTrainingPlansTitle;

  /// Account settings: explains nearby training-plan notification opt-in and range
  ///
  /// In en, this message translates to:
  /// **'Get an in-app notification when someone shares a public training plan at a spot within about 5 km of an active saved place or your last known location.'**
  String get profileLocationAlertsNotifyTrainingPlansSubtitle;

  /// Account settings: toggle for reminders when a planned training window starts
  ///
  /// In en, this message translates to:
  /// **'Remind me to check in for planned sessions'**
  String get profileTrainingPlanCheckInReminderTitle;

  /// Account settings: explains training plan check-in reminder opt-in
  ///
  /// In en, this message translates to:
  /// **'Get an in-app reminder when your planned session has started and you haven’t checked in at that spot yet.'**
  String get profileTrainingPlanCheckInReminderSubtitle;

  /// Account settings: saved locations subsection title
  ///
  /// In en, this message translates to:
  /// **'Locations of interest'**
  String get profileLocationAlertsSavedLocationsTitle;

  /// Account settings: button label for adding a saved location
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get profileLocationAlertsAddLocationButton;

  /// Account settings: shown when last-known is off and no saved locations are enabled for alerts
  ///
  /// In en, this message translates to:
  /// **'You won’t receive any location-based notifications until you turn on “Use last known location” or enable at least one saved place.'**
  String get profileLocationAlertsNoLocationsEnabledWarning;

  /// Account settings: empty state text when no saved locations exist
  ///
  /// In en, this message translates to:
  /// **'No saved locations yet. Add places like Home or Work.'**
  String get profileLocationAlertsEmptyState;

  /// Account settings: fallback label for saved location items
  ///
  /// In en, this message translates to:
  /// **'Saved location'**
  String get profileLocationAlertsDefaultLabel;

  /// Account settings: tooltip for disabling saved location alerts
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get profileLocationAlertsDisableTooltip;

  /// Account settings: tooltip for enabling saved location alerts
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get profileLocationAlertsEnableTooltip;

  /// Account settings: tooltip for editing a saved location
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileLocationAlertsEditTooltip;

  /// Account settings: tooltip for deleting a saved location
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileLocationAlertsDeleteTooltip;

  /// Account settings: confirmation dialog title before deleting a saved location
  ///
  /// In en, this message translates to:
  /// **'Delete saved location?'**
  String get profileLocationAlertsDeleteTitle;

  /// Account settings: confirmation dialog body before deleting a saved location
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {label}?'**
  String profileLocationAlertsDeleteMessage(String label);

  /// Account settings: confirmation button label for deleting a saved location
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileLocationAlertsDeleteConfirmButton;

  /// Account settings: dialog title for adding a saved location
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get profileLocationAlertsDialogAddTitle;

  /// Account settings: dialog title for editing a saved location
  ///
  /// In en, this message translates to:
  /// **'Edit location'**
  String get profileLocationAlertsDialogEditTitle;

  /// Account settings: label field label in saved location dialog
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get profileLocationAlertsLabelFieldLabel;

  /// Account settings: label field placeholder in saved location dialog
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get profileLocationAlertsLabelFieldPlaceholder;

  /// Account settings: enabled toggle label in saved location dialog
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get profileLocationAlertsEnabledLabel;

  /// Account settings: validation error when label is missing
  ///
  /// In en, this message translates to:
  /// **'Please enter a label'**
  String get profileLocationAlertsLabelRequired;

  /// Account settings: validation error when no location is selected
  ///
  /// In en, this message translates to:
  /// **'Please pick a location on the map'**
  String get profileLocationAlertsLocationRequired;

  /// About section: short intro paragraph
  ///
  /// In en, this message translates to:
  /// **'Parkour·Spot is a community-driven app for discovering and sharing parkour and freerunning spots worldwide. We\'re making it simple to find quality locations—wherever you train.'**
  String get profileAboutIntro;

  /// About section: expand long text
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get profileReadMore;

  /// About expanded: text before founder name link (keep trailing space)
  ///
  /// In en, this message translates to:
  /// **'Started by '**
  String get profileAboutStoryBeforeName;

  /// About expanded: story after founder name
  ///
  /// In en, this message translates to:
  /// **' from the Utrecht parkour community, the app brings together local knowledge from existing city and regional maps—whether they lived on Facebook, Instagram, websites, or retired apps—so great spot data doesn\'t get lost.'**
  String get profileAboutStoryAfterName;

  /// About expanded: community map paragraph
  ///
  /// In en, this message translates to:
  /// **'This is your map. Add new spots, rate existing ones, and enrich listings with details. The more we contribute, the stronger the community\'s shared knowledge becomes.'**
  String get profileAboutMapMission;

  /// About expanded: principles list heading
  ///
  /// In en, this message translates to:
  /// **'Our principles:'**
  String get profileAboutPrinciplesHeader;

  /// About expanded: transparency bullet
  ///
  /// In en, this message translates to:
  /// **'• Transparency: you can browse the app without an account, and each spot shows which external sources contributed to it.'**
  String get profileAboutPrincipleTransparency;

  /// About expanded: portability bullet
  ///
  /// In en, this message translates to:
  /// **'• Portability: we\'re building export tools so spot data can be used beyond the app.'**
  String get profileAboutPrinciplePortability;

  /// About expanded: open source bullet
  ///
  /// In en, this message translates to:
  /// **'• Open source: the app is community-owned, not dependent on one person.'**
  String get profileAboutPrincipleOpenSource;

  /// About expanded: closing encouragement
  ///
  /// In en, this message translates to:
  /// **'Enjoy discovering and sharing spots with Parkour.spot. Questions or ideas? Tap the contact button—we\'d love to hear from you.'**
  String get profileAboutEnjoy;

  /// Credits line before names (keep trailing space)
  ///
  /// In en, this message translates to:
  /// **'Major contributions by '**
  String get profileCreditsBy;

  /// After Daphne's name: role and separator
  ///
  /// In en, this message translates to:
  /// **' (art), '**
  String get profileCreditsDaphneArt;

  /// Separator between contributor names
  ///
  /// In en, this message translates to:
  /// **', '**
  String get profileCreditsComma;

  /// End of credits line
  ///
  /// In en, this message translates to:
  /// **' and many others.'**
  String get profileCreditsEnd;

  /// About section: GitHub button
  ///
  /// In en, this message translates to:
  /// **'View source code'**
  String get profileViewSourceCode;

  /// About section: email button
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get profileContactUs;

  /// About section: GitHub issues button
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get profileReportIssue;

  /// Account tab: PWA install card title
  ///
  /// In en, this message translates to:
  /// **'Install the Parkour·Spot app'**
  String get profileInstallBannerTitle;

  /// Account tab: PWA install card subtitle
  ///
  /// In en, this message translates to:
  /// **'Get the full app experience'**
  String get profileInstallBannerSubtitle;

  /// PWA install instructions dialog title
  ///
  /// In en, this message translates to:
  /// **'Install Parkour·Spot'**
  String get profileInstallDialogTitle;

  /// PWA install dialog: intro before steps
  ///
  /// In en, this message translates to:
  /// **'To install Parkour·Spot on your {device}, open this page in {browser} and follow these steps:'**
  String profileInstallIntro(String device, String browser);

  /// Device name for iOS install instructions
  ///
  /// In en, this message translates to:
  /// **'iPhone'**
  String get profileInstallDeviceIphone;

  /// Device name for Android install instructions
  ///
  /// In en, this message translates to:
  /// **'Android device'**
  String get profileInstallDeviceAndroid;

  /// PWA install iOS step 1
  ///
  /// In en, this message translates to:
  /// **'Tap the Share button at the bottom of the screen'**
  String get profileInstallIosStep1;

  /// PWA install iOS step 2
  ///
  /// In en, this message translates to:
  /// **'Scroll down and tap \"Add to Home Screen\"'**
  String get profileInstallIosStep2;

  /// PWA install iOS step 3
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add\" in the top right corner'**
  String get profileInstallIosStep3;

  /// PWA install iOS step 4
  ///
  /// In en, this message translates to:
  /// **'The app will appear on your home screen!'**
  String get profileInstallIosStep4;

  /// PWA install Android step 1
  ///
  /// In en, this message translates to:
  /// **'Tap the More menu (⋯) in the top right corner'**
  String get profileInstallAndroidStep1;

  /// PWA install Android step 2
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add to home screen\"'**
  String get profileInstallAndroidStep2;

  /// PWA install Android step 3
  ///
  /// In en, this message translates to:
  /// **'Tap \"Install app\"'**
  String get profileInstallAndroidStep3;

  /// PWA install Android step 4
  ///
  /// In en, this message translates to:
  /// **'The app will appear on your home screen!'**
  String get profileInstallAndroidStep4;

  /// Close PWA install instructions dialog
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get profileInstallGotIt;

  /// Web: default document title when leaving a location page
  ///
  /// In en, this message translates to:
  /// **'Parkour·Spot'**
  String get exploreMetaDefaultTitle;

  /// Web: default meta description when leaving a location page
  ///
  /// In en, this message translates to:
  /// **'Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.'**
  String get exploreMetaDefaultDescription;

  /// Web SEO title for city pages
  ///
  /// In en, this message translates to:
  /// **'Best parkour spots in {city}, {country}'**
  String exploreMetaTitleCityCountry(String city, String country);

  /// Web SEO description for city pages
  ///
  /// In en, this message translates to:
  /// **'Discover the best parkour spots in {city}, {country}. Find training locations, share your favorite spots, and connect with the parkour community.'**
  String exploreMetaDescriptionCityCountry(String city, String country);

  /// Web SEO title for country-only pages
  ///
  /// In en, this message translates to:
  /// **'Best parkour spots in {country}'**
  String exploreMetaTitleCountry(String country);

  /// Web SEO description for country-only pages
  ///
  /// In en, this message translates to:
  /// **'Discover the best parkour spots in {country}. Find training locations, share your favorite spots, and connect with the parkour community.'**
  String exploreMetaDescriptionCountry(String country);

  /// Add spot tab: heading when not signed in
  ///
  /// In en, this message translates to:
  /// **'Add New Spot'**
  String get exploreAddSpotTitle;

  /// Add spot tab: supporting text when not signed in
  ///
  /// In en, this message translates to:
  /// **'Share your favorite parkour spots with the community'**
  String get exploreAddSpotSubtitle;

  /// Add tab: sign-in prompt title
  ///
  /// In en, this message translates to:
  /// **'Sign in to add spots and events'**
  String get exploreSignInToAddSpot;

  /// Add tab: sign-in prompt supporting text
  ///
  /// In en, this message translates to:
  /// **'Contribute new spots or submit event proposals for moderator review.'**
  String get exploreSignInToAddSubtitle;

  /// Add tab hub: main heading
  ///
  /// In en, this message translates to:
  /// **'What do you want to add?'**
  String get addHubHeading;

  /// Add tab hub: supporting text
  ///
  /// In en, this message translates to:
  /// **'Share what you know with the community map.'**
  String get addHubSubtitle;

  /// Add tab hub: spot card title
  ///
  /// In en, this message translates to:
  /// **'Add New Spot'**
  String get addHubSpotTitle;

  /// Add tab hub: spot card description
  ///
  /// In en, this message translates to:
  /// **'Drop a pin, add photos, and put a new training spot on the map.'**
  String get addHubSpotDescription;

  /// Add tab hub: spot publish status badge
  ///
  /// In en, this message translates to:
  /// **'Live on the map right away'**
  String get addHubSpotPublishBadge;

  /// Add tab hub: spot card action
  ///
  /// In en, this message translates to:
  /// **'Add New Spot'**
  String get addHubSpotButton;

  /// Add tab hub: event card title
  ///
  /// In en, this message translates to:
  /// **'Add New Event'**
  String get addHubEventTitle;

  /// Add tab hub: event card description
  ///
  /// In en, this message translates to:
  /// **'Propose a jam, meetup, or session for others to find.'**
  String get addHubEventDescription;

  /// Add tab hub: event moderation status badge
  ///
  /// In en, this message translates to:
  /// **'Reviewed by moderators'**
  String get addHubEventModerationBadge;

  /// Add tab hub: event card action
  ///
  /// In en, this message translates to:
  /// **'Add New Event'**
  String get addHubEventButton;

  /// Add tab sign-in callout: heading
  ///
  /// In en, this message translates to:
  /// **'Sign in to contribute'**
  String get addHubSignInTitle;

  /// Add tab sign-in callout: supporting text
  ///
  /// In en, this message translates to:
  /// **'Free account. Add spots to the map or propose events for the community.'**
  String get addHubSignInSubtitle;

  /// Shown while profile loads before add spot
  ///
  /// In en, this message translates to:
  /// **'Loading your profile…'**
  String get exploreLoadingProfile;

  /// Map search field placeholder
  ///
  /// In en, this message translates to:
  /// **'Search location or spot…'**
  String get exploreSearchHint;

  /// Explore entity picker: title when choosing a map location
  ///
  /// In en, this message translates to:
  /// **'Pick location'**
  String get explorePickerTitleLocation;

  /// Explore entity picker: title when choosing a spot
  ///
  /// In en, this message translates to:
  /// **'Choose spot'**
  String get explorePickerTitleSpots;

  /// Explore entity picker: title when choosing an event
  ///
  /// In en, this message translates to:
  /// **'Choose event'**
  String get explorePickerTitleEvents;

  /// Explore entity picker: title when choosing a spot or event
  ///
  /// In en, this message translates to:
  /// **'Choose spot or event'**
  String get explorePickerTitleSpotsAndEvents;

  /// Explore entity picker: title when choosing an event pin or spots
  ///
  /// In en, this message translates to:
  /// **'Choose location or spots'**
  String get explorePickerTitleEventWhere;

  /// Explore entity picker: search placeholder for events mode
  ///
  /// In en, this message translates to:
  /// **'Search location or event…'**
  String get explorePickerSearchHintEvents;

  /// Explore entity picker: search placeholder for location-only mode
  ///
  /// In en, this message translates to:
  /// **'Search location…'**
  String get explorePickerSearchHintLocation;

  /// Explore entity picker: confirm single selection
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get explorePickerConfirmSelect;

  /// Explore entity picker: add to multi selection
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get explorePickerConfirmAdd;

  /// Event where picker: title when a map pin would replace selected spots
  ///
  /// In en, this message translates to:
  /// **'Use this location?'**
  String get explorePickerReplaceSpotsTitle;

  /// Event where picker: explain that confirming a pin drops selected spots
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This replaces the selected spot.} other{This replaces {count} selected spots.}}'**
  String explorePickerReplaceSpotsBody(int count);

  /// Event where picker: cancel replacing selected spots with a pin
  ///
  /// In en, this message translates to:
  /// **'Keep spots'**
  String get explorePickerKeepSpots;

  /// Event where picker: confirm replacing selected spots with a pin
  ///
  /// In en, this message translates to:
  /// **'Use location'**
  String get explorePickerUseLocation;

  /// Event where picker: explain that adding a spot drops the pin
  ///
  /// In en, this message translates to:
  /// **'This replaces the exact location.'**
  String get explorePickerReplaceLocationBody;

  /// Event where picker: cancel replacing a pin with a spot
  ///
  /// In en, this message translates to:
  /// **'Keep location'**
  String get explorePickerKeepLocation;

  /// Event where picker: confirm replacing a pin with a spot
  ///
  /// In en, this message translates to:
  /// **'Add spot'**
  String get explorePickerUseSpotInstead;

  /// Event where picker: short instruction above the map
  ///
  /// In en, this message translates to:
  /// **'Select an exact location, or one or more spots.'**
  String get explorePickerEventWhereHint;

  /// Event where picker: warn that pin or spots replace a linked list
  ///
  /// In en, this message translates to:
  /// **'Choosing a location or spots will replace {name}.'**
  String explorePickerEventWhereReplacesListHint(String name);

  /// Event where picker: summary while a list is linked and nothing else is chosen
  ///
  /// In en, this message translates to:
  /// **'Linked list: {name}'**
  String explorePickerEventWhereListLinked(String name);

  /// Event where picker: summary when neither pin nor spots are chosen
  ///
  /// In en, this message translates to:
  /// **'Nothing selected yet.'**
  String get explorePickerEventWhereNone;

  /// Event where picker: summary when a map pin is chosen
  ///
  /// In en, this message translates to:
  /// **'Exact location set.'**
  String get explorePickerEventWherePin;

  /// Event where picker: summary of selected spots
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{name}} other{{count} spots selected}}'**
  String explorePickerEventWhereSpots(int count, String name);

  /// Multi-spot picker: short instruction above the map
  ///
  /// In en, this message translates to:
  /// **'Tap spots on the map to add them. Confirm when done.'**
  String get explorePickerMultiSpotsHint;

  /// Multi-spot picker: summary of selected spots
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{name}} other{{count} spots selected}}'**
  String explorePickerMultiSpotsSummary(int count, String name);

  /// Event where picker: confirm the current pin or spots
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get explorePickerConfirmDone;

  /// Explore entity picker: entity already in selection
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get explorePickerAlreadyAdded;

  /// Explore entity picker: finish multi selection
  ///
  /// In en, this message translates to:
  /// **'Done ({count})'**
  String explorePickerDone(int count);

  /// Explore entity picker: loading indicator
  ///
  /// In en, this message translates to:
  /// **'Loading map…'**
  String get explorePickerLoading;

  /// Filters: section label above Attributes/Sources tabs
  ///
  /// In en, this message translates to:
  /// **'Filter spots by'**
  String get exploreFilterBy;

  /// Amenity chip: only spots that have at least one photo
  ///
  /// In en, this message translates to:
  /// **'Has photos'**
  String get exploreFilterHasImages;

  /// Filter mode: spot attributes (photos, access, facilities, skills)
  ///
  /// In en, this message translates to:
  /// **'Attributes'**
  String get exploreFilterAmenities;

  /// Filter mode: spot data sources
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get exploreFilterSources;

  /// Filter card: photos
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get exploreSpotPhotosTitle;

  /// Filter card: access
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get exploreSpotAccessTitle;

  /// Filter card: facilities
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get exploreSpotFacilitiesTitle;

  /// Facilities filter: AND match logic
  ///
  /// In en, this message translates to:
  /// **'Must have all selected'**
  String get exploreFacilitiesMatchAllHint;

  /// Skills/features filter: OR match logic
  ///
  /// In en, this message translates to:
  /// **'Match any selected'**
  String get exploreAttributesMatchAnyHint;

  /// Attribute filter: good-for mode; also used on spot detail
  ///
  /// In en, this message translates to:
  /// **'Good for'**
  String get exploreGoodForSegment;

  /// Attribute filter: features mode
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get exploreSpotFeaturesSegment;

  /// Source filter section label
  ///
  /// In en, this message translates to:
  /// **'Spot Source'**
  String get exploreSpotSourceLabel;

  /// Error loading sync source list for filters
  ///
  /// In en, this message translates to:
  /// **'Failed to load sources'**
  String get exploreSourcesLoadError;

  /// Source filter: all sources option
  ///
  /// In en, this message translates to:
  /// **'All Sources'**
  String get exploreAllSources;

  /// Source filter: native app spots only
  ///
  /// In en, this message translates to:
  /// **'Parkour·Spot (Native)'**
  String get exploreParkourSpotNative;

  /// Source filter: all folders chip
  ///
  /// In en, this message translates to:
  /// **'All Folders'**
  String get exploreAllFolders;

  /// SnackBar when geolocation fails
  ///
  /// In en, this message translates to:
  /// **'Error getting location: {error}'**
  String exploreLocationError(String error);

  /// Shown when centering map on user location
  ///
  /// In en, this message translates to:
  /// **'This is your current location'**
  String get exploreCurrentLocationSnackbar;

  /// Close button tooltip
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get exploreCloseTooltip;

  /// Clear search field
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get exploreClearSearchTooltip;

  /// Open filters
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get exploreFiltersTooltip;

  /// Loading state in search
  ///
  /// In en, this message translates to:
  /// **'Finding location...'**
  String get exploreFindingLocation;

  /// Long-press map: add spot prompt
  ///
  /// In en, this message translates to:
  /// **'Add spot at this location?'**
  String get exploreAddSpotHereTitle;

  /// Bottom sheet: total spots in view when ranked
  ///
  /// In en, this message translates to:
  /// **'{total} spots'**
  String exploreMapRankedTotalBar(int total);

  /// Bottom sheet: how many spots matched (unranked summary)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 spot found} other{{count} spots found}}'**
  String exploreMapSpotsFoundLine(int count);

  /// Suffix when not all spots are listed
  ///
  /// In en, this message translates to:
  /// **' ({count} best shown)'**
  String exploreMapBestShownParenthetical(int count);

  /// Explore bottom sheet segmented control: spots list
  ///
  /// In en, this message translates to:
  /// **'Spots'**
  String get exploreMapListModeSpots;

  /// Explore bottom sheet segmented control: events list
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get exploreMapListModeEvents;

  /// Empty state when map area has no upcoming events
  ///
  /// In en, this message translates to:
  /// **'No events in this area'**
  String get exploreNoEventsArea;

  /// Empty state hint when no events in viewport
  ///
  /// In en, this message translates to:
  /// **'Pan the map to another area or check back later'**
  String get exploreNoEventsAreaHint;

  /// Short badge on spot cards when an upcoming event is linked
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get spotCardUpcomingEventBadge;

  /// Button to center map on an event pin
  ///
  /// In en, this message translates to:
  /// **'Locate'**
  String get exploreEventLocate;

  /// Empty state when search has no results
  ///
  /// In en, this message translates to:
  /// **'No spots found'**
  String get exploreNoSpotsSearch;

  /// Empty state when map area has no spots
  ///
  /// In en, this message translates to:
  /// **'No spots in this area'**
  String get exploreNoSpotsArea;

  /// Empty state hint for search
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search terms'**
  String get exploreNoSpotsSearchHint;

  /// Empty state hint for map
  ///
  /// In en, this message translates to:
  /// **'Move the map to explore different areas'**
  String get exploreNoSpotsMapHint;

  /// FAB: reload spots
  ///
  /// In en, this message translates to:
  /// **'Refresh spots in current view'**
  String get exploreRefreshMapTooltip;

  /// FAB: from satellite to map
  ///
  /// In en, this message translates to:
  /// **'Switch to Map'**
  String get exploreSwitchToMap;

  /// FAB: to satellite/hybrid
  ///
  /// In en, this message translates to:
  /// **'Switch to Satellite'**
  String get exploreSwitchToSatellite;

  /// FAB tooltip when location blocked
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get exploreLocationPermissionDenied;

  /// FAB tooltip for my location
  ///
  /// In en, this message translates to:
  /// **'Center on my location'**
  String get exploreCenterOnMyLocation;

  /// Fullscreen filters panel title
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get exploreFiltersDialogTitle;

  /// Reset all filters
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get exploreClearFilters;

  /// Close filters panel; filters already apply live
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get exploreDoneFilters;

  /// Close filters panel, with live matching spot count in the current map view
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Done · 1 spot} other{Done · {count} spots}}'**
  String exploreDoneFiltersWithCount(int count);

  /// Spot list preview: spot count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} spot} other{{count} spots}}'**
  String exploreSpotCountShort(int count);

  /// Compact install button on explore PWA banner
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get explorePwaBannerInstall;

  /// Add spot: gallery picker error
  ///
  /// In en, this message translates to:
  /// **'Failed to pick images. Please try again.'**
  String get addSpotPickImagesFailed;

  /// Add spot: camera error
  ///
  /// In en, this message translates to:
  /// **'Failed to take photo. Please try again.'**
  String get addSpotTakePhotoFailed;

  /// Add spot: validation
  ///
  /// In en, this message translates to:
  /// **'Please upload at least one photo of the spot'**
  String get addSpotNeedPhoto;

  /// Add spot: validation
  ///
  /// In en, this message translates to:
  /// **'Please wait for location to be determined or pick a location on the map'**
  String get addSpotNeedLocation;

  /// Add spot: submit failed
  ///
  /// In en, this message translates to:
  /// **'Error creating spot: {error}'**
  String addSpotCreateError(String error);

  /// Add spot: name field label
  ///
  /// In en, this message translates to:
  /// **'Spot Name *'**
  String get addSpotNameLabel;

  /// Add spot: name validation
  ///
  /// In en, this message translates to:
  /// **'Please enter a spot name'**
  String get addSpotNameRequired;

  /// Add spot: description label
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get addSpotDescriptionLabel;

  /// Add spot: description validation empty
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get addSpotDescriptionRequired;

  /// Add spot: description validation length
  ///
  /// In en, this message translates to:
  /// **'Description must be at least 10 characters'**
  String get addSpotDescriptionMinLength;

  /// Add spot: submit in progress
  ///
  /// In en, this message translates to:
  /// **'Adding Spot...'**
  String get addSpotCreating;

  /// Add spot: primary submit
  ///
  /// In en, this message translates to:
  /// **'Add Spot'**
  String get addSpotCreateButton;

  /// Add spot: map card title
  ///
  /// In en, this message translates to:
  /// **'Select Spot Location'**
  String get addSpotLocationSectionTitle;

  /// Add spot: GPS loading row
  ///
  /// In en, this message translates to:
  /// **'Getting your location...'**
  String get addSpotGettingLocation;

  /// Add spot: no GPS
  ///
  /// In en, this message translates to:
  /// **'Location not available'**
  String get addSpotLocationNotAvailable;

  /// Add spot: overlay on mini map
  ///
  /// In en, this message translates to:
  /// **'Pick location'**
  String get addSpotPickLocationHint;

  /// Add spot: photos card title
  ///
  /// In en, this message translates to:
  /// **'Select Spot Images'**
  String get addSpotImagesSectionTitle;

  /// Add spot: choose from gallery
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get addSpotGalleryButton;

  /// Add spot: take photo
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get addSpotCameraButton;

  /// Add spot attributes: good for card
  ///
  /// In en, this message translates to:
  /// **'Good For'**
  String get addSpotGoodForTitle;

  /// Add spot attributes: good for hint
  ///
  /// In en, this message translates to:
  /// **'What parkour skills can be practiced here?'**
  String get addSpotGoodForSubtitle;

  /// Add spot attributes: features card
  ///
  /// In en, this message translates to:
  /// **'Spot Features'**
  String get addSpotFeaturesTitle;

  /// Add spot attributes: features hint
  ///
  /// In en, this message translates to:
  /// **'What physical features does this spot have?'**
  String get addSpotFeaturesSubtitle;

  /// Add spot attributes: access card
  ///
  /// In en, this message translates to:
  /// **'Spot Access'**
  String get addSpotAccessTitle;

  /// Add spot attributes: access hint
  ///
  /// In en, this message translates to:
  /// **'What is the access level for this spot?'**
  String get addSpotAccessSubtitle;

  /// Add spot attributes: facilities card (form)
  ///
  /// In en, this message translates to:
  /// **'Spot Facilities'**
  String get addSpotFacilitiesFormTitle;

  /// Add spot attributes: facilities hint
  ///
  /// In en, this message translates to:
  /// **'What amenities are available at this spot?'**
  String get addSpotFacilitiesSubtitle;

  /// Add spot: long-press hint for good-for chips
  ///
  /// In en, this message translates to:
  /// **'Long press any skill for more info'**
  String get addSpotLongPressHintSkill;

  /// Add spot: long-press hint for feature chips
  ///
  /// In en, this message translates to:
  /// **'Long press any feature for more info'**
  String get addSpotLongPressHintFeature;

  /// Add spot: long-press hint for facilities
  ///
  /// In en, this message translates to:
  /// **'Long press any facility for more info'**
  String get addSpotLongPressHintFacility;

  /// Full-screen map: choose coordinates
  ///
  /// In en, this message translates to:
  /// **'Pick Location'**
  String get addSpotPickLocationAppBarTitle;

  /// Location picker hint on mobile
  ///
  /// In en, this message translates to:
  /// **'Tip: You can also add spots from the Explore map by long-pressing on any location.'**
  String get addSpotTipLongPressMobile;

  /// Location picker hint on desktop web
  ///
  /// In en, this message translates to:
  /// **'Tip: You can also add spots from the Explore map by right-clicking on any location.'**
  String get addSpotTipRightClickDesktop;

  /// Event location picker hint on mobile
  ///
  /// In en, this message translates to:
  /// **'Tip: You can also add events from the Explore map by long-pressing on any location.'**
  String get addEventTipLongPressMobile;

  /// Event location picker hint on desktop web
  ///
  /// In en, this message translates to:
  /// **'Tip: You can also add events from the Explore map by right-clicking on any location.'**
  String get addEventTipRightClickDesktop;

  /// Location picker: confirm FAB
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get addSpotUseThisLocation;

  /// Open in maps from address row
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get addSpotDirectionsTooltip;

  /// While reverse-geocoding coordinates
  ///
  /// In en, this message translates to:
  /// **'Getting address...'**
  String get addSpotGettingAddress;

  /// Add event page: app bar title
  ///
  /// In en, this message translates to:
  /// **'Add New Event'**
  String get addEventTitle;

  /// Add event page: title field label
  ///
  /// In en, this message translates to:
  /// **'Event title *'**
  String get addEventTitleLabel;

  /// Add event page: title validation empty
  ///
  /// In en, this message translates to:
  /// **'Title is required.'**
  String get addEventTitleRequired;

  /// Add event page: title validation length
  ///
  /// In en, this message translates to:
  /// **'Title is too long.'**
  String get addEventTitleTooLong;

  /// Add event page: description field label
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get addEventDescriptionLabel;

  /// Add event page: description validation length
  ///
  /// In en, this message translates to:
  /// **'Description is too long.'**
  String get addEventDescriptionTooLong;

  /// Add event page: website field label
  ///
  /// In en, this message translates to:
  /// **'Website URL (optional)'**
  String get addEventWebsiteLabel;

  /// Add event page: website field placeholder
  ///
  /// In en, this message translates to:
  /// **'https://example.com'**
  String get addEventWebsiteHint;

  /// Add event page: poster/cover image section title
  ///
  /// In en, this message translates to:
  /// **'Select Event Images'**
  String get addEventPhotosSectionTitle;

  /// Add event page: all-day toggle
  ///
  /// In en, this message translates to:
  /// **'All-day event'**
  String get addEventAllDay;

  /// Add event page: timezone field label
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get addEventTimezoneLabel;

  /// Add event page: start date/time row
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get addEventStartLabel;

  /// Add event page: end date/time row
  ///
  /// In en, this message translates to:
  /// **'End (optional)'**
  String get addEventEndLabel;

  /// Add event page: end time not chosen
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get addEventEndNotSet;

  /// Add event page: clear end time button
  ///
  /// In en, this message translates to:
  /// **'Clear end'**
  String get addEventClearEndTooltip;

  /// Add event page: date picker title when choosing start date
  ///
  /// In en, this message translates to:
  /// **'Select start date'**
  String get addEventSchedulePickStartDate;

  /// Add event page: time picker title when choosing start time
  ///
  /// In en, this message translates to:
  /// **'Select start time'**
  String get addEventSchedulePickStartTime;

  /// Add event page: date picker title when choosing optional end date after start
  ///
  /// In en, this message translates to:
  /// **'Select end date (optional)'**
  String get addEventSchedulePickEndDateOptional;

  /// Add event page: time picker title when choosing optional end time after start
  ///
  /// In en, this message translates to:
  /// **'Select end time (optional)'**
  String get addEventSchedulePickEndTimeOptional;

  /// Add event page: skip optional end date/time in chained schedule picker
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get addEventScheduleSkipEnd;

  /// Add event page: combined start/end schedule field label
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get addEventScheduleLabel;

  /// Add event page: spot/list linking section
  ///
  /// In en, this message translates to:
  /// **'Linking'**
  String get addEventLinkingSectionTitle;

  /// Add event page: combined spot link and location section
  ///
  /// In en, this message translates to:
  /// **'Select Event Location'**
  String get addEventWhereSectionTitle;

  /// Add event page: schedule section title
  ///
  /// In en, this message translates to:
  /// **'Select Event Schedule'**
  String get addEventWhenSectionTitle;

  /// Add event page: submit blocked until address is geocoded
  ///
  /// In en, this message translates to:
  /// **'Tap the search icon next to the address to confirm it, or pick a location on the map.'**
  String get addEventAddressNeedsResolve;

  /// Add event page: open map picker to link spots
  ///
  /// In en, this message translates to:
  /// **'Link spot'**
  String get addEventLinkSpotButton;

  /// Add event page: linked spot chip
  ///
  /// In en, this message translates to:
  /// **'Spot: {name}'**
  String addEventLinkedSpotLabel(String name);

  /// Add event page: linked spot list chip
  ///
  /// In en, this message translates to:
  /// **'Spot list: {name}'**
  String addEventLinkedSpotListLabel(String name);

  /// Add event page: no map location chosen
  ///
  /// In en, this message translates to:
  /// **'Location not set'**
  String get addEventLocationNotSet;

  /// Add event page: confirmation when a map pin is active
  ///
  /// In en, this message translates to:
  /// **'Exact location set'**
  String get addEventExactLocationSet;

  /// Add event page: location section title
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get addEventLocationSectionTitle;

  /// Add event page: explains where is pin or spots or a list, not a mix
  ///
  /// In en, this message translates to:
  /// **'Choose an exact location, one or more spots, or a spot list.'**
  String get addEventLocationSectionHint;

  /// Add event page: overlay on the location preview map
  ///
  /// In en, this message translates to:
  /// **'Choose on map'**
  String get addEventChooseOnMapHint;

  /// Add event page: open dialog to link a spot list
  ///
  /// In en, this message translates to:
  /// **'Link list'**
  String get addEventLinkListButton;

  /// Add event page: snackbar when a pin replaces spots
  ///
  /// In en, this message translates to:
  /// **'Exact location replaced the linked spots.'**
  String get addEventWhereReplacedSpots;

  /// Add event page: snackbar when spots replace a pin
  ///
  /// In en, this message translates to:
  /// **'Linked spots replaced the exact location.'**
  String get addEventWhereReplacedLocation;

  /// Add event page: snackbar when a list replaces pin or spots
  ///
  /// In en, this message translates to:
  /// **'Spot list replaced the previous location.'**
  String get addEventWhereReplacedWithList;

  /// Add event page: snackbar when a pin replaces a linked list
  ///
  /// In en, this message translates to:
  /// **'Exact location replaced {name}.'**
  String addEventWhereReplacedListWithLocation(String name);

  /// Add event page: snackbar when spots replace a linked list
  ///
  /// In en, this message translates to:
  /// **'Linked spots replaced {name}.'**
  String addEventWhereReplacedListWithSpots(String name);

  /// Add event page: address input label
  ///
  /// In en, this message translates to:
  /// **'Exact address (optional)'**
  String get addEventAddressLabel;

  /// Add event page: address input hint
  ///
  /// In en, this message translates to:
  /// **'Street, number, city'**
  String get addEventAddressHint;

  /// Add event page: geocode typed address button
  ///
  /// In en, this message translates to:
  /// **'Use address'**
  String get addEventUseAddressButton;

  /// Add event page: open location picker button
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get addEventPickLocationButton;

  /// Add event page: clear typed address button tooltip
  ///
  /// In en, this message translates to:
  /// **'Clear address'**
  String get addEventClearAddressTooltip;

  /// Add event page: validation when resolving an empty address
  ///
  /// In en, this message translates to:
  /// **'Enter an address to search for.'**
  String get addEventAddressRequiredToResolve;

  /// Add event page: typed address geocoding failed
  ///
  /// In en, this message translates to:
  /// **'Could not find coordinates for this address.'**
  String get addEventAddressNotFound;

  /// Add event page: map location helper text
  ///
  /// In en, this message translates to:
  /// **'Pick a location on the map (optional when linked spot/list exists).'**
  String get addEventPickLocationHint;

  /// Add event page: clear map location button
  ///
  /// In en, this message translates to:
  /// **'Clear location'**
  String get addEventClearLocationTooltip;

  /// Add event page: open map picker button
  ///
  /// In en, this message translates to:
  /// **'Pick location'**
  String get addEventPickLocationTooltip;

  /// Add event page: fallback address from coordinates
  ///
  /// In en, this message translates to:
  /// **'Approx. {latitude}, {longitude}'**
  String addEventApproxCoordinates(String latitude, String longitude);

  /// Add event page: submit in progress
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get addEventSubmitting;

  /// Add event page: primary submit
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get addEventSubmitButton;

  /// Add event page: website validation
  ///
  /// In en, this message translates to:
  /// **'Website URL must be a valid http(s) URL.'**
  String get addEventWebsiteInvalid;

  /// Add event page: schedule validation
  ///
  /// In en, this message translates to:
  /// **'End time cannot be before start time.'**
  String get addEventEndBeforeStart;

  /// Add event page: location validation when none is selected
  ///
  /// In en, this message translates to:
  /// **'Location is required.'**
  String get addEventNeedLocationOrLink;

  /// Add event page: photo count validation
  ///
  /// In en, this message translates to:
  /// **'At most {count} photos allowed.'**
  String addEventMaxPhotos(int count);

  /// Add event page: photo upload error
  ///
  /// In en, this message translates to:
  /// **'Could not upload photos. Please try again.'**
  String get addEventUploadPhotosFailed;

  /// Add event page: submit failed
  ///
  /// In en, this message translates to:
  /// **'Could not submit event proposal.'**
  String get addEventSubmitFailed;

  /// Add event page: submit succeeded
  ///
  /// In en, this message translates to:
  /// **'Event submitted to the moderator queue.'**
  String get addEventSubmitSuccess;

  /// Placeholder when a spot or event has no photos yet (cards, detail carousel)
  ///
  /// In en, this message translates to:
  /// **'No images yet'**
  String get noImagesYet;

  /// Spot card: empty description
  ///
  /// In en, this message translates to:
  /// **'No description yet'**
  String get spotCardNoDescription;

  /// Spot card list chip: text before list name (keep trailing space)
  ///
  /// In en, this message translates to:
  /// **'Part of '**
  String get spotCardPartOfPrefix;

  /// Spot card: remove from editable list
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get spotCardRemoveFromListTooltip;

  /// After copying share link
  ///
  /// In en, this message translates to:
  /// **'Spot copied to clipboard!'**
  String get spotCardCopiedToClipboard;

  /// Share or clipboard error
  ///
  /// In en, this message translates to:
  /// **'Failed to share spot: {error}'**
  String spotCardShareFailed(String error);

  /// Badge when external source dropped the spot
  ///
  /// In en, this message translates to:
  /// **'Removed from source'**
  String get spotCardRemovedFromSource;

  /// Check-in tooltip when display name missing
  ///
  /// In en, this message translates to:
  /// **'This person'**
  String get spotCheckInUnnamedPerson;

  /// Avatar tooltip: public check-in
  ///
  /// In en, this message translates to:
  /// **'{name} is here now until {time}'**
  String spotCheckInTooltipPublic(String name, String time);

  /// Avatar tooltip: private check-in
  ///
  /// In en, this message translates to:
  /// **'You\'re here now until {time} — only you can see this check-in'**
  String spotCheckInTooltipPrivate(String time);

  /// Avatar tooltip: public training plan
  ///
  /// In en, this message translates to:
  /// **'{name} plans to train here {timeRange}'**
  String spotTrainingPlanTooltipPublic(String name, String timeRange);

  /// Avatar tooltip: private training plan
  ///
  /// In en, this message translates to:
  /// **'You plan to train here {timeRange} — only you can see this plan'**
  String spotTrainingPlanTooltipPrivate(String timeRange);

  /// Avatar tooltip: public training plan during its scheduled window (start time has passed)
  ///
  /// In en, this message translates to:
  /// **'{name} plans to train here until {untilTime}'**
  String spotTrainingPlanTooltipPublicUntil(String name, String untilTime);

  /// Avatar tooltip: private training plan during its scheduled window
  ///
  /// In en, this message translates to:
  /// **'You plan to train here until {untilTime} — only you can see this plan'**
  String spotTrainingPlanTooltipPrivateUntil(String untilTime);

  /// No description provided for @spotDetailRouteErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading spot'**
  String get spotDetailRouteErrorLoading;

  /// No description provided for @spotDetailRouteTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again later'**
  String get spotDetailRouteTryAgainLater;

  /// No description provided for @spotDetailRouteNotFound.
  ///
  /// In en, this message translates to:
  /// **'Spot not found'**
  String get spotDetailRouteNotFound;

  /// No description provided for @spotDetailRouteGoToExplore.
  ///
  /// In en, this message translates to:
  /// **'Go to Explore'**
  String get spotDetailRouteGoToExplore;

  /// No description provided for @spotDetailCheckInVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify your check-ins'**
  String get spotDetailCheckInVerifyFailed;

  /// No description provided for @spotDetailCheckInEndPreviousFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not end your previous check-in'**
  String get spotDetailCheckInEndPreviousFailed;

  /// No description provided for @spotDetailCheckInSuccess.
  ///
  /// In en, this message translates to:
  /// **'You’re checked in'**
  String get spotDetailCheckInSuccess;

  /// No description provided for @spotDetailCheckInFailed.
  ///
  /// In en, this message translates to:
  /// **'Check-in failed'**
  String get spotDetailCheckInFailed;

  /// No description provided for @spotDetailCheckInRemoved.
  ///
  /// In en, this message translates to:
  /// **'Check-in removed'**
  String get spotDetailCheckInRemoved;

  /// No description provided for @spotDetailCheckInDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete check-in'**
  String get spotDetailCheckInDeleteFailed;

  /// No description provided for @spotDetailCheckInUpdated.
  ///
  /// In en, this message translates to:
  /// **'Check-in updated'**
  String get spotDetailCheckInUpdated;

  /// No description provided for @spotDetailCheckInUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update check-in'**
  String get spotDetailCheckInUpdateFailed;

  /// No description provided for @spotDetailCheckInFabTooltipSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to check in'**
  String get spotDetailCheckInFabTooltipSignIn;

  /// No description provided for @spotDetailCheckInFabTooltipEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit check-in'**
  String get spotDetailCheckInFabTooltipEdit;

  /// No description provided for @spotDetailCheckInFabTooltipCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get spotDetailCheckInFabTooltipCheckIn;

  /// No description provided for @spotDetailSpotCreatedOnDateBy.
  ///
  /// In en, this message translates to:
  /// **'Spot created {date} by '**
  String spotDetailSpotCreatedOnDateBy(String date);

  /// No description provided for @spotDetailSpotCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Spot created by '**
  String get spotDetailSpotCreatedBy;

  /// No description provided for @spotDetailUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'Unknown Source'**
  String get spotDetailUnknownSource;

  /// No description provided for @spotDetailSpotImportedOnDateFrom.
  ///
  /// In en, this message translates to:
  /// **'Spot imported {date} from '**
  String spotDetailSpotImportedOnDateFrom(String date);

  /// No description provided for @spotDetailSpotImportedFrom.
  ///
  /// In en, this message translates to:
  /// **'Spot imported from '**
  String get spotDetailSpotImportedFrom;

  /// No description provided for @spotDetailFromFolder.
  ///
  /// In en, this message translates to:
  /// **' from the folder '**
  String get spotDetailFromFolder;

  /// No description provided for @spotDetailImprovedByAfterComma.
  ///
  /// In en, this message translates to:
  /// **', improved by '**
  String get spotDetailImprovedByAfterComma;

  /// No description provided for @spotDetailImprovedByAfterAnd.
  ///
  /// In en, this message translates to:
  /// **' and improved by '**
  String get spotDetailImprovedByAfterAnd;

  /// No description provided for @spotDetailUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get spotDetailUnknownUser;

  /// No description provided for @spotDetailListJoinAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get spotDetailListJoinAnd;

  /// No description provided for @spotDetailListJoinComma.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get spotDetailListJoinComma;

  /// No description provided for @spotDetailLastUpdatedAfterCommaAnd.
  ///
  /// In en, this message translates to:
  /// **', and last updated {date}.'**
  String spotDetailLastUpdatedAfterCommaAnd(String date);

  /// No description provided for @spotDetailLastUpdatedAfterAnd.
  ///
  /// In en, this message translates to:
  /// **' and last updated {date}.'**
  String spotDetailLastUpdatedAfterAnd(String date);

  /// No description provided for @spotDetailDateToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get spotDetailDateToday;

  /// No description provided for @spotDetailDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get spotDetailDateYesterday;

  /// No description provided for @communityDateTomorrow.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get communityDateTomorrow;

  /// Training window on one calendar day for community UI
  ///
  /// In en, this message translates to:
  /// **'From {startTime} until {endTime} {day}'**
  String communityActivityTrainSameDay(
    String startTime,
    String endTime,
    String day,
  );

  /// Training window spanning two calendar days for community UI
  ///
  /// In en, this message translates to:
  /// **'From {startTime} {startDay} until {endTime} {endDay}'**
  String communityActivityTrainSpan(
    String startTime,
    String startDay,
    String endTime,
    String endDay,
  );

  /// No description provided for @communityShareSpotFallbackName.
  ///
  /// In en, this message translates to:
  /// **'this spot'**
  String get communityShareSpotFallbackName;

  /// No description provided for @communityShareCheckInNarrative.
  ///
  /// In en, this message translates to:
  /// **'I\'m now training at {spotName} until about {untilPhrase}'**
  String communityShareCheckInNarrative(String spotName, String untilPhrase);

  /// No description provided for @communityShareTrainingPlanNarrative.
  ///
  /// In en, this message translates to:
  /// **'I\'m planning to train at {spotName} {relativeDay} from {startTime}'**
  String communityShareTrainingPlanNarrative(
    String spotName,
    String relativeDay,
    String startTime,
  );

  /// No description provided for @communityActivityShareCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Message copied to clipboard!'**
  String get communityActivityShareCopiedToClipboard;

  /// No description provided for @communityActivityShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share: {error}'**
  String communityActivityShareFailed(String error);

  /// No description provided for @spotDetailDateDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day ago} other{{count} days ago}}'**
  String spotDetailDateDaysAgo(int count);

  /// No description provided for @spotDetailDateWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 week ago} other{{count} weeks ago}}'**
  String spotDetailDateWeeksAgo(int count);

  /// No description provided for @spotDetailDateMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 month ago} other{{count} months ago}}'**
  String spotDetailDateMonthsAgo(int count);

  /// No description provided for @spotDetailDateYearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 year ago} other{{count} years ago}}'**
  String spotDetailDateYearsAgo(int count);

  /// No description provided for @spotDetailCopySpotFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy spot: {error}'**
  String spotDetailCopySpotFailed(String error);

  /// No description provided for @spotDetailAddressCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Address copied to clipboard!'**
  String get spotDetailAddressCopiedToClipboard;

  /// No description provided for @spotDetailCopyAddressFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy address: {error}'**
  String spotDetailCopyAddressFailed(String error);

  /// No description provided for @spotDetailOpenMapsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open maps app: {error}'**
  String spotDetailOpenMapsFailed(String error);

  /// No description provided for @spotDetailMoreActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get spotDetailMoreActionsTooltip;

  /// No description provided for @spotDetailMenuLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get spotDetailMenuLogin;

  /// No description provided for @spotDetailMenuLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get spotDetailMenuLoginSubtitle;

  /// No description provided for @spotDetailMenuFlagDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Flag as duplicate'**
  String get spotDetailMenuFlagDuplicate;

  /// No description provided for @spotDetailMenuFlagDuplicateSubtitleYes.
  ///
  /// In en, this message translates to:
  /// **'This spot is a duplicate'**
  String get spotDetailMenuFlagDuplicateSubtitleYes;

  /// No description provided for @spotDetailMenuFlagDuplicateSubtitleNo.
  ///
  /// In en, this message translates to:
  /// **'Already marked as duplicate'**
  String get spotDetailMenuFlagDuplicateSubtitleNo;

  /// No description provided for @spotDetailMenuSuggestPhoto.
  ///
  /// In en, this message translates to:
  /// **'Suggest photo'**
  String get spotDetailMenuSuggestPhoto;

  /// No description provided for @spotDetailMenuSuggestPhotoSubtitleYes.
  ///
  /// In en, this message translates to:
  /// **'Submit photos for this spot'**
  String get spotDetailMenuSuggestPhotoSubtitleYes;

  /// No description provided for @spotDetailMenuSuggestPhotoSubtitleNo.
  ///
  /// In en, this message translates to:
  /// **'Cannot suggest photos for duplicates'**
  String get spotDetailMenuSuggestPhotoSubtitleNo;

  /// No description provided for @spotDetailMenuSuggestEdit.
  ///
  /// In en, this message translates to:
  /// **'Suggest an edit'**
  String get spotDetailMenuSuggestEdit;

  /// No description provided for @spotDetailMenuSuggestEditSubtitleYes.
  ///
  /// In en, this message translates to:
  /// **'Propose changes to this spot'**
  String get spotDetailMenuSuggestEditSubtitleYes;

  /// No description provided for @spotDetailMenuSuggestEditSubtitleNo.
  ///
  /// In en, this message translates to:
  /// **'Cannot suggest edits for duplicates'**
  String get spotDetailMenuSuggestEditSubtitleNo;

  /// No description provided for @spotDetailMenuReportSpot.
  ///
  /// In en, this message translates to:
  /// **'Report spot'**
  String get spotDetailMenuReportSpot;

  /// No description provided for @spotDetailMenuReportSpotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us review this spot'**
  String get spotDetailMenuReportSpotSubtitle;

  /// No description provided for @spotDetailMenuEditSpot.
  ///
  /// In en, this message translates to:
  /// **'Edit spot'**
  String get spotDetailMenuEditSpot;

  /// No description provided for @spotDetailMenuEditSpotSubtitleNative.
  ///
  /// In en, this message translates to:
  /// **'Create native spot first'**
  String get spotDetailMenuEditSpotSubtitleNative;

  /// No description provided for @spotDetailMenuEditSpotSubtitleMod.
  ///
  /// In en, this message translates to:
  /// **'Moderator only'**
  String get spotDetailMenuEditSpotSubtitleMod;

  /// No description provided for @spotDetailMenuMarkDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Mark as duplicate'**
  String get spotDetailMenuMarkDuplicate;

  /// No description provided for @spotDetailMenuMarkDuplicateSubtitleDup.
  ///
  /// In en, this message translates to:
  /// **'Already marked as duplicate'**
  String get spotDetailMenuMarkDuplicateSubtitleDup;

  /// No description provided for @spotDetailMenuMarkDuplicateSubtitleMod.
  ///
  /// In en, this message translates to:
  /// **'Moderator only'**
  String get spotDetailMenuMarkDuplicateSubtitleMod;

  /// No description provided for @spotDetailMenuRemoveDuplicateStatus.
  ///
  /// In en, this message translates to:
  /// **'Remove duplicate'**
  String get spotDetailMenuRemoveDuplicateStatus;

  /// No description provided for @spotDetailMenuRemoveDuplicateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore original listing'**
  String get spotDetailMenuRemoveDuplicateSubtitle;

  /// No description provided for @spotDetailMenuCreateNative.
  ///
  /// In en, this message translates to:
  /// **'Create native spot'**
  String get spotDetailMenuCreateNative;

  /// No description provided for @spotDetailMenuCreateNativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Copy from external source'**
  String get spotDetailMenuCreateNativeSubtitle;

  /// No description provided for @spotDetailMenuCreateEvent.
  ///
  /// In en, this message translates to:
  /// **'Create event'**
  String get spotDetailMenuCreateEvent;

  /// No description provided for @spotDetailMenuCreateEventSubtitle.
  ///
  /// In en, this message translates to:
  /// **'At this spot'**
  String get spotDetailMenuCreateEventSubtitle;

  /// No description provided for @spotDetailMenuHideSpot.
  ///
  /// In en, this message translates to:
  /// **'Hide spot'**
  String get spotDetailMenuHideSpot;

  /// No description provided for @spotDetailMenuHideSpotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide from public view'**
  String get spotDetailMenuHideSpotSubtitle;

  /// No description provided for @spotDetailMenuUnhideSpot.
  ///
  /// In en, this message translates to:
  /// **'Unhide spot'**
  String get spotDetailMenuUnhideSpot;

  /// No description provided for @spotDetailMenuUnhideSpotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show in app again'**
  String get spotDetailMenuUnhideSpotSubtitle;

  /// No description provided for @spotDetailMenuDeleteSpot.
  ///
  /// In en, this message translates to:
  /// **'Delete spot'**
  String get spotDetailMenuDeleteSpot;

  /// No description provided for @spotDetailMenuDeleteSubtitleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin only'**
  String get spotDetailMenuDeleteSubtitleAdmin;

  /// No description provided for @spotDetailMenuTriggerResize.
  ///
  /// In en, this message translates to:
  /// **'Trigger image resize'**
  String get spotDetailMenuTriggerResize;

  /// No description provided for @spotDetailMenuTriggerResizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Re-create resized versions'**
  String get spotDetailMenuTriggerResizeSubtitle;

  /// Admin spot/event detail menu: open image URL diagnostics
  ///
  /// In en, this message translates to:
  /// **'Image URLs overview'**
  String get spotDetailMenuImageUrls;

  /// Admin spot/event detail menu subtitle for image URL diagnostics
  ///
  /// In en, this message translates to:
  /// **'Original, resized, and API URLs'**
  String get spotDetailMenuImageUrlsSubtitle;

  /// Admin image URL overview dialog title
  ///
  /// In en, this message translates to:
  /// **'Image URLs — {entityLabel}'**
  String adminImageUrlsDialogTitle(String entityLabel);

  /// No description provided for @adminImageUrlsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No images to show.'**
  String get adminImageUrlsEmpty;

  /// No description provided for @adminImageUrlsImageIndex.
  ///
  /// In en, this message translates to:
  /// **'Image {index} of {total}'**
  String adminImageUrlsImageIndex(int index, int total);

  /// No description provided for @adminImageUrlsLabelFirestore.
  ///
  /// In en, this message translates to:
  /// **'Firestore (original)'**
  String get adminImageUrlsLabelFirestore;

  /// No description provided for @adminImageUrlsLabel1200x1200.
  ///
  /// In en, this message translates to:
  /// **'Expected 1200×1200'**
  String get adminImageUrlsLabel1200x1200;

  /// No description provided for @adminImageUrlsLabel1200x630.
  ///
  /// In en, this message translates to:
  /// **'Expected 1200×630'**
  String get adminImageUrlsLabel1200x630;

  /// No description provided for @adminImageUrlsLabelActualDownload.
  ///
  /// In en, this message translates to:
  /// **'Actual resized download URL'**
  String get adminImageUrlsLabelActualDownload;

  /// No description provided for @adminImageUrlsLabelSpotsApi.
  ///
  /// In en, this message translates to:
  /// **'Spots API URL'**
  String get adminImageUrlsLabelSpotsApi;

  /// No description provided for @adminImageUrlsStatusExists.
  ///
  /// In en, this message translates to:
  /// **'Exists'**
  String get adminImageUrlsStatusExists;

  /// No description provided for @adminImageUrlsStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get adminImageUrlsStatusMissing;

  /// No description provided for @adminImageUrlsStatusNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Not a resizable Firebase Storage image.'**
  String get adminImageUrlsStatusNotApplicable;

  /// No description provided for @adminImageUrlsPreviewOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get adminImageUrlsPreviewOriginal;

  /// No description provided for @adminImageUrlsPreview1200.
  ///
  /// In en, this message translates to:
  /// **'1200×1200'**
  String get adminImageUrlsPreview1200;

  /// No description provided for @adminImageUrlsPreview630.
  ///
  /// In en, this message translates to:
  /// **'1200×630'**
  String get adminImageUrlsPreview630;

  /// No description provided for @adminImageUrlsCopyRow.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get adminImageUrlsCopyRow;

  /// No description provided for @adminImageUrlsCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get adminImageUrlsCopyAll;

  /// No description provided for @adminImageUrlsCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get adminImageUrlsCopiedToClipboard;

  /// No description provided for @adminImageUrlsApiFootnote.
  ///
  /// In en, this message translates to:
  /// **'The spots API returns the Spots API URL even when the resized file is missing; clients may get a 404 until resize completes.'**
  String get adminImageUrlsApiFootnote;

  /// No description provided for @adminImageUrlsEventApiFootnote.
  ///
  /// In en, this message translates to:
  /// **'There is no events API. The Spots API URL row shows the same 1200×1200 transform used for spot imageUrls.'**
  String get adminImageUrlsEventApiFootnote;

  /// No description provided for @spotDetailExternalSourceCannotEdit.
  ///
  /// In en, this message translates to:
  /// **'Spots from external sources cannot be edited. Please create a native spot first using “Mark as Duplicate” → “Create Native Spot”.'**
  String get spotDetailExternalSourceCannotEdit;

  /// No description provided for @spotDetailOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get spotDetailOk;

  /// No description provided for @spotDetailUnableEditNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to edit this spot right now.'**
  String get spotDetailUnableEditNow;

  /// No description provided for @spotDetailOnlyAdminsDelete.
  ///
  /// In en, this message translates to:
  /// **'Only administrators can delete spots.'**
  String get spotDetailOnlyAdminsDelete;

  /// No description provided for @spotDetailResizeAllHaveVersions.
  ///
  /// In en, this message translates to:
  /// **'All images already have resized versions'**
  String get spotDetailResizeAllHaveVersions;

  /// No description provided for @spotDetailResizeSummary.
  ///
  /// In en, this message translates to:
  /// **'Resize: {triggered} triggered, {verified} verified{failedPart}'**
  String spotDetailResizeSummary(
    int triggered,
    int verified,
    String failedPart,
  );

  /// No description provided for @spotDetailResizeFailedPart.
  ///
  /// In en, this message translates to:
  /// **', {failed} failed'**
  String spotDetailResizeFailedPart(int failed);

  /// No description provided for @spotDetailResizeTriggerFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to trigger resize: {error}'**
  String spotDetailResizeTriggerFailed(String error);

  /// No description provided for @spotDetailUnableFlagDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Unable to flag this spot as duplicate right now.'**
  String get spotDetailUnableFlagDuplicate;

  /// No description provided for @spotDetailThanksDuplicateReport.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your duplicate report has been submitted.'**
  String get spotDetailThanksDuplicateReport;

  /// No description provided for @spotDetailUnableSuggestPhotos.
  ///
  /// In en, this message translates to:
  /// **'Unable to suggest photos for this spot right now.'**
  String get spotDetailUnableSuggestPhotos;

  /// No description provided for @spotDetailCannotSuggestPhotosDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Cannot suggest photos for duplicate spots.'**
  String get spotDetailCannotSuggestPhotosDuplicate;

  /// No description provided for @spotDetailThanksPhotoSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your photo suggestion has been submitted for review.'**
  String get spotDetailThanksPhotoSuggestion;

  /// No description provided for @spotDetailUnableSuggestEdits.
  ///
  /// In en, this message translates to:
  /// **'Unable to suggest edits for this spot right now.'**
  String get spotDetailUnableSuggestEdits;

  /// No description provided for @spotDetailCannotSuggestEditsDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Cannot suggest edits for duplicate spots.'**
  String get spotDetailCannotSuggestEditsDuplicate;

  /// No description provided for @spotDetailThanksEditSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your edit suggestion has been submitted for review.'**
  String get spotDetailThanksEditSuggestion;

  /// No description provided for @spotDetailUnableReportNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to report this spot right now.'**
  String get spotDetailUnableReportNow;

  /// No description provided for @spotDetailThanksReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your report has been submitted.'**
  String get spotDetailThanksReportSubmitted;

  /// No description provided for @spotDetailUnableAddToList.
  ///
  /// In en, this message translates to:
  /// **'Unable to add this spot to a list right now.'**
  String get spotDetailUnableAddToList;

  /// No description provided for @spotDetailNoSpotListsAccess.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to spot lists.'**
  String get spotDetailNoSpotListsAccess;

  /// No description provided for @spotDetailListCreatedAndAdded.
  ///
  /// In en, this message translates to:
  /// **'List created and spot added!'**
  String get spotDetailListCreatedAndAdded;

  /// No description provided for @spotDetailSpotAddedToList.
  ///
  /// In en, this message translates to:
  /// **'Spot added to list!'**
  String get spotDetailSpotAddedToList;

  /// No description provided for @spotDetailEditReportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit & report'**
  String get spotDetailEditReportTooltip;

  /// No description provided for @spotDetailShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get spotDetailShareTooltip;

  /// No description provided for @spotDetailQuickActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get spotDetailQuickActionSave;

  /// No description provided for @spotDetailQuickActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get spotDetailQuickActionEdit;

  /// No description provided for @spotDetailQuickActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get spotDetailQuickActionShare;

  /// No description provided for @spotDetailQuickActionRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get spotDetailQuickActionRate;

  /// No description provided for @spotDetailRatingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Community rating and your stars'**
  String get spotDetailRatingTooltip;

  /// No description provided for @spotDetailPresenceHereNow.
  ///
  /// In en, this message translates to:
  /// **'Here now'**
  String get spotDetailPresenceHereNow;

  /// No description provided for @spotDetailCommunitySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get spotDetailCommunitySectionTitle;

  /// No description provided for @spotDetailCommunitySectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See who’s training or planning to be here, and share your session.'**
  String get spotDetailCommunitySectionSubtitle;

  /// No description provided for @spotDetailCommunityNobodyHere.
  ///
  /// In en, this message translates to:
  /// **'No one’s checked in yet. Check in to let others know you’re here.'**
  String get spotDetailCommunityNobodyHere;

  /// No description provided for @spotDetailCommunityNobodyHereShort.
  ///
  /// In en, this message translates to:
  /// **'No one’s here yet.'**
  String get spotDetailCommunityNobodyHereShort;

  /// No description provided for @spotDetailCommunityNobodySocialShort.
  ///
  /// In en, this message translates to:
  /// **'No one’s here or planning ahead yet.'**
  String get spotDetailCommunityNobodySocialShort;

  /// No description provided for @spotDetailCommunityActivityLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load community activity.'**
  String get spotDetailCommunityActivityLoadError;

  /// No description provided for @spotDetailCommunityActivityEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show right now.'**
  String get spotDetailCommunityActivityEmpty;

  /// No description provided for @spotDetailCommunityViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get spotDetailCommunityViewAll;

  /// No description provided for @spotDetailCommunityCheckInButton.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get spotDetailCommunityCheckInButton;

  /// No description provided for @spotDetailCommunityEditCheckInButton.
  ///
  /// In en, this message translates to:
  /// **'Edit check-in'**
  String get spotDetailCommunityEditCheckInButton;

  /// No description provided for @spotDetailCommunitySignInToCheckInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in to check in'**
  String get spotDetailCommunitySignInToCheckInButton;

  /// No description provided for @spotDetailCommunityPlanningVisitButton.
  ///
  /// In en, this message translates to:
  /// **'Plan to train'**
  String get spotDetailCommunityPlanningVisitButton;

  /// No description provided for @spotDetailCommunityPlanningVisitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set when you’ll train here.'**
  String get spotDetailCommunityPlanningVisitTooltip;

  /// Hover text for Community Check in button (no active check-in)
  ///
  /// In en, this message translates to:
  /// **'Show others you’re here now.'**
  String get spotDetailCommunityCheckInButtonTooltip;

  /// Hover text for Community Edit check-in button
  ///
  /// In en, this message translates to:
  /// **'Update your check-in.'**
  String get spotDetailCommunityEditCheckInButtonTooltip;

  /// Hover text for Community sign-in-to-check-in button
  ///
  /// In en, this message translates to:
  /// **'Sign in to check in here.'**
  String get spotDetailCommunitySignInToCheckInButtonTooltip;

  /// No description provided for @spotDetailCommunityPlanningToTrain.
  ///
  /// In en, this message translates to:
  /// **'Planning to train'**
  String get spotDetailCommunityPlanningToTrain;

  /// No description provided for @spotDetailCommunityNobodyPlanningShort.
  ///
  /// In en, this message translates to:
  /// **'No upcoming plans yet.'**
  String get spotDetailCommunityNobodyPlanningShort;

  /// No description provided for @spotDetailCommunitySignInToPlanButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in to plan a visit'**
  String get spotDetailCommunitySignInToPlanButton;

  /// No description provided for @spotDetailCommunityEditTrainingPlanButton.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get spotDetailCommunityEditTrainingPlanButton;

  /// Title for new check-in dialog on spot detail
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get spotCheckInDialogTitle;

  /// Title for edit check-in dialog on spot detail
  ///
  /// In en, this message translates to:
  /// **'Edit check-in'**
  String get spotCheckInDialogTitleEdit;

  /// Intro paragraph for new check-in dialog
  ///
  /// In en, this message translates to:
  /// **'Let others know you’re training here and roughly when you’ll finish. If you share publicly, you show on this spot’s Community strip until that time.'**
  String get spotCheckInDialogIntroNew;

  /// Intro paragraph for edit check-in dialog
  ///
  /// In en, this message translates to:
  /// **'Change your arrival and end times, who can see this check-in, and your note.'**
  String get spotCheckInDialogIntroEdit;

  /// Title for visibility switch on check-in dialog
  ///
  /// In en, this message translates to:
  /// **'Share publicly'**
  String get spotCheckInDialogSharePublic;

  /// Subtitle explaining private check-in on check-in dialog
  ///
  /// In en, this message translates to:
  /// **'Turn off to keep this check-in visible only to you.'**
  String get spotCheckInDialogShareSub;

  /// No description provided for @spotCheckInDialogLabelArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get spotCheckInDialogLabelArrived;

  /// No description provided for @spotCheckInDialogLabelHereUntil.
  ///
  /// In en, this message translates to:
  /// **'Here until'**
  String get spotCheckInDialogLabelHereUntil;

  /// No description provided for @spotCheckInDialogLabelUntil.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get spotCheckInDialogLabelUntil;

  /// No description provided for @spotCheckInDialogStillHere.
  ///
  /// In en, this message translates to:
  /// **'Still here'**
  String get spotCheckInDialogStillHere;

  /// No description provided for @spotCheckInDialogEndNow.
  ///
  /// In en, this message translates to:
  /// **'End now'**
  String get spotCheckInDialogEndNow;

  /// No description provided for @spotCheckInDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get spotCheckInDialogCancel;

  /// No description provided for @spotCheckInDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get spotCheckInDialogSave;

  /// No description provided for @spotCheckInDialogDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get spotCheckInDialogDelete;

  /// No description provided for @spotCheckInDialogConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete check-in?'**
  String get spotCheckInDialogConfirmDeleteTitle;

  /// No description provided for @spotCheckInDialogConfirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes this visit from your history. It doesn’t remove the spot from your Been to list.'**
  String get spotCheckInDialogConfirmDeleteBody;

  /// No description provided for @spotCheckInDialogExtendBannerText.
  ///
  /// In en, this message translates to:
  /// **'You have a recently expired check-in here.'**
  String get spotCheckInDialogExtendBannerText;

  /// No description provided for @spotCheckInDialogExtendInstead.
  ///
  /// In en, this message translates to:
  /// **'Extend that check-in instead'**
  String get spotCheckInDialogExtendInstead;

  /// Warning when user has an active check-in at a named spot
  ///
  /// In en, this message translates to:
  /// **'You’re currently checked in at {spotName}. Checking in here will end that check-in.'**
  String spotCheckInDialogActiveElsewhereAtNamed(String spotName);

  /// No description provided for @spotCheckInDialogActiveElsewhereUnnamed.
  ///
  /// In en, this message translates to:
  /// **'You’re checked in at another spot. Checking in here will end that check-in.'**
  String get spotCheckInDialogActiveElsewhereUnnamed;

  /// No description provided for @spotCheckInDialogActiveElsewhereMultiple.
  ///
  /// In en, this message translates to:
  /// **'You have active check-ins at other spots. Checking in here will end those check-ins.'**
  String get spotCheckInDialogActiveElsewhereMultiple;

  /// No description provided for @spotCheckInDialogNudgeEarlier.
  ///
  /// In en, this message translates to:
  /// **'15 minutes earlier'**
  String get spotCheckInDialogNudgeEarlier;

  /// No description provided for @spotCheckInDialogNudgeLater.
  ///
  /// In en, this message translates to:
  /// **'15 minutes later'**
  String get spotCheckInDialogNudgeLater;

  /// Shown when checking in from an eligible training plan; explains the plan will be removed
  ///
  /// In en, this message translates to:
  /// **'Saving replaces your plan with this check-in. Your planned end time is pre-filled below.'**
  String get spotCheckInDialogTrainingPlanConversionBanner;

  /// Shared label for optional note field on check-in and training-plan dialogs
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get spotDetailSessionNoteLabel;

  /// Placeholder hint for optional session note
  ///
  /// In en, this message translates to:
  /// **'e.g. skills or drills you’re working on'**
  String get spotDetailSessionNoteHint;

  /// No description provided for @spotTrainingPlanDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan to train here'**
  String get spotTrainingPlanDialogTitle;

  /// No description provided for @spotTrainingPlanDialogTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit training plan'**
  String get spotTrainingPlanDialogTitleEdit;

  /// Prompt in edit training plan dialog to switch to a live check-in
  ///
  /// In en, this message translates to:
  /// **'Here now? Check in so others know you’ve arrived.'**
  String get spotTrainingPlanDialogCheckInCtaBody;

  /// Edit training plan: prompt to check in before the planned window starts (linked check-in still allowed)
  ///
  /// In en, this message translates to:
  /// **'Here already? Check in so others know you’ve arrived.'**
  String get spotTrainingPlanDialogCheckInCtaBodyEarly;

  /// Button to leave edit plan and open check-in
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get spotTrainingPlanDialogCheckInCtaButton;

  /// No description provided for @spotTrainingPlanDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Set when you plan to start and finish. Public plans appear on this spot’s Community strip alongside other people who’ve shared.'**
  String get spotTrainingPlanDialogBody;

  /// No description provided for @spotTrainingPlanDialogSharePublic.
  ///
  /// In en, this message translates to:
  /// **'Share publicly'**
  String get spotTrainingPlanDialogSharePublic;

  /// No description provided for @spotTrainingPlanDialogShareSub.
  ///
  /// In en, this message translates to:
  /// **'Turn off to keep this plan visible only to you.'**
  String get spotTrainingPlanDialogShareSub;

  /// No description provided for @spotTrainingPlanDialogStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get spotTrainingPlanDialogStartLabel;

  /// No description provided for @spotTrainingPlanDialogEndLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get spotTrainingPlanDialogEndLabel;

  /// No description provided for @spotTrainingPlanDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get spotTrainingPlanDialogSave;

  /// No description provided for @spotTrainingPlanDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get spotTrainingPlanDialogCancel;

  /// No description provided for @spotTrainingPlanDialogDelete.
  ///
  /// In en, this message translates to:
  /// **'Remove plan'**
  String get spotTrainingPlanDialogDelete;

  /// No description provided for @spotTrainingPlanDialogDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this plan?'**
  String get spotTrainingPlanDialogDeleteTitle;

  /// No description provided for @spotTrainingPlanDialogDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'You can create a new plan anytime.'**
  String get spotTrainingPlanDialogDeleteBody;

  /// No description provided for @spotTrainingPlanValidationOrder.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time.'**
  String get spotTrainingPlanValidationOrder;

  /// No description provided for @spotTrainingPlanValidationMinDuration.
  ///
  /// In en, this message translates to:
  /// **'Window must be at least 15 minutes.'**
  String get spotTrainingPlanValidationMinDuration;

  /// No description provided for @spotTrainingPlanValidationMaxDuration.
  ///
  /// In en, this message translates to:
  /// **'Window cannot be longer than 12 hours.'**
  String get spotTrainingPlanValidationMaxDuration;

  /// No description provided for @spotTrainingPlanValidationStartTooFar.
  ///
  /// In en, this message translates to:
  /// **'Start time cannot be more than 30 days away.'**
  String get spotTrainingPlanValidationStartTooFar;

  /// No description provided for @spotTrainingPlanValidationEndNotFuture.
  ///
  /// In en, this message translates to:
  /// **'End time must be in the future.'**
  String get spotTrainingPlanValidationEndNotFuture;

  /// No description provided for @spotTrainingPlanValidationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid time range.'**
  String get spotTrainingPlanValidationInvalid;

  /// No description provided for @spotDetailTrainingPlanSaved.
  ///
  /// In en, this message translates to:
  /// **'Training plan saved'**
  String get spotDetailTrainingPlanSaved;

  /// No description provided for @spotDetailTrainingPlanUpdated.
  ///
  /// In en, this message translates to:
  /// **'Training plan updated'**
  String get spotDetailTrainingPlanUpdated;

  /// No description provided for @spotDetailTrainingPlanFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save training plan'**
  String get spotDetailTrainingPlanFailed;

  /// No description provided for @spotDetailTrainingPlanRemoved.
  ///
  /// In en, this message translates to:
  /// **'Training plan removed'**
  String get spotDetailTrainingPlanRemoved;

  /// No description provided for @spotDetailTrainingPlanDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove training plan'**
  String get spotDetailTrainingPlanDeleteFailed;

  /// No description provided for @spotTrainingPlanListDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Planning to train'**
  String get spotTrainingPlanListDialogTitle;

  /// No description provided for @spotTrainingPlanListDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'People who shared a public plan for this spot.'**
  String get spotTrainingPlanListDialogSubtitle;

  /// No description provided for @spotTrainingPlanListDialogClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get spotTrainingPlanListDialogClose;

  /// No description provided for @spotTrainingPlanListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No public plans yet.'**
  String get spotTrainingPlanListEmpty;

  /// No description provided for @spotTrainingPlanListLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load training plans'**
  String get spotTrainingPlanListLoadError;

  /// No description provided for @spotTrainingPlanEditMine.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get spotTrainingPlanEditMine;

  /// No description provided for @spotTrainingPlanJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get spotTrainingPlanJoin;

  /// No description provided for @spotTrainingPlanOnlyYou.
  ///
  /// In en, this message translates to:
  /// **'Only you'**
  String get spotTrainingPlanOnlyYou;

  /// No description provided for @spotTrainingPlanUnnamedPerson.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get spotTrainingPlanUnnamedPerson;

  /// No description provided for @spotTrainingPlanTimeRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String spotTrainingPlanTimeRange(String start, String end);

  /// No description provided for @spotDetailHiddenBanner.
  ///
  /// In en, this message translates to:
  /// **'This spot is hidden from public view. It likely no longer exists or doesn’t meet our policies. It will not appear in search results or on the map.'**
  String get spotDetailHiddenBanner;

  /// No description provided for @spotDetailSourceRemovedBanner.
  ///
  /// In en, this message translates to:
  /// **'This spot is no longer listed in {source}. Details might be outdated, so double-check before visiting.'**
  String spotDetailSourceRemovedBanner(String source);

  /// No description provided for @spotDetailSourceRemovedUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'its original source'**
  String get spotDetailSourceRemovedUnknownSource;

  /// No description provided for @spotDetailSectionFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get spotDetailSectionFeatures;

  /// No description provided for @spotDetailSectionAccess.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get spotDetailSectionAccess;

  /// No description provided for @spotDetailSectionFacilities.
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get spotDetailSectionFacilities;

  /// No description provided for @spotDetailJumpflixFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Jumpflix fetch failed: {error}'**
  String spotDetailJumpflixFetchFailed(String error);

  /// No description provided for @spotDetailBrandYoutube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get spotDetailBrandYoutube;

  /// No description provided for @spotDetailBrandJumpflix.
  ///
  /// In en, this message translates to:
  /// **'Jumpflix'**
  String get spotDetailBrandJumpflix;

  /// No description provided for @spotDetailBrandAsSeenIn.
  ///
  /// In en, this message translates to:
  /// **'As seen in'**
  String get spotDetailBrandAsSeenIn;

  /// No description provided for @spotDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get spotDetailLoading;

  /// No description provided for @spotDetailLoadingYourRating.
  ///
  /// In en, this message translates to:
  /// **'Loading your rating...'**
  String get spotDetailLoadingYourRating;

  /// No description provided for @spotDetailRateThisSpot.
  ///
  /// In en, this message translates to:
  /// **'Rate this spot'**
  String get spotDetailRateThisSpot;

  /// No description provided for @spotDetailHeaderNoRatingsYet.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get spotDetailHeaderNoRatingsYet;

  /// No description provided for @spotDetailCouldNotLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your profile.'**
  String get spotDetailCouldNotLoadProfile;

  /// No description provided for @spotDetailRefreshPageToRate.
  ///
  /// In en, this message translates to:
  /// **'Please refresh the page to rate.'**
  String get spotDetailRefreshPageToRate;

  /// No description provided for @spotDetailSignInToRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to rate this spot'**
  String get spotDetailSignInToRateTitle;

  /// No description provided for @spotDetailSignInToRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to rate this spot and help other parkour enthusiasts.'**
  String get spotDetailSignInToRateSubtitle;

  /// No description provided for @spotDetailSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get spotDetailSignInButton;

  /// No description provided for @spotDetailCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create an Account'**
  String get spotDetailCreateAccountButton;

  /// No description provided for @spotDetailMapSwitchToMap.
  ///
  /// In en, this message translates to:
  /// **'Switch to Map'**
  String get spotDetailMapSwitchToMap;

  /// No description provided for @spotDetailMapSwitchToSatellite.
  ///
  /// In en, this message translates to:
  /// **'Switch to Satellite'**
  String get spotDetailMapSwitchToSatellite;

  /// No description provided for @spotDetailMapLocateOnMap.
  ///
  /// In en, this message translates to:
  /// **'Locate on map'**
  String get spotDetailMapLocateOnMap;

  /// No description provided for @spotDetailDuplicateOf.
  ///
  /// In en, this message translates to:
  /// **'Duplicate of'**
  String get spotDetailDuplicateOf;

  /// No description provided for @spotDetailOriginalSpotFallback.
  ///
  /// In en, this message translates to:
  /// **'Original spot'**
  String get spotDetailOriginalSpotFallback;

  /// No description provided for @spotDetailAlsoBasedOn.
  ///
  /// In en, this message translates to:
  /// **'Also based on'**
  String get spotDetailAlsoBasedOn;

  /// No description provided for @spotDetailGalleryPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String spotDetailGalleryPageIndicator(int current, int total);

  /// No description provided for @spotDetailSaveMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save spot'**
  String get spotDetailSaveMenuTooltip;

  /// No description provided for @spotDetailSaveMenuSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save spots'**
  String get spotDetailSaveMenuSignInTitle;

  /// No description provided for @spotDetailSaveMenuSignInBody.
  ///
  /// In en, this message translates to:
  /// **'Add this spot to Want to visit, Been here, or your own lists. Log in or create a free account to get started.'**
  String get spotDetailSaveMenuSignInBody;

  /// No description provided for @spotDetailSaveMenuLogInOrCreate.
  ///
  /// In en, this message translates to:
  /// **'Log in or create account'**
  String get spotDetailSaveMenuLogInOrCreate;

  /// No description provided for @spotDetailSaveTooltipUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get spotDetailSaveTooltipUpdating;

  /// No description provided for @spotDetailSaveTooltipWantToVisit.
  ///
  /// In en, this message translates to:
  /// **'Saved: Want to visit'**
  String get spotDetailSaveTooltipWantToVisit;

  /// No description provided for @spotDetailSaveTooltipBeenHere.
  ///
  /// In en, this message translates to:
  /// **'Saved: Been here'**
  String get spotDetailSaveTooltipBeenHere;

  /// No description provided for @spotDetailSaveTooltipGeneric.
  ///
  /// In en, this message translates to:
  /// **'Save spot'**
  String get spotDetailSaveTooltipGeneric;

  /// No description provided for @spotDetailRemovedFromWantToVisit.
  ///
  /// In en, this message translates to:
  /// **'Removed from Want to visit'**
  String get spotDetailRemovedFromWantToVisit;

  /// No description provided for @spotDetailFailedToRemove.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove'**
  String get spotDetailFailedToRemove;

  /// No description provided for @spotDetailAddedToWantToVisit.
  ///
  /// In en, this message translates to:
  /// **'Added to Want to visit'**
  String get spotDetailAddedToWantToVisit;

  /// No description provided for @spotDetailFailedToAdd.
  ///
  /// In en, this message translates to:
  /// **'Failed to add'**
  String get spotDetailFailedToAdd;

  /// No description provided for @spotDetailRemovedFromBeenHere.
  ///
  /// In en, this message translates to:
  /// **'Removed from Been here'**
  String get spotDetailRemovedFromBeenHere;

  /// No description provided for @spotDetailAddedToBeenHere.
  ///
  /// In en, this message translates to:
  /// **'Added to Been here'**
  String get spotDetailAddedToBeenHere;

  /// No description provided for @spotDetailWantToVisit.
  ///
  /// In en, this message translates to:
  /// **'Want to visit'**
  String get spotDetailWantToVisit;

  /// No description provided for @spotDetailBeenHere.
  ///
  /// In en, this message translates to:
  /// **'Been here'**
  String get spotDetailBeenHere;

  /// No description provided for @spotDetailViewFullListTooltip.
  ///
  /// In en, this message translates to:
  /// **'View full list'**
  String get spotDetailViewFullListTooltip;

  /// No description provided for @spotDetailAddToCustomList.
  ///
  /// In en, this message translates to:
  /// **'Add to custom list'**
  String get spotDetailAddToCustomList;

  /// No description provided for @spotDetailAddToCustomListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose or create a list'**
  String get spotDetailAddToCustomListSubtitle;

  /// No description provided for @spotDetailListNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'List name cannot be empty'**
  String get spotDetailListNameEmpty;

  /// No description provided for @spotDetailFailedAddToListGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to add spot to list'**
  String get spotDetailFailedAddToListGeneric;

  /// No description provided for @spotDetailFailedCreateList.
  ///
  /// In en, this message translates to:
  /// **'Failed to create list'**
  String get spotDetailFailedCreateList;

  /// No description provided for @spotDetailFailedAddToSomeLists.
  ///
  /// In en, this message translates to:
  /// **'Failed to add spot to some lists'**
  String get spotDetailFailedAddToSomeLists;

  /// No description provided for @spotDetailAddToListTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to {name}'**
  String spotDetailAddToListTitle(String name);

  /// No description provided for @spotDetailSelectSections.
  ///
  /// In en, this message translates to:
  /// **'Select sections:'**
  String get spotDetailSelectSections;

  /// No description provided for @spotDetailSectionEntryCount.
  ///
  /// In en, this message translates to:
  /// **'Section ({count} spots)'**
  String spotDetailSectionEntryCount(int count);

  /// No description provided for @spotDetailAddToNewSection.
  ///
  /// In en, this message translates to:
  /// **'Add to new section'**
  String get spotDetailAddToNewSection;

  /// No description provided for @spotDetailSectionNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Section name (optional)'**
  String get spotDetailSectionNameOptional;

  /// No description provided for @spotDetailNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get spotDetailNoteOptional;

  /// No description provided for @spotDetailSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get spotDetailSkip;

  /// No description provided for @spotDetailAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get spotDetailAdd;

  /// No description provided for @spotDetailAddToListDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get spotDetailAddToListDialogTitle;

  /// No description provided for @spotDetailAlreadyInLists.
  ///
  /// In en, this message translates to:
  /// **'Already in these lists:'**
  String get spotDetailAlreadyInLists;

  /// No description provided for @spotDetailNoListsYet.
  ///
  /// In en, this message translates to:
  /// **'You don’t have any lists yet. Create one to get started!'**
  String get spotDetailNoListsYet;

  /// No description provided for @spotDetailSelectListsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select lists to add this spot to:'**
  String get spotDetailSelectListsPrompt;

  /// No description provided for @spotDetailCreateNewList.
  ///
  /// In en, this message translates to:
  /// **'Create New List'**
  String get spotDetailCreateNewList;

  /// No description provided for @spotDetailListNameLabel.
  ///
  /// In en, this message translates to:
  /// **'List Name'**
  String get spotDetailListNameLabel;

  /// No description provided for @spotDetailListNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., My Favorite Spots'**
  String get spotDetailListNameHint;

  /// No description provided for @spotDetailListDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get spotDetailListDescriptionLabel;

  /// No description provided for @spotDetailListDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a description for this list'**
  String get spotDetailListDescriptionHint;

  /// No description provided for @spotDetailVisibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get spotDetailVisibilityLabel;

  /// No description provided for @spotDetailCreateAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Create & Add'**
  String get spotDetailCreateAndAdd;

  /// No description provided for @spotDetailReportDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Report duplicate spot'**
  String get spotDetailReportDuplicateTitle;

  /// No description provided for @spotDetailReportDuplicateIntro.
  ///
  /// In en, this message translates to:
  /// **'Please select the spot this is a duplicate of.'**
  String get spotDetailReportDuplicateIntro;

  /// No description provided for @spotDetailEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get spotDetailEmailInvalid;

  /// No description provided for @spotDetailEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please provide an email address.'**
  String get spotDetailEmailRequired;

  /// No description provided for @spotDetailSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get spotDetailSubmitReport;

  /// No description provided for @spotDetailReportThisSpotTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this spot'**
  String get spotDetailReportThisSpotTitle;

  /// No description provided for @spotDetailReportIntro.
  ///
  /// In en, this message translates to:
  /// **'Let us know what is wrong with {name}. Moderators will review your report shortly.'**
  String spotDetailReportIntro(String name);

  /// No description provided for @spotDetailReportWhatWrong.
  ///
  /// In en, this message translates to:
  /// **'What is happening?'**
  String get spotDetailReportWhatWrong;

  /// No description provided for @spotDetailReportCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get spotDetailReportCategoryLabel;

  /// No description provided for @spotDetailReportCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a report category'**
  String get spotDetailReportCategoryHint;

  /// No description provided for @spotDetailReportDescribeIssue.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue'**
  String get spotDetailReportDescribeIssue;

  /// No description provided for @spotDetailReportDescribeIssueHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what does not match reality'**
  String get spotDetailReportDescribeIssueHint;

  /// No description provided for @spotDetailReportAdditionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get spotDetailReportAdditionalDetails;

  /// No description provided for @spotDetailReportAdditionalDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Anything else we should know?'**
  String get spotDetailReportAdditionalDetailsHint;

  /// No description provided for @spotDetailReportEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get spotDetailReportEmailLabel;

  /// No description provided for @spotDetailReportEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'We will contact you only about this report.'**
  String get spotDetailReportEmailHelper;

  /// No description provided for @spotDetailReportReachOutAt.
  ///
  /// In en, this message translates to:
  /// **'We will reach out at {email} if we need more info.'**
  String spotDetailReportReachOutAt(String email);

  /// No description provided for @spotDetailReportReachOutAccount.
  ///
  /// In en, this message translates to:
  /// **'We will reach out using your account email if we need more info.'**
  String get spotDetailReportReachOutAccount;

  /// No description provided for @spotDetailReportCategoryOtherDescribe.
  ///
  /// In en, this message translates to:
  /// **'Please describe the issue when selecting Other.'**
  String get spotDetailReportCategoryOtherDescribe;

  /// No description provided for @spotDetailReportCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a category.'**
  String get spotDetailReportCategoryRequired;

  /// No description provided for @spotDetailReportSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your report. Please try again.'**
  String get spotDetailReportSendFailed;

  /// No description provided for @spotDetailReportCategoryClosed.
  ///
  /// In en, this message translates to:
  /// **'Spot closed or removed'**
  String get spotDetailReportCategoryClosed;

  /// No description provided for @spotDetailReportCategoryInaccurate.
  ///
  /// In en, this message translates to:
  /// **'Location or details seem wrong'**
  String get spotDetailReportCategoryInaccurate;

  /// No description provided for @spotDetailReportCategoryUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Unsafe conditions'**
  String get spotDetailReportCategoryUnsafe;

  /// No description provided for @spotDetailReportCategoryNotASpot.
  ///
  /// In en, this message translates to:
  /// **'Not a spot'**
  String get spotDetailReportCategoryNotASpot;

  /// No description provided for @spotDetailReportCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get spotDetailReportCategoryOther;

  /// No description provided for @spotDetailReportCategoryClosedDesc.
  ///
  /// In en, this message translates to:
  /// **'The spot has been permanently closed, demolished, or removed and is no longer accessible. Please provide more details below.'**
  String get spotDetailReportCategoryClosedDesc;

  /// No description provided for @spotDetailReportCategoryInaccurateDesc.
  ///
  /// In en, this message translates to:
  /// **'Something about this spot looks wrong: the pin, name, description, or address may be incorrect. Use this when you are not sure what the correct information should be. Describe what seems off below. If you know what to change, use Suggest an edit from the spot menu instead.'**
  String get spotDetailReportCategoryInaccurateDesc;

  /// No description provided for @spotDetailReportCategoryUnsafeDesc.
  ///
  /// In en, this message translates to:
  /// **'The spot has become dangerous due to structural issues, environmental hazards, or other safety concerns. Please provide more details below on what is unsafe.'**
  String get spotDetailReportCategoryUnsafeDesc;

  /// No description provided for @spotDetailReportCategoryNotASpotDesc.
  ///
  /// In en, this message translates to:
  /// **'Only for objective issues like spam, spots in invalid locations (e.g., middle of the sea), private residences, entire cities, or other clearly invalid entries. For subjective opinions about spot quality, please use a rating instead. Please provide more details below on why this is not a spot.'**
  String get spotDetailReportCategoryNotASpotDesc;

  /// No description provided for @spotDetailReportCategoryOtherDesc.
  ///
  /// In en, this message translates to:
  /// **'Any other issue not covered by the categories above. Please describe the issue in the field below.'**
  String get spotDetailReportCategoryOtherDesc;

  /// No description provided for @spotDetailMarkDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as Duplicate'**
  String get spotDetailMarkDuplicateTitle;

  /// No description provided for @spotDetailMarkDuplicateBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to mark this spot as a duplicate? This action can be reversed later.'**
  String get spotDetailMarkDuplicateBody;

  /// No description provided for @spotDetailMarkDuplicateAddToOriginal.
  ///
  /// In en, this message translates to:
  /// **'Select which items to add to the original spot:'**
  String get spotDetailMarkDuplicateAddToOriginal;

  /// No description provided for @spotDetailMarkDuplicatePhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get spotDetailMarkDuplicatePhotos;

  /// No description provided for @spotDetailMarkDuplicateYoutube.
  ///
  /// In en, this message translates to:
  /// **'YouTube links'**
  String get spotDetailMarkDuplicateYoutube;

  /// No description provided for @spotDetailMarkDuplicateOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Select which items to overwrite in the original spot (if set):'**
  String get spotDetailMarkDuplicateOverwrite;

  /// No description provided for @spotDetailMarkDuplicateName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get spotDetailMarkDuplicateName;

  /// No description provided for @spotDetailMarkDuplicateDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get spotDetailMarkDuplicateDescription;

  /// No description provided for @spotDetailMarkDuplicateLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get spotDetailMarkDuplicateLocation;

  /// No description provided for @spotDetailMarkDuplicateSpotAttributes.
  ///
  /// In en, this message translates to:
  /// **'Spot attributes'**
  String get spotDetailMarkDuplicateSpotAttributes;

  /// No description provided for @spotDetailConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get spotDetailConfirm;

  /// No description provided for @spotDetailPickImagesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick images. Please try again.'**
  String get spotDetailPickImagesFailed;

  /// No description provided for @spotDetailSelectAtLeastOnePhoto.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one photo'**
  String get spotDetailSelectAtLeastOnePhoto;

  /// No description provided for @spotDetailSuggestPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest Photos'**
  String get spotDetailSuggestPhotosTitle;

  /// No description provided for @spotDetailSuggestPhotosIntro.
  ///
  /// In en, this message translates to:
  /// **'Submit photos to be added to this spot. Photos will be reviewed by moderators before being added.'**
  String get spotDetailSuggestPhotosIntro;

  /// No description provided for @spotDetailSelectPhotos.
  ///
  /// In en, this message translates to:
  /// **'Select Photos'**
  String get spotDetailSelectPhotos;

  /// No description provided for @spotDetailPickPhotos.
  ///
  /// In en, this message translates to:
  /// **'Pick Photos'**
  String get spotDetailPickPhotos;

  /// No description provided for @spotDetailAdditionalDetailsOptional.
  ///
  /// In en, this message translates to:
  /// **'Additional Details (Optional)'**
  String get spotDetailAdditionalDetailsOptional;

  /// No description provided for @spotDetailAdditionalDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Add any additional information about these photos...'**
  String get spotDetailAdditionalDetailsHint;

  /// No description provided for @spotDetailSuggestPhotosEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'We will contact you only about this suggestion.'**
  String get spotDetailSuggestPhotosEmailHelper;

  /// No description provided for @spotDetailSuggestPhotosSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit photo suggestion. Please try again.'**
  String get spotDetailSuggestPhotosSubmitFailed;

  /// No description provided for @spotDetailSuggestPhotosSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Error submitting photo suggestion: {error}'**
  String spotDetailSuggestPhotosSubmitError(String error);

  /// No description provided for @spotDetailSuggestEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest an Edit'**
  String get spotDetailSuggestEditTitle;

  /// No description provided for @spotDetailSuggestEditIntro.
  ///
  /// In en, this message translates to:
  /// **'Propose changes to this spot. Moderators will review your suggestions.'**
  String get spotDetailSuggestEditIntro;

  /// No description provided for @spotDetailSuggestEditSuggestChange.
  ///
  /// In en, this message translates to:
  /// **'Please suggest at least one change.'**
  String get spotDetailSuggestEditSuggestChange;

  /// No description provided for @spotDetailSuggestEditSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit edit suggestion. Please try again.'**
  String get spotDetailSuggestEditSubmitFailed;

  /// No description provided for @spotDetailSuggestEditSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Error submitting edit suggestion: {error}'**
  String spotDetailSuggestEditSubmitError(String error);

  /// No description provided for @spotDetailGeocoding.
  ///
  /// In en, this message translates to:
  /// **'Geocoding...'**
  String get spotDetailGeocoding;

  /// No description provided for @spotDetailChangeLocationPicked.
  ///
  /// In en, this message translates to:
  /// **'Change location (picked)'**
  String get spotDetailChangeLocationPicked;

  /// No description provided for @spotDetailPickLocationOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick different location on map'**
  String get spotDetailPickLocationOnMap;

  /// No description provided for @spotDetailFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get spotDetailFieldTitle;

  /// No description provided for @spotDetailFieldTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Spot title'**
  String get spotDetailFieldTitleHint;

  /// No description provided for @spotDetailFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get spotDetailFieldDescription;

  /// No description provided for @spotDetailFieldDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Spot description'**
  String get spotDetailFieldDescriptionHint;

  /// No description provided for @spotDetailFieldSpotAttributes.
  ///
  /// In en, this message translates to:
  /// **'Spot attributes'**
  String get spotDetailFieldSpotAttributes;

  /// No description provided for @spotDetailSuggestEditEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'We will contact you only about this suggestion.'**
  String get spotDetailSuggestEditEmailHelper;

  /// No description provided for @spotDetailMustBeLoggedInToRate.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to rate spots'**
  String get spotDetailMustBeLoggedInToRate;

  /// No description provided for @spotDetailRatingSubmitted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Rating 1 star submitted!} other{Rating {count} stars submitted!}}'**
  String spotDetailRatingSubmitted(int count);

  /// No description provided for @spotDetailRatingSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit rating. Please try again.'**
  String get spotDetailRatingSubmitFailed;

  /// No description provided for @spotDetailRatingSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Error submitting rating: {error}'**
  String spotDetailRatingSubmitError(String error);

  /// No description provided for @spotDetailNotExternalSource.
  ///
  /// In en, this message translates to:
  /// **'This spot is not from an external source.'**
  String get spotDetailNotExternalSource;

  /// No description provided for @spotDetailMustBeLoggedInCreateNative.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to create a native spot.'**
  String get spotDetailMustBeLoggedInCreateNative;

  /// No description provided for @spotDetailCreateNativeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Native Spot'**
  String get spotDetailCreateNativeDialogTitle;

  /// No description provided for @spotDetailCreateNativeDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will create a new native spot based on this spot and mark the current spot as a duplicate of it. All spot data (name, description, location, photos, YouTube links, and attributes) will be copied to the new native spot.\n\nNote: Admins can remove spots and duplicate links can be removed if needed.'**
  String get spotDetailCreateNativeDialogBody;

  /// No description provided for @spotDetailCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get spotDetailCreateButton;

  /// No description provided for @spotDetailUnableCreateNativeNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to create native spot right now.'**
  String get spotDetailUnableCreateNativeNow;

  /// No description provided for @spotDetailFailedCreateNativeSpot.
  ///
  /// In en, this message translates to:
  /// **'Failed to create native spot'**
  String get spotDetailFailedCreateNativeSpot;

  /// No description provided for @spotDetailNativeCreatedDuplicateMarked.
  ///
  /// In en, this message translates to:
  /// **'Native spot created and current spot marked as duplicate.'**
  String get spotDetailNativeCreatedDuplicateMarked;

  /// No description provided for @spotDetailFailedMarkDuplicateGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to mark spot as duplicate'**
  String get spotDetailFailedMarkDuplicateGeneric;

  /// No description provided for @spotDetailErrorCreatingNativeSpot.
  ///
  /// In en, this message translates to:
  /// **'Error creating native spot: {error}'**
  String spotDetailErrorCreatingNativeSpot(String error);

  /// No description provided for @spotDetailUnableMarkDuplicateNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to mark this spot as duplicate right now.'**
  String get spotDetailUnableMarkDuplicateNow;

  /// No description provided for @spotDetailAlreadyMarkedDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This spot is already marked as a duplicate.'**
  String get spotDetailAlreadyMarkedDuplicate;

  /// No description provided for @spotDetailSpotMarkedDuplicateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Spot marked as duplicate.'**
  String get spotDetailSpotMarkedDuplicateSuccess;

  /// No description provided for @spotDetailErrorMarkingDuplicateSpot.
  ///
  /// In en, this message translates to:
  /// **'Error marking spot as duplicate: {error}'**
  String spotDetailErrorMarkingDuplicateSpot(String error);

  /// No description provided for @spotDetailModeratorsOnlyHideUnhide.
  ///
  /// In en, this message translates to:
  /// **'Only moderators can hide/unhide spots.'**
  String get spotDetailModeratorsOnlyHideUnhide;

  /// No description provided for @spotDetailHideSpotTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide Spot'**
  String get spotDetailHideSpotTitle;

  /// No description provided for @spotDetailUnhideSpotTitle.
  ///
  /// In en, this message translates to:
  /// **'Unhide Spot'**
  String get spotDetailUnhideSpotTitle;

  /// No description provided for @spotDetailHideSpotMessage.
  ///
  /// In en, this message translates to:
  /// **'This will hide the spot from public view. Hidden spots will not appear in search results or on the map, but the spot data will be preserved and can be unhidden later.'**
  String get spotDetailHideSpotMessage;

  /// No description provided for @spotDetailUnhideSpotMessage.
  ///
  /// In en, this message translates to:
  /// **'This will restore the spot to public view. The spot will appear in search results and on the map again.'**
  String get spotDetailUnhideSpotMessage;

  /// No description provided for @spotDetailActionHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get spotDetailActionHide;

  /// No description provided for @spotDetailActionUnhide.
  ///
  /// In en, this message translates to:
  /// **'Unhide'**
  String get spotDetailActionUnhide;

  /// No description provided for @spotDetailUnableHideUnhideNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to hide/unhide this spot right now.'**
  String get spotDetailUnableHideUnhideNow;

  /// No description provided for @spotDetailSpotHiddenSuccess.
  ///
  /// In en, this message translates to:
  /// **'Spot hidden successfully.'**
  String get spotDetailSpotHiddenSuccess;

  /// No description provided for @spotDetailSpotUnhiddenSuccess.
  ///
  /// In en, this message translates to:
  /// **'Spot unhidden successfully.'**
  String get spotDetailSpotUnhiddenSuccess;

  /// No description provided for @spotDetailFailedHideSpot.
  ///
  /// In en, this message translates to:
  /// **'Failed to hide spot'**
  String get spotDetailFailedHideSpot;

  /// No description provided for @spotDetailFailedUnhideSpot.
  ///
  /// In en, this message translates to:
  /// **'Failed to unhide spot'**
  String get spotDetailFailedUnhideSpot;

  /// No description provided for @spotDetailErrorHidingSpot.
  ///
  /// In en, this message translates to:
  /// **'Error hiding spot: {error}'**
  String spotDetailErrorHidingSpot(String error);

  /// No description provided for @spotDetailErrorUnhidingSpot.
  ///
  /// In en, this message translates to:
  /// **'Error unhiding spot: {error}'**
  String spotDetailErrorUnhidingSpot(String error);

  /// No description provided for @spotDetailNotMarkedAsDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This spot is not marked as a duplicate.'**
  String get spotDetailNotMarkedAsDuplicate;

  /// No description provided for @spotDetailModeratorsOnlyRemoveDuplicateStatus.
  ///
  /// In en, this message translates to:
  /// **'Only moderators can remove duplicate status.'**
  String get spotDetailModeratorsOnlyRemoveDuplicateStatus;

  /// No description provided for @spotDetailRemoveDuplicateDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove the duplicate status from this spot. The spot will no longer be marked as a duplicate.\n\nDo you want to continue?'**
  String get spotDetailRemoveDuplicateDialogBody;

  /// No description provided for @spotDetailRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get spotDetailRemoveButton;

  /// No description provided for @spotDetailUnableRemoveDuplicateStatusNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to remove duplicate status right now.'**
  String get spotDetailUnableRemoveDuplicateStatusNow;

  /// No description provided for @spotDetailDuplicateStatusRemovedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Duplicate status removed successfully.'**
  String get spotDetailDuplicateStatusRemovedSuccess;

  /// No description provided for @spotDetailFailedRemoveDuplicateStatusGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove duplicate status'**
  String get spotDetailFailedRemoveDuplicateStatusGeneric;

  /// No description provided for @spotDetailErrorRemovingDuplicateStatus.
  ///
  /// In en, this message translates to:
  /// **'Error removing duplicate status: {error}'**
  String spotDetailErrorRemovingDuplicateStatus(String error);

  /// No description provided for @spotDetailCheckingLinkedData.
  ///
  /// In en, this message translates to:
  /// **'Checking linked data...'**
  String get spotDetailCheckingLinkedData;

  /// No description provided for @spotDetailDeleteSpotDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Spot'**
  String get spotDetailDeleteSpotDialogTitle;

  /// No description provided for @spotDetailDeleteSpotConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this spot? This action cannot be undone.'**
  String get spotDetailDeleteSpotConfirmMessage;

  /// No description provided for @spotDetailLinkedDataHeading.
  ///
  /// In en, this message translates to:
  /// **'This spot has linked data:'**
  String get spotDetailLinkedDataHeading;

  /// No description provided for @spotDetailLinkedRatingsLine.
  ///
  /// In en, this message translates to:
  /// **'• Ratings: {count}'**
  String spotDetailLinkedRatingsLine(int count);

  /// No description provided for @spotDetailLinkedReportsLine.
  ///
  /// In en, this message translates to:
  /// **'• Spot reports: {count}'**
  String spotDetailLinkedReportsLine(int count);

  /// No description provided for @spotDetailLinkedDuplicatesLine.
  ///
  /// In en, this message translates to:
  /// **'• Duplicate spots: {count}'**
  String spotDetailLinkedDuplicatesLine(int count);

  /// No description provided for @spotDetailResolveLinksBeforeDelete.
  ///
  /// In en, this message translates to:
  /// **'Please resolve these links before deleting the spot.'**
  String get spotDetailResolveLinksBeforeDelete;

  /// No description provided for @spotDetailSpotDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Spot deleted successfully'**
  String get spotDetailSpotDeletedSuccess;

  /// No description provided for @spotDetailFailedDeleteSpot.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete spot'**
  String get spotDetailFailedDeleteSpot;

  /// No description provided for @spotDetailErrorDeletingSpot.
  ///
  /// In en, this message translates to:
  /// **'Error deleting spot: {error}'**
  String spotDetailErrorDeletingSpot(String error);

  /// No description provided for @spotDetailFlagDuplicateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Flag as duplicate'**
  String get spotDetailFlagDuplicateDialogTitle;

  /// No description provided for @spotDetailFlagDuplicateIntro.
  ///
  /// In en, this message translates to:
  /// **'This spot appears to be a duplicate of another spot. Please select the original spot below.'**
  String get spotDetailFlagDuplicateIntro;

  /// No description provided for @spotDetailFlagDuplicateWhichQuestion.
  ///
  /// In en, this message translates to:
  /// **'Which spot is this a duplicate of?'**
  String get spotDetailFlagDuplicateWhichQuestion;

  /// No description provided for @spotDetailDuplicateSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Paste spot URL or enter spot ID'**
  String get spotDetailDuplicateSearchHint;

  /// No description provided for @spotDetailSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get spotDetailSearch;

  /// No description provided for @spotDetailNearbySpotsWithin50m.
  ///
  /// In en, this message translates to:
  /// **'Nearby spots (within ~50m)'**
  String get spotDetailNearbySpotsWithin50m;

  /// No description provided for @spotDetailFoundSpot.
  ///
  /// In en, this message translates to:
  /// **'Found Spot'**
  String get spotDetailFoundSpot;

  /// No description provided for @spotDetailSpotIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Spot ID: {id}'**
  String spotDetailSpotIdLabel(String id);

  /// No description provided for @spotDetailRemoveSelectionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove selection'**
  String get spotDetailRemoveSelectionTooltip;

  /// No description provided for @spotDetailImageFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Image failed to load'**
  String get spotDetailImageFailedToLoad;

  /// No description provided for @spotDetailClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get spotDetailClose;

  /// No description provided for @spotDetailExpandMoreCount.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String spotDetailExpandMoreCount(int count);

  /// No description provided for @spotDetailSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get spotDetailSubmit;

  /// No description provided for @spotDetailDuplicateReportSelectRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select the spot this is a duplicate of.'**
  String get spotDetailDuplicateReportSelectRequired;

  /// No description provided for @spotDetailDuplicateSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a spot ID or URL'**
  String get spotDetailDuplicateSearchEmpty;

  /// No description provided for @spotDetailDuplicateInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid spot ID or URL format'**
  String get spotDetailDuplicateInvalidUrl;

  /// No description provided for @spotDetailDuplicateCannotSelectSelf.
  ///
  /// In en, this message translates to:
  /// **'Cannot mark a spot as duplicate of itself'**
  String get spotDetailDuplicateCannotSelectSelf;

  /// No description provided for @spotDetailDuplicateSpotNotFound.
  ///
  /// In en, this message translates to:
  /// **'Spot not found'**
  String get spotDetailDuplicateSpotNotFound;

  /// No description provided for @spotDetailDuplicateFailedLoadSpot.
  ///
  /// In en, this message translates to:
  /// **'Failed to load spot: {error}'**
  String spotDetailDuplicateFailedLoadSpot(String error);

  /// Source details dialog loading state
  ///
  /// In en, this message translates to:
  /// **'Loading source...'**
  String get sourceDetailsLoadingSource;

  /// Source details dialog generic error title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get sourceDetailsErrorTitle;

  /// Source details dialog missing source fallback
  ///
  /// In en, this message translates to:
  /// **'Source not found'**
  String get sourceDetailsNotFound;

  /// Source details: total number of imported spots label
  ///
  /// In en, this message translates to:
  /// **'Total Spots'**
  String get sourceDetailsTotalSpots;

  /// Source details: folders section label
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get sourceDetailsFolders;

  /// Source details: external source link button
  ///
  /// In en, this message translates to:
  /// **'Go to Source'**
  String get sourceDetailsGoToSource;

  /// Source details: created date label
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get sourceDetailsAdded;

  /// Source details: last import date label
  ///
  /// In en, this message translates to:
  /// **'Last Imported'**
  String get sourceDetailsLastImported;

  /// Relative time in days for source details
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day ago} other{{count} days ago}}'**
  String sourceDetailsRelativeDaysAgo(int count);

  /// Relative time in hours for source details
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 hour ago} other{{count} hours ago}}'**
  String sourceDetailsRelativeHoursAgo(int count);

  /// Relative time in minutes for source details
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 minute ago} other{{count} minutes ago}}'**
  String sourceDetailsRelativeMinutesAgo(int count);

  /// Relative time for very recent source updates
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get sourceDetailsRelativeJustNow;

  /// Event source details dialog loading state
  ///
  /// In en, this message translates to:
  /// **'Loading event source...'**
  String get eventSourceDetailsLoadingSource;

  /// Event source details: total number of imported events label
  ///
  /// In en, this message translates to:
  /// **'Total Events'**
  String get eventSourceDetailsTotalEvents;

  /// Short event count label for event source details
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 event} other{{count} events}}'**
  String exploreEventCountShort(int count);

  /// Prompt on spot tracking list pages when user is signed out
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your {listName} list'**
  String spotTrackingSignInToViewList(String listName);

  /// Empty state title for spot tracking list pages
  ///
  /// In en, this message translates to:
  /// **'No spots in {listName}'**
  String spotTrackingNoSpotsInList(String listName);

  /// Tooltip on list save button when list is not saved
  ///
  /// In en, this message translates to:
  /// **'Save list'**
  String get spotListSaveTooltipSaveList;

  /// Tooltip on list save button when list is already saved
  ///
  /// In en, this message translates to:
  /// **'Saved list'**
  String get spotListSaveTooltipSavedList;

  /// Title in save-list popup shown to signed-out users
  ///
  /// In en, this message translates to:
  /// **'Sign in to save lists'**
  String get spotListSaveSignInTitle;

  /// Description in save-list popup shown to signed-out users
  ///
  /// In en, this message translates to:
  /// **'Save someone else’s spot list to your profile so you can open it again later.'**
  String get spotListSaveSignInBody;

  /// Snackbar when a list is saved
  ///
  /// In en, this message translates to:
  /// **'List saved to your profile'**
  String get spotListSaveSavedToProfile;

  /// Snackbar when saving a list fails
  ///
  /// In en, this message translates to:
  /// **'Could not save list'**
  String get spotListSaveCouldNotSaveList;

  /// Snackbar when a list is removed from saved
  ///
  /// In en, this message translates to:
  /// **'Removed from saved lists'**
  String get spotListSaveRemovedFromSavedLists;

  /// Snackbar when unsaving a list fails
  ///
  /// In en, this message translates to:
  /// **'Could not remove list'**
  String get spotListSaveCouldNotRemoveList;

  /// Popup action to save list
  ///
  /// In en, this message translates to:
  /// **'Save list'**
  String get spotListSaveActionSaveList;

  /// Popup action to remove list from saved
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get spotListSaveActionRemoveFromSaved;

  /// Popup action to navigate to saved lists section
  ///
  /// In en, this message translates to:
  /// **'View saved lists'**
  String get spotListSaveActionViewSavedLists;

  /// Error message when list detail cannot load requested list
  ///
  /// In en, this message translates to:
  /// **'List not found or not accessible'**
  String get spotListDetailListNotFoundOrNotAccessible;

  /// Delete list confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete List'**
  String get spotListDetailDeleteListTitle;

  /// Delete list confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String spotListDetailDeleteListConfirmation(String name);

  /// Delete action label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get spotListDetailDeleteAction;

  /// Snackbar after deleting a list
  ///
  /// In en, this message translates to:
  /// **'List deleted'**
  String get spotListDetailListDeleted;

  /// Snackbar when deleting list fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete list'**
  String get spotListDetailFailedToDeleteList;

  /// Empty state title for list detail page
  ///
  /// In en, this message translates to:
  /// **'No spots in this list'**
  String get spotListDetailNoSpotsInThisList;

  /// Edit list dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit List'**
  String get spotListDetailEditListTitle;

  /// Edit list dialog label for optional external info URL
  ///
  /// In en, this message translates to:
  /// **'More info link (optional)'**
  String get spotListDetailMoreInfoLinkLabel;

  /// Edit list dialog hint for optional external info URL
  ///
  /// In en, this message translates to:
  /// **'https://…'**
  String get spotListDetailMoreInfoLinkHint;

  /// Edit list dialog helper text for optional external info URL
  ///
  /// In en, this message translates to:
  /// **'A page elsewhere on the web with more about this list'**
  String get spotListDetailMoreInfoLinkHelper;

  /// Validation error for list more-info URL field
  ///
  /// In en, this message translates to:
  /// **'More info link must be a valid URL (http or https), e.g. example.com or https://example.com/page'**
  String get spotListDetailMoreInfoLinkValidationError;

  /// Save action label in list edit flows
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get spotListDetailSave;

  /// Snackbar when list update succeeds
  ///
  /// In en, this message translates to:
  /// **'List updated'**
  String get spotListDetailListUpdated;

  /// Snackbar when list update fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update list'**
  String get spotListDetailFailedToUpdateList;

  /// List provenance visibility prefix
  ///
  /// In en, this message translates to:
  /// **'Public list'**
  String get spotListDetailVisibilityPublicList;

  /// List provenance visibility prefix
  ///
  /// In en, this message translates to:
  /// **'Unlisted list'**
  String get spotListDetailVisibilityUnlistedList;

  /// List provenance visibility prefix
  ///
  /// In en, this message translates to:
  /// **'Private list'**
  String get spotListDetailVisibilityPrivateList;

  /// Snackbar when creator profile navigation fails
  ///
  /// In en, this message translates to:
  /// **'Could not open profile'**
  String get spotListDetailCouldNotOpenProfile;

  /// First phrase in list provenance sentence
  ///
  /// In en, this message translates to:
  /// **'{visibility} created {date}'**
  String spotListDetailCreatedPart(String visibility, String date);

  /// Suffix before creator name in list provenance sentence (keep spaces)
  ///
  /// In en, this message translates to:
  /// **' by '**
  String get spotListDetailCreatedBySuffix;

  /// Suffix after creator in list provenance sentence
  ///
  /// In en, this message translates to:
  /// **', and last updated {date}.'**
  String spotListDetailLastUpdatedPart(String date);

  /// Legacy prefix for inline more-info links (prefer detailExternalLinkCaption)
  ///
  /// In en, this message translates to:
  /// **'More information on '**
  String get spotListDetailMoreInformationOn;

  /// Caption on external link tile on event and list detail pages
  ///
  /// In en, this message translates to:
  /// **'More information'**
  String get detailExternalLinkCaption;

  /// Accessibility label for external link tile
  ///
  /// In en, this message translates to:
  /// **'Open {host}'**
  String detailExternalLinkOpenSemantics(String host);

  /// Snackbar after copying list share text
  ///
  /// In en, this message translates to:
  /// **'List copied to clipboard!'**
  String get spotListDetailCopiedToClipboard;

  /// Snackbar when list copy fails
  ///
  /// In en, this message translates to:
  /// **'Failed to copy list: {error}'**
  String spotListDetailCopyFailed(String error);

  /// Hint badge shown on list mini-map
  ///
  /// In en, this message translates to:
  /// **'Highlight list on map'**
  String get spotListDetailHighlightListOnMap;

  /// Tooltip for list management menu button
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get spotListDetailEditListTooltip;

  /// List management menu item that enters inline list edit mode
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get spotListDetailMenuEditList;

  /// Title of unsaved list edits discard dialog
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get spotListEditDiscardTitle;

  /// Body of unsaved list edits discard dialog
  ///
  /// In en, this message translates to:
  /// **'Your edits to this list will be lost.'**
  String get spotListEditDiscardMessage;

  /// Confirm discarding unsaved list edits
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get spotListEditDiscardAction;

  /// Button to add a section while editing a list
  ///
  /// In en, this message translates to:
  /// **'Add section'**
  String get spotListEditAddSection;

  /// Spot list edit: add spots to the current section
  ///
  /// In en, this message translates to:
  /// **'Add spots'**
  String get spotListEditAddSpots;

  /// Spot list edit: tooltip for adding spots to a section
  ///
  /// In en, this message translates to:
  /// **'Add spots to this section'**
  String get spotListEditAddSpotsTooltip;

  /// Hint for optional section title in list edit mode
  ///
  /// In en, this message translates to:
  /// **'Section title (optional)'**
  String get spotListEditSectionTitleLabel;

  /// Hint for optional section body in list edit mode
  ///
  /// In en, this message translates to:
  /// **'Section text (optional)'**
  String get spotListEditSectionTextLabel;

  /// Empty-state action to add a section title while editing a list
  ///
  /// In en, this message translates to:
  /// **'Add title'**
  String get spotListEditAddSectionTitle;

  /// Tooltip to edit a section title and text
  ///
  /// In en, this message translates to:
  /// **'Edit section'**
  String get spotListEditEditSectionTooltip;

  /// Tooltip to finish editing a section title and text
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get spotListEditDoneSectionTooltip;

  /// Empty state inside a list section while editing
  ///
  /// In en, this message translates to:
  /// **'No spots in this section'**
  String get spotListEditNoSpotsInSection;

  /// Hint that empty sections are dropped on save
  ///
  /// In en, this message translates to:
  /// **'Empty sections will be removed when you save'**
  String get spotListEditEmptySectionsRemovedOnSave;

  /// Title of remove-spot confirmation
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get spotListEditRemoveSpotTitle;

  /// Body of remove-spot confirmation
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from this list?'**
  String spotListEditRemoveSpotMessage(String name);

  /// Confirm removing a spot from the list
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get spotListEditRemoveSpotAction;

  /// Tooltip for removing a spot while editing a list
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get spotListEditRemoveSpotTooltip;

  /// Tooltip to add a per-spot note
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get spotListEditAddNoteTooltip;

  /// Tooltip to edit a per-spot note
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get spotListEditEditNoteTooltip;

  /// Label for inline per-spot note field
  ///
  /// In en, this message translates to:
  /// **'Note for this spot'**
  String get spotListEditNoteLabel;

  /// Tooltip to clear a per-spot note while editing a list
  ///
  /// In en, this message translates to:
  /// **'Remove note'**
  String get spotListEditRemoveNoteTooltip;

  /// Tooltip to finish editing a per-spot note
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get spotListEditDoneNoteTooltip;

  /// Tooltip to delete a list section
  ///
  /// In en, this message translates to:
  /// **'Delete section'**
  String get spotListEditDeleteSectionTooltip;

  /// Title of delete-section confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete section?'**
  String get spotListEditDeleteSectionTitle;

  /// Body of delete-section confirmation
  ///
  /// In en, this message translates to:
  /// **'Spots in this section will be removed from the list.'**
  String get spotListEditDeleteSectionMessage;

  /// Semantics label for reorder drag handle
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get spotListEditDragHandleTooltip;

  /// Segmented control label for public list visibility
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get spotListEditVisibilityPublic;

  /// Segmented control label for unlisted list visibility
  ///
  /// In en, this message translates to:
  /// **'Unlisted'**
  String get spotListEditVisibilityUnlisted;

  /// Segmented control label for private list visibility
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get spotListEditVisibilityPrivate;

  /// Helper text for public list visibility
  ///
  /// In en, this message translates to:
  /// **'Listed on your profile and visible to everyone'**
  String get spotListEditVisibilityPublicHelp;

  /// Helper text for unlisted list visibility
  ///
  /// In en, this message translates to:
  /// **'Visible with a direct link, but hidden from your profile'**
  String get spotListEditVisibilityUnlistedHelp;

  /// Helper text for private list visibility
  ///
  /// In en, this message translates to:
  /// **'Only visible to you'**
  String get spotListEditVisibilityPrivateHelp;

  /// List management menu item
  ///
  /// In en, this message translates to:
  /// **'Delete List'**
  String get spotListDetailMenuDeleteList;

  /// Fallback page title for list detail
  ///
  /// In en, this message translates to:
  /// **'Spot List'**
  String get spotListDetailPageTitle;

  /// List detail not-found body text
  ///
  /// In en, this message translates to:
  /// **'List not found'**
  String get spotListDetailListNotFound;

  /// Fallback SEO description for list detail pages
  ///
  /// In en, this message translates to:
  /// **'A curated list of {count, plural, one{1 parkour spot} other{{count} parkour spots}} on Parkour·Spot'**
  String spotListDetailMetaDescriptionFallback(int count);

  /// Heading for linked upcoming event callout on spot or list detail
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Upcoming event} other{Upcoming events}}'**
  String detailUpcomingEventLabel(int count);

  /// Secondary action under upcoming-event callout to open the full list of other upcoming events
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 more event} other{{count} more events}}'**
  String detailUpcomingEventsAndMore(int count);

  /// Title for bottom sheet listing all upcoming events at a spot or list
  ///
  /// In en, this message translates to:
  /// **'Upcoming events'**
  String get detailUpcomingEventsSheetTitle;

  /// Page title for public profile screen
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get publicProfilePageTitle;

  /// Tooltip for profile share action
  ///
  /// In en, this message translates to:
  /// **'Share Profile'**
  String get publicProfileShareProfileTooltip;

  /// Error heading on public profile screen
  ///
  /// In en, this message translates to:
  /// **'Error loading profile'**
  String get publicProfileErrorLoadingProfile;

  /// Error hint on public profile screen
  ///
  /// In en, this message translates to:
  /// **'Please try again later'**
  String get publicProfilePleaseTryAgainLater;

  /// SEO description for a user profile page
  ///
  /// In en, this message translates to:
  /// **'View {name}\'s parkour spots and lists on Parkour·Spot — {defaultDescription}'**
  String publicProfileMetaDescription(String name, String defaultDescription);

  /// Heading when profile is missing or inaccessible
  ///
  /// In en, this message translates to:
  /// **'Profile not found'**
  String get publicProfileProfileNotFound;

  /// Body text when profile is missing or inaccessible
  ///
  /// In en, this message translates to:
  /// **'This profile does not exist or is private.'**
  String get publicProfileNotFoundOrPrivate;

  /// Member since line on public profile
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String publicProfileMemberSince(String date);

  /// Tooltip for opening profile settings sheet
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get publicProfileEditProfileTooltip;

  /// Card title for tracking lists section on own profile
  ///
  /// In en, this message translates to:
  /// **'Spot tracking'**
  String get publicProfileSpotTracking;

  /// Empty state title for tracking lists section
  ///
  /// In en, this message translates to:
  /// **'No spots yet'**
  String get publicProfileNoSpotsYet;

  /// Hint for how to populate tracking/lists sections
  ///
  /// In en, this message translates to:
  /// **'Add spots from spot detail pages'**
  String get publicProfileAddSpotsFromSpotDetailPages;

  /// Tracking list title
  ///
  /// In en, this message translates to:
  /// **'Been to'**
  String get publicProfileBeenTo;

  /// Row title to open check-in history
  ///
  /// In en, this message translates to:
  /// **'My training activity'**
  String get publicProfileMyCheckIns;

  /// Subtitle for check-in history row
  ///
  /// In en, this message translates to:
  /// **'Upcoming training plans and your check-in history'**
  String get publicProfileMyCheckInsSubtitle;

  /// Prompt shown on my check-ins page when signed out
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your check-ins and training plans'**
  String get myCheckInsSignInPrompt;

  /// Button label to load more check-ins
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get myCheckInsLoadMore;

  /// Empty state title on my check-ins page
  ///
  /// In en, this message translates to:
  /// **'No visits or plans yet'**
  String get myCheckInsEmptyTitle;

  /// Empty state helper text on my check-ins page
  ///
  /// In en, this message translates to:
  /// **'Open a spot to check in or plan training. Until the end time you set, others can see you as “here now” on that spot unless you keep it private.'**
  String get myCheckInsEmptyDescription;

  /// Introductory text at the top of my check-ins page
  ///
  /// In en, this message translates to:
  /// **'Training plans list upcoming sessions you scheduled at spots. A check-in records a visit—when you arrived and until when you expect to leave. Public entries can show you on a spot until the end time you set; private ones stay visible only to you.'**
  String get myCheckInsIntro;

  /// Section heading for planned training on my check-ins page
  ///
  /// In en, this message translates to:
  /// **'Upcoming training'**
  String get myCheckInsUpcomingPlansTitle;

  /// Section heading for past check-ins when plans are also shown
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get myCheckInsPastCheckInsTitle;

  /// Shown when the user has training plans but no check-in history
  ///
  /// In en, this message translates to:
  /// **'No check-ins recorded yet.'**
  String get myCheckInsNoCheckInsYet;

  /// Error when the check-in list failed to load but other content may show
  ///
  /// In en, this message translates to:
  /// **'Could not load check-ins.'**
  String get myCheckInsCheckInsLoadFailed;

  /// Fallback spot name in check-in history tile
  ///
  /// In en, this message translates to:
  /// **'Spot'**
  String get myCheckInsSpotFallback;

  /// Label shown for private check-ins in history
  ///
  /// In en, this message translates to:
  /// **'Private — only you can see this'**
  String get myCheckInsPrivateOnlyYou;

  /// Short day unit in check-in duration summary
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String myCheckInsDurationDaysShort(int count);

  /// Short hour unit in check-in duration summary
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String myCheckInsDurationHoursShort(int count);

  /// Short minute unit in check-in duration summary
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String myCheckInsDurationMinutesShort(int count);

  /// Card title for user's own lists section
  ///
  /// In en, this message translates to:
  /// **'Spot lists'**
  String get publicProfileSpotLists;

  /// Subheading for user's own lists in unified card
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get publicProfileYours;

  /// CTA in empty owned-lists state
  ///
  /// In en, this message translates to:
  /// **'Create your first list'**
  String get publicProfileCreateYourFirstList;

  /// Subheading for saved lists in unified card
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get publicProfileSaved;

  /// Card title when viewing someone else's profile lists
  ///
  /// In en, this message translates to:
  /// **'Public Spot Lists'**
  String get publicProfilePublicSpotLists;

  /// Empty state title for saved lists subsection
  ///
  /// In en, this message translates to:
  /// **'No saved lists yet'**
  String get publicProfileNoSavedListsYet;

  /// Empty state hint for saved lists subsection
  ///
  /// In en, this message translates to:
  /// **'Save lists you find on other users’ list pages'**
  String get publicProfileSaveListsHint;

  /// Message shown when saved IDs resolve to no accessible lists
  ///
  /// In en, this message translates to:
  /// **'Your saved lists are no longer available or were removed.'**
  String get publicProfileSavedListsUnavailable;

  /// Snackbar after creating a list from profile
  ///
  /// In en, this message translates to:
  /// **'List created successfully'**
  String get publicProfileListCreatedSuccessfully;

  /// Dialog title for profile picture actions
  ///
  /// In en, this message translates to:
  /// **'Change Profile Picture'**
  String get publicProfileChangeProfilePicture;

  /// Option in profile picture dialog
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get publicProfileChooseFromGallery;

  /// Option in profile picture dialog
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get publicProfileTakePhoto;

  /// Option in profile picture dialog
  ///
  /// In en, this message translates to:
  /// **'Remove Picture'**
  String get publicProfileRemovePicture;

  /// Snackbar when selecting gallery image fails
  ///
  /// In en, this message translates to:
  /// **'Error picking image: {error}'**
  String publicProfileErrorPickingImage(String error);

  /// Snackbar when camera capture fails
  ///
  /// In en, this message translates to:
  /// **'Error taking photo: {error}'**
  String publicProfileErrorTakingPhoto(String error);

  /// Progress status while handling profile image
  ///
  /// In en, this message translates to:
  /// **'Processing image...'**
  String get publicProfileProcessingImage;

  /// Progress status while reading selected image
  ///
  /// In en, this message translates to:
  /// **'Reading image...'**
  String get publicProfileReadingImage;

  /// Progress status while uploading profile image
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get publicProfileUploading;

  /// Progress status near completion of profile image upload
  ///
  /// In en, this message translates to:
  /// **'Finishing...'**
  String get publicProfileFinishing;

  /// Progress status while updating user document
  ///
  /// In en, this message translates to:
  /// **'Updating profile...'**
  String get publicProfileUpdatingProfile;

  /// Snackbar after successful profile picture update
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated successfully'**
  String get publicProfileProfilePictureUpdatedSuccessfully;

  /// Snackbar when profile picture update fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture'**
  String get publicProfileFailedToUpdateProfilePicture;

  /// Snackbar when profile picture upload throws
  ///
  /// In en, this message translates to:
  /// **'Error uploading profile picture: {error}'**
  String publicProfileErrorUploadingProfilePicture(String error);

  /// Confirmation dialog title for removing profile picture
  ///
  /// In en, this message translates to:
  /// **'Remove Profile Picture'**
  String get publicProfileRemoveProfilePicture;

  /// Confirmation dialog body for removing profile picture
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove your profile picture?'**
  String get publicProfileRemoveProfilePictureConfirmation;

  /// Snackbar after profile picture removal succeeds
  ///
  /// In en, this message translates to:
  /// **'Profile picture removed successfully'**
  String get publicProfileProfilePictureRemovedSuccessfully;

  /// Snackbar when removing profile picture fails
  ///
  /// In en, this message translates to:
  /// **'Failed to remove profile picture'**
  String get publicProfileFailedToRemoveProfilePicture;

  /// Snackbar when removing profile picture throws
  ///
  /// In en, this message translates to:
  /// **'Error removing profile picture: {error}'**
  String publicProfileErrorRemovingProfilePicture(String error);

  /// Snackbar after profile URL copy succeeds
  ///
  /// In en, this message translates to:
  /// **'Profile copied to clipboard!'**
  String get publicProfileProfileCopiedToClipboard;

  /// Snackbar when sharing/copying profile fails
  ///
  /// In en, this message translates to:
  /// **'Failed to copy profile: {error}'**
  String publicProfileFailedToCopyProfile(String error);

  /// Stats label for spots created
  ///
  /// In en, this message translates to:
  /// **'Spots'**
  String get publicProfileStatsSpots;

  /// Stats label for ratings given
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get publicProfileStatsRatings;

  /// Bottom sheet title for editing profile
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get publicProfileSettingsTitle;

  /// Profile settings: email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get publicProfileEmailLabel;

  /// Profile settings: email privacy hint
  ///
  /// In en, this message translates to:
  /// **'Your email is not shown on your public profile.'**
  String get publicProfileEmailNotShownHint;

  /// Profile settings: display name label
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get publicProfileDisplayNameLabel;

  /// Profile settings: fallback when display name is empty
  ///
  /// In en, this message translates to:
  /// **'No display name set'**
  String get publicProfileNoDisplayNameSet;

  /// Generic edit action in profile settings
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get publicProfileEditAction;

  /// Profile settings: display name input hint
  ///
  /// In en, this message translates to:
  /// **'Enter your display name'**
  String get publicProfileDisplayNameHint;

  /// Profile settings: display name helper
  ///
  /// In en, this message translates to:
  /// **'Shown on your profile and spots you create (max {max} characters)'**
  String publicProfileDisplayNameHelper(int max);

  /// Validation error when display name exceeds max length
  ///
  /// In en, this message translates to:
  /// **'Display name must be at most {max} characters'**
  String publicProfileDisplayNameMaxLengthError(int max);

  /// Snackbar when display name update succeeds
  ///
  /// In en, this message translates to:
  /// **'Display name updated successfully'**
  String get publicProfileDisplayNameUpdated;

  /// Snackbar when display name is removed
  ///
  /// In en, this message translates to:
  /// **'Display name removed'**
  String get publicProfileDisplayNameRemoved;

  /// Validation/error text when display name update fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update display name'**
  String get publicProfileDisplayNameUpdateFailed;

  /// Generic save action in profile settings
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get publicProfileSaveAction;

  /// Profile settings: username label
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get publicProfileUsernameLabel;

  /// Profile settings: fallback when username is empty
  ///
  /// In en, this message translates to:
  /// **'No username set'**
  String get publicProfileNoUsernameSet;

  /// Profile settings: username input hint
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get publicProfileUsernameHint;

  /// Profile settings: username helper text
  ///
  /// In en, this message translates to:
  /// **'3-27 characters, letters, numbers, underscores, and hyphens only'**
  String get publicProfileUsernameHelper;

  /// Validation error when username input is empty
  ///
  /// In en, this message translates to:
  /// **'Username cannot be empty'**
  String get publicProfileUsernameEmpty;

  /// Validation error when username is not available
  ///
  /// In en, this message translates to:
  /// **'Username is already taken'**
  String get publicProfileUsernameTaken;

  /// Snackbar when username update succeeds
  ///
  /// In en, this message translates to:
  /// **'Username updated successfully'**
  String get publicProfileUsernameUpdated;

  /// Fallback error when username update fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update username'**
  String get publicProfileUsernameUpdateFailed;

  /// Profile settings: instagram section title
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get publicProfileInstagramLabel;

  /// Profile settings: fallback when instagram link is empty
  ///
  /// In en, this message translates to:
  /// **'No Instagram link set'**
  String get publicProfileNoInstagramSet;

  /// Generic add action in profile settings
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get publicProfileAddAction;

  /// Profile settings: instagram URL field label
  ///
  /// In en, this message translates to:
  /// **'Instagram Link'**
  String get publicProfileInstagramLinkLabel;

  /// Profile settings: instagram URL field hint
  ///
  /// In en, this message translates to:
  /// **'https://www.instagram.com/your_handle/'**
  String get publicProfileInstagramLinkHint;

  /// Profile settings: instagram URL helper text
  ///
  /// In en, this message translates to:
  /// **'You can also paste @handle or just the handle'**
  String get publicProfileInstagramLinkHelper;

  /// Validation error for instagram input
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Instagram profile URL or handle'**
  String get publicProfileInstagramInvalid;

  /// Snackbar when instagram link is removed
  ///
  /// In en, this message translates to:
  /// **'Instagram link removed'**
  String get publicProfileInstagramRemoved;

  /// Snackbar when instagram link update succeeds
  ///
  /// In en, this message translates to:
  /// **'Instagram link updated successfully'**
  String get publicProfileInstagramUpdated;

  /// Validation/error text when instagram update fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update Instagram link'**
  String get publicProfileInstagramUpdateFailed;

  /// Profile settings: privacy section title
  ///
  /// In en, this message translates to:
  /// **'Profile Privacy'**
  String get publicProfilePrivacyTitle;

  /// Profile settings: label when profile is public
  ///
  /// In en, this message translates to:
  /// **'Public Profile'**
  String get publicProfilePrivacyPublicLabel;

  /// Profile settings: label when profile is private
  ///
  /// In en, this message translates to:
  /// **'Private Profile'**
  String get publicProfilePrivacyPrivateLabel;

  /// Profile settings: explanation when profile is public
  ///
  /// In en, this message translates to:
  /// **'Your profile is visible to everyone'**
  String get publicProfilePrivacyPublicDescription;

  /// Profile settings: explanation when profile is private
  ///
  /// In en, this message translates to:
  /// **'Your profile is private and not visible to others'**
  String get publicProfilePrivacyPrivateDescription;

  /// Snackbar when privacy toggled to public
  ///
  /// In en, this message translates to:
  /// **'Profile is now public'**
  String get publicProfilePrivacyNowPublic;

  /// Snackbar when privacy toggled to private
  ///
  /// In en, this message translates to:
  /// **'Profile is now private'**
  String get publicProfilePrivacyNowPrivate;

  /// Snackbar when privacy toggle update fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile privacy'**
  String get publicProfileFailedToUpdateProfilePrivacy;

  /// Event detail page failed to load
  ///
  /// In en, this message translates to:
  /// **'Error loading event'**
  String get eventDetailRouteErrorLoading;

  /// Event detail load error subtitle
  ///
  /// In en, this message translates to:
  /// **'Please try again later'**
  String get eventDetailRouteTryAgainLater;

  /// Event document missing
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get eventDetailRouteNotFound;

  /// Navigate away from missing event
  ///
  /// In en, this message translates to:
  /// **'Go to Explore'**
  String get eventDetailRouteGoToExplore;

  /// Label for event start in a multi-day schedule
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get eventDetailStartsLabel;

  /// Label before event end date/time
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get eventDetailEndsLabel;

  /// Section label for event address or coordinates
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eventDetailLocationLabel;

  /// Button to open event location in maps app
  ///
  /// In en, this message translates to:
  /// **'Open in maps'**
  String get eventDetailOpenInMaps;

  /// Section heading for spots tied to this event
  ///
  /// In en, this message translates to:
  /// **'Linked spots'**
  String get eventDetailLinkedSpotsLabel;

  /// Empty state when linked spot ids do not resolve
  ///
  /// In en, this message translates to:
  /// **'No linked spots found.'**
  String get eventDetailNoLinkedSpots;

  /// Section heading for spot lists tied to this event
  ///
  /// In en, this message translates to:
  /// **'Linked spot lists'**
  String get eventDetailLinkedSpotListsLabel;

  /// Empty state when linked spot list ids do not resolve
  ///
  /// In en, this message translates to:
  /// **'No linked spot lists found.'**
  String get eventDetailNoLinkedSpotLists;

  /// Section heading for the event spot list map
  ///
  /// In en, this message translates to:
  /// **'Spots for this event'**
  String get eventDetailEventSpotsLabel;

  /// Empty state when the event spot list id does not resolve
  ///
  /// In en, this message translates to:
  /// **'Event spot list not found.'**
  String get eventDetailNoEventSpots;

  /// Open the full event spot list detail page
  ///
  /// In en, this message translates to:
  /// **'View spot list'**
  String get eventDetailEventSpotListViewAll;

  /// Highlight the event spot list on Explore
  ///
  /// In en, this message translates to:
  /// **'See on map'**
  String get eventDetailEventSpotListSeeOnMap;

  /// How many additional spots are in the event list beyond the preview
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String eventDetailEventSpotListMoreSpots(int count);

  /// Section heading for individually linked event spots when a spot list is also present
  ///
  /// In en, this message translates to:
  /// **'Event locations'**
  String get eventDetailEventSpotLocationsLabel;

  /// Empty state when directly linked event spot ids do not resolve
  ///
  /// In en, this message translates to:
  /// **'Event spots not found.'**
  String get eventDetailNoEventSpotLocations;

  /// Open a directly linked event spot detail page
  ///
  /// In en, this message translates to:
  /// **'View spot'**
  String get eventDetailEventSpotViewDetails;

  /// Title for admin edit event screen
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get adminEventEditTitle;

  /// Save button on admin edit event screen
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get adminEventEditSave;

  /// Banner title when editing an imported event
  ///
  /// In en, this message translates to:
  /// **'External calendar event'**
  String get adminEventExternalSyncWarningTitle;

  /// Banner body when editing an imported event
  ///
  /// In en, this message translates to:
  /// **'The next sync may overwrite the title, schedule, description, and venue address or coordinates from the external feed. Linked spots and spot lists are managed here and are not cleared by sync.'**
  String get adminEventExternalSyncWarningBody;

  /// Section title for spot lists linked to an event in admin form
  ///
  /// In en, this message translates to:
  /// **'Linked spot lists'**
  String get adminEventLinkedSpotListsTitle;

  /// Button to link a spot list to an event
  ///
  /// In en, this message translates to:
  /// **'Add list'**
  String get adminEventAddSpotList;

  /// Empty state for linked spot lists in admin event form
  ///
  /// In en, this message translates to:
  /// **'No spot lists selected yet'**
  String get adminEventNoLinkedSpotLists;

  /// Title for spot list selection dialog
  ///
  /// In en, this message translates to:
  /// **'Select spot list'**
  String get adminSpotListSelectionTitle;

  /// Input label for spot list selection dialog
  ///
  /// In en, this message translates to:
  /// **'List ID or URL'**
  String get adminSpotListSelectionInputLabel;

  /// Input hint for spot list selection dialog
  ///
  /// In en, this message translates to:
  /// **'list-id or https://parkour.spot/list/…'**
  String get adminSpotListSelectionInputHint;

  /// Button to look up a spot list by id or URL
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get adminSpotListSelectionLookup;

  /// Confirm spot list selection
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get adminSpotListSelectionSelect;

  /// Error when spot list lookup input is invalid
  ///
  /// In en, this message translates to:
  /// **'Enter a list ID or a /list/… URL'**
  String get adminSpotListSelectionInvalidInput;

  /// Error when spot list lookup fails
  ///
  /// In en, this message translates to:
  /// **'Spot list not found or not accessible'**
  String get adminSpotListSelectionNotFound;

  /// Error when admin tries to link a private list
  ///
  /// In en, this message translates to:
  /// **'Private lists cannot be linked to events'**
  String get adminSpotListSelectionPrivateList;

  /// Generic error when spot list lookup fails
  ///
  /// In en, this message translates to:
  /// **'Could not load the spot list'**
  String get adminSpotListSelectionLoadFailed;

  /// Subtitle after a spot list is found in selection dialog
  ///
  /// In en, this message translates to:
  /// **'{visibility} · {count} spots'**
  String adminSpotListSelectionFoundSubtitle(String visibility, int count);

  /// Admin menu item to edit an event
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get eventDetailAdminEditEvent;

  /// Subtitle when edit is disabled because the event is from an external source
  ///
  /// In en, this message translates to:
  /// **'Create native event first'**
  String get eventDetailMenuEditEventSubtitleNative;

  /// Subtitle on enabled edit event menu item for staff
  ///
  /// In en, this message translates to:
  /// **'Moderator only'**
  String get eventDetailMenuEditEventSubtitleMod;

  /// Shown when a moderator tries to edit an imported calendar event
  ///
  /// In en, this message translates to:
  /// **'Events from external sources cannot be edited. Please create a native event first using “Mark as Duplicate” → “Create native event”.'**
  String get eventDetailExternalSourceCannotEdit;

  /// Label for external calendar source name
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get eventDetailSourceLabel;

  /// Tooltip for admin actions menu on event detail
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get eventDetailAdminMenuTooltip;

  /// Tooltip for staff actions menu on event detail
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get eventDetailStaffMenuTooltip;

  /// Staff menu item to create a native copy of an external event
  ///
  /// In en, this message translates to:
  /// **'Create native event'**
  String get eventDetailMenuCreateNative;

  /// Subtitle for create native event menu item
  ///
  /// In en, this message translates to:
  /// **'Copy from external source'**
  String get eventDetailMenuCreateNativeSubtitle;

  /// Subtitle on enabled suggest photo menu item
  ///
  /// In en, this message translates to:
  /// **'Submit photos for this event'**
  String get eventDetailMenuSuggestPhotoSubtitleYes;

  /// Subtitle on disabled suggest photo menu item
  ///
  /// In en, this message translates to:
  /// **'Not available for duplicates'**
  String get eventDetailMenuSuggestPhotoSubtitleNo;

  /// Subtitle on enabled suggest edit menu item
  ///
  /// In en, this message translates to:
  /// **'Propose changes to this event'**
  String get eventDetailMenuSuggestEditSubtitleYes;

  /// Subtitle on disabled suggest edit menu item
  ///
  /// In en, this message translates to:
  /// **'Not available for duplicates'**
  String get eventDetailMenuSuggestEditSubtitleNo;

  /// Short subtitle when suggestions are temporarily blocked
  ///
  /// In en, this message translates to:
  /// **'Unavailable right now'**
  String get eventDetailMenuSuggestBlockedUnavailable;

  /// Confirmation dialog title for create native event
  ///
  /// In en, this message translates to:
  /// **'Create native event'**
  String get eventDetailCreateNativeDialogTitle;

  /// Confirmation dialog body for create native event
  ///
  /// In en, this message translates to:
  /// **'This will create a new native event based on this event and mark the current event as a duplicate of it. Event data (title, description, schedule, location, images, website, and linked spots) will be copied to the new native event.'**
  String get eventDetailCreateNativeDialogBody;

  /// Error when create native is attempted on a native event
  ///
  /// In en, this message translates to:
  /// **'This event is not from an external source.'**
  String get eventDetailNotExternalSource;

  /// Error when unauthenticated user tries create native event
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to create a native event.'**
  String get eventDetailMustBeLoggedInCreateNative;

  /// Error when event id is missing for create native
  ///
  /// In en, this message translates to:
  /// **'Unable to create native event right now.'**
  String get eventDetailUnableCreateNativeNow;

  /// Error when create native event Firestore write fails
  ///
  /// In en, this message translates to:
  /// **'Failed to create native event'**
  String get eventDetailFailedCreateNative;

  /// Success snackbar after create native event flow
  ///
  /// In en, this message translates to:
  /// **'Native event created and current event marked as duplicate.'**
  String get eventDetailNativeCreatedDuplicateMarked;

  /// Helper text in event duplicate picker dialog
  ///
  /// In en, this message translates to:
  /// **'Only native events can be selected. If you need to create a native event from an external source event, use \"Create native event\" from the event menu.'**
  String get eventDetailMarkDuplicateNativeOnlyHint;

  /// Event provenance: native event with creator and created date
  ///
  /// In en, this message translates to:
  /// **'Event created {date} by '**
  String eventDetailEventCreatedOnDateBy(String date);

  /// Event provenance: native event with creator, no created date
  ///
  /// In en, this message translates to:
  /// **'Event created by '**
  String get eventDetailEventCreatedBy;

  /// Event provenance: native event with created date only
  ///
  /// In en, this message translates to:
  /// **'Event created {date}'**
  String eventDetailEventCreatedOnDate(String date);

  /// Event provenance: synced event with first-seen date
  ///
  /// In en, this message translates to:
  /// **'Event imported {date} from '**
  String eventDetailEventImportedOnDateFrom(String date);

  /// Event provenance: synced event without created date
  ///
  /// In en, this message translates to:
  /// **'Event imported from '**
  String get eventDetailEventImportedFrom;

  /// Event detail: title unknown while loading duplicate original
  ///
  /// In en, this message translates to:
  /// **'Original event'**
  String get eventDetailOriginalEventFallback;

  /// Heading when viewing an event marked as a duplicate
  ///
  /// In en, this message translates to:
  /// **'Duplicate listing'**
  String get eventDetailDuplicateBannerTitle;

  /// Explanation on duplicate event detail pages
  ///
  /// In en, this message translates to:
  /// **'This listing is marked as a duplicate. Open the main event for the canonical details.'**
  String get eventDetailDuplicateBannerBody;

  /// Collapsible section heading for events marked as duplicates of this one
  ///
  /// In en, this message translates to:
  /// **'Duplicate listings'**
  String get eventDetailLinkedDuplicatesHeading;

  /// Shown when a non-staff user opens staff-only duplicate action
  ///
  /// In en, this message translates to:
  /// **'Only staff can manage event duplicates.'**
  String get eventDetailMarkDuplicateStaffOnly;

  /// No description provided for @eventDetailMenuHideEvent.
  ///
  /// In en, this message translates to:
  /// **'Hide event'**
  String get eventDetailMenuHideEvent;

  /// No description provided for @eventDetailMenuHideEventSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide from public view'**
  String get eventDetailMenuHideEventSubtitle;

  /// No description provided for @eventDetailMenuUnhideEvent.
  ///
  /// In en, this message translates to:
  /// **'Unhide event'**
  String get eventDetailMenuUnhideEvent;

  /// No description provided for @eventDetailMenuUnhideEventSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show to public again'**
  String get eventDetailMenuUnhideEventSubtitle;

  /// No description provided for @eventDetailHiddenBanner.
  ///
  /// In en, this message translates to:
  /// **'This event is hidden from public view. It likely no longer exists or doesn’t meet our policies. It will not appear in search results or on the map.'**
  String get eventDetailHiddenBanner;

  /// No description provided for @eventDetailModeratorsOnlyHideUnhide.
  ///
  /// In en, this message translates to:
  /// **'Only moderators can hide/unhide events.'**
  String get eventDetailModeratorsOnlyHideUnhide;

  /// No description provided for @eventDetailHideEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide Event'**
  String get eventDetailHideEventTitle;

  /// No description provided for @eventDetailUnhideEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Unhide Event'**
  String get eventDetailUnhideEventTitle;

  /// No description provided for @eventDetailHideEventMessage.
  ///
  /// In en, this message translates to:
  /// **'This will hide the event from public view. Hidden events will not appear in search results or on the map, but the event data will be preserved and can be unhidden later.'**
  String get eventDetailHideEventMessage;

  /// No description provided for @eventDetailUnhideEventMessage.
  ///
  /// In en, this message translates to:
  /// **'This will restore the event to public view. The event will appear in search results and on the map again.'**
  String get eventDetailUnhideEventMessage;

  /// No description provided for @eventDetailUnableHideUnhideNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to hide/unhide this event right now.'**
  String get eventDetailUnableHideUnhideNow;

  /// No description provided for @eventDetailEventHiddenSuccess.
  ///
  /// In en, this message translates to:
  /// **'Event hidden successfully.'**
  String get eventDetailEventHiddenSuccess;

  /// No description provided for @eventDetailEventUnhiddenSuccess.
  ///
  /// In en, this message translates to:
  /// **'Event unhidden successfully.'**
  String get eventDetailEventUnhiddenSuccess;

  /// No description provided for @eventDetailFailedHideEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to hide event'**
  String get eventDetailFailedHideEvent;

  /// No description provided for @eventDetailFailedUnhideEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to unhide event'**
  String get eventDetailFailedUnhideEvent;

  /// Event selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Mark as duplicate of native event'**
  String get eventDetailMarkDuplicatePickNativeTitle;

  /// Hint for finding canonical event by name, id, or link
  ///
  /// In en, this message translates to:
  /// **'Event name, URL, or ID'**
  String get eventDetailMarkDuplicateSearchHint;

  /// Invalid search input for event duplicate picker
  ///
  /// In en, this message translates to:
  /// **'Pick a matching event from the list, or enter a valid event id or /event/… link.'**
  String get eventDetailMarkDuplicateNotFoundOrInvalid;

  /// Chosen original has an external calendar source
  ///
  /// In en, this message translates to:
  /// **'That event is not a native parkour.spot event. Only native events can be the original.'**
  String get eventDetailMarkDuplicateTargetNotNative;

  /// Chosen original is itself a duplicate
  ///
  /// In en, this message translates to:
  /// **'That event is already marked as a duplicate of another event.'**
  String get eventDetailMarkDuplicateTargetIsDuplicate;

  /// Confirm picked search result in duplicate dialog
  ///
  /// In en, this message translates to:
  /// **'Use this event'**
  String get eventDetailMarkDuplicateUseButton;

  /// Section header in duplicate picker
  ///
  /// In en, this message translates to:
  /// **'Native events around these dates'**
  String get eventDetailMarkDuplicateSuggestionsHeader;

  /// Empty suggestions in duplicate picker
  ///
  /// In en, this message translates to:
  /// **'No native events found within a week of this event\'s dates.'**
  String get eventDetailMarkDuplicateNoSuggestions;

  /// Confirm marking duplicate; title is canonical event name
  ///
  /// In en, this message translates to:
  /// **'Mark this event as a duplicate of “{title}”?'**
  String eventDetailMarkDuplicateConfirmBody(String title);

  /// Title of the event duplicate transfer/confirm dialog
  ///
  /// In en, this message translates to:
  /// **'Mark as Duplicate'**
  String get eventDetailMarkDuplicateTitle;

  /// Body of the event duplicate transfer dialog; title is the original event
  ///
  /// In en, this message translates to:
  /// **'Mark this event as a duplicate of “{title}”? This action can be reversed later.'**
  String eventDetailMarkDuplicateBody(String title);

  /// Section header for additive merge options
  ///
  /// In en, this message translates to:
  /// **'Select which items to add to the original event:'**
  String get eventDetailMarkDuplicateAddToOriginal;

  /// Checkbox to append photos from the duplicate
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get eventDetailMarkDuplicatePhotos;

  /// Checkbox to union linked spots and spot lists
  ///
  /// In en, this message translates to:
  /// **'Linked spots'**
  String get eventDetailMarkDuplicateLinkedSpots;

  /// Section header for overwrite merge options
  ///
  /// In en, this message translates to:
  /// **'Select which items to overwrite in the original event (if set):'**
  String get eventDetailMarkDuplicateOverwrite;

  /// Checkbox to overwrite event title
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get eventDetailMarkDuplicateEventTitle;

  /// Checkbox to overwrite event description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get eventDetailMarkDuplicateDescription;

  /// Checkbox to overwrite event location
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eventDetailMarkDuplicateLocation;

  /// Checkbox to overwrite event dates and timezone
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get eventDetailMarkDuplicateSchedule;

  /// Checkbox to overwrite event website URL
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get eventDetailMarkDuplicateWebsite;

  /// Snackbar after duplicate link saved
  ///
  /// In en, this message translates to:
  /// **'Event marked as duplicate.'**
  String get eventDetailMarkDuplicateSuccess;

  /// Confirm clearing duplicateOf
  ///
  /// In en, this message translates to:
  /// **'Remove duplicate status from this event? It will no longer point to another event as its original.'**
  String get eventDetailRemoveDuplicateConfirmBody;

  /// Snackbar after duplicate cleared
  ///
  /// In en, this message translates to:
  /// **'Duplicate status removed.'**
  String get eventDetailRemoveDuplicateSuccess;

  /// Snackbar after event share URL copied
  ///
  /// In en, this message translates to:
  /// **'Event copied to clipboard!'**
  String get eventDetailCopiedToClipboard;

  /// Share or clipboard error on event detail
  ///
  /// In en, this message translates to:
  /// **'Failed to share event: {error}'**
  String eventDetailShareFailed(String error);

  /// Quick action label for suggesting event photos
  ///
  /// In en, this message translates to:
  /// **'Suggest photo'**
  String get eventDetailQuickActionSuggestPhoto;

  /// Quick action label for suggesting event edits
  ///
  /// In en, this message translates to:
  /// **'Suggest an edit'**
  String get eventDetailQuickActionSuggestEdit;

  /// Shown when event suggestion cannot open
  ///
  /// In en, this message translates to:
  /// **'Unable to suggest changes for this event right now.'**
  String get eventDetailUnableSuggestNow;

  /// Shown when trying to suggest on duplicate events
  ///
  /// In en, this message translates to:
  /// **'Cannot suggest changes for duplicate events.'**
  String get eventDetailCannotSuggestForDuplicate;

  /// Shown when trying to suggest on external events
  ///
  /// In en, this message translates to:
  /// **'Cannot suggest changes for externally sourced events. Create a native event first.'**
  String get eventDetailCannotSuggestForExternal;

  /// Success message after submitting event photo suggestion
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your photo suggestion has been submitted for review.'**
  String get eventDetailThanksPhotoSuggestion;

  /// Success message after submitting event edit suggestion
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your edit suggestion has been submitted for review.'**
  String get eventDetailThanksEditSuggestion;

  /// Event detail menu: flag as duplicate
  ///
  /// In en, this message translates to:
  /// **'Flag as duplicate'**
  String get eventDetailMenuFlagDuplicate;

  /// Event detail menu subtitle when duplicate flag is available
  ///
  /// In en, this message translates to:
  /// **'This event is a duplicate'**
  String get eventDetailMenuFlagDuplicateSubtitleYes;

  /// Event detail menu subtitle when event is already a duplicate
  ///
  /// In en, this message translates to:
  /// **'Already marked as duplicate'**
  String get eventDetailMenuFlagDuplicateSubtitleNo;

  /// Dialog title for flagging an event as duplicate
  ///
  /// In en, this message translates to:
  /// **'Flag as duplicate'**
  String get eventDetailFlagDuplicateDialogTitle;

  /// Dialog intro for flagging an event as duplicate
  ///
  /// In en, this message translates to:
  /// **'This event appears to be a duplicate of another event. Select the original event below.'**
  String get eventDetailFlagDuplicateIntro;

  /// Dialog question for picking duplicate original event
  ///
  /// In en, this message translates to:
  /// **'Which event is this a duplicate of?'**
  String get eventDetailFlagDuplicateWhichQuestion;

  /// Header for permissive duplicate report date suggestions
  ///
  /// In en, this message translates to:
  /// **'Events around these dates'**
  String get eventDetailFlagDuplicateSuggestionsHeader;

  /// Success message after submitting event duplicate suggestion
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your duplicate suggestion has been submitted for review.'**
  String get eventDetailThanksDuplicateSuggestion;

  /// Error when event duplicate flag cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Unable to flag this event as duplicate right now.'**
  String get eventDetailUnableFlagDuplicate;

  /// Validation when no original event selected for duplicate report
  ///
  /// In en, this message translates to:
  /// **'Please select the original event.'**
  String get eventDetailDuplicateReportSelectRequired;

  /// Chip label for duplicate event reports in moderator queue
  ///
  /// In en, this message translates to:
  /// **'Duplicate suggestion'**
  String get eventReportQueueDuplicateSuggestion;

  /// Approve button for duplicate event reports
  ///
  /// In en, this message translates to:
  /// **'Approve duplicate link'**
  String get eventReportQueueApproveDuplicate;

  /// Link to user-suggested original event in moderator queue
  ///
  /// In en, this message translates to:
  /// **'Open suggested original event'**
  String get eventReportQueueOpenOriginalEvent;

  /// Hint when approving duplicate report with external suggested original
  ///
  /// In en, this message translates to:
  /// **'The user suggested an event from an external source. Pick the native parkour.spot event that should be the canonical original.'**
  String get eventDuplicateApprovalExternalOriginalHint;

  /// Prompt for moderator to select native original when approving duplicate report
  ///
  /// In en, this message translates to:
  /// **'Pick the native event to use as the canonical original.'**
  String get eventDuplicateApprovalPickNativeTitle;

  /// Dialog title for event photo suggestions
  ///
  /// In en, this message translates to:
  /// **'Suggest photos'**
  String get eventDetailSuggestPhotosTitle;

  /// Dialog intro for event photo suggestions
  ///
  /// In en, this message translates to:
  /// **'Upload photos for this event. Moderators will review your suggestion.'**
  String get eventDetailSuggestPhotosIntro;

  /// Validation when no photos selected for event photo suggestion
  ///
  /// In en, this message translates to:
  /// **'Please add at least one photo.'**
  String get eventDetailSuggestPhotosPickRequired;

  /// General failure message for event photo suggestion submit
  ///
  /// In en, this message translates to:
  /// **'Failed to submit photo suggestion. Please try again.'**
  String get eventDetailSuggestPhotosSubmitFailed;

  /// Error detail for event photo suggestion submit
  ///
  /// In en, this message translates to:
  /// **'Error submitting photo suggestion: {error}'**
  String eventDetailSuggestPhotosSubmitError(String error);

  /// Dialog title for event edit suggestions
  ///
  /// In en, this message translates to:
  /// **'Suggest an edit'**
  String get eventDetailSuggestEditTitle;

  /// Dialog intro for event edit suggestions
  ///
  /// In en, this message translates to:
  /// **'Propose updates to this event. Moderators will review your suggestion.'**
  String get eventDetailSuggestEditIntro;

  /// Validation when no edit fields changed
  ///
  /// In en, this message translates to:
  /// **'Please suggest at least one change.'**
  String get eventDetailSuggestEditNoChanges;

  /// General failure message for event edit suggestion submit
  ///
  /// In en, this message translates to:
  /// **'Failed to submit edit suggestion. Please try again.'**
  String get eventDetailSuggestEditSubmitFailed;

  /// Error detail for event edit suggestion submit
  ///
  /// In en, this message translates to:
  /// **'Error submitting edit suggestion: {error}'**
  String eventDetailSuggestEditSubmitError(String error);

  /// Dialog title for reviewing event photo/edit suggestions
  ///
  /// In en, this message translates to:
  /// **'Review event suggestion'**
  String get eventSuggestionApprovalTitle;

  /// Warning title when target event is from an external source
  ///
  /// In en, this message translates to:
  /// **'Cannot approve suggestion'**
  String get eventSuggestionCannotApproveExternalTitle;

  /// Warning body when target event is from an external source
  ///
  /// In en, this message translates to:
  /// **'The selected event is from an external source ({sourceName}). Suggestions can only be approved for native events.\n\nTo approve this suggestion, first create a native event from the event details menu.'**
  String eventSuggestionCannotApproveExternalBody(String sourceName);

  /// Warning title when target event is a duplicate
  ///
  /// In en, this message translates to:
  /// **'Cannot approve suggestion'**
  String get eventSuggestionCannotApproveDuplicateTitle;

  /// Warning body when target event is a duplicate
  ///
  /// In en, this message translates to:
  /// **'The selected event is a duplicate of another event. Suggestions can only be approved for the native original event.\n\nPlease select the original event below.'**
  String get eventSuggestionCannotApproveDuplicateBody;

  /// Label for target event selection in approval dialog
  ///
  /// In en, this message translates to:
  /// **'Target event'**
  String get eventSuggestionTargetEventLabel;

  /// Radio label for the reported event in approval dialog
  ///
  /// In en, this message translates to:
  /// **'Reported event: {title}'**
  String eventSuggestionCurrentEventLabel(String title);

  /// Radio label for the original event in approval dialog
  ///
  /// In en, this message translates to:
  /// **'Original event: {title}'**
  String eventSuggestionOriginalEventLabel(String title);

  /// Subtitle when reported event is a duplicate
  ///
  /// In en, this message translates to:
  /// **'The reported event (duplicate of {title})'**
  String eventSuggestionReportedEventDuplicateSubtitle(String title);

  /// Subtitle when reported event is from an external source
  ///
  /// In en, this message translates to:
  /// **'The reported event (from {sourceName})'**
  String eventSuggestionReportedEventExternalSubtitle(String sourceName);

  /// Default subtitle for reported event target option
  ///
  /// In en, this message translates to:
  /// **'The reported event'**
  String get eventSuggestionReportedEventSubtitle;

  /// Subtitle when original event is from an external source
  ///
  /// In en, this message translates to:
  /// **'The original event (from {sourceName})'**
  String eventSuggestionOriginalEventExternalSubtitle(String sourceName);

  /// Subtitle when original event is native and recommended
  ///
  /// In en, this message translates to:
  /// **'The original event (recommended)'**
  String get eventSuggestionOriginalEventRecommendedSubtitle;

  /// Label for optional moderator notes in event suggestion approval
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get eventSuggestionModeratorNotesLabel;

  /// Hint for optional moderator notes in event suggestion approval
  ///
  /// In en, this message translates to:
  /// **'Document why you approved or rejected this suggestion...'**
  String get eventSuggestionModeratorNotesHint;

  /// Confirm button in event suggestion approval dialog
  ///
  /// In en, this message translates to:
  /// **'Approve suggestion'**
  String get eventSuggestionApproveButton;

  /// Generic failure when event suggestion approval fails
  ///
  /// In en, this message translates to:
  /// **'Could not approve this event suggestion.'**
  String get eventSuggestionApprovalFailed;

  /// Success message after approving an event suggestion
  ///
  /// In en, this message translates to:
  /// **'Approved and applied to event {eventId}.'**
  String eventSuggestionApprovalSuccess(String eventId);

  /// Section title listing fields the user proposed changing on an event
  ///
  /// In en, this message translates to:
  /// **'Suggested changes'**
  String get eventSuggestionChangedFieldsTitle;

  /// Label when a user suggests removing the event location
  ///
  /// In en, this message translates to:
  /// **'Remove location'**
  String get eventSuggestionLocationRemoved;

  /// Count of spots proposed in an event edit suggestion
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No linked spots} =1{1 linked spot} other{{count} linked spots}}'**
  String eventSuggestionLinkedSpotsCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'nl',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'nl':
      return AppLocalizationsNl();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
