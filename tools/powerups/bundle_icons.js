// Bundles the powerup glyphs (game-icons.net, CC BY 3.0) into core/powerups/powerup_glyphs.json
// and writes core/powerups/CREDITS.md. The game composes each glyph onto its own card at runtime
// (PowerupLibrary.icon), so only the glyph outlines are stored here.
//
//   node tools/powerups/bundle_icons.js

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "../..");
const VENDOR = path.join(__dirname, "vendor", "game-icons");

// powerup id -> "<author>/<glyph>" in the game-icons repository.
const GLYPHS = {
  time_extension: "lorc/sands-of-time",
  time_squeeze: "lorc/time-trap",
  spy_card: "delapouite/spy",
  insight: "lorc/crystal-ball",
  quick_step: "lorc/sprint",
  intel_leak: "delapouite/eye-target",
  recon_drone: "delapouite/delivery-drone",
  fortify: "lorc/bordered-shield",
  scout_report: "delapouite/binoculars",
  swap: "lorc/body-swapping",
  smoke_screen: "darkzaitzev/smoke-bomb",
  jammer: "delapouite/silenced",
  freeze: "lorc/frozen-orb",
  decoy: "lorc/scarecrow",
  chaos_order: "delapouite/rolling-dices",
  flag_hunter: "delapouite/flag-objective",
  double_march: "lorc/boot-prints",
  second_chance: "lorc/angel-wings",
  sabotage: "lorc/time-bomb",
  teleport: "lorc/teleport",
  mine_field: "lorc/land-mine",
  rally_cry: "delapouite/megaphone",
  reinforcement: "delapouite/team-upgrade",
  shuffle: "lorc/cycle",
};

const AUTHORS = { lorc: "Lorc", delapouite: "Delapouite", darkzaitzev: "DarkZaitzev" };

const bundle = {};
for (const [id, source] of Object.entries(GLYPHS)) {
  const svg = fs.readFileSync(path.join(VENDOR, source + ".svg"), "utf8");
  // Every <path d="..."> except the black 512x512 background square.
  const paths = [...svg.matchAll(/<path\b[^>]*\sd="([^"]+)"/g)]
    .map((m) => m[1])
    .filter((d) => !/^M0 0h512v512H0z$/i.test(d.trim()));
  if (paths.length === 0) throw new Error(`No glyph paths in ${source}`);
  bundle[id] = { source, paths };
}

const outDir = path.join(ROOT, "core", "powerups");
fs.writeFileSync(path.join(outDir, "powerup_glyphs.json"), JSON.stringify(bundle));

const lines = [
  "# Powerup glyph credits",
  "",
  "The powerup icons are composed at runtime (card, colours, outline) around glyphs from",
  "[game-icons.net](https://game-icons.net), licensed under",
  "[Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/).",
  "Sources are vendored unmodified in `tools/powerups/vendor/game-icons/`.",
  "",
  "| Powerup | Glyph | Author |",
  "| --- | --- | --- |",
];
for (const [id, { source }] of Object.entries(bundle)) {
  const [author, name] = source.split("/");
  lines.push(`| ${id} | [${name}](https://game-icons.net/1x1/${author}/${name}.html) | ${AUTHORS[author] || author} |`);
}
fs.writeFileSync(path.join(outDir, "CREDITS.md"), lines.join("\n") + "\n");
console.log(`Bundled ${Object.keys(bundle).length} glyphs.`);
