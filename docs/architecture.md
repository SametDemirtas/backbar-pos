# Architecture: widget trees and file manifest

This was drafted before any UI code, to settle what belongs in core and what
belongs in each app, and has been kept in step with the code since. Private
widgets (`_Name`) live in the file shown next to them.

## The boundary rule

**`packages/core` owns everything that would be identical if you wrote the
second app from scratch.** Models, Firestore access, order arithmetic, theme
tokens, and the widgets that render a *concept* both apps share (a price, a
sold-out state, a stream that might be loading or broken).

**`apps/*` own layout only.** A till and a phone lay out nothing alike, so the
grid, the rail, the panel and the sheet are app-local. Colours, radii, spacing,
type and touch sizes come from `PosTheme` and the metrics in core; layout
breakpoints stay in the app that uses them.

Two greps check the boundary: `apps/pos` and `apps/manager` contain no
`cloud_firestore` or `FirebaseFirestore`, and no `Color(0x…)` literal. Both apps
get their repositories from core and only pass a venue id.

---

## POS: tablet and web

```
PosApp                                          apps/pos/lib/main.dart
└── MaterialApp(theme: PosTheme.backbar)
    └── AppBootstrap                            core/src/app/app_bootstrap.dart
        │   initialises Firebase (the emulator when built with
        │   USE_FIREBASE_EMULATOR), signs in anonymously,
        │   renders a loading or _BootFailure screen instead of the child
        └── _TillRoot → PosHomePage             apps/pos/lib/src/pos_home_page.dart
            │   (_TillRoot, in main.dart, creates the repositories once)
            │   owns: OrderController, CheckoutController, selected MenuCategory
            │   listens: MenuRepository.watchMenu(), MenuLinkTracker
            ├── MarqueeRail                     apps/pos/lib/src/widgets/marquee_rail.dart
            │   └── MarqueeLabel × 4            core/src/ui/marquee_label.dart
            ├── Column (horizontal rail under 900 wide, top bar, CustomScrollView),
            │   or one CustomScrollView in a short window with the rail pinned
            │   ├── _TillTopBar                 apps/pos/lib/src/pos_home_page.dart
            │   │   └── LiveDot                 core/src/ui/live_dot.dart
            │   └── _MenuGrid → SliverGrid      apps/pos/lib/src/pos_home_page.dart
            │       │   (StateLoading / StateMessage from core in its place while
            │       │    the menu is loading, empty or broken; the check stays up)
            │           └── MenuTile × N        apps/pos/lib/src/widgets/menu_tile.dart
            │               ├── ChangeFlash     core/src/ui/change_flash.dart
            │               ├── SoldOutHatch    core/src/ui/sold_out.dart
            │               ├── SoldOutTag      core/src/ui/sold_out.dart
            │               └── PriceText       core/src/ui/price_text.dart
            └── OrderPanel                      apps/pos/lib/src/widgets/order_panel.dart
                ├── OrderLineRow × N            apps/pos/lib/src/widgets/order_panel.dart
                │   └── PriceText
                ├── StateMessage (empty check)  core/src/ui/state_message.dart
                ├── Notice (still sending, send failed)  core/src/ui/state_message.dart
                └── _Footer                     apps/pos/lib/src/widgets/order_panel.dart
                    ├── PriceText (total, display size)
                    └── PosButton × 2           core/src/ui/pos_button.dart
```

**State.** `OrderController` (the check) and `CheckoutController` (the send:
in flight, slow, failed, and the retry id) are `ChangeNotifier`s held by
`PosHomePage`. The order panel reads both through one `ListenableBuilder`; the
grid reads the check through its own. No state-management package: one screen
with one piece of mutable state does not need an injection framework.

**Live menu.** A single `StreamBuilder` on `MenuRepository.watchMenu`, built
around the till rather than inside a `StreamStateView`, so an errored stream
replaces the grid and never unmounts the check. The header reads CONNECTING,
LIVE or OFFLINE from that stream's state together with a `MenuLinkTracker`
(shared with the manager app), which follows `watchMenuIsLive()`: whether the
server has confirmed the menu or it is coming from the cache. Firestore's
`snapshots()` is the live channel: there is no polling, no refresh button, and
no manual invalidation anywhere in the codebase.

**Small windows.** Under 640 wide the check moves below the grid, unless the
window is also short (under 480) and still at least 520 wide, as a phone on its
side is: there the two stay side by side. Under 480 high the menu side becomes
one scroll view: a one-line top bar and the grid scroll together, under the
horizontal category rail, which stays pinned (from 900 wide the rail is the
vertical one beside the menu instead). The order panel caps its footer so the
lines above it never disappear, and keeps the send buttons in view; only in a
panel under 130 high does everything, buttons included, scroll together.

---

## Manager: phone

```
ManagerApp                                      apps/manager/lib/main.dart
└── MaterialApp(theme: PosTheme.daylight)
    └── AppBootstrap                            (the same widget, from core)
        └── _ManagerRoot → MenuListPage         apps/manager/lib/src/menu_list_page.dart
            │   listens: MenuRepository.watchMenu(), MenuLinkTracker
            ├── _PhoneWidth  (holds the list to a phone's width on a desktop)
            │   └── StreamStateView<List<MenuItem>>
            │       └── CustomScrollView
            │           ├── _SummaryHeader      apps/manager/lib/src/menu_list_page.dart
            │           │   ├── _LiveBadge → LiveDot (LIVE / CONNECTING / OFFLINE)
            │           │   └── _Stat × 3  (in a Wrap)
            │           ├── StateMessage        (in place of the list while the menu is empty)
            │           └── _MenuList → SliverList
            │               ├── MarqueeLabel  (category header)
            │               └── MenuRow × N     apps/manager/lib/src/widgets/menu_row.dart
            │                   ├── ChangeFlash
            │                   ├── SoldOutHatch
            │                   ├── PriceText
            │                   └── AvailabilityPill
            │                       apps/manager/lib/src/widgets/availability_pill.dart
            └── PosButton (new item)

MenuEditorSheet                                 apps/manager/lib/src/menu_editor_sheet.dart
│   modal bottom sheet, one widget for create and edit
├── TextFormField  (name)
├── TextFormField  (price, Money.tryParse)
├── _CategorySegments                           apps/manager/lib/src/menu_editor_sheet.dart
├── _AvailabilityRow → AvailabilityPill        apps/manager/lib/src/menu_editor_sheet.dart
├── Notice  (a notice on open, or a failed save or delete)
│                                               core/src/ui/state_message.dart
├── PosButton (save)
└── PosButton (delete → AlertDialog)
```

**State.** A `StatefulWidget` with a `GlobalKey<FormState>`. Validation lives in
`MenuItemDraft` in core so the same rules apply if a second client is ever
written; the widget only surfaces the messages.

**Availability writes.** `AvailabilityPill` shows a pending state from the tap
until the stream reflects the new value, and is otherwise driven by the stream,
not by local state: on failure the next snapshot puts it back and a snackbar
says why. Offline, Firestore applies the write to its cache at once, so the row
settles without waiting for a server acknowledgement that may be minutes away.
The editor likewise stops waiting after `MenuEditorSheet.acknowledgementGrace`
and says the change is saved on the phone.

---

## File manifest: `packages/core`

```
lib/backbar_pos_core.dart                 barrel export
lib/src/
  models/
    menu_category.dart                   the closed category set
    menu_item.dart                       MenuItem, MenuItemPatch, MenuItemDraft
    order.dart                           OrderLine, Order, CheckTooLarge
  money/
    money.dart                           cents ↔ display, parsing, formatting
  order/
    order_controller.dart                ChangeNotifier cart
    checkout_controller.dart             the send: in flight, slow, failed, retry id
  data/
    firestore_paths.dart                 collection refs + the Timestamp-aware converter
    menu_repository.dart                 watch / create / update / delete / setAvailability
    order_repository.dart                newOrderId / submit (retry-safe)
    menu_link.dart                       MenuLinkTracker: CONNECTING / LIVE / OFFLINE, shared by both apps
  app/
    app_bootstrap.dart                   Firebase init + anonymous sign-in + boot UI
    failure_text.dart                    exceptions → what to tell the person holding the device
    venue.dart                           VenueConfig (venueId, currency, till and station labels)
  theme/
    pos_palette.dart                     the two ramps as a ThemeExtension
    pos_type.dart                        Archivo roles, variable axes, tabular figures
    pos_theme.dart                       PosTheme.backbar / PosTheme.daylight
    pos_metrics.dart                     spacing, radii, durations, touch targets
  ui/
    price_text.dart          marquee_label.dart      live_dot.dart
    sold_out.dart            change_flash.dart       pos_button.dart
    state_message.dart       stream_state_view.dart  focus_ring.dart
assets/fonts/Archivo.ttf                 Archivo, OFL
```

## Test manifest

| File | Covers |
|---|---|
| `test/money_test.dart` | parsing, formatting, rounding, negative and overflow inputs |
| `test/menu_item_test.dart` | Firestore round-trip, malformed documents, unknown category, defaults, edit patches |
| `test/order_test.dart` | line identity, totals, unsellable detection |
| `test/order_repository_test.dart` | order submission shape, empty-order refusal |
| `test/regression_test.dart` | defects that cost money if they come back, one test each |
| `test/checkout_controller_test.dart` | only sent lines come off, failures keep the check, retry ids, slow sends |
| `test/failure_text_test.dart` | error codes become plain sentences, raw messages never shown |
| `test/order_controller_test.dart` | add, increment, remove, clear, total, price snapshotting, sold-out reconciliation |
| `test/menu_repository_test.dart` | streams and writes against `fake_cloud_firestore` |
| `test/menu_link_test.dart` | connecting before the first server confirmation, offline after losing it |
| `test/ui/shared_widgets_test.dart` | shared widgets render both themes, sold-out carries three channels |
| `apps/pos/test/` | tap-to-add updates the total, sold-out tile is not tappable, live snapshot updates the grid, failure paths keep the check |
| `apps/manager/test/` | create / edit / delete flows, validation messages, toggle write, offline writes, failures shown in the sheet |
| `tools/rules.test.js` | rules unit tests on the emulator |
