// Golden values from the mStream server's own engines (src/torrent/path-template.js,
// src/discovery-plugins/destination.js, src/db/name-key.js) for the phone's ports in
// lib/util/discover_jobs.dart and lib/util/discover_badges.dart. Read-only: pure modules.
// node test/util/fixtures/discover_layout_gold.mjs <mStream checkout> > test/util/fixtures/discover_layout_gold.json
const ROOT = process.argv[2];
if (!ROOT) { console.error('usage: node discover_layout_gold.mjs <mStream checkout>'); process.exit(2); }
const pathTemplate = await import(ROOT + '/src/torrent/path-template.js');
const destination = await import(ROOT + '/src/discovery-plugins/destination.js');
const { nameKey } = await import(ROOT + '/src/db/name-key.js');

const TAGS = [
  { artist: 'Marlowe Vale', album: 'Night Ferry', year: 2019, genre: 'Dream Pop', albumartist: null },
  { artist: 'AC/DC', album: 'Back in Black: Deluxe?', year: '1980', genre: null, albumartist: 'AC/DC' },
  { artist: '  ...Trail of Dead. ', album: 'Source Tags & Codes', year: null, genre: '', albumartist: '' },
  { artist: null, album: null, year: null, genre: null, albumartist: null },
  { artist: 'x'.repeat(260), album: 'tab\there', year: 0, genre: 'a\\b', albumartist: 'Various' },
  { artist: 'Björk', album: '音楽 / ロック', year: 1997, genre: 'Électro', albumartist: null },
];
const LAYOUTS = [
  '{{ARTIST}}/{{ALBUM}}', '{{ALBUMARTIST}}/{{ALBUM}} ({{YEAR}})', '{{PEER}}/{{ARTIST}}/{{ALBUM}}', '{{ artist }}\\{{Album}}',
  'From peers/{{GENRE}}/{{ARTIST}} - {{ALBUM}}', '{{YEAR}}', 'literal only', '{{ARTIST}}//{{ALBUM}}/', '{{GENRE}}/{{YEAR}}/{{PEER}}',
];
const BAD_LAYOUTS = [
  '', '/{{ARTIST}}', '\\{{ARTIST}}', '{{ARTIST}}/{{TRACK}}', '{{ARTIST}/{{ALBUM}}', '{ARTIST}', '{{ARTIST}}/../{{ALBUM}}', '~/{{ARTIST}}',
  '$HOME/{{ARTIST}}', 'C:/{{ARTIST}}', '{{ARTIST}}/D:stuff', 'a\u0001b/{{ARTIST}}', 'x'.repeat(501), '{{YEAR}}{{GENRE}}',
];
const BASES = ['', 'From peers', ' From peers / Sam ', 'a\\b\\c', '/lead/and/trail/', '..', 'ok/../up', '~home', 'C:/x', 'x'.repeat(600), 'tab\tin'];
const SEGMENTS = [null, '', 'AC/DC', ' . dots . ', 'a:b*c?d<e>f|g"h', 'multi   space', 'x'.repeat(300), 42, 'new\nline'];
const FILES = ['shared/03 Paper Lanterns.flac', 'a/b/..', '', 'dir/', 'bad:name?.mp3', '   .hidden. ', 'x/y\\z.mp3'];
const PEERS = ["Sam's server", null, 'a/b'];
const NAMES = ['Borrowed Tapes', '  borrowed\tTAPES ', 'Cold Open’s B‐Sides', '“Quoted” — Dash', 'Beyoncé', 'R.E.M.', '', null, 42, 'ÅNGSTRÖM  İstanbul', 'ΘΕΟΣ', 'ΟΔΟΣ ΚΑΙ ΣΟΦΙΑ', 'ΑΣ.', 'Σ', 'ΑΣ\'Β'];

const out = {
  tags: TAGS, layouts: LAYOUTS, badLayouts: BAD_LAYOUTS, bases: BASES, segments: SEGMENTS, files: FILES, peers: PEERS, names: NAMES,
  sanitize: SEGMENTS.map((s) => pathTemplate.sanitizeSegment(s)),
  resolve: [],
  validate: [...LAYOUTS, ...BAD_LAYOUTS].map((l) => { const v = destination.validateLayout(l); return { valid: v.valid, error: v.valid ? null : v.error }; }),
  normalizeBase: BASES.map((b) => { const v = destination.normalizeBase(b); return { valid: v.valid, base: v.valid ? v.base : null, error: v.valid ? null : v.error }; }),
  safeFileName: FILES.map((f) => destination.safeFileName(f)),
  renderTarget: [],
  nameKey: NAMES.map((n) => nameKey(n)),
  layoutVars: [...destination.LAYOUT_VARS],
  defaultLayout: destination.DEFAULT_LAYOUT,
};
for (const layout of [...LAYOUTS, ...BAD_LAYOUTS]) {
  for (let t = 0; t < TAGS.length; t++) {
    for (const peer of PEERS) {
      const r = pathTemplate.resolveTemplate(layout, { ...TAGS[t], peer });
      out.resolve.push({ layout, tags: t, peer, path: r.path, missingVars: r.missingVars });
    }
  }
}
for (const layout of LAYOUTS) {
  for (let t = 0; t < TAGS.length; t++) {
    for (const base of ['', 'From peers', 'a\\b']) {
      const r = destination.renderTarget({
        destination: { vpath: 'music', base: destination.normalizeBase(base).base, layout },
        tags: TAGS[t], peerName: "Sam's server", fileName: destination.safeFileName('shared/03 Paper Lanterns.flac'),
      });
      out.renderTarget.push({ layout, tags: t, base, relPath: r.relPath, missingVars: r.missingVars });
    }
  }
}
// Compact: layouts by index, long runs of 'x' as { x: length }.
const all = [...LAYOUTS, ...BAD_LAYOUTS];
for (const r of out.resolve) { r.layout = all.indexOf(r.layout); }
for (const r of out.renderTarget) { r.layout = LAYOUTS.indexOf(r.layout); }
const pack = (v) => (typeof v === 'string' && v.length >= 100 && /^x+$/.test(v) ? { x: v.length } : v);
const walk = (o) => (Array.isArray(o) ? o.map((v) => walk(pack(v)))
  : (o && typeof o === 'object' ? Object.fromEntries(Object.entries(o).map(([k, v]) => [k, walk(pack(v))])) : o));
process.stdout.write(JSON.stringify(walk(out)));
