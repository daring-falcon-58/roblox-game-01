-- Hud: everything the player sees — the timer, the coin count, the stage
-- name, the start screen, the win screen and the stage banners. It draws
-- only; every rule lives on the server. The start and win screens are built
-- here in code, so the place needs no pre-made interface.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local playerWonEvent = remotes:WaitForChild("PlayerWon")
local stageChangedEvent = remotes:WaitForChild("StageChanged")
local coinTakenEvent = remotes:WaitForChild("CoinTaken")
local resetRunEvent = remotes:WaitForChild("ResetRun")
local resetCoinsEvent = remotes:WaitForChild("ResetCoins")

local gui = Instance.new("ScreenGui")
gui.Name = "EmberGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10

local function makeLabel(name, parent, text, size, colour)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = size
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = colour
	label.TextStrokeTransparency = 0.6
	label.TextStrokeColor3 = Color3.fromRGB(20, 12, 8)
	label.Parent = parent
	return label
end

local function makeButton(name, parent, text, size)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.TextSize = size
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundColor3 = Color3.fromRGB(72, 160, 72)
	button.BorderSizePixel = 0
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	return button
end

-- The top bar sits centre and right, clear of the top-left corner where
-- Roblox puts its own menu buttons.
local timerLabel = makeLabel("Timer", gui, "TIME  0:00.0", 30, Color3.fromRGB(255, 255, 255))
timerLabel.AnchorPoint = Vector2.new(0.5, 0)
timerLabel.Position = UDim2.new(0.5, 0, 0, 12)
timerLabel.Size = UDim2.fromOffset(260, 40)

local coinsLabel = makeLabel("Coins", gui, "COINS  0/" .. tostring(GameConfig.TOTAL_COINS), 26, Color3.fromRGB(255, 214, 90))
coinsLabel.AnchorPoint = Vector2.new(1, 0)
coinsLabel.Position = UDim2.new(1, -16, 0, 14)
coinsLabel.Size = UDim2.fromOffset(220, 36)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Right

local stageLabel = makeLabel("Stage", gui, "START PAD", 22, Color3.fromRGB(230, 240, 255))
stageLabel.AnchorPoint = Vector2.new(0.5, 0)
stageLabel.Position = UDim2.new(0.5, 0, 0, 52)
stageLabel.Size = UDim2.fromOffset(320, 30)

local bannerLabel = makeLabel("Banner", gui, "", 44, Color3.fromRGB(255, 255, 255))
bannerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
bannerLabel.Position = UDim2.new(0.5, 0, 0.32, 0)
bannerLabel.Size = UDim2.fromOffset(640, 60)
bannerLabel.TextTransparency = 1

local toastLabel = makeLabel("Toast", gui, "", 24, Color3.fromRGB(255, 120, 90))
toastLabel.AnchorPoint = Vector2.new(0.5, 0.5)
toastLabel.Position = UDim2.new(0.5, 0, 0.68, 0)
toastLabel.Size = UDim2.fromOffset(560, 36)
toastLabel.TextTransparency = 1

local function showBanner(text, colour)
	bannerLabel.Text = text
	bannerLabel.TextColor3 = colour
	bannerLabel.TextTransparency = 0
	task.delay(GameConfig.BANNER_SECONDS, function()
		bannerLabel.TextTransparency = 1
	end)
end

local function showToast(text)
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	task.delay(2, function()
		toastLabel.TextTransparency = 1
	end)
end

-- The start screen: title, goal, controls and one big PLAY button.
local startFrame = Instance.new("Frame")
startFrame.Name = "StartScreen"
startFrame.Size = UDim2.fromScale(1, 1)
startFrame.BackgroundColor3 = Color3.fromRGB(24, 18, 40)
startFrame.BackgroundTransparency = 0.25
startFrame.BorderSizePixel = 0
startFrame.Parent = gui

local titleLabel = makeLabel("Title", startFrame, "EMBER ASCENT", 64, Color3.fromRGB(255, 196, 90))
titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
titleLabel.Position = UDim2.new(0.5, 0, 0.30, 0)
titleLabel.Size = UDim2.fromOffset(700, 80)

local subtitleLabel = makeLabel("Subtitle", startFrame, "Climb the tower. Dodge the lava. Reach the summit.", 26, Color3.fromRGB(240, 235, 255))
subtitleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
subtitleLabel.Position = UDim2.new(0.5, 0, 0.40, 0)
subtitleLabel.Size = UDim2.fromOffset(760, 36)

local helpLabel = makeLabel("Help", startFrame, "Move with WASD or the arrow keys  •  Jump with Space\nTouch a green pad to save your checkpoint  •  Grab all 12 coins", 22, Color3.fromRGB(220, 225, 240))
helpLabel.AnchorPoint = Vector2.new(0.5, 0.5)
helpLabel.Position = UDim2.new(0.5, 0, 0.52, 0)
helpLabel.Size = UDim2.fromOffset(760, 64)

local playButton = makeButton("PlayButton", startFrame, "▶  PLAY", 32)
playButton.AnchorPoint = Vector2.new(0.5, 0.5)
playButton.Position = UDim2.new(0.5, 0, 0.66, 0)
playButton.Size = UDim2.fromOffset(260, 72)

-- The win screen: time, coins, best time and a run-again button.
local winFrame = Instance.new("Frame")
winFrame.Name = "WinScreen"
winFrame.Size = UDim2.fromScale(1, 1)
winFrame.BackgroundColor3 = Color3.fromRGB(24, 18, 40)
winFrame.BackgroundTransparency = 0.25
winFrame.BorderSizePixel = 0
winFrame.Visible = false
winFrame.Parent = gui

local winTitle = makeLabel("WinTitle", winFrame, "SUMMIT REACHED!", 56, Color3.fromRGB(255, 214, 90))
winTitle.AnchorPoint = Vector2.new(0.5, 0.5)
winTitle.Position = UDim2.new(0.5, 0, 0.30, 0)
winTitle.Size = UDim2.fromOffset(700, 72)

local winStats = makeLabel("WinStats", winFrame, "", 28, Color3.fromRGB(240, 235, 255))
winStats.AnchorPoint = Vector2.new(0.5, 0.5)
winStats.Position = UDim2.new(0.5, 0, 0.44, 0)
winStats.Size = UDim2.fromOffset(700, 90)

local againButton = makeButton("AgainButton", winFrame, "↻  CLIMB AGAIN", 30)
againButton.AnchorPoint = Vector2.new(0.5, 0.5)
againButton.Position = UDim2.new(0.5, 0, 0.62, 0)
againButton.Size = UDim2.fromOffset(300, 68)

-- The timer is local and display-only; the server keeps the official time
-- and reports it when the run is won.
local runStart = nil
local playing = false
local coinsGot = 0

local function refreshHud()
	if playing and runStart ~= nil then
		timerLabel.Text = "TIME  " .. GameConfig.formatTime(os.clock() - runStart)
	else
		timerLabel.Text = "TIME  0:00.0"
	end
	coinsLabel.Text = "COINS  " .. tostring(coinsGot) .. "/" .. tostring(GameConfig.TOTAL_COINS)
end

RunService.RenderStepped:Connect(function()
	refreshHud()
end)

local function startRun()
	playing = true
	runStart = os.clock()
	coinsGot = 0
	startFrame.Visible = false
	winFrame.Visible = false
	stageLabel.Text = "START PAD"
	refreshHud()
end

playButton.MouseButton1Click:Connect(function()
	startRun()
end)

againButton.MouseButton1Click:Connect(function()
	resetRunEvent:FireServer()
	startRun()
end)

playerWonEvent.OnClientEvent:Connect(function(elapsed, coins, bestTime, isBest)
	playing = false
	local lines = "Your time:  " .. GameConfig.formatTime(elapsed)
		.. "\nCoins:  " .. tostring(coins) .. " / " .. tostring(GameConfig.TOTAL_COINS)
		.. "\nBest time:  " .. GameConfig.formatTime(bestTime)
		.. "  (par " .. GameConfig.formatTime(GameConfig.PAR_SECONDS) .. ")"
	if isBest then
		lines = lines .. "\n★ NEW BEST TIME! ★"
	end
	winStats.Text = lines
	winFrame.Visible = true
end)

stageChangedEvent.OnClientEvent:Connect(function(stageIndex)
	local name = GameConfig.stageName(stageIndex)
	stageLabel.Text = "STAGE " .. tostring(stageIndex) .. "  •  " .. name
	showBanner("STAGE " .. tostring(stageIndex) .. " — " .. name, GameConfig.stageColour(stageIndex))
end)

-- A coin this player took vanishes only on their screen: the server keeps
-- it there for everyone else.
coinTakenEvent.OnClientEvent:Connect(function(coin)
	coinsGot += 1
	if coin ~= nil then
		coin.Transparency = 1
		coin.CanTouch = false
	end
	refreshHud()
end)

resetCoinsEvent.OnClientEvent:Connect(function()
	coinsGot = 0
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name:match("^Coin%d*$") then
			descendant.Transparency = 0
			descendant.CanTouch = true
		end
	end
	refreshHud()
end)

-- A death is a small toast, not a punishment screen: the checkpoint is
-- already waiting.
local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		if playing then
			showToast("You fell! Back to your checkpoint…")
		end
	end)
end

if player.Character ~= nil then
	task.spawn(watchCharacter, player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

gui.Parent = playerGui
refreshHud()
