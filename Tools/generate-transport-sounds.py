#!/usr/bin/env python3
"""Prepare short CC0 cassette-key recordings without network dependencies."""

from pathlib import Path
import hashlib
import json
import math
import struct
import wave

RATE = 44100
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Tools/AudioSources/Transport"
OUTPUT = ROOT / "Stillroom/Resources/TransportSounds"


def read_excerpt(entry):
    path = SOURCE / entry["file"]
    if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
        raise ValueError(f"Source excerpt changed: {path.name}")
    with wave.open(str(path)) as recording:
        if recording.getnchannels() != 1 or recording.getsampwidth() != 2:
            raise ValueError(f"Expected mono PCM16: {path.name}")
        rate = recording.getframerate()
        raw = recording.readframes(recording.getnframes())
    return [value[0] / 32768 for value in struct.iter_unpack("<h", raw)], rate


def clean_recording(samples, rate):
    # Keep the recorded contact/latch timing. A modest band limit removes room
    # rumble and sharp microphone hiss; expansion lowers only the quiet gaps.
    high_pass = math.exp(-2 * math.pi * 85 / rate)
    low_pass = 1 - math.exp(-2 * math.pi * 6800 / rate)
    release = math.exp(-1 / (0.008 * rate))
    previous_input = previous_high = low_one = low_two = envelope = 0.0
    output = []
    for value in samples:
        high = high_pass * (previous_high + value - previous_input)
        previous_input, previous_high = value, high
        low_one += low_pass * (high - low_one)
        low_two += low_pass * (low_one - low_two)
        envelope = max(abs(low_two), envelope * release)
        expansion = max(0.08, min(1.0, (envelope / 0.004) ** 2))
        output.append(low_two * expansion)
    return output


def resample(samples, source_rate):
    # Windowed sinc keeps the 48 kHz recording's timing when producing the
    # 44.1 kHz app asset. No pitch shift or repeated synthetic impacts are used.
    output = []
    radius = 16
    cutoff = min(1.0, RATE / source_rate) * 0.94
    count = round(len(samples) * RATE / source_rate)
    for index in range(count):
        position = index * source_rate / RATE
        centre = math.floor(position)
        value = weight_sum = 0.0
        for source_index in range(centre - radius + 1, centre + radius + 1):
            distance = position - source_index
            if abs(distance) >= radius:
                continue
            phase = math.pi * distance * cutoff
            sinc = math.sin(phase) / phase if phase else 1.0
            window = 0.5 + 0.5 * math.cos(math.pi * distance / radius)
            weight = cutoff * sinc * window
            if 0 <= source_index < len(samples):
                value += samples[source_index] * weight
            weight_sum += weight
        output.append(value / weight_sum)
    return output


def write_effect(name, entry, peak):
    original, source_rate = read_excerpt(entry)
    samples = resample(clean_recording(original, source_rate), source_rate)
    # These endpoint ramps avoid introducing a new digital click around the
    # real mechanical click, including cancellation near the end of a cue.
    attack, release = round(0.002 * RATE), round(0.012 * RATE)
    for index in range(len(samples)):
        fade = min(1.0, index / attack, (len(samples) - index - 1) / release)
        samples[index] *= max(0.0, fade)
    scale = peak / max(abs(value) for value in samples)
    integers = [round(value * scale * 32767) for value in samples]
    payload = b"".join(struct.pack("<h", value) for value in integers)
    target = OUTPUT / (name + ".wav")
    with wave.open(str(target), "wb") as sound:
        sound.setparams((1, 2, RATE, len(integers), "NONE", "not compressed"))
        sound.writeframes(payload)
    peak_value = max(abs(value) for value in integers) / 32768
    rms = math.sqrt(sum((value / 32768) ** 2 for value in integers) / len(integers))
    window = round(0.020 * RATE)
    short_rms = max(math.sqrt(sum((x / 32768) ** 2 for x in integers[i:i + window]) /
                              len(integers[i:i + window]))
                    for i in range(0, len(integers), window))
    return {
        "filename": target.name,
        "sourceExcerpt": entry["file"],
        "durationSeconds": len(integers) / RATE,
        "sampleRate": RATE,
        "channels": 1,
        "bitsPerSample": 16,
        "peakDBFS": round(20 * math.log10(peak_value), 3),
        "rmsDBFS": round(20 * math.log10(rms), 3),
        "maximum20msRMSDBFS": round(20 * math.log10(short_rms), 3),
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
    }


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sources = json.loads((SOURCE / "SOURCES.json").read_text())
    excerpts = sources["excerpts"]
    results = [write_effect("OneTapePlayLatch", excerpts[0], 0.50),
               write_effect("OneTapePauseRelease", excerpts[1], 0.46),
               write_effect("OneTapeTrackStep", excerpts[2], 0.42)]
    manifest = {
        "purpose": "Real cassette play-latch, pause-key and short track-step mechanical UI cues.",
        "authoring": "Edited CC0 field recording by Joseph SARDIN / BigSoundBank, sound 0570. Source-frame excerpts, hashes and license are retained in Tools/AudioSources/Transport.",
        "source": {key: sources[key] for key in ["author", "title", "sourcePage", "license", "licenseURL", "downloadSHA256"]},
        "processing": "85 Hz high pass, two 6.8 kHz low-pass stages, quiet-gap expansion, windowed-sinc 48k-to-44.1k resampling, 2/12 ms endpoint ramps and bounded peak normalization. Original stroke timing retained.",
        "reproduce": "python3 Tools/generate-transport-sounds.py",
        "serviceGain": 0.65,
        "boundary": "Real recorded cassette mechanism; not the original Cassette application's audio or a verified physical-device loudness match.",
        "samples": results,
    }
    (OUTPUT / "PROVENANCE.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
