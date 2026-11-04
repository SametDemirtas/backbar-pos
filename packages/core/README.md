# backbar_pos_core

The shared layer behind both applications. Not published; consumed by
`apps/pos` and `apps/manager` through the workspace.

Everything here would be identical if the second app were written from scratch:

| Directory | What lives there |
|---|---|
| `src/models/` | `MenuItem`, `MenuItemDraft`, `MenuItemPatch` (an edit as a field diff), `MenuCategory`, `Order`, `OrderLine`, `CheckTooLarge` |
| `src/money/` | `Money`: integer cents, parsing and formatting |
| `src/order/` | `OrderController`, the check on the till; `CheckoutController`, which sends it with a stable id across retries |
| `src/data/` | Firestore paths, `MenuRepository`, `OrderRepository`, and `MenuLinkTracker` for connecting, live or offline |
| `src/app/` | `VenueConfig`, `AppBootstrap` (Firebase start-up, emulator or production), `describeFailure` |
| `src/theme/` | Design tokens as a `ThemeExtension`, for both themes |
| `src/ui/` | The widgets that render a concept both apps share |

Layout lives in `apps/`. Neither app imports `cloud_firestore` and neither app
contains a colour literal; if either becomes untrue, the boundary has leaked.

## Categories are a closed set

`MenuCategory` is an enum, not free text, so the two apps agree on section
ordering and the security rules can reject an unknown value without a document
read. A production venue would define its own categories in its own collection;
the root README lists that as deliberately out of scope.

An item stored under a category this build does not recognise is still shown and
still sellable, filed under `MenuCategory.fallback`, with its original value
carried on `MenuItem.unrecognisedCategory` so that an older till cannot destroy
it on the next write.

## Third-party assets

`assets/fonts/Archivo.ttf` is Archivo by Omnibus-Type, used under the SIL Open
Font License 1.1. The full licence text ships alongside it at
`assets/fonts/OFL.txt`.

## Tests

```
flutter test packages/core/test
```

Firestore-backed tests run against `fake_cloud_firestore`, so no emulator and no
network are needed.
