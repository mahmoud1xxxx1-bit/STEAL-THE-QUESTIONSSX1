from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

EXPECTED_PROJECT = "steal-the-questionssx1"
EXPECTED_PACKAGE = "com.STEALTHE.QUESTIONSSX1"
EXPECTED_PRODUCT_ID = "monthly_subscription_v2"

REQUIRED_EXTERNAL_FLAGS = {
    "STQ_BLAZE_ENABLED": "Blaze billing enabled intentionally",
    "STQ_FUNCTIONS_DEPLOYED": "Cloud Functions deployed to the approved Firebase project",
    "STQ_RULES_INDEXES_DEPLOYED": "Firestore rules and indexes deployed and verified",
    "STQ_PURCHASE_CREDENTIALS_CONFIGURED": "Google Play purchase-verification credentials configured",
    "STQ_REAL_CONTENT_LOADED": "Real production cards/questions loaded",
    "STQ_TWO_ACCOUNT_PVP_PASSED": "Live two-account PvP end-to-end test passed",
}


def fail(message: str) -> None:
    raise SystemExit(f"PRECHECK FAILED: {message}")


def require_file(path: str) -> str:
    file = Path(path)
    if not file.exists():
        fail(f"Missing required file: {path}")
    return file.read_text(encoding="utf-8")


def structural_checks() -> None:
    firebaserc = json.loads(require_file(".firebaserc"))
    firebase_json = json.loads(require_file("firebase.json"))
    readme = require_file("README.md")
    main_js = require_file("firebase_functions/main.js")
    purchase_engine = require_file("firebase_functions/purchase_verification_engine_v2.js")
    purchase_functions = require_file("firebase_functions/purchase_verification_functions_v2.js")
    firestore_rules = require_file("firestore.rules")
    workflow = require_file(".github/workflows/flutter-web-preview.yml")

    project = firebaserc.get("projects", {}).get("default")
    if project != EXPECTED_PROJECT:
        fail(f"Firebase target must be {EXPECTED_PROJECT!r}; got {project!r}")

    functions_source = firebase_json.get("functions", {}).get("source")
    if functions_source != "firebase_functions":
        fail("Unexpected Firebase Functions source")

    firestore = firebase_json.get("firestore", {})
    if firestore.get("rules") != "firestore.rules":
        fail("Unexpected Firestore rules path")
    if firestore.get("indexes") != "firestore.indexes.json":
        fail("Unexpected Firestore indexes path")

    if EXPECTED_PACKAGE not in workflow:
        fail("Android package is not enforced by Android CI")

    required_exports = [
        "matchmakingV2",
        "duelV2",
        "botV2",
        "weeklyRankingV2",
        "weeklyPrestigeV2",
        "purchaseVerificationV2",
        "cardLifecycleV2",
        "adminV2",
    ]
    for export_name in required_exports:
        if f"...{export_name}" not in main_js:
            fail(f"Missing Firebase export: {export_name}")

    if EXPECTED_PRODUCT_ID not in purchase_engine:
        fail("Subscription product ID drift detected")
    if "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" not in purchase_functions:
        fail("Google Play purchase verification secret is not wired")

    forbidden_rule_fragments = [
        "allow write: if true",
        "allow create, update, delete: if true",
    ]
    for fragment in forbidden_rule_fragments:
        if fragment in firestore_rules:
            fail(f"Unsafe Firestore rule found: {fragment}")

    if "Production launch remains blocked until Blaze" not in readme:
        fail("README no longer documents the production launch blockers")

    if "signInAnonymously" in "\n".join(
        path.read_text(encoding="utf-8", errors="ignore")
        for path in Path("lib").rglob("*.dart")
    ):
        fail("Anonymous authentication path detected")

    print("STRUCTURAL PRECHECK: PASS")
    print(f"Firebase project: {EXPECTED_PROJECT}")
    print(f"Android package: {EXPECTED_PACKAGE}")
    print(f"Subscription product: {EXPECTED_PRODUCT_ID}")
    print("Server-authoritative exports, Firestore safety, auth path, and deploy wiring verified.")


def production_checks() -> None:
    missing = []
    for key, description in REQUIRED_EXTERNAL_FLAGS.items():
        value = os.environ.get(key, "").strip().lower()
        if value not in {"1", "true", "yes"}:
            missing.append(f"{key}: {description}")

    if missing:
        print("PRODUCTION PRECHECK: BLOCKED")
        print("The repository is structurally ready, but these external launch gates are not verified:")
        for item in missing:
            print(f"- {item}")
        raise SystemExit(2)

    print("PRODUCTION PRECHECK: PASS")
    print("All repository and external launch gates were explicitly verified.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="STEAL THE QUESTIONS production preflight gate."
    )
    parser.add_argument(
        "--production",
        action="store_true",
        help="Require explicit verification of every external production launch gate.",
    )
    args = parser.parse_args()

    structural_checks()
    if args.production:
        production_checks()
    else:
        print("Production status: NOT CLAIMED. Run with --production only after external gates are verified.")


if __name__ == "__main__":
    main()
