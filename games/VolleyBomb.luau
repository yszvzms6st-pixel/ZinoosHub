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

local VERSION = "1.9.3"
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
	trickShots = true,
	playerMove = true,
	proPosition = true,
	emotes = true,
	lobbyWander = true,
	autoVote = true,
	voteMode = "Solo",
	autoProServer = true,
	-- Shop
	autoBuyAbility = true,
	abilityGoal = "Guardian",
	abilityBuyMode = "Just my main ability",
	skipAbilities = {},
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
	customFov = false,
	fov = 90,
	dodgeShockwave = true,
	avoidBlasts = true,
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
local BUY_MODE_OPTIONS = { "Just my main ability", "All abilities" }
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
	-- Magnet and Frozen catch the ball as it comes in so you can spike it
	-- (ability combos); Forcefield still saves balls you can't reach.
	Frozen = "incoming", Magnet = "incoming", Forcefield = "save",
}

-- Config ---------------------------------------------------------------------
local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/VolleyBomb_" .. tostring(LocalPlayer.UserId) .. ".rfld"
local SAVE_KEYS = {
	"autoHit", "autoMove", "autoSpike", "autoDive", "autoServe", "smartAim", "aimMode", "autoAbility", "showLanding", "humanize", "reaction", "combos", "comboChance", "trickShots", "playerMove", "proPosition", "emotes", "lobbyWander",
	"autoVote", "voteMode", "autoProServer", "autoBuyAbility", "abilityGoal", "abilityBuyMode", "skipAbilities", "autoEquipAbility", "autoBuyPacks", "saveForAbility", "packChoice",
	"autoDaily", "autoQuests", "autoAchievements", "autoSpin",
	"antiAfk", "stayActive", "autoReload", "notifications", "showTracker", "customFov", "fov", "dodgeShockwave", "avoidBlasts",
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
	if not table.find(BUY_MODE_OPTIONS, STATE.abilityBuyMode) then
		STATE.abilityBuyMode = "Just my main ability"
	end
	local skips = {}
	for _, name in ipairs(type(STATE.skipAbilities) == "table" and STATE.skipAbilities or {}) do
		if table.find(ABILITY_OPTIONS, name) then
			table.insert(skips, name)
		end
	end
	STATE.skipAbilities = skips
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
	-- Frozen only lasts 3s, so only fire it when the ball is close to arriving.
	if name == "Frozen" and moment == "incoming" and (STATE.incomingEta or 99) > 2.2 then
		return false
	end
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

-- Everyone standing in a square (team modes can have more than one).
local function occupantsOf(zone)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local rel = zone.CFrame:PointToObjectSpace(root.Position)
				if math.abs(rel.X) <= zone.Size.X / 2 and math.abs(rel.Z) <= zone.Size.Z / 2 and math.abs(rel.Y) < 25 then
					table.insert(list, { player = player, pos = root.Position })
				end
			end
		end
	end
	return list
end

-- Team modes (Duos/Trios): teammates share one bigger square (seen live: two
-- players in a 36x36 square, and no "Team" attribute set), so anyone in your
-- square is on your team.
local function teamMode()
	local mode = workspace:GetAttribute("Teammode")
	return mode ~= nil and mode ~= "Solo"
end

-- Is a teammate in your square clearly closer to this spot? Then it's their
-- ball (no fighting over it).
local function teammateCloser(myZone, root, spot)
	if not LocalPlayer:GetAttribute("Team") and not teamMode() then
		return nil
	end
	local mine = ((root.Position - spot) * Vector3.new(1, 0, 1)).Magnitude
	for _, entry in ipairs(occupantsOf(myZone)) do
		if teamMode() or isTeammate(entry.player) then
			local theirs = ((entry.pos - spot) * Vector3.new(1, 0, 1)).Magnitude
			-- Only leave it to them when they are basically on it and you are not
			-- (live, deferring more loosely lost points when teammates missed).
			if theirs < 5 and mine > 10 then
				return entry
			end
		end
	end
	return nil
end

-- Where a hit in direction dir would end up, following wall bounces.
local function simulate(kind, state, zones, ballPos, dir, now, quality)
	local origin, unit = Ball.Inside(zones, ballPos, dir)
	local ok, nextState = pcall(Ball.Hits[kind], state.Multipliers, origin, unit, now, quality, { Boost = 1 })
	if not ok or type(nextState) ~= "table" then
		return nil
	end
	local banked = nextState.Reflect == true
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
	return Ball.At(nextState, nextState.EndTime), nextState.EndTime - now, banked, nextState
end

local function chooseDirection(kind, state, zones, myZone, ballPos, now, quality)
	local candidates = {}
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local land, flight, banked, finalState = simulate(kind, state, zones, ballPos, dir, now, quality)
		local viaEmpty = false
		-- Wall shots that come back over your own square, or that land right
		-- on a square's edge, are too easy to get wrong (one came back into
		-- your own square live), so skip them.
		if land and banked and finalState then
			local okOrigin, back = pcall(function()
				for t = finalState.Time, finalState.EndTime, 0.05 do
					local p = Ball.At(finalState, t)
					if Ball.ZoneAt(zones, p) == myZone and p.Y - Ball.Ground(p).Y < 14 then
						return true
					end
				end
				return false
			end)
			if okOrigin and back then
				land = nil
			end
		end
		if land then
			local edgeZone = Ball.ZoneAt(zones, land)
			if edgeZone then
				local rel = edgeZone.CFrame:PointToObjectSpace(land)
				local margin = math.min(edgeZone.Size.X / 2 - math.abs(rel.X), edgeZone.Size.Z / 2 - math.abs(rel.Z))
				if margin < 2.5 then
					land = nil
				end
			end
		end
		if land then
			local zone = Ball.ZoneAt(zones, land)
			if zone and not zone:GetAttribute("Occupied") then
				-- An empty square doesn't end the point: the game bounces the
				-- ball slowly into the MIDDLE of the nearest player's square
				-- (Ball.BounceTo), so judge the shot by where that lands.
				local target = Ball.BounceTarget(zones, land)
				zone = target or zone
				if target and finalState then
					local ok, bounced = pcall(Ball.BounceTo, finalState, target.Position)
					if ok and type(bounced) == "table" then
						land = Ball.At(bounced, bounced.EndTime)
						flight = bounced.EndTime - now
						viaEmpty = true
					end
				end
			end
			if zone and zone ~= myZone and zone:GetAttribute("Occupied") then
				-- Score by the nearest enemy in that square (team modes have
				-- two or three), and never aim at a square with a teammate.
				local friendly, who, far = false, nil, nil
				for _, entry in ipairs(occupantsOf(zone)) do
					if isTeammate(entry.player) then
						friendly = true
						break
					end
					local d = ((entry.pos - land) * Vector3.new(1, 0, 1)).Magnitude
					if not far or d < far then
						far, who = d, entry.player
					end
				end
				if not friendly then
					table.insert(candidates, { dir = dir, far = far or 10, flight = flight, who = who, banked = banked, land = land, viaEmpty = viaEmpty })
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
			-- Trick shot: now and then go for a bank shot off a wall.
			if brain.preferBank and option.banked then
				option.score += 12
			end
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
		if brain.jumpServe then
			stats.jumpServes = (stats.jumpServes or 0) + 1
		end
		if brain.diveSpike then
			stats.diveSpikes = (stats.diveSpikes or 0) + 1
		end
		if brain.heldCombo then
			stats.abilityCombos = (stats.abilityCombos or 0) + 1
		end
		brain.jumpServe, brain.diveSpike, brain.heldCombo = false, false, false
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
	-- In the air after a spike swing the game's Swing won't hit again until
	-- you land, so an emergency bump in the air is a direct hit (live, a save
	-- was lost this way when the server rejected a combo set mid-jump).
	local hum = char:FindFirstChildOfClass("Humanoid")
	local inAir = hum and hum.FloorMaterial == Enum.Material.Air
	if humanizing() and not (inAir and kind == "Bump") then
		-- Swing like a player: the game's own Swing plays the bump/spike
		-- animation and makes the hit. Count it once the game logs the hit.
		brain.pendingKind, brain.pendingPick, brain.pendingQuality = resolvedKind, pick, quality
		local ok = pcall(BallController.Swing, BallController)
		elevate()
		return ok
	end
	if inAir and kind == "Bump" and type(BallController._tracks) == "table" and BallController._tracks.Bump then
		pcall(function()
			BallController._tracks.Bump:Play()
		end)
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
		elseif kind == "Fake" then
			kind = "Fake spike"
		elseif kind == "Tip" then
			stats.tips = (stats.tips or 0) + 1
		else
			stats.bumps += 1
		end
		if pick then
			stats.aimed = (stats.aimed or 0) + 1
			if pick.viaEmpty then
				stats.emptyAims = (stats.emptyAims or 0) + 1
			end
		end
		if pick and pick.banked then
			stats.banks = (stats.banks or 0) + 1
			kind = kind .. " off the wall"
		end
		local target = pick and pick.who and pick.who.DisplayName or nil
		stats.lastHit = kind .. (target and (" at " .. target) or "")
			.. (pick and pick.flight and string.format(" (%.1fs)", pick.flight) or "")
		STATE.playStatus = "Hit: " .. stats.lastHit
	end
end

-- Combo: set the ball up to yourself (a short pop inside your own square),
-- then the spike plan below jumps and spikes it.
local pathAt -- defined further down with the flight chain helpers
local function trySetToSelf(char, root, state, zones, myZone, ballPos, now, second)
	local maxHits = Ball.GetMaxHits()
	local used = (state.HitZone == myZone and tonumber(state.Hits)) or 0
	if used + 2 > maxHits then
		return false
	end
	local center = Vector3.new(myZone.Position.X, ballPos.Y, myZone.Position.Z)
	local toCenter = (center - ballPos) * Vector3.new(1, 0, 1)
	-- Check the pop stays in your square and comes down at spike height.
	-- Check the pop (and any bounce off a wall) stays in your square and
	-- comes down at spike height. Returns whether it works and if it banked.
	local function popWorks(dir)
		local origin, unit = Ball.Inside(zones, ballPos, dir)
		local ok, popped = pcall(Ball.Hits.Set, state.Multipliers, origin, unit, now)
		if not ok or type(popped) ~= "table" then
			return false
		end
		local chain = { popped }
		local current = popped
		for _ = 1, 2 do
			if not current.Reflect then
				break
			end
			local okBounce, bounced = pcall(Ball.Bounce, current)
			if not okBounce or type(bounced) ~= "table" then
				break
			end
			table.insert(chain, bounced)
			current = bounced
		end
		for t = now + 0.5, math.min(chain[#chain].EndTime, now + 3), 0.05 do
			local p, velocity = pathAt(chain, t)
			if Ball.ZoneAt(zones, p) ~= myZone then
				return false
			end
			local h = p.Y - Ball.Ground(p).Y
			if velocity.Y < 0 and h <= 15.5 and h >= 8.5 then
				return true, #chain > 1
			end
		end
		return false
	end
	local look = (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local dir, banked
	-- Pro Plays: now and then pop it off your own wall and back to yourself.
	if STATE.trickShots == true and math.random() < 0.3 then
		local axes = { myZone.CFrame.RightVector, -myZone.CFrame.RightVector, myZone.CFrame.LookVector, -myZone.CFrame.LookVector }
		for _, axis in ipairs(axes) do
			local flat = (axis * Vector3.new(1, 0, 1))
			if flat.Magnitude > 0.1 then
				local works, viaWall = popWorks(flat.Unit)
				if works and viaWall then
					dir, banked = flat.Unit, true
					break
				end
			end
		end
	end
	-- Otherwise pop it the way you already face (no turn needed), then
	-- toward the middle of your square.
	if not dir then
		if popWorks(look) then
			dir = look
		elseif toCenter.Magnitude > 3 and popWorks(toCenter.Unit) then
			dir = toCenter.Unit
		else
			return false
		end
	end
	if banked then
		stats.wallSets = (stats.wallSets or 0) + 1
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
		brain.comboSets = (second and brain.comboSets or 0) + 1
		-- A long combo (set, set, spike) when the touch limit allows it.
		brain.comboDouble = not second and STATE.trickShots == true and used + 3 <= maxHits and math.random() < 0.35
		if second then
			stats.longCombos = (stats.longCombos or 0) + 1
			STATE.playStatus = "Combo: second set"
		else
			stats.combos = (stats.combos or 0) + 1
			STATE.playStatus = "Combo: set up a spike"
		end
		return true
	end
	brain.pendingKind = nil
	return false
end

-- Tip: a soft set over into the next square, landing far from that player,
-- instead of a hard hit (pros mix these in so they're hard to read).
local function tryTip(char, root, state, zones, myZone, ballPos, now)
	local dir, pick = chooseDirection("Set", state, zones, myZone, ballPos, now, 1)
	if not dir or not pick or pick.far < 14 then
		return false
	end
	face(root, dir)
	if humanizing() and type(BallController._tracks) == "table" and BallController._tracks.Bump then
		pcall(function()
			BallController._tracks.Bump:Play()
		end)
	end
	brain.pendingKind, brain.pendingPick, brain.pendingQuality = "Tip", pick, 1
	local ok, hit = pcall(BallController.Hit, BallController, "Set")
	elevate()
	if ok and hit then
		STATE.playStatus = "Tipped it over"
		return true
	end
	brain.pendingKind = nil
	return false
end

-- Fake spike: you jump and swing like a spike, but softly tip it over the
-- line instead (into a square, landing far from that player).
function brain.tryFake(char, root, state, zones, myZone, ballPos, now)
	-- A soft tip over the line when you're close enough to one, otherwise a
	-- slow high lob deep into their square (a bump from the air).
	local kind = "Set"
	local dir, pick = chooseDirection("Set", state, zones, myZone, ballPos, now, 1)
	if not dir or not pick or pick.far < 10 then
		kind = "Bump"
		dir, pick = chooseDirection("Bump", state, zones, myZone, ballPos, now, 1)
		if not dir or not pick then
			return false
		end
	end
	face(root, dir)
	if type(BallController._tracks) == "table" and BallController._tracks.Spike then
		pcall(function()
			BallController._tracks.Spike:Play()
		end)
	end
	brain.pendingKind, brain.pendingPick, brain.pendingQuality = "Fake", pick, 1
	local ok, hit = pcall(BallController.Hit, BallController, kind)
	elevate()
	if ok and hit then
		stats.fakes = (stats.fakes or 0) + 1
		STATE.playStatus = "Fake spike: tipped it"
		return true
	end
	brain.pendingKind = nil
	return false
end

-- How far the game's dive slides in t seconds (same curve as the game:
-- speed eases from 120 down to 30 over half a second, times Dive.Boost).
function brain.diveReach(t)
	local module = AbilityModules.Dive
	local boost = module and tonumber(module.Boost) or 1
	local duration = module and tonumber(module.Duration) or 0.5
	local distance, step = 0, 1 / 120
	local s = 0
	while s < math.min(t, duration) do
		local x = math.min(s / duration, 1)
		local ease = 1 - (1 - x) ^ 2
		distance += (120 + (30 - 120) * ease) * boost * step
		s += step
	end
	return distance
end

-- Learned base: remember where balls hit into your square came down (relative
-- to the square) and wait at a spot that covers them, nudged 60% of the way
-- from the middle toward their average. Needs a few balls before it moves.
local landingMemory = {}
function brain.rememberLanding(zone, spot)
	local rel = zone.CFrame:PointToObjectSpace(spot)
	table.insert(landingMemory, Vector3.new(rel.X, 0, rel.Z))
	while #landingMemory > 24 do
		table.remove(landingMemory, 1)
	end
end
function brain.learnedBase(zone)
	if #landingMemory < 4 then
		return Vector3.zero
	end
	local sum = Vector3.zero
	for _, rel in ipairs(landingMemory) do
		sum += rel
	end
	local avg = sum / #landingMemory * 0.6
	local limitX, limitZ = zone.Size.X / 2 - 5, zone.Size.Z / 2 - 5
	local clamped = Vector3.new(math.clamp(avg.X, -limitX, limitX), 0, math.clamp(avg.Z, -limitZ, limitZ))
	return zone.CFrame:VectorToWorldSpace(clamped) * Vector3.new(1, 0, 1)
end
STATE.landingMemory = landingMemory

-- Read the hitter: the ball is about to come down in another player's square.
-- Look at which way they're facing and work out (with the game's own ball
-- maths) where a hit that way would land. If that's in your square, return
-- the spot so you can start leaning there before they even touch it.
local landingSpot -- defined further down (needs the flight chain helpers)
local readCache = { at = 0, key = nil, spot = nil }
function brain.readHitter(state, zones, myZone, now)
	if os.clock() - readCache.at < 0.2 and readCache.key == brain.stateKey then
		return readCache.spot
	end
	readCache.at, readCache.key, readCache.spot = os.clock(), brain.stateKey, nil
	if state.Dead or state.HitBy == LocalPlayer then
		return nil
	end
	local land, landTime = landingSpot(state, now)
	-- Only in the last moment before their touch: in this game you aim with
	-- the way you face, and players keep turning until they hit.
	if not land or landTime - now > 0.7 then
		return nil
	end
	local theirZone = Ball.ZoneAt(zones, land)
	if not theirZone or theirZone == myZone then
		return nil
	end
	-- The player in that square nearest to where it comes down.
	local hitter, best
	for _, entry in ipairs(occupantsOf(theirZone)) do
		local d = ((entry.pos - land) * Vector3.new(1, 0, 1)).Magnitude
		if not best or d < best then
			hitter, best = entry, d
		end
	end
	local char = hitter and hitter.player.Character
	local theirRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not theirRoot then
		return nil
	end
	local look = theirRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		return nil
	end
	local contact = land + Vector3.new(0, 5, 0)
	local spot = simulate("Bump", state, zones, contact, look.Unit, landTime, 1)
	if spot and Ball.ZoneAt(zones, spot) == myZone then
		readCache.spot = Ball.Contain(spot)
	end
	return readCache.spot
end

-- Turn like a mouse would: fast, but never an instant snap.
local function yawOf(vector)
	return math.atan2(-vector.X, -vector.Z)
end
local function turnToward(root, dir, rate)
	local flat = dir * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 then
		return true
	end
	local current = yawOf(root.CFrame.LookVector)
	local goal = yawOf(flat.Unit)
	local diff = (goal - current + math.pi) % (2 * math.pi) - math.pi
	local step = rate * math.clamp(brain.dt or (1 / 60), 1 / 240, 1 / 20)
	local done = math.abs(diff) <= step
	local yaw = done and goal or (current + math.sign(diff) * step)
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	return done
end
brain.turnToward = turnToward

-- Walk like someone on a keyboard: with the camera behind you (shift lock),
-- WASD only gives 8 directions relative to where you face, so the path is
-- made of those, with a fine adjustment right at the end. Urgent runs (a
-- ball about to land) go straight.
local function moveTo(hum, root, spot, urgent)
	if STATE.autoMove ~= true then
		return
	end
	if humanizing() then
		spot += brain.offset
	end
	local goal = Vector3.new(spot.X, root.Position.Y, spot.Z)
	local delta = goal - root.Position
	if STATE.playerMove ~= true or urgent or delta.Magnitude < 2.5 then
		hum:MoveTo(goal)
		return
	end
	local facing = yawOf(root.CFrame.LookVector)
	local want = yawOf(delta.Unit)
	local rel = (want - facing + math.pi) % (2 * math.pi) - math.pi
	local key = math.floor(rel / (math.pi / 4) + 0.5)
	-- Hold a "key" for a moment instead of switching every frame.
	if brain.walkKey and brain.walkKey ~= key and os.clock() - (brain.walkKeyAt or 0) < 0.12 then
		key = brain.walkKey
	elseif brain.walkKey ~= key then
		brain.walkKey, brain.walkKeyAt = key, os.clock()
	end
	local yaw = facing + key * math.pi / 4
	local step = CFrame.Angles(0, yaw, 0).LookVector * math.min(delta.Magnitude, 6)
	hum:MoveTo(root.Position + Vector3.new(step.X, 0, step.Z))
end

-- The ball's whole path from now: its current flight plus any wall bounces
-- that follow (worked out once per flight, it's a few hundred raycasts).
local chainCache = { key = nil, chain = nil }
local function flightChain(state)
	if chainCache.key == state and chainCache.chain then
		return chainCache.chain
	end
	local chain = { state }
	local current = state
	for _ = 1, 3 do
		if not current.Reflect then
			break
		end
		local ok, bounced = pcall(Ball.Bounce, current)
		if not ok or type(bounced) ~= "table" then
			break
		end
		table.insert(chain, bounced)
		current = bounced
	end
	chainCache.key, chainCache.chain = state, chain
	return chain
end

function pathAt(chain, t)
	for _, part in ipairs(chain) do
		if t <= part.EndTime then
			return Ball.At(part, t), Ball.VelocityAt(part, t)
		end
	end
	local last = chain[#chain]
	return Ball.At(last, last.EndTime), Ball.VelocityAt(last, last.EndTime)
end

local function pathEnd(chain)
	return chain[#chain].EndTime
end

function landingSpot(state, now)
	if state.Dead then
		return nil
	end
	local chain = flightChain(state)
	local last = chain[#chain]
	if last.Reflect or last.EndTime > now + 10 then
		return nil
	end
	return Ball.Contain(Ball.At(last, last.EndTime)), last.EndTime
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
	-- A new reaction only when a player actually hits it (not when it bounces
	-- off a wall, which also starts a new flight).
	local hitKey = state.HitAt or state.Time
	if hitKey ~= brain.stateKey then
		brain.stateKey = hitKey
		local range = REACTION_TIMES[STATE.reaction] or REACTION_TIMES.Normal
		-- Your own touch (set, serve toss): you already know where it's going.
		local mine = state.HitBy == LocalPlayer or now - (tonumber(BallController._lastHit) or 0) < 1.5
		brain.reactAt = os.clock() + ((humanizing() and not mine) and randomBetween(range[1], range[2]) or 0)
		local angle = math.random() * math.pi * 2
		local radius = humanizing() and randomBetween(0.2, 1.3) or 0
		brain.offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		brain.skipSpike = humanizing() and math.random() < 0.12
		brain.aimDir = nil
		brain.preferBank = STATE.trickShots == true and math.random() < 0.3
	end
	local myZone = Ball.ZoneAt(zones, root.Position)
	if not myZone then
		STATE.playStatus = "Not in a square"
		return
	end
	-- Learn where other players' hits into your square come down.
	if brain.learnKey ~= brain.stateKey and state.HitBy and state.HitBy ~= LocalPlayer then
		brain.learnKey = brain.stateKey
		local land = landingSpot(state, now)
		if land and Ball.ZoneAt(zones, land) == myZone then
			brain.rememberLanding(myZone, land)
		end
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
			local served = false
			if humanizing() then
				served = pcall(BallController.Swing, BallController)
			else
				local ok, result = pcall(BallController.Hit, BallController, "Toss")
				served = ok and result
			end
			elevate()
			if served then
				stats.serves += 1
				STATE.playStatus = "Served"
				-- Mixed serves so nobody can read them: mostly jump serves
				-- (toss then spike), sometimes a soft tip serve or a float
				-- serve (toss then bump).
				brain.serveStyle, brain.serveStyleUntil = nil, 0
				if STATE.trickShots == true and STATE.autoSpike == true then
					local roll = math.random()
					local style = roll < 0.5 and "jump" or (roll < 0.75 and "tip" or "float")
					brain.serveStyle, brain.serveStyleUntil = style, os.clock() + 4
					if style == "jump" then
						brain.comboUntil = os.clock() + 3
						brain.comboDouble = false
						brain.skipSpike = false
						brain.jumpServe = true
					else
						brain.comboUntil = 0
					end
				end
			end
		end
		return
	end

	brain.serveAt = nil
	local ballNow = Ball.Contain(Ball.At(state, now))
	local ballHere = Ball.ZoneAt(zones, ballNow) == myZone
	local airborne = hum.FloorMaterial == Enum.Material.Air
	local reacted = os.clock() >= brain.reactAt
	if not reacted then
		-- A hard hit about to land in your square: no time to "think".
		local land, landTime = landingSpot(state, now)
		if land and Ball.ZoneAt(zones, land) == myZone and landTime - now < 0.75 then
			reacted = true
		end
	end
	-- Someone else touched it: whatever combo you had going is over.
	if state.HitBy ~= nil and state.HitBy ~= LocalPlayer then
		brain.comboUntil = 0
		brain.jumpServe, brain.diveSpike = false, false
	end
	local inCombo = os.clock() < brain.comboUntil
	if inCombo then
		brain.skipSpike = false
	end

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
			if STATE.playerMove == true then
				turnToward(root, dir, 11)
			else
				local goal = CFrame.lookAt(root.Position, root.Position + dir)
				root.CFrame = root.CFrame:Lerp(goal, 0.22)
			end
		end
	end
	if brain.turning and os.clock() - brain.turning > 0.6 then
		brain.turning = nil
		if STATE.playerMove ~= true then
			hum.AutoRotate = true
		end
	end
	-- Player Movement steers the facing for the whole rally (shift-lock
	-- style), so the game's auto-turn stays off instead of flicking on/off.
	if STATE.playerMove == true then
		hum.AutoRotate = false
		brain.facing = true
		brain.lastFaceAt = os.clock()
	end

	-- A soft serve style (tip / float) is live for this toss only.
	local softServe = brain.serveStyle and brain.serveStyle ~= "jump" and os.clock() < (brain.serveStyleUntil or 0)
		and (state.HitBy == nil or state.HitBy == LocalPlayer) and state.Toss
	if not softServe and brain.serveStyle and brain.serveStyle ~= "jump" and (os.clock() >= (brain.serveStyleUntil or 0) or not state.Toss) then
		brain.serveStyle = nil
	end

	-- Ability combos: a ball your Magnet is holding above your head, or one
	-- your Frozen has stopped in the air in your square, gets jump-spiked.
	local held = state.Magnet == LocalPlayer or (state.Frozen and ballHere)
	if held and STATE.autoSpike == true and STATE.combos == true and not airborne and not softServe then
		local headTop = char.Head.Position.Y + 7.4
		local flat = Vector3.new(ballNow.X, root.Position.Y, ballNow.Z)
		local away = (flat - root.Position).Magnitude
		local above = ballNow.Y - headTop
		if state.Magnet == LocalPlayer then
			-- The magnet keeps the ball just above your head: just jump.
			if os.clock() - brain.lastJump > 0.8 then
				brain.lastJump = os.clock()
				brain.heldCombo = true
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			STATE.playStatus = "Magnet combo: spiking it"
			return
		elseif above <= 3 and above >= -1 then
			-- Frozen at a spikeable height: get under it and jump.
			moveTo(hum, root, flat, true)
			if away < 3 and os.clock() - brain.lastJump > 0.8 then
				brain.lastJump = os.clock()
				brain.heldCombo = true
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			STATE.playStatus = "Frozen combo: lining up the spike"
			return
		end
		-- Frozen too low or too high to spike: play it normally below.
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
				-- Fake spike: same jump and swing, but a soft tip over instead.
				if brain.fakeJump and brain.tryFake and brain.tryFake(char, root, state, zones, myZone, ballNow, now) then
					brain.fakeJump = false
					return
				end
				brain.fakeJump = false
				tryHit("Spike", char, root, state, zones, myZone, ballNow, now)
				return
			elseif not below and os.clock() - brain.lastJump < 0.9 then
				STATE.playStatus = "Waiting for the spike"
				-- Keep turning toward the shot while in the air.
				if STATE.playerMove == true and brain.aimDir and brain.aimKey == brain.stateKey then
					hum.AutoRotate = false
					brain.turning = os.clock()
					turnToward(root, brain.aimDir, 11)
				end
				return
			end
		end
	end

	-- Bump when it is in reach (or set it up to yourself for a combo).
	if ballHere and Ball.InRange("Bump", root.Position, ballNow) and reacted then
		local low = ballNow.Y - Ball.Ground(ballNow).Y < 6
		local secondSet = inCombo and brain.comboDouble and (brain.comboSets or 0) == 1 and not airborne
		if softServe and not airborne and os.clock() - brain.lastTry > 0.1 then
			-- Tip serve or float serve on your own toss.
			brain.lastTry = os.clock()
			local style = brain.serveStyle
			brain.serveStyle = nil
			local done = style == "tip" and tryTip(char, root, state, zones, myZone, ballNow, now)
			if not done then
				tryHit("Bump", char, root, state, zones, myZone, ballNow, now)
			end
			stats[style == "tip" and "tipServes" or "floatServes"] = (stats[style == "tip" and "tipServes" or "floatServes"] or 0) + 1
			STATE.playStatus = style == "tip" and "Tip serve" or "Float serve"
		elseif secondSet and os.clock() - brain.lastTry > 0.1 then
			brain.lastTry = os.clock()
			brain.comboDouble = false
			if not trySetToSelf(char, root, state, zones, myZone, ballNow, now, true) then
				STATE.playStatus = "Combo: going for the spike"
			end
		elseif inCombo and not low and not airborne then
			STATE.playStatus = "Combo: waiting to spike"
		elseif os.clock() - brain.lastTry > 0.1 then
			brain.lastTry = os.clock()
			local done = false
			-- Pro plays: now and then tip it softly over instead.
			if STATE.trickShots == true and not airborne and not inCombo and math.random() < 0.18 then
				done = tryTip(char, root, state, zones, myZone, ballNow, now)
			end
			if not done and STATE.combos == true and STATE.autoSpike == true and not airborne and not inCombo
				and math.random() < (COMBO_CHANCE[STATE.comboChance] or 70) / 100 then
				done = trySetToSelf(char, root, state, zones, myZone, ballNow, now)
			end
			if not done then
				tryHit("Bump", char, root, state, zones, myZone, ballNow, now)
			end
		end
		return
	end

	-- Spike plan: a point on the way down that you can get under, where the
	-- ball will be 0-2.5 studs above your head at the top of your jump (that's
	-- a PERFECT spike in the game's maths, which also powers Superspike).
	local waitForSecondSet = inCombo and brain.comboDouble and (brain.comboSets or 0) == 1 or softServe
	if STATE.autoSpike == true and not airborne and reacted and (inCombo or not brain.skipSpike) and not waitForSecondSet and not state.Tornado then
		local headTop = char.Head.Position.Y + 7.4
		local chain = flightChain(state)
		for t = now + 0.42, math.min(pathEnd(chain), now + 4), 0.03 do
			local raw, velocity = pathAt(chain, t)
			local p = Ball.Contain(raw)
			if Ball.ZoneAt(zones, p) == myZone and velocity.Y < 0 then
				local above = p.Y - headTop
				if above <= 2.5 and above >= -0.3 then
					local flat = Vector3.new(p.X, root.Position.Y, p.Z)
					local dist = (flat - root.Position).Magnitude
					if STATE.autoMove ~= true and dist > 4 then
						break
					end
					-- Once you've committed to a spike on this ball, stick with
					-- it (no flip-flopping between plans every frame).
					local slack = brain.spikeKey == brain.stateKey and 6 or 3
					if brain.spikeKey ~= brain.stateKey and teammateCloser(myZone, root, p) then
						break -- teammate's spike
					end
					if dist <= hum.WalkSpeed * (t - now - 0.42) + slack then
						brain.spikeKey = brain.stateKey
						moveTo(hum, root, flat, dist > hum.WalkSpeed * (t - now - 0.42) * 0.8)
						STATE.playStatus = inCombo and "Combo: going up for the spike" or "Lining up a spike"
						if t - now <= 0.8 then
							preAim("Spike", p, t, 1)
						end
						if t - now <= 0.46 and os.clock() - brain.lastJump > 0.8 and not (STATE.ringIncoming and STATE.ringIncoming(1.1)) then
							brain.lastJump = os.clock()
							-- Now and then this jump is a fake: tip instead of spike.
							brain.fakeJump = STATE.trickShots == true and not brain.jumpServe
								and (STATE.testFake == true or math.random() < 0.15)
							if not brain.fakeJump then
								useAbility("spike")
							end
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
	local fullPath = flightChain(state)
	if state.Tornado then
		-- TornadoBall: it spirals for ~3s and finishes in a corner of the
		-- target square. Its dips on the way are not where it ends up, so go
		-- straight to where it finishes and wait for it there.
		local finish = Ball.Contain(Ball.At(state, state.EndTime))
		if Ball.ZoneAt(zones, finish) == myZone and state.EndTime > now then
			target, targetTime = finish, state.EndTime
			brain.tornadoTarget = true
		end
	else
		brain.tornadoTarget = false
		for t = now, math.min(pathEnd(fullPath), now + 4), 0.03 do
			local p = Ball.Contain((pathAt(fullPath, t)))
			if Ball.ZoneAt(zones, p) == myZone and p.Y - Ball.Ground(p).Y <= 8 then
				target, targetTime = p, t
				break
			end
		end
	end
	-- Never lose sight of a ball that is going to land in your square.
	if not target then
		local land, landTime = landingSpot(state, now)
		if land and Ball.ZoneAt(zones, land) == myZone and landTime > now then
			target, targetTime = land, landTime
		end
	end
	-- In the last moment go for it anyway: a teammate who has not touched it
	-- yet might miss.
	local mate = target and reacted and targetTime - now > 0.8 and teammateCloser(myZone, root, target)
	if target and not reacted then
		STATE.playStatus = "Reacting"
	elseif mate then
		-- Teammate's ball: cover the other side of the square instead.
		local center = Vector3.new(myZone.Position.X, root.Position.Y, myZone.Position.Z)
		local fromMate = (center - mate.pos) * Vector3.new(1, 0, 1)
		local spot = center + (fromMate.Magnitude > 0.5 and fromMate.Unit or Vector3.zero) * math.min(myZone.Size.X, myZone.Size.Z) * 0.22
		moveTo(hum, root, spot)
		if STATE.playerMove == true and brain.faceBall then
			brain.faceBall(root, hum, ballNow)
		end
		STATE.playStatus = "Teammate's ball, covering"
	elseif target then
		local flat = Vector3.new(target.X, root.Position.Y, target.Z)
		local dist = (flat - root.Position).Magnitude
		-- Straight line only when it's tight; otherwise keyboard-style moves.
		local tight = dist / math.max(hum.WalkSpeed, 1) > (targetTime - now) * 0.75
		moveTo(hum, root, flat, tight)
		STATE.playStatus = "Going for the ball"
		if STATE.playerMove == true then
			-- Keep eyes on the ball while you move (shift-lock style).
			if brain.faceBall then brain.faceBall(root, hum, ballNow) end
		end
		if targetTime - now <= 0.8 then
			preAim("Bump", target, targetTime, 1)
		end
		STATE.incomingEta = targetTime - now
		useAbility("incoming")
		local land, landTime = landingSpot(state, now)
		local lands = land and Ball.ZoneAt(zones, land) == myZone
		local left = (lands and landTime or targetTime) - now
		local need = dist / math.max(hum.WalkSpeed, 1)
		if lands and need > left and left < 1 then
			useAbility("save")
		end
		-- Dive timed to the distance: the game's dive is a fast slide (about
		-- 35 studs in half a second), so start it when the slide will arrive
		-- with the ball, not a fixed half second early (that overshoots close
		-- balls).
		local landFlat = land and Vector3.new(land.X, root.Position.Y, land.Z)
		local landDist = landFlat and (landFlat - root.Position).Magnitude or dist
		local slide = brain.diveReach(math.max(left - 0.04, 0))
		local walkTooSlow = landDist / math.max(hum.WalkSpeed, 1) > left
		if STATE.autoDive == true and lands and walkTooSlow and left <= 0.55 and slide <= landDist + 3 and not (STATE.ringIncoming and STATE.ringIncoming(1.1))
			and landDist < 40 and os.clock() - brain.lastDive > 1 then
			brain.lastDive = os.clock()
			face(root, ((landFlat or flat) - root.Position).Unit)
			local ok = pcall(AbilityController.Activate, AbilityController, "Dive")
			elevate()
			if ok then
				stats.dives += 1
				STATE.playStatus = "Dived"
				-- Dive saves pop the ball up: follow it with a spike if you can.
				if STATE.trickShots == true and STATE.autoSpike == true then
					brain.comboUntil = os.clock() + 2.5
					brain.comboDouble = false
					brain.diveSpike = true
				end
			end
		end
	elseif STATE.avoidBlasts == true and (function()
		-- The ball blows up when it lands, and the blast reaches 15 studs
		-- (times the round's multiplier), even into the next square. If it's
		-- going to land near you in someone else's square, get clear.
		local land, landTime = landingSpot(state, now)
		if not land or landTime - now > 1.6 or Ball.ZoneAt(zones, land) == myZone then
			return false
		end
		local mult = type(state.Multipliers) == "table" and tonumber(state.Multipliers.BlastRadius) or 1
		local radius = (tonumber(Ball.BlastRadius) or 15) * mult + 3
		local away = (root.Position - land) * Vector3.new(1, 0, 1)
		if away.Magnitude >= radius then
			return false
		end
		local dir = away.Magnitude > 0.5 and away.Unit or (Vector3.new(myZone.Position.X, 0, myZone.Position.Z) - Vector3.new(land.X, 0, land.Z)).Unit
		local spot = root.Position + dir * (radius - away.Magnitude + 2)
		local rel = myZone.CFrame:PointToObjectSpace(spot)
		local limitX, limitZ = myZone.Size.X / 2 - 2, myZone.Size.Z / 2 - 2
		spot = myZone.CFrame:PointToWorldSpace(Vector3.new(math.clamp(rel.X, -limitX, limitX), rel.Y, math.clamp(rel.Z, -limitZ, limitZ)))
		moveTo(hum, root, spot, true)
		STATE.playStatus = "Getting clear of the blast"
		if brain.blastKey ~= brain.stateKey then
			brain.blastKey = brain.stateKey
			stats.blastsAvoided = (stats.blastsAvoided or 0) + 1
		end
		return true
	end)() then
		-- moving away from a blast next door
	else
		-- Wait in your square. Humanized: shuffle around the middle now and
		-- then instead of standing dead still.
		local center = Vector3.new(myZone.Position.X, root.Position.Y, myZone.Position.Z)
		if STATE.playerMove == true then
			-- Ready stance: lean toward where the ball is, like you're reading
			-- the play, with a little wandering, and the odd hop.
			-- (Reading a hitter's facing was tried live and was right only
			-- 3 of 12 times: players turn at the last moment. Not used.)
			local read = nil
			brain.reading = false
			local justHit = now - (tonumber(BallController._lastHit) or 0) < 1.2
			if STATE.proPosition == true then
				-- Pro positioning: wait where balls into your square have
				-- actually been landing this session (it learns), and get back
				-- there right after each of your own touches.
				if brain.readKey ~= brain.stateKey then
					brain.readKey = brain.stateKey
					local angle = math.random() * math.pi * 2
					brain.baseJitter = Vector3.new(math.cos(angle), 0, math.sin(angle)) * randomBetween(0, 1.5)
				end
				if not brain.idleSpot or os.clock() >= brain.idleAt or justHit then
					brain.idleAt = os.clock() + randomBetween(1.2, 3)
					local learned = brain.learnedBase and brain.learnedBase(myZone) or Vector3.zero
					local spot = center + learned + (brain.baseJitter or Vector3.zero)
					if justHit and brain.recoverKey ~= BallController._lastHit then
						brain.recoverKey = BallController._lastHit
						stats.recoveries = (stats.recoveries or 0) + 1
					end
					local rel = myZone.CFrame:PointToObjectSpace(spot)
					local limitX, limitZ = myZone.Size.X / 2 - 3, myZone.Size.Z / 2 - 3
					brain.idleSpot = myZone.CFrame:PointToWorldSpace(Vector3.new(math.clamp(rel.X, -limitX, limitX), rel.Y, math.clamp(rel.Z, -limitZ, limitZ)))
				end
			elseif not brain.idleSpot or os.clock() >= brain.idleAt then
				brain.idleAt = os.clock() + randomBetween(1.2, 3)
				local toward = (ballNow - center) * Vector3.new(1, 0, 1)
				local lean = toward.Magnitude > 1 and toward.Unit * math.min(toward.Magnitude, 30) * randomBetween(0.15, 0.3) or Vector3.zero
				local angle = math.random() * math.pi * 2
				local jitter = Vector3.new(math.cos(angle), 0, math.sin(angle)) * randomBetween(0, 2.5)
				local spot = center + lean + jitter
				local rel = myZone.CFrame:PointToObjectSpace(spot)
				local limitX, limitZ = myZone.Size.X / 2 - 3, myZone.Size.Z / 2 - 3
				brain.idleSpot = myZone.CFrame:PointToWorldSpace(Vector3.new(math.clamp(rel.X, -limitX, limitX), rel.Y, math.clamp(rel.Z, -limitZ, limitZ)))
			end
			if STATE.autoMove == true and (brain.idleSpot - root.Position) * Vector3.new(1, 0, 1) ~= Vector3.zero
				and ((brain.idleSpot - root.Position) * Vector3.new(1, 0, 1)).Magnitude > 1.5 then
				moveTo(hum, root, brain.idleSpot - (humanizing() and brain.offset or Vector3.zero))
			end
			if os.clock() >= (brain.hopAt or 0) then
				brain.hopAt = os.clock() + randomBetween(4, 11)
				-- No idle hops while reading a hitter: be ready to move.
				if math.random() < 0.35 and not airborne and not read then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
			if brain.faceBall then brain.faceBall(root, hum, ballNow) end
		elseif humanizing() then
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
		STATE.playStatus = brain.reading and "Reading the hitter" or "In position"
	end
end

trackConnection(RunService.Heartbeat:Connect(function(dt)
	if not running() then
		return
	end
	brain.dt = dt
	local ok, err = pcall(stepBrain)
	if not ok then
		STATE.playStatus = "Error: " .. tostring(err)
	end
	-- Hand turning back to the game when the hub isn't steering it (with
	-- Player Movement that's only once you're out of the round).
	local keepSteering = STATE.playerMove == true and STATE.autoHit == true and arenaName() ~= nil
	if brain.facing and not brain.turning and not keepSteering and os.clock() - (brain.lastFaceAt or 0) > 0.4 then
		brain.facing = false
		local _, _, hum = character()
		if hum then
			hum.AutoRotate = true
		end
	end
end))

-- Move Like A Player ------------------------------------------------------------
-- Face the ball (like shift lock), emote after kills and wins, and walk around
-- the lobby between rounds instead of standing still.
local EmoteInfo = safeRequire(Info:FindFirstChild("Emotes")) or {}
local EmoteController = safeRequire(Controllers:FindFirstChild("EmoteController"))
local EMOTE_NAMES = {}
for name in pairs(EmoteInfo) do
	table.insert(EMOTE_NAMES, name)
end

function brain.faceBall(root, hum, ballPos)
	if brain.turning then
		return
	end
	local flat = (ballPos - root.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 2 then
		return
	end
	hum.AutoRotate = false
	brain.facing = true
	brain.lastFaceAt = os.clock()
	-- Calm tracking: small differences are left alone (no robotic
	-- locked-on look), bigger ones turn at a human pace.
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude > 0.01 and look.Unit:Dot(flat.Unit) > 0.985 then
		return
	end
	turnToward(root, flat.Unit, 5.5)
end

local function playEmote()
	if not EmoteController or #EMOTE_NAMES == 0 or type(EmoteController._tracks) ~= "table" then
		return false
	end
	local name = EMOTE_NAMES[math.random(1, #EMOTE_NAMES)]
	if not EmoteController._tracks[name] then
		return false
	end
	local ok = pcall(EmoteController.Play, EmoteController, name)
	elevate()
	if ok then
		stats.emotes = (stats.emotes or 0) + 1
	end
	return ok
end
STATE.playEmote = playEmote

local function ballComingAtMe()
	local ball = arenaBall()
	local _, root = character()
	if not ball or not root or type(ball.State) ~= "table" or ball.State.Dead or type(ball.Zones) ~= "table" then
		return false
	end
	local myZone = Ball.ZoneAt(ball.Zones, root.Position)
	local land = landingSpot(ball.State, workspace:GetServerTimeNow())
	local now = Ball.Contain(Ball.At(ball.State, workspace:GetServerTimeNow()))
	return myZone ~= nil and ((land and Ball.ZoneAt(ball.Zones, land) == myZone) or Ball.ZoneAt(ball.Zones, now) == myZone)
end

local lobby = { anchor = nil, nextWalk = 0, emoteAt = nil, nextLobbyEmote = 0 }
local practicePad
do
	local objects = workspace:FindFirstChild("GameObjects")
	practicePad = objects and objects:FindFirstChild("EnterPractice")
end

local function safeLobbySpot(root, char)
	for _ = 1, 6 do
		local angle = math.random() * math.pi * 2
		local radius = randomBetween(3, 11)
		local spot = lobby.anchor + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local nearPractice = practicePad and ((practicePad.Position - spot) * Vector3.new(1, 0, 1)).Magnitude < 22
		if not nearPractice then
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { char }
			local hit = workspace:Raycast(spot + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
			if hit and hit.Instance and hit.Instance.CanCollide and math.abs(hit.Position.Y - (root.Position.Y - 3)) < 4 then
				return Vector3.new(spot.X, root.Position.Y, spot.Z)
			end
		end
	end
	return nil
end

local lastWins, lastElims = nil, nil
task.spawn(function()
	while running() do
		pcall(function()
			if STATE.playerMove ~= true then
				return
			end
			local char, root, hum = character()
			if not char then
				return
			end
			-- Celebrate kills and wins now and then.
			local wins, elims = leaderstat("Wins"), leaderstat("Eliminations")
			if lastWins and STATE.emotes == true then
				if wins > lastWins and math.random() < 0.6 then
					lobby.emoteAt = os.clock() + randomBetween(0.8, 2)
				elseif elims > lastElims and math.random() < 0.35 then
					lobby.emoteAt = os.clock() + randomBetween(0.5, 1.5)
				end
			end
			lastWins, lastElims = wins, elims
			if lobby.emoteAt and os.clock() >= lobby.emoteAt then
				if not ballComingAtMe() and hum.FloorMaterial ~= Enum.Material.Air then
					lobby.emoteAt = nil
					playEmote()
				elseif os.clock() - lobby.emoteAt > 6 then
					lobby.emoteAt = nil
				end
			end
			-- Lobby: wander around near where you are, hop, sometimes emote.
			if arenaName() then
				lobby.anchor = nil
				return
			end
			if STATE.lobbyWander ~= true or os.clock() - (STATE.proJoinAt or 0) < 10 then
				return
			end
			if not lobby.anchor or (lobby.anchor - root.Position).Magnitude > 40 then
				lobby.anchor = root.Position
				lobby.nextWalk = os.clock() + randomBetween(2, 5)
			end
			if os.clock() >= lobby.nextWalk then
				lobby.nextWalk = os.clock() + randomBetween(5, 14)
				local spot = safeLobbySpot(root, char)
				if spot then
					hum:MoveTo(spot)
				end
				if math.random() < 0.25 then
					task.delay(randomBetween(0.3, 1.2), function()
						if running() and not arenaName() then
							hum:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end)
				end
			end
			if STATE.emotes == true and os.clock() >= lobby.nextLobbyEmote then
				lobby.nextLobbyEmote = os.clock() + randomBetween(25, 70)
				if math.random() < 0.3 and hum.MoveDirection.Magnitude < 0.1 then
					playEmote()
				end
			end
		end)
		elevate()
		task.wait(0.5)
	end
end)

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
-- The next ability to buy: in "All abilities" mode the cheapest one you don't
-- own yet (skipping any you said not to buy), otherwise the one you picked.
local function nextAbilityToBuy()
	if STATE.abilityBuyMode ~= "All abilities" then
		return STATE.abilityGoal
	end
	for _, name in ipairs(ABILITY_OPTIONS) do
		if not ownsAbility(name) and not table.find(STATE.skipAbilities or {}, name) then
			return name
		end
	end
	return nil
end
STATE.nextAbilityToBuy = nextAbilityToBuy

local function stepShop()
	local coins = tonumber(dataGet("Money")) or 0
	local goal = nextAbilityToBuy()
	local goalData = goal and AbilityInfo[goal]
	local goalPrice = goalData and tonumber(goalData.Price) or 0
	local saving = 0
	local parts = {}

	if STATE.autoBuyAbility == true and STATE.abilityBuyMode == "All abilities" and not goal then
		table.insert(parts, "Every ability bought" .. (#(STATE.skipAbilities or {}) > 0 and (" (skipping " .. table.concat(STATE.skipAbilities, ", ") .. ")") or ""))
	end
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

	-- Equip your main ability (the one picked in the menu), not whatever was
	-- just bought.
	local main = STATE.abilityGoal
	if STATE.autoEquipAbility == true and main and ownsAbility(main) and equippedAbility() ~= main then
		local event = remote("EquipAbility")
		if event then
			event:FireServer(main)
			noteActivity("Equipped " .. main)
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
	STATE.proJoinAt = os.clock()
	proServer.tries += 1
	root.CFrame = CFrame.new(primary.Position + primary.CFrame.LookVector * 5 + Vector3.new(0, 3, 0))
	task.wait(0.4)
	pcall(fireproximityprompt, prompt)
	STATE.proStatus = "Joining Pro Servers..."
	noteActivity("Joining Pro Servers")
end

-- Dodge Shockwave ----------------------------------------------------------------
-- Shockwave (an enemy passive) sends a short ring out from where their ball
-- blew up: it grows to 60 studs across in 2 seconds and kills anyone it
-- touches. The game's own tip is "Jump to avoid!", so jump just before the
-- ring's edge reaches you.
local shockwaves = {}
local lastDodge = 0
-- Is a Shockwave ring going to reach you within `within` seconds? Then hold
-- dives and spike jumps so you're on the ground and can jump it.
function STATE.ringIncoming(within)
	if STATE.dodgeShockwave ~= true or next(shockwaves) == nil then
		return false
	end
	local _, root = character()
	if not root then
		return false
	end
	for part, info in pairs(shockwaves) do
		if part.Parent then
			local dist = ((root.Position - part.Position) * Vector3.new(1, 0, 1)).Magnitude
			local gap = dist - part.Size.X / 2
			if dist <= 31 and gap > -2.5 and gap / math.max(info.rate or 14.5, 1) <= within then
				return true
			end
		end
	end
	return false
end
trackConnection(workspace.ChildAdded:Connect(function(child)
	if child.Name == "Shockwave" and child:IsA("BasePart") then
		shockwaves[child] = { r = child.Size.X / 2, t = os.clock(), rate = 14.5 }
		stats.shockwavesSeen = (stats.shockwavesSeen or 0) + 1
	end
end))
STATE.shockwaves = shockwaves
trackConnection(RunService.Heartbeat:Connect(function()
	if not running() or next(shockwaves) == nil then
		return
	end
	local _, root, hum = character()
	for part, info in pairs(shockwaves) do
		if not part.Parent then
			shockwaves[part] = nil
		elseif root and STATE.dodgeShockwave == true then
			local radius = part.Size.X / 2
			local now = os.clock()
			if now - info.t > 0.03 then
				local measured = (radius - info.r) / (now - info.t)
				if measured > 1 then
					info.rate = measured
				end
				info.r, info.t = radius, now
			end
			local dist = ((root.Position - part.Position) * Vector3.new(1, 0, 1)).Magnitude
			local gap = dist - radius
			local reaches = dist <= 31
			if reaches then
				info.inRange = true
			end
			if reaches and gap > -2.5 and gap / math.max(info.rate, 1) <= 0.35
				and hum.FloorMaterial ~= Enum.Material.Air and now - lastDodge > 0.6 then
				lastDodge = now
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
				stats.dodges = (stats.dodges or 0) + 1
				noteActivity("Jumped a Shockwave")
			end
		end
	end
end))

-- Loss recorder: when the ball lands in your square or you die, write down
-- what happened (who hit it, how, what you were doing, any ability or
-- Shockwave involved) so a lost point can be explained instead of guessed.
STATE.losses = {}
local statusTrail = {}
local lastTrailStatus = nil
local function recordLoss(entry)
	entry.at = os.date("%H:%M:%S")
	entry.clock = os.clock()
	entry.trail = table.concat(statusTrail, " > ")
	entry.lastEnemyAbility = STATE.lastEnemyAbility
	table.insert(STATE.losses, 1, entry)
	while #STATE.losses > 5 do
		table.remove(STATE.losses)
	end
end
do
	local wasDead = true
	trackConnection(RunService.Heartbeat:Connect(function()
		if not running() then
			return
		end
		local status = STATE.playStatus
		if status ~= lastTrailStatus then
			lastTrailStatus = status
			table.insert(statusTrail, string.format("%.1f %s", os.clock() % 100, tostring(status)))
			while #statusTrail > 6 do
				table.remove(statusTrail, 1)
			end
		end
		local ball = arenaBall()
		local state = ball and ball.State
		if type(state) ~= "table" then
			return
		end
		if state.Dead and not wasDead then
			local _, root = character()
			local zones = ball.Zones
			local myZone = root and type(zones) == "table" and Ball.ZoneAt(zones, root.Position)
			if myZone and Ball.ZoneAt(zones, state.Origin) == myZone then
				local tags = {}
				for _, key in ipairs({ "Magnet", "Tornado", "Frozen", "Burst" }) do
					if state[key] then
						table.insert(tags, key)
					end
				end
				recordLoss({
					what = "Ball landed in your square",
					hitBy = state.HitBy and state.HitBy.Name or "?",
					touchesUsed = state.HitZone == myZone and state.Hits or 0,
					distance = math.floor(((root.Position - state.Origin) * Vector3.new(1, 0, 1)).Magnitude + 0.5),
					ballEffects = #tags > 0 and table.concat(tags, ",") or nil,
				})
			end
		end
		wasDead = state.Dead == true
	end))
	local function watchCharacter(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then
			return
		end
		trackConnection(hum.Died:Connect(function()
			local root = char:FindFirstChild("HumanoidRootPart")
			local ring
			for part, info in pairs(shockwaves) do
				if part.Parent and root then
					local gap = ((root.Position - part.Position) * Vector3.new(1, 0, 1)).Magnitude - part.Size.X / 2
					if math.abs(gap) < 20 then
						ring = string.format("ring edge %.1f studs away, in range=%s", gap, tostring(info.inRange == true))
					end
				end
			end
			-- Dying because the ball landed in your square is already recorded.
			local last = STATE.losses[1]
			if not ring and last and last.what == "Ball landed in your square" and os.clock() - (last.clock or 0) < 2 then
				return
			end
			-- Where the ball was: a blast just over the line can still reach you.
			-- (The game can clear your round tag the moment you die, so fall
			-- back to the ball the game last showed you.)
			local ball = arenaBall()
			if not ball and type(BallController._balls) == "table" and type(BallController._state) == "table" then
				ball = BallController._balls[BallController._state.Arena or "Main"]
			end
			local state = ball and ball.State
			local blast
			if type(state) == "table" and state.Tornado then
				blast = "TornadoBall shot"
			end
			if root and type(state) == "table" then
				local spot = state.Dead and state.Origin or Ball.At(state, workspace:GetServerTimeNow())
				local away = ((root.Position - spot) * Vector3.new(1, 0, 1)).Magnitude
				local zones = ball.Zones
				local mine = type(zones) == "table" and Ball.ZoneAt(zones, root.Position)
				local theirs = type(zones) == "table" and Ball.ZoneAt(zones, spot)
				blast = (blast and (blast .. ", ") or "") .. string.format("ball %d studs away%s", math.floor(away + 0.5),
					(mine and theirs and mine ~= theirs) and " in the next square (blast reaches 15)" or "")
			end
			recordLoss({
				what = ring and "Killed by a Shockwave ring" or "You died",
				shockwave = ring,
				ball = blast,
				hitBy = type(state) == "table" and state.HitBy and state.HitBy.Name or nil,
				inAir = hum.FloorMaterial == Enum.Material.Air,
				sinceDive = brain.lastDive and math.floor((os.clock() - brain.lastDive) * 10) / 10 or nil,
				height = root and math.floor(root.Position.Y) or nil,
				stateAtDeath = tostring(hum:GetState().Name),
			})
		end))
	end
	if LocalPlayer.Character then
		task.spawn(watchCharacter, LocalPlayer.Character)
	end
	trackConnection(LocalPlayer.CharacterAdded:Connect(watchCharacter))
end

-- Remember which abilities other players use on you (the game announces them).
do
	local event = remote("RoundNotification")
	if event then
		trackConnection(event.OnClientEvent:Connect(function(_, text)
			if type(text) ~= "string" then
				return
			end
			local who, ability = string.match(text, "^(.-) used (.-) ability")
			if ability and who ~= LocalPlayer.DisplayName and who ~= LocalPlayer.Name then
				stats.enemyAbilities = stats.enemyAbilities or {}
				stats.enemyAbilities[ability] = (stats.enemyAbilities[ability] or 0) + 1
				STATE.lastEnemyAbility = who .. " used " .. ability
			end
		end))
	end
end

-- Field of view ----------------------------------------------------------------
-- The game zooms the camera to 65-70 when its menus open and close, so the
-- chosen FOV is put back every frame, right after the camera updates.
local FOV_BIND = "ZinoosVolleyFov"
local fovApplied = false
local function applyFov()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if STATE.customFov == true then
		local value = math.clamp(tonumber(STATE.fov) or 90, 30, 120)
		if math.abs(camera.FieldOfView - value) > 0.01 then
			camera.FieldOfView = value
		end
		fovApplied = true
	elseif fovApplied then
		fovApplied = false
		camera.FieldOfView = 70
	end
end
pcall(function()
	RunService:BindToRenderStep(FOV_BIND, Enum.RenderPriority.Camera.Value + 1, applyFov)
end)
hubCleanup(function()
	pcall(RunService.UnbindFromRenderStep, RunService, FOV_BIND)
	if fovApplied and workspace.CurrentCamera then
		workspace.CurrentCamera.FieldOfView = 70
	end
end)

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
	toggle(humanBox, "Pro Plays", "trickShots", "Mixes in pro moves: jump serves, set-set-spike long combos, dive then spike, soft tips over the line, and bank shots off the walls")
	local moveBox = section(playTab, "Move Like A Player", "footprints")
	toggle(moveBox, "Player Movement", "playerMove", "Keeps your eyes on the ball like shift lock, leans toward the play in a ready stance, and hops now and then")
	toggle(moveBox, "Pro Positioning", "proPosition", "Learns where balls land in your square this session and waits in the spot that covers them best, and gets back there right after each of your touches")
	toggle(moveBox, "Emotes", "emotes", "Sometimes emotes after a kill or a win, and now and then in the lobby")
	toggle(moveBox, "Walk Around Lobby", "lobbyWander", "Wanders near where you are between rounds (keeps away from the practice pad)")
	local dangerBox = section(playTab, "Enemy Abilities", "shield")
	toggle(dangerBox, "Dodge Shockwave", "dodgeShockwave", "Jumps over Shockwave rings (they kill anyone they touch) right before they reach you")
	toggle(dangerBox, "Avoid Blasts", "avoidBlasts", "Steps away when the ball is about to blow up within blast range of you in the next square (the blast reaches 15 studs)")
	local dangerInfo = info(dangerBox, "Seen this session", "None yet")
	STATE.drawDanger = function()
		local parts = {}
		for name, count in pairs(stats.enemyAbilities or {}) do
			table.insert(parts, name .. " x" .. count)
		end
		table.sort(parts)
		local loss = STATE.losses and STATE.losses[1]
		local lossText = "No lost points recorded yet"
		if loss then
			lossText = string.format("Last lost point (%s): %s", loss.at, loss.what)
				.. (loss.hitBy and (" · hit by " .. loss.hitBy) or "")
				.. (loss.distance and (" · " .. loss.distance .. " studs from you") or "")
				.. (loss.shockwave and (" · " .. loss.shockwave) or "")
				.. (loss.ball and (" · " .. loss.ball) or "")
		end
		setInfo(dangerInfo, (#parts > 0 and table.concat(parts, " · ") or "None yet")
			.. string.format("\nShockwaves seen: %d · jumped: %d · blasts stepped away from: %d", stats.shockwavesSeen or 0, stats.dodges or 0, stats.blastsAvoided or 0)
			.. (STATE.lastEnemyAbility and ("\nLast: " .. STATE.lastEnemyAbility) or "")
			.. "\n" .. lossText)
	end
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
	toggle(shopBox, "Auto Buy Abilities", "autoBuyAbility", "Buys abilities with your coins as soon as you can afford them")
	local abilityLabels = {}
	choice(shopBox, "Buy", "All abilities = collects every one, cheapest first", BUY_MODE_OPTIONS, "abilityBuyMode")
	choice(shopBox, "Main Ability", "The one you play with (and the one bought in 'Just my main ability' mode)", ABILITY_OPTIONS, "abilityGoal")
	shopBox:Dropdown({
		Title = "Don't Buy",
		Desc = "Skipped in 'All abilities' mode",
		Values = ABILITY_OPTIONS,
		Value = table.clone(STATE.skipAbilities),
		Multi = true,
		AllowNone = true,
		Callback = function(list)
			local chosen = {}
			for _, value in ipairs(type(list) == "table" and list or {}) do
				local name = optionName(value)
				if type(name) == "string" and table.find(ABILITY_OPTIONS, name) then
					table.insert(chosen, name)
				end
			end
			table.sort(chosen)
			local before = table.clone(STATE.skipAbilities)
			table.sort(before)
			if table.concat(chosen, ",") == table.concat(before, ",") then
				return
			end
			elevate()
			STATE.skipAbilities = chosen
			saveConfig()
		end,
	})
	toggle(shopBox, "Auto Equip Main Ability", "autoEquipAbility", "Keeps your main ability equipped (new ones you buy don't replace it)")
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
	local cameraBox = section(playerTab, "Camera", "camera")
	toggle(cameraBox, "Custom FOV", "customFov", "Wider view so you can see more of the court (Roblox default is 70)")
	cameraBox:Slider({
		Title = "Field Of View",
		Desc = "30 = zoomed in · 70 = normal · 120 = widest",
		Step = 1,
		Value = { Min = 30, Max = 120, Default = math.clamp(tonumber(STATE.fov) or 90, 30, 120) },
		Callback = function(value)
			value = tonumber(value)
			if not value or value == STATE.fov then
				return
			end
			STATE.fov = value
			saveConfig()
		end,
	})
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
				humanize = true, reaction = "Normal", combos = true, comboChance = "Often", trickShots = true, playerMove = true, proPosition = true, emotes = true, lobbyWander = true,
				autoVote = true, voteMode = "Solo", autoProServer = true, autoBuyAbility = true, abilityGoal = "Guardian", abilityBuyMode = "Just my main ability", skipAbilities = {}, autoEquipAbility = true,
				autoBuyPacks = true, saveForAbility = false, packChoice = "Both", showTracker = true,
				autoDaily = true, autoQuests = true, autoAchievements = true, autoSpin = true,
				antiAfk = true, stayActive = true, autoReload = true, notifications = true, hideOnStart = false, customFov = false, fov = 90, dodgeShockwave = true, avoidBlasts = true,
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
			"%s session · %d wins · %d eliminations · coins +%s\n%d hits (%d spikes, %d perfect, %d bumps) · %d dives · %d serves · %d abilities\nCombos %d · long combos %d · wall sets %d · fake spikes %d · ability combos %d · dive→spikes %d · tips %d · wall shots %d\nServes: jump %d · tip %d · float %d\nLast: %s",
			clock, wins - stats.wins0, elims - stats.elims0, shortNumber(math.max(0, cash - stats.money0)),
			stats.hits, stats.spikes, stats.perfect, stats.bumps, stats.dives, stats.serves, stats.abilities or 0,
			stats.combos or 0, stats.longCombos or 0, stats.wallSets or 0, stats.fakes or 0, stats.abilityCombos or 0, stats.diveSpikes or 0, stats.tips or 0, stats.banks or 0,
			stats.jumpServes or 0, stats.tipServes or 0, stats.floatServes or 0,
			stats.lastHit
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
		pcall(STATE.drawDanger)
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
