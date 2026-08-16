import 'package:flutter/material.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/fuzzy_search.dart';
import '../../core/utils/haptics.dart';
import '../common/calm_widgets.dart';
import '../common/ink_flourishes.dart';

/// The things the Settings search box knows how to answer with a flourish
/// instead of a list.
enum SettingsEgg {
  /// The ensō brushes itself.
  enso,

  /// A single line of ink, and nothing else.
  zen,

  /// The seal presses down over the tagline.
  brand,
}

/// Folds the handful of accented characters these triggers can be typed with,
/// since [normalizeForSearch] only keeps plain ASCII letters and would turn
/// `ensō` into `ens`.
String _fold(String input) => input
    .toLowerCase()
    .replaceAll(RegExp('[ōóòôö]'), 'o')
    .replaceAll(RegExp('[āáàâä]'), 'a')
    .replaceAll(RegExp('[ēéèêë]'), 'e');

const _triggers = <String, SettingsEgg>{
  'enso': SettingsEgg.enso,
  'zen': SettingsEgg.zen,
  'budgetsense': SettingsEgg.brand,
};

/// The easter egg [query] asks for, if any.
///
/// Deliberately an exact match on the whole normalised query: typing your way
/// towards a real setting should never trip an egg, and `zen maru` is a genuine
/// search for the font.
SettingsEgg? settingsEggFor(String query) =>
    _triggers[normalizeForSearch(_fold(query))];

/// The card shown above the ordinary results when the search box is asked one
/// of the questions in [_triggers].
///
/// It sits *above* real results rather than replacing them, because `zen` is
/// also a genuine search for the Zen Maru Gothic font and an easter egg should
/// never cost someone the setting they were actually looking for.
class SettingsEggCard extends StatefulWidget {
  const SettingsEggCard(this.egg, {super.key});

  final SettingsEgg egg;

  @override
  State<SettingsEggCard> createState() => _SettingsEggCardState();
}

class _SettingsEggCardState extends State<SettingsEggCard> {
  @override
  void initState() {
    super.initState();
    Haptics.selection();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CalmCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.xl,
      ),
      child: Center(
        child: switch (widget.egg) {
          SettingsEgg.enso => const BrushedEnso(size: 104),
          SettingsEgg.zen => const InkLine(width: 160),
          SettingsEgg.brand => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SealStamp(size: 88),
                const SizedBox(height: Insets.md),
                Text(
                  AppInfo.tagline,
                  textAlign: TextAlign.center,
                  style: handwrittenFrom(
                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                            ) ??
                        const TextStyle(),
                  ),
                ),
              ],
            ),
        },
      ),
    );
  }
}
