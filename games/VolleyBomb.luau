-- ZinoosHub for Volley Bomb.
-- Plays rallies for you with the game's own ball maths: walks under the ball,
-- bumps or jump-spikes it where the other player is not, dives for low balls,
-- serves, uses your ability, and claims every free reward. Menu: WindUI.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

if game.GameId ~= 10774204862 then
	warn("[Zinoos hub] This only runs in Volley Bomb.")
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
if typeof(genv.ZinoosVolleyStop) == "function" then
	pcall(genv.ZinoosVolleyStop)
	elevate()
end
genv.ZinoosVolleyGen = (typeof(genv.ZinoosVolleyGen) == "number" and genv.ZinoosVolleyGen or 0) + 1
local token = genv.ZinoosVolleyGen
local function running()
	return genv.ZinoosVolleyGen == token
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Game modules ---------------------------------------------------------------
local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Packages = ReplicatedStorage:WaitForChild("Packages", 30)
local Ball = require(Shared:WaitForChild("Modules"):WaitForChild("Ball"))
elevate()
local Net = require(Packages:WaitForChild("Net"))
elevate()
local replion = require(Packages:WaitForChild("replion"))
elevate()

-- The game keeps the live ball in its BallController. An executor's require()
-- can hand back a fresh copy, so prefer the copy the game itself uses.
local function findLive(keys, check)
	if typeof(filtergc) ~= "function" then
		return nil
	end
	local ok, list = pcall(filtergc, "table", { Keys = keys }, false)
	elevate()
	if not ok or type(list) ~= "table" then
		return nil
	end
	for _, candidate in ipairs(list) do
		if type(candidate) == "table" and check(candidate) then
			return candidate
		end
	end
	return nil
end
local Controllers = Shared:WaitForChild("Controllers")
local BallController = require(Controllers:WaitForChild("BallController"))
elevate()
if type(BallController._balls) ~= "table" or next(BallController._balls) == nil then
	BallController = findLive({ "_balls", "HitModifiers", "Swing" }, function(t)
		return type(t._balls) == "table" and next(t._balls) ~= nil
	end) or BallController
end
local AbilityController = require(Controllers:WaitForChild("AbilityController"))
elevate()
if type(AbilityController._lastUsed) ~= "table" then
	AbilityController = findLive({ "_lastUsed", "_active", "ActivateEquipped" }, function()
		return true
	end) or AbilityController
end

local Info = ReplicatedStorage:WaitForChild("Data"):WaitForChild("Info")
local function safeRequire(instance)
	local ok, result = pcall(require, instance)
	elevate()
	return ok and result or nil
end
local DailyRewards = safeRequire(ReplicatedStorage.Data:FindFirstChild("DailyRewards")) or {}
local QuestInfo = safeRequire(Info:FindFirstChild("Quests")) or {}
local AchievementConfig = safeRequire(Info:FindFirstChild("AchievementConfig")) or {}
local AbilityInfo = safeRequire(Info:FindFirstChild("Abilities")) or {}
local PackInfo = safeRequire(Info:FindFirstChild("Packs")) or {}
local AbilityModules = {}
do
	local folder = Shared:FindFirstChild("Modules") and Shared.Modules:FindFirstChild("Abilities")
	for _, module in ipairs(folder and folder:GetChildren() or {}) do
		AbilityModules[module.Name] = safeRequire(module)
	end
end

local VERSION = "1.3.0"
local STATE = {
	_gen = token,
	version = VERSION,
	-- Play
	autoHit = true,
	autoMove = true,
	autoSpike = true,
	autoDive = true,
	autoServe = true,
	smartAim = true,
	aimMode = "Hardest to save",
	autoAbility = true,
	showLanding = false,
	humanize = true,
	reaction = "Normal",
	combos = true,
	comboChance = "Often",
	autoVote = true,
	voteMode = "Solo",
	autoProServer = true,
	-- Shop
	autoBuyAbility = true,
	abilityGoal = "Guardian",
	autoEquipAbility = true,
	autoBuyPacks = true,
	saveForAbility = false,
	packChoice = "Both",
	-- Rewards
	autoDaily = true,
	autoQuests = true,
	autoAchievements = true,
	autoSpin = true,
	-- Player
	antiAfk = true,
	stayActive = true,
	autoReload = true,
	-- Alerts
	notifications = true,
	showTracker = true,
	-- Menu
	toggleKey = "RightControl",
	hideOnStart = false,
	hubSize = "Normal",
	windTheme = "Zinoos",
	-- Live
	status = "Starting...",
	playStatus = "Waiting for a round",
	rewardStatus = "Waiting",
	shopStatus = "Waiting",
	proStatus = "Checking...",
	toggleControls = {},
}
genv.ZinoosVolleyState = STATE

STATE.ownerUserId = 9346336323
STATE.admin = LocalPlayer.UserId == STATE.ownerUserId

local stats = {
	hits = 0,
	bumps = 0,
	spikes = 0,
	perfect = 0,
	dives = 0,
	serves = 0,
	started = os.time(),
	wins0 = nil,
	elims0 = nil,
	money0 = nil,
	lastHit = "None yet",
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
	if genv.ZinoosVolleyGen == token then
		genv.ZinoosVolleyGen = token + 1
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
genv.ZinoosVolleyStop = shutdownHub
local function unloadHub()
	shutdownHub()
end

-- Options --------------------------------------------------------------------
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
local AIM_OPTIONS = { "Hardest to save", "Fastest", "Random player" }
local REACTION_OPTIONS = { "Fast", "Normal", "Relaxed" }
local COMBO_OPTIONS = { "Sometimes", "Often", "Always" }
local COMBO_CHANCE = { Sometimes = 40, Often = 70, Always = 100 }
local VOTE_OPTIONS = { "Solo", "Duos", "Trios" }
local PACK_OPTIONS = { "Both", "Ball Pack", "Explosions Pack" }
local PACK_NAMES = { ["Ball Pack"] = { "Basic Ball Pack" }, ["Explosions Pack"] = { "Basic Explosions Pack" }, Both = { "Basic Ball Pack", "Basic Explosions Pack" } }
-- Abilities you can buy with coins, cheapest first.
local ABILITY_OPTIONS = {}
do
	local list = {}
	for name, data in pairs(AbilityInfo) do
		if type(data) == "table" and tonumber(data.Price) then
			table.insert(list, { name = name, price = tonumber(data.Price) })
		end
	end
	table.sort(list, function(a, b)
		return a.price < b.price
	end)
	for _, entry in ipairs(list) do
		table.insert(ABILITY_OPTIONS, entry.name)
	end
	if #ABILITY_OPTIONS == 0 then
		ABILITY_OPTIONS = { "Guardian" }
	end
end
-- When each ability does the most good:
-- spike = right before a spike, hit = before any hit, incoming = the ball is
-- coming into your square, save = you can't reach a ball that will land in it.
local ABILITY_MOMENT = {
	Superspike = "spike", Curveball = "spike",
	Moonball = "hit", Portal = "hit", TornadoBall = "hit",
	Adrenaline = "incoming",
	Frozen = "save", Magnet = "save", Forcefield = "save",
}

-- Config ---------------------------------------------------------------------
local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/VolleyBomb_" .. tostring(LocalPlayer.UserId) .. ".rfld"
local SAVE_KEYS = {
	"autoHit", "autoMove", "autoSpike", "autoDive", "autoServe", "smartAim", "aimMode", "autoAbility", "showLanding", "humanize", "reaction", "combos", "comboChance",
	"autoVote", "voteMode", "autoProServer", "autoBuyAbility", "abilityGoal", "autoEquipAbility", "autoBuyPacks", "saveForAbility", "packChoice",
	"autoDaily", "autoQuests", "autoAchievements", "autoSpin",
	"antiAfk", "stayActive", "autoReload", "notifications", "showTracker",
	"toggleKey", "hideOnStart", "hubSize", "windTheme",
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
	if not table.find(AIM_OPTIONS, STATE.aimMode) then
		STATE.aimMode = "Hardest to save"
	end
	if not table.find(REACTION_OPTIONS, STATE.reaction) then
		STATE.reaction = "Normal"
	end
	if not table.find(COMBO_OPTIONS, STATE.comboChance) then
		STATE.comboChance = "Often"
	end
	if not table.find(VOTE_OPTIONS, STATE.voteMode) then
		STATE.voteMode = "Solo"
	end
	if not table.find(PACK_OPTIONS, STATE.packChoice) then
		STATE.packChoice = "Both"
	end
	if not table.find(ABILITY_OPTIONS, STATE.abilityGoal) then
		STATE.abilityGoal = table.find(ABILITY_OPTIONS, "Guardian") and "Guardian" or ABILITY_OPTIONS[#ABILITY_OPTIONS]
	end
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

local function playerData()
	local ok, data = pcall(function()
		return replion:GetReplion("PlayerData")
	end)
	elevate()
	return ok and data or nil
end

local function dataGet(path)
	local data = playerData()
	if not data then
		return nil
	end
	local ok, value = pcall(data.Get, data, path)
	elevate()
	return ok and value or nil
end

local function remote(name)
	local ok, object = pcall(Net.RemoteEvent, Net, name)
	elevate()
	return ok and object or nil
end

local function remoteFunction(name)
	local ok, object = pcall(Net.RemoteFunction, Net, name)
	elevate()
	return ok and object or nil
end

local function leaderstat(name)
	local folder = LocalPlayer:FindFirstChild("leaderstats")
	local value = folder and folder:FindFirstChild(name)
	return value and tonumber(value.Value) or 0
end

local function shortNumber(value)
	value = tonumber(value) or 0
	local suffixes = { "", "K", "M", "B", "T", "Qa" }
	local index = 1
	while math.abs(value) >= 1000 and index < #suffixes do
		value /= 1000
		index += 1
	end
	if index == 1 then
		return tostring(math.floor(value))
	end
	return string.format(value >= 100 and "%.0f%s" or "%.1f%s", value, suffixes[index])
end

local function character()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then
		return char, root, hum
	end
	return nil
end

local function arenaName()
	return LocalPlayer:GetAttribute("InRound")
end

local function arenaBall()
	local arena = arenaName()
	local balls = BallController._balls
	return arena and type(balls) == "table" and balls[arena] or nil
end

local function equippedAbility()
	return dataGet("EquippedAbility")
end

-- Uses the equipped ability when this moment suits it. A spike also counts as
-- a hit, so hit abilities fire before spikes too.
local function useAbility(moment)
	if STATE.autoAbility ~= true then
		return false
	end
	local name = equippedAbility()
	local wanted = name and ABILITY_MOMENT[name]
	if not wanted or not (wanted == moment or (moment == "spike" and wanted == "hit")) then
		return false
	end
	local okLeft, left = pcall(AbilityController.Remaining, AbilityController, name)
	if okLeft and tonumber(left) and left > 0 then
		return false
	end
	if type(AbilityController._active) == "table" and AbilityController._active[name] then
		return false
	end
	local ok = pcall(AbilityController.ActivateEquipped, AbilityController)
	elevate()
	if ok then
		stats.abilities = (stats.abilities or 0) + 1
	end
	return ok
end

-- Brain ------------------------------------------------------------------------
-- Everything below asks the game's own Ball module where the ball will be, so
-- the moves match what the server checks (reach, zones, cooldowns).
local brain = {
	lastTry = 0,
	lastDive = 0,
	lastJump = 0,
	lastServe = 0,
	marker = nil,
	-- Humanize: a new reaction to every new ball flight.
	stateKey = nil,
	reactAt = 0,
	offset = Vector3.zero,
	skipSpike = false,
	serveAt = nil,
	idleAt = 0,
	idleSpot = nil,
	aimKey = nil,
	aimDir = nil,
	comboUntil = 0,
	seenHit = 0,
	pendingKind = nil,
	pendingPick = nil,
}

local REACTION_TIMES = { Fast = { 0.07, 0.16 }, Normal = { 0.14, 0.28 }, Relaxed = { 0.24, 0.42 } }
local function randomBetween(a, b)
	return a + math.random() * (b - a)
end
local function humanizing()
	return STATE.humanize == true
end

-- Whoever stands in a square (not you).
local function occupantOf(zone)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local rel = zone.CFrame:PointToObjectSpace(root.Position)
				if math.abs(rel.X) <= zone.Size.X / 2 and math.abs(rel.Z) <= zone.Size.Z / 2 and math.abs(rel.Y) < 25 then
					return player, root.Position
				end
			end
		end
	end
	return nil
end

local function isTeammate(player)
	local mine = LocalPlayer:GetAttribute("Team")
	return mine ~= nil and player ~= nil and player:GetAttribute("Team") == mine
end

-- Where a hit in direction dir would end up, following wall bounces.
local function simulate(kind, state, zones, ballPos, dir, now, quality)
	local origin, unit = Ball.Inside(zones, ballPos, dir)
	local ok, nextState = pcall(Ball.Hits[kind], state.Multipliers, origin, unit, now, quality, { Boost = 1 })
	if not ok or type(nextState) ~= "table" then
		return nil
	end
	for _ = 1, 3 do
		if not nextState.Reflect then
			break
		end
		local okBounce, bounced = pcall(Ball.Bounce, nextState)
		if not okBounce or type(bounced) ~= "table" then
			break
		end
		nextState = bounced
	end
	return Ball.At(nextState, nextState.EndTime), nextState.EndTime - now
end

local function chooseDirection(kind, state, zones, myZone, ballPos, now, quality)
	local candidates = {}
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local land, flight = simulate(kind, state, zones, ballPos, dir, now, quality)
		if land then
			local zone = Ball.ZoneAt(zones, land)
			if zone and not zone:GetAttribute("Occupied") then
				zone = Ball.BounceTarget(zones, land) or zone
			end
			if zone and zone ~= myZone and zone:GetAttribute("Occupied") then
				local who, whoPos = occupantOf(zone)
				if not isTeammate(who) then
					local far = whoPos and ((whoPos - land) * Vector3.new(1, 0, 1)).Magnitude or 10
					table.insert(candidates, { dir = dir, far = far, flight = flight, who = who })
				end
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	local mode = STATE.aimMode
	local pick
	if mode == "Random player" then
		local byPlayer = {}
		for _, option in ipairs(candidates) do
			local key = option.who and option.who.Name or "?"
			byPlayer[key] = byPlayer[key] or {}
			table.insert(byPlayer[key], option)
		end
		local names = {}
		for name in pairs(byPlayer) do
			table.insert(names, name)
		end
		local list = byPlayer[names[math.random(1, #names)]]
		table.sort(list, function(a, b)
			return a.far > b.far
		end)
		pick = list[1]
	else
		for _, option in ipairs(candidates) do
			option.score = mode == "Fastest" and -option.flight or (option.far - option.flight * 4)
		end
		table.sort(candidates, function(a, b)
			return a.score > b.score
		end)
		pick = candidates[1]
		-- A person doesn't find the exact best angle every time: pick one of
		-- the top few, usually the best.
		if humanizing() and #candidates > 1 then
			local roll = math.random()
			local index = roll < 0.55 and 1 or (roll < 0.85 and 2 or 3)
			pick = candidates[math.min(index, #candidates)]
		end
	end
	return pick.dir, pick
end

local function face(root, dir)
	if dir then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	end
end

local function tryHit(kind, char, root, state, zones, myZone, ballPos, now)
	local quality = 1
	local resolvedKind = kind
	if kind == "Spike" then
		resolvedKind, quality = Ball.Resolve("Spike", char.Head.Position, ballPos, Ball.Jump(char, root.Position))
	end
	useAbility(resolvedKind == "Spike" and "spike" or "hit")
	local pick
	if resolvedKind == "Spike" then
		brain.comboUntil = 0
	end
	if STATE.smartAim == true then
		local dir
		if brain.aimDir and brain.aimKey == brain.stateKey and resolvedKind == brain.aimKind then
			dir, pick = brain.aimDir, brain.aimPick
		else
			dir, pick = chooseDirection(resolvedKind, state, zones, myZone, ballPos, now, quality)
		end
		face(root, dir)
	end
	if humanizing() then
		-- Swing like a player: the game's own Swing plays the bump/spike
		-- animation and makes the hit. Count it once the game logs the hit.
		brain.pendingKind, brain.pendingPick, brain.pendingQuality = resolvedKind, pick, quality
		local ok = pcall(BallController.Swing, BallController)
		elevate()
		return ok
	end
	local ok, hit = pcall(BallController.Hit, BallController, kind)
	elevate()
	if ok and hit then
		stats.hits += 1
		if resolvedKind == "Spike" then
			stats.spikes += 1
			if quality >= 0.9 then
				stats.perfect += 1
			end
		else
			stats.bumps += 1
		end
		local target = pick and pick.who and pick.who.DisplayName or nil
		stats.lastHit = resolvedKind .. (target and (" at " .. target) or "")
			.. (pick and string.format(" (%.1fs)", pick.flight) or "")
		STATE.playStatus = "Hit: " .. stats.lastHit
		return true
	end
	return false
end

-- Hits made through Swing are counted here, when the game records them.
local function countSwingHits()
	local last = tonumber(BallController._lastHit) or 0
	if last > brain.seenHit then
		brain.seenHit = last
		local kind = brain.pendingKind
		if not kind then
			return
		end
		brain.pendingKind = nil
		local pick, quality = brain.pendingPick, brain.pendingQuality or 1
		stats.hits += 1
		if kind == "Spike" then
			stats.spikes += 1
			if quality >= 0.9 then
				stats.perfect += 1
			end
		elseif kind == "Set" then
			stats.sets = (stats.sets or 0) + 1
		else
			stats.bumps += 1
		end
		local target = pick and pick.who and pick.who.DisplayName or nil
		stats.lastHit = kind .. (target and (" at " .. target) or "")
			.. (pick and pick.flight and string.format(" (%.1fs)", pick.flight) or "")
		STATE.playStatus = "Hit: " .. stats.lastHit
	end
end

-- Combo: set the ball up to yourself (a short pop inside your own square),
-- then the spike plan below jumps and spikes it.
local function trySetToSelf(char, root, state, zones, myZone, ballPos, now)
	local maxHits = Ball.GetMaxHits()
	local used = (state.HitZone == myZone and tonumber(state.Hits)) or 0
	if used + 2 > maxHits then
		return false
	end
	local center = Vector3.new(myZone.Position.X, ballPos.Y, myZone.Position.Z)
	local toCenter = (center - ballPos) * Vector3.new(1, 0, 1)
	local dir = toCenter.Magnitude > 3 and toCenter.Unit or (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	-- Check the pop stays in your square and comes down at spike height.
	local origin, unit = Ball.Inside(zones, ballPos, dir)
	local ok, popped = pcall(Ball.Hits.Set, state.Multipliers, origin, unit, now)
	if not ok or type(popped) ~= "table" then
		return false
	end
	local fine = false
	for t = now + 0.5, math.min(popped.EndTime, now + 3), 0.05 do
		local p = Ball.At(popped, t)
		if Ball.ZoneAt(zones, p) ~= myZone then
			return false
		end
		local h = p.Y - Ball.Ground(p).Y
		if Ball.VelocityAt(popped, t).Y < 0 and h <= 15.5 and h >= 8.5 then
			fine = true
			break
		end
	end
	if not fine then
		return false
	end
	face(root, dir)
	if humanizing() and type(BallController._tracks) == "table" and BallController._tracks.Bump then
		pcall(function()
			BallController._tracks.Bump:Play()
		end)
	end
	brain.pendingKind, brain.pendingPick, brain.pendingQuality = "Set", nil, 1
	local okHit, hit = pcall(BallController.Hit, BallController, "Set")
	elevate()
	if okHit and hit then
		brain.comboUntil = os.clock() + 2.5
		brain.skipSpike = false
		stats.combos = (stats.combos or 0) + 1
		STATE.playStatus = "Combo: set up a spike"
		return true
	end
	brain.pendingKind = nil
	return false
end

local function moveTo(hum, root, spot)
	if STATE.autoMove ~= true then
		return
	end
	if humanizing() then
		spot += brain.offset
	end
	hum:MoveTo(Vector3.new(spot.X, root.Position.Y, spot.Z))
end

local function landingSpot(state, now)
	if state.Dead or state.Reflect or state.EndTime > now + 10 then
		return nil
	end
	return Ball.Contain(Ball.At(state, state.EndTime)), state.EndTime
end

local function updateMarker(spot)
	if STATE.showLanding ~= true or not spot then
		if brain.marker then
			brain.marker.Transparency = 1
		end
		return
	end
	if not brain.marker or not brain.marker.Parent then
		local part = Instance.new("Part")
		part.Name = "ZinoosLanding"
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromHex("8268FF")
		part.Size = Vector3.new(0.2, 5, 5)
		part.Parent = workspace
		brain.marker = part
	end
	brain.marker.Transparency = 0.35
	local ground = Ball.Ground(spot)
	brain.marker.CFrame = CFrame.new(ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end
hubCleanup(function()
	if brain.marker then
		pcall(brain.marker.Destroy, brain.marker)
		brain.marker = nil
	end
	local _, _, hum = character()
	if hum then
		hum.AutoRotate = true
	end
end)

local function stepBrain()
	local ball = arenaBall()
	if not ball or type(ball.State) ~= "table" or type(ball.Zones) ~= "table" then
		updateMarker(nil)
		STATE.playStatus = arenaName() and "Waiting for the ball" or "Waiting for a round"
		return
	end
	local state, zones = ball.State, ball.Zones
	local now = workspace:GetServerTimeNow()
	updateMarker(landingSpot(state, now))
	countSwingHits()
	local char, root, hum = character()
	if not char or state.Dead then
		STATE.playStatus = state.Dead and "Waiting for the next serve" or "Waiting to respawn"
		brain.serveAt = nil
		return
	end
	-- Every new flight of the ball: a fresh human reaction.
	if state.Time ~= brain.stateKey then
		brain.stateKey = state.Time
		local range = REACTION_TIMES[STATE.reaction] or REACTION_TIMES.Normal
		brain.reactAt = os.clock() + (humanizing() and randomBetween(range[1], range[2]) or 0)
		local angle = math.random() * math.pi * 2
		local radius = humanizing() and randomBetween(0.2, 1.3) or 0
		brain.offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		brain.skipSpike = humanizing() and math.random() < 0.12
		brain.aimDir = nil
	end
	local myZone = Ball.ZoneAt(zones, root.Position)
	if not myZone then
		STATE.playStatus = "Not in a square"
		return
	end
	if STATE.autoHit ~= true then
		STATE.playStatus = "Auto Hit is off"
		return
	end

	-- Serve.
	if state.Server == LocalPlayer then
		if humanizing() and not brain.serveAt then
			brain.serveAt = os.clock() + randomBetween(0.6, 1.8)
		end
		if humanizing() and os.clock() < brain.serveAt then
			STATE.playStatus = "Getting ready to serve"
			return
		end
		if STATE.autoServe == true and os.clock() - brain.lastServe > 0.6 then
			brain.lastServe = os.clock()
			if humanizing() then
				pcall(BallController.Swing, BallController)
				elevate()
				stats.serves += 1
				STATE.playStatus = "Served"
				return
			end
			local ok, served = pcall(BallController.Hit, BallController, "Toss")
			elevate()
			if ok and served then
				stats.serves += 1
				STATE.playStatus = "Served"
			end
		end
		return
	end

	brain.serveAt = nil
	local ballNow = Ball.Contain(Ball.At(state, now))
	local ballHere = Ball.ZoneAt(zones, ballNow) == myZone
	local airborne = hum.FloorMaterial == Enum.Material.Air
	local reacted = os.clock() >= brain.reactAt
	if state.HitBy ~= LocalPlayer then
		brain.comboUntil = 0
	end
	local inCombo = os.clock() < brain.comboUntil

	-- Turn towards where you'll hit it a moment before, like a player lining
	-- up, instead of snapping round on the hit.
	local function preAim(kind, at, t, quality)
		if not humanizing() or STATE.smartAim ~= true then
			return
		end
		if brain.aimKey ~= brain.stateKey or brain.aimKind ~= kind then
			brain.aimKey, brain.aimKind = brain.stateKey, kind
			brain.aimDir, brain.aimPick = chooseDirection(kind, state, zones, myZone, at, t, quality or 1)
		end
		local dir = brain.aimDir
		if dir then
			hum.AutoRotate = false
			brain.turning = os.clock()
			local goal = CFrame.lookAt(root.Position, root.Position + dir)
			root.CFrame = root.CFrame:Lerp(goal, 0.22)
		end
	end
	if brain.turning and os.clock() - brain.turning > 0.6 then
		brain.turning = nil
		hum.AutoRotate = true
	end

	-- In the air: only hit once it really counts as a spike (high enough in the
	-- jump, ball not below your head). Hitting earlier would turn it into a bump.
	if airborne and ballHere and STATE.autoSpike == true then
		local reach = Ball.Reach("Spike", root.Position, char)
		if Ball.InRange("Spike", reach, ballNow) then
			local kind, quality = Ball.Resolve("Spike", char.Head.Position, ballNow, Ball.Jump(char, root.Position))
			local below = ballNow.Y < char.Head.Position.Y - 0.5
			-- Wait for a perfect contact (ball close above the head) unless the
			-- jump is running out.
			local late = os.clock() - brain.lastJump > 0.58
			if kind == "Spike" and (quality >= 0.9 or late) and os.clock() - brain.lastTry > 0.05 then
				brain.lastTry = os.clock()
				tryHit("Spike", char, root, state, zones, myZone, ballNow, now)
				return
			elseif not below and os.clock() - brain.lastJump < 0.9 then
				STATE.playStatus = "Waiting for the spike"
				return
			end
		end
	end

	-- Bump when it is in reach (or set it up to yourself for a combo).
	if ballHere and Ball.InRange("Bump", root.Position, ballNow) and reacted then
		local low = ballNow.Y - Ball.Ground(ballNow).Y < 6
		if inCombo and not low and not airborne then
			STATE.playStatus = "Combo: waiting to spike"
		elseif os.clock() - brain.lastTry > 0.1 then
			brain.lastTry = os.clock()
			local comboed = false
			if STATE.combos == true and STATE.autoSpike == true and not airborne and not inCombo
				and math.random() < (COMBO_CHANCE[STATE.comboChance] or 70) / 100 then
				comboed = trySetToSelf(char, root, state, zones, myZone, ballNow, now)
			end
			if not comboed then
				tryHit("Bump", char, root, state, zones, myZone, ballNow, now)
			end
		end
		return
	end

	-- Spike plan: a point on the way down that you can get under, where the
	-- ball will be 0-2.5 studs above your head at the top of your jump (that's
	-- a PERFECT spike in the game's maths, which also powers Superspike).
	if STATE.autoSpike == true and not airborne and reacted and (inCombo or not brain.skipSpike) then
		local headTop = char.Head.Position.Y + 7.4
		for t = now + 0.42, math.min(state.EndTime, now + 4), 0.03 do
			local p = Ball.Contain(Ball.At(state, t))
			if Ball.ZoneAt(zones, p) == myZone and Ball.VelocityAt(state, t).Y < 0 then
				local above = p.Y - headTop
				if above <= 2.5 and above >= -0.3 then
					local flat = Vector3.new(p.X, root.Position.Y, p.Z)
					local dist = (flat - root.Position).Magnitude
					if STATE.autoMove ~= true and dist > 4 then
						break
					end
					if dist <= hum.WalkSpeed * (t - now - 0.42) + 3 then
						moveTo(hum, root, flat)
						STATE.playStatus = inCombo and "Combo: going up for the spike" or "Lining up a spike"
						if t - now <= 0.8 then
							preAim("Spike", p, t, 1)
						end
						if t - now <= 0.46 and os.clock() - brain.lastJump > 0.8 then
							brain.lastJump = os.clock()
							useAbility("spike")
							hum:ChangeState(Enum.HumanoidStateType.Jumping)
						end
						return
					end
					break
				end
			end
		end
	end

	-- Walk to the first point where the ball is low enough to hit in your square.
	local target, targetTime
	for t = now, math.min(state.EndTime, now + 4), 0.03 do
		local p = Ball.Contain(Ball.At(state, t))
		if Ball.ZoneAt(zones, p) == myZone and p.Y - Ball.Ground(p).Y <= 8 then
			target, targetTime = p, t
			break
		end
	end
	if target and not reacted then
		STATE.playStatus = "Reacting"
	elseif target then
		local flat = Vector3.new(target.X, root.Position.Y, target.Z)
		local dist = (flat - root.Position).Magnitude
		moveTo(hum, root, flat)
		STATE.playStatus = "Going for the ball"
		if targetTime - now <= 0.45 and not (STATE.combos == true and STATE.autoSpike == true) then
			preAim("Bump", target, targetTime, 1)
		end
		useAbility("incoming")
		local land, landTime = landingSpot(state, now)
		local lands = land and Ball.ZoneAt(zones, land) == myZone
		local left = (lands and landTime or targetTime) - now
		local need = dist / math.max(hum.WalkSpeed, 1)
		if lands and need > left and left < 1 then
			useAbility("save")
		end
		if STATE.autoDive == true and lands and need > left and left < 0.5 and dist < 30 and os.clock() - brain.lastDive > 1 then
			brain.lastDive = os.clock()
			face(root, (flat - root.Position).Unit)
			local ok = pcall(AbilityController.Activate, AbilityController, "Dive")
			elevate()
			if ok then
				stats.dives += 1
				STATE.playStatus = "Dived"
			end
		end
	else
		-- Wait in your square. Humanized: shuffle around the middle now and
		-- then instead of standing dead still.
		local center = Vector3.new(myZone.Position.X, root.Position.Y, myZone.Position.Z)
		if humanizing() then
			if not brain.idleSpot or os.clock() >= brain.idleAt then
				brain.idleAt = os.clock() + randomBetween(1.8, 4.5)
				local angle = math.random() * math.pi * 2
				local radius = randomBetween(0, 5)
				brain.idleSpot = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			end
			if STATE.autoMove == true and (brain.idleSpot - root.Position).Magnitude > 1.5 then
				hum:MoveTo(Vector3.new(brain.idleSpot.X, root.Position.Y, brain.idleSpot.Z))
			end
		elseif (center - root.Position).Magnitude > 4 then
			moveTo(hum, root, center)
		end
		STATE.playStatus = "In position"
	end
end

trackConnection(RunService.Heartbeat:Connect(function()
	if not running() then
		return
	end
	local ok, err = pcall(stepBrain)
	if not ok then
		STATE.playStatus = "Error: " .. tostring(err)
	end
end))

-- Rewards ----------------------------------------------------------------------
local DAY = 86400
local spinBusy = false

local function claimDaily()
	local data = playerData()
	if not data then
		return 0
	end
	local claimed = dataGet("ClaimedDailyRewards") or {}
	local first = tonumber(dataGet("FirstJoinTime")) or 0
	local now = workspace:GetServerTimeNow()
	local count = 0
	for index in ipairs(DailyRewards) do
		if not table.find(claimed, index) and first + (index - 1) * DAY <= now then
			local event = remote("ClaimDayReward")
			if event then
				event:FireServer(index)
				count += 1
				task.wait(0.5)
			end
		end
	end
	return count
end

local function claimQuests()
	local progress = dataGet("DailyQuests") or {}
	local claimed = dataGet("ClaimedQuests") or {}
	local count = 0
	for name, value in pairs(progress) do
		local quest = QuestInfo[name]
		if quest and tonumber(value) and tonumber(value) >= (tonumber(quest.Goal) or math.huge) and not claimed[name] then
			local event = remote("ClaimQuest")
			if event then
				event:FireServer(name)
				count += 1
				task.wait(0.5)
			end
		end
	end
	return count
end

local function claimAchievements()
	local claimed = dataGet("ClaimedAchievements") or {}
	local count = 0
	for _, category in ipairs(AchievementConfig) do
		for _, achievement in ipairs(type(category) == "table" and category.Achievements or {}) do
			if achievement.Id and not claimed[achievement.Id] and achievement.Stat then
				local value = tonumber(dataGet(achievement.Stat)) or 0
				if value >= (tonumber(achievement.Goal) or math.huge) then
					local event = remote("ClaimAchievement")
					if event then
						event:FireServer(achievement.Id)
						count += 1
						task.wait(0.5)
					end
				end
			end
		end
	end
	return count
end

local function spinWheel()
	if spinBusy then
		return false
	end
	local spins = (tonumber(dataGet("Spins")) or 0) + (tonumber(dataGet("LuckySpins")) or 0)
	if spins <= 0 then
		return false
	end
	local request = remoteFunction("RequestSpin")
	local reward = remoteFunction("RequestRewardFromSpin")
	if not request or not reward then
		return false
	end
	spinBusy = true
	local ok, index = pcall(request.InvokeServer, request)
	elevate()
	if ok and type(index) == "number" then
		task.wait(5)
		pcall(reward.InvokeServer, reward)
		elevate()
		spinBusy = false
		return true
	end
	spinBusy = false
	return false
end

local rewardTotals = { daily = 0, quests = 0, achievements = 0, spins = 0 }
local function stepRewards()
	local parts = {}
	if STATE.autoDaily == true then
		rewardTotals.daily += claimDaily()
	end
	if STATE.autoQuests == true then
		rewardTotals.quests += claimQuests()
	end
	if STATE.autoAchievements == true then
		rewardTotals.achievements += claimAchievements()
	end
	if STATE.autoSpin == true and spinWheel() then
		rewardTotals.spins += 1
		noteActivity("Spun the wheel")
	end
	if rewardTotals.daily > 0 then table.insert(parts, rewardTotals.daily .. " daily") end
	if rewardTotals.quests > 0 then table.insert(parts, rewardTotals.quests .. " quests") end
	if rewardTotals.achievements > 0 then table.insert(parts, rewardTotals.achievements .. " achievements") end
	if rewardTotals.spins > 0 then table.insert(parts, rewardTotals.spins .. " spins") end
	local nextSpin = (tonumber(LocalPlayer:GetAttribute("NextSpinReceivedAt")) or 0) - os.time()
	STATE.rewardStatus = (#parts > 0 and ("Claimed " .. table.concat(parts, ", ")) or "Nothing to claim yet")
		.. (nextSpin > 0 and string.format(" · free spin in %dm", math.ceil(nextSpin / 60)) or "")
end

-- Shop -------------------------------------------------------------------------
local function ownsAbility(name)
	local owned = dataGet("OwnedAbilities") or {}
	return owned[name] == true
end

local function packComplete(packName)
	local pack = PackInfo[packName]
	if type(pack) ~= "table" or type(pack.Items) ~= "table" then
		return true
	end
	local ownedKey = pack.Kind == "Explosions" and "OwnedExplosions" or "OwnedBalls"
	local owned = dataGet(ownedKey) or {}
	for item in pairs(pack.Items) do
		if not owned[item] then
			return false
		end
	end
	return true
end

local shopTotals = { abilities = 0, packs = 0 }
local function stepShop()
	local coins = tonumber(dataGet("Money")) or 0
	local goal = STATE.abilityGoal
	local goalData = goal and AbilityInfo[goal]
	local goalPrice = goalData and tonumber(goalData.Price) or 0
	local saving = 0
	local parts = {}

	if STATE.autoBuyAbility == true and goalData then
		if ownsAbility(goal) then
			table.insert(parts, goal .. " owned")
		elseif coins >= goalPrice then
			local event = remote("BuyAbility")
			if event then
				event:FireServer(goal)
				task.wait(1)
				if ownsAbility(goal) then
					shopTotals.abilities += 1
					coins = tonumber(dataGet("Money")) or coins
					noteActivity("Bought " .. goal)
					notify("Bought " .. goal, "Your new ability is ready")
				end
			end
		else
			saving = STATE.saveForAbility == true and goalPrice or 0
			table.insert(parts, string.format("%s: %s/%s coins", goal, shortNumber(coins), shortNumber(goalPrice)))
		end
	end

	if STATE.autoEquipAbility == true and goal and ownsAbility(goal) and equippedAbility() ~= goal then
		local event = remote("EquipAbility")
		if event then
			event:FireServer(goal)
			noteActivity("Equipped " .. goal)
		end
	end

	if STATE.autoBuyPacks == true then
		local bought, done, broke = false, 0, false
		local names = PACK_NAMES[STATE.packChoice] or {}
		for _, packName in ipairs(names) do
			local pack = PackInfo[packName]
			local price = pack and tonumber(pack.Price) or math.huge
			if packComplete(packName) then
				done += 1
			elseif coins - price >= saving then
				local ok, result = pcall(Net.Invoke, Net, "BuyPack", packName)
				elevate()
				if ok and result then
					shopTotals.packs += 1
					bought = true
					coins = tonumber(dataGet("Money")) or (coins - price)
					local item = type(result) == "string" and result or nil
					STATE.lastPack = (item and (item .. " from ") or "") .. packName
					noteActivity("Opened " .. packName .. (item and (": " .. item) or ""))
				end
			else
				broke = true
			end
		end
		if done == #names and #names > 0 then
			table.insert(parts, "every pack complete")
		elseif not bought and saving > 0 then
			table.insert(parts, "packs wait until the ability is bought")
		elseif not bought and broke then
			table.insert(parts, "not enough coins for a pack")
		end
	end
	if shopTotals.packs > 0 then
		table.insert(parts, shopTotals.packs .. " packs opened" .. (STATE.lastPack and (" (last: " .. STATE.lastPack .. ")") or ""))
	end
	STATE.shopStatus = #parts > 0 and table.concat(parts, " · ") or "Nothing to buy right now"
end

-- Votes for your game mode once per vote.
local votedFor = nil
local function stepVote()
	local voting = workspace:GetAttribute("Voting")
	if STATE.autoVote ~= true or not voting then
		return
	end
	local key = tostring(voting) .. STATE.voteMode
	if votedFor == key then
		return
	end
	local event = remote("VoteTeammode")
	if event then
		event:FireServer(STATE.voteMode)
		votedFor = key
		noteActivity("Voted " .. STATE.voteMode)
	end
end
trackConnection(workspace:GetAttributeChangedSignal("Voting"):Connect(function()
	task.wait(0.5)
	if running() then
		pcall(stepVote)
	end
end))

-- Pro Servers: the lobby pad "Join Pro Servers" (1.5x coins) needs a number of
-- wins. Once you have them, walk onto the pad between rounds and press it.
local proServer = { lastTry = 0, tries = 0 }
local function proPad()
	local objects = workspace:FindFirstChild("GameObjects")
	local model = objects and objects:FindFirstChild("ProServer")
	local prompt = model and model:FindFirstChildWhichIsA("ProximityPrompt", true)
	local primary = model and (model:FindFirstChild("Primary") or model.PrimaryPart)
	local needed
	local label = primary and primary:FindFirstChild("BillboardGui") and primary.BillboardGui:FindFirstChild("Wins")
	if label and label:IsA("TextLabel") then
		needed = tonumber(string.match(label.Text, "%d+"))
	end
	return prompt, primary, needed or 20
end
STATE.proPad = proPad

-- Normal servers are place 98979169190595; Pro Servers are place 97790681249268
-- (it has the same pad, so never try to join from there).
local MAIN_PLACE, PRO_PLACE = 98979169190595, 97790681249268
local function stepProServer()
	if game.PlaceId == PRO_PLACE then
		STATE.proStatus = "You're in a Pro Server (1.5x coins)"
		return
	elseif game.PlaceId ~= MAIN_PLACE then
		STATE.proStatus = "Pro Servers can only be joined from the main lobby"
		return
	end
	local prompt, primary, needed = proPad()
	if not prompt or not primary then
		STATE.proStatus = "No Pro Server pad here (you may already be in one)"
		return
	end
	local wins = leaderstat("Wins")
	if wins < needed then
		STATE.proStatus = string.format("%d/%d wins to unlock Pro Servers (1.5x coins)", wins, needed)
		return
	end
	if STATE.autoProServer ~= true then
		STATE.proStatus = "Unlocked · turn on Auto Join to go"
		return
	end
	if arenaName() or os.clock() - proServer.lastTry < 60 or proServer.tries >= 5 then
		STATE.proStatus = proServer.tries >= 5 and "Tried 5 times, stopped (join it from the pad)" or "Unlocked · joining between rounds"
		return
	end
	local _, root = character()
	if not root then
		return
	end
	proServer.lastTry = os.clock()
	proServer.tries += 1
	root.CFrame = CFrame.new(primary.Position + primary.CFrame.LookVector * 5 + Vector3.new(0, 3, 0))
	task.wait(0.4)
	pcall(fireproximityprompt, prompt)
	STATE.proStatus = "Joining Pro Servers..."
	noteActivity("Joining Pro Servers")
end

-- Player -----------------------------------------------------------------------
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
end
trackConnection(LocalPlayer.Idled:Connect(pulseAntiAfk))

-- The game has its own AFK switch that keeps you out of rounds.
local function stepStayActive()
	if STATE.stayActive == true and LocalPlayer:GetAttribute("AFK") == true then
		local event = remote("ToggleAFK")
		if event then
			event:FireServer()
			noteActivity("Turned the game's AFK mode off")
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

-- Reload the hub after a server change (rejoin, hop, practice, update shutdown).
do
	local queueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	local RELOAD = [==[
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(4)
if getgenv().ZinoosVolleyGen ~= nil then return end
local ok, source = pcall(function()
	return game:HttpGet("https://raw.githubusercontent.com/yszvzms6st-pixel/ZinoosHub/refs/heads/main/games/VolleyBomb.luau")
end)
if ok and type(source) == "string" and #source > 1000 and getgenv().ZinoosVolleyGen == nil then
	local chunk = loadstring(source, "=ZinoosHub/VolleyBomb.luau")
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
		warn("[Zinoos hub] Menu could not load (" .. tostring(loadError) .. "). Auto play still runs with your saved settings.")
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
		Icon = "volleyball",
		Author = "Volley Bomb",
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
			Icon = "volleyball",
			CornerRadius = UDim.new(1, 0),
			StrokeThickness = 2,
			Color = ColorSequence.new(Color3.fromHex("8268FF"), Color3.fromHex("C084FC")),
			OnlyMobile = false,
			Enabled = true,
			Draggable = true,
			-- Right side, so it doesn't cover the game's round text at the top.
			Position = UDim2.new(1, -110, 0.42, 0),
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
			pcall(WindUI.Notify, WindUI, { Title = tostring(title), Content = tostring(message), Icon = "volleyball", Duration = 4.5 })
		end)
	end

	-- Control helpers ------------------------------------------------------
	local dropdowns = {}

	local function onToggle(key, on)
		STATE[key] = on
		if key == "antiAfk" and on then
			task.defer(pulseAntiAfk)
		elseif key == "stayActive" and on then
			task.defer(stepStayActive)
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

	local function syncToggle(key)
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
				STATE[key] = value
				saveConfig()
				if after then after(value) end
			end,
		})
		table.insert(dropdowns, { element = element, get = function() return tostring(STATE[key]) end })
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
	local playTab = Window:Tab({ Title = "Auto Play", Icon = "volleyball" })
	local shopTab = Window:Tab({ Title = "Shop", Icon = "shopping-cart" })
	local rewardTab = Window:Tab({ Title = "Rewards", Icon = "gift" })
	local playerTab = Window:Tab({ Title = "Player", Icon = "user" })
	local settingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
	elevate()

	-- Home
	local overview = info(homeTab, "Overview", "Loading your stats...")
	button(homeTab, "Start / Stop Auto Play", "Turns Auto Hit on or off", "power", function()
		onToggle("autoHit", STATE.autoHit ~= true)
		syncToggle("autoHit")
		notify("Auto Play", STATE.autoHit and "On" or "Off")
	end)
	local sessionBox = section(homeTab, "This Session", "chart-line")
	local sessionInfo = info(sessionBox, "Session", "Nothing yet")
	local activityBox = section(homeTab, "Activity", "list")
	local activityInfo = info(activityBox, "Now", "Starting...")

	-- Auto Play
	local playBox = section(playTab, "Rallies", "volleyball")
	local playInfo = info(playBox, "Status", "Waiting for a round")
	toggle(playBox, "Auto Hit", "autoHit", "Bumps or spikes the ball when it comes into your square")
	toggle(playBox, "Auto Move", "autoMove", "Walks under the ball. Turn off to move yourself and only auto hit")
	toggle(playBox, "Auto Spike", "autoSpike", "Jumps and spikes when the ball drops at the right height (much faster than a bump)")
	toggle(playBox, "Auto Dive", "autoDive", "Dives for balls you can't walk to in time")
	toggle(playBox, "Auto Serve", "autoServe", "Serves straight away when it's your turn")
	local aimBox = section(playTab, "Aiming", "crosshair")
	toggle(aimBox, "Smart Aim", "smartAim", "Works out where each hit lands and sends it into another player's square")
	choice(aimBox, "Aim For", "Hardest to save = far from the player · Fastest = shortest flight", AIM_OPTIONS, "aimMode")
	toggle(aimBox, "Show Landing Spot", "showLanding", "Purple circle where the ball will land")
	local humanBox = section(playTab, "Play Like A Human", "user-check")
	toggle(humanBox, "Humanize", "humanize", "Human reaction time, the game's real bump/spike animations, turning before hits, not-quite-perfect positioning and aim, a short wait before serving, moving around while waiting")
	choice(humanBox, "Reaction Speed", "Fast 0.07-0.16s · Normal 0.14-0.28s · Relaxed 0.24-0.42s", REACTION_OPTIONS, "reaction")
	toggle(humanBox, "Combos", "combos", "Sets the ball up to yourself in your square, then jump-spikes it")
	choice(humanBox, "Combo How Often", nil, COMBO_OPTIONS, "comboChance")
	local abilityBox = section(playTab, "Ability", "zap")
	local abilityInfo = info(abilityBox, "Equipped", "Checking...")
	toggle(abilityBox, "Auto Use Ability", "autoAbility", "Uses it at the right moment: spike abilities before a spike, Moonball/Portal/Tornado before a hit, Adrenaline when the ball comes your way, Frozen/Magnet/Forcefield to save a ball you can't reach")
	local lobbyBox = section(playTab, "Lobby", "users")
	toggle(lobbyBox, "Auto Vote Game Mode", "autoVote", "Votes for you when the round vote opens")
	choice(lobbyBox, "Vote For", "Trios needs 12 players in the server", VOTE_OPTIONS, "voteMode")
	toggle(lobbyBox, "On-screen Tracker", "showTracker", "Small box with wins, eliminations and coins made this session")
	local proBox = section(playTab, "Pro Servers", "crown")
	local proInfo = info(proBox, "Status", "Checking...")
	toggle(proBox, "Auto Join Pro Servers", "autoProServer", "1.5x coins. Goes to the lobby pad and joins once you have the wins (between rounds)")

	-- Shop
	local shopBox = section(shopTab, "Abilities", "zap")
	local shopInfo = info(shopBox, "Status", "Waiting")
	toggle(shopBox, "Auto Buy Ability", "autoBuyAbility", "Saves your coins and buys the ability below as soon as you can afford it")
	local abilityLabels = {}
	choice(shopBox, "Ability To Get", "Guardian = survive one blast every game", ABILITY_OPTIONS, "abilityGoal")
	toggle(shopBox, "Auto Equip It", "autoEquipAbility", "Equips it once you own it")
	local priceInfo = info(shopBox, "Prices", (function()
		for _, name in ipairs(ABILITY_OPTIONS) do
			local data = AbilityInfo[name]
			table.insert(abilityLabels, string.format("%s  %s coins", name, shortNumber(data and data.Price or 0)))
		end
		return table.concat(abilityLabels, "\n")
	end)())
	local packBox = section(shopTab, "Packs", "package")
	toggle(packBox, "Auto Buy Packs", "autoBuyPacks", "Opens ball and explosion packs with your coins (100 each) and stops once you own everything in a pack")
	choice(packBox, "Packs", nil, PACK_OPTIONS, "packChoice")
	toggle(packBox, "Save For Ability First", "saveForAbility", "Holds pack buying until the ability above is bought")
	local packInfo = info(packBox, "Opened", "None yet")

	-- Rewards
	local rewardBox = section(rewardTab, "Free Rewards", "gift")
	local rewardInfo = info(rewardBox, "Status", "Waiting")
	toggle(rewardBox, "Auto Daily Gifts", "autoDaily")
	toggle(rewardBox, "Auto Claim Quests", "autoQuests")
	toggle(rewardBox, "Auto Claim Achievements", "autoAchievements")
	toggle(rewardBox, "Auto Spin Wheel", "autoSpin", "Uses your spins as soon as you have them")
	local questBox = section(rewardTab, "Daily Quests", "list-checks")
	local questInfo = info(questBox, "Progress", "Loading...")

	-- Player
	local afkBox = section(playerTab, "AFK", "moon")
	toggle(afkBox, "Anti AFK", "antiAfk", "Stops the 20 minute idle kick")
	toggle(afkBox, "Stay Active", "stayActive", "Turns the game's AFK button off so you keep getting put in rounds")
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
	toggle(lookBox, "Notifications", "notifications")
	local configBox = section(settingsTab, "Config", "save")
	info(configBox, "Saving", "Changes save automatically for this Roblox account.")
	button(configBox, "Reset to Defaults", nil, "rotate-ccw", function()
		confirm("Reset every setting?", "All options go back to their defaults.", function()
			local defaults = {
				autoHit = true, autoMove = true, autoSpike = true, autoDive = true, autoServe = true,
				smartAim = true, aimMode = "Hardest to save", autoAbility = true, showLanding = false,
				humanize = true, reaction = "Normal", combos = true, comboChance = "Often",
				autoVote = true, voteMode = "Solo", autoProServer = true, autoBuyAbility = true, abilityGoal = "Guardian", autoEquipAbility = true,
				autoBuyPacks = true, saveForAbility = false, packChoice = "Both", showTracker = true,
				autoDaily = true, autoQuests = true, autoAchievements = true, autoSpin = true,
				antiAfk = true, stayActive = true, autoReload = true, notifications = true, hideOnStart = false,
			}
			for key, value in pairs(defaults) do
				STATE[key] = value
				syncToggle(key)
			end
			for _, entry in ipairs(dropdowns) do
				pcall(entry.element.Select, entry.element, entry.get())
			end
			saveConfig()
			notify("Defaults restored", "Everything is back to normal")
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
	local function questText()
		local progress = dataGet("DailyQuests") or {}
		local claimed = dataGet("ClaimedQuests") or {}
		local names = {}
		for name in pairs(progress) do
			table.insert(names, name)
		end
		table.sort(names)
		local lines = {}
		for _, name in ipairs(names) do
			local quest = QuestInfo[name]
			local goal = quest and tonumber(quest.Goal) or 0
			local value = tonumber(progress[name]) or 0
			local mark = claimed[name] and "✓ " or (value >= goal and goal > 0 and "★ " or "")
			table.insert(lines, string.format("%s%s  %d/%d", mark, quest and quest.Description or name, math.min(value, goal), goal))
		end
		return #lines > 0 and table.concat(lines, "\n") or "No quests today"
	end

	local function refresh()
		local wins, elims = leaderstat("Wins"), leaderstat("Eliminations")
		local cash = tonumber(dataGet("Money")) or 0
		stats.wins0 = stats.wins0 or wins
		stats.elims0 = stats.elims0 or elims
		stats.money0 = stats.money0 or cash
		local elapsed = math.max(0, os.time() - stats.started)
		local clock = elapsed >= 3600
			and string.format("%d:%02d:%02d", elapsed // 3600, elapsed % 3600 // 60, elapsed % 60)
			or string.format("%d:%02d", elapsed // 60, elapsed % 60)
		local arena = arenaName()
		elevate()
		setInfo(overview, string.format(
			"%s\nCoins %s · Wins %d · Eliminations %d · Streak %s\n%s",
			STATE.autoHit == true and "Auto Play ON" or "Auto Play OFF",
			shortNumber(cash), wins, elims, tostring(dataGet("Streak") or 0),
			arena and ("In a round (" .. arena .. ")") or "In the lobby"
		))
		setInfo(sessionInfo, string.format(
			"%s session · %d wins · %d eliminations · coins +%s\n%d hits (%d spikes, %d perfect, %d bumps) · %d dives · %d serves · %d abilities\nLast: %s",
			clock, wins - stats.wins0, elims - stats.elims0, shortNumber(math.max(0, cash - stats.money0)),
			stats.hits, stats.spikes, stats.perfect, stats.bumps, stats.combos or 0, stats.dives, stats.serves, stats.abilities or 0, stats.lastHit
		))
		local lines = { "Play · " .. tostring(STATE.playStatus), "Rewards · " .. tostring(STATE.rewardStatus) }
		for _, item in ipairs(STATE.activity) do
			table.insert(lines, item)
		end
		setInfo(activityInfo, table.concat(lines, "\n"))
		setInfo(playInfo, tostring(STATE.playStatus))
		local ability = equippedAbility()
		local abilityData = ability and AbilityInfo[ability]
		setInfo(abilityInfo, ability and (tostring(abilityData and abilityData.DisplayName or ability)
			.. (abilityData and abilityData.Description and ("\n" .. abilityData.Description) or "")) or "None equipped")
		setInfo(rewardInfo, tostring(STATE.rewardStatus))
		setInfo(shopInfo, tostring(STATE.shopStatus))
		setInfo(proInfo, tostring(STATE.proStatus))
		local packLines = {}
		for _, packName in ipairs({ "Basic Ball Pack", "Basic Explosions Pack" }) do
			local pack = PackInfo[packName]
			if type(pack) == "table" and type(pack.Items) == "table" then
				local owned = dataGet(pack.Kind == "Explosions" and "OwnedExplosions" or "OwnedBalls") or {}
				local have, total = 0, 0
				for item in pairs(pack.Items) do
					total += 1
					if owned[item] then have += 1 end
				end
				table.insert(packLines, string.format("%s: %d/%d collected", packName, have, total))
			end
		end
		table.insert(packLines, "Last: " .. tostring(STATE.lastPack or "none yet"))
		setInfo(packInfo, table.concat(packLines, "\n"))
		setInfo(questInfo, questText())
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

if running() then
	local ok, err = xpcall(installHub, debug.traceback)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
	end
end

-- Rewards and staying active.
task.spawn(function()
	task.wait(3)
	while running() do
		pcall(stepStayActive)
		elevate()
		pcall(stepRewards)
		elevate()
		pcall(stepVote)
		elevate()
		pcall(stepShop)
		elevate()
		pcall(stepProServer)
		elevate()
		task.wait(5)
	end
end)

-- On-screen tracker: a small box in the top-right with this session's results.
do
	local gui, label, stroke
	local function build()
		elevate()
		gui = Instance.new("ScreenGui")
		gui.Name = "ZinoosVolleyTracker"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = false
		gui.DisplayOrder = 50
		local pill = Instance.new("Frame")
		pill.AnchorPoint = Vector2.new(1, 0)
		pill.Position = UDim2.new(1, -12, 0, 14)
		pill.Size = UDim2.fromOffset(0, 30)
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
		pill.BackgroundTransparency = 0.15
		pill.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = pill
		stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromHex("8268FF")
		stroke.Parent = pill
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = pill
		label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, 30)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = ""
		label.Parent = pill
		local placed = pcall(function()
			gui.Parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
		end)
		if not placed then
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		end
	end
	hubCleanup(function()
		if gui then
			elevate()
			pcall(gui.Destroy, gui)
			gui = nil
		end
	end)
	task.spawn(function()
		while running() do
			local show = STATE.showTracker == true
			if show and not gui then
				pcall(build)
			end
			if gui then
				local wins, elims = leaderstat("Wins"), leaderstat("Eliminations")
				local cash = tonumber(dataGet("Money")) or 0
				stats.wins0 = stats.wins0 or wins
				stats.elims0 = stats.elims0 or elims
				stats.money0 = stats.money0 or cash
				elevate()
				pcall(function()
					gui.Enabled = show
					local playing = STATE.autoHit == true
					stroke.Color = playing and Color3.fromHex("8268FF") or Color3.fromHex("8C8896")
					label.Text = string.format("%s  WINS +%d · KILLS +%d · COINS +%s · SPIKES %d",
						playing and "AUTO" or "OFF",
						wins - (stats.wins0 or wins), elims - (stats.elims0 or elims),
						shortNumber(math.max(0, cash - (stats.money0 or cash))), stats.spikes)
				end)
			end
			task.wait(1)
		end
	end)
end

task.spawn(function()
	while running() do
		task.wait(120)
		pulseAntiAfk()
	end
end)

notify("Zinoos Hub", "Volley Bomb hub v" .. VERSION .. " loaded")
