import 'package:flutter/material.dart';

/// A fixed, const set of category / transaction icons. Because these are
/// compile-time constants, Flutter's icon tree-shaking still works even though
/// the *choice* of icon is stored as a code point in the database.
///
/// IMPORTANT: this list is APPEND-ONLY. The first 12 entries (indices 0-11)
/// must never move, because seed data and older imports refer to icons by their
/// position here. Add new icons at the end.
///
/// Look icons up by code point via [categoryIcon]; never construct a dynamic
/// `IconData` from a runtime int (that breaks tree-shaking and warns).
const List<IconData> kCategoryIcons = <IconData>[
  // --- Original 12 (indices 0-11) - DO NOT REORDER ------------------------
  Icons.home_outlined, // 0
  Icons.star_outline, // 1
  Icons.account_balance_outlined, // 2
  Icons.restaurant_outlined, // 3
  Icons.directions_car_outlined, // 4
  Icons.shopping_bag_outlined, // 5
  Icons.medical_services_outlined, // 6
  Icons.school_outlined, // 7
  Icons.pets_outlined, // 8
  Icons.flight_outlined, // 9
  Icons.bolt_outlined, // 10
  Icons.card_giftcard_outlined, // 11

  // --- Food & drink -------------------------------------------------------
  Icons.local_cafe_outlined,
  Icons.local_bar_outlined,
  Icons.local_pizza_outlined,
  Icons.fastfood_outlined,
  Icons.bakery_dining_outlined,
  Icons.lunch_dining_outlined,
  Icons.dinner_dining_outlined,
  Icons.ramen_dining_outlined,
  Icons.brunch_dining_outlined,
  Icons.icecream_outlined,
  Icons.cake_outlined,
  Icons.coffee_outlined,
  Icons.emoji_food_beverage_outlined,
  Icons.wine_bar_outlined,
  Icons.liquor_outlined,
  Icons.egg_outlined,
  Icons.set_meal_outlined,
  Icons.kebab_dining_outlined,
  Icons.restaurant_menu_outlined,
  Icons.local_grocery_store_outlined,

  // --- Transport ----------------------------------------------------------
  Icons.directions_bus_outlined,
  Icons.directions_bike_outlined,
  Icons.directions_transit_outlined,
  Icons.directions_subway_outlined,
  Icons.directions_boat_outlined,
  Icons.train_outlined,
  Icons.tram_outlined,
  Icons.local_taxi_outlined,
  Icons.local_shipping_outlined,
  Icons.two_wheeler_outlined,
  Icons.pedal_bike_outlined,
  Icons.electric_scooter_outlined,
  Icons.electric_car_outlined,
  Icons.moped_outlined,
  Icons.airport_shuttle_outlined,
  Icons.commute_outlined,
  Icons.sailing_outlined,
  Icons.flight_takeoff_outlined,
  Icons.local_gas_station_outlined,
  Icons.ev_station_outlined,
  Icons.local_parking_outlined,

  // --- Home & utilities ---------------------------------------------------
  Icons.lightbulb_outline,
  Icons.water_drop_outlined,
  Icons.gas_meter_outlined,
  Icons.power_outlined,
  Icons.wifi_outlined,
  Icons.router_outlined,
  Icons.thermostat_outlined,
  Icons.cleaning_services_outlined,
  Icons.chair_outlined,
  Icons.bed_outlined,
  Icons.kitchen_outlined,
  Icons.countertops_outlined,
  Icons.yard_outlined,
  Icons.grass_outlined,
  Icons.plumbing_outlined,
  Icons.handyman_outlined,
  Icons.construction_outlined,
  Icons.roofing_outlined,
  Icons.house_outlined,
  Icons.apartment_outlined,
  Icons.villa_outlined,
  Icons.weekend_outlined,
  Icons.local_laundry_service_outlined,
  Icons.iron_outlined,
  Icons.microwave_outlined,
  Icons.blender_outlined,
  Icons.coffee_maker_outlined,

  // --- Shopping & lifestyle ----------------------------------------------
  Icons.shopping_cart_outlined,
  Icons.storefront_outlined,
  Icons.local_mall_outlined,
  Icons.checkroom_outlined,
  Icons.diamond_outlined,
  Icons.watch_outlined,
  Icons.redeem_outlined,
  Icons.loyalty_outlined,
  Icons.sell_outlined,
  Icons.local_offer_outlined,
  Icons.style_outlined,

  // --- Health & wellness --------------------------------------------------
  Icons.fitness_center_outlined,
  Icons.spa_outlined,
  Icons.self_improvement_outlined,
  Icons.healing_outlined,
  Icons.local_pharmacy_outlined,
  Icons.vaccines_outlined,
  Icons.monitor_heart_outlined,
  Icons.psychology_outlined,
  Icons.medication_outlined,
  Icons.health_and_safety_outlined,
  Icons.bloodtype_outlined,
  Icons.favorite_outline,

  // --- Entertainment & leisure -------------------------------------------
  Icons.movie_outlined,
  Icons.theaters_outlined,
  Icons.sports_esports_outlined,
  Icons.videogame_asset_outlined,
  Icons.music_note_outlined,
  Icons.library_music_outlined,
  Icons.casino_outlined,
  Icons.celebration_outlined,
  Icons.nightlife_outlined,
  Icons.attractions_outlined,
  Icons.festival_outlined,
  Icons.confirmation_number_outlined,
  Icons.local_activity_outlined,
  Icons.park_outlined,
  Icons.beach_access_outlined,
  Icons.pool_outlined,
  Icons.hiking_outlined,
  Icons.travel_explore_outlined,
  Icons.camera_alt_outlined,
  Icons.palette_outlined,
  Icons.brush_outlined,
  Icons.sports_basketball_outlined,
  Icons.sports_tennis_outlined,

  // --- Finance & work -----------------------------------------------------
  Icons.savings_outlined,
  Icons.account_balance_wallet_outlined,
  Icons.payments_outlined,
  Icons.credit_card_outlined,
  Icons.paid_outlined,
  Icons.request_quote_outlined,
  Icons.receipt_long_outlined,
  Icons.receipt_outlined,
  Icons.pie_chart_outline,
  Icons.work_outline,
  Icons.business_center_outlined,
  Icons.badge_outlined,
  Icons.corporate_fare_outlined,
  Icons.domain_outlined,
  Icons.engineering_outlined,
  Icons.calculate_outlined,
  Icons.print_outlined,
  Icons.devices_outlined,

  // --- Tech & subscriptions ----------------------------------------------
  Icons.tv_outlined,
  Icons.cast_outlined,
  Icons.cloud_outlined,
  Icons.subscriptions_outlined,
  Icons.live_tv_outlined,
  Icons.ondemand_video_outlined,
  Icons.sim_card_outlined,
  Icons.call_outlined,
  Icons.sms_outlined,
  Icons.mail_outline,
  Icons.phone_iphone_outlined,
  Icons.headset_outlined,

  // --- Family & people ----------------------------------------------------
  Icons.child_care_outlined,
  Icons.child_friendly_outlined,
  Icons.family_restroom_outlined,
  Icons.people_outline,
  Icons.person_outline,
  Icons.volunteer_activism_outlined,
  Icons.baby_changing_station_outlined,
  Icons.stroller_outlined,
  Icons.toys_outlined,

  // --- Education ----------------------------------------------------------
  Icons.menu_book_outlined,
  Icons.auto_stories_outlined,
  Icons.science_outlined,
  Icons.biotech_outlined,
  Icons.history_edu_outlined,
  Icons.draw_outlined,
  Icons.edit_outlined,
  Icons.backpack_outlined,
  Icons.cast_for_education_outlined,

  // --- Nature & misc ------------------------------------------------------
  Icons.eco_outlined,
  Icons.recycling_outlined,
  Icons.forest_outlined,
  Icons.wb_sunny_outlined,
  Icons.umbrella_outlined,
  Icons.local_florist_outlined,
  Icons.agriculture_outlined,
  Icons.cruelty_free_outlined,
  Icons.emoji_nature_outlined,

  // --- Responsibilities / documents / time -------------------------------
  Icons.policy_outlined,
  Icons.security_outlined,
  Icons.shield_outlined,
  Icons.verified_user_outlined,
  Icons.description_outlined,
  Icons.article_outlined,
  Icons.folder_outlined,
  Icons.inventory_2_outlined,
  Icons.category_outlined,
  Icons.pending_actions_outlined,
  Icons.event_outlined,
  Icons.calendar_month_outlined,
  Icons.alarm_outlined,
  Icons.schedule_outlined,
  Icons.flag_outlined,
  Icons.bookmark_outline,
  Icons.push_pin_outlined,
  Icons.label_outline,
];

const IconData kFallbackCategoryIcon = Icons.label_outline;

/// Resolve a stored code point back to its const [IconData].
IconData categoryIcon(int codePoint) {
  for (final icon in kCategoryIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return kFallbackCategoryIcon;
}
