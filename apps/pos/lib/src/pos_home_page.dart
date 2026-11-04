import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

import 'widgets/marquee_rail.dart';
import 'widgets/menu_tile.dart';
import 'widgets/order_panel.dart';

class PosHomePage extends StatefulWidget {
  const PosHomePage({
    super.key,
    required this.menuRepository,
    required this.orderRepository,
    required this.venue,
    required this.staffUid,
  });

  final MenuRepository menuRepository;
  final OrderRepository orderRepository;
  final VenueConfig venue;

  final String staffUid;

  @override
  State<PosHomePage> createState() => _PosHomePageState();
}

class _PosHomePageState extends State<PosHomePage> {
  final OrderController _order = OrderController();
  late final CheckoutController _checkout = CheckoutController(
    order: _order,
    repository: widget.orderRepository,
    tillLabel: widget.venue.tillLabel,
    staffUid: widget.staffUid,
  );
  late final Stream<List<MenuItem>> _menu = widget.menuRepository.watchMenu();
  late final Listenable _checkState = Listenable.merge([_order, _checkout]);

  MenuCategory? _category;
  MenuCategory? _shown;

  final ScrollController _menuScroll = ScrollController();

  late final MenuLinkTracker _link;

  @override
  void initState() {
    super.initState();
    _link = MenuLinkTracker(widget.menuRepository)
      ..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(PosHomePage old) {
    super.didUpdateWidget(old);
    _checkout.configure(
      repository: widget.orderRepository,
      tillLabel: widget.venue.tillLabel,
      staffUid: widget.staffUid,
    );
  }

  @override
  void dispose() {
    _menuScroll.dispose();
    _link.dispose();
    _checkout.dispose();
    _order.dispose();
    super.dispose();
  }

  void _followShown(MenuCategory shown) {
    if (shown == _shown) return;
    final moved = _shown != null;
    _shown = shown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _category = shown;
      if (moved && _menuScroll.hasClients) _menuScroll.jumpTo(0);
    });
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await _checkout.send();
    if (sent == null || !mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Sent ${sent.itemCount} '
          '${sent.itemCount == 1 ? 'item' : 'items'} · '
          '${sent.total.format(symbol: widget.venue.currencySymbol)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<MenuItem>>(
          stream: _menu,
          builder: (context, snapshot) {
            final menu = snapshot.data ?? const <MenuItem>[];
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final shown = _Till.shownCategory(menu, _category);
            if (menu.isNotEmpty) _followShown(shown);
            return _Till(
              menu: menu,
              menuError: snapshot.error,
              menuLoading: loading,
              link: _link.link(
                menuError: snapshot.hasError,
                menuLoading: loading,
              ),
              order: _order,
              checkout: _checkout,
              checkState: _checkState,
              venue: widget.venue,
              category: shown,
              menuScroll: _menuScroll,
              onSelectCategory: (category) {
                setState(() => _category = _shown = category);
                if (_menuScroll.hasClients) _menuScroll.jumpTo(0);
              },
              onSend: _send,
            );
          },
        ),
      ),
    );
  }
}

class _Till extends StatelessWidget {
  const _Till({
    required this.menu,
    required this.menuError,
    required this.menuLoading,
    required this.link,
    required this.order,
    required this.checkout,
    required this.checkState,
    required this.venue,
    required this.category,
    required this.onSelectCategory,
    required this.menuScroll,
    required this.onSend,
  });

  final List<MenuItem> menu;

  final Object? menuError;

  final bool menuLoading;

  final MenuLink link;
  final OrderController order;
  final CheckoutController checkout;

  final Listenable checkState;
  final VenueConfig venue;
  final MenuCategory category;
  final ValueChanged<MenuCategory> onSelectCategory;
  final ScrollController menuScroll;
  final VoidCallback onSend;

  static List<MenuCategory> categoriesOf(List<MenuItem> menu) => [
    for (final candidate in MenuCategory.values)
      if (menu.any((item) => item.category == candidate)) candidate,
  ];

  static MenuCategory shownCategory(List<MenuItem> menu, MenuCategory? wanted) {
    final categories = categoriesOf(menu);
    return categories.contains(wanted)
        ? wanted!
        : (categories.firstOrNull ?? MenuCategory.drinks);
  }

  @override
  Widget build(BuildContext context) {
    final categories = categoriesOf(menu);
    final selected = category;
    final visible = [
      for (final item in menu)
        if (item.category == selected) item,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final panelWidth = wide
            ? 376.0
            : (constraints.maxWidth * 0.38).clamp(320.0, 376.0);

        final roomy = constraints.maxHeight >= 480;
        final rail = MarqueeRail(
          categories: categories,
          selected: selected,
          onSelect: onSelectCategory,
          axis: Axis.horizontal,
        );
        final sectionLabel = SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PosSpace.x5,
              PosSpace.x5,
              PosSpace.x5,
              PosSpace.x3,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MarqueeLabel(
                '${selected.label} · ${visible.length} '
                '${visible.length == 1 ? 'item' : 'items'}',
                header: true,
              ),
            ),
          ),
        );
        final Widget content;
        if (menuError != null) {
          content = SliverFillRemaining(
            hasScrollBody: false,
            child: StateMessage(
              title: 'Cannot reach the menu',
              detail: describeFailure(menuError!),
              tone: StateTone.error,
            ),
          );
        } else if (menuLoading) {
          content = const SliverFillRemaining(
            hasScrollBody: false,
            child: StateLoading(),
          );
        } else if (menu.isEmpty && link == MenuLink.connecting) {
          content = const SliverFillRemaining(
            hasScrollBody: false,
            child: StateMessage(
              title: 'Waiting for the menu',
              detail:
                  'This till has not reached the server yet. The menu '
                  'appears as soon as it does.',
            ),
          );
        } else if (menu.isEmpty) {
          content = const SliverFillRemaining(
            hasScrollBody: false,
            child: StateMessage(
              title: 'This venue has no menu yet',
              detail: 'Add the first item from the manager app.',
            ),
          );
        } else {
          content = _MenuGrid(
            items: visible,
            order: order,
            currencySymbol: venue.currencySymbol,
          );
        }

        final Widget menuColumn = roomy
            ? Column(
                children: [
                  if (!wide) rail,
                  _TillTopBar(venue: venue, status: link),
                  Expanded(
                    child: CustomScrollView(
                      key: const ValueKey('menu-scroll'),
                      controller: menuScroll,
                      slivers: [if (menu.isNotEmpty) sectionLabel, content],
                    ),
                  ),
                ],
              )
            : CustomScrollView(
                key: const ValueKey('menu-scroll'),
                controller: menuScroll,
                slivers: [
                  if (!wide)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PinnedRail(rail),
                    ),
                  SliverToBoxAdapter(
                    child: _TillTopBar(venue: venue, status: link, dense: true),
                  ),
                  content,
                ],
              );

        final stacked =
            constraints.maxWidth < 640 &&
            (constraints.maxHeight >= 480 || constraints.maxWidth < 520);

        final orderPanel = ListenableBuilder(
          listenable: checkState,
          builder: (context, _) => OrderPanel(
            order: order.order,
            unsellableItemIds: menuError != null || menuLoading
                ? const <String>{}
                : order.unsellableItemIds(menu),
            currencySymbol: venue.currencySymbol,
            tillLabel: venue.tillLabel,
            onRemoveOne: order.removeOne,
            onRemoveLine: order.removeLine,
            onClear: order.clear,
            onSend: onSend,
            sending: checkout.sending,
            sendSlow: checkout.slow,
            sendErrorRetryable: checkout.error is! CheckTooLarge,
            sendError: switch (checkout.error) {
              final error? => describeFailure(error),
              null => null,
            },
          ),
        );

        if (stacked) {
          return Column(
            children: [
              Expanded(child: menuColumn),
              SizedBox(
                height: math.min(
                  constraints.maxHeight / 2,
                  math.max(constraints.maxHeight * 0.4, 300),
                ),
                child: orderPanel,
              ),
            ],
          );
        }

        return Row(
          children: [
            if (wide)
              MarqueeRail(
                categories: categories,
                selected: selected,
                onSelect: onSelectCategory,
              ),
            Expanded(child: menuColumn),
            SizedBox(width: panelWidth, child: orderPanel),
          ],
        );
      },
    );
  }
}

class _TillTopBar extends StatelessWidget {
  const _TillTopBar({
    required this.venue,
    required this.status,
    this.dense = false,
  });

  final VenueConfig venue;
  final MenuLink status;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: dense ? 48 : 76),
      padding: const EdgeInsets.symmetric(horizontal: PosSpace.x5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    venue.displayName,
                    style: PosType.tillVenue.copyWith(
                      color: palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!dense) ...[
                  const SizedBox(height: 3),
                  MarqueeLabel(
                    [venue.tillLabel, ?venue.stationLabel].join(' · '),
                    color: palette.textMuted,
                    style: PosType.meta,
                  ),
                ],
              ],
            ),
          ),
          if (status == MenuLink.live) ...[
            const LiveDot(),
            const SizedBox(width: PosSpace.x2),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Semantics(
                liveRegion: true,
                container: true,
                child: Text(
                  status.label,
                  style: PosType.status.copyWith(
                    color: status == MenuLink.offline
                        ? palette.emberInk
                        : palette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({
    required this.items,
    required this.order,
    required this.currencySymbol,
  });

  final List<MenuItem> items;
  final OrderController order;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: order,
      builder: (context, _) => _buildGrid(context),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const minTileWidth = 208.0;
        final columns =
            ((constraints.crossAxisExtent - PosSpace.x5 * 2) /
                    (minTileWidth + PosSpace.x3))
                .floor()
                .clamp(1, 6);

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            PosSpace.x5,
            PosSpace.x2,
            PosSpace.x5,
            PosSpace.x5,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: PosSpace.x3,
              crossAxisSpacing: PosSpace.x3,
              mainAxisExtent: math.max(
                PosTouch.tile,
                PosTouch.tile * MediaQuery.textScalerOf(context).scale(16) / 16,
              ),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return MenuTile(
                  key: ValueKey(item.id),
                  item: item,
                  quantityInOrder: order.quantityOf(item.id),
                  currencySymbol: currencySymbol,
                  onTap: () => order.add(item),
                );
              },
              childCount: items.length,
              findChildIndexCallback: (key) {
                final index = items.indexWhere(
                  (item) => ValueKey(item.id) == key,
                );
                return index == -1 ? null : index;
              },
            ),
          ),
        );
      },
    );
  }
}

class _PinnedRail extends SliverPersistentHeaderDelegate {
  const _PinnedRail(this.rail);

  final Widget rail;

  @override
  double get minExtent => PosTouch.control;

  @override
  double get maxExtent => PosTouch.control;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => rail;

  @override
  bool shouldRebuild(_PinnedRail old) => old.rail != rail;
}
