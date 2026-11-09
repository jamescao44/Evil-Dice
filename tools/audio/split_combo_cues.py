#!/usr/bin/env python3
"""Split the five authored 2–6-note cues without changing their pitch or tempo."""
import argparse
import array
import hashlib
import json
from pathlib import Path
import sys
import wave

# Starts follow the authored timeline; the last endpoint excludes only silent padding.
BOUNDARIES = (0.0, 0.75, 1.5, 2.25, 3.375, 4.5)
EDGE_SECONDS = 0.002
ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="The original combos.wav recording")
    args = parser.parse_args()
    source_hash = hashlib.sha256(args.source.read_bytes()).hexdigest()
    with wave.open(str(args.source), "rb") as source:
        params = source.getparams()
        if params.sampwidth != 2 or params.nchannels != 2:
            raise ValueError("Expected the authored stereo 16-bit PCM recording")
        if params.nframes < round(BOUNDARIES[-1] * params.framerate):
            raise ValueError("Recording is shorter than the five cue boundaries")
        raw = source.readframes(params.nframes)
    manifest_path = ROOT / "assets/audio/sources.json"
    manifest = json.loads(manifest_path.read_text())
    manifest.pop("dice/combination.wav", None)
    frame_bytes = params.sampwidth * params.nchannels
    for count, (start, end) in enumerate(zip(BOUNDARIES, BOUNDARIES[1:]), 2):
        first, last = round(start * params.framerate), round(end * params.framerate)
        samples = array.array("h", raw[first * frame_bytes:last * frame_bytes])
        if sys.byteorder != "little":
            samples.byteswap()
        # Tiny edge fades avoid clicks where the fourth cue starts before the prior tail ends.
        edge = round(EDGE_SECONDS * params.framerate)
        for frame in range(edge):
            gain = frame / (edge - 1)
            for channel in range(params.nchannels):
                a = frame * params.nchannels + channel
                b = (last - first - 1 - frame) * params.nchannels + channel
                samples[a] = round(samples[a] * gain)
                samples[b] = round(samples[b] * gain)
        if sys.byteorder != "little":
            samples.byteswap()
        relative = f"dice/combos_{count}.wav"
        destination = ROOT / "assets/audio" / relative
        with wave.open(str(destination), "wb") as output:
            output.setparams(params)
            output.writeframes(samples.tobytes())
        manifest[relative] = {
            "source": "User-provided outs-FXs/combos.wav",
            "source_sha256": source_hash,
            "source_segment_seconds": [start, end],
            "processing": "2 ms edge fades only; original pitch, tempo, gain and stereo PCM",
            "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
        }
        print(f"{relative}: {end - start:.3f}s")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
