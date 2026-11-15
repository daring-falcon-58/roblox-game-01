// Ember Ascent — the entry program (Node 22, standard library only).
//
// It hands the game in: game.rbxl, src/, screenshots/ and PLAY.json are
// copied from this repository into the output directory, and dossier.json
// is written with the kit's vendored library, exactly as the scorer
// rebuilds it. The program runs twice in grading and both runs must write
// the same bytes, so there is no timestamp, no randomness and no network
// anywhere in here.
//
// Run it locally the same way the grader does, with MAKEFUN_OUTPUT_DIR
// standing in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import {
  copyFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

// The scorer's own caps (kit reference/gate.json): only text_max_bytes
// shapes the dossier's bytes; the rest refuse an entry the scorer would
// refuse, so this program fails early where the scorer would fail it.
const DOSSIER_CAPS = {
  text_max_bytes: 65536,
  screenshots: { max: 4, max_bytes: 262144 },
  max_instances: 500000,
  scripts_max_source_bytes: 8388608,
  scripts_max_path_chars: 1048576,
};

const root = fileURLToPath(new URL(".", import.meta.url));
const outDir = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

function fail(message) {
  throw new Error(`ember-ascent: ${message}`);
}

function mustExist(path, what) {
  if (!existsSync(path)) fail(`missing ${what}: ${path}`);
}

function checkScreenshots(dir) {
  const names = readdirSync(dir)
    .filter((name) => !name.startsWith("."))
    .sort();
  if (names.length < 3 || names.length > 4) {
    fail(`screenshots/ holds ${names.length} images, need 3 or 4`);
  }
  for (const name of names) {
    const path = join(dir, name);
    if (!statSync(path).isFile()) fail(`screenshots/${name} is not a file`);
    if (!/\.(png|jpe?g)$/i.test(name)) {
      fail(`screenshots/${name} is not a PNG or JPEG (screenshots/ is images only)`);
    }
    if (statSync(path).size > 262144) {
      fail(`screenshots/${name} is over 256 KiB`);
    }
  }
  return names;
}

function handIn() {
  const placePath = join(root, "game.rbxl");
  const playPath = join(root, "PLAY.json");
  const srcPath = join(root, "src");
  const shotsPath = join(root, "screenshots");

  mustExist(placePath, "the place file");
  mustExist(playPath, "PLAY.json");
  mustExist(srcPath, "the scripts");
  mustExist(shotsPath, "the screenshots");
  const shotNames = checkScreenshots(shotsPath);

  mkdirSync(outDir, { recursive: true });
  copyFileSync(placePath, join(outDir, "game.rbxl"));
  copyFileSync(playPath, join(outDir, "PLAY.json"));
  cpSync(srcPath, join(outDir, "src"), { recursive: true });
  mkdirSync(join(outDir, "screenshots"), { recursive: true });
  cpSync(shotsPath, join(outDir, "screenshots"), { recursive: true });

  const dossier = buildDossier(outDir, DOSSIER_CAPS);
  writeFileSync(join(outDir, "dossier.json"), dossier);

  console.log(
    `ember-ascent: handed in game.rbxl (${statSync(placePath).size} bytes), ` +
      `${shotNames.length} screenshots (${shotNames.join(", ")}), ` +
      `dossier.json (${dossier.length} bytes)`,
  );
}

handIn();
