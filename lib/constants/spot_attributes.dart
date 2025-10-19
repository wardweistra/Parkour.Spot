import 'package:flutter/material.dart';

/// Centralized configuration for spot attributes
/// Ensures consistency across Add Spot screen, Detail screen, and future features
class SpotAttributes {
  // Private constructor to prevent instantiation
  SpotAttributes._();

  /// Good For skills configuration
  static const Map<String, Map<String, dynamic>> goodForSkills = {
    'vaults': {
      'label': 'Vaults',
      'icon': Icons.directions_run,
      'description': 'Jumping over obstacles',
    },
    'balance': {
      'label': 'Balance',
      'icon': Icons.balance,
      'description': 'Walking on narrow surfaces',
    },
    'ascend': {
      'label': 'Ascend',
      'icon': Icons.arrow_upward,
      'description': 'Climbing up structures',
    },
    'descend': {
      'label': 'Descend',
      'icon': Icons.arrow_downward,
      'description': 'Controlled descent techniques',
    },
    'speed_run': {
      'label': 'Speed run',
      'icon': Icons.speed,
      'description': 'Fast-paced movement sequences',
    },
    'water_challenges': {
      'label': 'Water challenges',
      'icon': Icons.water,
      'description': 'Water-based obstacles',
    },
    'pole_slide': {
      'label': 'Pole slide',
      'icon': Icons.arrow_downward_outlined,
      'description': 'Sliding down poles',
    },
    'precisions': {
      'label': 'Precisions',
      'icon': Icons.center_focus_strong,
      'description': 'Precise landing techniques',
    },
    'wall_runs': {
      'label': 'Wall Runs',
      'icon': Icons.directions_run,
      'description': 'Running up vertical surfaces',
    },
    'strides': {
      'label': 'Strides',
      'icon': Icons.open_in_full,
      'description': 'Long jumping movements',
    },
    'rolls': {
      'label': 'Rolls',
      'icon': Icons.refresh,
      'description': 'Rolling techniques for safe landings',
    },
    'cats': {
      'label': 'Cats',
      'icon': Icons.pets,
      'description': 'Cat-like climbing and hanging movements',
    },
    'flow': {
      'label': 'Flow',
      'icon': Icons.waves,
      'description': 'Smooth, continuous movement sequences',
    },
    'flips': {
      'label': 'Flips',
      'icon': Icons.refresh,
      'description': 'Aerial rotations and acrobatic movements',
    },
  };

  /// Spot features configuration
  static const Map<String, Map<String, dynamic>> spotFeatures = {
    'walls_low': {
      'label': 'Walls - Low (<1m)',
      'icon': Icons.view_in_ar,
      'description': 'Low walls for vaulting (up to 1 meter)',
    },
    'walls_medium': {
      'label': 'Walls - Medium (1-2m)',
      'icon': Icons.view_in_ar,
      'description': 'Medium height walls (1 to 2 meters)',
    },
    'walls_high': {
      'label': 'Walls - High (>2m)',
      'icon': Icons.view_in_ar,
      'description': 'High walls for climbing (above 2 meters)',
    },
    'bars_low': {
      'label': 'Bars - Low (<1m)',
      'icon': Icons.horizontal_rule,
      'description': 'Low bars for swinging (up to 1 meter)',
    },
    'bars_medium': {
      'label': 'Bars - Medium (1-2m)',
      'icon': Icons.horizontal_rule,
      'description': 'Medium height bars (1 to 2 meters)',
    },
    'bars_high': {
      'label': 'Bars - High (>2m)',
      'icon': Icons.horizontal_rule,
      'description': 'High bars for advanced moves (above 2 meters)',
    },
    'climbing_tree': {
      'label': 'Climbing tree',
      'icon': Icons.park,
      'description': 'Tree suitable for climbing',
    },
    'rocks': {
      'label': 'Rocks',
      'icon': Icons.terrain,
      'description': 'Natural rock formations',
    },
    'soft_landing_pit': {
      'label': 'Soft landing pit',
      'icon': Icons.toys,
      'description': 'Soft surface for safe landings',
    },
    'roof_gap': {
      'label': 'Roof gap',
      'icon': Icons.roofing,
      'description': 'Jumping between rooftops',
    },
    'bouncy_equipment': {
      'label': 'Bouncy Equipment',
      'icon': Icons.sports_gymnastics,
      'description': 'Airtrack, trampoline, spring floor, or similar bouncy surfaces',
    },
  };

  /// Spot access configuration
  static const Map<String, Map<String, dynamic>> spotAccess = {
    'public': {
      'label': 'Public',
      'icon': Icons.lock_open,
      'description': 'Open to everyone, no restrictions',
    },
    'restricted': {
      'label': 'Restricted',
      'icon': Icons.lock,
      'description': 'Limited access, may require permission',
    },
    'paid': {
      'label': 'Paid',
      'icon': Icons.payments,
      'description': 'Requires payment or membership',
    },
  };

  /// Spot facilities configuration
  static const Map<String, Map<String, dynamic>> spotFacilities = {
    'covered': {
      'label': 'Covered',
      'icon': Icons.roofing,
      'description': 'Shelter from weather',
    },
    'lighting': {
      'label': 'Lighting',
      'icon': Icons.lightbulb,
      'description': 'Artificial lighting available',
    },
    'water_tap': {
      'label': 'Water tap',
      'icon': Icons.water_drop,
      'description': 'Access to drinking water',
    },
    'toilet': {
      'label': 'Toilet',
      'icon': Icons.wc,
      'description': 'Restroom facilities',
    },
    'parking': {
      'label': 'Parking',
      'icon': Icons.local_parking,
      'description': 'Vehicle parking available',
    },
  };

  /// Get icon for a specific attribute
  static IconData getIcon(String category, String key) {
    switch (category) {
      case 'goodFor':
        return goodForSkills[key]?['icon'] ?? Icons.info;
      case 'features':
        return spotFeatures[key]?['icon'] ?? Icons.info;
      case 'access':
        return spotAccess[key]?['icon'] ?? Icons.info;
      case 'facilities':
        return spotFacilities[key]?['icon'] ?? Icons.info;
      default:
        return Icons.info;
    }
  }

  /// Get display label for a specific attribute
  static String getLabel(String category, String key) {
    switch (category) {
      case 'goodFor':
        return goodForSkills[key]?['label'] ?? key;
      case 'features':
        return spotFeatures[key]?['label'] ?? key;
      case 'access':
        return spotAccess[key]?['label'] ?? key;
      case 'facilities':
        return spotFacilities[key]?['label'] ?? key;
      default:
        return key;
    }
  }

  /// Get description for a specific attribute
  static String getDescription(String category, String key) {
    switch (category) {
      case 'goodFor':
        return goodForSkills[key]?['description'] ?? '';
      case 'features':
        return spotFeatures[key]?['description'] ?? '';
      case 'access':
        return spotAccess[key]?['description'] ?? '';
      case 'facilities':
        return spotFacilities[key]?['description'] ?? '';
      default:
        return '';
    }
  }

  /// Get all keys for a specific category
  static List<String> getKeys(String category) {
    switch (category) {
      case 'goodFor':
        return goodForSkills.keys.toList();
      case 'features':
        return spotFeatures.keys.toList();
      case 'access':
        return spotAccess.keys.toList();
      case 'facilities':
        return spotFacilities.keys.toList();
      default:
        return [];
    }
  }

  /// Get all entries for a specific category
  static Map<String, Map<String, dynamic>> getEntries(String category) {
    switch (category) {
      case 'goodFor':
        return goodForSkills;
      case 'features':
        return spotFeatures;
      case 'access':
        return spotAccess;
      case 'facilities':
        return spotFacilities;
      default:
        return {};
    }
  }
}
