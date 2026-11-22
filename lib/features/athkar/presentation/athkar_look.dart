import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

/// The Athkar page's sections (Tahfeez's own grouping of Hisn al-Muslim's
/// chapters, by their IDs), each with its icon.
enum AthkarGroup {
  daily(Icons.wb_twilight_rounded, [27, 28, 1, 29, 30, 31]),
  prayer(Icons.mosque_outlined, [
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    32,
    33,
    42,
  ]),
  remembrance(Icons.auto_awesome_outlined, [
    107,
    129,
    130,
    131,
    85,
    84,
    44,
    92,
    106,
    122,
    123,
  ]),
  home(Icons.home_outlined, [6, 7, 8, 9, 10, 11, 2, 3, 4, 5]),
  distress(Icons.shield_outlined, [
    34,
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    43,
    45,
    46,
    82,
    88,
    94,
    124,
    125,
    126,
    128,
    53,
  ]),
  food(Icons.restaurant_outlined, [68, 69, 70, 71, 72, 73, 74, 75, 76]),
  people(Icons.diversity_3_outlined, [
    47,
    48,
    77,
    78,
    79,
    80,
    81,
    83,
    86,
    87,
    89,
    90,
    91,
    93,
    108,
    109,
    112,
    113,
    114,
    132,
  ]),
  travel(Icons.flight_takeoff_rounded, [
    95,
    96,
    97,
    98,
    99,
    100,
    101,
    102,
    103,
    104,
    105,
    110,
    111,
  ]),
  nature(Icons.cloud_outlined, [61, 62, 63, 64, 65, 66, 67]),
  illness(Icons.healing_outlined, [49, 50, 51, 52, 54, 55, 56, 57, 58, 59, 60]),
  hajj(Icons.landscape_outlined, [115, 116, 117, 118, 119, 120, 121, 127]);

  const AthkarGroup(this.icon, this.categories);

  final IconData icon;

  /// Its chapters (IDs), in the order shown.
  final List<int> categories;

  String title(AppLocalizations l10n) => switch (this) {
    daily => l10n.athkarGroupDaily,
    prayer => l10n.athkarGroupPrayer,
    remembrance => l10n.athkarGroupRemembrance,
    home => l10n.athkarGroupHome,
    distress => l10n.athkarGroupDistress,
    food => l10n.athkarGroupFood,
    people => l10n.athkarGroupPeople,
    travel => l10n.athkarGroupTravel,
    nature => l10n.athkarGroupNature,
    illness => l10n.athkarGroupIllness,
    hajj => l10n.athkarGroupHajj,
  };

  /// The group a chapter is in.
  static AthkarGroup? of(int category) {
    for (final g in values) {
      if (g.categories.contains(category)) return g;
    }
    return null;
  }
}

/// A chapter's own icon, where one says it better than its section's.
const _icons = <int, IconData>{
  27: Icons.wb_sunny_outlined,
  28: Icons.bedtime_outlined,
  1: Icons.alarm_outlined,
  29: Icons.nights_stay_outlined,
  30: Icons.nights_stay_outlined,
  31: Icons.cloud_queue_outlined,
  6: Icons.wc_outlined,
  7: Icons.wc_outlined,
  8: Icons.water_drop_outlined,
  9: Icons.water_drop_outlined,
  10: Icons.logout_rounded,
  11: Icons.login_rounded,
  2: Icons.checkroom_outlined,
  3: Icons.checkroom_outlined,
  4: Icons.checkroom_outlined,
  5: Icons.checkroom_outlined,
  12: Icons.directions_walk_rounded,
  15: Icons.campaign_outlined,
  26: Icons.lightbulb_outline_rounded,
  32: Icons.front_hand_outlined,
  107: Icons.favorite_outline_rounded,
  129: Icons.replay_rounded,
  44: Icons.replay_rounded,
  122: Icons.sentiment_satisfied_alt_outlined,
  123: Icons.sentiment_satisfied_alt_outlined,
  106: Icons.sentiment_neutral_outlined,
  34: Icons.sentiment_dissatisfied_outlined,
  35: Icons.sentiment_dissatisfied_outlined,
  41: Icons.payments_outlined,
  82: Icons.mood_bad_outlined,
  124: Icons.healing_outlined,
  125: Icons.visibility_outlined,
  68: Icons.dinner_dining_outlined,
  73: Icons.dinner_dining_outlined,
  74: Icons.no_food_outlined,
  75: Icons.no_food_outlined,
  76: Icons.eco_outlined,
  47: Icons.child_care_outlined,
  48: Icons.child_care_outlined,
  77: Icons.sick_outlined,
  78: Icons.sick_outlined,
  79: Icons.favorite_border_rounded,
  80: Icons.favorite_border_rounded,
  81: Icons.favorite_border_rounded,
  108: Icons.waving_hand_outlined,
  109: Icons.waving_hand_outlined,
  95: Icons.directions_car_outlined,
  97: Icons.location_city_outlined,
  98: Icons.storefront_outlined,
  99: Icons.car_repair_outlined,
  105: Icons.flight_land_rounded,
  110: Icons.pets_outlined,
  111: Icons.pets_outlined,
  61: Icons.air_rounded,
  62: Icons.thunderstorm_outlined,
  63: Icons.water_drop_outlined,
  64: Icons.umbrella_outlined,
  65: Icons.umbrella_outlined,
  66: Icons.wb_cloudy_outlined,
  67: Icons.brightness_3_outlined,
  55: Icons.local_florist_outlined,
  56: Icons.local_florist_outlined,
  57: Icons.local_florist_outlined,
  58: Icons.local_florist_outlined,
  59: Icons.local_florist_outlined,
  60: Icons.local_florist_outlined,
  127: Icons.volunteer_activism_outlined,
};

/// The icon shown for a chapter.
IconData athkarCategoryIcon(int category) =>
    _icons[category] ??
    AthkarGroup.of(category)?.icon ??
    Icons.auto_awesome_outlined;
