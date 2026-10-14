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
	warn(string.format("[Zinoos hub] %s is off because %s is missing.", name, dependency))
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
		if child.Name == "ZinoosEggValue" or child.Name == "ZinoosHoldValue" then
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

function STATE.plotRoom()
	local data = readData()
	if type(data) ~= "table" or typeof(Plot) ~= "table" or typeof(Plot.Slots) ~= "function" then
		return nil
	end
	local level = data.baseLevel
	if type(level) ~= "number" then
		level = 0
	end
	local ok, slots = pcall(Plot.Slots, level)
	if not ok or type(slots) ~= "number" then
		return nil
	end
	local occupied = 0
	if type(data.plotPets) == "table" then
		for _, pet in pairs(data.plotPets) do
			if type(pet) == "table" then
				occupied += 1
			end
		end
	end
	return {
		slots = slots,
		occupied = occupied,
		free = occupied < slots,
	}
end

function STATE.placeHoldActive()
	local room = STATE.plotRoom()
	if room and room.free == true then
		STATE.placeHoldUntil = 0
		STATE.placeHoldCount = nil
	elseif room and type(STATE.placeHoldCount) == "number" and room.occupied < STATE.placeHoldCount then
		STATE.placeHoldUntil = 0
		STATE.placeHoldCount = nil
	end
	return os.clock() < (STATE.placeHoldUntil or 0)
end

function STATE.markPlaceHold()
	local room = STATE.plotRoom()
	STATE.placeHoldCount = room and room.occupied or nil
	STATE.placeHoldUntil = os.clock() + 12
	STATE.placeStatus = "Plot full"
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
		return false
	end
	if not fromSteal and STATE.autoPlace ~= true then
		return nil
	end
	local function note(text)
		if fromSteal and STATE.autoPlace ~= true and text ~= "Plot full" then
			return
		end
		STATE.placeStatus = text
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
	if STATE.placeHoldActive() then
		note("Plot full")
		return "full"
	end
	local chosen = STATE.collectPlaceEggs()[1]
	if not chosen or typeof(chosen.tool) ~= "Instance" then
		if not fromSteal then
			note("No selected eggs")
		end
		return nil
	end
	local tool = chosen.tool
	local uid = chosen.uid
	local eggName = type(chosen.name) == "string" and chosen.name or "egg"
	if type(uid) ~= "string" or not STATE.eggWorthPlacing(tool) then
		return nil
	end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	local leftTraining = false
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
	local function finish(result)
		if leftTraining then
			STATE.placeBusy = false
		end
		return result
	end
	if typeof(ClientRegistry) ~= "table" or typeof(ClientRegistry.Get) ~= "function" then
		return finish(false)
	end
	local plot = ClientRegistry.Get("PlotController"):GetPlot(LocalPlayer)
	local base = plot and plot:FindFirstChild("Base")
	if not (base and base:IsA("BasePart")) then
		return finish(false)
	end
	if fromSteal then
		local homeUntil = os.clock() + 3
		while not withinReach(base) and os.clock() < homeUntil and running() do
			task.wait(0.1)
		end
	end
	if not withinReach(base) then
		return finish("away")
	end
	note("Placing " .. eggName)
	local fired = false
	for attempt = 1, 3 do
		if not running() or (not fromSteal and STATE.autoPlace ~= true) then
			return finish(false)
		end
		if fired and (tool.Parent == nil or STATE.petOnPlot(uid)) then
			note("Placed " .. eggName)
			return finish(true)
		end
		if tool.Parent ~= nil and not STATE.eggWorthPlacing(tool) then
			return finish(nil)
		end
		if tool.Parent ~= character then
			local backpack = LocalPlayer:FindFirstChild("Backpack")
			if tool.Parent ~= backpack then
				break
			end
			humanoid:EquipTool(tool)
			task.wait(0.15)
		end
		local spread = attempt == 1 and 0.25 or (attempt == 2 and 0.45 or 0.7)
		local x = (math.random() - 0.5) * base.Size.X * spread
		local z = (math.random() - 0.5) * base.Size.Z * spread
		if type(x) ~= "number" or type(z) ~= "number" then
			break
		end
		Net:FireServer("PlacePet", uid, x, z)
		fired = true
		task.wait(0.8)
		if tool.Parent == nil or STATE.petOnPlot(uid) then
			note("Placed " .. eggName)
			return finish(true)
		end
		if attempt < 3 then
			task.wait(0.3)
		end
	end
	if fired then
		STATE.markPlaceHold()
		return finish("full")
	end
	return finish("away")
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
	if STATE.placeHoldActive() then
		STATE.placeStatus = "Plot full"
		STATE.nextAutoPlace = STATE.placeHoldUntil
		return
	end
	STATE.placeStatus = "Scanning inventory"
	local placed = STATE.placeSelectedEgg(false)
	if placed == "full" then
		STATE.placeStatus = "Plot full"
		STATE.nextAutoPlace = os.clock() + 3
	elseif placed == "away" then
		STATE.placeStatus = "Scanning inventory"
		STATE.nextAutoPlace = os.clock() + 2
	elseif placed == true then
		STATE.nextAutoPlace = os.clock() + 0.6
	elseif placed == nil then
		STATE.placeStatus = "No selected eggs"
		STATE.nextAutoPlace = os.clock() + 1.2
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

local function webhookUrl()
	local raw = type(STATE.webhook) == "string" and STATE.webhook or ""
	local url = string.match(raw, "^%s*(https://%S+)%s*$")
	if not url then
		return nil
	end
	local host, path = string.match(url, "^https://([^/%s]+)(/.*)$")
	if not host or not path then
		return nil
	end
	host = string.lower(host)
	local portAt = string.find(host, ":", 1, true)
	if portAt then
		host = string.sub(host, 1, portAt - 1)
	end
	if string.sub(host, 1, 4) == "www." then
		host = string.sub(host, 5)
	end
	local webhookPrefix = "/api/webhooks/"
	if not webhookHosts[host] or string.sub(path, 1, #webhookPrefix) ~= webhookPrefix then
		return nil
	end
	return url
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
		sendWebhook(url, {
			username = "Zinoos hub",
			embeds = {
				{
					title = kind,
					description = string.format("**%s**\n%s\n%s", clean, rarity, money or ""),
					color = 16098851,
				},
			},
		})
	end)
	return true
end

local liteHooked = setmetatable({}, { __mode = "k" })

local function hideOne(child)
	if child:IsA("BasePart") then
		if child.LocalTransparencyModifier ~= 1 then
			child.LocalTransparencyModifier = 1
		end
		if child.CastShadow then
			child:SetAttribute("ZinoosShadow", true)
			child.CastShadow = false
		end
	elseif child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam") or child:IsA("Light") or child:IsA("Highlight") then
		if child.Enabled then
			child:SetAttribute("ZinoosHid", true)
			child.Enabled = false
		end
	end
end

local function hideVisual(model)
	if model:GetAttribute("ZinoosLite") ~= true then
		local animator = model:FindFirstChildWhichIsA("Animator", true)
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop()
			end
		end
		for _, child in ipairs(model:GetDescendants()) do
			hideOne(child)
		end
		model:SetAttribute("ZinoosLite", true)
	end
	if liteHooked[model] then
		return
	end
	liteHooked[model] = true
	STATE.connect(model.DescendantAdded, function(child)
		if running() and STATE.litePets == true then
			hideOne(child)
		end
		return model
	end, model)
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
		eachPlaced(hideVisual)
		if friends then
			for _, model in ipairs(friends:GetChildren()) do
				if model:IsA("Model") then
					hideVisual(model)
				end
			end
		end
	elseif STATE._liteWasOn == true then
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
	for _, child in ipairs(frame:GetChildren()) do
		local tag = child:FindFirstChild("ZinoosValue")
		if tag then
			tag:Destroy()
		end
		if child:IsA("GuiObject") then
			for _, nested in ipairs(child:GetChildren()) do
				local nestedTag = nested:FindFirstChild("ZinoosValue")
				if nestedTag then
					nestedTag:Destroy()
				end
			end
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
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiButton") and child:FindFirstChild("ToolName") then
			callback(child)
		elseif child:IsA("GuiObject") then
			for _, nested in ipairs(child:GetChildren()) do
				if nested:IsA("GuiButton") and nested:FindFirstChild("ToolName") then
					callback(nested)
				end
			end
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
		local slots = {}
		eachSlot(frame, function(slot)
			slots[#slots + 1] = slot
		end)
		table.sort(slots, function(a, b)
			return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
		end)
		for _, slot in ipairs(slots) do
			local nameLabel = slot:FindFirstChild("ToolName")
			local queue = nameLabel and queues[nameLabel.Text]
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
}

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
	if type(saved.WebhookUrl) == "string" then
		STATE.webhook = saved.WebhookUrl
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
		WebhookUrl = type(STATE.webhook) == "string" and STATE.webhook or "",
		MenuX = STATE.menuX,
		MenuY = STATE.menuY,
		DockX = STATE.dockX,
		DockY = STATE.dockY,
		DockCustom = STATE.dockCustom == true,
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

local function installHub()
	closeLeftoverMenus()

	local accent = Color3.fromRGB(255, 79, 158)
	local ink = Color3.fromRGB(245, 240, 248)
	local muted = Color3.fromRGB(176, 160, 190)
	local panel = Color3.fromRGB(24, 18, 32)
	local side = Color3.fromRGB(32, 24, 42)
	local cardColor = Color3.fromRGB(40, 30, 52)
	local off = Color3.fromRGB(62, 48, 76)
	local line = Color3.fromRGB(70, 52, 86)

	local TweenService = game:GetService("TweenService")
	local motion = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function playMotion(object, props)
		local tween = TweenService:Create(object, motion, props)
		tween:Play()
		return tween
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
	local function fitScale()
		local view = viewSize()
		local margin = 16
		local scale = math.min((view.X - margin * 2) / 700, (view.Y - margin * 2) / 468, 1)
		uiScale.Scale = math.clamp(scale, 0.35, 1)
	end
	fitScale()

	local launcher = Instance.new("TextButton")
	launcher.Name = "Zinoos hub"
	launcher.AutoButtonColor = false
	launcher.Text = "Zinoos  0:00"
	launcher.Font = Enum.Font.GothamBold
	launcher.TextSize = 14
	launcher.TextColor3 = ink
	launcher.BackgroundColor3 = panel
	launcher.Size = UDim2.fromOffset(132, 36)
	launcher.Position = UDim2.new(1, -148, 0.62, 0)
	launcher.Visible = false
	launcher.Parent = gui
	local launcherCorner = Instance.new("UICorner")
	launcherCorner.CornerRadius = UDim.new(1, 0)
	launcherCorner.Parent = launcher
	local launcherStroke = Instance.new("UIStroke")
	launcherStroke.Color = accent
	launcherStroke.Thickness = 1.5
	launcherStroke.Parent = launcher

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(700, 468)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local windowScale = Instance.new("UIScale")
	windowScale.Name = "WindowMotion"
	windowScale.Parent = holder

	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.45
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
	window.BorderSizePixel = 0
	window.Size = UDim2.fromScale(1, 1)
	window.ZIndex = 2
	window.Parent = holder
	local windowCorner = Instance.new("UICorner")
	windowCorner.CornerRadius = UDim.new(0, 16)
	windowCorner.Parent = window
	local windowStroke = Instance.new("UIStroke")
	windowStroke.Color = line
	windowStroke.Thickness = 1
	windowStroke.Parent = window

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundColor3 = side
	sidebar.BorderSizePixel = 0
	sidebar.Size = UDim2.new(0, 168, 1, 0)
	sidebar.ZIndex = 3
	sidebar.Parent = window
	local sideCorner = Instance.new("UICorner")
	sideCorner.CornerRadius = UDim.new(0, 16)
	sideCorner.Parent = sidebar
	local sideFill = Instance.new("Frame")
	sideFill.BackgroundColor3 = side
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
	markText.TextColor3 = Color3.new(1, 1, 1)
	markText.TextSize = 16
	markText.Size = UDim2.fromScale(1, 1)
	markText.ZIndex = 5
	markText.Parent = mark

	local brand = Instance.new("TextLabel")
	brand.BackgroundTransparency = 1
	brand.Font = Enum.Font.GothamBold
	brand.Text = "Zinoos"
	brand.TextColor3 = ink
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
	brandSub.TextSize = 12
	brandSub.TextXAlignment = Enum.TextXAlignment.Left
	brandSub.Position = UDim2.fromOffset(52, 32)
	brandSub.Size = UDim2.new(1, -60, 0, 16)
	brandSub.ZIndex = 4
	brandSub.Parent = sidebar

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(168, 0)
	content.Size = UDim2.new(1, -168, 1, 0)
	content.ZIndex = 3
	content.Parent = window

	local header = Instance.new("Frame")
	header.Name = "DragBar"
	header.Active = true
	header.BackgroundColor3 = Color3.fromRGB(32, 24, 42)
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, 52)
	header.ZIndex = 4
	header.Parent = content
	local pageTitle = Instance.new("TextLabel")
	pageTitle.BackgroundTransparency = 1
	pageTitle.Font = Enum.Font.GothamBold
	pageTitle.Text = "Home"
	pageTitle.TextColor3 = ink
	pageTitle.TextSize = 18
	pageTitle.TextXAlignment = Enum.TextXAlignment.Left
	pageTitle.Position = UDim2.fromOffset(18, 0)
	pageTitle.Size = UDim2.new(0.4, 0, 1, 0)
	pageTitle.ZIndex = 4
	pageTitle.Parent = header

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.BackgroundColor3 = cardColor
	search.BorderSizePixel = 0
	search.ClearTextOnFocus = false
	search.Font = Enum.Font.Gotham
	search.PlaceholderText = "Search"
	search.PlaceholderColor3 = muted
	search.Text = ""
	search.TextColor3 = ink
	search.TextSize = 14
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.AnchorPoint = Vector2.new(1, 0.5)
	search.Position = UDim2.new(1, -52, 0.5, 0)
	search.Size = UDim2.fromOffset(180, 32)
	search.ZIndex = 5
	search.Parent = header
	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 8)
	searchCorner.Parent = search
	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 10)
	searchPad.Parent = search

	local closeButton = Instance.new("TextButton")
	closeButton.AutoButtonColor = false
	closeButton.Text = "X"
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 14
	closeButton.TextColor3 = muted
	closeButton.BackgroundTransparency = 1
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -12, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(28, 28)
	closeButton.ZIndex = 5
	closeButton.Parent = header

	local pageHost = Instance.new("Frame")
	pageHost.BackgroundTransparency = 1
	pageHost.Position = UDim2.fromOffset(0, 52)
	pageHost.Size = UDim2.new(1, 0, 1, -52)
	pageHost.ZIndex = 4
	pageHost.Parent = content

	local pages = {}
	local navButtons = {}
	local function newPage(name)
		local page = Instance.new("ScrollingFrame")
		page.Name = name
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Size = UDim2.fromScale(1, 1)
		page.ScrollBarThickness = 4
		page.ScrollBarImageColor3 = accent
		page.CanvasSize = UDim2.new()
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.Visible = false
		page.ZIndex = 4
		page.Parent = pageHost
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingRight = UDim.new(0, 16)
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 16)
		pad.Parent = page
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = page
		local pageScale = Instance.new("UIScale")
		pageScale.Name = "PageMotion"
		pageScale.Parent = page
		pages[name] = page
		return page
	end

	local homePage = newPage("Home")
	local mainPage = newPage("Main")
	local discordPage = newPage("Discord")

	local function showPage(name)
		for pageName, page in pairs(pages) do
			local show = pageName == name
			page.Visible = show
			if show then
				local pageScale = page:FindFirstChild("PageMotion")
				if pageScale and pageScale:IsA("UIScale") then
					pageScale.Scale = 0.985
					playMotion(pageScale, { Scale = 1 })
				end
			end
		end
		pageTitle.Text = name
		for buttonName, button in pairs(navButtons) do
			playMotion(button, { BackgroundTransparency = buttonName == name and 0 or 1 })
		end
	end

	local function onActivate(control, callback, selectable)
		control.Active = true
		control.Selectable = selectable ~= false
		control.Activated:Connect(callback)
	end

	local function addNav(name, order)
		local button = Instance.new("TextButton")
		button.Name = name
		button.AutoButtonColor = false
		button.Text = "   " .. name
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 14
		button.TextColor3 = ink
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.BackgroundColor3 = Color3.fromRGB(54, 36, 64)
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(12, 64 + (order - 1) * 40)
		button.Size = UDim2.new(1, -24, 0, 34)
		button.ZIndex = 4
		button.Parent = sidebar
		local navCorner = Instance.new("UICorner")
		navCorner.CornerRadius = UDim.new(0, 8)
		navCorner.Parent = button
		navButtons[name] = button
		onActivate(button, function()
			showPage(name)
		end)
	end
	addNav("Home", 1)
	addNav("Main", 2)
	addNav("Discord", 3)

	local profile = Instance.new("Frame")
	profile.BackgroundTransparency = 1
	profile.AnchorPoint = Vector2.new(0, 1)
	profile.Position = UDim2.new(0, 12, 1, -12)
	profile.Size = UDim2.new(1, -24, 0, 42)
	profile.ZIndex = 4
	profile.Parent = sidebar
	local avatar = Instance.new("ImageLabel")
	avatar.BackgroundColor3 = cardColor
	avatar.BorderSizePixel = 0
	avatar.Size = UDim2.fromOffset(32, 32)
	avatar.Position = UDim2.fromOffset(0, 5)
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
		end
	end)
	local profileName = Instance.new("TextLabel")
	profileName.BackgroundTransparency = 1
	profileName.Font = Enum.Font.GothamBold
	profileName.Text = LocalPlayer.DisplayName
	profileName.TextColor3 = ink
	profileName.TextSize = 13
	profileName.TextXAlignment = Enum.TextXAlignment.Left
	profileName.TextTruncate = Enum.TextTruncate.AtEnd
	profileName.Position = UDim2.fromOffset(40, 4)
	profileName.Size = UDim2.new(1, -40, 0, 16)
	profileName.ZIndex = 5
	profileName.Parent = profile
	local profileGame = Instance.new("TextLabel")
	profileGame.BackgroundTransparency = 1
	profileGame.Font = Enum.Font.Gotham
	profileGame.Text = "Lift Rock For Eggs"
	profileGame.TextColor3 = muted
	profileGame.TextSize = 11
	profileGame.TextXAlignment = Enum.TextXAlignment.Left
	profileGame.Position = UDim2.fromOffset(40, 20)
	profileGame.Size = UDim2.new(1, -40, 0, 14)
	profileGame.ZIndex = 5
	profileGame.Parent = profile

	local function label(parent, text, size, color, font, height)
		local item = Instance.new("TextLabel")
		item.BackgroundTransparency = 1
		item.Font = font or Enum.Font.Gotham
		item.Text = text
		item.TextColor3 = color or ink
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
		local box = Instance.new("Frame")
		box.Name = title
		box.BackgroundColor3 = cardColor
		box.BorderSizePixel = 0
		box.LayoutOrder = order
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.Size = UDim2.new(1, 0, 0, 0)
		box.ZIndex = 5
		box.Parent = parent
		local boxCorner = Instance.new("UICorner")
		boxCorner.CornerRadius = UDim.new(0, 12)
		boxCorner.Parent = box
		local boxPad = Instance.new("UIPadding")
		boxPad.PaddingTop = UDim.new(0, 10)
		boxPad.PaddingBottom = UDim.new(0, 10)
		boxPad.PaddingLeft = UDim.new(0, 12)
		boxPad.PaddingRight = UDim.new(0, 12)
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
		local goal = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		local color = on and accent or off
		if instant then
			knob.Position = goal
			track.BackgroundColor3 = color
			return
		end
		playMotion(knob, { Position = goal })
		playMotion(track, { BackgroundColor3 = color })
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
	local popup = Instance.new("Frame")
	popup.BackgroundColor3 = Color3.fromRGB(32, 24, 44)
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
		local selected = {}
		if multiple and type(current) == "table" then
			for _, name in ipairs(current) do
				selected[name] = true
			end
		end
		local selectedIndex = 1
		local foundSelected = false
		local function paintChoice(choice, option)
			local on = (multiple and selected[option] == true) or (not multiple and option == current)
			choice.BackgroundColor3 = on and Color3.fromRGB(64, 36, 58) or Color3.fromRGB(32, 24, 44)
			choice.BackgroundTransparency = on and 0 or 1
			choice.Text = (on and "  ✓ " or "    ") .. option
		end
		for index, option in ipairs(options) do
			if multiple and selected[option] and not foundSelected then
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
					selected[option] = not selected[option]
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
		playMotion(popup, { Size = UDim2.fromOffset(popupWidth, popupHeight) })
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
		pick.TextXAlignment = stacked and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		pick.TextTruncate = Enum.TextTruncate.AtEnd
		pick.Text = stacked and (" " .. getValue()) or getValue()
		pick.BackgroundColor3 = Color3.fromRGB(28, 20, 38)
		pick.AnchorPoint = stacked and Vector2.new(0, 1) or Vector2.new(1, 0.5)
		pick.Position = stacked and UDim2.new(0, 0, 1, 0) or UDim2.new(1, 0, 0.5, 0)
		pick.Size = stacked and UDim2.new(1, 0, 0, 26) or UDim2.fromOffset(132, 26)
		pick.ZIndex = 7
		pick.Parent = row
		local pickCorner = Instance.new("UICorner")
		pickCorner.CornerRadius = UDim.new(0, 8)
		pickCorner.Parent = pick
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
		pick.TextXAlignment = Enum.TextXAlignment.Left
		pick.TextTruncate = Enum.TextTruncate.AtEnd
		pick.Text = " " .. STATE.rarityLabel(getList())
		pick.BackgroundColor3 = Color3.fromRGB(28, 20, 38)
		pick.AnchorPoint = Vector2.new(1, 0.5)
		pick.Position = UDim2.new(1, 0, 0.5, 0)
		pick.Size = UDim2.fromOffset(156, 26)
		pick.ZIndex = 7
		pick.Parent = row
		local pickCorner = Instance.new("UICorner")
		pickCorner.CornerRadius = UDim.new(0, 8)
		pickCorner.Parent = pick
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
	columnLayout.Padding = UDim.new(0, 10)
	columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	columnLayout.Parent = columns

	local function column(order)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Size = UDim2.new(0.5, -5, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Parent = columns
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 10)
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
	makeSwitch(screenCard, "Egg ESP", "eggEsp")
	makeSwitch(screenCard, "Inventory ESP", "invEsp")
	makeSwitch(screenCard, "Low End", "lowEnd")

	local training = card(rightColumn, "TRAINING", 1)
	makeSwitch(training, "Auto Train", "autoTrain")
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
		chip.BorderSizePixel = 0
		chip.LayoutOrder = order
		chip.Size = UDim2.new(0.5, -5, 0, 58)
		chip.ZIndex = 5
		chip.Parent = parentFrame
		local chipCorner = Instance.new("UICorner")
		chipCorner.CornerRadius = UDim.new(0, 12)
		chipCorner.Parent = chip
		local chipTitle = Instance.new("TextLabel")
		chipTitle.BackgroundTransparency = 1
		chipTitle.Font = Enum.Font.Gotham
		chipTitle.Text = title
		chipTitle.TextColor3 = muted
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
		chipValue.TextSize = 18
		chipValue.TextXAlignment = Enum.TextXAlignment.Left
		chipValue.Position = UDim2.fromOffset(12, 26)
		chipValue.Size = UDim2.new(1, -20, 0, 24)
		chipValue.ZIndex = 6
		chipValue.Parent = chip
		return chipValue
	end

	local welcome = label(homePage, "Welcome", 22, ink, Enum.Font.GothamBold, 28)
	welcome.LayoutOrder = 1
	local blurb = label(homePage, "Stays on your bench. Grabs an egg of a ticked rarity, then comes back.", 14, muted, Enum.Font.Gotham, 36)
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
	local sessionText = label(homePage, "Session 0:00", 14, ink, Enum.Font.GothamBold, 20)
	sessionText.LayoutOrder = 3
	local statGrid = Instance.new("Frame")
	statGrid.BackgroundTransparency = 1
	statGrid.LayoutOrder = 4
	statGrid.Size = UDim2.new(1, 0, 0, 126)
	statGrid.Parent = homePage
	local strengthText = statChip(statGrid, "Strength", 1)
	strengthText.Parent.Position = UDim2.fromOffset(0, 0)
	local cashText = statChip(statGrid, "Cash", 2)
	cashText.Parent.Position = UDim2.new(0.5, 5, 0, 0)
	local rebirthText = statChip(statGrid, "Rebirths", 3)
	rebirthText.Parent.Position = UDim2.fromOffset(0, 68)
	local speedText = statChip(statGrid, "Speed", 4)
	speedText.Parent.Position = UDim2.new(0.5, 5, 0, 68)

	local note = card(homePage, "HOW IT WORKS", 5)
	local noteBody = label(note, "Tick every rarity you want stolen. Tick every rarity you want placed on your plot. An unticked egg stays in your bag. Nothing here sells pets.", 13, ink, Enum.Font.Gotham, 56)
	noteBody.LayoutOrder = 1

	local trackerCard = card(homePage, "EGG TRACKER", 6)
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
			trackerStatus.TextColor3 = muted
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
		if STATE.placeStatus == "Plot full" or (STATE.autoPlace == true and type(STATE.placeStatus) == "string" and STATE.placeStatus ~= "") then
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
		trackerStatus.TextColor3 = eligible > 0 and accent or muted
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
				slot.name.TextColor3 = egg.worth and ink or muted
				if egg.reason == "under a rock" or egg.reason == "unavailable" or egg.reason == "waiting for daytime" then
					slot.rare.Text = egg.reason
					slot.rare.TextColor3 = muted
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

	local discordBlurb = label(discordPage, "Get a Discord message when an eligible egg matching the selected rarity shows up, when you steal it, and when it hatches.", 14, muted, Enum.Font.Gotham, 40)
	discordBlurb.LayoutOrder = 1
	local discordCard = card(discordPage, "WEBHOOK", 2)
	makeSwitch(discordCard, "Webhook Alerts", "webhookOn")
	local urlBox = Instance.new("TextBox")
	urlBox.BackgroundColor3 = Color3.fromRGB(28, 20, 38)
	urlBox.BorderSizePixel = 0
	urlBox.ClearTextOnFocus = false
	urlBox.Font = Enum.Font.Gotham
	urlBox.PlaceholderText = "https://discord.com/api/webhooks/..."
	urlBox.PlaceholderColor3 = muted
	urlBox.Text = STATE.webhook or ""
	urlBox.TextColor3 = ink
	urlBox.TextSize = 13
	urlBox.TextXAlignment = Enum.TextXAlignment.Left
	urlBox.LayoutOrder = 3
	urlBox.Size = UDim2.new(1, 0, 0, 32)
	urlBox.ZIndex = 6
	urlBox.Parent = discordCard
	local urlCorner = Instance.new("UICorner")
	urlCorner.CornerRadius = UDim.new(0, 8)
	urlCorner.Parent = urlBox
	local urlPad = Instance.new("UIPadding")
	urlPad.PaddingLeft = UDim.new(0, 8)
	urlPad.PaddingRight = UDim.new(0, 8)
	urlPad.Parent = urlBox
	urlBox.FocusLost:Connect(function()
		STATE.webhook = urlBox.Text
		STATE.webhookControl.value = urlBox.Text
		STATE.webhookControl.currentValue = urlBox.Text
		saveConfig()
	end)
	remember(urlBox, discordCard, "discord webhook")

	local function actionButton(parentFrame, text, order, filled, callback)
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.Font = Enum.Font.GothamBold
		button.Text = text
		button.TextSize = 14
		button.TextColor3 = filled and Color3.new(1, 1, 1) or ink
		button.BackgroundColor3 = filled and accent or Color3.fromRGB(28, 20, 38)
		button.LayoutOrder = order
		button.Size = UDim2.new(1, 0, 0, 34)
		button.ZIndex = 6
		button.Parent = parentFrame
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button
		onActivate(button, callback)
		remember(button, parentFrame, text)
		return button
	end

	local hookStatus = label(discordCard, "", 13, muted, Enum.Font.Gotham, 32)
	hookStatus.LayoutOrder = 4
	hookStatus.TextWrapped = true
	local function showHookResult(text, ok)
		hookStatus.Text = text
		hookStatus.TextColor3 = ok and accent or Color3.fromRGB(255, 120, 150)
	end
	actionButton(discordCard, "Test Webhook", 5, false, function()
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
	actionButton(discordCard, "Unload", 6, true, function()
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
		launcher.Text = "Zinoos  " .. clockText
	end
	refreshSession()
	task.spawn(function()
		while running() and gui.Parent do
			pcall(refreshHome)
			pcall(refreshTracker)
			pcall(refreshSession)
			task.wait(1)
		end
	end)

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
			holder.Visible = true
			shadow.Visible = true
			launcher.Visible = false
			windowScale.Scale = 0.92
			playMotion(windowScale, { Scale = 1 })
			return
		end
		playMotion(windowScale, { Scale = 0.94 })
		task.delay(0.16, function()
			if token ~= openToken or not gui.Parent then
				return
			end
			holder.Visible = false
			shadow.Visible = false
			launcher.Visible = true
			windowScale.Scale = 1
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

	local saveCard = card(homePage, "CONFIG", 7)
	local saveNote = label(saveCard, "Saves the toggles, rarities, zone, and priority for this account. Your other account keeps its own save.", 13, muted, Enum.Font.Gotham, 40)
	saveNote.LayoutOrder = 1
	local saveResult = label(saveCard, "", 13, accent, Enum.Font.Gotham, 18)
	saveResult.LayoutOrder = 3
	actionButton(saveCard, "Save Config", 2, true, function()
		saveConfig()
		saveResult.Text = "Saved for " .. LocalPlayer.DisplayName
		saveResult.TextColor3 = accent
	end)

	windowScale.Scale = 0.92
	playMotion(windowScale, { Scale = 1 })

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
		pcall(stepUpgrade)
		task.wait(0.4)
		if not running() then
			break
		end
		pcall(stepTrails)
		task.wait(1.2)
	end
end)

task.spawn(function()
	while running() do
		STATE.stealTick = os.clock()
		local ok, result = pcall(runStealTrip)
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
			local placedOk = pcall(STATE.stepAutoPlace)
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

local function stepEquipBest()
	if STATE.equipBest ~= true or not featureReady("Equip Best") then
		return
	end
	if os.clock() < (STATE.nextEquip or 0) then
		return
	end
	local data = readData()
	if not data then
		return
	end
	local worstPet = nil
	local worst = math.huge
	local anyPlot = false
	for uid, pet in pairs(data.plotPets or {}) do
		if type(pet) == "table" and pet.hatchAt == nil then
			local spec = petSpec(pet.key)
			if not (spec and spec.IsEgg) then
				anyPlot = true
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
	if not bestPet or (anyPlot and best <= worst) then
		return
	end
	STATE.nextEquip = os.clock() + 1.4
	local placeUid = bestPet.uid
	local pickupUid = worstPet and (worstPet.uid)
	if type(placeUid) ~= "string" then
		return
	end
	task.spawn(function()
		Net:FireServer("EquipBestPets")
		if not (type(pickupUid) == "string" and best > worst) then
			return
		end
		Net:FireServer("PickupPet", pickupUid)
		task.wait(0.35)
		if not running() then
			return
		end
		local plot = ClientRegistry.Get("PlotController"):GetPlot(LocalPlayer)
		local base = plot and plot:FindFirstChild("Base")
		if not (base and base:IsA("BasePart")) then
			return
		end
		local x = (math.random() - 0.5) * math.min(base.Size.X * 0.35, 16)
		local z = (math.random() - 0.5) * math.min(base.Size.Z * 0.35, 16)
		if type(x) == "number" and type(z) == "number" then
			Net:FireServer("PlacePet", placeUid, x, z)
		end
	end)
end

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
		task.wait(4 * 60)
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
		pcall(stepView)
	end
	if os.clock() >= (STATE.nextInv or 0) then
		STATE.nextInv = os.clock() + (STATE.lowEnd == true and 2 or 1.2)
		pcall(stepInventory)
	end
	if os.clock() >= (STATE.nextHookScan or 0) then
		STATE.nextHookScan = os.clock() + 2
		pcall(scanNewPets)
	end
	if os.clock() >= (STATE.nextAnimals or 0) then
		STATE.nextAnimals = os.clock() + 1
		pcall(paintAnimals)
	end
	stepTrain()
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
	pcall(stepRebirth)
	pcall(popFreeBubbles)
	pcall(dismissPurchase)
	pcall(clearBestNotices)
	pcall(stepOpenEggs)
	pcall(stepEquipBest)
	pcall(stepDaily)
	pcall(stepIndex)
	pcall(stepStash)
end)

startupFinished = true
