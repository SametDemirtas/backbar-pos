import 'dart:async';

import 'package:flutter/material.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

import 'menu_editor_sheet.dart';
import 'widgets/menu_row.dart';

class MenuListPage extends StatefulWidget {
  const MenuListPage({
    super.key,
    required this.repository,
    required this.venue,
  });

  final MenuRepository repository;
  final VenueConfig venue;

  @override
  State<MenuListPage> createState() => _MenuListPageState();
}

class _MenuListPageState extends State<MenuListPage> {
  late final Stream<List<MenuItem>> _menu = widget.repository.watchMenu().map(
    _settle,
  );

  late final MenuLinkTracker _link;

  @override
  void initState() {
    super.initState();
    _link = MenuLinkTracker(widget.repository)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  final Map<String, bool> _pending = {};

  List<MenuItem> _settle(List<MenuItem> menu) {
    _pending.removeWhere(
      (id, target) =>
          !menu.any((item) => item.id == id && item.isAvailable != target),
    );
    return menu;
  }

  Future<void> _toggle(MenuItem item) async {
    if (!item.isAvailable && item.blockedFromSale) {
      _openEditor(item, switch ((item.name.isEmpty, item.priceCents == 0)) {
        (true, true) =>
          'This item has no name and no usable price. Fill in both before '
              'putting it back on sale.',
        (true, false) =>
          'This item has no name. Give it one before putting it back on '
              'sale.',
        _ =>
          '${item.name} has no usable price. Set one before putting it '
              'back on sale.',
      });
      return;
    }

    final target = !item.isAvailable;
    setState(() => _pending[item.id] = target);
    try {
      await widget.repository.setAvailability(item.id, isAvailable: target);
    } catch (error) {
      debugPrint('Availability write failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update ${item.displayName}. ${describeFailure(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted && _pending[item.id] == target) {
        setState(() => _pending.remove(item.id));
      }
    }
  }

  void _openEditor([MenuItem? existing, String? notice]) {
    MenuEditorSheet.show(
      context,
      repository: widget.repository,
      currencySymbol: widget.venue.currencySymbol,
      existing: existing,
      notice: notice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final emptyTitle = _link.hasBeenLive
        ? 'No menu yet'
        : 'Waiting for the menu';
    final emptyDetail = _link.hasBeenLive
        ? 'Add the first item and it appears on every till.'
        : 'This phone has not reached the server yet.';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _PhoneWidth(
          child: StreamStateView<List<MenuItem>>(
            stream: _menu,
            emptyTitle: emptyTitle,
            emptyDetail: emptyDetail,
            errorTitle: 'Cannot reach the menu',
            builder: (context, menu) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _SummaryHeader(
                      venue: widget.venue,
                      menu: menu,
                      link: _link.link(),
                    ),
                  ),
                  if (menu.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: StateMessage(
                        title: emptyTitle,
                        detail: emptyDetail,
                      ),
                    )
                  else
                    _MenuList(
                      menu: menu,
                      currencySymbol: widget.venue.currencySymbol,
                      pending: _pending,
                      onEdit: _openEditor,
                      onToggle: _toggle,
                    ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: _PhoneWidth(
          fillHeight: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PosSpace.x4,
              PosSpace.x3,
              PosSpace.x4,
              PosSpace.x5,
            ),
            child: PosButton(
              label: 'NEW ITEM',
              kind: PosButtonKind.primary,
              height: PosTouch.action,
              onPressed: () => _openEditor(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneWidth extends StatelessWidget {
  const _PhoneWidth({required this.child, this.fillHeight = true});

  static const double maxWidth = 560;

  final Widget child;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: fillHeight ? null : 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class _MenuList extends StatelessWidget {
  const _MenuList({
    required this.menu,
    required this.currencySymbol,
    required this.pending,
    required this.onEdit,
    required this.onToggle,
  });

  final List<MenuItem> menu;
  final String currencySymbol;

  final Map<String, bool> pending;
  final ValueChanged<MenuItem> onEdit;
  final ValueChanged<MenuItem> onToggle;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    MenuCategory? lastCategory;

    for (final item in menu) {
      if (item.category != lastCategory) {
        lastCategory = item.category;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PosSpace.x4,
              PosSpace.x5,
              PosSpace.x4,
              PosSpace.x2,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MarqueeLabel(item.category.label, header: true),
            ),
          ),
        );
      }
      rows.add(
        MenuRow(
          key: ValueKey(item.id),
          item: item,
          currencySymbol: currencySymbol,
          pending: switch (pending[item.id]) {
            final target? => target != item.isAvailable,
            null => false,
          },
          onEdit: () => onEdit(item),
          onToggle: () => onToggle(item),
        ),
      );
    }

    return SliverList.list(children: rows);
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.venue,
    required this.menu,
    required this.link,
  });

  final VenueConfig venue;
  final List<MenuItem> menu;

  final MenuLink link;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final soldOut = menu.where((item) => !item.isAvailable).length;
    final categories = menu.map((item) => item.category).toSet().length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        PosSpace.x4,
        PosSpace.x5,
        PosSpace.x4,
        PosSpace.x4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        venue.displayName,
                        style: PosType.headline.copyWith(
                          color: palette.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    MarqueeLabel(
                      'Menu control',
                      style: PosType.meta,
                      color: palette.textMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PosSpace.x3),
              _LiveBadge(link: link),
            ],
          ),
          const SizedBox(height: PosSpace.x5),
          Wrap(
            spacing: PosSpace.x5,
            runSpacing: PosSpace.x3,
            children: [
              _Stat(value: menu.length - soldOut, label: 'On sale'),
              _Stat(value: soldOut, label: 'Sold out', alarming: soldOut > 0),
              _Stat(value: categories, label: 'Categories'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.link});

  final MenuLink link;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: palette.marquee.withValues(alpha: 0.16),
          borderRadius: PosRadius.badge,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (link == MenuLink.live) ...[
              LiveDot(size: 6, color: palette.marqueeInk),
              const SizedBox(width: 7),
            ],
            Text(
              link.label,
              style: PosType.tag.copyWith(color: palette.marqueeInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.alarming = false,
  });

  final int value;
  final String label;
  final bool alarming;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: PosType.stat.copyWith(
              color: alarming ? palette.emberInk : palette.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          MarqueeLabel(label, style: PosType.tag, color: palette.textMuted),
        ],
      ),
    );
  }
}
