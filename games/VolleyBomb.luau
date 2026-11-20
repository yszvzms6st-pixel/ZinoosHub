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

local VERSION = "1.27.1"
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
	showPresses = true,
	humanize = true,
	reaction = "Normal",
	nativeFollowups = true,
	trickShots = true,
	spinMoves = true,
	readPlayers = true,
	playerMove = true,
	proPosition = true,
	emotes = true,
	lobbyWander = true,
	autoVote = true,
	voteMode = "Solo",
	autoProServer = true,
	tryhard = false,
	tryhardHops = 0,
	tryhardHold = 0,
	tryhardBest = 0,
	tryhardBestTop = 0,
	tryhardBestId = "",
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
	afk = false,
	stayActive = true,
	autoReload = true,
	-- Alerts
	notifications = true,
	fpsBoost = false,
	showTracker = true,
	customFov = false,
	fov = 90,
	dodgeShockwave = true,
	autoHopEmpty = false,
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
	"autoHit", "autoMove", "autoSpike", "autoDive", "autoServe", "smartAim", "aimMode", "autoAbility", "showLanding", "showPresses", "humanize", "reaction", "nativeFollowups", "trickShots", "spinMoves", "readPlayers", "playerMove", "proPosition", "emotes", "lobbyWander",
	"autoVote", "voteMode", "autoProServer", "tryhard", "tryhardHops", "tryhardHold", "tryhardBest", "tryhardBestTop", "tryhardBestId", "autoBuyAbility", "abilityGoal", "abilityBuyMode", "skipAbilities", "autoEquipAbility", "autoBuyPacks", "saveForAbility", "packChoice",
	"autoDaily", "autoQuests", "autoAchievements", "autoSpin",
	"antiAfk", "afk", "stayActive", "autoReload", "notifications", "fpsBoost", "showTracker", "customFov", "fov", "dodgeShockwave", "avoidBlasts", "autoHopEmpty",
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

-- Potato Mode. Local graphics only: shadows, effects, and textures. Nothing
-- about movement, hits, or speed changes. Turning it off puts the look back.
;(function()
	local Lighting = game:GetService("Lighting")
	local Workspace = game:GetService("Workspace")
	local potatoVisuals = {}
	local potatoChanged = 0
	local potatoEpoch = 0
	local graphicsBefore = nil

	local function owned(object)
		local current = object
		while typeof(current) == "Instance" do
			if current:GetAttribute("ZinoosOwned") == true then
				return true
			end
			current = current.Parent
		end
		return false
	end

	local function potatoSet(object, property, value)
		local saved = potatoVisuals[object]
		if not saved then
			saved = {}
			potatoVisuals[object] = saved
		end
		local firstChange = saved[property] == nil
		if saved[property] == nil then
			local ok, current = pcall(function()
				return object[property]
			end)
			if not ok then
				return false
			end
			saved[property] = { value = current }
		end
		local written = pcall(function()
			object[property] = value
		end)
		if written and firstChange then
			potatoChanged += 1
		end
		return written
	end

	local function simplifyVisual(object)
		if STATE.fpsBoost ~= true or owned(object) or object:IsA("Terrain") then
			return
		end
		if object:IsA("MeshPart") then
			potatoSet(object, "TextureID", "")
			potatoSet(object, "Material", Enum.Material.SmoothPlastic)
			potatoSet(object, "MaterialVariant", "")
			potatoSet(object, "Reflectance", 0)
			potatoSet(object, "CastShadow", false)
			potatoSet(object, "RenderFidelity", Enum.RenderFidelity.Performance)
		elseif object:IsA("BasePart") then
			potatoSet(object, "Material", Enum.Material.SmoothPlastic)
			potatoSet(object, "MaterialVariant", "")
			potatoSet(object, "Reflectance", 0)
			potatoSet(object, "CastShadow", false)
		elseif object:IsA("Decal") or object:IsA("Texture") then
			potatoSet(object, "Transparency", 1)
		elseif object:IsA("SpecialMesh") then
			potatoSet(object, "TextureId", "")
		elseif object:IsA("SurfaceAppearance") then
			for _, property in ipairs({ "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" }) do
				potatoSet(object, property, "")
			end
		elseif object:IsA("ParticleEmitter")
			or object:IsA("Trail")
			or object:IsA("Beam")
			or object:IsA("Smoke")
			or object:IsA("Fire")
			or object:IsA("Sparkles")
			or object:IsA("PointLight")
			or object:IsA("SpotLight")
			or object:IsA("SurfaceLight")
			or object:IsA("PostEffect") then
			potatoSet(object, "Enabled", false)
		elseif object:IsA("Atmosphere") then
			potatoSet(object, "Density", 0)
			potatoSet(object, "Haze", 0)
			potatoSet(object, "Glare", 0)
		elseif object:IsA("Clouds") then
			potatoSet(object, "Cover", 0)
			potatoSet(object, "Density", 0)
		end
	end

	local function restorePotatoVisuals()
		for object, properties in pairs(potatoVisuals) do
			if object.Parent then
				for property, saved in pairs(properties) do
					pcall(function()
						object[property] = saved.value
					end)
				end
			end
		end
		table.clear(potatoVisuals)
		potatoChanged = 0
	end

	local function applyTerrainPotato()
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if not terrain or not graphicsBefore then
			return
		end
		graphicsBefore.terrain = graphicsBefore.terrain or {}
		for property, value in pairs({
			WaterWaveSize = 0,
			WaterWaveSpeed = 0,
			WaterReflectance = 0,
			WaterTransparency = 1,
		}) do
			if graphicsBefore.terrain[property] == nil then
				local ok, current = pcall(function()
					return terrain[property]
				end)
				if ok then
					graphicsBefore.terrain[property] = current
					pcall(function()
						terrain[property] = value
					end)
				end
			else
				pcall(function()
					terrain[property] = value
				end)
			end
		end
		if graphicsBefore.decoration == nil and typeof(gethiddenproperty) == "function" then
			local ok, value = pcall(gethiddenproperty, terrain, "Decoration")
			if ok then
				graphicsBefore.decoration = value == true
			end
		end
		if typeof(sethiddenproperty) == "function" then
			pcall(sethiddenproperty, terrain, "Decoration", false)
		end
	end

	local function restoreTerrainPotato(saved)
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if not terrain or type(saved) ~= "table" then
			return
		end
		for property, value in pairs(saved.terrain or {}) do
			pcall(function()
				terrain[property] = value
			end)
		end
		if saved.decoration ~= nil and typeof(sethiddenproperty) == "function" then
			pcall(sethiddenproperty, terrain, "Decoration", saved.decoration)
		end
	end

	function STATE.applyFpsBoost(silent)
		potatoEpoch += 1
		local epoch = potatoEpoch
		if STATE.fpsBoost == true then
			if not graphicsBefore then
				graphicsBefore = {
					shadows = Lighting.GlobalShadows,
					environmentDiffuse = Lighting.EnvironmentDiffuseScale,
					environmentSpecular = Lighting.EnvironmentSpecularScale,
				}
				pcall(function()
					graphicsBefore.quality = settings().Rendering.QualityLevel
					settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
				end)
			end
			Lighting.GlobalShadows = false
			Lighting.EnvironmentDiffuseScale = 0
			Lighting.EnvironmentSpecularScale = 0
			applyTerrainPotato()
			STATE.potatoStatus = "On. Flattening the court"
			if silent ~= true then
				notify("Potato Mode", "On. Shadows and effects are off")
			end
			task.spawn(function()
				local objects = Workspace:GetDescendants()
				for _, object in ipairs(Lighting:GetDescendants()) do
					table.insert(objects, object)
				end
				for index, object in ipairs(objects) do
					if not running() or STATE.fpsBoost ~= true or epoch ~= potatoEpoch then
						return
					end
					simplifyVisual(object)
					if index % 400 == 0 then
						STATE.potatoChangedCount = potatoChanged
						task.wait()
					end
				end
				if running() and STATE.fpsBoost == true and epoch == potatoEpoch then
					STATE.potatoChangedCount = potatoChanged
					STATE.potatoStatus = "On. The court is flat and light"
				end
			end)
		elseif graphicsBefore then
			local saved = graphicsBefore
			graphicsBefore = nil
			Lighting.GlobalShadows = saved.shadows
			Lighting.EnvironmentDiffuseScale = saved.environmentDiffuse
			Lighting.EnvironmentSpecularScale = saved.environmentSpecular
			pcall(function()
				if saved.quality then
					settings().Rendering.QualityLevel = saved.quality
				end
			end)
			restoreTerrainPotato(saved)
			restorePotatoVisuals()
			STATE.potatoChangedCount = 0
			STATE.potatoStatus = "Off. Normal look"
			if silent ~= true then
				notify("Potato Mode", "Off. The normal look is back")
			end
		else
			STATE.potatoStatus = "Off. Normal look"
		end
	end

	trackConnection(Workspace.DescendantAdded:Connect(function(object)
		if STATE.fpsBoost == true then
			task.defer(simplifyVisual, object)
		end
	end))
	trackConnection(Lighting.DescendantAdded:Connect(function(object)
		if STATE.fpsBoost == true then
			task.defer(simplifyVisual, object)
		end
	end))
	hubCleanup(function()
		if graphicsBefore then
			STATE.fpsBoost = false
			STATE.applyFpsBoost(true)
		end
	end)
end)()

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

-- Show Button Presses: when auto play hits, dives or uses your ability, the
-- matching button at the bottom of the screen dips in with a click ripple, so
-- you can see what it's pressing. Purely visual and only on your own screen.
do
	local TweenService = game:GetService("TweenService")
	local lastPress = {}
	function STATE.pressButton(name)
		if STATE.showPresses ~= true or os.clock() - (lastPress[name] or 0) < 0.15 then
			return
		end
		lastPress[name] = os.clock()
		task.spawn(pcall, function()
			local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
			local hud = gui and gui:FindFirstChild("HUD")
			local inner = hud and hud:FindFirstChild("HUD")
			if not inner then
				return
			end
			-- PC/console buttons live in Bottom, phone buttons in MobileControls.
			local button
			for _, holderName in ipairs({ "Bottom", "MobileControls" }) do
				local holder = inner:FindFirstChild(holderName)
				local found = holder and holder.Visible and holder:FindFirstChild(name)
				if found and found:IsA("GuiObject") and found.Visible then
					button = found
					break
				end
			end
			if not button then
				return
			end
			-- Press-in bounce (skipped if the game already scales this button).
			local scale = button:FindFirstChild("ZinoosPress")
			local other = false
			for _, child in ipairs(button:GetChildren()) do
				if child:IsA("UIScale") and child ~= scale then
					other = true
				end
			end
			if not other then
				if not scale then
					scale = Instance.new("UIScale")
					scale.Name = "ZinoosPress"
					scale.Parent = button
				end
				scale.Scale = 0.84
				TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
			-- Click ripple, like the game's own tap effect.
			local ripple = Instance.new("Frame")
			ripple.Name = "ZinoosRipple"
			ripple.AnchorPoint = Vector2.new(0.5, 0.5)
			ripple.Position = UDim2.fromScale(0.5, 0.5)
			ripple.Size = UDim2.fromScale(0.2, 0.2)
			ripple.SizeConstraint = Enum.SizeConstraint.RelativeYY
			ripple.BackgroundColor3 = Color3.new(1, 1, 1)
			ripple.BackgroundTransparency = 0.35
			ripple.BorderSizePixel = 0
			ripple.ZIndex = button.ZIndex + 5
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = ripple
			ripple.Parent = button
			local tween = TweenService:Create(ripple, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1.5, 1.5), BackgroundTransparency = 1 })
			tween.Completed:Once(function()
				ripple:Destroy()
			end)
			tween:Play()
		end)
	end
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
		STATE.superReadySince = nil
		return false
	end
	-- Superspike is saved for a kill shot (the brain opens the window when
	-- the spike it's lining up is a good one), unless it's been sitting
	-- ready for 12 seconds.
	if name == "Superspike" then
		STATE.superReadySince = STATE.superReadySince or os.clock()
		if not (STATE.superOkUntil and os.clock() < STATE.superOkUntil) and os.clock() - STATE.superReadySince < 12 then
			return false
		end
	end
	if type(AbilityController._active) == "table" and AbilityController._active[name] then
		return false
	end
	local ok = pcall(AbilityController.ActivateEquipped, AbilityController)
	elevate()
	if ok then
		STATE.pressButton("AbilityTwoButton")
		stats.abilities = (stats.abilities or 0) + 1
		if name == "Superspike" then
			STATE.superReadySince = nil
			stats.superspikes = (stats.superspikes or 0) + 1
		end
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
	deadSince = nil,
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

-- Read another player: where they'll be once they react (people keep running
-- the way they're going for a moment), and whether they can dive right now:
-- the game's dive only starts from the ground (Grounded) and can't be used
-- again for 0.7s, so someone in the air or mid-dive can only walk.
function brain.readPlayer(player)
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return nil
	end
	local vel = root.AssemblyLinearVelocity
	local flatVel = vel * Vector3.new(1, 0, 1)
	local okGround, ground = pcall(Ball.Ground, root.Position)
	local height = okGround and (root.Position.Y - ground.Y) or 0
	-- Standing, the middle of the body is about 3 studs up for every avatar
	-- type (classic avatars have no hip height, so don't use that).
	local airborne = height > 4.8 or math.abs(vel.Y) > 10
	local diving = flatVel.Magnitude > 34
	local predicted = root.Position + flatVel * (diving and 0.12 or 0.25)
	return { predicted = predicted, cantDive = airborne or diving }
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

-- Superspike (Burst 1.6, MinSpeed 60.9 from the game's module): the hit
-- modifiers a Superspike adds, if it will power this spike. "armed" = it's
-- already active; "ready" = off cooldown and the kill-shot window is open.
function brain.superMods(allowReady)
	if equippedAbility() ~= "Superspike" then
		return nil
	end
	local armed = type(AbilityController._active) == "table" and AbilityController._active.Superspike
	if not armed then
		if not allowReady or STATE.autoAbility ~= true then
			return nil
		end
		local ok, left = pcall(AbilityController.Remaining, AbilityController, "Superspike")
		if not ok or (tonumber(left) or 1) > 0 then
			return nil
		end
	end
	local m = AbilityModules.Superspike
	return {
		Boost = 1,
		Burst = m and tonumber(m.Burst) or 1.6,
		Decay = m and tonumber(m.Decay) or 3,
		MinSpeed = m and tonumber(m.MinSpeed) or 60.9,
	}
end

-- The hit modifiers your equipped ability adds to this hit (values from the
-- game's ability modules), so the aim matches where the ball really goes.
-- Abilities with a random part (Curveball's side, Moonball's distance) give
-- several variants, and a shot only counts if every variant is good.
function brain.hitMods(kind, allowReady)
	local name = equippedAbility()
	local m = name and AbilityModules[name]
	if not m then
		return nil
	end
	local active = type(AbilityController._active) == "table" and AbilityController._active[name]
	local ready = false
	if not active and allowReady and STATE.autoAbility == true then
		local ok, left = pcall(AbilityController.Remaining, AbilityController, name)
		ready = ok and tonumber(left) == 0
	end
	if name == "Superspike" and kind == "Spike" then
		return brain.superMods(allowReady)
	elseif name == "Adrenaline" and kind == "Spike" and active then
		return { Boost = tonumber(m.SpikeBoost) or 1.3, MinSpeed = tonumber(m.MinSpikeSpeed) or 60.9 }
	elseif name == "Curveball" and kind == "Spike" and (active or ready) then
		local curve, minDistance = tonumber(m.Curve) or 100, tonumber(m.MinDistance) or 20
		return { variants = {
			{ Boost = 1, Curve = curve, MinDistance = minDistance, IgnoreWalls = m.IgnoreWalls },
			{ Boost = 1, Curve = -curve, MinDistance = minDistance, IgnoreWalls = m.IgnoreWalls },
		} }
	elseif name == "Moonball" and kind == "Bump" and active then
		local range = m.Distance
		local low, high = range and range.Min or 30, range and range.Max or 80
		local list = {}
		for _, d in ipairs({ low, (low + high) / 2, high }) do
			table.insert(list, { Height = m.Height or 100, Distance = d, TimeScale = m.TimeScale or 1.75, FallScale = m.FallScale or 0.5 })
		end
		return { variants = list }
	end
	return nil
end

-- Where a hit in direction dir would end up, following wall bounces.
local function simulate(kind, state, zones, ballPos, dir, now, quality, mods)
	local origin, unit = Ball.Inside(zones, ballPos, dir)
	local ok, nextState = pcall(Ball.Hits[kind], state.Multipliers, origin, unit, now, quality, mods and table.clone(mods) or { Boost = 1 })
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

local function chooseDirection(kind, state, zones, myZone, ballPos, now, quality, mods)
	local candidates = {}
	-- Last resort: any direction whose ball ends up outside your own square
	-- (never hit it into your own square just because nothing looked good).
	local fallback, fallbackScore
	-- A Superspike gets 36 angles (it's the kill shot, so aim it finely).
	local steps = mods and mods.Burst and 36 or 24
	for i = 0, steps - 1 do
		local angle = i / steps * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local variants = mods and mods.variants
		local land, flight, banked, finalState = simulate(kind, state, zones, ballPos, dir, now, quality, variants and variants[1] or mods)
		-- Random-part abilities: every variant has to stay out of your square
		-- (and the slowest one counts).
		if land and variants then
			for v = 2, #variants do
				local otherLand, otherFlight = simulate(kind, state, zones, ballPos, dir, now, quality, variants[v])
				if not otherLand or Ball.ZoneAt(zones, otherLand) == myZone then
					land = nil
					break
				end
				flight = math.max(flight or 0, otherFlight or 0)
			end
		end
		local viaEmpty = false
		if land then
			local endZone = Ball.ZoneAt(zones, land)
			if endZone ~= myZone then
				local away = ((land - myZone.Position) * Vector3.new(1, 0, 1)).Magnitude
				if not fallbackScore or away > fallbackScore then
					fallback, fallbackScore = { dir = dir, far = 0, flight = flight, land = land, banked = banked }, away
				end
			end
		end
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
				local friendly, who, far, stuck = false, nil, nil, false
				for _, entry in ipairs(occupantsOf(zone)) do
					if isTeammate(entry.player) then
						friendly = true
						break
					end
					-- Wrong-foot them: judge the shot from where they'll be once
					-- they react (they keep running the way they're going for a
					-- moment), not from where they stand right now.
					local read = brain.readPlayer and brain.readPlayer(entry.player)
					local from = read and read.predicted or entry.pos
					local d = ((from - land) * Vector3.new(1, 0, 1)).Magnitude
					if not far or d < far then
						far, who, stuck = d, entry.player, read ~= nil and read.cantDive
					end
				end
				if not friendly then
					table.insert(candidates, { dir = dir, far = far or 10, flight = flight, who = who, banked = banked, land = land, viaEmpty = viaEmpty, cantDive = stuck, zone = zone })
				end
			end
		end
	end
	if #candidates == 0 then
		if fallback then
			stats.fallbackAims = (stats.fallbackAims or 0) + 1
			return fallback.dir, fallback
		end
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
			-- Read Players: aim where this player has missed before, away from
			-- where they always save it and from where they usually wait.
			if mode ~= "Fastest" and option.who and brain.weakSpot then
				option.score += brain.weakSpot(option.who, option.zone, option.land)
			end
			-- Punish the jump: the game's dive only works from the ground and
			-- needs 0.7s before it can go again, so a player who is in the air
			-- or mid-dive can only walk to this one.
			if option.cantDive and mode ~= "Fastest" then
				option.score += 8
			end
			-- Trick shot: now and then go for a bank shot off a wall.
			if brain.preferBank and option.banked then
				option.score += 12
			end
		end
		table.sort(candidates, function(a, b)
			return a.score > b.score
		end)
		pick = candidates[1]
		-- A person doesn't find the exact best angle every time. Usually a
		-- good one, not always the hardest.
		if humanizing() and #candidates > 1 then
			local roll = math.random()
			local index = roll < 0.38 and 1 or (roll < 0.72 and 2 or 3)
			pick = candidates[math.min(index, #candidates)]
		end
	end
	if pick.cantDive and brain.punishKey ~= brain.stateKey then
		brain.punishKey = brain.stateKey
		stats.punishes = (stats.punishes or 0) + 1
	end
	return pick.dir, pick
end

local function face(root, dir)
	if not dir then
		return
	end
	local flat = dir * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 then
		return
	end
	-- The hit reads your facing on this exact frame, so this has to land on
	-- the aim. The approach already turned most of the way; a few degrees
	-- left is not worth a visible snap.
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude > 0.01 and look.Unit:Dot(flat.Unit) > 0.996 then
		return
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
end

local function tryHit(kind, char, root, state, zones, myZone, ballPos, now)
	local quality = 1
	local resolvedKind = kind
	if kind == "Spike" then
		resolvedKind, quality = Ball.Resolve("Spike", char.Head.Position, ballPos, Ball.Jump(char, root.Position))
	end
	useAbility(resolvedKind == "Spike" and "spike" or "hit")
	brain.spinLeft = 0
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
		-- An armed Superspike powers this spike: aim with its extra speed.
		local mods = brain.hitMods(resolvedKind, false)
		if brain.aimDir and brain.aimKey == brain.stateKey and resolvedKind == brain.aimKind and (brain.aimSuper == true) == (mods ~= nil) then
			dir, pick = brain.aimDir, brain.aimPick
			-- The aim was picked a moment ago for where you planned to hit it.
			-- Check it again from where the ball really is now (a wall bounce
			-- or a late jump moves the contact point; seen live: a spike aimed
			-- that way came down in your own square). Aim again if it would.
			local land = simulate(resolvedKind, state, zones, ballPos, dir, now, quality, mods and mods.variants and mods.variants[1] or mods)
			local landZone = land and Ball.ZoneAt(zones, land)
			if landZone and not landZone:GetAttribute("Occupied") then
				landZone = Ball.BounceTarget(zones, land) or landZone
			end
			if not land or landZone == myZone then
				dir, pick = chooseDirection(resolvedKind, state, zones, myZone, ballPos, now, quality, mods)
				stats.aimFixes = (stats.aimFixes or 0) + 1
				-- Keep turning toward the new aim (not the old one) until the
				-- swing lands.
				brain.aimDir, brain.aimPick = dir, pick
			end
		else
			dir, pick = chooseDirection(resolvedKind, state, zones, myZone, ballPos, now, quality, mods)
			if resolvedKind == brain.aimKind then
				brain.aimDir, brain.aimPick, brain.aimSuper = dir, pick, mods ~= nil
			end
		end
		face(root, dir)
	end
	-- Use the same Swing entry point as normal player input. Never manufacture
	-- a lower-level hit directly; Swing lets the game choose
	-- Bump on the ground or Spike in the air and enforce its own busy checks.
	local hum = char:FindFirstChildOfClass("Humanoid")
	local inAir = hum and hum.FloorMaterial == Enum.Material.Air
	if kind == "Bump" and inAir then
		return false
	end
	brain.pendingKind, brain.pendingPick, brain.pendingQuality = resolvedKind, pick, quality
	local ok = pcall(BallController.Swing, BallController)
	elevate()
	if not ok then
		brain.pendingKind = nil
	else
		STATE.pressButton("BumpSpikeButton")
	end
	return ok
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

-- The only Set path kept by the hub is the game's native Dive ability.
local pathAt -- defined further down with the flight chain helpers
local function diveReady(hum)
	if STATE.autoDive ~= true or not hum or hum.FloorMaterial == Enum.Material.Air or BallController:Busy()
		or os.clock() - brain.lastDive <= 1 then
		return false
	end
	local okLeft, left = pcall(AbilityController.Remaining, AbilityController, "Dive")
	elevate()
	return not okLeft or tonumber(left) == 0
end

local function startNativeDive(root, hum, dir, plan)
	if not diveReady(hum) or not dir or dir.Magnitude < 0.1 then
		return false
	end
	dir = (dir * Vector3.new(1, 0, 1)).Unit
	brain.lastDive = os.clock()
	brain.diveCheck = {
		at = os.clock(),
		startedAt = workspace:GetServerTimeNow(),
		hit = tonumber(BallController._lastHit) or 0,
		key = brain.stateKey,
		expectSet = plan and plan.expectSet == true,
	}
	face(root, dir)
	-- Dive reads Humanoid.MoveDirection first, so give it the same direction
	-- the character is visibly facing instead of only rotating the root.
	pcall(hum.Move, hum, dir, false)
	if brain.diveCheck.expectSet then
		brain.pendingKind, brain.pendingPick, brain.pendingQuality = "Set", nil, 1
	end
	local ok, activated = pcall(AbilityController.Activate, AbilityController, "Dive")
	elevate()
	if not ok or activated == false
		or (type(AbilityController._active) == "table" and not AbilityController._active.Dive) then
		ok = false
	end
	if not ok then
		brain.diveCheck = nil
		if brain.pendingKind == "Set" then
			brain.pendingKind = nil
		end
		return false
	end
	STATE.pressButton("AbilityButton")
	stats.dives += 1
	return true
end

-- Float shot: a normal bump aimed deep into the next square. This keeps the
-- visible move and the server hit type consistent.
local function tryTip(char, root, state, zones, myZone, ballPos, now)
	local dir, pick = chooseDirection("Bump", state, zones, myZone, ballPos, now, 1)
	if not dir or not pick or pick.far < 14 then
		return false
	end
	face(root, dir)
	brain.pendingKind, brain.pendingPick, brain.pendingQuality = "Tip", pick, 1
	local ok = pcall(BallController.Swing, BallController)
	elevate()
	if ok then
		STATE.pressButton("BumpSpikeButton")
		STATE.playStatus = "Floated it over"
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

-- How long the dive takes to cover a distance. Used so a save starts when
-- the slide will meet the ball, not after the ball has already landed.
function brain.diveTime(distance)
	if distance <= 0 then
		return 0
	end
	local module = AbilityModules.Dive
	local boost = module and tonumber(module.Boost) or 1
	local duration = module and tonumber(module.Duration) or 0.5
	local covered, step, s = 0, 1 / 120, 0
	while s < duration and covered < distance do
		local x = math.min(s / duration, 1)
		local ease = 1 - (1 - x) ^ 2
		covered += (120 + (30 - 120) * ease) * boost * step
		s += step
	end
	if covered < distance then
		return nil
	end
	return s
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

local landingSpot -- defined further down (needs the flight chain helpers)

-- Learn the players (Read Players): per player, where their hits into your
-- square come down (so you wait where THEY aim), where they stand when a
-- ball comes at them, and which spots in their square they've saved or
-- missed (so your shots go where they're weak). Everything is stored
-- relative to the square, so it still works when squares change, and it is
-- kept through hub reloads for this session.
local playerModel = getgenv().ZinoosVolleyModel or {}
getgenv().ZinoosVolleyModel = playerModel
local function modelOf(player)
	local key = player and player.UserId
	if not key then
		return nil
	end
	playerModel[key] = playerModel[key] or { aims = {}, saves = {}, misses = {}, homeSum = Vector3.zero, homeN = 0 }
	return playerModel[key]
end
local function pushCapped(list, item, cap)
	table.insert(list, item)
	while #list > cap do
		table.remove(list, 1)
	end
end
local function flatRel(zone, pos)
	local rel = zone.CFrame:PointToObjectSpace(pos)
	return Vector3.new(rel.X, 0, rel.Z)
end
function brain.noteAim(hitter, zone, land)
	local m = STATE.readPlayers == true and modelOf(hitter)
	if m then
		pushCapped(m.aims, flatRel(zone, land), 20)
	end
end
-- Where this hitter usually puts it in your square (60% of the way from
-- the middle toward their average), once they've done it 3+ times.
function brain.hitterBase(hitter, zone)
	local m = STATE.readPlayers == true and hitter and playerModel[hitter.UserId]
	if not m or #m.aims < 3 then
		return nil
	end
	local sum = Vector3.zero
	for _, rel in ipairs(m.aims) do
		sum += rel
	end
	local avg = sum / #m.aims * 0.6
	local limitX, limitZ = zone.Size.X / 2 - 5, zone.Size.Z / 2 - 5
	local clamped = Vector3.new(math.clamp(avg.X, -limitX, limitX), 0, math.clamp(avg.Z, -limitZ, limitZ))
	return zone.CFrame:VectorToWorldSpace(clamped) * Vector3.new(1, 0, 1)
end
-- How weak this player is at this landing spot: past misses near it count
-- up, past saves near it count down (a few points at most).
function brain.weakSpot(player, zone, land)
	local m = STATE.readPlayers == true and player and playerModel[player.UserId]
	if not m or not zone then
		return 0
	end
	local rel = flatRel(zone, land)
	local score = 0
	for _, spot in ipairs(m.misses) do
		if (spot - rel).Magnitude < 6 then
			score += 3
		end
	end
	for _, spot in ipairs(m.saves) do
		if (spot - rel).Magnitude < 4 then
			score -= 1
		end
	end
	if m.homeN >= 3 then
		-- Far from where they usually wait is harder for them.
		score += math.min(((m.homeSum / m.homeN) - rel).Magnitude, 20) * 0.15
	end
	return math.clamp(score, -6, 9)
end
-- Watch every ball that heads into someone else's square and how it ends.
local defenseWatch = { key = nil, pending = nil }
function brain.watchDefense(state, zones, now)
	if STATE.readPlayers ~= true then
		return
	end
	local key = tostring(state.HitAt) .. tostring(state.Dead) .. tostring(state.HitBy)
	if key == defenseWatch.key then
		return
	end
	defenseWatch.key = key
	local pending = defenseWatch.pending
	if pending then
		defenseWatch.pending = nil
		local m = modelOf(pending.defender)
		if m then
			if state.Dead and state.Origin and Ball.ZoneAt(zones, state.Origin) == pending.zone then
				pushCapped(m.misses, pending.rel, 30)
				stats.learnedMisses = (stats.learnedMisses or 0) + 1
			elseif state.HitBy == pending.defender then
				pushCapped(m.saves, pending.rel, 40)
			end
		end
	end
	if state.Dead or not state.HitBy then
		return
	end
	local land = landingSpot(state, now)
	local zone = land and Ball.ZoneAt(zones, land)
	if not zone or not zone:GetAttribute("Occupied") then
		return
	end
	-- The defender: whoever stands in that square, nearest the landing.
	local defender, best, defPos
	for _, entry in ipairs(occupantsOf(zone)) do
		local d = ((entry.pos - land) * Vector3.new(1, 0, 1)).Magnitude
		if entry.player ~= state.HitBy and (not best or d < best) then
			defender, best, defPos = entry.player, d, entry.pos
		end
	end
	if not defender then
		return
	end
	local m = modelOf(defender)
	if m then
		m.homeSum += flatRel(zone, defPos)
		m.homeN += 1
	end
	defenseWatch.pending = { defender = defender, zone = zone, rel = flatRel(zone, land) }
end

-- Read the hitter: the ball is about to come down in another player's square.
-- Look at which way they're facing and work out (with the game's own ball
-- maths) where a hit that way would land. If that's in your square, return
-- the spot so you can start leaning there before they even touch it.
-- (landingSpot is declared above, with the player model; defined further down)
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
local function turnToward(root, dir, rate, force)
	local flat = dir * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 then
		return true
	end
	-- Setting the character's rotation stops the game's walking for that
	-- frame (measured live: turning on every frame of a run, you moved 24%
	-- of the time instead of 98%). A normal turn waits until the run has
	-- paused. A forced turn is the approach into a hit: the caller spaces
	-- those out so the run keeps its speed.
	if not force and brain.walkingUntil and os.clock() < brain.walkingUntil then
		return false
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

-- Face a direction in good time for a hit. While a walk is in progress, turn
-- on some frames only, and never more than 18 degrees on one of them, so the
-- run does not stall and the swing is not a snap.
function brain.easeFace(root, hum, dir, loose)
	local flat = typeof(dir) == "Vector3" and dir * Vector3.new(1, 0, 1)
	if not root or not hum or not flat or flat.Magnitude < 0.01 then
		return
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	-- Watching the ball can sit a little off. Lining up a hit stays tighter,
	-- or the swing still has a snap left to do.
	local slop = loose and (humanizing() and 0.94 or 0.97) or 0.985
	if look.Magnitude > 0.01 and look.Unit:Dot(flat.Unit) > slop then
		return
	end
	hum.AutoRotate = false
	brain.turning = os.clock()
	brain.facing = true
	brain.lastFaceAt = os.clock()
	local walking = brain.walkingUntil and os.clock() < brain.walkingUntil
	local rate = loose and 6 or 11
	if walking then
		local nowClock = os.clock()
		if nowClock < (brain.preTurnAt or 0) then
			return
		end
		local gap = math.clamp(nowClock - (brain.preTurnClock or nowClock), 1 / 60, 0.1)
		brain.preTurnAt = nowClock + (loose and randomBetween(0.1, 0.2) or 0.08)
		brain.preTurnClock = nowClock
		local frame = math.clamp(brain.dt or (1 / 60), 1 / 240, 1 / 20)
		local cap = loose and math.rad(12) or math.rad(18)
		rate = math.min(rate * gap, cap) / frame
	else
		brain.preTurnClock = os.clock()
	end
	turnToward(root, flat.Unit, rate, true)
end

-- Walk like someone on a keyboard: with the camera behind you (shift lock),
-- WASD only gives 8 directions relative to where you face, so the path is
-- made of those, with a fine adjustment right at the end. Urgent runs (a
-- ball about to land) go straight.
local function moveTo(hum, root, spot, urgent)
	if STATE.autoMove ~= true then
		return
	end
	-- The wide aim is applied by the caller when there is time. An urgent run
	-- goes to the spot it was given, so a late shuffle is not pulled off the ball.
	local goal = Vector3.new(spot.X, root.Position.Y, spot.Z)
	local delta = goal - root.Position
	if delta.Magnitude > 2 then
		brain.walkingUntil = os.clock() + 0.12
	end
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

-- With time, start wide of the ball and close in, so the run bends onto it
-- instead of drawing a straight line to the stud. The last moment is exact.
function brain.approachSpot(zone, root, spot, secondsLeft, settle)
	settle = settle or 0.4
	if not humanizing() or typeof(spot) ~= "Vector3" or secondsLeft <= settle then
		return spot
	end
	local bias = brain.offset
	if typeof(bias) ~= "Vector3" or bias.Magnitude < 0.4 then
		return spot
	end
	local fade = math.clamp((secondsLeft - settle) / 0.8, 0, 1)
	local wide = bias.Unit * math.clamp(bias.Magnitude * 1.6, 1.5, 3.2)
	local goal = spot + wide * fade
	if not zone or not root then
		return goal
	end
	local rel = zone.CFrame:PointToObjectSpace(goal)
	local limitX, limitZ = zone.Size.X / 2 - 2, zone.Size.Z / 2 - 2
	local clamped = zone.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(rel.X, -limitX, limitX),
		rel.Y,
		math.clamp(rel.Z, -limitZ, limitZ)
	))
	return Vector3.new(clamped.X, root.Position.Y, clamped.Z)
end

-- Always moving (Spin Moves). The character turns itself in loops (no forced
-- turning, which would stall the run).
-- Loops: quick tight circles around a spot, facing the way you run, so every
-- loop is a spin. Direction and size change every second or two.
-- With Humanize on, jog between spots around your square. A perfect circle
-- is the thing people notice. Now and then a short curve, not an orbit.
function brain.runLoop(hum, root, center)
	if humanizing() then
		local jog = brain.jog
		if not (jog and jog.arcUntil and os.clock() < jog.arcUntil) then
			if not jog or os.clock() >= (jog.leaveAt or 0) then
				if math.random() < 0.16 then
					brain.loop = nil
					brain.jog = { arcUntil = os.clock() + randomBetween(0.45, 0.85) }
				else
					local angle = math.random() * math.pi * 2
					local radius = randomBetween(1.6, 5.2)
					local bend = randomBetween(1.3, 2.8) * (math.random() < 0.5 and -1 or 1)
					brain.jog = {
						goal = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius),
						leaveAt = os.clock() + 4,
						bend = Vector3.new(-math.sin(angle) * bend, 0, math.cos(angle) * bend),
					}
				end
				jog = brain.jog
			end
			if jog.goal then
				local goal = Vector3.new(jog.goal.X, root.Position.Y, jog.goal.Z)
				local away = (goal - root.Position).Magnitude
				if away < 1.15 then
					jog.leaveAt = os.clock() + randomBetween(0.18, 0.55)
					jog.goal = nil
					hum:MoveTo(root.Position)
					return
				end
				local steer = goal
				if jog.bend and away > 2.4 then
					local along = math.clamp(1 - away / 8, 0.25, 0.85)
					steer = root.Position:Lerp(goal, along) + jog.bend * (1 - along)
				end
				hum.AutoRotate = true
				brain.walkingUntil = os.clock() + 0.12
				hum:MoveTo(Vector3.new(steer.X, root.Position.Y, steer.Z))
				return
			end
			if not jog.arcUntil then
				hum:MoveTo(root.Position)
				return
			end
		end
	end
	if not brain.loop or os.clock() > brain.loop.untilT then
		local radius = humanizing() and randomBetween(4, 7) or randomBetween(2.5, 4.5)
		brain.loop = { untilT = os.clock() + randomBetween(0.8, 2.2), dir = math.random() < 0.5 and -1 or 1, r = radius, a = math.random() * math.pi * 2 }
		stats.loops = (stats.loops or 0) + 1
	end
	local loop = brain.loop
	loop.a += loop.dir * (hum.WalkSpeed / loop.r) * math.clamp(brain.dt or (1 / 60), 1 / 240, 1 / 20)
	local ahead = loop.a + loop.dir * 0.9
	hum.AutoRotate = true
	brain.walkingUntil = os.clock() + 0.12
	hum:MoveTo(Vector3.new(center.X + math.cos(ahead) * loop.r, root.Position.Y, center.Z + math.sin(ahead) * loop.r))
end
-- Side steps: a ready shuffle while a ball could come your way. Each trip
-- crosses the spot (several studs, so it is not a quarter-second flip) and
-- the return starts when you arrive, instead of planting to stare at the
-- ball. You keep facing the play while you go.
function brain.sideStep(hum, root, center, ballPos, zone)
	local toBall = (ballPos - center) * Vector3.new(1, 0, 1)
	local side = toBall.Magnitude > 0.5 and Vector3.new(-toBall.Z, 0, toBall.X).Unit or Vector3.new(1, 0, 0)
	if brain.stepSide and os.clock() < (brain.stepSideUntil or 0) then
		side = brain.stepSide
	else
		brain.stepSide = side
		brain.stepSideUntil = os.clock() + 0.7
	end
	local function clampSpot(goal)
		if not zone then
			return goal
		end
		local rel = zone.CFrame:PointToObjectSpace(goal)
		local limitX, limitZ = zone.Size.X / 2 - 2, zone.Size.Z / 2 - 2
		return zone.CFrame:PointToWorldSpace(Vector3.new(math.clamp(rel.X, -limitX, limitX), rel.Y, math.clamp(rel.Z, -limitZ, limitZ)))
	end
	local function beginTrip(prev)
		local pos
		if humanizing() then
			local sign = (prev or 0) >= 0 and -1 or 1
			if math.random() < 0.3 then
				sign = -sign
			end
			pos = sign * randomBetween(2.2, 6.2)
		else
			pos = (prev or 0) >= 0 and randomBetween(-6.5, -4) or randomBetween(4, 6.5)
		end
		brain.step = {
			pos = pos,
			untilT = os.clock() + 0.4,
			hang = humanizing() and math.random() < 0.5 and randomBetween(0.16, 0.4) or 0,
		}
		return brain.step
	end
	local step = brain.step or beginTrip(0)
	local goal = clampSpot(center + side * step.pos)
	local away = ((goal - root.Position) * Vector3.new(1, 0, 1)).Magnitude
	if away < 1 and not step.arrivedAt then
		step.arrivedAt = os.clock()
		step.leaveAt = os.clock() + (step.hang or 0)
	end
	if away < 1 and step.leaveAt and os.clock() >= step.leaveAt and os.clock() >= step.untilT then
		step = beginTrip(step.pos)
		goal = clampSpot(center + side * step.pos)
		away = ((goal - root.Position) * Vector3.new(1, 0, 1)).Magnitude
	end
	hum.AutoRotate = false
	brain.easeFace(root, hum, ballPos - root.Position, true)
	if away > 0.8 then
		brain.walkingUntil = os.clock() + 0.12
		hum:MoveTo(Vector3.new(goal.X, root.Position.Y, goal.Z))
	else
		hum:MoveTo(root.Position)
	end
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
			-- Magnet stores the pull on the live ball. Looking ahead rewrites
			-- it, so the ball jumps and the real landing is no longer the one
			-- we walk to. Only the current moment is safe.
			if part.Magnet then
				local at = part.Last or part.Time
				if type(at) == "number" and t > at + (1 / 30) then
					return Ball.At(part, at), Ball.VelocityAt(part, at)
				end
			end
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
		part:SetAttribute("ZinoosOwned", true)
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

-- An enemy Magnet has no landing: it pulls the ball, then drops it. Stay under
-- it while it is in your square, and dive if it is low and still going to be
-- there. Looking ahead at the pull is handled in pathAt, so the live ball is
-- not rewritten. A normal ball does not come through here.
function brain.enemyMagnet(state, zones, myZone, root, hum, ballNow, airborne)
	local who = state.Magnet
	if not who or who == LocalPlayer or not root or not hum or not myZone then
		return false
	end
	local ahead = ballNow
	local head = who.Character and who.Character:FindFirstChild("Head")
	if head and type(Ball.SweetSpot) == "function" and state.Damping and state.PullSpeed then
		local ok, pull = pcall(Ball.SweetSpot, head.Position)
		if ok and typeof(pull) == "Vector3" then
			local gap = pull - ballNow
			local dt = 0.35
			if gap.Magnitude > 0.1 then
				local cover = math.min(1 - math.exp(-state.Damping * dt), state.PullSpeed * dt / gap.Magnitude)
				ahead = Ball.Contain(ballNow + gap * cover)
			end
		end
	end
	local here = Ball.ZoneAt(zones, ballNow) == myZone
	local aheadHere = Ball.ZoneAt(zones, ahead) == myZone
	if here or aheadHere then
		local spot = aheadHere and ahead or ballNow
		local flat = Vector3.new(spot.X, root.Position.Y, spot.Z)
		moveTo(hum, root, flat, true)
		local height = spot.Y - Ball.Ground(spot).Y
		local dist = ((flat - root.Position) * Vector3.new(1, 0, 1)).Magnitude
		STATE.playStatus = "Magnet ball, staying under it"
		if height <= 8 and dist > 3.5 and aheadHere and STATE.autoDive == true and not airborne
			and os.clock() - brain.lastDive > 1 and not BallController:Busy()
			and dist <= brain.diveReach(0.4) + 4.5
			and not (STATE.ringIncoming and STATE.ringIncoming(1.1))
			and not (STATE.ringNearby and STATE.ringNearby(62)) then
			local okLeft, leftDive = pcall(AbilityController.Remaining, AbilityController, "Dive")
			elevate()
			if not okLeft or tonumber(leftDive) == 0 then
				if startNativeDive(root, hum, flat - root.Position, { expectSet = true }) then
					STATE.playStatus = "Dived for the magnet"
				end
			end
		end
	else
		STATE.playStatus = "Magnet ball, letting it go"
	end
	return true
end

-- True for a short moment after the landing spot jumps (a curve, a wall,
-- a late read). A spike jump leaves you in the air, and a dive only works
-- on the ground, so a landing that is still moving is a save, not a spike.
function brain.landingSlid(key, spot)
	if typeof(spot) ~= "Vector3" then
		return false
	end
	local flat = Vector3.new(spot.X, 0, spot.Z)
	if brain.landWatchKey ~= key or typeof(brain.landWatch) ~= "Vector3" then
		brain.landWatchKey = key
		brain.landWatch = flat
		brain.landWatchAt = nil
		return false
	end
	if (flat - brain.landWatch).Magnitude > 5 then
		brain.landWatch = flat
		brain.landWatchAt = os.clock()
	end
	return brain.landWatchAt ~= nil and os.clock() - brain.landWatchAt < 0.25
end

local function stepBrain()
	if STATE.afk == true then
		local _, root, hum = character()
		if hum and root then
			pcall(hum.MoveTo, hum, root.Position)
		end
		STATE.playStatus = "AFK"
		return
	end
	local ball = arenaBall()
	if not ball or type(ball.State) ~= "table" or type(ball.Zones) ~= "table" then
		updateMarker(nil)
		STATE.playStatus = arenaName() and "Waiting for the ball" or "Waiting for a round"
		return
	end
	local state, zones = ball.State, ball.Zones
	local now = workspace:GetServerTimeNow()
	updateMarker(landingSpot(state, now))
	pcall(brain.watchDefense, state, zones, now)
	countSwingHits()
	-- How did the last dive go? (caught and counted by the server / touched
	-- on your screen only / missed)
	local check = brain.diveCheck
	if check and not check.setHit and state.HitBy == LocalPlayer and state.Kind == "Set"
		and (tonumber(state.HitAt) or 0) >= (tonumber(check.startedAt) or now) - 0.1 then
		check.setHit = true
	end
	if check and os.clock() - check.at > 0.7 then
		brain.diveCheck = nil
		local touched = (tonumber(BallController._lastHit) or 0) > check.hit
		local nativeSet = check.setHit == true
			or (touched and state.HitBy == LocalPlayer and state.Kind == "Set")
		if nativeSet then
			stats.diveSaves = (stats.diveSaves or 0) + 1
			stats.nativeDiveSets = (stats.nativeDiveSets or 0) + 1
			-- Only arm a follow-up after the live ball state confirms that the
			-- native Dive really produced a Set and another team touch is legal.
			if STATE.nativeFollowups == true and STATE.autoSpike == true
				and (tonumber(state.Hits) or 0) < Ball.GetMaxHits() then
				brain.comboUntil = os.clock() + 2.5
				brain.skipSpike = false
				brain.diveSpike = true
			end
		elseif touched then
			stats.diveNotCounted = (stats.diveNotCounted or 0) + 1
		else
			stats.diveMisses = (stats.diveMisses or 0) + 1
		end
		if check.expectSet and not nativeSet then
			if brain.pendingKind == "Set" then
				brain.pendingKind = nil
			end
		end
	end
	local char, root, hum = character()
	if not char or state.Dead then
		STATE.playStatus = state.Dead and "Waiting for the next serve" or "Waiting to respawn"
		brain.serveAt = nil
		-- The server resolves the landing/blast shortly after the client marks
		-- the ball Dead. Do not immediately walk back toward the middle during
		-- that gap: doing so can carry a survivor back into an adjacent blast.
		if char and state.Dead and STATE.autoHit == true and STATE.autoMove == true then
			brain.deadSince = brain.deadSince or os.clock()
			if os.clock() - brain.deadSince < 0.8 then
				hum:MoveTo(root.Position)
				STATE.playStatus = "Waiting for the blast to clear"
				return
			end
		else
			brain.deadSince = nil
		end
		-- Get set for the next serve: strong players spike their serve
		-- straight away (seen live: under 0.15s to react), so wait in your
		-- ready spot instead of wherever the last point left you.
		if char and state.Dead and STATE.autoHit == true and STATE.autoMove == true then
			local readyZone = Ball.ZoneAt(zones, root.Position)
			if readyZone then
				local ready = Vector3.new(readyZone.Position.X, root.Position.Y, readyZone.Position.Z)
					+ (brain.learnedBase and brain.learnedBase(readyZone) or Vector3.zero) * 0.5
				local away = ((ready - root.Position) * Vector3.new(1, 0, 1)).Magnitude
				if away > 6 or (away > 2.5 and STATE.spinMoves ~= true) then
					hum.AutoRotate = true
					hum:MoveTo(ready)
					STATE.playStatus = "Getting ready for the serve"
				elseif STATE.spinMoves == true and hum.FloorMaterial ~= Enum.Material.Air then
					-- Keep moving while you wait: loops around the ready spot.
					brain.runLoop(hum, root, ready)
				end
			end
		end
		return
	end
	brain.deadSince = nil
	-- Every new flight of the ball: a fresh human reaction.
	-- A new reaction only when a player actually hits it (not when it bounces
	-- off a wall, which also starts a new flight).
	local hitKey = state.HitAt or state.Time
	if hitKey ~= brain.stateKey then
		brain.stateKey = hitKey
		local range = REACTION_TIMES[STATE.reaction] or REACTION_TIMES.Normal
		-- Your own touch (set, serve toss): you already know where it's going.
		local mine = state.HitBy == LocalPlayer or now - (tonumber(BallController._lastHit) or 0) < 1.5
		local delay = (humanizing() and not mine) and randomBetween(range[1], range[2]) or 0
		if delay > 0 then
			local land, landTime = landingSpot(state, now)
			local zone = Ball.ZoneAt(zones, root.Position)
			local urgent = zone and land and Ball.ZoneAt(zones, land) == zone and landTime - now < 1.15
			-- A bit late when you've got time. A ball already on you stays sharp.
			if not urgent and math.random() < 0.4 then
				delay += randomBetween(0.1, 0.26)
			end
		end
		brain.reactAt = os.clock() + delay
		local angle = math.random() * math.pi * 2
		local radius = humanizing() and randomBetween(0.6, 2.4) or 0
		brain.offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		brain.skipSpike = humanizing() and math.random() < 0.12
		brain.jumpLead = humanizing() and randomBetween(0.38, 0.5) or 0.46
		-- Most spikes are a bit early or late. A perfect one now and then.
		if humanizing() then
			brain.spikeWant = math.random() < 0.28 and randomBetween(0.88, 0.95) or randomBetween(0.55, 0.78)
		else
			brain.spikeWant = 0.9
		end
		-- Quick attack: the player who just hit it is out of position (in the
		-- air, mid-dive, or far from the middle of their square), so spike it
		-- straight back on the first touch instead of setting up, before they
		-- can reset.
		brain.quickAttack = false
		if state.HitBy and state.HitBy ~= LocalPlayer then
			local read = brain.readPlayer(state.HitBy)
			local theirRoot = state.HitBy.Character and state.HitBy.Character:FindFirstChild("HumanoidRootPart")
			local theirZone = theirRoot and Ball.ZoneAt(zones, theirRoot.Position)
			local off = theirZone and ((theirRoot.Position - theirZone.Position) * Vector3.new(1, 0, 1)).Magnitude or 0
			brain.quickAttack = (read ~= nil and read.cantDive) or off > 8
			if brain.quickAttack then
				brain.skipSpike = false
			end
		end
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
			brain.noteAim(state.HitBy, myZone, land)
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
			-- Normal player input reaches the serve through Swing; keep the
			-- non-humanized mode on that same path too.
			local served = pcall(BallController.Swing, BallController)
			elevate()
			if served then
				STATE.pressButton("BumpSpikeButton")
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
		else
			-- Same when it comes down low in your square soon, even if a wall
			-- bounce hides where it finally lands (seen live: a fast spike got
			-- a 0.15s "think" because its landing was off a wall).
			local chain = flightChain(state)
			for t = now, math.min(pathEnd(chain), now + 0.75), 0.03 do
				local p = Ball.Contain((pathAt(chain, t)))
				if Ball.ZoneAt(zones, p) == myZone and p.Y - Ball.Ground(p).Y <= 12 then
					reacted = true
					break
				end
			end
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
			brain.aimSuper = false
			-- Superspike kill shot: if it's ready, plan this spike with its
			-- extra speed, and fire it only when that shot is a real killer
			-- (lands far from them, or they're in the air / mid-dive and can't
			-- dive for it). Otherwise keep it for a better one.
			local mods = kind == "Spike" and brain.superMods(true) or nil
			if mods then
				local armed = type(AbilityController._active) == "table" and AbilityController._active.Superspike
				local dir, pick = chooseDirection(kind, state, zones, myZone, at, t, quality or 1, mods)
				local held = STATE.superReadySince and os.clock() - STATE.superReadySince >= 12
				if dir and pick and (armed or held or pick.cantDive or (pick.far or 0) >= 12) then
					STATE.superOkUntil = os.clock() + 1.5
					brain.aimDir, brain.aimPick, brain.aimSuper = dir, pick, true
				else
					mods = nil
				end
			end
			if not mods then
				-- Other abilities (Curveball, Adrenaline, Moonball): aim with
				-- their real effect when it will be on this hit.
				local other = equippedAbility() ~= "Superspike" and brain.hitMods(kind, true) or nil
				brain.aimDir, brain.aimPick = chooseDirection(kind, state, zones, myZone, at, t, quality or 1, other)
				brain.aimSuper = other ~= nil
			end
		end
		if brain.aimDir then
			brain.easeFace(root, hum, brain.aimDir)
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

	-- Native ability follow-ups: a ball your Magnet is holding above your head, or one
	-- your Frozen has stopped in the air in your square, gets jump-spiked.
	local held = state.Magnet == LocalPlayer or (state.Frozen and ballHere)
	if held and STATE.autoSpike == true and STATE.nativeFollowups == true and not airborne and not softServe then
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
			STATE.playStatus = "Magnet follow-up: spiking it"
			return
		elseif above <= 3 and above >= -1 then
			-- Frozen at a spikeable height: get under it and jump.
			moveTo(hum, root, flat, true)
			if away < 3 and os.clock() - brain.lastJump > 0.8 then
				brain.lastJump = os.clock()
				brain.heldCombo = true
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			STATE.playStatus = "Frozen follow-up: lining up the spike"
			return
		end
		-- Frozen too low or too high to spike: play it normally below.
	end

	-- Style: a 360 spin on the way up (spike jumps and some hops). Only in the
	-- air (turning on the ground stops your run) and never mid-swing. The hit
	-- still finishes on the aim, so the spin can't send the ball off line.
	if brain.spinLeft and brain.spinLeft > 0 then
		if airborne and not BallController:Busy() then
			local step = math.min(brain.spinLeft, 27 * math.clamp(brain.dt or (1 / 60), 1 / 240, 1 / 20))
			brain.spinLeft -= step
			hum.AutoRotate = false
			brain.turning = os.clock()
			root.CFrame = root.CFrame * CFrame.Angles(0, step * (brain.spinDir or 1), 0)
			if brain.spinLeft <= 0 then
				stats.spins = (stats.spins or 0) + 1
			end
		elseif not airborne and os.clock() - brain.lastJump > 0.3 then
			brain.spinLeft = 0
		end
	end

	-- In the air: only hit once it really counts as a spike (high enough in the
	-- jump, ball not below your head). Hitting earlier would turn it into a bump.
	if airborne and ballHere and STATE.autoSpike == true then
		local reach = Ball.Reach("Spike", root.Position, char)
		if Ball.InRange("Spike", reach, ballNow) then
			local kind, quality = Ball.Resolve("Spike", char.Head.Position, ballNow, Ball.Jump(char, root.Position))
			local below = ballNow.Y < char.Head.Position.Y - 0.5
			-- Swing once this jump's contact is "good enough". Humanize picks that
			-- bar per rally, so it isn't a perfect spike every time. The jump
			-- running out still forces the hit.
			local late = os.clock() - brain.lastJump > 0.58
			local want = brain.spikeWant or 0.9
			if kind == "Spike" and (quality >= want or late) and os.clock() - brain.lastTry > 0.05 then
				brain.lastTry = os.clock()
				tryHit("Spike", char, root, state, zones, myZone, ballNow, now)
				return
			elseif not below and os.clock() - brain.lastJump < 0.9 then
				STATE.playStatus = "Waiting for the spike"
				-- Keep turning toward the shot while in the air (after any spin).
				if STATE.playerMove == true and brain.aimDir and brain.aimKey == brain.stateKey and not (brain.spinLeft and brain.spinLeft > 0) then
					hum.AutoRotate = false
					brain.turning = os.clock()
					turnToward(root, brain.aimDir, 11, true)
				end
				return
			end
		end
	end

	-- Bump when it is in reach. The hub never creates its own Set here; the
	-- only Set comes from a native defensive Dive above.
	if ballHere and Ball.InRange("Bump", root.Position, ballNow) and reacted then
		local low = ballNow.Y - Ball.Ground(ballNow).Y < 6
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
		elseif inCombo and not low and not airborne then
			STATE.playStatus = "Native follow-up: waiting to spike"
		elseif os.clock() - brain.lastTry > 0.1 then
			brain.lastTry = os.clock()
			local done = false
			-- Pro plays: now and then tip it softly over instead.
			-- (A quick attack skips the slow stuff: hit it straight back.)
			if STATE.trickShots == true and not airborne and not inCombo and not brain.quickAttack and math.random() < 0.18 then
				done = tryTip(char, root, state, zones, myZone, ballNow, now)
			end
			if not done then
				tryHit("Bump", char, root, state, zones, myZone, ballNow, now)
			end
		end
		return
	end

	-- Spike plan is below. An enemy Magnet must be handled first: sampling
	-- its path rewrites the live ball.
	if brain.enemyMagnet(state, zones, myZone, root, hum, ballNow, airborne) then
		return
	end

	-- Spike plan: a point on the way down that you can get under, where the
	-- ball will be 0-2.5 studs above your head at the top of your jump (that's
	-- a PERFECT spike in the game's maths, which also powers Superspike).
	if STATE.autoSpike == true and not airborne and reacted and (inCombo or not brain.skipSpike) and not softServe and not state.Tornado then
		local headTop = char.Head.Position.Y + 7.4
		local chain = flightChain(state)
		local landNote, landNoteTime = landingSpot(state, now)
		local landNoteHere = landNote and Ball.ZoneAt(zones, landNote) == myZone
		local landingSlid = landNoteHere and brain.landingSlid(brain.stateKey, landNote) or false
		for t = now + 0.42, math.min(pathEnd(chain), now + 4), 0.03 do
			local raw, velocity = pathAt(chain, t)
			local p = Ball.Contain(raw)
			if Ball.ZoneAt(zones, p) == myZone and velocity.Y < 0 then
				local above = p.Y - headTop
				if above <= (brain.quickAttack and 3.2 or 2.5) and above >= -0.3 then
					local flat = Vector3.new(p.X, root.Position.Y, p.Z)
					local dist = (flat - root.Position).Magnitude
					if STATE.autoMove ~= true and dist > 4 then
						break
					end
					-- Once you've committed to a spike on this ball, stick with
					-- it (no flip-flopping between plans every frame).
					local slack = brain.spikeKey == brain.stateKey and 6 or (brain.quickAttack and 5 or 3)
					if brain.quickAttack and brain.quickKey ~= brain.stateKey then
						brain.quickKey = brain.stateKey
						stats.quickAttacks = (stats.quickAttacks or 0) + 1
					end
					if brain.spikeKey ~= brain.stateKey and teammateCloser(myZone, root, p) then
						break -- teammate's spike
					end
					if dist <= hum.WalkSpeed * (t - now - 0.42) + slack then
						brain.spikeKey = brain.stateKey
						local eta = t - now
						local behind = dist > hum.WalkSpeed * (eta - 0.42) * 0.8
						local landFlat = landNoteHere and Vector3.new(landNote.X, 0, landNote.Z) or nil
						local apart = landFlat and (Vector3.new(flat.X, 0, flat.Z) - landFlat).Magnitude or 0
						local under = dist <= 4.5
						local sameSpot = not landNoteHere or (apart <= 8 and not landingSlid)
						local soon = landNoteHere and landNoteTime - now < 1.2
						-- A dive only works on the ground. If the ball is about
						-- to land in the square and this jump is not stood under
						-- it, stay down and save it.
						if soon and (not under or not sameSpot) and eta <= (brain.jumpLead or 0.46) + 0.08 then
							break
						end
						-- Wide on the way in. On the stud before the jump, so the
						-- spike still goes where you aimed.
						local aim = (humanizing() and not behind and eta > 0.7) and brain.approachSpot(myZone, root, flat, eta, 0.7) or flat
						moveTo(hum, root, aim, behind or eta <= 0.7)
						STATE.playStatus = inCombo and "Native follow-up: going up for the spike" or "Lining up a spike"
						if t - now <= 0.8 then
							preAim("Spike", p, t, 1)
						end
						if under and sameSpot and t - now <= (brain.jumpLead or 0.46) and os.clock() - brain.lastJump > 0.8 and not (STATE.ringIncoming and STATE.ringIncoming(1.1)) then
							brain.lastJump = os.clock()
							useAbility("spike")
							-- A 360 now and then, not on a timer. The spin ends
							-- facing the shot, so the hit still goes where you aimed.
							brain.spinLeft = (STATE.spinMoves == true and humanizing() and math.random() < 0.12) and math.pi * 2 or 0
							brain.spinDir = math.random() < 0.5 and -1 or 1
							if brain.spinLeft > 0 and brain.aimDir and brain.aimKey == brain.stateKey then
								local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
								local aimFlat = brain.aimDir * Vector3.new(1, 0, 1)
								if look.Magnitude > 0.01 and aimFlat.Magnitude > 0.01 then
									local diff = (yawOf(aimFlat.Unit) - yawOf(look.Unit) + math.pi) % (2 * math.pi) - math.pi
									brain.spinDir = diff >= 0 and 1 or -1
									brain.spinLeft = math.pi * 2 + math.abs(diff)
								end
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
	if not target and ballHere then
		-- The final landing can be wrong after a Curveball, a Magnet drop, or
		-- a wall. If the ball is already in your square and coming down, go
		-- to it anyway.
		local velOk, vel = pcall(Ball.VelocityAt, state, now)
		local height = ballNow.Y - Ball.Ground(ballNow).Y
		if height <= 16 and (not velOk or typeof(vel) ~= "Vector3" or vel.Y < 4) then
			target, targetTime = ballNow, now + math.clamp(height / 30, 0.18, 0.9)
		end
	end
	-- Your own hit can come back off the wall. The predicted landing says it
	-- has left, so the hub stands still, and the ball drops in the square.
	-- If the live ball is travelling back toward you, go and play it.
	if not target and state.HitBy == LocalPlayer and not state.Dead and not state.Toss then
		local velOk, vel = pcall(Ball.VelocityAt, state, now)
		local flatVel = velOk and typeof(vel) == "Vector3" and Vector3.new(vel.X, 0, vel.Z) or Vector3.zero
		local toCenter = Vector3.new(myZone.Position.X - ballNow.X, 0, myZone.Position.Z - ballNow.Z)
		local comingBack = flatVel.Magnitude < 2 and (typeof(vel) ~= "Vector3" or vel.Y < 6)
			or (toCenter.Magnitude > 0.5 and flatVel.Magnitude >= 2 and flatVel.Unit:Dot(toCenter.Unit) > 0.15)
		if comingBack then
			for step = 0, 0.9, 0.1 do
				local ahead = Ball.Contain(ballNow + flatVel * step)
				if Ball.ZoneAt(zones, ahead) == myZone then
					target, targetTime = ahead, now + math.max(step, 0.2)
					break
				end
			end
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
		local eta = targetTime - now
		-- Straight once the ball is yours inside a second. The wide step is only
		-- while there is time to spare.
		local tight = dist / math.max(hum.WalkSpeed, 1) > eta * 0.75
		local aim = (humanizing() and not tight and eta > 0.9) and brain.approachSpot(myZone, root, flat, eta, 0.4) or flat
		moveTo(hum, root, aim, tight or eta <= 0.9)
		STATE.playStatus = "Going for the ball"
		STATE.incomingEta = targetTime - now
		useAbility("incoming")
		local land, landTime = landingSpot(state, now)
		local lands = land and Ball.ZoneAt(zones, land) == myZone
		local left = (lands and landTime or targetTime) - now
		-- Dive timed to the distance: the game's dive is a fast slide (about
		-- 35 studs in half a second), so start it when the slide will arrive
		-- with the ball, not a fixed half second early (that overshoots close
		-- balls).
		local landFlat = land and Vector3.new(land.X, root.Position.Y, land.Z)
		local landDist = landFlat and (landFlat - root.Position).Magnitude or dist
		-- Catch it a moment before it lands, while it's still ~4 studs up: the
		-- dive grabs the ball when it's low near you, and a grab in the last
		-- split second can lose to the ball touching the ground. The game's
		-- dive also remembers the last 0.2s of its path, so arriving a little
		-- early still catches it, while arriving late never does.
		local catchSpot, catchTime = landFlat, (lands and landTime or targetTime)
		if lands then
			for t = math.max(now, landTime - 0.5), landTime, 0.02 do
				local p = pathAt(fullPath, t)
				if p.Y - Ball.Ground(p).Y <= 4.5 then
					catchSpot, catchTime = Vector3.new(p.X, root.Position.Y, p.Z), t
					break
				end
			end
		end
		local catchDist = catchSpot and (catchSpot - root.Position).Magnitude or landDist
		-- Start far enough ahead of the visible contact for the native Dive to
		-- replicate before the server resolves the landing. The Dive module
		-- remembers roughly 0.2s of its path, so this stays inside its own
		-- legitimate catch window while avoiding last-frame misses.
		local early = 0.18
		local slide = brain.diveReach(math.max(catchTime - now - early, 0))
		-- You have to be there before the catch, not as the ball hits the
		-- ground. Walking that would arrive on the landing is already late.
		local walkBudget = catchTime - now - 0.1
		local walkTooSlow = catchDist > 1.2 and catchDist / math.max(hum.WalkSpeed, 1) > walkBudget
		if lands and catchDist / math.max(hum.WalkSpeed, 1) > walkBudget and catchTime - now < 1 then
			useAbility("save")
		end
		-- Can a dive still get there? The slide plus the dive's catch box
		-- (about 4.5 studs) must reach the ball. A dive that falls short only
		-- leaves you lying next to the explosion.
		local diveCanReach = brain.diveReach(math.max(left, 0)) + 4.5 >= landDist
		-- Best case: walk now, then dive in the last half second.
		local bestReach = hum.WalkSpeed * math.max(left - 0.5, 0) + brain.diveReach(math.min(math.max(left, 0), 0.5)) + 4.5
		local hopeless = lands and walkTooSlow and bestReach < landDist and left < 1.2
		-- A walk that will not arrive still has to dive. Start when the slide
		-- meets the ball (the dive remembers about a fifth of a second), not
		-- only when the full slide happens to match the distance. That second
		-- check never opened on a ball 13 studs away with half a second left.
		local travel = brain.diveTime(math.max(catchDist - 3, 0))
		local catchEta = catchTime - now
		local earlyBy = travel and (catchEta - travel) or 99
		local meet = travel ~= nil and earlyBy <= 0.2 and earlyBy >= -0.08
		local oldWindow = left <= 0.72 and slide <= catchDist + 2
		-- Turn on the way in. A dive faces the catch; a bump or spike faces the
		-- shot. Either way the hit itself only has to correct what's left.
		if lands and walkTooSlow and catchSpot then
			brain.easeFace(root, hum, catchSpot - root.Position)
		elseif targetTime - now <= 0.8 then
			preAim("Bump", target, targetTime, 1)
		elseif STATE.playerMove == true and brain.faceBall then
			brain.faceBall(root, hum, ballNow)
		end
		-- Chase trace for the loss recorder: what the dive check saw, so a
		-- "ran for it but never dived" death can be explained. Reading only.
		if brain.traceKey ~= brain.stateKey then
			brain.traceKey, brain.trace = brain.stateKey, {}
		end
		if os.clock() - (brain.traceAt or 0) >= 0.05 then
			brain.traceAt, brain.traceClock = os.clock(), os.clock()
			local okCd, cd = pcall(AbilityController.Remaining, AbilityController, "Dive")
			local busy = BallController:Busy()
			elevate()
			table.insert(brain.trace, string.format("%.2f lands=%s land=%.0f catch=%.0f(%.2f) slide=%.0f walkSlow=%s bud=%.2f reach=%s hopeless=%s air=%s busy=%s cd=%s ring=%s%s",
				left, lands and "y" or "n", landDist, catchDist, catchTime - now, slide, walkTooSlow and "y" or "n", walkBudget, diveCanReach and "y" or "n",
				hopeless and "y" or "n", hum.FloorMaterial == Enum.Material.Air and "y" or "n", busy and "y" or "n",
				okCd and tostring(math.floor((tonumber(cd) or 0) * 10) / 10) or "?",
				(STATE.ringIncoming and STATE.ringIncoming(1.1)) and "I" or "", (STATE.ringNearby and STATE.ringNearby(62)) and "N" or "-"))
			while #brain.trace > 16 do
				table.remove(brain.trace, 1)
			end
		end
		if STATE.autoDive == true and lands and walkTooSlow and diveCanReach and (oldWindow or meet) and not (STATE.ringIncoming and STATE.ringIncoming(1.1)) and not (STATE.ringNearby and STATE.ringNearby(62))
			and landDist < 40 and os.clock() - brain.lastDive > 1
			-- Only when the game will actually start the dive (on the ground, not
			-- mid-swing, off cooldown): turning to dive while a swing is still
			-- going would send that hit the wrong way. The game's own dive
			-- cooldown always applies.
			and hum.FloorMaterial ~= Enum.Material.Air and not BallController:Busy()
			and (function()
				local okLeft, leftDive = pcall(AbilityController.Remaining, AbilityController, "Dive")
				return not okLeft or tonumber(leftDive) == 0
			end)() then
			local diveDir = (catchSpot or landFlat or flat) - root.Position
			if startNativeDive(root, hum, diveDir, { expectSet = true }) then
				STATE.playStatus = "Dived"
			end
		elseif hopeless and landFlat then
			-- A ball landing in your own occupied square eliminates you even at
			-- the far corner (live loss: 22 studs from the ball). Running away is
			-- therefore guaranteed to lose. Keep chasing it and make one final
			-- native Dive attempt; the game/server still decides whether it saves.
			local diveDir = landFlat - root.Position
			if STATE.autoDive == true and left <= 1.2
				and not (STATE.ringIncoming and STATE.ringIncoming(1.1))
				and not (STATE.ringNearby and STATE.ringNearby(62))
				and startNativeDive(root, hum, diveDir, { expectSet = true }) then
				STATE.playStatus = "Last-chance Dive"
			else
				STATE.playStatus = "Last chance, going for the ball"
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
		-- Never back away from a Set the native Dive just produced.
		if inCombo or (state.HitBy == LocalPlayer and state.Kind == "Set") then
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
					local spread = humanizing() and randomBetween(0.8, 3.2) or randomBetween(0, 1.5)
					brain.baseJitter = Vector3.new(math.cos(angle), 0, math.sin(angle)) * spread
				end
				-- Read Players: who hits next (the player in the square the ball
				-- is coming down in)? Wait where THEY usually aim at you.
				local nextHitter
				do
					local land = landingSpot(state, now)
					local nextZone = land and Ball.ZoneAt(zones, land)
					if nextZone and nextZone ~= myZone then
						local best
						for _, entry in ipairs(occupantsOf(nextZone)) do
							local d = ((entry.pos - land) * Vector3.new(1, 0, 1)).Magnitude
							if not best or d < best then
								nextHitter, best = entry.player, d
							end
						end
					end
				end
				local hitterBase = nextHitter and brain.hitterBase(nextHitter, myZone)
				if not brain.idleSpot or os.clock() >= brain.idleAt or justHit or (hitterBase and brain.readFor ~= nextHitter) then
					brain.idleAt = os.clock() + randomBetween(1.2, 3)
					brain.readFor = hitterBase and nextHitter or nil
					if hitterBase then
						stats.reads = (stats.reads or 0) + 1
					end
					local learned = hitterBase or (brain.learnedBase and brain.learnedBase(myZone)) or Vector3.zero
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
			-- Run about (Spin Moves): while the ball is safely flying to someone
			-- else, keep moving like the pros do (seen live: a top player ran
			-- 78% of the round and spun ~10 times a minute): quick tight loops
			-- around your spot, facing the way you run so every loop is a spin,
			-- with short rests. The character turns itself here (no forced
			-- turning), so it never slows you down, and you're back on your
			-- spot as soon as a ball can come your way.
			local runAbout = false
			if STATE.spinMoves == true and STATE.autoMove == true and not airborne
				and ((brain.idleSpot - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 6 then
				local land, landTime = landingSpot(state, now)
				local safe = land and landTime - now > 0.9 and Ball.ZoneAt(zones, land) ~= myZone
				runAbout = true
				-- Go to side steps the moment a ball could come your way, but only
				-- start looping again after a short settle, so it doesn't flick
				-- between the two (and between auto-turn on and off) every frame.
				if not safe then
					brain.loopOkAt = os.clock() + randomBetween(0.3, 0.55)
				elseif os.clock() < (brain.loopOkAt or 0) then
					safe = false
				end
				if safe then
					brain.runLoop(hum, root, brain.idleSpot)
				else
					-- A ball could come your way: keep your feet moving with
					-- quick side steps across your spot (still facing the play)
					-- instead of standing still.
					brain.sideStep(hum, root, brain.idleSpot, ballNow, myZone)
				end
			end
			if not runAbout and STATE.autoMove == true and (brain.idleSpot - root.Position) * Vector3.new(1, 0, 1) ~= Vector3.zero
				and ((brain.idleSpot - root.Position) * Vector3.new(1, 0, 1)).Magnitude > 1.5 then
				moveTo(hum, root, brain.idleSpot)
			end
			if os.clock() >= (brain.hopAt or 0) then
				local lively = STATE.spinMoves == true
				brain.hopAt = os.clock() + (lively and randomBetween(2.5, 6) or randomBetween(4, 11))
				-- Hop only when nobody can hit it at you for a second (the ball is
				-- still flying to another square): the game's dive only works
				-- from the ground, so never be in the air when it matters.
				-- (Seen live: a hop right as an enemy Portal teleported the ball
				-- into your square with 0.4s left; every dive check passed except
				-- "on the ground". So no hops while a Portal is live, and a wider
				-- safety window.)
				local land, landTime = landingSpot(state, now)
				local portalLive = STATE.portalAt and os.clock() - STATE.portalAt < 15
				local safe = land and landTime - now > 1.4 and Ball.ZoneAt(zones, land) ~= myZone and not portalLive
				-- Players hit the ball before it lands, so also wait until nobody
				-- can reach it for a second: it has to stay above spike height
				-- (~13 studs) for longer than a hop lasts. (Seen live: a hop, then
				-- a fast hit from the next square came in 0.6s, landing 2 studs
				-- away while you were still in the air.)
				if safe then
					for t = now, math.min(pathEnd(fullPath), now + 1.1), 0.05 do
						local p = Ball.Contain((pathAt(fullPath, t)))
						if p.Y - Ball.Ground(p).Y <= 13 then
							safe = false
							break
						end
					end
				end
				if math.random() < (lively and (humanizing() and 0.22 or 0.55) or 0.35) and not airborne and not read and safe then
					brain.lastJump = os.clock()
					if lively and math.random() < (humanizing() and 0.12 or 0.35) then
						brain.spinLeft = math.pi * 2
						brain.spinDir = math.random() < 0.5 and -1 or 1
					end
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
			if brain.faceBall and not runAbout then brain.faceBall(root, hum, ballNow) end
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
	local slop = humanizing() and 0.96 or 0.985
	if look.Magnitude > 0.01 and look.Unit:Dot(flat.Unit) > slop then
		return
	end
	turnToward(root, flat.Unit, humanizing() and 4.2 or 5.5)
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
		STATE.proStatus = STATE.tryhardStatus or "You're in a Pro Server (1.5x coins)"
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
-- Any live Shockwave ring whose centre is within `range` studs of you. A
-- dive slides up to ~30 studs and a ring grows to 30 across its radius, so
-- diving while one is nearby can slide you straight into it (seen live: a
-- Shockwave death 0.3s after a dive, the ring's centre too far away to
-- count as "incoming" from where you started).
function STATE.ringNearby(range)
	if STATE.dodgeShockwave ~= true or next(shockwaves) == nil then
		return false
	end
	local _, root = character()
	if not root then
		return false
	end
	for part in pairs(shockwaves) do
		if part.Parent and ((root.Position - part.Position) * Vector3.new(1, 0, 1)).Magnitude <= range then
			return true
		end
	end
	return false
end

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
	if brain.trace and #brain.trace > 0 and os.clock() - (brain.traceClock or 0) < 1.5 then
		entry.chase = table.concat(brain.trace, " | ")
	end
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
			local ring, ringHit
			for part, info in pairs(shockwaves) do
				if part.Parent and root then
					local gap = ((root.Position - part.Position) * Vector3.new(1, 0, 1)).Magnitude - part.Size.X / 2
					if math.abs(gap) < 20 then
						ring = string.format("ring edge %.1f studs away, in range=%s", gap, tostring(info.inRange == true))
						ringHit = ringHit or math.abs(gap) < 4
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
				-- Only blame the ring when its edge was actually on you.
				what = ringHit and "Killed by a Shockwave ring" or "You died",
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
				-- Portal: that player's next 3 hits teleport the ball to a random
				-- square, so where it lands can't be predicted for a while.
				if ability == "Portal" then
					STATE.portalAt = os.clock()
				end
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

-- The game has its own AFK button. Follow that click. Do not flip it back on.
function STATE.bindGameAfkButton()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("HUD")
	local inner = hud and hud:FindFirstChild("HUD")
	local left = inner and inner:FindFirstChild("Left")
	local buttons = left and left:FindFirstChild("Buttons")
	local button = buttons and buttons:FindFirstChild("AFK")
	if typeof(button) ~= "Instance" or button == STATE.afkButton then
		return
	end
	STATE.afkButton = button
	local function pressed()
		STATE.afkButtonAt = os.clock()
		STATE.afkToggleAt = os.clock()
	end
	trackConnection(button.Activated:Connect(pressed))
	trackConnection(button.MouseButton1Click:Connect(pressed))
end

function STATE.watchGameAfk()
	if STATE.afkWatching == true then
		return
	end
	STATE.afkWatching = true
	trackConnection(LocalPlayer:GetAttributeChangedSignal("AFK"):Connect(function()
		if STATE.afkPushed == true then
			STATE.afkPushed = false
			return
		end
		if os.clock() - (STATE.afkButtonAt or 0) > 1.5 then
			return
		end
		local gameAfk = LocalPlayer:GetAttribute("AFK") == true
		STATE.afk = gameAfk
		STATE.afkPush = false
		STATE.afkToggleAt = os.clock()
		if type(STATE.syncToggle) == "function" then
			pcall(STATE.syncToggle, "afk")
		end
		if type(STATE.saveConfig) == "function" then
			STATE.saveConfig()
		end
	end))
end

local function stepStayActive()
	local event = remote("ToggleAFK")
	local gameAfk = LocalPlayer:GetAttribute("AFK") == true
	if STATE.afkPush == true then
		STATE.afkPush = false
		if (STATE.afk == true) ~= gameAfk and event then
			STATE.afkToggleAt = os.clock()
			STATE.afkPushed = true
			event:FireServer()
			noteActivity(STATE.afk == true and "AFK on" or "AFK off")
		end
		return
	end
	-- Stay Active only clears AFK while the hub is meant to be playing.
	-- It never turns the game's AFK button back on.
	if STATE.afk == true then
		return
	end
	if STATE.stayActive == true and gameAfk and event and os.clock() - (STATE.afkToggleAt or 0) > 3 then
		STATE.afkToggleAt = os.clock()
		STATE.afkPushed = true
		event:FireServer()
		noteActivity("Turned the game's AFK mode off")
	end
end

function STATE.rejoin()
	game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

function STATE.hopPro()
	local ok, body = pcall(function()
		return game:HttpGet("https://games.roblox.com/v1/games/" .. PRO_PLACE .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
	end)
	if not ok then
		STATE.proStatus = "Couldn't find another Pro server"
		notify("Pro Server", "Couldn't get the server list")
		return false
	end
	local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, body)
	if not okDecode or type(decoded) ~= "table" then
		STATE.proStatus = "Couldn't find another Pro server"
		notify("Pro Server", "Couldn't read the server list")
		return false
	end
	local minimum = tonumber(STATE.hopMinPlayers) or 1
	STATE.hopMinPlayers = nil
	local function collect(atLeast)
		local found = {}
		for _, server in ipairs(decoded.data or {}) do
			local playing = tonumber(server.playing) or 0
			local max = tonumber(server.maxPlayers) or 0
			if server.id ~= game.JobId and playing >= atLeast and playing < max then
				table.insert(found, server.id)
			end
		end
		return found
	end
	local options = collect(minimum)
	if #options == 0 and minimum > 1 then
		options = collect(1)
	end
	if #options == 0 then
		STATE.proStatus = "No other Pro server with room"
		notify("Pro Server", "No other Pro server with room")
		return false
	end
	local id = options[math.random(1, math.min(#options, 12))]
	local reason = STATE.hopReason or "Hopping to another Pro server"
	STATE.hopReason = nil
	STATE.proStatus = reason
	notify("Pro Server", reason)
	local moved = pcall(function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(PRO_PLACE, id, LocalPlayer)
	end)
	return moved
end

-- Other people in this server who are actually playing, and how many of them
-- have a lot of wins. AFK players and anyone whose wins have not loaded yet
-- are left out.
function STATE.lobbyTryhard()
	local strong, active, best = 0, 0, 0
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer and player:GetAttribute("DataLoaded") == true and player:GetAttribute("AFK") ~= true then
			local stats = player:FindFirstChild("leaderstats")
			local winsValue = stats and stats:FindFirstChild("Wins")
			local wins = winsValue and tonumber(winsValue.Value) or 0
			active += 1
			if wins >= 200 then
				strong += 1
			end
			if wins > best then
				best = wins
			end
		end
	end
	return strong, active, best
end

function STATE.watchTryhard()
	if STATE.tryhardWatching == true then
		return
	end
	STATE.tryhardWatching = true
	task.spawn(function()
		local started = os.clock()
		while running() do
			task.wait(5)
			if not running() then
				return
			end
			local looking = STATE.tryhard == true and STATE.afk ~= true and game.PlaceId == PRO_PLACE and STATE.tryhardLeaving ~= true
			if not looking then
				if STATE.tryhard ~= true then
					STATE.tryhardStatus = nil
				end
			else
				local strong, _, best = STATE.lobbyTryhard()
				local good = strong >= 2 or best >= 300
				local phrase = best > 0 and string.format("Best other player has %d wins", best) or "Wins are still loading"
				local function remember()
					if type(STATE.saveConfig) == "function" then
						STATE.saveConfig()
					end
				end
				if good then
					STATE.tryhardStatus = phrase
					if (STATE.tryhardHops or 0) ~= 0 or (STATE.tryhardHold or 0) ~= 0 or (STATE.tryhardBestTop or 0) ~= 0 then
						STATE.tryhardHops = 0
						STATE.tryhardHold = 0
						STATE.tryhardBest = 0
						STATE.tryhardBestTop = 0
						STATE.tryhardBestId = ""
						remember()
					end
				elseif arenaName() then
					STATE.tryhardSeenRound = true
					STATE.tryhardStatus = phrase .. ". Playing this round"
				elseif os.time() < (STATE.tryhardHold or 0) then
					STATE.tryhardStatus = phrase .. ". Staying for a bit"
				elseif not STATE.tryhardSeenRound and os.clock() - started < 150 then
					STATE.tryhardStatus = phrase .. ". Playing here first"
				else
					if best > (STATE.tryhardBestTop or 0) and type(game.JobId) == "string" then
						STATE.tryhardBestTop = best
						STATE.tryhardBest = strong
						STATE.tryhardBestId = game.JobId
					end
					local hops = (STATE.tryhardHops or 0) + 1
					if hops > 4 and type(STATE.tryhardBestId) == "string" and STATE.tryhardBestId ~= "" and STATE.tryhardBestId ~= game.JobId then
						STATE.tryhardHops = 0
						STATE.tryhardHold = os.time() + 600
						STATE.tryhardLeaving = true
						STATE.tryhardStatus = "Going back to the lobby with the highest wins"
						remember()
						pcall(function()
							game:GetService("TeleportService"):TeleportToPlaceInstance(PRO_PLACE, STATE.tryhardBestId, LocalPlayer)
						end)
					elseif hops > 4 then
						STATE.tryhardHops = 0
						STATE.tryhardHold = os.time() + 600
						STATE.tryhardStatus = phrase .. ". Staying for a bit"
						remember()
					else
						STATE.tryhardHops = hops
						STATE.tryhardLeaving = true
						STATE.tryhardStatus = phrase .. ". Looking for a harder lobby"
						STATE.hopMinPlayers = 6
						STATE.hopReason = "Looking for people with more wins"
						remember()
						if STATE.hopPro() ~= true then
							STATE.tryhardLeaving = false
							STATE.tryhardHops = math.max(0, hops - 1)
							remember()
						end
					end
				end
			end
		end
	end)
end
STATE.watchTryhard()

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

-- The busiest server of this place that still has room (more players =
-- rounds keep starting). Returns its id and player count, or nil.
function STATE.fullestServer()
	local ok, body = pcall(function()
		return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
	end)
	if not ok then
		return nil
	end
	local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, body)
	if not okDecode then
		return nil
	end
	local best
	for _, server in ipairs(decoded and decoded.data or {}) do
		local playing, max = tonumber(server.playing) or 0, tonumber(server.maxPlayers) or 0
		if server.id ~= game.JobId and playing < max - 1 and (not best or playing > best.playing) then
			best = { id = server.id, playing = playing }
		end
	end
	return best and best.id, best and best.playing
end

-- Auto hop when your lobby empties (overnight): if the server stays under
-- 4 players between rounds for 2 minutes, move to the busiest server with
-- room. At most once every 10 minutes, and only to a server with more
-- players than this one.
do
	local emptySince, lastHop = nil, 0
	task.spawn(function()
		while running() do
			task.wait(15)
			if STATE.autoHopEmpty == true and STATE.afk ~= true and not arenaName() then
				local count = #Players:GetPlayers()
				if count < 4 then
					emptySince = emptySince or os.clock()
					STATE.hopStatus = string.format("Only %d here; moving to a busier server in %ds", count, math.max(0, math.ceil(120 - (os.clock() - emptySince))))
					if os.clock() - emptySince >= 120 and os.clock() - lastHop >= 600 then
						local id, playing = STATE.fullestServer()
						if id and playing and playing > count then
							lastHop = os.clock()
							STATE.hopStatus = "Moving to a server with " .. playing .. " players"
							noteActivity("Server nearly empty, moving to one with " .. playing .. " players")
							pcall(function()
								game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer)
							end)
						end
					end
				else
					emptySince = nil
					STATE.hopStatus = count .. " players here"
				end
			elseif arenaName() then
				emptySince = nil
			end
		end
	end)
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
		elseif key == "afk" then
			STATE.afkPush = true
			task.defer(stepStayActive)
		elseif key == "fpsBoost" and type(STATE.applyFpsBoost) == "function" then
			task.defer(STATE.applyFpsBoost)
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
	toggle(playBox, "Auto Dive", "autoDive", "Uses the game's real dive to save low balls and set them")
	toggle(playBox, "Auto Serve", "autoServe", "Serves straight away when it's your turn")
	local aimBox = section(playTab, "Aiming", "crosshair")
	toggle(aimBox, "Smart Aim", "smartAim", "Works out where each hit lands and sends it into another player's square")
	choice(aimBox, "Aim For", "Hardest to save = far from the player · Fastest = shortest flight", AIM_OPTIONS, "aimMode")
	toggle(aimBox, "Show Landing Spot", "showLanding", "Purple circle where the ball will land")
	toggle(aimBox, "Show Button Presses", "showPresses", "The Bump/Spike, Dive and ability buttons at the bottom press in when auto play uses them (only on your screen)")
	local humanBox = section(playTab, "Play Like A Human", "user-check")
	toggle(humanBox, "Humanize", "humanize", "Jogs on a curve while you wait, steps onto the ball from the side, and still goes straight when the ball is already yours")
	choice(humanBox, "Reaction Speed", "Fast 0.07-0.16s · Normal 0.14-0.28s · Relaxed 0.24-0.42s", REACTION_OPTIONS, "reaction")
	toggle(humanBox, "Native Follow-ups", "nativeFollowups", "After the game confirms a real Dive Set or ability hold, uses the remaining legal touch for a spike")
	toggle(humanBox, "Pro Plays", "trickShots", "Mixes in legal moves through normal Swing: jump serves, float shots, and bank shots off the walls")
	local moveBox = section(playTab, "Move Like A Player", "footprints")
	toggle(moveBox, "Player Movement", "playerMove", "Keeps your eyes on the ball like shift lock, leans toward the play in a ready stance, and hops now and then")
	toggle(moveBox, "Spin Moves", "spinMoves", "Style like the pros: runs quick loops and spins around your spot, hops about (with the odd 360) while the ball is flying to someone else, and sometimes does a 360 on the way up before slapping a spike. Only when it's safe, and back on your spot the moment a ball can come your way")
	toggle(moveBox, "Read Players", "readPlayers", "Learns every player as you play: where each one aims into your square (you wait there when they're about to hit), where they wait, and which spots in their square they've saved or missed (your shots go where they're weak)")
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
	toggle(proBox, "Tryhard Lobbies", "tryhard", "Plays the round, then leaves a Pro server if nobody else has 300 wins and fewer than 2 people have 200")
	button(proBox, "Hop Pro Server", "Moves you to a different Pro server", "shuffle", STATE.hopPro)

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
	toggle(cameraBox, "Potato Mode", "fpsBoost", "Flattens shadows, effects, and textures so the game is lighter. Switch it off and the normal look comes back")
	local potatoInfo = info(cameraBox, "Graphics", STATE.potatoStatus or "Off. Normal look")
	local afkBox = section(playerTab, "AFK", "moon")
	toggle(afkBox, "AFK", "afk", "On: you stand there and the hub does not play. Off: auto play carries on")
	toggle(afkBox, "Anti AFK", "antiAfk", "Stops the 20 minute idle kick")
	toggle(afkBox, "Stay Active", "stayActive", "Turns the game's AFK button off so you keep getting put in rounds. Does nothing while AFK above is on")
	toggle(afkBox, "Reload Hub After Server Change", "autoReload")
	local serverBox = section(playerTab, "Server", "server")
	toggle(serverBox, "Leave Empty Servers", "autoHopEmpty", "If your server stays under 4 players between rounds for 2 minutes, moves you to the busiest server (at most every 10 minutes). Good for leaving it on overnight")
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
				smartAim = true, aimMode = "Hardest to save", autoAbility = true, showLanding = false, showPresses = true,
				humanize = true, reaction = "Normal", nativeFollowups = true, trickShots = true, playerMove = true, proPosition = true, emotes = true, lobbyWander = true,
				autoVote = true, voteMode = "Solo", autoProServer = true, tryhard = false, tryhardHops = 0, tryhardHold = 0, tryhardBest = 0, tryhardBestTop = 0, tryhardBestId = "", autoBuyAbility = true, abilityGoal = "Guardian", abilityBuyMode = "Just my main ability", skipAbilities = {}, autoEquipAbility = true,
				autoBuyPacks = true, saveForAbility = false, packChoice = "Both", showTracker = true,
				autoDaily = true, autoQuests = true, autoAchievements = true, autoSpin = true,
				antiAfk = true, afk = false, stayActive = true, autoReload = true, notifications = true, fpsBoost = false, hideOnStart = false, customFov = false, fov = 90, dodgeShockwave = true, avoidBlasts = true,
			}
			for key, value in pairs(defaults) do
				STATE[key] = value
				syncToggle(key)
			end
			for _, entry in ipairs(dropdowns) do
				pcall(entry.element.Select, entry.element, entry.get())
			end
			saveConfig()
			if type(STATE.applyFpsBoost) == "function" then
				STATE.applyFpsBoost()
			end
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
		-- Wait for your saved stats to load (after a server change they read 0
		-- for a moment, which made the session count show all-time totals).
		if LocalPlayer:GetAttribute("DataLoaded") ~= true or not LocalPlayer:FindFirstChild("leaderstats") then
			return
		end
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
			"%s session · %d wins · %d eliminations · coins +%s\n%d hits (%d spikes, %d perfect, %d bumps) · %d dives (%d native sets) · %d serves · %d abilities\nNative follow-ups: ability %d · dive→spikes %d · float shots %d · wall shots %d · punish shots %d · 360s %d · superspike kill shots %d · quick attacks %d\nRead players: %d reads · %d weak spots learned\nServes: jump %d · tip %d · float %d\nLast: %s",
			clock, wins - stats.wins0, elims - stats.elims0, shortNumber(math.max(0, cash - stats.money0)),
			stats.hits, stats.spikes, stats.perfect, stats.bumps, stats.dives, stats.nativeDiveSets or 0, stats.serves, stats.abilities or 0,
			stats.abilityCombos or 0, stats.diveSpikes or 0, stats.tips or 0, stats.banks or 0, stats.punishes or 0, stats.spins or 0, stats.superspikes or 0, stats.quickAttacks or 0, stats.reads or 0, stats.learnedMisses or 0,
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
		setInfo(potatoInfo, tostring(STATE.potatoStatus or "Off. Normal look"))
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
		-- WindUI opens itself a moment after it's created (with an animation),
		-- which undid an immediate close. Close it once it has finished
		-- opening, and check again a bit later.
		for _, delay in ipairs({ 0.8, 1.6, 3 }) do
			task.delay(delay, function()
				if windowGone or not running() then
					return
				end
				elevate()
				local frame = Window.UIElements and Window.UIElements.Main
				local shown = not (typeof(frame) == "Instance" and frame:IsA("GuiObject")) or frame.Visible
				if shown and not brain.menuOpenedByUser then
					pcall(Window.Close, Window)
				end
			end)
		end
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
if STATE.fpsBoost == true and type(STATE.applyFpsBoost) == "function" then
	task.defer(STATE.applyFpsBoost)
end

-- Rewards and staying active.
task.spawn(function()
	pcall(STATE.watchGameAfk)
	pcall(STATE.bindGameAfkButton)
	if STATE.afk == true then
		STATE.afkPush = true
		pcall(stepStayActive)
	end
	task.wait(3)
	while running() do
		pcall(STATE.bindGameAfkButton)
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
			if gui and LocalPlayer:GetAttribute("DataLoaded") == true and LocalPlayer:FindFirstChild("leaderstats") then
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
