-- Zinoos hub for Steal an Anime Pack.
-- Same WindUI window as the other Zinoos games. It steals the best pack from the
-- best stage your speed can handle, runs it home, places it, opens it when it's
-- grown, equips your best characters, trains your speed and claims the free stuff.
-- Everything is walked (pathfinding), never teleported: the server checks movement.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

if game.GameId ~= 10701622575 then
	warn("[Zinoos hub] This only runs in Steal an Anime Pack")
	return
end

local function elevate()
	if typeof(setthreadidentity) == "function" then
		pcall(setthreadidentity, 8)
	end
end
elevate()

local LocalPlayer = Players.LocalPlayer
local genv = getgenv()

-- One copy at a time: a new run stops the old one first.
if typeof(genv.ZinoosAnimeStop) == "function" then
	pcall(genv.ZinoosAnimeStop)
	elevate()
end
genv.ZinoosAnimeGen = (typeof(genv.ZinoosAnimeGen) == "number" and genv.ZinoosAnimeGen or 0) + 1
local token = genv.ZinoosAnimeGen
local function running()
	return genv.ZinoosAnimeGen == token
end

local STAGE_BEST = "Best for my speed"

local STATE = {
	_gen = token,
	autoSteal = true,
	stage = STAGE_BEST,
	autoPlace = true,
	autoOpen = true,
	autoEquipBest = true,
	autoTrain = true,
	trainSeconds = "60",
	autoTreadmillUpgrade = true,
	autoBaseUpgrade = true,
	autoLuckUpgrade = false,
	autoRebirth = false,
	autoClaim = true,
	antiAfk = true,
	autoReconnect = false,
	noPausePopup = true,
	fpsBoost = false,
	disable3d = false,
	hideOnStart = false,
	notifications = true,
	toggleKey = "RightControl",
	hubSize = "Compact",
	windTheme = "Zinoos",
	toggleControls = {},
	status = "Starting",
	detail = "",
}
genv.ZinoosAnimeState = STATE

-- This account is the hub owner; the menu shows an Admin tag only for them.
STATE.adminIds = {
	[9346336323] = true,
}
STATE.admin = STATE.adminIds[LocalPlayer.UserId] == true

local runtime = { connections = {}, cleanups = {} }
local function trackConnection(connection)
	table.insert(runtime.connections, connection)
	return connection
end
local function hubCleanup(fn)
	table.insert(runtime.cleanups, fn)
end

local function shutdownHub()
	if genv.ZinoosAnimeGen == token then
		genv.ZinoosAnimeGen = token + 1
	end
	STATE._unloaded = true
	STATE.noPausePopup = false
	for _, connection in ipairs(runtime.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(runtime.connections)
	for index = #runtime.cleanups, 1, -1 do
		pcall(runtime.cleanups[index])
		runtime.cleanups[index] = nil
	end
end
genv.ZinoosAnimeStop = shutdownHub
local function unloadHub()
	shutdownHub()
end

local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/StealAnAnimePack_" .. tostring(LocalPlayer.UserId) .. ".rfld"

local FLAG_KEYS = {
	AutoSteal = "autoSteal",
	AutoPlace = "autoPlace",
	AutoOpen = "autoOpen",
	AutoEquipBest = "autoEquipBest",
	AutoTrain = "autoTrain",
	AutoTreadmillUpgrade = "autoTreadmillUpgrade",
	AutoBaseUpgrade = "autoBaseUpgrade",
	AutoLuckUpgrade = "autoLuckUpgrade",
	AutoRebirth = "autoRebirth",
	AutoClaim = "autoClaim",
	AntiAfk = "antiAfk",
	AutoReconnect = "autoReconnect",
	NoPausePopup = "noPausePopup",
	FpsBoost = "fpsBoost",
	Disable3d = "disable3d",
	HideOnStart = "hideOnStart",
	Notifications = "notifications",
}

local STAGE_OPTIONS = { STAGE_BEST }
for index = 1, 14 do
	STAGE_OPTIONS[#STAGE_OPTIONS + 1] = "Stage " .. index
end
local TRAIN_OPTIONS = { "30", "60", "120", "300" }
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
local CHOICES = {
	Stage = { key = "stage", options = STAGE_OPTIONS },
	TrainSeconds = { key = "trainSeconds", options = TRAIN_OPTIONS },
	ToggleKey = { key = "toggleKey", options = KEY_OPTIONS },
	WindTheme = { key = "windTheme" },
	HubSize = { key = "hubSize", options = { "Compact", "Normal", "Large" } },
}

local function loadSaved()
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" or not isfile(CONFIG_PATH) then
		return
	end
	local ok, saved = pcall(function()
		return HttpService:JSONDecode(readfile(CONFIG_PATH))
	end)
	if not ok or type(saved) ~= "table" then
		return
	end
	for flag, key in pairs(FLAG_KEYS) do
		if type(saved[flag]) == "boolean" then
			STATE[key] = saved[flag]
		end
	end
	for flag, choice in pairs(CHOICES) do
		local value = saved[flag]
		if type(value) == "string" and (not choice.options or table.find(choice.options, value)) then
			STATE[choice.key] = value
		end
	end
end

local function saveConfig()
	if typeof(writefile) ~= "function" then
		return
	end
	if typeof(makefolder) == "function" then
		pcall(makefolder, "Rayfield")
		pcall(makefolder, "Rayfield/Configurations")
		pcall(makefolder, "Rayfield/Configurations/ZinoosHub")
	end
	local payload = {}
	for flag, key in pairs(FLAG_KEYS) do
		payload[flag] = STATE[key] == true
	end
	for flag, choice in pairs(CHOICES) do
		payload[flag] = STATE[choice.key]
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if ok then
		pcall(writefile, CONFIG_PATH, encoded)
	end
end
STATE.writeConfig = saveConfig

local stats = { steals = 0, lost = 0, placed = 0, opened = 0, upgrades = 0, claimed = 0, rebirths = 0, trained = 0 }
STATE.stats = stats
STATE.activity = {}
local function noteActivity(text)
	if STATE.activity[#STATE.activity] == text then
		return
	end
	table.insert(STATE.activity, text)
	while #STATE.activity > 8 do
		table.remove(STATE.activity, 1)
	end
end

local function notify(title, message)
	noteActivity(tostring(title) .. (message and message ~= "" and (" · " .. tostring(message)) or ""))
	if STATE.notifications == false then
		return
	end
	if typeof(STATE.toast) == "function" then
		pcall(STATE.toast, { title = tostring(title), message = tostring(message or "") })
	end
end

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function shortNumber(value)
	value = tonumber(value) or 0
	local sign = value < 0 and "-" or ""
	value = math.abs(value)
	if value < 1000 then
		return sign .. tostring(math.floor(value))
	end
	local index = 0
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	return sign .. string.format(value >= 100 and "%.0f%s" or "%.2f%s", value, SUFFIXES[index])
end
STATE.shortNumber = shortNumber

local function character()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then
		return char, root, hum
	end
	return nil
end

-- Game modules ----------------------------------------------------------------
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteRoot = ReplicatedStorage:WaitForChild("Remotes")
local function gameModule(instance)
	local ok, result = pcall(require, instance)
	elevate()
	return ok and result or nil
end
local DataReceiver = gameModule(Shared.Modules.DataReceiver)
local PlacementUtil = gameModule(Shared.Utilities.PlacementUtil)
local PacksConfig = gameModule(Shared.Configs.PacksConfig)
local StageConfig = gameModule(Shared.Configs.StageConfig)
local TutorialConfig = gameModule(Shared.Configs.TutorialConfig)
local TreadmillConfig = gameModule(Shared.Configs.TreadmillConfig)
local LuckMachineConfig = gameModule(Shared.Configs.LuckMachineConfig)
elevate()

-- The game sends your save to the client as JSON; DataReceiver keeps it.
local function playerData()
	local data = DataReceiver and DataReceiver.Data
	return type(data) == "table" and type(data.Player) == "table" and data.Player or {}
end
local function serverData()
	local data = DataReceiver and DataReceiver.Data
	return type(data) == "table" and type(data.Server) == "table" and data.Server or {}
end
local function cash()
	return tonumber(playerData().Cash) or 0
end
local function speedStat()
	return tonumber(playerData().Speed) or 0
end
local function packsData()
	local inventory = playerData().Inventory
	local packs = type(inventory) == "table" and inventory.Packs
	return type(packs) == "table" and packs or {}
end
local function backpack()
	local list = packsData().Backpack
	return type(list) == "table" and list or {}
end
local function placedList()
	local list = packsData().Placed
	return type(list) == "table" and list or {}
end
-- The pack you're carrying right now (the server tracks steals per player).
local function carrying()
	local stealing = serverData().Stealing
	return type(stealing) == "table" and stealing[tostring(LocalPlayer.UserId)] or nil
end

local function remote(namespace, name)
	local folder = RemoteRoot:FindFirstChild(namespace)
	return folder and folder:FindFirstChild(name) or nil
end
local function invoke(namespace, name, ...)
	if not running() then
		return false, "stopped"
	end
	local target = remote(namespace, name)
	if not target or not target:IsA("RemoteFunction") then
		return false, "missing remote " .. namespace .. "/" .. name
	end
	local packed = table.pack(...)
	local ok, result = pcall(function()
		return target:InvokeServer(table.unpack(packed, 1, packed.n))
	end)
	elevate()
	if not ok then
		return false, result
	end
	return true, result
end
local function fire(namespace, name, ...)
	local target = remote(namespace, name)
	if target and target:IsA("RemoteEvent") then
		pcall(target.FireServer, target, ...)
		return true
	end
	return false
end
local function succeeded(ok, result)
	return ok and (result == true or (type(result) == "table" and result.Success == true))
end
local function reasonOf(ok, result)
	if not ok then
		return tostring(result)
	end
	if type(result) == "table" then
		return tostring(result.Reason or result.Message or "refused")
	end
	return tostring(result)
end

-- Your plot ---------------------------------------------------------------------
local function myPlot()
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	if PlacementUtil and type(PlacementUtil.GetPlayerPlot) == "function" then
		local ok, info = pcall(PlacementUtil.GetPlayerPlot, LocalPlayer)
		elevate()
		if ok and type(info) == "table" and info.Name ~= nil then
			local plot = plots:FindFirstChild(tostring(info.Name))
			if plot then
				return plot
			end
		elseif ok and typeof(info) == "Instance" then
			return info
		end
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local label = plot:FindFirstChild("Sign") and plot.Sign:FindFirstChild("DisplayName", true)
		if label and label:IsA("TextLabel") and label.Text == LocalPlayer.DisplayName then
			return plot
		end
	end
	return nil
end
local function homePoint()
	local plot = myPlot()
	local model = plot and plot:FindFirstChild("PlotModel")
	local spawn = model and model:FindFirstChild("SpawnPoint")
	return spawn and spawn.Position or nil
end
local function inOwnPlot()
	if not PlacementUtil or type(PlacementUtil.IsPlayerInOwnedPlot) ~= "function" then
		return false
	end
	local ok, inside = pcall(PlacementUtil.IsPlayerInOwnedPlot, LocalPlayer)
	return ok and inside == true
end

-- Treadmill: stepping on one locks you into training, so walking routes avoid
-- every treadmill, and the hub steps off yours before it goes anywhere.
local function training()
	return LocalPlayer:GetAttribute("TrainingOnTreadmill") ~= nil
end
local function leaveTreadmill()
	if not training() then
		return true
	end
	fire("Treadmill", "ExitRequest")
	local started = os.clock()
	while training() and os.clock() - started < 3 and running() do
		task.wait(0.1)
	end
	task.wait(0.3)
	return not training()
end

local avoidParts = {}
local function clearAvoid()
	for _, part in ipairs(avoidParts) do
		pcall(part.Destroy, part)
	end
	table.clear(avoidParts)
end
hubCleanup(clearAvoid)
local avoidRefreshed = 0
local function refreshAvoid()
	if os.clock() - avoidRefreshed < 30 and #avoidParts > 0 then
		return
	end
	avoidRefreshed = os.clock()
	clearAvoid()
	local plots = Workspace:FindFirstChild("Plots")
	for _, plot in ipairs(plots and plots:GetChildren() or {}) do
		local treadmill = plot:FindFirstChild("Treadmil")
		if treadmill and treadmill:IsA("Model") then
			local ok, cf, size = pcall(treadmill.GetBoundingBox, treadmill)
			if ok then
				local part = Instance.new("Part")
				part.Name = "ZinoosAvoid"
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Transparency = 1
				part.CFrame = cf
				part.Size = size + Vector3.new(8, 6, 8)
				local modifier = Instance.new("PathfindingModifier")
				modifier.Label = "ZinoosAvoid"
				modifier.Parent = part
				part.Parent = Workspace
				avoidParts[#avoidParts + 1] = part
			end
		end
	end
end

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Walks with PathfindingService (no teleports). goal() is read again on every
-- re-path so moving targets work. Stops when done() says so or after timeout.
local function walkTo(goal, timeout, done)
	refreshAvoid()
	local started = os.clock()
	local points, index, pathedAt = {}, 1, 0
	local lastPos, stuckSince = nil, os.clock()
	while running() and os.clock() - started < timeout do
		local _, root, hum = character()
		if not root then
			return false
		end
		if done and done(root) then
			return true
		end
		if training() then
			leaveTreadmill()
		end
		local target = goal()
		if typeof(target) ~= "Vector3" then
			return false
		end
		if os.clock() - pathedAt > 3 or index > #points + 1 then
			pathedAt = os.clock()
			points, index = {}, 1
			pcall(function()
				local path = PathfindingService:CreatePath({
					AgentRadius = 2.5,
					AgentHeight = 5,
					AgentCanJump = true,
					WaypointSpacing = 8,
					Costs = { ZinoosAvoid = math.huge },
				})
				path:ComputeAsync(root.Position, target)
				if path.Status == Enum.PathStatus.Success then
					points = path:GetWaypoints()
				end
			end)
		end
		local point = points[index]
		if not point then
			hum:MoveTo(target)
			if not done and flat(root.Position, target) < 4 then
				return true
			end
		elseif flat(root.Position, point.Position) < 3 then
			index += 1
		else
			if point.Action == Enum.PathWaypointAction.Jump then
				hum.Jump = true
			end
			hum:MoveTo(point.Position)
		end
		if lastPos and (root.Position - lastPos).Magnitude > 0.6 then
			stuckSince = os.clock()
		elseif os.clock() - stuckSince > 1.2 then
			hum.Jump = true
			pathedAt = 0
			stuckSince = os.clock()
		end
		lastPos = root.Position
		task.wait(0.1)
	end
	local _, rootNow = character()
	return rootNow ~= nil and done ~= nil and done(rootNow)
end

-- Stages ------------------------------------------------------------------------
local function rarityRank(rarity)
	local ranks = PacksConfig and PacksConfig.RarityRank
	return type(ranks) == "table" and tonumber(ranks[rarity]) or 0
end

local function stageInfo(key)
	local stages = StageConfig and StageConfig.Stages
	return type(stages) == "table" and stages[key] or nil
end
STATE.stageInfo = stageInfo

-- The tutorial only lets you steal from one stage at certain steps.
local function tutorialStage()
	local data = playerData()
	if data.TutorialComplete == true or not TutorialConfig or type(TutorialConfig.Step) ~= "table" then
		return nil
	end
	local step = tonumber(data.TutorialStep)
	local steps = TutorialConfig.Step
	if step == tonumber(steps.StealStagePack) or step == tonumber(steps.ReturnStagePack) then
		return TutorialConfig.StealStage or "Stage2"
	end
	if step == tonumber(steps.StealPack) or step == tonumber(steps.ReturnToBase) then
		return "Stage1"
	end
	return nil
end

-- Best stage = the furthest one whose recommended speed you already have.
local function bestStage()
	local mySpeed = speedStat()
	local pick = "Stage1"
	for index = 1, 14 do
		local key = "Stage" .. index
		local info = stageInfo(key)
		local needed = info and tonumber(info.RecommendedSpeed)
		if needed and mySpeed >= needed and info.RuntimeEnabled ~= false then
			pick = key
		end
	end
	return pick
end
STATE.bestStage = bestStage

local function targetStage()
	local forced = tutorialStage()
	if forced then
		return forced, true
	end
	if STATE.stage ~= STAGE_BEST then
		local number = tonumber(string.match(tostring(STATE.stage), "%d+"))
		if number then
			return "Stage" .. number, false
		end
	end
	return bestStage(), false
end

local function packWeight(prompt)
	local text = tostring(prompt:GetAttribute("DetailText") or "")
	return tonumber(string.match(text, "%[([%d%.]+)kg%]")) or 0
end

-- Best pack in a stage: highest rarity, then heaviest (heavier = more cash).
local function bestPackIn(stageKey)
	local packs = Workspace:FindFirstChild("Game") and Workspace.Game:FindFirstChild("Packs")
	local stage = packs and packs:FindFirstChild(stageKey)
	local spawned = stage and stage:FindFirstChild("SpawnedPacks")
	local best, bestRank, bestWeight = nil, -1, -1
	for _, pack in ipairs(spawned and spawned:GetChildren() or {}) do
		local prompt = pack:FindFirstChild("StealPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled and prompt.Parent and prompt.Parent:IsA("Attachment") then
			local rank = rarityRank(prompt:GetAttribute("DetailRarity"))
			local weight = packWeight(prompt)
			if rank > bestRank or (rank == bestRank and weight > bestWeight) then
				best, bestRank, bestWeight = prompt, rank, weight
			end
		end
	end
	return best
end

local function promptPosition(prompt)
	local parent = prompt and prompt.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

-- Stealing ------------------------------------------------------------------------
local function packCount()
	return #backpack()
end

local function stepSteal()
	if STATE.autoSteal ~= true or not running() then
		return false
	end
	local home = homePoint()
	if not home then
		STATE.status = "Looking for your plot"
		return false
	end
	-- Already holding one (from a reload or a manual steal): just run it home.
	if not carrying() then
		local stageKey, tutorial = targetStage()
		local prompt = bestPackIn(stageKey)
		if not prompt then
			STATE.status = "Waiting for packs in " .. stageKey
			return false
		end
		local label = tostring(prompt:GetAttribute("DetailText") or "a pack")
		local rarity = tostring(prompt:GetAttribute("DetailRarity") or "")
		STATE.status = "Going for " .. label .. " (" .. rarity .. ")"
		STATE.detail = stageKey .. (tutorial and " (tutorial)" or "")
		leaveTreadmill()
		local reached = walkTo(function()
			return promptPosition(prompt)
		end, 40, function(root)
			local spot = promptPosition(prompt)
			return not prompt.Parent or not prompt.Enabled or (spot ~= nil and (root.Position - spot).Magnitude < 4)
		end)
		if not reached or not prompt.Parent or not prompt.Enabled then
			STATE.status = "That pack got taken, picking another"
			return false
		end
		local _, _, hum = character()
		if hum then
			local _, root = character()
			hum:MoveTo(root.Position)
		end
		pcall(prompt.InputHoldBegin, prompt)
		task.wait(1.7)
		pcall(prompt.InputHoldEnd, prompt)
		local waited = os.clock()
		while not carrying() and os.clock() - waited < 2 and running() do
			task.wait(0.05)
		end
		if not carrying() then
			STATE.status = "Steal didn't go through, trying again"
			return false
		end
		STATE.status = "Running " .. label .. " home"
	end
	local before = packCount()
	walkTo(homePoint, 45, function()
		return packCount() > before or not carrying()
	end)
	task.wait(0.5)
	if packCount() > before then
		stats.steals += 1
		notify("Stole a pack", tostring(STATE.detail))
		return true
	end
	stats.lost += 1
	STATE.status = "Lost the pack on the way home"
	noteActivity("Lost a pack (the guard got you)")
	return false
end

-- Placing, opening, equipping ------------------------------------------------------
local function freeSpot(area)
	if not PlacementUtil or type(PlacementUtil.RandomPointInArea) ~= "function" then
		return nil
	end
	for _ = 1, 40 do
		local ok, point = pcall(PlacementUtil.RandomPointInArea, area)
		if ok and typeof(point) == "Vector3" then
			local okOverlap, overlaps = pcall(PlacementUtil.OverlapsPlacedPack, LocalPlayer, point)
			if okOverlap and not overlaps then
				return point
			end
		end
	end
	return nil
end

local placeBlockedUntil = 0
local function stepPlace()
	if STATE.autoPlace ~= true or os.clock() < placeBlockedUntil then
		return false
	end
	local pack = nil
	for _, entry in ipairs(backpack()) do
		if type(entry) == "table" and entry.Id and entry.Kind ~= "Character" then
			pack = entry
			break
		end
	end
	if not pack then
		return false
	end
	local plot = myPlot()
	local area = plot and plot:FindFirstChild("PlotModel") and plot.PlotModel:FindFirstChild("AnimeArea")
	if not area then
		return false
	end
	local spot = freeSpot(area)
	if not spot then
		STATE.status = "No room on your plot for more packs"
		placeBlockedUntil = os.clock() + 20
		return false
	end
	STATE.status = "Placing " .. tostring(pack.PackName or "a pack")
	leaveTreadmill()
	walkTo(function()
		return spot
	end, 15, function(root)
		return inOwnPlot() and flat(root.Position, spot) < 10
	end)
	-- The server only places the pack you're holding: equip its tool first.
	local char, _, hum = character()
	local tool = nil
	for _, holder in ipairs({ char, LocalPlayer:FindFirstChild("Backpack") }) do
		for _, item in ipairs(holder and holder:GetChildren() or {}) do
			if item:IsA("Tool") and item:GetAttribute("PackId") == pack.Id then
				tool = item
			end
		end
	end
	if tool and hum and tool.Parent ~= char then
		pcall(hum.UnequipTools, hum)
		pcall(hum.EquipTool, hum, tool)
		fire("Tools", "RequestEquip", { Equipped = true, Tool = tool })
		task.wait(0.4)
	end
	local ok, result = invoke("Packs", "PlaceOwned", { PackId = pack.Id, Position = spot })
	if succeeded(ok, result) then
		stats.placed += 1
		noteActivity("Placed " .. tostring(pack.PackName) .. " (" .. tostring(pack.Rarity) .. ")")
		return true
	end
	STATE.detail = "Place: " .. reasonOf(ok, result)
	placeBlockedUntil = os.clock() + 15
	return false
end

local function stepOpen()
	if STATE.autoOpen ~= true then
		return 0
	end
	local now = os.time()
	local opened = 0
	for _, entry in ipairs(placedList()) do
		if type(entry) == "table" and entry.Id and entry.Kind ~= "Character" and not entry.OpenedAt
			and (tonumber(entry.GrowthEndsAt) or math.huge) <= now then
			local ok, result = invoke("Packs", "OpenOwned", entry.Id)
			if succeeded(ok, result) then
				opened += 1
				stats.opened += 1
				noteActivity("Opened " .. tostring(entry.PackName) .. " (" .. tostring(entry.Rarity) .. ")")
				task.wait(0.5)
			end
		end
	end
	return opened
end

local equipAt = 0
local function stepEquipBest()
	if STATE.autoEquipBest ~= true or os.clock() - equipAt < 30 then
		return
	end
	equipAt = os.clock()
	invoke("Packs", "EquipBest")
end

-- Speed: training and upgrades ------------------------------------------------------
local function treadmillLevel()
	return tonumber(string.match(tostring(playerData().TreadmillLevel or ""), "%d+")) or 1
end
local function treadmillPrice()
	local upgrade = TreadmillConfig and TreadmillConfig.Upgrade
	local prices = type(upgrade) == "table" and upgrade.Prices
	if type(prices) ~= "table" then
		return nil
	end
	local level = treadmillLevel()
	if level >= (tonumber(upgrade.MaximumLevel) or 18) then
		return nil
	end
	return tonumber(prices[level + 1] or prices[tostring(level + 1)])
end
STATE.treadmillPrice = treadmillPrice

local function startTraining()
	if training() then
		return true
	end
	-- Training starts when you step onto your own treadmill's box.
	local plot = myPlot()
	local treadmill = plot and plot:FindFirstChild("Treadmil")
	local box = treadmill and treadmill:FindFirstChild("TreadmilBox", true)
	if not box or not box:IsA("BasePart") then
		return false
	end
	walkTo(function()
		return box.Position
	end, 15, function()
		return training()
	end)
	return training()
end

local upgradeAt = { treadmill = 0, base = 0, luck = 0 }
local function stepUpgrades()
	-- The treadmill upgrade only works within 24 studs of it, i.e. while training.
	if STATE.autoTreadmillUpgrade == true and training() and os.clock() - upgradeAt.treadmill > 5 then
		local price = treadmillPrice()
		if price and cash() >= price then
			upgradeAt.treadmill = os.clock()
			local ok, result = invoke("Treadmill", "Upgrade", {})
			if succeeded(ok, result) or (ok and result ~= false and result ~= nil) then
				stats.upgrades += 1
				notify("Treadmill upgraded", "Level " .. tostring(treadmillLevel()))
			end
		end
	end
	if STATE.autoBaseUpgrade == true and os.clock() - upgradeAt.base > 20 then
		upgradeAt.base = os.clock()
		local before = tonumber(playerData().BaseUpgradeLevel) or 0
		invoke("BaseUpgrade", "Purchase", {})
		task.wait(0.3)
		if (tonumber(playerData().BaseUpgradeLevel) or 0) > before then
			stats.upgrades += 1
			notify("Base upgraded", "Level " .. tostring(playerData().BaseUpgradeLevel))
		end
	end
	if STATE.autoLuckUpgrade == true and os.clock() - upgradeAt.luck > 10 then
		upgradeAt.luck = os.clock()
		local before = tonumber(playerData().HatchLuckLevel) or 0
		local price = LuckMachineConfig and LuckMachineConfig.Price
		local estimate = type(price) == "table" and (tonumber(price.Base) or 500) * (tonumber(price.Growth) or 1.015) ^ before or 500
		if cash() >= estimate then
			invoke("LuckMachine", "Upgrade", 1)
			task.wait(0.3)
			if (tonumber(playerData().HatchLuckLevel) or 0) > before then
				stats.upgrades += 1
				noteActivity("Hatch Luck " .. tostring(playerData().HatchLuckLevel))
			end
		end
	end
end

local rebirthAt = 0
local function stepRebirth()
	if STATE.autoRebirth ~= true or os.clock() - rebirthAt < 30 then
		return
	end
	rebirthAt = os.clock()
	local before = tonumber(playerData().Rebirths) or 0
	invoke("Rebirth", "Request")
	task.wait(1)
	if (tonumber(playerData().Rebirths) or 0) > before then
		stats.rebirths += 1
		notify("Rebirthed", "Rebirth " .. tostring(playerData().Rebirths))
	end
end

-- Free rewards ------------------------------------------------------------------------
local claimAt = 0
local function stepClaims(force)
	if not force and (STATE.autoClaim ~= true or os.clock() - claimAt < 60) then
		return 0
	end
	claimAt = os.clock()
	local count = 0
	for _, call in ipairs({
		{ "Daily", "Claim" },
		{ "FreeGift", "Claim" },
		{ "Offline", "Claim" },
		{ "Index", "ClaimReward" },
	}) do
		local ok, result = invoke(call[1], call[2])
		if succeeded(ok, result) then
			count += 1
		end
		task.wait(0.3)
	end
	stats.claimed += count
	if count > 0 then
		noteActivity("Claimed " .. count .. " reward" .. (count == 1 and "" or "s"))
	end
	return count
end
function STATE.claimNow()
	return stepClaims(true)
end

-- Main loop: one job at a time so walking never fights itself.
local lastSteal = 0
local function stepMain()
	stepOpen()
	if stepPlace() then
		return
	end
	stepEquipBest()
	stepUpgrades()
	stepRebirth()
	local trainFor = tonumber(STATE.trainSeconds) or 60
	local stealDue = STATE.autoSteal == true and (STATE.autoTrain ~= true or os.clock() - lastSteal >= trainFor or tutorialStage() ~= nil)
	if stealDue then
		lastSteal = os.clock()
		stepSteal()
		return
	end
	if STATE.autoTrain == true then
		if not training() then
			STATE.status = "Training on the treadmill"
			if startTraining() then
				stats.trained += 1
			end
		else
			local left = math.max(0, math.ceil(trainFor - (os.clock() - lastSteal)))
			STATE.status = STATE.autoSteal == true and ("Training · next steal in " .. left .. "s") or "Training on the treadmill"
		end
	elseif STATE.autoSteal ~= true then
		STATE.status = "Idle"
	end
end

-- Player helpers.
local pulseAntiAfk = function()
	if not running() or STATE.antiAfk ~= true then
		return false
	end
	local ok = pcall(function()
		local virtual = game:GetService("VirtualUser") :: any
		virtual:CaptureController()
		virtual:ClickButton2(Vector2.new(-1, -1))
	end)
	STATE.antiAfkOperational = ok
	return ok
end
trackConnection(LocalPlayer.Idled:Connect(function()
	pulseAntiAfk()
end))

local pauseGuisBefore = setmetatable({}, { __mode = "k" })
local function restorePausePopup()
	elevate()
	for gui, enabled in pairs(pauseGuisBefore) do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	table.clear(pauseGuisBefore)
end
hubCleanup(restorePausePopup)
local function hidePausePopup()
	if STATE.noPausePopup ~= true then
		restorePausePopup()
		return
	end
	elevate()
	local pause = CoreGui:FindFirstChild("RobloxNetworkPauseNotification")
	if pause and pause:IsA("ScreenGui") then
		if pauseGuisBefore[pause] == nil then
			pauseGuisBefore[pause] = pause.Enabled
		end
		pause.Enabled = false
	end
end

local reconnectPending = false
pcall(function()
	trackConnection(GuiService.ErrorMessageChanged:Connect(function(message)
		if STATE.autoReconnect == true and reconnectPending ~= true and type(message) == "string" and message ~= "" then
			reconnectPending = true
			task.delay(2, function()
				if not running() or STATE.autoReconnect ~= true then
					reconnectPending = false
					return
				end
				local ok = pcall(function()
					TeleportService:Teleport(game.PlaceId, LocalPlayer)
				end)
				task.delay(ok and 15 or 0, function()
					reconnectPending = false
				end)
			end)
		end
	end))
end)

function STATE.apply3d()
	pcall(function()
		RunService:Set3dRenderingEnabled(STATE.disable3d ~= true)
	end)
end
hubCleanup(function()
	pcall(function()
		RunService:Set3dRenderingEnabled(true)
	end)
end)

-- Potato Mode turns off effects only; the world and the hub stay visible.
local POTATO_CLASSES = {
	ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true,
	PointLight = true, SpotLight = true, SurfaceLight = true,
	BloomEffect = true, BlurEffect = true, SunRaysEffect = true, DepthOfFieldEffect = true,
}
local potato = nil
local function potatoOff(profile, instance)
	if potato ~= profile or not POTATO_CLASSES[instance.ClassName] then
		return
	end
	local ok, enabled = pcall(function()
		return instance.Enabled
	end)
	if ok and enabled then
		profile.items[instance] = true
		pcall(function()
			instance.Enabled = false
		end)
	end
end
function STATE.applyFpsBoost()
	if STATE.fpsBoost == true and running() then
		if potato then
			return
		end
		local profile = { items = setmetatable({}, { __mode = "k" }), connections = {} }
		potato = profile
		pcall(function()
			profile.quality = settings().Rendering.QualityLevel
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
		pcall(function()
			profile.shadows = Lighting.GlobalShadows
			Lighting.GlobalShadows = false
		end)
		table.insert(profile.connections, Workspace.DescendantAdded:Connect(function(instance)
			if POTATO_CLASSES[instance.ClassName] then
				task.defer(potatoOff, profile, instance)
			end
		end))
		task.spawn(function()
			local stack = { Workspace, Lighting }
			local scanned = 0
			while #stack > 0 and potato == profile do
				local current = table.remove(stack)
				local ok, children = pcall(current.GetChildren, current)
				if ok then
					for _, child in ipairs(children) do
						stack[#stack + 1] = child
						potatoOff(profile, child)
					end
				end
				scanned += 1
				if scanned % 80 == 0 then
					RunService.Heartbeat:Wait()
				end
			end
		end)
	elseif potato then
		local profile = potato
		potato = nil
		for _, connection in ipairs(profile.connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		for instance in pairs(profile.items) do
			pcall(function()
				instance.Enabled = true
			end)
		end
		pcall(function()
			if profile.quality then
				settings().Rendering.QualityLevel = profile.quality
			end
			if profile.shadows ~= nil then
				Lighting.GlobalShadows = profile.shadows
			end
		end)
	end
end
hubCleanup(function()
	STATE.fpsBoost = false
	STATE.applyFpsBoost()
end)

function STATE.rejoin()
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
end

local function publicServers()
	local ok, body = pcall(function()
		return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100")
	end)
	local decoded = ok and select(2, pcall(HttpService.JSONDecode, HttpService, body))
	local list = {}
	for _, server in ipairs(type(decoded) == "table" and decoded.data or {}) do
		if server.id ~= game.JobId and (tonumber(server.playing) or 0) < (tonumber(server.maxPlayers) or 0) then
			list[#list + 1] = server
		end
	end
	return list
end

function STATE.hop(lowest)
	local list = publicServers()
	if #list == 0 then
		return false
	end
	local pick = list[math.random(1, #list)]
	if lowest then
		table.sort(list, function(a, b)
			return (tonumber(a.playing) or 0) < (tonumber(b.playing) or 0)
		end)
		pick = list[1]
	end
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, LocalPlayer)
	end)
	return true
end

-- The dashboard is the same WindUI window the other Zinoos games use.
local WINDUI_URL = "https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua"

local function loadWindUI()
	local caches = type(genv.ZinoosWindUISources) == "table" and genv.ZinoosWindUISources or {}
	genv.ZinoosWindUISources = caches
	local source = caches[WINDUI_URL]
	if type(source) ~= "string" or #source < 1000 then
		local ok, body = pcall(function()
			return game:HttpGet(WINDUI_URL)
		end)
		elevate()
		if not ok or type(body) ~= "string" or #body < 1000 then
			return nil, "download failed"
		end
		source = body
		caches[WINDUI_URL] = source
	end
	local chunk, compileError = loadstring(source, "=WindUI")
	if not chunk then
		caches[WINDUI_URL] = nil
		return nil, compileError
	end
	local ok, library = pcall(chunk)
	elevate()
	if not ok or type(library) ~= "table" then
		caches[WINDUI_URL] = nil
		return nil, tostring(library)
	end
	return library
end

local ZINOOS_THEME = {
	Name = "Zinoos",
	Accent = Color3.fromHex("#1c1733"),
	Dialog = Color3.fromHex("#15111f"),
	Outline = Color3.fromHex("#FFFFFF"),
	Text = Color3.fromHex("#F5F7FB"),
	Placeholder = Color3.fromHex("#9BA8BA"),
	Background = Color3.fromHex("#0d0b14"),
	Button = Color3.fromHex("#5b4bb5"),
	Icon = Color3.fromHex("#b4a7ff"),
	Toggle = Color3.fromHex("#8268FF"),
	Slider = Color3.fromHex("#8268FF"),
	Checkbox = Color3.fromHex("#8268FF"),
	PanelBackground = Color3.fromHex("#FFFFFF"),
	PanelBackgroundTransparency = 0.96,
	SliderIcon = Color3.fromHex("#908F95"),
	Primary = Color3.fromHex("#8268FF"),
	LabelBackground = Color3.fromHex("#000000"),
	LabelBackgroundTransparency = 0.83,
	ElementBackground = Color3.fromHex("#1a1628"),
	ElementBackgroundTransparency = 0,
}

local function installHub()
	elevate()

	local WindUI, loadError = loadWindUI()
	if not WindUI then
		warn("[Zinoos hub] Menu could not load (" .. tostring(loadError) .. "). Automation is still running with your saved settings.")
		return
	end
	pcall(WindUI.AddTheme, WindUI, ZINOOS_THEME)
	pcall(WindUI.SetNotificationLower, WindUI, true)
	elevate()

	local camera = Workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local small = touch or view.X < 900 or view.Y < 560
	local themeName = type(STATE.windTheme) == "string" and STATE.windTheme ~= "" and STATE.windTheme or "Zinoos"
	if type(WindUI.Themes) == "table" and WindUI.Themes[themeName] == nil then
		themeName = "Zinoos"
	end

	local Window = WindUI:CreateWindow({
		Title = "Zinoos Hub",
		Icon = "sparkles",
		Author = "Steal an Anime Pack",
		Folder = "ZinoosHub",
		Size = small and UDim2.fromOffset(520, 330) or UDim2.fromOffset(720, 520),
		MinSize = small and Vector2.new(420, 260) or Vector2.new(560, 360),
		MaxSize = Vector2.new(900, 620),
		Theme = themeName,
		Resizable = true,
		SideBarWidth = small and 150 or 190,
		HideSearchBar = false,
		ScrollBarEnabled = not small,
		AutoScale = true,
		ToggleKey = Enum.KeyCode[STATE.toggleKey] or Enum.KeyCode.RightControl,
		User = { Enabled = true, Anonymous = false },
		OpenButton = {
			Title = "Zinoos Hub",
			Icon = "sparkles",
			CornerRadius = UDim.new(1, 0),
			StrokeThickness = 2,
			Color = ColorSequence.new(Color3.fromHex("8268FF"), Color3.fromHex("C084FC")),
			OnlyMobile = false,
			Enabled = true,
			Draggable = true,
		},
	})
	elevate()
	if not Window then
		warn("[Zinoos hub] Menu window could not be created.")
		return
	end

	local okFit, fitScale = pcall(Window.GetUIScale, Window)
	fitScale = okFit and tonumber(fitScale) or 1
	local SIZE_FACTORS = { Compact = 0.94, Normal = 1, Large = 1.08 }
	do
		local scale = fitScale * (SIZE_FACTORS[STATE.hubSize] or 1)
		if small then
			scale = math.min(scale, fitScale)
		end
		if math.abs(scale - fitScale) > 0.001 then
			pcall(Window.SetUIScale, Window, scale)
		end
		elevate()
	end
	pcall(Window.Tag, Window, { Title = "v" .. tostring(STATE.version or "1.0.0"), Color = Color3.fromHex("#8268FF") })
	if STATE.admin then
		pcall(Window.Tag, Window, { Title = "Admin", Color = Color3.fromHex("#F6BE3A") })
	end

	local windowGone = false
	hubCleanup(function()
		if not windowGone then
			windowGone = true
			elevate()
			pcall(Window.Destroy, Window)
		end
		for _, name in ipairs({ "ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui" }) do
			local layer = WindUI[name]
			if typeof(layer) == "Instance" then
				pcall(layer.Destroy, layer)
			end
		end
		STATE.toast = nil
	end)

	local function rebuildMenu()
		if windowGone then
			return
		end
		windowGone = true
		elevate()
		pcall(Window.Destroy, Window)
		task.delay(0.35, function()
			if running() then
				elevate()
				local ok, err = pcall(installHub)
				if not ok then
					warn("[Zinoos hub] Menu rebuild failed: " .. tostring(err))
				end
			end
		end)
	end
	pcall(Window.OnDestroy, Window, function()
		if not windowGone then
			windowGone = true
			if running() then
				task.defer(unloadHub)
			end
		end
	end)

	STATE.toast = function(entry)
		task.spawn(function()
			elevate()
			pcall(WindUI.Notify, WindUI, {
				Title = tostring(entry.title),
				Content = tostring(entry.message),
				Icon = "bell",
				Duration = 4.5,
			})
		end)
		return true
	end

	local function onToggle(key, on)
		STATE[key] = on
		if key == "antiAfk" and on then
			task.defer(pulseAntiAfk)
		elseif key == "disable3d" then
			STATE.apply3d()
		elseif key == "fpsBoost" then
			STATE.applyFpsBoost()
		elseif key == "noPausePopup" then
			hidePausePopup()
		elseif key == "autoClaim" and on then
			task.spawn(STATE.claimNow)
		elseif key == "autoTrain" and not on and training() then
			task.spawn(leaveTreadmill)
		end
		elevate()
		saveConfig()
	end

	local function toggle(parent, title, key, desc)
		if type(parent) ~= "table" or type(parent.Toggle) ~= "function" then
			return nil
		end
		elevate()
		local ok, element = pcall(function()
			return parent:Toggle({
				Title = title,
				Desc = desc,
				Value = STATE[key] == true,
				Callback = function(value)
					value = value == true
					if (STATE[key] == true) == value then
						return
					end
					elevate()
					onToggle(key, value)
				end,
			})
		end)
		if not ok or type(element) ~= "table" then
			warn("[Zinoos hub] " .. title .. " failed: " .. tostring(element))
			return nil
		end
		STATE.toggleControls[key] = element
		return element
	end

	local function syncToggle(key)
		local element = STATE.toggleControls[key]
		if type(element) == "table" and element.Value ~= (STATE[key] == true) then
			elevate()
			pcall(element.Set, element, STATE[key] == true, false)
		end
	end

	local function choice(parent, title, desc, options, getValue, setValue)
		if type(parent) ~= "table" or type(parent.Dropdown) ~= "function" then
			return nil
		end
		elevate()
		local ok, element = pcall(function()
			return parent:Dropdown({
				Title = title,
				Desc = desc,
				Values = options,
				Value = getValue(),
				Callback = function(value)
					if type(value) == "table" then
						value = value.Title or value.Name
					end
					if type(value) ~= "string" or value == getValue() then
						return
					end
					elevate()
					setValue(value)
					saveConfig()
				end,
			})
		end)
		if not ok or type(element) ~= "table" then
			warn("[Zinoos hub] " .. title .. " failed: " .. tostring(element))
			return nil
		end
		return element
	end

	local sections = {}
	local paragraphSection = {}
	local pendingReflow = {}
	local function isShown(box)
		local frame = typeof(box.ElementFrame) == "Instance" and box.ElementFrame or nil
		if not frame or not frame.Parent then
			return false
		end
		local node = frame
		while node and not node:IsA("ScreenGui") do
			if node:IsA("GuiObject") and not node.Visible then
				return false
			end
			node = node.Parent
		end
		return node ~= nil and node.Enabled
	end
	local function reflow(box)
		elevate()
		if not box or windowGone or box.Opened ~= true or not isShown(box) then
			return
		end
		pcall(box.Open, box, true)
	end
	local function reflowShown()
		for _, box in ipairs(sections) do
			reflow(box)
		end
	end
	local function queueReflow(box)
		if not box or pendingReflow[box] then
			return
		end
		pendingReflow[box] = true
		task.delay(0.1, function()
			pendingReflow[box] = nil
			reflow(box)
		end)
	end

	local liveText = {}
	local function info(parent, title, text)
		if type(parent) ~= "table" or type(parent.Paragraph) ~= "function" then
			return nil
		end
		elevate()
		local ok, paragraph = pcall(function()
			return parent:Paragraph({ Title = title, Desc = text })
		end)
		if not ok or type(paragraph) ~= "table" then
			warn("[Zinoos hub] " .. title .. " failed: " .. tostring(paragraph))
			return nil
		end
		liveText[paragraph] = text
		if parent.__type == "Section" then
			paragraphSection[paragraph] = parent
		end
		return paragraph
	end
	local function setInfo(paragraph, text)
		if paragraph and liveText[paragraph] ~= text then
			liveText[paragraph] = text
			elevate()
			pcall(paragraph.SetDesc, paragraph, text)
			queueReflow(paragraphSection[paragraph])
		end
	end

	local function button(parent, title, desc, icon, callback)
		if type(parent) ~= "table" or type(parent.Button) ~= "function" then
			return nil
		end
		elevate()
		local ok, element = pcall(function()
			return parent:Button({
				Title = title,
				Desc = desc,
				Icon = icon,
				Callback = function()
					elevate()
					local ran, err = pcall(callback)
					if not ran then
						notify(title .. " failed", tostring(err))
					end
				end,
			})
		end)
		if not ok or type(element) ~= "table" then
			warn("[Zinoos hub] " .. title .. " failed: " .. tostring(element))
			return nil
		end
		return element
	end

	local function section(tab, title, icon)
		if type(tab) ~= "table" or type(tab.Section) ~= "function" then
			return nil
		end
		elevate()
		local ok, box = pcall(function()
			return tab:Section({ Title = title, Icon = icon, Box = true, Opened = true })
		end)
		if not ok or type(box) ~= "table" then
			warn("[Zinoos hub] " .. title .. " failed: " .. tostring(box))
			return nil
		end
		table.insert(sections, box)
		return box
	end

	local function confirm(title, content, onYes)
		local ok = pcall(Window.Dialog, Window, {
			Title = title,
			Content = content,
			Buttons = {
				{ Title = "Cancel", Variant = "Secondary", Callback = function() end },
				{ Title = "Confirm", Variant = "Primary", Callback = function()
					elevate()
					onYes()
				end },
			},
		})
		if not ok then
			onYes()
		end
	end

	local homeTab = Window:Tab({ Title = "Home", Icon = "house" })
	local farmTab = Window:Tab({ Title = "Stealing", Icon = "package" })
	local speedTab = Window:Tab({ Title = "Speed", Icon = "zap" })
	local rewardTab = Window:Tab({ Title = "Rewards", Icon = "gift" })
	local playerTab = Window:Tab({ Title = "Player", Icon = "user" })
	local settingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
	elevate()

	local overview = info(homeTab, "Overview", "Loading your stats...")
	button(homeTab, "Start / Stop Stealing", "Turns Auto Steal on or off", "power", function()
		local on = STATE.autoSteal ~= true
		onToggle("autoSteal", on)
		syncToggle("autoSteal")
		notify(on and "Stealing started" or "Stealing stopped", "")
	end)
	button(homeTab, "Claim Now", "Daily reward, free gift, offline cash and Index rewards", "gift", function()
		task.spawn(function()
			local count = STATE.claimNow()
			notify(count > 0 and ("Claimed " .. count) or "Nothing ready", "")
		end)
	end)
	local activityInfo = info(homeTab, "Activity", "Waiting for the next thing the hub does.")

	local stealInfo
	do
		local stealBox = section(farmTab, "Auto Steal", "package")
		toggle(stealBox, "Auto Steal", "autoSteal", "Walks to the best pack, steals it and runs it back to your plot. Walked, never teleported")
		choice(stealBox, "Stage", "Best for my speed = the furthest stage whose recommended speed you have. The tutorial stage always goes first", STAGE_OPTIONS, function()
			return STATE.stage
		end, function(option)
			STATE.stage = option
		end)
		stealInfo = info(stealBox, "Status", "Starting")

		local plotBox = section(farmTab, "Your Plot", "home")
		toggle(plotBox, "Auto Place", "autoPlace", "Places stolen packs on your plot so they grow")
		toggle(plotBox, "Auto Open", "autoOpen", "Opens packs as soon as they finish growing")
		toggle(plotBox, "Auto Equip Best", "autoEquipBest", "Keeps your best characters on the plot earning cash")
	end

	local speedInfo
	do
		local trainBox = section(speedTab, "Training", "activity")
		toggle(trainBox, "Auto Train", "autoTrain", "Trains on your treadmill between steals. Speed lets you steal from better stages")
		choice(trainBox, "Train Between Steals (seconds)", "How long it trains before the next steal when Auto Steal is on too", TRAIN_OPTIONS, function()
			return STATE.trainSeconds
		end, function(option)
			STATE.trainSeconds = option
		end)
		speedInfo = info(trainBox, "Speed", "Loading")

		local upgradeBox = section(speedTab, "Upgrades", "trending-up")
		toggle(upgradeBox, "Auto Treadmill Upgrade", "autoTreadmillUpgrade", "Upgrades your treadmill (more speed per second) while it trains")
		toggle(upgradeBox, "Auto Base Upgrade", "autoBaseUpgrade", "Upgrades your base when you can afford it")
		toggle(upgradeBox, "Auto Hatch Luck", "autoLuckUpgrade", "Buys Hatch Luck levels in the Luck Machine")
		toggle(upgradeBox, "Auto Rebirth", "autoRebirth", "Rebirths when you have the speed for it. Rebirth resets your cash for a cash and luck boost")
	end

	do
		local claimBox = section(rewardTab, "Free Rewards", "gift")
		toggle(claimBox, "Auto Claim", "autoClaim", "Daily reward, free gift, offline cash and Index rewards")
	end

	do
		local clientBox = section(playerTab, "Performance & AFK", "cpu")
		toggle(clientBox, "Anti AFK", "antiAfk")
		toggle(clientBox, "Auto Reconnect on Kick", "autoReconnect")
		toggle(clientBox, "Hide Roblox Pause Popup", "noPausePopup")
		toggle(clientBox, "Potato Mode", "fpsBoost", "Turns off particles, trails, lights and shadows")
		toggle(clientBox, "AFK Black Screen", "disable3d", "Stops drawing the world")

		local serverBox = section(playerTab, "Server", "server")
		info(serverBox, "This Server", "Job " .. string.sub(game.JobId, 1, 8) .. "... · Place " .. tostring(game.PlaceId))
		button(serverBox, "Rejoin", nil, "rotate-ccw", function()
			STATE.rejoin()
		end)
		button(serverBox, "Server Hop", nil, "shuffle", function()
			if not STATE.hop(false) then
				notify("No other server found", "Try again in a moment")
			end
		end)
		button(serverBox, "Lowest Player Server", nil, "users", function()
			if not STATE.hop(true) then
				notify("No other server found", "Try again in a moment")
			end
		end)
		button(serverBox, "Copy Job ID", nil, "copy", function()
			if typeof(setclipboard) == "function" and pcall(setclipboard, game.JobId) then
				notify("Job ID copied", game.JobId)
			else
				notify("Copy is not available", game.JobId)
			end
		end)
	end

	do
		local lookBox = section(settingsTab, "Look", "palette")
		local themes = { "Zinoos" }
		local okThemes, list = pcall(WindUI.GetThemes, WindUI)
		if okThemes and type(list) == "table" then
			for key, value in pairs(list) do
				local name = type(key) == "string" and key or value
				if type(name) == "string" and name ~= "Zinoos" and not table.find(themes, name) then
					table.insert(themes, name)
				end
			end
			table.sort(themes, function(a, b)
				if a == "Zinoos" then
					return true
				end
				if b == "Zinoos" then
					return false
				end
				return a < b
			end)
		end
		choice(lookBox, "Theme", nil, themes, function()
			return themeName
		end, function(option)
			themeName = option
			STATE.windTheme = option
			pcall(WindUI.SetTheme, WindUI, option)
		end)
		choice(lookBox, "Menu Size", nil, { "Compact", "Normal", "Large" }, function()
			return STATE.hubSize or "Compact"
		end, function(option)
			STATE.hubSize = option
			saveConfig()
			rebuildMenu()
		end)
		choice(lookBox, "Open / Close Key (PC)", nil, KEY_OPTIONS, function()
			return STATE.toggleKey
		end, function(option)
			STATE.toggleKey = option
			pcall(Window.SetToggleKey, Window, Enum.KeyCode[option])
		end)
		toggle(lookBox, "Start Hidden", "hideOnStart", "Opens with the key or the Zinoos button")
		toggle(lookBox, "Hub Notifications", "notifications")

		local configBox = section(settingsTab, "Config", "save")
		info(configBox, "Saving", "Changes save automatically for this Roblox account.")
		button(configBox, "Save Now", nil, "save", function()
			saveConfig()
			notify("Saved", "Settings saved for " .. LocalPlayer.DisplayName)
		end)

		local communityBox = section(settingsTab, "Community", "message-circle")
		button(communityBox, "Copy Discord Invite", "discord.gg/94pC3T6NZG", "copy", function()
			local invite = "https://discord.gg/94pC3T6NZG"
			if typeof(setclipboard) == "function" and pcall(setclipboard, invite) then
				notify("Invite copied", "Paste it in your browser")
			else
				notify("Discord invite", invite)
			end
		end)
		button(communityBox, "Unload Hub", "Stops everything and removes the menu", "log-out", function()
			confirm("Unload Zinoos Hub?", "All automation stops until you run the loader again.", function()
				task.defer(unloadHub)
			end)
		end)
	end

	pcall(Window.SelectTab, Window, 1)
	for _, delay in ipairs({ 0.2, 0.6, 1.5 }) do
		task.delay(delay, reflowShown)
	end
	local tabModule = Window.TabModule
	if type(tabModule) == "table" and type(tabModule.OnChange) == "function" then
		local previous = tabModule.OnChangeFunc
		pcall(tabModule.OnChange, tabModule, function(...)
			if type(previous) == "function" then
				pcall(previous, ...)
			end
			task.delay(0.15, reflowShown)
			task.delay(0.5, reflowShown)
		end)
	end


	local sessionStarted = os.time()
	local function refresh()
		local elapsed = math.max(0, os.time() - sessionStarted)
		local clock = elapsed >= 3600
			and string.format("%d:%02d:%02d", elapsed // 3600, elapsed % 3600 // 60, elapsed % 60)
			or string.format("%d:%02d", elapsed // 60, elapsed % 60)
		elevate()
		local data = playerData()
		local equipped = 0
		for _, entry in ipairs(placedList()) do
			if type(entry) == "table" and entry.Kind == "Character" then
				equipped += 1
			end
		end
		setInfo(overview, string.format(
			"%s\n$%s  ·  %s speed  ·  Level %s  ·  Rebirths %s\n%d on your plot  ·  %d in backpack\nSession %s",
			tostring(STATE.status or "Waiting"),
			shortNumber(cash()),
			shortNumber(speedStat()),
			tostring(data.Level or 0),
			tostring(data.Rebirths or 0),
			#placedList(),
			#backpack(),
			clock
		))
		local lines = {
			string.format("Stolen %d  ·  Lost %d  ·  Placed %d  ·  Opened %d", stats.steals, stats.lost, stats.placed, stats.opened),
			string.format("Upgrades %d  ·  Rebirths %d  ·  Claimed %d", stats.upgrades, stats.rebirths, stats.claimed),
		}
		if data.TutorialComplete ~= true and tonumber(data.TutorialStep) then
			lines[#lines + 1] = "Tutorial step " .. tostring(data.TutorialStep) .. " (the hub follows it)"
		end
		if STATE.antiAfk == true then
			lines[#lines + 1] = STATE.antiAfkOperational == true and "Anti AFK active" or "Anti AFK waiting for idle"
		end
		for _, item in ipairs(STATE.activity) do
			lines[#lines + 1] = tostring(item)
		end
		setInfo(activityInfo, table.concat(lines, "\n"))
		local stageKey, tutorial = targetStage()
		local stage = stageInfo(stageKey)
		setInfo(stealInfo, tostring(STATE.status or "Waiting")
			.. (STATE.detail ~= "" and ("\n" .. tostring(STATE.detail)) or "")
			.. "\nTarget: " .. stageKey .. (stage and stage.Text and (" · " .. tostring(stage.Text)) or "") .. (tutorial and " (tutorial)" or ""))
		local nextStage = nil
		for index = 1, 14 do
			local info = stageInfo("Stage" .. index)
			local needed = info and tonumber(info.RecommendedSpeed)
			if needed and speedStat() < needed then
				nextStage = string.format("Stage %d needs %s speed", index, shortNumber(needed))
				break
			end
		end
		local price = treadmillPrice()
		setInfo(speedInfo, string.format("%s speed  ·  Best stage: %s\n%s\nTreadmill level %d%s",
			shortNumber(speedStat()),
			bestStage(),
			nextStage or "Every stage unlocked",
			treadmillLevel(),
			price and (" · next $" .. shortNumber(price)) or " · max"
		))
	end

	task.spawn(function()
		while running() and not windowGone do
			pcall(refresh)
			task.wait(1)
		end
	end)

	if STATE.hideOnStart == true then
		-- WindUI opens itself again just after it is made (with an animation),
		-- so an immediate Close left the menu open. Close it once it settles,
		-- and only while it is showing, so a close can never flip it open.
		for _, delay in ipairs({ 0.8, 1.6, 3 }) do
			task.delay(delay, function()
				if windowGone or not running() then
					return
				end
				elevate()
				local frame = Window.UIElements and Window.UIElements.Main
				if typeof(frame) == "Instance" and frame.Parent and frame:IsA("GuiObject") and frame.Visible then
					pcall(Window.Close, Window)
				end
			end)
		end
	end
end

loadSaved()
STATE.version = "1.0.0"

if running() then
	elevate()
	local ok, err = xpcall(installHub, debug.traceback)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
	end
end

-- Stealing, placing, training and upgrades: one job at a time.
task.spawn(function()
	elevate()
	task.wait(1)
	while running() do
		local ok, err = pcall(stepMain)
		if not ok then
			STATE.detail = tostring(err)
			warn("[Zinoos hub] " .. tostring(err))
			task.wait(2)
		else
			task.wait(0.3)
		end
	end
end)

-- Free rewards.
task.spawn(function()
	elevate()
	task.wait(5)
	while running() do
		pcall(stepClaims)
		elevate()
		task.wait(5)
	end
end)

task.spawn(function()
	elevate()
	while running() do
		pcall(hidePausePopup)
		task.wait(0.5)
	end
end)

pcall(STATE.apply3d)
pcall(STATE.applyFpsBoost)

task.spawn(function()
	while running() do
		task.wait(4 * 60)
		pulseAntiAfk()
	end
end)
