# Design previews

The design system was settled here before any Flutter was written, so the
palette, the type scale and every component state could be looked at and argued
with while they were still cheap to change. `../DESIGN.md` is the written
system; these are what it looks like.

Open any file in a browser, or serve the folder:

```bash
python3 -m http.server --directory design 8000
```

| File | What it shows |
|---|---|
| `01-color.html` | Both ramps side by side, with measured contrast |
| `02-type.html` | The type roles, the width axis, tabular vs proportional figures |
| `03-menu-tile.html` | The till tile in every state, including the change flash |
| `04-order-panel.html` | Order lines, the money column, the sold-out-mid-round case |
| `05-manager-row.html` | The manager row and the labelled availability pill |
| `06-editor-sheet.html` | Create and edit, including the validation messages |
| `07-screen-pos.html` | The whole till |
| `08-screen-manager.html` | The whole manager app |

`Archivo.ttf` is a copy of the font in `packages/core/assets/fonts/`, kept here
so a preview opens standalone without reaching out of this folder. The
applications load the copy inside the package; this one is read only by these
HTML files. Its licence, the SIL Open Font License 1.1, is in `OFL.txt` beside it.

None of this ships in either application.
