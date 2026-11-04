import 'package:flutter/material.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

class MarqueeRail extends StatelessWidget {
  const MarqueeRail({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
    this.axis = Axis.vertical,
  });

  final List<MenuCategory> categories;
  final MenuCategory? selected;
  final ValueChanged<MenuCategory> onSelect;

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final vertical = axis == Axis.vertical;

    final tabs = [
      for (final category in categories)
        _RailTab(
          category: category,
          selected: category == selected,
          axis: axis,
          onTap: () => onSelect(category),
        ),
    ];

    if (!vertical) {
      return Material(
        color: palette.well,
        child: Container(
          height: PosTouch.control,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.line)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: PosSpace.x2),
            children: tabs,
          ),
        ),
      );
    }

    return Material(
      color: palette.well,
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: palette.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: PosSpace.x4),
            const _VenueMark(),
            const SizedBox(height: PosSpace.x6),
            Expanded(child: ListView(children: tabs)),
          ],
        ),
      ),
    );
  }
}

class _VenueMark extends StatelessWidget {
  const _VenueMark();

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    return Center(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.marquee,
          borderRadius: PosRadius.badge,
        ),
        child: Text(
          'B',
          style: PosType.venueMark.copyWith(color: palette.onMarquee),
        ),
      ),
    );
  }
}

class _RailTab extends StatelessWidget {
  const _RailTab({
    required this.category,
    required this.selected,
    required this.axis,
    required this.onTap,
  });

  final MenuCategory category;
  final bool selected;
  final Axis axis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final vertical = axis == Axis.vertical;
    final accent = selected ? palette.marquee : palette.textMuted;

    return FocusRing(
      borderRadius: BorderRadius.zero,
      child: Semantics(
        button: true,
        selected: selected,
        label: category.label,
        onTap: onTap,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(
                minWidth: vertical ? 0 : PosTouch.control,
                minHeight: vertical ? PosTouch.control : 0,
              ),
              padding: vertical
                  ? const EdgeInsets.symmetric(vertical: PosSpace.x5)
                  : const EdgeInsets.symmetric(horizontal: PosSpace.x4),
              decoration: BoxDecoration(
                border: selected
                    ? Border(
                        left: vertical
                            ? BorderSide(color: palette.marquee, width: 3)
                            : BorderSide.none,
                        bottom: vertical
                            ? BorderSide.none
                            : BorderSide(color: palette.marquee, width: 3),
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: MarqueeLabel(category.label, color: accent, axis: axis),
            ),
          ),
        ),
      ),
    );
  }
}
