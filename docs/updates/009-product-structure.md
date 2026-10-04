# UPDATE 009 — Product structure

Status: implementation update

## Goal
Turn the temporary navigation shell into a usable product structure without adding the real 222 question bank or live Firebase gameplay.

## Included
- Reworked HOME into a real entry dashboard with collection progress, active deck status, primary play action and quick access.
- Reworked COLLECTION with rarity filters, complete 222-card structure and owned/locked states.
- Reworked DECKS into five visible deck slots with 2 free slots and 3 Weekly Pass slots.
- Added an actual deck-builder screen with 10-card selection logic against locally owned cards.
- Reworked PLAY into Bot Training and TROLL DUEL mode selection with clear locked/ready states.
- Added a visible duel flow explaining 10-card deck -> server selects 7 -> 7 questions -> result/steal.
- Reworked MORE with real Ranking, Weekly Pass, Settings and How It Works screens.
- Added bilingual RTL/LTR structure to the new screens.
- Kept the visual direction explicitly non-final.

## Intentionally not included
- Real question content.
- Firebase authentication or persistence.
- Live matchmaking.
- Server-authoritative duel/steal execution.
- Store billing.
- Final art/branding lock.

## Safety
All player ownership and rewards remain demo/local state. The UI does not claim that client-side actions are authoritative.
