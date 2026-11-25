-- Zinoos hub for Fish for Secret Animals!
-- Same WindUI window as the other Zinoos games. It casts for you (every cast is a
-- perfect cast), puts the best Sea Beasts in your pen, sells the rest, trains at
-- the gym, dives in the Sunken Treasury, buys upgrades and claims the free rewards.

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

if game.GameId ~= 10774303559 then
	warn("[Zinoos hub] This only runs in Fish for Secret Animals!")
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
if typeof(genv.ZinoosFishStop) == "function" then
	pcall(genv.ZinoosFishStop)
	elevate()
end
genv.ZinoosFishGen = (typeof(genv.ZinoosFishGen) == "number" and genv.ZinoosFishGen or 0) + 1
local token = genv.ZinoosFishGen
local function running()
	return genv.ZinoosFishGen == token
end

local STATE = {
	_gen = token,
	autoFish = true,
	perfectCast = true,
	catchMode = "Pen best, sell rest",
	keepRarity = "Legendary",
	keepMutated = true,
	autoTrain = true,
	split = "Mostly fish",
	autoDoubleRep = true,
	autoBuyRod = true,
	autoBuyPen = true,
	autoBuyBar = true,
	autoBuyBait = true,
	autoBestBait = true,
	useSpecialBait = true,
	autoClaim = true,
	autoCodes = true,
	autoIndex = true,
	autoAquarium = true,
	autoHatch = true,
	autoEquipPets = true,
	blockOffers = true,
	autoLair = true,
	lairSpot = "Hot Spring",
	lairRisk = "Smart",
	lairTime = "60s",
	autoDoubloons = true,
	walkSpeed = false,
	speed = 32,
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
	redeemed = {},
	toggleControls = {},
	status = "Starting",
	detail = "",
}
genv.ZinoosFishState = STATE

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
	if genv.ZinoosFishGen == token then
		genv.ZinoosFishGen = token + 1
	end
	STATE._unloaded = true
	STATE.walkSpeed = false
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
genv.ZinoosFishStop = shutdownHub
local function unloadHub()
	shutdownHub()
end

local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/FishSecretAnimals_" .. tostring(LocalPlayer.UserId) .. ".rfld"

local FLAG_KEYS = {
	AutoFish = "autoFish",
	PerfectCast = "perfectCast",
	KeepMutated = "keepMutated",
	AutoTrain = "autoTrain",
	AutoDoubleRep = "autoDoubleRep",
	AutoBuyRod = "autoBuyRod",
	AutoBuyPen = "autoBuyPen",
	AutoBuyBar = "autoBuyBar",
	AutoBuyBait = "autoBuyBait",
	AutoBestBait = "autoBestBait",
	UseSpecialBait = "useSpecialBait",
	AutoClaim = "autoClaim",
	AutoCodes = "autoCodes",
	AutoIndex = "autoIndex",
	AutoAquarium = "autoAquarium",
	AutoHatch = "autoHatch",
	AutoEquipPets = "autoEquipPets",
	BlockOffers = "blockOffers",
	AutoLair = "autoLair",
	AutoDoubloons = "autoDoubloons",
	WalkSpeed = "walkSpeed",
	AntiAfk = "antiAfk",
	AutoReconnect = "autoReconnect",
	NoPausePopup = "noPausePopup",
	FpsBoost = "fpsBoost",
	Disable3d = "disable3d",
	HideOnStart = "hideOnStart",
	Notifications = "notifications",
}

local CATCH_OPTIONS = { "Pen best, sell rest", "Keep everything", "Sell everything" }
local KEEP_OPTIONS = { "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" }
local SPLIT_OPTIONS = { "Mostly fish", "Even", "Mostly train" }
local SPLITS = {
	["Mostly fish"] = { 150, 45 },
	["Even"] = { 90, 90 },
	["Mostly train"] = { 45, 150 },
}
local LAIR_RISK_OPTIONS = { "Safe", "Smart", "Greedy" }
local LAIR_RISKS = { Safe = 0.6, Smart = 1, Greedy = 1.4 }
local LAIR_TIME_OPTIONS = { "30s", "60s", "120s", "240s" }
local LAIR_SPOT_OPTIONS = { "Hot Spring", "Ice Hole", "Pearl Pool", "Abyss Hole" }
local SPEED_OPTIONS = { "16", "24", "32", "50", "75", "100" }
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
local CHOICES = {
	CatchMode = { key = "catchMode", options = CATCH_OPTIONS },
	KeepRarity = { key = "keepRarity", options = KEEP_OPTIONS },
	Split = { key = "split", options = SPLIT_OPTIONS },
	LairSpot = { key = "lairSpot", options = LAIR_SPOT_OPTIONS },
	LairRisk = { key = "lairRisk", options = LAIR_RISK_OPTIONS },
	LairTime = { key = "lairTime", options = LAIR_TIME_OPTIONS },
	ToggleKey = { key = "toggleKey", options = KEY_OPTIONS },
	WindTheme = { key = "windTheme" },
	HubSize = { key = "hubSize", options = { "Compact", "Normal", "Large" } },
}
local LIST_KEYS = { Redeemed = "redeemed" }

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
	if type(saved.Speed) == "number" then
		STATE.speed = math.clamp(saved.Speed, 16, 100)
	end
	for flag, choice in pairs(CHOICES) do
		local value = saved[flag]
		if type(value) == "string" and (not choice.options or table.find(choice.options, value)) then
			STATE[choice.key] = value
		end
	end
	for flag, key in pairs(LIST_KEYS) do
		if type(saved[flag]) == "table" then
			local list = {}
			for _, value in ipairs(saved[flag]) do
				if type(value) == "string" then
					table.insert(list, value)
				end
			end
			STATE[key] = list
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
	local payload = { Speed = STATE.speed }
	for flag, key in pairs(FLAG_KEYS) do
		payload[flag] = STATE[key] == true
	end
	for flag, choice in pairs(CHOICES) do
		payload[flag] = STATE[choice.key]
	end
	for flag, key in pairs(LIST_KEYS) do
		payload[flag] = type(STATE[key]) == "table" and STATE[key] or {}
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if ok then
		pcall(writefile, CONFIG_PATH, encoded)
	end
end
STATE.writeConfig = saveConfig

local stats = { casts = 0, kept = 0, sold = 0, soldCash = 0, doubles = 0, bought = 0, claimed = 0, hatched = 0 }
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

local function attr(name)
	return LocalPlayer:GetAttribute(name)
end

local function cash()
	return tonumber(attr("Cash")) or 0
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

-- Game modules. Everything below talks to the game through its own Net module.
local Client = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Net = require(Client:WaitForChild("Net"))
local Cast = require(Client:WaitForChild("Cast"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
elevate()

local function call(name, ...)
	if not running() then
		return false, "stopped"
	end
	local packed = table.pack(...)
	local ok, a, b = pcall(function()
		return Net.invoke(name, table.unpack(packed, 1, packed.n))
	end)
	elevate()
	if not ok then
		return false, tostring(a)
	end
	return a, b
end

local function send(name, ...)
	if not running() then
		return
	end
	local packed = table.pack(...)
	pcall(function()
		Net.fire(name, table.unpack(packed, 1, packed.n))
	end)
	elevate()
end

local function gameState()
	local state = Net.State
	return type(state) == "table" and state or {}
end

local function beasts()
	local list = gameState().Beasts
	return type(list) == "table" and list or {}
end

local function carried()
	for _, beast in ipairs(beasts()) do
		if type(beast) == "table" and beast.S == "carry" then
			return beast
		end
	end
	return nil
end

local RARITY_RANK = {}
for index, rarity in ipairs(type(Config.Rarities) == "table" and Config.Rarities or {}) do
	if type(rarity) == "table" and rarity.Id then
		RARITY_RANK[rarity.Id] = index
	end
end

local function beastName(beast)
	local ok, name = pcall(Config.BeastName, beast.K)
	return ok and tostring(name) or tostring(beast.K)
end

local function beastRank(beast)
	local rarity
	local ok, shown = pcall(Config.ShownRarity, beast.K)
	if ok and type(shown) == "table" then
		rarity = shown.Id
	end
	if not rarity then
		local info = Config.BeastById[beast.K]
		rarity = type(info) == "table" and info.Rarity or nil
	end
	return RARITY_RANK[rarity] or 1, rarity or "Common"
end

local function beastValue(beast)
	local ok, value = pcall(Config.BeastValue, beast.K, beast.M)
	return ok and tonumber(value) or 0
end

-- Locked, exclusive, mutated (when kept) and rare-enough beasts are never sold.
local function protected(beast)
	if beast.L then
		return true
	end
	local info = Config.BeastById[beast.K]
	if type(info) ~= "table" or info.Exclusive then
		return true
	end
	if STATE.keepMutated and type(beast.M) == "string" and beast.M ~= "" then
		return true
	end
	return beastRank(beast) >= (RARITY_RANK[STATE.keepRarity] or 99)
end

local function isTraining()
	local char = LocalPlayer.Character
	return char ~= nil and char:GetAttribute("Training") == true
end

-- Perfect Cast: the game's own cast code checks this ReplicatedStorage attribute
-- and locks the power bar at the very top when it is set. It only exists on
-- this client.
local perfectSet = false
local function applyPerfect()
	local want = running() and STATE.autoFish == true and STATE.perfectCast == true
	if want then
		if ReplicatedStorage:GetAttribute("StudioPerfect") ~= true then
			ReplicatedStorage:SetAttribute("StudioPerfect", true)
		end
		perfectSet = true
	elseif perfectSet then
		perfectSet = false
		ReplicatedStorage:SetAttribute("StudioPerfect", nil)
	end
end
hubCleanup(function()
	if perfectSet then
		perfectSet = false
		pcall(function()
			ReplicatedStorage:SetAttribute("StudioPerfect", nil)
		end)
	end
end)

-- The power bar and the catch card both take Space, a click or a tap.
local VirtualInputManager = game:GetService("VirtualInputManager")
local function tap()
	if UserInputService:GetFocusedTextBox() then
		return
	end
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
		task.wait(0.04)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
	end)
end

-- The game's Robux offer popups (pen full, cash packs, Legend Lure...) stop the
-- next cast until someone closes them, so a full pen froze Auto Fish after one
-- catch. Every offer goes through the Offers module's show(), so the hub skips
-- it while Block Offer Popups is on and hides one that is already open.
local offers = { hooked = false, nextClose = 0 }
do
	local module = Client:FindFirstChild("Offers")
	if module then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type(result.show) == "function" then
			offers.module = result
			offers.show = result.show
		end
	end
	elevate()

	function offers.apply()
		local module = offers.module
		if not module then
			return
		end
		local want = running() and STATE.blockOffers == true
		if want and not offers.hooked then
			offers.hooked = true
			local original = offers.show
			module.show = function(...)
				if running() and STATE.blockOffers == true then
					return nil
				end
				return original(...)
			end
		elseif not want and offers.hooked then
			offers.hooked = false
			module.show = offers.show
		end
	end

	function offers.close()
		if STATE.blockOffers ~= true or os.clock() < offers.nextClose then
			return false
		end
		local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local gui = playerGui and playerGui:FindFirstChild("OfferGui")
		if not (gui and gui:IsA("ScreenGui") and gui.Enabled) then
			return false
		end
		offers.nextClose = os.clock() + 1
		gui.Enabled = false
		noteActivity("Closed a Robux offer popup")
		return true
	end

	-- What the game is waiting on before it will cast, for the status line.
	function offers.holding()
		local ok, held = pcall(function()
			return type(Cast.hold) == "function" and Cast.hold() == true
		end)
		elevate()
		return ok and held
	end
end
hubCleanup(function()
	if offers.hooked and offers.module then
		offers.hooked = false
		offers.module.show = offers.show
	end
end)

local fish = {
	aimSince = nil,
	aimDelay = 0.6,
	nextTap = 0,
	nextCast = 0,
	wasBusy = false,
	nextFill = 0,
	lastFill = 0,
	nextSell = 0,
	sellBlock = {},
	phase = "train",
	phaseUntil = 0,
	nextStart = 0,
	nextDouble = 0,
	nextBuy = 0,
	buyBlock = {},
	nextBait = 0,
	nextClaim = 0,
	claimBlock = {},
	nextPets = 0,
	nextAquarium = 0,
	hatchBlock = {},
	favoriteTried = false,
}

local function sellBeast(beast)
	local ok, value = call("SellBeast", beast.Id)
	if ok then
		stats.sold += 1
		stats.soldCash += tonumber(value) or 0
		return true
	end
	fish.sellBlock[beast.Id] = os.clock() + 120
	return false
end

-- A fresh catch is carried. Sell it, or put it away and let the game fill the
-- pen with your best Sea Beasts.
local function handleCatch()
	local beast = carried()
	if not beast then
		return false
	end
	local name = beastName(beast)
	if STATE.catchMode == "Sell everything" and not protected(beast) then
		local ok, value = call("Sell", "Landed")
		if ok then
			stats.sold += 1
			stats.soldCash += tonumber(value) or 0
			noteActivity("Sold " .. name .. " for $" .. shortNumber(value))
			return true
		end
	end
	send("PutAway")
	task.wait(0.35)
	send("FillPen")
	fish.lastFill = os.clock()
	fish.nextFill = os.clock() + 30
	stats.kept += 1
	local _, rarity = beastRank(beast)
	noteActivity("Caught " .. tostring(rarity) .. " " .. name)
	return true
end

-- Sell what is left in storage after the pen has been filled.
local function stepSellExtras()
	if os.clock() < fish.nextSell or STATE.catchMode == nil then
		return
	end
	fish.nextSell = os.clock() + 15
	if fish.lastFill == 0 or os.clock() - fish.lastFill < 2 then
		return
	end
	local stored = {}
	for _, beast in ipairs(beasts()) do
		if type(beast) == "table" and beast.S == "store" and not protected(beast) and (fish.sellBlock[beast.Id] or 0) < os.clock() then
			table.insert(stored, beast)
		end
	end
	if #stored == 0 then
		return
	end
	if STATE.catchMode == "Keep everything" then
		local limit = (tonumber(Config.MaxBeasts) or 100) - 5
		if #beasts() < limit then
			return
		end
		table.sort(stored, function(a, b)
			return beastValue(a) < beastValue(b)
		end)
		local extra = #beasts() - limit + 1
		for index = 1, math.min(extra, #stored) do
			sellBeast(stored[index])
			task.wait(0.25)
		end
		return
	end
	local sold = 0
	for _, beast in ipairs(stored) do
		if not running() or Cast.busy() then
			break
		end
		if sellBeast(beast) then
			sold += 1
		end
		task.wait(0.25)
		if sold >= 10 then
			break
		end
	end
	if sold > 0 then
		noteActivity("Sold " .. sold .. " extra Sea Beast" .. (sold == 1 and "" or "s"))
	end
end

local function stepFillPen()
	if STATE.catchMode == "Sell everything" or os.clock() < fish.nextFill then
		return
	end
	fish.nextFill = os.clock() + 30
	send("FillPen")
	fish.lastFill = os.clock()
end

local function stepFish()
	local busy = Cast.busy()
	if busy then
		fish.wasBusy = true
		if Cast.aiming() then
			fish.aimSince = fish.aimSince or os.clock()
			local wait = STATE.perfectCast and 0.25 or fish.aimDelay
			if os.clock() - fish.aimSince >= wait and os.clock() >= fish.nextTap then
				fish.nextTap = os.clock() + 0.5
				tap()
			end
			STATE.status = "Fishing"
			STATE.detail = STATE.perfectCast and "Locking a perfect cast" or "Aiming"
		else
			fish.aimSince = nil
			-- Skips the catch card the same way a tap would.
			if os.clock() >= fish.nextTap then
				fish.nextTap = os.clock() + 0.7
				tap()
			end
			STATE.status = "Fishing"
			STATE.detail = "Reeling it in"
		end
		return
	end
	fish.aimSince = nil
	if fish.wasBusy then
		fish.wasBusy = false
		stats.casts += 1
		fish.nextCast = os.clock() + 0.8
	end
	if os.clock() < fish.nextCast then
		return
	end
	if handleCatch() then
		fish.nextCast = os.clock() + 0.6
		return
	end
	local char = LocalPlayer.Character
	if char and char:GetAttribute("Riding") ~= nil then
		STATE.status = "Riding"
		STATE.detail = "Get off the ride to fish"
		return
	end
	if isTraining() then
		send("StopTraining")
		fish.nextCast = os.clock() + 0.8
		return
	end
	if offers.holding() then
		-- The game will not start a cast while one of its popups is open.
		offers.close()
		fish.nextCast = os.clock() + 0.5
		STATE.status = "Fishing"
		STATE.detail = STATE.blockOffers and "Waiting for a game popup to close" or "Close the game's popup to keep fishing"
		return
	end
	local ok, started = pcall(Cast.goFish)
	elevate()
	if ok and started then
		fish.aimDelay = 0.6 + math.random() * 0.9
		STATE.status = "Fishing"
		STATE.detail = "Casting"
	else
		fish.nextCast = os.clock() + 1.5
		STATE.status = "Waiting to cast"
	end
end

local function gymBar()
	local plot = attr("PlotIndex")
	local map = Workspace:FindFirstChild("Map")
	local gym = map and map:FindFirstChild("Gym")
	return gym and plot and gym:FindFirstChild("PullUpBar_" .. tostring(plot)) or nil
end

local function stepTrain()
	if Cast.busy() then
		stepFish()
		return
	end
	if isTraining() then
		STATE.status = "Training"
		STATE.detail = "Level " .. tostring(attr("Level") or 1) .. " · XP " .. tostring(attr("XP") or 0) .. "/" .. tostring(attr("XPNeed") or 0)
		return
	end
	if (tonumber(attr("BarTier")) or 0) < 1 then
		local ok = call("BuyTier", "Bar")
		if not ok then
			STATE.status = "Training"
			STATE.detail = "Need money for the first pull-up bar"
			return
		end
	end
	if handleCatch() then
		return
	end
	local _, root = character()
	local bar = gymBar()
	if not root or not bar then
		STATE.detail = "Looking for your pull-up bar"
		return
	end
	local pos = bar:GetPivot().Position
	local flat = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z).Magnitude
	if flat > 3 then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
		fish.nextStart = os.clock() + 0.4
	end
	if os.clock() >= fish.nextStart then
		fish.nextStart = os.clock() + 1.5
		send("StartTraining")
	end
	STATE.status = "Training"
	STATE.detail = "Getting on the bar"
end

local function stepDoubleRep()
	if STATE.autoDoubleRep ~= true or not isTraining() then
		return
	end
	if attr("DoubleRep") == true and os.clock() >= fish.nextDouble then
		fish.nextDouble = os.clock() + 0.4
		send("DoubleRep")
		stats.doubles += 1
	end
end

-- Sunken Treasury: doubloon dives. It opens once your power reaches the
-- Prehistoric sea. Each dive goes deeper for bigger chests while the snap
-- chance is worth it, then keeps the haul.
local LAIR = type(Config.Lair) == "table" and Config.Lair or {}
local LAIR_DEPTHS = type(LAIR.Depths) == "table" and LAIR.Depths or {}
local LAIR_LOOT_VALUE = { NeptunePearl = 3000, DivineBait = 90000, Egg = 1500, Skin = 25000, Beast = 25000 }
local lair = {
	nextDive = 0,
	nextEnter = 0,
	nextLeave = 0,
	nextShop = 0,
	dives = 0,
	snaps = 0,
	doubloons = 0,
	deepest = 0,
	fails = 0,
	token = nil,
}
STATE.lair = lair
-- Unloading mid-dive keeps what that dive already found.
hubCleanup(function()
	local open = lair.token
	lair.token = nil
	if open ~= nil then
		task.spawn(pcall, Net.invoke, "Lair", "keep", open)
	end
end)

local function lairOpen()
	local ok, open = pcall(Config.LairOpen, tonumber(attr("Power")) or 0)
	elevate()
	return ok and open == true
end
STATE.lairOpen = lairOpen

local function inLair()
	local _, root = character()
	local origin = LAIR.Origin
	return root ~= nil and typeof(origin) == "Vector3" and (root.Position - origin).Magnitude < 400
end

local function lairSpotId()
	for _, spot in ipairs(type(LAIR.Spots) == "table" and LAIR.Spots or {}) do
		if spot.Name == STATE.lairSpot then
			return spot.Id
		end
	end
	return "HotSpring"
end

local function chestAverage(depth)
	local row = LAIR_DEPTHS[depth]
	if type(row) ~= "table" then
		return 0
	end
	for _, chest in ipairs(type(LAIR.Chests) == "table" and LAIR.Chests or {}) do
		if chest.Id == row.Chest then
			return ((tonumber(chest.Min) or 0) + (tonumber(chest.Max) or 0)) / 2
		end
	end
	return 0
end

local function lootValue(got)
	if type(got) ~= "table" then
		return 0
	end
	if got.Kind == "Chest" then
		return tonumber(got.Doubloons) or 0
	end
	if got.SeaKing or got.Kind == "SeaKing" then
		return math.huge
	end
	local each = LAIR_LOOT_VALUE[got.Bait or ""] or LAIR_LOOT_VALUE[got.Kind or ""] or 3000
	return each * (tonumber(got.Count) or 1)
end

local function lootWords(got)
	if type(got) ~= "table" or got.Kind == "Chest" then
		return nil
	end
	if got.SeaKing or got.Kind == "SeaKing" then
		return "the SEA KING"
	end
	if got.Kind == "Bait" then
		local bait = Config.BaitById and Config.BaitById[got.Bait or ""]
		return tostring(got.Count or 1) .. "x " .. tostring(bait and bait.Name or got.Bait or "bait")
	end
	if got.Kind == "Beast" then
		return "a Sea Beast"
	end
	local word = string.lower(tostring(got.Kind or "prize"))
	return (string.find(word, "^[aeiou]") and "an " or "a ") .. word
end

local function stepLeaveLair()
	if not inLair() or os.clock() < lair.nextLeave then
		return false
	end
	lair.nextLeave = os.clock() + 3
	STATE.status = "Leaving the Treasury"
	STATE.detail = ""
	call("Lair", "leave")
	return true
end

-- One dive: go down while the snap chance is lower than what the next chest adds.
local function lairDive()
	local spotId = lairSpotId()
	local map = Workspace:FindFirstChild("Map")
	local lairMap = map and map:FindFirstChild("Lair")
	local spots = lairMap and lairMap:FindFirstChild("Spots")
	local spot = spots and spots:FindFirstChild(spotId)
	local _, root = character()
	if not spot or not root then
		STATE.detail = "Looking for the dive spot"
		lair.nextDive = os.clock() + 2
		return
	end
	local pos = spot:GetPivot().Position
	if (root.Position - pos).Magnitude > 6 then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
		task.wait(0.4)
	end
	local result, message = call("Lair", "dive", spotId, "Strong")
	if type(result) ~= "table" or result.Token == nil then
		lair.nextDive = os.clock() + 2
		if type(message) == "string" and message ~= "stopped" then
			STATE.detail = message
		end
		-- The server can forget you are down here (after a reload or a lag spike):
		-- going in again fixes it.
		lair.fails += 1
		if lair.fails >= 2 and running() then
			lair.fails = 0
			call("Lair", "stop")
			call("Lair", "enter")
			lair.nextDive = os.clock() + 1.5
		end
		return
	end
	lair.fails = 0
	local diveToken = result.Token
	lair.token = diveToken
	local depth = tonumber(result.Depth) or 1
	local snap = tonumber(result.Snap) or 1
	local haul = lootValue(result.Got)
	local found = {}
	local scale = 1
	local function learn(got, at)
		local average = chestAverage(at)
		if type(got) == "table" and got.Kind == "Chest" and average > 0 then
			scale = math.clamp((tonumber(got.Doubloons) or average) / average, 0.5, 3)
		end
		local words = lootWords(got)
		if words then
			table.insert(found, words)
		end
	end
	learn(result.Got, depth)
	local risk = LAIR_RISKS[STATE.lairRisk] or 1
	while running() and STATE.autoLair == true and depth < #LAIR_DEPTHS and haul ~= math.huge do
		local gain = chestAverage(depth + 1) * scale
		if gain <= 0 or snap >= gain / (haul + gain) * risk then
			break
		end
		STATE.status = "Sunken Treasury"
		STATE.detail = string.format("Depth %d · %s doubloons so far · %d%% snap risk", depth, shortNumber(haul), math.floor(snap * 100 + 0.5))
		local step
		local started = os.clock()
		repeat
			task.wait(0.3)
			step = call("Lair", "deeper", diveToken)
		until type(step) == "table" or os.clock() - started > 6 or not running()
		if type(step) ~= "table" then
			break
		end
		if step.Snapped then
			lair.token = nil
			lair.snaps += 1
			if #found > 0 then
				noteActivity("Line snapped at depth " .. tostring(depth + 1) .. ", lost " .. table.concat(found, ", "))
			end
			lair.nextDive = os.clock() + 1
			return
		end
		depth = tonumber(step.Depth) or depth + 1
		snap = tonumber(step.Snap) or 1
		haul += lootValue(step.Got)
		learn(step.Got, depth)
	end
	local kept
	for _ = 1, 20 do
		task.wait(0.3)
		kept = call("Lair", "keep", diveToken)
		if type(kept) == "table" or not running() then
			break
		end
	end
	lair.token = nil
	if type(kept) ~= "table" then
		call("Lair", "stop")
		lair.nextDive = os.clock() + 2
		return
	end
	local coins = tonumber(kept.Doubloons) or tonumber(kept.Total) or 0
	lair.dives += 1
	lair.doubloons += coins
	lair.deepest = math.max(lair.deepest, depth)
	-- Every dive is in the Treasury line on Home; only the good ones go in the log.
	if #found > 0 then
		notify("Treasury loot", table.concat(found, ", ") .. " · +" .. shortNumber(coins) .. " doubloons")
	elseif depth >= 7 then
		noteActivity("Treasury dive to depth " .. tostring(depth) .. ": +" .. shortNumber(coins) .. " doubloons")
	end
	lair.nextDive = os.clock() + 0.5
end

local function stepLair()
	if Cast.busy() then
		stepFish()
		return
	end
	if not inLair() then
		if handleCatch() then
			return
		end
		if isTraining() then
			send("StopTraining")
			return
		end
		if os.clock() < lair.nextEnter then
			return
		end
		lair.nextEnter = os.clock() + 4
		STATE.status = "Sunken Treasury"
		STATE.detail = "Diving down to the Treasury"
		local ok, message = call("Lair", "enter")
		if ok ~= true and type(message) == "string" and message ~= "stopped" then
			STATE.detail = message
			lair.nextEnter = os.clock() + 15
		end
		return
	end
	if os.clock() < lair.nextDive then
		return
	end
	STATE.status = "Sunken Treasury"
	STATE.detail = "Diving at the " .. tostring(STATE.lairSpot)
	lairDive()
end

-- Doubloon shop: Line Strength first (fewer snaps), then Luck, then keep a Luck Potion going.
local function stepDoubloons()
	if STATE.autoDoubloons ~= true or os.clock() < lair.nextShop then
		return
	end
	lair.nextShop = os.clock() + 5
	local coins = tonumber(attr("Doubloons")) or 0
	for _, id in ipairs({ "Line", "Luck" }) do
		local skill = Config.LairSkillById and Config.LairSkillById[id]
		if type(skill) == "table" and type(skill.Levels) == "table" then
			local level = math.clamp(math.floor(tonumber(attr("Lair" .. id)) or 0), 0, #skill.Levels)
			local row = skill.Levels[level + 1]
			if row then
				if coins >= (tonumber(row.Price) or math.huge) then
					local ok, message = call("Lair", "upgrade", id)
					if ok == true then
						stats.bought += 1
						notify(tostring(skill.Name) .. " upgraded", "Level " .. tostring(level + 1))
					elseif type(message) == "string" then
						noteActivity(tostring(skill.Name) .. ": " .. message)
						lair.nextShop = os.clock() + 30
					end
				end
				return
			end
		end
	end
	local potion = Config.LairShopById and Config.LairShopById.Luck
	local ends = tonumber(attr("LuckBoostEnds")) or 0
	if type(potion) == "table" and coins >= (tonumber(potion.Price) or math.huge) and ends < Workspace:GetServerTimeNow() then
		local ok, message = call("Lair", "buy", "Luck", nil, false)
		if ok == true then
			stats.bought += 1
			notify("Luck Potion", "x2 luck for " .. tostring(potion.Minutes or 15) .. " min")
		else
			if type(message) == "string" then
				noteActivity("Luck Potion: " .. message)
			end
			lair.nextShop = os.clock() + 60
		end
	end
end

-- Fishing, training and the Treasury take turns when more than one is on.
local function phaseList()
	local list = {}
	if STATE.autoFish == true then
		table.insert(list, "fish")
	end
	if STATE.autoTrain == true then
		table.insert(list, "train")
	end
	if STATE.autoLair == true and lairOpen() then
		table.insert(list, "dive")
	end
	return list
end

local function phaseLength(phase)
	local split = SPLITS[STATE.split] or SPLITS["Mostly fish"]
	if phase == "fish" then
		return split[1]
	elseif phase == "train" then
		return split[2]
	end
	return tonumber(string.match(tostring(STATE.lairTime), "%d+")) or 60
end

local function currentPhase()
	local list = phaseList()
	if #list == 0 then
		return "none"
	end
	if #list == 1 then
		fish.phase = list[1]
		return fish.phase
	end
	local index = table.find(list, fish.phase)
	if (not index or os.clock() >= fish.phaseUntil) and not Cast.busy() then
		fish.phase = list[(index or 0) % #list + 1]
		fish.phaseUntil = os.clock() + phaseLength(fish.phase)
	end
	return fish.phase
end

local function stepMain()
	applyPerfect()
	local phase = currentPhase()
	if phase ~= "dive" and stepLeaveLair() then
		return
	end
	if phase == "fish" then
		stepFish()
	elseif phase == "train" then
		stepTrain()
	elseif phase == "dive" then
		stepLair()
	else
		STATE.status = "Idle"
		STATE.detail = "Auto Fish, Auto Train and Auto Treasury are off"
	end
end

-- Shop.
local function rodPrice(index)
	local rod = Config.Rods[index]
	if not rod then
		return nil
	end
	if type(rod.FixedPrice) == "number" then
		return rod.FixedPrice
	end
	-- The late rods (Rocket and up) cost their listed Price, far above the curve.
	local ok, price = pcall(Config.RodPrice, index)
	local curve = ok and tonumber(price) or nil
	local listed = tonumber(rod.Price)
	if curve and listed then
		return math.max(curve, listed)
	end
	return curve or listed
end

local function nextRod()
	local owned = gameState().OwnedRods
	owned = type(owned) == "table" and owned or {}
	local best = 0
	for index, rod in ipairs(Config.Rods) do
		if owned[rod.Id] then
			best = index
		end
	end
	local rod = Config.Rods[best + 1]
	if not rod then
		return nil
	end
	return rod, rodPrice(best + 1)
end

local function nextPen()
	local tier = tonumber(attr("PenTier")) or 1
	local row = type(Config.PenTiers) == "table" and Config.PenTiers[tier + 1] or nil
	return row, row and tonumber(row.Price)
end

local function nextBar()
	local tier = tonumber(attr("BarTier")) or 0
	local row = type(Config.BarTiers) == "table" and Config.BarTiers[tier + 1] or nil
	if not row then
		return nil
	end
	local ok, price = pcall(Config.BarPrice, tier + 1)
	return row, ok and tonumber(price) or tonumber(row.Price)
end

local function stepBuy()
	if os.clock() < fish.nextBuy then
		return
	end
	fish.nextBuy = os.clock() + 2
	local money = cash()
	local options = {}
	local function add(kind, label, price, buy)
		if price and price <= money and (fish.buyBlock[kind] or 0) < os.clock() then
			table.insert(options, { kind = kind, label = label, price = price, buy = buy })
		end
	end
	if STATE.autoBuyRod then
		local rod, price = nextRod()
		if rod then
			add("Rod", rod.Name or rod.Id, price, function()
				return call("Buy", "Rod", rod.Id)
			end)
		end
	end
	if STATE.autoBuyPen then
		local row, price = nextPen()
		if row then
			add("Pen", tostring(row.Slots or "") .. " slot pen", price, function()
				return call("BuyTier", "Pen")
			end)
		end
	end
	if STATE.autoBuyBar then
		local row, price = nextBar()
		if row then
			add("Bar", row.Name or "Pull-up bar", price, function()
				return call("BuyTier", "Bar")
			end)
		end
	end
	if #options == 0 then
		return
	end
	table.sort(options, function(a, b)
		return a.price < b.price
	end)
	local pick = options[1]
	local ok, message = pick.buy()
	if ok then
		stats.bought += 1
		notify("Bought " .. pick.label, "$" .. shortNumber(pick.price))
		fish.nextBuy = os.clock() + 0.6
	else
		fish.buyBlock[pick.kind] = os.clock() + 30
		if type(message) == "string" then
			noteActivity(pick.label .. ": " .. message)
		end
	end
end

local function baitCount(id)
	if id == "Worm" then
		return math.huge
	end
	local owned = gameState().Baits
	return type(owned) == "table" and (tonumber(owned[id]) or 0) or 0
end

-- Guaranteed-rarity baits beat luck baits; then the luckiest one wins.
-- Jackpot Bait is left alone: its "Secret Cast" is a slot spin that mostly
-- lands Rare or Epic, worse than a normal cast later in the game.
local function baitScore(bait)
	if bait.SecretCast == true then
		return 0
	end
	local luck = tonumber(bait.Luck) or 1
	if STATE.useSpecialBait == true then
		local effect = tostring(bait.Effect or "")
		if bait.Id == "DivineBait" or string.find(effect, "Always a Divine", 1, true) then
			return 1e6
		elseif string.find(effect, "Always a Secret", 1, true) then
			return 1e5
		elseif string.find(effect, "Mythic or rarer", 1, true) then
			return 1e4
		end
	end
	return luck
end

local function stepBait()
	if os.clock() < fish.nextBait or Cast.busy() then
		return
	end
	fish.nextBait = os.clock() + 5
	if STATE.autoBuyBait then
		-- Best cash bait that costs under 1% of your cash, when you have none left.
		local best
		for _, bait in ipairs(Config.Baits) do
			if (tonumber(bait.Price) or 0) > 0 and (tonumber(bait.Robux) or 0) == 0 and cash() >= bait.Price * 100 then
				if not best or (bait.Luck or 1) > (best.Luck or 1) then
					best = bait
				end
			end
		end
		if best and baitCount(best.Id) <= 0 and (fish.buyBlock["Bait" .. best.Id] or 0) < os.clock() then
			local ok = call("Buy", "Bait", best.Id)
			if ok then
				notify("Bought " .. tostring(best.Name), "x" .. tostring(best.Pack or ""))
			else
				fish.buyBlock["Bait" .. best.Id] = os.clock() + 60
			end
		end
	end
	if STATE.autoBestBait then
		local best = Config.BaitById.Worm
		for _, bait in ipairs(Config.Baits) do
			if baitCount(bait.Id) > 0 and baitScore(bait) > (best and baitScore(best) or 1) then
				best = bait
			end
		end
		if best and attr("Bait") ~= best.Id then
			call("Equip", "Bait", best.Id)
		end
	end
end

-- Free rewards.
local PUBLIC_CODES = {}
for code, info in pairs(type(Config.Codes) == "table" and Config.Codes or {}) do
	if type(code) == "string" and type(info) == "table" and info.Users == nil then
		table.insert(PUBLIC_CODES, code)
	end
end
table.sort(PUBLIC_CODES)
STATE.publicCodes = PUBLIC_CODES

local function claim(key, ...)
	if (fish.claimBlock[key] or 0) > os.clock() then
		return false
	end
	local ok, message = call("Claim", ...)
	if ok then
		stats.claimed += 1
		return true
	end
	fish.claimBlock[key] = os.clock() + 90
	return false, message
end

local function redeemCodes()
	local done = 0
	for _, code in ipairs(PUBLIC_CODES) do
		if not table.find(STATE.redeemed, code) then
			local ok, message = call("RedeemCode", code)
			local text = type(message) == "string" and message or ""
			if ok then
				done += 1
				table.insert(STATE.redeemed, code)
				notify("Code redeemed", code)
			elseif string.find(string.lower(text), "slow", 1, true) then
				-- The game rate-limits codes. Try this one again on the next pass.
				break
			else
				table.insert(STATE.redeemed, code)
				if text ~= "" then
					noteActivity(code .. ": " .. text)
				end
			end
			task.wait(3)
		end
	end
	saveConfig()
	return done
end
STATE.redeemCodes = redeemCodes

local function stepClaims(force)
	if not force and os.clock() < fish.nextClaim then
		return 0
	end
	fish.nextClaim = os.clock() + 15
	local state = gameState()
	local count = 0
	if STATE.autoClaim or force then
		local daily = state.Daily
		if type(daily) == "table" and daily.Ready == true and claim("Daily", "Daily") then
			count += 1
			notify("Daily reward claimed", "")
		end
		local gifts = state.Gifts
		local started = tonumber(state.SessionStart)
		if type(gifts) == "table" and started and type(Config.Gifts) == "table" then
			local minutes = (Workspace:GetServerTimeNow() - started) / 60
			for index, gift in ipairs(Config.Gifts) do
				if gifts[index] ~= true and minutes >= (tonumber(gift.Minutes) or math.huge) then
					if claim("Gift" .. index, "Gift", index) then
						count += 1
						noteActivity("Claimed the " .. tostring(gift.Minutes) .. " minute gift")
					end
				end
			end
		end
		if attr("GroupMember") == true and state.GroupClaimed ~= true and claim("Group", "Group") then
			count += 1
		end
		if state.FavoriteClaimed ~= true and not fish.favoriteTried then
			fish.favoriteTried = true
			if claim("Favorite", "Favorite") then
				count += 1
			end
		end
		if (tonumber(state.Offline) or 0) > 0 and claim("Offline", "Offline") then
			count += 1
			notify("Offline cash claimed", "")
		end
	end
	if STATE.autoIndex or force then
		local index = type(state.Index) == "table" and state.Index or {}
		local done = type(state.IndexClaimed) == "table" and state.IndexClaimed or {}
		for _, biome in ipairs(type(Config.Biomes) == "table" and Config.Biomes or {}) do
			if done[biome.Id] ~= true and type(biome.Beasts) == "table" and #biome.Beasts > 0 then
				local complete = true
				for _, beast in ipairs(biome.Beasts) do
					local id = type(beast) == "table" and beast.Id or beast
					if index[id] ~= true then
						complete = false
						break
					end
				end
				if complete and claim("Index" .. tostring(biome.Id), "Index", biome.Id) then
					count += 1
					notify("Index reward", tostring(biome.Name or biome.Id))
				end
			end
		end
	end
	if (STATE.autoAquarium or force) and (force or os.clock() >= fish.nextAquarium) then
		-- Aquarium milestones: every new species + mutation you catch fills it up,
		-- and each milestone (5%, 10%, 20%...) has a reward to claim.
		fish.nextAquarium = os.clock() + 60
		local aquarium = type(Config.Aquarium) == "table" and Config.Aquarium or {}
		local ok, data = call("Aquarium", "Get", LocalPlayer.UserId)
		if ok == true and type(data) == "table" and data.Mine == true and type(Config.AquariumDone) == "function" then
			local okDone, done = pcall(Config.AquariumDone, data.Record)
			done = okDone and tonumber(done) or 0
			local claimed = type(data.Claimed) == "table" and data.Claimed or {}
			for _, milestone in ipairs(type(aquarium.Milestones) == "table" and aquarium.Milestones or {}) do
				local at = tonumber(milestone.At)
				if at and at <= done + 1e-6 and claimed[tostring(milestone.At)] ~= true then
					local good, message = call("Aquarium", "Claim", milestone.At)
					if not good then
						break
					end
					count += 1
					stats.claimed += 1
					notify("Aquarium " .. tostring(milestone.At) .. "% reward", type(message) == "string" and message or "")
					task.wait(0.5)
				end
			end
		end
	end
	if STATE.autoCodes and #STATE.redeemed < #PUBLIC_CODES then
		count += redeemCodes()
	end
	return count
end
STATE.claimNow = function()
	return stepClaims(true)
end

-- Eggs and pets.
local function stepPets()
	if os.clock() < fish.nextPets then
		return
	end
	fish.nextPets = os.clock() + 20
	local state = gameState()
	if STATE.autoHatch and type(state.NestEggs) == "table" then
		local now = Workspace:GetServerTimeNow()
		for _, egg in pairs(state.NestEggs) do
			local id = type(egg) == "table" and egg.Id ~= nil and tostring(egg.Id) or nil
			local readyAt = type(egg) == "table" and tonumber(egg.R) or 0
			if id and readyAt <= now and (fish.hatchBlock[id] or 0) < os.clock() then
				local result = call("NestHatch", id)
				if type(result) == "table" then
					stats.hatched += 1
					notify("Hatched", tostring(result.Name or "a pet"))
				else
					fish.hatchBlock[id] = os.clock() + 45
				end
				task.wait(0.5)
			end
		end
	end
	if STATE.autoEquipPets then
		call("PetEquip", "Best")
	end
end
STATE.equipBestNow = function()
	return call("PetEquip", "Best")
end

-- Player helpers.
local walkSpeedsBefore = setmetatable({}, { __mode = "k" })
local function restoreWalkSpeed()
	for hum, speed in pairs(walkSpeedsBefore) do
		if hum.Parent then
			hum.WalkSpeed = speed
		end
	end
	table.clear(walkSpeedsBefore)
end
hubCleanup(restoreWalkSpeed)

local function stepSpeed()
	local _, _, hum = character()
	if hum and STATE.walkSpeed == true and not Cast.busy() and not isTraining() and hum.WalkSpeed > 0 then
		if walkSpeedsBefore[hum] == nil then
			walkSpeedsBefore[hum] = hum.WalkSpeed
		end
		hum.WalkSpeed = STATE.speed
	end
end

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
		Author = "Fish for Secret Animals",
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
		elseif key == "walkSpeed" and not on then
			restoreWalkSpeed()
		elseif key == "autoTrain" and not on and isTraining() then
			send("StopTraining")
		elseif key == "autoClaim" and on then
			task.spawn(STATE.claimNow)
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
	local fishTab = Window:Tab({ Title = "Fishing", Icon = "fish" })
	local shopTab = Window:Tab({ Title = "Shop", Icon = "shopping-cart" })
	local rewardTab = Window:Tab({ Title = "Rewards", Icon = "gift" })
	local playerTab = Window:Tab({ Title = "Player", Icon = "user" })
	local settingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
	elevate()

	local overview = info(homeTab, "Overview", "Loading your stats...")
	button(homeTab, "Start / Stop Fishing", "Turns Auto Fish on or off", "power", function()
		local on = STATE.autoFish ~= true
		onToggle("autoFish", on)
		syncToggle("autoFish")
		notify(on and "Fishing started" or "Fishing stopped", "")
	end)
	button(homeTab, "Claim Now", "Daily, timed gifts, offline cash, Index and Aquarium rewards and codes", "gift", function()
		task.spawn(function()
			local count = STATE.claimNow()
			notify(count > 0 and ("Claimed " .. count) or "Nothing ready", "")
		end)
	end)
	local activityInfo = info(homeTab, "Activity", "Waiting for the next thing the hub does.")

	local fishInfo
	local lairInfo
	do
		local castBox = section(fishTab, "Casting", "fish")
		toggle(castBox, "Auto Fish", "autoFish", "Casts, lands the catch and casts again")
		toggle(castBox, "Perfect Cast", "perfectCast", "Locks the power bar at the top every time")
		toggle(castBox, "Block Offer Popups", "blockOffers", "Keeps the game's Robux offers closed. They stop fishing until closed")
		fishInfo = info(castBox, "Status", "Starting")

		local catchBox = section(fishTab, "Your Catch", "package")
		choice(catchBox, "After A Catch", "Pen best puts your best Sea Beasts in the pen for $/s and sells the others", CATCH_OPTIONS, function()
			return STATE.catchMode
		end, function(option)
			STATE.catchMode = option
		end)
		choice(catchBox, "Never Sell", "Keeps this rarity and anything rarer", KEEP_OPTIONS, function()
			return STATE.keepRarity
		end, function(option)
			STATE.keepRarity = option
		end)
		toggle(catchBox, "Keep Mutated", "keepMutated", "Never sells a Sea Beast with a mutation")
		button(catchBox, "Fill Pen Now", "Puts your best Sea Beasts in the pen", "layout-grid", function()
			send("FillPen")
			notify("Pen filled", "")
		end)

		local trainBox = section(fishTab, "Gym", "dumbbell")
		toggle(trainBox, "Auto Train", "autoTrain", "Trains on your pull-up bar for Power. Takes turns with fishing")
		choice(trainBox, "Fish / Train Split", "Mostly fish: 150s fishing, 45s training", SPLIT_OPTIONS, function()
			return STATE.split
		end, function(option)
			STATE.split = option
			fish.phaseUntil = 0
		end)
		toggle(trainBox, "Auto Double Rep", "autoDoubleRep", "Hits the 2x button every time it pops up")

		local lairBox = section(fishTab, "Sunken Treasury", "gem")
		toggle(lairBox, "Auto Treasury", "autoLair", "Dives for doubloon chests. Takes turns with fishing and training")
		choice(lairBox, "Dive Spot", "Hot Spring: more doubloons. Ice Hole: bigger chests. Pearl Pool: eggs and pearls. Abyss Hole: Sea Beasts", LAIR_SPOT_OPTIONS, function()
			return STATE.lairSpot
		end, function(option)
			STATE.lairSpot = option
		end)
		choice(lairBox, "Dive Risk", "Smart goes deeper only while the next chest is worth the snap chance", LAIR_RISK_OPTIONS, function()
			return STATE.lairRisk
		end, function(option)
			STATE.lairRisk = option
		end)
		choice(lairBox, "Treasury Time", "How long each Treasury turn lasts", LAIR_TIME_OPTIONS, function()
			return STATE.lairTime
		end, function(option)
			STATE.lairTime = option
			fish.phaseUntil = 0
		end)
		toggle(lairBox, "Auto Spend Doubloons", "autoDoubloons", "Line Strength, then Luck upgrades, then keeps a Luck Potion going")
		lairInfo = info(lairBox, "Treasury", "Waiting")
	end

	do
		local buyBox = section(shopTab, "Upgrades", "arrow-up-circle")
		toggle(buyBox, "Auto Buy Rods", "autoBuyRod", "Buys the next rod as soon as you can afford it")
		toggle(buyBox, "Auto Buy Pen", "autoBuyPen", "More pen slots for more $/s")
		toggle(buyBox, "Auto Buy Pull-Up Bar", "autoBuyBar", "More XP per rep")

		local baitBox = section(shopTab, "Bait", "bug")
		toggle(baitBox, "Use Best Bait", "autoBestBait", "Equips the luckiest bait you own")
		toggle(baitBox, "Use Special Baits", "useSpecialBait", "Always-Divine, Always-Secret and Mythic Magnet baits go first. Turn off to save them")
		toggle(baitBox, "Auto Buy Bait", "autoBuyBait", "Buys the luckiest cash bait that costs under 1% of your money")
	end

	do
		local claimBox = section(rewardTab, "Free Rewards", "gift")
		toggle(claimBox, "Auto Claim", "autoClaim", "Daily reward, timed gifts, offline cash, group and favorite rewards")
		toggle(claimBox, "Auto Index Rewards", "autoIndex", "Claims each area once you have caught every Sea Beast in it")
		toggle(claimBox, "Auto Aquarium Rewards", "autoAquarium", "Claims the Aquarium milestones (5%, 10%, 20%...): cash, worms and luck")
		toggle(claimBox, "Redeem Codes", "autoCodes", "Redeems the free codes once: " .. table.concat(PUBLIC_CODES, ", "))
		button(claimBox, "Redeem Codes Now", nil, "ticket", function()
			table.clear(STATE.redeemed)
			task.spawn(redeemCodes)
		end)

		local petBox = section(rewardTab, "Eggs & Pets", "egg")
		toggle(petBox, "Auto Hatch Eggs", "autoHatch", "Hatches the eggs in your nest when they are ready")
		toggle(petBox, "Auto Equip Best Pets", "autoEquipPets", "Equips your best pets")
		button(petBox, "Equip Best Now", nil, "paw-print", function()
			STATE.equipBestNow()
			notify("Best pets equipped", "")
		end)
	end

	do
		local moveBox = section(playerTab, "Movement", "footprints")
		toggle(moveBox, "Custom Walk Speed", "walkSpeed")
		choice(moveBox, "Walk Speed", "16 is the normal speed", SPEED_OPTIONS, function()
			return tostring(STATE.speed)
		end, function(option)
			STATE.speed = tonumber(option) or STATE.speed
		end)

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
		local rod = Config.RodById and Config.RodById[attr("Rod") or ""]
		local bait = Config.BaitById and Config.BaitById[attr("Bait") or ""]
		local baitLeft = baitCount(attr("Bait") or "Worm")
		setInfo(overview, string.format(
			"%s\n$%s  ·  $%s/s\nLevel %s  ·  Power %s\n%s  ·  %s%s\nPen %s/%s  ·  %s doubloons  ·  Session %s",
			tostring(STATE.status or "Waiting"),
			shortNumber(cash()),
			shortNumber(attr("Income") or 0),
			tostring(attr("Level") or 1),
			shortNumber(attr("Power") or 0),
			tostring(rod and rod.Name or attr("Rod") or "Rod"),
			tostring(bait and bait.Name or attr("Bait") or "Bait"),
			baitLeft ~= math.huge and (" x" .. tostring(baitLeft)) or "",
			tostring(attr("PenCount") or 0),
			tostring(attr("PenSlots") or 0),
			shortNumber(attr("Doubloons") or 0),
			clock
		))
		local lines = {
			string.format("Casts %d  ·  Kept %d  ·  Sold %d ($%s)", stats.casts, stats.kept, stats.sold, shortNumber(stats.soldCash)),
			string.format("Double reps %d  ·  Bought %d  ·  Claimed %d", stats.doubles, stats.bought, stats.claimed),
		}
		if lair.dives > 0 or lair.snaps > 0 then
			lines[#lines + 1] = string.format("Treasury dives %d  ·  +%s doubloons  ·  Snapped %d", lair.dives, shortNumber(lair.doubloons), lair.snaps)
		end
		if (tonumber(attr("Tutorial")) or 0) ~= 0 then
			lines[#lines + 1] = "Finishing the game's tutorial for you"
		end
		if STATE.antiAfk == true then
			lines[#lines + 1] = STATE.antiAfkOperational == true and "Anti AFK active" or "Anti AFK waiting for idle"
		end
		for _, item in ipairs(STATE.activity) do
			lines[#lines + 1] = tostring(item)
		end
		setInfo(activityInfo, table.concat(lines, "\n"))
		setInfo(fishInfo, tostring(STATE.status or "Waiting") .. "\n" .. tostring(STATE.detail or ""))
		local lairText
		if not lairOpen() then
			lairText = "Opens when your power can reach the Prehistoric sea. Keep training!"
		else
			local lineSkill = math.floor(tonumber(attr("LairLine")) or 0)
			local luckSkill = math.floor(tonumber(attr("LairLuck")) or 0)
			lairText = string.format("%s doubloons  ·  Line Strength %d/5  ·  Luck %d/5\nThis session: %d dives, +%s, deepest %d, snapped %d",
				shortNumber(attr("Doubloons") or 0), lineSkill, luckSkill, lair.dives, shortNumber(lair.doubloons), lair.deepest, lair.snaps)
		end
		setInfo(lairInfo, lairText)
	end

	task.spawn(function()
		while running() and not windowGone do
			pcall(refresh)
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

loadSaved()
STATE.version = "1.1.1"

if running() then
	elevate()
	local ok, err = xpcall(installHub, debug.traceback)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
	end
end

-- Casting and training.
task.spawn(function()
	elevate()
	while running() do
		local ok, err = pcall(stepMain)
		if not ok then
			STATE.status = "Fishing error"
			STATE.detail = tostring(err)
			warn("[Zinoos hub] " .. tostring(err))
			task.wait(2)
		else
			task.wait(0.15)
		end
	end
end)

-- Shop, pen, rewards and pets.
task.spawn(function()
	elevate()
	task.wait(2)
	while running() do
		pcall(stepFillPen)
		pcall(stepSellExtras)
		pcall(stepBuy)
		pcall(stepBait)
		pcall(stepDoubloons)
		pcall(stepClaims)
		pcall(stepPets)
		elevate()
		task.wait(0.5)
	end
end)

task.spawn(function()
	elevate()
	while running() do
		pcall(stepDoubleRep)
		pcall(stepSpeed)
		pcall(hidePausePopup)
		pcall(offers.apply)
		pcall(offers.close)
		task.wait(0.15)
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
