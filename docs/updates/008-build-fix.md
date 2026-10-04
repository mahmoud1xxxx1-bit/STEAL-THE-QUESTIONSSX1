# FIX 008 — Restore missing shared UI components

The GitHub Actions Web build for UPDATE 007 failed because UPDATE 007 removed two shared widgets still referenced by PLAY:
- _PageTitle
- _ModePanel

This fix restores both components without changing the game structure or adding questions.

Backup:
BACKUP-BEFORE-FIX-008
