-- GameServer: owns every rule of Ember Ascent — checkpoints, coins, lava,
-- the win, the timer and the leaderboard. The client only draws what this
-- script decides, so the game stays fair when more than one player climbs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local playerWonEvent = remotes:WaitForChild("PlayerWon")
local stageChangedEvent = remotes:WaitForChild("StageChanged")
local coinTakenEvent = remotes:WaitForChild("CoinTaken")
local resetRunEvent = remotes:WaitForChild("ResetRun")
local resetCoinsEvent = remotes:WaitForChild("ResetCoins")

local START_PAD = workspace:WaitForChild("StartPad")
local WIN_PAD = workspace:WaitForChild("WinPad")

-- The tower's best times live in a DataStore, but a DataStore that answers
-- slowly or not at all must never stop the game: every call is wrapped in
-- pcall and a miss just means the best time lives for this session only.
local bestStore = nil
local ok, store = pcall(function()
	return DataStoreService:GetDataStore("EmberAscentBestV1")
end)
if ok then
	bestStore = store
end

-- One row per player, kept in a plain table so a reset is one assignment.
local states = {}
-- Humanoids killed in the last second, so one lava touch cannot kill twice.
local recentlyKilled = {}

local function newState()
	return {
		checkpoint = nil, -- CFrame above the last checkpoint pad, or nil
		stage = 0, -- 0 means still on the start pad
		coins = 0,
		collected = {}, -- [coin Instance] = true, per player
		runStart = os.clock(),
		bestTime = nil, -- seconds, session best (or the stored one)
		won = false,
	}
end

local function killHumanoid(humanoid)
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if recentlyKilled[humanoid] and os.clock() - recentlyKilled[humanoid] < 1 then
		return
	end
	recentlyKilled[humanoid] = os.clock()
	humanoid.Health = 0
end

local function characterOf(hit)
	local parent = hit and hit.Parent
	if parent == nil then
		return nil
	end
	return parent:FindFirstChildOfClass("Humanoid")
end

local function playerOf(hit)
	local humanoid = characterOf(hit)
	if humanoid == nil then
		return nil
	end
	return Players:GetPlayerFromCharacter(humanoid.Parent)
end

local function setupLeaderstats(player, state)
	local board = Instance.new("Folder")
	board.Name = "leaderstats"
	local stageValue = Instance.new("IntValue")
	stageValue.Name = "Stage"
	stageValue.Value = state.stage
	stageValue.Parent = board
	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = 0
	coinsValue.Parent = board
	local bestValue = Instance.new("IntValue")
	bestValue.Name = "Best"
	bestValue.Value = 0
	bestValue.Parent = board
	board.Parent = player
	return board
end

local function loadStoredBest(player, state, board)
	if bestStore == nil then
		return
	end
	task.spawn(function()
		local success, stored = pcall(function()
			return bestStore:GetAsync("best_" .. tostring(player.UserId))
		end)
		if success and type(stored) == "number" and stored > 0 then
			state.bestTime = stored
			local bestValue = board:FindFirstChild("Best")
			if bestValue then
				bestValue.Value = math.floor(stored + 0.5)
			end
		end
	end)
end

local function onPlayerAdded(player)
	local state = newState()
	states[player] = state
	local board = setupLeaderstats(player, state)
	loadStoredBest(player, state, board)

	player.CharacterAdded:Connect(function(character)
		-- A respawn goes back to the last checkpoint, never to the start,
		-- unless the run was reset. Wait a beat so the character is assembled
		-- before it is moved.
		task.wait(0.25)
		if state.checkpoint ~= nil and character.Parent ~= nil then
			character:PivotTo(state.checkpoint)
		end
	end)
end

local function onPlayerRemoving(player)
	states[player] = nil
end

-- Touching a checkpoint pad claims it: the respawn point moves, the stage
-- counter advances and the client shows the stage banner.
local function bindCheckpoints()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name:match("^Checkpoint%d+$") then
			local stageIndex = tonumber(descendant.Name:match("%d+"))
			descendant.Touched:Connect(function(hit)
				local player = playerOf(hit)
				if player == nil then
					return
				end
				local state = states[player]
				if state == nil or state.stage >= stageIndex then
					return
				end
				state.stage = stageIndex
				state.checkpoint = descendant.CFrame + Vector3.new(0, 3, 0)
				local board = player:FindFirstChild("leaderstats")
				if board then
					local stageValue = board:FindFirstChild("Stage")
					if stageValue then
						stageValue.Value = stageIndex
					end
				end
				stageChangedEvent:FireClient(player, stageIndex)
			end)
		end
	end
end

-- Coins are shared in the world but collected per player: the server counts
-- the touch and tells only that player's client to hide the coin, so two
-- climbers never steal each other's coins.
local function bindCoins()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name:match("^Coin%d*$") then
			descendant.Touched:Connect(function(hit)
				local player = playerOf(hit)
				if player == nil then
					return
				end
				local state = states[player]
				if state == nil or state.collected[descendant] then
					return
				end
				state.collected[descendant] = true
				state.coins += 1
				local board = player:FindFirstChild("leaderstats")
				if board then
					local coinsValue = board:FindFirstChild("Coins")
					if coinsValue then
						coinsValue.Value = state.coins
					end
				end
				coinTakenEvent:FireClient(player, descendant)
			end)
		end
	end
end

-- Lava and spinner bars kill on touch. The same debounce that guards lava
-- also guards a spinner, through killHumanoid.
local function bindHazards()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and (descendant.Name == "Lava" or descendant.Name == "Spinner") then
			descendant.Touched:Connect(function(hit)
				killHumanoid(characterOf(hit))
			end)
		end
	end
end

local function winRun(player, state)
	if state.won then
		return
	end
	state.won = true
	local elapsed = os.clock() - state.runStart
	local isBest = state.bestTime == nil or elapsed < state.bestTime
	if isBest then
		state.bestTime = elapsed
		local board = player:FindFirstChild("leaderstats")
		if board then
			local bestValue = board:FindFirstChild("Best")
			if bestValue then
				bestValue.Value = math.floor(elapsed + 0.5)
			end
		end
		if bestStore ~= nil then
			task.spawn(function()
				pcall(function()
					bestStore:SetAsync("best_" .. tostring(player.UserId), elapsed)
				end)
			end)
		end
	end
	playerWonEvent:FireClient(player, elapsed, state.coins, state.bestTime, isBest)
end

local function bindWinPad()
	WIN_PAD.Touched:Connect(function(hit)
		local player = playerOf(hit)
		if player == nil then
			return
		end
		local state = states[player]
		if state == nil then
			return
		end
		winRun(player, state)
	end)
end

local function resetRun(player)
	local state = states[player]
	if state == nil then
		return
	end
	local best = state.bestTime
	states[player] = newState()
	states[player].bestTime = best
	local board = player:FindFirstChild("leaderstats")
	if board then
		local stageValue = board:FindFirstChild("Stage")
		if stageValue then
			stageValue.Value = 0
		end
		local coinsValue = board:FindFirstChild("Coins")
		if coinsValue then
			coinsValue.Value = 0
		end
	end
	resetCoinsEvent:FireClient(player)
	local character = player.Character
	if character ~= nil then
		character:PivotTo(START_PAD.CFrame + Vector3.new(0, 3, 0))
	end
end

resetRunEvent.OnServerEvent:Connect(function(player)
	resetRun(player)
end)

-- A fall past the lava plane is a death, wherever the player went over.
RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character ~= nil then
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if root ~= nil and humanoid ~= nil and root.Position.Y < GameConfig.DEATH_Y then
				killHumanoid(humanoid)
			end
		end
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

bindCheckpoints()
bindCoins()
bindHazards()
bindWinPad()
