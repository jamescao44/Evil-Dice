extends RefCounted
## Sample-accurate repeated one-shots: tails overlap without frame-timer jitter.
static func build(source: AudioStreamWAV, period_seconds: float) -> AudioStreamWAV:
	assert(source.format == AudioStreamWAV.FORMAT_16_BITS)
	var channels: int = 2 if source.stereo else 1
	var input: PackedByteArray = source.data
	var source_frames: int = input.size()/(channels*2)
	var period: int = roundi(period_seconds*source.mix_rate)
	var repeats: int = ceili(float(source_frames)/period)
	var frames: int = repeats*period
	var mix := PackedFloat32Array()
	mix.resize(frames*channels)
	for repeat in range(repeats):
		var offset: int = repeat*period
		for frame in range(mini(source_frames,frames-offset)):
			# Sub-millisecond edge smoothing removes abrupt non-zero first/last
			# samples without clipping the authored tail or changing the rhythm.
			var edge: float = minf(1.0,minf(frame,source_frames-1-frame)/(source.mix_rate*0.0005))
			for channel in range(channels):
				mix[(offset+frame)*channels+channel] += input.decode_s16((frame*channels+channel)*2)*smoothstep(0,1,edge)
	var data := PackedByteArray()
	data.resize(frames*channels*2)
	for sample in range(mix.size()): data.encode_s16(sample*2,clampi(roundi(mix[sample]),-32768,32767))
	var stream: AudioStreamWAV = source.duplicate()
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = frames-period
	stream.loop_end = frames
	return stream
