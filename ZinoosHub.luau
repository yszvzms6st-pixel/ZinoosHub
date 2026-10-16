-- Zinoos hub for Lift Rock For Eggs.
-- The bench grants strength. The treadmill grants speed.
-- Strength only, until rebirth is maxed. After that, the treadmill only.
-- Rebirth, gym/floor/basement upgrades, and the best affordable trail use the game's own remotes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

if game.PlaceId ~= 76731343328034 then
	warn("[Zinoos hub] This only runs in Lift Rock For Eggs.")
	return
end

local genv = getgenv()
local STATE
do
	local shared = genv.STATE
	if typeof(shared) ~= "table" then
		shared = {}
		genv.STATE = shared
	end
	STATE = shared
end
STATE._replaceHub = nil
genv.ZinoosReplace = nil

local featureOn = {}
local function featureReady(name)
	return featureOn[name] ~= false
end
local function disableFeature(name, dependency)
	if featureOn[name] == false then
		return
	end
	featureOn[name] = false
	if type(STATE.featureDown) ~= "table" then
		STATE.featureDown = {}
	end
	STATE.featureDown[name] = dependency
	warn(string.format("[Zinoos hub] %s is off because %s is missing.", name, dependency))
end

function STATE.noteFault(name, ok, err)
	if type(STATE.featureFaults) ~= "table" then
		STATE.featureFaults = {}
	end
	if ok then
		STATE.featureFaults[name] = nil
		return true
	end
	local message = tostring(err)
	if #message > 140 then
		message = string.sub(message, 1, 137) .. "..."
	end
	if STATE.featureFaults[name] ~= message then
		STATE.featureFaults[name] = message
		if STATE.admin == true and name ~= "Auto Steal" then
			warn(string.format("[Zinoos hub] %s: %s", tostring(name), message))
		end
	end
	return false
end

function STATE.watchFeature(name, fn)
	local ok, result = pcall(fn)
	STATE.noteFault(name, ok, result)
	return ok, result
end

local runtime = {
	stopped = false,
	connections = {},
	cleanups = {},
}

local function graphicsSnapshot()
	local snap = {}
	pcall(function()
		snap.quality = settings().Rendering.QualityLevel
	end)
	snap.shadows = Lighting.GlobalShadows
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local sun = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if bloom then
		snap.bloomEnabled = bloom.Enabled == true
	end
	if sun then
		snap.sunEnabled = sun.Enabled == true
	end
	pcall(function()
		snap.anim = workspace.ClientAnimatorThrottling
	end)
	pcall(function()
		snap.interp = (workspace :: any).InterpolationThrottling
	end)
	return snap
end

local function applyGraphics(snap, low)
	if type(snap) ~= "table" then
		return false
	end
	local failed = false
	local qualityOk = pcall(function()
		if low then
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		elseif snap.quality ~= nil then
			settings().Rendering.QualityLevel = snap.quality
		end
	end)
	failed = failed or not qualityOk
	if low then
		Lighting.GlobalShadows = false
	elseif typeof(snap.shadows) == "boolean" then
		Lighting.GlobalShadows = snap.shadows
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom and typeof(snap.bloomEnabled) == "boolean" then
		bloom.Enabled = if low then false else snap.bloomEnabled
	end
	local sun = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if sun and typeof(snap.sunEnabled) == "boolean" then
		sun.Enabled = if low then false else snap.sunEnabled
	end
	local throttleOk = pcall(function()
		local world = workspace :: any
		if low then
			workspace.ClientAnimatorThrottling = Enum.ClientAnimatorThrottlingMode.Enabled
			world.InterpolationThrottling = Enum.InterpolationThrottlingMode.Enabled
		else
			if snap.anim ~= nil then
				workspace.ClientAnimatorThrottling = snap.anim
			end
			if snap.interp ~= nil then
				world.InterpolationThrottling = snap.interp
			end
		end
	end)
	failed = failed or not throttleOk
	return not failed
end

local function captureBaseline()
	if type(genv.ZinoosGraphicsBaseline) == "table" then
		return genv.ZinoosGraphicsBaseline
	end
	local snap = graphicsSnapshot()
	genv.ZinoosGraphicsBaseline = snap
	return snap
end

local function restoreBaseline()
	local snap = genv.ZinoosGraphicsBaseline
	if type(snap) ~= "table" then
		return true
	end
	local ok = applyGraphics(snap, false)
	if ok then
		genv.ZinoosGraphicsBaseline = nil
	end
	return ok
end

local function destroyZinoosGuis()
	local function sweep(root)
		if not root then
			return
		end
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("ScreenGui") and (child.Name == "ZinoosHubMenu" or child.Name == "ZinoosInvEsp" or child:FindFirstChild("Zinoos hub")) then
				child:Destroy()
			end
		end
	end
	sweep(CoreGui)
	sweep(CoreGui:FindFirstChild("RobloxGui"))
	local codex = CoreGui:FindFirstChild("CodexLiftRock")
	if codex then
		codex:Destroy()
	end
end

local function showLiteModels()
	local live = workspace:FindFirstChild("Live")
	if not live then
		return
	end
	for _, child in ipairs(live:GetDescendants()) do
		if child.Name == "ZinoosEggValue" or child.Name == "ZinoosHoldValue" or child.Name == "ZinoosPlotEgg" then
			child:Destroy()
		elseif child:IsA("Model") then
			child:SetAttribute("ZinoosLite", nil)
		elseif child:IsA("BasePart") then
			child.LocalTransparencyModifier = 0
			if child:GetAttribute("ZinoosShadow") == true then
				child.CastShadow = true
				child:SetAttribute("ZinoosShadow", nil)
			end
		elseif (child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam") or child:IsA("Light") or child:IsA("Highlight")) and child:GetAttribute("ZinoosHid") == true then
			child.Enabled = true
			child:SetAttribute("ZinoosHid", nil)
		end
	end
end

local function connectionAlive(connection)
	local alive = false
	local ok = pcall(function()
		alive = connection.Connected == true
	end)
	return ok and alive
end

local function forgetConnection(connection)
	runtime.connections[connection] = nil
end

local function trackConnection(connection, owner)
	local canDisconnect = false
	pcall(function()
		canDisconnect = typeof(connection.Disconnect) == "function"
	end)
	if not canDisconnect or not connectionAlive(connection) then
		return connection
	end
	runtime.connections[connection] = true
	if typeof(owner) ~= "Instance" then
		return connection
	end
	local release
	release = owner.Destroying:Connect(function()
		forgetConnection(connection)
		forgetConnection(release)
		pcall(function()
			connection:Disconnect()
		end)
		pcall(function()
			release:Disconnect()
		end)
	end)
	if connectionAlive(release) then
		runtime.connections[release] = true
	else
		forgetConnection(release)
	end
	return connection
end

local function pruneConnections()
	for connection in pairs(runtime.connections) do
		if not connectionAlive(connection) then
			runtime.connections[connection] = nil
		end
	end
end

local function disconnectOwned()
	local snapshot = runtime.connections
	runtime.connections = {}
	for connection in pairs(snapshot) do
		pcall(function()
			connection:Disconnect()
		end)
	end
end

function STATE.connectionCount()
	pruneConnections()
	local alive = 0
	for _ in pairs(runtime.connections) do
		alive += 1
	end
	return alive
end

local function hubCleanup(fn)
	table.insert(runtime.cleanups, fn)
end

local function closeLeftoverMenus()
	destroyZinoosGuis()
end

local function shutdownHub(mode)
	local restoring = mode == "unload" or mode == "failed"
	if runtime.stopped then
		if restoring then
			destroyZinoosGuis()
			showLiteModels()
			restoreBaseline()
		end
		return
	end
	runtime.stopped = true
	genv.ZinoosGen = (typeof(genv.ZinoosGen) == "number" and genv.ZinoosGen or 0) + 1
	STATE._gen = -1
	STATE._alive = false
	STATE.liftSteal = false
	STATE.stealGoal = nil
	if mode == "unload" then
		STATE._unloaded = true
	end
	disconnectOwned()
	for index = #runtime.cleanups, 1, -1 do
		local fn = runtime.cleanups[index]
		runtime.cleanups[index] = nil
		pcall(fn)
	end
	destroyZinoosGuis()
	local marker = CoreGui:FindFirstChild("ZinoosHub")
	if marker then
		marker:Destroy()
	end
	if restoring then
		showLiteModels()
		restoreBaseline()
	end
end

local function legacyStop()
	local shared = genv.STATE
	genv.ZinoosGen = (typeof(genv.ZinoosGen) == "number" and genv.ZinoosGen or 0) + 1
	if typeof(shared) == "table" then
		shared._gen = -1
		shared._alive = false
		shared.liftSteal = false
		shared.stealGoal = nil
		if type(shared._connections) == "table" then
			for index = #shared._connections, 1, -1 do
				local connection = shared._connections[index]
				shared._connections[index] = nil
				pcall(function()
					connection:Disconnect()
				end)
			end
		end
		shared._connections = nil
	end
	if typeof(filtergc) == "function" then
		local ok, copies = pcall(function()
			return filtergc("table", { Keys = { "stealZone", "_gen", "autoSteal" } }, false)
		end)
		if ok and type(copies) == "table" then
			for _, copy in ipairs(copies) do
				if copy ~= STATE then
					copy._alive = false
					copy._gen = -1
				end
			end
		end
	end
	destroyZinoosGuis()
	local oldMarker = CoreGui:FindFirstChild("ZinoosHub")
	if oldMarker then
		oldMarker:Destroy()
	end
end

local previousShutdown = genv.ZinoosShutdown
genv.ZinoosShutdown = shutdownHub
STATE.shutdown = shutdownHub
if typeof(previousShutdown) == "function" then
	local stopped, stopErr = pcall(previousShutdown, "replace")
	if not stopped then
		warn("[Zinoos hub] Could not stop the previous run: " .. tostring(stopErr))
		legacyStop()
	end
else
	legacyStop()
end
captureBaseline()

local hubMarker = Instance.new("Folder")
hubMarker.Name = "ZinoosHub"
hubMarker.Parent = CoreGui
local startupFinished = false
local mainThread = coroutine.running()
task.spawn(function()
	while not startupFinished do
		if coroutine.status(mainThread) == "dead" then
			pcall(shutdownHub, "failed")
			return
		end
		task.wait(0.1)
	end
end)

local LocalPlayer = Players.LocalPlayer
local function loadModule(label, loader)
	local ok, result = pcall(loader)
	if ok and result ~= nil then
		return result
	end
	warn(string.format("[Zinoos hub] dependency %s is missing.", label))
	return nil
end
local Shared = loadModule("ReplicatedStorage.Shared", function()
	return ReplicatedStorage:WaitForChild("Shared", 8)
end)
local Net = Shared and loadModule("Shared.Net", function()
	return require(Shared:WaitForChild("Net", 8))
end)
local allowLeaveBench = function()
	return false
end
local function unwrapNetFire(fn)
	local current = fn
	if typeof(getupvalues) ~= "function" then
		return current
	end
	for _ = 1, 6 do
		local ok, ups = pcall(getupvalues, current)
		if not ok or type(ups) ~= "table" then
			break
		end
		local gate, inner = nil, nil
		for _, value in pairs(ups) do
			if typeof(value) == "function" then
				local calledOk, result = pcall(value)
				if calledOk and type(result) == "boolean" then
					gate = value
				else
					inner = inner or value
				end
			end
		end
		if not (gate and inner) then
			break
		end
		current = inner
	end
	return current
end
local currentFire = typeof(Net) == "table" and Net.FireServer or nil
local netFireServer = currentFire
if typeof(STATE) == "table" and currentFire == STATE._fireWrapper and typeof(STATE._rawNetFire) == "function" then
	netFireServer = STATE._rawNetFire
elseif typeof(STATE) == "table" and currentFire == STATE._rawNetFire and typeof(STATE._rawNetFire) == "function" then
	netFireServer = STATE._rawNetFire
end
if typeof(STATE) == "table" and typeof(STATE._rawNetFire) ~= "function" then
	local rawFire = unwrapNetFire(currentFire)
	if typeof(rawFire) == "function" then
		STATE._rawNetFire = rawFire
	end
end
if typeof(netFireServer) ~= "function" and typeof(STATE) == "table" and typeof(STATE._rawNetFire) == "function" then
	netFireServer = STATE._rawNetFire
end
local fireWrapper
fireWrapper = function(self, remoteName, ...)
	if remoteName == "LeaveBench" then
		local allowedOk, allowed = pcall(allowLeaveBench)
		if allowedOk and allowed == false then
			return
		end
	end
	if remoteName == "StartBench" and STATE.liftSteal == true then
		return
	end
	return netFireServer(self, remoteName, ...)
end
if typeof(Net) == "table" and typeof(netFireServer) == "function" then
	Net.FireServer = fireWrapper
	STATE._fireWrapper = fireWrapper
end
local function configModule(name)
	return Shared and loadModule("Shared.Configs." .. name, function()
		return require(Shared.Configs[name])
	end)
end
local Rebirths = configModule("Rebirths")
local Gym = configModule("Gym")
local Plot = configModule("Plot")
local Trails = configModule("Trails")
local Pets = configModule("Pets")
local Rarities = configModule("Rarities")
local Wild = configModule("Wild")
local Zones = configModule("Zones")
local DailyRewards = configModule("DailyRewards")
local Format = Shared and loadModule("Shared.Format", function()
	return require(Shared.Format)
end)
local Grades = configModule("Grades")
local displayWarned = {}
local function warnDisplayOnce(name, dependency)
	if displayWarned[name] then
		return
	end
	displayWarned[name] = true
	warn(string.format("[Zinoos hub] %s is off because %s is missing.", name, dependency))
end
local function shortNumber(value)
	if typeof(Format) == "table" and typeof(Format.Short) == "function" then
		local ok, text = pcall(Format.Short, value)
		if ok and text ~= nil then
			return tostring(text)
		end
	end
	warnDisplayOnce("Number display", "Format.Short")
	return tostring(value)
end
local function petSpec(key)
	if typeof(Pets) == "table" and typeof(Pets.Specs) == "table" then
		return Pets.Specs[key]
	end
	warnDisplayOnce("Pet display", "Pets.Specs")
	return nil
end
local ClientRegistry = loadModule("ClientRegistry", function()
	local scripts = LocalPlayer:WaitForChild("PlayerScripts", 8)
	local moduleScript = scripts:WaitForChild("Client"):WaitForChild("Lib"):WaitForChild("ClientRegistry")
	local loadModuleScript = require :: any
	return loadModuleScript(moduleScript)
end)

local FLOORS = {
	Meadow = { pos = Vector3.new(198, 19, 153), size = Vector3.new(96, 36, 120) },
	Desert = { pos = Vector3.new(198, 20, -8), size = Vector3.new(96, 39, 171) },
	Volcano = { pos = Vector3.new(198, 22, -226), size = Vector3.new(96, 43, 233) },
	Snow = { pos = Vector3.new(198, 24, -540), size = Vector3.new(96, 46, 361) },
	Crystal = { pos = Vector3.new(198, 26, -936), size = Vector3.new(96, 50, 401) },
	Jungle = { pos = Vector3.new(198, 28, -1374), size = Vector3.new(96, 53, 441) },
	Candy = { pos = Vector3.new(198, 30, -1896), size = Vector3.new(96, 57, 573) },
	Haunted = { pos = Vector3.new(198, 31, -2572), size = Vector3.new(96, 60, 745) },
	Heaven = { pos = Vector3.new(198, 33, -3444), size = Vector3.new(96, 64, 969) },
	Space = { pos = Vector3.new(198, 34, -4575), size = Vector3.new(96, 67, 1260) },
	Prehistoric = { pos = Vector3.new(198, 34, -5835), size = Vector3.new(96, 67, 1260) },
}
local FALLBACK_RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine", "Exclusive" }
local rarityOptions = {}
local rarityRank = {}
if typeof(Rarities) == "table" and typeof(Rarities.Order) == "table" then
	for index, name in ipairs(Rarities.Order) do
		if type(name) == "string" and name ~= "" then
			rarityRank[name] = index
			rarityOptions[#rarityOptions + 1] = name
		end
	end
end
if #rarityOptions == 0 then
	for index, name in ipairs(FALLBACK_RARITIES) do
		rarityRank[name] = index
		rarityOptions[index] = name
	end
end
local mutationRank = { None = 0, Golden = 1, Diamond = 2, Rainbow = 3, Cursed = 4 }
local rarityOfName = {}
local weightOfName = {}
if typeof(Zones) == "table" and typeof(Zones.Order) == "table" and typeof(Wild) == "table" and typeof(Wild.SpawnWeights) == "table" and typeof(Pets) == "table" and typeof(Pets.Specs) == "table" then
	for _, zoneName in ipairs(Zones.Order) do
		local weights = Wild.SpawnWeights[zoneName]
		if type(weights) == "table" then
			for key, weight in pairs(weights) do
				local spec = Pets.Specs[key]
				local name = spec and (spec.DisplayName or spec.Name)
				if name then
					rarityOfName[name] = rarityRank[spec.Rarity] or 0
					weightOfName[name] = weight
				end
			end
		end
	end
end
local rarityByDisplay = {}
if typeof(Pets) == "table" and typeof(Pets.Specs) == "table" then
	for _, spec in pairs(Pets.Specs) do
		if type(spec) == "table" and type(spec.DisplayName) == "string" and type(spec.Rarity) == "string" then
			rarityByDisplay[spec.DisplayName] = spec.Rarity
		end
	end
end
local queueRare

function STATE.connect(signal, fn, owner)
	if typeof(fn) ~= "function" then
		return nil
	end
	local ok, connection = pcall(function()
		return signal:Connect(fn)
	end)
	if not ok then
		return nil
	end
	return trackConnection(connection, owner)
end
STATE.onCleanup = hubCleanup
if typeof(STATE.override) ~= "function" then
	function STATE.override(tbl, key, value)
		tbl[key] = value
	end
end

local function bindFeature(name, checks)
	for _, check in ipairs(checks) do
		local ok, pass = pcall(check.test)
		if not ok or pass ~= true then
			disableFeature(name, check.name)
			return
		end
	end
	featureOn[name] = true
end

local function bindFeatures()
	STATE.featureDown = {}
	STATE.featureFaults = {}
	local hasFire = typeof(Net) == "table" and typeof(Net.FireServer) == "function"
	local hasInvoke = typeof(Net) == "table" and typeof(Net.InvokeServer) == "function"
	local hasOnClient = typeof(Net) == "table" and typeof(Net.OnClient) == "function"
	bindFeature("Auto Train", {
		{ name = "Net.FireServer", test = function()
			return hasFire
		end },
		{ name = "Rebirths", test = function()
			return typeof(Rebirths) == "table"
		end },
	})
	bindFeature("Auto Rebirth", {
		{ name = "Net.FireServer", test = function()
			return hasFire
		end },
		{ name = "Rebirths", test = function()
			return typeof(Rebirths) == "table"
		end },
	})
	bindFeature("Auto Upgrade", {
		{ name = "Net.InvokeServer", test = function()
			return hasInvoke
		end },
		{ name = "Gym.LevelOf", test = function()
			return typeof(Gym) == "table" and typeof(Gym.LevelOf) == "function" and typeof(Gym.UnlockCost) == "number" and typeof(Gym.Levels) == "table"
		end },
		{ name = "Plot.FloorPrice", test = function()
			return typeof(Plot) == "table" and typeof(Plot.FloorPrice) == "function" and typeof(Plot.BasementPrice) == "function" and typeof(Plot.MaxLevel) == "number" and typeof(Plot.MaxBasementLevel) == "number"
		end },
	})
	bindFeature("Auto Trails", {
		{ name = "Net.FireServer", test = function()
			return hasFire
		end },
		{ name = "Trails.Order", test = function()
			return typeof(Trails) == "table" and typeof(Trails.Order) == "table" and typeof(Trails.Defs) == "table"
		end },
	})
	bindFeature("Auto Steal", {
		{ name = "Net.FireServer", test = function()
			return hasFire
		end },
		{ name = "Zones.Order", test = function()
			return typeof(Zones) == "table" and typeof(Zones.Order) == "table"
		end },
		{ name = "Pets.Specs", test = function()
			return typeof(Pets) == "table" and typeof(Pets.Specs) == "table"
		end },
	})
	bindFeature("Auto Place", {
		{ name = "Net.FireServer", test = function()
			return hasFire
		end },
		{ name = "Plot.Slots", test = function()
			return typeof(Plot) == "table" and typeof(Plot.Slots) == "function"
		end },
	})
	bindFeature("Auto Open", {
		{ name = "Net.FireServer", test = function()
			return hasFire
		end },
	})
	bindFeature("Equip Best", {
		{ name = "Net.FireServer", test = function()
			return hasFire
		end },
		{ name = "Plot.Slots", test = function()
			return typeof(Plot) == "table" and typeof(Plot.Slots) == "function"
		end },
		{ name = "Pets.IncomeFor", test = function()
			return typeof(Pets) == "table" and typeof(Pets.IncomeFor) == "function"
		end },
		{ name = "Plot.PetLevelMultiplier", test = function()
			return typeof(Plot) == "table" and typeof(Plot.PetLevelMultiplier) == "function"
		end },
		{ name = "Grades.Multiplier", test = function()
			return typeof(Grades) == "table" and typeof(Grades.Multiplier) == "function"
		end },
	})
	bindFeature("Auto Daily", {
		{ name = "Net.FireServer", test = function()
			return hasFire
		end },
		{ name = "DailyRewards", test = function()
			return typeof(DailyRewards) == "table"
		end },
	})
	bindFeature("Auto Index", {
		{ name = "Net.InvokeServer", test = function()
			return hasInvoke
		end },
	})
	bindFeature("Free Stash", {
		{ name = "Net.FireServer", test = function()
			return hasFire
		end },
		{ name = "Net.OnClient", test = function()
			return hasOnClient
		end },
	})
	bindFeature("Inventory ESP", {
		{ name = "Pets.IncomeFor", test = function()
			return typeof(Pets) == "table" and typeof(Pets.IncomeFor) == "function"
		end },
	})
	bindFeature("Low End", {
		{ name = "Rendering.QualityLevel", test = function()
			return settings().Rendering.QualityLevel ~= nil
		end },
	})
end
bindFeatures()

STATE.train = nil
setmetatable(STATE, {
	__index = function(_, key)
		if key == "train" then
			return false
		end
		return nil
	end,
	__newindex = function(table, key, value)
		if key == "train" then
			return
		end
		rawset(table, key, value)
	end,
})
if STATE.autoTrain == nil then
	STATE.autoTrain = true
end
if STATE.rebirth == nil then
	STATE.rebirth = true
end
if STATE.upgrade == nil then
	STATE.upgrade = true
end
if STATE.trails == nil then
	STATE.trails = true
end
if STATE.equipBest == nil then
	STATE.equipBest = true
end
if STATE.autoSteal == nil then
	STATE.autoSteal = true
end
if STATE.autoPlace ~= true then
	STATE.autoPlace = false
end
if STATE.placementPriority ~= "Lowest Rarity First" and STATE.placementPriority ~= "Inventory Order" then
	STATE.placementPriority = "Highest Rarity First"
end
if STATE.autoOpen == nil then
	STATE.autoOpen = true
end
STATE.autoSell = false
if STATE.autoDaily == nil then
	STATE.autoDaily = true
end
if STATE.autoIndex == nil then
	STATE.autoIndex = true
end
if STATE.freeStash == nil then
	STATE.freeStash = true
end
if STATE.litePets == nil then
	STATE.litePets = true
end
if STATE.eggEsp == nil then
	STATE.eggEsp = true
end
if STATE.invEsp == nil then
	STATE.invEsp = true
end
if STATE.lowEnd == nil then
	STATE.lowEnd = true
end
if STATE.webhookOn == nil then
	STATE.webhookOn = true
end
if STATE.antiAfk == nil then
	STATE.antiAfk = true
end
if STATE.phoneGames == nil then
	STATE.phoneGames = false
end
if STATE.phoneChoice ~= "When Pigs Fly" and STATE.phoneChoice ~= "Snack Stack" then
	STATE.phoneChoice = "Critter Merge"
end
if type(STATE.webhook) ~= "string" then
	STATE.webhook = ""
end
if rarityRank[STATE.webhookRarity] == nil then
	STATE.webhookRarity = "Divine"
end
if rarityRank[STATE.placeRarity] == nil then
	STATE.placeRarity = rarityOptions[1] or "Common"
end
if type(STATE.stealZone) ~= "string" or FLOORS[STATE.stealZone] == nil then
	STATE.stealZone = "Meadow"
end
genv.ZinoosGen = (typeof(genv.ZinoosGen) == "number" and genv.ZinoosGen or 0) + 1
local token = genv.ZinoosGen
STATE._alive = false
STATE._gen = math.floor(os.clock() * 1000)
local myGen = STATE._gen
STATE._unloaded = false
task.wait(0.05)
local function running()
	return genv.ZinoosGen == token and STATE._gen == myGen
end
STATE.alive = running

STATE.liftSteal = false
STATE.stealGoal = nil
STATE.nextSteal = 0
STATE.stashGen = (STATE.stashGen or 0) + 1
local stashGen = STATE.stashGen
if featureReady("Free Stash") then
	trackConnection(Net:OnClient("BrockStashStart", function(payload)
		if not running() or STATE.stashGen ~= stashGen or type(payload) ~= "table" or type(payload.cards) ~= "table" then
			return
		end
		STATE.stashCards = payload.cards
		STATE.stashTaken = {}
		for index = 1, tonumber(payload.stage) or 0 do
			STATE.stashTaken[index] = true
		end
	end))
	trackConnection(Net:OnClient("BrockStashState", function(payload)
		if not running() or STATE.stashGen ~= stashGen or type(payload) ~= "table" then
			return
		end
		for key in pairs(payload.taken or {}) do
			local index = tonumber(key)
			if index then
				STATE.stashTaken[index] = true
			end
		end
	end))
	trackConnection(Net:OnClient("BrockStashEnd", function()
		if not running() or STATE.stashGen ~= stashGen then
			return
		end
		STATE.stashCards = nil
		STATE.stashTaken = {}
	end))
end

local added = {}
local lastRebirthAt = 0
local lastSwitchAt = 0
local popped = setmetatable({}, { __mode = "k" })


local function contentHeight(menu)
	local height = 0
	for _, child in ipairs(menu:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, 5) ~= "Codex" then
			height += child.Size.Y.Offset
		end
	end
	return height
end


local function unloadHub()
	shutdownHub("unload")
end

hubCleanup(function()
	if typeof(Net) == "table" and Net.FireServer == fireWrapper and typeof(netFireServer) == "function" then
		Net.FireServer = netFireServer
	end
	local gui = CoreGui:FindFirstChild("ToraScript")
	local title = gui and gui:FindFirstChildWhichIsA("ImageButton")
	local menu = title and title:FindFirstChild("Frame")
	for _, row in ipairs(added) do
		if row.Parent then
			row:Destroy()
		end
	end
	table.clear(added)
	if menu then
		local height = contentHeight(menu)
		if height > 0 then
			menu.Size = UDim2.new(1, 0, 0, height)
		end
	end
end)

local function hideBestNotice(text)
	return type(text) == "string" and string.find(text, "best animals", 1, true) ~= nil
end

local function clearBestNotices()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local frame = playerGui and playerGui:FindFirstChild("Notifications")
	frame = frame and frame:FindFirstChild("Frame")
	if not frame then
		return
	end
	for _, child in ipairs(frame:GetChildren()) do
		local label = child:FindFirstChild("Label")
		if label and label:IsA("TextLabel") and hideBestNotice(label.Text) then
			child:Destroy()
		end
	end
end

local noticeController = nil
local originalShow = nil
local showWrapper = nil
task.defer(function()
	if not running() then
		return
	end
	if typeof(ClientRegistry) ~= "table" or typeof(ClientRegistry.TryGet) ~= "function" then
		return
	end
	local notifications = ClientRegistry.TryGet("NotificationController")
	if not notifications or typeof(notifications.Show) ~= "function" then
		return
	end
	local currentShow = notifications.Show
	if currentShow == STATE._showWrapper and typeof(STATE._originalShow) == "function" then
		currentShow = STATE._originalShow
	end
	noticeController = notifications
	originalShow = currentShow
	showWrapper = function(self, text, kind, gradient)
		if hideBestNotice(text) then
			return
		end
		return originalShow(self, text, kind, gradient)
	end
	notifications.Show = showWrapper
	STATE._showWrapper = showWrapper
	STATE._originalShow = originalShow
	clearBestNotices()
end)
hubCleanup(function()
	if noticeController and showWrapper and noticeController.Show == showWrapper and typeof(originalShow) == "function" then
		noticeController.Show = originalShow
	end
end)

local function readData()
	if typeof(ClientRegistry) ~= "table" or typeof(ClientRegistry.Get) ~= "function" then
		return nil
	end
	local data = nil
	pcall(function()
		data = ClientRegistry.Get("DataController"):Get()
	end)
	return data
end

local function myGym()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local owner = plot:FindFirstChild("owner")
		if owner and owner.Value == LocalPlayer.Name then
			return plot:FindFirstChild("Gym")
		end
	end
	return nil
end

local function onPart(hrp, part, padX, padZ, minY, maxY)
	local rel = part.CFrame:PointToObjectSpace(hrp.Position)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X + padX
		and math.abs(rel.Z) <= half.Z + padZ
		and rel.Y > minY
		and rel.Y < maxY
end

local function standOn(hrp, humanoid, part)
	local look = part.CFrame.LookVector
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	local stand = part.Position + Vector3.new(0, humanoid.HipHeight + hrp.Size.Y / 2 + 0.5, 0)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = CFrame.lookAt(stand, stand + look)
end

local function dismountTreadmill()
	if os.clock() - lastSwitchAt < 0.6 then
		return
	end
	lastSwitchAt = os.clock()
	local ok, connections = pcall(getconnections, game:GetService("UserInputService").JumpRequest)
	if not ok or not connections then
		return
	end
	for _, connection in ipairs(connections) do
		if connection.Function then
			pcall(connection.Function)
		end
	end
end

local function updateFocus()
	if typeof(Rebirths) ~= "table" then
		STATE.trainFocus = "strength"
		return
	end
	local data = readData()
	local maxed = data ~= nil and Rebirths[(data.rebirths or 0) + 1] == nil
	STATE.trainFocus = maxed and "speed" or "strength"
end

local function releaseGym()
	if LocalPlayer:GetAttribute("Benching") then
		if typeof(Net) ~= "table" or typeof(Net.FireServer) ~= "function" then
			return false
		end
		if os.clock() - lastSwitchAt >= 0.4 then
			lastSwitchAt = os.clock()
			Net:FireServer("LeaveBench")
		end
		return false
	end
	if LocalPlayer:GetAttribute("TrainingMounted") == true then
		dismountTreadmill()
		return false
	end
	return true
end

local activeGoal = nil
hubCleanup(function()
	activeGoal = nil
	STATE.liftSteal = false
	STATE.stealGoal = nil
	STATE.placeBusy = false
end)

local function pinGoal(part, goal)
	if not part or typeof(goal) ~= "CFrame" then
		return
	end
	part.AssemblyLinearVelocity = Vector3.zero
	part.CFrame = goal
end

local function stepTrain()
	if STATE.liftSteal then
		local character = LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local goal = activeGoal
		if hrp and typeof(goal) == "CFrame" then
			releaseGym()
			pinGoal(hrp, goal)
			task.defer(function()
				if STATE.liftSteal and hrp.Parent and typeof(activeGoal) == "CFrame" then
					pinGoal(hrp, activeGoal)
				end
			end)
		end
		return
	end
	if STATE.placeBusy == true then
		releaseGym()
		return
	end
	if not featureReady("Auto Train") or STATE.autoTrain ~= true then
		if LocalPlayer:GetAttribute("Benching") or LocalPlayer:GetAttribute("TrainingMounted") == true then
			releaseGym()
		end
		return
	end
	if LocalPlayer:GetAttribute("GymOwned") ~= true then
		return
	end
	updateFocus()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or humanoid.Health <= 0 then
		return
	end
	local gym = myGym()
	if not gym then
		if typeof(STATE.homePos) == "Vector3" then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = CFrame.new(STATE.homePos)
		end
		return
	end
	local bench = gym:FindFirstChild("Bench")
	local seat = bench and bench:FindFirstChild("Seat")
	local treadmill = gym:FindFirstChild("Treadmill")
	local belt = treadmill and treadmill:FindFirstChild("Belt")
	local runPart = treadmill and treadmill:FindFirstChild("RunPart")
	if not seat then
		if typeof(STATE.homePos) == "Vector3" then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = CFrame.new(STATE.homePos)
		end
		return
	end

	if STATE.trainFocus == "speed" then
		if LocalPlayer:GetAttribute("TrainingMounted") == true then
			return
		end
		if LocalPlayer:GetAttribute("Benching") then
			if os.clock() - lastSwitchAt >= 0.6 then
				lastSwitchAt = os.clock()
				Net:FireServer("LeaveBench")
			end
			return
		end
		if belt and not onPart(hrp, belt, 0.5, 0.5, -1, 9) then
			standOn(hrp, humanoid, runPart or belt)
		end
		return
	end

	if LocalPlayer:GetAttribute("Benching") then
		return
	end
	if LocalPlayer:GetAttribute("TrainingMounted") == true then
		dismountTreadmill()
		return
	end
	if seat and not onPart(hrp, seat, 0.6, 0.6, -1, 6) then
		standOn(hrp, humanoid, seat)
	end
end

local function stepRebirth()
	if STATE.rebirth ~= true or not featureReady("Auto Rebirth") then
		return
	end
	local data = readData()
	if not data then
		return
	end
	local nextTier = Rebirths[(data.rebirths or 0) + 1]
	if typeof(nextTier) ~= "table" or typeof(nextTier.StrengthRequirement) ~= "number" then
		return
	end
	if typeof(data.strength) ~= "number" or data.strength < nextTier.StrengthRequirement then
		return
	end
	if os.clock() - lastRebirthAt < 4 then
		return
	end
	lastRebirthAt = os.clock()
	Net:FireServer("RequestRebirth")
end

local function stepUpgrade()
	if STATE.upgrade ~= true or not featureReady("Auto Upgrade") then
		return
	end
	local data = readData()
	if not data or typeof(data.cash) ~= "number" then
		return
	end
	local cash = data.cash
	if data.gymOwned ~= true then
		if cash >= Gym.UnlockCost then
			Net:InvokeServer("BuyGym")
		end
		return
	end
	local level = Gym.LevelOf(data.gymLevel)
	local nextLevel = typeof(level) == "number" and Gym.Levels[level + 1]
	if typeof(level) == "number" and level < #Gym.Levels and typeof(nextLevel) == "table" and typeof(nextLevel.Price) == "number" and cash >= nextLevel.Price then
		Net:InvokeServer("UpgradeGym")
		return
	end
	local nextFloor = (data.baseLevel or 0) + 1
	if typeof(nextFloor) == "number" and nextFloor <= Plot.MaxLevel then
		local priceOk, floorPrice = pcall(function()
			return Plot.FloorPrice(nextFloor)
		end)
		if priceOk and typeof(floorPrice) == "number" and cash >= floorPrice then
			Net:InvokeServer("BuyFloorLevel", nextFloor)
			return
		end
	end
	local nextBasement = (data.basementLevel or 0) + 1
	if typeof(nextBasement) == "number" and nextBasement <= Plot.MaxBasementLevel then
		local priceOk, basementPrice = pcall(function()
			return Plot.BasementPrice(nextBasement)
		end)
		if priceOk and typeof(basementPrice) == "number" and cash >= basementPrice then
			Net:InvokeServer("BuyBasementLevel", nextBasement)
		end
	end
end

local function stepTrails()
	if STATE.trails ~= true or not featureReady("Auto Trails") then
		return
	end
	local data = readData()
	if not data then
		return
	end
	local owned = data.trails or {}
	local cash = data.cash or 0
	local ceiling = 0
	local bestOwned = nil
	local bestMultiplier = -1
	for _, name in ipairs(Trails.Order) do
		local def = Trails.Defs[name]
		if def and owned[name] then
			ceiling = math.max(ceiling, def.Price or 0)
			if name ~= "None" and (def.Multiplier or 0) > bestMultiplier then
				bestMultiplier = def.Multiplier or 0
				bestOwned = name
			end
		end
	end
	local buyName = nil
	local buyPrice = ceiling
	for _, name in ipairs(Trails.Order) do
		local def = Trails.Defs[name]
		local price = def and def.Price or 0
		if def and name ~= "None" and price > ceiling and not owned[name] and price <= cash and price > buyPrice then
			buyName = name
			buyPrice = price
		end
	end
	if typeof(buyName) == "string" then
		Net:FireServer("BuyTrail", buyName)
		return
	end
	if typeof(bestOwned) == "string" and data.trail ~= bestOwned then
		Net:FireServer("EquipTrail", bestOwned)
	end
end

local prehistoricEggs

local function homeSpot()
	local gym = myGym()
	local bench = gym and gym:FindFirstChild("Bench")
	local seat = bench and bench:FindFirstChild("Seat")
	if seat then
		STATE.homePos = seat.Position + Vector3.new(0, 6, 0)
	end
	return STATE.homePos or Vector3.new(299, 10, 314)
end

function STATE.normalizeRarities(list)
	local ordered = {}
	if type(list) ~= "table" then
		return ordered
	end
	local seen = {}
	for _, name in ipairs(rarityOptions) do
		for _, item in ipairs(list) do
			if item == name and not seen[name] then
				seen[name] = true
				ordered[#ordered + 1] = name
			end
		end
	end
	return ordered
end

function STATE.expandRarity(name)
	local rank = rarityRank[name]
	local ordered = {}
	if not rank then
		return ordered
	end
	for _, option in ipairs(rarityOptions) do
		if (rarityRank[option] or 0) >= rank then
			ordered[#ordered + 1] = option
		end
	end
	return ordered
end

function STATE.raritySelected(list, rank)
	if type(rank) ~= "number" or type(list) ~= "table" then
		return false
	end
	local name = rarityOptions[rank]
	if type(name) ~= "string" then
		return false
	end
	for _, item in ipairs(list) do
		if item == name then
			return true
		end
	end
	return false
end

function STATE.rarityLabel(list)
	if type(list) ~= "table" or #list == 0 then
		return "None"
	end
	return table.concat(list, ", ")
end

function STATE.toggleRarity(list, name)
	if rarityRank[name] == nil then
		return STATE.normalizeRarities(list)
	end
	local nextList = {}
	local found = false
	if type(list) == "table" then
		for _, item in ipairs(list) do
			if item == name then
				found = true
			else
				nextList[#nextList + 1] = item
			end
		end
	end
	if not found then
		nextList[#nextList + 1] = name
	end
	return STATE.normalizeRarities(nextList)
end

if type(STATE.alertRarities) ~= "table" then
	STATE.alertRarities = STATE.expandRarity(STATE.webhookRarity or "Divine")
end
if type(STATE.placeRarities) ~= "table" then
	STATE.placeRarities = STATE.expandRarity(STATE.placeRarity or rarityOptions[1] or "Common")
end

function STATE.toolEggRank(tool)
	if typeof(tool) ~= "Instance" then
		return nil
	end
	local named = tool:GetAttribute("Rarity")
	if type(named) ~= "string" then
		named = tool:GetAttribute("rarity")
	end
	if type(named) == "string" and rarityRank[named] then
		return rarityRank[named]
	end
	local key = tool:GetAttribute("Key")
	if key ~= nil then
		local spec = petSpec(key)
		if spec and type(spec.Rarity) == "string" and rarityRank[spec.Rarity] then
			return rarityRank[spec.Rarity]
		end
	end
	local uid = tool:GetAttribute("petUID")
	if uid ~= nil then
		uid = tostring(uid)
		local data = readData()
		local function findPet(list)
			if type(list) ~= "table" then
				return nil
			end
			local direct = list[uid]
			if type(direct) == "table" then
				return direct
			end
			for _, pet in pairs(list) do
				if type(pet) == "table" and tostring(pet.uid) == uid then
					return pet
				end
			end
			return nil
		end
		local pet = findPet(data and data.backpack) or findPet(data and data.plotPets)
		if type(pet) == "table" then
			local spec = petSpec(pet.key)
			if spec and type(spec.Rarity) == "string" and rarityRank[spec.Rarity] then
				return rarityRank[spec.Rarity]
			end
		end
	end
	local petName = string.gsub(tool.Name, "%s*%b()%s*$", "")
	petName = string.gsub(petName, " Egg$", "")
	local rank = rarityOfName[petName] or rarityOfName[tool.Name]
	if rank then
		return rank
	end
	local display = rarityByDisplay[petName] or rarityByDisplay[tool.Name]
	if type(display) == "string" and rarityRank[display] then
		return rarityRank[display]
	end
	return nil
end

function STATE.eggWorthPlacing(tool)
	local rank = STATE.toolEggRank(tool)
	if rank == nil then
		return false
	end
	return STATE.raritySelected(STATE.placeRarities, rank)
end

function STATE.placementChoice(value)
	if value == "Lowest Rarity First" or value == "Inventory Order" or value == "Highest Rarity First" then
		return value
	end
	return "Highest Rarity First"
end

function STATE.plotData()
	if type(STATE._plotTestData) == "function" then
		return STATE._plotTestData()
	end
	return readData()
end

function STATE.plotInvoke(name, ...)
	if type(STATE._plotTestInvoke) == "function" then
		return STATE._plotTestInvoke(name, ...)
	end
	return Net:FireServer(name, ...)
end

function STATE.acquirePlot(reason, toggleName)
	if STATE._plotLock ~= nil or not running() then
		return nil
	end
	if type(toggleName) == "string" and STATE[toggleName] ~= true then
		return nil
	end
	local lock = {
		reason = reason,
		toggle = toggleName,
		gen = STATE._gen,
		token = genv.ZinoosGen,
	}
	STATE._plotLock = lock
	return lock
end

function STATE.releasePlot(lock)
	if lock ~= nil and STATE._plotLock == lock then
		STATE._plotLock = nil
	end
end

function STATE.generationOwns(lock)
	if type(lock) ~= "table" or STATE._plotLock ~= lock then
		return false, "Feature cancelled"
	end
	if not running() or lock.gen ~= STATE._gen or lock.token ~= genv.ZinoosGen then
		return false, "Generation replaced"
	end
	return true
end

function STATE.plotOwns(lock, toggleName)
	local owns, why = STATE.generationOwns(lock)
	if not owns then
		return false, why
	end
	local toggle = toggleName or lock.toggle
	if type(toggle) == "string" and STATE[toggle] ~= true then
		return false, "Feature cancelled"
	end
	return true
end

function STATE.plotPetRecord(data, uid)
	local pets = type(data) == "table" and data.plotPets or nil
	if type(pets) ~= "table" or type(uid) ~= "string" then
		return nil
	end
	if type(pets[uid]) == "table" then
		return pets[uid]
	end
	for _, pet in pairs(pets) do
		if type(pet) == "table" and pet.uid ~= nil and tostring(pet.uid) == uid then
			return pet
		end
	end
	return nil
end

function STATE.petCoords(pet)
	local pos = type(pet) == "table" and pet.pos or nil
	if type(pos) ~= "table" then
		return nil, nil
	end
	local x = pos.x or pos.X
	local z = pos.z or pos.Z
	if type(x) ~= "number" or type(z) ~= "number" then
		return nil, nil
	end
	return x, z
end

function STATE.waitPlot(lock, toggleName, predicate)
	local testing = type(STATE._plotTestInvoke) == "function" or type(STATE._plotTestData) == "function"
	local ticks = 0
	local deadline = os.clock() + 2.4
	local function ownsNow()
		if toggleName == false then
			return STATE.generationOwns(lock)
		end
		return STATE.plotOwns(lock, toggleName)
	end
	while true do
		local owns, why = ownsNow()
		if not owns then
			return false, why
		end
		local data = STATE.plotData()
		if predicate(data) == true then
			return true
		end
		if testing then
			ticks += 1
			if ticks >= 6 then
				break
			end
		elseif os.clock() >= deadline then
			break
		else
			task.wait(0.12)
		end
	end
	local owns, why = ownsNow()
	if not owns then
		return false, why
	end
	return false, "Timed out waiting for confirmation"
end

function STATE.plotRoom(data)
	data = data or STATE.plotData()
	if type(data) ~= "table" then
		return nil
	end
	local slots = nil
	if type(STATE._plotTestData) == "function" and type(STATE._plotTestSlots) == "number" and STATE._plotTestSlots >= 1 then
		slots = STATE._plotTestSlots
	else
		if typeof(Plot) ~= "table" or typeof(Plot.Slots) ~= "function" then
			return nil
		end
		local level = data.baseLevel
		if type(level) ~= "number" then
			level = 0
		end
		local ok, counted = pcall(Plot.Slots, level)
		if not ok or type(counted) ~= "number" or counted < 1 then
			return nil
		end
		slots = counted
	end
	local animals = 0
	local eggs = 0
	if type(data.plotPets) == "table" then
		for _, pet in pairs(data.plotPets) do
			if type(pet) == "table" then
				local spec = petSpec(pet.key)
				if pet.hatchAt ~= nil or (spec and spec.IsEgg) then
					eggs += 1
				else
					animals += 1
				end
			end
		end
	end
	return {
		activeAnimals = animals,
		growingEggs = eggs,
		activeSlots = slots,
		free = animals < slots,
		slots = slots,
		occupied = animals,
	}
end

function STATE.placeHoldActive()
	local room = STATE.plotRoom()
	if room and room.free == true then
		STATE.placeHoldUntil = 0
		STATE.placeHoldCount = nil
	elseif room and type(STATE.placeHoldCount) == "number" and room.activeAnimals < STATE.placeHoldCount then
		STATE.placeHoldUntil = 0
		STATE.placeHoldCount = nil
	end
	return os.clock() < (STATE.placeHoldUntil or 0) and STATE.placeStatus == "Confirmed full"
end

function STATE.markPlaceHold()
	local room = STATE.plotRoom()
	if not room or room.free ~= false then
		return false
	end
	STATE.placeHoldCount = room.activeAnimals
	STATE.placeHoldUntil = os.clock() + 12
	STATE.placeStatus = "Confirmed full"
	return true
end

function STATE.guardedPlace(lock, toggleName, uid, x, z, confirm, eggPlace)
	local owns, why = STATE.plotOwns(lock, toggleName)
	if not owns then
		return why, false
	end
	if type(uid) ~= "string" or type(x) ~= "number" or type(z) ~= "number" then
		return "Selection became invalid", false
	end
	local room = STATE.plotRoom()
	if eggPlace ~= true and room and room.free == false then
		STATE.markPlaceHold()
		return "Confirmed full", false
	end
	owns, why = STATE.plotOwns(lock, toggleName)
	if not owns then
		return why, false
	end
	local fired = pcall(STATE.plotInvoke, "PlacePet", uid, x, z)
	if not fired then
		return "Remote rejected", false
	end
	local confirmed, waitWhy = STATE.waitPlot(lock, false, function(data)
		if type(confirm) == "function" then
			return confirm(data) == true
		end
		return STATE.plotPetRecord(data, uid) ~= nil
	end)
	if confirmed then
		return true, true
	end
	if waitWhy == "Generation replaced" or waitWhy == "Feature cancelled" then
		return waitWhy, true
	end
	local fresh = STATE.plotData()
	if type(confirm) == "function" and confirm(fresh) == true then
		return true, true
	end
	if STATE.plotPetRecord(fresh, uid) ~= nil then
		return true, true
	end
	if eggPlace ~= true then
		local again = STATE.plotRoom(fresh)
		if again and again.free == false then
			STATE.markPlaceHold()
			return "Confirmed full", true
		end
	end
	return "Timed out waiting for confirmation", true
end

function STATE.petOnPlot(uid)
	if type(uid) ~= "string" then
		return false
	end
	local data = readData()
	local pets = data and data.plotPets
	if type(pets) ~= "table" then
		return false
	end
	if type(pets[uid]) == "table" then
		return true
	end
	for _, pet in pairs(pets) do
		if type(pet) == "table" and pet.uid ~= nil and tostring(pet.uid) == uid then
			return true
		end
	end
	return false
end

function STATE.collectPlaceEggs()
	local list = {}
	local function scan(container, equipped)
		if not container then
			return
		end
		for index, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("isEgg") and type(child:GetAttribute("petUID")) == "string" and STATE.eggWorthPlacing(child) then
				list[#list + 1] = {
					tool = child,
					rank = STATE.toolEggRank(child) or 0,
					order = (equipped and 0 or 1000) + index,
					name = child.Name,
					uid = child:GetAttribute("petUID"),
				}
			end
		end
	end
	scan(LocalPlayer.Character, true)
	scan(LocalPlayer:FindFirstChild("Backpack"), false)
	local priority = STATE.placementChoice(STATE.placementPriority)
	table.sort(list, function(a, b)
		if priority == "Inventory Order" or a.rank == b.rank then
			return a.order < b.order
		end
		if priority == "Lowest Rarity First" then
			return a.rank < b.rank
		end
		return a.rank > b.rank
	end)
	return list
end

function STATE.placeSelectedEgg(fromSteal)
	if not running() then
		return "Feature cancelled"
	end
	if not fromSteal and STATE.autoPlace ~= true then
		return nil
	end
	local toggleName = fromSteal and "autoSteal" or "autoPlace"
	local lock = STATE.acquirePlot(fromSteal and "delivery" or "place", toggleName)
	if not lock then
		return "Feature cancelled"
	end
	local leftTraining = false
	local function finish(result)
		if leftTraining then
			STATE.placeBusy = false
		end
		STATE.releasePlot(lock)
		return result
	end
	local function note(text)
		if fromSteal and STATE.autoPlace ~= true and text ~= "Confirmed full" then
			return
		end
		STATE.placeStatus = text
	end
	local owns, why = STATE.plotOwns(lock, toggleName)
	if not owns then
		return finish(why)
	end
	if type(STATE._plotTestInvoke) == "function" and type(STATE._plotTestPlace) == "table" then
		local testUid = STATE._plotTestPlace.uid
		if type(testUid) ~= "string" then
			return finish("Selection became invalid")
		end
		local result = STATE.guardedPlace(lock, toggleName, testUid, STATE._plotTestPlace.x or 0, STATE._plotTestPlace.z or 0, function(data)
			return STATE.plotPetRecord(data, testUid) ~= nil
		end, true)
		if result == "Confirmed full" then
			note("Confirmed full")
		elseif result == "Remote rejected" or result == "Timed out waiting for confirmation" then
			STATE.placeStatus = result
		end
		return finish(result)
	end
	local function withinReach(base)
		local character = LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp or not (base and base:IsA("BasePart")) then
			return false
		end
		local offset = Vector3.new(base.Position.X - hrp.Position.X, 0, base.Position.Z - hrp.Position.Z)
		local reach = Vector3.new(base.Size.X, 0, base.Size.Z).Magnitude / 2 + 30
		return offset.Magnitude <= reach
	end
	local chosen = STATE.collectPlaceEggs()[1]
	if not chosen or typeof(chosen.tool) ~= "Instance" then
		if not fromSteal then
			note("No selected eggs")
		end
		return finish(nil)
	end
	local tool = chosen.tool
	local uid = chosen.uid
	local eggName = type(chosen.name) == "string" and chosen.name or "egg"
	if type(uid) ~= "string" or not STATE.eggWorthPlacing(tool) then
		return finish("Selection became invalid")
	end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return finish("Away from plot")
	end
	if not fromSteal and (LocalPlayer:GetAttribute("Benching") or LocalPlayer:GetAttribute("TrainingMounted") == true) then
		STATE.placeBusy = true
		leftTraining = true
		local releaseUntil = os.clock() + 2
		while os.clock() < releaseUntil and running() and STATE.autoPlace == true do
			if releaseGym() and not LocalPlayer:GetAttribute("Benching") and LocalPlayer:GetAttribute("TrainingMounted") ~= true then
				break
			end
			task.wait(0.1)
		end
	end
	if typeof(ClientRegistry) ~= "table" or typeof(ClientRegistry.Get) ~= "function" then
		return finish("Away from plot")
	end
	local plot = ClientRegistry.Get("PlotController"):GetPlot(LocalPlayer)
	local base = plot and plot:FindFirstChild("Base")
	if not (base and base:IsA("BasePart")) then
		return finish("Away from plot")
	end
	if fromSteal then
		local homeUntil = os.clock() + 3
		while not withinReach(base) and os.clock() < homeUntil and running() do
			task.wait(0.1)
		end
	end
	if not withinReach(base) then
		return finish("Away from plot")
	end
	owns, why = STATE.plotOwns(lock, toggleName)
	if not owns then
		return finish(why)
	end
	if tool.Parent == nil or not STATE.eggWorthPlacing(tool) then
		return finish("Selection became invalid")
	end
	note("Placing " .. eggName)
	local taken = {}
	local fresh = STATE.plotData()
	for _, pet in pairs(fresh and fresh.plotPets or {}) do
		local px, pz = STATE.petCoords(pet)
		if type(px) == "number" and type(pz) == "number" then
			taken[#taken + 1] = { px, pz }
		end
	end
	local halfX = math.max(8, base.Size.X * 0.45)
	local halfZ = math.max(6, base.Size.Z * 0.45)
	local x, z = nil, nil
	for n = 1, 48 do
		local col = (n - 1) % 8
		local row = math.floor((n - 1) / 8)
		local tryX = -halfX + (col + 0.5) * ((halfX * 2) / 8)
		local tryZ = -halfZ + (row + 0.5) * ((halfZ * 2) / 6)
		local clear = true
		for _, pos in ipairs(taken) do
			local dx = tryX - pos[1]
			local dz = tryZ - pos[2]
			if dx * dx + dz * dz < 36 then
				clear = false
				break
			end
		end
		if clear then
			x, z = tryX, tryZ
			break
		end
	end
	if type(x) ~= "number" or type(z) ~= "number" then
		x = (math.random() - 0.5) * math.min(base.Size.X * 0.8, halfX * 2)
		z = (math.random() - 0.5) * math.min(base.Size.Z * 0.8, halfZ * 2)
	end
	if type(x) ~= "number" or type(z) ~= "number" then
		return finish("Selection became invalid")
	end
	if tool.Parent ~= character then
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		if tool.Parent ~= backpack then
			return finish("Selection became invalid")
		end
		humanoid:EquipTool(tool)
		task.wait(0.15)
	end
	owns, why = STATE.plotOwns(lock, toggleName)
	if not owns then
		return finish(why)
	end
	local result = STATE.guardedPlace(lock, toggleName, uid, x, z, function(data)
		return tool.Parent == nil or STATE.plotPetRecord(data, uid) ~= nil
	end, true)
	if result == true then
		note("Placed " .. eggName)
		return finish(true)
	end
	if result == "Confirmed full" then
		note("Confirmed full")
		return finish("Confirmed full")
	end
	if result == "Remote rejected" or result == "Timed out waiting for confirmation" then
		STATE.placeStatus = result
	end
	return finish(result)
end

function STATE.stepAutoPlace()
	if not running() or STATE.autoPlace ~= true or not featureReady("Auto Place") then
		return
	end
	if os.clock() < (STATE.nextAutoPlace or 0) then
		return
	end
	if STATE.placeBusy == true then
		return
	end
	local eggs = STATE.collectPlaceEggs()
	if #eggs == 0 then
		STATE.placeStatus = "No selected eggs"
		STATE.nextAutoPlace = os.clock() + 1.2
		return
	end
	if STATE._plotLock ~= nil then
		return
	end
	STATE.placeStatus = "Scanning inventory"
	local placed = STATE.placeSelectedEgg(false)
	if placed == "Confirmed full" then
		STATE.placeStatus = "Confirmed full"
		STATE.nextAutoPlace = os.clock() + 3
	elseif placed == "Away from plot" then
		STATE.placeStatus = "Away from plot"
		STATE.nextAutoPlace = os.clock() + 2
	elseif placed == true then
		STATE.nextAutoPlace = os.clock() + 0.6
	elseif placed == nil then
		STATE.placeStatus = "No selected eggs"
		STATE.nextAutoPlace = os.clock() + 1.2
	elseif type(placed) == "string" then
		STATE.placeStatus = placed
		STATE.nextAutoPlace = os.clock() + 4
	else
		STATE.nextAutoPlace = os.clock() + 4
	end
end

local function deliverHeld()
	activeGoal = CFrame.new(homeSpot())
	STATE.stealGoal = activeGoal
	for _ = 1, 16 do
		if not running() then
			return false
		end
		if LocalPlayer:GetAttribute("holdingFriend") == true then
			task.wait(0.25)
			continue
		end
		local placed = STATE.placeSelectedEgg(true)
		if placed == nil or placed == true then
			return true
		end
		return false
	end
	return LocalPlayer:GetAttribute("holdingFriend") ~= true
end

local function stealZone()
	local name = STATE.stealZone
	if type(name) == "string" and FLOORS[name] then
		return name
	end
	return "Meadow"
end

local function zoneChoice(value)
	if type(value) == "table" then
		value = value[1]
	end
	if type(value) == "string" and FLOORS[value] then
		return value
	end
	return "Meadow"
end

local alertedEggs = setmetatable({}, { __mode = "k" })

local function alertRank()
	return rarityRank[STATE.webhookRarity] or rarityRank.Divine or 10
end

local function rockById(id)
	if type(id) ~= "string" then
		return nil
	end
	local folder = workspace:FindFirstChild("BonusRocks")
	return folder and folder:FindFirstChild(id) or nil
end

local function rockIsLifted(id)
	local rock = rockById(id)
	return rock ~= nil and rock:GetAttribute("LiftedLocal") == true
end

local function eggLabel(model)
	local key = model:GetAttribute("Key")
	local spec = key and typeof(Pets) == "table" and typeof(Pets.Specs) == "table" and Pets.Specs[key]
	local name = spec and spec.DisplayName
	if type(name) ~= "string" or name == "" then
		name = model.Name
	end
	if not string.find(name, "Egg", 1, true) then
		name ..= " Egg"
	end
	return name
end

local function eggRank(model)
	local key = model:GetAttribute("Key")
	local spec = key and typeof(Pets) == "table" and typeof(Pets.Specs) == "table" and Pets.Specs[key]
	if spec and type(spec.Rarity) == "string" and rarityRank[spec.Rarity] then
		return rarityRank[spec.Rarity]
	end
	local petName = string.gsub(model.Name, " Egg$", "")
	local rank = rarityOfName[petName] or rarityOfName[model.Name]
	if rank then
		return rank
	end
	return rarityRank[rarityByDisplay[petName] or ""] or 0
end

local function inZone(pos, zone)
	local floor = FLOORS[zone or stealZone()]
	if not floor then
		return false
	end
	local halfX = floor.size.X / 2 + 40
	local halfZ = floor.size.Z / 2 + 40
	return math.abs(pos.X - floor.pos.X) <= halfX and math.abs(pos.Z - floor.pos.Z) <= halfZ
end

local function stealDaytime()
	local phase = ReplicatedStorage:GetAttribute("TimeOfDayPhase")
	local dayId = ReplicatedStorage:GetAttribute("TimeOfDayEndsAt")
	return phase == "Day" and typeof(dayId) == "number"
end

local function rarityName(rank)
	local name = rarityOptions[rank]
	if type(name) == "string" and name ~= "" then
		return name
	end
	return "Unknown"
end

local function modelAlive(model)
	if typeof(model) ~= "Instance" then
		return false
	end
	local ok, parent = pcall(function()
		return model.Parent
	end)
	return ok and parent ~= nil
end

local function assessEgg(model, fromFront)
	local exists = modelAlive(model)
	local pos = Vector3.zero
	if exists then
		local ok, pivot = pcall(function()
			return model:GetPivot().Position
		end)
		if ok and typeof(pivot) == "Vector3" then
			pos = pivot
		else
			exists = false
		end
	end
	local zone = stealZone()
	local zoneOk = fromFront == true
	if exists and not zoneOk then
		zoneOk = model:GetAttribute("SpawnZone") == zone and inZone(pos, zone)
	end
	local rank = exists and eggRank(model) or 0
	local meets = STATE.raritySelected(STATE.alertRarities, rank)
	local bonusId = exists and model:GetAttribute("BonusRock") or nil
	local locked = type(bonusId) == "string" and not rockIsLifted(bonusId)
	local prompt = nil
	if exists then
		local foundOk, found = pcall(function()
			return model:FindFirstChild("StealPrompt", true)
		end)
		if foundOk and typeof(found) == "Instance" and found:IsA("ProximityPrompt") then
			prompt = found
		end
	end
	local promptOk = false
	if prompt then
		local enabledOk, enabled = pcall(function()
			return prompt.Enabled
		end)
		local distanceOk, distance = pcall(function()
			return prompt.MaxActivationDistance
		end)
		local parentOk, parent = pcall(function()
			return prompt.Parent
		end)
		promptOk = enabledOk and enabled == true and distanceOk and type(distance) == "number" and distance > 0 and parentOk and parent ~= nil
	end
	local day = stealDaytime()
	local worth = exists and zoneOk and meets and not locked and promptOk
	local reason = nil
	if not exists then
		reason = "gone"
	elseif not zoneOk then
		reason = "wrong zone"
	elseif locked then
		reason = "under a rock"
	elseif not promptOk then
		reason = "unavailable"
	elseif not meets then
		reason = "below rarity"
	elseif not day then
		reason = "waiting for daytime"
	end
	local label = exists and eggLabel(model) or "Egg"
	local mutationName = "None"
	if exists then
		local mutationOk, mutation = pcall(function()
			return model:GetAttribute("Mutation")
		end)
		if mutationOk and mutation ~= nil then
			mutationName = tostring(mutation)
		end
	end
	local petName = string.gsub(label, " Egg$", "")
	return {
		model = model,
		prompt = promptOk and prompt or nil,
		pos = pos,
		label = label,
		rarity = rarityName(rank),
		rank = rank,
		mutation = mutationName,
		mutationScore = mutationRank[mutationName] or 0,
		weight = weightOfName[petName] or 999,
		front = fromFront == true,
		locked = locked,
		worth = worth == true,
		canAttempt = worth == true and day == true,
		reason = reason,
	}
end

local function listSpawnedEggs()
	local list = {}
	local function addEgg(egg, fromFront)
		if not egg:IsA("Model") then
			return
		end
		local info = assessEgg(egg, fromFront)
		if info.reason == "gone" or info.reason == "wrong zone" then
			return
		end
		list[#list + 1] = info
	end
	local live = workspace:FindFirstChild("Live")
	local folder = live and live:FindFirstChild("Friends")
	if folder then
		for _, egg in ipairs(folder:GetChildren()) do
			addEgg(egg, false)
		end
	end
	local stock = workspace:FindFirstChild("_MeadowStock")
	if stock then
		for _, egg in ipairs(stock:GetChildren()) do
			addEgg(egg, true)
		end
	end
	table.sort(list, function(a, b)
		if a.worth ~= b.worth then
			return a.worth
		end
		if a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return a.label < b.label
	end)
	return list
end

local function scanPoints(zone)
	local floor = FLOORS[zone or stealZone()] or FLOORS.Meadow
	local halfZ = floor.size.Z / 2 - 20
	local span = math.max(halfZ * 2, 1)
	local count = math.clamp(math.ceil(span / 400), 1, 4)
	local points = {}
	for index = 1, count do
		local offset = count == 1 and 0 or -halfZ + (index - 1) / (count - 1) * span
		points[index] = Vector3.new(floor.pos.X, 8, floor.pos.Z + offset)
	end
	return points
end

function prehistoricEggs()
	local list = {}
	local function consider(egg, fromFront)
		if not egg:IsA("Model") then
			return
		end
		local info = assessEgg(egg, fromFront)
		if not info.worth or not info.prompt or not info.model then
			return
		end
		if queueRare and not alertedEggs[egg] then
			local accepted = queueRare("Eligible egg", info.label, nil, "egg|" .. tostring(os.clock()) .. "|" .. egg:GetFullName())
			if accepted then
				alertedEggs[egg] = true
			end
		end
		list[#list + 1] = {
			model = info.model,
			prompt = info.prompt,
			pos = info.pos,
			rarity = info.rank,
			weight = info.weight,
			mutation = info.mutationScore,
			label = info.label,
		}
	end
	local live = workspace:FindFirstChild("Live")
	local folder = live and live:FindFirstChild("Friends")
	if folder then
		for _, egg in ipairs(folder:GetChildren()) do
			consider(egg, false)
		end
	end
	local stock = workspace:FindFirstChild("_MeadowStock")
	if stock then
		for _, egg in ipairs(stock:GetChildren()) do
			consider(egg, true)
		end
	end
	table.sort(list, function(a, b)
		if a.rarity ~= b.rarity then
			return a.rarity > b.rarity
		end
		if a.weight ~= b.weight then
			return a.weight < b.weight
		end
		return a.mutation > b.mutation
	end)
	return list
end

allowLeaveBench = function()
	if STATE.autoTrain ~= true then
		return true
	end
	if STATE.trainFocus == "speed" then
		return true
	end
	local eggs = prehistoricEggs()
	local egg = eggs[1]
	return STATE.liftSteal == true and egg ~= nil and egg.model.Parent ~= nil
end

local function betterEgg(a, b)
	if not b then
		return a
	end
	if not a then
		return b
	end
	if a.rarity ~= b.rarity then
		return a.rarity > b.rarity and a or b
	end
	if a.weight ~= b.weight then
		return a.weight < b.weight and a or b
	end
	if a.mutation ~= b.mutation then
		return a.mutation > b.mutation and a or b
	end
	return a
end

local function streamAround(pos, seconds)
	local done = false
	task.spawn(function()
		pcall(function()
			LocalPlayer:RequestStreamAroundAsync(pos, seconds)
		end)
		done = true
	end)
	local limit = os.clock() + seconds + 0.75
	while not done and os.clock() < limit do
		if not running() or STATE.autoSteal ~= true then
			return
		end
		task.wait(0.1)
	end
end

local function hasEggTool()
	local function scan(container)
		if not container then
			return false
		end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("isEgg") and type(child:GetAttribute("petUID")) == "string" and STATE.eggWorthPlacing(child) then
				return true
			end
		end
		return false
	end
	return scan(LocalPlayer:FindFirstChild("Backpack")) or scan(LocalPlayer.Character)
end

function STATE.holdingUnseenEgg()
	if LocalPlayer:GetAttribute("holdingFriend") ~= true then
		return false
	end
	local function seen(container)
		if not container then
			return false
		end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("isEgg") then
				return true
			end
		end
		return false
	end
	return not seen(LocalPlayer.Character) and not seen(LocalPlayer:FindFirstChild("Backpack"))
end

local function peekPrehistoric()
	local seen = {}
	local function consider()
		for _, egg in ipairs(prehistoricEggs()) do
			local key = string.format("%d,%d", math.floor(egg.pos.X + 0.5), math.floor(egg.pos.Z + 0.5))
			seen[key] = betterEgg(seen[key], egg)
		end
	end
	local function bestSeen()
		local best = nil
		for _, egg in pairs(seen) do
			best = betterEgg(best, egg)
		end
		return best
	end
	consider()
	local best = bestSeen()
	if not (best and best.model.Parent) then
		for _, pos in ipairs(scanPoints(stealZone())) do
			if not running() or STATE.autoSteal ~= true then
				break
			end
			streamAround(pos, 3)
			consider()
			best = bestSeen()
			if best and best.model.Parent then
				break
			end
		end
	end
	best = bestSeen()
	if best and not best.model.Parent then
		streamAround(best.pos, 3)
		local nearest = nil
		local nearestDist = 40
		for _, egg in ipairs(prehistoricEggs()) do
			local dist = (egg.pos - best.pos).Magnitude
			if dist < nearestDist then
				nearest = egg
				nearestDist = dist
			end
		end
		best = nearest
	end
	if best and best.model.Parent then
		return best
	end
	return nil
end

local stealRestores = {}
local function rememberSteal(instance, property)
	if typeof(instance) ~= "Instance" then
		return
	end
	local ok, value = pcall(function()
		return instance[property]
	end)
	if ok then
		stealRestores[#stealRestores + 1] = { instance, property, value }
	end
end
local function restoreStealChanges()
	for index = #stealRestores, 1, -1 do
		local item = stealRestores[index]
		stealRestores[index] = nil
		local instance = item[1]
		if typeof(instance) == "Instance" and instance.Parent then
			pcall(function()
				instance[item[2]] = item[3]
			end)
		end
	end
end
hubCleanup(restoreStealChanges)

local function stageCFrame()
	local gym = myGym()
	local bench = gym and gym:FindFirstChild("Bench")
	local seat = bench and bench:FindFirstChild("Seat")
	if not seat then
		return nil
	end
	local stand = seat.Position + seat.CFrame.LookVector * 16 + Vector3.new(0, 4, 0)
	return CFrame.new(stand)
end

local function standOutFront()
	local goal = stageCFrame()
	if typeof(goal) ~= "CFrame" then
		return false
	end
	STATE.liftSteal = true
	activeGoal = goal
	STATE.stealGoal = goal
	local limit = os.clock() + 2
	while os.clock() < limit and running() and STATE.autoSteal == true do
		local character = LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
			humanoid.Sit = false
		end
		if LocalPlayer:GetAttribute("Benching") then
			releaseGym()
		end
		if hrp then
			pinGoal(hrp, goal)
			if not LocalPlayer:GetAttribute("Benching") and (hrp.Position - goal.Position).Magnitude < 8 then
				return true
			end
		end
		task.wait(0.05)
	end
	return false
end

local function backToBench()
	local gym = myGym()
	local bench = gym and gym:FindFirstChild("Bench")
	local seat = bench and bench:FindFirstChild("Seat")
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if seat and hrp and humanoid then
		standOn(hrp, humanoid, seat)
		STATE.liftSteal = true
		activeGoal = hrp.CFrame
		STATE.stealGoal = activeGoal
		task.wait(0.25)
	elseif seat and hrp then
		local back = CFrame.new(seat.Position + Vector3.new(0, 3, 0))
		STATE.liftSteal = true
		activeGoal = back
		STATE.stealGoal = back
		pinGoal(hrp, back)
		task.wait(0.25)
	end
	activeGoal = nil
	STATE.liftSteal = false
	STATE.stealGoal = nil
	LocalPlayer:SetAttribute("CodexMode", "train")
end

local stealAttempts = setmetatable({}, { __mode = "k" })
local stealIdentities = {}
local STEAL_ATTEMPT_LIMIT = 3
local STEAL_RETRY_WAIT = 4

local function clearStealAttempts()
	table.clear(stealAttempts)
	table.clear(stealIdentities)
end

local function eggIdentity(model)
	if typeof(model) ~= "Instance" then
		return nil
	end
	local zone = model:GetAttribute("SpawnZone")
	local slot = model:GetAttribute("SlotIndex")
	local key = model:GetAttribute("Key")
	if slot ~= nil and key ~= nil then
		return tostring(zone) .. "|slot|" .. tostring(slot) .. "|" .. tostring(key)
	end
	if not (model:IsA("Model") or model:IsA("BasePart")) then
		return tostring(zone) .. "|" .. model.Name
	end
	local ok, pivot = pcall(function()
		return model:GetPivot().Position
	end)
	if not ok or typeof(pivot) ~= "Vector3" then
		return tostring(zone) .. "|" .. model.Name
	end
	return string.format("%s|%s|%d|%d", tostring(zone), model.Name, math.floor(pivot.X / 4), math.floor(pivot.Z / 4))
end

local function findStealRecord(model)
	if typeof(model) ~= "Instance" then
		return nil
	end
	local record = stealAttempts[model]
	if type(record) == "table" then
		return record
	end
	local identity = eggIdentity(model)
	if identity then
		local shared = stealIdentities[identity]
		if type(shared) == "table" then
			return shared
		end
	end
	return nil
end

local function stealRecord(model)
	local record = findStealRecord(model)
	if type(record) == "table" then
		stealAttempts[model] = record
		return record
	end
	record = {
		count = 0,
		last = 0,
		cooldown = 0,
		completed = false,
		reason = nil,
	}
	stealAttempts[model] = record
	local identity = eggIdentity(model)
	if identity then
		stealIdentities[identity] = record
	end
	return record
end

local function canAttemptModel(model)
	if typeof(model) ~= "Instance" or model.Parent == nil then
		return false
	end
	local record = findStealRecord(model)
	if type(record) ~= "table" then
		return true
	end
	if record.completed == true or (record.count or 0) >= STEAL_ATTEMPT_LIMIT then
		return false
	end
	return os.clock() >= (record.cooldown or 0)
end

local function noteStealAttempt(model, reason, completed)
	if typeof(model) ~= "Instance" then
		return nil
	end
	local record = stealRecord(model)
	record.last = os.clock()
	if (record.count or 0) < 1 then
		record.count = 1
	end
	if completed == true then
		record.completed = true
		record.reason = nil
		record.cooldown = 0
		return record
	end
	record.reason = reason
	record.cooldown = os.clock() + STEAL_RETRY_WAIT
	return record
end

local function beginStealAttempt(model)
	local record = stealRecord(model)
	record.count = (record.count or 0) + 1
	record.last = os.clock()
	record.completed = false
	return record
end

local function resetStealScan()
	STATE.nextSteal = 0
	STATE.openedDay = nil
	STATE.streamedDay = nil
	STATE.triedKeys = {}
	clearStealAttempts()
	STATE.stealError = nil
	STATE.liftSteal = false
	STATE.stealGoal = nil
	activeGoal = nil
	STATE.stealTarget = nil
end

local function pendingDelivery()
	if STATE.holdingUnseenEgg() then
		return true
	end
	if STATE.placeHoldActive() then
		return false
	end
	return hasEggTool()
end

local function runStealTrip()
	if STATE.autoSteal ~= true or not featureReady("Auto Steal") then
		return
	end
	if pendingDelivery() then
		if os.clock() < (STATE.nextPlace or 0) then
			return nil
		end
		STATE.liftSteal = true
		deliverHeld()
		local deliverySucceeded = not pendingDelivery()
		backToBench()
		local previous = STATE.lastStealStatus
		local eggName = nil
		local attempt = nil
		if type(previous) == "table" then
			if type(previous.eggName) == "string" then
				eggName = previous.eggName
			end
			if type(previous.attempt) == "number" then
				attempt = previous.attempt
			end
		end
		if type(eggName) ~= "string" and type(STATE.stealTarget) == "string" then
			eggName = STATE.stealTarget
		end
		local status = {
			outcome = if deliverySucceeded then "Delivery succeeded" else "Pickup succeeded",
			eggName = eggName,
			attempt = attempt,
			failureReason = if deliverySucceeded then nil else "delivery pending",
			pickupSucceeded = true,
			deliverySucceeded = deliverySucceeded,
			timestamp = os.clock(),
		}
		STATE.lastStealStatus = status
		if deliverySucceeded then
			STATE.stealError = nil
			STATE.stealTarget = nil
			STATE.nextPlace = 0
		else
			STATE.stealError = "delivery pending"
			STATE.nextPlace = os.clock() + 8
		end
		return status
	end
	if os.clock() < (STATE.nextSteal or 0) then
		return
	end
	local dayId = ReplicatedStorage:GetAttribute("TimeOfDayEndsAt")
	if not stealDaytime() then
		STATE.liftSteal = false
		STATE.stealGoal = nil
		activeGoal = nil
		STATE.stealTarget = nil
		LocalPlayer:SetAttribute("CodexMode", "train")
		local waiting = {
			outcome = "Waiting for daytime",
			eggName = nil,
			attempt = nil,
			failureReason = nil,
			pickupSucceeded = false,
			deliverySucceeded = false,
			timestamp = os.clock(),
		}
		STATE.lastStealStatus = waiting
		return waiting
	end
	if STATE.triedDay ~= dayId then
		STATE.triedDay = dayId
		STATE.triedKeys = {}
		STATE.openedDay = nil
		STATE.streamedDay = nil
		clearStealAttempts()
	end
	local function finishSteal(fields)
		local status = {
			outcome = fields.outcome,
			eggName = fields.eggName,
			attempt = fields.attempt,
			failureReason = fields.failureReason,
			pickupSucceeded = fields.pickupSucceeded == true,
			deliverySucceeded = fields.deliverySucceeded == true,
			timestamp = os.clock(),
		}
		STATE.lastStealStatus = status
		if type(fields.failureReason) == "string" and fields.failureReason ~= "" then
			STATE.stealError = fields.failureReason
		elseif status.pickupSucceeded then
			STATE.stealError = nil
		end
		return status
	end
	local function retryOutcome(reason, count)
		if (count or 0) >= STEAL_ATTEMPT_LIMIT then
			return "Retry limit reached"
		end
		if reason == "arrival timeout" then
			return "Retrying after arrival timeout"
		end
		if type(reason) == "string" and reason ~= "" then
			return "Retrying after " .. reason
		end
		return "Retrying after pickup timeout"
	end
	local function failAttempt(model, eggName, reason)
		local record = noteStealAttempt(model, reason, false)
		local count = record and record.count or 1
		restoreStealChanges()
		backToBench()
		STATE.nextSteal = os.clock() + STEAL_RETRY_WAIT
		return finishSteal({
			outcome = retryOutcome(reason, count),
			eggName = eggName,
			attempt = count,
			failureReason = reason,
			pickupSucceeded = false,
			deliverySucceeded = false,
		})
	end
	local function freshTarget()
		for _, egg in ipairs(prehistoricEggs()) do
			if canAttemptModel(egg.model) then
				return egg
			end
		end
		return nil
	end
	local function blockedTarget()
		local sawLimit = false
		local sawCooldown = false
		for _, egg in ipairs(prehistoricEggs()) do
			local record = findStealRecord(egg.model)
			if type(record) == "table" and record.completed ~= true then
				if (record.count or 0) >= STEAL_ATTEMPT_LIMIT then
					sawLimit = true
				elseif os.clock() < (record.cooldown or 0) then
					sawCooldown = true
				end
			end
		end
		if sawCooldown then
			return "cooldown"
		end
		if sawLimit then
			return "limit"
		end
		return nil
	end
	local target = freshTarget()
	if not target and STATE.streamedDay ~= dayId then
		STATE.streamedDay = dayId
		local peeked = peekPrehistoric()
		if peeked and canAttemptModel(peeked.model) then
			target = peeked
		end
	end
	if not target then
		local blocked = blockedTarget()
		STATE.liftSteal = false
		STATE.stealGoal = nil
		activeGoal = nil
		STATE.stealTarget = nil
		LocalPlayer:SetAttribute("CodexMode", "train")
		if blocked == "cooldown" then
			return nil
		end
		local previous = STATE.lastStealStatus
		if type(previous) == "table" then
			if previous.outcome == "Pickup succeeded" or previous.outcome == "Delivery succeeded" or previous.outcome == "Retry limit reached" then
				return nil
			end
		end
		if blocked == "limit" then
			return finishSteal({
				outcome = "Retry limit reached",
				failureReason = "retry limit reached",
				pickupSucceeded = false,
				deliverySucceeded = false,
			})
		end
		return finishSteal({
			outcome = "No matching eggs",
			pickupSucceeded = false,
			deliverySucceeded = false,
		})
	end
	local stolenName = target.label or target.model.Name
	STATE.stealTarget = stolenName
	local started = beginStealAttempt(target.model)
	finishSteal({
		outcome = "Preparing to grab",
		eggName = stolenName,
		attempt = started.count,
		pickupSucceeded = false,
		deliverySucceeded = false,
	})
	if not standOutFront() then
		return failAttempt(target.model, stolenName, "bench exit")
	end
	if not target.model.Parent then
		restoreStealChanges()
		backToBench()
		STATE.nextSteal = os.clock() + 2
		return finishSteal({
			outcome = "No matching eggs",
			eggName = stolenName,
			failureReason = "gone",
			pickupSucceeded = false,
			deliverySucceeded = false,
		})
	end
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return failAttempt(target.model, stolenName, "missing character")
	end
	LocalPlayer:SetAttribute("CodexMode", "steal")
	homeSpot()
	local grabbed = false
	local arrived = false
	local tripFault = nil
	local tripOk, tripErr = pcall(function()
		local gym = myGym()
		local bench = gym and gym:FindFirstChild("Bench")
		local seat = bench and bench:FindFirstChild("Seat")
		if seat and seat:IsA("Seat") then
			rememberSteal(seat, "Disabled")
			seat.Disabled = true
		end
		local releaseLimit = os.clock() + 1.5
		while not releaseGym() and os.clock() < releaseLimit and running() and STATE.autoSteal == true do
			task.wait(0.05)
		end
		if LocalPlayer:GetAttribute("Benching") or not running() or STATE.autoSteal ~= true then
			tripFault = "bench exit"
			return
		end
		local tripCharacter = LocalPlayer.Character
		local tripRoot = tripCharacter and tripCharacter:FindFirstChild("HumanoidRootPart")
		local humanoid = tripCharacter and tripCharacter:FindFirstChildOfClass("Humanoid")
		if not tripRoot then
			tripFault = "missing character"
			return
		end
		if not target.model.Parent then
			tripFault = "gone"
			return
		end
		if not target.prompt or not target.prompt.Parent then
			tripFault = "prompt failure"
			return
		end
		rememberSteal(target.prompt, "HoldDuration")
		rememberSteal(target.prompt, "RequiresLineOfSight")
		rememberSteal(target.prompt, "MaxActivationDistance")
		target.prompt.HoldDuration = 0
		target.prompt.RequiresLineOfSight = false
		if target.prompt.MaxActivationDistance < 30 then
			target.prompt.MaxActivationDistance = 30
		end
		for _, part in ipairs(target.model:GetDescendants()) do
			if part:IsA("BasePart") then
				rememberSteal(part, "CanCollide")
				part.CanCollide = false
			end
		end
		if humanoid then
			humanoid.PlatformStand = false
			humanoid.Sit = false
		end
		local stand = target.model:GetPivot().Position + Vector3.new(0, 4, 0)
		local goal = CFrame.new(stand)
		activeGoal = goal
		STATE.stealGoal = goal
		pinGoal(tripRoot, goal)
		local arriveUntil = os.clock() + 1.5
		while os.clock() < arriveUntil and running() and STATE.autoSteal == true and target.model.Parent do
			pinGoal(tripRoot, goal)
			if (tripRoot.Position - stand).Magnitude < 18 then
				arrived = true
				break
			end
			task.wait(0.05)
		end
		if not target.model.Parent then
			tripFault = "gone"
			return
		end
		if not arrived then
			tripFault = "arrival timeout"
			return
		end
		local grabUntil = os.clock() + 2
		while os.clock() < grabUntil and running() and STATE.autoSteal == true and target.prompt.Parent do
			pinGoal(tripRoot, goal)
			fireproximityprompt(target.prompt)
			if LocalPlayer:GetAttribute("holdingFriend") == true then
				grabbed = true
				break
			end
			task.wait(0.1)
		end
		grabbed = grabbed or LocalPlayer:GetAttribute("holdingFriend") == true
		if not grabbed then
			tripFault = "pickup timeout"
		end
	end)
	restoreStealChanges()
	if not tripOk then
		grabbed = false
		tripFault = "script error"
		warn("[Zinoos hub] steal " .. tostring(tripErr))
	end
	local carryingEgg = LocalPlayer:GetAttribute("holdingFriend") == true
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("isEgg") then
				carryingEgg = true
				break
			end
		end
	end
	local pickupSucceeded = grabbed or carryingEgg
	local deliverySucceeded = false
	if pickupSucceeded then
		deliverHeld()
		deliverySucceeded = LocalPlayer:GetAttribute("holdingFriend") ~= true and not hasEggTool()
		noteStealAttempt(target.model, nil, true)
	elseif tripFault == "gone" then
		restoreStealChanges()
		backToBench()
		LocalPlayer:SetAttribute("CodexMode", "train")
		LocalPlayer:SetAttribute("CodexStolen", 0)
		LocalPlayer:SetAttribute("CodexStealName", stolenName)
		STATE.nextSteal = os.clock() + 2
		return finishSteal({
			outcome = "No matching eggs",
			eggName = stolenName,
			failureReason = "gone",
			pickupSucceeded = false,
			deliverySucceeded = false,
		})
	else
		return failAttempt(target.model, stolenName, tripFault or "pickup timeout")
	end
	LocalPlayer:SetAttribute("CodexMode", "train")
	LocalPlayer:SetAttribute("CodexStolen", pickupSucceeded and 1 or 0)
	LocalPlayer:SetAttribute("CodexStealName", stolenName)
	if pickupSucceeded and queueRare then
		queueRare("Stolen egg", stolenName)
	end
	backToBench()
	STATE.stealTarget = nil
	STATE.nextSteal = os.clock() + (pickupSucceeded and 12 or STEAL_RETRY_WAIT)
	local attemptCount = stealRecord(target.model).count
	return finishSteal({
		outcome = deliverySucceeded and "Delivery succeeded" or "Pickup succeeded",
		eggName = stolenName,
		attempt = attemptCount,
		pickupSucceeded = true,
		deliverySucceeded = deliverySucceeded,
	})
end

local savedPadTouch = setmetatable({}, { __mode = "k" })
local function restorePurchasePads()
	for trigger, value in pairs(savedPadTouch) do
		savedPadTouch[trigger] = nil
		if typeof(trigger) == "Instance" and trigger.Parent and trigger:IsA("BasePart") then
			local part = trigger
			part.CanTouch = value
		end
	end
end
hubCleanup(restorePurchasePads)

local function dismissPurchase()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local confirm = playerGui and playerGui:FindFirstChild("PurchaseConfirmation")
	if confirm and confirm.Enabled then
		local decline = confirm:FindFirstChild("Decline", true)
		if decline then
			local ok, connections = pcall(getconnections, decline.MouseButton1Click)
			if ok and connections then
				for _, connection in ipairs(connections) do
					if connection.Function then
						pcall(connection.Function)
					end
				end
			end
		end
		local ui = ClientRegistry.TryGet("UIController")
		if ui then
			pcall(function()
				ui:Close("PurchaseConfirmation")
			end)
		end
		confirm.Enabled = false
	end
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local pad = plot:FindFirstChild("FarmUpgradePad")
		local trigger = pad and pad:FindFirstChild("TriggerPart", true)
		if trigger and trigger:IsA("BasePart") then
			if savedPadTouch[trigger] == nil then
				savedPadTouch[trigger] = trigger.CanTouch
			end
			trigger.CanTouch = false
		end
	end
end

local function stepDaily()
	if STATE.autoDaily ~= true or not featureReady("Auto Daily") then
		return
	end
	if os.clock() < (STATE.nextDaily or 0) then
		return
	end
	local data = readData()
	local daily = data and data.daily
	if type(daily) ~= "table" then
		return
	end
	if (daily.nextAt or 0) > os.time() then
		return
	end
	local claimed = daily.claimed or {}
	local count = 0
	for _ in pairs(claimed) do
		count += 1
	end
	local day = count + 1
	if day > (DailyRewards.CycleDays or 7) then
		return
	end
	if type(day) ~= "number" or claimed[tostring(day)] == true or claimed[day] == true then
		return
	end
	STATE.nextDaily = os.clock() + 8
	Net:FireServer("ClaimDailyReward", day)
end

local function hasPendingIndex(rewards)
	if type(rewards) ~= "table" then
		return false
	end
	for _, group in pairs(rewards) do
		if type(group) == "table" then
			for _, status in pairs(group) do
				if status == "pending" then
					return true
				end
			end
		end
	end
	return false
end

local function stepIndex()
	if STATE.autoIndex ~= true or not featureReady("Auto Index") then
		return
	end
	if os.clock() < (STATE.nextIndex or 0) then
		return
	end
	local data = readData()
	if not hasPendingIndex(data and data.indexRewards) then
		return
	end
	STATE.nextIndex = os.clock() + 10
	pcall(function()
		Net:InvokeServer("ClaimAllIndexRewards")
	end)
end

local function stepStash()
	if STATE.freeStash ~= true or not featureReady("Free Stash") then
		return
	end
	local cards = STATE.stashCards
	if type(cards) ~= "table" then
		return
	end
	if os.clock() < (STATE.nextStash or 0) then
		return
	end
	local taken = STATE.stashTaken or {}
	local index = nil
	for cardIndex = 1, #cards do
		if not taken[cardIndex] then
			index = cardIndex
			break
		end
	end
	if not index then
		return
	end
	local card = cards[index]
	if type(card) ~= "table" or card.paid == true then
		return
	end
	if type(index) ~= "number" then
		return
	end
	STATE.nextStash = os.clock() + 0.6
	Net:FireServer("ClaimStashCard", index)
end

local function popFreeBubbles()
	if STATE.autoTrain ~= true then
		return
	end
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local folder = playerGui and playerGui:FindFirstChild("TrainingBubbles")
	if not folder then
		return
	end
	for _, bubble in ipairs(folder:GetChildren()) do
		if bubble:IsA("GuiButton") and bubble.Name == "TrainingBubble" and bubble.Active and not popped[bubble] then
			local gradient = bubble:FindFirstChildOfClass("UIGradient")
			local keypoints = gradient and gradient.Color.Keypoints
			if keypoints and #keypoints <= 2 then
				popped[bubble] = true
				local ok, connections = pcall(getconnections, bubble.Activated)
				if ok and connections then
					for _, connection in ipairs(connections) do
						if connection.Function then
							pcall(connection.Function)
						end
					end
				end
			end
		end
	end
end

local eggValue = {}
if typeof(Pets) == "table" and typeof(Pets.Specs) == "table" then
	for _, spec in pairs(Pets.Specs) do
		if type(spec) == "table" and type(spec.DisplayName) == "string" and type(spec.Income) == "number" and not spec.IsEgg then
			eggValue[spec.DisplayName] = spec.Income
			eggValue[spec.DisplayName .. " Egg"] = spec.Income
		end
	end
end

local function eggValueText(model)
	local income = eggValue[model.Name]
	if not income then
		income = eggValue[string.gsub(model.Name, " Egg$", "")]
	end
	if not income then
		return model.Name
	end
	return model.Name .. "  $" .. shortNumber(income) .. "/s"
end

local webhookHosts = {
	["discord.com"] = true,
	["discordapp.com"] = true,
	["canary.discord.com"] = true,
	["ptb.discord.com"] = true,
}

function STATE.parseWebhook(raw)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	if string.find(raw, "%s") or string.find(raw, "@", 1, true) or string.find(raw, "?", 1, true) or string.find(raw, "#", 1, true) or string.find(raw, "%%") then
		return nil
	end
	local host, id, token = string.match(raw, "^https://([^/]+)/api/webhooks/([^/]+)/([^/]+)$")
	if type(host) ~= "string" or type(id) ~= "string" or type(token) ~= "string" then
		return nil
	end
	host = string.lower(host)
	if string.find(host, ":", 1, true) or string.find(host, "@", 1, true) or not webhookHosts[host] then
		return nil
	end
	if not string.match(id, "^%d+$") or id == "" then
		return nil
	end
	if not string.match(token, "^[%w_%-]+$") or token == "" then
		return nil
	end
	return "https://" .. host .. "/api/webhooks/" .. id .. "/" .. token
end

STATE.webhookParserTests = {
	{ url = "https://discord.com/api/webhooks/123456789012345678/abcDEF_123-token", accept = "https://discord.com/api/webhooks/123456789012345678/abcDEF_123-token" },
	{ url = "https://discordapp.com/api/webhooks/42/tok", accept = "https://discordapp.com/api/webhooks/42/tok" },
	{ url = "https://canary.discord.com/api/webhooks/7/Ab", accept = "https://canary.discord.com/api/webhooks/7/Ab" },
	{ url = "https://ptb.discord.com/api/webhooks/9/Zz", accept = "https://ptb.discord.com/api/webhooks/9/Zz" },
	{ url = "https://user:pass@discord.com/api/webhooks/1/tok", accept = false },
	{ url = "https://discord.com:443@evil.example/api/webhooks/1/tok", accept = false },
	{ url = "https://discord.com/api/webhooks/1/tok?wait=true", accept = false },
	{ url = "https://discord.com/api/webhooks/1/tok#frag", accept = false },
	{ url = "https://discord.com/api/webhooks/1/tok%2Fextra", accept = false },
	{ url = "https://discord.com:443/api/webhooks/1/tok", accept = false },
	{ url = "https://discord.com:/api/webhooks/1/tok", accept = false },
	{ url = "https://discord.com:abc/api/webhooks/1/tok", accept = false },
	{ url = "https://discord.com/api/webhooks/1/tok with space", accept = false },
	{ url = "https://discord.com.evil.example/api/webhooks/1/tok", accept = false },
	{ url = "https://evildiscord.com/api/webhooks/1/tok", accept = false },
	{ url = "https://not.discord.com/api/webhooks/1/tok", accept = false },
	{ url = "http://discord.com/api/webhooks/1/tok", accept = false },
	{ url = "https://discord.com/api/webhooks//tok", accept = false },
	{ url = "https://discord.com/api/webhooks/1/", accept = false },
	{ url = "https://discord.com/api/webhooks/1/tok/extra", accept = false },
	{ url = "https://www.discord.com/api/webhooks/1/tok", accept = false },
}

function STATE.runWebhookParserTests()
	local failed = {}
	for index, case in ipairs(STATE.webhookParserTests) do
		local got = STATE.parseWebhook(case.url)
		local want = case.accept
		local ok = (want == false and got == nil) or got == want
		if not ok then
			failed[#failed + 1] = index
		end
	end
	return #failed == 0, failed
end

local function webhookUrl()
	return STATE.parseWebhook(type(STATE.webhook) == "string" and STATE.webhook or "")
end

local function webhookRequest()
	if typeof(request) == "function" then
		return request
	end
	return nil
end

local requestWarned = false
local function sendWebhook(url, payload)
	local requester = webhookRequest()
	if not requester then
		if not requestWarned then
			requestWarned = true
			warn("[Zinoos hub] Webhook request is not available.")
		end
		return false, "Request is not available."
	end
	local okEncode, body = pcall(function()
		return game:GetService("HttpService"):JSONEncode(payload)
	end)
	if not okEncode then
		return false, "Could not build the message."
	end
	local ok, result = pcall(requester, {
		Url = url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = body,
	})
	if not ok then
		return false, "The request failed."
	end
	local code = nil
	if type(result) == "table" then
		code = result.StatusCode or result.Status or result.statusCode or result.status_code
	elseif type(result) == "number" then
		code = result
	end
	if type(code) == "number" and code >= 200 and code < 300 then
		return true, "Webhook sent."
	end
	return false, "Webhook failed."
end

queueRare = function(kind, name, money, mark)
	if STATE.webhookOn == false or STATE._unloaded then
		return false
	end
	local url = webhookUrl()
	if not url then
		return false
	end
	local clean = string.gsub(tostring(name), " Egg$", "")
	local rarity = rarityByDisplay[clean] or ""
	if not STATE.raritySelected(STATE.alertRarities, rarityRank[rarity]) then
		return false
	end
	if not webhookRequest() then
		if not requestWarned then
			requestWarned = true
			warn("[Zinoos hub] Webhook request is not available.")
		end
		return false
	end
	if type(money) ~= "string" or money == "" then
		if typeof(Pets) == "table" and typeof(Pets.Specs) == "table" then
			for _, spec in pairs(Pets.Specs) do
				if type(spec) == "table" and spec.DisplayName == clean and type(spec.Income) == "number" then
					money = "$" .. shortNumber(spec.Income) .. "/s"
					break
				end
			end
		else
			warnDisplayOnce("Pet display", "Pets.Specs")
		end
	end
	local stamp = mark or (kind .. "|" .. clean .. "|" .. rarity)
	local now = os.clock()
	if STATE._hookStamp == stamp and now - (STATE._hookAt or 0) < 12 then
		return false
	end
	STATE._hookStamp = stamp
	STATE._hookAt = now
	task.spawn(function()
		if STATE._unloaded or not running() then
			return
		end
		local sent, reason = sendWebhook(url, {
			username = "Zinoos hub",
			embeds = {
				{
					title = kind,
					description = string.format("**%s**\n%s\n%s", clean, rarity, money or ""),
					color = 16098851,
				},
			},
		})
		if STATE.noteFault then
			STATE.noteFault("Webhook Alerts", sent == true, reason)
		end
	end)
	return true
end

function STATE.liteId(inst)
	if typeof(inst) ~= "Instance" then
		return nil
	end
	local ok, id = pcall(function()
		return inst:GetDebugId()
	end)
	if ok and type(id) == "string" and id ~= "" then
		return id
	end
	local marked = inst:GetAttribute("ZinoosWatch")
	if type(marked) == "string" and marked ~= "" then
		return marked
	end
	STATE._liteSeq = (STATE._liteSeq or 0) + 1
	local fresh = "z" .. tostring(STATE._gen or 0) .. "-" .. tostring(STATE._liteSeq)
	inst:SetAttribute("ZinoosWatch", fresh)
	return fresh
end

function STATE.ensureLiteGen()
	if STATE._liteGen == STATE._gen and type(STATE._liteOwned) == "table" and type(STATE._liteRoots) == "table" then
		return
	end
	STATE._liteOwned = {}
	STATE._liteRoots = {}
	STATE._liteGen = STATE._gen
end

function STATE.releaseLiteId(id)
	local owned = STATE._liteOwned
	if type(id) ~= "string" or type(owned) ~= "table" then
		return
	end
	local connection = owned[id]
	owned[id] = nil
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
	end
end

function STATE.releaseLiteWatch()
	local owned = STATE._liteOwned
	if type(owned) == "table" then
		for id, connection in pairs(owned) do
			owned[id] = nil
			if connection then
				pcall(function()
					connection:Disconnect()
				end)
			end
		end
	end
	local roots = STATE._liteRoots
	if type(roots) == "table" then
		for id, pair in pairs(roots) do
			roots[id] = nil
			if type(pair) == "table" then
				for _, connection in ipairs(pair) do
					pcall(function()
						connection:Disconnect()
					end)
				end
			end
		end
	end
	STATE._liteOwned = {}
	STATE._liteRoots = {}
	STATE._liteGen = STATE._gen
end

function STATE.hideLitePart(child)
	if typeof(child) ~= "Instance" then
		return
	end
	if child:IsA("BasePart") then
		if child.LocalTransparencyModifier ~= 1 then
			child.LocalTransparencyModifier = 1
		end
		STATE.ensureLiteGen()
		local id = STATE.liteId(child)
		if type(id) == "string" and STATE._liteOwned[id] == nil then
			local connection = STATE.connect(child:GetPropertyChangedSignal("LocalTransparencyModifier"), function()
				if running() and STATE.litePets == true and child.Parent and child.LocalTransparencyModifier ~= 1 then
					child.LocalTransparencyModifier = 1
				end
			end)
			if connection then
				if STATE._liteOwned[id] == nil then
					STATE._liteOwned[id] = connection
				else
					pcall(function()
						connection:Disconnect()
					end)
				end
			end
		end
		if child.CastShadow then
			child:SetAttribute("ZinoosShadow", true)
			child.CastShadow = false
		end
	elseif child:IsA("ParticleEmitter") then
		if child.Enabled then
			child:SetAttribute("ZinoosHid", true)
			child.Enabled = false
		end
	elseif child:IsA("Trail") then
		if child.Enabled then
			child:SetAttribute("ZinoosHid", true)
			child.Enabled = false
		end
	elseif child:IsA("Beam") then
		if child.Enabled then
			child:SetAttribute("ZinoosHid", true)
			child.Enabled = false
		end
	elseif child:IsA("Light") then
		if child.Enabled then
			child:SetAttribute("ZinoosHid", true)
			child.Enabled = false
		end
	elseif child:IsA("Highlight") then
		if child.Enabled then
			child:SetAttribute("ZinoosHid", true)
			child.Enabled = false
		end
	end
end

function STATE.hideLiteModel(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	if model:GetAttribute("ZinoosLite") ~= true then
		local animator = model:FindFirstChildWhichIsA("Animator", true)
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop()
			end
		end
		model:SetAttribute("ZinoosLite", true)
	end
	for _, child in ipairs(model:GetDescendants()) do
		STATE.hideLitePart(child)
	end
	STATE.ensureLiteGen()
	local id = STATE.liteId(model)
	if type(id) ~= "string" or STATE._liteOwned[id] ~= nil then
		return
	end
	local connection = STATE.connect(model.DescendantAdded, function(child)
		if running() and STATE.litePets == true then
			STATE.hideLitePart(child)
		end
	end)
	if connection then
		if STATE._liteOwned[id] == nil then
			STATE._liteOwned[id] = connection
		else
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
end

function STATE.watchLiteRoot(root)
	if typeof(root) ~= "Instance" or STATE.litePets ~= true then
		return
	end
	STATE.ensureLiteGen()
	local id = STATE.liteId(root)
	if type(id) ~= "string" or STATE._liteRoots[id] ~= nil then
		return
	end
	local added = STATE.connect(root.DescendantAdded, function(inst)
		if running() and STATE.litePets == true and inst:IsA("Model") then
			STATE.hideLiteModel(inst)
		end
	end)
	local removing = STATE.connect(root.DescendantRemoving, function(inst)
		STATE.releaseLiteId(STATE.liteId(inst))
	end)
	if STATE._liteRoots[id] == nil then
		STATE._liteRoots[id] = { added, removing }
	end
end

local function hideOne(child)
	STATE.hideLitePart(child)
end

local function hideVisual(model)
	STATE.hideLiteModel(model)
end

local function showVisual(model)
	model:SetAttribute("ZinoosLite", nil)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.LocalTransparencyModifier = 0
			if child:GetAttribute("ZinoosShadow") == true then
				child.CastShadow = true
				child:SetAttribute("ZinoosShadow", nil)
			end
		elseif (child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam") or child:IsA("Light") or child:IsA("Highlight")) and child:GetAttribute("ZinoosHid") == true then
			child.Enabled = true
			child:SetAttribute("ZinoosHid", nil)
		end
	end
end

local function ensureEggTag(model)
	local existing = model:FindFirstChild("ZinoosEggValue")
	if existing then
		return existing
	end
	local adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not adornee then
		return nil
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZinoosEggValue"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 280
	billboard.Size = UDim2.fromOffset(180, 28)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.TextStrokeTransparency = 0.35
	label.Parent = billboard
	billboard.Parent = model
	return billboard
end

local function stepView()
	local live = workspace:FindFirstChild("Live")
	if not live then
		return
	end
	local friends = live:FindFirstChild("Friends")
	local owned = live:FindFirstChild("PlayerFriends")
	local lite = STATE.litePets == true
	local function eachPlaced(callback)
		if not owned then
			return
		end
		for _, folder in ipairs(owned:GetChildren()) do
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") then
					callback(model)
				end
			end
		end
	end
	if lite then
		STATE.watchLiteRoot(owned)
		STATE.watchLiteRoot(friends)
		eachPlaced(hideVisual)
		if friends then
			for _, model in ipairs(friends:GetChildren()) do
				if model:IsA("Model") then
					hideVisual(model)
				end
			end
		end
	elseif STATE._liteWasOn == true then
		STATE.releaseLiteWatch()
		eachPlaced(showVisual)
		if friends then
			for _, model in ipairs(friends:GetChildren()) do
				if model:IsA("Model") then
					showVisual(model)
				end
			end
		end
	end
	STATE._liteWasOn = lite
	STATE.paintPlotEggs()
	if not friends then
		return
	end
	local zone = stealZone()
	for _, model in ipairs(friends:GetChildren()) do
		if model:IsA("Model") then
			local show = STATE.eggEsp == true and model:GetAttribute("SpawnZone") == zone
			local tag = model:FindFirstChild("ZinoosEggValue")
			if show then
				local pos = model:GetPivot().Position
				if inZone(pos, zone) then
					tag = tag or ensureEggTag(model)
					local label = tag and tag:FindFirstChild("Value")
					if label then
						local text = eggValueText(model)
						if label.Text ~= text then
							label.Text = text
						end
					end
					if tag then
						local dist = STATE.lowEnd == true and 150 or 280
						if tag.MaxDistance ~= dist then
							tag.MaxDistance = dist
						end
					end
				elseif tag then
					tag:Destroy()
				end
			elseif tag then
				tag:Destroy()
			end
		end
	end
end

local function applyLowEnd(on)
	if not featureReady("Low End") then
		return
	end
	applyGraphics(captureBaseline(), on == true)
end

local phoneLayout = UserInputService.TouchEnabled
local invGui
local invLabel
local incomeByUid = {}

local function eventSig(pet)
	local extra = pet.eventMutations
	if type(extra) ~= "table" then
		return ""
	end
	local parts = {}
	for key, name in pairs(extra) do
		parts[#parts + 1] = tostring(key) .. "=" .. tostring(name)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function cashNow(data)
	local rebirths = data and data.rebirths or 0
	local row = typeof(Rebirths) == "table" and Rebirths[rebirths] or nil
	local cash = type(row) == "table" and row.CashMulti or 1
	if type(cash) ~= "number" then
		cash = 1
	end
	return cash
end

local function rememberPet(pet, cash)
	local uid = pet.uid
	if type(uid) ~= "string" then
		return 0
	end
	local spec = petSpec(pet.key)
	if pet.hatchAt ~= nil or (spec and spec.IsEgg) then
		incomeByUid[uid] = nil
		return 0
	end
	local sig = table.concat({
		tostring(pet.key),
		tostring(pet.mutation),
		eventSig(pet),
		tostring(pet.weight),
		tostring(pet.level),
		tostring(pet.grade),
		tostring(cash),
	}, "|")
	local cached = incomeByUid[uid]
	if cached and cached.sig == sig then
		return cached.amount
	end
	if typeof(Pets) ~= "table" or typeof(Pets.IncomeFor) ~= "function" then
		return 0
	end
	local ok, base = pcall(Pets.IncomeFor, pet)
	base = ok and type(base) == "number" and base or 0
	local level, grade = 1, 1
	if typeof(Plot) == "table" and typeof(Plot.PetLevelMultiplier) == "function" then
		pcall(function()
			level = Plot.PetLevelMultiplier(pet.level) or 1
		end)
	end
	if typeof(Grades) == "table" and typeof(Grades.Multiplier) == "function" then
		pcall(function()
			grade = Grades.Multiplier(pet.grade) or 1
		end)
	end
	local amount = base * level * grade * cash
	incomeByUid[uid] = {
		sig = sig,
		amount = amount,
		text = "$" .. shortNumber(amount) .. "/s",
	}
	return amount
end

local function destroyInvHuds(except)
	local function sweep(root)
		if not root then
			return
		end
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("ScreenGui") and child.Name == "ZinoosInvEsp" and child ~= except then
				child:Destroy()
			end
		end
	end
	sweep(CoreGui)
	sweep(CoreGui:FindFirstChild("RobloxGui"))
end

local function ensureInvGui()
	if invGui and invGui.Parent and invLabel and invLabel.Parent then
		destroyInvHuds(invGui)
		invGui.Enabled = true
		return invLabel
	end
	local existing = CoreGui:FindFirstChild("ZinoosInvEsp")
	if existing and existing:IsA("ScreenGui") then
		local total = existing:FindFirstChild("Total")
		if total and total:IsA("TextLabel") then
			invGui = existing
			invLabel = total
			destroyInvHuds(invGui)
			invGui.Enabled = true
			return invLabel
		end
	end
	destroyInvHuds(nil)
	invGui = Instance.new("ScreenGui")
	invGui.Name = "ZinoosInvEsp"
	invGui.ResetOnSpawn = false
	invGui.IgnoreGuiInset = false
	invGui.DisplayOrder = 40
	invLabel = Instance.new("TextLabel")
	invLabel.Name = "Total"
	invLabel.AnchorPoint = Vector2.new(0.5, 0)
	invLabel.Position = UDim2.new(0.5, 0, 0, 6)
	invLabel.Size = UDim2.fromOffset(phoneLayout and 168 or 200, phoneLayout and 22 or 26)
	invLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	invLabel.BackgroundTransparency = 0.4
	invLabel.BorderSizePixel = 0
	invLabel.Font = Enum.Font.GothamBold
	invLabel.TextSize = phoneLayout and 13 or 15
	invLabel.TextColor3 = Color3.fromRGB(130, 255, 150)
	invLabel.Text = "Bag"
	invLabel.Active = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = invLabel
	invLabel.Parent = invGui
	invGui.Parent = CoreGui
	return invLabel
end

local function wipeHold(container)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") then
			local handle = child:FindFirstChild("Handle") or child:FindFirstChildWhichIsA("BasePart")
			local tag = handle and handle:FindFirstChild("ZinoosHoldValue")
			if tag then
				tag:Destroy()
			end
		end
	end
end

local function wipeSlots(frame)
	if not frame then
		return
	end
	for _, child in ipairs(frame:GetDescendants()) do
		if child.Name == "ZinoosValue" then
			child:Destroy()
		end
	end
end

local function clearInvEsp()
	if invGui then
		invGui.Enabled = false
	end
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local backpackGui = playerGui and playerGui:FindFirstChild("BackpackGui")
	local root = backpackGui and backpackGui:FindFirstChild("Backpack")
	if root then
		wipeSlots(root:FindFirstChild("Hotbar"))
		wipeSlots(root:FindFirstChild("Inventory"))
	end
	wipeHold(LocalPlayer.Character)
	wipeHold(LocalPlayer:FindFirstChild("Backpack"))
end

local function slotLabel(slot)
	local label = slot:FindFirstChild("ZinoosValue")
	if label then
		return label
	end
	label = Instance.new("TextLabel")
	label.Name = "ZinoosValue"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -1)
	label.Size = UDim2.new(1, -4, 0, phoneLayout and 12 or 14)
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = phoneLayout and 10 or 11
	label.TextColor3 = Color3.fromRGB(130, 255, 150)
	label.TextStrokeTransparency = 0.45
	label.ZIndex = 8
	label.Active = false
	label.Parent = slot
	return label
end

local function eachSlot(frame, callback)
	if not frame then
		return
	end
	for _, child in ipairs(frame:GetDescendants()) do
		if child:IsA("GuiButton") and child:FindFirstChild("ToolName") then
			callback(child)
		end
	end
end

local function toolValueText(tool)
	if tool:GetAttribute("isEgg") == true then
		return eggValueText(tool)
	end
	local uid = tool:GetAttribute("petUID")
	local entry = type(uid) == "string" and incomeByUid[uid]
	return entry and entry.text or nil
end

local function paintHeld()
	local character = LocalPlayer.Character
	wipeHold(LocalPlayer:FindFirstChild("Backpack"))
	if not character then
		return
	end
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			local text = toolValueText(tool)
			local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
			if not (text and handle) then
				local old = handle and handle:FindFirstChild("ZinoosHoldValue")
				if old then
					old:Destroy()
				end
			else
				local board = handle:FindFirstChild("ZinoosHoldValue")
				if not board then
					board = Instance.new("BillboardGui")
					board.Name = "ZinoosHoldValue"
					board.AlwaysOnTop = true
					board.LightInfluence = 0
					board.Size = UDim2.fromOffset(phoneLayout and 140 or 160, 22)
					board.StudsOffset = Vector3.new(0, 3.5, 0)
					board.MaxDistance = STATE.lowEnd == true and 80 or 140
					local label = Instance.new("TextLabel")
					label.Name = "Value"
					label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
					label.BackgroundTransparency = 0.35
					label.BorderSizePixel = 0
					label.Font = Enum.Font.GothamBold
					label.TextColor3 = Color3.fromRGB(130, 255, 150)
					label.TextSize = phoneLayout and 13 or 14
					label.Size = UDim2.fromScale(1, 1)
					label.Parent = board
					board.Parent = handle
				end
				board.MaxDistance = STATE.lowEnd == true and 80 or 140
				local label = board:FindFirstChild("Value")
				if label and label.Text ~= text then
					label.Text = text
				end
			end
		end
	end
end

local function stepInventory()
	if not featureReady("Inventory ESP") or STATE.invEsp ~= true then
		if STATE._invShown then
			STATE._invShown = false
			clearInvEsp()
		end
		return
	end
	STATE._invShown = true
	local data = readData()
	local cash = cashNow(data)
	local seen = {}
	local total = 0
	local bag = data and data.backpack
	if type(bag) == "table" then
		for _, pet in pairs(bag) do
			if type(pet) == "table" and type(pet.uid) == "string" then
				seen[pet.uid] = true
				total += rememberPet(pet, cash)
			end
		end
	end
	for uid in pairs(incomeByUid) do
		if not seen[uid] then
			incomeByUid[uid] = nil
		end
	end
	local label = ensureInvGui()
	local text = "Bag  $" .. shortNumber(total) .. "/s"
	if label.Text ~= text then
		label.Text = text
	end
	local queues = {}
	local function addTools(container)
		if not container then
			return
		end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				local valueText = toolValueText(tool)
				if valueText then
					local queue = queues[tool.Name]
					if not queue then
						queue = {}
						queues[tool.Name] = queue
					end
					queue[#queue + 1] = valueText
				end
			end
		end
	end
	addTools(LocalPlayer:FindFirstChild("Backpack"))
	addTools(LocalPlayer.Character)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local backpackGui = playerGui and playerGui:FindFirstChild("BackpackGui")
	local root = backpackGui and backpackGui:FindFirstChild("Backpack")
	local function paint(frame)
		local remaining = {}
		for name, list in pairs(queues) do
			remaining[name] = table.clone(list)
		end
		local slots = {}
		eachSlot(frame, function(slot)
			slots[#slots + 1] = slot
		end)
		table.sort(slots, function(a, b)
			return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
		end)
		for _, slot in ipairs(slots) do
			local nameLabel = slot:FindFirstChild("ToolName")
			local queue = nameLabel and remaining[nameLabel.Text]
			local valueText = queue and table.remove(queue, 1)
			local valueLabel = slot:FindFirstChild("ZinoosValue")
			if valueText then
				valueLabel = valueLabel or slotLabel(slot)
				if valueLabel.Text ~= valueText then
					valueLabel.Text = valueText
				end
				valueLabel.Visible = true
			elseif valueLabel then
				valueLabel.Visible = false
			end
		end
	end
	if root then
		paint(root:FindFirstChild("Hotbar"))
		paint(root:FindFirstChild("Inventory"))
	end
	paintHeld()
end

applyLowEnd(STATE.lowEnd == true)
hubCleanup(function()
	clearInvEsp()
	if invGui then
		invGui:Destroy()
		invGui = nil
		invLabel = nil
	end
end)

local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/ZinoosHub.rfld"
local CONFIG_VERSION = 2

function STATE.configPath()
	local id = LocalPlayer.UserId
	if type(id) == "number" and id > 0 then
		return "Rayfield/Configurations/ZinoosHub/ZinoosHub_" .. tostring(id) .. ".rfld"
	end
	return CONFIG_PATH
end

local FLAG_KEYS = {
	AutoTrain = "autoTrain",
	AutoRebirth = "rebirth",
	AutoUpgrade = "upgrade",
	AutoTrails = "trails",
	AutoSteal = "autoSteal",
	AutoPlace = "autoPlace",
	AutoOpen = "autoOpen",
	EquipBest = "equipBest",
	AutoDaily = "autoDaily",
	AutoIndex = "autoIndex",
	FreeStash = "freeStash",
	LitePets = "litePets",
	EggEsp = "eggEsp",
	InvEsp = "invEsp",
	LowEnd = "lowEnd",
	WebhookAlerts = "webhookOn",
	AntiAfk = "antiAfk",
	PhoneGames = "phoneGames",
}

STATE.adminIds = {
	[9346336323] = true,
}
STATE.admin = STATE.adminIds[LocalPlayer.UserId] == true

STATE.defaultTheme = {
	blush = 1,
	Kind = "theme",
	Name = "AstaTheme",
	Theme = {
		Colors = {
			Panel = "151110",
			Text = "f2ece8",
			Element = "000000",
			Risky = "ffffff",
			Outline = "000000",
			Hover = "000000",
			Background = "000000",
			DimText = "ffffff",
			Accent = "fff1e9",
		},
		Glow = false,
		ElementGlow = true,
		CardOpacity = 0.66,
		Wallpaper = {
			Image = "https://ysoyjfnigavjajrjftmv.supabase.co/storage/v1/object/public/theme-images/8239b4cd-652e-4ebf-a692-6a796f1bc0c6.jpg",
			Transparency = 0.17,
		},
		Icon = "https://ysoyjfnigavjajrjftmv.supabase.co/storage/v1/object/public/theme-images/63c9defa-4d08-4112-bbfe-d981407516df.jpg",
	},
}

function STATE.themeColor(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "number" then
		local channel = math.clamp(math.floor(value), 0, 255)
		return Color3.fromRGB(channel, channel, channel)
	end
	if type(value) == "table" then
		local r = value.r or value.R or value[1]
		local g = value.g or value.G or value[2]
		local b = value.b or value.B or value[3]
		if type(r) == "number" and type(g) == "number" and type(b) == "number" then
			if r <= 1 and g <= 1 and b <= 1 then
				return Color3.new(r, g, b)
			end
			return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
		end
	end
	if type(value) ~= "string" then
		return fallback
	end
	local trimmed = string.lower(string.match(value, "^%s*(.-)%s*$") or "")
	local hex = string.match(trimmed, "^#([%x]+)$") or string.match(trimmed, "^([%x]+)$")
	if not hex then
		hex = string.match(trimmed, "^0x([%x]+)$")
	end
	if type(hex) ~= "string" then
		return fallback
	end
	if #hex == 3 then
		hex = string.sub(hex, 1, 1) .. string.sub(hex, 1, 1) .. string.sub(hex, 2, 2) .. string.sub(hex, 2, 2) .. string.sub(hex, 3, 3) .. string.sub(hex, 3, 3)
	end
	if #hex ~= 6 then
		return fallback
	end
	local r = tonumber(string.sub(hex, 1, 2), 16)
	local g = tonumber(string.sub(hex, 3, 4), 16)
	local b = tonumber(string.sub(hex, 5, 6), 16)
	if not r or not g or not b then
		return fallback
	end
	return Color3.fromRGB(r, g, b)
end

function STATE.readTheme(raw)
	local source = raw
	if type(raw) == "string" then
		local text = string.match(raw, "^%s*(.-)%s*$") or ""
		if text == "" then
			return nil, nil, nil, "Paste a theme first."
		end
		local ok, decoded = pcall(function()
			return game:GetService("HttpService"):JSONDecode(text)
		end)
		if not ok or type(decoded) ~= "table" then
			return nil, nil, nil, "That is not a theme."
		end
		source = decoded
	end
	if type(source) ~= "table" then
		return nil, nil, nil, "That is not a theme."
	end
	local body = source
	local name = "Custom"
	if type(source.Name) == "string" and source.Name ~= "" then
		name = source.Name
	elseif type(source.name) == "string" and source.name ~= "" then
		name = source.name
	end
	if type(source.Theme) == "table" then
		body = source.Theme
	elseif type(source.theme) == "table" then
		body = source.theme
	end
	local colors = body.Colors or body.colors or body
	if type(colors) ~= "table" then
		return nil, nil, nil, "That theme has no colours."
	end
	local function pick(group, ...)
		if type(group) ~= "table" then
			return nil
		end
		for index = 1, select("#", ...) do
			local key = select(index, ...)
			if group[key] ~= nil then
				return group[key]
			end
		end
		return nil
	end
	local accent = STATE.themeColor(pick(colors, "Accent", "accent") or pick(body, "Accent", "accent"))
	local ink = STATE.themeColor(pick(colors, "Text", "text", "MainText") or pick(body, "Text", "text"))
	local panel = STATE.themeColor(pick(colors, "Background", "background") or pick(body, "Background", "background"))
	local side = STATE.themeColor(pick(colors, "Panel", "panel", "Sidebar") or pick(body, "Panel", "panel"), panel)
	local card = STATE.themeColor(pick(colors, "Element", "element", "Card") or pick(body, "Element", "element"), panel or side)
	if not accent and not ink and not panel and not side and not card then
		return nil, nil, nil, "That theme has no colours."
	end
	accent = accent or Color3.fromRGB(255, 241, 233)
	ink = ink or Color3.fromRGB(242, 236, 232)
	panel = panel or Color3.fromRGB(0, 0, 0)
	side = side or panel
	card = card or panel
	local muted = STATE.themeColor(pick(colors, "DimText", "dimText", "Muted", "SubText") or pick(body, "DimText", "dimText"), ink)
	if muted and card then
		local gap = math.abs(muted.R - card.R) + math.abs(muted.G - card.G) + math.abs(muted.B - card.B)
		if gap < 0.45 then
			muted = ink
		end
	end
	local hover = STATE.themeColor(pick(colors, "Hover", "hover") or pick(body, "Hover", "hover"), panel)
	local outline = STATE.themeColor(pick(colors, "Outline", "outline", "Stroke") or pick(body, "Outline", "outline"), accent)
	local risky = STATE.themeColor(pick(colors, "Risky", "risky") or pick(body, "Risky", "risky"), Color3.new(1, 1, 1))
	local opacity = pick(body, "CardOpacity", "cardOpacity", "Opacity")
	if type(opacity) ~= "number" then
		opacity = 1
	end
	opacity = math.clamp(opacity, 0.2, 1)
	local elementGlow = pick(body, "ElementGlow", "elementGlow")
	if elementGlow == nil then
		elementGlow = true
	end
	local wall = pick(body, "Wallpaper", "wallpaper", "BackgroundImage")
	local wallUrl = nil
	local wallFade = 0
	if type(wall) == "string" then
		wallUrl = wall
	elseif type(wall) == "table" then
		wallUrl = wall.Image or wall.image or wall.Url or wall.url
		wallFade = wall.Transparency or wall.transparency or wall.ImageTransparency or 0
	end
	if STATE.trustedThemeUrl(wallUrl) == nil then
		wallUrl = nil
	end
	if type(wallUrl) == "string" then
		opacity = math.max(opacity, 0.84)
	end
	if type(wallFade) ~= "number" then
		wallFade = 0
	end
	wallFade = math.clamp(wallFade, 0, 0.95)
	local iconValue = pick(body, "Icon", "icon", "Logo") or pick(source, "Icon", "icon")
	local iconUrl = nil
	if type(iconValue) == "string" then
		iconUrl = iconValue
	elseif type(iconValue) == "table" then
		iconUrl = iconValue.Image or iconValue.image or iconValue.Url or iconValue.url
	end
	if STATE.trustedThemeUrl(iconUrl) == nil then
		iconUrl = nil
	end
	local lightAccent = accent.R + accent.G + accent.B > 2.2
	local darkHover = hover.R + hover.G + hover.B < 0.45
	return {
		accent = accent,
		ink = ink,
		muted = muted,
		panel = panel,
		side = side,
		card = card,
		off = card,
		inkDark = lightAccent and side or ink,
		stroke = elementGlow and accent or outline,
		selected = accent,
		hover = hover,
		risky = risky,
		cardFade = 1 - opacity,
		strokeFade = elementGlow and 0.58 or 0.4,
		selectedFade = lightAccent and 0.78 or 0,
		hoverFade = darkHover and 0.4 or 0.15,
		barFade = 0.72,
		wallpaper = wallUrl ~= nil,
		icon = iconUrl ~= nil,
		wallFade = wallFade,
		wallUrl = wallUrl,
		iconUrl = iconUrl,
		glow = pick(body, "Glow", "glow") == true,
		name = name,
	}, name, source, nil
end

function STATE.hubThemeDef()
	if type(STATE.hubThemeLook) == "table" and typeof(STATE.hubThemeLook.accent) == "Color3" then
		return STATE.hubThemeLook
	end
	local look = STATE.readTheme(STATE.defaultTheme)
	if type(look) == "table" then
		STATE.hubThemeLook = look
		return look
	end
	return {
		accent = Color3.fromRGB(255, 241, 233),
		ink = Color3.fromRGB(242, 236, 232),
		muted = Color3.fromRGB(255, 255, 255),
		panel = Color3.fromRGB(0, 0, 0),
		side = Color3.fromRGB(21, 17, 16),
		card = Color3.fromRGB(0, 0, 0),
		off = Color3.fromRGB(0, 0, 0),
		inkDark = Color3.fromRGB(21, 17, 16),
		stroke = Color3.fromRGB(255, 241, 233),
		selected = Color3.fromRGB(255, 241, 233),
		hover = Color3.fromRGB(0, 0, 0),
		risky = Color3.new(1, 1, 1),
		cardFade = 0.34,
		strokeFade = 0.58,
		selectedFade = 0.78,
		hoverFade = 0.4,
		barFade = 0.72,
		wallpaper = false,
		icon = false,
		wallFade = 1,
	}
end

function STATE.useTheme(raw)
	local look, name, source, err = STATE.readTheme(raw)
	if type(look) ~= "table" then
		return nil, err or "That is not a theme."
	end
	STATE.hubThemeLook = look
	STATE.themeName = name or look.name or "Custom"
	STATE.themeSource = source
	STATE.themeIcon = nil
	STATE.themeWall = nil
	if STATE.writeConfig then
		STATE.writeConfig()
	end
	if STATE.applyLook then
		STATE.applyLook()
	end
	task.spawn(function()
		if STATE.loadThemeImages then
			STATE.loadThemeImages()
		end
	end)
	return look
end

local function syncSavedVisuals()
	applyLowEnd(STATE.lowEnd == true)
	if STATE.litePets == true then
		STATE._liteWasOn = true
	elseif STATE._liteWasOn == true then
		showLiteModels()
		STATE._liteWasOn = false
	else
		STATE._liteWasOn = false
	end
end

local function loadSaved()
	local function useFreshZone()
		STATE.stealZone = "Meadow"
		STATE.stealZoneExplicit = false
		syncSavedVisuals()
		return false
	end
	local path = CONFIG_PATH
	if typeof(isfile) == "function" and isfile(STATE.configPath()) then
		path = STATE.configPath()
	end
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" or not isfile(path) then
		return useFreshZone()
	end
	local ok, saved = pcall(function()
		return game:GetService("HttpService"):JSONDecode(readfile(path))
	end)
	if not ok or type(saved) ~= "table" then
		return useFreshZone()
	end
	for flag, key in pairs(FLAG_KEYS) do
		if type(saved[flag]) == "boolean" then
			STATE[key] = saved[flag]
		end
	end
	STATE.autoSell = false
	local zone = saved.StealZone
	if type(zone) == "table" then
		zone = zone[1]
	end
	local zoneValid = type(zone) == "string" and FLOORS[zone] ~= nil
	local rarity = saved.WebhookRarity
	if type(rarity) == "table" then
		rarity = rarity[1]
	end
	if type(rarity) == "string" and rarityRank[rarity] then
		STATE.webhookRarity = rarity
	end
	local alertList = STATE.normalizeRarities(saved.WebhookRarities)
	if #alertList > 0 then
		STATE.alertRarities = alertList
	elseif type(rarity) == "string" and rarityRank[rarity] then
		STATE.alertRarities = STATE.expandRarity(rarity)
	end
	STATE.webhookRarity = STATE.alertRarities[1] or STATE.webhookRarity
	local placeRarity = saved.PlaceRarity
	if type(placeRarity) == "table" then
		placeRarity = placeRarity[1]
	end
	if type(placeRarity) == "string" and rarityRank[placeRarity] then
		STATE.placeRarity = placeRarity
	end
	local placeList = STATE.normalizeRarities(saved.PlaceRarities)
	if #placeList > 0 then
		STATE.placeRarities = placeList
	elseif type(placeRarity) == "string" and rarityRank[placeRarity] then
		STATE.placeRarities = STATE.expandRarity(placeRarity)
	end
	STATE.placeRarity = STATE.placeRarities[1] or STATE.placeRarity
	STATE.placementPriority = STATE.placementChoice(saved.PlacementPriority)
	local savedPhone = saved.PhoneGame
	if type(savedPhone) == "table" then
		savedPhone = savedPhone[1]
	end
	if savedPhone == "When Pigs Fly" or savedPhone == "Flappy" then
		STATE.phoneChoice = "When Pigs Fly"
	elseif savedPhone == "Snack Stack" or savedPhone == "Stack" then
		STATE.phoneChoice = "Snack Stack"
	elseif savedPhone == "Critter Merge" or savedPhone == "Merge" then
		STATE.phoneChoice = "Critter Merge"
	end
	if type(saved.WebhookUrl) == "string" then
		STATE.webhook = saved.WebhookUrl
	end
	if type(saved.ThemeData) == "table" then
		local look, name, source = STATE.readTheme(saved.ThemeData)
		if type(look) == "table" then
			STATE.hubThemeLook = look
			STATE.themeName = name or STATE.themeName
			STATE.themeSource = source
		end
	elseif type(saved.Theme) == "string" and saved.Theme ~= "" then
		STATE.themeName = saved.Theme
	end
	if type(saved.MenuX) == "number" then
		STATE.menuX = saved.MenuX
	end
	if type(saved.MenuY) == "number" then
		STATE.menuY = saved.MenuY
	end
	if type(saved.DockX) == "number" then
		STATE.dockX = saved.DockX
	end
	if type(saved.DockY) == "number" then
		STATE.dockY = saved.DockY
	end
	STATE.dockCustom = saved.DockCustom == true
	local legacy = saved.ConfigVersion ~= CONFIG_VERSION and type(saved.StealZoneExplicit) ~= "boolean"
	local migrated = false
	if legacy then
		migrated = true
		if zoneValid and zone == "Prehistoric" then
			STATE.stealZone = "Meadow"
			STATE.stealZoneExplicit = false
		elseif zoneValid and zone ~= "Meadow" then
			STATE.stealZone = zone
			STATE.stealZoneExplicit = true
		else
			STATE.stealZone = "Meadow"
			STATE.stealZoneExplicit = false
		end
	elseif saved.StealZoneExplicit == true and zoneValid then
		STATE.stealZone = zone
		STATE.stealZoneExplicit = true
	else
		STATE.stealZone = "Meadow"
		STATE.stealZoneExplicit = false
	end
	syncSavedVisuals()
	return migrated
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
	local payload = {
		ConfigVersion = CONFIG_VERSION,
		StealZoneExplicit = STATE.stealZoneExplicit == true,
		AutoSell = false,
		StealZone = { STATE.stealZone or "Meadow" },
		WebhookRarity = { STATE.alertRarities[1] or STATE.webhookRarity or "Divine" },
		WebhookRarities = STATE.alertRarities,
		PlaceRarity = { STATE.placeRarities[1] or STATE.placeRarity or rarityOptions[1] or "Common" },
		PlaceRarities = STATE.placeRarities,
		PlacementPriority = STATE.placementChoice(STATE.placementPriority),
		PhoneGame = STATE.phoneChoice or "Critter Merge",
		WebhookUrl = type(STATE.webhook) == "string" and STATE.webhook or "",
		MenuX = STATE.menuX,
		MenuY = STATE.menuY,
		DockX = STATE.dockX,
		DockY = STATE.dockY,
		DockCustom = STATE.dockCustom == true,
		Theme = type(STATE.themeName) == "string" and STATE.themeName or "AstaTheme",
		ThemeData = type(STATE.themeSource) == "table" and STATE.themeSource or nil,
	}
	for flag, key in pairs(FLAG_KEYS) do
		payload[flag] = STATE[key] == true
	end
	local ok, encoded = pcall(function()
		return game:GetService("HttpService"):JSONEncode(payload)
	end)
	if ok then
		pcall(writefile, STATE.configPath(), encoded)
	end
end
STATE.writeConfig = saveConfig

function STATE.applyPlaceRarity(option)
	if type(option) ~= "string" or rarityRank[option] == nil then
		return
	end
	local ordered = STATE.toggleRarity(STATE.placeRarities, option)
	STATE.placeRarities = ordered
	STATE.placeRarity = ordered[1] or STATE.placeRarity
	if type(STATE.placeControl) ~= "table" then
		STATE.placeControl = {}
	end
	STATE.placeControl.value = ordered[1]
	STATE.placeControl.currentOption = ordered
	if typeof(STATE._setPlaceText) == "function" then
		pcall(STATE._setPlaceText, STATE.rarityLabel(ordered))
	end
	saveConfig()
end

local function applyAlertRarity(option)
	if type(option) ~= "string" or rarityRank[option] == nil then
		return
	end
	local ordered = STATE.toggleRarity(STATE.alertRarities, option)
	STATE.alertRarities = ordered
	STATE.webhookRarity = ordered[1] or STATE.webhookRarity
	if type(STATE.rarityControl) ~= "table" then
		STATE.rarityControl = {}
	end
	STATE.rarityControl.value = ordered[1]
	STATE.rarityControl.currentOption = ordered
	if typeof(STATE._setRarityText) == "function" then
		pcall(STATE._setRarityText, STATE.rarityLabel(ordered))
	end
	resetStealScan()
	saveConfig()
	if typeof(STATE.refreshTracker) == "function" then
		pcall(STATE.refreshTracker)
	end
end

local pulseAntiAfk

function STATE.canonicalHttps(raw)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	if string.find(raw, "%s") or string.find(raw, "@", 1, true) or string.find(raw, "?", 1, true) or string.find(raw, "#", 1, true) or string.find(raw, "%%") then
		return nil
	end
	local host, path = string.match(raw, "^https://([^/%?#]+)(/[^%?#]*)$")
	if not host then
		host = string.match(raw, "^https://([^/%?#]+)$")
		path = "/"
	end
	if type(host) ~= "string" or string.find(host, ":", 1, true) or not string.match(host, "^[%w%-%.]+$") then
		return nil
	end
	if type(path) ~= "string" or string.find(path, "?", 1, true) or string.find(path, "#", 1, true) then
		return nil
	end
	return "https://" .. string.lower(host) .. path
end

function STATE.trustedThemeUrl(raw)
	local canonical = STATE.canonicalHttps(raw)
	if type(canonical) ~= "string" then
		return nil
	end
	local host = string.match(canonical, "^https://([^/]+)")
	if host ~= "ysoyjfnigavjajrjftmv.supabase.co" then
		return nil
	end
	return canonical
end

do
	local look, name = STATE.readTheme(STATE.defaultTheme)
	if type(look) == "table" then
		STATE.hubThemeLook = look
		STATE.themeName = name or "AstaTheme"
	end
end

function STATE.hashUrl(url)
	local h1 = 2166136261
	local h2 = 16777619
	for index = 1, #url do
		local byte = string.byte(url, index)
		h1 = bit32.bxor(h1, byte)
		h1 = bit32.band(h1 * 16777619, 4294967295)
		h2 = bit32.bxor(h2, bit32.lrotate(byte, index % 8))
		h2 = bit32.band(h2 * 2246822519, 4294967295)
	end
	return string.format("%08x%08x", h1, h2)
end

function STATE.imageFormat(body)
	if type(body) ~= "string" or #body < 12 then
		return nil
	end
	if string.byte(body, 1) == 137 and string.sub(body, 2, 4) == "PNG" and string.byte(body, 5) == 13 then
		return "png"
	end
	if string.byte(body, 1) == 255 and string.byte(body, 2) == 216 and string.byte(body, 3) == 255 then
		return "jpeg"
	end
	if string.sub(body, 1, 4) == "RIFF" and string.sub(body, 9, 12) == "WEBP" then
		return "webp"
	end
	return nil
end

function STATE.themeDir()
	return STATE._themeRoot or "ZinoosHub/theme"
end

function STATE.ensureThemeFolders()
	if typeof(makefolder) ~= "function" then
		return
	end
	pcall(makefolder, "ZinoosHub")
	pcall(makefolder, STATE.themeDir())
end

function STATE.readThemeManifest()
	if typeof(readfile) ~= "function" then
		return {}
	end
	local path = STATE.themeDir() .. "/manifest.json"
	local ok, text = pcall(readfile, path)
	if not ok or type(text) ~= "string" or text == "" then
		return {}
	end
	local decodedOk, decoded = pcall(function()
		return game:GetService("HttpService"):JSONDecode(text)
	end)
	if decodedOk and type(decoded) == "table" then
		return decoded
	end
	return {}
end

function STATE.writeThemeManifest(manifest)
	if typeof(writefile) ~= "function" or type(manifest) ~= "table" then
		return
	end
	local ok, encoded = pcall(function()
		return game:GetService("HttpService"):JSONEncode(manifest)
	end)
	if ok then
		pcall(writefile, STATE.themeDir() .. "/manifest.json", encoded)
	end
end

function STATE.themeStillCurrent(gen, token)
	return running() and STATE._gen == gen and genv.ZinoosGen == token and STATE._unloaded ~= true
end

function STATE.storeThemeBody(url, body, gen, token)
	local canonical = STATE.canonicalHttps(url)
	if not canonical or type(body) ~= "string" then
		return nil
	end
	if not STATE.themeStillCurrent(gen, token) then
		return nil
	end
	-- A trusted download is already in memory here. HttpGet has no streaming
	-- or header-only API on this executor, so this limit cannot stop that
	-- download. It only refuses the disk write and the decoder. Untrusted
	-- hosts are rejected in themeAsset before HttpGet is called.
	if #body > 5 * 1024 * 1024 or #body < 12 then
		return nil
	end
	local format = STATE.imageFormat(body)
	if not format then
		return nil
	end
	if typeof(writefile) ~= "function" or typeof(getcustomasset) ~= "function" then
		return nil
	end
	STATE.ensureThemeFolders()
	if not STATE.themeStillCurrent(gen, token) then
		return nil
	end
	local key = STATE.hashUrl(canonical)
	local path = STATE.themeDir() .. "/" .. key .. "." .. format
	local manifest = STATE.readThemeManifest()
	local existing = manifest[key]
	if type(existing) == "table" and existing.path == path and typeof(isfile) == "function" and isfile(path) then
		local cachedOk, cached = pcall(readfile, path)
		if cachedOk and STATE.imageFormat(cached) == format then
			if not STATE.themeStillCurrent(gen, token) then
				return nil
			end
			local assetOk, asset = pcall(getcustomasset, path)
			if assetOk and type(asset) == "string" and asset ~= "" then
				return asset
			end
		end
	end
	if not STATE.themeStillCurrent(gen, token) then
		return nil
	end
	if not pcall(writefile, path, body) then
		return nil
	end
	manifest[key] = { path = path, at = os.time(), format = format }
	local oldestKey = nil
	local oldestAt = math.huge
	local count = 0
	for itemKey, item in pairs(manifest) do
		if itemKey ~= "order" and type(item) == "table" then
			count += 1
			local at = type(item.at) == "number" and item.at or 0
			if at < oldestAt then
				oldestAt = at
				oldestKey = itemKey
			end
		end
	end
	if count > 16 and type(oldestKey) == "string" and oldestKey ~= key then
		local old = manifest[oldestKey]
		manifest[oldestKey] = nil
		if type(old) == "table" and type(old.path) == "string" and typeof(delfile) == "function" then
			pcall(delfile, old.path)
		end
	end
	if not STATE.themeStillCurrent(gen, token) then
		if typeof(delfile) == "function" then
			pcall(delfile, path)
		end
		return nil
	end
	STATE.writeThemeManifest(manifest)
	local assetOk, asset = pcall(getcustomasset, path)
	if not STATE.themeStillCurrent(gen, token) then
		return nil
	end
	if assetOk and type(asset) == "string" and asset ~= "" then
		return asset
	end
	return nil
end

function STATE.themeAsset(url, gen, token)
	local canonical = STATE.trustedThemeUrl(url)
	if not canonical then
		return nil
	end
	gen = gen or STATE._gen
	token = token or genv.ZinoosGen
	if not STATE.themeStillCurrent(gen, token) then
		return nil
	end
	local key = STATE.hashUrl(canonical)
	local manifest = STATE.readThemeManifest()
	local existing = manifest[key]
	if type(existing) == "table" and type(existing.path) == "string" and typeof(isfile) == "function" and isfile(existing.path) and typeof(readfile) == "function" then
		local cachedOk, cached = pcall(readfile, existing.path)
		if cachedOk and STATE.imageFormat(cached) == existing.format then
			if not STATE.themeStillCurrent(gen, token) then
				return nil
			end
			local assetOk, asset = pcall(getcustomasset, existing.path)
			if assetOk and type(asset) == "string" and asset ~= "" and STATE.themeStillCurrent(gen, token) then
				return asset
			end
		end
	end
	if not STATE.themeStillCurrent(gen, token) then
		return nil
	end
	local fetch = STATE._themeFetch
	if type(fetch) ~= "function" then
		if typeof(game.HttpGet) ~= "function" then
			return nil
		end
		fetch = function(target)
			return game:HttpGet(target)
		end
	end
	local ok, body = pcall(fetch, canonical)
	if not STATE.themeStillCurrent(gen, token) then
		return nil
	end
	if not ok or type(body) ~= "string" then
		return nil
	end
	return STATE.storeThemeBody(canonical, body, gen, token)
end

function STATE.loadThemeImages()
	local gen = STATE._gen
	local token = genv.ZinoosGen
	local theme = STATE.hubThemeDef()
	if theme.icon and type(theme.iconUrl) == "string" then
		local icon = STATE.themeAsset(theme.iconUrl, gen, token)
		if STATE.themeStillCurrent(gen, token) and type(icon) == "string" then
			STATE.themeIcon = icon
		end
	elseif STATE.themeStillCurrent(gen, token) then
		STATE.themeIcon = nil
	end
	if not STATE.themeStillCurrent(gen, token) then
		return
	end
	if theme.wallpaper and type(theme.wallUrl) == "string" then
		local photo = STATE.themeAsset(theme.wallUrl, gen, token)
		if STATE.themeStillCurrent(gen, token) and type(photo) == "string" then
			STATE.themeWall = photo
		end
	elseif STATE.themeStillCurrent(gen, token) then
		STATE.themeWall = nil
	end
	if STATE.themeStillCurrent(gen, token) and STATE.applyLook then
		STATE.applyLook()
	end
end

local function installHub()
	closeLeftoverMenus()
	STATE.themeSwitches = {}

	local theme = STATE.hubThemeDef()
	local accent = theme.accent
	local ink = theme.ink
	local muted = theme.muted
	local panel = theme.panel
	local side = theme.side
	local cardColor = theme.card
	local selected = theme.selected
	local off = theme.off
	local line = theme.stroke
	local mint = theme.accent
	local inkDark = theme.inkDark
	local cardFade = theme.cardFade
	local function role(object, kind)
		object:SetAttribute("ZinoosRole", kind)
		return object
	end

	local TweenService = game:GetService("TweenService")
	local tweenInfo = {
		open = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		fade = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		toggle = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		card = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		drop = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	}
	local liveTweens = {}
	local function playMotion(object, props, info)
		local old = liveTweens[object]
		if old then
			pcall(function()
				old:Cancel()
			end)
		end
		local tween = TweenService:Create(object, info or tweenInfo.hover, props)
		liveTweens[object] = tween
		tween.Completed:Connect(function()
			if liveTweens[object] == tween then
				liveTweens[object] = nil
			end
		end)
		tween:Play()
		return tween
	end
	local function bindPress(gui)
		local scale = Instance.new("UIScale")
		scale.Name = "PressScale"
		scale.Parent = gui
		gui.MouseButton1Down:Connect(function()
			playMotion(scale, { Scale = 0.98 }, tweenInfo.hover)
		end)
		gui.MouseButton1Up:Connect(function()
			playMotion(scale, { Scale = 1 }, tweenInfo.hover)
		end)
		gui.MouseLeave:Connect(function()
			if scale.Scale ~= 1 then
				playMotion(scale, { Scale = 1 }, tweenInfo.hover)
			end
		end)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ZinoosHubMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 220
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = CoreGui

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local function viewSize()
		local camera = workspace.CurrentCamera
		return camera and camera.ViewportSize or Vector2.new(1280, 720)
	end
	local holder
	local fullMode = false
	local applyHubLayout
	local function fitScale()
		local view = viewSize()
		local compact = view.X < 760 or view.Y < 560 or (UserInputService.TouchEnabled and view.X < 900)
		local medium = not compact and (view.X < 1400 or view.Y < 820)
		local margin = (compact or fullMode) and 0 or 16
		local baseW, baseH
		if compact or fullMode then
			baseW = math.max(320, view.X - margin * 2)
			baseH = math.max(480, view.Y - margin * 2)
		elseif medium then
			baseW = math.min(972, math.max(640, view.X - 32))
			baseH = math.min(668, math.max(480, view.Y - 32))
		else
			baseW = 972
			baseH = 668
		end
		holder.Size = UDim2.fromOffset(baseW, baseH)
		uiScale.Scale = 1
		if applyHubLayout then
			applyHubLayout(view, compact, baseW)
		end
	end

	local launcher = Instance.new("CanvasGroup")
	launcher.Name = "Zinoos hub"
	launcher.BackgroundColor3 = side
	role(launcher, "side")
	launcher.BorderSizePixel = 0
	launcher.AnchorPoint = Vector2.new(0, 0.5)
	launcher.Position = UDim2.new(0, 28, 0.58, 0)
	launcher.Size = UDim2.fromOffset(300, 136)
	launcher.GroupTransparency = 0
	launcher.Active = true
	launcher.Visible = true
	launcher.Parent = gui
	local launcherCorner = Instance.new("UICorner")
	launcherCorner.CornerRadius = UDim.new(0, 16)
	launcherCorner.Parent = launcher
	local launcherStroke = Instance.new("UIStroke")
	launcherStroke.Color = line
	launcherStroke.Transparency = 0.45
	launcherStroke.Thickness = 1
	launcherStroke.Parent = launcher
	local dockAvatar = Instance.new("ImageLabel")
	dockAvatar.BackgroundColor3 = cardColor
	dockAvatar.BorderSizePixel = 0
	dockAvatar.Position = UDim2.fromOffset(14, 14)
	dockAvatar.Size = UDim2.fromOffset(36, 36)
	dockAvatar.Parent = launcher
	local dockAvatarCorner = Instance.new("UICorner")
	dockAvatarCorner.CornerRadius = UDim.new(1, 0)
	dockAvatarCorner.Parent = dockAvatar
	local dockName = Instance.new("TextLabel")
	dockName.BackgroundTransparency = 1
	dockName.Font = Enum.Font.GothamBold
	dockName.Text = LocalPlayer.DisplayName
	dockName.TextColor3 = ink
	role(dockName, "ink")
	dockName.TextSize = 15
	dockName.TextXAlignment = Enum.TextXAlignment.Left
	dockName.TextTruncate = Enum.TextTruncate.AtEnd
	dockName.Position = UDim2.fromOffset(60, 14)
	dockName.Size = UDim2.new(1, -150, 0, 18)
	dockName.Parent = launcher
	local dockGame = Instance.new("TextLabel")
	dockGame.BackgroundTransparency = 1
	dockGame.Font = Enum.Font.Gotham
	dockGame.Text = STATE.admin and "Admin" or "Lift Rock For Eggs"
	dockGame.TextColor3 = STATE.admin and accent or muted
	role(dockGame, STATE.admin and "accentText" or "muted")
	dockGame.TextSize = 12
	dockGame.TextXAlignment = Enum.TextXAlignment.Left
	dockGame.Position = UDim2.fromOffset(60, 32)
	dockGame.Size = UDim2.new(1, -150, 0, 16)
	dockGame.Parent = launcher
	local dockClock = Instance.new("TextLabel")
	dockClock.BackgroundTransparency = 1
	dockClock.Font = Enum.Font.GothamBold
	dockClock.Text = "0:00"
	dockClock.TextColor3 = ink
	role(dockClock, "ink")
	dockClock.TextSize = 14
	dockClock.TextXAlignment = Enum.TextXAlignment.Right
	dockClock.Position = UDim2.new(1, -126, 0, 16)
	dockClock.Size = UDim2.fromOffset(100, 18)
	dockClock.Parent = launcher
	local dockStats = Instance.new("TextLabel")
	dockStats.BackgroundTransparency = 1
	dockStats.Font = Enum.Font.Gotham
	dockStats.Text = "60 fps    0 ms"
	dockStats.TextColor3 = mint
	role(dockStats, "accentText")
	dockStats.TextSize = 12
	dockStats.TextXAlignment = Enum.TextXAlignment.Left
	dockStats.Position = UDim2.fromOffset(14, 64)
	dockStats.Size = UDim2.new(1, -28, 0, 16)
	dockStats.Parent = launcher
	local barTrack = Instance.new("Frame")
	barTrack.BackgroundColor3 = accent
	barTrack.BackgroundTransparency = 0.72
	barTrack.BorderSizePixel = 0
	barTrack.Position = UDim2.fromOffset(14, 86)
	barTrack.Size = UDim2.new(1, -28, 0, 4)
	barTrack.Parent = launcher
	local barTrackCorner = Instance.new("UICorner")
	barTrackCorner.CornerRadius = UDim.new(1, 0)
	barTrackCorner.Parent = barTrack
	local fpsBar = Instance.new("Frame")
	fpsBar.BackgroundColor3 = mint
	fpsBar.BorderSizePixel = 0
	fpsBar.Size = UDim2.fromScale(0.7, 1)
	fpsBar.Parent = barTrack
	local fpsBarCorner = Instance.new("UICorner")
	fpsBarCorner.CornerRadius = UDim.new(1, 0)
	fpsBarCorner.Parent = fpsBar
	local dockHint = Instance.new("TextLabel")
	dockHint.BackgroundTransparency = 1
	dockHint.Font = Enum.Font.Gotham
	dockHint.Text = "Click or press Right Ctrl to open"
	dockHint.TextColor3 = muted
	role(dockHint, "muted")
	dockHint.TextSize = 12
	dockHint.TextXAlignment = Enum.TextXAlignment.Left
	dockHint.Position = UDim2.fromOffset(14, 100)
	dockHint.Size = UDim2.new(1, -28, 0, 18)
	dockHint.Parent = launcher
	local fpsCount = 0
	trackConnection(RunService.Heartbeat:Connect(function()
		fpsCount += 1
	end))

	holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(972, 668)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	fitScale()
	local windowScale = Instance.new("UIScale")
	windowScale.Name = "WindowMotion"
	windowScale.Parent = holder

	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 1
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, 8)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = 1
	shadow.Parent = holder
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 18)
	shadowCorner.Parent = shadow

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.BackgroundColor3 = panel
	role(window, "panel")
	window.BorderSizePixel = 0
	window.Size = UDim2.fromScale(1, 1)
	window.ZIndex = 2
	window.Parent = holder
	local windowCorner = Instance.new("UICorner")
	windowCorner.CornerRadius = UDim.new(0, 16)
	windowCorner.Parent = window
	local windowStroke = Instance.new("UIStroke")
	windowStroke.Color = line
	windowStroke.Transparency = 0.55
	windowStroke.Thickness = 1
	windowStroke.Parent = window
	local wallpaper = Instance.new("CanvasGroup")
	wallpaper.Name = "Wallpaper"
	wallpaper.BackgroundTransparency = 1
	wallpaper.BorderSizePixel = 0
	wallpaper.Size = UDim2.fromScale(1, 1)
	wallpaper.ZIndex = 1
	wallpaper.Parent = window
	local wallpaperCorner = Instance.new("UICorner")
	wallpaperCorner.CornerRadius = UDim.new(0, 16)
	wallpaperCorner.Parent = wallpaper
	local wallpaperImage = Instance.new("ImageLabel")
	wallpaperImage.BackgroundTransparency = 1
	wallpaperImage.BorderSizePixel = 0
	wallpaperImage.Size = UDim2.fromScale(1, 1)
	wallpaperImage.ScaleType = Enum.ScaleType.Crop
	wallpaperImage.ImageTransparency = 1
	wallpaperImage.ZIndex = 1
	wallpaperImage.Parent = wallpaper
	local wallpaperScrim = Instance.new("Frame")
	wallpaperScrim.Name = "Scrim"
	wallpaperScrim.BackgroundColor3 = Color3.new(0, 0, 0)
	wallpaperScrim.BackgroundTransparency = 0.38
	wallpaperScrim.BorderSizePixel = 0
	wallpaperScrim.Size = UDim2.fromScale(1, 1)
	wallpaperScrim.ZIndex = 2
	wallpaperScrim.Parent = wallpaper

	local sideWrap = Instance.new("CanvasGroup")
	sideWrap.Name = "SideWrap"
	sideWrap.BackgroundTransparency = 1
	sideWrap.BorderSizePixel = 0
	sideWrap.Size = UDim2.new(0.25, 0, 1, 0)
	sideWrap.GroupTransparency = 1
	sideWrap.ZIndex = 3
	sideWrap.Parent = window
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundColor3 = side
	role(sidebar, "side")
	sidebar.BackgroundTransparency = 0
	sidebar.BorderSizePixel = 0
	sidebar.Size = UDim2.fromScale(1, 1)
	sidebar.ZIndex = 3
	sidebar.Parent = sideWrap
	local sideCorner = Instance.new("UICorner")
	sideCorner.CornerRadius = UDim.new(0, 16)
	sideCorner.Parent = sidebar
	local sideFill = Instance.new("Frame")
	sideFill.BackgroundColor3 = side
	role(sideFill, "side")
	sideFill.BackgroundTransparency = 0
	sideFill.BorderSizePixel = 0
	sideFill.Position = UDim2.new(1, -16, 0, 0)
	sideFill.Size = UDim2.new(0, 16, 1, 0)
	sideFill.ZIndex = 3
	sideFill.Parent = sidebar

	local mark = Instance.new("Frame")
	mark.BackgroundColor3 = accent
	mark.BorderSizePixel = 0
	mark.Position = UDim2.fromOffset(16, 16)
	mark.Size = UDim2.fromOffset(28, 28)
	mark.ZIndex = 4
	mark.Parent = sidebar
	local markCorner = Instance.new("UICorner")
	markCorner.CornerRadius = UDim.new(1, 0)
	markCorner.Parent = mark
	local markText = Instance.new("TextLabel")
	markText.BackgroundTransparency = 1
	markText.Font = Enum.Font.GothamBlack
	markText.Text = "Z"
	markText.TextColor3 = inkDark
	role(markText, "inkDark")
	markText.TextSize = 16
	markText.Size = UDim2.fromScale(1, 1)
	markText.ZIndex = 5
	markText.Parent = mark
	local markImage = Instance.new("ImageLabel")
	markImage.BackgroundTransparency = 1
	markImage.BorderSizePixel = 0
	markImage.Size = UDim2.fromScale(1, 1)
	markImage.ScaleType = Enum.ScaleType.Crop
	markImage.ZIndex = 6
	markImage.Parent = mark
	local markImageCorner = Instance.new("UICorner")
	markImageCorner.CornerRadius = UDim.new(1, 0)
	markImageCorner.Parent = markImage
	task.spawn(STATE.loadThemeImages)

	local brand = Instance.new("TextLabel")
	brand.BackgroundTransparency = 1
	brand.Font = Enum.Font.GothamBold
	brand.Text = "Zinoos"
	brand.TextColor3 = ink
	role(brand, "ink")
	brand.TextSize = 16
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.Position = UDim2.fromOffset(52, 14)
	brand.Size = UDim2.new(1, -60, 0, 20)
	brand.ZIndex = 4
	brand.Parent = sidebar
	local brandSub = Instance.new("TextLabel")
	brandSub.BackgroundTransparency = 1
	brandSub.Font = Enum.Font.Gotham
	brandSub.Text = "Lift Rock"
	brandSub.TextColor3 = muted
	role(brandSub, "muted")
	brandSub.TextSize = 12
	brandSub.TextXAlignment = Enum.TextXAlignment.Left
	brandSub.Position = UDim2.fromOffset(52, 32)
	brandSub.Size = UDim2.new(1, -60, 0, 16)
	brandSub.ZIndex = 4
	brandSub.Parent = sidebar

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Position = UDim2.new(0.25, 0, 0, 0)
	content.Size = UDim2.new(0.75, 0, 1, 0)
	content.ZIndex = 3
	content.Parent = window
	local headWrap = Instance.new("CanvasGroup")
	headWrap.Name = "HeadWrap"
	headWrap.BackgroundTransparency = 1
	headWrap.BorderSizePixel = 0
	headWrap.Size = UDim2.new(1, 0, 0, 64)
	headWrap.GroupTransparency = 1
	headWrap.ZIndex = 4
	headWrap.Parent = content
	local header = Instance.new("Frame")
	header.Name = "DragBar"
	header.Active = true
	header.BackgroundColor3 = panel
	header.BackgroundTransparency = 1
	header.BorderSizePixel = 0
	header.Size = UDim2.fromScale(1, 1)
	header.ZIndex = 4
	header.Parent = headWrap
	local pageTitle = Instance.new("TextLabel")
	pageTitle.BackgroundTransparency = 1
	pageTitle.Font = Enum.Font.GothamBold
	pageTitle.Text = "Home"
	pageTitle.TextColor3 = ink
	role(pageTitle, "ink")
	pageTitle.TextSize = 18
	pageTitle.TextXAlignment = Enum.TextXAlignment.Left
	pageTitle.Position = UDim2.fromOffset(28, 0)
	pageTitle.Size = UDim2.new(0.42, 0, 1, 0)
	pageTitle.ZIndex = 4
	pageTitle.Parent = header

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.BackgroundColor3 = cardColor
	search.BackgroundTransparency = cardFade
	search.BorderSizePixel = 0
	search.ClearTextOnFocus = false
	search.Font = Enum.Font.Gotham
	search.PlaceholderText = "Search"
	search.PlaceholderColor3 = muted
	search.Text = ""
	search.TextColor3 = ink
	role(search, "field")
	search.TextSize = 14
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.AnchorPoint = Vector2.new(1, 0.5)
	search.Position = UDim2.new(1, -96, 0.5, 0)
	search.Size = UDim2.fromOffset(200, 34)
	search.ZIndex = 5
	search.Parent = header
	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 8)
	searchCorner.Parent = search
	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = accent
	searchStroke.Transparency = 0.58
	searchStroke.Thickness = 1
	searchStroke.Parent = search
	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 10)
	searchPad.Parent = search

	local fullButton = Instance.new("TextButton")
	fullButton.Name = "Fullscreen"
	fullButton.AutoButtonColor = false
	fullButton.Text = "⛶"
	fullButton.Font = Enum.Font.Gotham
	fullButton.TextSize = 16
	fullButton.TextColor3 = muted
	role(fullButton, "muted")
	fullButton.BackgroundTransparency = 1
	fullButton.AnchorPoint = Vector2.new(1, 0.5)
	fullButton.Position = UDim2.new(1, -48, 0.5, 0)
	fullButton.Size = UDim2.fromOffset(32, 32)
	fullButton.ZIndex = 5
	fullButton.Parent = header
	local closeButton = Instance.new("TextButton")
	closeButton.AutoButtonColor = false
	closeButton.Text = "X"
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 14
	closeButton.TextColor3 = muted
	role(closeButton, "muted")
	closeButton.BackgroundTransparency = 1
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -12, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(28, 28)
	closeButton.ZIndex = 5
	closeButton.Parent = header

	local pageWrap = Instance.new("CanvasGroup")
	pageWrap.Name = "PageWrap"
	pageWrap.BackgroundTransparency = 1
	pageWrap.BorderSizePixel = 0
	pageWrap.Position = UDim2.fromOffset(0, 64)
	pageWrap.Size = UDim2.new(1, 0, 1, -64)
	pageWrap.GroupTransparency = 1
	pageWrap.ZIndex = 4
	pageWrap.Parent = content
	local pageHost = Instance.new("Frame")
	pageHost.BackgroundTransparency = 1
	pageHost.Size = UDim2.fromScale(1, 1)
	pageHost.ZIndex = 4
	pageHost.Parent = pageWrap

	local pages = {}
	local navButtons = {}
	local function newPage(name)
		local page = Instance.new("ScrollingFrame")
		page.Name = name
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Size = UDim2.fromScale(1, 1)
		page.ScrollBarThickness = 3
		page.ScrollBarImageColor3 = muted
		page.ScrollBarImageTransparency = 0.35
		page.CanvasSize = UDim2.new()
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.Visible = false
		page.ZIndex = 4
		page.Parent = pageHost
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 28)
		pad.PaddingRight = UDim.new(0, 28)
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 28)
		pad.Parent = page
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 12)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = page
		pages[name] = page
		return page
	end

	local homePage = newPage("Home")
	local mainPage = newPage("Main")
	local discordPage = newPage("Discord")

	local currentPage = "Home"
	local pageToken = 0
	local function playCards(page)
		if not page then
			return
		end
		pageToken += 1
		local token = pageToken
		local index = 0
		local function visit(root)
			local kids = root:GetChildren()
			table.sort(kids, function(a, b)
				local aOrder = a:IsA("GuiObject") and a.LayoutOrder or 0
				local bOrder = b:IsA("GuiObject") and b.LayoutOrder or 0
				return aOrder < bOrder
			end)
			for _, child in ipairs(kids) do
				if child:GetAttribute("ZinoosSlot") == true then
					local motion = child:FindFirstChild("Motion")
					if motion and motion:IsA("CanvasGroup") then
						index += 1
						local step = index
						motion.Position = UDim2.fromOffset(0, 12)
						motion.GroupTransparency = 1
						task.delay((step - 1) * 0.035, function()
							if token ~= pageToken or not motion.Parent then
								return
							end
							playMotion(motion, {
								Position = UDim2.fromOffset(0, 0),
								GroupTransparency = 0,
							}, tweenInfo.card)
						end)
					end
				elseif child:IsA("Frame") and child.BackgroundTransparency >= 1 and child:FindFirstChildOfClass("UIListLayout") then
					visit(child)
				end
			end
		end
		visit(page)
	end
	local function showPage(name)
		currentPage = name
		for pageName, page in pairs(pages) do
			page.Visible = pageName == name
		end
		pageTitle.Text = name
		local themeNow = STATE.hubThemeDef()
		for buttonName, button in pairs(navButtons) do
			local on = buttonName == name
			button.BackgroundColor3 = on and themeNow.selected or themeNow.hover
			playMotion(button, { BackgroundTransparency = on and themeNow.selectedFade or 1 }, tweenInfo.hover)
		end
		if holder.Visible then
			playCards(pages[name])
		end
		if name == "Discord" then
			STATE.webhookReveal = false
			if STATE.applyWebhookMask then
				STATE.applyWebhookMask()
			end
		end
	end

	local function onActivate(control, callback, selectable)
		control.Active = true
		control.Selectable = selectable ~= false
		control.Activated:Connect(callback)
	end

	local function navIcon(parent, kind)
		local icon = Instance.new("Frame")
		icon.BackgroundTransparency = 1
		icon.BorderSizePixel = 0
		icon.Position = UDim2.fromOffset(12, 10)
		icon.Size = UDim2.fromOffset(16, 16)
		icon.ZIndex = 6
		icon.Parent = parent
		local function mark(w, h, x, y, round)
			local part = Instance.new("Frame")
			part.BackgroundTransparency = 1
			part.BorderSizePixel = 0
			part.Position = UDim2.fromOffset(x, y)
			part.Size = UDim2.fromOffset(w, h)
			part.ZIndex = 6
			part.Parent = icon
			local stroke = Instance.new("UIStroke")
			stroke.Color = ink
			stroke:SetAttribute("ZinoosRole", "iconStroke")
			stroke.Thickness = 1.25
			stroke.Parent = part
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(round and 1 or 0, round and 0 or 2)
			corner.Parent = part
			return part
		end
		if kind == "Home" then
			mark(10, 7, 3, 8, false)
			local roof = mark(2, 8, 7, 1, false)
			roof.Rotation = 40
		elseif kind == "Main" then
			mark(6, 6, 0, 0, false)
			mark(6, 6, 9, 0, false)
			mark(6, 6, 0, 9, false)
			mark(6, 6, 9, 9, false)
		else
			mark(10, 10, 3, 3, true)
		end
	end
	local function addNav(name, order)
		local button = Instance.new("TextButton")
		button.Name = name
		button.AutoButtonColor = false
		button.Text = ""
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 15
		button.TextColor3 = ink
		button.TextXAlignment = Enum.TextXAlignment.Left
		local navLabel = Instance.new("TextLabel")
		navLabel.Name = "Label"
		navLabel.BackgroundTransparency = 1
		navLabel.Font = Enum.Font.GothamMedium
		navLabel.Text = name
		navLabel.TextSize = 15
		navLabel.TextColor3 = ink
		role(navLabel, "ink")
		navLabel.TextXAlignment = Enum.TextXAlignment.Left
		navLabel.TextTruncate = Enum.TextTruncate.AtEnd
		navLabel.Position = UDim2.fromOffset(36, 0)
		navLabel.Size = UDim2.new(1, -44, 1, 0)
		navLabel.ZIndex = 6
		navLabel.Parent = button
		button.BackgroundColor3 = selected
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(12, 78 + (order - 1) * 42)
		button.Size = UDim2.new(1, -24, 0, 36)
		button.ZIndex = 4
		button.Parent = sidebar
		local navCorner = Instance.new("UICorner")
		navCorner.CornerRadius = UDim.new(0, 10)
		navCorner.Parent = button
		navIcon(button, name)
		navButtons[name] = button
		bindPress(button)
		button.MouseEnter:Connect(function()
			if currentPage ~= name then
				local themeNow = STATE.hubThemeDef()
				playMotion(button, { BackgroundColor3 = themeNow.hover, BackgroundTransparency = themeNow.hoverFade }, tweenInfo.hover)
			end
		end)
		button.MouseLeave:Connect(function()
			if currentPage ~= name then
				local themeNow = STATE.hubThemeDef()
				playMotion(button, { BackgroundColor3 = themeNow.hover, BackgroundTransparency = 1 }, tweenInfo.hover)
			end
		end)
		onActivate(button, function()
			showPage(name)
		end)
	end
	addNav("Home", 1)
	addNav("Main", 2)
	addNav("Discord", 3)

	local profile = Instance.new("Frame")
	profile.BackgroundColor3 = cardColor
	profile.BackgroundTransparency = cardFade
	role(profile, "card")
	profile.BorderSizePixel = 0
	profile.AnchorPoint = Vector2.new(0, 1)
	profile.Position = UDim2.new(0, 12, 1, -14)
	profile.Size = UDim2.new(1, -24, 0, 56)
	profile.ZIndex = 4
	profile.Parent = sidebar
	local profileCorner = Instance.new("UICorner")
	profileCorner.CornerRadius = UDim.new(0, 12)
	profileCorner.Parent = profile
	local profileStroke = Instance.new("UIStroke")
	profileStroke.Color = accent
	profileStroke.Transparency = 0.58
	profileStroke.Thickness = 1
	profileStroke.Parent = profile
	local avatar = Instance.new("ImageLabel")
	avatar.BackgroundColor3 = cardColor
	avatar.BorderSizePixel = 0
	avatar.Size = UDim2.fromOffset(32, 32)
	avatar.Position = UDim2.fromOffset(10, 10)
	avatar.ZIndex = 5
	avatar.Parent = profile
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatar
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		if ok and gui.Parent then
			avatar.Image = image
			dockAvatar.Image = image
		end
	end)
	local profileName = Instance.new("TextLabel")
	profileName.BackgroundTransparency = 1
	profileName.Font = Enum.Font.GothamBold
	profileName.Text = LocalPlayer.DisplayName
	profileName.TextColor3 = ink
	role(profileName, "ink")
	profileName.TextSize = 13
	profileName.TextXAlignment = Enum.TextXAlignment.Left
	profileName.TextTruncate = Enum.TextTruncate.AtEnd
	profileName.Position = UDim2.fromOffset(50, 10)
	profileName.Size = UDim2.new(1, -60, 0, 16)
	profileName.ZIndex = 5
	profileName.Parent = profile
	local profileGame = Instance.new("TextLabel")
	profileGame.BackgroundTransparency = 1
	profileGame.Font = Enum.Font.Gotham
	profileGame.Text = STATE.admin and "Admin" or "Lift Rock For Eggs"
	profileGame.TextColor3 = STATE.admin and accent or muted
	role(profileGame, STATE.admin and "accentText" or "muted")
	profileGame.TextSize = 11
	profileGame.TextXAlignment = Enum.TextXAlignment.Left
	profileGame.Position = UDim2.fromOffset(50, 28)
	profileGame.Size = UDim2.new(1, -60, 0, 14)
	profileGame.ZIndex = 5
	profileGame.Parent = profile

	local function label(parent, text, size, color, font, height)
		local item = Instance.new("TextLabel")
		item.BackgroundTransparency = 1
		item.Font = font or Enum.Font.Gotham
		item.Text = text
		item.TextColor3 = color or ink
		if color == muted then
			item:SetAttribute("ZinoosRole", "muted")
		elseif color == accent then
			item:SetAttribute("ZinoosRole", "accentText")
		elseif color == inkDark then
			item:SetAttribute("ZinoosRole", "inkDark")
		else
			item:SetAttribute("ZinoosRole", "ink")
		end
		item.TextSize = size or 14
		item.TextWrapped = true
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.TextYAlignment = Enum.TextYAlignment.Top
		item.Size = UDim2.new(1, 0, 0, height or 20)
		item.ZIndex = 5
		item.Parent = parent
		return item
	end

	local function card(parent, title, order)
		local slot = Instance.new("Frame")
		slot.Name = title
		slot.BackgroundTransparency = 1
		slot.BorderSizePixel = 0
		slot.LayoutOrder = order
		slot.AutomaticSize = Enum.AutomaticSize.Y
		slot.Size = UDim2.new(1, 0, 0, 0)
		slot.ZIndex = 5
		slot:SetAttribute("ZinoosSlot", true)
		slot.Parent = parent
		local box = Instance.new("CanvasGroup")
		box.Name = "Motion"
		box.BackgroundColor3 = cardColor
		box.BackgroundTransparency = cardFade
		role(box, "card")
		box.BorderSizePixel = 0
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.Size = UDim2.new(1, 0, 0, 0)
		box.GroupTransparency = 0
		box.ZIndex = 5
		box.Parent = slot
		local boxCorner = Instance.new("UICorner")
		boxCorner.CornerRadius = UDim.new(0, 12)
		boxCorner.Parent = box
		local boxStroke = Instance.new("UIStroke")
		boxStroke.Color = line
		boxStroke.Transparency = 0.62
		boxStroke.Thickness = 1
		boxStroke.Parent = box
		local boxPad = Instance.new("UIPadding")
		boxPad.PaddingTop = UDim.new(0, 12)
		boxPad.PaddingBottom = UDim.new(0, 12)
		boxPad.PaddingLeft = UDim.new(0, 14)
		boxPad.PaddingRight = UDim.new(0, 14)
		boxPad.Parent = box
		local boxLayout = Instance.new("UIListLayout")
		boxLayout.Padding = UDim.new(0, 6)
		boxLayout.SortOrder = Enum.SortOrder.LayoutOrder
		boxLayout.Parent = box
		local heading = label(box, title, 13, muted, Enum.Font.GothamBold, 16)
		heading.LayoutOrder = 0
		return box
	end

	local searchRows = {}
	local function remember(row, cardFrame, text)
		row:SetAttribute("ZinoosSearch", string.lower(text))
		local page = "Main"
		local current = row
		while current do
			if current == discordPage then
				page = "Discord"
				break
			elseif current == homePage then
				page = "Home"
				break
			elseif current == mainPage then
				page = "Main"
				break
			end
			current = current.Parent
		end
		searchRows[#searchRows + 1] = { row = row, card = cardFrame, text = string.lower(text), page = page }
	end

	local function paintSwitch(track, knob, on, instant)
		local themeNow = STATE.hubThemeDef()
		local goal = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		local color = on and themeNow.accent or themeNow.off
		local knobColor = on and themeNow.inkDark or themeNow.accent
		local glow = track:FindFirstChild("Glow")
		local glowFade = on and 0.82 or 0.35
		if instant then
			knob.Position = goal
			knob.BackgroundColor3 = knobColor
			track.BackgroundColor3 = color
		if glow and glow:IsA("UIStroke") then
			glow.Color = themeNow.accent
			glow.Transparency = glowFade
		end
			return
		end
		playMotion(knob, { Position = goal, BackgroundColor3 = knobColor }, tweenInfo.toggle)
		playMotion(track, { BackgroundColor3 = color }, tweenInfo.toggle)
		if glow and glow:IsA("UIStroke") then
			glow.Color = themeNow.accent
			playMotion(glow, { Transparency = glowFade }, tweenInfo.toggle)
		end
	end

	local function onToggle(key, on)
		STATE[key] = on
		if key == "autoTrain" and not on then
			lastSwitchAt = 0
			releaseGym()
		elseif key == "autoSteal" and on then
			resetStealScan()
		elseif key == "autoPlace" then
			STATE.placeBusy = false
			STATE.nextAutoPlace = 0
			STATE.placeStatus = on and "Scanning inventory" or nil
		elseif key == "antiAfk" and on and pulseAntiAfk then
			task.defer(pulseAntiAfk)
		elseif key == "lowEnd" then
			applyLowEnd(on)
		elseif key == "invEsp" and not on then
			STATE._invShown = false
			clearInvEsp()
		end
		saveConfig()
	end

	local function makeSwitch(parentBox, name, key, hint)
		local row = Instance.new("Frame")
		row.Name = name
		row.BackgroundTransparency = 1
		row.LayoutOrder = 1
		row.Size = UDim2.new(1, 0, 0, hint and 50 or 30)
		row.ZIndex = 6
		row.Parent = parentBox
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamMedium
		title.Text = name
		title.TextColor3 = ink
		role(title, "ink")
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Size = UDim2.new(1, -52, 0, 18)
		title.ZIndex = 6
		title.Parent = row
		if hint then
			local note = Instance.new("TextLabel")
			note.BackgroundTransparency = 1
			note.Font = Enum.Font.Gotham
			note.Text = hint
			note.TextColor3 = muted
			role(note, "muted")
			note.TextSize = 11
			note.TextWrapped = true
			note.TextXAlignment = Enum.TextXAlignment.Left
			note.Position = UDim2.fromOffset(0, 18)
			note.Size = UDim2.new(1, -52, 0, 28)
			note.ZIndex = 6
			note.Parent = row
		end
		local track = Instance.new("TextButton")
		track.AutoButtonColor = false
		track.Text = ""
		track.AnchorPoint = Vector2.new(1, 0.5)
		track.Position = UDim2.new(1, 0, 0.5, 0)
		track.Size = UDim2.fromOffset(36, 20)
		track.ZIndex = 7
		track.Parent = row
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track
		local trackStroke = Instance.new("UIStroke")
		trackStroke.Name = "Glow"
		trackStroke:SetAttribute("ZinoosRole", "switchGlow")
		trackStroke.Color = accent
		trackStroke.Transparency = 0.35
		trackStroke.Thickness = 1
		trackStroke.Parent = track
		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.Size = UDim2.fromOffset(14, 14)
		knob.BackgroundColor3 = Color3.new(1, 1, 1)
		knob.BorderSizePixel = 0
		knob.ZIndex = 8
		knob.Parent = track
		local knobCorner = Instance.new("UICorner")
		knobCorner.CornerRadius = UDim.new(1, 0)
		knobCorner.Parent = knob
		local control = STATE.toggleControls[key]
		if type(control) ~= "table" then
			control = {}
			STATE.toggleControls[key] = control
		end
		control.value = STATE[key] == true
		paintSwitch(track, knob, control.value, true)
		onActivate(track, function()
			control.value = not control.value
			paintSwitch(track, knob, control.value)
			onToggle(key, control.value == true)
		end)
		STATE.themeSwitches[#STATE.themeSwitches + 1] = { track = track, knob = knob, key = key }
		remember(row, parentBox, name .. " " .. (hint or ""))
		return row
	end

	local popupBlock = Instance.new("TextButton")
	popupBlock.BackgroundTransparency = 1
	popupBlock.Text = ""
	popupBlock.Size = UDim2.fromScale(1, 1)
	popupBlock.Visible = false
	popupBlock.ZIndex = 20
	popupBlock.Parent = window
	local popup = Instance.new("CanvasGroup")
	popup.BackgroundColor3 = side
	popup.BackgroundTransparency = 0.08
	role(popup, "side")
	popup.BorderSizePixel = 0
	popup.ClipsDescendants = true
	popup.Visible = false
	popup.ZIndex = 21
	popup.Size = UDim2.fromOffset(180, 0)
	popup.Parent = window
	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 10)
	popupCorner.Parent = popup
	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = line
	popupStroke.Transparency = 0.45
	popupStroke.Parent = popup
	local popupScroll = Instance.new("ScrollingFrame")
	popupScroll.BackgroundTransparency = 1
	popupScroll.BorderSizePixel = 0
	popupScroll.Size = UDim2.fromScale(1, 1)
	popupScroll.CanvasSize = UDim2.fromOffset(0, 0)
	popupScroll.ScrollBarThickness = 4
	popupScroll.ScrollBarImageColor3 = accent
	popupScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	popupScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	popupScroll.ZIndex = 22
	popupScroll.Parent = popup
	local popupLayout = Instance.new("UIListLayout")
	popupLayout.SortOrder = Enum.SortOrder.LayoutOrder
	popupLayout.Parent = popupScroll
	local popupPad = Instance.new("UIPadding")
	popupPad.PaddingTop = UDim.new(0, 4)
	popupPad.PaddingBottom = UDim.new(0, 4)
	popupPad.Parent = popupScroll

	local function closePopup()
		popup.Visible = false
		popupBlock.Visible = false
		for _, child in ipairs(popupScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end
	onActivate(popupBlock, closePopup, false)

	local function openPopup(anchor, options, current, callback, multiple)
		closePopup()
		local rowHeight = 28
		local picked = {}
		if multiple and type(current) == "table" then
			for _, name in ipairs(current) do
				picked[name] = true
			end
		end
		local selectedIndex = 1
		local foundSelected = false
		local function paintChoice(choice, option)
			local themeNow = STATE.hubThemeDef()
			local on = (multiple and picked[option] == true) or (not multiple and option == current)
			choice.BackgroundColor3 = on and themeNow.selected or themeNow.side
			choice.BackgroundTransparency = on and themeNow.selectedFade or 1
			choice.TextColor3 = themeNow.ink
			choice.Text = (on and "  ✓ " or "    ") .. option
		end
		for index, option in ipairs(options) do
			if multiple and picked[option] and not foundSelected then
				selectedIndex = index
				foundSelected = true
			elseif not multiple and option == current then
				selectedIndex = index
			end
			local choice = Instance.new("TextButton")
			choice.Name = "Choice"
			choice.LayoutOrder = index
			choice.AutoButtonColor = false
			choice.Font = Enum.Font.Gotham
			choice.TextSize = 13
			choice.TextColor3 = ink
			choice.TextXAlignment = Enum.TextXAlignment.Left
			choice.Size = UDim2.new(1, -8, 0, rowHeight)
			choice.ZIndex = 23
			choice.Parent = popupScroll
			paintChoice(choice, option)
			onActivate(choice, function()
				if multiple then
					picked[option] = not picked[option]
					paintChoice(choice, option)
					callback(option)
				else
					callback(option)
					closePopup()
				end
			end)
		end
		local popupWidth = 180
		for _, option in ipairs(options) do
			local estimate = 36 + #tostring(option) * 7
			if estimate > popupWidth then
				popupWidth = estimate
			end
		end
		if popupWidth > 280 then
			popupWidth = 280
		end
		local contentHeight = #options * rowHeight + 8
		local scale = uiScale.Scale
		if scale < 0.05 then
			scale = 1
		end
		local view = viewSize()
		local origin = window.AbsolutePosition
		local anchorPos = anchor.AbsolutePosition
		local anchorHeight = anchor.AbsoluteSize.Y
		local roomBelow = view.Y - (anchorPos.Y + anchorHeight + 8)
		local roomAbove = anchorPos.Y - 8
		local room = math.max(roomBelow, roomAbove)
		room = math.clamp(room, rowHeight * scale + 8, math.max(rowHeight * scale + 8, view.Y - 16))
		local popupPixels = math.min(contentHeight * scale, room)
		local popupHeight = popupPixels / scale
		popup.Size = UDim2.fromOffset(popupWidth, 0)
		popup.GroupTransparency = 1
		playMotion(popup, {
			Size = UDim2.fromOffset(popupWidth, popupHeight),
			GroupTransparency = 0,
		}, tweenInfo.drop)
		popupScroll.CanvasSize = UDim2.fromOffset(0, contentHeight)
		local openAbove = roomBelow + 1 < popupPixels and roomAbove > roomBelow
		local pixelY = openAbove and (anchorPos.Y - popupPixels - 6) or (anchorPos.Y + anchorHeight + 6)
		pixelY = math.clamp(pixelY, 8, math.max(8, view.Y - popupPixels - 8))
		local pixelX = math.clamp(anchorPos.X, 8, math.max(8, view.X - popupWidth * scale - 8))
		popup.Position = UDim2.fromOffset((pixelX - origin.X) / scale, (pixelY - origin.Y) / scale)
		local scrollY = math.max(0, (selectedIndex - 1) * rowHeight)
		local visibleRows = math.max(popupHeight - 8, rowHeight)
		if scrollY > contentHeight - visibleRows then
			scrollY = math.max(0, contentHeight - visibleRows)
		end
		popupScroll.CanvasPosition = Vector2.new(0, scrollY)
		popup.Visible = true
		popupBlock.Visible = true
	end

	local function makeDropdown(parentBox, name, getValue, options, callback, stacked)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = 2
		row.Size = UDim2.new(1, 0, 0, stacked and 52 or 30)
		row.ZIndex = 6
		row.Parent = parentBox
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamMedium
		title.Text = name
		title.TextColor3 = ink
		role(title, "ink")
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.Size = stacked and UDim2.new(1, 0, 0, 18) or UDim2.new(0.48, 0, 1, 0)
		title.ZIndex = 6
		title.Parent = row
		local pick = Instance.new("TextButton")
		pick.AutoButtonColor = false
		pick.Font = Enum.Font.Gotham
		pick.TextSize = 13
		pick.TextColor3 = ink
		role(pick, "field")
		pick.TextXAlignment = stacked and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		pick.TextTruncate = Enum.TextTruncate.AtEnd
		pick.Text = stacked and (" " .. getValue()) or getValue()
		pick.BackgroundColor3 = panel
		pick.BackgroundTransparency = cardFade
		pick.AnchorPoint = stacked and Vector2.new(0, 1) or Vector2.new(1, 0.5)
		pick.Position = stacked and UDim2.new(0, 0, 1, 0) or UDim2.new(1, 0, 0.5, 0)
		pick.Size = stacked and UDim2.new(1, 0, 0, 26) or UDim2.fromOffset(132, 26)
		pick.ZIndex = 7
		pick.Parent = row
		local pickCorner = Instance.new("UICorner")
		pickCorner.CornerRadius = UDim.new(0, 8)
		pickCorner.Parent = pick
		local pickStroke = Instance.new("UIStroke")
		pickStroke.Color = accent
		pickStroke.Transparency = 0.58
		pickStroke.Thickness = 1
		pickStroke.Parent = pick
		bindPress(pick)
		onActivate(pick, function()
			openPopup(pick, options, getValue(), function(option)
				callback(option)
				pick.Text = stacked and (" " .. getValue()) or getValue()
			end)
		end)
		remember(row, parentBox, name)
		return pick
	end

	local function makeMultiDropdown(parentBox, name, getList, options, onToggleName)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = 2
		row.Size = UDim2.new(1, 0, 0, 30)
		row.ZIndex = 6
		row.Parent = parentBox
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamMedium
		title.Text = name
		title.TextColor3 = ink
		role(title, "ink")
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Size = UDim2.new(0.42, 0, 1, 0)
		title.ZIndex = 6
		title.Parent = row
		local pick = Instance.new("TextButton")
		pick.AutoButtonColor = false
		pick.Font = Enum.Font.Gotham
		pick.TextSize = 13
		pick.TextColor3 = ink
		role(pick, "field")
		pick.TextXAlignment = Enum.TextXAlignment.Left
		pick.TextTruncate = Enum.TextTruncate.AtEnd
		pick.Text = " " .. STATE.rarityLabel(getList())
		pick.BackgroundColor3 = panel
		pick.BackgroundTransparency = cardFade
		pick.AnchorPoint = Vector2.new(1, 0.5)
		pick.Position = UDim2.new(1, 0, 0.5, 0)
		pick.Size = UDim2.fromOffset(156, 26)
		pick.ZIndex = 7
		pick.Parent = row
		local pickCorner = Instance.new("UICorner")
		pickCorner.CornerRadius = UDim.new(0, 8)
		pickCorner.Parent = pick
		local pickStroke = Instance.new("UIStroke")
		pickStroke.Color = accent
		pickStroke.Transparency = 0.58
		pickStroke.Thickness = 1
		pickStroke.Parent = pick
		bindPress(pick)
		onActivate(pick, function()
			openPopup(pick, options, getList(), function(option)
				onToggleName(option)
				pick.Text = " " .. STATE.rarityLabel(getList())
			end, true)
		end)
		remember(row, parentBox, name)
		return pick
	end

	STATE.toggleControls = {}
	STATE.zoneControl = {
		value = STATE.stealZone,
		currentOption = { STATE.stealZone },
	}
	STATE.rarityControl = {
		value = STATE.alertRarities[1],
		currentOption = STATE.alertRarities,
	}
	STATE.placeControl = {
		value = STATE.placeRarities[1],
		currentOption = STATE.placeRarities,
	}
	STATE.webhookControl = {
		value = STATE.webhook or "",
		currentValue = STATE.webhook or "",
	}

	local columns = Instance.new("Frame")
	columns.BackgroundTransparency = 1
	columns.Size = UDim2.new(1, 0, 0, 0)
	columns.AutomaticSize = Enum.AutomaticSize.Y
	columns.Parent = mainPage
	local columnLayout = Instance.new("UIListLayout")
	columnLayout.FillDirection = Enum.FillDirection.Horizontal
	columnLayout.Padding = UDim.new(0, 12)
	columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	columnLayout.Parent = columns

	local function column(order)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Size = UDim2.new(0.5, -6, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Parent = columns
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 12)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = frame
		return frame
	end
	local leftColumn = column(1)
	local rightColumn = column(2)

	local eggs = card(leftColumn, "EGGS", 1)
	makeSwitch(eggs, "Auto Steal", "autoSteal", "Grabs an egg of a ticked rarity, then comes back")
	makeSwitch(eggs, "Auto Place", "autoPlace", "Places ticked eggs from your bag")
	local zoneOptions = {}
	if typeof(Zones) == "table" and typeof(Zones.Order) == "table" then
		for _, zoneName in ipairs(Zones.Order) do
			zoneOptions[#zoneOptions + 1] = zoneName
		end
	end
	if #zoneOptions == 0 then
		zoneOptions[1] = "Meadow"
	end
	makeDropdown(eggs, "Steal Zone", function()
		return STATE.stealZone or "Meadow"
	end, zoneOptions, function(option)
		local chosen = zoneChoice(option)
		local changed = chosen ~= STATE.stealZone
		STATE.stealZone = chosen
		STATE.stealZoneExplicit = true
		STATE.zoneControl.value = STATE.stealZone
		STATE.zoneControl.currentOption = { STATE.stealZone }
		if changed then
			resetStealScan()
		end
		saveConfig()
		if typeof(STATE.refreshTracker) == "function" then
			pcall(STATE.refreshTracker)
		end
	end)
	local rarityPick = makeMultiDropdown(eggs, "Alert Rarity", function()
		return STATE.alertRarities
	end, rarityOptions, function(option)
		applyAlertRarity(option)
	end)
	STATE._setRarityText = function(text)
		rarityPick.Text = " " .. tostring(text)
	end
	local placePick = makeMultiDropdown(eggs, "Place Rarity", function()
		return STATE.placeRarities
	end, rarityOptions, function(option)
		STATE.applyPlaceRarity(option)
	end)
	STATE._setPlaceText = function(text)
		placePick.Text = " " .. tostring(text)
	end
	makeDropdown(eggs, "Placement Priority", function()
		return STATE.placementChoice(STATE.placementPriority)
	end, { "Highest Rarity First", "Lowest Rarity First", "Inventory Order" }, function(option)
		STATE.placementPriority = STATE.placementChoice(option)
		saveConfig()
	end, true)

	local pets = card(leftColumn, "PETS", 2)
	makeSwitch(pets, "Auto Open", "autoOpen")
	makeSwitch(pets, "Equip Best", "equipBest")

	local screenCard = card(leftColumn, "SCREEN", 3)
	makeSwitch(screenCard, "Lite Pets", "litePets")
	makeSwitch(screenCard, "Egg ESP", "eggEsp", "Steal eggs, and what your plot eggs will hatch into")
	makeSwitch(screenCard, "Inventory ESP", "invEsp")
	makeSwitch(screenCard, "Low End", "lowEnd")

	local training = card(rightColumn, "TRAINING", 1)
	makeSwitch(training, "Auto Train", "autoTrain")
	makeSwitch(training, "Phone Games", "phoneGames", "Plays the bench phone game you picked for a high score. Bubbles pause while the phone is open.")
	makeDropdown(training, "Phone Game", function()
		return STATE.phoneChoice or "Critter Merge"
	end, { "Critter Merge", "When Pigs Fly", "Snack Stack" }, function(option)
		if option == "When Pigs Fly" or option == "Snack Stack" or option == "Critter Merge" then
			STATE.phoneChoice = option
		end
		saveConfig()
	end, true)
	makeSwitch(training, "Anti AFK", "antiAfk", "Stays in the game while you are idle")
	makeSwitch(training, "Auto Rebirth", "rebirth")

	local upgrades = card(rightColumn, "UPGRADES", 2)
	makeSwitch(upgrades, "Auto Upgrade", "upgrade")
	makeSwitch(upgrades, "Auto Trails", "trails")
	makeSwitch(upgrades, "Auto Daily", "autoDaily")
	makeSwitch(upgrades, "Auto Index", "autoIndex")
	makeSwitch(upgrades, "Free Stash", "freeStash")

	local function statChip(parentFrame, title, order)
		local chip = Instance.new("Frame")
		chip.BackgroundColor3 = cardColor
		chip.BackgroundTransparency = cardFade
		role(chip, "card")
		chip.BorderSizePixel = 0
		chip.LayoutOrder = order
		chip.Size = UDim2.new(0.5, -5, 0, 58)
		chip.ZIndex = 5
		chip.Parent = parentFrame
		local chipCorner = Instance.new("UICorner")
		chipCorner.CornerRadius = UDim.new(0, 12)
		chipCorner.Parent = chip
		local chipStroke = Instance.new("UIStroke")
		chipStroke.Color = accent
		chipStroke.Transparency = 0.62
		chipStroke.Thickness = 1
		chipStroke.Parent = chip
		local chipTitle = Instance.new("TextLabel")
		chipTitle.BackgroundTransparency = 1
		chipTitle.Font = Enum.Font.Gotham
		chipTitle.Text = title
		chipTitle.TextColor3 = muted
		role(chipTitle, "muted")
		chipTitle.TextSize = 12
		chipTitle.TextXAlignment = Enum.TextXAlignment.Left
		chipTitle.Position = UDim2.fromOffset(12, 8)
		chipTitle.Size = UDim2.new(1, -20, 0, 16)
		chipTitle.ZIndex = 6
		chipTitle.Parent = chip
		local chipValue = Instance.new("TextLabel")
		chipValue.BackgroundTransparency = 1
		chipValue.Font = Enum.Font.GothamBold
		chipValue.Text = "-"
		chipValue.TextColor3 = ink
		role(chipValue, "ink")
		chipValue.TextSize = 18
		chipValue.TextXAlignment = Enum.TextXAlignment.Left
		chipValue.Position = UDim2.fromOffset(12, 26)
		chipValue.Size = UDim2.new(1, -20, 0, 24)
		chipValue.ZIndex = 6
		chipValue.Parent = chip
		return chipValue
	end

	local lookCard = card(homePage, "THEME", 0)
	local themeNote = label(lookCard, "Paste a theme and import it. It saves on this account.", 12, muted, Enum.Font.Gotham, 32)
	themeNote.LayoutOrder = 1
	local themeBox = Instance.new("TextBox")
	themeBox.Name = "ThemeImport"
	themeBox.BackgroundColor3 = panel
	themeBox.BackgroundTransparency = cardFade
	themeBox.BorderSizePixel = 0
	themeBox.ClearTextOnFocus = false
	themeBox.MultiLine = true
	themeBox.TextWrapped = true
	themeBox.Font = Enum.Font.Gotham
	themeBox.PlaceholderText = "{\"Kind\":\"theme\",\"Name\":\"My theme\",\"Theme\":{...}}"
	themeBox.PlaceholderColor3 = muted
	themeBox.Text = ""
	themeBox.TextColor3 = ink
	themeBox.TextSize = 12
	themeBox.TextXAlignment = Enum.TextXAlignment.Left
	themeBox.TextYAlignment = Enum.TextYAlignment.Top
	themeBox.LayoutOrder = 2
	themeBox.Size = UDim2.new(1, 0, 0, 78)
	themeBox.ZIndex = 6
	themeBox.Parent = lookCard
	role(themeBox, "field")
	local themeBoxCorner = Instance.new("UICorner")
	themeBoxCorner.CornerRadius = UDim.new(0, 8)
	themeBoxCorner.Parent = themeBox
	local themeBoxPad = Instance.new("UIPadding")
	themeBoxPad.PaddingTop = UDim.new(0, 6)
	themeBoxPad.PaddingBottom = UDim.new(0, 6)
	themeBoxPad.PaddingLeft = UDim.new(0, 8)
	themeBoxPad.PaddingRight = UDim.new(0, 8)
	themeBoxPad.Parent = themeBox
	local themeStatus = label(lookCard, STATE.themeName or "AstaTheme", 12, muted, Enum.Font.Gotham, 16)
	themeStatus.Name = "ThemeStatus"
	themeStatus.LayoutOrder = 3
	local importButton = Instance.new("TextButton")
	importButton.AutoButtonColor = false
	importButton.Font = Enum.Font.GothamBold
	importButton.Text = "Import Theme"
	importButton.TextSize = 14
	importButton.TextColor3 = inkDark
	importButton.BackgroundColor3 = accent
	importButton.LayoutOrder = 4
	importButton.Size = UDim2.new(1, 0, 0, 34)
	importButton.ZIndex = 6
	importButton.Parent = lookCard
	role(importButton, "accentFill")
	importButton:SetAttribute("ZinoosTextRole", "inkDark")
	local importCorner = Instance.new("UICorner")
	importCorner.CornerRadius = UDim.new(0, 8)
	importCorner.Parent = importButton
	bindPress(importButton)
	onActivate(importButton, function()
		local imported, err = STATE.useTheme(themeBox.Text)
		if imported then
			themeBox.Text = ""
			themeStatus.Text = "Imported " .. (STATE.themeName or "theme")
			themeStatus.TextColor3 = STATE.hubThemeDef().accent
		else
			themeStatus.Text = err or "That is not a theme."
			themeStatus.TextColor3 = Color3.fromRGB(255, 120, 150)
		end
	end)
	remember(importButton, lookCard, "import theme")

	local introSlot = Instance.new("Frame")
	introSlot.BackgroundTransparency = 1
	introSlot.BorderSizePixel = 0
	introSlot.LayoutOrder = 1
	introSlot.AutomaticSize = Enum.AutomaticSize.Y
	introSlot.Size = UDim2.new(1, 0, 0, 0)
	introSlot:SetAttribute("ZinoosSlot", true)
	introSlot.Parent = homePage
	local intro = Instance.new("CanvasGroup")
	intro.Name = "Motion"
	intro.BackgroundTransparency = 1
	intro.AutomaticSize = Enum.AutomaticSize.Y
	intro.Size = UDim2.new(1, 0, 0, 0)
	intro.Parent = introSlot
	local introLayout = Instance.new("UIListLayout")
	introLayout.Padding = UDim.new(0, 4)
	introLayout.SortOrder = Enum.SortOrder.LayoutOrder
	introLayout.Parent = intro
	local welcome = label(intro, "Welcome", 22, ink, Enum.Font.GothamBold, 28)
	welcome.LayoutOrder = 1
	local blurb = label(intro, "Stays on your bench. Grabs an egg of a ticked rarity, then comes back.", 14, muted, Enum.Font.Gotham, 36)
	blurb.LayoutOrder = 2
	local sessionStarted = os.time()
	local function sessionClock()
		local elapsed = math.max(0, os.time() - sessionStarted)
		local hours = math.floor(elapsed / 3600)
		local minutes = math.floor((elapsed % 3600) / 60)
		local seconds = elapsed % 60
		if hours > 0 then
			return string.format("%d:%02d:%02d", hours, minutes, seconds)
		end
		return string.format("%d:%02d", minutes, seconds)
	end
	local sessionText = label(intro, "Session 0:00", 14, ink, Enum.Font.GothamBold, 20)
	sessionText.LayoutOrder = 3
	local statSlot = Instance.new("Frame")
	statSlot.BackgroundTransparency = 1
	statSlot.BorderSizePixel = 0
	statSlot.LayoutOrder = 4
	statSlot.AutomaticSize = Enum.AutomaticSize.Y
	statSlot.Size = UDim2.new(1, 0, 0, 0)
	statSlot:SetAttribute("ZinoosSlot", true)
	statSlot.Parent = homePage
	local statGrid = Instance.new("CanvasGroup")
	statGrid.Name = "Motion"
	statGrid.BackgroundTransparency = 1
	statGrid.Size = UDim2.new(1, 0, 0, 128)
	statGrid.Parent = statSlot
	local strengthText = statChip(statGrid, "Strength", 1)
	strengthText.Parent.Position = UDim2.fromOffset(0, 0)
	local cashText = statChip(statGrid, "Cash", 2)
	cashText.Parent.Position = UDim2.new(0.5, 5, 0, 0)
	local rebirthText = statChip(statGrid, "Rebirths", 3)
	rebirthText.Parent.Position = UDim2.fromOffset(0, 68)
	local speedText = statChip(statGrid, "Speed", 4)
	speedText.Parent.Position = UDim2.new(0.5, 5, 0, 68)

	local refreshHealth
	if STATE.admin == true then
		local healthCard = card(homePage, "STATUS", 5)
		local healthBody = label(healthCard, "", 13, Color3.fromRGB(255, 186, 92), Enum.Font.Gotham, 20)
		healthBody.LayoutOrder = 1
		healthBody.AutomaticSize = Enum.AutomaticSize.Y
		healthBody.Size = UDim2.new(1, 0, 0, 0)
		healthBody:SetAttribute("ZinoosRole", "status")
		remember(healthBody, healthCard, "feature status down broken")
		local healthSlot = healthCard.Parent
		healthSlot.Visible = false
		refreshHealth = function()
			local lines = {}
			local down = STATE.featureDown
			if type(down) == "table" then
				for name, dependency in pairs(down) do
					lines[#lines + 1] = tostring(name) .. " is down. " .. tostring(dependency) .. " is missing."
				end
			end
			local faults = STATE.featureFaults
			if type(faults) == "table" then
				for name, message in pairs(faults) do
					if type(message) == "string" and message ~= "" then
						lines[#lines + 1] = tostring(name) .. " · " .. message
					end
				end
			end
			if STATE.antiAfk == true and STATE.antiAfkOperational ~= true and type(STATE.antiAfkError) == "string" and STATE.antiAfkError ~= "" then
				lines[#lines + 1] = "Anti AFK · " .. STATE.antiAfkError
			end
			table.sort(lines)
			local text = table.concat(lines, "\n")
			if healthBody.Text ~= text then
				healthBody.Text = text
			end
			healthSlot.Visible = text ~= ""
		end
		STATE.refreshHealth = refreshHealth
	else
		STATE.refreshHealth = nil
	end

	local note = card(homePage, "HOW IT WORKS", 6)
	local noteBody = label(note, "Tick every rarity you want stolen. Tick every rarity you want placed on your plot. An unticked egg stays in your bag. Nothing here sells pets.", 13, ink, Enum.Font.Gotham, 56)
	noteBody.LayoutOrder = 1

	local trackerCard = card(homePage, "EGG TRACKER", 7)
	local trackerStatus = label(trackerCard, "Looking for eggs...", 13, muted, Enum.Font.Gotham, 112)
	trackerStatus.LayoutOrder = 1
	remember(trackerStatus, trackerCard, "egg tracker spawned eggs")
	local trackerRows = {}
	local function rarityColor(rank)
		if rank >= (rarityRank.Divine or 10) then
			return accent
		end
		if rank >= (rarityRank.Eternal or 9) then
			return Color3.fromRGB(255, 196, 92)
		end
		if rank >= (rarityRank.Legendary or 5) then
			return Color3.fromRGB(196, 160, 255)
		end
		return muted
	end
	for index = 1, 8 do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = index + 1
		row.Size = UDim2.new(1, 0, 0, 18)
		row.Visible = false
		row.ZIndex = 6
		row.Parent = trackerCard
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextSize = 13
		nameLabel.Text = ""
		nameLabel.TextColor3 = ink
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
		nameLabel.ZIndex = 6
		nameLabel.Parent = row
		local rareLabel = Instance.new("TextLabel")
		rareLabel.BackgroundTransparency = 1
		rareLabel.Font = Enum.Font.GothamBold
		rareLabel.TextSize = 11
		rareLabel.Text = ""
		rareLabel.TextXAlignment = Enum.TextXAlignment.Right
		rareLabel.AnchorPoint = Vector2.new(1, 0)
		rareLabel.Position = UDim2.new(1, 0, 0, 0)
		rareLabel.Size = UDim2.new(0.48, 0, 1, 0)
		rareLabel.ZIndex = 6
		rareLabel.Parent = row
		trackerRows[index] = { row = row, name = nameLabel, rare = rareLabel }
	end
	local trackerMore = label(trackerCard, "", 12, muted, Enum.Font.Gotham, 16)
	trackerMore.LayoutOrder = 20
	trackerMore.Visible = false

	local function refreshTracker()
		local ok, eggs = pcall(listSpawnedEggs)
		if not ok or type(eggs) ~= "table" then
			trackerStatus.Text = "Can't see eggs right now."
			trackerStatus.TextColor3 = STATE.hubThemeDef().muted
			return
		end
		local eligible = 0
		local waitingCount = 0
		for _, egg in ipairs(eggs) do
			if egg.worth then
				eligible += 1
			end
			if egg.reason == "waiting for daytime" then
				waitingCount += 1
			end
		end
		local phase = ReplicatedStorage:GetAttribute("TimeOfDayPhase")
		if phase ~= "Day" and phase ~= "Night" then
			phase = stealDaytime() and "Day" or "Night"
		end
		local lines = {
			string.format("%s · %s · %s", stealZone(), STATE.rarityLabel(STATE.alertRarities), tostring(phase)),
			string.format("%d spawned · %d eligible · %d waiting for daytime", #eggs, eligible, waitingCount),
		}
		local status = STATE.lastStealStatus
		if waitingCount > 0 and not stealDaytime() then
			lines[#lines + 1] = "Waiting for daytime"
		elseif type(status) == "table" and type(status.outcome) == "string" and status.outcome ~= "" then
			local outcome = status.outcome
			if type(status.failureReason) == "string" and status.failureReason ~= "" and status.pickupSucceeded ~= true then
				local remain = 0
				if type(status.timestamp) == "number" and string.find(outcome, "Retrying", 1, true) then
					remain = math.max(0, math.ceil(status.timestamp + 4 - os.clock()))
				end
				if remain > 0 then
					outcome ..= " · retry in " .. tostring(remain) .. "s"
				elseif outcome ~= status.failureReason then
					outcome ..= " · " .. status.failureReason
				end
			end
			lines[#lines + 1] = outcome
		elseif #eggs == 0 or eligible == 0 then
			lines[#lines + 1] = "No matching eggs"
		end
		if STATE.placeStatus == "Confirmed full" or (STATE.autoPlace == true and type(STATE.placeStatus) == "string" and STATE.placeStatus ~= "") then
			lines[#lines + 1] = STATE.placeStatus
		end
		if STATE.antiAfk == true then
			if STATE.antiAfkOperational == true then
				lines[#lines + 1] = "Anti AFK working through " .. tostring(STATE.antiAfkMethod or "VirtualUser")
			else
				lines[#lines + 1] = "Anti AFK requested but unavailable"
			end
		end
		trackerStatus.Text = table.concat(lines, "\n")
		local themeNow = STATE.hubThemeDef()
		trackerStatus.TextColor3 = eligible > 0 and themeNow.accent or themeNow.muted
		for index, slot in ipairs(trackerRows) do
			local egg = eggs[index]
			slot.row.Visible = egg ~= nil
			if egg then
				local extra = ""
				if egg.mutation ~= "None" and egg.mutation ~= "" then
					extra = " · " .. egg.mutation
				end
				if egg.front then
					extra ..= " · Front"
				end
				slot.name.Text = egg.label .. extra
				slot.name.TextColor3 = egg.worth and themeNow.ink or themeNow.muted
				if egg.reason == "under a rock" or egg.reason == "unavailable" or egg.reason == "waiting for daytime" then
					slot.rare.Text = egg.reason
					slot.rare.TextColor3 = themeNow.muted
				else
					slot.rare.Text = egg.rarity
					slot.rare.TextColor3 = rarityColor(egg.rank)
				end
			end
		end
		local extraCount = #eggs - #trackerRows
		trackerMore.Visible = extraCount > 0
		trackerMore.Text = extraCount > 0 and ("+" .. tostring(extraCount) .. " more") or ""
	end
	STATE.refreshTracker = refreshTracker

	local discordSlot = Instance.new("Frame")
	discordSlot.BackgroundTransparency = 1
	discordSlot.BorderSizePixel = 0
	discordSlot.LayoutOrder = 1
	discordSlot.AutomaticSize = Enum.AutomaticSize.Y
	discordSlot.Size = UDim2.new(1, 0, 0, 0)
	discordSlot:SetAttribute("ZinoosSlot", true)
	discordSlot.Parent = discordPage
	local discordMotion = Instance.new("CanvasGroup")
	discordMotion.Name = "Motion"
	discordMotion.BackgroundTransparency = 1
	discordMotion.AutomaticSize = Enum.AutomaticSize.Y
	discordMotion.Size = UDim2.new(1, 0, 0, 0)
	discordMotion.Parent = discordSlot
	local discordBlurb = label(discordMotion, "Get a Discord message when an eligible egg matching the selected rarity shows up, when you steal it, and when it hatches.", 14, muted, Enum.Font.Gotham, 48)
	discordBlurb.LayoutOrder = 1
	local discordCard = card(discordPage, "WEBHOOK", 2)
	makeSwitch(discordCard, "Webhook Alerts", "webhookOn")
	local urlBox = Instance.new("TextBox")
	urlBox.BackgroundColor3 = panel
	urlBox.BackgroundTransparency = cardFade
	urlBox.BorderSizePixel = 0
	urlBox.ClearTextOnFocus = false
	urlBox.Font = Enum.Font.Gotham
	urlBox.PlaceholderText = "https://discord.com/api/webhooks/..."
	urlBox.PlaceholderColor3 = muted
	urlBox.Text = STATE.webhook or ""
	urlBox.TextColor3 = ink
	role(urlBox, "field")
	urlBox.TextSize = 13
	urlBox.TextXAlignment = Enum.TextXAlignment.Left
	urlBox.LayoutOrder = 3
	urlBox.Size = UDim2.new(1, 0, 0, 36)
	urlBox.ZIndex = 6
	urlBox.Parent = discordCard
	local webhookMask = Instance.new("TextLabel")
	webhookMask.Name = "Mask"
	webhookMask.BackgroundTransparency = 1
	webhookMask.Font = Enum.Font.Gotham
	webhookMask.Text = "••••••••••••"
	webhookMask.TextColor3 = ink
	webhookMask.TextSize = 13
	webhookMask.TextXAlignment = Enum.TextXAlignment.Left
	webhookMask.Size = UDim2.fromScale(1, 1)
	webhookMask.ZIndex = 7
	webhookMask.Visible = false
	webhookMask.Parent = urlBox
	local urlCorner = Instance.new("UICorner")
	urlCorner.CornerRadius = UDim.new(0, 8)
	urlCorner.Parent = urlBox
	local urlStroke = Instance.new("UIStroke")
	urlStroke.Color = accent
	urlStroke.Transparency = 0.58
	urlStroke.Thickness = 1
	urlStroke.Parent = urlBox
	local urlPad = Instance.new("UIPadding")
	urlPad.PaddingLeft = UDim.new(0, 8)
	urlPad.PaddingRight = UDim.new(0, 8)
	urlPad.Parent = urlBox
	STATE.webhookReveal = false
	STATE._webhookBox = urlBox
	function STATE.applyWebhookMask()
		local box = STATE._webhookBox
		if not box or not box.Parent then
			return
		end
		local mask = box:FindFirstChild("Mask")
		local hidden = STATE.webhookReveal ~= true and box:IsFocused() ~= true
		local hasValue = type(box.Text) == "string" and box.Text ~= ""
		box.TextTransparency = (hidden and hasValue) and 1 or 0
		if mask and mask:IsA("TextLabel") then
			mask.Visible = hidden and hasValue
			mask.TextColor3 = box.TextColor3
		end
	end
	urlBox.Focused:Connect(function()
		STATE.applyWebhookMask()
	end)
	urlBox.FocusLost:Connect(function()
		local text = urlBox.Text
		if type(text) ~= "string" then
			text = ""
		end
		STATE.webhook = text
		STATE.webhookControl.value = text
		STATE.webhookControl.currentValue = text
		saveConfig()
		STATE.applyWebhookMask()
	end)
	STATE.applyWebhookMask()
	remember(urlBox, discordCard, "discord webhook")

	local function actionButton(parentFrame, text, order, filled, callback)
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.Font = Enum.Font.GothamBold
		button.Text = text
		button.TextSize = 14
		button.TextColor3 = filled and inkDark or ink
		button.BackgroundColor3 = filled and accent or panel
		button.BackgroundTransparency = filled and 0 or cardFade
		role(button, filled and "accentFill" or "card")
		button:SetAttribute("ZinoosTextRole", filled and "inkDark" or "ink")
		button.LayoutOrder = order
		button.Size = UDim2.new(1, 0, 0, 34)
		button.ZIndex = 6
		button.Parent = parentFrame
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button
		if not filled then
			local buttonStroke = Instance.new("UIStroke")
			buttonStroke.Color = accent
			buttonStroke.Transparency = 0.5
			buttonStroke.Thickness = 1
			buttonStroke.Parent = button
		end
		bindPress(button)
		button.MouseEnter:Connect(function()
			local themeNow = STATE.hubThemeDef()
			local base = filled and themeNow.accent or themeNow.card
			playMotion(button, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.08) }, tweenInfo.hover)
		end)
		button.MouseLeave:Connect(function()
			local themeNow = STATE.hubThemeDef()
			playMotion(button, { BackgroundColor3 = filled and themeNow.accent or themeNow.card }, tweenInfo.hover)
		end)
		onActivate(button, callback)
		remember(button, parentFrame, text)
		return button
	end

	local revealButton
	revealButton = actionButton(discordCard, "Show webhook", 4, false, function()
		STATE.webhookReveal = STATE.webhookReveal ~= true
		if revealButton then
			revealButton.Text = STATE.webhookReveal == true and "Hide webhook" or "Show webhook"
		end
		STATE.applyWebhookMask()
	end)
	local hookStatus = label(discordCard, "", 13, muted, Enum.Font.Gotham, 32)
	hookStatus.LayoutOrder = 5
	hookStatus.TextWrapped = true
	local function showHookResult(text, ok)
		hookStatus.Text = text
		hookStatus.TextColor3 = ok and accent or Color3.fromRGB(255, 120, 150)
	end
	actionButton(discordCard, "Test Webhook", 6, false, function()
		local url = webhookUrl()
		if not url then
			showHookResult("That webhook link is not a Discord webhook.", false)
			return
		end
		if not webhookRequest() then
			showHookResult("Request is not available.", false)
			return
		end
		showHookResult("Sending...", true)
		task.spawn(function()
			local ok, message = sendWebhook(url, {
				username = "Zinoos hub",
				content = "Webhook connected. You'll get a ping when an eligible egg matching the selected rarity shows up, is stolen, or hatches.",
			})
			if gui.Parent then
				showHookResult(message, ok)
			end
		end)
	end)
	actionButton(discordCard, "Unload", 7, true, function()
		task.defer(unloadHub)
	end)

	local function applySearch()
		local query = string.lower(search.Text)
		local used = {}
		local pages = {}
		for _, item in ipairs(searchRows) do
			local show = query == "" or string.find(item.text, query, 1, true) ~= nil
			item.row.Visible = show
			if show and query ~= "" then
				used[item.card] = true
				pages[item.page or "Main"] = true
			end
		end
		for _, item in ipairs(searchRows) do
			item.card.Visible = query == "" or used[item.card] == true
		end
		if query == "" then
			return
		end
		local current = "Main"
		if homePage.Visible then
			current = "Home"
		elseif discordPage.Visible then
			current = "Discord"
		end
		if pages[current] then
			return
		end
		if pages.Home and not pages.Main and not pages.Discord then
			showPage("Home")
		elseif pages.Main and not pages.Home and not pages.Discord then
			showPage("Main")
		elseif pages.Discord and not pages.Home and not pages.Main then
			showPage("Discord")
		elseif pages.Home then
			showPage("Home")
		elseif pages.Main then
			showPage("Main")
		elseif pages.Discord then
			showPage("Discord")
		end
	end
	trackConnection(search:GetPropertyChangedSignal("Text"):Connect(applySearch))

	local function refreshHome()
		local data = readData()
		local strength = LocalPlayer:GetAttribute("Strength")
		if type(strength) ~= "number" then
			strength = data and data.strength or 0
		end
		local speed = LocalPlayer:GetAttribute("Speed")
		if type(speed) ~= "number" then
			speed = data and data.speed or 0
		end
		local rebirths = LocalPlayer:GetAttribute("Rebirths")
		if type(rebirths) ~= "number" then
			rebirths = data and data.rebirths or 0
		end
		strengthText.Text = shortNumber(strength or 0)
		cashText.Text = "$" .. shortNumber((data and data.cash) or 0)
		rebirthText.Text = tostring(rebirths or 0)
		speedText.Text = shortNumber(speed or 0)
	end
	refreshHome()
	refreshTracker()
	local function refreshSession()
		local clockText = sessionClock()
		sessionText.Text = "Session " .. clockText
		dockClock.Text = clockText
		local fps = fpsCount
		fpsCount = 0
		local ping = 0
		pcall(function()
			ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
		end)
		dockStats.Text = string.format("%d fps    %d ms", fps, ping)
		local fill = math.clamp(fps / 80, 0.08, 1)
		fpsBar.Size = UDim2.fromScale(fill, 1)
		local themeNow = STATE.hubThemeDef()
		fpsBar.BackgroundColor3 = fps >= 30 and themeNow.accent or (themeNow.risky or Color3.new(1, 1, 1))
	end
	refreshSession()
	task.spawn(function()
		while running() and gui.Parent do
			pcall(refreshHome)
			pcall(refreshTracker)
			if refreshHealth then
				pcall(refreshHealth)
			end
			pcall(refreshSession)
			task.wait(1)
		end
	end)

	local function applyLook()
		local themeNow = STATE.hubThemeDef()
		for _, obj in ipairs(gui:GetDescendants()) do
			if obj:IsA("UIStroke") and obj:GetAttribute("ZinoosRole") == nil then
				obj:SetAttribute("ZinoosRole", "stroke")
			end
			local kind = obj:GetAttribute("ZinoosRole")
			local textKind = obj:GetAttribute("ZinoosTextRole")
			if kind == "panel" and obj:IsA("GuiObject") then
				obj.BackgroundColor3 = themeNow.panel
			elseif kind == "side" and obj:IsA("GuiObject") then
				obj.BackgroundColor3 = themeNow.side
			elseif kind == "card" and obj:IsA("GuiObject") then
				obj.BackgroundColor3 = themeNow.card
				obj.BackgroundTransparency = themeNow.cardFade
			elseif kind == "field" and obj:IsA("GuiObject") then
				obj.BackgroundColor3 = themeNow.card
				obj.BackgroundTransparency = themeNow.cardFade
				if obj:IsA("TextButton") or obj:IsA("TextBox") or obj:IsA("TextLabel") then
					obj.TextColor3 = themeNow.ink
				end
				if obj:IsA("TextBox") then
					obj.PlaceholderColor3 = themeNow.muted
				end
			elseif kind == "accentFill" and obj:IsA("GuiObject") then
				obj.BackgroundColor3 = themeNow.accent
				obj.BackgroundTransparency = 0
			elseif kind == "ink" and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
				obj.TextColor3 = themeNow.ink
			elseif kind == "muted" and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
				obj.TextColor3 = themeNow.muted
			elseif kind == "inkDark" and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
				obj.TextColor3 = themeNow.inkDark
			elseif kind == "accentText" and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
				obj.TextColor3 = themeNow.accent
			elseif kind == "stroke" and obj:IsA("UIStroke") then
				obj.Color = themeNow.stroke
				obj.Transparency = themeNow.strokeFade
			elseif kind == "iconStroke" and obj:IsA("UIStroke") then
				obj.Color = themeNow.ink
			end
			if textKind == "inkDark" and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
				obj.TextColor3 = themeNow.inkDark
			elseif textKind == "ink" and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
				obj.TextColor3 = themeNow.ink
			end
		end
		barTrack.BackgroundColor3 = themeNow.accent
		barTrack.BackgroundTransparency = themeNow.barFade
		if themeNow.wallpaper and type(STATE.themeWall) == "string" then
			wallpaperImage.Image = STATE.themeWall
			wallpaperImage.ImageTransparency = themeNow.wallFade
		else
			wallpaperImage.ImageTransparency = 1
		end
		if themeNow.icon and type(STATE.themeIcon) == "string" then
			markImage.Image = STATE.themeIcon
			markImage.ImageTransparency = 0
			mark.BackgroundTransparency = 1
			markText.Visible = false
		else
			markImage.ImageTransparency = 1
			mark.BackgroundColor3 = themeNow.accent
			mark.BackgroundTransparency = 0
			markText.TextColor3 = themeNow.inkDark
			markText.Visible = true
		end
		for _, entry in ipairs(STATE.themeSwitches) do
			if entry.track.Parent then
				paintSwitch(entry.track, entry.knob, STATE[entry.key] == true, true)
			end
		end
		for buttonName, button in pairs(navButtons) do
			local on = buttonName == currentPage
			button.BackgroundColor3 = on and themeNow.selected or themeNow.hover
			button.BackgroundTransparency = on and themeNow.selectedFade or 1
			local navLabel = button:FindFirstChild("Label")
			if navLabel and navLabel:IsA("TextLabel") then
				navLabel.TextColor3 = themeNow.ink
			end
		end
		if STATE.refreshTracker then
			pcall(STATE.refreshTracker)
		end
	end
	STATE.applyLook = applyLook
	applyLook()

	showPage("Home")

	local function placeTopLeft(obj, absX, absY)
		local parentPos = obj.Parent.AbsolutePosition
		local scale = uiScale.Scale
		if scale < 0.05 then
			scale = 1
		end
		local size = obj.AbsoluteSize
		local anchor = obj.AnchorPoint
		obj.Position = UDim2.fromOffset((absX - parentPos.X + anchor.X * size.X) / scale, (absY - parentPos.Y + anchor.Y * size.Y) / scale)
	end

	local function clampObject(obj)
		local view = viewSize()
		local size = obj.AbsoluteSize
		local pos = obj.AbsolutePosition
		local x = math.clamp(pos.X, 0, math.max(0, view.X - size.X))
		local y = math.clamp(pos.Y, 0, math.max(0, view.Y - size.Y))
		if math.abs(x - pos.X) > 1 or math.abs(y - pos.Y) > 1 then
			placeTopLeft(obj, x, y)
		end
	end

	local function rememberSpot(obj, keyX, keyY)
		local view = viewSize()
		if view.X < 1 or view.Y < 1 then
			return
		end
		local pos = obj.AbsolutePosition
		STATE[keyX] = pos.X / view.X
		STATE[keyY] = pos.Y / view.Y
		saveConfig()
	end

	local function rememberLayout()
		if not gui.Parent then
			return
		end
		clampObject(holder)
		clampObject(launcher)
		local view = viewSize()
		if view.X < 1 or view.Y < 1 then
			return
		end
		local changed = false
		if type(STATE.menuX) == "number" and type(STATE.menuY) == "number" then
			local menuPos = holder.AbsolutePosition
			local nextX = menuPos.X / view.X
			local nextY = menuPos.Y / view.Y
			if math.abs(nextX - STATE.menuX) > 0.002 or math.abs(nextY - STATE.menuY) > 0.002 then
				STATE.menuX = nextX
				STATE.menuY = nextY
				changed = true
			end
		end
		if STATE.dockCustom and type(STATE.dockX) == "number" and type(STATE.dockY) == "number" then
			local dockPos = launcher.AbsolutePosition
			local nextX = dockPos.X / view.X
			local nextY = dockPos.Y / view.Y
			if math.abs(nextX - STATE.dockX) > 0.002 or math.abs(nextY - STATE.dockY) > 0.002 then
				STATE.dockX = nextX
				STATE.dockY = nextY
				changed = true
			end
		end
		if changed then
			saveConfig()
		end
	end
	applyHubLayout = function(_, compact, baseW)
		local narrow = compact or baseW < 860
		sideWrap.Size = compact and UDim2.new(0, 72, 1, 0) or UDim2.new(0.25, 0, 1, 0)
		content.Position = compact and UDim2.fromOffset(72, 0) or UDim2.new(0.25, 0, 0, 0)
		content.Size = compact and UDim2.new(1, -72, 1, 0) or UDim2.new(0.75, 0, 1, 0)
		brand.Visible = not compact
		brandSub.Visible = not compact
		profile.Visible = not compact
		columnLayout.FillDirection = narrow and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
		local columnSize = narrow and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -6, 0, 0)
		leftColumn.Size = columnSize
		rightColumn.Size = columnSize
		for index, name in ipairs({ "Home", "Main", "Discord" }) do
			local button = navButtons[name]
			if button then
				local label = button:FindFirstChild("Label")
				if label then
					label.Visible = not compact
				end
				button.Size = compact and UDim2.fromOffset(48, 44) or UDim2.new(1, -24, 0, 36)
				button.Position = UDim2.fromOffset(12, compact and (70 + (index - 1) * 52) or (78 + (index - 1) * 42))
			end
		end
		for _, page in pairs(pages) do
			local pad = page:FindFirstChildOfClass("UIPadding")
			if pad then
				pad.PaddingLeft = UDim.new(0, compact and 12 or 28)
				pad.PaddingRight = UDim.new(0, compact and 12 or 28)
			end
		end
		search.Size = UDim2.fromOffset(compact and 140 or 200, compact and 40 or 34)
	end
	fitScale()
	local function refit()
		fitScale()
		task.defer(rememberLayout)
	end
	local viewSignal = nil
	local function bindView()
		if viewSignal then
			pcall(function()
				viewSignal:Disconnect()
			end)
			viewSignal = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			viewSignal = trackConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit))
		end
	end
	trackConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		refit()
		bindView()
	end))
	bindView()

	task.defer(function()
		if not gui.Parent then
			return
		end
		local view = viewSize()
		if type(STATE.menuX) == "number" and type(STATE.menuY) == "number" then
			placeTopLeft(holder, STATE.menuX * view.X, STATE.menuY * view.Y)
			clampObject(holder)
		end
		if STATE.dockCustom and type(STATE.dockX) == "number" and type(STATE.dockY) == "number" then
			placeTopLeft(launcher, STATE.dockX * view.X, STATE.dockY * view.Y)
			clampObject(launcher)
		end
	end)

	local dragTarget = nil
	local dragStart = nil
	local dragOrigin = nil
	local dragMoved = false

	local function beginDrag(target, input)
		dragTarget = target
		dragStart = input.Position
		dragOrigin = target.AbsolutePosition
		dragMoved = false
	end

	local function canDragFrom(input)
		local hits = gui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
		for _, hit in ipairs(hits) do
			if hit:IsA("GuiButton") or hit:IsA("TextBox") then
				return false
			end
		end
		return true
	end

	header.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if canDragFrom(input) then
			beginDrag(holder, input)
		end
	end)
	sidebar.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if canDragFrom(input) then
			beginDrag(holder, input)
		end
	end)
	launcher.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(launcher, input)
		end
	end)

	local openToken = 0
	local function setOpen(open)
		openToken += 1
		local token = openToken
		if open then
			STATE.webhookReveal = false
			if STATE.applyWebhookMask then
				STATE.applyWebhookMask()
			end
			playMotion(launcher, { GroupTransparency = 1 }, tweenInfo.hover)
			holder.Visible = true
			shadow.Visible = true
			windowScale.Scale = 0.9
			sideWrap.GroupTransparency = 1
			headWrap.GroupTransparency = 1
			pageWrap.GroupTransparency = 1
			playMotion(windowScale, { Scale = 1 }, tweenInfo.open)
			task.delay(0.12, function()
				if token ~= openToken or not gui.Parent then
					return
				end
				launcher.Visible = false
				launcher.GroupTransparency = 0
			end)
			task.delay(0.22, function()
				if token ~= openToken or not gui.Parent then
					return
				end
				playMotion(sideWrap, { GroupTransparency = 0 }, tweenInfo.fade)
				task.delay(0.04, function()
					if token ~= openToken or not gui.Parent then
						return
					end
					playMotion(headWrap, { GroupTransparency = 0 }, tweenInfo.fade)
				end)
				task.delay(0.08, function()
					if token ~= openToken or not gui.Parent then
						return
					end
					playMotion(pageWrap, { GroupTransparency = 0 }, tweenInfo.fade)
					playCards(pages[currentPage])
				end)
			end)
			return
		end
		closePopup()
		playMotion(pageWrap, { GroupTransparency = 1 }, tweenInfo.fade)
		playMotion(headWrap, { GroupTransparency = 1 }, tweenInfo.fade)
		playMotion(sideWrap, { GroupTransparency = 1 }, tweenInfo.fade)
		playMotion(windowScale, { Scale = 0.9 }, tweenInfo.open)
		task.delay(0.26, function()
			if token ~= openToken or not gui.Parent then
				return
			end
			holder.Visible = false
			shadow.Visible = false
			windowScale.Scale = 1
			launcher.Visible = true
			launcher.GroupTransparency = 1
			playMotion(launcher, { GroupTransparency = 0 }, tweenInfo.fade)
		end)
	end

	local dragConn = trackConnection(UserInputService.InputChanged:Connect(function(input)
		if not dragTarget or not dragStart or not dragOrigin then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		if not dragMoved and delta.Magnitude < 8 then
			return
		end
		dragMoved = true
		placeTopLeft(dragTarget, dragOrigin.X + delta.X, dragOrigin.Y + delta.Y)
	end))
	local dragEndConn = trackConnection(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local target = dragTarget
		local moved = dragMoved
		dragTarget = nil
		dragStart = nil
		dragOrigin = nil
		dragMoved = false
		if not target or not target.Parent then
			return
		end
		if moved then
			clampObject(target)
			if target == holder then
				rememberSpot(holder, "menuX", "menuY")
			else
				STATE.dockCustom = true
				rememberSpot(launcher, "dockX", "dockY")
			end
			return
		end
		if target == launcher then
			setOpen(true)
		end
	end))

	bindPress(closeButton)
	bindPress(fullButton)
	fullButton.MouseEnter:Connect(function()
		playMotion(fullButton, { TextColor3 = STATE.hubThemeDef().ink }, tweenInfo.hover)
	end)
	fullButton.MouseLeave:Connect(function()
		playMotion(fullButton, { TextColor3 = STATE.hubThemeDef().muted }, tweenInfo.hover)
	end)
	onActivate(fullButton, function()
		fullMode = not fullMode
		fullButton.Text = fullMode and "▣" or "⛶"
		fitScale()
	end)
	onActivate(closeButton, function()
		if not STATE.dockCustom then
			local spot = holder.AbsolutePosition
			placeTopLeft(launcher, spot.X + 16, spot.Y + 16)
		end
		setOpen(false)
	end)

	local keyConn = trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or search:IsFocused() or urlBox:IsFocused() then
			return
		end
		if input.KeyCode == Enum.KeyCode.RightControl then
			setOpen(not holder.Visible)
		end
	end))

	local saveCard = card(homePage, "CONFIG", 8)
	local saveNote = label(saveCard, "Saves the toggles, rarities, zone, and priority for this account. Your other account keeps its own save.", 13, muted, Enum.Font.Gotham, 40)
	saveNote.LayoutOrder = 1
	local saveResult = label(saveCard, "", 13, accent, Enum.Font.Gotham, 18)
	saveResult.LayoutOrder = 3
	actionButton(saveCard, "Save Config", 2, true, function()
		saveConfig()
		saveResult.Text = "Saved for " .. LocalPlayer.DisplayName
		saveResult.TextColor3 = accent
	end)

	windowScale.Scale = 0.9
	sideWrap.GroupTransparency = 1
	headWrap.GroupTransparency = 1
	pageWrap.GroupTransparency = 1
	holder.Visible = false
	shadow.Visible = false
	launcher.Visible = true

	STATE.hubWindow = {
		Unload = function()
			unloadHub()
		end,
	}
end

local configMigrated = loadSaved()
if configMigrated then
	resetStealScan()
	saveConfig()
end

task.spawn(function()
	if not running() then
		return
	end
	local ok, err = pcall(installHub)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
		if running() then
			shutdownHub("failed")
		end
	end
end)

task.spawn(function()
	while running() do
		STATE.watchFeature("Auto Upgrade", stepUpgrade)
		task.wait(0.4)
		if not running() then
			break
		end
		STATE.watchFeature("Auto Trails", stepTrails)
		task.wait(1.2)
	end
end)

task.spawn(function()
	while running() do
		STATE.stealTick = os.clock()
		local ok, result = pcall(runStealTrip)
		STATE.noteFault("Auto Steal", ok, result)
		if not ok then
			local message = tostring(result)
			STATE.liftSteal = false
			STATE.stealGoal = nil
			STATE.stealTarget = nil
			activeGoal = nil
			restoreStealChanges()
			STATE.nextSteal = os.clock() + 8
			STATE.stealError = message
			STATE.lastStealStatus = {
				outcome = "Retrying after script error",
				eggName = nil,
				attempt = nil,
				failureReason = message,
				pickupSucceeded = false,
				deliverySucceeded = false,
				timestamp = os.clock(),
			}
			warn("[Zinoos hub] steal " .. message)
		elseif type(result) == "table" then
			STATE.lastStealStatus = result
		end
		if not (STATE.autoSteal == true and pendingDelivery()) then
			local placedOk = STATE.watchFeature("Auto Place", STATE.stepAutoPlace)
			if not placedOk then
				STATE.placeBusy = false
			end
		end
		task.wait(0.6)
	end
end)

local openTried = {}

local function stepOpenEggs()
	if STATE.autoOpen ~= true or not featureReady("Auto Open") then
		return
	end
	local data = readData()
	local pets = data and data.plotPets
	if type(pets) ~= "table" then
		return
	end
	local now = os.time()
	local sent = 0
	for uid, pet in pairs(pets) do
		if sent >= 2 then
			break
		end
		if type(pet) == "table" and pet.hatchAt and pet.hatchAt <= now then
			local eggUid = type(pet.uid) == "string" and pet.uid or (type(uid) == "string" and uid or nil)
			local last = eggUid and openTried[eggUid]
			if eggUid and (not last or os.clock() - last > 3) then
				openTried[eggUid] = os.clock()
				Net:FireServer("OpenEgg", eggUid)
				sent += 1
			end
		elseif openTried[uid] then
			openTried[uid] = nil
		end
	end
end


local function shownIncome(pet)
	if typeof(Pets) ~= "table" or typeof(Pets.IncomeFor) ~= "function" then
		return 0
	end
	local ok, base = pcall(Pets.IncomeFor, pet)
	base = ok and type(base) == "number" and base or 0
	local level = 1
	local grade = 1
	pcall(function()
		level = Plot.PetLevelMultiplier(pet.level) or 1
	end)
	pcall(function()
		grade = Grades.Multiplier(pet.grade) or 1
	end)
	local data = readData()
	local rebirths = data and data.rebirths or 0
	local row = typeof(Rebirths) == "table" and Rebirths[rebirths] or nil
	local cash = type(row) == "table" and row.CashMulti or 1
	if type(cash) ~= "number" then
		cash = 1
	end
	return base * level * grade * cash
end

function STATE.plotEggText(pet)
	local spec = petSpec(pet.rolledKey) or petSpec(pet.key)
	local name = (spec and (spec.DisplayName or spec.Name)) or "Egg"
	local rarity = spec and type(spec.Rarity) == "string" and spec.Rarity or ""
	local mutation = pet.mutation
	if type(mutation) ~= "string" or mutation == "" or mutation == "None" then
		mutation = nil
	end
	local incomePet = {}
	for key, value in pairs(pet) do
		incomePet[key] = value
	end
	if pet.rolledKey ~= nil then
		incomePet.key = pet.rolledKey
	end
	incomePet.hatchAt = nil
	local money = shownIncome(incomePet)
	local clock = ""
	if type(pet.hatchAt) == "number" then
		local remain = math.max(0, math.floor(pet.hatchAt - os.time()))
		local hours = math.floor(remain / 3600)
		local mins = math.floor((remain % 3600) / 60)
		local secs = remain % 60
		if hours > 0 then
			clock = string.format("%d:%02d:%02d", hours, mins, secs)
		else
			clock = string.format("%d:%02d", mins, secs)
		end
	end
	local head = name
	if rarity ~= "" then
		head = head .. "  " .. rarity
	end
	if mutation then
		head = head .. "  " .. mutation
	end
	return head .. "\n$" .. shortNumber(money) .. "/s   " .. clock
end

function STATE.makePlotEggTag(model)
	local adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not adornee then
		return nil
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZinoosPlotEgg"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 240
	billboard.Size = UDim2.fromOffset(220, 36)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Color3.fromRGB(166, 214, 184)
	label.TextSize = 14
	label.TextStrokeTransparency = 0.35
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard
	billboard.Parent = model
	return billboard
end

function STATE.clearPlotEggs()
	local live = workspace:FindFirstChild("Live")
	local owned = live and live:FindFirstChild("PlayerFriends")
	local mine = owned and owned:FindFirstChild(LocalPlayer.Name)
	if not mine then
		return
	end
	for _, model in ipairs(mine:GetChildren()) do
		local tag = model:FindFirstChild("ZinoosPlotEgg")
		if tag then
			tag:Destroy()
		end
	end
end

function STATE.paintPlotEggs()
	if STATE.eggEsp ~= true then
		STATE.clearPlotEggs()
		return
	end
	local data = readData()
	local pets = data and data.plotPets
	local live = workspace:FindFirstChild("Live")
	local owned = live and live:FindFirstChild("PlayerFriends")
	local mine = owned and owned:FindFirstChild(LocalPlayer.Name)
	if not mine or type(pets) ~= "table" then
		return
	end
	for _, model in ipairs(mine:GetChildren()) do
		if model:IsA("Model") then
			local pet = pets[model.Name]
			local growing = model:GetAttribute("incubating") == true and type(pet) == "table" and pet.hatchAt ~= nil
			local tag = model:FindFirstChild("ZinoosPlotEgg")
			if not growing then
				if tag then
					tag:Destroy()
				end
			else
				if not tag then
					tag = STATE.makePlotEggTag(model)
				end
				local label = tag and tag:FindFirstChild("Value")
				if label then
					local text = STATE.plotEggText(pet)
					if label.Text ~= text then
						label.Text = text
					end
				end
				if tag then
					local dist = STATE.lowEnd == true and 120 or 240
					if tag.MaxDistance ~= dist then
						tag.MaxDistance = dist
					end
				end
			end
		end
	end
end

function STATE.equipPetInBackpack(data, uid)
	local bag = type(data) == "table" and data.backpack or nil
	if type(bag) ~= "table" or type(uid) ~= "string" then
		return false
	end
	if type(bag[uid]) == "table" then
		return true
	end
	for _, pet in pairs(bag) do
		if type(pet) == "table" and pet.uid ~= nil and tostring(pet.uid) == uid then
			return true
		end
	end
	return false
end

function STATE.noteEquipPhase(txn, phase)
	if type(txn) ~= "table" then
		return
	end
	txn.phase = phase
	if type(txn.oldUid) ~= "string" then
		return
	end
	if phase == "confirmed" or phase == "done" then
		local record = STATE._equipRecovery
		if type(record) == "table" and record.oldUid == txn.oldUid and record.newUid == txn.newUid and record.gen == txn.gen then
			STATE._equipRecovery = nil
		end
		return
	end
	if phase ~= "picked-up" and phase ~= "placing" and phase ~= "restoring" then
		return
	end
	STATE._equipRecovery = {
		gen = txn.gen,
		token = txn.token,
		oldUid = txn.oldUid,
		oldX = txn.oldX,
		oldZ = txn.oldZ,
		newUid = txn.newUid,
		phase = phase,
	}
end

function STATE.equipRecoveryPlan(record, data)
	if type(record) ~= "table" or type(record.oldUid) ~= "string" or type(record.newUid) ~= "string" then
		return "clear"
	end
	if record.phase ~= "picked-up" and record.phase ~= "placing" and record.phase ~= "restoring" then
		return "clear"
	end
	if type(record.oldX) ~= "number" or type(record.oldZ) ~= "number" then
		return "clear"
	end
	if type(data) ~= "table" or type(data.plotPets) ~= "table" or type(data.backpack) ~= "table" then
		if type(record.pendingAt) ~= "number" then
			record.pendingAt = os.clock()
		end
		if os.clock() >= record.pendingAt + 2.4 then
			return "clear"
		end
		return "wait"
	end
	record.pendingAt = nil
	if STATE.plotPetRecord(data, record.newUid) ~= nil or STATE.plotPetRecord(data, record.oldUid) ~= nil then
		record.absentAt = nil
		return "clear"
	end
	if STATE.equipPetInBackpack(data, record.oldUid) then
		record.absentAt = nil
		if record.phase == "placing" or record.phase == "restoring" then
			return "settle"
		end
		return "restore"
	end
	if type(record.absentAt) ~= "number" then
		record.absentAt = os.clock()
	end
	if os.clock() >= record.absentAt + 2.4 then
		return "clear"
	end
	return "wait"
end

function STATE.observeEquipRecovery(record)
	local testing = type(STATE._plotTestInvoke) == "function" or type(STATE._plotTestData) == "function"
	local function look()
		return STATE.equipRecoveryPlan(record, STATE.plotData())
	end
	if type(record) ~= "table" or record.phase == "picked-up" then
		return look()
	end
	local ticks = 0
	local deadline = os.clock() + 2.4
	while true do
		local plan = look()
		if plan == "clear" or plan == "restore" then
			return plan
		end
		if testing then
			ticks += 1
			if ticks >= 6 then
				break
			end
		elseif os.clock() >= deadline then
			break
		else
			task.wait(0.12)
		end
	end
	local plan = look()
	if plan == "settle" then
		return "restore"
	end
	return plan
end

function STATE.restoreEquipPet(lock, txn)
	if type(txn) ~= "table" or type(txn.oldUid) ~= "string" or type(txn.oldX) ~= "number" or type(txn.oldZ) ~= "number" then
		return false, "Selection became invalid"
	end
	if not running() or txn.gen ~= STATE._gen or txn.token ~= genv.ZinoosGen or STATE._plotLock ~= lock then
		return false, "Generation replaced"
	end
	local data = STATE.plotData()
	if STATE.plotPetRecord(data, txn.newUid) ~= nil then
		STATE.noteEquipPhase(txn, "confirmed")
		return true, "confirmed"
	end
	if STATE.plotPetRecord(data, txn.oldUid) ~= nil then
		STATE.noteEquipPhase(txn, "done")
		return true, "already"
	end
	STATE.noteEquipPhase(txn, "restoring")
	if not running() or txn.gen ~= STATE._gen or txn.token ~= genv.ZinoosGen or STATE._plotLock ~= lock then
		return false, "Generation replaced"
	end
	local fired = pcall(STATE.plotInvoke, "PlacePet", txn.oldUid, txn.oldX, txn.oldZ)
	if not fired then
		return false, "Remote rejected"
	end
	local back, backWhy = STATE.waitPlot(lock, false, function(fresh)
		return STATE.plotPetRecord(fresh, txn.oldUid) ~= nil or STATE.plotPetRecord(fresh, txn.newUid) ~= nil
	end)
	if not running() or txn.gen ~= STATE._gen or txn.token ~= genv.ZinoosGen then
		return false, "Generation replaced"
	end
	data = STATE.plotData()
	if STATE.plotPetRecord(data, txn.newUid) ~= nil then
		STATE.noteEquipPhase(txn, "confirmed")
		return true, "confirmed"
	end
	if STATE.plotPetRecord(data, txn.oldUid) ~= nil then
		STATE.noteEquipPhase(txn, "done")
		return true, "already"
	end
	if back ~= true then
		return false, backWhy or "Timed out waiting for confirmation"
	end
	return false, "Timed out waiting for confirmation"
end

function STATE.recoverEquipSwap()
	local record = STATE._equipRecovery
	if type(record) ~= "table" or not running() then
		return false
	end
	if STATE._equipRecovering ~= nil then
		return false
	end
	if os.clock() < (STATE._equipRetryAt or 0) then
		return false
	end
	if STATE._equipTxn ~= nil then
		return false
	end
	local token = {}
	STATE._equipRecovering = token
	local lock = STATE.acquirePlot("equip-recover", nil)
	local function release(result)
		if STATE._equipRecovering == token then
			STATE._equipRecovering = nil
		end
		STATE.releasePlot(lock)
		return result
	end
	if not lock then
		return release(false)
	end
	local plan = STATE.observeEquipRecovery(record)
	if plan == "wait" or plan == "settle" then
		return release(false)
	end
	if plan ~= "restore" then
		STATE._equipRecovery = nil
		return release(false)
	end
	if STATE._equipRecovery ~= record or STATE._equipTxn ~= nil or os.clock() < (STATE._equipRetryAt or 0) or not running() or STATE._plotLock ~= lock then
		return release(false)
	end
	local data = STATE.plotData()
	if type(data) ~= "table" or type(data.plotPets) ~= "table" or type(data.backpack) ~= "table" then
		return release(false)
	end
	if STATE.plotPetRecord(data, record.newUid) ~= nil or STATE.plotPetRecord(data, record.oldUid) ~= nil then
		STATE._equipRecovery = nil
		return release(false)
	end
	if not STATE.equipPetInBackpack(data, record.oldUid) then
		return release(false)
	end
	local fired = pcall(STATE.plotInvoke, "PlacePet", record.oldUid, record.oldX, record.oldZ)
	if not fired then
		STATE._equipRetryAt = os.clock() + 2
		return release(false)
	end
	local back = STATE.waitPlot(lock, false, function(fresh)
		return STATE.plotPetRecord(fresh, record.oldUid) ~= nil or STATE.plotPetRecord(fresh, record.newUid) ~= nil
	end)
	data = STATE.plotData()
	if STATE.plotPetRecord(data, record.newUid) ~= nil then
		STATE._equipRecovery = nil
		STATE._equipRetryAt = 0
		return release(false)
	end
	if STATE.plotPetRecord(data, record.oldUid) ~= nil then
		STATE._equipRecovery = nil
		STATE._equipRetryAt = 0
		return release(true)
	end
	if back ~= true then
		STATE._equipRetryAt = os.clock() + 2
		return release(false)
	end
	STATE._equipRetryAt = os.clock() + 2
	return release(false)
end

function STATE.noteEquipIdle(best, worst, openSlot, hasBest)
	local nothingBetter = hasBest ~= true or (openSlot ~= true and type(best) == "number" and type(worst) == "number" and best <= worst)
	if not nothingBetter then
		return false
	end
	STATE.equipStatus = "Up to date"
	STATE.nextEquip = os.clock() + 2.5
	return true
end

function STATE.commitEquip(placeUid, pickupUid, backX, backZ, openSlot)
	local lock = STATE.acquirePlot("equip", "equipBest")
	if not lock then
		return "Feature cancelled"
	end
	local function finish(status)
		STATE.releasePlot(lock)
		STATE._equipTxn = nil
		if type(status) == "string" then
			STATE.equipStatus = status
		elseif status == true then
			STATE.equipStatus = nil
		end
		return status
	end
	local testing = type(STATE._plotTestInvoke) == "function"
	local owns, why = STATE.plotOwns(lock, "equipBest")
	if not owns then
		return finish(why)
	end
	if type(placeUid) ~= "string" then
		return finish("Selection became invalid")
	end
	if openSlot ~= true and (type(pickupUid) ~= "string" or type(backX) ~= "number" or type(backZ) ~= "number") then
		return finish("Selection became invalid")
	end
	local x, z = 1, 2
	if not testing then
		if typeof(ClientRegistry) ~= "table" or typeof(ClientRegistry.Get) ~= "function" then
			return finish("Away from plot")
		end
		local plot = ClientRegistry.Get("PlotController"):GetPlot(LocalPlayer)
		local base = plot and plot:FindFirstChild("Base")
		if not (base and base:IsA("BasePart")) then
			return finish("Away from plot")
		end
		local character = LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return finish("Away from plot")
		end
		local offset = base.CFrame:PointToObjectSpace(hrp.Position)
		local reach = math.sqrt(base.Size.X * base.Size.X + base.Size.Z * base.Size.Z) / 2 + 30
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > reach then
			return finish("Away from plot")
		end
		local taken = {}
		local fresh = STATE.plotData()
		for _, pet in pairs(fresh and fresh.plotPets or {}) do
			local px, pz = STATE.petCoords(pet)
			if type(px) == "number" and type(pz) == "number" then
				taken[#taken + 1] = { px, pz }
			end
		end
		local halfX = math.max(8, base.Size.X * 0.42)
		local halfZ = math.max(6, base.Size.Z * 0.4)
		x, z = nil, nil
		for n = 1, 30 do
			local col = (n - 1) % 6
			local row = math.floor((n - 1) / 6)
			local tryX = -halfX + (col + 0.5) * ((halfX * 2) / 6)
			local tryZ = -halfZ + (row + 0.5) * ((halfZ * 2) / 5)
			local clear = true
			for _, pos in ipairs(taken) do
				local dx = tryX - pos[1]
				local dz = tryZ - pos[2]
				if dx * dx + dz * dz < 36 then
					clear = false
					break
				end
			end
			if clear then
				x, z = tryX, tryZ
				break
			end
		end
		if type(x) ~= "number" or type(z) ~= "number" then
			x = (math.random() - 0.5) * math.min(base.Size.X * 0.35, 16)
			z = (math.random() - 0.5) * math.min(base.Size.Z * 0.35, 16)
		end
	end
	local txn = {
		gen = STATE._gen,
		token = genv.ZinoosGen,
		oldUid = if openSlot == true then nil else pickupUid,
		oldX = backX,
		oldZ = backZ,
		newUid = placeUid,
		phase = "select",
	}
	STATE._equipTxn = txn
	local function sameGen()
		return running() and txn.gen == STATE._gen and txn.token == genv.ZinoosGen and STATE._plotLock == lock
	end
	local function restoreOld()
		if not sameGen() then
			return false, "Generation replaced"
		end
		return STATE.restoreEquipPet(lock, txn)
	end
	local function acceptRestore(fallback)
		local restored, restoreWhy = restoreOld()
		if restored == true then
			if restoreWhy == "confirmed" then
				return finish(true)
			end
			return finish(fallback)
		end
		if restoreWhy ~= "Generation replaced" then
			STATE._equipRetryAt = os.clock() + 2
		end
		return finish(restoreWhy or "Timed out waiting for confirmation")
	end
	if openSlot ~= true then
		owns, why = STATE.plotOwns(lock, "equipBest")
		if not owns then
			return finish(why)
		end
		if not pcall(STATE.plotInvoke, "PickupPet", pickupUid) then
			return finish("Remote rejected")
		end
		STATE.noteEquipPhase(txn, "picked-up")
		local left, leftWhy = STATE.waitPlot(lock, false, function(data)
			return STATE.plotPetRecord(data, pickupUid) == nil
		end)
		if not left then
			if not sameGen() or leftWhy == "Generation replaced" then
				return finish("Generation replaced")
			end
			if STATE.plotPetRecord(STATE.plotData(), pickupUid) ~= nil then
				STATE.noteEquipPhase(txn, "done")
				return finish(leftWhy or "Timed out waiting for confirmation")
			end
			return acceptRestore(leftWhy or "Feature cancelled")
		end
		if not sameGen() then
			return finish("Generation replaced")
		end
		if STATE.equipBest ~= true then
			return acceptRestore("Feature cancelled")
		end
	end
	owns, why = STATE.plotOwns(lock, "equipBest")
	if not owns then
		if openSlot ~= true then
			if not sameGen() or why == "Generation replaced" then
				return finish("Generation replaced")
			end
			return acceptRestore(why)
		end
		return finish(why)
	end
	STATE.noteEquipPhase(txn, "placing")
	local placed, placeSent = STATE.guardedPlace(lock, "equipBest", placeUid, x, z, function(data)
		return STATE.plotPetRecord(data, placeUid) ~= nil
	end)
	if placed == true then
		STATE.noteEquipPhase(txn, "confirmed")
		return finish(true)
	end
	if not sameGen() or placed == "Generation replaced" then
		return finish("Generation replaced")
	end
	local cancelledBeforeSend = placed == "Feature cancelled" and placeSent ~= true
	if cancelledBeforeSend or placed == "Confirmed full" or placed == "Remote rejected" or placed == "Selection became invalid" then
		if openSlot ~= true and placed ~= "Confirmed full" then
			return acceptRestore(placed)
		end
		return finish(placed)
	end
	local settled = STATE.waitPlot(lock, false, function(data)
		return STATE.plotPetRecord(data, placeUid) ~= nil
	end)
	if settled == true or STATE.plotPetRecord(STATE.plotData(), placeUid) ~= nil then
		STATE.noteEquipPhase(txn, "confirmed")
		return finish(true)
	end
	if not sameGen() then
		return finish("Generation replaced")
	end
	if openSlot ~= true then
		local fresh = STATE.plotData()
		if STATE.plotPetRecord(fresh, placeUid) ~= nil then
			STATE.noteEquipPhase(txn, "confirmed")
			return finish(true)
		end
		if STATE.plotPetRecord(fresh, pickupUid) ~= nil then
			STATE.noteEquipPhase(txn, "done")
			return finish(true)
		end
		if not STATE.equipPetInBackpack(fresh, pickupUid) then
			STATE._equipRetryAt = os.clock() + 2
			return finish("Timed out waiting for confirmation")
		end
		return acceptRestore("Timed out waiting for confirmation")
	end
	return finish(placed or "Timed out waiting for confirmation")
end

local function stepEquipBest()
	if not running() then
		return
	end
	if STATE._plotLock ~= nil then
		return
	end
	if STATE.recoverEquipSwap() == true or STATE._equipRecovery ~= nil then
		return
	end
	if STATE.equipBest ~= true or not featureReady("Equip Best") then
		return
	end
	if os.clock() < (STATE.nextEquip or 0) then
		return
	end
	local data = STATE.plotData()
	if not data then
		return
	end
	local room = STATE.plotRoom(data)
	if not room then
		STATE.equipStatus = "Selection became invalid"
		STATE.nextEquip = os.clock() + 4
		return
	end
	local worstPet = nil
	local worst = math.huge
	for uid, pet in pairs(data.plotPets or {}) do
		if type(pet) == "table" and pet.hatchAt == nil then
			local spec = petSpec(pet.key)
			if not (spec and spec.IsEgg) then
				local income = shownIncome(pet)
				if income < worst then
					worst = income
					worstPet = pet
					if pet.uid == nil then
						worstPet = { uid = uid, key = pet.key }
						for field, value in pairs(pet) do
							worstPet[field] = value
						end
					end
				end
			end
		end
	end
	local bestPet = nil
	local best = 0
	for _, pet in pairs(data.backpack or {}) do
		if type(pet) == "table" and pet.uid and pet.hatchAt == nil then
			local spec = petSpec(pet.key)
			if not (spec and spec.IsEgg) then
				local income = shownIncome(pet)
				if income > best then
					best = income
					bestPet = pet
				end
			end
		end
	end
	local openSlot = room.activeAnimals < room.activeSlots
	if STATE.noteEquipIdle(best, worst, openSlot, bestPet ~= nil) then
		return
	end
	local placeUid = bestPet.uid
	local pickupUid = worstPet and worstPet.uid
	if type(placeUid) ~= "string" then
		STATE.equipStatus = "Selection became invalid"
		return
	end
	local backX, backZ = nil, nil
	if not openSlot then
		backX, backZ = STATE.petCoords(worstPet)
		if type(pickupUid) ~= "string" or type(backX) ~= "number" or type(backZ) ~= "number" then
			STATE.equipStatus = "Selection became invalid"
			return
		end
	end
	STATE.nextEquip = os.clock() + 1.4
	task.spawn(function()
		local status = STATE.commitEquip(placeUid, pickupUid, backX, backZ, openSlot)
		if status ~= true and running() then
			STATE.nextEquip = math.max(STATE.nextEquip or 0, os.clock() + 4)
		end
	end)
end
STATE.stepEquipBest = stepEquipBest

local function syncToggles()
	local controls = STATE.toggleControls
	if type(controls) ~= "table" then
		return
	end
	for key, control in pairs(controls) do
		if type(control) == "table" and typeof(control.value) == "boolean" and STATE[key] ~= control.value then
			STATE[key] = control.value
			if key == "autoTrain" and control.value == false then
				lastSwitchAt = 0
				releaseGym()
			elseif key == "autoSteal" and control.value == true then
				resetStealScan()
			elseif key == "autoPlace" then
				STATE.placeBusy = false
				STATE.nextAutoPlace = 0
				STATE.placeStatus = control.value == true and "Scanning inventory" or nil
			elseif key == "lowEnd" then
				applyLowEnd(control.value == true)
			elseif key == "invEsp" and control.value == false then
				STATE._invShown = false
				clearInvEsp()
			end
		end
	end
	local hookControl = STATE.webhookControl
	if type(hookControl) == "table" then
		local text = hookControl.value
		if type(text) ~= "string" then
			text = hookControl.currentValue
		end
		if type(text) == "string" and text ~= STATE.webhook then
			STATE.webhook = text
		end
	end
	local rareControl = STATE.rarityControl
	if type(rareControl) == "table" and type(rareControl.currentOption) == "table" then
		local ordered = STATE.normalizeRarities(rareControl.currentOption)
		if STATE.rarityLabel(ordered) ~= STATE.rarityLabel(STATE.alertRarities) then
			STATE.alertRarities = ordered
			STATE.webhookRarity = ordered[1] or STATE.webhookRarity
			resetStealScan()
			saveConfig()
		end
	end
	local placeControl = STATE.placeControl
	if type(placeControl) == "table" and type(placeControl.currentOption) == "table" then
		local ordered = STATE.normalizeRarities(placeControl.currentOption)
		if STATE.rarityLabel(ordered) ~= STATE.rarityLabel(STATE.placeRarities) then
			STATE.placeRarities = ordered
			STATE.placeRarity = ordered[1] or STATE.placeRarity
			saveConfig()
		end
	end
end

local function pullHomeIfEmpty()
	if not running() then
		return
	end
	if STATE.placeBusy == true then
		return
	end
	if LocalPlayer:GetAttribute("Benching") or LocalPlayer:GetAttribute("TrainingMounted") == true then
		return
	end
	local eggs = prehistoricEggs()
	if STATE.liftSteal and eggs[1] and eggs[1].model.Parent then
		return
	end
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return
	end
	local home = homeSpot()
	if typeof(home) == "Vector3" and (hrp.Position - home).Magnitude < 18 then
		return
	end
	if hrp.Position.Z > -4000 and not inZone(hrp.Position, stealZone()) then
		return
	end
	STATE.liftSteal = false
	STATE.stealGoal = nil
	activeGoal = nil
	local gym = myGym()
	local bench = gym and gym:FindFirstChild("Bench")
	local seat = bench and bench:FindFirstChild("Seat")
	if seat then
		standOn(hrp, humanoid, seat)
		return
	end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(home)
end

local function paintAnimals()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local menu = playerGui and playerGui:FindFirstChild("ActiveBrainrotsNEW")
	if not menu or not menu.Enabled then
		return
	end
	local frame = menu:FindFirstChild("Frame")
	local container = frame and frame:FindFirstChild("Container")
	if not container then
		return
	end
	local data = readData()
	local pets = data and data.plotPets
	local bag = data and data.backpack
	if type(pets) ~= "table" and type(bag) ~= "table" then
		return
	end
	local function petFor(uid)
		local pet = type(pets) == "table" and pets[uid] or nil
		if type(pet) == "table" then
			return pet
		end
		if type(bag) ~= "table" then
			return nil
		end
		pet = bag[uid]
		if type(pet) == "table" then
			return pet
		end
		for _, item in pairs(bag) do
			if type(item) == "table" and item.uid == uid then
				return item
			end
		end
		return nil
	end
	for _, card in ipairs(container:GetChildren()) do
		local pet = petFor(card.Name)
		local label = card:FindFirstChild("DisplayName", true)
		if type(pet) == "table" and pet.hatchAt == nil and label and label:IsA("TextLabel") and string.find(label.Text, "/s", 1, true) then
			local money = shortNumber(shownIncome(pet))
			local text = string.gsub(label.Text, "%$[^<%)]+/s", "$" .. money .. "/s", 1)
			if label.Text ~= text then
				label.RichText = true
				label.Text = text
			end
		end
	end
end

local knownPets = {}
local petsReady = false

local function scanNewPets()
	local data = readData()
	if not data then
		return
	end
	local function walk(list)
		if type(list) ~= "table" then
			return
		end
		for uid, pet in pairs(list) do
			if type(pet) == "table" then
				local id = tostring(pet.uid or uid)
				local hatched = pet.hatchAt == nil
				local prev = knownPets[id]
				if not petsReady then
					knownPets[id] = hatched and "pet" or "egg"
				elseif prev == nil and not hatched then
					knownPets[id] = "egg"
				elseif (prev == nil or prev == "egg") and hatched then
					knownPets[id] = "pet"
					local spec = petSpec(pet.key)
					if spec and not spec.IsEgg and queueRare then
						queueRare("Hatched", spec.DisplayName or spec.Name or pet.key, "$" .. shortNumber(shownIncome(pet)) .. "/s")
					end
				end
			end
		end
	end
	walk(data.plotPets)
	walk(data.backpack)
	petsReady = true
end

local function pulseVirtualInput()
	local input = (game:GetService("VirtualInputManager") :: any)
	if typeof(input.SendMouseButtonEvent) ~= "function" then
		error("VirtualInputManager.SendMouseButtonEvent is missing")
	end
	local calls = {
		function()
			input:SendMouseButtonEvent(-10000, -10000, 1, true, game, 0)
			input:SendMouseButtonEvent(-10000, -10000, 1, false, game, 0)
		end,
		function()
			input:SendMouseButtonEvent(-10000, -10000, 1, true, game)
			input:SendMouseButtonEvent(-10000, -10000, 1, false, game)
		end,
	}
	local lastError = "VirtualInputManager failed"
	for _, call in ipairs(calls) do
		local ok, err = pcall(call)
		if ok then
			return
		end
		lastError = tostring(err)
	end
	error(lastError)
end

pulseAntiAfk = function()
	if not running() or STATE.antiAfk ~= true then
		return false
	end
	local function nudgeMouse()
		local input = (game:GetService("VirtualInputManager") :: any)
		if typeof(input.SendMouseMoveEvent) ~= "function" then
			error("VirtualInputManager.SendMouseMoveEvent is missing")
		end
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local x = math.clamp(view.X * 0.5, 1, math.max(1, view.X - 1))
		local y = math.clamp(view.Y * 0.92, 1, math.max(1, view.Y - 1))
		input:SendMouseMoveEvent(x, y, game)
		input:SendMouseMoveEvent(x + 2, y, game)
		input:SendMouseMoveEvent(x, y, game)
	end
	local userOk = pcall(function()
		local virtual = (game:GetService("VirtualUser") :: any)
		virtual:CaptureController()
		virtual:ClickButton2(Vector2.new(-1, -1))
	end)
	local moveOk, moveErr = pcall(nudgeMouse)
	if userOk or moveOk then
		STATE.antiAfkOperational = true
		STATE.antiAfkMethod = moveOk and "VirtualInputManager" or "VirtualUser"
		STATE.lastAntiAfk = os.clock()
		STATE.antiAfkError = nil
		return true
	end
	local inputOk, inputErr = pcall(pulseVirtualInput)
	if inputOk then
		STATE.antiAfkOperational = true
		STATE.antiAfkMethod = "VirtualInputManager"
		STATE.lastAntiAfk = os.clock()
		STATE.antiAfkError = nil
		return true
	end
	STATE.antiAfkOperational = false
	STATE.antiAfkMethod = nil
	STATE.antiAfkError = tostring(moveErr or inputErr)
	return false
end
local antiAfkConnection = STATE.connect(LocalPlayer.Idled, function()
	pulseAntiAfk()
end)
local antiAfkThread = task.spawn(function()
	task.wait(1)
	if running() and STATE.antiAfk == true then
		pulseAntiAfk()
	end
	while running() do
		task.wait(8 * 60)
		if not running() then
			return
		end
		pulseAntiAfk()
	end
end)
hubCleanup(function()
	pcall(task.cancel, antiAfkThread)
	if antiAfkConnection then
		pcall(function()
			antiAfkConnection:Disconnect()
		end)
	end
	STATE._plotLock = nil
	if STATE.releaseLiteWatch then
		STATE.releaseLiteWatch()
	end
	local builtPhone = STATE._phoneBuiltFor == true
	if STATE.restorePhoneHooks then
		STATE.restorePhoneHooks()
	end
	if builtPhone and STATE.phoneController then
		local phone = STATE.phoneController()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local panelGui = playerGui and playerGui:FindFirstChild("PhonePanel")
		if phone and type(phone.Close) == "function" and phone:IsOpen() then
			pcall(function()
				phone:Close()
			end)
		end
		if panelGui and phone and type(getupvalues) == "function" and type(setupvalue) == "function" and type(phone.Open) == "function" then
			local ups = getupvalues(phone.Open)
			if type(ups) == "table" then
				for index, value in ipairs(ups) do
					if value == panelGui then
						setupvalue(phone.Open, index, nil)
						break
					end
				end
			end
		end
		if panelGui then
			panelGui:Destroy()
		end
	end
	STATE._phoneBuiltFor = false
	STATE._phoneProps = nil
end)

function STATE.phoneController()
	if typeof(ClientRegistry) ~= "table" or typeof(ClientRegistry.TryGet) ~= "function" then
		return nil
	end
	return ClientRegistry.TryGet("PhoneController")
end

function STATE.phoneFnSource(fn)
	local src = ""
	if type(fn) ~= "function" then
		return src
	end
	pcall(function()
		src = debug.info(fn, "s") or ""
	end)
	return src
end

function STATE.unwrapPhoneFn(fn)
	local guard = 0
	while type(fn) == "function" and guard < 6 do
		if not string.find(STATE.phoneFnSource(fn), "ZinoosHub", 1, true) then
			return fn
		end
		if type(getupvalues) ~= "function" then
			return fn
		end
		local ups = getupvalues(fn)
		local inner = nil
		if type(ups) == "table" then
			for _, value in ipairs(ups) do
				if type(value) == "function" then
					inner = value
					break
				end
			end
		end
		if type(inner) ~= "function" or inner == fn then
			return fn
		end
		fn = inner
		guard += 1
	end
	return fn
end

function STATE.rememberPhoneHook(target, key, original, wrapper, gen)
	if type(STATE._phoneHooks) ~= "table" then
		STATE._phoneHooks = {}
	end
	if type(STATE._phoneHookFns) ~= "table" then
		STATE._phoneHookFns = {}
	end
	STATE._phoneHookFns[wrapper] = true
	STATE._phoneHooks[#STATE._phoneHooks + 1] = {
		target = target,
		key = key,
		original = original,
		wrapper = wrapper,
		gen = gen,
	}
end

function STATE.restorePhoneHooks()
	local hooks = STATE._phoneHooks
	if type(hooks) ~= "table" then
		STATE._phoneHooked = false
		STATE._phonePageHook = nil
		return
	end
	for index = #hooks, 1, -1 do
		local record = hooks[index]
		hooks[index] = nil
		if type(record) == "table" and type(record.target) == "table" and type(record.key) == "string" and type(record.wrapper) == "function" and record.target[record.key] == record.wrapper and type(record.original) == "function" then
			record.target[record.key] = record.original
		end
	end
	STATE._phoneHooked = false
	STATE._phonePageHook = nil
end

function STATE.hookPhonePanel()
	local ok, panel = pcall(function()
		local moduleScript = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Phone"):WaitForChild("Panel")
		local loadModuleScript = require :: any
		return loadModuleScript(moduleScript)
	end)
	if not ok or type(panel) ~= "table" or type(panel.build) ~= "function" then
		return false
	end
	if type(STATE._phoneHookFns) == "table" and STATE._phoneHookFns[panel.build] == true then
		local fresh = false
		if type(STATE._phoneHooks) == "table" then
			for _, record in ipairs(STATE._phoneHooks) do
				if type(record) == "table" and record.wrapper == panel.build and record.gen == STATE._gen and record.key == "build" then
					fresh = true
					break
				end
			end
		end
		if fresh then
			STATE._phoneHooked = true
			return true
		end
		STATE.restorePhoneHooks()
	end
	local original = STATE.unwrapPhoneFn(panel.build)
	local gen = STATE._gen
	local function wrapper(scope, props)
		if running() and gen == STATE._gen and STATE.phoneGames == true and type(props) == "table" then
			props.autoplay = true
			STATE._phoneProps = props
		end
		return original(scope, props)
	end
	panel.build = wrapper
	STATE.rememberPhoneHook(panel, "build", original, wrapper, gen)
	STATE._phoneHooked = true
	return true
end

function STATE.phoneLimits()
	if type(STATE._phoneLimits) == "table" then
		return STATE._phoneLimits
	end
	local limits = {}
	local ok, config = pcall(function()
		local moduleScript = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Phone"):WaitForChild("Config")
		local loadModuleScript = require :: any
		return loadModuleScript(moduleScript)
	end)
	local order = { "Merge", "Flappy", "Stack" }
	if ok and type(config) == "table" and type(config.Games) == "table" then
		if type(config.Order) == "table" and #config.Order > 0 then
			order = config.Order
		end
		for _, key in ipairs(order) do
			local game = config.Games[key]
			if type(key) == "string" and type(game) == "table" then
				limits[#limits + 1] = {
					key = key,
					per = type(game.MaxPerSecond) == "number" and game.MaxPerSecond or 1,
					slack = type(game.Slack) == "number" and game.Slack or 0,
					max = type(game.MaxScore) == "number" and game.MaxScore or 100000,
					title = type(game.Title) == "string" and game.Title or key,
				}
			end
		end
	end
	STATE._phoneLimits = limits
	return limits
end

function STATE.phoneScore(gameKey)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local panel = playerGui and playerGui:FindFirstChild("PhonePanel")
	if not panel then
		return nil
	end
	local best = nil
	for _, child in ipairs(panel:GetDescendants()) do
		if child.Name == "Score" and child:IsA("TextLabel") then
			local frame = child.Parent
			local onThisGame = gameKey == nil
			while frame and frame ~= panel do
				if frame.Name == gameKey then
					onThisGame = frame:IsA("GuiObject") and frame.Visible == true
					break
				end
				frame = frame.Parent
			end
			local amount = onThisGame and tonumber(child.Text)
			if amount and (best == nil or amount > best) then
				best = amount
			end
		end
	end
	return best
end

function STATE.notePhonePeak(key, score)
	if type(key) ~= "string" or type(score) ~= "number" or score < 1 then
		return
	end
	score = math.floor(score)
	if STATE._phonePeakKey ~= key then
		STATE._phonePeakKey = key
		STATE._phonePeak = score
		STATE._phoneRunAt = os.clock()
		return
	end
	local previous = STATE._phonePeak or 0
	if score + 3 < previous then
		STATE._phoneHeldPeak = math.max(STATE._phoneHeldPeak or 0, previous)
		STATE._phoneHeldKey = key
		STATE._phoneHeldAt = STATE._phoneRunAt
		STATE._phonePeak = score
		STATE._phoneRunAt = os.clock()
		return
	end
	if previous < 1 then
		STATE._phoneRunAt = os.clock()
	end
	if score > previous then
		STATE._phonePeak = score
	end
end

function STATE.savePhoneScore(game)
	if type(game) ~= "table" then
		return false
	end
	local shown = STATE.phoneScore(game.key) or 0
	local step = STATE._phoneStep
	if STATE._phoneKind == game.key and typeof(step) == "function" and type(getupvalues) == "function" then
		local ups = getupvalues(step)
		if type(ups) == "table" then
			local peek = nil
			local scoreState = nil
			if game.key == "Stack" then
				peek = ups[6]
				scoreState = ups[18]
			elseif game.key == "Flappy" then
				peek = ups[4]
				scoreState = ups[15]
			end
			if typeof(peek) == "function" and type(scoreState) == "table" then
				local ok, value = pcall(peek, scoreState)
				if ok and type(value) == "number" and value > shown then
					shown = value
				end
			end
		end
	end
	if shown > 0 then
		STATE.notePhonePeak(game.key, shown)
	end
	if STATE._phonePeakKey == game.key and type(STATE._phonePeak) == "number" and STATE._phonePeak > shown then
		shown = STATE._phonePeak
	end
	if STATE._phoneHeldKey == game.key and type(STATE._phoneHeldPeak) == "number" and STATE._phoneHeldPeak > shown then
		shown = STATE._phoneHeldPeak
	end
	if shown < 1 then
		return false
	end
	local saved = 0
	if type(STATE._phoneBests) == "table" and type(STATE._phoneBests[game.key]) == "number" then
		saved = STATE._phoneBests[game.key]
	end
	if shown <= saved then
		return false
	end
	local score = math.floor(math.min(shown, game.max))
	if score <= saved then
		return false
	end
	local ok, result = pcall(function()
		return Net:InvokeServer("PhoneGameSubmit", game.key, score)
	end)
	if not ok or type(result) ~= "table" or type(result.best) ~= "number" then
		return false
	end
	if type(STATE._phoneBests) ~= "table" then
		STATE._phoneBests = {}
	end
	STATE._phoneBests[game.key] = result.best
	STATE.phoneBest = result.best
	STATE.phoneGame = game.title or game.key
	local props = STATE._phoneProps
	local bests = type(props) == "table" and props.bests or nil
	if type(bests) == "table" and type(bests.set) == "function" then
		local copy = {}
		for key, value in pairs(STATE._phoneBests) do
			copy[key] = value
		end
		pcall(function()
			bests:set(copy)
		end)
	end
	if STATE._phoneHeldKey == game.key and result.best >= (STATE._phoneHeldPeak or 0) then
		STATE._phoneHeldPeak = nil
		STATE._phoneHeldKey = nil
		STATE._phoneHeldAt = nil
	end
	if result.best >= score then
		STATE._phoneBanked = true
	end
	return result.best >= score
end

function STATE.saveCurrentPhone()
	local key = STATE._phoneKey
	if type(key) ~= "string" then
		return false
	end
	local limits = STATE.phoneLimits()
	for _, item in ipairs(limits) do
		if item.key == key then
			return STATE.savePhoneScore(item)
		end
	end
	return false
end

function STATE.hookPhoneLeave()
	local props = STATE._phoneProps
	local page = type(props) == "table" and props.page or nil
	if type(page) ~= "table" or type(page.set) ~= "function" then
		return
	end
	if type(STATE._phoneHookFns) == "table" and STATE._phoneHookFns[page.set] == true then
		local fresh = false
		if type(STATE._phoneHooks) == "table" then
			for _, record in ipairs(STATE._phoneHooks) do
				if type(record) == "table" and record.wrapper == page.set and record.gen == STATE._gen and record.key == "set" then
					fresh = true
					break
				end
			end
		end
		if fresh then
			STATE._phonePageHook = page.set
			return
		end
		STATE.restorePhoneHooks()
	end
	local original = STATE.unwrapPhoneFn(page.set)
	local gen = STATE._gen
	local function hook(self, nextPage)
		if not running() or gen ~= STATE._gen then
			return original(self, nextPage)
		end
		if nextPage == nil and self ~= page then
			nextPage = self
			self = page
		end
		if type(nextPage) == "string" and type(STATE._phoneKey) == "string" and nextPage ~= STATE._phoneKey then
			pcall(STATE.saveCurrentPhone)
		end
		if type(nextPage) == "string" then
			STATE._phonePage = nextPage
		end
		return original(self, nextPage)
	end
	page.set = hook
	STATE._phonePageHook = hook
	STATE.rememberPhoneHook(page, "set", original, hook, gen)
end

function STATE.pullPhoneBests()
	if os.clock() < (STATE._phoneBestsAt or 0) then
		return
	end
	STATE._phoneBestsAt = os.clock() + 15
	local ok, data = pcall(function()
		local moduleScript = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net")
		local loadModuleScript = require :: any
		local net = loadModuleScript(moduleScript)
		return net:InvokeServer("GetPhoneData")
	end)
	if ok and type(data) == "table" and type(data.bests) == "table" then
		STATE._phoneBests = data.bests
		local waiting = STATE._phoneWaitScore
		local key = STATE._phoneWaitKey
		if type(waiting) == "number" and type(key) == "string" then
			local got = data.bests[key]
			if type(got) == "number" and got >= waiting then
				STATE._phoneWaitScore = nil
				STATE._phoneWaitKey = nil
			end
		end
	end
end

function STATE.notePhoneRound(phase)
	if phase == "play" then
		if STATE._phoneWasPlay ~= true and STATE._phoneSawRound == true then
			local peak = STATE._phonePeakKey == STATE._phoneKey and STATE._phonePeak or 0
			if peak < 5 then
				STATE._phoneRoundAt = os.clock()
				STATE._phoneBanked = false
				STATE._phoneHoldAt = nil
			end
		end
		STATE._phoneWasPlay = true
		STATE._phoneSawRound = true
	elseif phase == "menu" or phase == "over" or phase == "dead" then
		STATE._phoneWasPlay = false
		STATE._phoneSawRound = true
	end
end

function STATE.rebuildPhone()
	if STATE.phoneGames == true then
		if not STATE.hookPhonePanel() then
			return false
		end
	else
		STATE.restorePhoneHooks()
	end
	local phone = STATE.phoneController()
	if not phone then
		return false
	end
	if phone:IsOpen() then
		phone:Close()
	end
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild("PhonePanel")
	local cleared = gui == nil
	if gui and type(getupvalues) == "function" and type(setupvalue) == "function" then
		local ups = getupvalues(phone.Open)
		if type(ups) == "table" then
			for index, value in ipairs(ups) do
				if value == gui then
					setupvalue(phone.Open, index, nil)
					cleared = true
					break
				end
			end
		end
	end
	if gui and cleared then
		gui:Destroy()
	elseif gui then
		return false
	end
	STATE._phoneProps = nil
	return true
end

function STATE.openPhoneGame(game)
	local phone = STATE.phoneController()
	local props = STATE._phoneProps
	if not phone or type(game) ~= "table" or type(props) ~= "table" or type(props.page) ~= "table" or type(props.page.set) ~= "function" then
		return false
	end
	props.autoplay = true
	if not phone:IsOpen() then
		phone:Open()
	end
	props.page:set(game.key)
	STATE._phonePage = game.key
	STATE._phoneIndex = game.index
	STATE._phoneKey = game.key
	STATE._phoneStep = nil
	STATE._phoneScanAt = 0
	STATE._phoneRoundAt = os.clock()
	STATE._phoneSubmitAt = os.clock() + 8
	STATE._phoneSent = nil
	STATE._phoneBanked = false
	STATE._phoneWasPlay = false
	STATE._phoneSawRound = false
	STATE._phoneHoldAt = nil
	STATE.phoneGame = game.title or game.key
	return true
end

function STATE.phoneGameKey(choice)
	if choice == "When Pigs Fly" or choice == "Flappy" then
		return "Flappy"
	end
	if choice == "Snack Stack" or choice == "Stack" then
		return "Stack"
	end
	return "Merge"
end

function STATE.chosenPhoneGame(limits)
	local want = STATE.phoneGameKey(STATE.phoneChoice)
	for index, game in ipairs(limits) do
		if game.key == want then
			game.index = index
			return game
		end
	end
	local game = limits[1]
	game.index = 1
	return game
end

function STATE.stepPhoneGames()
	local phone = STATE.phoneController()
	if STATE.phoneGames ~= true then
		if STATE._phoneRunning then
			local limits = STATE.phoneLimits()
			local game = nil
			for _, item in ipairs(limits) do
				if item.key == STATE._phoneKey then
					game = item
					break
				end
			end
			if game then
				pcall(STATE.savePhoneScore, game)
			end
			STATE._phoneRunning = false
			STATE._phonePaused = false
			STATE._phoneKey = nil
			if phone and phone:IsOpen() then
				phone:Close()
			end
			if STATE._phoneBuiltFor == true then
				STATE.rebuildPhone()
				STATE._phoneBuiltFor = false
			end
		end
		return
	end
	if not phone then
		error("Phone is missing")
	end
	local limits = STATE.phoneLimits()
	if #limits == 0 then
		error("Phone games are missing")
	end
	local game = STATE.chosenPhoneGame(limits)
	if STATE.liftSteal == true or STATE.placeBusy == true then
		if STATE._phonePaused ~= true then
			if phone:IsOpen() then
				phone:Close()
			end
			STATE._phonePaused = true
		end
		return
	end
	if STATE._phoneBuiltFor ~= true then
		if not STATE.rebuildPhone() then
			error("Phone could not be opened")
		end
		STATE._phoneBuiltFor = true
		phone:Open()
	end
	STATE._phoneRunning = true
	local resumed = STATE._phonePaused == true
	STATE._phonePaused = false
	local props = STATE._phoneProps
	STATE.hookPhoneLeave()
	if STATE._phoneNeedSave == true then
		STATE._phoneNeedSave = false
		STATE._phoneSavedRound = STATE._phoneRoundAt
		pcall(STATE.saveCurrentPhone)
	end
	local liveScore = STATE.phoneScore(game.key)
	if type(liveScore) == "number" then
		STATE.notePhonePeak(game.key, liveScore)
	end
	local needStart = resumed or type(props) ~= "table" or not phone:IsOpen() or STATE._phoneKey ~= game.key
	if not needStart and type(STATE._phonePage) == "string" and STATE._phonePage ~= game.key then
		needStart = true
	end
	if needStart then
		if type(STATE._phoneKey) == "string" and STATE._phoneKey ~= game.key then
			for _, item in ipairs(limits) do
				if item.key == STATE._phoneKey then
					pcall(STATE.savePhoneScore, item)
					break
				end
			end
		elseif type(STATE._phonePage) == "string" and STATE._phonePage ~= game.key then
			pcall(STATE.saveCurrentPhone)
		end
		if not STATE.openPhoneGame(game) then
			error("Phone game did not start")
		end
		return
	end
	if os.clock() >= (STATE._phoneSubmitAt or 0) then
		STATE._phoneSubmitAt = os.clock() + 15
		STATE.pullPhoneBests()
	end
end

function STATE.phoneStepKind(deep)
	if type(deep) ~= "table" then
		return nil
	end
	local ninth = deep[9]
	local props = deep[6]
	if type(ninth) == "table" and type(deep[10]) == "number" and type(deep[11]) == "number" and type(props) == "table" and props.autoplay ~= nil then
		return "Flappy"
	end
	props = deep[8]
	if type(deep[2]) == "table" and typeof(deep[12]) == "function" and type(ninth) == "number" and type(props) == "table" and props.autoplay ~= nil then
		return "Stack"
	end
	props = deep[5]
	if typeof(ninth) == "function" and type(deep[8]) == "number" and type(deep[12]) == "table" and typeof(deep[3]) == "function" and type(props) == "table" and props.autoplay ~= nil then
		return "Merge"
	end
	return nil
end

function STATE.findPhoneStep()
	if type(getconnections) ~= "function" or type(getupvalues) ~= "function" then
		return nil, nil
	end
	local cons = getconnections(RunService.Heartbeat)
	if type(cons) ~= "table" then
		return nil, nil
	end
	local function walk(fn, depth)
		if depth > 3 or typeof(fn) ~= "function" then
			return nil, nil
		end
		local deep = getupvalues(fn)
		if type(deep) ~= "table" then
			return nil, nil
		end
		local kind = STATE.phoneStepKind(deep)
		if kind then
			return fn, kind
		end
		local limit = math.min(#deep, 8)
		for index = 1, limit do
			if typeof(deep[index]) == "function" then
				local found, foundKind = walk(deep[index], depth + 1)
				if found then
					return found, foundKind
				end
			end
		end
		return nil, nil
	end
	for _, conn in ipairs(cons) do
		local found, kind = walk(conn.Function, 0)
		if found then
			return found, kind
		end
	end
	return nil, nil
end

function STATE.steerFlappy(step)
	local ups = getupvalues(step)
	if type(ups) ~= "table" or type(ups[6]) ~= "table" or typeof(ups[4]) ~= "function" or typeof(ups[8]) ~= "function" then
		return
	end
	ups[6].autoplay = false
	local phase = ups[4](ups[5])
	STATE.notePhoneRound(phase)
	if typeof(ups[4]) == "function" and type(ups[15]) == "table" then
		local ok, value = pcall(ups[4], ups[15])
		if ok then
			STATE.notePhonePeak("Flappy", value)
		end
	end
	if phase == "menu" then
		STATE._phoneHoldAt = nil
		ups[8]()
		return
	end
	if phase == "over" or phase == "dead" then
		if STATE._phoneSavedRound ~= STATE._phoneRoundAt then
			STATE._phoneNeedSave = true
		end
		STATE._phoneHoldAt = STATE._phoneHoldAt or os.clock()
		if STATE._phoneNeedSave == true then
			return
		end
		if phase == "over" and os.clock() - STATE._phoneHoldAt >= 2.5 then
			STATE._phoneHoldAt = nil
			ups[8]()
		end
		return
	end
	if phase ~= "play" or type(ups[10]) ~= "number" or type(ups[11]) ~= "number" or type(ups[9]) ~= "table" then
		return
	end
	STATE._phoneHoldAt = nil
	local y = ups[10]
	local vy = ups[11]
	local width = type(ups[3]) == "number" and ups[3] or 50
	local birdX = width * 0.3
	local gapY, gap, nearest = 46, 28, math.huge
	for _, pipe in ipairs(ups[9]) do
		if type(pipe) == "table" and type(pipe.x) == "number" and pipe.x + 14 >= birdX - 1 and pipe.x < nearest then
			nearest = pipe.x
			gapY = type(pipe.gapY) == "number" and pipe.gapY or gapY
			gap = type(pipe.gap) == "number" and pipe.gap or gap
		end
	end
	local nextY = y
	local nextVy = vy
	for _ = 1, 5 do
		nextVy = math.min(nextVy + 250 / 55, 120)
		nextY += nextVy / 55
	end
	local ceiling = gapY - math.max(4, gap / 2 - 4.8)
	local floorLine = gapY + math.max(4, gap / 2 - 4.8)
	if y > 76 or nextY > floorLine or (y > gapY + 2 and vy > -25) then
		setupvalue(step, 11, -72)
	elseif y < 7 or (nextY < ceiling and vy < 0) then
		setupvalue(step, 11, 40)
	end
end

function STATE.steerStack(step)
	local ups = getupvalues(step)
	if type(ups) ~= "table" or typeof(ups[6]) ~= "function" or type(ups[2]) ~= "table" then
		return
	end
	if type(ups[8]) == "table" then
		ups[8].autoplay = false
	end
	local phase = ups[6](ups[7])
	STATE.notePhoneRound(phase)
	if typeof(ups[6]) == "function" and type(ups[18]) == "table" then
		local ok, value = pcall(ups[6], ups[18])
		if ok then
			STATE.notePhonePeak("Stack", value)
		end
	end
	if phase == "menu" then
		if typeof(ups[10]) == "function" then
			ups[10]()
		end
		return
	end
	if phase == "over" or phase == "dead" then
		if STATE._phoneSavedRound ~= STATE._phoneRoundAt then
			STATE._phoneNeedSave = true
		end
		STATE._phoneHoldAt = STATE._phoneHoldAt or os.clock()
		if STATE._phoneNeedSave == true then
			return
		end
		if phase == "over" and os.clock() - STATE._phoneHoldAt >= 2.5 and typeof(ups[10]) == "function" then
			STATE._phoneHoldAt = nil
			ups[10]()
		end
		return
	end
	if phase ~= "play" then
		return
	end
	local top = ups[2][#ups[2]]
	local mover = ups[11]
	if type(top) ~= "table" or type(top.x) ~= "number" or type(mover) ~= "table" then
		return
	end
	local now = os.clock()
	if now - (STATE._stackNext or 0) >= 0.3 then
		mover.x = top.x
		if typeof(ups[12]) == "function" then
			ups[12]()
		end
		STATE._stackNext = now
	else
		local away = top.x + 8
		if away > 92 then
			away = top.x - 8
		end
		mover.x = away
	end
end

function STATE.mergeSettled(bodies)
	if type(bodies) ~= "table" then
		return true
	end
	for _, body in ipairs(bodies) do
		if type(body) == "table" then
			local vx = type(body.vx) == "number" and body.vx or 0
			local vy = type(body.vy) == "number" and body.vy or 0
			if math.abs(vx) > 22 or math.abs(vy) > 22 then
				return false
			end
		end
	end
	return true
end

function STATE.mergeAim(bodies, tier, radius)
	local aim = nil
	local room = -1
	local movingMatch = false
	local tops = { 100, 100, 100, 100, 100, 100, 100, 100 }
	if type(bodies) == "table" then
		for _, body in ipairs(bodies) do
			if type(body) == "table" and body.tier == tier and type(body.x) == "number" and type(body.y) == "number" and type(body.r) == "number" then
				local vx = type(body.vx) == "number" and body.vx or 0
				local vy = type(body.vy) == "number" and body.vy or 0
				local space = body.y - body.r
				if math.abs(vx) > 22 or math.abs(vy) > 22 then
					movingMatch = true
				elseif space > 20 and space > room then
					room = space
					aim = body.x
				end
			end
		end
		if aim == nil and movingMatch then
			return nil
		end
		if aim == nil then
			for _, body in ipairs(bodies) do
				if type(body) == "table" and type(body.x) == "number" and type(body.y) == "number" and type(body.r) == "number" then
					local column = math.clamp(math.floor(body.x / 12.5) + 1, 1, 8)
					local top = body.y - body.r
					if top < tops[column] then
						tops[column] = top
					end
				end
			end
			local bestColumn, bestTop = 4, -1
			for column = 1, 8 do
				if tops[column] > bestTop then
					bestTop = tops[column]
					bestColumn = column
				end
			end
			if bestTop >= 26 then
				aim = (bestColumn - 0.5) * 12.5
			end
		end
	end
	if type(aim) ~= "number" then
		return nil
	end
	local edge = math.clamp(type(radius) == "number" and radius or 6, 4, 20)
	return math.clamp(aim, edge, 100 - edge)
end

function STATE.steerMerge(step)
	local ups = getupvalues(step)
	if type(ups) ~= "table" or type(ups[5]) ~= "table" or typeof(ups[3]) ~= "function" or typeof(ups[9]) ~= "function" then
		return
	end
	ups[5].autoplay = false
	local phase = ups[3](ups[4])
	STATE.notePhoneRound(phase)
	if phase == "over" then
		if STATE._phoneSavedRound ~= STATE._phoneRoundAt then
			STATE._phoneNeedSave = true
		end
		STATE._phoneHoldAt = STATE._phoneHoldAt or os.clock()
		if STATE._phoneNeedSave == true then
			return
		end
		if os.clock() - STATE._phoneHoldAt >= 2.5 and typeof(ups[7]) == "function" then
			STATE._phoneHoldAt = nil
			ups[7]()
		end
		return
	end
	if phase ~= "play" and phase ~= "menu" then
		return
	end
	STATE._phoneHoldAt = nil
	if os.clock() - (STATE._mergeNext or 0) < 0.12 then
		return
	end
	if type(ups[2]) == "number" and ups[2] > 0 then
		return
	end
	if phase == "play" and not STATE.mergeSettled(ups[12]) then
		STATE._mergeUnsettled = STATE._mergeUnsettled or os.clock()
		if os.clock() - STATE._mergeUnsettled < 0.4 then
			return
		end
	else
		STATE._mergeUnsettled = nil
	end
	local tier = type(ups[19]) == "number" and ups[19] or 1
	local radius = 6
	local ladder = ups[18]
	if type(ladder) == "table" and type(ladder[tier]) == "table" and type(ladder[tier].r) == "number" then
		radius = ladder[tier].r
	end
	local aim = STATE.mergeAim(ups[12], tier, radius)
	if aim == nil then
		if phase == "menu" or type(ups[12]) ~= "table" or #ups[12] == 0 then
			aim = math.clamp(50, radius, 100 - radius)
		else
			return
		end
	end
	STATE._mergeNext = os.clock()
	setupvalue(step, 8, aim)
	ups[9]()
end

function STATE.steerPhone()
	if STATE.phoneGames ~= true or STATE._phonePaused == true then
		STATE._phoneStep = nil
		return
	end
	if typeof(getupvalues) ~= "function" or typeof(setupvalue) ~= "function" then
		return
	end
	if os.clock() >= (STATE._phoneScanAt or 0) or typeof(STATE._phoneStep) ~= "function" then
		STATE._phoneScanAt = os.clock() + 0.2
		STATE._phoneStep, STATE._phoneKind = STATE.findPhoneStep()
	end
	local step = STATE._phoneStep
	if typeof(step) ~= "function" or STATE._phoneKind ~= STATE._phoneKey then
		return
	end
	if STATE._phoneKind == "Flappy" then
		STATE.steerFlappy(step)
	elseif STATE._phoneKind == "Stack" then
		STATE.steerStack(step)
	elseif STATE._phoneKind == "Merge" then
		STATE.steerMerge(step)
	end
end

STATE.connect(RunService.RenderStepped, function()
	if not running() or STATE.phoneGames ~= true then
		return
	end
	local ok, err = pcall(STATE.steerPhone)
	if not ok then
		STATE._phoneStep = nil
		STATE._phoneScanAt = 0
		STATE.noteFault("Phone Games", false, err)
	end
end)

task.spawn(function()
	while running() do
		if STATE.phoneGames == true or STATE._phoneRunning then
			STATE.watchFeature("Phone Games", STATE.stepPhoneGames)
		end
		task.wait(1)
	end
end)

local nextBubble = 0
STATE.connect(RunService.Heartbeat, function()
	if not running() then
		return
	end
	if os.clock() >= (STATE.nextPrune or 0) then
		STATE.nextPrune = os.clock() + 1
		pruneConnections()
	end
	STATE.train = false
	syncToggles()
	if os.clock() >= (STATE.nextView or 0) then
		STATE.nextView = os.clock() + (STATE.lowEnd == true and 1.25 or 0.5)
		STATE.watchFeature("Lite Pets, Egg ESP", stepView)
	end
	if os.clock() >= (STATE.nextInv or 0) then
		STATE.nextInv = os.clock() + (STATE.lowEnd == true and 2 or 1.2)
		STATE.watchFeature("Inventory ESP", stepInventory)
	end
	if os.clock() >= (STATE.nextHookScan or 0) then
		STATE.nextHookScan = os.clock() + 2
		STATE.watchFeature("Hatch alerts", scanNewPets)
	end
	if os.clock() >= (STATE.nextAnimals or 0) then
		STATE.nextAnimals = os.clock() + 1
		STATE.watchFeature("Animals menu", paintAnimals)
	end
	STATE.watchFeature("Auto Train", stepTrain)
	if STATE.lowEnd ~= true or os.clock() >= (STATE.nextHome or 0) then
		if STATE.lowEnd == true then
			STATE.nextHome = os.clock() + 0.25
		end
		task.defer(function()
			task.defer(pullHomeIfEmpty)
		end)
	end
	local now = os.clock()
	if now < nextBubble then
		return
	end
	nextBubble = now + 0.4
	STATE.watchFeature("Auto Rebirth", stepRebirth)
	STATE.watchFeature("Free bubbles", popFreeBubbles)
	STATE.watchFeature("Purchase prompts", dismissPurchase)
	STATE.watchFeature("Best notices", clearBestNotices)
	STATE.watchFeature("Auto Open", stepOpenEggs)
	STATE.watchFeature("Equip Best", stepEquipBest)
	STATE.watchFeature("Auto Daily", stepDaily)
	STATE.watchFeature("Auto Index", stepIndex)
	STATE.watchFeature("Free Stash", stepStash)
end)

function STATE.runThemeHostChecks()
	local fetches = 0
	STATE._themeFetch = function()
		fetches += 1
		return "not-an-image"
	end
	local gen = STATE._gen
	local token = genv.ZinoosGen
	local function blocked(url)
		return STATE.themeAsset(url, gen, token) == nil
	end
	local untrustedQuiet = blocked("https://evil.example/pic.png")
		and blocked("https://ysoyjfnigavjajrjftmv.supabase.co.evil.example/a.png")
		and blocked("https://user@ysoyjfnigavjajrjftmv.supabase.co/a.png")
		and blocked("https://ysoyjfnigavjajrjftmv.supabase.co:443/a.png")
		and blocked("http://ysoyjfnigavjajrjftmv.supabase.co/a.png")
		and blocked("https://ysoyjfnigavjajrjftmv.supabase.co/a.png?x=1")
		and blocked("https://ysoyjfnigavjajrjftmv.supabase.co/a.png#x")
		and blocked("https://ysoyjfnigavjajrjftmv.supabase.co/a .png")
		and blocked("https://ysoyjfnigavjajrjftmv.supabase.co/a%2F.png")
		and fetches == 0
	local trusted = STATE.themeAsset("https://ysoyjfnigavjajrjftmv.supabase.co/storage/v1/object/public/theme-images/repair-check.png", gen, token)
	local colours = STATE.readTheme({
		Name = "ColoursOnly",
		Theme = {
			Colors = { Accent = "ff00aa", Text = "ffffff", Background = "111111", Element = "222222" },
			Wallpaper = "https://evil.example/nope.png",
			Icon = "https://evil.example/icon.png",
		},
	})
	STATE._themeFetch = nil
	return {
		untrustedQuiet = untrustedQuiet,
		trustedCalled = fetches == 1 and trusted == nil,
		coloursOk = type(colours) == "table" and typeof(colours.accent) == "Color3" and colours.wallpaper ~= true and colours.icon ~= true,
		fetches = fetches,
	}
end

function STATE.runPlotRepairChecks()
	local savedEquip = STATE.equipBest
	local savedPlace = STATE.autoPlace
	local savedSteal = STATE.autoSteal
	local savedLock = STATE._plotLock
	local savedStatus = STATE.equipStatus
	local savedNext = STATE.nextEquip
	local savedPlaceStatus = STATE.placeStatus
	local savedHold = STATE.placeHoldUntil
	local savedGen = STATE._gen
	local savedToken = genv.ZinoosGen
	local report = {}
	local function cleanup()
		STATE._plotTestData = nil
		STATE._plotTestInvoke = nil
		STATE._plotTestSlots = nil
		STATE._plotTestPlace = nil
		STATE._plotLock = savedLock
		STATE._equipTxn = nil
		STATE._equipRecovery = nil
		STATE._equipRetryAt = 0
		STATE._equipRecovering = nil
		STATE.equipBest = savedEquip
		STATE.autoPlace = savedPlace
		STATE.autoSteal = savedSteal
		STATE.equipStatus = savedStatus
		STATE.nextEquip = savedNext
		STATE.placeStatus = savedPlaceStatus
		STATE.placeHoldUntil = savedHold
		STATE._gen = savedGen
		genv.ZinoosGen = savedToken
	end
	local function names(log)
		local list = {}
		for _, call in ipairs(log) do
			list[#list + 1] = call.name .. ":" .. tostring(call.uid)
		end
		return table.concat(list, ",")
	end
	local ok, err = pcall(function()
		STATE._plotTestSlots = 2
		STATE._plotTestData = function()
			return {
				baseLevel = 1,
				plotPets = {
					animal = { uid = "animal", key = "Cat" },
					eggA = { uid = "eggA", key = "Egg", hatchAt = 9999999999 },
					eggB = { uid = "eggB", key = "Egg", hatchAt = 9999999999 },
				},
				backpack = {},
			}
		end
		local room = STATE.plotRoom()
		STATE._plotTestData = function()
			return {
				baseLevel = 1,
				plotPets = {
					a = { uid = "a", key = "Cat" },
					b = { uid = "b", key = "Dog" },
					egg = { uid = "egg", key = "Egg", hatchAt = 9999999999 },
				},
				backpack = {},
			}
		end
		local packed = STATE.plotRoom()
		report.eggsSeparate = room ~= nil and packed ~= nil and room.activeAnimals == 1 and room.growingEggs == 2 and room.free == true and packed.activeAnimals == 2 and packed.growingEggs == 1 and packed.free == false
		local calls = {}
		STATE._plotTestPlace = { uid = "egg", x = 1, z = 2 }
		STATE._plotTestInvoke = function(name)
			calls[#calls + 1] = name
		end
		STATE.autoPlace = true
		STATE._plotLock = nil
		local fullStatus = STATE.placeSelectedEgg(false)
		local fullFires = 0
		for _, name in ipairs(calls) do
			if name == "PlacePet" then
				fullFires += 1
			end
		end
		report.fullNoFire = fullStatus == "Timed out waiting for confirmation" and fullFires == 1 and STATE.placeStatus ~= "Confirmed full"
		STATE._plotLock = nil
		STATE.placeHoldUntil = 0
		STATE.placeStatus = nil
		local blocked = {}
		STATE._plotTestInvoke = function(name)
			blocked[#blocked + 1] = name
		end
		local blockLock = STATE.acquirePlot("equip", nil)
		local blockedStatus = STATE.guardedPlace(blockLock, nil, "pet", 1, 2, nil, false)
		STATE.releasePlot(blockLock)
		STATE.placeHoldUntil = 0
		STATE.placeStatus = nil
		report.fullStillBlocksPets = blockedStatus == "Confirmed full" and #blocked == 0
		calls = {}
		STATE._plotLock = nil
		STATE._plotTestData = function()
			return {
				baseLevel = 1,
				plotPets = {
					a = { uid = "a", key = "Cat" },
					growing = { uid = "growing", key = "Egg", hatchAt = 9999999999 },
				},
				backpack = {},
			}
		end
		local timeoutStatus = STATE.placeSelectedEgg(false)
		local timeoutFires = 0
		for _, name in ipairs(calls) do
			if name == "PlacePet" then
				timeoutFires += 1
			end
		end
		report.timeoutOpen = timeoutStatus == "Timed out waiting for confirmation" and timeoutFires == 1 and STATE.placeStatus ~= "Confirmed full"
		local sawPlace = false
		calls = {}
		STATE._plotLock = nil
		STATE._plotTestInvoke = function(name)
			calls[#calls + 1] = name
			if name == "PlacePet" then
				sawPlace = true
			end
		end
		STATE._plotTestData = function()
			local pets = { a = { uid = "a", key = "Cat" } }
			if sawPlace then
				pets.b = { uid = "b", key = "Dog" }
			end
			return { baseLevel = 1, plotPets = pets, backpack = {} }
		end
		local lateFull = STATE.placeSelectedEgg(false)
		report.timeoutThenFull = lateFull == "Timed out waiting for confirmation" and #calls == 1 and STATE.placeStatus ~= "Confirmed full"
		local function runSwap(mode)
			local log = {}
			local oldOn = true
			local newOn = false
			local reads = 0
			local placeRead = nil
			local bag = {}
			STATE.equipBest = true
			STATE._plotLock = nil
			STATE._equipRecovery = nil
			STATE._equipTxn = nil
			STATE._plotTestSlots = 4
			STATE._plotTestData = function()
				reads += 1
				local pets = {}
				if oldOn then
					pets.old = { uid = "old", key = "Cat", pos = { x = 3, z = 4 } }
				end
				local revealLate = mode == "late" and placeRead ~= nil and reads > placeRead + 6
				if newOn or revealLate then
					pets.newpet = { uid = "new", key = "Dog", pos = { x = 1, z = 2 } }
					if revealLate then
						newOn = true
					end
				end
				if oldOn then
					bag.old = nil
				else
					bag.old = { uid = "old", key = "Cat" }
				end
				return { baseLevel = 1, plotPets = pets, backpack = bag }
			end
			STATE._plotTestInvoke = function(name, uid, x, z)
				log[#log + 1] = { name = name, uid = uid, x = x, z = z }
				if name == "PickupPet" and uid == "old" then
					oldOn = false
					if mode == "toggle" then
						STATE.equipBest = false
					elseif mode == "replace" then
						STATE._gen = -1
						genv.ZinoosGen = (genv.ZinoosGen or 0) + 1
					end
				elseif name == "PlacePet" and uid == "new" then
					placeRead = reads
					if mode == "success" then
						newOn = true
					end
				elseif name == "PlacePet" and uid == "old" then
					oldOn = true
				end
			end
			local status = STATE.commitEquip("new", "old", 3, 4, false)
			return status, log, oldOn, newOn, reads
		end
		local successStatus, successLog, successOld = runSwap("success")
		report.success = successStatus == true and successOld == false and names(successLog) == "PickupPet:old,PlacePet:new" and STATE._equipRecovery == nil
		local failStatus, failLog, failOld = runSwap("fail")
		local failLast = failLog[#failLog]
		report.failedPlace = failStatus ~= true and failOld == true and names(failLog) == "PickupPet:old,PlacePet:new,PlacePet:old" and failLast and failLast.x == 3 and failLast.z == 4 and STATE._equipRecovery == nil
		local toggleStatus, toggleLog, toggleOld = runSwap("toggle")
		report.toggleRestores = toggleStatus == "Feature cancelled" and toggleOld == true and names(toggleLog) == "PickupPet:old,PlacePet:old" and toggleLog[2].x == 3 and toggleLog[2].z == 4
		STATE.equipBest = true
		local replaceStatus, replaceLog = runSwap("replace")
		STATE._gen = savedGen
		genv.ZinoosGen = savedToken
		local record = STATE._equipRecovery
		local replaceStopped = replaceStatus == "Generation replaced" and names(replaceLog) == "PickupPet:old" and type(record) == "table" and record.oldUid == "old" and record.oldX == 3 and record.oldZ == 4 and record.newUid == "new"
		if type(record) == "table" then
			record.gen = savedGen - 1
			record.token = savedToken - 1
		end
		local recovered = STATE.recoverEquipSwap() == true
		local recoverCall = replaceLog[#replaceLog]
		report.generationRestores = replaceStopped and recovered and names(replaceLog) == "PickupPet:old,PlacePet:old" and recoverCall and recoverCall.x == 3 and recoverCall.z == 4
		STATE._equipRecovery = {
			gen = savedGen - 1,
			token = savedToken - 1,
			oldUid = "old",
			oldX = 3,
			oldZ = 4,
			newUid = "new",
			phase = "picked-up",
		}
		STATE._plotTestData = function()
			return { baseLevel = 1, plotPets = { newpet = { uid = "new", key = "Dog" } }, backpack = { old = { uid = "old", key = "Cat" } } }
		end
		local before = #replaceLog
		local skipped = STATE.recoverEquipSwap() == false and STATE._equipRecovery == nil and #replaceLog == before
		report.latePlan = skipped and STATE.equipRecoveryPlan({
			phase = "picked-up",
			oldUid = "old",
			newUid = "new",
			oldX = 3,
			oldZ = 4,
		}, {
			plotPets = { newpet = { uid = "new" } },
			backpack = { old = { uid = "old" } },
		}) == "clear"
		local lateStatus, lateLog, lateOld, lateNew = runSwap("late")
		report.lateSwap = lateStatus == true and lateOld == false and lateNew == true and names(lateLog) == "PickupPet:old,PlacePet:new"
		local delayedReads = 0
		local delayedLog = {}
		local delayedOn = true
		local delayedPicked = false
		local delayedReleased = false
		STATE.equipBest = true
		STATE._plotLock = nil
		STATE._equipTxn = nil
		STATE._equipRecovery = nil
		STATE._equipRetryAt = 0
		STATE._plotTestSlots = 4
		STATE._plotTestData = function()
			if delayedPicked and not delayedReleased then
				delayedReads += 1
				if delayedReads >= 4 then
					delayedOn = false
					delayedReleased = true
				end
			end
			local pets = {}
			local bag = {}
			if delayedOn then
				pets.old = { uid = "old", key = "Cat", pos = { x = 3, z = 4 } }
			else
				bag.old = { uid = "old", key = "Cat" }
			end
			return { baseLevel = 1, plotPets = pets, backpack = bag }
		end
		STATE._plotTestInvoke = function(name, uid, x, z)
			delayedLog[#delayedLog + 1] = { name = name, uid = uid, x = x, z = z }
			if name == "PickupPet" and uid == "old" then
				delayedPicked = true
				STATE.equipBest = false
			elseif name == "PlacePet" and uid == "old" then
				delayedOn = true
				delayedReleased = true
			end
		end
		local delayedStatus = STATE.commitEquip("new", "old", 3, 4, false)
		report.delayedToggle = delayedStatus == "Feature cancelled" and delayedReads >= 4 and delayedOn == true and names(delayedLog) == "PickupPet:old,PlacePet:old" and delayedLog[2].x == 3 and delayedLog[2].z == 4
		local retryLog = {}
		local retryOn = true
		local retryPlaces = 0
		STATE.equipBest = true
		STATE._plotLock = nil
		STATE._equipTxn = nil
		STATE._equipRecovery = nil
		STATE._equipRetryAt = 0
		STATE._plotTestData = function()
			local pets = {}
			local bag = {}
			if retryOn then
				pets.old = { uid = "old", key = "Cat", pos = { x = 3, z = 4 } }
			else
				bag.old = { uid = "old", key = "Cat" }
			end
			return { baseLevel = 1, plotPets = pets, backpack = bag }
		end
		STATE._plotTestInvoke = function(name, uid, x, z)
			retryLog[#retryLog + 1] = { name = name, uid = uid, x = x, z = z }
			if name == "PickupPet" and uid == "old" then
				retryOn = false
			elseif name == "PlacePet" and uid == "old" then
				retryPlaces += 1
				if retryPlaces >= 2 then
					retryOn = true
				end
			end
		end
		local retryStatus = STATE.commitEquip("new", "old", 3, 4, false)
		local retryKept = type(STATE._equipRecovery) == "table" and STATE._equipTxn == nil and STATE._equipRecovery.phase == "restoring"
		local retryScheduled = (STATE._equipRetryAt or 0) > os.clock()
		STATE._equipRetryAt = 0
		local retryNewBefore = 0
		for _, call in ipairs(retryLog) do
			if call.name == "PlacePet" and call.uid == "new" then
				retryNewBefore += 1
			end
		end
		local retryAgain = STATE.recoverEquipSwap() == true
		local retryNewAfter = 0
		for _, call in ipairs(retryLog) do
			if call.name == "PlacePet" and call.uid == "new" then
				retryNewAfter += 1
			end
		end
		local retryLast = retryLog[#retryLog]
		report.retryRestore = retryStatus ~= true and retryKept and retryScheduled and retryAgain and retryOn == true and retryPlaces == 2 and retryNewBefore == retryNewAfter and retryLast and retryLast.name == "PlacePet" and retryLast.uid == "old" and retryLast.x == 3 and retryLast.z == 4 and STATE._equipRecovery == nil
		local settleLog = {}
		local settleReads = 0
		STATE._equipTxn = nil
		STATE._equipRetryAt = 0
		STATE._equipRecovery = {
			gen = savedGen - 1,
			token = savedToken - 1,
			oldUid = "old",
			oldX = 3,
			oldZ = 4,
			newUid = "new",
			phase = "placing",
		}
		STATE._plotTestInvoke = function(name, uid)
			settleLog[#settleLog + 1] = { name = name, uid = uid }
		end
		STATE._plotTestData = function()
			settleReads += 1
			local pets = {}
			local bag = { old = { uid = "old", key = "Cat" } }
			if settleReads >= 5 then
				pets.newpet = { uid = "new", key = "Dog", pos = { x = 1, z = 2 } }
			end
			return { baseLevel = 1, plotPets = pets, backpack = bag }
		end
		local settleRan = STATE.recoverEquipSwap()
		local settleBlind = #settleLog == 0
		report.lateAfterReplace = settleRan == false and settleReads >= 5 and settleBlind and STATE._equipRecovery == nil
		STATE._equipRecovery = {
			gen = savedGen - 1,
			token = savedToken - 1,
			oldUid = "old",
			oldX = 3,
			oldZ = 4,
			newUid = "new",
			phase = "picked-up",
		}
		local missingCalls = 0
		STATE._plotTestInvoke = function()
			missingCalls += 1
		end
		STATE._plotTestData = function()
			return { baseLevel = 1, plotPets = {} }
		end
		local missingRan = STATE.recoverEquipSwap()
		report.missingBackpack = missingRan == false and missingCalls == 0 and type(STATE._equipRecovery) == "table" and STATE._equipRecovery.oldUid == "old"
		local sentLog = {}
		local sentReads = 0
		local sentNew = false
		local sentOld = true
		STATE.equipBest = true
		STATE._plotLock = nil
		STATE._equipTxn = nil
		STATE._equipRecovery = nil
		STATE._equipRetryAt = 0
		STATE._equipRecovering = nil
		STATE._plotTestSlots = 4
		STATE._plotTestInvoke = function(name, uid, x, z)
			sentLog[#sentLog + 1] = { name = name, uid = uid, x = x, z = z }
			if name == "PickupPet" and uid == "old" then
				sentOld = false
			elseif name == "PlacePet" and uid == "new" then
				STATE.equipBest = false
			end
		end
		STATE._plotTestData = function()
			local second = sentLog[2]
			if second and second.name == "PlacePet" and second.uid == "new" and sentNew ~= true then
				sentReads += 1
				if sentReads >= 4 then
					sentNew = true
				end
			end
			local pets = {}
			local bag = {}
			if sentOld then
				pets.old = { uid = "old", key = "Cat", pos = { x = 3, z = 4 } }
			elseif sentNew ~= true then
				bag.old = { uid = "old", key = "Cat" }
			end
			if sentNew then
				pets.newpet = { uid = "new", key = "Dog", pos = { x = 1, z = 2 } }
			end
			return { baseLevel = 1, plotPets = pets, backpack = bag }
		end
		local sentStatus = STATE.commitEquip("new", "old", 3, 4, false)
		report.sentToggle = sentStatus == true and sentReads >= 4 and names(sentLog) == "PickupPet:old,PlacePet:new"
		local overlapLog = {}
		local overlapPlaces = 0
		local overlapOn = false
		STATE.equipBest = true
		STATE._plotLock = nil
		STATE._equipTxn = nil
		STATE._equipRetryAt = 0
		STATE._equipRecovering = nil
		STATE._equipRecovery = {
			gen = savedGen - 1,
			token = savedToken - 1,
			oldUid = "old",
			oldX = 3,
			oldZ = 4,
			newUid = "new",
			phase = "picked-up",
		}
		STATE._plotTestData = function()
			local pets = {}
			local bag = {}
			if overlapOn then
				pets.old = { uid = "old", key = "Cat", pos = { x = 3, z = 4 } }
			else
				bag.old = { uid = "old", key = "Cat" }
			end
			return { baseLevel = 1, plotPets = pets, backpack = bag }
		end
		STATE._plotTestInvoke = function(name, uid, x, z)
			overlapLog[#overlapLog + 1] = { name = name, uid = uid, x = x, z = z }
			if name == "PlacePet" and uid == "old" then
				overlapPlaces += 1
				if overlapPlaces == 1 then
					STATE.recoverEquipSwap()
				else
					overlapOn = true
				end
			end
		end
		local overlapFirst = STATE.recoverEquipSwap()
		local overlapBeforeRetry = overlapPlaces
		STATE._equipRetryAt = 0
		local overlapSecond = STATE.recoverEquipSwap()
		local overlapNew = 0
		for _, call in ipairs(overlapLog) do
			if call.uid == "new" then
				overlapNew += 1
			end
		end
		report.overlapRecover = overlapFirst == false and overlapSecond == true and overlapBeforeRetry == 1 and overlapPlaces == 2 and overlapNew == 0 and overlapOn == true and STATE._equipRecovery == nil
		local emptyCalls = 0
		STATE._equipTxn = nil
		STATE._equipRetryAt = 0
		STATE._equipRecovering = nil
		STATE._equipRecovery = {
			gen = savedGen - 1,
			token = savedToken - 1,
			oldUid = "old",
			oldX = 3,
			oldZ = 4,
			newUid = "new",
			phase = "picked-up",
		}
		STATE._plotTestInvoke = function()
			emptyCalls += 1
		end
		STATE._plotTestData = function()
			return { baseLevel = 1, plotPets = {}, backpack = {} }
		end
		local emptyKept = true
		for _ = 1, 8 do
			if STATE.recoverEquipSwap() ~= false or STATE._equipRecovery == nil then
				emptyKept = false
			end
		end
		report.emptyPending = emptyKept and emptyCalls == 0 and type(STATE._equipRecovery) == "table"
		STATE._equipRecovery = nil
		STATE.equipBest = true
		STATE.autoPlace = true
		STATE.autoSteal = true
		STATE._plotLock = nil
		local function holds(reason, toggle)
			STATE._plotLock = nil
			local first = STATE.acquirePlot(reason, toggle)
			local again = STATE.acquirePlot(reason, toggle)
			local place = STATE.acquirePlot("place", "autoPlace")
			local steal = STATE.acquirePlot("delivery", "autoSteal")
			local equip = STATE.acquirePlot("equip", "equipBest")
			local held = first ~= nil and again == nil and place == nil and steal == nil and equip == nil
			STATE.releasePlot(first)
			return held
		end
		report.overlap = holds("equip", "equipBest") and holds("place", "autoPlace") and holds("delivery", "autoSteal")
		STATE._equipRecovery = nil
		STATE._plotLock = nil
		STATE.equipBest = true
		local moved = false
		STATE._plotTestSlots = 1
		STATE._plotTestInvoke = function()
			moved = true
		end
		STATE.equipStatus = "Timed out waiting for confirmation"
		local worseIdle = STATE.noteEquipIdle(1, 5, false, true) == true and STATE.equipStatus == "Up to date" and (STATE.nextEquip or 0) > os.clock()
		local betterContinues = STATE.noteEquipIdle(9, 1, false, true) == false
		STATE.equipStatus = "Timed out waiting for confirmation"
		STATE.nextEquip = 0
		STATE._plotTestData = function()
			return { baseLevel = 1, plotPets = { plot = { uid = "plot", key = "Cat" } }, backpack = {} }
		end
		STATE.stepEquipBest()
		report.upToDate = worseIdle and betterContinues and STATE.equipStatus == "Up to date" and (STATE.nextEquip or 0) > os.clock() and moved == false
	end)
	cleanup()
	if not ok then
		report.error = tostring(err)
	end
	return report
end

function STATE.runRepairChecks()
	local webhookOk, webhookFailed = STATE.runWebhookParserTests()
	local urlA = "https://cdn.example.com/assets/same-tail-name.png"
	local urlB = "https://cdn.example.com/other/same-tail-name.png"
	local hashesDiffer = STATE.hashUrl(urlA) ~= STATE.hashUrl(urlB)
	local badUrl = STATE.canonicalHttps("http://cdn.example.com/a.png") == nil and STATE.canonicalHttps("https://user@cdn.example.com/a.png") == nil
	local png = string.char(137) .. "PNG" .. string.char(13, 10, 26, 10) .. string.rep("A", 64)
	local textBody = "this is not an image body at all"
	local notImage = STATE.imageFormat(textBody) == nil and STATE.imageFormat(png) == "png"
	local tooBig = #string.rep("A", 5 * 1024 * 1024 + 16) > 5 * 1024 * 1024
	local savedRoot = STATE._themeRoot
	local savedGen = STATE._gen
	local savedToken = genv.ZinoosGen
	STATE._themeRoot = "ZinoosHub/theme-repair-test"
	STATE.ensureThemeFolders()
	local foldersReady = typeof(isfolder) ~= "function" or isfolder("ZinoosHub/theme-repair-test") == true
	local stored = STATE.storeThemeBody(urlA, png, savedGen, savedToken)
	local other = STATE.storeThemeBody(urlB, png, savedGen, savedToken)
	local pathA = STATE.themeDir() .. "/" .. STATE.hashUrl(STATE.canonicalHttps(urlA)) .. ".png"
	local pathB = STATE.themeDir() .. "/" .. STATE.hashUrl(STATE.canonicalHttps(urlB)) .. ".png"
	local wroteDistinct = typeof(isfile) == "function" and isfile(pathA) and isfile(pathB) and pathA ~= pathB
	local rejectedText = STATE.storeThemeBody("https://cdn.example.com/note.txt", textBody .. textBody, savedGen, savedToken) == nil
	local rejectedUrl = STATE.storeThemeBody("https://cdn.example.com/a.png?x=1", png, savedGen, savedToken) == nil
	local oversized = string.char(137) .. "PNG" .. string.char(13, 10, 26, 10) .. string.rep("B", 5 * 1024 * 1024)
	local rejectedSize = STATE.storeThemeBody("https://cdn.example.com/big.png", oversized, savedGen, savedToken) == nil
	STATE._gen = -424242
	local stale = STATE.storeThemeBody("https://cdn.example.com/stale.png", png, savedGen, savedToken) == nil
	local stalePath = "ZinoosHub/theme-repair-test/" .. STATE.hashUrl("https://cdn.example.com/stale.png") .. ".png"
	local staleUnwritten = typeof(isfile) ~= "function" or isfile(stalePath) ~= true
	STATE._gen = savedGen
	if typeof(delfile) == "function" then
		pcall(delfile, pathA)
		pcall(delfile, pathB)
		pcall(delfile, "ZinoosHub/theme-repair-test/manifest.json")
	end
	STATE._themeRoot = savedRoot
	local themeHost = STATE.runThemeHostChecks()
	local authorityBypass = STATE.parseWebhook("https://discord.com:443@evil.example/api/webhooks/1/tok") == nil
	local plot = STATE.runPlotRepairChecks()
	local plotOk = plot.eggsSeparate == true and plot.fullNoFire == true and plot.fullStillBlocksPets == true and plot.timeoutOpen == true and plot.timeoutThenFull == true and plot.success == true and plot.failedPlace == true and plot.toggleRestores == true and plot.generationRestores == true and plot.latePlan == true and plot.lateSwap == true and plot.delayedToggle == true and plot.retryRestore == true and plot.lateAfterReplace == true and plot.missingBackpack == true and plot.sentToggle == true and plot.overlapRecover == true and plot.emptyPending == true and plot.overlap == true and plot.upToDate == true and plot.error == nil
	return {
		webhookOk = webhookOk,
		webhookFailed = webhookFailed,
		authorityBypass = authorityBypass,
		hashesDiffer = hashesDiffer,
		badUrl = badUrl,
		notImage = notImage,
		tooBig = tooBig,
		foldersReady = foldersReady,
		stored = type(stored) == "string" or wroteDistinct,
		wroteDistinct = wroteDistinct,
		rejectedText = rejectedText,
		rejectedUrl = rejectedUrl,
		rejectedSize = rejectedSize,
		stale = stale and staleUnwritten,
		themeHost = themeHost,
		plot = plot,
		plotOk = plotOk,
	}
end

startupFinished = true
