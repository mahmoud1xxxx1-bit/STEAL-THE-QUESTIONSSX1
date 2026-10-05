# UPDATE 010 — REAL GAME SYSTEMS (1–7)

Implemented on branch UPDATE-010-REAL-GAME-SYSTEMS.

## 1. Question/card content
- 222 fixed Card IDs.
- 150 EPIC, 50 GOLD, 22 LEGENDARY.
- Bilingual Arabic/English question content.
- Three base answer options.
- Weekly Pass fourth option is available in the content model.
- Shared client/server question-generation logic is deterministic from the same fact catalog.

## 2. Collection + decks
- Local persistent collection.
- No duplicate owned Card IDs.
- Five deck slots modeled.
- Two free slots, three Weekly Pass slots.
- Deck validation requires exactly 10 distinct owned cards.
- Authenticated save goes through a callable server endpoint.

## 3. Bot onboarding
- Bot questions now run as actual rounds.
- 20-second server/client timer.
- Correct answer awards one random unowned normal card.
- Wrong/timeout awards nothing.
- Bot closes at 10 owned cards.

## 4. Firebase account/data layer
- Firebase initialization layer added.
- Email/password sign-in and account creation added.
- Server-created player profile.
- Firestore collection model and security rules added.
- Client direct writes to ownership/decks/stats are blocked by rules.

## 5. Server-authoritative duel
- Authenticated PvP only.
- One active duel per player.
- Matchmaking queue.
- Server selects 7 from each 10-card deck.
- Opponent receives questions generated from those 7 cards.
- 20 seconds per question.
- Server stores correct answers outside client-readable duel documents.
- Server resolves score and time tie-breaker.

## 6. Server-authoritative steal
- Winner-only reveal.
- Ten-slot face-down selection.
- Server checks ownership and selected slot.
- Atomic loser removal + winner addition.
- Duplicate ownership is rejected and another target can be selected.

## 7. Ranking + Weekly Pass
- Ranking endpoint ordered by owned cards, wins, then UID.
- Weekly top-three reward claim:
  - rank 1: one Legendary
  - rank 2: three Gold
  - rank 3: two Gold
- One reward claim per player per UTC week.
- Weekly Pass product ID reserved as weekly_pass_v1.
- Store purchase service added.
- Receipt is sent to the server for verification.
- No unverified receipt grants the pass. Actual Google Play/App Store receipt verification credentials/configuration are external release configuration and are not fabricated in this update.

## Firebase configuration note
The repository now contains .firebaserc, firebase.json, Firestore rules/indexes, and Cloud Functions source.

GitHub Pages supports optional Firebase web configuration through these repository secrets:
- FIREBASE_WEB_API_KEY
- FIREBASE_WEB_APP_ID
- FIREBASE_WEB_MESSAGING_SENDER_ID
- FIREBASE_WEB_AUTH_DOMAIN
- FIREBASE_WEB_STORAGE_BUCKET
- FIREBASE_PROJECT_ID

Without those values, the web preview safely remains in local mode instead of pretending to be connected to Firebase.

## Validation target
Before merging to main, run Flutter tests and the web build. Do not treat Update 010 as complete until GitHub Actions reports Success.