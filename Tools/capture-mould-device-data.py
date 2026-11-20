"""Read-only inventory and selected index hashes; never copy user audio."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

stage, device = sys.argv[1:3]
root = Path(__file__).resolve().parents[1]
work = root / "Build" / "MouldedShellsDataSnapshot"
work.mkdir(parents=True, exist_ok=True)
listing = work / f"files-{stage}.json"
command = ["xcrun", "devicectl", "--quiet", "device", "info", "files",
           "--device", device, "--domain-type", "appDataContainer",
           "--domain-identifier", "com.liuhang.stillroom",
           "--subdirectory", "Library/Application Support/Stillroom",
           "--json-output", str(listing)]
subprocess.run(command, check=True, capture_output=True)
files = json.loads(listing.read_text())["result"]["files"]
indexes = {}
inventory = []
for item in files:
    if item.get("resources", {}).get("isDirectory"):
        continue
    relative = item["relativePath"]
    metadata = item.get("metadata", {})
    inventory.append([relative, metadata.get("size")])
    if Path(relative).name not in {"library.json", "crafted-archive.json", "media-overrides.json", "catalog.json"}:
        continue
    destination = work / stage / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["xcrun", "devicectl", "--quiet", "device", "copy", "from",
                    "--device", device, "--domain-type", "appDataContainer",
                    "--domain-identifier", "com.liuhang.stillroom",
                    "--source", "Library/Application Support/Stillroom/" + relative,
                    "--destination", str(destination)], check=True, capture_output=True)
    indexes[relative] = hashlib.sha256(destination.read_bytes()).hexdigest()
snapshot = {
    "stage": stage, "indexSHA256": indexes, "fileCount": len(inventory),
    "fileNameAndSizeSHA256": hashlib.sha256(json.dumps(sorted(inventory)).encode()).hexdigest(),
    "scope": "Application Support/Stillroom index hashes and file-name/size inventory only. No audio bytes copied. Appearance preferences are intentionally selectable."
}
output = root / "Evidence/0.4.0/moulded-shells-20261107" / f"data-{stage}.json"
output.write_text(json.dumps(snapshot, indent=2) + "\n")
print(f"Recorded {len(indexes)} selected indexes and {len(inventory)} file entries.")
