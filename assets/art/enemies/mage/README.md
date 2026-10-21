# Normal mage

User-provided Aseprite export: `source.gif` (64 × 64, nine frames).

- `sprite.png`: frame 1, with its full transparent canvas preserved.
- `piece_02.png`–`piece_09.png`: frames 2–9, cropped only to their non-transparent bounds. Duplicate-looking source frames remain separate pieces.
- No resampling, recoloring or generated artwork. These assets are user-provided, not part of the DCSS CC0 collection.

`scripts/enemies/enemy_visuals.gd` registers the sprite, the eight pieces and their emission positions. `enemy_debris.gd` scatters them at the current enemy scale with gravity, spin and two small bounces. Pieces remain until the existing feeding fade; dark-red pixel droplets briefly splatter and fade. Reduced effects uses a shorter, unspun fall and fewer droplets. Elite mages retain their previous sprite and death pose.

Future exports can use a transparent PNG sheet with equal-size cells: the full character first, then pieces left at their original positions on the character canvas. Keep the `.aseprite` file as the editable source.
