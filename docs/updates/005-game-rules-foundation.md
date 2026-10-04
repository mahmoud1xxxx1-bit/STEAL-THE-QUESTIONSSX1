# UPDATE 005 — Game Rules Foundation

Date: 2026-10-05

## Purpose
Freeze the core card/collection/deck/duel economy before Firebase implementation.

## Locked in this update
- 222 unique question cards.
- 22 LEGENDARY / 50 GOLD / 150 EPIC.
- No duplicate Card ID per player.
- New player starts at 0 cards.
- Bot onboarding until exactly 10 cards.
- Correct bot answer = 1 random unowned normal card.
- Wrong/timeout = no card.
- PvP requires at least 10 owned cards.
- PvP loss below 10 returns player to bot onboarding.
- 2 free decks + 3 Weekly Pass decks.
- Each deck = exactly 10 distinct cards.
- Server selects 7 cards from each selected deck.
- Each player answers 7 questions generated from the opponent's 7 selected cards.
- 20 seconds per question.
- Winner = most correct; tie-break = lower total response time.
- Exact tie = draw, no steal.
- Winner steals exactly 1 card from loser deck.
- Card transfer must be atomic and server-authoritative.
- Weekly Pass is the only paid product.
- Visual prototype remains provisional.

## Implementation boundary
This update intentionally does not start Firebase or redesign the visuals.
It establishes the stable rules that the backend and UI will implement next.
