# STEAL THE QUESTIONS — MASTER DESIGN PLAN

## 1. Design goal
The game must feel:
- bright, premium, comfortable, energetic
- clearly a game, not a school quiz
- memorable through card shape, motion, sound, and the steal moment

Do not use a near-black, flat, grey, or visually empty interface.
Do not overload the screen with effects.

## 2. Fixed visual identity
### Palette
- Base: deep navy-blue, not black
- Main surface: rich blue-violet
- Primary accent: electric cyan
- Secondary accent: vivid violet
- Reward accent: warm gold
- Correct: fresh green
- Wrong/time: controlled coral-red
- Text: soft white with strong contrast

### Surfaces
Use layered surfaces:
1. atmospheric background
2. table/arena surface
3. cards
4. controls
5. result overlays

Cards must remain the strongest visual object.

## 3. Card identity
The card is the game's signature.
- distinctive silhouette and border
- subtle depth and glass/metal feeling
- small rarity badge
- clean question typography
- no generic rectangular quiz panel

Card lifecycle:
DECK -> DRAW -> FLIP -> QUESTION -> ANSWER -> RESULT -> EXIT

The same motion language is reused everywhere.

## 4. Duel screen
Layout:
- opponent strip at top
- active card centered
- timer integrated into card
- three large answer choices below/attached to the card
- own deck indicator at bottom
- no unnecessary navigation controls during a duel

The player must understand the state in under one second.

## 5. Answer choices
Three choices only in the free version.
Each choice:
- large touch target
- A/B/C marker
- short press animation
- clear selected state
- no confusing small icons

Correct:
- card pulse + clean green confirmation + signature sound

Wrong:
- short impact + controlled red confirmation + signature sound

Timeout:
- timer closes + distinct timeout sound

## 6. Timer
Base duel timer: 6 seconds.
Visual countdown is part of the card, not a detached stopwatch.
Final 2 seconds become visually more urgent without becoming noisy.

## 7. Steal sequence
This is the signature scene after winning.

Sequence:
1. WIN moment
2. opponent's 10 cards appear face-down
3. cards fan into a controlled selection field
4. player touches one card
5. card rises and reveals its question
6. short pause
7. STEAL confirmation
8. card flies into the player's collection
9. collection count updates

The steal scene must feel satisfying for the winner and meaningful for the loser.

## 8. Core pages
1. Home
2. Cards
3. Decks
4. Duel setup
5. Duel
6. Result / Steal
7. Leaderboard
8. Shop
9. Settings

No additional major pages until approved.

## 9. Home
Home should immediately show:
- player identity
- total owned cards
- world rank
- primary DUEL action
- visible recent/best card

The player should know what to do without reading instructions.

## 10. Cards
A collection-first screen:
- card grid
- owned/locked states
- simple filters
- card detail on tap

Do not make it look like an inventory system.

## 11. Decks
Exactly 5 deck slots:
- 2 free
- 3 Weekly Pass

Each deck contains exactly 10 cards.
The screen makes selection feel strategic, not administrative.

## 12. Duel setup
Simple sequence:
SELECT DECK -> CONFIRM -> FIND RIVAL

No unnecessary menus.

## 13. Result
Show:
- final score
- winner/loser
- concise performance feedback
- primary action

Winner continues immediately to the STEAL screen.

## 14. Leaderboard
Primary metric:
TOTAL CARDS OWNED

Show:
- rank
- player name
- card count

Keep this page clean and competitive.

## 15. Shop
One product only in the initial release:
WEEKLY PASS

Present it as a premium upgrade, not a crowded store.

Benefits:
- 3 additional decks
- fourth answer option
- future approved pass features

## 16. Motion rules
- Fast but readable
- Main transitions: 250–550ms
- Important moments may use a short 650–900ms payoff
- No constant floating animations
- Motion must communicate state, not decorate empty space

## 17. Sound rules
Create a compact signature sound set:
- card draw
- card flip
- answer select
- correct
- wrong
- timeout
- win
- steal
- collection update

Music should support tension and release; it must never overpower the question.

## 18. Comfort rules
- high text contrast
- large touch targets
- generous spacing
- no excessive glow
- no rapid camera movement
- no flashing effects
- readable on small phones and tablets

## 19. Content rule
The first implementation is a visual prototype.
Do not add the 1,111-question database yet.
Do not add economy, Firebase logic, leaderboard backend, or subscriptions to the visual prototype.

## 20. Definition of done for the visual foundation
A player can:
1. see the card enter
2. see it reveal the question
3. read three answers comfortably
4. understand the timer instantly
5. select an answer confidently
6. feel a distinct correct/wrong result
7. reach a polished steal presentation

Only after this foundation feels excellent do we expand the game systems.
