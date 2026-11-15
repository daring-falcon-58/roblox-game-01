-- Course: keeps the tower moving. Moving platforms slide, spinner bars turn,
-- vanishing platforms blink out on a timer and coins spin in place. Nothing
-- here decides a win or a death — it only moves the pieces, and the game
-- server reads the touches. Every part is found by name, so the world the
-- generator lays out and this script agree without a shared list.
--
-- One Roblox quirk this script works around: an anchored part moved by
-- CFrame does not carry a player standing on it. So each heartbeat, after a
-- mover slides, every rider standing on it is shifted by the same offset.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local movers = {} -- { part, home: CFrame, phase: number, last: CFrame }
local moversByPart = {}
local spinners = {} -- { part, home: CFrame }
local vanishers = {} -- { part, homeTransparency: number }
local coins = {} -- { part, home: CFrame }

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") then
		if descendant.Name:match("^Mover%d+$") then
			local entry = {
				part = descendant,
				home = descendant.CFrame,
				phase = math.random() * math.pi * 2,
				last = descendant.CFrame,
			}
			table.insert(movers, entry)
			moversByPart[descendant] = entry
		elseif descendant.Name == "Spinner" then
			table.insert(spinners, { part = descendant, home = descendant.CFrame })
		elseif descendant.Name:match("^Vanish%d+$") then
			table.insert(vanishers, { part = descendant, homeTransparency = descendant.Transparency })
		elseif descendant.Name:match("^Coin%d*$") then
			table.insert(coins, { part = descendant, home = descendant.CFrame })
		end
	end
end

-- One shared clock drives every cycle, so the tower's rhythm is steady and
-- a player can learn it: movers slide on a sine, vanishers run a fixed
-- solid/gone loop, spinners and coins turn at a constant rate.
local startedAt = os.clock()
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.FilterDescendantsInstances = {}
for _, mover in ipairs(movers) do
	table.insert(raycastParams.FilterDescendantsInstances, mover.part)
end

local function carryRiders(offsets)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character ~= nil then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root ~= nil then
				local hit = workspace:Raycast(
					root.Position,
					Vector3.new(0, -4, 0),
					raycastParams
				)
				if hit ~= nil then
					local offset = offsets[hit.Instance]
					if offset ~= nil then
						root.CFrame += offset
					end
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock() - startedAt

	local offsets = {}
	for _, mover in ipairs(movers) do
		local slide = math.sin((now / GameConfig.MOVER_PERIOD) * math.pi * 2 + mover.phase)
		local nextFrame = mover.home * CFrame.new(slide * GameConfig.MOVER_RANGE, 0, 0)
		offsets[mover.part] = nextFrame.Position - mover.last.Position
		mover.part.CFrame = nextFrame
		mover.last = nextFrame
	end
	carryRiders(offsets)

	for _, spinner in ipairs(spinners) do
		local angle = now * GameConfig.SPINNER_SPEED
		spinner.part.CFrame = spinner.home * CFrame.Angles(0, angle, 0)
	end

	local cycle = GameConfig.VANISH_SOLID_SECONDS + GameConfig.VANISH_GONE_SECONDS
	local inCycle = now % cycle
	for _, vanisher in ipairs(vanishers) do
		if inCycle < GameConfig.VANISH_SOLID_SECONDS then
			vanisher.part.Transparency = vanisher.homeTransparency
			vanisher.part.CanCollide = true
		else
			vanisher.part.Transparency = 1
			vanisher.part.CanCollide = false
		end
	end

	for _, coin in ipairs(coins) do
		local angle = now * GameConfig.COIN_SPIN_SPEED
		coin.part.CFrame = coin.home * CFrame.Angles(0, angle, 0)
	end
end)
