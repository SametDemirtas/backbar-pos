# Backbar POS

Backbar POS is a small point-of-sale system for a bar. It has two Flutter apps
that share one Firestore database: a till that runs on a tablet or in a browser
behind the bar, and a phone app the manager uses to change the menu.

When the manager marks the Guinness sold out, every till in the venue updates
on its own within moments. Models, money handling, Firestore access and the
shared widgets live in one Dart package, so each app holds only its own layout.
You can run both apps locally against the Firebase emulator, without a Firebase
account.

```
backbar-pos/
├── packages/core/          the shared layer: models, money, order logic,
│                           Firestore access, theme, common widgets
├── apps/pos/               the till          (tablet and web)
├── apps/manager/           menu control      (phone)
├── firestore.rules         the security rules
├── tools/                  rules tests + the demo menu seeder
├── DESIGN.md               the design system and why it is that way
├── design/                 HTML previews of it, written before any Flutter
└── docs/architecture.md    widget trees and the core/app boundary
```

---

## Running it

Everything runs against the local Firebase emulator, so no Firebase account is
needed.

**Prerequisites:** a Flutter SDK with Dart 3.10.7 or newer (a recent 3.38.x
or later), Node 20+, a JDK 21+ (the Firestore emulator needs one), and
`npm i -g firebase-tools@15.32.1`, the version CI uses.

```bash
make setup      # flutter pub get + npm ci for the tools
make emulator   # terminal 1: Firestore and Auth on localhost
make seed       # terminal 2: a 21-item demo menu, 2 of them sold out
make pos        # terminal 3: the till, in Chrome
make manager    # terminal 4: the manager app, in Chrome
```

Put the two windows side by side and toggle an item in the manager app: on the
till, the tile flashes gold on its leading edge and goes sold out in place.

The manager app is a phone layout. On a desktop browser it holds itself to a
phone's width.

### Against a real Firebase project

First add your venue id to the allowlist in `firestore.rules` and to
`VenueConfig` (`packages/core/lib/src/app/venue.dart`), and enable **Anonymous**
sign-in on the project: both apps sign in anonymously at boot and the rules
require it. Then:

```bash
dart pub global activate flutterfire_cli
(cd apps/pos && flutterfire configure --project <id> --out lib/firebase_options.dart)
(cd apps/manager && flutterfire configure --project <id> --out lib/firebase_options.dart)
firebase deploy --only firestore:rules --project <id>
```

and run without the emulator flag, for example
`cd apps/pos && flutter run -d chrome`. Read the security section below before
pointing anything real at it.

`apps/*/lib/firebase_options.dart` is committed as a placeholder that throws
with these instructions. `flutterfire configure` overwrites it, so keep the
generated file out of your commits:

```bash
git update-index --skip-worktree apps/pos/lib/firebase_options.dart apps/manager/lib/firebase_options.dart
```

---

## Tests

```bash
make check
```

runs all of it:

```bash
flutter analyze                                                   # all three packages
flutter test packages/core/test apps/pos/test apps/manager/test   # 304 Dart tests
npm --prefix tools test                                           # 72 rules tests
```

The Dart tests run against `fake_cloud_firestore`, so they need no emulator and
no network. The rules tests run against the real emulator, since only the rules
engine shows what the rules actually allow. Five of them, at the end of
`tools/rules.test.js`, read the rules file and the Dart source side by side and
fail if the two disagree about the categories, the price ceiling, the order
caps, the maximum name length or the till label length.

---

## Design decisions

**Money is an integer, everywhere.** `Money` holds whole minor units (pence
here, cents in the code). There is no `double` on the money path, and the rules
reject a non-integer price server-side. Prices render with tabular figures, so
a running total does not jitter as it changes.

**The price on a check is a snapshot.** A line holds the price the item had
when it was rung in. Re-price the Guinness mid-round and the open check does not
move; ring in another and you get a second line at the new price.

**Sold out keeps the item on the till.** A sold-out item stays visible, marked
three ways at once (a hatch, a struck price and the words) so a colourblind
bartender in a dark room can still read it. An item that goes sold out while it
is on an open check is flagged and left on the check, because the round may
already be poured.

**The menu is live.** Both apps read the menu through one
`MenuRepository.watchMenu()`, which is Firestore's `snapshots()`. There is no
polling and no cache to invalidate. Both headers say LIVE only while the server
has confirmed the menu (`snapshot.metadata.isFromCache` is false): offline,
Firestore keeps serving the cached menu without an error, so they say
CONNECTING until the first confirmation and OFFLINE after losing it.

**A send only takes off what it sent.** The till stays usable while a check is
in flight, so the acknowledgement removes exactly the submitted quantities and
leaves anything rung in since. A failed send leaves the check standing. The
order id is made on the device and reused when the same check is retried, so a
send that landed without the till hearing back is found rather than posted
twice.

**Reading a document is defensive.** `MenuItem.fromMap` never casts. A
negative, fractional, non-finite or oversized price, or a missing name, makes
that one item unsellable instead of throwing. The parser runs inside a `map`
over the whole collection, so one hand-edited document would otherwise blank
the entire menu.

**No state-management package.** The till has one screen and one piece of
mutable state, the check, held in a `ChangeNotifier`. `OrderController` and
`CheckoutController` are plain Dart and are tested without any widgets.

**One design system, two themes.** The till is dark and the manager app is
light, built from the same tokens with the neutral ramp inverted: the till sits
behind a bar at night, and the manager app is often read in daylight.
`DESIGN.md` has the palette and the reasoning.

**Shared code lives in one package.** `packages/core` owns
everything that would be identical if the second app were written from
scratch; `apps/*` own layout. Neither app touches Firestore and neither
contains a colour literal:

```bash
grep -rnE "cloud_firestore|FirebaseFirestore" apps/pos/lib apps/manager/lib
grep -rEn "Color\(0x" apps/pos/lib apps/manager/lib
```

---

## Security model

`firestore.rules` assumes the client cannot be trusted. Tablets in a venue are
shared, and an app's own validation only protects people who use the app as
intended.

**What is enforced.** Every operation needs a signed-in device and a venue the
rules serve. Menu writes are schema-checked: exact field set, a name of 1–60
characters, an integer price above zero and at most `Money.maxCents`, a known
category, a boolean flag, and timestamps equal to the server's clock. One
exception: an edit may leave an already-invalid stored price as it is, such as
a float written before these rules, so the item can still be renamed; a new
price has to be a valid one. The same goes for a category this build does not
know, and for a field added by hand in the console: an edit may leave them as
they are, but cannot introduce new ones. The sold-out toggle is checked as a
two-field diff, so an unrelated invalid field never blocks it. Orders are
append-only, bounded, attributed to the device that sent them, and readable
only by that device. Everything else is closed.

**What is not enforced.**

- *Who is inside a venue.* Authentication is anonymous sign-in, and the
  Firebase web config ships in every client, so "signed in" means "called
  `signInAnonymously()`". Anyone can therefore read, re-price or delete the menu
  of a venue the rules serve. Tenancy is a stub: an allowlist of venue ids,
  standing in for a `venueId` claim that nothing in this project mints.
- *The arithmetic on an order.* Rules cannot iterate, so the lines of an order
  cannot be checked against its total. Their number is capped, but each line
  can be as large as the document allows. A forged order can under-report
  takings.

**What closes it.** Provisioning that mints `venueId` and `role` claims from a
device record; a real credential on the manager app, so menu writes are never
reachable from an anonymous session; App Check enforcement; and a Cloud Function
on order create that re-sums the lines and records any discrepancy for an admin.
Until then, these rules are meant for use with the emulator only.

---

## Deliberately left out

- **Roles.** Covered above. A role the client could set on itself would not
  protect anything, so there is no role at all.
- **Payments.** "Send order" records the check. No tender, split or receipt.
- **Venue-defined categories.** `MenuCategory` is a closed set of four so both
  apps agree on section order and the rules can reject unknown values. An item
  filed under a category this build does not know is still shown and sold, and
  its category is written back untouched.
- **Modifiers, sizes, tabs, covers, printers.** Real POS features, out of scope.
- **Offline beyond Firestore's own cache.** Writes are queued and reads work
  through a dropout, including on web, where the cache is persisted. A venue with
  genuinely bad wifi needs more than that.
- **Server-side menu ordering.** Sorting is client-side, to avoid a composite
  index as a first-run failure mode. Right for tens of items, wrong for
  thousands.
- **Golden tests.** Widget tests assert structure, semantics and behaviour, not
  pixels.

## What comes next

1. Device provisioning and custom claims, replacing the venue allowlist and
   adding a manager role.
2. The order-reconciliation Cloud Function.
3. An audit trail on the menu: `updatedBy` and a per-item history.
4. Modifiers and sizes.
5. Crash reporting and structured logs from devices in venues.
6. Golden tests on both themes, alongside the CI in `.github/workflows`, which
   already runs analyze, the Dart tests and the rules tests.

---

## License

MIT, see [LICENSE](LICENSE). The bundled Archivo typeface is under the SIL Open
Font License 1.1, with the licence next to each copy of the font.
