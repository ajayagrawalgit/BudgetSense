import 'package:flutter/material.dart';

import '../theme/category_icons.dart';

/// Splitwise-style icon auto-detection. Given free text (a category or expense
/// name the user is typing), returns the best-matching icon from
/// [kCategoryIcons] on the fly. The user can always override the suggestion.
///
/// Design notes:
///  * Every icon returned here is guaranteed to be in [kCategoryIcons], so the
///    picker can highlight it as "selected" by code point.
///  * Matching is keyword-based and case-insensitive. Longer/more specific
///    keywords are checked first so "coffee shop" beats a generic "shop".
///  * This is pure and side-effect free, so it's trivially testable.
abstract final class IconSuggester {
  /// Ordered rules: the FIRST keyword found as a substring wins. Keep the most
  /// specific phrases near the top. Each entry maps keywords -> a const icon
  /// that also lives in [kCategoryIcons].
  static const List<(List<String>, IconData)> _rules = [
    // Food & drink
    (
      [
        'grocery',
        'groceries',
        'supermarket',
        'mart',
        'kirana',
        'vegetable',
        'bigbasket',
        'blinkit',
        'zepto',
        'dmart',
        'provision',
      ],
      Icons.local_grocery_store_outlined
    ),
    (
      ['coffee', 'cafe', 'café', 'starbucks', 'barista', 'ccd', 'latte'],
      Icons.local_cafe_outlined
    ),
    (['pizza', 'dominos', "domino's"], Icons.local_pizza_outlined),
    (
      ['burger', 'mcdonald', 'kfc', 'fast food', 'fries'],
      Icons.fastfood_outlined
    ),
    (['ice cream', 'icecream', 'gelato'], Icons.icecream_outlined),
    (
      ['cake', 'bakery', 'pastry', 'bread', 'dessert'],
      Icons.bakery_dining_outlined
    ),
    (['beer', 'pub', 'bar ', 'brewery', 'cocktail'], Icons.local_bar_outlined),
    (['wine'], Icons.wine_bar_outlined),
    (['liquor', 'alcohol', 'whisky', 'vodka', 'rum'], Icons.liquor_outlined),
    (['tea', 'chai'], Icons.emoji_food_beverage_outlined),
    (['breakfast'], Icons.brunch_dining_outlined),
    (['lunch'], Icons.lunch_dining_outlined),
    (['dinner'], Icons.dinner_dining_outlined),
    (['ramen', 'noodle', 'chinese'], Icons.ramen_dining_outlined),
    (
      [
        'dining',
        'restaurant',
        'food',
        'swiggy',
        'zomato',
        'eat',
        'meal',
        'canteen',
        'dhaba',
        'takeout',
        'takeaway',
      ],
      Icons.restaurant_outlined
    ),

    // Transport / travel
    (
      ['fuel', 'petrol', 'diesel', 'gas station', 'indianoil', 'hp petrol'],
      Icons.local_gas_station_outlined
    ),
    (['charging', 'ev charge', 'charge station'], Icons.ev_station_outlined),
    (['parking'], Icons.local_parking_outlined),
    (['uber', 'ola', 'taxi', 'cab'], Icons.local_taxi_outlined),
    (['bus'], Icons.directions_bus_outlined),
    (['metro', 'subway'], Icons.directions_subway_outlined),
    (['train', 'railway', 'irctc', 'rail'], Icons.train_outlined),
    (
      [
        'flight',
        'airfare',
        'airplane',
        'airline',
        'indigo',
        'vistara',
        'air ticket',
      ],
      Icons.flight_outlined
    ),
    (['boat', 'ferry', 'cruise'], Icons.directions_boat_outlined),
    (['bike', 'bicycle', 'cycle'], Icons.pedal_bike_outlined),
    (['scooter', 'scooty'], Icons.electric_scooter_outlined),
    (['motorcycle', 'two wheeler', 'bullet'], Icons.two_wheeler_outlined),
    (
      ['car', 'vehicle', 'auto', 'drive', 'garage', 'service center'],
      Icons.directions_car_outlined
    ),
    (
      [
        'travel',
        'trip',
        'tour',
        'holiday',
        'vacation',
        'makemytrip',
        'goibibo',
        'explore',
      ],
      Icons.travel_explore_outlined
    ),
    (
      ['hotel', 'resort', 'stay', 'oyo', 'lodge', 'airbnb'],
      Icons.beach_access_outlined
    ),

    // Home & utilities
    (
      ['electricity', 'electric bill', 'power bill', 'bescom', 'current bill'],
      Icons.bolt_outlined
    ),
    (['water bill', 'water'], Icons.water_drop_outlined),
    (
      ['gas cylinder', 'lpg', 'gas bill', 'cooking gas'],
      Icons.gas_meter_outlined
    ),
    (
      ['wifi', 'internet', 'broadband', 'jio fiber', 'airtel fiber'],
      Icons.wifi_outlined
    ),
    (['rent', 'lease', 'landlord'], Icons.home_outlined),
    (
      [
        'maid',
        'cleaning',
        'housekeeping',
        'cook',
        'househelp',
        'household help',
      ],
      Icons.cleaning_services_outlined
    ),
    (['furniture', 'sofa', 'chair'], Icons.chair_outlined),
    (['appliance', 'fridge', 'refrigerator'], Icons.kitchen_outlined),
    (['repair', 'plumber', 'plumbing'], Icons.plumbing_outlined),
    (['handyman', 'carpenter', 'fix', 'maintenance'], Icons.handyman_outlined),
    (['laundry', 'dry clean', 'ironing'], Icons.local_laundry_service_outlined),
    (['garden', 'lawn', 'plants'], Icons.yard_outlined),

    // Shopping & lifestyle
    (
      [
        'clothes',
        'clothing',
        'apparel',
        'fashion',
        'myntra',
        'shirt',
        'dress',
        'wardrobe',
      ],
      Icons.checkroom_outlined
    ),
    (
      ['jewel', 'jewellery', 'jewelry', 'gold', 'ring', 'diamond'],
      Icons.diamond_outlined
    ),
    (['watch'], Icons.watch_outlined),
    (['gift', 'present'], Icons.card_giftcard_outlined),
    (['mall', 'shopping mall'], Icons.local_mall_outlined),
    (
      [
        'amazon',
        'flipkart',
        'online shopping',
        'order',
        'shopping',
        'shop',
        'store',
        'purchase',
      ],
      Icons.shopping_bag_outlined
    ),

    // Health & wellness
    (['gym', 'fitness', 'workout', 'cult'], Icons.fitness_center_outlined),
    (
      [
        'spa',
        'salon',
        'massage',
        'parlour',
        'parlor',
        'haircut',
        'barber',
        'grooming',
      ],
      Icons.spa_outlined
    ),
    (['yoga', 'meditation', 'mindful'], Icons.self_improvement_outlined),
    (
      ['pharmacy', 'medicine', 'medical store', 'apollo', 'chemist', 'drug'],
      Icons.local_pharmacy_outlined
    ),
    (['vaccine', 'vaccination', 'shot'], Icons.vaccines_outlined),
    (
      [
        'doctor',
        'hospital',
        'clinic',
        'health',
        'medical',
        'checkup',
        'dental',
        'dentist',
        'surgery',
      ],
      Icons.medical_services_outlined
    ),

    // Entertainment / leisure
    (
      ['movie', 'cinema', 'pvr', 'inox', 'film', 'theatre', 'theater'],
      Icons.movie_outlined
    ),
    (
      ['game', 'gaming', 'playstation', 'xbox', 'steam'],
      Icons.sports_esports_outlined
    ),
    (
      ['music', 'spotify', 'song', 'concert', 'gaana'],
      Icons.music_note_outlined
    ),
    (
      ['netflix', 'prime video', 'hotstar', 'ott', 'streaming'],
      Icons.live_tv_outlined
    ),
    (['party', 'celebration', 'birthday'], Icons.celebration_outlined),
    (['club', 'nightlife', 'nightclub'], Icons.nightlife_outlined),
    (['park', 'picnic'], Icons.park_outlined),
    (['swim', 'pool'], Icons.pool_outlined),
    (['photo', 'camera', 'photography'], Icons.camera_alt_outlined),
    (
      ['sports', 'cricket', 'football', 'basketball', 'tennis'],
      Icons.sports_basketball_outlined
    ),
    (['hobby', 'art', 'painting', 'craft'], Icons.palette_outlined),

    // Finance & work
    (
      [
        'sip',
        'mutual fund',
        'invest',
        'investment',
        'stock',
        'shares',
        'equity',
        'nps',
        'ppf',
        'fd',
        'zerodha',
        'groww',
      ],
      Icons.savings_outlined
    ),
    (
      ['salary', 'income', 'payroll', 'wage', 'stipend'],
      Icons.payments_outlined
    ),
    (['credit card', 'card payment', 'cc bill'], Icons.credit_card_outlined),
    // Insurance BEFORE loan: "premium" contains the substring "emi", so the
    // loan rule would otherwise shadow it.
    (['insurance', 'premium', 'lic', 'policy'], Icons.policy_outlined),
    (
      ['loan', 'emi', 'mortgage', 'instalment', 'installment'],
      Icons.request_quote_outlined
    ),
    (['tax', 'gst', 'income tax', 'tds'], Icons.receipt_long_outlined),
    (['bill', 'invoice', 'receipt'], Icons.receipt_outlined),
    (
      ['bank', 'atm', 'deposit', 'withdraw', 'transfer', 'upi'],
      Icons.account_balance_outlined
    ),
    (
      ['wallet', 'paytm', 'cash', 'petty cash'],
      Icons.account_balance_wallet_outlined
    ),
    (
      [
        'office',
        'work',
        'business',
        'freelance',
        'client',
        'upwork',
        'consulting',
      ],
      Icons.work_outline
    ),

    // Tech & subscriptions
    (
      [
        'phone bill',
        'mobile recharge',
        'recharge',
        'airtel',
        'jio',
        'vi ',
        'vodafone',
        'postpaid',
        'prepaid',
        'sim',
      ],
      Icons.sim_card_outlined
    ),
    (['subscription', 'membership', 'renewal'], Icons.subscriptions_outlined),
    (['cloud', 'storage', 'icloud', 'drive', 'dropbox'], Icons.cloud_outlined),
    (['tv', 'television', 'dth', 'cable'], Icons.tv_outlined),
    (['phone', 'mobile', 'smartphone', 'iphone'], Icons.phone_iphone_outlined),
    (
      ['laptop', 'computer', 'gadget', 'electronics', 'device'],
      Icons.devices_outlined
    ),
    (['headphone', 'earphone', 'earbuds', 'headset'], Icons.headset_outlined),

    // Family / people / education
    (['baby', 'diaper', 'infant'], Icons.child_care_outlined),
    (['kids', 'children', 'child', 'toy'], Icons.toys_outlined),
    (['family', 'parents', 'home support'], Icons.family_restroom_outlined),
    (
      [
        'donation',
        'charity',
        'temple',
        'donate',
        'iskcon',
        'tithe',
        'offering',
      ],
      Icons.volunteer_activism_outlined
    ),
    (
      [
        'school',
        'tuition',
        'college',
        'course',
        'education',
        'class',
        'coaching',
        'fees',
        'fee',
        'exam',
      ],
      Icons.school_outlined
    ),
    (['book', 'books', 'reading', 'kindle'], Icons.menu_book_outlined),
    (['stationery', 'pen', 'notebook'], Icons.edit_outlined),

    // Pets & nature
    (['pet', 'dog', 'cat', 'vet', 'pets'], Icons.pets_outlined),
    (['plant', 'flower', 'nursery'], Icons.local_florist_outlined),

    // Documents / misc
    (['document', 'paperwork', 'notary'], Icons.description_outlined),
    (['reminder', 'due', 'pending'], Icons.pending_actions_outlined),
  ];

  /// Returns the code point of the best-matching icon for [text], or null when
  /// nothing is confidently detected (caller keeps whatever it already had).
  static int? suggestCodePoint(String text) {
    final q = text.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final (keywords, icon) in _rules) {
      for (final k in keywords) {
        if (q.contains(k)) return icon.codePoint;
      }
    }
    return null;
  }

  /// Convenience: resolve straight to a const [IconData] (falls back to the
  /// generic label icon when nothing matches), for previews.
  static IconData suggestIcon(String text) {
    final cp = suggestCodePoint(text);
    return cp == null ? kFallbackCategoryIcon : categoryIcon(cp);
  }

  /// Ordered, de-duplicated code points whose keywords match [query] as a
  /// substring (either direction). Powers the icon-picker search box. Returns
  /// an empty list when nothing matches, so callers can fall back to showing
  /// every icon.
  static List<int> searchCodePoints(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final seen = <int>{};
    final out = <int>[];
    for (final (keywords, icon) in _rules) {
      final hit = keywords.any((k) => k.contains(q) || q.contains(k));
      if (hit && seen.add(icon.codePoint)) out.add(icon.codePoint);
    }
    return out;
  }
}
