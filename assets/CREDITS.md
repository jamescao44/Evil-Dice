# Asset credits

## Dungeon Crawl Stone Soup — active fantasy art

Source: [Dungeon Crawl 32×32 Tiles Supplemental on OpenGameArt](https://opengameart.org/content/dungeon-crawl-32x32-tiles-supplemental), **Dungeon Crawl Stone Soup Full.zip**, plus the [original collection page](https://opengameart.org/content/dungeon-crawl-32x32-tiles). License: **CC0 / public domain**. The collection includes work by the Crawl/Stone Soup and rltiles artists, with individual contributors listed in the unmodified [original README and credits](licenses/DCSS-README.txt). The full [CC0 license](licenses/DCSS-CC0.txt) is retained.

Selected PNGs are copied unchanged to `art/fantasy/`. The complete source-to-project mapping is in [sources.json](art/fantasy/sources.json).

The treasure chest and seven reward category icons are copied unchanged from the same collection into `art/rewards/`; exact paths are in [reward sources.json](art/rewards/sources.json). Elite glows tint additional copies of the human sprites at runtime. Treasure audio reuses Kenney ticks, landings, plucks, confirmation, book, rumble, and bell clips, with pitch variation and layered prize reveals.

| Game role | Original file in the public archive |
| --- | --- |
| The Horror | `monster/abyss/worldbinder.png` |
| Vanguard | `monster/vault/vault_guard_new.png` |
| Elf Archer | `monster/deep_elf_master_archer.png` |
| Elite mage / legacy mage | `monster/deep_elf_mage.png` |
| Paladin | `monster/holy/paladin.png` |
| High Priest | `monster/deep_elf_high_priest.png` |
| Elf Spellsword | `monster/deep_elf_blademaster.png` |
| Fleeing civilians | `monster/human_new.png`, `monster/human_old.png` |
| Fleeing aristocrats | `monster/enchantress_human.png` |
| Courtyard paving | `dungeon/floor/limestone_0.png` through `_3.png` |
| Interface stone texture | `dungeon/wall/stone_gray_0.png` |
| Ruined arch | `dungeon/gateways/stone_arch.png` |
| Broken column | `dungeon/statues/crumbled_column.png` |
| Trees and grass | `dungeon/trees/mangrove_1.png`, `dungeon/floor/grass/grass_full_new.png` |
| Grimoire icon | `item/book/book_of_the_dead_new.png` |
| Boon and effect icons | `gui/skills/`: shields, fighting, transmutations, necromancy, invocations, spellcasting |

The actors use 32×32 source images with nearest-neighbor sampling and stepped idle motion. Apparent scale changes with growth; death poses rotate and flatten the same sprite. City troops and inhabitants lean and hop while running; civilians and aristocrats emerge when houses become rubble. Scene and UI textures are tiled, cropped, and tinted at runtime. These are existing public pixel-art tiles; no custom image generation was used for this redesign.

## User-provided basic dice

The basic dice use the user's unchanged 48×48-cell `basic_dice.png` atlas and retain the original `.aseprite` source under `art/dice/`. Frames 1–6 are the resting faces and frames 7–13 are rolling poses. Battle dice, home previews and miniature skill dice share this artwork. See [dice asset notes](art/dice/SOURCE.md). This artwork is user-provided and is not covered by the public asset licenses listed elsewhere here.

## User-provided normal mage

The normal mage uses the user's nine-frame `mage.gif`, retained in `art/enemies/mage/source.gif`. Frame 1 is its living sprite; frames 2–9 are eight scattered death pieces. See [mage asset notes](art/enemies/mage/README.md). This custom artwork is user-provided and is not included in the DCSS CC0 attribution. Its small blood splatter is drawn in code.

## Relic inventory artwork

Relic sprites use unchanged CC0 tiles from the same **Dungeon Crawl Stone Soup Full** archive above: scrolls, rings, armor, shields, weapons, runestones, a skull, an hourglass, and the bread/crystal/book icons used for Fortune Cookie, Crystal Ball and Ancient Prophecy. Exact source paths are recorded in [relic sources.json](art/relics/sources.json). The six elemental magic stones and Prismatic Stone instead share the project's original `magic_gem.svg`, tinted at draw time by element; Prismatic Stone uses a multicolor tint. The previous stone PNGs remain as unused source references. Transparent margins are trimmed at draw time; source PNGs are unmodified. The added weapon, pet, helmet, mask and tentacle sprites also use unchanged tiles from this archive. Clover, ice rose and six pip-marked cursed dice use original project pixel-vector SVGs, recorded in the same source manifest. Fries and Hamburger use **thekingphoenix**’s [Icons: Food.](https://opengameart.org/content/icons-food), licensed **CC0**. The source PNG is unchanged; AtlasTexture resources select the matching sprites. See [food icon provenance](licenses/Food-Icons.txt). The former food SVGs are unused references. The chest atlas is rendered from the same shared renderer by `tests/render_relic_atlas.gd`.

## Silkscreen — all active text and numbers

Copyright 2001 The Silkscreen Project Authors. Source: [Google Fonts Silkscreen](https://github.com/google/fonts/tree/main/ofl/silkscreen). License: **SIL Open Font License 1.1**. Original notice: [Silkscreen OFL](licenses/Silkscreen-OFL.txt).

`fonts/Silkscreen-Regular.ttf` is unmodified. The game disables font smoothing and subpixel positioning and uses whole-pixel baselines for all UI, guide text, and floating damage numbers. It uses no fallback body font.

## Interface Sounds — restored dice and reveal audio

Creator: **Kenney**. Source: [Interface Sounds](https://kenney.nl/assets/interface-sounds). License: **CC0**. Original notice: [Kenney Interface Sounds](licenses/Kenney-Interface-Sounds.txt).

Five unchanged clips are active again: `click_001` for tumbling, `drop_001` for landings, `confirmation_002` for pairs, `bong_001` for triple reveals, and `pluck_001` for the rising reveal chime. Runtime pitch variations match the earlier prototype. The other three interface clips remain unused.

## Impact Sounds and RPG Audio — active combat effects

Creator: **Kenney**. Sources: [Impact Sounds](https://kenney.nl/assets/impact-sounds) and [RPG Audio](https://kenney.nl/assets/rpg-audio). Both packs are **CC0**. Original notices are retained: [Impact Sounds license](licenses/Kenney-Impact-Sounds.txt), [RPG Audio license](licenses/Kenney-RPG-Audio.txt).

Nine distinct combat recordings are copied unchanged into source folders under `audio/`; [source mapping](audio/sources.json) records every file’s original archive path and checksum. Clips reused by different sources have separate copies so they can be replaced independently. Seven are used for weapon strikes, spells, boons, feeding, and destruction; the heavier dice landing/rattle clips are retained but unused. A Combat bus limiter bounds the mix.

| Project clip | Original clip | Use |
| --- | --- | --- |
| land | impactWood_heavy_000 | Unused; original dice landing restored |
| hit | impactPunch_heavy_001 | Attack impact |
| crash | impactGlass_heavy_001 | Ultimate and city destruction |
| rumble | impactMetal_heavy_000 | Spell impact and feeding resonance |
| bell | impactBell_heavy_000 | Boons, enemy magic, victory |
| slash | knifeSlice | Weapon and attack sweep |
| chop | chop | Falling enemy |
| roll | handleCoins2 | Unused; original dice rattle restored |
| book | bookOpen | Debug selection |

## Earlier prototype assets — retained, unused

These files remain on disk for reference; the battle scene does not load them.

- **Gothicvania Town**, Luis Zuno / Ansimuz, [source](https://opengameart.org/content/gothicvania-town), **CC0**, [original notice](licenses/Gothicvania.txt). `art/battleground.png` is `PNG/environment/environment-preview.png`; `art/recruit.png`, `art/investigator.png`, and `art/medic.png` are the bearded-idle, hat-man-idle, and oldman-idle strips. No music from this pack is used.
- **Tentacle Horror Deep**, FreeGameSprites, [source](https://freegamesprites.com/en/assets/tentacle-horror-deep-gothic), publisher-listed **CC0**, [saved source/license record](licenses/FreeGameSprites.txt). `art/cthulhu.png` is the unmodified public PNG. Provenance: the publisher serves it from its `images/ai-sprites/generated/` collection. The previous palette shader also remains unused.
- **Rajdhani**, Copyright (c) 2014 Indian Type Foundry, [source](https://github.com/google/fonts/tree/main/ofl/rajdhani), **OFL 1.1**, [notice](licenses/Rajdhani-OFL.txt). `fonts/Rajdhani-SemiBold.ttf` is unmodified and unused.
- **Kenney Tiny Dungeon**, [source](https://kenney.nl/assets/tiny-dungeon), **CC0**, [notice](licenses/Kenney-Tiny-Dungeon.txt). `sprites/tiny-dungeon.png` is unused.

## Project visuals

Bone dice and pips, magic-circle runes, textured framing, health bars, animated combo/skill labels, castle-city layout, roofs, circular walls, moat, bridges, a few icons, particles, slashes, feeding, and spells are implemented in project code. The city combines public stone, grass, tree, and rubble textures with pixel geometry. The user's castle-city reference guides the composition; its image is not redistributed as a game asset. No paid assets are used.

Reward currency icons also use unchanged CC0 DCSS tiles: `item/amulet/crystal_red.png` (ruby region displayed without its chain) and `item/scroll/blank_paper.png` (summon contract with a code-drawn magic seal). Original coins and shard artwork remain unused. See `art/rewards/sources.json`.

## User-provided charge-loop audio

`audio/dice/magic_leak_loop.wav` derives from the user-provided `magic_leak.wav`. It is not part of the Kenney CC0 packs. The source excerpt, crossfade and normalization details are recorded in [magic_leak_loop.txt](audio/dice/magic_leak_loop.txt). `scripts/dice/charge_audio.gd` controls its runtime volume.

## User-provided finished sound effects

`audio/item/arcade_slot_roll.wav`, `arcade_slot_roll2.wav`, and `audio/item/reward_level1.wav` through `reward_level3.wav` are copied unchanged from the user's `outs-FXs` folder. These are user-provided project audio, separate from the CC0 packs. Chest presentation uses the original 160 BPM timing; all five import as uncompressed 48 kHz stereo PCM.

`audio/item/card_draw.wav`, `audio/item/deck_flip.wav`, and `audio/item/deck_flip2.wav` are copied unchanged from the same user-owned `outs-FXs` folder. Card draw plays on a successful fan pick; one of the two single-card flips is selected with equal probability at each card's visual departure during shuffling, with a quieter mix for the faster reduced-effects animation. All three import as uncompressed PCM and are separate from the Kenney packs.

`audio/dice/soft_sweep.wav` and `audio/dice/perfect.wav` are copied unchanged from the user’s finished-SFX folder, `/Users/James/Desktop/Music Files/Station A/Evil Dice/outs-FXs`. The soft sweep replaces the scraping dice-throw sweep; the Perfect clip layers onto accepted Perfect throws. These are user-provided project audio, not part of the Kenney CC0 packs. The existing magic-leak charging loop now plays at 25% of its original runtime amplitude across its entire power curve. The soft sweep plays 6 dB louder than its initial mix; source WAV files remain unchanged.

- **Noto Sans SC**: bundled Chinese font from [Google Fonts / Adobe](https://github.com/google/fonts/tree/main/ofl/notosanssc), SIL Open Font License 1.1. License: `fonts/NotoSansSC-LICENSE.txt`.

## Tarot cards

Art by Jose Angel Canabal. All 22 Major Arcana and the card back are from
[Major Arcana Pixel Art](https://jcanabal.itch.io/major-arcana-pixel-art-free).
Original monochrome PNGs, used unchanged. Free commercial and noncommercial
digital-game use with attribution; asset resale and print use are not permitted.
See `art/tarot/LICENSE.txt` for the source and license summary.

## Soul crystal drops and pickup audio

**Bobjt**, [Gem collect SFX](https://opengameart.org/content/gem-collect-sfx), **CC0 1.0**. Unmodified stereo WAVs: the reverb version accompanies enemy crystal drops; the short version plays at collection with light pitch variation. See [provenance](licenses/Gem-Collect-SFX.txt).

## Hooded shopkeeper

**Shopkeeper** by **pablopirata**, [OpenGameArt source](https://opengameart.org/content/shopkeeper), licensed **CC0 1.0**. The original `keeper.png` is copied unchanged to `art/shop/`; see [provenance](art/shop/SOURCE.md). Shelves are drawn in code.

### Player evolution forms

All three active levels use [Flamelings by surt](https://opengameart.org/content/flamelings), CC0. Sprites extracted with transparent backgrounds and nearest-neighbor scaling. The former original AI-generated ember starter is retained as an unused source asset. See [source and generation record](licenses/Flamelings.txt).

### Meal ingredient additions
- Lemon soda and fried chicken: **KARSIORI STUDIO**, [Food Pack 2](https://karsiori.itch.io/free-pixel-art-food-pack-2), CC0. Original Soda Can 4 and Chicken Drumstick PNGs.
- Cookie sundae placeholder: ice cream from **thekingphoenix**, [Icons: Food](https://opengameart.org/content/icons-food), CC0; same sheet as fries and hamburger. Meal icons combine only foods actually collected.

New relic placeholder icons (2026-10-25): reused unmodified CC0 Dungeon Crawl tiles; per-file sources are recorded in `assets/art/relics/sources.json`.

Third-level boss and summons (2026-10-25): unmodified CC0 Dungeon Crawl tiles from the same archived pack: deep elf demonologist, zombie octopode, eldritch tentacle and balrug. Exact paths are recorded in `art/fantasy/sources.json`.

Damage-calculation knock (`audio/item/damage_knock.wav`): original procedural synthesis for this project; short damped wooden-block resonances and a soft noise transient, no sampled recording.

The October build relic icons (Vodka, Seed, Bandage, Steel Sword, Split Arrow, Book of the Dead) reuse the CC0 DCSS supplemental tiles listed in `assets/art/relics/sources.json`. Pet Orb composes the five existing pet sprites.

Pet food bowls and the Super Pet Ball are original project pixel-vector SVG icons. Companion creatures reuse the credited CC0 Dungeon Crawl Stone Soup tiles; the full dragon uses `monster/dragons/dragon.png` from the same archive. Source tiles are unchanged.

Remains and broken-sword parts, Ticket, enchanted chips and Nightmare Totem are original project pixel-vector icons. Other new relic placeholders reuse the unchanged CC0 DCSS tiles recorded in `art/relics/sources.json`. Ghost of the Witch shares Unidentified Ring artwork with a runtime violet magic glow.

Ghost of the Witch companion: unchanged `monster/enchantress_human.png` from the credited CC0 DCSS archive, rendered with a spectral tint and transparency.
