# Texture Standards

Every image added to this folder must follow these rules. Uncompressed art was
73% of the addon's install size before the 2026-06 cleanup — these rules keep
that from recurring.

## Required: compressed format

- **No uncompressed truecolor TGA (type 2).** Save TGA as **RLE-compressed
  (type 10)** or use **PNG** — the retail client loads both.
- Use 24bpp unless the texture actually needs an alpha channel.

## Required: author at display size

Author art at the size it renders in-game (check `heroHeight` / frame code),
not at source/screenshot resolution. A 768×768 hero displayed at 190 px tall
ships ~12× the pixels it uses.

## What's New hero lifecycle

`WhatsNewFrame` only ever renders the **current** version's hero — the ICYMI
section shows the previous entry's feature rows without its hero. When shipping
a release with a new hero: delete the outgoing version's hero texture and
remove its `heroTexture`/`heroHeight` fields from `UI/WhatsNewData.lua` in the
same commit. The frame collapses the hero space when the field is absent.
