# Two-Phone Test Checklist

This checklist prepares STEAL THE QUESTIONS for testing on two physical Android phones without changing the question bank.

## Hard guard

**DO NOT add real questions during this phase.**  
Do not seed, generate, rewrite, or replace production questions. Question content will be handled later as a separate approved phase.

## Build identity

- Firebase project: `steal-the-questionssx1`
- Android package: `com.STEALTHE.QUESTIONSSX1`
- Authentication: Google Sign-In only
- CI artifact: signed release APK from Android CI
- Primary admin: `love.dotk@gmail.com`

## Phase A — What can be tested now without Blaze deployment

Install the same latest signed CI APK on Phone A and Phone B.

1. Launch succeeds with no white screen or crash.
2. Sign in on Phone A with Google account A.
3. Sign in on Phone B with a different Google account B.
4. Confirm each phone gets its own player profile and session.
5. Verify Home, Collection, Deck, Profile, Ranking, Hall of Legends, Subscription UI, and error/loading states.
6. On the primary admin account, verify the hidden Super Admin opens and its pages render.
7. Confirm a non-admin account cannot access Super Admin.
8. Confirm the app clearly falls back to Spark/demo behavior when live callable Functions are unavailable.

Passing Phase A means the Android client, authentication shell, navigation, and local/demo readiness are suitable for two physical devices. It does **not** prove live PvP.

## Phase B — Required before real cross-device PvP

Do this only after explicit approval to enable Blaze and deploy the backend:

1. Enable Blaze intentionally for `steal-the-questionssx1`.
2. Deploy Cloud Functions.
3. Deploy Firestore Rules and Indexes.
4. Load only the specifically approved test/real card-question content needed for the duel flow.
5. Keep Phone A and Phone B on two different Google accounts.
6. Bring each account to 10 distinct owned cards.
7. Build a valid 10-card Deck on each account.
8. Start random matchmaking from both phones.
9. Confirm both phones receive the same duel ID.
10. Each player locks 7 distinct card/question challenges.
11. Complete all 7 questions with the 20-second timeout behavior.
12. Confirm result ordering: correct answers first, then elapsed time, exact tie = draw.
13. On a win, confirm exactly 10 facedown opponent snapshot cards appear.
14. Confirm one selected card transfers exactly once and duplicate ownership becomes `×N`.
15. Confirm weekly points and weekly/total steals update server-side.
16. Confirm public profile, Theft Kings, Ranking, and Hall of Legends reflect the result.
17. Confirm Gold/Legendary activity timestamp updates when used in PvP.
18. Confirm reconnect/resume does not duplicate rewards or steals.
19. Confirm Super Admin can inspect the duel/player and can safely cancel a stuck duel.
20. Only after the full flow passes on two phones should `STQ_TWO_ACCOUNT_PVP_PASSED` be attested for production preflight.

## Pass criteria

A two-phone live PvP test is considered passed only when both devices complete the full server-authoritative flow without manual Firestore edits, duplicate rewards, identity leaks, or client-side currency/ranking writes.
