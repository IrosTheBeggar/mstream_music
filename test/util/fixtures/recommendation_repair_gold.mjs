// Golden values from the mStream server's own recommendation schema
// (src/discovery-plugins/recommendation.js repairRecommendation and
// normalizeRecommendation) for the phone's port in lib/objects/discovery.dart
// (sendableRecommendation): which rows the server can repair, which facts it
// nulls, and what it reads the rest as — so a schema change on the server
// shows up as a failing test here. Read-only: nothing here writes or listens.
// node test/util/fixtures/recommendation_repair_gold.mjs <mStream checkout> > test/util/fixtures/recommendation_repair_gold.json
const ROOT = process.argv[2];
if (!ROOT) { console.error('usage: node recommendation_repair_gold.mjs <mStream checkout>'); process.exit(2); }
const rec = await import(ROOT + '/src/discovery-plugins/recommendation.js');

// A per-song P2P row as discovery-p2p.js builds it, then each case's change.
const BASE = {
  artist: 'Static Bloom', title: 'Paper Satellites', album: 'Tidewater', year: 2011, isrc: 'USRC17607839',
  releaseGroupMbid: null, duration: 238.4, similarity: 0.88, recordingMbid: null, exportId: 'x1',
  peer: { endpointId: 'ep1', name: 'Vinyl Vault' }, seedIndex: 0,
};
const x = (n) => 'x'.repeat(n);
const CASES = {
  valid: {},
  'isrc dashed': { isrc: 'US-RC1-76-07839' },
  'isrc spaced lower': { isrc: ' usrc1 7607839 ' },
  'isrc lower': { isrc: 'usrc17607839' },
  'isrc bad': { isrc: 'BAD' },
  'isrc thirteen': { isrc: 'USRC176078390' },
  'isrc number': { isrc: 12345 },
  'isrc empty': { isrc: '' },
  'year 0': { year: 0 },
  'year 10000': { year: 10000 },
  'year 999': { year: 999 },
  'year abc': { year: 'abc' },
  'year string': { year: '2011' },
  'year padded string': { year: ' 1999 ' },
  'year fractional': { year: 2011.5 },
  'year bool': { year: true },
  'duration negative': { duration: -1 },
  'duration string': { duration: '238.4' },
  'duration word': { duration: 'long' },
  'duration zero': { duration: 0 },
  'mbid 65': { recordingMbid: x(65) },
  'mbid 64': { recordingMbid: x(64) },
  'release group number': { releaseGroupMbid: 7 },
  'album 513': { album: x(513) },
  'album 512 padded': { album: `  ${x(512)}  ` },
  'album empty': { album: '' },
  'albumArtist list': { albumArtist: ['Various'] },
  'every fact bad': { album: 7, albumArtist: x(600), year: 0, isrc: 'BAD', releaseGroupMbid: x(65), recordingMbid: false, duration: -3 },
  'artist 513': { artist: x(513) },
  'artist 512 padded': { artist: `${x(512)}  ` },
  'artist number': { artist: 42 },
  'title list': { title: ['x'] },
  'exportId 257': { exportId: x(257) },
  'exportId 256': { exportId: x(256) },
  'exportId number': { exportId: 7 },
  'filepath 2049': { filepath: x(2049) },
  'peer name 129': { peer: { endpointId: 'ep1', name: x(129) } },
  'peer endpointId 129': { peer: { endpointId: x(129), name: 'Vinyl Vault' } },
  'peer endpointId 128': { peer: { endpointId: x(128), name: null, id: 4 } },
  'peer id fractional': { peer: { id: 1.5 } },
  'peer id empty': { peer: { id: '' } },
  'peer id string': { peer: { id: 'peer-1', extra: true } },
  'peer id object': { peer: { id: {} } },
  'peer string': { peer: 'Vinyl Vault' },
  'peer null': { peer: null },
  'source x': { source: 'x' },
  'source empty': { source: '' },
  'source number': { source: 1 },
  'source federation': { source: 'federation' },
  'source local': { source: 'local' },
  'source null': { source: null },
};

const out = [];
for (const [name, change] of Object.entries(CASES)) {
  const input = { ...BASE, ...change };
  const { row, nulled } = rec.repairRecommendation(input);
  out.push({ name, input, repaired: row !== null, nulled, normalized: row ? rec.normalizeRecommendation(row) : null });
}
process.stdout.write(JSON.stringify({ nullableFacts: [...rec.NULLABLE_FACTS], cases: out }) + '\n');
process.exit(0);
