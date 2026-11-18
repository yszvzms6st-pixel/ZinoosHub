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

local VERSION = "1.0.0"
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
	-- Menu
	toggleKey = "RightControl",
	hideOnStart = false,
	hubSize = "Normal",
	windTheme = "Zinoos",
	-- Live
	status = "Starting...",
	playStatus = "Waiting for a round",
	rewardStatus = "Waiting",
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

-- Config ---------------------------------------------------------------------
local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/VolleyBomb_" .. tostring(LocalPlayer.UserId) .. ".rfld"
local SAVE_KEYS = {
	"autoHit", "autoMove", "autoSpike", "autoDive", "autoServe", "smartAim", "aimMode", "autoAbility", "showLanding",
	"autoDaily", "autoQuests", "autoAchievements", "autoSpin",
	"antiAfk", "stayActive", "autoReload", "notifications",
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

-- Brain ------------------------------------------------------------------------
-- Everything below asks the game's own Ball module where the ball will be, so
-- the moves match what the server checks (reach, zones, cooldowns).
local brain = {
	lastTry = 0,
	lastDive = 0,
	lastJump = 0,
	lastServe = 0,
	marker = nil,
}

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
		local bestScore
		for _, option in ipairs(candidates) do
			local score = mode == "Fastest" and -option.flight or (option.far - option.flight * 4)
			if not bestScore or score > bestScore then
				pick, bestScore = option, score
			end
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
	local pick
	if STATE.smartAim == true then
		local dir
		dir, pick = chooseDirection(resolvedKind, state, zones, myZone, ballPos, now, quality)
		face(root, dir)
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

local function moveTo(hum, root, spot)
	if STATE.autoMove ~= true then
		return
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
	local char, root, hum = character()
	if not char or state.Dead then
		STATE.playStatus = state.Dead and "Waiting for the next serve" or "Waiting to respawn"
		return
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
		if STATE.autoServe == true and os.clock() - brain.lastServe > 0.6 then
			brain.lastServe = os.clock()
			local ok, served = pcall(BallController.Hit, BallController, "Toss")
			elevate()
			if ok and served then
				stats.serves += 1
				STATE.playStatus = "Served"
			end
		end
		return
	end

	local ballNow = Ball.Contain(Ball.At(state, now))
	local ballHere = Ball.ZoneAt(zones, ballNow) == myZone
	local airborne = hum.FloorMaterial == Enum.Material.Air

	-- Spike while in the air.
	if airborne and ballHere and STATE.autoSpike == true then
		local reach = Ball.Reach("Spike", root.Position, char)
		if Ball.InRange("Spike", reach, ballNow) and os.clock() - brain.lastTry > 0.05 then
			brain.lastTry = os.clock()
			tryHit("Spike", char, root, state, zones, myZone, ballNow, now)
			return
		end
	end

	-- Bump when it is in reach.
	if ballHere and Ball.InRange("Bump", root.Position, ballNow) then
		if os.clock() - brain.lastTry > 0.1 then
			brain.lastTry = os.clock()
			tryHit("Bump", char, root, state, zones, myZone, ballNow, now)
		end
		return
	end

	-- Spike plan: a point on the way down, 9-15 studs up, that you can get under.
	if STATE.autoSpike == true and not airborne then
		for t = now + 0.42, math.min(state.EndTime, now + 4), 0.03 do
			local p = Ball.Contain(Ball.At(state, t))
			if Ball.ZoneAt(zones, p) == myZone and Ball.VelocityAt(state, t).Y < 0 then
				local height = p.Y - Ball.Ground(p).Y
				if height <= 15 and height >= 9 then
					local flat = Vector3.new(p.X, root.Position.Y, p.Z)
					local dist = (flat - root.Position).Magnitude
					if STATE.autoMove ~= true and dist > 4 then
						break
					end
					if dist <= hum.WalkSpeed * (t - now - 0.42) + 3 then
						moveTo(hum, root, flat)
						STATE.playStatus = "Lining up a spike"
						if t - now <= 0.46 and os.clock() - brain.lastJump > 0.8 then
							brain.lastJump = os.clock()
							if STATE.autoAbility == true then
								pcall(AbilityController.ActivateEquipped, AbilityController)
								elevate()
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
	for t = now, math.min(state.EndTime, now + 4), 0.03 do
		local p = Ball.Contain(Ball.At(state, t))
		if Ball.ZoneAt(zones, p) == myZone and p.Y - Ball.Ground(p).Y <= 8 then
			target, targetTime = p, t
			break
		end
	end
	if target then
		local flat = Vector3.new(target.X, root.Position.Y, target.Z)
		local dist = (flat - root.Position).Magnitude
		moveTo(hum, root, flat)
		STATE.playStatus = "Going for the ball"
		local land, landTime = landingSpot(state, now)
		local lands = land and Ball.ZoneAt(zones, land) == myZone
		local left = (lands and landTime or targetTime) - now
		local need = dist / math.max(hum.WalkSpeed, 1)
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
		-- Wait in the middle of your square.
		local center = Vector3.new(myZone.Position.X, root.Position.Y, myZone.Position.Z)
		if (center - root.Position).Magnitude > 4 then
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
	local abilityBox = section(playTab, "Ability", "zap")
	local abilityInfo = info(abilityBox, "Equipped", "Checking...")
	toggle(abilityBox, "Auto Use Ability", "autoAbility", "Uses your ability right before a spike")

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
			"%s session · %d wins · %d eliminations · coins +%s\n%d hits (%d spikes, %d perfect, %d bumps) · %d dives · %d serves\nLast: %s",
			clock, wins - stats.wins0, elims - stats.elims0, shortNumber(math.max(0, cash - stats.money0)),
			stats.hits, stats.spikes, stats.perfect, stats.bumps, stats.dives, stats.serves, stats.lastHit
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
		task.wait(5)
	end
end)

task.spawn(function()
	while running() do
		task.wait(120)
		pulseAntiAfk()
	end
end)

notify("Zinoos Hub", "Volley Bomb hub v" .. VERSION .. " loaded")
