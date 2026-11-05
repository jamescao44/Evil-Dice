extends RefCounted
## Transparent viewport captures contain premultiplied RGB; PNG sprites need straight alpha.

## Restore original color without grading it; playback applies transparency exactly once.
static func straight_alpha(image: Image) -> Image:
	image.convert(Image.FORMAT_RGBA8)
	var pixels: PackedByteArray = image.get_data()
	for offset in range(0,pixels.size(),4):
		var alpha: int = pixels[offset+3]
		if alpha == 255: continue
		for channel in range(3):
			pixels[offset+channel] = mini(255,roundi(pixels[offset+channel]*255.0/alpha)) if alpha > 0 else 0
	return Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,pixels)
