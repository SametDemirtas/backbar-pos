# Backbar POS: Design System

The till is equipment for people who work at night. It sits on the backbar next
to the card reader, and a bartender has to read it at a glance, in a dark room,
with people waiting at the bar.

---

## 1. What the room dictates

Five facts about where this software runs shape everything below.

| Fact about the venue | What follows |
|---|---|
| The room is dark. A white tablet at full brightness ruins the bartender's night vision and lights up the bar. | The till has **one theme, and it is dark**. There is no light mode toggle. |
| Hands are wet, sometimes gloved, and always in a hurry. | **124 px menu tiles**, 60 px primary buttons, 56 px minimum for any other tap target. Nothing depends on hover. |
| The screen is read from 60–80 cm away, often at an angle. | Strong luminance steps. Mid-greys wash out at an angle, so the neutral ramp skips the middle. |
| It is loud, and nobody reads a toast. | State is shown **on the item itself**, where it stays until it changes. |
| The till has to balance at the end of the night. | Money is **tabular, right-aligned and in integer cents**, and its layout never shifts. |

### Two apps, two settings

The POS is **equipment**: dark, dense, fixed and high-contrast, used in one place
with full attention.

The Manager app is closer to **a document**: light, calm and roomy, used in an
office, a delivery bay or a cab in the afternoon. The till's dark palette would
be hard to read on a phone in sunlight.

Both apps use the same tokens, type and accent, with the neutral ramp inverted,
and both read their colours from the same `PosTheme` extension.

---

## 2. Colour

### Two accents on warm neutrals

Colour is used sparingly so that it carries meaning. Gold marks money and the
primary action. Ember marks what cannot be sold, what cannot be undone, and
errors. Everything else is a warm neutral.

The base is a warm near-black. Warm neutrals suit stage lighting and wood; cool
greys look clinical in a bar.

### Neutral ramp: "Backbar" (POS, dark)

| Token | Hex | Use |
|---|---|---|
| `ink.void` | `#0B0A09` | App background. Near-black rather than `#000`, which smears on OLED when scrolling and flattens the luminance steps. |
| `ink.well` | `#131110` | Sunken areas: the order panel gutter. |
| `ink.surface` | `#1A1715` | Menu tiles, cards. |
| `ink.raised` | `#23201D` | Pressed or selected tile base. |
| `ink.line` | `#322D29` | Hairlines. On dark, borders do the job shadows do on light. |
| `ink.disabled` | `#4A433D` | Struck-through prices, disabled glyphs. |
| `bone.primary` | `#F5F0E8` | Primary text. Off-white, because `#FFFFFF` on near-black glows at the brightness a bar tablet runs at. |
| `bone.secondary` | `#B8AFA3` | Category labels, secondary meta. |
| `bone.muted` | `#958C81` | Timestamps, hints. |

### Paper ramp: "Daylight" (Manager, light)

| Token | Hex | Use |
|---|---|---|
| `paper.base` | `#FAF7F2` | App background. Warm paper rather than `#FFF`. |
| `paper.well` | `#F2EDE4` | Grouped list background. |
| `paper.surface` | `#FFFFFF` | Cards and sheets. The only pure white in the system, used for the surface you write on. |
| `paper.raised` | `#F2EDE4` | Pressed and selected rows; the same paper as the well. |
| `paper.line` | `#E4DCCF` | Hairlines. |
| `paper.disabled` | `#B6AC9C` | |
| `ink.primary` | `#1A1613` | Primary text. |
| `ink.secondary` | `#6B6156` | |
| `ink.muted` | `#70675C` | |

### Accents

| Token | On dark | On light | Meaning |
|---|---|---|---|
| `marquee` | `#F2B03D` | `#F2B03D` fill / `#8A5A0F` text | Selection, primary action, the running total, the live-change flash. |
| `ember` | `#E5533D` fill / `#F06E5A` text | `#B93A25` fill / `#A8321F` text | Sold out, destructive actions, errors and the OFFLINE label. A warm red-orange that sits well next to the gold. The text forms are lighter on dark and deeper on light so the `SOLD OUT` tag clears 4.5:1 on its own tinted wash. |

Contrast, measured with the WCAG 2 relative-luminance formula:

- `bone.primary` on `ink.void`: **17.4:1** (AAA)
- `bone.secondary` on `ink.surface`: **8.2:1** (AAA)
- `bone.muted` on `ink.raised`, its darkest use: **4.9:1** (AA)
- `marquee` on `ink.void`: **10.4:1** (AAA)
- `ink.primary` on `paper.base`: **16.8:1** (AAA)
- `ink.muted` on `paper.well`, its darkest use: **4.8:1** (AA)
- `ember` text on `ink.surface`: **6.0:1** (AA)
- the `SOLD OUT` tag on its own wash, over `ink.raised`: **4.9:1** (AA)

Text clears 4.5:1 against every plain surface it is drawn on, in both themes.
Two cases sit below that on purpose. The struck price of a sold-out item
(`ink.disabled`, `paper.disabled`) is a disabled state. And on a sold-out tile
that is also on the open check, the hatch stripes that cross the title and the
tag bring them to 4.3–4.4:1 along each stripe. In both cases the hatch and the
words `SOLD OUT` carry the meaning, so the dimmed text does not have to.

**Colour is never the only signal.** Sold out is shown three ways at once: a
diagonal hatch across the tile, a strikethrough on the price, and the words
`SOLD OUT`. A colourblind bartender in a dark room still gets all three.

---

## 3. Type

**Archivo** (Omnibus-Type, SIL Open Font License), variable, with axes
`wght 100–900` and `wdth 62–125`. One family in one 640 KB file, bundled as an
asset in the shared package. There is no `google_fonts` fetch at runtime, so the
till does not depend on the venue's wifi to draw its own labels.

One family covers both the wide marquee labels and the condensed total, so there
is no second typeface to pair with it.

| Role | Size | wght | wdth | Tracking | Notes |
|---|---|---|---|---|---|
| Marquee (category rails, section heads) | 13 | 700 | **125** | +0.18em | Uppercase, wide and tracked, like a venue's letter board. |
| Tile title (item name) | 17 | 600 | 100 | 0 | Two lines at most, then an ellipsis. |
| Tile price | 20 | 700 | 100 | 0 | Tabular. |
| Running total | 40 | 800 | **87** | −0.01em | Condensed so a four-figure tab does not wrap the panel. Tabular. |
| Body | 15 | 450 | 100 | 0 | |
| Meta / caption | 12 | 500 | 100 | +0.02em | |
| Status (LIVE, CONNECTING, OFFLINE) | 12 | 500 | 100 | +0.12em | Uppercase. |
| Button label | 15 | 650 | 100 | +0.04em | |

**Every number uses `FontFeature.tabularFigures()`**, so a running total keeps
its width as items are added.

---

## 4. Space, shape, depth

**Spacing scale:** `4, 8, 12, 16, 24, 32, 48, 64`. Layout spacing comes from
this scale. A few small offsets inside components, such as a tag's padding or
the gap between an item name and its unit price, are set by eye at 2–7 px.

**Radii are kept tight.**

| Token | Value |
|---|---|
| `r.badge` | 2 |
| `r.control` | 6 |
| `r.surface` | 8 |
| `r.sheet` | 16 (top corners only, Manager) |

Framework defaults usually round at 12–16 px. A 6 px corner looks more like an
instrument panel, which suits a till.

**Depth:** on dark there are **no drop shadows**, because they do not show on
near-black. Hierarchy comes from a luminance step plus a 1px `ink.line`
hairline. On light there is one shadow, used only for the editor sheet. The
previews draw it as `0 1px 2px rgba(26,22,19,.06), 0 8px 24px rgba(26,22,19,.08)`;
Flutter approximates it with the sheet's elevation 8 and a `#1A1613` shadow at
8% opacity.

**Touch:** menu tiles are 124 px tall and grow with the text size, primary
buttons are 60 px, every other target is at least 56 px, and adjacent targets
are at least 8 px apart.

---

## 5. Motion

| Interaction | Duration | Curve |
|---|---|---|
| **Remote change flash** | 240ms in, 600ms hold, 400ms out | `easeOut` / `easeIn` |
| Live dot pulse | 2400ms loop | `easeOut` |

Button presses and the editor sheet use Flutter's Material defaults. The flash
and the live dot hold still under `MediaQuery.disableAnimations`.

### The change flash

When an item changes on the till because someone edited it in the Manager app,
the tile lights a 3px `marquee` bar on its leading edge and holds it for 600ms.
This is how a bartender sees that a change made on the manager's phone has
reached this till.

---

## 6. What changed once it was built

The tile's leading edge was first specified to do two jobs: steady gold for "in
the current order" and pulsing gold for "just changed remotely". Once built, the
two were hard to tell apart, because a steady bar and a bar that has just
finished pulsing look the same.

The edge now means one thing: **this changed remotely, just now.** Being on the
current order is shown by the raised tile background and the gold quantity
badge.

---

## 7. Details that carry the design

1. **The change flash**, so a remote edit is visible on the till.
2. **The marquee rail**: category names in wide, tracked caps down the edge of
   the menu.
3. **Sold out as a visible state**: a diagonal hatch, a struck price and the
   label, readable across the bar and never colour alone.
4. **A single money column**: every price in a check is right-aligned in one
   column of tabular figures, so a bartender reads down rather than across.

---

## 8. Token export

The tokens live in `packages/core/lib/src/theme/` and reach both apps through a
`PosTheme` `ThemeExtension`. Neither app hard-codes a colour, and radii, spacing,
type and touch sizes come from the tokens. Layout breakpoints and a few one-off
sizes stay in the app that uses them.
