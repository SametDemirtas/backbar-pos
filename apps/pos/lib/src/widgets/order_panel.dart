import 'package:flutter/material.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

class OrderPanel extends StatelessWidget {
  const OrderPanel({
    super.key,
    required this.order,
    required this.unsellableItemIds,
    required this.currencySymbol,
    required this.tillLabel,
    required this.onRemoveOne,
    required this.onRemoveLine,
    required this.onClear,
    required this.onSend,
    this.sending = false,
    this.sendSlow = false,
    this.sendError,
    this.sendErrorRetryable = true,
  });

  final Order order;

  final Set<String> unsellableItemIds;

  final String currencySymbol;
  final String tillLabel;

  final void Function(String lineKey) onRemoveOne;

  final void Function(String lineKey) onRemoveLine;
  final VoidCallback onClear;
  final VoidCallback onSend;
  final bool sending;

  final bool sendSlow;

  final String? sendError;

  final bool sendErrorRetryable;

  @override
  Widget build(BuildContext context) {
    final header = _Header(tillLabel: tillLabel, itemCount: order.itemCount);
    final rows = <Widget>[
      if (sendSlow) const _Notice(child: _SendSlow()),
      if (sendError != null)
        _Notice(
          child: _SendFailure(
            message: sendError!,
            retryable: sendErrorRetryable,
          ),
        ),
      for (final line in order.lines)
        OrderLineRow(
          key: ValueKey(line.key),
          line: line,
          currencySymbol: currencySymbol,
          unsellable: unsellableItemIds.contains(line.itemId),
          onRemoveOne: sending ? null : () => onRemoveOne(line.key),
          onRemoveLine: sending ? null : () => onRemoveLine(line.key),
        ),
    ];
    final footer = _Footer(
      total: order.total,
      currencySymbol: currencySymbol,
      onClear: order.isEmpty || sending ? null : onClear,
      onSend: order.isEmpty ? null : onSend,
      sending: sending,
      status: sendError != null
          ? (sendErrorRetryable
                ? 'Not sent — see above, then send again'
                : 'Not sent — too big for one order, see above')
          : sendSlow
          ? 'Still sending — do not ring it in again'
          : null,
      statusIsError: sendError != null,
    );

    final palette = PosPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.well,
        border: Border(left: BorderSide(color: palette.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final list = CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: header),
              if (order.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyCheck,
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: PosSpace.x2),
                  sliver: SliverList.list(children: rows),
                ),
            ],
          );
          if (constraints.maxHeight < 130) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  header,
                  if (order.isEmpty) _emptyCheck else ...rows,
                  footer.asTight(scrollable: false),
                ],
              ),
            );
          }
          if (constraints.maxHeight < 260) {
            return Column(
              children: [
                Expanded(child: list),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.85,
                  ),
                  child: footer.asTight(),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: list),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.7,
                ),
                child: footer,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tillLabel, required this.itemCount});

  final String tillLabel;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        PosSpace.x5,
        PosSpace.x5,
        PosSpace.x5,
        PosSpace.x4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const MarqueeLabel('Order', header: true),
          const SizedBox(width: PosSpace.x3),
          Flexible(
            child: Text(
              itemCount == 0
                  ? '$tillLabel · EMPTY'
                  : '$tillLabel · $itemCount ITEM${itemCount == 1 ? '' : 'S'}',
              style: PosType.meta.copyWith(color: palette.textMuted),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class OrderLineRow extends StatelessWidget {
  const OrderLineRow({
    super.key,
    required this.line,
    required this.currencySymbol,
    required this.unsellable,
    required this.onRemoveOne,
    required this.onRemoveLine,
  });

  final OrderLine line;
  final String currencySymbol;

  final bool unsellable;

  final VoidCallback? onRemoveOne;
  final VoidCallback? onRemoveLine;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);

    return FocusRing(
      borderRadius: BorderRadius.zero,
      child: Semantics(
        label: [
          '${line.quantity} × ${line.name}',
          line.amount.format(symbol: currencySymbol),
          if (unsellable) 'no longer on sale',
        ].join(', '),
        button: true,
        enabled: onRemoveOne != null,
        onTap: onRemoveOne,
        onTapHint: 'remove one',
        onLongPress: onRemoveLine,
        onLongPressHint: 'remove the whole line',
        child: ExcludeSemantics(
          child: Material(
            type: unsellable ? MaterialType.canvas : MaterialType.transparency,
            color: unsellable ? palette.emberWash : null,
            child: InkWell(
              onTap: onRemoveOne,
              onLongPress: onRemoveLine,
              child: Container(
                constraints: const BoxConstraints(minHeight: PosTouch.control),
                padding: const EdgeInsets.symmetric(
                  horizontal: PosSpace.x5,
                  vertical: PosSpace.x3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 34,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${line.quantity}',
                          maxLines: 1,
                          style: PosType.money.copyWith(color: palette.marquee),
                        ),
                      ),
                    ),
                    const SizedBox(width: PosSpace.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.name,
                            style: PosType.bodyStrong.copyWith(
                              color: unsellable
                                  ? palette.textSecondary
                                  : palette.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            unsellable
                                ? 'No longer on sale — hold to drop the line'
                                : '${line.unitPrice.format(symbol: currencySymbol)} each',
                            style: PosType.meta.copyWith(
                              color: unsellable
                                  ? palette.emberInk
                                  : palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: PosSpace.x3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: PriceText(
                          line.amount,
                          symbol: currencySymbol,
                          style: PosType.money,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _emptyCheck = StateMessage(title: 'Tap the menu to start a round.');

class _Footer extends StatelessWidget {
  const _Footer({
    required this.total,
    required this.currencySymbol,
    required this.onClear,
    required this.onSend,
    required this.sending,
    required this.status,
    required this.statusIsError,
    this.tight = false,
    this.scrollable = true,
  });

  final Money total;
  final String currencySymbol;
  final VoidCallback? onClear;
  final VoidCallback? onSend;
  final bool sending;

  final String? status;
  final bool statusIsError;

  final bool tight;

  final bool scrollable;

  _Footer asTight({bool scrollable = true}) => _Footer(
    total: total,
    currencySymbol: currencySymbol,
    onClear: onClear,
    onSend: onSend,
    sending: sending,
    status: status,
    statusIsError: statusIsError,
    tight: true,
    scrollable: scrollable,
  );

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);

    final totalRow = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(
          child: Padding(
            padding: EdgeInsets.only(bottom: PosSpace.x2),
            child: MarqueeLabel('Total'),
          ),
        ),
        const SizedBox(width: PosSpace.x3),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: PriceText(
              total,
              style: PosType.total,
              color: total.isZero ? palette.disabled : palette.marquee,
              symbol: currencySymbol,
              semanticsPrefix: 'Total',
            ),
          ),
        ),
      ],
    );
    final statusLine = Semantics(
      liveRegion: true,
      container: true,
      child: status == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: PosSpace.x3),
              child: Text(
                status!,
                style: PosType.meta.copyWith(
                  color: statusIsError
                      ? palette.emberInk
                      : palette.textSecondary,
                ),
                maxLines: tight ? 1 : 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [statusLine, totalRow],
    );

    return Container(
      padding: EdgeInsets.all(tight ? PosSpace.x3 : PosSpace.x5),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (scrollable)
            Flexible(child: SingleChildScrollView(child: body))
          else
            body,
          SizedBox(height: tight ? PosSpace.x3 : PosSpace.x5),
          Row(
            children: [
              SizedBox(
                width: 104,
                child: PosButton(
                  label: 'CLEAR',
                  kind: PosButtonKind.ghost,
                  height: PosTouch.action,
                  onPressed: onClear,
                ),
              ),
              const SizedBox(width: PosSpace.x2),
              Expanded(
                child: PosButton(
                  label: 'SEND ORDER',
                  height: PosTouch.action,
                  busy: sending,
                  onPressed: onSend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosSpace.x5,
        PosSpace.x2,
        PosSpace.x5,
        PosSpace.x2,
      ),
      child: child,
    );
  }
}

class _SendSlow extends StatelessWidget {
  const _SendSlow();

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);

    return Notice(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Still sending',
            style: PosType.bodyStrong.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: 3),
          Text(
            'It will go through when the connection returns. '
            'Do not ring this round in again.',
            style: PosType.meta.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SendFailure extends StatelessWidget {
  const _SendFailure({required this.message, required this.retryable});

  final String message;
  final bool retryable;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);

    return Notice(
      tone: StateTone.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not send the order',
            style: PosType.bodyStrong.copyWith(color: palette.emberInk),
          ),
          const SizedBox(height: 3),
          Text(
            retryable
                ? 'The round is still here. Press send again.'
                : 'The round is still here. Take some lines off and send them as '
                      'a separate order.',
            style: PosType.meta.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: PosSpace.x2),
          Text(
            message,
            style: PosType.meta.copyWith(color: palette.textMuted),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
