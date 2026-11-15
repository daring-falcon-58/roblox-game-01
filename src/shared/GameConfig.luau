-- GameConfig: the single place that names Ember Ascent's stages, palette and
-- tuning numbers. The server scripts and the client HUD both require this
-- module, so a stage rename or a tuning change lands everywhere at once.

local GameConfig = {}

-- Four stages, climbed in order. Each stage's colour tints its platforms,
-- its gate arch and its banner, so a player can read where they are at a
-- glance. The colours are 0-255 RGB triples, turned into Color3 by callers.
GameConfig.STAGES = {
	{ name = "MEADOW", colour = { 96, 178, 92 }, accent = { 214, 240, 120 } },
	{ name = "EMBER", colour = { 224, 112, 48 }, accent = { 255, 196, 90 } },
	{ name = "FROST", colour = { 118, 188, 232 }, accent = { 210, 240, 255 } },
	{ name = "SUMMIT", colour = { 156, 112, 224 }, accent = { 255, 214, 90 } },
}

GameConfig.STAGE_COUNT = #GameConfig.STAGES

-- Coins: three per stage, twelve in the whole tower.
GameConfig.COINS_PER_STAGE = 3
GameConfig.TOTAL_COINS = GameConfig.STAGE_COUNT * GameConfig.COINS_PER_STAGE

-- Falling below this height means the lava got you, wherever you are.
GameConfig.DEATH_Y = -20

-- Moving platforms slide this far from their home position, and take this
-- many seconds for one full back-and-forth.
GameConfig.MOVER_RANGE = 5
GameConfig.MOVER_PERIOD = 4

-- A spinner bar turns this many radians per second.
GameConfig.SPINNER_SPEED = 1.6

-- Vanishing platforms stay solid for this long, then gone for this long.
GameConfig.VANISH_SOLID_SECONDS = 2.5
GameConfig.VANISH_GONE_SECONDS = 1.5

-- Coins spin this fast, in radians per second.
GameConfig.COIN_SPIN_SPEED = 2.2

-- How long a stage banner stays on screen after a checkpoint, in seconds.
GameConfig.BANNER_SECONDS = 2.5

-- The gold time for a full climb, shown on the win screen as the par.
GameConfig.PAR_SECONDS = 150

function GameConfig.stageName(index)
	local stage = GameConfig.STAGES[index]
	if stage then
		return stage.name
	end
	return "MEADOW"
end

function GameConfig.stageColour(index)
	local stage = GameConfig.STAGES[index]
	if stage then
		return Color3.fromRGB(stage.colour[1], stage.colour[2], stage.colour[3])
	end
	return Color3.fromRGB(96, 178, 92)
end

function GameConfig.stageAccent(index)
	local stage = GameConfig.STAGES[index]
	if stage then
		return Color3.fromRGB(stage.accent[1], stage.accent[2], stage.accent[3])
	end
	return Color3.fromRGB(214, 240, 120)
end

-- "87.4" seconds reads as "1:27.4" on the HUD and the win screen.
function GameConfig.formatTime(seconds)
	if seconds == nil then
		return "--:--.-"
	end
	local total = math.max(0, seconds)
	local minutes = math.floor(total / 60)
	local rest = total - minutes * 60
	return string.format("%d:%04.1f", minutes, rest)
end

return GameConfig
