# GAME SPEC — STEAL THE QUESTIONS

Status: LOCKED FOUNDATION (Update 005)

## 1. Core objective
STEAL THE QUESTIONS is a competitive collectible-question card game.
The primary loop is:
Answer -> earn/steal cards -> build decks -> duel -> steal -> collect -> rank.

The game is not a school quiz, TV game show, character combat game, or currency-driven RPG.

## 2. Card universe
- Total unique question cards: 222.
- 22 cards are LEGENDARY.
- 200 cards are normal competitive cards:
  - 150 EPIC
  - 50 GOLD
- Every card has one permanent Card ID.
- The question itself is the collectible card identity.
- A player can own a maximum of one copy of each Card ID.
- Multiple players can own the same Card ID.
- A stolen card keeps its Card ID and rarity.

### Legendary acquisition
LEGENDARY cards are not awarded by normal bot play.
They are ranking rewards:
- Rank 1: 1 LEGENDARY card.
- Rank 2: 3 GOLD cards.
- Rank 3: 2 GOLD cards.
- Other ranks: no end-of-ranking card reward.

A future ranking-cycle rule may distribute the 22 Legendary pool again, but it is not implemented in this foundation update.

## 3. Collection
Collection = every Card ID currently owned by the player.

### New player
- Starts with 0 cards.
- Completes the tutorial.
- Can only play the system/bot onboarding mode.
- PvP is locked until the player owns 10 cards.

### Bot onboarding
- Correct answer: award 1 random unowned normal card.
- Wrong answer: award nothing.
- Timeout: counts as wrong and awards nothing.
- The bot mode is available only while collection size is below 10.
- When collection reaches 10 cards, bot onboarding ends and PvP unlocks.

### Falling below 10 cards
If a PvP loss reduces collection below 10:
- PvP is locked again.
- Bot onboarding becomes available.
- The player uses bot play until collection returns to 10.
- No duplicate Card IDs are ever awarded.

## 4. Decks
- A deck contains exactly 10 distinct owned cards.
- A card may be reused in more than one deck.
- Free deck slots: 2.
- Weekly Pass deck slots: +3.
- Total possible deck slots with pass: 5.
- A locked pass deck is preserved but cannot be selected until the pass is active.
- A player must have a complete 10-card selected deck before entering PvP.

The deck is strategically important because its cards form the question pool presented by that player during a duel.

## 5. Duel model
PvP is a server-authoritative 1v1 duel.

Each player:
1. Selects one valid 10-card deck.
2. The server randomly selects exactly 7 unique cards from that deck for the duel.
3. The selected 7 cards become that player's attack/question set.
4. During the 7 rounds, each player answers questions generated from the opponent's selected 7 cards.
5. Both players therefore play 7 questions total.

This preserves the collectible-card identity:
your deck determines the questions your opponent must face.

### Timing
- 7 rounds.
- 20 seconds per question.
- Question phase: 2 minutes 20 seconds.
- Result + steal + closing target: 40 seconds.
- Full duel target: 3 minutes.

Timeout = wrong answer and full 20-second response time for tie-breaking.

## 6. Scoring and winner
For each player:
- Primary score = number of correct answers out of 7.
- If scores are tied, lower total response time wins.
- Total response time is the sum of the 7 response times; timeout contributes the full 20 seconds.
- An exact tie on both score and total response time is a DRAW.
- A draw has no winner and no steal.

The final winner decision must be calculated server-side.

## 7. Steal
Only the winner performs the steal flow.

Sequence:
1. Winner sees the opponent's 10-card duel deck face-down.
2. Winner selects exactly 1 card.
3. Server validates the selected Card ID is in the opponent's actual duel deck and still owned by the opponent.
4. The selected card is revealed.
5. Winner confirms the steal.
6. Server atomically removes the Card ID from loser collection and adds it to winner collection.
7. The stolen card remains the same Card ID and rarity.

If the loser would fall below 10 cards after the steal, the onboarding rule in section 3 applies after the duel closes.

No client-only transfer is trusted.

## 8. Matchmaking
Initial PvP matchmaking requirements:
- Authenticated players only.
- Player must have at least 10 owned cards.
- Player must select an unlocked complete deck.
- Only one active PvP duel per player.
- Server creates the match and owns the duel state.
- Client may display state but may not award/remove cards directly.

Detailed queue balancing and anti-abuse tuning are implementation-phase work.

## 9. Weekly Pass
Weekly Pass is the only paid product in the initial release.

Benefits:
- +3 deck slots (total 5).
- Unlocks a 4th answer option where supported.
- No gems, gold, energy, equipment, or other paid currencies.

The pass duration is treated as weekly access. Exact store price, billing SKU, and renewal behavior are deferred to the monetization implementation and must not be hard-coded into game rules.

## 10. Screens
Initial product flow:
- Welcome / authentication
- Tutorial / onboarding
- Bot play
- Home / collection summary
- Collection
- Deck builder
- PvP matchmaking
- Duel
- Result
- Steal
- Ranking
- Weekly Pass
- Settings
- Language selection

## 11. Server authority
Firebase will be the authoritative backend.

Client must never be the final authority for:
- card ownership
- card awards
- steal transfers
- duel winner
- score validation
- response timing
- ranking rewards
- pass entitlement

Random card selection and duel selection must be reproducible/validatable server-side where needed.

## 12. Foundation implementation order
Update 005 locks the rules and creates pure game-domain logic/tests.

Next implementation order:
1. Question/card data model and real 222-card content pipeline.
2. Collection + deck persistence.
3. Bot onboarding.
4. Firebase authentication/data model/rules.
5. Server-authoritative matchmaking and duel state.
6. Server-authoritative steal transaction.
7. Ranking rewards.
8. Weekly Pass.
9. Final visual redesign.
10. Android/iPhone QA and release.

The current visual prototype is not the final art direction and must not be treated as locked.
