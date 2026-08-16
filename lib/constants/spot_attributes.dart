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
      'description':
          'This spot is good for different ways of vaulting over obstacles',
      'filterDescription': 'Spots good for vaulting',
    },
    'balance': {
      'label': 'Balance',
      'icon': Icons.balance,
      'description':
          'This spot is good for balancing on rails or narrow surfaces',
      'filterDescription': 'Spots good for balance work',
    },
    'ascend': {
      'label': 'Ascents',
      'icon': Icons.arrow_upward,
      'description': 'This spot is good for climbing up structures',
      'filterDescription': 'Spots good for climbing up',
    },
    'descend': {
      'label': 'Descents',
      'icon': Icons.arrow_downward,
      'description': 'This spot is good for climbing down structures',
      'filterDescription': 'Spots good for climbing down',
    },
    'speed_run': {
      'label': 'Speed runs',
      'icon': Icons.speed,
      'description': 'This spot is good for fast-paced lines of movement',
      'filterDescription': 'Spots good for fast lines',
    },
    'water_challenges': {
      'label': 'Water challenges',
      'icon': Icons.water,
      'description': 'This spot is good for challenges over water',
      'filterDescription': 'Spots good for water challenges',
    },
    'pole_slide': {
      'label': 'Pole slides',
      'icon': Icons.arrow_downward_outlined,
      'description': 'This spot is good for sliding down poles',
      'filterDescription': 'Spots good for pole slides',
    },
    'precisions': {
      'label': 'Precisions',
      'icon': Icons.center_focus_strong,
      'description': 'This spot is good for precise landing techniques',
      'filterDescription': 'Spots good for precision landings',
    },
    'wall_runs': {
      'label': 'Wall runs',
      'icon': Icons.directions_run,
      'description':
          'This spot is good for running up vertical or slanted surfaces',
      'filterDescription': 'Spots good for wall runs',
    },
    'strides': {
      'label': 'Strides',
      'icon': Icons.open_in_full,
      'description':
          'This spot is good for one-footed jumping lines over obstacles',
      'filterDescription': 'Spots good for stride lines',
    },
    'rolls': {
      'label': 'Rolls',
      'icon': Icons.refresh,
      'description':
          'This spot is good for rolling techniques on the ground or on obstacles',
      'filterDescription': 'Spots good for rolls',
    },
    'cats': {
      'label': 'Cat leaps',
      'icon': Icons.pets,
      'description':
          'This spot is good for hanging or jumping towards hanging off obstacles',
      'filterDescription': 'Spots good for cat leaps',
    },
    'flow': {
      'label': 'Flow',
      'icon': Icons.waves,
      'description':
          'This spot is good for smooth, continuous movement sequences',
      'filterDescription': 'Spots good for flow',
    },
    'flips': {
      'label': 'Flips',
      'icon': Icons.refresh,
      'description':
          'This spot is good for aerial rotations and acrobatic movements',
      'filterDescription': 'Spots good for flips',
    },
    'swings': {
      'label': 'Swings',
      'icon': Icons.sync,
      'description':
          'This spot is good for swinging movements on bars and structures',
      'filterDescription': 'Spots good for swings',
    },
  };

  /// Spot features configuration
  static const Map<String, Map<String, dynamic>> spotFeatures = {
    'walls_low': {
      'label': 'Low wall',
      'icon': Icons.view_in_ar,
      'description': 'This spot has low walls, up to 1 meter or 3 feet high',
      'filterDescription': 'Spots with low walls (up to 1 m / 3 ft)',
    },
    'walls_medium': {
      'label': 'Medium wall',
      'icon': Icons.view_in_ar,
      'description':
          'This spot has medium height walls, 1 to 2 meters or 3-7 feet high',
      'filterDescription': 'Spots with medium walls (1 to 2 m / 3 to 7 ft)',
    },
    'walls_high': {
      'label': 'High wall',
      'icon': Icons.view_in_ar,
      'description': 'This spot has high walls, above 2 meters or 7 feet high',
      'filterDescription': 'Spots with high walls (above 2 m / 7 ft)',
    },
    'bars_low': {
      'label': 'Low bar',
      'icon': Icons.horizontal_rule,
      'description': 'This spot has low bars, up to 1 meter or 3 feet high',
      'filterDescription': 'Spots with low bars (up to 1 m / 3 ft)',
    },
    'bars_medium': {
      'label': 'Medium bar',
      'icon': Icons.horizontal_rule,
      'description':
          'This spot has medium height bars, 1 meter or 3 feet to 2 meters or 7 feet high',
      'filterDescription': 'Spots with medium bars (1 to 2 m / 3 to 7 ft)',
    },
    'bars_high': {
      'label': 'High bar',
      'icon': Icons.horizontal_rule,
      'description': 'This spot has high bars, above 2 meters or 7 feet high',
      'filterDescription': 'Spots with high bars (above 2 m / 7 ft)',
    },
    'climbing_tree': {
      'label': 'Climbing tree',
      'icon': Icons.park,
      'description': 'This spot has a tree suitable for climbing',
      'filterDescription': 'Spots with a climbable tree',
    },
    'rocks': {
      'label': 'Rocks',
      'icon': Icons.terrain,
      'description': 'This spot has natural rock formations',
      'filterDescription': 'Spots with natural rocks',
    },
    'soft_landing_pit': {
      'label': 'Soft landing pit',
      'icon': Icons.bed,
      'description':
          'This spot has a soft surface for safe landings, like for example a sandpit or foam pit',
      'filterDescription': 'Spots with a soft landing pit',
    },
    'roof_gap': {
      'label': 'Roof gap',
      'icon': Icons.roofing,
      'description':
          'This spot has a roof gap, allowing you to jump between rooftops',
      'filterDescription': 'Spots with a roof gap',
    },
    'bouncy_equipment': {
      'label': 'Bouncy equipment',
      'icon': Icons.sports_gymnastics,
      'description':
          'This spot has bouncy equipment, like an airtrack, trampoline, spring floor, or similar',
      'filterDescription': 'Spots with bouncy equipment',
    },
  };

  /// Spot access configuration
  static const Map<String, Map<String, dynamic>> spotAccess = {
    'public': {
      'label': 'Public',
      'icon': Icons.lock_open,
      'description': 'This spot is open to everyone, no restrictions',
      'filterDescription': 'Open to everyone',
    },
    'restricted': {
      'label': 'Restricted',
      'icon': Icons.lock,
      'description':
          'This spot has limited access and may require permission from the owner',
      'filterDescription': 'Limited access; may need permission',
    },
    'paid': {
      'label': 'Paid',
      'icon': Icons.payments,
      'description':
          'This spot requires payment or a membership to access, like for example a commercial parkour gym or park',
      'filterDescription': 'Requires payment or membership',
    },
  };

  /// Spot facilities configuration
  static const Map<String, Map<String, dynamic>> spotFacilities = {
    'covered': {
      'label': 'Covered',
      'icon': Icons.roofing,
      'description':
          'Whether this spot has a roof or cover from the weather, making it possible to train in rain or harsh sunshine',
      'filterDescription': 'Has cover from weather',
    },
    'lighting': {
      'label': 'Lighting',
      'icon': Icons.lightbulb,
      'description':
          'Whether this spot has artificial lighting, making it possible to train at night',
      'filterDescription': 'Has lighting for night training',
    },
    'water_tap': {
      'label': 'Water tap',
      'icon': Icons.water_drop,
      'description': 'Whether this spot has a water tap available',
      'filterDescription': 'Has a water tap',
    },
    'toilet': {
      'label': 'Toilet',
      'icon': Icons.wc,
      'description':
          'Whether this spot has public restroom facilities available',
      'filterDescription': 'Has a restroom',
    },
    'parking': {
      'label': 'Parking',
      'icon': Icons.local_parking,
      'description': 'Whether this spot has vehicle parking available',
      'filterDescription': 'Has parking',
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

  /// Get description for a specific attribute (add/edit spot wording)
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

  /// Get filter-oriented tooltip for Explore filters
  static String getFilterDescription(String category, String key) {
    switch (category) {
      case 'goodFor':
        return goodForSkills[key]?['filterDescription'] as String? ??
            getDescription(category, key);
      case 'features':
        return spotFeatures[key]?['filterDescription'] as String? ??
            getDescription(category, key);
      case 'access':
        return spotAccess[key]?['filterDescription'] as String? ??
            getDescription(category, key);
      case 'facilities':
        return spotFacilities[key]?['filterDescription'] as String? ??
            getDescription(category, key);
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
