# library_mirror

The app's local library index: a SQLite cache of what a server's
`POST /api/v1/sync/manifest` (and the album / artist / playlist / rated
lists) returned, plus the on-disk state of every local copy the app knows
about. Pure Dart — no Flutter imports — so the mirror engine that builds on
it can also run headless.

Design: `BACKUP_SYNC_PLAN.md` §4.1, work packages A2–A4 in
`BACKUP_SYNC_IMPLEMENTATION.md`.

```
dart pub get
dart test
```
