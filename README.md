# STEAL THE QUESTIONS

A simple competitive quiz game built around owned question cards, short duels, and one-card stealing after victory.

## Scope lock

- Platforms: Android + iPhone
- Client: Flutter
- Backend: Firebase (Authentication, Firestore, Cloud Functions later)
- No VPS
- 1,111 total questions
- 5 decks per player: 2 free + 3 from Weekly Pass
- Each duel uses exactly 10 cards per player
- Winner steals exactly 1 card from the opponent
- Ranking is based on cards owned
- Weekly Pass is the only purchase in the initial version

The first implementation phase is visual and interaction-first: card presentation, question presentation, answer selection, timer, result feedback, and the steal sequence.
