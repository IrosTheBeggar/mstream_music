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

## Headless copy (`mstream_mirror`)

The same engine from the command line, for a NAS, a desktop without the app
open, or a scheduled task (A11):

```
dart run library_mirror:mstream_mirror --server http://nas:3000 --dest D:\Music --keep library:music
dart run library_mirror:mstream_mirror --server http://nas:3000 --dest D:\Music        # later runs
dart compile exe bin/mstream_mirror.dart -o mstream_mirror.exe                            # one binary
```

`--keep kind:key` adds a rule (`library:music`, `folder:/music/Live`,
`album:Name`, `artist:Name`, `playlist:Name`, `rated:8`), `--drop` removes
one, `--list-rules` shows them; rules live in the index next to the copy
(`<dest>/.mstream-index.db`), so a bare run repeats the last set. Sign in
with `--user`/`--password` or pass `--token`; public-mode servers need
neither. Exit codes: 0 ok, 1 fatal, 2 some files failed (retried next run).
The copy lands in `<dest>/media/<name>/`, deletions in
`<dest>/.mstream-trash/<name>/<date>/` for `--retention-days` (30).

