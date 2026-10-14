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

Playback IDs use `source/filename` without the extension, such as `item/deck_flip2` or `dice/perfect`. Register new files in `scripts/audio/sound_catalog.gd`, then use the source-qualified ID with `battle._sound()`. The continuous charge loop and home button player reference their respective `dice/` and `ui/` files directly.

`item/deck_flip.wav` and `item/deck_flip2.wav` alternate randomly with equal probability, once per card leaving the deck. `item/card_draw.wav` plays when a card is picked from the fan. Keep their uncompressed import settings when replacing WAVs.

Chest audio is managed by `scripts/audio/chest_audio.gd`: `item/arcade_slot_roll.wav` starts with the first visible reel motion after the opening delay, repeats at constant volume through spinning, then stops on the first landing for Normal/Perfect/Greed or the final landing for Ultra. Greed switches to `item/arcade_slot_roll2.wav` as soon as that tier appears. Both sources include their full tails; `timed_audio_loop.gd` overlaps repeats every 0.84375 seconds (nine sixteenth notes at 160 BPM), with a sample-accurate periodic segment and sub-millisecond edge smoothing to prevent clicks. Normal/Perfect play `reward_level1.wav` once on the first reward explosion; Greed starts `reward_level2.wav` once on its first explosion, continuing across the remaining prizes. Ultra starts `reward_level3.wav` immediately upon appearing (or when an earned Ultra is opened), with no additional stop tap, landing rewards left to right on its final five notes at 3.000, 3.1875, 3.375, 3.5625 and 3.750 seconds (160 BPM); its remainder plays once without restarting. Payouts keep their original pitch and tempo and continue through tarot selection; they stop when the chest closes or the run restarts. Pausing before the reveal still holds the rolling sound and Ultra buildup in sync. All five user-provided WAVs are unchanged, stereo 48 kHz, and imported without compression.

`dice/land.ogg` and `dice/roll.ogg` are retained alternatives, not active dice sounds. `ui/error_004.ogg`, `ui/glitch_004.ogg` and `ui/maximize_008.ogg` are also unused.

See `sources.json` for provenance and checksums, `dice/magic_leak_loop.txt` for the processed charging loop, and `../CREDITS.md` for licenses. Checksums describe the files at organization time; update the corresponding entry when replacing a recording.

`enemy/crystal_drop.wav` plays when defeated enemies burst into soul crystals; `item/crystal_collect.wav` plays as crystals reach the currency counter. Grouped drops and pickups are rate-limited to avoid overlapping chime spikes. Both are uncompressed CC0 stereo recordings by Bobjt.
