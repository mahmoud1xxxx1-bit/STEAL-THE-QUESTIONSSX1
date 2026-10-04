# UPDATE 006 — Real Home and Product Navigation

Date: 2026-10-05

## Problem fixed
The previous build exposed only the duel visual prototype. The locked game rules existed in code/docs but were not represented by a reachable product shell.

## Implemented
- Real app entry now opens HOME.
- Bottom navigation:
  - HOME
  - COLLECTION
  - DECKS
  - PLAY
  - MORE
- Home shows:
  - 222-card collection
  - 10-card PvP gate
  - Bot onboarding path
  - deck count
  - quick access to all main areas
- Collection shows all 222 card slots and rarity totals.
- Decks shows 5 possible slots with 2 free + 3 Weekly Pass.
- Play exposes Bot Training and Troll Duel.
- Bot demo lets correct answers add unique cards until 10.
- Troll Duel demo exposes 7-question flow and steal selection.
- More exposes Ranking, Weekly Pass, and Settings.
- Arabic/English toggle is available in the main shell.

## Important boundary
This is the functional product shell/demo layer. Firebase authentication, persistent collection, real matchmaking, server-authoritative scoring/steal, ranking data, and store billing are still not connected.

The visual art direction remains provisional.
