# Product Scope — STEAL THE QUESTIONS

## Core loop
1. New player completes tutorial and plays bot onboarding.
2. Correct answers award unique collectible question cards.
3. At 10 owned cards, PvP unlocks and bot onboarding stops.
4. Player builds decks from owned cards.
5. Each deck contains exactly 10 distinct cards.
6. A PvP duel uses 7 cards selected by the server from each player's chosen deck.
7. Each player answers 7 questions generated from the opponent's selected cards.
8. 20 seconds per question.
9. Primary winner rule: most correct answers.
10. Tie-breaker: lower total response time.
11. Winner steals exactly 1 card from the loser's 10-card duel deck.
12. If a loss drops a player below 10 cards, bot onboarding returns until 10 cards are restored.
13. Ranking is primarily based on cards owned.

## Fixed limits
- 222 unique question cards total for the initial release.
- 22 LEGENDARY.
- 150 EPIC.
- 50 GOLD.
- One copy of each Card ID per player.
- 10 cards per deck.
- 5 deck slots maximum: 2 free + 3 Weekly Pass.
- PvP requires at least 10 owned cards.
- 7 duel questions per player.
- 20 seconds per question.
- 2 minutes 20 seconds question phase.
- 40 seconds target result/steal/closing phase.
- 3 minute full duel target.
- Winner steals exactly 1 card.
- Exact score + exact response-time tie = DRAW, no steal.
- One active PvP duel per player.

## New player
- Starts with 0 cards.
- Tutorial first.
- Bot only until 10 cards.
- Correct bot answer: 1 random unowned normal card.
- Wrong/timeout: no card.
- Bot is disabled at 10 cards.
- Bot returns if PvP loss reduces collection below 10.

## Rarity
- LEGENDARY: 22 special cards, ranking reward.
- GOLD: 50 cards.
- EPIC: 150 cards.

Ranking rewards:
- 1st: 1 LEGENDARY.
- 2nd: 3 GOLD.
- 3rd: 2 GOLD.
- Other ranks: no card reward.

## Weekly Pass
Only paid product in the initial release:
- +3 deck slots.
- 4th answer option where supported.
- Weekly access.
- Exact price/SKU/renewal behavior is deferred to monetization implementation.

## Out of scope for this product foundation
- No gems.
- No gold currency.
- No energy system.
- No equipment.
- No characters.
- No worlds.
- No real-time character combat.
- No chat.
- No large social system.
- No client-trusted economy actions.

## Build order
1. Game rules and domain models.
2. 222-card content pipeline.
3. Collection/decks.
4. Bot onboarding.
5. Firebase auth/data model/rules.
6. Matchmaking + server-authoritative duel.
7. Server-authoritative steal.
8. Ranking.
9. Weekly Pass.
10. Final visual design.
11. QA, release build, and store preparation.
