import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/icon_suggester.dart';

/// A small circular button showing the currently-selected icon. Tapping it
/// opens a searchable grid of every icon in [kCategoryIcons]. Used by both the
/// category editor and the quick-add sheet, so icon choosing is DRY.
class IconChoiceButton extends StatelessWidget {
  const IconChoiceButton({
    required this.codePoint,
    required this.color,
    required this.onChanged,
    this.suggested = false,
    super.key,
  });

  /// Currently selected icon code point.
  final int codePoint;

  /// Tint for the icon preview (usually the category colour or accent).
  final Color color;

  /// Called with the newly picked code point.
  final ValueChanged<int> onChanged;

  /// When true, shows a tiny "auto" dot to hint the icon was auto-detected.
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: 'Choose icon',
      child: InkWell(
        onTap: () async {
          final picked = await showIconPickerSheet(
            context,
            selected: codePoint,
            color: color,
          );
          if (picked != null) onChanged(picked);
        },
        borderRadius: Corners.md,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: Corners.md,
                border: Border.all(color: colors.border),
              ),
              child: Icon(categoryIcon(codePoint), size: 24, color: color),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  suggested ? Icons.auto_awesome : Icons.edit,
                  size: 12,
                  color: suggested ? colors.accent : colors.textFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a modal bottom sheet with a live search field and a scrollable grid of
/// every icon in [kCategoryIcons]. Returns the chosen code point, or null.
Future<int?> showIconPickerSheet(
  BuildContext context, {
  required int selected,
  required Color color,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _IconPickerSheet(selected: selected, color: color),
  );
}

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({required this.selected, required this.color});

  final int selected;
  final Color color;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    // When the user types, surface the icons the suggestion engine maps to that
    // word first; if nothing matches, fall back to the full list. One source of
    // truth (IconSuggester) drives both auto-detect and search.
    final matches = IconSuggester.searchCodePoints(_query);
    final List<IconData> all = _query.isEmpty || matches.isEmpty
        ? kCategoryIcons
        : matches.map(categoryIcon).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose an icon', style: text.titleLarge),
            const SizedBox(height: Insets.md),
            TextField(
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Search e.g. food, car, gym',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: Insets.md),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: Insets.sm,
                  crossAxisSpacing: Insets.sm,
                ),
                itemCount: all.length,
                itemBuilder: (context, i) {
                  final ic = all[i];
                  final isSel = ic.codePoint == widget.selected;
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(ic.codePoint),
                    borderRadius: Corners.sm,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSel
                            ? widget.color.withValues(alpha: 0.16)
                            : colors.surfaceMuted,
                        borderRadius: Corners.sm,
                        border: Border.all(
                          color: isSel ? widget.color : colors.border,
                          width: isSel ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        ic,
                        size: 22,
                        color: isSel ? widget.color : colors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
