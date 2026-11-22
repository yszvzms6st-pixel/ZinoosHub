-- ZinoosHub for Throw a Seed.
-- Throws through the game's own remotes (Aim -> Throw -> Collect), trains on
-- the pull-up bar, buys upgrades, places, fuses and sells plants, and claims
-- every free reward. Menu: WindUI (pinned release).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

if game.GameId ~= 10775182046 then
	warn("[Zinoos hub] This only runs in Throw a Seed.")
	return
end

local LocalPlayer = Players.LocalPlayer
local genv = getgenv()
local function elevate()
	if typeof(setthreadidentity) == "function" then
		pcall(setthreadidentity, 8)
	end
end
elevate()

-- One copy at a time: a new run stops the old one first.
if typeof(genv.ZinoosSeedStop) == "function" then
	pcall(genv.ZinoosSeedStop)
	elevate()
end
genv.ZinoosSeedGen = (typeof(genv.ZinoosSeedGen) == "number" and genv.ZinoosSeedGen or 0) + 1
local token = genv.ZinoosSeedGen
local function running()
	return genv.ZinoosSeedGen == token
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Game modules ---------------------------------------------------------------
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local Balance = require(ReplicatedStorage:WaitForChild("Balance", 30))
elevate()
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig", 30))
elevate()
-- The game keeps your plants, seeds and index in its ClientState module.
-- An executor's require() can hand back a fresh, empty copy of that module,
-- so look for the copy the game itself is using first.
local function findGameClientState()
	if typeof(filtergc) ~= "function" then
		return nil
	end
	local ok, list = pcall(filtergc, "table", { Keys = { "MyPlot", "plants", "PenCenter" } }, false)
	elevate()
	if not ok or type(list) ~= "table" then
		return nil
	end
	local best = nil
	for _, candidate in ipairs(list) do
		if type(candidate) == "table" and candidate.ready == true and type(candidate.plants) == "table" then
			if not best or #candidate.plants > #best.plants then
				best = candidate
			end
		end
	end
	return best
end
local ClientState = findGameClientState()
local ownClientState = ClientState == nil
if not ClientState then
	ClientState = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("ClientState", 30))
	elevate()
end
local AimRemote = Remotes:WaitForChild("Aim")
local ThrowRemote = Remotes:WaitForChild("Throw")
local HereRemote = Remotes:WaitForChild("Here")
local CollectRemote = Remotes:WaitForChild("Collect")
local RequestRemote = Remotes:WaitForChild("Request")
local NotifyRemote = Remotes:WaitForChild("Notify")

local RARITIES = table.clone(Balance.Rarities or {
	"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
	"Divine", "Cosmic", "Celestial", "Secret", "Eternal", "Infinity",
})
local SIZE_NAMES = {}
for index, size in ipairs(Balance.Sizes or {}) do
	SIZE_NAMES[index] = size.name
end
local MUTATION_NAMES = {}
for index, mutation in ipairs(Balance.Mutations or {}) do
	MUTATION_NAMES[index] = mutation.name
end

local function rarityName(tier)
	return RARITIES[tonumber(tier) or 1] or ("Tier " .. tostring(tier))
end
local function rarityTier(name)
	return table.find(RARITIES, name) or 1
end

local VERSION = "1.5.1"
local STATE = {
	_gen = token,
	version = VERSION,
	-- Farming
	autoThrow = true,
	throwGap = 6,
	showAnimation = false,
	cycleTrain = true,
	cycleTrainMinutes = 5,
	cycleThrowMinutes = 2,
	showCycleTimer = true,
	autoTrain = false,
	autoXpOffers = true,
	-- Upgrades
	autoSeed = true,
	autoBar = true,
	autoCapacity = true,
	cashReserve = "$0",
	-- Garden
	autoPlace = true,
	autoFuse = false,
	fuseMaxRarity = "Uncommon",
	autoSell = false,
	sellRarities = { "Common" },
	keepMutations = true,
	keepBigSizes = true,
	smartStorage = false,
	keepTradeDupes = true,
	tradeSpares = 3,
	keepMutationMin = "Ruby and up",
	indexHunt = false,
	historyFilter = "All",
	-- Rewards
	autoDaily = true,
	autoGifts = true,
	autoCodes = true,
	autoOffline = true,
	autoPotions = false,
	useLuckyThrows = false,
	-- Live events
	autoAdminAbuse = true,
	autoAbuseDrops = true,
	autoAbuseCrown = true,
	autoPieFight = true,
	autoHarvestMoon = true,
	autoHarvestBasket = true,
	autoHarvestShop = true,
	-- Alerts
	notifications = true,
	notifyMinRarity = "Epic",
	notifyNew = true,
	notifyMutations = true,
	-- Player
	walkSpeed = false,
	speed = 32,
	antiAfk = true,
	autoReload = true,
	disable3d = false,
	-- Menu
	toggleKey = "RightControl",
	hideOnStart = false,
	hubSize = "Normal",
	windTheme = "Zinoos",
	redeemedCodes = {},
	-- Live
	status = "Starting...",
	throwStatus = "Waiting",
	trainStatus = "Off",
	cycleStatus = "Off",
	upgradeStatus = "Waiting",
	gardenStatus = "Waiting",
	rewardStatus = "Waiting",
	abuseStatus = "Watching for admin events",
	harvestStatus = "Checking event",
	toggleControls = {},
}
genv.ZinoosSeedState = STATE
STATE.clientState = ClientState
STATE.ownClientState = ownClientState

STATE.ownerUserId = 9346336323
STATE.admin = LocalPlayer.UserId == STATE.ownerUserId

local stats = {
	throws = 0,
	rejected = 0,
	newPlants = 0,
	perfect = 0,
	bestTier = 0,
	bestText = "None yet",
	rarityCounts = {},
	recent = {},
	started = os.time(),
	cash0 = nil,
	spent = 0,
}
STATE.stats = stats

local runtime = { connections = {}, cleanups = {} }
local function trackConnection(connection)
	table.insert(runtime.connections, connection)
	return connection
end
local function hubCleanup(fn)
	table.insert(runtime.cleanups, fn)
end

local function shutdownHub()
	if genv.ZinoosSeedGen == token then
		genv.ZinoosSeedGen = token + 1
	end
	STATE._unloaded = true
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
genv.ZinoosSeedStop = shutdownHub
local function unloadHub()
	shutdownHub()
end

-- Options --------------------------------------------------------------------
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
local SPEED_OPTIONS = { "16", "24", "32", "50", "75", "100" }
local CASH_RESERVE_OPTIONS = { "$0", "$1K", "$10K", "$100K", "$1M", "$10M", "$100M", "$1B", "$10B", "$100B", "$1T", "$10T", "$100T", "$1Qa" }
local CASH_RESERVE_VALUES = {
	["$0"] = 0, ["$1K"] = 1e3, ["$10K"] = 1e4, ["$100K"] = 1e5, ["$1M"] = 1e6,
	["$10M"] = 1e7, ["$100M"] = 1e8, ["$1B"] = 1e9, ["$10B"] = 1e10, ["$100B"] = 1e11,
	["$1T"] = 1e12, ["$10T"] = 1e13, ["$100T"] = 1e14, ["$1Qa"] = 1e15,
}
local NOTIFY_OPTIONS = table.clone(RARITIES)
table.insert(NOTIFY_OPTIONS, 1, "All")
local FUSE_OPTIONS = { "Common", "Uncommon", "Rare" }
-- Always Keep Mutations: the lowest mutation that is never sold or fused
-- (Balance.Mutations: 2 Gold, 3 Diamond, 4 Emerald, 5 Ruby, 6 Rainbow).
local KEEP_MUTATION_OPTIONS = { "Off", "Rainbow only", "Ruby and up", "Emerald and up", "Diamond and up", "Gold and up" }
local KEEP_MUTATION_MIN = { ["Rainbow only"] = 6, ["Ruby and up"] = 5, ["Emerald and up"] = 4, ["Diamond and up"] = 3, ["Gold and up"] = 2 }

-- Config ---------------------------------------------------------------------
local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/ThrowASeed_" .. tostring(LocalPlayer.UserId) .. ".rfld"
local SAVE_KEYS = {
	"autoThrow", "throwGap", "showAnimation", "cycleTrain", "cycleTrainMinutes", "cycleThrowMinutes", "showCycleTimer", "autoTrain", "autoXpOffers",
	"autoSeed", "autoBar", "autoCapacity", "cashReserve",
	"autoPlace", "autoFuse", "fuseMaxRarity", "autoSell", "sellRarities", "keepMutations", "keepBigSizes", "smartStorage", "keepTradeDupes", "tradeSpares", "keepMutationMin", "indexHunt", "historyFilter",
	"autoDaily", "autoGifts", "autoCodes", "autoOffline", "autoPotions", "useLuckyThrows",
	"autoAdminAbuse", "autoAbuseDrops", "autoAbuseCrown", "autoPieFight", "autoHarvestMoon", "autoHarvestBasket", "autoHarvestShop",
	"notifications", "notifyMinRarity", "notifyNew", "notifyMutations",
	"walkSpeed", "speed", "antiAfk", "autoReload", "disable3d",
	"toggleKey", "hideOnStart", "hubSize", "windTheme", "redeemedCodes",
}

local function loadSaved()
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
		return
	end
	local okExists, exists = pcall(isfile, CONFIG_PATH)
	if not okExists or not exists then
		return
	end
	local ok, saved = pcall(function()
		return HttpService:JSONDecode(readfile(CONFIG_PATH))
	end)
	if not ok or type(saved) ~= "table" then
		return
	end
	for _, key in ipairs(SAVE_KEYS) do
		local value = saved[key]
		if value ~= nil and type(value) == type(STATE[key]) then
			STATE[key] = value
		end
	end
	STATE.throwGap = math.clamp(tonumber(STATE.throwGap) or 6, 5.5, 30)
	STATE.cycleTrainMinutes = math.clamp(math.floor(tonumber(STATE.cycleTrainMinutes) or 5), 1, 60)
	STATE.cycleThrowMinutes = math.clamp(math.floor(tonumber(STATE.cycleThrowMinutes) or 2), 1, 60)
	if CASH_RESERVE_VALUES[STATE.cashReserve] == nil then
		STATE.cashReserve = "$0"
	end
	if not table.find(FUSE_OPTIONS, STATE.fuseMaxRarity) then
		STATE.fuseMaxRarity = "Uncommon"
	end
	if not table.find(NOTIFY_OPTIONS, STATE.notifyMinRarity) then
		STATE.notifyMinRarity = "Epic"
	end
	local cleaned = {}
	for _, name in ipairs(STATE.sellRarities) do
		if table.find(RARITIES, name) then
			table.insert(cleaned, name)
		end
	end
	STATE.sellRarities = cleaned
end

local function saveConfig()
	if typeof(writefile) ~= "function" then
		return
	end
	local data = { ConfigVersion = 1 }
	for _, key in ipairs(SAVE_KEYS) do
		data[key] = STATE[key]
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if ok then
		if typeof(makefolder) == "function" then
			pcall(makefolder, "Rayfield")
			pcall(makefolder, "Rayfield/Configurations")
			pcall(makefolder, "Rayfield/Configurations/ZinoosHub")
		end
		pcall(writefile, CONFIG_PATH, encoded)
	end
end
STATE.saveConfig = saveConfig

-- Helpers ----------------------------------------------------------------------
local function shortNumber(value)
	value = tonumber(value) or 0
	local ok, text = pcall(Balance.Short, value)
	return ok and text or tostring(math.floor(value))
end

local function attr(name)
	return LocalPlayer:GetAttribute(name)
end

local function money()
	return tonumber(attr("Money")) or 0
end

local function spendable()
	return money() - (CASH_RESERVE_VALUES[STATE.cashReserve] or 0)
end

-- The server answers "Slow down" to requests sent too close together, so
-- every request goes through one queue with a gap, and a "Slow down" answer
-- waits and tries again.
local requestGate = { nextAt = 0, gap = 0.9 }
local function slowedDown(message)
	return type(message) == "string" and string.find(string.lower(message), "slow down", 1, true) ~= nil
end
local function request(name, args)
	for attempt = 1, 3 do
		while os.clock() < requestGate.nextAt do
			task.wait(requestGate.nextAt - os.clock())
		end
		requestGate.nextAt = os.clock() + requestGate.gap
		local ok, result, message = pcall(RequestRemote.InvokeServer, RequestRemote, name, args or {})
		elevate()
		if not ok then
			return false, "Connection problem"
		end
		if result or not slowedDown(message) then
			return result, message
		end
		requestGate.nextAt = os.clock() + 2.5 * attempt
	end
	return false, "Slow down"
end

STATE.activity = {}
local function noteActivity(text)
	text = os.date("%H:%M") .. "  " .. tostring(text)
	table.insert(STATE.activity, 1, text)
	while #STATE.activity > 6 do
		table.remove(STATE.activity)
	end
end

local function notify(title, message)
	if STATE.notifications ~= true then
		return
	end
	if type(STATE.toast) == "function" then
		pcall(STATE.toast, title, message)
		return
	end
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = title, Text = message, Duration = 5 })
	end)
end

local function character()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return char, hum, root
	end
	return nil
end

local function myPlot()
	local name = attr("Plot")
	local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	return name and plots and plots:FindFirstChild(name) or nil
end

local function plants()
	return type(ClientState.plants) == "table" and ClientState.plants or {}
end

local function plantIncome(plant)
	local ok, value = pcall(Balance.Income, plant.rarity or 1, plant.size, plant.mutation, 1, plant.plant)
	return ok and tonumber(value) or tonumber(plant.income) or 0
end

local function indexCount()
	local found, total = 0, 0
	for _ in pairs(type(ClientState.index) == "table" and ClientState.index or {}) do
		found += 1
	end
	for _, entry in ipairs(Balance.ByOdds or {}) do
		if not (Balance.Retired and Balance.Retired[entry.name]) then
			total += 1
		end
	end
	return found, total
end

local function describePlant(result)
	local parts = {}
	local size = tonumber(result.size) or 1
	local mutation = tonumber(result.mutation) or 1
	if size > 1 and SIZE_NAMES[size] then
		table.insert(parts, SIZE_NAMES[size])
	end
	if mutation > 1 and MUTATION_NAMES[mutation] then
		table.insert(parts, MUTATION_NAMES[mutation])
	end
	table.insert(parts, tostring(result.plant or "Plant"))
	return table.concat(parts, " ")
end

-- Movement -------------------------------------------------------------------
local function launchStrip()
	local map = workspace:FindFirstChild("Map")
	local canyon = map and map:FindFirstChild("Canyon")
	return canyon and canyon:FindFirstChild("LaunchStrip") or nil
end

-- Just behind the launch strip: close enough for the server to accept a
-- throw, but outside the strip so the game's own throw screen stays closed.
local function throwSpot(onStrip)
	local strip = launchStrip()
	if not strip then
		return nil
	end
	if onStrip then
		-- The game's own spot: 1 stud past the strip's middle. Used to get
		-- unstuck when the server keeps refusing throws from behind the strip.
		return strip.CFrame * CFrame.new(0, strip.Size.Y / 2 + 3, -1)
	end
	local back = -(tonumber(ZoneConfig.Direction) or -1)
	local depth = strip.Size.Z / 2 + 5
	return strip.CFrame * CFrame.new(0, strip.Size.Y / 2 + 3, back * depth)
end

local function trainSpot()
	local plot = myPlot()
	local station = plot and plot:FindFirstChild("BarStation")
	local bar = station and station:FindFirstChild("Bar")
	return bar and bar:FindFirstChild("TrainSpot") or nil
end

local function moveTo(cf, within)
	local char, _, root = character()
	if not char or not cf then
		return false
	end
	if (root.Position - cf.Position).Magnitude <= (within or 4) then
		return true
	end
	if root.Anchored then
		root.Anchored = false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	char:PivotTo(cf)
	return true
end

local function isTraining()
	local char = LocalPlayer.Character
	return char ~= nil and char:GetAttribute("Training") == true
end

local function stopTraining()
	if isTraining() then
		request("StopTrain")
	end
end

-- Admin Abuse events -----------------------------------------------------------
-- v342 added server-backed pickup and contest events. Keep one queue so event
-- requests respect the same throttle as every other Request call.
local function abuseOn(kind)
	return workspace:GetServerTimeNow() < (tonumber(workspace:GetAttribute("Abuse" .. kind .. "Until")) or 0)
end

local abuse = {
	active = {},
	queue = {},
	seen = {},
	full = {},
	collected = 0,
	lastResult = "Watching for admin events",
}
STATE.abuse = abuse

local function dropPosition(operation)
	local drop = operation.drop
	local position = Vector3.new(tonumber(drop[2]) or 0, tonumber(drop[3]) or 0, tonumber(drop[4]) or 0)
	local path = drop[6]
	if operation.kind == "turkeys" and type(path) == "table" and #path > 0 then
		local progress = math.max(workspace:GetServerTimeNow() - (tonumber(drop[5]) or 0), 0) / 2.5
		local index = math.min(math.floor(progress) + 1, #path)
		local from = path[index]
		local to = path[math.min(index + 1, #path)]
		if type(from) == "table" and type(to) == "table" then
			local alpha = math.clamp(progress - (index - 1), 0, 1)
			position = Vector3.new(
				(tonumber(from[1]) or 0) + ((tonumber(to[1]) or 0) - (tonumber(from[1]) or 0)) * alpha,
				position.Y,
				(tonumber(from[2]) or 0) + ((tonumber(to[2]) or 0) - (tonumber(from[2]) or 0)) * alpha
			)
		end
	end
	return position
end

local function queueAbuseDrops(data)
	if STATE.autoAdminAbuse ~= true or STATE.autoAbuseDrops ~= true then
		return
	end
	for _, drop in ipairs(type(data.drops) == "table" and data.drops or {}) do
		if type(drop) == "table" then
			local key = tostring(data.kind) .. ":" .. tostring(data.id) .. ":" .. tostring(drop[1])
			if not abuse.seen[key] then
				abuse.seen[key] = true
				table.insert(abuse.queue, { key = key, kind = data.kind, id = data.id, drop = drop, ends = data.ends })
			end
		end
	end
	table.sort(abuse.queue, function(a, b)
		return (tonumber(a.drop[5]) or 0) < (tonumber(b.drop[5]) or 0)
	end)
end

local function abuseEventName(kind)
	local config = Balance.AdminAbuse
	for _, event in ipairs(config and config.Events or {}) do
		if event.key == kind then
			return event.name or event.short or kind
		end
	end
	return tostring(kind)
end

local function abuseEventListener(message, data)
	if type(data) ~= "table" then
		return
	end
	if message == "AbuseEvent" and type(data.kind) == "string" then
		abuse.active[data.kind] = data
		queueAbuseDrops(data)
		abuse.lastResult = abuseEventName(data.kind) .. " active"
		noteActivity("Admin event: " .. abuseEventName(data.kind))
	elseif message == "AbuseEnd" and type(data.kind) == "string" then
		local current = abuse.active[data.kind]
		if current == nil or current.id == data.id then
			abuse.active[data.kind] = nil
		end
	elseif message == "AbuseTaken" and data.by == LocalPlayer.UserId then
		abuse.collected += 1
		abuse.lastResult = "Collected " .. abuseEventName(data.kind) .. " reward"
	end
end
trackConnection(NotifyRemote.OnClientEvent:Connect(abuseEventListener))

local function runAbuseOperation(operation)
	if STATE.autoAdminAbuse ~= true then
		return
	end
	local now = workspace:GetServerTimeNow()
	if operation.ends and now >= operation.ends then
		return
	end
	local landsAt = tonumber(operation.drop[5]) or now
	while landsAt > workspace:GetServerTimeNow() and running() do
		task.wait(math.min(landsAt - workspace:GetServerTimeNow(), 1))
	end
	if abuse.full[tostring(operation.kind) .. ":" .. tostring(operation.id)] then
		return
	end
	STATE.onTrip = true
	stopTraining()
	local position = dropPosition(operation)
	moveTo(CFrame.new(position + Vector3.new(0, 3, 0)), 5)
	task.wait(0.12)
	local ok, result = request("AbuseGrab", { kind = operation.kind, id = operation.id, drop = operation.drop[1] })
	if ok then
		abuse.lastResult = "Collected " .. abuseEventName(operation.kind) .. " reward"
		noteActivity(abuse.lastResult)
	elseif tostring(result) == "full" then
		abuse.full[tostring(operation.kind) .. ":" .. tostring(operation.id)] = true
		abuse.lastResult = abuseEventName(operation.kind) .. " reward cap reached"
	else
		abuse.lastResult = abuseEventName(operation.kind) .. ": " .. tostring(result or "missed")
	end
	STATE.onTrip = false
end

local function chaseCrown(data)
	if STATE.autoAdminAbuse ~= true or STATE.autoAbuseCrown ~= true or data.holder == LocalPlayer.UserId then
		return false
	end
	local position
	local holder = tonumber(data.holder) and Players:GetPlayerByUserId(tonumber(data.holder))
	local holderRoot = holder and holder.Character and holder.Character:FindFirstChild("HumanoidRootPart")
	if holderRoot then
		position = holderRoot.Position
	elseif type(data.pos) == "table" then
		position = Vector3.new(tonumber(data.pos[1]) or 0, tonumber(data.pos[2]) or 0, tonumber(data.pos[3]) or 0)
	end
	if not position then
		return false
	end
	STATE.onTrip = true
	stopTraining()
	moveTo(CFrame.new(position + Vector3.new(0, 2, 0)), 5)
	local ok, result = request("AbuseGrab", { kind = "crown", id = data.id })
	abuse.lastResult = ok and "Took the event crown" or ("Crown: " .. tostring(result or "chasing"))
	STATE.onTrip = false
	return true
end

local function throwEventPie(data)
	if STATE.autoAdminAbuse ~= true or STATE.autoPieFight ~= true then
		return false
	end
	local target, targetRoot
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			target, targetRoot = player, root
			break
		end
	end
	if not target then
		abuse.lastResult = "Pie Fight: waiting for another player"
		return false
	end
	STATE.onTrip = true
	stopTraining()
	moveTo(CFrame.new(targetRoot.Position + Vector3.new(0, 2, 8)), 70)
	local ok, result = request("AbuseGrab", { kind = "pies", id = data.id, target = target.UserId })
	abuse.lastResult = ok and ("Pie hit x" .. tostring(type(result) == "table" and result.hits or "?"))
		or ("Pie Fight: " .. tostring(result or "missed"))
	STATE.onTrip = false
	return true
end

local function startAbuseAutomation()
	task.defer(function()
		request("AbuseSync")
	end)
	task.spawn(function()
		while running() do
			local operation = STATE.autoAdminAbuse == true and STATE.autoAbuseDrops == true and table.remove(abuse.queue, 1) or nil
			if operation then
				pcall(runAbuseOperation, operation)
			else
				local now = workspace:GetServerTimeNow()
				local crown = abuse.active.crown
				local pies = abuse.active.pies
				if crown and (not crown.ends or now < crown.ends) then
					pcall(chaseCrown, crown)
				elseif pies and (not pies.ends or now < pies.ends) then
					pcall(throwEventPie, pies)
				end
				task.wait(0.55)
			end
			STATE.onTrip = false
		end
	end)
end

-- Throwing -------------------------------------------------------------------
-- The server only accepts a throw about 6.6 s after the last accepted one
-- (measured live). The hub learns that gap: a refused throw makes it wait a
-- little longer, accepted throws slowly try a little sooner.
-- The server can also get stuck refusing every throw after a training turn
-- (seen live: 6+ minutes, StopTrain every few seconds did not help, one throw
-- from the game's own spot on the strip fixed it at once). So a refused run
-- climbs a ladder: StopTrain once, then throw from on the strip, then StopTrain
-- again now and then, and as a last resort respawn the character.
-- Since place v342 the server wants ~9-10 s between throws (it was ~6.6 s).
local throwState = { lastOkSent = 0, sentAt = 0, learned = 9.4, refusedRow = 0, needStop = true, lastStop = 0, lastRespawn = 0, afterTrain = false, log = {} }

-- Catch history -------------------------------------------------------------------
-- Every plant you catch, saved per account so it survives reloads and server
-- changes: the newest 500 in full, totals for ever.
local HISTORY_PATH = "Rayfield/Configurations/ZinoosHub/ThrowASeed_history_" .. tostring(LocalPlayer.UserId) .. ".json"
local history = { entries = {}, total = 0, newCount = 0, byRarity = {}, best = nil, version = 0, dirty = false, savedAt = 0, lastSeen = nil }
STATE.history = history

do
	local ok, data = pcall(function()
		if typeof(isfile) == "function" and isfile(HISTORY_PATH) then
			return HttpService:JSONDecode(readfile(HISTORY_PATH))
		end
		return nil
	end)
	if ok and type(data) == "table" then
		history.entries = type(data.entries) == "table" and data.entries or {}
		history.total = tonumber(data.total) or #history.entries
		history.newCount = tonumber(data.newCount) or 0
		history.byRarity = type(data.byRarity) == "table" and data.byRarity or {}
		history.best = type(data.best) == "table" and data.best or nil
	end
end

function history.save(force)
	if not history.dirty or (not force and os.clock() - history.savedAt < 10) then
		return
	end
	history.savedAt = os.clock()
	history.dirty = false
	pcall(function()
		writefile(HISTORY_PATH, HttpService:JSONEncode({
			entries = history.entries, total = history.total, newCount = history.newCount,
			byRarity = history.byRarity, best = history.best,
		}))
	end)
end

function history.plantNumber(plant)
	return tonumber(tostring(plant and plant.id or ""):match("%d+"))
end

function history.newestNumber()
	local best = 0
	for _, plant in pairs(type(ClientState.plants) == "table" and ClientState.plants or {}) do
		best = math.max(best, history.plantNumber(plant) or 0)
	end
	return best
end

-- Start linking from the plants you already have, so the first catch counts too.
pcall(function()
	history.lastSeen = history.newestNumber()
end)

function history.clear()
	history.entries, history.total, history.newCount, history.byRarity, history.best = {}, 0, 0, {}, nil
	history.version += 1
	history.dirty = true
	history.save(true)
end

function history.add(result)
	if history.lastSeen == nil then
		history.lastSeen = history.newestNumber()
	end
	local tier = tonumber(result.rarity) or 1
	local entry = {
		t = os.time(),
		plant = tostring(result.plant or "Plant"),
		tier = tier,
		size = tonumber(result.size) or 1,
		mutation = tonumber(result.mutation) or 1,
		income = tonumber(result.income) or 0,
		new = result.isNew == true or nil,
	}
	table.insert(history.entries, 1, entry)
	while #history.entries > 500 do
		table.remove(history.entries)
	end
	history.total += 1
	if entry.new then
		history.newCount += 1
	end
	local rarity = rarityName(tier)
	history.byRarity[rarity] = (tonumber(history.byRarity[rarity]) or 0) + 1
	local best = history.best
	if not best or tier > (tonumber(best.tier) or 0) or (tier == tonumber(best.tier) and entry.income > (tonumber(best.income) or 0)) then
		history.best = entry
	end
	-- Link it to the plant the game adds, so the list can show garden / kept / sold.
	task.delay(1.5, function()
		local found, foundNumber
		for _, plant in pairs(type(ClientState.plants) == "table" and ClientState.plants or {}) do
			local number = history.plantNumber(plant)
			if number and number > (history.lastSeen or 0) and plant.plant == entry.plant and (not foundNumber or number < foundNumber) then
				found, foundNumber = plant, number
			end
		end
		if found then
			entry.id = found.id
			history.lastSeen = foundNumber
			history.version += 1
			history.dirty = true
		end
	end)
	history.version += 1
	history.dirty = true
	history.save()
end

local HISTORY_FILTERS = { "All", "New to index", "Mutated", "Ruby and Rainbow", "Huge and bigger", "Still mine (garden or kept)" }

function history.summaryText()
	if history.total == 0 then
		return "No catches yet. Every plant you throw shows up here."
	end
	local lines = {
		string.format("Catches: %s · new to index: %s", shortNumber(history.total), shortNumber(history.newCount)),
	}
	local best = history.best
	if best then
		table.insert(lines, string.format("Best ever: %s (%s) · $%s/s", describePlant(best), rarityName(best.tier), shortNumber(best.income)))
	end
	local rarities = {}
	for name, count in pairs(history.byRarity) do
		table.insert(rarities, { name = name, count = tonumber(count) or 0, tier = rarityTier(name) or 0 })
	end
	table.sort(rarities, function(a, b)
		return a.tier > b.tier
	end)
	local parts = {}
	for i = 1, math.min(#rarities, 6) do
		table.insert(parts, rarities[i].name .. " " .. shortNumber(rarities[i].count))
	end
	if #parts > 0 then
		table.insert(lines, table.concat(parts, " · "))
	end
	return table.concat(lines, "\n")
end

function history.listText(filter, limit)
	local where = {}
	for _, plant in pairs(type(ClientState.plants) == "table" and ClientState.plants or {}) do
		if plant.id then
			where[plant.id] = plant.placed and "garden" or "kept"
		end
	end
	local today = os.date("%d/%m")
	local lines = {}
	for _, entry in ipairs(history.entries) do
		local status = entry.id and (where[entry.id] or "sold") or nil
		local mutation, size = tonumber(entry.mutation) or 1, tonumber(entry.size) or 1
		local show = filter == "All"
			or (filter == "New to index" and entry.new)
			or (filter == "Mutated" and mutation > 1)
			or (filter == "Ruby and Rainbow" and mutation >= 5)
			or (filter == "Huge and bigger" and size >= 4)
			or (filter == "Still mine (garden or kept)" and (status == "garden" or status == "kept"))
		if show then
			local stamp = os.date("%d/%m", entry.t) == today and os.date("%H:%M", entry.t) or os.date("%d/%m %H:%M", entry.t)
			table.insert(lines, string.format("%s  %s · %s · $%s/s%s%s", stamp, describePlant(entry), rarityName(entry.tier),
				shortNumber(entry.income), entry.new and " · NEW" or "", status and (" · " .. status) or ""))
			if #lines >= limit then
				break
			end
		end
	end
	return #lines > 0 and table.concat(lines, "\n") or "Nothing here yet."
end

-- Picture list: a scrolling panel inside the WindUI box, one row per catch with
-- the plant's own 3D model (ReplicatedStorage.PlantModels[rarity][name],
-- framed like the game's inventory slots), tinted with its mutation colours.
local MUTATION_LOOK = {
	[2] = Color3.fromHex("FFC83A"), -- Gold
	[3] = Color3.fromHex("BFF4FF"), -- Diamond
	[4] = Color3.fromHex("2EE07A"), -- Emerald
	[5] = Color3.fromHex("FF3150"), -- Ruby
}

function history.buildList(paragraph, title)
	elevate()
	local root = type(paragraph) == "table" and (paragraph.ElementFrame or (type(paragraph.UIElements) == "table" and paragraph.UIElements.Main)) or nil
	if typeof(root) ~= "Instance" then
		root = nil
		local guiRoot = typeof(gethui) == "function" and gethui() or game:GetService("CoreGui")
		local windGui = guiRoot and guiRoot:FindFirstChild("WindUI")
		for _, label in ipairs(windGui and windGui:GetDescendants() or {}) do
			if label:IsA("TextLabel") and label.Text == title and label.Parent and label.Parent.Name == "TitleFrame" then
				local node = label
				while node and not node:IsA("ImageButton") do
					node = node.Parent
				end
				root = node
				break
			end
		end
	end
	local inner
	for _, child in ipairs(root and root:GetChildren() or {}) do
		if child:IsA("Frame") and child:FindFirstChildOfClass("UIListLayout") and child:FindFirstChild("TitleFrame") then
			inner = child
			break
		end
	end
	if not inner then
		return nil
	end
	local fontFace
	for _, label in ipairs(inner:GetDescendants()) do
		if label:IsA("TextLabel") then
			fontFace = label.FontFace
			break
		end
	end
	local ink = Color3.fromRGB(240, 238, 245)
	local dim = Color3.fromRGB(170, 166, 185)
	local statusHex = { garden = "58D68D", kept = "B05AFF", sold = "8C8896" }

	local function round(parent, radius)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius)
		corner.Parent = parent
	end
	local function text(parent, value, size, weight)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Text = value
		label.TextSize = size
		label.TextColor3 = ink
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.RichText = true
		if fontFace then
			label.FontFace = Font.new(fontFace.Family, weight or Enum.FontWeight.Medium)
		end
		label.Parent = parent
		return label
	end

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "ZinoosHistoryList"
	panel.LayoutOrder = 50
	panel.Size = UDim2.new(1, 0, 0, 360)
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BackgroundTransparency = 0.55
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 3
	panel.ScrollingDirection = Enum.ScrollingDirection.Y
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.new()
	round(panel, 12)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 10)
	pad.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel
	local empty = text(panel, "Nothing here yet.", 14)
	empty.Size = UDim2.new(1, 0, 0, 24)
	empty.TextColor3 = dim
	panel.Parent = inner

	local function picture(holder, entry)
		local models = ReplicatedStorage:FindFirstChild("PlantModels")
		local folder = models and models:FindFirstChild(rarityName(entry.tier))
		local model = folder and folder:FindFirstChild((tostring(entry.plant):gsub(" ", "")))
		if not model then
			local letter = text(holder, string.sub(tostring(entry.plant), 1, 1), 20, Enum.FontWeight.Bold)
			letter.Size = UDim2.fromScale(1, 1)
			letter.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		local view = Instance.new("ViewportFrame")
		view.BackgroundTransparency = 1
		view.Size = UDim2.fromScale(1, 1)
		view.Ambient = Color3.fromRGB(170, 170, 180)
		view.LightColor = Color3.new(1, 1, 1)
		view.LightDirection = Vector3.new(-0.6, -1, -0.5)
		local clone = model:Clone()
		local mutation = tonumber(entry.mutation) or 1
		local index = 0
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Trail") or part:IsA("BillboardGui")
				or part:IsA("Script") or part:IsA("LocalScript") or part:IsA("Sound") then
				part:Destroy()
			elseif part:IsA("BasePart") then
				index += 1
				if mutation == 6 then
					part.Color = Color3.fromHSV((index * 0.13) % 1, 0.75, 1)
				elseif MUTATION_LOOK[mutation] then
					part.Color = part.Color:Lerp(MUTATION_LOOK[mutation], 0.65)
				end
			end
		end
		if clone:IsA("Model") then
			clone:PivotTo(CFrame.new())
		end
		clone.Parent = view
		local ok, center, size = pcall(function()
			return clone:GetBoundingBox()
		end)
		if not ok then
			center, size = CFrame.new(), Vector3.new(4, 4, 4)
		end
		local camera = Instance.new("Camera")
		camera.FieldOfView = 34
		local distance = math.max(size.X, size.Y, size.Z) * 0.62 / 0.3057306814586604
		camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0.45, 0.32, -1).Unit * distance, center.Position)
		camera.Parent = view
		view.CurrentCamera = camera
		view.Parent = holder
	end

	local rows = {}
	local function makeRow(entry)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 54)
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.BackgroundTransparency = 0.95
		row.BorderSizePixel = 0
		round(row, 10)
		local pic = Instance.new("Frame")
		pic.Size = UDim2.fromOffset(46, 46)
		pic.Position = UDim2.fromOffset(4, 4)
		pic.BackgroundColor3 = Color3.fromRGB(28, 26, 36)
		pic.BorderSizePixel = 0
		pic.ClipsDescendants = true
		pic.Parent = row
		round(pic, 10)
		local ring = Instance.new("UIStroke")
		ring.Thickness = 2
		local mutation = tonumber(entry.mutation) or 1
		if mutation == 6 then
			ring.Color = Color3.new(1, 1, 1)
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(70, 210, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
			})
			gradient.Parent = ring
		else
			ring.Color = MUTATION_LOOK[mutation] or Color3.fromRGB(70, 66, 84)
		end
		ring.Parent = pic
		pcall(picture, pic, entry)
		local name = text(row, describePlant(entry), 15, Enum.FontWeight.Bold)
		name.Position = UDim2.fromOffset(60, 7)
		name.Size = UDim2.new(1, -66, 0, 20)
		local sub = text(row, "", 13)
		sub.Position = UDim2.fromOffset(60, 29)
		sub.Size = UDim2.new(1, -66, 0, 18)
		sub.TextColor3 = dim
		return { frame = row, sub = sub }
	end

	return function(filter, limit)
		elevate()
		local where = {}
		for _, plant in pairs(type(ClientState.plants) == "table" and ClientState.plants or {}) do
			if plant.id then
				where[plant.id] = plant.placed and "garden" or "kept"
			end
		end
		local today = os.date("%d/%m")
		local shown = {}
		local count = 0
		for _, entry in ipairs(history.entries) do
			local status = entry.id and (where[entry.id] or "sold") or nil
			local mutation, size = tonumber(entry.mutation) or 1, tonumber(entry.size) or 1
			local show = filter == "All"
				or (filter == "New to index" and entry.new)
				or (filter == "Mutated" and mutation > 1)
				or (filter == "Ruby and Rainbow" and mutation >= 5)
				or (filter == "Huge and bigger" and size >= 4)
				or (filter == "Still mine (garden or kept)" and (status == "garden" or status == "kept"))
			if show then
				count += 1
				local row = rows[entry]
				if not row then
					row = makeRow(entry)
					rows[entry] = row
				end
				shown[entry] = true
				row.frame.LayoutOrder = count
				row.frame.Parent = panel
				local stamp = os.date("%d/%m", entry.t) == today and os.date("%H:%M", entry.t) or os.date("%d/%m %H:%M", entry.t)
				row.sub.Text = string.format("%s · %s · $%s/s%s%s", stamp, rarityName(entry.tier), shortNumber(entry.income),
					entry.new and ' · <font color="#FFD23A">NEW</font>' or "",
					status and string.format(' · <font color="#%s">%s</font>', statusHex[status], status) or "")
				if count >= limit then
					break
				end
			end
		end
		for entry, row in pairs(rows) do
			if not shown[entry] then
				row.frame:Destroy()
				rows[entry] = nil
			end
		end
		empty.Visible = count == 0
	end
end

hubCleanup(function()
	history.save(true)
end)

local function recordThrow(result)
	stats.throws += 1
	pcall(history.add, result)
	if result.perfect then
		stats.perfect += 1
	end
	local tier = tonumber(result.rarity) or 1
	local rarity = rarityName(tier)
	stats.rarityCounts[rarity] = (stats.rarityCounts[rarity] or 0) + 1
	local name = describePlant(result)
	if result.isNew then
		stats.newPlants += 1
	end
	if tier > stats.bestTier or (tier == stats.bestTier and stats.bestText == "None yet") then
		stats.bestTier = tier
		stats.bestText = name .. " (" .. rarity .. ")"
	end
	local line = string.format("%s · %s%s", name, rarity, result.isNew and " · NEW" or "")
	table.insert(stats.recent, 1, line)
	while #stats.recent > 6 do
		table.remove(stats.recent)
	end
	local minTier = STATE.notifyMinRarity == "All" and 1 or rarityTier(STATE.notifyMinRarity)
	local mutation = tonumber(result.mutation) or 1
	if tier >= minTier
		or (STATE.notifyNew == true and result.isNew)
		or (STATE.notifyMutations == true and mutation > 1) then
		notify(result.isNew and "New plant!" or (rarity .. " plant"), line .. string.format(" · %s/s", shortNumber(result.income or 0)))
	end
	if tier >= 5 or result.isNew then
		noteActivity(line)
	end
end

-- Standing on the strip makes the game open its own throw meter and lock the
-- camera; it stays up until you walk. The game closes it on W, so tap W
-- (and call the game's own abort if a phone executor can't send keys).
local gameAbort
local function gameAiming()
	local fx = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("ThrowFX")
	return fx ~= nil and fx:GetAttribute("State") == "aiming"
end

local function closeGameAim()
	if not gameAiming() then
		return
	end
	pcall(function()
		local vim = game:GetService("VirtualInputManager")
		vim:SendKeyEvent(true, Enum.KeyCode.W, false, game)
		task.wait(0.05)
		vim:SendKeyEvent(false, Enum.KeyCode.W, false, game)
	end)
	task.wait(0.3)
	if not gameAiming() then
		return
	end
	if gameAbort == nil then
		gameAbort = false
		pcall(function()
			local found = typeof(filtergc) == "function" and filtergc("function", { Name = "abort" }, false) or {}
			for _, fn in ipairs(found) do
				local src = debug.info(fn, "s")
				if type(src) == "string" and src:find("ThrowClient") then
					gameAbort = fn
					break
				end
			end
		end)
	end
	if gameAbort then
		pcall(gameAbort)
	end
end

-- Auto Complete Index -----------------------------------------------------------
-- The game's roll (Balance.Roll) walks every plant from rarest to commonest and
-- stops at each one with chance luck x c. Luck = zone luck where the seed lands
-- x seed luck x boosts, and the game's Throw Power setting (1-100%) shortens
-- the throw. So low power + a weak seed rolls commons, full power + the best
-- seed rolls Secrets. Before each throw the hub picks the power and seed with
-- the best chance of a plant you are missing (live: 1% power + Plain Seed gave
-- luck 1.2 in the Meadow and 3 new commons in 4 throws).
local indexHunt = { extra = 1, plan = nil, planAt = 0, planKey = "", touched = false, summary = "" }
STATE.indexHuntInfo = indexHunt

function indexHunt.missing()
	local have = type(ClientState.index) == "table" and ClientState.index or {}
	local list = {}
	for _, names in ipairs(Balance.Plants or {}) do
		for _, name in ipairs(names) do
			if not have[name] then
				table.insert(list, name)
			end
		end
	end
	return list
end

-- Chance of each plant for one throw at this luck (same walk as Balance.Roll).
function indexHunt.chances(luck)
	local result = {}
	local pass = 1
	local secretLuck = Balance.SecretLuck(luck)
	local last
	for _, entry in ipairs(Balance.ByOdds or {}) do
		local l = entry.tier == Balance.SecretTier and secretLuck or luck
		local p = math.min(1, l * (tonumber(entry.c) or 0))
		result[entry.name] = (result[entry.name] or 0) + pass * p
		pass *= 1 - p
		last = entry
		if pass <= 1e-15 then
			pass = 0
			break
		end
	end
	if last and pass > 0 then
		result[last.name] = (result[last.name] or 0) + pass
	end
	return result
end

function indexHunt.plantList(names, max)
	local shown = {}
	for i = 1, math.min(#names, max) do
		shown[i] = names[i]
	end
	return table.concat(shown, ", ") .. (#names > max and (" +" .. (#names - max) .. " more") or "")
end

function indexHunt.makePlan()
	local missing = indexHunt.missing()
	local strength = (tonumber(attr("Strength")) or 1) * (abuseOn("Throw") and (tonumber(Balance.AdminAbuse and Balance.AdminAbuse.ThrowStrength) or 25) or 1)
	local key = table.concat(missing, ",") .. "|" .. math.floor(math.log10(math.max(1, strength)) * 20) .. "|" .. string.format("%.2f", indexHunt.extra)
	if indexHunt.planKey == key and os.clock() - indexHunt.planAt < 60 then
		return indexHunt.plan
	end
	indexHunt.planKey, indexHunt.planAt = key, os.clock()
	local missingSet = {}
	local secretsLeft, othersLeft = {}, {}
	local secretNames = {}
	for _, entry in ipairs(Balance.ByOdds or {}) do
		if entry.tier == Balance.SecretTier then
			secretNames[entry.name] = true
		end
	end
	for _, name in ipairs(missing) do
		missingSet[name] = true
		table.insert(secretNames[name] and secretsLeft or othersLeft, name)
	end
	indexHunt.secretsLeft, indexHunt.othersLeft = secretsLeft, othersLeft
	local best
	indexHunt.maxSeedLuck = 0
	if #missing > 0 then
		local maxDistance = Balance.DistanceMax(strength)
		for _, seedIndex in ipairs(type(ClientState.seeds) == "table" and ClientState.seeds or {}) do
			seedIndex = tonumber(seedIndex)
			local okSeed, seedLuck = pcall(Balance.SeedLuck, seedIndex, ClientState.seeds)
			seedLuck = okSeed and tonumber(seedLuck) or nil
			if seedLuck then
				indexHunt.maxSeedLuck = math.max(indexHunt.maxSeedLuck, seedLuck)
			end
			if seedIndex and seedLuck then
				for power = 1, 100 do
					local zoneLuck = tonumber((ZoneConfig.LuckAt(maxDistance * power / 100))) or 1
					local luck = zoneLuck * seedLuck * indexHunt.extra
					local chances = indexHunt.chances(luck)
					local score = 0
					for name in pairs(missingSet) do
						score += chances[name] or 0
					end
					-- Ties (e.g. only Secrets left, all at the luck cap) go to
					-- full power and the strongest seed, i.e. normal farming.
					if not best or score > best.score * 1.0001
						or (score >= best.score * 0.9999 and (power > best.power or (power == best.power and seedLuck > best.seedLuck))) then
						best = { power = power, seed = seedIndex, seedLuck = seedLuck, score = score, luck = luck }
					end
				end
			end
		end
	end
	if best and best.score <= 0 then
		best = nil
	end
	indexHunt.plan = best
	return best
end

-- True while the hub is throwing at low power / a weak seed for commons.
function indexHunt.huntingLow()
	local plan = indexHunt.plan
	return STATE.indexHunt == true and plan ~= nil
		and (plan.power < 100 or plan.seedLuck < (indexHunt.maxSeedLuck or 0))
end

function indexHunt.restore()
	if not indexHunt.touched then
		return
	end
	if tonumber(attr("PowerPct")) ~= 100 then
		request("Settings", { power = 100 })
	end
	indexHunt.touched = false
	-- stepUpgrades equips the best seed again.
end

-- Set Throw Power and seed for the next throw.
function indexHunt.apply()
	if STATE.indexHunt ~= true then
		indexHunt.plan = nil
		return indexHunt.restore()
	end
	local plan = indexHunt.makePlan()
	if not plan then
		return indexHunt.restore()
	end
	if tonumber(attr("PowerPct")) ~= plan.power then
		if request("Settings", { power = plan.power }) then
			indexHunt.touched = true
		end
	end
	if tonumber(attr("Seed")) ~= plan.seed then
		if request("EquipSeed", { i = plan.seed }) then
			indexHunt.touched = true
		end
	end
end

-- Learn the boost multiplier (potions, events) from a real throw result.
function indexHunt.learn(result)
	local distance, luck, seedLuck = tonumber(result.distance), tonumber(result.luck), tonumber(result.seedLuck)
	if distance and luck and seedLuck and seedLuck > 0 then
		local zoneLuck = tonumber((ZoneConfig.LuckAt(distance))) or 0
		if zoneLuck > 0 then
			indexHunt.extra = math.clamp(luck / (zoneLuck * seedLuck), 1, 1e6)
		end
	end
end

hubCleanup(function()
	if indexHunt.touched then
		pcall(RequestRemote.InvokeServer, RequestRemote, "Settings", { power = 100 })
	end
end)

-- Live tracker text for the Index box.
function indexHunt.trackerText(found, total)
	local lines = { string.format("%d of %d plants found (%d%%)", found, total, total > 0 and math.floor(found / total * 100) or 0) }
	if found >= total and total > 0 then
		table.insert(lines, "Index complete!")
		return table.concat(lines, "\n")
	end
	if STATE.indexHunt ~= true then
		table.insert(lines, "Auto Complete Index is off")
		return table.concat(lines, "\n")
	end
	local plan = indexHunt.makePlan()
	local others, secrets = indexHunt.othersLeft or {}, indexHunt.secretsLeft or {}
	if #others > 0 and plan and indexHunt.huntingLow() then
		local seed = Balance.Seeds[plan.seed]
		local pct = plan.score * 100
		table.insert(lines, "Hunting: " .. indexHunt.plantList(others, 4))
		table.insert(lines, string.format("%d%% power + %s · %s chance of a new plant each throw",
			plan.power, seed and seed.name or "?", pct >= 10 and string.format("%d%%", math.floor(pct + 0.5)) or string.format("%.1f%%", pct)))
	elseif #others > 0 then
		table.insert(lines, "Can't be thrown right now: " .. indexHunt.plantList(others, 4))
	end
	if #secrets > 0 then
		local each = ""
		if plan and not indexHunt.huntingLow() and plan.score > 0 then
			each = " · about 1 in " .. shortNumber(math.floor(1 / plan.score)) .. " throws"
		end
		table.insert(lines, string.format("Secrets left (%d): only at full power%s", #secrets, each))
	end
	return table.concat(lines, "\n")
end

-- Harvest Moon and Admin Jackpot both need an exact landing zone. They take
-- priority over the normal index hunter, then restore the player's power when
-- the timed event ends.
local eventAim = { active = false, kind = nil, target = nil, power = nil, originalPower = nil, touched = false }
STATE.eventAim = eventAim

local function zonePower(zoneName, strengthScale)
	for _, zone in ipairs(ZoneConfig.List or {}) do
		if zone.name == zoneName then
			local strength = math.max(1, tonumber(attr("Strength")) or 1) * (strengthScale or 1)
			local maxDistance = tonumber(Balance.DistanceMax(strength)) or 1
			local center = ((tonumber(zone.start) or 0) + (tonumber(zone.finish) or tonumber(zone.start) or 0)) / 2
			local raw = center / math.max(maxDistance, 1) * 100
			if raw <= 100 then
				return math.clamp(math.floor(raw + 0.5), 1, 100), zone
			end
			return nil, zone
		end
	end
	return nil
end

local function bestEventSeed()
	local best, bestLuck = nil, -math.huge
	for _, owned in ipairs(type(ClientState.seeds) == "table" and ClientState.seeds or {}) do
		local index = tonumber(owned)
		local ok, luck = pcall(Balance.SeedLuck, index, ClientState.seeds)
		luck = ok and tonumber(luck) or -math.huge
		if index and luck > bestLuck then
			best, bestLuck = index, luck
		end
	end
	return best
end

local function harvestPlan()
	if STATE.autoHarvestMoon ~= true or attr("HarvestOk") ~= true or type(Balance.HarvestMoon) ~= "function" then
		return nil
	end
	local now = workspace:GetServerTimeNow()
	local moon, startsAt, endsAt = Balance.HarvestMoon(now)
	if not startsAt or not endsAt or now < startsAt or now >= endsAt then
		return nil
	end
	local beams = Balance.HarvestBeams(moon)
	local have = type(ClientState.index) == "table" and ClientState.index or {}
	local reach = tonumber(attr("ZoneReach")) or #ZoneConfig.List
	local best
	for index, zone in ipairs(ZoneConfig.List or {}) do
		if index <= reach and beams[zone.name] then
			local power = zonePower(zone.name, abuseOn("Throw") and (tonumber(Balance.AdminAbuse and Balance.AdminAbuse.ThrowStrength) or 25) or 1)
			if power then
				local missing = 0
				for _, plant in ipairs(Balance.HarvestZone and Balance.HarvestZone[zone.name] or {}) do
					if not have[plant.name] then
						missing += 1
					end
				end
				local score = missing * 1e12 + (tonumber(zone.finish) or tonumber(zone.start) or index)
				if not best or score > best.score then
					best = { kind = "Harvest Moon", zone = zone.name, power = power, score = score, endsAt = endsAt, missing = missing }
				end
			end
		end
	end
	return best
end

local function jackpotPlan()
	if STATE.autoAdminAbuse ~= true or not abuseOn("Jackpot") then
		return nil
	end
	local zone = workspace:GetAttribute("AbuseJackpotZone")
	if type(zone) ~= "string" then
		return nil
	end
	local scale = abuseOn("Throw") and (tonumber(Balance.AdminAbuse and Balance.AdminAbuse.ThrowStrength) or 25) or 1
	local power = zonePower(zone, scale)
	return power and { kind = "Jackpot", zone = zone, power = power, endsAt = tonumber(workspace:GetAttribute("AbuseJackpotUntil")) } or nil
end

function eventAim.plan()
	return jackpotPlan() or harvestPlan()
end

function eventAim.restore()
	if eventAim.touched and tonumber(attr("PowerPct")) ~= (eventAim.originalPower or 100) then
		request("Settings", { power = eventAim.originalPower or 100 })
	end
	eventAim.active, eventAim.kind, eventAim.target, eventAim.power = false, nil, nil, nil
	eventAim.originalPower, eventAim.touched = nil, false
end

function eventAim.apply()
	local plan = eventAim.plan()
	if not plan then
		eventAim.restore()
		return false
	end
	if not eventAim.touched then
		eventAim.originalPower = tonumber(attr("PowerPct")) or 100
	end
	eventAim.active, eventAim.kind, eventAim.target, eventAim.power = true, plan.kind, plan.zone, plan.power
	if tonumber(attr("PowerPct")) ~= plan.power and request("Settings", { power = plan.power }) then
		eventAim.touched = true
	end
	local seed = bestEventSeed()
	if seed and tonumber(attr("Seed")) ~= seed then
		request("EquipSeed", { i = seed })
	end
	return true
end

hubCleanup(function()
	if eventAim.touched then
		pcall(RequestRemote.InvokeServer, RequestRemote, "Settings", { power = eventAim.originalPower or 100 })
	end
end)

local function throwOnce()
	local char = character()
	if not char then
		return false, "Waiting for your character"
	end
	if isTraining() or throwState.needStop then
		throwState.needStop = false
		throwState.lastStop = os.clock()
		request("StopTrain")
		task.wait(1)
	end
	if not eventAim.apply() then
		indexHunt.apply()
	end
	-- Right after pull-ups the server refuses throws from behind the strip
	-- (seen every time live), so the first one goes from on the strip.
	local fromStrip = throwState.refusedRow >= 3 or throwState.afterTrain == true
	local spot = throwSpot(fromStrip)
	if not spot then
		return false, "Launch strip not found"
	end
	if moveTo(spot, 6) then
		task.wait(0.1)
	end
	if not fromStrip then
		closeGameAim()
	end
	local started = os.clock()
	AimRemote:FireServer()
	-- The meter is 0.5 - cos(t / 1.5 * 2pi) / 2: full at 0.75 s after Aim.
	task.wait(0.75)
	local elapsed = os.clock() - started
	local meter = 0.5 - math.cos(elapsed / 1.5 * math.pi * 2) * 0.5
	HereRemote:FireServer()
	throwState.sentAt = os.clock()
	local ok, result = pcall(ThrowRemote.InvokeServer, ThrowRemote, meter)
	elevate()
	do
		local _, _, rootNow = character()
		local log = throwState.log or {}
		throwState.log = log
		table.insert(log, 1, string.format("%.1f since ok %.1f %s dz=%.0f", os.clock(), throwState.sentAt - throwState.lastOkSent,
			type(result) == "table" and "OK" or "NO", rootNow and (rootNow.Position - spot.Position).Magnitude or -1))
		while #log > 20 do
			table.remove(log)
		end
	end
	STATE.throwLog = throwState.log
	if fromStrip then
		closeGameAim()
	end
	if not ok or type(result) ~= "table" then
		return false, "Server said wait (cooldown)"
	end
	CollectRemote:FireServer(true)
	recordThrow(result)
	indexHunt.learn(result)
	return true, result
end

-- Show Throw Animation: let the game do its own throw (meter, flight, reveal)
-- and only press at the top of the meter and Throw Again for the player.
-- One full throw takes about 15-35 s, so this is slower than plain throwing.
local animated = { pressedAt = 0, maxPlant = nil }

function animated.gui(name)
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	return pg and pg:FindFirstChild(name)
end

function animated.choiceButton(name)
	local gui = animated.gui("ChoixApresLancer")
	if not gui or not gui.Enabled then
		return nil
	end
	local buttons = gui:FindFirstChild("Boutons", true)
	local button = buttons and buttons:FindFirstChild(name)
	if button and button.Visible and buttons.Visible then
		local frame = buttons
		while frame and frame ~= gui do
			if frame:IsA("GuiObject") and not frame.Visible then
				return nil
			end
			frame = frame.Parent
		end
		return button
	end
	return nil
end

function animated.click(button)
	local done = false
	pcall(function()
		for _, conn in ipairs(getconnections(button.Activated)) do
			conn:Fire()
			done = true
		end
	end)
	if not done and typeof(firesignal) == "function" then
		pcall(firesignal, button.Activated)
	end
end

function animated.meter()
	local hud = animated.gui("HudLancer")
	local jauge = hud and hud:FindFirstChild("Jauge")
	if not jauge or not jauge.Visible then
		return nil
	end
	local cursor = jauge:FindFirstChild("Capsule") and jauge.Capsule:FindFirstChild("Curseur")
	return cursor and (317 - cursor.Position.Y.Offset) / 304 or nil
end

function animated.press()
	local sent = pcall(function()
		local vim = game:GetService("VirtualInputManager")
		vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
		task.wait(0.03)
		vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
	end)
	-- The game hides the meter 0.4 s after a press it took.
	task.wait(0.6)
	if sent and animated.meter() == nil then
		return
	end
	do
		-- The key didn't land (some phone executors): call the game's own input handler.
		pcall(function()
			local fake = { KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard }
			for _, conn in ipairs(getconnections(UserInputService.InputBegan)) do
				local fn = conn.Function
				local src = fn and debug.info(fn, "s")
				if type(src) == "string" and src:find("ThrowClient") then
					fn(fake, false)
				end
			end
		end)
	end
end

function animated.newestPlantNumber()
	local best = 0
	for _, plant in pairs(type(ClientState.plants) == "table" and ClientState.plants or {}) do
		local number = tonumber(tostring(plant.id or ""):match("%d+"))
		if number and number > best then
			best = number
		end
	end
	return best
end

function animated.recordNew()
	local seen = animated.maxPlant or animated.newestPlantNumber()
	local newest, newestNumber = nil, seen
	for _, plant in pairs(type(ClientState.plants) == "table" and ClientState.plants or {}) do
		local number = tonumber(tostring(plant.id or ""):match("%d+"))
		if number and number > newestNumber then
			newest, newestNumber = plant, number
		end
	end
	animated.maxPlant = newestNumber
	if newest then
		recordThrow({
			plant = newest.plant, rarity = newest.rarity, size = newest.size, mutation = newest.mutation,
			income = newest.income, perfect = true,
		})
	end
end

-- True while the game is in the middle of a throw it started.
function animated.busy()
	local camera = workspace.CurrentCamera
	return os.clock() - animated.pressedAt < 60 and camera and camera.CameraType == Enum.CameraType.Scriptable
		and animated.meter() == nil and animated.choiceButton("Encore") == nil
end

-- Leaves the game's throw screens (used when the animation is turned off or
-- the cycle wants pull-ups). Returns true while it still has to wait.
function animated.finish()
	if animated.busy() then
		STATE.throwStatus = "Letting the throw animation finish"
		return true
	end
	local again = animated.choiceButton("Encore")
	if again then
		animated.click(again)
		task.delay(1, animated.recordNew)
		task.wait(0.5)
	end
	closeGameAim()
	return false
end

-- One step of the animated loop; returns how long to wait.
function animated.step()
	if animated.maxPlant == nil then
		animated.maxPlant = animated.newestPlantNumber()
	end
	if isTraining() or throwState.needStop then
		throwState.needStop = false
		throwState.lastStop = os.clock()
		request("StopTrain")
		task.wait(1)
	end
	local again = animated.choiceButton("Encore")
	if again then
		indexHunt.apply()
		animated.click(again)
		task.delay(1, animated.recordNew)
		STATE.throwStatus = string.format("Throw Again · %d done", stats.throws)
		STATE.status = "Throwing"
		return 1
	end
	if animated.busy() then
		STATE.throwStatus = string.format("Watching the throw · %d done", stats.throws)
		STATE.status = "Throwing"
		return 0.3
	end
	local level = animated.meter()
	if level then
		-- The meter peaks every 1.5 s; press near the top (PERFECT band).
		local started = os.clock()
		while os.clock() - started < 3 do
			level = animated.meter()
			if not level then
				break
			end
			if level >= 0.965 then
				animated.pressedAt = os.clock()
				animated.press()
				STATE.throwStatus = "PERFECT! Watching the throw"
				return 1
			end
			RunService.RenderStepped:Wait()
		end
		return 0.2
	end
	-- Stand on the strip; the game opens its meter by itself.
	indexHunt.apply()
	local _, _, root = character()
	if root and root.Anchored then
		root.Anchored = false
	end
	moveTo(throwSpot(true), 3)
	STATE.throwStatus = "Walking onto the strip"
	return 0.5
end

-- Training -------------------------------------------------------------------
local function startTraining()
	if isTraining() then
		return true
	end
	local spot = trainSpot()
	local prompt = spot and spot:FindFirstChild("TrainPrompt")
	if not prompt then
		return false
	end
	moveTo(spot.WorldCFrame * CFrame.new(0, 0, 3), 5)
	task.wait(0.4)
	if typeof(fireproximityprompt) == "function" then
		pcall(fireproximityprompt, prompt)
	else
		pcall(function()
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.05)
			prompt:InputHoldEnd()
		end)
	end
	elevate()
	-- The server plays a short start cutscene before training counts.
	local waited = 0
	while waited < 3 and not isTraining() do
		task.wait(0.25)
		waited += 0.25
	end
	return isTraining()
end

local cycle = { phase = "throw", endsAt = 0 }

local function eventPriorityMode()
	local aim = eventAim.plan()
	if aim then
		STATE.priorityReason = aim.kind .. " · " .. aim.zone
		return "throw"
	end
	if STATE.autoAdminAbuse == true then
		local loadedLucky = (tonumber(attr("LuckyThrows")) or 0) + (tonumber(attr("LuckyThrows10")) or 0)
		if abuseOn("Luck") or abuseOn("Mutation") or abuseOn("Throw") or loadedLucky > 0 then
			STATE.priorityReason = loadedLucky > 0 and ("Admin Lucky Throws · " .. loadedLucky .. " left") or "Admin throw boost"
			return "throw"
		end
		if abuseOn("Train") then
			STATE.priorityReason = "Admin training boost"
			return "train"
		end
	end
	STATE.priorityReason = nil
	return nil
end

local function wantedMode()
	local priority = eventPriorityMode()
	if priority then
		STATE.cycleStatus = STATE.priorityReason
		return priority
	end
	if STATE.cycleTrain == true then
		local now = os.clock()
		if cycle.endsAt == 0 then
			cycle.phase = "train"
			cycle.endsAt = now + STATE.cycleTrainMinutes * 60
		elseif now >= cycle.endsAt then
			cycle.phase = cycle.phase == "train" and "throw" or "train"
			cycle.endsAt = now + (cycle.phase == "train" and STATE.cycleTrainMinutes or STATE.cycleThrowMinutes) * 60
			noteActivity(cycle.phase == "train" and "Cycle: training" or "Cycle: throwing")
		end
		local left = math.max(0, math.floor(cycle.endsAt - now))
		STATE.cycleStatus = string.format("%s · %d:%02d left", cycle.phase == "train" and "Training" or "Throwing", left // 60, left % 60)
		return cycle.phase
	end
	cycle.endsAt = 0
	STATE.cycleStatus = "Off"
	if STATE.autoThrow == true then
		return "throw"
	end
	if STATE.autoTrain == true then
		return "train"
	end
	return "idle"
end

local function strengthLine()
	local strength = tonumber(attr("Strength")) or 0
	local nextZone = tonumber(attr("NextZoneStrength"))
	local text = "Strength " .. shortNumber(strength) .. " · Level " .. tostring(attr("Level") or "?")
	if nextZone and nextZone > strength then
		text ..= " · next zone at " .. shortNumber(nextZone)
	end
	return text
end

local function stepFarm()
	local mode = wantedMode()
	STATE.mode = mode
	if STATE.onTrip == true then
		STATE.status = "At a machine"
		return 0.3
	end
	if mode == "throw" then
		STATE.trainStatus = STATE.cycleTrain == true and "Waiting for the cycle" or "Off"
		if STATE.showAnimation == true then
			return animated.step()
		end
		if animated.finish() then
			return 0.5
		end
		local gap = math.max(tonumber(STATE.throwGap) or 6, throwState.learned)
		-- Aim 0.85 s early so the throw itself lands right on the gap.
		local wait = throwState.lastOkSent + gap - 0.85 - os.clock()
		if wait > 0 then
			STATE.throwStatus = string.format("Next throw in %.1fs · %d done · every %.1fs", wait, stats.throws, gap)
			return math.min(wait, 0.25)
		end
		local ok, result = throwOnce()
		if ok then
			throwState.lastOkSent = throwState.sentAt
			throwState.refusedRow = 0
			throwState.afterTrain = false
			throwState.learned = math.max(6.2, throwState.learned - 0.05)
			STATE.throwStatus = string.format("Threw %s · %d done", describePlant(result), stats.throws)
			STATE.status = "Throwing"
			return 0.1
		end
		stats.rejected += 1
		if result == "Server said wait (cooldown)" then
			-- A refused try does not restart the server's wait (measured), so
			-- try again shortly and learn a slightly longer gap.
			throwState.refusedRow += 1
			local row = throwState.refusedRow
			if throwState.sentAt - throwState.lastOkSent < 15 then
				-- Only a refusal close to the last throw says the wait is longer.
				throwState.learned = math.min(14, throwState.learned + 0.3)
			end
			if row == 2 or (row >= 10 and os.clock() - throwState.lastStop > 30) then
				-- The server may still think you are training.
				throwState.needStop = true
			end
			if row == 6 or row % 15 == 0 then
				CollectRemote:FireServer(true)
			end
			if row >= 20 and os.clock() - throwState.lastRespawn > 180 then
				-- Over a minute stuck: a fresh character clears it on the server.
				throwState.lastRespawn = os.clock()
				noteActivity("Throws stuck, respawning to fix it")
				local _, humanoid = character()
				if humanoid then
					humanoid.Health = 0
				end
				STATE.throwStatus = "Throws stuck, respawning"
				return 6
			end
			STATE.status = "Throwing"
			STATE.throwStatus = row >= 3 and string.format("Server keeps saying wait (%d in a row), trying to unstick it", row)
				or "Server said wait, trying again"
			return row >= 6 and 3 or 0.6
		end
		STATE.throwStatus = tostring(result)
		return 0.5
	elseif mode == "train" then
		-- The next throwing turn starts with a StopTrain to the server.
		throwState.needStop = true
		throwState.afterTrain = true
		STATE.throwStatus = STATE.cycleTrain == true and "Waiting for the cycle" or "Off"
		if animated.finish() then
			return 0.5
		end
		if not isTraining() then
			STATE.trainStatus = "Getting on the bar..."
			if not startTraining() then
				-- The server refuses a restart for a while after pull-ups stop.
				STATE.trainStatus = "Bar not ready yet (the game makes you wait after stopping), retrying"
				return 5
			end
			noteActivity("Started pull-ups")
		end
		STATE.trainStatus = "Doing pull-ups · " .. strengthLine()
		STATE.status = "Training"
		return 1
	end
	STATE.throwStatus = "Off"
	STATE.trainStatus = isTraining() and ("Doing pull-ups by hand · " .. strengthLine()) or "Off"
	STATE.status = "Idle"
	return 0.5
end

-- Upgrades -------------------------------------------------------------------
local function ownsSeed(index)
	for _, owned in ipairs(type(ClientState.seeds) == "table" and ClientState.seeds or {}) do
		if tonumber(owned) == index then
			return true
		end
	end
	return false
end

local function bestOwnedSeed()
	local best, bestLuck = nil, -1
	for index in ipairs(Balance.Seeds or {}) do
		if ownsSeed(index) then
			local ok, luck = pcall(Balance.SeedLuck, index, ClientState.seeds)
			luck = ok and tonumber(luck) or 0
			if luck > bestLuck then
				best, bestLuck = index, luck
			end
		end
	end
	return best
end

local function nextSeed()
	for index, seed in ipairs(Balance.Seeds or {}) do
		if not seed.hidden and not seed.robux and tonumber(seed.price) and not ownsSeed(index) then
			return index, seed
		end
	end
	return nil
end

local function nextBar()
	local bar = tonumber(attr("Bar")) or 1
	local entry = Balance.Bars and Balance.Bars[bar + 1]
	if entry and tonumber(entry.price) then
		return bar + 1, entry
	end
	return nil
end

local function nextCapacityCost()
	local capacity = tonumber(attr("Capacity")) or tonumber(ClientState.capacity) or 8
	local base = tonumber(ClientState.capacityBase) or capacity
	if base >= (Balance.CapacityMax or 30) then
		return nil
	end
	local ok, cost = pcall(Balance.CapacityCost, base)
	return ok and tonumber(cost) or nil
end

local upgradeWait = 0
local function stepUpgrades()
	if os.clock() < upgradeWait then
		return
	end
	upgradeWait = os.clock() + 2
	local wanted = {}
	-- Keep the best owned seed equipped (also after buying one by hand),
	-- except while Auto Complete Index has picked a weaker one for commons.
	local best = bestOwnedSeed()
	if best and tonumber(attr("Seed")) ~= best and not indexHunt.huntingLow() and not eventAim.active then
		local ok, message = request("EquipSeed", { i = best })
		if ok then
			noteActivity("Equipped " .. tostring(Balance.Seeds[best].name))
		else
			STATE.upgradeStatus = "Equip seed: " .. tostring(message)
		end
	end
	if STATE.autoSeed == true then
		local index, seed = nextSeed()
		if index then
			table.insert(wanted, { kind = "seed", index = index, price = seed.price, name = seed.name })
		end
	end
	if STATE.autoBar == true then
		local index, bar = nextBar()
		if index then
			table.insert(wanted, { kind = "bar", index = index, price = bar.price, name = bar.name })
		end
	end
	if STATE.autoCapacity == true then
		local cost = nextCapacityCost()
		if cost then
			table.insert(wanted, { kind = "capacity", price = cost, name = "Bigger Garden" })
		end
	end
	if #wanted == 0 then
		STATE.upgradeStatus = (STATE.autoSeed or STATE.autoBar or STATE.autoCapacity) and "Everything selected is maxed" or "Off"
		return
	end
	-- Cheapest first, so every upgrade keeps moving.
	table.sort(wanted, function(a, b)
		return a.price < b.price
	end)
	local pick = wanted[1]
	if spendable() < pick.price then
		local parts = {}
		for _, item in ipairs(wanted) do
			table.insert(parts, item.name .. " $" .. shortNumber(item.price))
		end
		STATE.upgradeStatus = "Saving for " .. table.concat(parts, " · ")
		return
	end
	local ok, message
	if pick.kind == "seed" then
		ok, message = request("BuySeed", { i = pick.index })
		if ok then
			request("EquipSeed", { i = pick.index })
		end
	elseif pick.kind == "bar" then
		ok, message = request("BuyBar")
	else
		ok, message = request("BuyCapacity")
	end
	if ok then
		stats.spent += pick.price
		STATE.upgradeStatus = "Bought " .. pick.name
		noteActivity("Bought " .. pick.name .. " ($" .. shortNumber(pick.price) .. ")")
		notify("Upgrade bought", pick.name .. " for $" .. shortNumber(pick.price))
		upgradeWait = os.clock() + 1
	else
		STATE.upgradeStatus = pick.name .. ": " .. tostring(message or "not bought")
		upgradeWait = os.clock() + 10
	end
end

-- Garden: place, fuse, sell -----------------------------------------------------
local function protectedPlant(plant)
	-- "Holding" is the plant in your hand. (The plant's own "hand" field only
	-- means it is in your inventory, so it is not used here.)
	if plant.placed or attr("Holding") == plant.id or (tonumber(plant.rarity) or 1) == Balance.SecretTier then
		return true
	end
	if STATE.keepMutations == true and (tonumber(plant.mutation) or 1) > 1 then
		return true
	end
	if STATE.keepBigSizes == true and (tonumber(plant.size) or 1) >= 4 then
		return true
	end
	return false
end

local function storedPlants()
	local list = {}
	for _, plant in ipairs(plants()) do
		if not plant.placed then
			table.insert(list, plant)
		end
	end
	return list
end

local function placedStats()
	local placed, weakest = 0, math.huge
	for _, plant in ipairs(plants()) do
		if plant.placed then
			placed += 1
			weakest = math.min(weakest, plantIncome(plant))
		end
	end
	return placed, weakest
end

-- Some actions only work beside a machine (Fuse Machine, Sell Stall).
-- A trip walks there, does the work and leaves; throwing and training wait
-- while a trip is running and take you back afterwards.
local function propCFrame(name)
	local props = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Props")
	local model = props and props:FindFirstChild(name)
	if not model then
		return nil
	end
	local ok, pivot = pcall(model.GetPivot, model)
	local okSize, size = pcall(model.GetExtentsSize, model)
	if not ok then
		return nil
	end
	local depth = okSize and size.Z / 2 + 5 or 12
	local spot = pivot.Position + Vector3.new(0, 3, depth)
	return CFrame.lookAt(spot, Vector3.new(pivot.Position.X, spot.Y, pivot.Position.Z))
end

local function withTrip(cf, work)
	if not cf then
		return work()
	end
	STATE.onTrip = true
	-- Let a throw that is already flying finish first.
	task.wait(1)
	local ok, err = pcall(function()
		-- An animated throw: wait for it, then leave the game's throw screens.
		local waited = 0
		while animated.busy() and waited < 45 do
			task.wait(0.5)
			waited += 0.5
		end
		local back = animated.choiceButton("Retour")
		if back then
			animated.click(back)
			task.delay(1, animated.recordNew)
			task.wait(1)
		end
		closeGameAim()
		if isTraining() then
			stopTraining()
			task.wait(0.5)
		end
		moveTo(cf, 4)
		task.wait(0.6)
		work()
	end)
	STATE.onTrip = false
	elevate()
	if not ok then
		warn("[Zinoos hub] Trip failed: " .. tostring(err))
	end
end

STATE.withTrip = withTrip
STATE.propCFrame = propCFrame
STATE.request = request

local fuseWait = 0
local gardenWait = 0

-- The game's fuse maths (Balance.FuseCandidates): 3 plants make 1 random
-- plant worth 0.72-1.2x their total, capped at the best plant the machine can
-- make. Returns the lowest income the fuse can give, i.e. what is guaranteed.
local function fuseSureIncome(trio)
	local ok, candidates = pcall(Balance.FuseCandidates, trio)
	if not ok or type(candidates) ~= "table" or #candidates == 0 then
		return nil
	end
	local base, actual = 0, 0
	for _, plant in ipairs(trio) do
		local okIncome, value = pcall(Balance.Income, tonumber(plant.rarity) or 1, plant.size, plant.mutation, 1, plant.plant)
		base += okIncome and tonumber(value) or 0
		actual += plantIncome(plant)
	end
	local scale = base > 0 and actual / base or 1
	local low = math.huge
	for _, candidate in ipairs(candidates) do
		low = math.min(low, (tonumber(candidate.inc) or 0) * scale)
	end
	return low < math.huge and low or nil
end

-- Fuse or Sell Leftovers: fuse only when the result is sure to go straight
-- into the garden; when nothing in storage can do that, sell it. Placed,
-- held and Secret plants are never touched. Returns notes for the status.
local function stepSmartStorage(stored)
	local notes = {}
	local capacity = tonumber(ClientState.capacity) or tonumber(attr("Capacity")) or 8
	local placed, weakest = placedStats()
	if placed < capacity or weakest == math.huge then
		return notes
	end
	local pool = {}
	for _, plant in ipairs(stored) do
		-- A plant that beats the garden belongs in it (and may have just been
		-- placed before the game's data caught up): never fuse or sell it.
		if not plant.placed and attr("Holding") ~= plant.id and (tonumber(plant.rarity) or 1) ~= Balance.SecretTier
			and plantIncome(plant) <= weakest then
			table.insert(pool, plant)
		end
	end
	if #pool == 0 then
		return notes
	end
	table.sort(pool, function(a, b)
		return plantIncome(a) > plantIncome(b)
	end)
	-- Kept for trading, never fused or sold:
	-- * Always Keep Mutations: every plant with that mutation or rarer.
	-- * Keep Duplicates For Trading: an exact copy (same plant, mutation and
	--   size) of a plant in the garden, up to the chosen spares of each kind.
	local keptForTrade = 0
	local minMutation = KEEP_MUTATION_MIN[tostring(STATE.keepMutationMin)]
	if STATE.keepTradeDupes == true or minMutation then
		local function kindOf(plant)
			return string.format("%s|%d|%d", tostring(plant.plant), tonumber(plant.mutation) or 1, tonumber(plant.size) or 1)
		end
		local gardenKinds = {}
		if STATE.keepTradeDupes == true then
			for _, plant in ipairs(plants()) do
				if plant.placed then
					gardenKinds[kindOf(plant)] = true
				end
			end
		end
		local spares = math.clamp(math.floor(tonumber(STATE.tradeSpares) or 3), 1, 20)
		local keptOf = {}
		local rest = {}
		for _, plant in ipairs(pool) do
			local kind = kindOf(plant)
			if minMutation and (tonumber(plant.mutation) or 1) >= minMutation then
				keptForTrade += 1
			elseif gardenKinds[kind] and (keptOf[kind] or 0) < spares then
				keptOf[kind] = (keptOf[kind] or 0) + 1
				keptForTrade += 1
			else
				table.insert(rest, plant)
			end
		end
		pool = rest
		if keptForTrade > 0 then
			table.insert(notes, "Keeping " .. keptForTrade .. " for trading")
		end
		if #pool == 0 then
			return notes
		end
	end
	local count = Balance.FuseCount or 3
	local fuses = {}
	local index = 1
	while #fuses < 12 and index + count - 1 <= #pool do
		local trio = {}
		for offset = 0, count - 1 do
			table.insert(trio, pool[index + offset])
		end
		local sure = fuseSureIncome(trio)
		if not sure or sure <= weakest * 1.001 then
			break
		end
		table.insert(fuses, trio)
		index += count
	end
	if #fuses > 0 then
		-- Worth fusing: do that first (on a throwing turn), sell nothing yet.
		if os.clock() >= fuseWait and STATE.mode ~= "train" then
			fuseWait = os.clock() + 30
			local fused = 0
			withTrip(propCFrame("FuseMachine"), function()
				for _, trio in ipairs(fuses) do
					if not running() then
						break
					end
					local ids = {}
					for _, plant in ipairs(trio) do
						table.insert(ids, plant.id)
					end
					local ok, message = request("Fuse", { ids = ids })
					if not ok then
						table.insert(notes, "Fuse: " .. tostring(message))
						break
					end
					fused += 1
				end
			end)
			if fused > 0 then
				noteActivity(string.format("Fused %d plants into %d better ones", fused * count, fused))
				table.insert(notes, "Fused " .. fused .. "x (garden upgrades)")
			end
		else
			table.insert(notes, #fuses .. " fuse(s) will upgrade the garden")
		end
		return notes
	end
	-- Nothing can beat the garden: sell (in batches the server handles easily).
	-- The game pays SellMultiplier (10) x a plant's income. Counted from the
	-- plants themselves: the money change would also include garden income.
	local sellMult = tonumber(Balance.SellMultiplier) or 10
	local sold, gained = 0, 0
	local batch, batchValue = {}, 0
	local function flush()
		if #batch == 0 then
			return true
		end
		local ok, message = request("SellMany", { ids = batch })
		if not ok and type(message) == "string" and string.find(message, "Go to", 1, true) and STATE.mode ~= "train" then
			withTrip(propCFrame("SellStall"), function()
				ok, message = request("SellMany", { ids = batch })
			end)
		end
		if ok then
			sold += #batch
			gained += batchValue
		else
			table.insert(notes, "Sell: " .. tostring(message))
		end
		batch, batchValue = {}, 0
		return ok
	end
	for _, plant in ipairs(pool) do
		table.insert(batch, plant.id)
		batchValue += plantIncome(plant) * sellMult
		if #batch >= 200 and not flush() then
			break
		end
	end
	flush()
	if sold > 0 then
		noteActivity(string.format("Sold %d leftover plant%s%s", sold, sold == 1 and "" or "s", gained > 0 and (" for $" .. shortNumber(gained)) or ""))
		table.insert(notes, "Sold " .. sold .. " (fusing can't beat your garden)")
	end
	return notes
end

STATE.smartStorageStep = stepSmartStorage

local function stepGarden()
	if os.clock() < gardenWait then
		return
	end
	gardenWait = os.clock() + 6
	local notes = {}
	local stored = storedPlants()
	-- Place best: only ask the game when a stored plant beats the garden.
	if STATE.autoPlace == true and #stored > 0 then
		local capacity = tonumber(ClientState.capacity) or tonumber(attr("Capacity")) or 8
		local placed, weakest = placedStats()
		local better = false
		for _, plant in ipairs(stored) do
			if placed < capacity or plantIncome(plant) > weakest * 1.001 then
				better = true
				break
			end
		end
		if better then
			local before = tonumber(attr("Income")) or 0
			local ok, message = request("PlaceBest")
			task.wait(0.6)
			local after = tonumber(attr("Income")) or 0
			if ok and after > before * 1.01 then
				noteActivity(string.format("Placed best plants · income $%s/s", shortNumber(after)))
			end
			table.insert(notes, ok and "Placed best plants" or ("Place: " .. tostring(message)))
			stored = storedPlants()
		end
	end
	if STATE.smartStorage == true then
		for _, note in ipairs(stepSmartStorage(stored)) do
			table.insert(notes, note)
		end
		stored = storedPlants()
	end
	-- Fuse three weak stored plants into a stronger one.
	if STATE.autoFuse == true and STATE.smartStorage ~= true then
		local maxTier = rarityTier(STATE.fuseMaxRarity)
		local pool = {}
		for _, plant in ipairs(stored) do
			if not protectedPlant(plant) and (tonumber(plant.rarity) or 1) <= maxTier and (tonumber(plant.rarity) or 1) ~= Balance.SecretTier then
				table.insert(pool, plant)
			end
		end
		table.sort(pool, function(a, b)
			return plantIncome(a) < plantIncome(b)
		end)
		local fused = 0
		-- Trips wait for a throwing turn: leaving the bar stops pull-ups, and
		-- the game makes you wait before they can start again.
		if #pool >= (Balance.FuseCount or 3) and os.clock() >= fuseWait and STATE.mode ~= "train" then
			fuseWait = os.clock() + 45
			-- The game only fuses at the Fuse Machine: one trip, up to 12 fuses.
			withTrip(propCFrame("FuseMachine"), function()
				while #pool >= (Balance.FuseCount or 3) and fused < 12 and running() do
					local ids = {}
					for _ = 1, (Balance.FuseCount or 3) do
						table.insert(ids, table.remove(pool, 1).id)
					end
					local ok, message = request("Fuse", { ids = ids })
					if not ok then
						table.insert(notes, "Fuse: " .. tostring(message))
						break
					end
					fused += 1
				end
			end)
		end
		if fused > 0 then
			noteActivity("Fused " .. fused * (Balance.FuseCount or 3) .. " plants")
			table.insert(notes, "Fused " .. fused .. "x")
			stored = storedPlants()
		end
	end
	-- Sell: only stored plants of the chosen rarities; placed, mutated and
	-- big plants are always kept.
	if STATE.autoSell == true and STATE.smartStorage ~= true and #STATE.sellRarities > 0 then
		local ids = {}
		local value = 0
		for _, plant in ipairs(stored) do
			if not protectedPlant(plant) and table.find(STATE.sellRarities, rarityName(plant.rarity)) then
				table.insert(ids, plant.id)
				value += plantIncome(plant) * (tonumber(Balance.SellMultiplier) or 10)
			end
		end
		if #ids > 0 then
			local ok, message = request("SellMany", { ids = ids })
			if not ok and type(message) == "string" and string.find(message, "Go to", 1, true) and STATE.mode ~= "train" then
				withTrip(propCFrame("SellStall"), function()
					ok, message = request("SellMany", { ids = ids })
				end)
			end
			if ok then
				noteActivity(string.format("Sold %d plants%s", #ids, value > 0 and (" for $" .. shortNumber(value)) or ""))
				table.insert(notes, "Sold " .. #ids)
			else
				table.insert(notes, "Sell: " .. tostring(message))
			end
		end
	end
	local placed = placedStats()
	local capacity = tonumber(ClientState.capacity) or tonumber(attr("Capacity")) or 8
	STATE.gardenStatus = string.format("%d/%d placed · %d stored · $%s/s%s", placed, capacity, #storedPlants(), shortNumber(attr("Income")), #notes > 0 and ("\n" .. table.concat(notes, " · ")) or "")
end

-- Rewards ----------------------------------------------------------------------
local function claimedGifts()
	local set = {}
	for part in string.gmatch(tostring(attr("GiftsClaimed") or ""), "%d+") do
		set[tonumber(part)] = true
	end
	return set
end

local rewardWait = 0
local offlineDone = false
local codesDone = false
local codeTries = {}
local function stepRewards()
	if os.clock() < rewardWait then
		return
	end
	rewardWait = os.clock() + 5
	local notes = {}
	if STATE.autoDaily == true and attr("DailyReady") == true then
		local ok, message = request("ClaimDaily")
		if ok then
			noteActivity("Claimed the daily reward")
			notify("Daily reward", tostring(message or "Claimed"))
		end
		table.insert(notes, ok and "Daily claimed" or ("Daily: " .. tostring(message)))
	end
	if STATE.autoGifts == true then
		local start = tonumber(attr("SessionStart")) or workspace:GetServerTimeNow()
		local played = workspace:GetServerTimeNow() - start
		local claimed = claimedGifts()
		local nextIn = nil
		for index, gift in ipairs(Balance.Gifts or {}) do
			if not claimed[index] then
				if played >= gift.at then
					local ok = request("ClaimGift", { i = index })
					if ok then
						noteActivity("Claimed playtime gift " .. index)
					end
					task.wait(0.3)
				else
					nextIn = nextIn and math.min(nextIn, gift.at - played) or (gift.at - played)
				end
			end
		end
		table.insert(notes, nextIn and string.format("Next gift in %d:%02d", math.floor(nextIn) // 60, math.floor(nextIn) % 60) or "All gifts claimed this session")
	end
	if STATE.autoOffline == true and not offlineDone then
		offlineDone = true
		local ok = request("CollectOffline")
		if ok then
			noteActivity("Collected offline cash")
		end
	end
	if STATE.autoCodes == true and not codesDone then
		local redeemed, pending = 0, 0
		for code in pairs(Balance.Codes or {}) do
			if not table.find(STATE.redeemedCodes, code) then
				codeTries[code] = (codeTries[code] or 0) + 1
				local ok, message = request("RedeemCode", { code = code })
				local text = string.lower(tostring(message or ""))
				-- Remember codes that worked, or that the game says are used up,
				-- expired or unknown, so they are never sent again. Anything else
				-- (a busy server) is tried again later, up to 3 times a session.
				if ok or string.find(text, "already") or string.find(text, "expired") or string.find(text, "used")
					or string.find(text, "invalid") or string.find(text, "limit") or string.find(text, "not a") then
					table.insert(STATE.redeemedCodes, code)
				elseif codeTries[code] < 3 then
					pending += 1
				end
				if ok then
					redeemed += 1
					noteActivity("Redeemed code " .. code)
				end
			end
		end
		codesDone = pending == 0
		saveConfig()
		if redeemed > 0 then
			notify("Codes redeemed", redeemed .. " new code" .. (redeemed == 1 and "" or "s"))
		end
	end
	if STATE.autoPotions == true or STATE.useLuckyThrows == true then
		local okItems, items = pcall(function()
			return HttpService:JSONDecode(tostring(attr("Items") or "{}"))
		end)
		if okItems and type(items) == "table" then
			local now = workspace:GetServerTimeNow()
			-- Boost_<kind> is the seconds left (an extra potion adds time).
			local function boostLeft(kind)
				local value = tonumber(attr("Boost_" .. kind)) or 0
				if value > 1e9 then
					value -= now
				end
				return math.max(0, value)
			end
			local function owned(prefix)
				local keys = {}
				for key, count in pairs(items) do
					if (tonumber(count) or 0) > 0 and string.match(tostring(key), "^(%w+):") == prefix then
						table.insert(keys, key)
					end
				end
				-- Shortest potion first, so long ones are kept for later.
				table.sort(keys, function(a, b)
					return (tonumber(string.match(a, ":(%d+)")) or 0) < (tonumber(string.match(b, ":(%d+)")) or 0)
				end)
				return keys
			end
			local function use(key, label)
				local ok = request("UseItem", { key = key })
				if ok then
					items[key] = (tonumber(items[key]) or 1) - 1
					noteActivity("Used " .. label)
				end
				task.wait(0.4)
				return ok
			end
			if STATE.autoPotions == true then
				-- Luck only helps while throwing, 2x XP only while training,
				-- 2x Money always.
				local wanted = { Money = true }
				-- (Not while Auto Complete Index hunts commons: more luck makes
				-- commons harder to roll.)
				if STATE.mode == "throw" and not indexHunt.huntingLow() then
					wanted.Luck2, wanted.Luck5 = true, true
				elseif STATE.mode == "train" then
					wanted.Train = true
				end
				for _, kind in ipairs({ "Luck5", "Luck2", "Money", "Train" }) do
					if wanted[kind] and boostLeft(kind) <= 0 then
						local key = owned(kind)[1]
						if key then
							use(key, kind == "Train" and "2x XP potion" or (kind == "Money" and "2x Money potion" or (kind == "Luck5" and "5x Luck potion" or "2x Luck potion")))
						end
					end
				end
			end
			-- Lucky Throws (50x and 10x luck on one throw): save them for a 5x Luck
			-- potion when you have one, then load one at a time so each lands
			-- inside the boost. Without 5x potions they are used straight away.
			if STATE.useLuckyThrows == true and STATE.mode == "throw" and not indexHunt.huntingLow() then
				local loaded = (tonumber(attr("LuckyThrows")) or 0) + (tonumber(attr("LuckyThrows10")) or 0)
				local lucky = (tonumber(items.Lucky) or 0) > 0 and "Lucky" or ((tonumber(items.Lucky10) or 0) > 0 and "Lucky10" or nil)
				if loaded == 0 and lucky then
					local luck5Left = boostLeft("Luck5")
					local hasLuck5 = #owned("Luck5") > 0
					if luck5Left <= 15 and hasLuck5 then
						-- Start a 5x Luck potion for them (Auto Use Potions may be off).
						use(owned("Luck5")[1], "5x Luck potion for Lucky Throws")
						luck5Left = boostLeft("Luck5")
					end
					if luck5Left > 15 or not hasLuck5 then
						-- One throw per server wait: load as many as fit in the boost (max 3).
						local fit = luck5Left > 15 and math.clamp(math.floor((luck5Left - 10) / math.max(8, throwState.learned)), 1, 3) or 1
						for _ = 1, fit do
							lucky = (tonumber(items.Lucky) or 0) > 0 and "Lucky" or ((tonumber(items.Lucky10) or 0) > 0 and "Lucky10" or nil)
							if not lucky or not use(lucky, lucky == "Lucky" and "Lucky Throw (50x luck)" or "Lucky Throw (10x luck)") then
								break
							end
						end
					end
				end
			end
		end
	end
	STATE.rewardStatus = #notes > 0 and table.concat(notes, " · ") or "On"
end

-- Harvest update ---------------------------------------------------------------
local harvestWait = 0
local harvestBasketTrip = -math.huge
local function harvestCounts()
	local found, zones, total = 0, {}, 0
	local have = type(ClientState.index) == "table" and ClientState.index or {}
	for _, plant in ipairs(Balance.Harvest and Balance.Harvest.plants or {}) do
		total += 1
		if have[plant.name] then
			found += 1
			zones[plant.zone] = true
		end
	end
	local zoneCount = 0
	for _ in pairs(zones) do
		zoneCount += 1
	end
	return found, total, zoneCount
end

local function stepHarvest()
	if not Balance.Harvest or os.clock() < harvestWait then
		return
	end
	harvestWait = os.clock() + 4
	local now = workspace:GetServerTimeNow()
	local eventUntil = tonumber(workspace:GetAttribute("HarvestUntil")) or 0
	local standOpen = attr("HarvestStand") == true and now < eventUntil + (tonumber(Balance.Harvest.StandDays) or 3) * 86400
	local notes = {}
	local found, total, zones = harvestCounts()
	local cranberries = tonumber(attr("Cranberries")) or 0
	local step = tonumber(attr("HarvestStep")) or 0
	table.insert(notes, string.format("Index %d/%d · zones %d/17 · %d Cranberries", found, total, zones, cranberries))

	-- The server only takes the basket next to it (it sits at your plot) and
	-- only takes Cranberries in / sells rewards next to Farmer Hazel, so both
	-- are short trips: basket -> Hazel (hand it in) -> buy what you can afford.
	local stand = Balance.Harvest.Stand or {}
	local function hazelCFrame()
		local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("HarvestStand")
		local hazel = folder and folder:FindFirstChild("FarmerHazel")
		local root = hazel and (hazel:FindFirstChild("RootPart") or hazel.PrimaryPart)
		local standAt = typeof(Balance.Harvest.StandAt) == "CFrame" and Balance.Harvest.StandAt.Position or nil
		local at = root and root.Position or standAt
		if root and standAt then
			-- Stand between Hazel and the counter: buying checks the counter,
			-- handing in checks Hazel (a buy from beside Hazel was refused once).
			at = (root.Position + standAt) / 2
		end
		return at and CFrame.lookAt(at + Vector3.new(0, 3, 4), at + Vector3.new(0, 3, 0)) or nil
	end
	local function buyAtStand()
		local bought = 0
		while bought < #stand and running() do
			local current = tonumber(attr("HarvestStep")) or 0
			local reward = stand[current + 1]
			if not reward or (tonumber(attr("Cranberries")) or 0) < (tonumber(reward.price) or math.huge) then
				break
			end
			local ok, result = request("HarvestBuy")
			if not ok then
				table.insert(notes, "Stand: " .. tostring(result or "not bought"))
				break
			end
			bought += 1
			noteActivity(reward.mutation and "Bought Harvest Mutation" or ("Bought Harvest reward " .. (current + 1)))
			table.insert(notes, reward.mutation and "Harvest Mutation bought" or ("Stand reward " .. (current + 1) .. " bought"))
		end
	end

	local basket = tonumber(attr("Basket")) or 0
	local held = tonumber(attr("BasketHeld")) or 0
	local basketDue = STATE.autoHarvestBasket == true and attr("HarvestOk") == true
		and (held > 0 or (basket > 0 and os.clock() - harvestBasketTrip > 300))
	local nextReward = stand[step + 1]
	local canBuy = STATE.autoHarvestShop == true and standOpen and nextReward ~= nil
		and cranberries + basket >= (tonumber(nextReward.price) or math.huge)
	if basketDue or (canBuy and cranberries >= (tonumber(nextReward.price) or math.huge)) then
		harvestBasketTrip = os.clock()
		local before = cranberries
		if basketDue and held == 0 then
			local basketPart = workspace:FindFirstChild("HarvestPlot")
			basketPart = basketPart and basketPart:FindFirstChild("CranberryBasket")
			basketPart = basketPart and (basketPart:FindFirstChild("Root") or basketPart.PrimaryPart)
			if basketPart then
				withTrip(CFrame.new(basketPart.Position + Vector3.new(0, 3, 4)), function()
					local ok, result = request("HarvestBasket")
					if not ok then
						table.insert(notes, "Basket: " .. tostring(result or "not ready"))
					end
				end)
			end
		end
		withTrip(hazelCFrame(), function()
			if (tonumber(attr("BasketHeld")) or 0) > 0 then
				local ok, result = request("HarvestHazel")
				local deposited = ok and type(result) == "table" and tonumber(result.deposited) or 0
				if deposited > 0 then
					noteActivity("Handed in Harvest basket (+" .. deposited .. " Cranberries)")
					table.insert(notes, "Basket handed in (+" .. deposited .. ")")
				elseif not ok then
					table.insert(notes, "Hazel: " .. tostring(result or "try again"))
				end
			end
			if STATE.autoHarvestShop == true and standOpen then
				buyAtStand()
			end
		end)
		cranberries = tonumber(attr("Cranberries")) or before
		step = tonumber(attr("HarvestStep")) or step
		nextReward = stand[step + 1]
		harvestWait = os.clock() + 8
	end

	if nextReward then
		table.insert(notes, string.format("Next stand reward %d/%d: %d Cranberries", step + 1, #Balance.Harvest.Stand, nextReward.price))
	else
		table.insert(notes, "Harvest Stand complete")
	end

	local moon, startsAt, endsAt = Balance.HarvestMoon(now)
	if attr("HarvestOk") == true and startsAt and endsAt then
		if startsAt <= now and now < endsAt then
			table.insert(notes, string.format("Harvest Moon active · %d:%02d left%s", math.floor(endsAt - now) // 60, math.floor(endsAt - now) % 60,
				eventAim.target and (" · targeting " .. eventAim.target .. " at " .. tostring(eventAim.power) .. "%") or ""))
		else
			table.insert(notes, string.format("Next moon in %d:%02d", math.max(0, math.floor(startsAt - now)) // 60, math.max(0, math.floor(startsAt - now)) % 60))
		end
	elseif standOpen then
		table.insert(notes, "Harvest event ended · Stand still open")
	else
		table.insert(notes, "Harvest event is closed")
	end
	STATE.harvestMoon = moon
	STATE.harvestStatus = table.concat(notes, "\n")
end

local function abuseStatusText()
	local now = workspace:GetServerTimeNow()
	local lines, boosts, events = {}, {}, {}
	for _, kind in ipairs({ "Cash", "Luck", "Train", "Mutation", "Throw", "Jackpot", "AfterParty" }) do
		local untilAt = tonumber(workspace:GetAttribute("Abuse" .. kind .. "Until")) or 0
		if untilAt > now then
			local mult = tonumber(workspace:GetAttribute("Abuse" .. kind .. "Mult"))
			local left = math.max(0, math.floor(untilAt - now))
			table.insert(boosts, string.format("%s%s %d:%02d", mult and ("x" .. tostring(mult) .. " ") or "", kind, left // 60, left % 60))
		end
	end
	for kind, data in pairs(abuse.active) do
		if not data.ends or now < data.ends then
			local left = data.ends and math.max(0, math.floor(data.ends - now)) or 0
			table.insert(events, abuseEventName(kind) .. (data.ends and string.format(" %d:%02d", left // 60, left % 60) or ""))
		end
	end
	table.sort(events)
	table.insert(lines, #boosts > 0 and ("Boosts: " .. table.concat(boosts, " · ")) or "No admin boost active")
	table.insert(lines, #events > 0 and ("Events: " .. table.concat(events, " · ")) or "No admin event active")
	table.insert(lines, string.format("Event rewards collected: %d · %s", abuse.collected, abuse.lastResult))
	if STATE.priorityReason then
		table.insert(lines, "Farm priority: " .. STATE.priorityReason)
	end
	return table.concat(lines, "\n")
end

-- XP offers (the purple "2x" bubble) pop up while training. Tap the bubble the
-- way a player would, so the game claims it and clears it from the screen at
-- once; if that doesn't land, claim it straight from the server. The server's
-- "XPBoost" reply is what counts a claim.
do
	local pendingXp = {}

	local function findXpBubble()
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		if not pg then
			return nil
		end
		for _, gui in ipairs(pg:GetChildren()) do
			local bubble = gui:FindFirstChild("XPOffer", true)
			if bubble and bubble:IsA("GuiButton") then
				return bubble
			end
		end
		return nil
	end

	trackConnection(NotifyRemote.OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" or data.id == nil then
			return
		end
		if kind == "XPBoost" then
			if pendingXp[data.id] then
				pendingXp[data.id] = nil
				STATE.xpOffers = (STATE.xpOffers or 0) + 1
			end
		elseif kind == "XPOffer" and STATE.autoXpOffers == true then
			local id = data.id
			pendingXp[id] = true
			task.delay(8, function()
				pendingXp[id] = nil
			end)
			task.delay(0.35, function()
				if not running() or not pendingXp[id] then
					return
				end
				local bubble = findXpBubble()
				if bubble then
					pcall(function()
						for _, conn in ipairs(getconnections(bubble.Activated)) do
							conn:Fire()
						end
					end)
				end
				task.wait(1.2)
				if running() and pendingXp[id] then
					request("XPBoost", { id = id })
				end
			end)
		end
	end))
end

-- Player -----------------------------------------------------------------------
local function stepSpeed()
	local _, hum = character()
	if hum and STATE.walkSpeed == true then
		hum.WalkSpeed = tonumber(STATE.speed) or 32
	end
end

local function pulseAntiAfk()
	if not running() or STATE.antiAfk ~= true then
		return
	end
	pcall(function()
		local virtual = game:GetService("VirtualUser")
		virtual:CaptureController()
		virtual:ClickButton2(Vector2.new(-1, -1))
	end)
	pcall(function()
		local mouse = UserInputService:GetMouseLocation()
		game:GetService("VirtualInputManager"):SendMouseMoveEvent(mouse.X, mouse.Y, game)
	end)
	pcall(function()
		HereRemote:FireServer()
	end)
end
trackConnection(LocalPlayer.Idled:Connect(pulseAntiAfk))

function STATE.apply3d()
	pcall(RunService.Set3dRenderingEnabled, RunService, STATE.disable3d ~= true)
end
hubCleanup(function()
	pcall(RunService.Set3dRenderingEnabled, RunService, true)
end)

function STATE.teleport(kind)
	if kind == "garden" then
		local plot = myPlot()
		local fence = plot and plot:FindFirstChild("Fence")
		if fence then
			local center = fence:GetBoundingBox().Position
			moveTo(CFrame.lookAt(Vector3.new(center.X, center.Y + 3, center.Z - 17), Vector3.new(center.X, center.Y + 3, center.Z + 10)), 1)
		end
	elseif kind == "strip" then
		moveTo(throwSpot(), 1)
	elseif kind == "bar" then
		local spot = trainSpot()
		if spot then
			moveTo(spot.WorldCFrame * CFrame.new(0, 0, 3), 1)
		end
	end
end

function STATE.rejoin()
	game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

function STATE.hop()
	local ok, body = pcall(function()
		return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
	end)
	if ok then
		local decoded = HttpService:JSONDecode(body)
		local options = {}
		for _, server in ipairs(decoded and decoded.data or {}) do
			if server.id ~= game.JobId and (server.playing or 0) < (server.maxPlayers or 0) then
				table.insert(options, server.id)
			end
		end
		if #options > 0 then
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, options[math.random(1, #options)], LocalPlayer)
			return true
		end
	end
	return false
end

-- Reload the hub after a server change (rejoin, hop, update shutdown).
do
	local queueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	local RELOAD = [==[
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(4)
if getgenv().ZinoosSeedGen ~= nil then return end
local ok, source = pcall(function()
	return game:HttpGet("https://raw.githubusercontent.com/yszvzms6st-pixel/ZinoosHub/refs/heads/main/games/ThrowASeed.luau")
end)
if ok and type(source) == "string" and #source > 1000 and getgenv().ZinoosSeedGen == nil then
	local chunk = loadstring(source, "=ZinoosHub/ThrowASeed.luau")
	if chunk then chunk() end
end
]==]
	STATE.autoReloadAvailable = typeof(queueTeleport) == "function"
	local queued = false
	trackConnection(LocalPlayer.OnTeleport:Connect(function(teleportState)
		if queued or not running() or STATE.autoReload ~= true or not STATE.autoReloadAvailable then
			return
		end
		if teleportState == Enum.TeleportState.Started or teleportState == Enum.TeleportState.InProgress then
			queued = pcall(queueTeleport, RELOAD)
		end
	end))
end

-- Menu -----------------------------------------------------------------------
local WINDUI_URL = "https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua"

local function loadWindUI()
	local source = genv.ZinoosWindUISource
	if type(source) ~= "string" or #source < 1000 then
		local ok, body = pcall(function()
			return game:HttpGet(WINDUI_URL)
		end)
		elevate()
		if not ok or type(body) ~= "string" or #body < 1000 then
			return nil, "download failed"
		end
		source = body
		genv.ZinoosWindUISource = source
	end
	local chunk, compileError = loadstring(source, "=WindUI")
	if not chunk then
		genv.ZinoosWindUISource = nil
		return nil, compileError
	end
	local ok, library = pcall(chunk)
	elevate()
	if not ok or type(library) ~= "table" then
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
		warn("[Zinoos hub] Menu could not load (" .. tostring(loadError) .. "). Farming still runs with your saved settings.")
		return
	end
	pcall(WindUI.AddTheme, WindUI, ZINOOS_THEME)
	pcall(WindUI.SetNotificationLower, WindUI, true)
	elevate()

	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local small = touch or view.X < 900 or view.Y < 560
	local themeName = type(STATE.windTheme) == "string" and STATE.windTheme ~= "" and STATE.windTheme or "Zinoos"
	if type(WindUI.Themes) == "table" and WindUI.Themes[themeName] == nil then
		themeName = "Zinoos"
	end

	local Window = WindUI:CreateWindow({
		Title = "Zinoos Hub",
		Icon = "sprout",
		Author = "Throw a Seed",
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
			Icon = "sprout",
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

	-- The scale must be final before any tab exists (WindUI measures each box
	-- once with the scale its tab was made at).
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
	pcall(Window.Tag, Window, { Title = "v" .. VERSION, Color = Color3.fromHex("#8268FF") })
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
		-- The close button removes the window: treat it as unloading the hub.
		if not windowGone then
			windowGone = true
			if running() then
				task.defer(unloadHub)
			end
		end
	end)

	local lastToastKey, lastToastAt = nil, 0
	STATE.toast = function(title, message)
		local key = tostring(title) .. "\0" .. tostring(message)
		if key == lastToastKey and os.clock() - lastToastAt < 1.5 then
			return
		end
		lastToastKey, lastToastAt = key, os.clock()
		task.spawn(function()
			elevate()
			pcall(WindUI.Notify, WindUI, { Title = tostring(title), Content = tostring(message), Icon = "sprout", Duration = 4.5 })
		end)
	end

	-- Control helpers ------------------------------------------------------
	local syncToggle
	local dropdowns = {}

	local function onToggle(key, on)
		STATE[key] = on
		if key == "autoThrow" and on then
			STATE.autoTrain = false
			if syncToggle then syncToggle("autoTrain") end
		elseif key == "autoTrain" and on then
			STATE.autoThrow = false
			if syncToggle then syncToggle("autoThrow") end
		elseif key == "autoTrain" and not on then
			task.spawn(stopTraining)
		elseif key == "cycleTrain" then
			cycle.endsAt = 0
			if not on then
				task.spawn(stopTraining)
			end
		elseif key == "disable3d" then
			STATE.apply3d()
		elseif key == "indexHunt" then
			indexHunt.planKey = ""
			if not on then
				indexHunt.plan = nil
				task.spawn(indexHunt.restore)
			end
		elseif key == "walkSpeed" and not on then
			local _, hum = character()
			if hum then hum.WalkSpeed = 16 end
		elseif key == "autoSell" and on then
			task.defer(notify, "Auto Sell is on", "Sells stored " .. (#STATE.sellRarities > 0 and table.concat(STATE.sellRarities, ", ") or "(none picked)") .. " plants. Placed, mutated and big plants are kept.")
		elseif key == "antiAfk" and on then
			task.defer(pulseAntiAfk)
		end
		elevate()
		saveConfig()
	end

	local function toggle(parent, title, key, desc)
		local element = parent:Toggle({
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
		STATE.toggleControls[key] = { element = element }
		return element
	end

	syncToggle = function(key)
		local control = STATE.toggleControls[key]
		local element = control and control.element
		if element and element.Value ~= (STATE[key] == true) then
			elevate()
			pcall(element.Set, element, STATE[key] == true, false)
		end
	end
	STATE.syncToggle = syncToggle

	local function optionName(value)
		if type(value) == "table" then
			return value.Title or value.Name
		end
		return value
	end

	local function choice(parent, title, desc, options, key, after)
		local element = parent:Dropdown({
			Title = title,
			Desc = desc,
			Values = options,
			Value = tostring(STATE[key]),
			Callback = function(value)
				value = optionName(value)
				if type(value) ~= "string" or value == tostring(STATE[key]) then
					return
				end
				elevate()
				if type(STATE[key]) == "number" then
					STATE[key] = tonumber(value) or STATE[key]
				else
					STATE[key] = value
				end
				saveConfig()
				if after then after(value) end
			end,
		})
		table.insert(dropdowns, { element = element, get = function() return tostring(STATE[key]) end })
		return element
	end

	local function multiChoice(parent, title, desc, options, key)
		local element = parent:Dropdown({
			Title = title,
			Desc = desc,
			Values = options,
			Value = table.clone(STATE[key]),
			Multi = true,
			AllowNone = true,
			Callback = function(list)
				local chosen = {}
				for _, value in ipairs(type(list) == "table" and list or {}) do
					local name = optionName(value)
					if type(name) == "string" then
						chosen[name] = true
					end
				end
				local ordered = {}
				for _, option in ipairs(options) do
					if chosen[option] then
						table.insert(ordered, option)
					end
				end
				if table.concat(ordered, ",") == table.concat(STATE[key], ",") then
					return
				end
				elevate()
				STATE[key] = ordered
				saveConfig()
			end,
		})
		table.insert(dropdowns, { element = element, get = function() return table.clone(STATE[key]) end })
		return element
	end

	local function slider(parent, title, desc, key, min, max, step)
		return parent:Slider({
			Title = title,
			Desc = desc,
			Step = step or 1,
			Value = { Min = min, Max = max, Default = tonumber(STATE[key]) or min },
			Callback = function(value)
				value = tonumber(value)
				if not value or value == STATE[key] then
					return
				end
				STATE[key] = value
				if key == "cycleTrainMinutes" or key == "cycleThrowMinutes" then
					cycle.endsAt = 0
				end
				saveConfig()
			end,
		})
	end

	-- WindUI measures a box once; re-measure boxes on screen when their text
	-- changes so nothing gets cut off.
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
		if not box or windowGone or box.Opened ~= true or not isShown(box) then
			return
		end
		elevate()
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
		local paragraph = parent:Paragraph({ Title = title, Desc = text })
		liveText[paragraph] = text
		if type(parent) == "table" and parent.__type == "Section" then
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
		return parent:Button({
			Title = title,
			Desc = desc,
			Icon = icon,
			Callback = function()
				elevate()
				task.spawn(function()
					local ok, err = pcall(callback)
					if not ok then
						notify(title .. " failed", tostring(err))
					end
				end)
			end,
		})
	end

	local function section(tab, title, icon)
		local box = tab:Section({ Title = title, Icon = icon, Box = true, Opened = true })
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

	-- Tabs -----------------------------------------------------------------
	local homeTab = Window:Tab({ Title = "Home", Icon = "house" })
	local farmTab = Window:Tab({ Title = "Farming", Icon = "target" })
	local eventTab = Window:Tab({ Title = "Events", Icon = "sparkles" })
	local upgradeTab = Window:Tab({ Title = "Upgrades", Icon = "trending-up" })
	local gardenTab = Window:Tab({ Title = "Garden", Icon = "flower-2" })
	local historyTab = Window:Tab({ Title = "History", Icon = "history" })
	local rewardTab = Window:Tab({ Title = "Rewards", Icon = "gift" })
	local playerTab = Window:Tab({ Title = "Player", Icon = "user" })
	local settingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
	elevate()

	-- Home
	local overview = info(homeTab, "Overview", "Loading your stats...")
	button(homeTab, "Start / Stop Farming", "Turns Auto Throw on or off", "power", function()
		onToggle("autoThrow", STATE.autoThrow ~= true)
		syncToggle("autoThrow")
		syncToggle("autoTrain")
		notify(STATE.autoThrow and "Farming started" or "Farming stopped", STATE.autoThrow and "Auto Throw is on" or "Auto Throw is off")
	end)
	local sessionBox = section(homeTab, "This Session", "chart-column")
	local sessionInfo = info(sessionBox, "Throws", "No throws yet")
	local recentInfo = info(sessionBox, "Recent Plants", "Nothing yet")
	local activityBox = section(homeTab, "Activity", "activity")
	local activityInfo = info(activityBox, "Live", "Starting...")
	local communityBox = section(homeTab, "Community", "message-circle")
	button(communityBox, "Copy Discord Invite", "discord.gg/94pC3T6NZG", "copy", function()
		local invite = "https://discord.gg/94pC3T6NZG"
		if typeof(setclipboard) == "function" and pcall(setclipboard, invite) then
			notify("Invite copied", "Paste it in your browser")
		else
			notify("Discord invite", invite)
		end
	end)

	-- Farming
	local throwBox = section(farmTab, "Throwing", "target")
	local throwInfo = info(throwBox, "Status", "Waiting")
	toggle(throwBox, "Auto Throw", "autoThrow", "PERFECT throw every time, no throw screen")
	toggle(throwBox, "Show Throw Animation", "showAnimation", "Plays the game's real throw, flight and reveal (still PERFECT, presses Throw Again for you). Slower: about 15-35s a throw")
	slider(throwBox, "Slowest Throw Pace (seconds)", "The hub learns the server wait (about 6.6s) and never goes faster. Raise it to look more human", "throwGap", 5.5, 20, 0.5)
	local trainBox = section(farmTab, "Training", "dumbbell")
	local trainInfo = info(trainBox, "Status", "Off")
	toggle(trainBox, "Auto Train", "autoTrain", "Does pull-ups on your bar for strength (stops Auto Throw)")
	toggle(trainBox, "Train & Throw Cycle", "cycleTrain", "Trains, then throws, on repeat with the timers below")
	slider(trainBox, "Train For (minutes)", nil, "cycleTrainMinutes", 1, 30, 1)
	slider(trainBox, "Throw For (minutes)", nil, "cycleThrowMinutes", 1, 30, 1)
	toggle(trainBox, "Timer On Screen", "showCycleTimer", "Small Training / Throwing countdown (and the live index tracker) in the top-right of your game screen")
	toggle(trainBox, "Auto Tap 2x XP Bubbles", "autoXpOffers", "Taps the purple 2x bubble the moment it pops up while training")

	-- Events
	local abuseBox = section(eventTab, "Admin Abuse", "zap")
	local abuseInfo = info(abuseBox, "Live Status", "Watching for admin events...")
	toggle(abuseBox, "Auto Admin Abuse", "autoAdminAbuse", "Uses active Luck, Mutation, Throw, Train and 25x Jackpot boosts in the best farming mode")
	toggle(abuseBox, "Auto Collect Event Drops", "autoAbuseDrops", "Collects Lucky Dice, cash rain, storm potions, turkeys, treasure and Colossus drops up to each server cap")
	toggle(abuseBox, "Auto King Of The Crown", "autoAbuseCrown", "Chases and takes the crown for the longest-hold reward")
	toggle(abuseBox, "Auto Pie Fight", "autoPieFight", "Targets nearby players and throws pies for the hit reward")
	info(abuseBox, "Automatic Events", "Cash Nuke, Giveaway and UFO rewards are server-awarded automatically. Fireworks, Big Tom Peek, Big Heads and Disco are visual events with nothing to claim.")
	local harvestBox = section(eventTab, "Harvest Update", "moon-star")
	local harvestInfo = info(harvestBox, "Live Status", "Checking Harvest...")
	toggle(harvestBox, "Auto Harvest Moon", "autoHarvestMoon", "Forces throwing during each moon and targets an active beam, preferring zones missing from your Harvest Index")
	toggle(harvestBox, "Auto Collect Cranberry Basket", "autoHarvestBasket", "Collects the basket on your plot whenever it has Cranberries")
	toggle(harvestBox, "Auto Buy Harvest Stand", "autoHarvestShop", "Buys all seven limited rewards in order whenever you have enough Cranberries, including the final Harvest Mutation")

	-- Upgrades
	local upgradeBox = section(upgradeTab, "Auto Buy", "shopping-cart")
	local upgradeInfo = info(upgradeBox, "Status", "Waiting")
	toggle(upgradeBox, "Auto Buy Seeds", "autoSeed", "Next seed = more luck. The best one is always equipped")
	toggle(upgradeBox, "Auto Buy Bars", "autoBar", "Next pull-up bar = more strength per rep")
	toggle(upgradeBox, "Auto Buy Bigger Garden", "autoCapacity", "More garden spots = more money per second")
	choice(upgradeBox, "Keep Cash", "Never spend below this", CASH_RESERVE_OPTIONS, "cashReserve")
	local nowBox = section(upgradeTab, "Current", "info")
	local currentInfo = info(nowBox, "Gear", "Loading...")

	-- Garden
	local gardenBox = section(gardenTab, "Garden", "flower-2")
	local gardenInfo = info(gardenBox, "Status", "Waiting")
	toggle(gardenBox, "Auto Place Best", "autoPlace", "Keeps your best plants in the garden")
	-- One box for everything that fuses or sells stored plants.
	local sellBox = section(gardenTab, "Fuse & Sell", "badge-dollar-sign")
	toggle(sellBox, "Fuse Or Sell Leftovers (Best)", "smartStorage", "Fuses 3 plants only when the result is sure to go into your garden, sells the rest. While on, the manual options below are skipped")
	toggle(sellBox, "Keep Duplicates For Trading", "keepTradeDupes", "Keeps exact copies (same plant, mutation and size) of plants in your garden instead of selling them")
	slider(sellBox, "Spares Of Each Kind", "How many copies of each garden plant to keep for trading", "tradeSpares", 1, 20, 1)
	choice(sellBox, "Always Keep Mutations", "Every plant with this mutation or rarer is kept, never sold or fused", KEEP_MUTATION_OPTIONS, "keepMutationMin")
	info(sellBox, "Always Safe", "Plants in your garden, the one in your hand and Secret plants are never sold or fused. Your index stays either way.")
	info(sellBox, "Or Set It Up Yourself", "Turn the switch above off to use these instead.")
	toggle(sellBox, "Auto Fuse", "autoFuse", "Fuses 3 weak stored plants into a stronger one")
	choice(sellBox, "Fuse Up To", "Highest rarity that gets fused", FUSE_OPTIONS, "fuseMaxRarity")
	toggle(sellBox, "Auto Sell", "autoSell", "Sells stored plants of the rarities below")
	multiChoice(sellBox, "Sell Rarities", nil, RARITIES, "sellRarities")
	toggle(sellBox, "Keep Mutated Plants", "keepMutations", "Gold, Diamond, Emerald, Ruby and Rainbow are never fused or sold by the manual options")
	toggle(sellBox, "Keep Huge And Bigger", "keepBigSizes", "Huge, Massive and bigger are never fused or sold by the manual options")
	local indexBox = section(gardenTab, "Index", "book-open")
	local indexInfo = info(indexBox, "Progress", "Loading...")
	-- History
	local historyBox = section(historyTab, "Catch History", "history")
	local historySummary = info(historyBox, "All Time", history.summaryText())
	choice(historyBox, "Show", "Which catches the list below shows", HISTORY_FILTERS, "historyFilter", function()
		history.version += 1
	end)
	button(historyBox, "Clear History", "Deletes the saved list and totals", "trash-2", function()
		confirm("Clear your catch history?", "The list and all-time totals are deleted. Your plants are not touched.", function()
			history.clear()
		end)
	end)
	local historyListBox = section(historyTab, "Latest Catches", "list")
	local historyList = info(historyListBox, "Newest First (last 30)", history.listText(tostring(STATE.historyFilter), 30))
	local historyDrawn, historyDrawnAt = -1, 0
	local drawRows = nil
	task.defer(function()
		local ok, update = pcall(history.buildList, historyList, "Newest First (last 30)")
		if ok and type(update) == "function" then
			drawRows = update
			historyDrawn = -1
			setInfo(historyList, "Scroll the list. The picture ring shows the mutation; garden / kept / sold is where the plant is now.")
			queueReflow(historyListBox)
		end
	end)
	STATE.drawHistory = function()
		if history.version == historyDrawn and os.clock() - historyDrawnAt < 10 then
			return
		end
		historyDrawn, historyDrawnAt = history.version, os.clock()
		setInfo(historySummary, history.summaryText())
		if drawRows then
			local ok = pcall(drawRows, tostring(STATE.historyFilter), 30)
			if not ok then
				drawRows = nil
			end
		else
			setInfo(historyList, history.listText(tostring(STATE.historyFilter), 30))
		end
		history.save()
	end

	toggle(indexBox, "Auto Complete Index", "indexHunt", "On throwing turns, sets Throw Power and seed for the best chance of plants you're missing (low power for commons), then goes back to 100% and your best seed")

	-- Rewards
	local rewardBox = section(rewardTab, "Free Rewards", "gift")
	local rewardInfo = info(rewardBox, "Status", "Waiting")
	toggle(rewardBox, "Auto Daily Reward", "autoDaily")
	toggle(rewardBox, "Auto Playtime Gifts", "autoGifts")
	toggle(rewardBox, "Auto Redeem Codes", "autoCodes", "Redeems every code in the game once")
	toggle(rewardBox, "Auto Collect Offline Cash", "autoOffline")
	toggle(rewardBox, "Auto Use Potions", "autoPotions", "Luck potions while throwing, 2x XP while training, 2x Money any time; never stacks the same boost")
	toggle(rewardBox, "Use Lucky Throws", "useLuckyThrows", "Uses your 50x and 10x Lucky Throws, timed inside a 5x Luck potion when you have one")
	button(rewardBox, "Redeem Codes Now", nil, "ticket", function()
		STATE.redeemedCodes = {}
		table.clear(codeTries)
		codesDone = false
		rewardWait = 0
		local was = STATE.autoCodes
		STATE.autoCodes = true
		stepRewards()
		STATE.autoCodes = was
		notify("Codes", "Tried every code")
	end)
	local alertBox = section(rewardTab, "Alerts", "bell")
	toggle(alertBox, "Notifications", "notifications")
	choice(alertBox, "Alert From Rarity", "Pop-up for plants this rare or better", NOTIFY_OPTIONS, "notifyMinRarity")
	toggle(alertBox, "Alert New Index Plants", "notifyNew")
	toggle(alertBox, "Alert Mutations", "notifyMutations")

	-- Player
	local moveBox = section(playerTab, "Movement", "footprints")
	toggle(moveBox, "Walk Speed", "walkSpeed")
	choice(moveBox, "Speed", nil, SPEED_OPTIONS, "speed")
	button(moveBox, "Go To Garden", nil, "house", function() STATE.teleport("garden") end)
	button(moveBox, "Go To Launch Strip", nil, "target", function() STATE.teleport("strip") end)
	button(moveBox, "Go To Pull-up Bar", nil, "dumbbell", function() STATE.teleport("bar") end)
	local afkBox = section(playerTab, "AFK", "moon")
	toggle(afkBox, "Anti AFK", "antiAfk", "Stops the 20 minute idle kick")
	toggle(afkBox, "AFK Black Screen", "disable3d", "Stops drawing the world to save battery and heat")
	toggle(afkBox, "Reload Hub After Server Change", "autoReload")
	local serverBox = section(playerTab, "Server", "server")
	button(serverBox, "Rejoin", nil, "rotate-ccw", STATE.rejoin)
	button(serverBox, "Server Hop", nil, "shuffle", function()
		if not STATE.hop() then
			notify("Server Hop", "No other server found")
		end
	end)

	-- Settings
	local lookBox = section(settingsTab, "Menu", "palette")
	local themes = {}
	if type(WindUI.Themes) == "table" then
		for name in pairs(WindUI.Themes) do
			table.insert(themes, name)
		end
		table.sort(themes)
	end
	if #themes == 0 then
		themes = { "Zinoos" }
	end
	choice(lookBox, "Theme", nil, themes, "windTheme", function(option)
		pcall(WindUI.SetTheme, WindUI, option)
	end)
	choice(lookBox, "Menu Size", nil, { "Compact", "Normal", "Large" }, "hubSize", function()
		rebuildMenu()
	end)
	choice(lookBox, "Open / Close Key (PC)", nil, KEY_OPTIONS, "toggleKey", function(option)
		pcall(Window.SetToggleKey, Window, Enum.KeyCode[option])
	end)
	toggle(lookBox, "Start Hidden", "hideOnStart", "Opens with the key or the Zinoos button")
	local configBox = section(settingsTab, "Config", "save")
	info(configBox, "Saving", "Changes save automatically for this Roblox account.")
	button(configBox, "Reset to Defaults", "Auto Sell turns off", "rotate-ccw", function()
		confirm("Reset every setting?", "All options go back to their defaults and Auto Sell turns off.", function()
			local defaults = {
				autoThrow = true, throwGap = 6, showAnimation = false, cycleTrain = true, cycleTrainMinutes = 5, cycleThrowMinutes = 2, showCycleTimer = true,
				autoTrain = false, autoXpOffers = true, autoSeed = true, autoBar = true, autoCapacity = true,
				cashReserve = "$0", autoPlace = true, autoFuse = false, fuseMaxRarity = "Uncommon",
				autoSell = false, sellRarities = { "Common" }, keepMutations = true, keepBigSizes = true, smartStorage = false, keepTradeDupes = true, tradeSpares = 3, keepMutationMin = "Ruby and up", indexHunt = false, historyFilter = "All",
				autoDaily = true, autoGifts = true, autoCodes = true, autoOffline = true, autoPotions = false, useLuckyThrows = false,
				autoAdminAbuse = true, autoAbuseDrops = true, autoAbuseCrown = true, autoPieFight = true,
				autoHarvestMoon = true, autoHarvestBasket = true, autoHarvestShop = true,
				notifications = true, notifyMinRarity = "Epic", notifyNew = true, notifyMutations = true,
				walkSpeed = false, speed = 32, antiAfk = true, autoReload = true, disable3d = false, hideOnStart = false,
			}
			for key, value in pairs(defaults) do
				STATE[key] = value
				syncToggle(key)
			end
			for _, entry in ipairs(dropdowns) do
				pcall(entry.element.Select, entry.element, entry.get())
			end
			cycle.endsAt = 0
			STATE.apply3d()
			saveConfig()
			notify("Defaults restored", "Auto Sell is off")
		end)
	end)
	button(configBox, "Unload Hub", "Stops everything and removes the menu", "log-out", function()
		confirm("Unload Zinoos Hub?", "All automation stops until you run the loader again.", function()
			task.defer(unloadHub)
		end)
	end)

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

	-- Live text --------------------------------------------------------------
	local function countSummary()
		local parts = {}
		for _, name in ipairs(RARITIES) do
			local count = stats.rarityCounts[name]
			if count and count > 0 then
				table.insert(parts, name .. " " .. count)
			end
		end
		return #parts > 0 and table.concat(parts, " · ") or "None yet"
	end

	local function refresh()
		local cash = money()
		stats.cash0 = stats.cash0 or cash
		local elapsed = math.max(0, os.time() - stats.started)
		local clock = elapsed >= 3600
			and string.format("%d:%02d:%02d", elapsed // 3600, elapsed % 3600 // 60, elapsed % 60)
			or string.format("%d:%02d", elapsed // 60, elapsed % 60)
		local found, total = indexCount()
		local seedIndex = tonumber(attr("Seed")) or 1
		local seed = Balance.Seeds[seedIndex]
		local bar = Balance.Bars[tonumber(attr("Bar")) or 1]
		local placed = placedStats()
		local capacity = tonumber(ClientState.capacity) or tonumber(attr("Capacity")) or 8
		local zone = ZoneConfig.List and ZoneConfig.List[tonumber(attr("ZoneReach")) or 1]
		local zoneName = zone and (zone.name or zone.Name) or ("Zone " .. tostring(attr("ZoneReach") or 1))
		local lucky = (tonumber(attr("LuckyThrows")) or 0) + (tonumber(attr("LuckyThrows10")) or 0)
		elevate()

		local mode = STATE.cycleTrain == true and ("Cycle · " .. STATE.cycleStatus)
			or (STATE.autoThrow == true and "Farming ON") or (STATE.autoTrain == true and "Training") or "Farming OFF"
		setInfo(overview, string.format(
			"%s\nMoney $%s · $%s/s · Strength %s · Level %s\nReach: %s · Seed: %s · Bar: %s\nGarden %d/%d · Index %d/%d%s",
			mode,
			shortNumber(cash),
			shortNumber(attr("Income")),
			shortNumber(attr("Strength")),
			tostring(attr("Level") or "?"),
			tostring(zoneName),
			seed and seed.name or "?",
			bar and bar.name or "?",
			placed,
			capacity,
			found,
			total,
			lucky > 0 and (" · Lucky Throws " .. lucky) or ""
		))
		local perHour = elapsed > 60 and math.floor(stats.throws / elapsed * 3600) or 0
		setInfo(sessionInfo, string.format(
			"%s session · %d throws (%d/h) · %d new plants · %d waits\nBest: %s\nRarities: %s\nCash made: $%s · spent on upgrades: $%s",
			clock, stats.throws, perHour, stats.newPlants, stats.rejected,
			stats.bestText, countSummary(), shortNumber(math.max(0, cash - (stats.cash0 or cash) + stats.spent)), shortNumber(stats.spent)
		))
		setInfo(recentInfo, #stats.recent > 0 and table.concat(stats.recent, "\n") or "Nothing yet")
		local lines = {
			"Throw · " .. tostring(STATE.throwStatus),
			"Train · " .. tostring(STATE.trainStatus),
			"Upgrades · " .. tostring(STATE.upgradeStatus),
			"Garden · " .. (string.gsub(tostring(STATE.gardenStatus), "\n", " · ")),
			"Rewards · " .. tostring(STATE.rewardStatus),
		}
		for _, item in ipairs(STATE.activity) do
			table.insert(lines, item)
		end
		setInfo(activityInfo, table.concat(lines, "\n"))
		setInfo(throwInfo, tostring(STATE.throwStatus) .. "\n" .. strengthLine())
		setInfo(trainInfo, tostring(STATE.trainStatus) .. (STATE.cycleTrain == true and ("\nCycle: " .. STATE.cycleStatus) or "") .. ((STATE.xpOffers or 0) > 0 and ("\n2x bubbles tapped: " .. STATE.xpOffers) or ""))
		setInfo(upgradeInfo, tostring(STATE.upgradeStatus))
		local nextSeedIndex, nextSeedEntry = nextSeed()
		local nextBarIndex, nextBarEntry = nextBar()
		local capCost = nextCapacityCost()
		setInfo(currentInfo, string.format(
			"Seed: %s (%sx luck)\nNext seed: %s\nBar: %s\nNext bar: %s\nGarden: %d spots · next spot %s",
			seed and seed.name or "?",
			seed and tostring(seed.luck) or "?",
			nextSeedIndex and (nextSeedEntry.name .. " $" .. shortNumber(nextSeedEntry.price)) or "All bought",
			bar and bar.name or "?",
			nextBarIndex and (nextBarEntry.name .. " $" .. shortNumber(nextBarEntry.price)) or "All bought",
			capacity,
			capCost and ("$" .. shortNumber(capCost)) or "maxed"
		))
		setInfo(gardenInfo, tostring(STATE.gardenStatus))
		setInfo(indexInfo, indexHunt.trackerText(found, total))
		setInfo(abuseInfo, abuseStatusText())
		setInfo(harvestInfo, tostring(STATE.harvestStatus))
		pcall(STATE.drawHistory)
		setInfo(rewardInfo, tostring(STATE.rewardStatus) .. string.format("\nCodes used: %d of %d", #STATE.redeemedCodes, (function()
			local n = 0
			for _ in pairs(Balance.Codes or {}) do n += 1 end
			return n
		end)()))
	end

	task.spawn(function()
		while running() and not windowGone do
			pcall(refresh)
			pcall(reflowShown)
			task.wait(1)
		end
	end)

	if STATE.hideOnStart == true then
		task.defer(function()
			elevate()
			pcall(Window.Close, Window)
		end)
	end
end

-- Start ----------------------------------------------------------------------
loadSaved()
startAbuseAutomation()

if running() then
	local ok, err = xpcall(installHub, debug.traceback)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
	end
end

-- Throwing / training loop.
task.spawn(function()
	while running() do
		local ok, pause = pcall(stepFarm)
		elevate()
		if not ok then
			STATE.throwStatus = "Error: " .. tostring(pause)
			pause = 2
		end
		task.wait(type(pause) == "number" and pause or 0.5)
	end
end)

-- Upgrades, garden and rewards.
task.spawn(function()
	if ownClientState then
		-- Our own copy of ClientState only hears changes; ask the server for
		-- the full list once so it starts complete.
		request("FullSync")
	end
	task.wait(2)
	while running() do
		pcall(stepUpgrades)
		elevate()
		pcall(stepGarden)
		elevate()
		pcall(stepRewards)
		elevate()
		pcall(stepHarvest)
		elevate()
		task.wait(1)
	end
end)

task.spawn(function()
	while running() do
		pcall(stepSpeed)
		task.wait(0.5)
	end
end)

task.spawn(function()
	while running() do
		task.wait(120)
		pulseAntiAfk()
	end
end)

-- On-screen cycle timer: a small pill in the top-right of the game screen that
-- counts down the Train & Throw turns while the menu is closed.
do
	local gui, timerPill, indexPill
	local function makePill(holder, order)
		local pill = Instance.new("Frame")
		pill.Name = "Pill" .. order
		pill.LayoutOrder = order
		pill.Size = UDim2.fromOffset(0, 34)
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
		pill.BackgroundTransparency = 0.15
		pill.Parent = holder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = pill
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = pill
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = pill
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 8)
		list.Parent = pill
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(10, 10)
		dot.LayoutOrder = 1
		dot.BorderSizePixel = 0
		dot.Parent = pill
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, 34)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 16
		label.TextColor3 = Color3.new(1, 1, 1)
		label.LayoutOrder = 2
		label.Text = ""
		label.Parent = pill
		return { frame = pill, dot = dot, label = label, stroke = stroke }
	end
	local function build()
		elevate()
		gui = Instance.new("ScreenGui")
		gui.Name = "ZinoosSeedTimer"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = false
		gui.DisplayOrder = 50
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local holder = Instance.new("Frame")
		holder.Name = "Holder"
		holder.AnchorPoint = Vector2.new(1, 0)
		holder.Position = UDim2.new(1, -12, 0, 8)
		holder.Size = UDim2.fromOffset(0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.XY
		holder.BackgroundTransparency = 1
		holder.Parent = gui
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Right
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 6)
		list.Parent = holder
		timerPill = makePill(holder, 1)
		indexPill = makePill(holder, 2)
		local placed = pcall(function()
			gui.Parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
		end)
		if not placed then
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		end
	end
	local function indexCounts()
		local found, total = 0, 0
		local have = type(ClientState.index) == "table" and ClientState.index or {}
		for _, names in ipairs(Balance.Plants or {}) do
			for _, name in ipairs(names) do
				total += 1
				if have[name] then
					found += 1
				end
			end
		end
		return found, total
	end
	hubCleanup(function()
		if gui then
			elevate()
			pcall(gui.Destroy, gui)
			gui = nil
		end
	end)
	task.spawn(function()
		local indexColor = Color3.fromHex("B05AFF")
		while running() do
			local showTimer = STATE.showCycleTimer ~= false and ((STATE.cycleTrain == true and cycle.endsAt > 0) or STATE.priorityReason ~= nil)
			-- The live index pill shows while Auto Complete Index is on.
			local showIndex = STATE.showCycleTimer ~= false and STATE.indexHunt == true
			if (showTimer or showIndex) and not gui then
				pcall(build)
			end
			if gui then
				local left = math.max(0, math.ceil(cycle.endsAt - os.clock()))
				local training = STATE.priorityReason and STATE.mode == "train" or cycle.phase == "train"
				local color = training and Color3.fromHex("FF9A2A") or Color3.fromHex("6BE34A")
				local indexText
				if showIndex then
					local found, total = indexCounts()
					indexText = string.format("INDEX  %d/%d", found, total)
					if found >= total then
						indexText ..= "  DONE"
					elseif indexHunt.huntingLow() and indexHunt.othersLeft and indexHunt.othersLeft[1] then
						indexText ..= "  · " .. indexHunt.othersLeft[1]
					end
				end
				elevate()
				pcall(function()
					gui.Enabled = showTimer or showIndex
					timerPill.frame.Visible = showTimer
					indexPill.frame.Visible = showIndex
					if showTimer then
						timerPill.label.Text = STATE.priorityReason and string.upper(STATE.priorityReason)
							or string.format("%s  %d:%02d", training and "TRAINING" or "THROWING", left // 60, left % 60)
						timerPill.dot.BackgroundColor3 = color
						timerPill.stroke.Color = color
					end
					if showIndex then
						indexPill.label.Text = indexText
						indexPill.dot.BackgroundColor3 = indexColor
						indexPill.stroke.Color = indexColor
					end
				end)
			end
			task.wait(0.25)
		end
	end)
end

pcall(STATE.apply3d)
hubCleanup(stopTraining)
notify("Zinoos Hub", "Throw a Seed hub v" .. VERSION .. " loaded")
