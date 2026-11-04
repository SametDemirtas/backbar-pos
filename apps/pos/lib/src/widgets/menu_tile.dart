import 'package:flutter/material.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.item,
    required this.quantityInOrder,
    required this.onTap,
    required this.currencySymbol,
  });

  final MenuItem item;

  final int quantityInOrder;

  final VoidCallback onTap;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final soldOut = !item.isAvailable;
    final inOrder = quantityInOrder > 0;

    return ChangeFlash(
      signature: item,
      child: FocusRing(
        outset: true,
        child: Semantics(
          button: !soldOut,
          enabled: !soldOut,
          label: [
            item.displayName,
            item.price.format(symbol: currencySymbol),
            if (soldOut) 'sold out',
            if (inOrder) '$quantityInOrder on this order',
          ].join(', '),
          onTap: soldOut ? null : onTap,
          child: ExcludeSemantics(
            child: Material(
              color: inOrder ? palette.raised : palette.surface,
              borderRadius: PosRadius.control,
              child: InkWell(
                onTap: soldOut ? null : onTap,
                borderRadius: PosRadius.control,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: PosRadius.control,
                    border: Border.all(color: palette.line),
                  ),
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      if (soldOut) const Positioned.fill(child: SoldOutHatch()),
                      Padding(
                        padding: const EdgeInsets.all(PosSpace.x4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (soldOut)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: SoldOutTag(),
                              ),
                            Flexible(
                              child: Text(
                                item.displayName,
                                style: PosType.tileTitle.copyWith(
                                  color: soldOut
                                      ? palette.textMuted
                                      : palette.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: PriceText(
                                      item.price,
                                      style: PosType.tilePrice,
                                      struck: soldOut,
                                      symbol: currencySymbol,
                                    ),
                                  ),
                                ),
                                if (inOrder) _QuantityBadge(quantityInOrder),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  const _QuantityBadge(this.quantity);

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.marquee,
        borderRadius: PosRadius.badge,
      ),
      child: Text(
        '$quantity',
        style: PosType.badge.copyWith(color: palette.onMarquee),
      ),
    );
  }
}
