import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_list.dart';

String spotListVisibilityLabel(
  AppLocalizations l10n,
  SpotListVisibility visibility,
) {
  switch (visibility) {
    case SpotListVisibility.public:
      return l10n.spotListDetailVisibilityPublicList;
    case SpotListVisibility.unlisted:
      return l10n.spotListDetailVisibilityUnlistedList;
    case SpotListVisibility.private:
      return l10n.spotListDetailVisibilityPrivateList;
  }
}

String spotListVisibilityDescription(
  AppLocalizations l10n,
  SpotListVisibility visibility,
) {
  return spotListVisibilityLabel(l10n, visibility);
}

String spotListVisibilitySummary(
  AppLocalizations l10n,
  SpotListVisibility visibility,
) {
  switch (visibility) {
    case SpotListVisibility.public:
      return l10n.spotListDetailVisibilityPublicList;
    case SpotListVisibility.unlisted:
      return l10n.spotListDetailVisibilityUnlistedList;
    case SpotListVisibility.private:
      return l10n.spotListDetailVisibilityPrivateList;
  }
}

extension SpotListVisibilityLocalization on SpotListVisibility {
  String localizedLabel(AppLocalizations l10n) =>
      spotListVisibilityLabel(l10n, this);

  String localizedShortLabel(AppLocalizations l10n) {
    switch (this) {
      case SpotListVisibility.public:
        return l10n.spotListEditVisibilityPublic;
      case SpotListVisibility.unlisted:
        return l10n.spotListEditVisibilityUnlisted;
      case SpotListVisibility.private:
        return l10n.spotListEditVisibilityPrivate;
    }
  }

  String localizedHelp(AppLocalizations l10n) {
    switch (this) {
      case SpotListVisibility.public:
        return l10n.spotListEditVisibilityPublicHelp;
      case SpotListVisibility.unlisted:
        return l10n.spotListEditVisibilityUnlistedHelp;
      case SpotListVisibility.private:
        return l10n.spotListEditVisibilityPrivateHelp;
    }
  }

  String localizedDescription(AppLocalizations l10n) =>
      spotListVisibilityDescription(l10n, this);

  String localizedListLabel(AppLocalizations l10n) =>
      spotListVisibilitySummary(l10n, this);

  IconData get icon {
    switch (this) {
      case SpotListVisibility.public:
        return Icons.public_outlined;
      case SpotListVisibility.unlisted:
        return Icons.link;
      case SpotListVisibility.private:
        return Icons.lock_outline;
    }
  }
}
