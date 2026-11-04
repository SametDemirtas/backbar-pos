import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

import 'widgets/availability_pill.dart';

class MenuEditorSheet extends StatefulWidget {
  const MenuEditorSheet({
    super.key,
    required this.repository,
    required this.currencySymbol,
    this.existing,
    this.notice,
  });

  static const Duration acknowledgementGrace = Duration(seconds: 3);

  final MenuRepository repository;
  final String currencySymbol;

  final MenuItem? existing;

  final String? notice;

  static Future<void> show(
    BuildContext context, {
    required MenuRepository repository,
    required String currencySymbol,
    MenuItem? existing,
    String? notice,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: MenuEditorSheet(
          repository: repository,
          currencySymbol: currencySymbol,
          existing: existing,
          notice: notice,
        ),
      ),
    );
  }

  @override
  State<MenuEditorSheet> createState() => _MenuEditorSheetState();
}

class _MenuEditorSheetState extends State<MenuEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _priceFocus = FocusNode();
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money.fromCents(widget.existing!.priceCents).toEditingString(),
  );

  late MenuCategory _category =
      widget.existing?.category ?? MenuCategory.drinks;
  late bool _isAvailable = widget.existing?.isAvailable ?? true;

  bool _categoryTouched = false;

  bool _saving = false;

  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameFocus.dispose();
    _priceFocus.dispose();
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      final nameError = MenuItemDraft.validateName(_name.text);
      final error = nameError ?? MenuItemDraft.validatePrice(_price.text);
      (nameError != null ? _nameFocus : _priceFocus).requestFocus();
      if (error != null) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          error,
          Directionality.of(context),
        );
      }
      return;
    }

    final price = Money.tryParse(_price.text)!;
    final name = _name.text.trim();

    await _run(
      failed: 'Could not save.',
      handedOff:
          'Saved on this phone. The tills get it when the connection '
          'returns.',
      write: () {
        if (_isEditing) {
          final existing = widget.existing!;
          return widget.repository.update(
            existing.id,
            MenuItemPatch.between(
              existing,
              name: name,
              priceCents: price.cents,
              category: _category,
              categoryTouched: _categoryTouched,
              isAvailable: _isAvailable,
            ),
          );
        } else {
          return widget.repository.create(
            MenuItemDraft(
              name: name,
              priceCents: price.cents,
              category: _category,
              isAvailable: _isAvailable,
            ),
          );
        }
      },
    );
  }

  Future<void> _run({
    required Future<void> Function() write,
    required String handedOff,
    required String failed,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _awaitOrHandOff(
        Future<void>.sync(write),
        messenger,
        handedOff: handedOff,
        failedLater: failed,
      );
      if (mounted && navigator.canPop()) navigator.pop();
    } catch (error) {
      debugPrint('$failed $error');
      final message = '$failed ${describeFailure(error)}';
      if (!mounted) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      } else {
        setState(() {
          _saving = false;
          _error = message;
        });
      }
    }
  }

  Future<void> _awaitOrHandOff(
    Future<void> write,
    ScaffoldMessengerState messenger, {
    required String handedOff,
    required String failedLater,
  }) async {
    final acknowledged = await write
        .then((_) => true)
        .timeout(MenuEditorSheet.acknowledgementGrace, onTimeout: () => false);
    if (acknowledged) return;
    messenger.showSnackBar(SnackBar(content: Text(handedOff)));
    unawaited(
      write.catchError((Object error) {
        debugPrint('$failedLater (after closing) $error');
        messenger.showSnackBar(
          SnackBar(content: Text('$failedLater ${describeFailure(error)}')),
        );
      }),
    );
  }

  Future<void> _delete() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text(
          '${widget.existing!.displayName} will disappear from every till in the '
          'venue. Marking it sold out keeps it on the menu instead.',
        ),
        actions: [
          FocusRing(
            outset: true,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it'),
            ),
          ),
          FocusRing(
            outset: true,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: PosPalette.of(context).emberInk,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _saving) return;

    await _run(
      failed: 'Could not delete.',
      handedOff:
          'Deleted on this phone. The tills lose it when the connection '
          'returns.',
      write: () => widget.repository.delete(widget.existing!.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          PosSpace.x4,
          PosSpace.x2,
          PosSpace.x4,
          PosSpace.x6,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  _isEditing ? 'Edit item' : 'New item',
                  style: PosType.sheetTitle.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (widget.notice != null) ...[
                const SizedBox(height: PosSpace.x3),
                _SheetMessage(widget.notice!, isError: false),
              ],
              const SizedBox(height: PosSpace.x5),

              _FieldLabel('Name'),
              Semantics(
                label: 'Name',
                child: TextFormField(
                  controller: _name,
                  focusNode: _nameFocus,
                  autofocus: !_isEditing,
                  style: PosType.field.copyWith(color: palette.textPrimary),
                  textCapitalization: TextCapitalization.sentences,
                  validator: MenuItemDraft.validateName,
                ),
              ),
              const SizedBox(height: PosSpace.x4),

              _FieldLabel('Price'),
              Semantics(
                label: 'Price',
                child: TextFormField(
                  controller: _price,
                  focusNode: _priceFocus,
                  style: PosType.field.copyWith(color: palette.textPrimary),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    prefixText: '${widget.currencySymbol} ',
                    prefixStyle: PosType.field.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                  validator: MenuItemDraft.validatePrice,
                ),
              ),
              const SizedBox(height: PosSpace.x4),

              _FieldLabel('Category'),
              _CategorySegments(
                selected: _category,
                onChanged: (category) => setState(() {
                  _category = category;
                  _categoryTouched = true;
                }),
              ),
              const SizedBox(height: PosSpace.x5),

              _AvailabilityRow(
                isAvailable: _isAvailable,
                onChanged: (value) => setState(() => _isAvailable = value),
              ),
              const SizedBox(height: PosSpace.x5),

              if (_error != null) ...[
                _SheetMessage(_error!, isError: true),
                const SizedBox(height: PosSpace.x3),
              ],
              PosButton(
                label: 'SAVE',
                height: PosTouch.action,
                busy: _saving,
                onPressed: _save,
              ),
              if (_isEditing) ...[
                const SizedBox(height: PosSpace.x2),
                PosButton(
                  label: 'DELETE ITEM',
                  kind: PosButtonKind.danger,
                  height: PosTouch.action,
                  onPressed: _saving ? null : _delete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: MarqueeLabel(
          text,
          style: PosType.fieldLabel,
          color: PosPalette.of(context).textSecondary,
        ),
      ),
    );
  }
}

class _CategorySegments extends StatelessWidget {
  const _CategorySegments({required this.selected, required this.onChanged});

  final MenuCategory selected;
  final ValueChanged<MenuCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(14) / 14 > 1.15;
    final perRow = large ? 2 : 4;
    final categories = MenuCategory.values;

    return Column(
      children: [
        for (var start = 0; start < categories.length; start += perRow) ...[
          if (start > 0) const SizedBox(height: PosSpace.x2),
          Row(
            children: [
              for (final category in categories.skip(start).take(perRow)) ...[
                if (category != categories[start])
                  const SizedBox(width: PosSpace.x2),
                Expanded(
                  child: _Segment(
                    category: category,
                    selected: category == selected,
                    onTap: () => onChanged(category),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final MenuCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);

    return FocusRing(
      outset: true,
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        selected: selected,
        label: category.label,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Material(
            color: selected ? palette.marquee : palette.well,
            borderRadius: PosRadius.control,
            child: InkWell(
              onTap: onTap,
              borderRadius: PosRadius.control,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: PosRadius.control,
                  border: Border.all(
                    color: selected ? palette.marqueeInk : palette.textMuted,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: PosTouch.control,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PosSpace.x1,
                      vertical: PosSpace.x2,
                    ),
                    child: Center(
                      child: Text(
                        category.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: PosType.tag.copyWith(
                          color: selected
                              ? palette.onMarquee
                              : palette.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({required this.isAvailable, required this.onChanged});

  final bool isAvailable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: PosSpace.x3),
      decoration: BoxDecoration(
        color: palette.well,
        borderRadius: PosRadius.control,
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAvailable ? 'On sale' : 'Sold out',
                  style: PosType.bodyStrong.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAvailable
                      ? 'Tills can sell it right now'
                      : 'Stays on the menu, cannot be sold',
                  style: PosType.meta.copyWith(color: palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: PosSpace.x3),
          AvailabilityPill(
            isAvailable: isAvailable,
            onChanged: () => onChanged(!isAvailable),
            subject: 'availability',
          ),
        ],
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage(this.text, {required this.isError});

  final String text;

  final bool isError;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    return Semantics(
      liveRegion: isError,
      container: true,
      child: Notice(
        tone: isError ? StateTone.error : StateTone.neutral,
        child: Text(
          text,
          style: PosType.bodyStrong.copyWith(
            color: isError ? palette.emberInk : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}
