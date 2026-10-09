# STEAL THE QUESTIONS

Competitive Arabic-first card quiz game for Android, backed by Firebase.

## Current product contract

- Categories: Football, Animals, Anime, Countries & Geography, Movies & Series, General Knowledge, Science & Technology.
- New players start with zero cards and use Bot mode until they own at least 10 different card IDs.
- A PvP deck contains exactly 10 different owned cards.
- Matchmaking is random; there is no direct opponent selection.
- Each player prepares 7 distinct card/question challenges before the duel.
- Each duel contains 7 questions with 20 seconds per question.
- Timeout counts as a wrong answer.
- Winner is decided by correct answers first, then lowest total elapsed time. An exact tie is a draw.
- Weekly ranking points: Win +30, Loss -15, Draw 0.
- Winner steals exactly one card from the opponent's exact 10-card duel deck snapshot.
- Duplicate ownership is allowed: a stolen duplicate increases the player's copy count, while decks still require 10 distinct card IDs.
- Rarity lifecycle: Epic never expires; Gold returns to system inventory after 12 days without PvP use; Legendary after 7 days.
- Free entitlement: 2 deck slots and 3 answer choices.
- Subscriber entitlement: 5 deck slots and 4 answer choices.
- Subscription product ID: `monthly_subscription_v2`.
- Google Sign-In is the Android authentication path. Anonymous authentication is not used.
- Card and question content is stored in Firestore and managed through the hidden admin interface; real production questions are not bundled in the APK.
- Sensitive economy, duel, ranking, stealing, lifecycle, and subscription verification logic is server-authoritative.

## Firebase identity

- Firebase project: `steal-the-questionssx1`
- Android package: `com.STEALTHE.QUESTIONSSX1`
- Functions source: `firebase_functions`
- Firestore rules: `firestore.rules`
- Firestore indexes: `firestore.indexes.json`

Before any Firebase deployment, run:

`python3 tool/verify_firebase_deploy_target.py`

The guard refuses deployment when the repository is not targeting the approved Firebase project or expected Functions/rules/index files.

## Release status

The repository supports Spark/demo testing and signed Android CI builds. Production launch remains blocked until Blaze is intentionally enabled, Cloud Functions/rules/indexes are deployed and verified, purchase-verification credentials are configured, real card/question content is loaded, and a live two-account PvP end-to-end test passes.


## Production preflight gate

Every Android CI run executes the structural preflight:

`python3 tool/production_preflight.py`

This verifies the approved Firebase project/package, Functions exports, Firestore safety, Google Play verification wiring, and the absence of anonymous authentication. A green structural preflight does **not** claim production readiness.

Only before a real production launch, run:

`python3 tool/production_preflight.py --production`

Production mode additionally requires explicit verification of all external launch gates:

- Blaze intentionally enabled.
- Cloud Functions deployed to `steal-the-questionssx1`.
- Firestore rules and indexes deployed and verified.
- Google Play purchase-verification credentials configured.
- Real production cards/questions loaded.
- Live two-account PvP end-to-end test passed.

If any one of these is not explicitly verified, production preflight exits blocked.
