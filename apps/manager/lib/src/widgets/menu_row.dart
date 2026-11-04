import 'package:flutter/material.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

import 'availability_pill.dart';

class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.item,
    required this.currencySymbol,
    required this.onEdit,
    required this.onToggle,
    this.pending = false,
  });

  final MenuItem item;
  final String currencySymbol;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  final bool pending;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final soldOut = !item.isAvailable;

    return ChangeFlash(
      signature: item,
      child: Material(
        color: palette.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.line)),
          ),
          child: Stack(
            children: [
              if (soldOut) const Positioned.fill(child: SoldOutHatch()),
              Row(
                children: [
                  Expanded(
                    child: FocusRing(
                      borderRadius: BorderRadius.zero,
                      child: Semantics(
                        button: true,
                        label: [
                          item.displayName,
                          item.price.format(symbol: currencySymbol),
                          if (soldOut) 'sold out',
                          'edit',
                        ].join(', '),
                        onTap: onEdit,
                        child: ExcludeSemantics(
                          child: InkWell(
                            onTap: onEdit,
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: PosTouch.control + PosSpace.x4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: PosSpace.x4,
                                vertical: PosSpace.x3,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displayName,
                                    style: PosType.rowTitle.copyWith(
                                      color: soldOut
                                          ? palette.textMuted
                                          : palette.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  PriceText(
                                    item.price,
                                    style: PosType.moneySmall,
                                    color: soldOut
                                        ? palette.disabled
                                        : palette.textSecondary,
                                    struck: soldOut,
                                    symbol: currencySymbol,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: PosSpace.x4),
                    child: AvailabilityPill(
                      isAvailable: item.isAvailable,
                      pending: pending,
                      onChanged: onToggle,
                      subject: item.displayName,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
