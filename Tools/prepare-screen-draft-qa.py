#!/usr/bin/env python3
"""Prepare synthetic audio only in the explicitly named, isolated QA simulator."""
import array
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave


ROOT = Path(__file__).resolve().parent.parent
DEVICE_ID = "2C650379-F02A-4D67-9C0A-3DAC0390EBAB"
DEVICE_NAME = "One Tape Print Redraw QA"
BUNDLE_ID = "com.liuhang.stillroom"
SAMPLE_RATE = 22050
PREFIX = "screen-draft-qa-"
SOURCE = (
    "Deterministic, newly synthesized PCM for screen QA only: sine-wave bass, "
    "exponentially decaying kick pulses, a quiet four-note sine melody and short "
    "high-frequency pulses. No microphone, downloaded recording or user music."
)
TRACKS = [
    {"id": PREFIX + "night-signal-v1", "title": "夜航信号", "duration": 480, "variant": 0},
    {"id": PREFIX + "faint-trail-v1", "title": "微光轨迹", "duration": 60, "variant": 1},
]


def run(*arguments):
    return subprocess.check_output(arguments, text=True, timeout=30).strip()


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_plain_file(path):
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise RuntimeError("Refusing a symlink or non-file: " + str(path))


def verify_destination():
    inventory = json.loads(run("xcrun", "simctl", "list", "devices", "available", "-j"))
    matches = [device for group in inventory["devices"].values() for device in group
               if device.get("udid") == DEVICE_ID]
    if len(matches) != 1 or matches[0].get("name") != DEVICE_NAME:
        raise RuntimeError("The fixed simulator identifier/name does not match the isolated QA device.")
    device = matches[0]
    container = Path(run("xcrun", "simctl", "get_app_container", DEVICE_ID, BUNDLE_ID, "data"))
    device_data = Path(device["dataPath"]).resolve()
    expected_parent = device_data / "Containers/Data/Application"
    if DEVICE_ID not in device_data.parts or container.is_symlink():
        raise RuntimeError("Unexpected simulator container path.")
    container = container.resolve(strict=True)
    if container.parent != expected_parent:
        raise RuntimeError("App container is outside the authorized simulator.")
    directory = container / "Library/Application Support/Stillroom/Library"
    for ancestor in [directory, *directory.parents]:
        if ancestor == container.parent:
            break
        if ancestor.is_symlink():
            raise RuntimeError("Refusing a symlink in the library path.")
    return directory


def synthetic_pattern(variant):
    """A short, seam-faded pattern bounds CPU/memory while yielding changing PCM."""
    period = 16 if variant == 0 else 12
    notes = [220.0, 261.625565, 293.664768, 329.627557]
    if variant:
        notes = [261.625565, 329.627557, 391.995436, 293.664768]
    samples = array.array("h")
    tau = math.tau
    beat_duration = 0.5 if variant == 0 else 0.6
    for frame in range(period * SAMPLE_RATE):
        time = frame / SAMPLE_RATE
        beat = time % beat_duration
        low_note = [55.0, 65.406391, 73.416192, 82.406889][int(time / 4) % 4]
        if variant:
            low_note *= 1.5
        bass = math.sin(tau * low_note * time) * 0.23
        bass *= 0.7 + 0.3 * math.cos(tau * time / 4)
        kick_phase = tau * (46 * beat + 80 / 30 * (1 - math.exp(-30 * beat)))
        kick = math.sin(kick_phase) * math.exp(-18 * beat) * 0.21
        note = notes[int(time / 2) % 4]
        note_envelope = max(0.0, math.sin(math.pi * (time % 2) / 2))
        melody = (math.sin(tau * note * time) * 0.075
                  + math.sin(tau * note * 2 * time) * 0.018) * note_envelope
        tick = math.sin(tau * 1760 * time) * math.exp(-60 * beat) * 0.025
        # Fade both ends of the repeated pattern to avoid discontinuity clicks.
        seam = min(1.0, time / 0.025, (period - time) / 0.025)
        amplitude = max(-0.95, min(0.95, (bass + kick + melody + tick) * seam))
        samples.append(round(amplitude * 32767))
    if sys.byteorder != "little":
        samples.byteswap()
    return samples.tobytes(), period


def ensure_generated_audio(build_directory, specification):
    basename = specification["id"] + ".wav"
    target = build_directory / basename
    require_plain_file(target)
    descriptor, temporary_name = tempfile.mkstemp(prefix=basename + ".", dir=build_directory)
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        pattern, period = synthetic_pattern(specification["variant"])
        with wave.open(str(temporary), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(SAMPLE_RATE)
            for _ in range(specification["duration"] // period):
                output.writeframesraw(pattern)
        if target.exists():
            if sha256(target) != sha256(temporary):
                raise RuntimeError("Existing generated audio differs; retained unchanged: " + str(target))
        else:
            # A hard link fails if another process has created the destination.
            os.link(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)
    with wave.open(str(target), "rb") as sound:
        actual = (sound.getnchannels(), sound.getsampwidth(), sound.getframerate(), sound.getnframes())
    expected = (1, 2, SAMPLE_RATE, specification["duration"] * SAMPLE_RATE)
    if actual != expected:
        raise RuntimeError("Unexpected synthetic PCM format: " + str(target))
    return target, sha256(target)


def read_index(index):
    require_plain_file(index)
    if not index.exists():
        return None, []
    original = index.read_bytes()
    tracks = json.loads(original)
    if not isinstance(tracks, list) or not all(isinstance(track, dict) for track in tracks):
        raise RuntimeError("Unrecognized library index; retained unchanged.")
    ids = [track.get("id") for track in tracks]
    if not all(isinstance(value, str) for value in ids) or len(set(ids)) != len(ids):
        raise RuntimeError("Invalid library identities; retained unchanged.")
    for track in tracks:
        for key in ["id", "title", "artist", "album", "audioFile", "palette", "lyrics"]:
            if not isinstance(track.get(key), str):
                raise RuntimeError("Invalid Track schema; retained unchanged.")
        if (track.get("isDemo") is not False or track.get("remote") is not None
                or not isinstance(track.get("isLyricDemo"), bool)
                or not isinstance(track.get("duration"), (int, float))
                or not math.isfinite(track["duration"]) or track["duration"] < 0
                or track["palette"] not in ["sea", "window", "night", "local"]):
            raise RuntimeError("Invalid local Track schema; retained unchanged.")
        for filename in [track["audioFile"], track.get("artworkFile")]:
            if filename is not None and (not isinstance(filename, str) or not filename
                    or filename in [".", ".."] or any(mark in filename for mark in ["/", "\\", "\0"])):
                raise RuntimeError("Unsafe filename in index; retained unchanged.")
    return original, tracks


def install_audio(source, destination, expected_hash):
    require_plain_file(destination)
    if destination.exists():
        if sha256(destination) != expected_hash:
            raise RuntimeError("Existing simulator audio differs; retained unchanged: " + str(destination))
        return
    try:
        # Exclusive creation prevents replacement of any existing simulator file.
        with source.open("rb") as incoming, destination.open("xb") as outgoing:
            shutil.copyfileobj(incoming, outgoing)
    except Exception:
        # Keep any failed-copy file for explicit inspection; never delete a file
        # that might have been created or changed by another application action.
        raise
    if sha256(destination) != expected_hash:
        raise RuntimeError("Copy verification failed; audio retained for inspection.")


def main():
    directory = verify_destination()
    index = directory / "library.json"
    original, existing = read_index(index)
    build_directory = ROOT / "Build/ScreenDraftQA"
    build_directory.mkdir(parents=True, exist_ok=True)
    generated = [ensure_generated_audio(build_directory, spec) for spec in TRACKS]
    expected_tracks = []
    for specification, (source, fingerprint) in zip(TRACKS, generated):
        expected_tracks.append({
            "id": specification["id"], "title": specification["title"],
            "artist": "One Tape · 合成测试音", "album": "屏幕初稿",
            "audioFile": source.name, "palette": "local", "duration": specification["duration"],
            "lyrics": "", "isDemo": False, "isLyricDemo": False, "contentHash": fingerprint,
        })
    additions = []
    for expected in expected_tracks:
        matching = [track for track in existing if track["id"] == expected["id"]]
        if matching:
            if any(matching[0].get(key) != value for key, value in expected.items()):
                raise RuntimeError("An existing fixed QA record differs; retained unchanged.")
        else:
            if any(track["audioFile"] == expected["audioFile"] for track in existing):
                raise RuntimeError("An existing record owns the QA audio filename; retained unchanged.")
            additions.append(expected)
    directory.mkdir(parents=True, exist_ok=True)
    # Preflight all audio destinations before the first copy.
    for source, fingerprint in generated:
        destination = directory / source.name
        require_plain_file(destination)
        if destination.exists() and sha256(destination) != fingerprint:
            raise RuntimeError("Conflicting audio exists; nothing is replaced.")
    for source, fingerprint in generated:
        install_audio(source, directory / source.name, fingerprint)
    if additions:
        encoded = (json.dumps(existing + additions, ensure_ascii=False, indent=2) + "\n").encode("utf8")
        current = index.read_bytes() if index.exists() else None
        if current != original:
            raise RuntimeError("The library index changed during preparation; no index replacement made.")
        if original is None:
            with index.open("xb") as output:
                output.write(encoded)
        else:
            descriptor, temporary_name = tempfile.mkstemp(prefix=".screen-draft-qa-index-", dir=directory)
            temporary = Path(temporary_name)
            try:
                with os.fdopen(descriptor, "wb") as output:
                    output.write(encoded)
                    output.flush()
                    os.fsync(output.fileno())
                if index.read_bytes() != original:
                    raise RuntimeError("The existing index changed; retained instead of replacing it.")
                os.replace(temporary, index)
            finally:
                temporary.unlink(missing_ok=True)
    receipt = {
        "syntheticSource": SOURCE,
        "generator": {"path": str(Path(__file__).resolve()), "sha256": sha256(Path(__file__))},
        "index": {"path": str(index), "previousSHA256": hashlib.sha256(original).hexdigest() if original else None,
                  "sha256": sha256(index)},
        "audio": [{"path": str(directory / source.name), "sha256": fingerprint,
                   "generatedSourcePath": str(source)} for source, fingerprint in generated],
    }
    evidence = ROOT / "Evidence/0.4.0/screen-draft-v1/qa-fixture.json"
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
    print(json.dumps({"preparedIndex": str(index), "addedRecords": len(additions),
                      "retainedRecords": len(existing), "receipt": str(evidence)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
