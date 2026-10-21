# Basic dice artwork

User-provided `basic_dice.png` and its original `basic_dice.aseprite`, copied unchanged from `/Users/James/Documents/Aseprite/Evil Dice/dice` on 2026-10-20.

Runtime uses the PNG's thirteen horizontal 48×48 cells: frames 1–6 are faces 1–6; frames 7–13 are the rolling animation. The Aseprite source is retained for editing; the exported PNG and the user's stated mapping define the runtime sequence.

The game samples the atlas with nearest-neighbor filtering. Random animation phase, direction, rotation and travel are presentation only and do not choose the rolled number.
