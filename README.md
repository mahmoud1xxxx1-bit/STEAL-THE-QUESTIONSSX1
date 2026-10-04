# STEAL THE QUESTIONS

A competitive quiz card game built around owned question cards, short duels, and one-card stealing after victory.

## Scope lock
- Platforms: Android + iPhone
- Client: Flutter
- Backend: Firebase (later)
- No VPS
- 222 total questions for the initial game
- 5 decks per player: 2 free + 3 from Weekly Pass
- Each deck contains exactly 10 cards
- Each duel uses 7 questions selected from the chosen 10-card deck
- Each question has 20 seconds
- Duel questions take 2 minutes 20 seconds
- Result + steal sequence targets 40 seconds
- Full round target: 3 minutes
- Winner steals exactly 1 card from the opponent
- Ranking is based on cards owned
- Weekly Pass is the only purchase in the initial version

## Visual-first build
The first build focuses only on the signature card experience:
card entrance, flip, question, answers, timer, result feedback, duel flow, and steal presentation.

GitHub Pages is the rapid Flutter Web preview for the same Flutter UI that will become the Android and iPhone builds.
