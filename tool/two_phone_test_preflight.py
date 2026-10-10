from __future__ import annotations

import json
from pathlib import Path

EXPECTED_PROJECT = "steal-the-questionssx1"
EXPECTED_PACKAGE = "com.STEALTHE.QUESTIONSSX1"


def fail(message: str) -> None:
    raise SystemExit(f"TWO-PHONE PRECHECK FAILED: {message}")


def read(path: str) -> str:
    file = Path(path)
    if not file.exists():
        fail(f"Missing required file: {path}")
    return file.read_text(encoding="utf-8", errors="ignore")


def main() -> None:
    firebaserc = json.loads(read(".firebaserc"))
    workflow = read(".github/workflows/flutter-web-preview.yml")
    auth = read("lib/backend/google_auth_v2.dart")
    runtime = read("lib/backend/online_runtime_v2.dart")
    main_js = read("firebase_functions/main.js")
    rules = read("firestore.rules")
    checklist = read("TWO_PHONE_TEST_CHECKLIST.md")

    project = firebaserc.get("projects", {}).get("default")
    if project != EXPECTED_PROJECT:
        fail(f"Firebase project must be {EXPECTED_PROJECT}; got {project!r}")

    if EXPECTED_PACKAGE not in workflow:
        fail("Android CI no longer enforces the approved Android package")

    if "GoogleSignIn" not in auth or "GoogleAuthProvider.credential" not in auth:
        fail("Google Sign-In wiring is missing")

    dart_sources = "\n".join(
        path.read_text(encoding="utf-8", errors="ignore")
        for path in Path("lib").rglob("*.dart")
    )
    if "signInAnonymously" in dart_sources:
        fail("Anonymous authentication detected")

    if "FirebaseBootstrap.initialize" not in runtime:
        fail("Firebase runtime bootstrap is missing")

    for export_name in (
        "matchmakingV2",
        "duelV2",
        "botV2",
        "weeklyRankingV2",
        "profileFeaturesV2",
        "adminV2",
    ):
        if f"...{export_name}" not in main_js:
            fail(f"Missing backend export required for two-phone flow: {export_name}")

    if "allow create, update, delete: if false;" not in rules:
        fail("Server-authoritative user-write protection is missing")

    if "DO NOT add real questions" not in checklist:
        fail("Two-phone checklist lost the no-question-content guard")

    print("TWO-PHONE STRUCTURAL PRECHECK: PASS")
    print(f"Firebase project: {EXPECTED_PROJECT}")
    print(f"Android package: {EXPECTED_PACKAGE}")
    print("Google Sign-In path: present")
    print("Server-authoritative PvP/Admin exports: present")
    print("Signed APK can be used for two-device install/auth/UI validation.")
    print("LIVE PvP is not claimed until Functions/rules/indexes are actually deployed.")


if __name__ == "__main__":
    main()
