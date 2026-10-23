// Golden values from the mStream server's own engines (src/torrent/path-template.js,
// src/discovery-plugins/destination.js, src/db/name-key.js, and federation-copy.js's
// serverFolderOf) for the phone's ports in lib/util/discover_jobs.dart and
// lib/util/discover_badges.dart. Read-only: nothing here writes or listens.
// node test/util/fixtures/discover_layout_gold.mjs <mStream checkout> > test/util/fixtures/discover_layout_gold.json
const ROOT = process.argv[2];
if (!ROOT) { console.error('usage: node discover_layout_gold.mjs <mStream checkout>'); process.exit(2); }
const pathTemplate = await import(ROOT + '/src/torrent/path-template.js');
const destination = await import(ROOT + '/src/discovery-plugins/destination.js');
const { nameKey } = await import(ROOT + '/src/db/name-key.js');
const { serverFolderOf } = await import(ROOT + '/src/discovery-plugins/plugins/federation-copy.js');

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
const BASES = ['', 'From peers', ' From peers / Sam ', 'a\\b\\c', '/lead/and/trail/', '..', 'ok/../up', '~home', 'C:/x', 'x'.repeat(600), 'tab\tin', ' nel\u0085 '];
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
// The phone keeps no base folder (the webapp and the terminal do): it holds a
// destination's as the start of the layout, normalised base + '/' + layout
// (discover_jobs.dart foldBase), and saves base ''. Whether the server takes
// that layout, and where it files each song from it — `same` when that is
// where the base folder and the layout put it. Every base here is one the
// server keeps; the long ones go with one layout.
const FOLD_BASES = [
  'From peers', ' From peers / Sam ', '/lead/and/trail/', 'a\\b', 'My  Music', '.', '.hidden/v1.0', 'Été/日本語/🎵',
  'Mix * ? < > | "', '$money', 'a$HOMEx', ' nel\u0085 /x', 'a{b', '}}', '{{FOO}}', '{{ARTIST}}', '{{ artist }}', '{{PEER}}',
  'x'.repeat(300), 'x'.repeat(480),
];
const FOLD_TAGS = [0, 1, 2, 3, 5];
out.foldBases = FOLD_BASES;
out.fold = [];
for (const base of FOLD_BASES) {
  const long = base.length >= 100;
  for (const layout of long ? [LAYOUTS[0]] : LAYOUTS) {
    const b = destination.normalizeBase(base).base;
    const folded = `${b}/${layout}`;
    const check = destination.validateLayout(folded);
    const row = { base: FOLD_BASES.indexOf(base), layout: LAYOUTS.indexOf(layout), error: check.valid ? null : check.error, tags: [], relDir: [], same: [] };
    if (check.valid) {
      for (const t of long ? [...FOLD_TAGS, 4] : FOLD_TAGS) {
        // null: refused (renderTarget renders whole and throws past 500 characters)
        const at = (d) => {
          try {
            return destination.renderTarget({ destination: { vpath: 'music', ...d }, tags: TAGS[t], peerName: "Sam's server", fileName: 'f.mp3' }).relDir;
          } catch { return null; }
        };
        const after = at({ base: '', layout: folded });
        row.tags.push(t);
        row.relDir.push(after);
        row.same.push(after === at({ base: b, layout }));
      }
    }
    out.fold.push(row);
  }
}
// {{SERVERFOLDER}}: the folders a copied song sits in on the peer — a value that may
// be several folders, each made safe on its own (sanitizeFolders) — from its path
// there, the peer's library dropped (serverFolderOf); how layouts render it, and
// which of them the server takes (its sample is two folders).
const PEER_PATHS = [
  'peerlib/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', 'peerlib/01.mp3', '01.mp3', '', null,
  '/peerlib//Boukmanflow/./Borrowed Tapes/x.mp3', 'peerlib\\Win\\Dir\\x.mp3', 'peerlib/../x/y.mp3', 'peerlib/a/../b.mp3',
  ' peerlib / sp ace /  x.mp3 ', 'peerlib/AC:DC?/Live*/x.mp3', 'peerlib/~/$HOME/x.mp3', 'peerlib/..../...hidden/x.mp3',
  'peerlib/nel\u0085/x.mp3', 'peerlib/' + 'x'.repeat(260) + '/y.mp3', 'peerlib/a/b/c/d/e.flac',
  // A first folder that is no folder ('.', blank) is never the library; a NEL one is.
  './peerlib/a/x.mp3', ' /peerlib/a/x.mp3', 'peerlib/ /a/x.mp3', '\u0085/peerlib/a/x.mp3',
];
const SERVER_FOLDERS = [
  'Boukmanflow/Borrowed Tapes', '', null, 'a\\b', '../up/..', ' . /x//y/ ', 'AC:DC/Live?', '~/$HOME/x', 'x'.repeat(300) + '/y',
  'a/./b', 'Été/日本語', 42, ('x'.repeat(150) + '/').repeat(4),
];
const SERVER_FOLDER_LAYOUTS = [
  '{{SERVERFOLDER}}', 'From friends/{{SERVERFOLDER}}', 'Copy of {{SERVERFOLDER}}', '{{SERVERFOLDER}} ({{YEAR}})/{{ARTIST}}',
  '{{PEER}}/{{SERVERFOLDER}}/{{ALBUM}}', '{{ serverfolder }}', '{{SERVERFOLDER}}{{SERVERFOLDER}}', '{{SERVERFOLDER}}/..',
  'C:{{SERVERFOLDER}}', '{{SERVERFOLDER}}/{{TRACK}}',
];
out.peerPaths = PEER_PATHS;
out.serverFolderOf = PEER_PATHS.map((p) => serverFolderOf(p));
out.serverFolders = SERVER_FOLDERS;
out.sanitizeFolders = SERVER_FOLDERS.map((v) => pathTemplate.sanitizeFolders(v));
out.serverFolderLayouts = SERVER_FOLDER_LAYOUTS;
out.serverFolderValidate = SERVER_FOLDER_LAYOUTS.map((l) => { const v = destination.validateLayout(l); return { valid: v.valid, error: v.valid ? null : v.error }; });
out.serverFolderResolve = [];
out.serverFolderRender = [];
for (const layout of SERVER_FOLDER_LAYOUTS) {
  const ok = destination.validateLayout(layout).valid;
  for (const serverfolder of SERVER_FOLDERS) {
    for (const t of [0, 3]) {
      const r = pathTemplate.resolveTemplate(layout, { ...TAGS[t], peer: "Sam's server", serverfolder });
      out.serverFolderResolve.push({ layout: SERVER_FOLDER_LAYOUTS.indexOf(layout), folder: SERVER_FOLDERS.indexOf(serverfolder), tags: t, path: r.path, missingVars: r.missingVars });
      if (!ok) { continue; }
      const row = { layout: SERVER_FOLDER_LAYOUTS.indexOf(layout), folder: SERVER_FOLDERS.indexOf(serverfolder), tags: t };
      try {
        const target = destination.renderTarget({
          destination: { vpath: 'music', base: 'From peers', layout }, tags: TAGS[t], peerName: "Sam's server", serverFolder: serverfolder, fileName: 'f.mp3',
        });
        out.serverFolderRender.push({ ...row, relPath: target.relPath, missingVars: target.missingVars, error: null });
      } catch {
        // Refused: the code the whole render fails validateResolvedPath with.
        const whole = pathTemplate.resolveTemplate(layout, { ...TAGS[t], peer: "Sam's server", serverfolder }, { truncate: false }).path;
        out.serverFolderRender.push({ ...row, relPath: null, missingVars: null, error: pathTemplate.validateResolvedPath(whole).error });
      }
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
