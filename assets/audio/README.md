# Sound files

Files are grouped by what produces the sound in the game.

| Folder | Sounds |
| --- | --- |
| `item/` | Tarot drawing, shuffling and casting; relic pickups; treasure opening, reels and rewards |
| `dice/` | Charging, throwing, tumbling, landing, Perfect and combination reveals |
| `player/` | Player skills, impacts, buffs, damage feedback, taking damage, ice breaking and feeding |
| `enemy/` | Enemy attacks, spells, support/shields, deaths and city destruction |
| `ui/` | Home, menu, help and debug controls; unused interface alternatives |

Replace a file in its folder to change that source's sound. Several sources currently use the same original recording; these have separate files so future replacements do not affect unrelated actions. Pitch, volume, timing and the audio mix are controlled at the call sites and are unchanged by this organization.

Playback IDs use `source/filename` without the extension, such as `item/deck_flip2` or `dice/perfect`. Register new files in `scripts/sound_catalog.gd`, then use the source-qualified ID with `battle._sound()`. The continuous charge loop and home button player reference their respective `dice/` and `ui/` files directly.

`item/deck_flip.wav` and `item/deck_flip2.wav` alternate randomly with equal probability, once per card leaving the deck. `item/card_draw.wav` plays when a card is picked from the fan. Keep their uncompressed import settings when replacing WAVs.

`dice/land.ogg` and `dice/roll.ogg` are retained alternatives, not active dice sounds. `ui/error_004.ogg`, `ui/glitch_004.ogg` and `ui/maximize_008.ogg` are also unused.

See `sources.json` for provenance and checksums, `dice/magic_leak_loop.txt` for the processed charging loop, and `../CREDITS.md` for licenses. Checksums describe the files at organization time; update the corresponding entry when replacing a recording.
