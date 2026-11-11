// Golden values from the mStream server's own folder and artist engines
// (src/discovery-plugins/plugins/federation-copy.js planFolder, landingFor
// and planArtistAlbums; src/discovery-plugins/destination.js layoutLead) and
// the webapp's left-out line (webapp/alpha/discover-jobs.js artistLeftOut)
// for the phone's ports in lib/util/discover_jobs.dart and
// lib/util/plan_artist_albums.dart, over generated inputs: so the server,
// the webapp and the phone cannot drift. Read-only: nothing here writes or
// listens.
// node test/util/fixtures/discover_folder_gold.mjs <mStream checkout> > test/util/fixtures/discover_folder_gold.json
import { createRequire } from 'node:module';

const ROOT = process.argv[2];
if (!ROOT) { console.error('usage: node discover_folder_gold.mjs <mStream checkout>'); process.exit(2); }
const fed = await import(ROOT + '/src/discovery-plugins/plugins/federation-copy.js');
const destination = await import(ROOT + '/src/discovery-plugins/destination.js');
const { nameKey } = await import(ROOT + '/src/db/name-key.js');
const webapp = createRequire(import.meta.url)(ROOT + '/webapp/alpha/discover-jobs.js');

// A small deterministic generator: the same JSON on every run.
let seed = 20261024;
const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
const pick = (a) => a[Math.floor(rnd() * a.length)];
const CHARS = [...'abcdeABCDE éèçñøÅßæœ0123456789 _-.,()[]{}!?&#%+~$@\'`^=<>|:*'];
const word = (n = 1 + Math.floor(rnd() * 9)) => Array.from({ length: n }, () => pick(CHARS)).join('').trim() || 'q';
const SUPPORTED = { mp3: true, flac: true, m4a: true, m3u: false };
const isSupported = (name) => destination.isSupportedAudioFile(name, SUPPORTED);

const folders = [];
for (let t = 0; t < 120; t++) {
  const folder = ['music', word(), ...(rnd() < 0.5 ? [word()] : [])].join('/');
  const listing = [];
  const n = 1 + Math.floor(rnd() * 9);
  for (let i = 0; i < n; i++) {
    const depth = Math.floor(rnd() * 3);
    const dirs = Array.from({ length: depth }, () => (rnd() < 0.1 ? pick(['..', '.hidden', '@eaDir', '$RECYCLE.BIN']) : word()));
    const ext = pick(['mp3', 'flac', 'm4a', 'txt', 'jpg', 'm3u', 'MP3']);
    const inside = rnd() < 0.9;
    listing.push(`${inside ? folder : 'music/elsewhere'}/${[...dirs, `${word()}.${ext}`].join('/')}`);
  }
  if (rnd() < 0.2) { listing.push(listing[0]); }
  if (rnd() < 0.2) { listing.push(`/${listing[0]}/`.replace('//', '/')); }
  const plan = fed.planFolder(listing, folder, { isSupported });
  folders.push({ folder, listing, songs: plan.songs, skipped: plan.skipped });
}

const LAYOUTS = ['{{ALBUMARTIST}}/{{ALBUM}}', 'From friends/{{ALBUMARTIST}}/{{ALBUM}}', ' /From friends/{{ARTIST}}', 'a//b/{{ALBUM}}',
  'plain/only', '{{ARTIST}}', 'Copy of {{SERVERFOLDER}}', 'x}/y', 'Sam/{{PEER}}/{{ALBUM}}', '\\Mixes\\{{YEAR}}'];
const BASES = ['', 'From peers', 'a/b', ' From peers / Sam '];
const leads = LAYOUTS.map((layout) => ({ layout, folders: destination.layoutLead(layout) }));
const landings = [];
for (let t = 0; t < 80; t++) {
  const folder = ['music', word(), ...(rnd() < 0.6 ? [word()] : []), ...(rnd() < 0.2 ? ['..', word()] : [])].join('/');
  const layout = pick(LAYOUTS);
  const base = destination.normalizeBase(pick(BASES));
  if (!base.valid) { continue; }
  const dest = { vpath: 'copies', base: base.base, layout };
  const mirror = fed.landingFor({ folder, landing: null, destination: dest });
  const path = pick(['Borrowed Tapes', 'From Sam/Tapes', ' a / b ', '']);
  const into = fed.landingFor({ folder, landing: { vpath: 'music', path }, destination: dest, writable: [{ vpath: 'music' }, { vpath: 'copies' }] });
  landings.push({ folder, base: dest.base, layout, mirror: mirror.dir, intoPath: path, into: into.dir, intoVpath: into.vpath });
}

const ARTISTS = ['Boukmanflow', 'ALM', 'Color Out', 'Various Artists'];
const artists = [];
for (let t = 0; t < 60; t++) {
  const albums = [];
  const n = 1 + Math.floor(rnd() * 6);
  for (let i = 0; i < n; i++) {
    const credit = pick([...ARTISTS, null, '  ', 'boukmanflow ']);
    const named = Array.from({ length: Math.floor(rnd() * 3) }, () => pick(ARTISTS));
    albums.push({
      name: rnd() < 0.1 ? null : word(),
      year: pick([2019, '2021', null, 2023]),
      album_artist: credit,
      artists: named,
      compilation: pick([true, false, undefined]),
      track_count: pick([3, '9', null, 12]),
    });
  }
  const artist = pick(ARTISTS);
  // The library's album names as the copy keys them (owned.js ownedAlbumKeys).
  const localKeys = new Set(albums.filter(() => rnd() < 0.3).map((a) => nameKey(a.name)));
  const plan = fed.planArtistAlbums({ albums }, artist);
  const missing = fed.planArtistAlbums({ albums }, artist, { localKeys, onlyMissing: true });
  const left = webapp.artistLeftOut({ albums }, artist);
  artists.push({ albums, artist, localKeys: [...localKeys], plan: plan.plan, skipped: plan.skipped, missing: missing.plan, leftOut: left });
}

process.stdout.write(JSON.stringify({ supported: SUPPORTED, folders, leads, landings, artists }, null, 0) + '\n');
