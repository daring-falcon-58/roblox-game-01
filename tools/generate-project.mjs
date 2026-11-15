// generate-project.mjs — builds default.project.json for Ember Ascent.
//
// The tower is laid out from a small course spec (four stages, eight steps
// each) instead of hand-placed parts: every platform, checkpoint, coin,
// mover, spinner, vanishing platform, gate and cloud comes from the same
// numbers, so the place file, the server scripts and the screenshots all
// agree. Run it, then `rojo build`:
//
//   node tools/generate-project.mjs
//   ./tools/rojo build default.project.json --output game.rbxl
//
// This script only writes default.project.json; it never touches game.rbxl.

import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repo = dirname(here);

// ---------------------------------------------------------------------------
// Course spec
// ---------------------------------------------------------------------------

// Four stages, climbed in order. baseY is the height the stage starts at,
// startZ is where its first platform sits, and the stage's colour tints its
// platforms, gate arch and HUD banner.
const STAGES = [
  { name: "MEADOW", colour: [96, 178, 92], accent: [214, 240, 120], baseY: 0, startZ: 20 },
  { name: "EMBER", colour: [224, 112, 48], accent: [255, 196, 90], baseY: 20, startZ: 130 },
  { name: "FROST", colour: [118, 188, 232], accent: [210, 240, 255], baseY: 40, startZ: 240 },
  { name: "SUMMIT", colour: [156, 112, 224], accent: [255, 214, 90], baseY: 60, startZ: 350 },
];

// Eight steps per stage. x is the sideways offset from the stage's centre
// line, so the climb zigzags; z advances 12 studs a step and y rises 2.5,
// a jump any player can make. kind picks the step's trick.
const STEPS = [
  { x: 0, kind: "plain" },
  { x: -7, kind: "plain" },
  { x: 7, kind: "mover" },
  { x: -7, kind: "plain" },
  { x: 7, kind: "spinner" },
  { x: 0, kind: "plain" },
  { x: -7, kind: "vanish" },
  { x: 7, kind: "plain" },
];

const STEP_Z = 12;
const STEP_Y = 2.5;
const PLATFORM_SIZE = [8, 1, 8];
const COIN_STEPS = [1, 3, 5]; // steps that carry a coin (0-based), 3 a stage
const GOLD = [255, 200, 40];
const CHECKPOINT_GREEN = [60, 220, 90];
const LAVA_COLOUR = [255, 80, 20];

// ---------------------------------------------------------------------------
// Rojo tree helpers
// ---------------------------------------------------------------------------

function rgb(triple) {
  return [triple[0] / 255, triple[1] / 255, triple[2] / 255];
}

function part(name, position, size, colour, extra = {}) {
  // Rojo takes the instance name from the tree key, never from a Name
  // property, so the key IS the name; no Name property is written.
  return {
    $className: "Part",
    $properties: {
      Anchored: true,
      CanCollide: extra.canCollide ?? true,
      CanTouch: extra.canTouch ?? true,
      Color: rgb(colour),
      Material: extra.material ?? "SmoothPlastic",
      Position: position,
      Size: size,
      Transparency: extra.transparency ?? 0,
      ...(extra.shape ? { Shape: extra.shape } : {}),
    },
    ...(extra.children ?? {}),
  };
}

function ball(name, position, diameter, colour, transparency = 0) {
  return part(name, position, [diameter, diameter, diameter], colour, {
    shape: "Ball",
    canCollide: false,
    canTouch: false,
    transparency,
  });
}

// ---------------------------------------------------------------------------
// World
// ---------------------------------------------------------------------------

const workspaceChildren = {};

// The start pad and its spawn point.
workspaceChildren.StartPad = part("StartPad", [0, 0, 0], [14, 1, 14], [150, 200, 150]);
workspaceChildren.SpawnLocation = {
  $className: "SpawnLocation",
  $properties: {
    Anchored: true,
    Color: rgb([120, 200, 120]),
    Duration: 0,
    Enabled: true,
    Neutral: true,
    Position: [0, 1, 0],
    Size: [6, 1, 6],
  },
};

// One lava sea under the whole tower: any fall ends in it.
workspaceChildren.Lava = part("Lava", [0, -12, 220], [90, 1, 480], LAVA_COLOUR, {
  material: "Neon",
});

let moverCount = 0;
let vanishCount = 0;
let coinCount = 0;

for (const [stageIndex, stage] of STAGES.entries()) {
  const stageNumber = stageIndex + 1;

  // Checkpoint pad at the stage's foot, with a gate arch over it.
  const gateZ = stage.startZ - 10;
  const gateY = stage.baseY;
  workspaceChildren[`Checkpoint${stageNumber}`] = part(
    `Checkpoint${stageNumber}`,
    [0, gateY, gateZ],
    [8, 1, 8],
    CHECKPOINT_GREEN,
    { material: "Neon" },
  );
  workspaceChildren[`GateLeft${stageNumber}`] = part(
    `GateLeft${stageNumber}`,
    [-6, gateY + 4, gateZ],
    [2, 8, 2],
    stage.accent,
    { material: "Neon" },
  );
  workspaceChildren[`GateRight${stageNumber}`] = part(
    `GateRight${stageNumber}`,
    [6, gateY + 4, gateZ],
    [2, 8, 2],
    stage.accent,
    { material: "Neon" },
  );
  workspaceChildren[`GateTop${stageNumber}`] = part(
    `GateTop${stageNumber}`,
    [0, gateY + 8, gateZ],
    [14, 1, 2],
    stage.accent,
    { material: "Neon" },
  );

  for (const [stepIndex, step] of STEPS.entries()) {
    const x = step.x;
    const y = stage.baseY + stepIndex * STEP_Y;
    const z = stage.startZ + stepIndex * STEP_Z;
    const key = `Platform${stageNumber}_${stepIndex + 1}`;

    if (step.kind === "mover") {
      moverCount += 1;
      workspaceChildren[`Mover${moverCount}`] = part(
        `Mover${moverCount}`,
        [x, y, z],
        PLATFORM_SIZE,
        stage.colour,
        { material: "Neon" },
      );
    } else if (step.kind === "vanish") {
      vanishCount += 1;
      workspaceChildren[`Vanish${vanishCount}`] = part(
        `Vanish${vanishCount}`,
        [x, y, z],
        PLATFORM_SIZE,
        stage.colour,
      );
    } else if (step.kind === "spinner") {
      // A plain platform with a killer bar turning above it. Rojo takes a
      // part's Position as world coordinates, so the bar's position is
      // absolute even though it nests under its platform.
      workspaceChildren[key] = part(key, [x, y, z], PLATFORM_SIZE, stage.colour, {
        children: {
          Spinner: part("Spinner", [x, y + 1.5, z], [2, 1, 11], [255, 60, 60], {
            material: "Neon",
            canCollide: false,
          }),
        },
      });
    } else {
      workspaceChildren[key] = part(key, [x, y, z], PLATFORM_SIZE, stage.colour);
    }

    if (COIN_STEPS.includes(stepIndex)) {
      coinCount += 1;
      workspaceChildren[`Coin${coinCount}`] = ball(
        "Coin",
        [x, y + 3.5, z],
        2.5,
        GOLD,
      );
      // The ball's own material should shine.
      workspaceChildren[`Coin${coinCount}`].$properties.Material = "Neon";
    }
  }
}

// The win pad at the top of the tower, with a gold beacon beside it.
const winZ = STAGES[3].startZ + 7 * STEP_Z + STEP_Z;
const winY = STAGES[3].baseY + 7 * STEP_Y + STEP_Y;
workspaceChildren.WinPad = part("WinPad", [0, winY, winZ], [10, 1, 10], GOLD, {
  material: "Neon",
});
workspaceChildren.Beacon = part("Beacon", [12, winY + 12, winZ + 4], [3, 24, 3], GOLD, {
  material: "Neon",
  canCollide: false,
  canTouch: false,
});
workspaceChildren.BeaconTop = ball("BeaconTop", [12, winY + 25, winZ + 4], 5, GOLD);

// Clouds drifting around the tower, for the skyline.
const clouds = [
  [-28, 24, 40, 10], [30, 30, 90, 12], [-32, 44, 150, 9], [28, 52, 200, 11],
  [-30, 58, 260, 10], [32, 66, 310, 12], [-28, 72, 360, 9], [30, 80, 410, 11],
  [-24, 84, 445, 10], [24, 18, 10, 8], [-20, 90, 300, 8], [22, 40, 180, 9],
];
for (const [index, cloud] of clouds.entries()) {
  workspaceChildren[`Cloud${index + 1}`] = ball(
    `Cloud${index + 1}`,
    [cloud[0], cloud[1], cloud[2]],
    cloud[3],
    [255, 255, 255],
    0.45,
  );
}

// ---------------------------------------------------------------------------
// Project
// ---------------------------------------------------------------------------

const project = {
  name: "ember-ascent",
  tree: {
    $className: "DataModel",
    Players: {
      $properties: { CharacterAutoLoads: true },
    },
    ReplicatedStorage: {
      Shared: { $path: "src/shared" },
      Remotes: {
        $className: "Folder",
        PlayerWon: { $className: "RemoteEvent" },
        StageChanged: { $className: "RemoteEvent" },
        CoinTaken: { $className: "RemoteEvent" },
        ResetRun: { $className: "RemoteEvent" },
        ResetCoins: { $className: "RemoteEvent" },
      },
    },
    ServerScriptService: {
      Server: { $path: "src/server" },
    },
    StarterPlayer: {
      StarterPlayerScripts: {
        Client: { $path: "src/client" },
      },
    },
    Workspace: {
      $properties: { FilteringEnabled: true },
      ...workspaceChildren,
    },
    Lighting: {
      $properties: {
        Ambient: [0.3, 0.3, 0.35],
        OutdoorAmbient: [0.55, 0.55, 0.6],
        Brightness: 2,
        ClockTime: 15.5,
        FogEnd: 600,
        GlobalShadows: true,
        Outlines: false,
        Technology: "Voxel",
      },
    },
    SoundService: {
      $properties: { RespectFilteringEnabled: true },
    },
  },
};

writeFileSync(join(repo, "default.project.json"), JSON.stringify(project, null, 2) + "\n");

const partCount = Object.keys(workspaceChildren).length;
console.log(`wrote default.project.json: ${partCount} workspace instances, ` +
  `${moverCount} movers, ${vanishCount} vanishing platforms, ${coinCount} coins, ` +
  `win pad at y=${winY}, z=${winZ}`);
