from __future__ import annotations

import json
from pathlib import Path

EXPECTED_PROJECT = "steal-the-questionssx1"

firebaserc_path = Path(".firebaserc")
firebase_json_path = Path("firebase.json")

if not firebaserc_path.exists():
    raise SystemExit("Missing .firebaserc.")
if not firebase_json_path.exists():
    raise SystemExit("Missing firebase.json.")

firebaserc = json.loads(firebaserc_path.read_text(encoding="utf-8"))
firebase_json = json.loads(firebase_json_path.read_text(encoding="utf-8"))

actual = (
    firebaserc.get("projects", {}).get("default")
    if isinstance(firebaserc, dict)
    else None
)
if actual != EXPECTED_PROJECT:
    raise SystemExit(
        f"Refusing Firebase deploy: expected {EXPECTED_PROJECT!r}, got {actual!r}."
    )

functions_source = firebase_json.get("functions", {}).get("source")
rules_path = firebase_json.get("firestore", {}).get("rules")
indexes_path = firebase_json.get("firestore", {}).get("indexes")

if functions_source != "firebase_functions":
    raise SystemExit("Unexpected Firebase Functions source directory.")
if rules_path != "firestore.rules":
    raise SystemExit("Unexpected Firestore rules path.")
if indexes_path != "firestore.indexes.json":
    raise SystemExit("Unexpected Firestore indexes path.")

for required in [
    Path("firebase_functions/main.js"),
    Path("firestore.rules"),
    Path("firestore.indexes.json"),
]:
    if not required.exists():
        raise SystemExit(f"Missing required Firebase deployment file: {required}")

print(f"Firebase deploy target verified: {EXPECTED_PROJECT}")
print("Functions/rules/indexes deployment paths verified.")
