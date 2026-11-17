-- ZinoosHub for Throw Food For Animals.
-- Uses the existing Lift Rock interface and the game's native controllers/remotes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

if game.GameId ~= 10766972131 then
	warn("[Zinoos hub] This only runs in Throw Food For Animals.")
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
if typeof(genv.ZinoosThrowFoodStop) == "function" then
	pcall(genv.ZinoosThrowFoodStop)
	-- Calling a closure from the previous run can restore that script's
	-- capability context on this thread. Re-assert ours before continuing.
	elevate()
end
genv.ZinoosThrowFoodGen = (typeof(genv.ZinoosThrowFoodGen) == "number" and genv.ZinoosThrowFoodGen or 0) + 1
local token = genv.ZinoosThrowFoodGen
local function running()
	return genv.ZinoosThrowFoodGen == token
end

-- Rarities and mutations come from the game's own config so new tiers (such
-- as Sovereign, Champion and Lucid) appear without a hub update. The fixed
-- lists remain as a fallback and keep every older option selectable.
local function gameNameList(moduleName, fallback)
	local names = {}
	local ok = pcall(function()
		local folder = ReplicatedStorage:WaitForChild("Config", 10)
		local module = folder and folder:WaitForChild(moduleName, 10)
		local config = module and require(module)
		local entries = {}
		for order, entry in ipairs(type(config) == "table" and type(config.List) == "table" and config.List or {}) do
			if type(entry) == "table" and type(entry.Name) == "string" then
				table.insert(entries, { name = entry.Name, order = tonumber(entry.Index) or order })
			end
		end
		table.sort(entries, function(a, b)
			return a.order < b.order
		end)
		for _, entry in ipairs(entries) do
			table.insert(names, entry.name)
		end
	end)
	elevate()
	if not ok or #names == 0 then
		return table.clone(fallback)
	end
	for _, name in ipairs(fallback) do
		if not table.find(names, name) then
			table.insert(names, name)
		end
	end
	return names
end

local RARITY_OPTIONS = gameNameList("RarityConfig", {
	"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
	"Secret", "Divine", "Celestial", "Eternal", "Cosmic", "Supreme", "Sovereign",
})
local MUTATION_OPTIONS = gameNameList("MutationsConfig", { "Gold", "Diamond", "Emerald", "Ruby", "Rainbow", "Champion", "Lucid" })
local RARITY_RANK = {}
for index, rarity in ipairs(RARITY_OPTIONS) do
	RARITY_RANK[rarity] = index
end
local NOTIFY_RARITY_OPTIONS = { "All" }
for _, rarity in ipairs(RARITY_OPTIONS) do
	table.insert(NOTIFY_RARITY_OPTIONS, rarity)
end
local ESP_DISTANCE_OPTIONS = { "100", "250", "500", "1000", "Unlimited" }
local KEEP_BACKUP_OPTIONS = { "Keep 0", "Keep 5", "Keep 10", "Keep 15", "Keep 20", "Keep 30" }
local SELL_INTERVAL_OPTIONS = { "Every 1 minute", "Every 2 minutes", "Every 5 minutes", "Every 10 minutes", "Every 30 minutes" }
local SUPER_RESERVE_OPTIONS = { "Use all", "Keep 1", "Keep 5", "Keep 10", "Keep 25", "Keep 50" }
local TRAIN_TARGET_OPTIONS = { "1K", "2.5K", "5K", "10K", "25K", "50K", "100K", "250K", "500K", "1M", "5M", "10M" }
local TRAIN_TARGET_VALUES = {
	["1K"] = 1e3, ["2.5K"] = 2.5e3, ["5K"] = 5e3, ["10K"] = 1e4,
	["25K"] = 2.5e4, ["50K"] = 5e4, ["100K"] = 1e5, ["250K"] = 2.5e5,
	["500K"] = 5e5, ["1M"] = 1e6, ["5M"] = 5e6, ["10M"] = 1e7,
}
local CASH_RESERVE_OPTIONS = {
	"$0", "$1K", "$10K", "$100K", "$1M", "$10M", "$100M", "$1B",
	"$1T", "$1Qa", "$1Qi", "$1Sx", "$1Sp", "$1Oc", "$1No", "$1Dc", "$1Ud", "$1Dd", "$1Td",
	"$1Qad", "$1Qid", "$1Sxd", "$1Spd", "$1Ocd", "$1Nod", "$1Vg",
}
local CASH_RESERVE_VALUES = {
	["$0"] = 0, ["$1K"] = 1e3, ["$10K"] = 1e4, ["$100K"] = 1e5,
	["$1M"] = 1e6, ["$10M"] = 1e7, ["$100M"] = 1e8, ["$1B"] = 1e9,
	["$1T"] = 1e12, ["$1Qa"] = 1e15, ["$1Qi"] = 1e18, ["$1Sx"] = 1e21,
	["$1Sp"] = 1e24, ["$1Oc"] = 1e27, ["$1No"] = 1e30, ["$1Dc"] = 1e33,
	["$1Ud"] = 1e36, ["$1Dd"] = 1e39, ["$1Td"] = 1e42,
	["$1Qad"] = 1e45, ["$1Qid"] = 1e48, ["$1Sxd"] = 1e51, ["$1Spd"] = 1e54,
	["$1Ocd"] = 1e57, ["$1Nod"] = 1e60, ["$1Vg"] = 1e63,
}

local STATE = {
	_gen = token,
	version = "3.5.0",
	animalsCache = nil,
	trainOnBoost = true,
	autoRingRush = true,
	dreamBuy = false,
	dreamPotionBuy = false,
	dreamInfuse = false,
	autoTrail = true,
	-- Collection page: one Auto Collect switch for the world index and the
	-- Dreamland collection. "indexHunt" keeps its old save key.
	indexHunt = false,
	collectClaim = true,
	collectStop = true,
	collectSuper = false,
	collectTarget = "Auto",
	collectStatus = "Auto Collect is off",
	aimStatus = "Maximum distance",
	dreamStatus = "Checking Dreamland...",
	indexStatus = "Checking index rewards...",
	boostStatus = "No boosts active",
	autoThrow = true,
	perfectMeter = true,
	autoSkip = true,
	autoTrain = false,
	cycleTrain = false,
	cycleTrainMinutes = 5,
	cycleThrowMinutes = 5,
	cycleStatus = "Off",
	autoTapBonus = true,
	autoFood = true,
	autoStand = true,
	autoFence = false,
	equipBest = true,
	autoSell = false,
	keepBest = 10,
	sellMinutes = 2,
	sellRarities = { "Common", "Uncommon", "Rare" },
	protectedMutations = table.clone(MUTATION_OPTIONS),
	stopOnRarity = false,
	stopTargetRarity = "Supreme",
	stopOnMutation = false,
	stopTargetMutations = { "Rainbow" },
	trainToTarget = false,
	trainTargetPower = "10K",
	resumeThrowAfterTraining = true,
	cashReserve = "$0",
	superThrowReserve = 0,
	autoOffline = true,
	autoFree = true,
	autoSuper = false,
	walkSpeed = false,
	speed = 32,
	antiAfk = true,
	autoReload = true,
	infiniteJump = false,
	noclip = false,
	instantPrompts = false,
	fly = false,
	flySpeed = 60,
	noPausePopup = true,
	autoReconnect = false,
	disable3d = false,
	fpsBoost = false,
	hidePets = true,
	notifications = true,
	notifyCatches = true,
	notifySales = true,
	notifyProgress = true,
	notifyMinRarity = "All",
	espEnabled = false,
	espOwnOnly = false,
	espAllAnimals = false,
	espRarities = table.clone(RARITY_OPTIONS),
	espMaxDistance = "500",
	hideOnStart = false,
	toggleKey = "RightControl",
	toggleControls = {},
	themeSwitches = {},
}
genv.ZinoosThrowFoodState = STATE

-- The Admin tag is deliberately locked to the owner's exact Roblox user ID.
STATE.ownerUserId = 9346336323
STATE.admin = LocalPlayer.UserId == STATE.ownerUserId

local runtime = { connections = {}, cleanups = {} }
local function trackConnection(connection)
	table.insert(runtime.connections, connection)
	return connection
end
local function hubCleanup(fn)
	table.insert(runtime.cleanups, fn)
end

local function destroyMenus()
	elevate()
	for _, root in ipairs({ CoreGui, typeof(gethui) == "function" and gethui() or nil }) do
		local old = root and root:FindFirstChild("ZinoosThrowFoodMenu")
		if old then
			old:Destroy()
		end
	end
end

local function shutdownHub()
	if genv.ZinoosThrowFoodGen == token then
		genv.ZinoosThrowFoodGen = token + 1
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
	destroyMenus()
end
genv.ZinoosThrowFoodStop = shutdownHub
local function unloadHub()
	shutdownHub()
end

local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/ThrowFoodAnimals_" .. tostring(LocalPlayer.UserId) .. ".rfld"
local CONFIG_VERSION = 3
local SPEED_OPTIONS = { "16", "24", "32", "50", "75", "100" }

local FLAG_KEYS = {
	AutoThrow = "autoThrow",
	PerfectMeter = "perfectMeter",
	AutoSkip = "autoSkip",
	AutoTrain = "autoTrain",
	CycleTrain = "cycleTrain",
	AutoTapBonus = "autoTapBonus",
	AutoFood = "autoFood",
	AutoStand = "autoStand",
	AutoFence = "autoFence",
	EquipBest = "equipBest",
	AutoSell = "autoSell",
	AutoOffline = "autoOffline",
	AutoFree = "autoFree",
	AutoSuper = "autoSuper",
	StopOnRarity = "stopOnRarity",
	StopOnMutation = "stopOnMutation",
	TrainToTarget = "trainToTarget",
	ResumeThrowAfterTraining = "resumeThrowAfterTraining",
	WalkSpeed = "walkSpeed",
	AntiAfk = "antiAfk",
	AutoReload = "autoReload",
	InfiniteJump = "infiniteJump",
	Noclip = "noclip",
	InstantPrompts = "instantPrompts",
	Fly = "fly",
	NoPausePopup = "noPausePopup",
	AutoReconnect = "autoReconnect",
	Disable3d = "disable3d",
	FpsBoost = "fpsBoost",
	HidePets = "hidePets",
	Notifications = "notifications",
	NotifyCatches = "notifyCatches",
	NotifySales = "notifySales",
	NotifyProgress = "notifyProgress",
	EspEnabled = "espEnabled",
	EspOwnOnly = "espOwnOnly",
	EspAllAnimals = "espAllAnimals",
	HideOnStart = "hideOnStart",
	TrainOnBoost = "trainOnBoost",
	AutoRingRush = "autoRingRush",
	DreamBuy = "dreamBuy",
	DreamPotionBuy = "dreamPotionBuy",
	DreamInfuse = "dreamInfuse",
	AutoTrail = "autoTrail",
	IndexHunt = "indexHunt",
	CollectClaim = "collectClaim",
	CollectStop = "collectStop",
	CollectSuper = "collectSuper",
}

-- Shared between the boost-training step and config saving: temporary
-- boost training must never be written to disk as the user's own choice.
local boostTraining = { active = false, resumeThrow = false, declined = false }

local FLY_SPEED_OPTIONS = { "30", "60", "100", "150", "200" }
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
local CHOICES = {
	ToggleKey = { key = "toggleKey", options = KEY_OPTIONS },
	NotifyMinRarity = { key = "notifyMinRarity", options = NOTIFY_RARITY_OPTIONS },
	EspMaxDistance = { key = "espMaxDistance", options = ESP_DISTANCE_OPTIONS },
	StopTargetRarity = { key = "stopTargetRarity", options = RARITY_OPTIONS },
	TrainTargetPower = { key = "trainTargetPower", options = TRAIN_TARGET_OPTIONS },
	CashReserve = { key = "cashReserve", options = CASH_RESERVE_OPTIONS },
	-- "Auto", a world zone key, or "Dream:<area>"; checked against the game
	-- when the Collection page is built.
	CollectTarget = { key = "collectTarget" },
	-- Any WindUI theme name; an unknown one falls back to Zinoos at load.
	WindTheme = { key = "windTheme" },
}
STATE.LIST_KEYS = {
	SellRarities = "sellRarities",
	ProtectedMutations = "protectedMutations",
	EspRarities = "espRarities",
	StopTargetMutations = "stopTargetMutations",
}
local LIST_OPTIONS = {
	SellRarities = RARITY_OPTIONS,
	ProtectedMutations = MUTATION_OPTIONS,
	EspRarities = RARITY_OPTIONS,
	StopTargetMutations = MUTATION_OPTIONS,
}
local NUMBERS = {
	FlySpeed = { "flySpeed", 10, 300 },
	CycleTrainMinutes = { "cycleTrainMinutes", 1, 60 },
	CycleThrowMinutes = { "cycleThrowMinutes", 1, 60 },
	SellMinutes = { "sellMinutes", 1, 30 },
	KeepBest = { "keepBest", 0, 50 },
	SuperThrowReserve = { "superThrowReserve", 0, 9999 },
}
STATE.defaultTheme = {
	blush = 1,
	Kind = "theme",
	Name = "ZinoosDark",
	Theme = {
		Colors = {
			Panel = "10141c",
			Text = "f5f7fb",
			Element = "171d28",
			Risky = "ff6577",
			Outline = "2a3445",
			Hover = "1d2532",
			Background = "0b0f15",
			DimText = "9ba8ba",
			Accent = "8268ff",
		},
		Glow = false,
		ElementGlow = false,
		CardOpacity = 0.98,
		Wallpaper = {
			Image = "",
			Transparency = 1,
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

STATE.hubSizes = { Compact = 0.8, Normal = 0.9, Large = 1 }
STATE.phoneHubSizes = { Compact = { 0.75, 0.64, 0.74 }, Normal = { 0.85, 0.72, 0.8 }, Large = { 1, 0.84, 0.76 } }

function STATE.hubScaleValue()
	return STATE.hubSizes[STATE.hubSize or "Compact"] or STATE.hubSizes.Compact
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
-- Theme images belong to this run only.
function STATE.themeStillCurrent(gen, tokenNow)
	return running() and STATE._unloaded ~= true
end

-- Without a theme of its own, use the one saved by the Lift Rock hub on this account.
local function borrowLiftRockTheme()
	local path = "Rayfield/Configurations/ZinoosHub/ZinoosHub_" .. tostring(LocalPlayer.UserId) .. ".rfld"
	if typeof(isfile) ~= "function" or not isfile(path) then
		path = "Rayfield/Configurations/ZinoosHub/ZinoosHub.rfld"
	end
	if typeof(isfile) ~= "function" or not isfile(path) then
		return
	end
	local ok, saved = pcall(function()
		return game:GetService("HttpService"):JSONDecode(readfile(path))
	end)
	if ok and type(saved) == "table" and type(saved.ThemeData) == "table" and saved.Theme ~= "AstaTheme" and saved.Theme ~= "ZinoosDark" then
		local look, name, source = STATE.readTheme(saved.ThemeData)
		if type(look) == "table" then
			STATE.hubThemeLook = look
			STATE.themeName = name or STATE.themeName
			STATE.themeSource = source
		end
	end
end

local function loadSaved()
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
		return
	end
	borrowLiftRockTheme()
	if not isfile(CONFIG_PATH) then
		return
	end
	local ok, saved = pcall(function()
		return game:GetService("HttpService"):JSONDecode(readfile(CONFIG_PATH))
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
	for flag, spec in pairs(NUMBERS) do
		if type(saved[flag]) == "number" then
			STATE[spec[1]] = math.clamp(saved[flag], spec[2], spec[3])
		end
	end
	for flag, key in pairs(STATE.LIST_KEYS) do
		if type(saved[flag]) == "table" then
			local selected = {}
			for _, value in ipairs(saved[flag]) do
				if type(value) == "string" then
					selected[value] = true
				end
			end
			local list = {}
			for _, option in ipairs(LIST_OPTIONS[flag] or {}) do
				if selected[option] then
					table.insert(list, option)
				end
			end
			STATE[key] = list
		end
	end
	-- v2.0 stored one all-or-nothing mutation switch. Preserve its meaning once,
	-- then save the new per-mutation selection format.
	if type(saved.ProtectedMutations) ~= "table" and saved.KeepMutations == false then
		STATE.protectedMutations = {}
	end
	-- v2.4 defaulted to every sell rarity. On the first v2.5+ load, replace that
	-- legacy default with the safer low-rarity filter and require Auto Sell to be
	-- turned back on deliberately. A versioned config prevents repeat migration.
	if (tonumber(saved.ConfigVersion) or 0) < CONFIG_VERSION
		and type(saved.SellRarities) == "table"
		and #STATE.sellRarities == #RARITY_OPTIONS then
		STATE.autoSell = false
		STATE.sellRarities = { "Common", "Uncommon", "Rare" }
		STATE.configMigratedSellSafety = true
	end
	if saved.HubSize == "Compact" or saved.HubSize == "Normal" or saved.HubSize == "Large" then
		STATE.hubSize = saved.HubSize
	end
	if type(saved.ThemeData) == "table" and saved.Theme ~= "AstaTheme" and saved.Theme ~= "ZinoosDark" then
		local look, name, source = STATE.readTheme(saved.ThemeData)
		if type(look) == "table" then
			STATE.hubThemeLook = look
			STATE.themeName = name or STATE.themeName
			STATE.themeSource = source
		end
	end
	for _, key in ipairs({ "MenuX", "MenuY", "DockX", "DockY" }) do
		if type(saved[key]) == "number" then
			STATE[string.lower(string.sub(key, 1, 1)) .. string.sub(key, 2)] = saved[key]
		end
	end
	STATE.dockCustom = saved.DockCustom == true
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
		Speed = STATE.speed,
		HubSize = STATE.hubSize or "Compact",
		MenuX = STATE.menuX,
		MenuY = STATE.menuY,
		DockX = STATE.dockX,
		DockY = STATE.dockY,
		DockCustom = STATE.dockCustom == true,
		Theme = type(STATE.themeName) == "string" and STATE.themeName or "ZinoosDark",
		ThemeData = type(STATE.themeSource) == "table" and STATE.themeSource or nil,
	}
	for flag, key in pairs(FLAG_KEYS) do
		payload[flag] = STATE[key] == true
	end
	if boostTraining.active then
		-- Save the user's real choice, not the temporary boost switch.
		payload.AutoTrain = false
		payload.AutoThrow = boostTraining.resumeThrow == true
	end
	for flag, choice in pairs(CHOICES) do
		payload[flag] = STATE[choice.key]
	end
	for flag, spec in pairs(NUMBERS) do
		payload[flag] = STATE[spec[1]]
	end
	for flag, key in pairs(STATE.LIST_KEYS) do
		payload[flag] = type(STATE[key]) == "table" and STATE[key] or {}
	end
	local ok, encoded = pcall(function()
		return game:GetService("HttpService"):JSONEncode(payload)
	end)
	if ok then
		pcall(writefile, CONFIG_PATH, encoded)
	end
end
STATE.writeConfig = saveConfig

local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

STATE.status = "Starting"
STATE.throwStatus = "Waiting"
STATE.superThrowStatus = "Waiting"
STATE.trainingStatus = "Off"
STATE.upgradeStatus = "Checking"
STATE.sellStatus = "Off"
STATE.rewardStatus = "Checking"
local stats = {
	throws = 0,
	trained = 0,
	bonuses = 0,
	foods = 0,
	stands = 0,
	fences = 0,
	sold = 0,
	rewards = 0,
	catches = 0,
	targetStops = 0,
	rarityCounts = {},
	mutationCounts = {},
}
STATE.stats = stats
STATE.activity = {}
STATE.notificationLog = {}
STATE.catchHistory = {}
STATE.toast = nil

local function noteActivity(text)
	if type(text) ~= "string" or text == "" or STATE.activity[#STATE.activity] == text then
		return
	end
	table.insert(STATE.activity, text)
	while #STATE.activity > 8 do
		table.remove(STATE.activity, 1)
	end
end

local function humanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function seated()
	local hum = humanoid()
	return hum ~= nil and hum.SeatPart ~= nil
end

local function stepSpeed()
	local hum = humanoid()
	if hum and STATE.walkSpeed == true and not seated() then
		hum.WalkSpeed = STATE.speed
	end
end

local pulseAntiAfk = function()
	if not running() or STATE.antiAfk ~= true then
		return false
	end
	local ok = pcall(function()
		local virtual = game:GetService("VirtualUser")
		virtual:CaptureController()
		virtual:ClickButton2(Vector2.new(-1, -1))
	end)
	-- The game has its own AFK check (AFKRejoin: 18 minutes with no
	-- UserInputService input, then it moves you to another server).
	-- VirtualUser does not count for it, so also send a mouse move to where
	-- the mouse already is. If that is unavailable, run the game's own input
	-- listener directly.
	local reset = pcall(function()
		local mouse = UserInputService:GetMouseLocation()
		game:GetService("VirtualInputManager"):SendMouseMoveEvent(mouse.X, mouse.Y, game)
	end)
	if not reset and typeof(getconnections) == "function" then
		pcall(function()
			for _, connection in ipairs(getconnections(UserInputService.InputBegan)) do
				local fn = connection.Function
				if type(fn) == "function" and string.find(tostring(debug.info(fn, "s")), "AFKRejoin", 1, true) then
					fn()
					reset = true
				end
			end
		end)
	end
	STATE.antiAfkOperational = ok or reset
	return ok or reset
end

-- Auto reload: when this client is teleported (rejoin, server hop, update
-- shutdown), queue a small script that loads this hub again in the new server.
-- In a different place of the same game it re-queues itself and waits.
do
local queueTeleport = queue_on_teleport
	or (syn and syn.queue_on_teleport)
	or (fluxus and fluxus.queue_on_teleport)
local RELOAD_BODY = [==[
if not game:IsLoaded() then game.Loaded:Wait() end
local env = getgenv()
local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
if game.PlaceId ~= __PLACE__ then
	if q and type(env.ZinoosReloadSrc) == "string" then
		pcall(q, "getgenv().ZinoosReloadSrc = " .. string.format("%q", env.ZinoosReloadSrc) .. "\nloadstring(getgenv().ZinoosReloadSrc)()")
	end
	return
end
task.wait(4)
if env.ZinoosThrowFoodGen ~= nil then return end
local ok, source = pcall(function()
	return game:HttpGet("https://raw.githubusercontent.com/yszvzms6st-pixel/ZinoosHub/refs/heads/main/games/ThrowFoodAnimals.luau")
end)
if not ok or type(source) ~= "string" or #source < 1000 or env.ZinoosThrowFoodGen ~= nil then return end
local chunk = loadstring(source, "=ZinoosHub/ThrowFoodAnimals.luau")
if chunk then chunk() end
]==]
RELOAD_BODY = string.gsub(RELOAD_BODY, "__PLACE__", tostring(game.PlaceId))
STATE.autoReloadAvailable = typeof(queueTeleport) == "function"
local reloadQueued = false
local function queueReload()
	if reloadQueued or not running() or STATE.autoReload ~= true or not STATE.autoReloadAvailable then
		return
	end
	reloadQueued = pcall(queueTeleport, "getgenv().ZinoosReloadSrc = " .. string.format("%q", RELOAD_BODY) .. "\nloadstring(getgenv().ZinoosReloadSrc)()")
end
trackConnection(LocalPlayer.OnTeleport:Connect(function(teleportState)
	if teleportState == Enum.TeleportState.Started or teleportState == Enum.TeleportState.InProgress then
		queueReload()
	end
end))
end

local Remotes = require(ReplicatedStorage.Shared.Remotes)
elevate()
local LevelConfig = require(ReplicatedStorage.Config.LevelConfig)
elevate()
local FoodsConfig = require(ReplicatedStorage.Config.FoodsConfig)
elevate()
local StandsConfig = require(ReplicatedStorage.Config.StandsConfig)
elevate()
local FenceConfig = require(ReplicatedStorage.Config.FenceConfig)
elevate()
local AreasConfig = require(ReplicatedStorage.Config.AreasConfig)
elevate()
local AnimalEconomy = require(ReplicatedStorage.Config.AnimalEconomy)
elevate()
local Mutations = require(ReplicatedStorage.Shared.Mutations)
elevate()
local AreaUtil = require(ReplicatedStorage.Shared.AreaUtil)
elevate()
-- Newer game systems. Each is optional so a renamed module only disables its
-- own feature instead of stopping the whole hub.
local function optionalRequire(parent, name)
	local module = parent and parent:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, value = pcall(require, module)
	elevate()
	return ok and type(value) == "table" and value or nil
end
local GameConfig = optionalRequire(ReplicatedStorage:FindFirstChild("Config"), "GameConfig")
local RarityConfig = optionalRequire(ReplicatedStorage:FindFirstChild("Config"), "RarityConfig")
local Dreamland = optionalRequire(ReplicatedStorage:FindFirstChild("Shared"), "Dreamland")
local DreamlandConfig = Dreamland and Dreamland.Config or optionalRequire(ReplicatedStorage:FindFirstChild("Config"), "DreamlandConfig")
local IndexRewards = optionalRequire(ReplicatedStorage:FindFirstChild("Shared"), "IndexRewards")
local controllers = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Controllers")
local GameDataController = require(controllers.DataController)
elevate()
local dataReady = false
for _ = 1, 300 do
	local ok, ready = pcall(GameDataController.IsReady, GameDataController)
	if ok and ready == true then
		dataReady = true
		break
	end
	task.wait(0.1)
end
if not dataReady then
	warn("[Zinoos hub] Player data did not replicate through DataController.")
	shutdownHub()
	return
end

local ClientState = require(controllers.ClientState)
elevate()
STATE.throwController = require(controllers.ThrowController)
elevate()
STATE.throwMeter = require(controllers.ThrowMeter)
elevate()
STATE.superThrowController = require(controllers.SuperThrow)
elevate()
STATE.throwMeterOriginalNew = STATE.throwMeter.new
hubCleanup(function()
	if STATE.throwMeter and STATE.throwMeterOriginalNew then
		STATE.throwMeter.new = STATE.throwMeterOriginalNew
	end
end)

-- The game's Get/GetData hand back a full copy every call. With thousands
-- of animals that is ~4-5 ms each, and the hub reads every second. So the
-- animal list is kept from the game's own change feed (one copy per change),
-- and readAll only fetches the keys a caller actually reads.
do
	local ok, stop = pcall(GameDataController.ObserveTable, GameDataController, "Animals", function(value)
		if type(value) == "table" then
			STATE.animalsCache = value
		end
	end)
	if ok and type(stop) == "function" then
		hubCleanup(stop)
	end
end

local function getData(key)
	if key == "Animals" and type(STATE.animalsCache) == "table" then
		return STATE.animalsCache
	end
	local ok, value = pcall(GameDataController.Get, GameDataController, key)
	return ok and value or nil
end

local function readAll()
	return setmetatable({}, {
		__index = function(self, key)
			local value = getData(key)
			if value ~= nil then
				rawset(self, key, value)
			end
			return value
		end,
	})
end

local DataController = {}
function DataController:GetValue(key)
	return getData(key)
end

local function shortNumber(value)
	value = tonumber(value) or 0
	local abs = math.abs(value)
	for _, unit in ipairs({ {1e63, "Vg"}, {1e60, "Nod"}, {1e57, "Ocd"}, {1e54, "Spd"}, {1e51, "Sxd"}, {1e48, "Qid"}, {1e45, "Qad"}, {1e42, "Td"}, {1e39, "Dd"}, {1e36, "Ud"}, {1e33, "Dc"}, {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"}, {1e21, "Sx"}, {1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"} }) do
		if abs >= unit[1] then
			return string.format("%.2f%s", value / unit[1], unit[2]):gsub("%.00", ""):gsub("(%..-)0([A-Za-z]+)$", "%1%2")
		end
	end
	return tostring(math.floor(value + 0.5))
end
STATE.shortNumber = shortNumber

local function invoke(name, ...)
	local ok, result = pcall(Remotes.Invoke, name, ...)
	elevate()
	if not ok then
		return { Ok = false, Reason = tostring(result) }
	end
	return type(result) == "table" and result or { Ok = result ~= false }
end

local function notificationAllowed(category, rarity)
	if STATE.notifications ~= true then
		return false
	end
	if category == "catch" then
		if STATE.notifyCatches ~= true then
			return false
		end
		local minimum = STATE.notifyMinRarity
		if minimum ~= "All" then
			local wanted = RARITY_RANK[minimum] or 1
			local actual = RARITY_RANK[rarity] or 1
			if actual < wanted then
				return false
			end
		end
	elseif category == "sale" then
		return STATE.notifySales == true
	elseif category == "progress" then
		return STATE.notifyProgress == true
	end
	return true
end

local function notify(category, title, message, rarity)
	if not notificationAllowed(category, rarity) then
		return false
	end
	local entry = {
		category = category,
		title = tostring(title or "ZinoosHub"),
		message = tostring(message or ""),
		rarity = rarity,
		time = os.time(),
	}
	table.insert(STATE.notificationLog, entry)
	while #STATE.notificationLog > 20 do
		table.remove(STATE.notificationLog, 1)
	end
	if typeof(STATE.toast) == "function" then
		local ok = pcall(STATE.toast, entry)
		return ok
	end
	return false
end
STATE.notify = notify

local function publicStatus(value)
	return (tostring(value or "game"):gsub("ZinoosHub([%w_]+)", "%1"))
end

local function readableAnimalName(value)
	local text = tostring(value or "Animal"):gsub("_", " ")
	text = text:gsub("(%l)(%u)", "%1 %2")
	text = text:gsub("(%a)(%d)", "%1 %2"):gsub("(%d)(%a)", "%1 %2")
	return text
end

local function describeCatch(result)
	result = type(result) == "table" and result or {}
	local entry = type(result.Entry) == "table" and result.Entry
		or type(result.Animal) == "table" and result.Animal
		or result
	local modelName = entry.ModelName or result.ModelName
	local info = nil
	if type(modelName) == "string" then
		local ok, value = pcall(AnimalEconomy.Get, modelName)
		if ok and type(value) == "table" then
			info = value
		end
	end
	local displayName = entry.DisplayName or result.DisplayName
		or (info and (info.DisplayName or info.Name))
		or modelName
		or "Animal"
	local rarity = entry.Rarity or result.Rarity or (info and info.Rarity) or "Common"
	local mutation = entry.Mutation or result.Mutation
	local income = tonumber(entry.Income or result.Income)
	if not income and type(modelName) == "string" then
		local ok, value = pcall(Mutations.IncomeOf, {
			ModelName = modelName,
			Mutation = mutation,
		}, LocalPlayer:GetAttribute("BestIncome") or 0)
		if ok then
			income = tonumber(value)
		end
	end
	displayName = readableAnimalName(displayName)
	local title = mutation and (tostring(mutation) .. " " .. tostring(displayName)) or tostring(displayName)
	local message = tostring(rarity)
	if income and income > 0 then
		message ..= "  •  $" .. shortNumber(income) .. "/s"
	end
	return title, message, rarity, mutation, income, displayName
end

local knownAnimalIds = {}
local animalWatchReady = false
local function targetCatchMatched(rarity, mutation)
	local rarityHit = STATE.stopOnRarity == true
		and (RARITY_RANK[rarity] or 0) >= (RARITY_RANK[STATE.stopTargetRarity] or math.huge)
	local mutationHit = STATE.stopOnMutation == true
		and type(mutation) == "string"
		and type(STATE.stopTargetMutations) == "table"
		and table.find(STATE.stopTargetMutations, mutation) ~= nil
	return rarityHit or mutationHit, rarityHit, mutationHit
end

local function stopForTargetCatch(title, rarity, mutation)
	local matched, rarityHit, mutationHit = targetCatchMatched(rarity, mutation)
	if not matched then
		return
	end
	STATE.autoThrow = false
	stats.targetStops += 1
	local reason = rarityHit and (tostring(rarity) .. " rarity")
		or (mutationHit and (tostring(mutation) .. " mutation"))
		or "target"
	STATE.throwStatus = "Stopped for " .. tostring(title)
	STATE.status = "Target animal found"
	noteActivity("Stopped Auto Throw: " .. tostring(title) .. " matched " .. tostring(reason))
	notify("system", "Target animal found", tostring(title) .. " matched " .. tostring(reason))
	if typeof(STATE.syncToggle) == "function" then
		pcall(STATE.syncToggle, "autoThrow")
	end
	saveConfig()
end
STATE.targetCatchMatched = targetCatchMatched
STATE.stopForTargetCatch = stopForTargetCatch

local function stepAnimalNotifications()
	local animals = getData("Animals")
	if type(animals) ~= "table" then
		return
	end
	local current = {}
	for id, entry in pairs(animals) do
		current[id] = true
		if animalWatchReady and not knownAnimalIds[id] and type(entry) == "table" then
			local title, message, rarity, mutation, income, displayName = describeCatch(entry)
			STATE.lastCatch = {
				id = id,
				title = title,
				message = message,
				rarity = rarity,
				mutation = mutation,
				income = income,
				displayName = displayName,
				time = os.time(),
			}
			stats.catches += 1
			stats.rarityCounts[rarity] = (stats.rarityCounts[rarity] or 0) + 1
			if mutation then
				stats.mutationCounts[mutation] = (stats.mutationCounts[mutation] or 0) + 1
			end
			table.insert(STATE.catchHistory, 1, STATE.lastCatch)
			while #STATE.catchHistory > 12 do
				table.remove(STATE.catchHistory)
			end
			notify("catch", "Caught " .. title, message, rarity)
			stopForTargetCatch(title, rarity, mutation)
		end
	end
	knownAnimalIds = current
	animalWatchReady = true
end

local function claimBusy(label)
	if ClientState.Busy ~= nil then
		return nil, publicStatus(ClientState.Busy)
	end
	local tokenName = "ZinoosHub" .. tostring(label)
	ClientState.Busy = tokenName
	return tokenName
end

local function releaseBusy(tokenName)
	if tokenName and ClientState.Busy == tokenName then
		ClientState.Busy = nil
	end
end

local function rootPart()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function positionOf(target)
	if not target then
		return nil
	end
	if target:IsA("BasePart") then
		return target.Position
	end
	local ok, pivot = pcall(target.GetPivot, target)
	return ok and pivot.Position or nil
end

local function moveNear(target, offset)
	local root = rootPart()
	local position = positionOf(target)
	elevate()
	if not root or not position or root.Anchored then
		return nil, nil
	end
	local old = root.CFrame
	local destination = position + (offset or Vector3.new(0, 3, 0))
	root.CFrame = CFrame.lookAt(destination, destination + Vector3.new(0, 0, -10))
	root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.8)
	return root, old
end

local function restorePosition(root, old)
	elevate()
	if root and root.Parent and old then
		root.Anchored = false
		root.CFrame = old
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function localProps()
	return workspace:FindFirstChild("LocalPlotProps")
end

local function foodShopTarget()
	local props = localProps()
	local shop = props and props:FindFirstChild("FoodShop")
	return shop and (shop:FindFirstChild("ActivationCircle") or shop)
end

local function trainingTarget()
	local props = localProps()
	local area = props and props:FindFirstChild("TrainingArea")
	return area and (area:FindFirstChild("TrainingSpot") or area)
end

local function standTarget()
	local spot = trainingTarget()
	return spot and (spot:FindFirstChild("UpgradeButton") or spot)
end

local function fenceTarget()
	local gui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("PlotUpgradeSign")
	return gui and gui.Adornee
end

local function sellTarget()
	local place = workspace:FindFirstChild("SellPlace")
	return place and (place:FindFirstChild("ActivationCircle") or place)
end

local function invokeNear(label, target, remoteName, ...)
	local tokenName, busy = claimBusy(label)
	if not tokenName then
		return { Ok = false, Reason = "Busy:" .. tostring(busy or "game") }
	end
	local root, old = moveNear(target)
	if not root then
		releaseBusy(tokenName)
		return { Ok = false, Reason = "TargetUnavailable" }
	end
	local args = table.pack(...)
	local result = invoke(remoteName, table.unpack(args, 1, args.n))
	restorePosition(root, old)
	releaseBusy(tokenName)
	return result
end

local lastSkip = nil
local function syncAutoSkip()
	if lastSkip == STATE.autoSkip then
		return
	end
	local result = invoke("Player_SetSetting", "AutoSkip", STATE.autoSkip == true)
	if result.Ok then
		lastSkip = STATE.autoSkip
	end
end

local function throwPosition()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local launch = AreaUtil.GetLaunchPosition()
	elevate()
	if root and humanoid and launch and not root.Anchored then
		local height = humanoid.HipHeight + root.Size.Y / 2 + 0.1
		local position = launch + Vector3.new(0, height, 0)
		root.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -10))
		root.AssemblyLinearVelocity = Vector3.zero
		return true, root, height
	end
	return false
end

local function leaveThrowLine(root, height)
	local starter = workspace:FindFirstChild("StarterArea")
	local line = starter and starter:FindFirstChild("CrossLine")
	elevate()
	if root and root.Parent and line then
		root.Anchored = false
		local position = line.Position + Vector3.new(0, height or 3, 4)
		root.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -10))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

-- Throw aim. The game's own distance slider (Player_SetThrowPower, 0 means
-- maximum) decides which area the food lands in. The hub only moves it while
-- Dream Hunt or Index Hunt wants a specific area, and puts it back to maximum
-- afterwards. A slider the player set by hand is left alone.
local aim = { applied = false }
-- Remember on disk when the hub moved the slider, so a hub that starts after
-- a rejoin or server hop can put it back to maximum distance.
aim.file = "Rayfield/Configurations/ZinoosHub/ThrowFoodAnimals_aim_" .. tostring(LocalPlayer.UserId) .. ".txt"
function aim.remember(power)
	pcall(writefile, aim.file, tostring(power or 0))
end

local function areaIndexOf(key)
	local ok, count = pcall(AreaUtil.Count)
	if not ok or type(count) ~= "number" then
		return nil
	end
	for index = 1, count do
		local config = AreasConfig.Get(index)
		if type(config) == "table" and config.Key == key then
			return index, config
		end
	end
	return nil
end

local function areaSpan(index)
	local launch = AreaUtil.GetLaunchPosition()
	local area = AreaUtil.Get(index)
	if not launch or type(area) ~= "table" or type(area.ZStart) ~= "number" or type(area.ZEnd) ~= "number" then
		return nil
	end
	return launch.Z - area.ZStart, launch.Z - area.ZEnd
end

local function throwPowerRange()
	local level = tonumber(getData("Level")) or 1
	local maxPower = tonumber(LevelConfig.ThrowPowerForLevel(level)) or 0
	local minPower = math.min(tonumber(LevelConfig.MinThrowPower) or 0, maxPower)
	return minPower, maxPower
end

-- Returns the slider value that lands `depth` (0 = front, 1 = back) of the
-- way into an area, 0 when maximum distance already lands there, or nil
-- when the area cannot be reached at this level.
local function aimPowerFor(areaKey, depth)
	local index = areaIndexOf(areaKey)
	if not index then
		return nil
	end
	local startDistance, endDistance = areaSpan(index)
	if not startDistance then
		return nil
	end
	local bonus = GameConfig and type(GameConfig.Throw) == "table" and tonumber(GameConfig.Throw.MeterBonusStuds) or 0
	local minPower, maxPower = throwPowerRange()
	local wanted = math.floor(startDistance + (endDistance - startDistance) * depth - bonus + 0.5)
	local power = wanted
	if wanted >= maxPower then
		power = maxPower
	elseif wanted < minPower then
		power = minPower
	end
	local ok, _, landed = pcall(AreaUtil.ComputeLanding, power + bonus, 0)
	if not ok or landed ~= index then
		return nil
	end
	return power >= maxPower and 0 or power
end

local function displayAreaName(key)
	local _, config = areaIndexOf(key)
	return config and config.Name or tostring(key)
end

local function dreamState()
	if not Dreamland then
		return nil
	end
	local ok, state = pcall(Dreamland.State)
	return ok and type(state) == "table" and state or nil
end

local function dreamEligible()
	if not Dreamland then
		return false
	end
	local ok, eligible = pcall(Dreamland.IsEligible, LocalPlayer)
	return ok and eligible == true
end

local function dreamCaught()
	local data = getData("Dreamland")
	return type(data) == "table" and type(data.Caught) == "table" and data.Caught or {}
end

-- Collection: the world index (one collection per zone) and the Dreamland
-- collection (split into its five dream habitats) as one list. Each row:
-- id ("Forest" or "Dream:Taiga"), area, name, found, total, dream, claimed,
-- reachable (a throw at this level can land there).
STATE.collectReach = { at = 0, level = nil, areas = {} }
function STATE.collectReachable(area)
	local cache = STATE.collectReach
	local level = tonumber(getData("Level")) or 1
	if os.clock() - cache.at > 20 or cache.level ~= level then
		cache.at, cache.level, cache.areas = os.clock(), level, {}
	end
	if cache.areas[area] == nil then
		cache.areas[area] = aimPowerFor(area, 0.5) ~= nil
	end
	return cache.areas[area]
end

function STATE.collectionRows()
	local data = readAll()
	local index = type(data.Index) == "table" and data.Index or {}
	local rows = { world = {}, dream = {}, worldFound = 0, worldTotal = 0, dreamFound = 0, dreamTotal = 0 }
	if IndexRewards then
		local ok, collections = pcall(IndexRewards.Collections, "World")
		for _, collection in ipairs(ok and type(collections) == "table" and collections or {}) do
			if type(collection) == "table" and collection.Area and collection.Tab ~= "Limited" then
				local okProgress, found, total = pcall(IndexRewards.Progress, index, collection)
				found, total = tonumber(found) or 0, tonumber(total) or 0
				if okProgress and total > 0 then
					local okClaimed, claimed = pcall(IndexRewards.IsClaimed, data, collection.Key)
					-- The zone's animals are listed from most common to rarest, and
					-- the zone's front band rolls the common ones, its back band the
					-- rare ones. Remember where the first missing animal sits (0..1).
					local okAnimals, animals = pcall(IndexRewards.Animals, collection)
					local firstMissing = nil
					if okAnimals and type(animals) == "table" and #animals > 0 then
						for position, name in ipairs(animals) do
							if not index[name] then
								firstMissing = (position - 1) / #animals
								break
							end
						end
					end
					table.insert(rows.world, {
						firstMissing = firstMissing,
						id = tostring(collection.Key),
						area = collection.Area,
						name = displayAreaName(collection.Area),
						found = math.min(found, total),
						total = total,
						claimed = okClaimed and claimed == true,
						reachable = STATE.collectReachable(collection.Area),
					})
					rows.worldFound += math.min(found, total)
					rows.worldTotal += total
				end
			end
		end
	end
	if DreamlandConfig and type(DreamlandConfig.Zones) == "table" then
		local caught = type(data.Dreamland) == "table" and type(data.Dreamland.Caught) == "table" and data.Dreamland.Caught or {}
		for _, zone in ipairs(DreamlandConfig.Zones) do
			if type(zone) == "table" and type(zone.Animals) == "table" and zone.Area then
				local found = 0
				for _, name in ipairs(zone.Animals) do
					if caught[name] then
						found += 1
					end
				end
				table.insert(rows.dream, {
					id = "Dream:" .. tostring(zone.Area),
					area = zone.Area,
					name = displayAreaName(zone.Area),
					found = found,
					total = #zone.Animals,
					dream = true,
					reachable = STATE.collectReachable(zone.Area),
				})
				rows.dreamFound += found
				rows.dreamTotal += #zone.Animals
			end
		end
	end
	elevate()
	return rows
end

-- Collection planner. Which animal a throw catches is rolled from the food's
-- Bait, the zone and how deep into the zone the food lands (the game's own
-- Shared.AnimalRoll.Weights). With the best food a zone's commonest animals
-- can never roll, so for every zone this tries each owned food and landing
-- depth and keeps the one with the highest chance of an animal still
-- missing from the index. Re-planned only when the index, level or owned
-- foods change.
do
	local AnimalRoll = optionalRequire(ReplicatedStorage:FindFirstChild("Shared"), "AnimalRoll")
	local AnimalsData = nil
	pcall(function()
		AnimalsData = require(ReplicatedStorage:FindFirstChild("AnimalsData"))
	end)
	elevate()
	-- Landing spots well inside each of the zone's three bands: real throws
	-- land a few studs off, and the game nudges landings away from the band
	-- lines, so a spot near an edge can end up in the next zone or band.
	local DEPTHS = {}
	for band = 0, 2 do
		for _, offset in ipairs({ 0.07, 0.12, 0.17, 0.21, 0.26 }) do
			DEPTHS[#DEPTHS + 1] = band / 3 + offset
		end
	end
	local cache = { key = nil, plans = {} }
	function STATE.collectPlanReset()
		cache.key = nil
	end

	-- Slider value for a throw aimed `depth` into the area. Not every throw
	-- gets the meter's bonus distance, so the slider sits halfway and the
	-- spot only counts when the throw lands in this area and the same band
	-- with or without the bonus. Returns the slider value (0 = maximum) and
	-- the two landing depths (no bonus, full bonus).
	local function landingDepth(distance, index)
		local ok, position, landed = pcall(AreaUtil.ComputeLanding, distance, 0)
		if not ok or landed ~= index or typeof(position) ~= "Vector3" then
			return nil
		end
		local okDepth, depth = pcall(AreaUtil.DepthInArea, index, position.Z)
		return okDepth and tonumber(depth) or nil
	end
	local function exactPower(index, depth)
		local startDistance, endDistance = areaSpan(index)
		if not startDistance then
			return nil
		end
		local bonus = GameConfig and type(GameConfig.Throw) == "table" and tonumber(GameConfig.Throw.MeterBonusStuds) or 0
		local minPower, maxPower = throwPowerRange()
		local wanted = math.floor(startDistance + (endDistance - startDistance) * depth - bonus / 2 + 0.5)
		if wanted < minPower or wanted > maxPower then
			return nil
		end
		local low = landingDepth(wanted, index)
		local high = landingDepth(wanted + bonus, index)
		if not low or not high then
			return nil
		end
		local subAreas = tonumber(AreasConfig.SubAreas) or 3
		if math.floor(math.clamp(low, 0, 0.999) * subAreas) ~= math.floor(math.clamp(high, 0, 0.999) * subAreas) then
			return nil
		end
		return wanted >= maxPower and 0 or wanted, low, high
	end

	local function ownedFoods()
		local owned = getData("OwnedFoods")
		local equipped = tonumber(getData("EquippedFood")) or 0
		local list = {}
		local count = (FoodsConfig.Count and FoodsConfig.Count()) or 0
		for i = 1, count do
			local food = FoodsConfig.Get(i)
			local has = type(owned) == "table" and (owned[i] == true or owned[tostring(i)] == true)
			if food and tonumber(food.Bait) and (has or i == equipped) then
				list[#list + 1] = { index = i, bait = tonumber(food.Bait) }
			end
		end
		return list, equipped
	end
	STATE.collectOwnedFoods = ownedFoods

	-- rows: STATE.collectionRows().world. Returns { [row.id] = plan } where
	-- plan = { food, depth, power, chance }.
	function STATE.collectPlans(rows)
		if not AnimalRoll or type(AnimalRoll.Weights) ~= "function" or type(AnimalsData) ~= "table" then
			return nil
		end
		local foods = ownedFoods()
		if #foods == 0 then
			return nil
		end
		local index = getData("Index")
		index = type(index) == "table" and index or {}
		local parts = { tostring(getData("Level")), tostring(#foods), tostring(STATE.collectBanEpoch or 0) }
		for _, row in ipairs(rows) do
			parts[#parts + 1] = row.id .. ":" .. tostring(row.found)
		end
		local key = table.concat(parts, "|")
		if cache.key == key then
			return cache.plans
		end
		local plans = {}
		for _, row in ipairs(rows) do
			local areaIndex = areaIndexOf(row.area)
			local animals = AnimalsData[row.area]
			if areaIndex and type(animals) == "table" and row.found < row.total then
				local missing = {}
				for rank, animal in ipairs(animals) do
					if type(animal) == "table" and index[animal.ModelName] ~= true then
						missing[#missing + 1] = rank
					end
				end
				local best = nil
				if #missing > 0 then
					for _, depth in ipairs(DEPTHS) do
						local power, low, high = exactPower(areaIndex, depth)
						if power then
							for _, food in ipairs(foods) do
								-- The worse of the two possible landings counts.
								local chance = nil
								for _, landed in ipairs({ low, high }) do
									local ok, weights = pcall(AnimalRoll.Weights, food.bait, areaIndex, landed)
									local here = 0
									if ok and type(weights) == "table" then
										for _, rank in ipairs(missing) do
											here += tonumber(weights[rank]) or 0
										end
									end
									chance = chance and math.min(chance, here) or here
								end
								do
									-- Prefer the stronger food on ties: more cash per catch.
									if not best or chance > best.chance + 1e-6 or (math.abs(chance - best.chance) <= 1e-6 and food.index > best.food) then
										best = { food = food.index, depth = depth, power = power, chance = chance }
									end
								end
							end
						end
					end
				end
				plans[row.id] = best
				-- Spread the work over frames instead of one long hitch.
				task.wait()
			end
		end
		elevate()
		cache.key = key
		cache.plans = plans
		return plans
	end
end

-- Food Auto Collect asked for, and the food to put back afterwards. The
-- marker file lets a hub started after a rejoin finish the job.
do
	local foodSwap = {
		file = "Rayfield/Configurations/ZinoosHub/ThrowFoodAnimals_food_" .. tostring(LocalPlayer.UserId) .. ".txt",
		nextTry = 0,
	}
	local function bestOwned()
		local list = STATE.collectOwnedFoods and STATE.collectOwnedFoods() or {}
		local best = 0
		for _, food in ipairs(list) do
			best = math.max(best, food.index)
		end
		return best
	end
	local function equip(index)
		local equipped = tonumber(getData("EquippedFood")) or 0
		if equipped == index then
			return true
		end
		if os.clock() < foodSwap.nextTry or ClientState.Busy ~= nil then
			return false
		end
		local result = invokeNear("Food", foodShopTarget(), "Shop_Equip", index)
		if not result.Ok then
			foodSwap.nextTry = os.clock() + 5
			STATE.collectFoodStatus = "Food swap failed: " .. tostring(result.Reason or "rejected")
			return false
		end
		local deadline = os.clock() + 1.5
		while running() and (tonumber(getData("EquippedFood")) or 0) ~= index and os.clock() < deadline do
			task.wait(0.05)
		end
		return (tonumber(getData("EquippedFood")) or 0) == index
	end

	-- Equip the food the planner wants (nil = the best food you own).
	function STATE.collectEquipFood(wanted)
		local best = bestOwned()
		if best <= 0 then
			return false
		end
		local target = wanted or best
		local equipped = tonumber(getData("EquippedFood")) or 0
		if equipped == target then
			return true
		end
		if target ~= best then
			-- Remember to put the best food back afterwards.
			pcall(writefile, foodSwap.file, tostring(best))
			STATE.collectFoodSwapped = true
		end
		local ok = equip(target)
		if ok and target == best then
			STATE.collectFoodSwapped = false
			pcall(writefile, foodSwap.file, "")
		end
		return ok
	end

	-- Put the best food back once Auto Collect no longer needs another one.
	function STATE.collectRestoreFood()
		if STATE.collectFoodSwapped ~= true then
			return
		end
		STATE.collectEquipFood(nil)
	end

	local ok, saved = pcall(readfile, foodSwap.file)
	if ok and tonumber(saved) then
		STATE.collectFoodSwapped = true
	end
end

-- Where Auto Collect wants the next throw to land. Returns the slider value
-- (0 = maximum distance), a label, and the row id it is working on.
function STATE.aimTarget()
	STATE.collectWantsSuper = false
	if STATE.indexHunt ~= true then
		return nil
	end
	local rows = STATE.collectionRows()
	local state = dreamState()
	local dreamLive = state ~= nil and state.Active == true and dreamEligible()
	-- A zone has three bands: the front rolls its common animals, the back its
	-- rarest. Aim at the band of the first animal still missing. Lucky
	-- (Super) Throws only pay off in the back band, where the rare ones are.
	STATE.collectWantsSuper = false
	STATE.collectFoodWanted = nil
	local plans = STATE.collectPlans and STATE.collectPlans(rows.world) or nil
	local function aimAt(row)
		local plan = plans and not row.dream and plans[row.id] or nil
		if plan and plan.chance > 0 then
			STATE.collectFoodWanted = plan.food
			STATE.collectWantsSuper = plan.chance < 0.5
			return plan.power, string.format("Collecting %s · %d/%d · %d%% new per throw", row.name, row.found, row.total, math.floor(plan.chance * 100 + 0.5)), row.id
		end
		local depth, band = 0.95, nil
		if row.dream then
			-- A dream catch is picked at random from the habitat's first
			-- ceil(depth x count) dream animals, so land in the shortest
			-- front stretch with the best share of animals still missing.
			local animals = nil
			for _, zone in ipairs(DreamlandConfig and type(DreamlandConfig.Zones) == "table" and DreamlandConfig.Zones or {}) do
				if type(zone) == "table" and zone.Area == row.area then
					animals = zone.Animals
				end
			end
			if type(animals) == "table" and #animals > 0 then
				local caught = dreamCaught()
				local bestShare, bestCount, missing = -1, #animals, 0
				for count, name in ipairs(animals) do
					if not caught[name] then
						missing += 1
					end
					local share = missing / count
					if share > bestShare + 1e-9 then
						bestShare, bestCount = share, count
					end
				end
				-- Middle of that stretch, nudged forward for throws that miss
				-- the meter bonus.
				depth = math.clamp((bestCount - 0.5) / #animals + 0.04, 0.05, 0.95)
			end
		end
		if not row.dream then
			local at = tonumber(row.firstMissing) or 0.9
			if at < 0.45 then
				depth, band = 0.17, "front"
			elseif at < 0.75 then
				depth, band = 0.5, "middle"
			else
				depth, band = 0.85, "back"
			end
		end
		local power = aimPowerFor(row.area, depth)
		if power then
			STATE.collectWantsSuper = band == "back"
			return power, string.format("Collecting %s%s%s · %d/%d", row.dream and "Dreamland " or "", row.name, band and (" (" .. band .. ")") or "", row.found, row.total), row.id
		end
		return nil
	end

	local target = tostring(STATE.collectTarget or "Auto")
	if target ~= "Auto" then
		for _, list in ipairs({ rows.world, rows.dream }) do
			for _, row in ipairs(list) do
				if row.id == target then
					if row.found >= row.total then
						return nil
					end
					if row.dream and not dreamLive then
						-- Dream animals only appear during a run; farm normally until then.
						return 0, "Waiting for the next Dreamland run · " .. row.name, row.id
					end
					return aimAt(row)
				end
			end
		end
		return nil
	end

	-- Dream animals only show up for a few minutes, so they come first.
	if dreamLive then
		local best = nil
		for order, row in ipairs(rows.dream) do
			local missing = row.total - row.found
			if missing > 0 and row.reachable and (not best or missing > best.total - best.found or (missing == best.total - best.found and order > best.order)) then
				best = row
				best.order = order
			end
		end
		if best then
			local power, label, id = aimAt(best)
			if power then
				return power, label, id
			end
		end
	end
	-- World: easiest missing animal first (the one sitting furthest toward the
	-- common end of its zone), so every throw has the best chance of being new.
	-- Zones where only the rarest are left come last.
	if plans then
		-- Best chance of a new animal per throw. Near-ties stay on the zone
		-- already being worked (no food swap), then go to the zone with more
		-- missing.
		local best, bestPlan = nil, nil
		for _, row in ipairs(rows.world) do
			local plan = plans[row.id]
			local banned = STATE.collectBans and (STATE.collectBans[row.id] or 0) > os.clock()
			if row.found < row.total and plan and plan.chance > 0 and not banned then
				local better = not best
				if best then
					local diff = plan.chance - bestPlan.chance
					if diff > 0.03 then
						better = true
					elseif diff >= -0.03 then
						if row.id == STATE.collectAimId and best.id ~= STATE.collectAimId then
							better = true
						elseif best.id ~= STATE.collectAimId and (row.total - row.found) > (best.total - best.found) then
							better = true
						end
					end
				end
				if better then
					best, bestPlan = row, plan
				end
			end
		end
		if best then
			return aimAt(best)
		end
	end
	local best = nil
	for _, row in ipairs(rows.world) do
		local missing = row.total - row.found
		local at = tonumber(row.firstMissing) or 1
		if missing > 0 and row.reachable then
			local bestAt = best and (tonumber(best.firstMissing) or 1)
			if not best or at < bestAt - 0.001 or (math.abs(at - bestAt) <= 0.001 and missing > best.total - best.found) then
				best = row
			end
		end
	end
	if best then
		return aimAt(best)
	end
	return nil
end

-- Is the thing Auto Collect is working on finished? "Auto" means every row
-- in both lists.
function STATE.collectComplete(rows)
	local target = tostring(STATE.collectTarget or "Auto")
	for _, list in ipairs({ rows.world, rows.dream }) do
		for _, row in ipairs(list) do
			if (target == "Auto" or row.id == target) and row.found < row.total then
				return false
			end
		end
	end
	return #rows.world + #rows.dream > 0
end

local function setThrowPower(power)
	if (tonumber(getData("ThrowPower")) or 0) == power then
		return true
	end
	local result = invoke("Player_SetThrowPower", power)
	if not result.Ok then
		STATE.aimStatus = "Aim rejected: " .. tostring(result.Reason or "unknown")
		return false
	end
	local deadline = os.clock() + 1.5
	while running() and (tonumber(getData("ThrowPower")) or 0) ~= power and os.clock() < deadline do
		task.wait(0.05)
	end
	return true
end

function STATE.restoreAim()
	if aim.applied then
		if setThrowPower(0) then
			aim.applied = false
			aim.remember(0)
			STATE.aimStatus = "Maximum distance"
		end
	end
end
hubCleanup(function()
	pcall(STATE.restoreAim)
end)
do
	-- The last hub aimed and never got to put the slider back (the server
	-- changed mid-throw): take it over so it goes back to maximum.
	local ok, saved = pcall(readfile, aim.file)
	local power = ok and tonumber(saved) or 0
	if power and power > 0 and (tonumber(getData("ThrowPower")) or 0) == power then
		aim.applied = true
	end
end

function STATE.applyAim()
	-- Safety net: if a zone's planned throws keep giving nothing new (4 in a
	-- row), skip that zone for 10 minutes and plan again.
	do
		local rows = STATE.collectRows
		local found = rows and (rows.worldFound + rows.dreamFound) or 0
		local miss = STATE.collectMiss
		local catches = tonumber(stats.catches) or 0
		if STATE.indexHunt == true and miss and miss.id == STATE.collectAimId and miss.id and not string.find(miss.id, "^Dream:") then
			if found > miss.found then
				miss.count = 0
			elseif catches > miss.catches then
				miss.count += catches - miss.catches
			end
			if miss.count >= 4 then
				STATE.collectBans = STATE.collectBans or {}
				STATE.collectBans[miss.id] = os.clock() + 600
				STATE.collectBanEpoch = (STATE.collectBanEpoch or 0) + 1
				noteActivity("Auto Collect: " .. tostring(miss.id) .. " gave nothing new 4 times, trying other zones for 10 minutes")
				miss.count = 0
			end
			miss.found, miss.catches = found, catches
		end
	end
	local ok, power, label, rowId = pcall(STATE.aimTarget)
	elevate()
	STATE.collectAimId = ok and type(power) == "number" and rowId or nil
	if STATE.collectAimId and (not STATE.collectMiss or STATE.collectMiss.id ~= STATE.collectAimId) then
		local rows = STATE.collectRows
		STATE.collectMiss = {
			id = STATE.collectAimId,
			count = 0,
			found = rows and (rows.worldFound + rows.dreamFound) or 0,
			catches = tonumber(stats.catches) or 0,
		}
	end
	-- The planner may want a weaker food for this zone; otherwise make sure
	-- the best food is back on.
	if STATE.collectAimId and STATE.collectFoodWanted then
		pcall(STATE.collectEquipFood, STATE.collectFoodWanted)
	else
		pcall(STATE.collectRestoreFood)
	end
	elevate()
	if ok and type(power) == "number" then
		if power ~= 0 or aim.applied then
			if setThrowPower(power) then
				aim.applied = power ~= 0
				aim.remember(power)
				STATE.aimStatus = label or "Aimed throw"
			end
		else
			STATE.aimStatus = label or "Maximum distance"
		end
		return
	end
	STATE.restoreAim()
	if not aim.applied then
		STATE.aimStatus = "Maximum distance"
	end
end

local lastObservedThrows = tonumber(getData("Throws")) or 0
local nextThrowTrigger = 0
local function shouldUseSuperThrow()
	-- While Auto Collect is aiming, Lucky Throws follow the Collection page:
	-- spent only on throws into a zone's rare back band.
	if STATE.indexHunt == true and STATE.collectAimId ~= nil then
		if STATE.collectSuper ~= true then
			STATE.superThrowStatus = "Off while collecting"
			return false
		elseif STATE.collectWantsSuper ~= true then
			STATE.superThrowStatus = "Saved for rare collection animals"
			return false
		end
	elseif STATE.autoSuper ~= true then
		STATE.superThrowStatus = "Off"
		return false
	end
	local available = tonumber(getData("SuperThrows")) or 0
	local reserve = tonumber(STATE.superThrowReserve) or 0
	if available <= reserve then
		STATE.superThrowStatus = available <= 0
			and "No saved Super Throws"
			or ("Reserve protected - " .. tostring(available) .. " saved")
		return false
	end
	STATE.superThrowStatus = "Ready - " .. tostring(available) .. " saved"
	return true
end

local function useSuperThrow()
	local before = tonumber(getData("SuperThrows")) or 0
	local result = invoke("Throw_UseSuper")
	if result.Ok then
		STATE.superThrowStatus = "Armed - " .. tostring(math.max(0, before - 1)) .. " saved"
		noteActivity("Super Throw armed")
	else
		STATE.superThrowStatus = "Not armed: " .. tostring(result.Reason or "rejected")
	end
	return result
end

local function stepThrow()
	-- During Ring Rush every throw is a ring flight. Auto Ring Rush plays it
	-- even with Auto Throw off; with Auto Ring Rush off the hub's own throws
	-- wait so they never get in the player's way.
	local ringLive = typeof(STATE.ringRushLive) == "function" and STATE.ringRushLive() == true
	local ringPlay = ringLive and STATE.autoRingRush == true
	if (STATE.autoThrow ~= true and not ringPlay) or STATE.autoTrain == true then
		if STATE.autoThrow ~= true then
			STATE.throwStatus = "Off"
		end
		return 0.5
	end
	if ringLive and not ringPlay then
		STATE.throwStatus = "Paused for Ring Rush (Auto Ring Rush is off)"
		return 1
	end
	syncAutoSkip()
	local currentThrows = tonumber(getData("Throws")) or lastObservedThrows
	if currentThrows > lastObservedThrows then
		stats.throws += currentThrows - lastObservedThrows
		STATE.throwStatus = "Completed throw " .. tostring(currentThrows)
		noteActivity("Caught throw result " .. tostring(currentThrows))
	end
	lastObservedThrows = currentThrows
	local busy = ClientState.Busy
	if busy == "Throw" then
		STATE.status = ringLive and "Flying through Ring Rush" or "Throwing food"
		STATE.throwStatus = ringLive and "Ring Rush flight running"
			or (STATE.perfectMeter and "Perfect throw running" or "Throw running")
		return 0.25
	elseif busy then
		STATE.status = "Waiting for " .. publicStatus(busy)
		STATE.throwStatus = "Waiting for game"
		return 0.5
	end
	if os.clock() < nextThrowTrigger then
		return 0.25
	end
	-- Point this throw at a Dreamland habitat or an unfinished index area when
	-- those options are on; otherwise keep (or restore) maximum distance.
	if not ringPlay then
		pcall(STATE.applyAim)
	end
	elevate()
	local throwToken = claimBusy("Throw")
	if not throwToken then
		return 0.5
	end
	local moved, root, height = throwPosition()
	if not moved then
		releaseBusy(throwToken)
		STATE.throwStatus = "Throw line unavailable"
		nextThrowTrigger = os.clock() + 1
		return 0.5
	end
	STATE.status = "Throwing food"
	STATE.throwStatus = STATE.perfectMeter and "Perfect throw running" or "Throw running"
	-- Give the server enough time to receive the line teleport. A quarter-second
	-- was unreliable on lower FPS clients and caused valid throws to return TooFar.
	task.wait(0.8)
	if ringPlay then
		-- A ring flight only exists in the game's own throw, so always use
		-- it here. The throw returns when the run ends (event over, or too
		-- many missed rings), which can be the rest of the event.
		local previousAutoTap = STATE.throwMeter.TestAutoTap
		local previousMeterNew = STATE.throwMeter.new
		STATE.throwMeter.new = function(...)
			local meter = previousMeterNew(...)
			meter:SetLocked(true)
			return meter
		end
		STATE.throwMeter.TestAutoTap = 0.5
		local ringsBefore = STATE.ringRushRings()
		STATE.status = "Flying through Ring Rush"
		STATE.throwStatus = "Ring Rush flight running"
		STATE.ringRushStatus = "Flying and steering through the rings..."
		noteActivity("Ring Rush flight started")
		releaseBusy(throwToken)
		local sequenceOk, sequenceError = pcall(STATE.throwController.Start)
		STATE.throwMeter.new = previousMeterNew
		STATE.throwMeter.TestAutoTap = previousAutoTap
		elevate()
		local gained = math.max(0, STATE.ringRushRings() - ringsBefore)
		if sequenceOk then
			STATE.ringRushStatus = string.format("Last run: %d %s. Starting the next one...", gained, gained == 1 and "ring" or "rings")
			STATE.throwStatus = "Ring Rush run ended"
			noteActivity(string.format("Ring Rush run: %d rings", gained))
		else
			STATE.ringRushStatus = "Run error: " .. tostring(sequenceError)
			STATE.throwStatus = "Ring Rush error: " .. tostring(sequenceError)
		end
		lastObservedThrows = tonumber(getData("Throws")) or lastObservedThrows
		STATE.status = "Waiting for next throw"
		nextThrowTrigger = os.clock() + (sequenceOk and 1 or 3)
		return 0.25
	end
	if STATE.autoSkip ~= true then
		-- The game's controller owns the complete throw, POV and animal reveal.
		-- Keep our prep token until Start is called so its line detector cannot
		-- start a second copy between the teleport and the controller call.
		local previousAutoTap = STATE.throwMeter.TestAutoTap
		local previousMeterNew = STATE.throwMeter.new
		if STATE.perfectMeter == true then
			-- The game's "Perfect" band begins below a full meter, so timing an
			-- automatic tap can display +19. Locking the native meter makes its
			-- own Run method return exactly 1 and award the maximum +20 power.
			STATE.throwMeter.new = function(...)
				local meter = previousMeterNew(...)
				meter:SetLocked(true)
				return meter
			end
			STATE.throwMeter.TestAutoTap = 0.5
		else
			STATE.throwMeter.TestAutoTap = 0.9
		end
		local wantsSuper = shouldUseSuperThrow()
		local superBefore = tonumber(getData("SuperThrows")) or 0
		local previousSuperBegin = STATE.superThrowController.Begin
		local requestedSuper = false
		if wantsSuper and type(previousSuperBegin) == "function" then
			-- A visible throw creates its native SuperThrow offer only after
			-- Throw_Start succeeds. Use that offer's own UseSaved flow so its
			-- grant event, meter lock and visuals stay in the game's order.
			STATE.superThrowController.Begin = function(context)
				local superInstance = previousSuperBegin(context)
				if type(superInstance) == "table"
					and superInstance.SavedMode == true
					and type(superInstance.UseSaved) == "function" then
					requestedSuper = true
					STATE.superThrowStatus = "Using native Super Throw offer"
					task.defer(function()
						if running() and not superInstance.Dead and superInstance.State == "Offer" then
							superInstance:UseSaved()
						end
					end)
				else
					STATE.superThrowStatus = "Not offered for this throw"
				end
				return superInstance
			end
		end
		releaseBusy(throwToken)
		local sequenceOk, sequenceError = pcall(STATE.throwController.Start)
		STATE.superThrowController.Begin = previousSuperBegin
		STATE.throwMeter.new = previousMeterNew
		STATE.throwMeter.TestAutoTap = previousAutoTap
		elevate()
		local after = tonumber(getData("Throws")) or lastObservedThrows
		if after > lastObservedThrows then
			stats.throws += after - lastObservedThrows
			STATE.throwStatus = "Completed visible throw " .. tostring(after)
			noteActivity("Completed catch animation " .. tostring(after))
		elseif not sequenceOk then
			STATE.throwStatus = "Throw animation error: " .. tostring(sequenceError)
		else
			STATE.throwStatus = "Visible throw ended without a catch"
		end
		if requestedSuper then
			local superAfter = tonumber(getData("SuperThrows")) or superBefore
			local superDeadline = os.clock() + 1
			while running() and superAfter >= superBefore and os.clock() < superDeadline do
				task.wait()
				superAfter = tonumber(getData("SuperThrows")) or superBefore
			end
			STATE.superThrowStatus = superAfter < superBefore
				and ("Used - " .. tostring(superAfter) .. " saved")
				or "Server did not apply Super Throw"
		end
		lastObservedThrows = after
		STATE.status = "Waiting for next throw"
		nextThrowTrigger = os.clock() + 0.35
		return 0.25
	end
	local started = invoke("Throw_Start")
	local result = nil
	local superResult = nil
	if started.Ok then
		-- The skipped path has no native meter offer, but the server still
		-- requires an active throw before it accepts Throw_UseSuper.
		if shouldUseSuperThrow() then
			if started.SuperOffer == true then
				superResult = useSuperThrow()
			else
				STATE.superThrowStatus = "Not offered for this throw"
			end
		end
		result = invoke("Throw_Resolve", STATE.perfectMeter == true and 1 or 0.75)
		if result.Ok then
			invoke("Throw_Complete")
			if superResult and superResult.Ok then
				STATE.superThrowStatus = result.SuperThrow
					and ("Used - " .. tostring(tonumber(getData("SuperThrows")) or 0) .. " saved")
					or "Server did not apply Super Throw"
			end
		else
			invoke("Throw_Cancel")
		end
	end
	leaveThrowLine(root, height)
	releaseBusy(throwToken)
	local after = tonumber(getData("Throws")) or lastObservedThrows
	if after > lastObservedThrows then
		stats.throws += after - lastObservedThrows
		local animal = result and (result.DisplayName or result.ModelName)
		STATE.throwStatus = "Completed throw " .. tostring(after)
		noteActivity(animal and ("Caught " .. tostring(animal)) or ("Completed throw " .. tostring(after)))
	elseif not started.Ok then
		STATE.throwStatus = "Waiting: " .. tostring(started.Reason or "rejected")
	elseif result and not result.Ok then
		STATE.throwStatus = "Resolve failed: " .. tostring(result.Reason or "rejected")
	end
	lastObservedThrows = after
	STATE.status = "Waiting for next throw"
	nextThrowTrigger = os.clock() + (started.Reason == "Cooldown" and 0.75 or 0.35)
	return 0.25
end

local trainingSession = nil
local trainingToken = nil
local trainingRoot = nil
local trainingReturn = nil
local nextBonus = 0
local pendingBonusId = nil
local pendingBonusExpires = 0
trackConnection(Remotes.Event("Training_Bonus").OnClientEvent:Connect(function(id, expires)
	if STATE.autoTrain == true and STATE.autoTapBonus == true then
		pendingBonusId = id
		pendingBonusExpires = tonumber(expires) or 0
	end
end))
local function stopTraining()
	if trainingSession then
		invoke("Training_Stop")
		trainingSession = nil
		STATE.trainingStatus = "Stopped"
	end
	restorePosition(trainingRoot, trainingReturn)
	trainingRoot = nil
	trainingReturn = nil
	releaseBusy(trainingToken)
	trainingToken = nil
	pendingBonusId = nil
	pendingBonusExpires = 0
end
hubCleanup(stopTraining)

local function stopTrainingAtTarget()
	if STATE.autoTrain ~= true or STATE.trainToTarget ~= true or boostTraining.active then
		return false
	end
	local level = tonumber(getData("Level")) or 1
	-- The saved ThrowPower value is the game's distance slider (0 = maximum),
	-- which the throw aim may lower. Measure the full power the level gives.
	local power = tonumber(LevelConfig.EffectiveThrowPower(level, 0)) or 0
	local target = TRAIN_TARGET_VALUES[STATE.trainTargetPower] or math.huge
	if power < target then
		return false
	end
	stopTraining()
	elevate()
	STATE.autoTrain = false
	if STATE.resumeThrowAfterTraining == true then
		STATE.autoThrow = true
	end
	STATE.trainingStatus = "Target reached at " .. shortNumber(power)
	STATE.status = STATE.resumeThrowAfterTraining == true and "Training target reached; throwing resumed" or "Training target reached"
	noteActivity(STATE.status)
	notify("progress", "Training target reached", shortNumber(power) .. " throw power")
	if typeof(STATE.syncToggle) == "function" then
		pcall(STATE.syncToggle, "autoTrain")
		pcall(STATE.syncToggle, "autoThrow")
	end
	saveConfig()
	return true
end
STATE.stopTrainingAtTarget = stopTrainingAtTarget

local function atMaxLevel()
	local maxLevel = tonumber(LevelConfig.MaxLevel)
	return maxLevel ~= nil and (tonumber(getData("Level")) or 0) >= maxLevel
end
STATE.atMaxLevel = atMaxLevel

local function stepTraining()
	if STATE.autoTrain ~= true then
		stopTraining()
		STATE.trainingStatus = atMaxLevel() and "Max level reached - training gives nothing" or "Off"
		return
	end
	if atMaxLevel() then
		-- Training only adds XP; a max-level account gains nothing from it, so
		-- go back to throwing instead of standing on the pull-up bar.
		stopTraining()
		elevate()
		STATE.autoTrain = false
		STATE.autoThrow = true
		boostTraining.active = false
		STATE.trainingStatus = "Max level reached - training gives nothing"
		noteActivity("Max level reached; Auto Throw resumed")
		notify("progress", "Max level reached", "Training gives no more power, so Auto Throw was turned back on")
		if typeof(STATE.syncToggle) == "function" then
			pcall(STATE.syncToggle, "autoTrain")
			pcall(STATE.syncToggle, "autoThrow")
		end
		saveConfig()
		return
	end
	if stopTrainingAtTarget() then
		return
	end
	if not trainingSession then
		trainingToken = claimBusy("Training")
		if not trainingToken then
			STATE.trainingStatus = "Waiting for " .. publicStatus(ClientState.Busy)
			return
		end
		trainingRoot, trainingReturn = moveNear(trainingTarget())
		if not trainingRoot then
			STATE.trainingStatus = "Training spot unavailable"
			releaseBusy(trainingToken)
			trainingToken = nil
			return
		end
		local result = invoke("Training_Start")
		if result.Ok then
			trainingSession = result
			stats.trained += 1
			STATE.trainingStatus = "Training"
			STATE.status = "Training throw power"
			noteActivity("Training started")
		else
			STATE.trainingStatus = "Start rejected: " .. tostring(result.Reason or "unknown")
			restorePosition(trainingRoot, trainingReturn)
			trainingRoot = nil
			trainingReturn = nil
			releaseBusy(trainingToken)
			trainingToken = nil
			return
		end
	end
	if STATE.autoTapBonus == true and pendingBonusId and os.clock() >= nextBonus then
		if pendingBonusExpires <= 0 or workspace:GetServerTimeNow() < pendingBonusExpires then
			local bonusId = pendingBonusId
			pendingBonusId = nil
			local result = invoke("Training_TapBonus", bonusId)
			if result.Ok then
				stats.bonuses += 1
				STATE.trainingStatus = "Training + bonus"
				local finish = (tonumber(result.Start) or 0) + (tonumber(result.Duration) or 0)
				if finish > 0 then
					nextBonus = os.clock() + math.max(0.1, finish - workspace:GetServerTimeNow())
				end
			elseif result.Reason then
				STATE.trainingStatus = "Training; bonus " .. tostring(result.Reason)
			end
		else
			pendingBonusId = nil
		end
	end
end

local nextUpgrade = 0
local function bestOwnedFood(data)
	local owned = type(data.OwnedFoods) == "table" and data.OwnedFoods or {}
	local best = 1
	for _, food in ipairs(FoodsConfig.All or FoodsConfig.List or {}) do
		if owned[food.Index] == true or owned[tostring(food.Index)] == true then
			best = math.max(best, food.Index)
		end
	end
	return best
end

local function stepUpgrades()
	if os.clock() < nextUpgrade then
		return
	end
	nextUpgrade = os.clock() + 1.5
	local data = readAll()
	local money = tonumber(data.Money) or 0
	local reserve = CASH_RESERVE_VALUES[STATE.cashReserve] or 0
	local spendable = math.max(0, money - reserve)
	local reserveBlocked = false
	local changed = false
	local selectedUpgrades = 0
	local maxedUpgrades = 0
	STATE.upgradeStatus = "Checking upgrades"
	if STATE.autoFood == true then
		selectedUpgrades += 1
		local best = bestOwnedFood(data)
		local equipped = tonumber(data.EquippedFood) or 0
		local nextFood = FoodsConfig.Get and FoodsConfig.Get(best + 1) or (FoodsConfig.All or {})[best + 1]
		local nextFoodPrice = nextFood and (tonumber(nextFood.Price) or math.huge) or math.huge
		if nextFood and nextFoodPrice <= spendable then
			local result = invokeNear("Food", foodShopTarget(), "Shop_Buy", nextFood.Index)
			if result.Ok then
				stats.foods += 1
				changed = true
				STATE.upgradeStatus = "Bought " .. tostring(nextFood.Name)
				noteActivity(STATE.upgradeStatus)
				notify("progress", "Food upgraded", tostring(nextFood.Name))
			else
				STATE.upgradeStatus = "Food: " .. tostring(result.Reason or "rejected")
			end
		else
			if nextFood and nextFoodPrice <= money then
				reserveBlocked = true
			end
			if not nextFood and best <= equipped then
				maxedUpgrades += 1
			end
			-- Auto Collect may be using a weaker food on purpose.
			if best > equipped and not (STATE.indexHunt == true and STATE.collectFoodWanted ~= nil) then
				local result = invokeNear("Food", foodShopTarget(), "Shop_Equip", best)
				if result.Ok then
					STATE.upgradeStatus = "Equipped " .. tostring((FoodsConfig.GetAny and FoodsConfig.GetAny(best) or {}).Name or ("food " .. best))
					changed = true
					notify("progress", "Food equipped", (STATE.upgradeStatus:gsub("^Equipped%s+", "")))
				else
					STATE.upgradeStatus = "Food equip: " .. tostring(result.Reason or "rejected")
				end
			end
		end
	end
	if STATE.autoStand == true then
		selectedUpgrades += 1
		if not changed then
			local stand = tonumber(data.Stand) or 0
			local nextStand = StandsConfig.Get and StandsConfig.Get(stand + 1) or (StandsConfig.All or {})[stand + 1]
			local nextStandPrice = nextStand and (tonumber(nextStand.Price) or math.huge) or math.huge
			if not nextStand then
				maxedUpgrades += 1
			elseif nextStandPrice <= spendable then
				local result = invokeNear("Stand", standTarget(), "Stand_Upgrade")
				if result.Ok then
					stats.stands += 1
					changed = true
					STATE.upgradeStatus = "Bought " .. tostring(nextStand.Name)
					noteActivity(STATE.upgradeStatus)
					notify("progress", "Stand upgraded", tostring(nextStand.Name))
				else
					STATE.upgradeStatus = "Stand: " .. tostring(result.Reason or "rejected")
				end
			elseif nextStandPrice <= money then
				reserveBlocked = true
			end
		end
	end
	if STATE.autoFence == true then
		selectedUpgrades += 1
		if not changed then
			local level = tonumber(data.FenceLevel) or 0
			local upgrade = FenceConfig.Get and FenceConfig.Get(level + 1) or (FenceConfig.Upgrades or {})[level + 1]
			local fencePrice = upgrade and (tonumber(upgrade.Price) or math.huge) or math.huge
			if not upgrade then
				maxedUpgrades += 1
			elseif fencePrice <= spendable then
				local result = invokeNear("Fence", fenceTarget(), "Plot_UpgradeFence")
				if result.Ok then
					stats.fences += 1
					changed = true
					STATE.upgradeStatus = "Fence upgraded"
					noteActivity(STATE.upgradeStatus)
					notify("progress", "Fence upgraded", "A new plot slot is available")
				else
					STATE.upgradeStatus = "Fence: " .. tostring(result.Reason or "rejected")
				end
			elseif fencePrice <= money then
				reserveBlocked = true
			end
		end
	end
	if not changed and STATE.upgradeStatus == "Checking upgrades" then
		if reserveBlocked then
			STATE.upgradeStatus = "Keeping " .. tostring(STATE.cashReserve) .. " cash reserve"
		elseif selectedUpgrades == 0 then
			STATE.upgradeStatus = "Automatic upgrades off"
		elseif maxedUpgrades == selectedUpgrades then
			STATE.upgradeStatus = "All selected upgrades maxed"
		else
			STATE.upgradeStatus = "Waiting for money or release"
		end
	end
end

local nextEquip = 0
function STATE.equipBestNow()
	local tokenName, busy = claimBusy("Equip")
	if not tokenName then
		STATE.equipStatus = "Waiting for " .. tostring(busy or "game")
		return false
	end
	local result = invoke("Plot_EquipBest")
	releaseBusy(tokenName)
	if result.Ok then
		local changed = (tonumber(result.Placed) or 0) + (tonumber(result.Removed) or 0)
		STATE.equipStatus = changed > 0 and ("Equipped " .. tostring(result.Count or result.Placed or changed)) or "Best already equipped"
		STATE.status = STATE.equipStatus
		noteActivity(STATE.equipStatus)
		if changed > 0 then
			notify("progress", "Best team equipped", STATE.equipStatus)
		end
		return true
	end
	STATE.equipStatus = "Equip: " .. tostring(result.Reason or "rejected")
	return false
end

local function animalIncome(entry)
	local ok, value = pcall(Mutations.IncomeOf, entry, LocalPlayer:GetAttribute("BestIncome") or 0)
	return ok and tonumber(value) or 0
end

local function listContains(list, value)
	return type(list) == "table" and type(value) == "string" and table.find(list, value) ~= nil
end

local function animalRarity(entry)
	if type(entry) ~= "table" or type(entry.ModelName) ~= "string" then
		return nil
	end
	local ok, info = pcall(AnimalEconomy.Get, entry.ModelName)
	return ok and type(info) == "table" and type(info.Rarity) == "string" and info.Rarity or nil
end

local function sellProtection(entry, id, keep)
	if entry.Placed then
		return "placed"
	end
	if keep[id] then
		return "best"
	end
	if entry.Mutation and listContains(STATE.protectedMutations, entry.Mutation) then
		return "mutation"
	end
	local rarity = animalRarity(entry)
	if not rarity or not listContains(STATE.sellRarities, rarity) then
		return "rarity"
	end
	return nil
end

local function buildSellPlan()
	local animals = getData("Animals")
	if type(animals) ~= "table" then
		return nil
	end
	local ranked = {}
	local backpackRanked = {}
	local summary = {
		total = 0,
		backpack = 0,
		placed = 0,
		protectedBest = 0,
		protectedMutation = 0,
		excludedRarity = 0,
		eligible = 0,
	}
	for id, entry in pairs(animals) do
		if type(entry) == "table" then
			summary.total += 1
			if entry.Placed then
				summary.placed += 1
			else
				summary.backpack += 1
			end
			local item = { id = id, entry = entry, income = animalIncome(entry) }
			table.insert(ranked, item)
			if not entry.Placed then
				table.insert(backpackRanked, item)
			end
		end
	end
	table.sort(ranked, function(a, b)
		return a.income > b.income
	end)
	table.sort(backpackRanked, function(a, b)
		return a.income > b.income
	end)
	local keep = {}
	for index = 1, math.min(math.max(0, STATE.keepBest), #backpackRanked) do
		keep[backpackRanked[index].id] = true
	end
	for _, item in ipairs(ranked) do
		local reason = sellProtection(item.entry, item.id, keep)
		if not reason then
			summary.eligible += 1
		elseif reason == "best" then
			summary.protectedBest += 1
		elseif reason == "mutation" then
			summary.protectedMutation += 1
		elseif reason == "rarity" then
			summary.excludedRarity += 1
		end
	end
	return ranked, keep, summary
end

-- Ranking every animal takes ~15 ms with a few thousand of them, and the
-- menu asks for this every second. Reuse the last answer until the animal
-- count or the sell filters change (or 30 seconds pass).
do
local sellPreviewCache = { key = nil, at = 0, summary = nil }
function STATE.sellPreview(fresh)
	local animals = getData("Animals")
	local count, placed = 0, 0
	if type(animals) == "table" then
		for _, entry in pairs(animals) do
			count += 1
			if type(entry) == "table" and entry.Placed then
				placed += 1
			end
		end
	end
	local key = table.concat({
		count, placed, tostring(STATE.keepBest),
		table.concat(STATE.sellRarities or {}, ","),
		table.concat(STATE.protectedMutations or {}, ","),
	}, "|")
	local now = os.clock()
	if fresh ~= true and sellPreviewCache.summary and sellPreviewCache.key == key and now - sellPreviewCache.at < 30 then
		return sellPreviewCache.summary
	end
	local _, _, summary = buildSellPlan()
	sellPreviewCache.key = key
	sellPreviewCache.at = now
	sellPreviewCache.summary = summary
	return summary
end
end

function STATE.sellRiskWarning()
	local highest = nil
	for _, rarity in ipairs(STATE.sellRarities or {}) do
		if (RARITY_RANK[rarity] or 0) >= (RARITY_RANK.Epic or 4) then
			highest = rarity
		end
	end
	return highest and ("Warning: " .. tostring(highest) .. " and other selected high rarities can be sold") or nil
end

local nextSellAt = 0
function STATE.sellJunkNow(force)
	local ranked, keep = buildSellPlan()
	if not ranked then
		STATE.sellStatus = "No animals"
		return 0
	end
	local tokenName, busy = claimBusy("Sell")
	if not tokenName then
		STATE.sellStatus = "Waiting for " .. tostring(busy or "game")
		return 0
	end
	local root, old = moveNear(sellTarget())
	if not root then
		releaseBusy(tokenName)
		STATE.sellStatus = "Sell circle unavailable"
		return 0
	end
	local sold = 0
	local rejected = nil
	for _, item in ipairs(ranked) do
		if not running() or (force ~= true and STATE.autoSell ~= true) then
			break
		end
		if not sellProtection(item.entry, item.id, keep) then
			local result = invoke("Plot_SellAnimal", item.id)
			if result.Ok then
				sold += 1
				stats.sold += 1
			elseif not rejected then
				rejected = tostring(result.Reason or "rejected")
			end
			task.wait(0.12)
		end
	end
	restorePosition(root, old)
	releaseBusy(tokenName)
	STATE.sellStatus = sold > 0 and ("Sold " .. sold .. " weak animals") or (rejected and ("Sell: " .. rejected) or "Nothing safe to sell")
	if sold > 0 then
		noteActivity(STATE.sellStatus)
		notify("sale", "Animals sold", STATE.sellStatus)
	end
	return sold
end

local nextReward = 0
local function stepRewards()
	if os.clock() < nextReward then return end
	nextReward = os.clock() + 5
	local data = readAll()
	local attempted = false
	if STATE.autoOffline == true and type(data.OfflinePending) == "table" and (tonumber(data.OfflinePending.Base) or 0) > 0 then
		attempted = true
		local result = invoke("Offline_Claim")
		if result.Ok then
			stats.rewards += 1
			STATE.rewardStatus = "Claimed offline earnings"
			noteActivity(STATE.rewardStatus)
			notify("progress", "Offline earnings claimed", "Your saved animal income was collected")
		else
			STATE.rewardStatus = "Offline reward: " .. tostring(result.Reason or "rejected")
		end
	end
	if STATE.autoFree == true and data.FreeAnimalClaimed ~= true then
		attempted = true
		local result = invoke("Shop_ClaimFree")
		if result.Ok then
			stats.rewards += 1
			STATE.rewardStatus = "Claimed free animal"
			noteActivity(STATE.rewardStatus)
			notify("progress", "Free animal claimed", "Check the catch notification for its details")
		elseif result.Reason then
			STATE.rewardStatus = "Free reward: " .. tostring(result.Reason)
		end
	end
	if not attempted then
		STATE.rewardStatus = (STATE.autoOffline == true or STATE.autoFree == true) and "No rewards ready" or "Off"
	end
end

-- Events and boosts: admin abuse boosts, Dreamland research and index trails.
local function clockText(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Admin boosts live in workspace attributes such as AdminLuck/AdminLuckEnd.
local function attributeBoost(name)
	local value = tonumber(workspace:GetAttribute(name)) or 1
	local ends = tonumber(workspace:GetAttribute(name .. "End")) or 0
	local now = workspace:GetServerTimeNow()
	if value > 1 and (ends <= 0 or ends > now) then
		return value, ends > 0 and (ends - now) or nil
	end
	return 1, nil
end

-- Personal timed boosts (Mr. Hush's shop) are player attributes.
local function personalBoost(kind)
	local ends = tonumber(LocalPlayer:GetAttribute("Timed" .. kind .. "End")) or 0
	local left = ends - workspace:GetServerTimeNow()
	if left > 0 then
		return 2, left
	end
	return 1, nil
end

local function trainingBoostActive()
	return attributeBoost("AdminTraining") > 1 or personalBoost("Training") > 1
end

local function boostText()
	local parts = {}
	local function add(label, value, left)
		if value > 1 then
			parts[#parts + 1] = string.format("%s %sx%s", label, shortNumber(value), left and (" (" .. clockText(left) .. ")") or "")
		end
	end
	add("Admin luck", attributeBoost("AdminLuck"))
	add("Server luck", attributeBoost("ServerLuck"))
	add("Admin money", attributeBoost("AdminMoney"))
	add("Admin training", attributeBoost("AdminTraining"))
	add("Cash boost", personalBoost("Cash"))
	add("Training boost", personalBoost("Training"))
	return #parts > 0 and table.concat(parts, " · ") or "No boosts active"
end

-- Ring Rush ------------------------------------------------------------------
-- An admin abuse live event (about 2 hours). While it runs, every throw turns
-- into a flight: the food flies down a lane and has to be steered through
-- rings, with cash, Lucky Throws and a Big Champion pet at ring milestones.
-- Auto Ring Rush lets the game run its own flight and steers it: the food
-- glides to the next ring no faster than the server's steering check allows
-- (80 studs a second), and imps can't knock it out (the server only judges
-- rings, never imps). The hooks change nothing while the option is off.
do
	local config = optionalRequire(ReplicatedStorage:FindFirstChild("Config"), "RingRushConfig")
	local folder = controllers:FindFirstChild("RingRush")
	local Steering = folder and optionalRequire(folder, "RingRushSteering")
	local CourseView = folder and optionalRequire(folder, "RingRushCourseView")
	elevate()
	local eventName = config and config.EventName or "RingRush"
	local endKey = "LiveEvent_" .. eventName
	local stageKey = "LiveEventStage_" .. eventName
	local runKey = config and config.RunKeyAttribute or "RingRushRunKey"
	local flightStages = config and config.FlightStages or { Arrival = true, Rush = true }
	local milestones = config and config.Milestones or {}
	local repeatReward = config and config.RepeatReward
	local GLIDE_SPEED = 60
	local ring = { view = nil, hooked = false, wasLive = false }
	STATE.ringRush = ring

	-- LiveEvent_RingRush holds the event's end time; the stage says whether
	-- throws are flights right now (Arrival and Rush) or the finale is on.
	function STATE.ringRushLive()
		if workspace:GetAttribute(endKey) == nil then
			return false
		end
		local stage = workspace:GetAttribute(stageKey)
		return type(stage) == "string" and flightStages[stage] == true
	end

	function STATE.ringRushRings()
		local ok, data = pcall(GameDataController.Get, GameDataController, "RingRush")
		elevate()
		if ok and type(data) == "table" and data.Key == workspace:GetAttribute(runKey) then
			return tonumber(data.Rings) or 0
		end
		return 0
	end

	local function rewardText(rings)
		for _, milestone in ipairs(milestones) do
			local need = tonumber(milestone.Rings) or 0
			if need > rings then
				return string.format("Next reward: %s at %d rings", tostring(milestone.Text or milestone.Kind), need)
			end
		end
		if type(repeatReward) == "table" then
			return string.format("All rewards done · %dm of cash every %d rings", tonumber(repeatReward.Minutes) or 1, tonumber(repeatReward.EveryRings) or 10)
		end
		return "All rewards done"
	end

	function STATE.ringRushText()
		local ends = workspace:GetAttribute(endKey)
		if ends == nil then
			return "Not live right now. It only runs during admin abuse (about 2 hours).\n" .. rewardText(0)
		end
		local stage = workspace:GetAttribute(stageKey)
		local left = type(ends) == "number" and (ends - workspace:GetServerTimeNow()) or nil
		local rings = STATE.ringRushRings()
		local lines = {
			string.format("LIVE%s%s", type(stage) == "string" and (" · " .. stage) or "", left and left > 0 and (" · " .. clockText(left) .. " left") or ""),
			string.format("%d rings this event · %s", rings, rewardText(rings)),
		}
		if STATE.autoRingRush ~= true then
			lines[#lines + 1] = "Auto Ring Rush is off, so Auto Throw waits. Play it yourself or turn it on."
		elseif not ring.hooked then
			lines[#lines + 1] = "Steering unavailable (game changed). Throws still run, steer yourself."
		elseif STATE.ringRushStatus then
			lines[#lines + 1] = tostring(STATE.ringRushStatus)
		end
		return table.concat(lines, "\n")
	end

	-- Called from the event loop: one heads-up when the event goes live.
	function STATE.stepRingRush()
		local live = workspace:GetAttribute(endKey) ~= nil
		if live and not ring.wasLive then
			noteActivity("Ring Rush is live")
			notify("progress", "Ring Rush is live!", STATE.autoRingRush == true and "Auto Ring Rush is playing it for you" or "Turn on Auto Ring Rush in the Admin Abuse tab")
		elseif not live and ring.wasLive then
			STATE.ringRushStatus = nil
			noteActivity("Ring Rush ended")
		end
		ring.wasLive = live
	end

	if type(Steering) == "table" and type(Steering.Step) == "function" and type(Steering.GetOffset) == "function"
		and type(CourseView) == "table" and type(CourseView.Update) == "function"
		and type(CourseView.GetCrossedMob) == "function" then
		local originalStep = Steering.Step
		local originalGetOffset = Steering.GetOffset
		local originalUpdate = CourseView.Update
		local originalCrossed = CourseView.GetCrossedMob
		local originalDestroy = CourseView.Destroy
		local glides = setmetatable({}, { __mode = "k" })

		-- The flight calls Update every frame with the next ring's number and
		-- the flight clock, before it steps the steering.
		CourseView.Update = function(self, ...)
			ring.view = self
			return originalUpdate(self, ...)
		end
		if type(originalDestroy) == "function" then
			CourseView.Destroy = function(self, ...)
				if ring.view == self then
					ring.view = nil
				end
				return originalDestroy(self, ...)
			end
		end
		Steering.Step = function(self, frame, ...)
			originalStep(self, frame, ...)
			local view = ring.view
			if STATE.autoRingRush == true and view and type(frame) == "table" then
				local entry = type(view.Rings) == "table" and view.Rings[view.NextIndex]
				local course = view.Course
				if entry and course and type(course.GetRingOffset) == "function" then
					local ok, target = pcall(course.GetRingOffset, course, entry.Ring, view.Time)
					if ok and typeof(target) == "Vector2" then
						local current = glides[self] or originalGetOffset(self)
						local reach = GLIDE_SPEED * math.clamp(tonumber(frame.DeltaTime) or 0, 0, 0.1)
						local gap = target - current
						glides[self] = gap.Magnitude <= reach and target or (current + gap.Unit * reach)
						return
					end
				end
			end
			glides[self] = nil
		end
		Steering.GetOffset = function(self, ...)
			local glide = STATE.autoRingRush == true and glides[self]
			if glide then
				return glide
			end
			return originalGetOffset(self, ...)
		end
		CourseView.GetCrossedMob = function(self, ...)
			local mob = originalCrossed(self, ...)
			if mob ~= nil and STATE.autoRingRush == true then
				return nil
			end
			return mob
		end
		ring.hooked = true
		hubCleanup(function()
			Steering.Step = originalStep
			Steering.GetOffset = originalGetOffset
			CourseView.Update = originalUpdate
			CourseView.GetCrossedMob = originalCrossed
			if type(originalDestroy) == "function" then
				CourseView.Destroy = originalDestroy
			end
			ring.view = nil
		end)
	end
end

local function syncThrowTrainToggles()
	if typeof(STATE.syncToggle) == "function" then
		pcall(STATE.syncToggle, "autoTrain")
		pcall(STATE.syncToggle, "autoThrow")
	end
end

-- During a training boost, swap Auto Throw for Auto Train and swap back when
-- the boost ends. Skipped at max level, where training gives nothing.
local function stepBoostTraining()
	-- Ring Rush only pays while throwing, so it wins over boost training.
	local ringPlay = STATE.autoRingRush == true and typeof(STATE.ringRushLive) == "function" and STATE.ringRushLive()
	local active = STATE.trainOnBoost == true and trainingBoostActive() and not atMaxLevel() and not ringPlay
	if not active then
		boostTraining.declined = false
	end
	if boostTraining.active then
		if active and STATE.autoTrain == true then
			return
		end
		-- Either the boost ended or the user switched training off themselves.
		local userStopped = active
		boostTraining.active = false
		if STATE.autoTrain == true then
			STATE.autoTrain = false
			stopTraining()
		end
		if userStopped then
			boostTraining.declined = true
		elseif boostTraining.resumeThrow then
			STATE.autoThrow = true
			notify("progress", "Training boost over", "Auto Throw resumed")
		end
		elevate()
		syncThrowTrainToggles()
		saveConfig()
		return
	end
	if active and not boostTraining.declined and STATE.autoTrain ~= true and STATE.autoThrow == true then
		boostTraining.active = true
		boostTraining.resumeThrow = true
		STATE.autoTrain = true
		STATE.autoThrow = false
		noteActivity("Training boost: training until it ends")
		notify("progress", "Training boost active", "Training until the boost ends, then Auto Throw resumes")
		elevate()
		syncThrowTrainToggles()
	end
end

-- Train & Throw cycle (mainly for new players): trains for a set time,
-- then throws for a set time, on repeat. Training is paused for training
-- boosts (which train anyway) and skipped at max level.
do
	local cycle = { phase = nil, endsAt = 0 }
	local function setPhase(phase)
		cycle.phase = phase
		local minutes = phase == "train" and STATE.cycleTrainMinutes or STATE.cycleThrowMinutes
		cycle.endsAt = os.clock() + math.max(1, tonumber(minutes) or 5) * 60
		if phase == "train" then
			STATE.autoThrow = false
			STATE.autoTrain = true
		else
			STATE.autoTrain = false
			stopTraining()
			STATE.autoThrow = true
		end
		elevate()
		syncThrowTrainToggles()
		noteActivity(phase == "train" and "Cycle: training" or "Cycle: throwing")
	end
	function STATE.stepCycle()
		if STATE.cycleTrain ~= true then
			if cycle.phase == "train" then
				-- Switched off mid-training: go back to throwing.
				STATE.autoTrain = false
				stopTraining()
				STATE.autoThrow = true
				elevate()
				syncThrowTrainToggles()
			end
			cycle.phase = nil
			STATE.cycleStatus = "Off"
			return
		end
		if atMaxLevel() then
			if cycle.phase ~= "throw" or STATE.autoThrow ~= true then
				setPhase("throw")
			end
			cycle.endsAt = math.huge
			STATE.cycleStatus = "Max level: training gives nothing, so it only throws"
			return
		end
		if boostTraining.active then
			STATE.cycleStatus = "Paused while a training boost lasts"
			return
		end
		if STATE.autoRingRush == true and typeof(STATE.ringRushLive) == "function" and STATE.ringRushLive() then
			-- Ring Rush only pays while throwing, so hold the throw turn.
			if cycle.phase ~= "throw" or STATE.autoThrow ~= true then
				setPhase("throw")
			end
			cycle.endsAt = math.max(tonumber(cycle.endsAt) or 0, os.clock() + 5)
			STATE.cycleStatus = "Paused while Ring Rush is live"
			return
		end
		if not cycle.phase then
			setPhase("train")
		elseif os.clock() >= cycle.endsAt then
			setPhase(cycle.phase == "train" and "throw" or "train")
		end
		STATE.cycleStatus = string.format("%s · %s next in %s",
			cycle.phase == "train" and "Training" or "Throwing",
			cycle.phase == "train" and "throwing" or "training",
			clockText(cycle.endsAt - os.clock()))
	end
	-- A new length applies from the next switch; restart so it shows now.
	function STATE.resetCycle()
		cycle.phase = nil
	end
	-- phase ("train"/"throw"), seconds left, seconds in this turn; nil when off.
	function STATE.cycleInfo()
		if STATE.cycleTrain ~= true or not cycle.phase or cycle.endsAt == math.huge then
			return nil
		end
		local minutes = cycle.phase == "train" and STATE.cycleTrainMinutes or STATE.cycleThrowMinutes
		return cycle.phase, math.max(0, cycle.endsAt - os.clock()), math.max(1, tonumber(minutes) or 5) * 60
	end

	-- Live timer on screen while the cycle runs: which turn it is, a
	-- countdown and a bar, so it is obvious it is working without the menu.
	-- Hidden under the AFK Black Screen, which shows the same countdown.
	local timerGui = nil
	local function destroyTimer()
		if timerGui then
			pcall(function()
				timerGui:Destroy()
			end)
			timerGui = nil
		end
	end
	hubCleanup(destroyTimer)
	local function buildTimer()
		local parent = (typeof(gethui) == "function" and gethui()) or CoreGui
		local look = STATE.hubThemeDef()
		local accent = look and typeof(look.accent) == "Color3" and look.accent or Color3.fromRGB(150, 110, 255)
		local gui = Instance.new("ScreenGui")
		gui.Name = "ZinoosCycleTimer"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local card = Instance.new("Frame")
		card.Name = "Card"
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, 52)
		card.Size = UDim2.fromOffset(230, 46)
		card.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
		card.BackgroundTransparency = 0.1
		card.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = accent
		stroke.Transparency = 0.4
		stroke.Parent = card
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(12, 5)
		title.Size = UDim2.new(1, -24, 0, 18)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Parent = card
		local time = Instance.new("TextLabel")
		time.Name = "Time"
		time.BackgroundTransparency = 1
		time.Position = UDim2.fromOffset(12, 5)
		time.Size = UDim2.new(1, -24, 0, 18)
		time.Font = Enum.Font.GothamBold
		time.TextSize = 14
		time.TextXAlignment = Enum.TextXAlignment.Right
		time.TextColor3 = accent
		time.Parent = card
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Position = UDim2.new(0, 12, 0, 30)
		track.Size = UDim2.new(1, -24, 0, 6)
		track.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
		track.BorderSizePixel = 0
		track.Parent = card
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = accent
		fill.BorderSizePixel = 0
		fill.Parent = track
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill
		gui.Parent = parent
		timerGui = gui
	end
	task.spawn(function()
		while running() do
			local phase, left, total = STATE.cycleInfo()
			if phase and STATE.disable3d ~= true then
				elevate()
				if not (timerGui and timerGui.Parent) then
					pcall(buildTimer)
				end
				local card = timerGui and timerGui:FindFirstChild("Card")
				if card then
					card.Title.Text = phase == "train" and "🏋️ TRAINING" or "🍔 THROWING"
					card.Time.Text = string.format("%s → %s", clockText(left), phase == "train" and "throw" or "train")
					card.Track.Fill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
				end
			elseif timerGui then
				elevate()
				destroyTimer()
			end
			task.wait(0.25)
		end
	end)
end

local nextDreamAction = 0
local lastDreamActive = nil
local dreamNote = nil
local function dreamInvoke(label, ...)
	-- Mr. Hush's stand closes his window beyond 22 studs, so act beside it
	-- when it exists in the world.
	local stand = workspace:FindFirstChild("DreamlandStand")
	if stand then
		return invokeNear(label, stand, "Dreamland_Action", ...)
	end
	return invoke("Dreamland_Action", ...)
end

local function stepDreamland()
	if not Dreamland or not DreamlandConfig then
		STATE.dreamStatus = "Dreamland is not in this game version"
		return
	end
	local state = dreamState() or {}
	local eligible = dreamEligible()
	local data = getData("Dreamland")
	data = type(data) == "table" and data or {}
	local okUnique, unique = pcall(Dreamland.UniqueCount, data.Caught)
	unique = okUnique and tonumber(unique) or 0
	local okAll, all = pcall(DreamlandConfig.AllAnimals)
	local total = okAll and type(all) == "table" and #all or 24
	local tokens = tonumber(data.Tokens) or 0
	elevate()

	local isActive = state.Active == true
	if isActive ~= lastDreamActive then
		if isActive and lastDreamActive ~= nil and eligible then
			notify("progress", "Dreamland run started", STATE.indexHunt == true
				and "Auto Collect is aiming at dream habitats with animals you still need"
				or "Dream habitats are open for 5 minutes")
		end
		lastDreamActive = isActive
	end

	if eligible and state.Open == true and os.clock() >= nextDreamAction then
		if STATE.collectClaim == true then
			local ok, list = pcall(Dreamland.ClaimableMilestones, data)
			if ok and type(list) == "table" and #list > 0 then
				nextDreamAction = os.clock() + 10
				if data.Talked ~= true then
					dreamInvoke("DreamTalk", "Talked")
				end
				for _, milestone in ipairs(list) do
					local result = dreamInvoke("DreamClaim", "Claim", milestone)
					elevate()
					if result.Ok then
						stats.rewards += 1
						local info = type(DreamlandConfig.Milestones) == "table" and DreamlandConfig.Milestones[milestone]
						dreamNote = "Claimed " .. tostring(info and info.Text or ("milestone " .. tostring(milestone)))
						noteActivity(dreamNote)
						notify("progress", "Research milestone claimed", tostring(info and info.Text or milestone))
					else
						-- The server can grant a milestone before our copy of the
						-- save shows it; that is not a problem worth reporting.
						local reason = tostring(result.Reason or "rejected")
						if reason ~= "NothingToClaim" and reason ~= "AlreadyClaimed" and reason ~= "Claimed" then
							dreamNote = "Milestone claim: " .. reason
						end
						break
					end
				end
			end
		end
		if STATE.dreamBuy == true and os.clock() >= nextDreamAction and type(DreamlandConfig.Shop) == "table" then
			for _, item in ipairs(DreamlandConfig.Shop) do
				local price = tonumber(item.Price) or math.huge
				local useful = item.Kind == "Boost" and not (item.Boost == "Training" and atMaxLevel())
				if useful and tokens >= price then
					local okLeft, left = pcall(Dreamland.StockLeft, data, item)
					if okLeft and (left == nil or left > 0) then
						nextDreamAction = os.clock() + 10
						local result = dreamInvoke("DreamShop", "Buy", item.Key)
						elevate()
						if result.Ok then
							tokens -= price
							dreamNote = "Bought " .. tostring(item.Name)
							noteActivity(dreamNote)
							notify("progress", "Research shop", "Bought " .. tostring(item.Name))
						else
							dreamNote = "Shop: " .. tostring(result.Reason or "rejected")
							break
						end
					end
				end
			end
		end
		-- Dream Potions: one per step, with whatever tokens the boosts left.
		if STATE.dreamPotionBuy == true and os.clock() >= nextDreamAction and type(DreamlandConfig.Shop) == "table" then
			local potion = nil
			for _, item in ipairs(DreamlandConfig.Shop) do
				if item.Kind == "Potion" then
					potion = item
				end
			end
			local price = potion and tonumber(potion.Price) or math.huge
			if potion and tokens >= price then
				nextDreamAction = os.clock() + 3
				local result = dreamInvoke("DreamShop", "Buy", potion.Key)
				elevate()
				if result.Ok then
					tokens -= price
					dreamNote = "Bought a " .. tostring(potion.Name)
					noteActivity(dreamNote)
				else
					dreamNote = "Potion shop: " .. tostring(result.Reason or "rejected")
					nextDreamAction = os.clock() + 30
				end
			end
		end
		-- Infusion: only with a full set of potions (100% success), on the
		-- strongest placed animal that is not Dream yet.
		local potions = tonumber(data.Potions) or 0
		local need = DreamlandConfig.Infusion and tonumber(DreamlandConfig.Infusion.MaxPotions) or 4
		if STATE.dreamInfuse == true and os.clock() >= nextDreamAction and potions >= need then
			local bestId, bestEntry, bestPlaced, bestIncome = nil, nil, false, -1
			local animals = getData("Animals")
			for id, entry in pairs(type(animals) == "table" and animals or {}) do
				if type(entry) == "table" and entry.ModelName and entry.Dream ~= true and entry.OfBest == nil then
					-- Placed animals earn, so they always come first.
					local placed = entry.Placed == true
					local income = animalIncome(entry)
					if (placed and not bestPlaced) or (placed == bestPlaced and income > bestIncome) then
						bestId, bestEntry, bestPlaced, bestIncome = id, entry, placed, income
					end
				end
			end
			elevate()
			if bestId then
				nextDreamAction = os.clock() + 8
				local name = describeCatch(bestEntry)
				local result = dreamInvoke("DreamInfuse", "Infuse", bestId, need)
				elevate()
				if result.Ok and result.Success ~= false then
					stats.rewards += 1
					dreamNote = "Infused " .. tostring(name) .. " · Dream x1.2 income"
					noteActivity(dreamNote)
					notify("progress", "Infusion successful", tostring(name) .. " is now Dream (x1.2 income)")
				elseif result.Ok then
					dreamNote = "Infusion failed on " .. tostring(name)
				else
					dreamNote = "Infusion: " .. tostring(result.Reason or "rejected")
					nextDreamAction = os.clock() + 30
				end
			end
		end
	end

	local now = workspace:GetServerTimeNow()
	local timing
	if state.Open ~= true then
		timing = state.OpensAt and ("Opens in " .. clockText(state.OpensAt - now)) or "Closed"
	elseif isActive then
		timing = "Dream run LIVE · " .. clockText((tonumber(state.RunEnd) or now) - now) .. " left"
	else
		timing = "Next dream run in " .. clockText((tonumber(state.NextStart) or now) - now)
	end
	STATE.dreamTiming = eligible and timing or "Locked for now"
	STATE.dreamLive = isActive and eligible
	local lines = {
		timing,
		string.format("%d/%d dream animals found · %s research tokens · %d Dream Potions", unique, total, shortNumber(tokens), tonumber(data.Potions) or 0),
	}
	if not eligible then
		lines[#lines + 1] = "Not unlocked for you yet; the game opens it after you have played a while"
	end
	if dreamNote then
		lines[#lines + 1] = dreamNote
	end
	STATE.dreamStatus = table.concat(lines, "\n")
end

local nextIndexAction = 0
local indexNote = nil
local function trailScore(trail)
	local bonus = type(trail) == "table" and type(trail.Bonus) == "table" and trail.Bonus or {}
	return (tonumber(bonus.Xp) or 0) + (tonumber(bonus.Cash) or 0)
end

local function stepIndexRewards()
	if not IndexRewards then
		STATE.indexStatus = "Index rewards are not in this game version"
		return
	end
	if os.clock() >= nextIndexAction then
		nextIndexAction = os.clock() + 15
		if STATE.collectClaim == true then
			local ok, claimable = pcall(IndexRewards.Claimable, readAll())
			elevate()
			for _, key in ipairs(ok and type(claimable) == "table" and claimable or {}) do
				local result = invoke("IndexRewards_Claim", key)
				if result.Ok then
					stats.rewards += 1
					local collection = IndexRewards.GetCollection(key)
					local trail = collection and IndexRewards.TrailOf(collection)
					indexNote = "Claimed " .. tostring(trail and trail.Name or key)
					noteActivity(indexNote)
					notify("progress", "Index reward claimed", tostring(trail and trail.Name or key))
				else
					indexNote = "Index claim: " .. tostring(result.Reason or "rejected")
					break
				end
			end
		end
		if STATE.autoTrail == true then
			local data = readAll()
			local owned = type(data.Trails) == "table" and type(data.Trails.Owned) == "table" and data.Trails.Owned or {}
			local bestKey, bestScore = nil, -1
			for key, has in pairs(owned) do
				local trail = has == true and IndexRewards.GetTrail(key)
				local score = trail and trailScore(trail) or -1
				if trail and (score > bestScore or (score == bestScore and tostring(key) < tostring(bestKey))) then
					bestKey, bestScore = key, score
				end
			end
			local okEquipped, equipped = pcall(IndexRewards.Equipped, data)
			if bestKey and (not okEquipped or equipped ~= bestKey) then
				local current = okEquipped and equipped and IndexRewards.GetTrail(equipped)
				if not current or trailScore(current) < bestScore then
					local result = invoke("IndexRewards_Equip", bestKey)
					local trail = IndexRewards.GetTrail(bestKey)
					indexNote = result.Ok and ("Equipped " .. tostring(trail and trail.Name or bestKey))
						or ("Trail equip: " .. tostring(result.Reason or "rejected"))
				end
			end
		end
	end
	local data = readAll()
	local ownedCount = 0
	if type(data.Trails) == "table" and type(data.Trails.Owned) == "table" then
		for _, has in pairs(data.Trails.Owned) do
			if has == true then
				ownedCount += 1
			end
		end
	end
	local okEquipped, equipped = pcall(IndexRewards.Equipped, data)
	local equippedTrail = okEquipped and equipped and IndexRewards.GetTrail(equipped)
	local closest = nil
	local okCollections, collections = pcall(IndexRewards.Collections)
	for _, collection in ipairs(okCollections and type(collections) == "table" and collections or {}) do
		local okProgress, found, total = pcall(IndexRewards.Progress, data.Index, collection)
		found, total = tonumber(found) or 0, tonumber(total) or 0
		local claimed = IndexRewards.IsClaimed(data, collection.Key)
		if okProgress and total > 0 and found < total and not claimed then
			if not closest or total - found < closest.total - closest.found then
				closest = { name = IndexRewards.Name(collection), found = found, total = total }
			end
		end
	end
	elevate()
	local lines = {
		string.format("%d trails owned · wearing %s", ownedCount, equippedTrail and tostring(equippedTrail.Name) or "none"),
		closest and string.format("Closest: %s %d/%d", tostring(closest.name), closest.found, closest.total) or "Every collection is complete",
	}
	if indexNote then
		lines[#lines + 1] = indexNote
	end
	STATE.indexStatus = table.concat(lines, "\n")
end

-- Collection page: keeps the list fresh, and turns Auto Collect off once
-- what it was working on is complete (when Stop When Complete is on).
function STATE.stepCollection()
	local rows = STATE.collectionRows()
	STATE.collectRows = rows
	if STATE.indexHunt == true and STATE.collectStop == true and STATE.collectComplete(rows) then
		STATE.indexHunt = false
		if STATE.syncToggle then
			STATE.syncToggle("indexHunt")
		end
		saveConfig()
		local what = STATE.collectTarget == "Auto" and "Your whole collection" or "That zone"
		noteActivity("Collection complete · Auto Collect turned off")
		notify("progress", "Collection complete", what .. " is finished. Auto Collect is off and throws go back to maximum distance")
	end
	-- Auto Collect switched off while not throwing: put the best food back.
	if STATE.indexHunt ~= true and STATE.autoThrow ~= true and STATE.collectFoodSwapped == true and not STATE.collectRestoring then
		STATE.collectRestoring = true
		task.spawn(function()
			pcall(STATE.collectRestoreFood)
			STATE.collectRestoring = false
		end)
	end
	local found = rows.worldFound + rows.dreamFound
	local total = rows.worldTotal + rows.dreamTotal
	local doing
	if STATE.indexHunt ~= true then
		doing = "Auto Collect is off"
	elseif STATE.autoThrow ~= true then
		doing = "Auto Collect is on · turn on Auto Throw to start"
	else
		doing = tostring(STATE.aimStatus)
	end
	STATE.collectStatus = string.format("%d / %d animals found\n%s", found, total, doing)
end

-- The zone list on the Collection page. WindUI has no progress bars, so the
-- list is drawn by hand inside a WindUI text box: one scrolling panel with a
-- World group and a Dreamland group, a bar per zone, and the zone Auto
-- Collect is aiming at picked out in the theme colour. Returns an update
-- function, or nil when the box cannot be found.
function STATE.buildCollectList(paragraph, title)
	elevate()
	local root = type(paragraph) == "table" and (paragraph.ElementFrame or (type(paragraph.UIElements) == "table" and paragraph.UIElements.Main)) or nil
	if typeof(root) ~= "Instance" then
		root = nil
		local guiRoot = typeof(gethui) == "function" and gethui() or CoreGui
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
	local inner = nil
	for _, child in ipairs(root and root:GetChildren() or {}) do
		if child:IsA("Frame") and child:FindFirstChildOfClass("UIListLayout") and child:FindFirstChild("TitleFrame") then
			inner = child
			break
		end
	end
	if not inner then
		return nil
	end
	local fontFace = nil
	for _, label in ipairs(inner:GetDescendants()) do
		if label:IsA("TextLabel") then
			fontFace = label.FontFace
			break
		end
	end
	local look = STATE.hubThemeDef()
	local accent = look.accent or Color3.fromRGB(130, 104, 255)
	local ink = look.ink or Color3.fromRGB(242, 236, 232)
	local done = Color3.fromRGB(88, 214, 141)

	local function text(parent, value, size, weight, align)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Text = value
		label.TextSize = size
		label.TextColor3 = ink
		label.TextXAlignment = align or Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextTruncate = Enum.TextTruncate.AtEnd
		if fontFace then
			label.FontFace = Font.new(fontFace.Family, weight or Enum.FontWeight.Medium)
		end
		label.Parent = parent
		return label
	end
	local function round(parent, radius)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius)
		corner.Parent = parent
	end

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "ZinoosCollectList"
	panel.LayoutOrder = 50
	panel.Size = UDim2.new(1, 0, 0, 330)
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BackgroundTransparency = 0.55
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 3
	panel.ScrollBarImageColor3 = accent
	panel.ScrollingDirection = Enum.ScrollingDirection.Y
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.new()
	round(panel, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Transparency = 0.8
	stroke.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 14)
	pad.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = panel

	local order = 0
	local function bar(parent, height)
		local track = Instance.new("Frame")
		track.BackgroundColor3 = ink
		track.BackgroundTransparency = 0.88
		track.BorderSizePixel = 0
		track.Size = UDim2.new(1, 0, 0, height)
		round(track, height)
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = accent
		fill.BorderSizePixel = 0
		fill.Size = UDim2.new(0, 0, 1, 0)
		round(fill, height)
		fill.Parent = track
		track.Parent = parent
		return track, fill
	end

	local function header(name)
		order += 1
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, 0, 0, order == 1 and 34 or 44)
		frame.Parent = panel
		local top = order == 1 and 0 or 10
		local label = text(frame, name, 12, Enum.FontWeight.Bold)
		label.Position = UDim2.new(0, 0, 0, top)
		label.Size = UDim2.new(0.5, 0, 0, 16)
		label.TextColor3 = accent
		local right = text(frame, "", 12, Enum.FontWeight.SemiBold, Enum.TextXAlignment.Right)
		right.Position = UDim2.new(0.4, 0, 0, top)
		right.Size = UDim2.new(0.6, 0, 0, 16)
		local track, fill = bar(frame, 4)
		track.Position = UDim2.new(0, 0, 0, top + 22)
		return { right = right, fill = fill }
	end

	local rowsById = {}
	local function row(id)
		order += 1
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, 0, 0, 34)
		frame.BackgroundColor3 = accent
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		round(frame, 8)
		frame.Parent = panel
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 6, 0, 6)
		dot.Position = UDim2.new(0, 6, 0, 9)
		dot.BorderSizePixel = 0
		round(dot, 3)
		dot.Parent = frame
		local name = text(frame, "", 13, Enum.FontWeight.Medium)
		name.Position = UDim2.new(0, 18, 0, 3)
		name.Size = UDim2.new(1, -90, 0, 18)
		local count = text(frame, "", 12, Enum.FontWeight.SemiBold, Enum.TextXAlignment.Right)
		count.Position = UDim2.new(1, -86, 0, 3)
		count.Size = UDim2.new(0, 80, 0, 18)
		local track, fill = bar(frame, 3)
		track.Position = UDim2.new(0, 18, 0, 25)
		track.Size = UDim2.new(1, -24, 0, 3)
		local entry = { frame = frame, dot = dot, name = name, count = count, fill = fill, track = track, last = nil }
		rowsById[id] = entry
		return entry
	end

	local worldHead, dreamHead = nil, nil
	local built = false
	local function build(rows)
		worldHead = header("WORLD INDEX")
		for _, item in ipairs(rows.world) do
			row(item.id)
		end
		dreamHead = header("DREAMLAND")
		for _, item in ipairs(rows.dream) do
			row(item.id)
		end
		built = true
	end

	local function setFill(fill, found, total)
		local share = total > 0 and math.clamp(found / total, 0, 1) or 0
		fill.Size = UDim2.new(share, 0, 1, 0)
		fill.Visible = share > 0
		fill.BackgroundColor3 = share >= 1 and done or accent
	end

	local function update(rows)
		if type(rows) ~= "table" or not panel.Parent then
			return
		end
		elevate()
		if not built then
			build(rows)
		end
		worldHead.right.Text = string.format("%d / %d", rows.worldFound, rows.worldTotal)
		setFill(worldHead.fill, rows.worldFound, rows.worldTotal)
		local dreamText = string.format("%d / %d", rows.dreamFound, rows.dreamTotal)
		dreamHead.right.Text = (STATE.dreamTiming and (tostring(STATE.dreamTiming) .. "  ·  ") or "") .. dreamText
		dreamHead.right.TextColor3 = STATE.dreamLive and accent or ink
		setFill(dreamHead.fill, rows.dreamFound, rows.dreamTotal)
		local aiming = STATE.indexHunt == true and STATE.collectAimId or nil
		for _, list in ipairs({ rows.world, rows.dream }) do
			for _, item in ipairs(list) do
				local entry = rowsById[item.id]
				if entry then
					local complete = item.found >= item.total
					local targeted = aiming == item.id
					local waiting = targeted and item.dream and STATE.dreamLive ~= true
					local key = string.format("%d/%d/%s/%s/%s/%s/%s", item.found, item.total, tostring(complete), tostring(targeted), tostring(item.reachable), tostring(item.claimed), tostring(waiting))
					if entry.last ~= key then
						entry.last = key
						entry.name.Text = item.name .. (waiting and "  ·  waiting for run" or (targeted and "  ·  collecting" or (not item.reachable and "  ·  out of reach" or "")))
						entry.name.TextColor3 = targeted and accent or ink
						entry.name.TextTransparency = (item.reachable or complete) and 0 or 0.5
						entry.count.Text = complete and ((item.claimed == false and not item.dream) and "Reward ready" or "Done") or string.format("%d / %d", item.found, item.total)
						entry.count.TextColor3 = complete and done or ink
						entry.count.TextTransparency = complete and 0 or 0.25
						entry.dot.BackgroundColor3 = complete and done or (targeted and accent or ink)
						entry.dot.BackgroundTransparency = (complete or targeted) and 0 or 0.75
						entry.frame.BackgroundTransparency = targeted and 0.86 or 1
						setFill(entry.fill, item.found, item.total)
					end
				end
			end
		end
	end

	panel.Parent = inner
	return update
end

local function stepEvents()
	pcall(stepBoostTraining)
	pcall(STATE.stepCycle)
	pcall(STATE.stepRingRush)
	STATE.boostStatus = boostText()
	pcall(stepDreamland)
	pcall(stepIndexRewards)
	pcall(STATE.stepCollection)
	elevate()
	-- Put the distance slider back once the hub is no longer throwing, so
	-- the HUD and the game's own throws use full power again.
	if aim.applied and (STATE.autoThrow ~= true or STATE.autoTrain == true) and ClientState.Busy == nil then
		pcall(STATE.restoreAim)
	end
end

function STATE.teleportTo(kind)
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local target
	if kind == "Shop" then
		target = foodShopTarget()
	elseif kind == "Training" then
		target = trainingTarget()
	elseif kind == "Sell" then
		target = sellTarget()
	elseif kind == "Throw" then
		throwPosition()
		return true
	end
	if target then
		local position = positionOf(target)
		if not position then return false end
		local destination = position + Vector3.new(0, 3, 0)
		root.CFrame = CFrame.lookAt(destination, destination + Vector3.new(0, 0, -10))
		root.AssemblyLinearVelocity = Vector3.zero
		return true
	end
	return false
end

-- Movement helpers.
trackConnection(UserInputService.JumpRequest:Connect(function()
	local hum = humanoid()
	if STATE.infiniteJump == true and hum and not seated() then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end))

local noclipParts = {}
trackConnection(RunService.Stepped:Connect(function()
	if STATE.noclip ~= true then
		if next(noclipParts) then
			for part, original in pairs(noclipParts) do
				if part.Parent then
					part.CanCollide = original
				end
			end
			table.clear(noclipParts)
		end
		return
	end
	local character = LocalPlayer.Character
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			if noclipParts[part] == nil then
				noclipParts[part] = part.CanCollide
			end
			part.CanCollide = false
		end
	end
end))

STATE.promptDurations = setmetatable({}, { __mode = "k" })
function STATE.applyInstantPrompts()
	if STATE.instantPrompts == true then
		for _, prompt in ipairs(workspace:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") then
				if STATE.promptDurations[prompt] == nil then
					STATE.promptDurations[prompt] = prompt.HoldDuration
				end
				prompt.HoldDuration = 0
			end
		end
		return
	end
	for prompt, duration in pairs(STATE.promptDurations) do
		if prompt.Parent then
			prompt.HoldDuration = duration
		end
	end
	table.clear(STATE.promptDurations)
end

trackConnection(ProximityPromptService.PromptShown:Connect(function(prompt)
	if STATE.instantPrompts == true then
		if STATE.promptDurations[prompt] == nil then
			STATE.promptDurations[prompt] = prompt.HoldDuration
		end
		prompt.HoldDuration = 0
	end
end))
hubCleanup(function()
	STATE.instantPrompts = false
	STATE.applyInstantPrompts()
end)

local flyMover = nil
local function stopFly()
	if flyMover then
		flyMover:Destroy()
		flyMover = nil
	end
	local hum = humanoid()
	if hum then
		hum.PlatformStand = false
	end
end
hubCleanup(stopFly)
trackConnection(RunService.RenderStepped:Connect(function()
	local hum = humanoid()
	local root = hum and hum.RootPart
	if STATE.fly ~= true or not root or seated() then
		if flyMover then
			stopFly()
		end
		return
	end
	if not flyMover or flyMover.Parent ~= root then
		stopFly()
		flyMover = Instance.new("BodyVelocity")
		flyMover.Name = "ZinoosFly"
		flyMover.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		flyMover.Parent = root
	end
	hum.PlatformStand = true
	local camera = workspace.CurrentCamera
	local look = camera and camera.CFrame or root.CFrame
	local move = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		move += look.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		move -= look.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		move += look.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		move -= look.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		move += Vector3.yAxis
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		move -= Vector3.yAxis
	end
	if hum.MoveDirection.Magnitude > 0 and move.Magnitude == 0 then
		move = hum.MoveDirection
	end
	flyMover.Velocity = move.Magnitude > 0 and move.Unit * STATE.flySpeed or Vector3.zero
end))

-- Client helpers.
STATE.pausePopupOriginal = nil
local function restorePausePopup()
	local saved = STATE.pausePopupOriginal
	STATE.pausePopupOriginal = nil
	if saved and saved.object and saved.object.Parent then
		pcall(function()
			saved.object[saved.property] = saved.value
		end)
	end
end

local function hidePausePopup()
	if STATE.noPausePopup ~= true then
		restorePausePopup()
		return
	end
	local robloxGui = CoreGui:FindFirstChild("RobloxGui")
	local pause = robloxGui and (robloxGui:FindFirstChild("NetworkPause", true) or robloxGui:FindFirstChild("CoreScripts/NetworkPause"))
	if pause then
		pcall(function()
			local property = pause:IsA("ScreenGui") and "Enabled" or "Visible"
			if not STATE.pausePopupOriginal or STATE.pausePopupOriginal.object ~= pause then
				restorePausePopup()
				STATE.pausePopupOriginal = { object = pause, property = property, value = pause[property] }
			end
			pause[property] = false
		end)
	end
end
hubCleanup(restorePausePopup)

pcall(function()
	trackConnection(GuiService.ErrorMessageChanged:Connect(function(message)
		if STATE.autoReconnect == true and type(message) == "string" and message ~= "" then
			task.wait(2)
			if STATE.autoReconnect == true then
				pcall(function()
					TeleportService:Teleport(game.PlaceId, LocalPlayer)
				end)
			end
		end
	end))
end)

-- AFK Black Screen: stops drawing the 3D world (big GPU and battery saving)
-- and covers the game with a black screen showing live progress, so a
-- phone or PC left overnight still shows what the hub is doing.
do
	local screen = nil
	local startedAt = os.clock()

	local function clock(seconds)
		seconds = math.max(0, math.floor(seconds))
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end

	local function destroyScreen()
		if screen then
			pcall(function()
				screen:Destroy()
			end)
			screen = nil
		end
	end

	local function buildScreen()
		elevate()
		local parent = (typeof(gethui) == "function" and gethui()) or CoreGui
		local look = STATE.hubThemeDef()
		local accent = look and typeof(look.accent) == "Color3" and look.accent or Color3.fromRGB(150, 110, 255)
		local gui = Instance.new("ScreenGui")
		gui.Name = "ZinoosAfkScreen"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		-- Under the hub menu, so the menu and its alerts still open on top.
		local wind = parent:FindFirstChild("WindUI")
		gui.DisplayOrder = (wind and wind:IsA("ScreenGui") and wind.DisplayOrder or 1000) - 1

		local back = Instance.new("Frame")
		back.Name = "Black"
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.new(0, 0, 0)
		back.BorderSizePixel = 0
		back.Active = true
		back.Parent = gui

		local box = Instance.new("Frame")
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.fromScale(0.5, 0.5)
		box.Size = UDim2.new(0.9, 0, 0, 300)
		box.BackgroundTransparency = 1
		box.Parent = back
		local cap = Instance.new("UISizeConstraint")
		cap.MaxSize = Vector2.new(520, 300)
		cap.Parent = box
		local layout = Instance.new("UIListLayout")
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = box

		local function label(order, size, color, bold)
			local text = Instance.new("TextLabel")
			text.LayoutOrder = order
			text.Size = UDim2.new(1, 0, 0, size + 6)
			text.BackgroundTransparency = 1
			text.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
			text.TextSize = size
			text.TextColor3 = color
			text.TextWrapped = true
			text.Text = ""
			text.Parent = box
			return text
		end
		local title = label(1, 30, accent, true)
		title.Text = "ZINOOS HUB"
		local sub = label(2, 13, Color3.fromRGB(150, 150, 160), true)
		sub.Text = "AFK MODE  ·  THE HUB IS STILL RUNNING"
		local index = label(3, 24, Color3.new(1, 1, 1), true)
		local doing = label(4, 15, Color3.fromRGB(210, 210, 220), false)
		doing.Size = UDim2.new(1, 0, 0, 40)
		local session = label(5, 14, Color3.fromRGB(170, 170, 180), false)
		local last = label(6, 14, Color3.fromRGB(170, 170, 180), false)

		local button = Instance.new("TextButton")
		button.LayoutOrder = 7
		button.Size = UDim2.new(0, 220, 0, 36)
		button.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamBold
		button.TextSize = 14
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Text = "Turn off black screen"
		button.Parent = box
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		button.MouseButton1Click:Connect(function()
			STATE.disable3d = false
			if STATE.syncToggle then
				STATE.syncToggle("disable3d")
			end
			STATE.apply3d()
			saveConfig()
		end)

		gui.Parent = parent
		screen = gui

		task.spawn(function()
			while running() and screen == gui and gui.Parent do
				local rows = STATE.collectRows
				local found = rows and (rows.worldFound + rows.dreamFound) or 0
				local total = rows and (rows.worldTotal + rows.dreamTotal) or 0
				local doingText = tostring(STATE.aimStatus or STATE.status or "")
				if STATE.cycleTrain == true and STATE.cycleInfo and STATE.cycleInfo() then
					doingText = "Train & Throw: " .. tostring(STATE.cycleStatus)
				elseif STATE.indexHunt ~= true then
					doingText = STATE.autoThrow == true and "Farming · Auto Throw on" or "Auto Throw is off"
				elseif STATE.autoThrow ~= true then
					doingText = "Auto Collect is on · Auto Throw is off"
				end
				local catch = STATE.lastCatch
				local catchText = catch and ("Last catch: " .. tostring(catch.title) .. " (" .. tostring(catch.rarity) .. ")") or "Last catch: waiting for the first one"
				local money = shortNumber(getData("Money"))
				elevate()
				-- The menu may be built after the black screen: stay under it.
				local windGui = gui.Parent and gui.Parent:FindFirstChild("WindUI")
				if windGui and windGui:IsA("ScreenGui") and gui.DisplayOrder ~= windGui.DisplayOrder - 1 then
					gui.DisplayOrder = windGui.DisplayOrder - 1
				end
				index.Text = total > 0 and string.format("Index %d / %d", found, total) or "Index loading..."
				doing.Text = doingText
				session.Text = string.format("Running %s  ·  %d catches  ·  $%s", clock(os.clock() - startedAt), tonumber(stats.catches) or 0, money)
				last.Text = catchText
				task.wait(1)
			end
		end)
	end

	function STATE.apply3d()
		local on = STATE.disable3d == true
		pcall(function()
			RunService:Set3dRenderingEnabled(not on)
		end)
		if on and not (screen and screen.Parent) then
			pcall(buildScreen)
		elseif not on then
			destroyScreen()
		end
	end
	hubCleanup(destroyScreen)
end
hubCleanup(function()
	pcall(function()
		RunService:Set3dRenderingEnabled(true)
	end)
end)

local graphicsBefore = nil
local potatoVisuals = setmetatable({}, { __mode = "k" })
local potatoEpoch = 0
local potatoChanged = 0

local function potatoSet(object, property, value)
	if not object or object:GetAttribute("ZinoosOwned") == true then
		return false
	end
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
	if STATE.fpsBoost ~= true or object:GetAttribute("ZinoosOwned") == true then
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
	if not terrain then
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
			graphicsBefore.terrain[property] = terrain[property]
		end
		terrain[property] = value
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
	if not terrain then
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

function STATE.applyFpsBoost()
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
		STATE.potatoStatus = "Applying Potato Mode..."
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
				if index % 500 == 0 then
					task.wait()
				end
			end
			STATE.potatoChangedCount = potatoChanged
			STATE.potatoStatus = string.format("Potato Mode active • %d properties reduced", potatoChanged)
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
		STATE.potatoStatus = "Potato Mode off"
		if STATE.hidePets == true and typeof(STATE.applyHidePets) == "function" then
			STATE.applyHidePets()
		end
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
	STATE.fpsBoost = false
	STATE.applyFpsBoost()
end)

local hiddenPetVisuals = {}
local hiddenPetRoots = {}

local function hidePetVisual(object)
	if object:GetAttribute("ZinoosOwned") == true then
		return
	end
	local saved = hiddenPetVisuals[object]
	if saved then
		if saved.kind == "part" then
			object.LocalTransparencyModifier = 1
			object.CastShadow = false
		elseif saved.kind == "transparency" then
			object.Transparency = 1
		elseif saved.kind == "enabled" then
			object.Enabled = false
		end
		return
	end
	if object:IsA("BasePart") then
		hiddenPetVisuals[object] = {
			kind = "part",
			localTransparency = object.LocalTransparencyModifier,
			castShadow = object.CastShadow,
		}
		object.LocalTransparencyModifier = 1
		object.CastShadow = false
	elseif object:IsA("Decal") or object:IsA("Texture") then
		hiddenPetVisuals[object] = { kind = "transparency", transparency = object.Transparency }
		object.Transparency = 1
	elseif object:IsA("ParticleEmitter")
		or object:IsA("Trail")
		or object:IsA("Beam")
		or object:IsA("Smoke")
		or object:IsA("Fire")
		or object:IsA("Sparkles")
		or object:IsA("Highlight")
		or object:IsA("BillboardGui")
		or object:IsA("SurfaceGui")
		or object:IsA("PointLight")
		or object:IsA("SpotLight")
		or object:IsA("SurfaceLight") then
		hiddenPetVisuals[object] = { kind = "enabled", enabled = object.Enabled }
		object.Enabled = false
	end
end

local function hidePetRoot(root)
	if STATE.hidePets ~= true or not root or not root:IsDescendantOf(workspace) then
		return
	end
	local current = root
	while current and current ~= workspace do
		if current.Name == "NewAnimalView" or string.sub(current.Name, 1, 14) == "ThrowSequence_" then
			return
		end
		current = current.Parent
	end
	hidePetVisual(root)
	for _, object in ipairs(root:GetDescendants()) do
		hidePetVisual(object)
	end
	if not hiddenPetRoots[root] then
		hiddenPetRoots[root] = root.DescendantAdded:Connect(function(object)
			if STATE.hidePets == true then
				hidePetVisual(object)
			end
		end)
	end
end

local function restorePetVisuals()
	for _, connection in pairs(hiddenPetRoots) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(hiddenPetRoots)
	for object, saved in pairs(hiddenPetVisuals) do
		pcall(function()
			if saved.kind == "part" then
				object.LocalTransparencyModifier = saved.localTransparency
				object.CastShadow = STATE.fpsBoost == true and false or saved.castShadow
			elseif saved.kind == "transparency" then
				object.Transparency = STATE.fpsBoost == true and 1 or saved.transparency
			elseif saved.kind == "enabled" then
				object.Enabled = STATE.fpsBoost == true and false or saved.enabled
			end
		end)
	end
	table.clear(hiddenPetVisuals)
end

function STATE.applyHidePets()
	if STATE.hidePets ~= true then
		restorePetVisuals()
		STATE.petVisibilityStatus = "Animal models visible"
		return
	end
	for _, tag in ipairs({ "PlotAnimal", "Animal" }) do
		for _, root in ipairs(CollectionService:GetTagged(tag)) do
			hidePetRoot(root)
		end
	end
	STATE.petVisibilityStatus = "Animal models hidden locally"
end

local function hideNewPet(root)
	task.spawn(function()
		for _ = 1, 20 do
			if not running() or STATE.hidePets ~= true then
				return
			end
			if root:IsDescendantOf(workspace) then
				hidePetRoot(root)
				return
			end
			task.wait(0.1)
		end
	end)
end

trackConnection(CollectionService:GetInstanceAddedSignal("PlotAnimal"):Connect(hideNewPet))
trackConnection(CollectionService:GetInstanceAddedSignal("Animal"):Connect(hideNewPet))
hubCleanup(function()
	STATE.hidePets = false
	restorePetVisuals()
	STATE.fpsBoost = false
	STATE.applyFpsBoost()
end)

-- Lightweight animal ESP. It reads the game's confirmed PlotAnimal attributes and
-- keeps its own UI under CoreGui so Hide Animal Models can stay enabled.
local ESP_COLORS = {
	Common = Color3.fromRGB(190, 198, 210),
	Uncommon = Color3.fromRGB(95, 220, 130),
	Rare = Color3.fromRGB(70, 155, 255),
	Epic = Color3.fromRGB(180, 95, 255),
	Legendary = Color3.fromRGB(255, 185, 60),
	Mythic = Color3.fromRGB(255, 80, 135),
	Secret = Color3.fromRGB(255, 245, 150),
	Divine = Color3.fromRGB(255, 255, 255),
	Celestial = Color3.fromRGB(90, 235, 255),
	Eternal = Color3.fromRGB(255, 105, 225),
	Cosmic = Color3.fromRGB(125, 105, 255),
	Supreme = Color3.fromRGB(255, 80, 80),
	Sovereign = Color3.fromRGB(246, 190, 58),
}
-- Any rarity added after this list uses the game's own rarity colour.
for _, rarity in ipairs(RARITY_OPTIONS) do
	if not ESP_COLORS[rarity] and RarityConfig and type(RarityConfig.ByName) == "table" then
		local entry = RarityConfig.ByName[rarity]
		if type(entry) == "table" and typeof(entry.Color) == "Color3" then
			ESP_COLORS[rarity] = entry.Color
		end
	end
end
local espFolder = Instance.new("Folder")
espFolder.Name = "ZinoosThrowFoodESP"
elevate()
espFolder.Parent = CoreGui
local espEntries = {}

local function clearEspEntry(root)
	local entry = espEntries[root]
	if not entry then
		return
	end
	for _, object in ipairs({ entry.billboard, entry.highlight }) do
		if object then
			pcall(function()
				object:Destroy()
			end)
		end
	end
	espEntries[root] = nil
end

local function clearEsp()
	for root in pairs(espEntries) do
		clearEspEntry(root)
	end
	STATE.espStatus = "ESP off"
end

local function espLimit()
	if STATE.espMaxDistance == "Unlimited" then
		return math.huge
	end
	return tonumber(STATE.espMaxDistance) or 500
end

local function espAllowed(root, distance)
	if STATE.espEnabled ~= true or not root or not root:IsDescendantOf(workspace) then
		return false
	end
	local rarity = root:GetAttribute("Rarity") or "Common"
	if not listContains(STATE.espRarities, rarity) then
		return false
	end
	if STATE.espOwnOnly == true and root:GetAttribute("OwnerUserId") ~= LocalPlayer.UserId then
		return false
	end
	return distance <= espLimit()
end

local function ensureEspEntry(root, adornee)
	local entry = espEntries[root]
	if entry and entry.adornee == adornee and entry.billboard.Parent then
		return entry
	end
	clearEspEntry(root)
	elevate()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZinoosAnimalESP"
	billboard:SetAttribute("ZinoosOwned", true)
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(210, 54)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	billboard.Parent = espFolder

	local text = Instance.new("TextLabel")
	text.Name = "Details"
	text.BackgroundColor3 = Color3.fromRGB(8, 11, 17)
	text.BackgroundTransparency = 0.2
	text.BorderSizePixel = 0
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 13
	text.TextWrapped = true
	text.TextStrokeColor3 = Color3.new(0, 0, 0)
	text.TextStrokeTransparency = 0.35
	text.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 0.2
	stroke.Parent = text

	local highlight = Instance.new("Highlight")
	highlight.Name = "ZinoosAnimalESP"
	highlight:SetAttribute("ZinoosOwned", true)
	highlight.Adornee = root
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillTransparency = 0.88
	highlight.OutlineTransparency = 0.08
	highlight.Parent = espFolder

	entry = {
		adornee = adornee,
		billboard = billboard,
		label = text,
		stroke = stroke,
		highlight = highlight,
	}
	espEntries[root] = entry
	return entry
end

function STATE.refreshEsp()
	if STATE.espEnabled ~= true then
		clearEsp()
		return 0
	end
	local playerRoot = rootPart()
	local candidates = {}
	local bestByPlot = {}
	for _, root in ipairs(CollectionService:GetTagged("PlotAnimal")) do
		if root:IsDescendantOf(workspace) then
			local adornee = root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true)
			local position = adornee and adornee.Position
			local distance = playerRoot and position and (playerRoot.Position - position).Magnitude or 0
			if adornee and espAllowed(root, distance) then
				local candidate = {
					root = root,
					adornee = adornee,
					distance = distance,
					income = tonumber(root:GetAttribute("Income")) or 0,
				}
				if STATE.espAllAnimals == true then
					table.insert(candidates, candidate)
				else
					local plotKey = tostring(root:GetAttribute("OwnerUserId") or 0) .. ":" .. tostring(root:GetAttribute("PlotIndex") or "?")
					local current = bestByPlot[plotKey]
					if not current or candidate.income > current.income then
						bestByPlot[plotKey] = candidate
					end
				end
			end
		end
	end
	if STATE.espAllAnimals ~= true then
		for _, candidate in pairs(bestByPlot) do
			table.insert(candidates, candidate)
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)

	local seen = {}
	local visible = 0
	for _, candidate in ipairs(candidates) do
		local root = candidate.root
		local adornee = candidate.adornee
		local distance = candidate.distance
		if root:IsDescendantOf(workspace) and adornee.Parent then
				seen[root] = true
				visible += 1
				local rarity = root:GetAttribute("Rarity") or "Common"
				local color = ESP_COLORS[rarity] or Color3.new(1, 1, 1)
				local displayName = root:GetAttribute("DisplayName") or root:GetAttribute("AnimalName") or root.Name
				local mutation = root:GetAttribute("Mutation")
				local income = candidate.income
				local ownerId = tonumber(root:GetAttribute("OwnerUserId")) or 0
				local owner = ownerId == LocalPlayer.UserId and "You" or ((Players:GetPlayerByUserId(ownerId) or {}).DisplayName or "Other plot")
				local entry = ensureEspEntry(root, adornee)
				elevate()
				entry.label.Text = string.format("%s%s  [%s]\n$%s/s  •  %dm  •  %s", mutation and (mutation .. " ") or "", tostring(displayName), tostring(rarity), shortNumber(income), math.floor(distance + 0.5), tostring(owner))
				entry.label.TextColor3 = color
				entry.stroke.Color = color
				entry.highlight.FillColor = color
				entry.highlight.OutlineColor = color
				local ok, size = pcall(root.GetExtentsSize, root)
				entry.billboard.StudsOffsetWorldSpace = Vector3.new(0, ok and math.clamp(size.Y * 0.6 + 1.5, 3, 14) or 4, 0)
		end
	end
	for root in pairs(espEntries) do
		if not seen[root] then
			clearEspEntry(root)
		end
	end
	STATE.espStatus = STATE.espAllAnimals == true
		and string.format("ESP showing %d animals", visible)
		or string.format("ESP showing %d strongest plot animals", visible)
	return visible
end

hubCleanup(function()
	clearEsp()
	pcall(function()
		espFolder:Destroy()
	end)
end)

-- Server helpers.
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

function STATE.copyJobId()
	if typeof(setclipboard) == "function" then
		pcall(setclipboard, game.JobId)
		return true
	end
	return false
end

trackConnection(LocalPlayer.Idled:Connect(function()
	pulseAntiAfk()
end))

-- The dashboard is built with WindUI (pinned release, so an upstream update
-- can never break the hub). WindUI scales itself to the screen and shows a
-- draggable open button on phones; PC players use the toggle key.
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
	destroyMenus()
	STATE.themeSwitches = {}
	STATE.uiStatusLabels = {}

	local WindUI, loadError = loadWindUI()
	if not WindUI then
		-- Farming keeps running with the saved settings even without a menu.
		warn("[Zinoos hub] Menu could not load (" .. tostring(loadError) .. "). Automation is still running with your saved settings.")
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Zinoos Hub",
				Text = "Menu could not load. Farming still runs with your saved settings.",
				Duration = 8,
			})
		end)
		return
	end
	STATE.windUI = WindUI
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
		Icon = "sparkles",
		Author = "Throw Food For Animals",
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
	STATE.windWindow = Window

	-- WindUI shrinks the window once so it fits the screen. Menu Size scales
	-- from that fit, and never grows past the screen on a phone. Every tab
	-- remembers the scale it was built at and sizes its boxes with it, so the
	-- scale must be final BEFORE any tab exists; a later change rebuilds the
	-- menu (see rebuildMenu) instead of leaving every box too short.
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
	pcall(Window.Tag, Window, { Title = "v" .. tostring(STATE.version), Color = Color3.fromHex("#8268FF") })
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
		-- Full unload: also remove WindUI's notification, dropdown and
		-- tooltip layers.
		for _, name in ipairs({ "ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui" }) do
			local layer = WindUI[name]
			if typeof(layer) == "Instance" then
				pcall(layer.Destroy, layer)
			end
		end
		STATE.toast = nil
		STATE.syncToggle = nil
	end)

	-- Throw this window away and build a fresh one (used when the menu size
	-- changes). The hub keeps running; only the menu is replaced.
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
		-- The close button asks first, then removes the window: treat that as
		-- unloading the hub so nothing keeps running invisibly.
		if not windowGone then
			windowGone = true
			if running() then
				task.defer(unloadHub)
			end
		end
	end)

	-- Notifications --------------------------------------------------------
	local TOAST_ICONS = { catch = "paw-print", sale = "badge-dollar-sign", progress = "trending-up", system = "info" }
	local lastToastKey, lastToastAt = nil, 0
	STATE.toast = function(entry)
		local key = tostring(entry.title) .. "\0" .. tostring(entry.message)
		if key == lastToastKey and os.clock() - lastToastAt < 1.5 then
			return true
		end
		lastToastKey, lastToastAt = key, os.clock()
		-- Rendering must never hold up the farming loops.
		task.spawn(function()
			elevate()
			pcall(WindUI.Notify, WindUI, {
				Title = tostring(entry.title),
				Content = tostring(entry.message),
				Icon = TOAST_ICONS[entry.category] or "bell",
				Duration = 4.5,
			})
		end)
		return true
	end

	-- Control helpers ------------------------------------------------------
	local syncToggle
	local dropdowns = {}

	local function onToggle(key, on)
		STATE[key] = on
		if key == "autoThrow" and on then
			STATE.autoTrain = false
			task.spawn(stopTraining)
			if syncToggle then syncToggle("autoTrain") end
		elseif key == "autoTrain" and on then
			STATE.autoThrow = false
			if syncToggle then syncToggle("autoThrow") end
		elseif key == "indexHunt" and on and STATE.autoThrow ~= true then
			-- Auto Collect only chooses where throws land; it needs Auto Throw
			-- to actually throw.
			STATE.autoThrow = true
			STATE.autoTrain = false
			task.spawn(stopTraining)
			if syncToggle then
				syncToggle("autoThrow")
				syncToggle("autoTrain")
			end
			task.defer(notify, "system", "Auto Throw turned on", "Auto Collect needs it to throw")
		elseif key == "antiAfk" and on and pulseAntiAfk then
			task.defer(pulseAntiAfk)
		elseif key == "disable3d" then
			STATE.apply3d()
		elseif key == "autoSkip" then
			lastSkip = nil
			task.spawn(syncAutoSkip)
			task.defer(notify, "system", on and "Catch animation skipped" or "Catch animation enabled", on and "Auto Throw will use the fast catch path" or "Auto Throw will show the full game reveal")
		elseif key == "autoSuper" then
			shouldUseSuperThrow()
		elseif key == "fpsBoost" then
			STATE.applyFpsBoost()
		elseif key == "hidePets" then
			STATE.applyHidePets()
		elseif key == "instantPrompts" then
			STATE.applyInstantPrompts()
		elseif key == "noPausePopup" then
			hidePausePopup()
		elseif key == "espEnabled" or key == "espOwnOnly" or key == "espAllAnimals" then
			task.defer(STATE.refreshEsp)
		elseif key == "notifications" and on then
			task.defer(notify, "system", "Notifications enabled", "Catches, sales and progress will appear here")
		elseif key == "autoTrain" and not on then
			task.spawn(stopTraining)
		elseif key == "autoSell" then
			nextSellAt = 0
			if not on then
				STATE.sellStatus = "Off"
			else
				local warning = STATE.sellRiskWarning()
				if warning then
					task.defer(notify, "system", "Review Auto Sell filters", warning)
				end
			end
		elseif key == "equipBest" and on then
			task.spawn(STATE.equipBestNow)
		elseif key == "walkSpeed" and not on then
			local hum = humanoid()
			if hum then
				hum.WalkSpeed = 16
			end
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
		local control = STATE.toggleControls[key]
		if type(control) ~= "table" then
			control = {}
			STATE.toggleControls[key] = control
		end
		control.value = STATE[key] == true
		control.element = element
		return element
	end

	syncToggle = function(key)
		local control = STATE.toggleControls[key]
		if type(control) ~= "table" then
			return
		end
		local value = STATE[key] == true
		control.value = value
		local element = control.element
		if element and element.Value ~= value then
			elevate()
			-- Second argument false: move the switch without re-running it.
			pcall(element.Set, element, value, false)
		end
	end
	STATE.syncToggle = syncToggle

	local function optionName(value)
		if type(value) == "table" then
			return value.Title or value.Name
		end
		return value
	end

	local function choice(parent, title, desc, options, getValue, setValue)
		local element = parent:Dropdown({
			Title = title,
			Desc = desc,
			Values = options,
			Value = getValue(),
			Callback = function(value)
				value = optionName(value)
				if type(value) ~= "string" or value == getValue() then
					return
				end
				elevate()
				setValue(value)
				saveConfig()
			end,
		})
		table.insert(dropdowns, { element = element, get = getValue })
		return element
	end

	local function multiChoice(parent, title, desc, options, key, after)
		local element = parent:Dropdown({
			Title = title,
			Desc = desc,
			Values = options,
			Value = table.clone(type(STATE[key]) == "table" and STATE[key] or {}),
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
				local current = type(STATE[key]) == "table" and STATE[key] or {}
				if #ordered == #current then
					local same = true
					for index, value in ipairs(ordered) do
						if current[index] ~= value then
							same = false
							break
						end
					end
					if same then
						return
					end
				end
				elevate()
				STATE[key] = ordered
				saveConfig()
				if after then
					after(ordered)
				end
			end,
		})
		table.insert(dropdowns, {
			element = element,
			get = function()
				return table.clone(type(STATE[key]) == "table" and STATE[key] or {})
			end,
		})
		return element
	end

	local function refreshDropdowns()
		for _, entry in ipairs(dropdowns) do
			elevate()
			pcall(entry.element.Select, entry.element, entry.get())
		end
	end

	-- WindUI measures a box's height when it opens and never again, so a box
	-- whose text grows would cut its last rows off. Re-measure open boxes
	-- after the menu is built and whenever their text changes.
	local sections = {}
	local paragraphSection = {}
	local pendingReflow = {}
	-- A box on a tab that is not showing measures as zero high, so only ever
	-- re-measure boxes that are actually on screen.
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
				local ok, err = pcall(callback)
				if not ok then
					notify("system", title .. " failed", tostring(err))
				end
			end,
		})
	end

	local function section(tab, title, icon)
		-- Every box starts open so nothing is hidden; players can fold any
		-- box away with its arrow.
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

	local function applyPreset(values, name)
		for key, value in pairs(values) do
			STATE[key] = value
			syncToggle(key)
		end
		if STATE.autoTrain ~= true then
			task.spawn(stopTraining)
		end
		nextSellAt = 0
		saveConfig()
		STATE.status = name .. " preset active"
		noteActivity(STATE.status)
		notify("system", name .. " enabled", "You can still change every option afterwards")
	end

	-- Tabs -----------------------------------------------------------------
	local homeTab = Window:Tab({ Title = "Home", Icon = "house" })
	local farmTab = Window:Tab({ Title = "Farming", Icon = "target" })
	local abuseTab = Window:Tab({ Title = "Admin Abuse", Icon = "crown" })
	local collectTab = Window:Tab({ Title = "Collection", Icon = "library" })
	local animalTab = Window:Tab({ Title = "Animals", Icon = "paw-print" })
	local progressTab = Window:Tab({ Title = "Progress", Icon = "trending-up" })
	local playerTab = Window:Tab({ Title = "Player", Icon = "user" })
	local settingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
	elevate()

	-- Home -----------------------------------------------------------------
	local overview = info(homeTab, "Overview", "Loading your stats...")
	button(homeTab, "Start / Stop Farming", "Turns Auto Throw on or off", "power", function()
		local on = STATE.autoThrow ~= true
		onToggle("autoThrow", on)
		syncToggle("autoThrow")
		notify("system", on and "Farming started" or "Farming stopped", on and "Auto Throw is on" or "Auto Throw is off")
	end)
	do
		local quick = section(homeTab, "Quick Start", "zap", false)
		button(quick, "Safe AFK", "Throws, upgrades and claims rewards. Never sells", "shield-check", function()
			applyPreset({
				autoThrow = true, perfectMeter = true, autoSkip = true, autoSuper = false,
				autoTrain = false, autoTapBonus = true, autoFood = true, autoStand = true,
				autoFence = true, equipBest = true, autoSell = false,
				autoOffline = true, autoFree = true,
			}, "Safe AFK")
		end)
		button(quick, "Fast Progress", "Same as Safe AFK and also spends Super Throws. Never sells", "rocket", function()
			applyPreset({
				autoThrow = true, perfectMeter = true, autoSkip = true, autoSuper = true,
				autoTrain = false, autoTapBonus = true, autoFood = true, autoStand = true,
				autoFence = true, equipBest = true, autoSell = false,
				autoOffline = true, autoFree = true,
			}, "Fast Progress")
		end)
		button(quick, "Stop Automation", "Turns every farming option off", "octagon-x", function()
			applyPreset({
				autoThrow = false, autoTrain = false, autoFood = false, autoStand = false,
				autoFence = false, equipBest = false, autoSell = false,
				autoOffline = false, autoFree = false,
			}, "Stopped")
		end)
	end
	local sessionInfo = info(homeTab, "This Session", "No new animals caught yet.")
	local historyInfo = info(homeTab, "Recent Catches", "No new animals caught yet.")
	local activityInfo = info(homeTab, "Activity", "Waiting for the next thing the hub does.")

	-- Farming --------------------------------------------------------------
	local throwInfo, superInfo, trainInfo, boostInfo, aimInfo, ringInfo
	-- Admin Abuse ----------------------------------------------------------
	do
		local ringBox = section(abuseTab, "Ring Rush", "orbit")
		toggle(ringBox, "Auto Ring Rush", "autoRingRush", "When Ring Rush is live: throws, steers through every ring and gets past the imps. Works even with Auto Throw off")
		ringInfo = info(ringBox, "Ring Rush", tostring(STATE.ringRushText and STATE.ringRushText() or "Checking Ring Rush..."))
		local liveBox = section(abuseTab, "Live Boosts", "sparkles")
		toggle(liveBox, "Train During Training Boosts", "trainOnBoost", "Trains while a training boost lasts. Skipped at max level and during Ring Rush")
		boostInfo = info(liveBox, "Boosts", tostring(STATE.boostStatus))
	end
	do
		local throwBox = section(farmTab, "Throwing", "target")
		toggle(throwBox, "Auto Throw", "autoThrow", "Throws and catches on repeat")
		toggle(throwBox, "Always Land Maximum Throws (+20)", "perfectMeter")
		toggle(throwBox, "Skip Catch Animation", "autoSkip", "Starts the next throw sooner")
		toggle(throwBox, "Use Super Throws Automatically", "autoSuper")
		choice(throwBox, "Super Throw Reserve", "Never spends your last few Super Throws", SUPER_RESERVE_OPTIONS, function()
			return STATE.superThrowReserve > 0 and ("Keep " .. tostring(STATE.superThrowReserve)) or "Use all"
		end, function(option)
			STATE.superThrowReserve = tonumber(option:match("%d+")) or 0
		end)
		throwInfo = info(throwBox, "Status", tostring(STATE.throwStatus))
		superInfo = info(throwBox, "Super Throw", tostring(STATE.superThrowStatus))

		local aimBox = section(farmTab, "Aiming", "crosshair")
		aimInfo = info(aimBox, "Aim", tostring(STATE.aimStatus))

		local trainBox = section(farmTab, "Training", "dumbbell", false)
		toggle(trainBox, "Train & Throw Cycle", "cycleTrain", "Trains, then throws, on repeat. Great for new players. Skipped at max level")
		do
			local lengths = { "1 minute", "2 minutes", "3 minutes", "5 minutes", "10 minutes", "15 minutes", "20 minutes", "30 minutes" }
			local function label(minutes)
				minutes = tonumber(minutes) or 5
				return tostring(minutes) .. (minutes == 1 and " minute" or " minutes")
			end
			choice(trainBox, "Train For", "How long each training turn lasts", lengths, function()
				return label(STATE.cycleTrainMinutes)
			end, function(option)
				STATE.cycleTrainMinutes = tonumber(option:match("%d+")) or STATE.cycleTrainMinutes
				STATE.resetCycle()
			end)
			choice(trainBox, "Throw For", "How long each throwing turn lasts", lengths, function()
				return label(STATE.cycleThrowMinutes)
			end, function(option)
				STATE.cycleThrowMinutes = tonumber(option:match("%d+")) or STATE.cycleThrowMinutes
				STATE.resetCycle()
			end)
		end
		toggle(trainBox, "Auto Train Throw Power", "autoTrain", "Pauses Auto Throw while training")
		toggle(trainBox, "Claim Training Bonuses", "autoTapBonus")
		toggle(trainBox, "Stop at Target Power", "trainToTarget")
		choice(trainBox, "Target Throw Power", nil, TRAIN_TARGET_OPTIONS, function()
			return STATE.trainTargetPower
		end, function(option)
			STATE.trainTargetPower = option
		end)
		toggle(trainBox, "Resume Auto Throw After Target", "resumeThrowAfterTraining")
		trainInfo = info(trainBox, "Status", tostring(STATE.trainingStatus))

		local stopBox = section(farmTab, "Stop On Target Catch", "flag", false)
		toggle(stopBox, "Stop on Minimum Rarity", "stopOnRarity")
		choice(stopBox, "Minimum Target Rarity", "Also stops for every higher rarity", RARITY_OPTIONS, function()
			return STATE.stopTargetRarity
		end, function(option)
			STATE.stopTargetRarity = option
		end)
		toggle(stopBox, "Stop on Selected Mutations", "stopOnMutation")
		multiChoice(stopBox, "Mutations That Stop Farming", nil, MUTATION_OPTIONS, "stopTargetMutations")
	end

	-- Collection -----------------------------------------------------------
	-- One page for the world index and the Dreamland collection.
	local collectInfo, collectUpdate
	do
		local box = section(collectTab, "Collection", "library")
		toggle(box, "Auto Collect", "indexHunt", "Aims your throws at zones where you're still missing animals")
		local firstRows = STATE.collectionRows()
		STATE.collectRows = firstRows
		local targetIds, targetNames = { "Auto" }, { "Auto" }
		for _, item in ipairs(firstRows.world) do
			table.insert(targetIds, item.id)
			table.insert(targetNames, item.name)
		end
		for _, item in ipairs(firstRows.dream) do
			table.insert(targetIds, item.id)
			table.insert(targetNames, "Dreamland · " .. item.name)
		end
		if not table.find(targetIds, STATE.collectTarget) then
			STATE.collectTarget = "Auto"
		end
		choice(box, "Target Zone", "Auto picks whatever you're missing, or choose one zone", targetNames, function()
			return targetNames[table.find(targetIds, STATE.collectTarget) or 1]
		end, function(option)
			local at = table.find(targetNames, option)
			STATE.collectTarget = at and targetIds[at] or "Auto"
			task.defer(STATE.stepCollection)
		end)
		toggle(box, "Use Lucky Throws While Collecting", "collectSuper", "Off: lucky throws are saved for normal farming. On: spent only on a zone's rarest animals")
		toggle(box, "Auto Claim Rewards", "collectClaim", "Zone trails and Dreamland research milestones")
		toggle(box, "Stop When Complete", "collectStop", "Turns Auto Collect off once it's finished")
		collectInfo = info(box, "Progress", tostring(STATE.collectStatus))

		local listBox = section(collectTab, "Zones", "map")
		local listTitle = "World & Dreamland"
		local holder = info(listBox, listTitle, "Every zone's index. The one being collected is highlighted")
		local okList, update = pcall(STATE.buildCollectList, holder, listTitle)
		elevate()
		if okList and type(update) == "function" then
			collectUpdate = update
			pcall(collectUpdate, firstRows)
			elevate()
		end
	end

	-- Animals --------------------------------------------------------------
	local animalInfo, sellInfo, espInfo
	do
		local animalBox = section(animalTab, "Your Animals", "paw-print")
		toggle(animalBox, "Keep Best Animals Equipped", "equipBest")
		toggle(animalBox, "Hide Animal Models (FPS)", "hidePets", "Hidden on your screen only. Nothing is unequipped")
		button(animalBox, "Equip Best Now", nil, "crown", function()
			local ok = STATE.equipBestNow()
			notify("progress", ok and "Best animals equipped" or "Equip Best was rejected", ok and "Your strongest animals are placed" or "Try again in a moment")
		end)
		animalInfo = info(animalBox, "Status", "Checking your animals...")

		local sellBox = section(animalTab, "Safe Auto Sell", "badge-dollar-sign", false)
		toggle(sellBox, "Auto Sell Backpack Animals", "autoSell", "Placed animals, your best backups and protected mutations are never sold")
		multiChoice(sellBox, "Rarities Allowed to Sell", "Unticked rarities are always kept", RARITY_OPTIONS, "sellRarities", function()
			local warning = STATE.sellRiskWarning()
			if warning then
				notify("system", "Review Auto Sell filters", warning)
			end
		end)
		multiChoice(sellBox, "Never Sell These Mutations", nil, MUTATION_OPTIONS, "protectedMutations")
		choice(sellBox, "Keep Best Backpack Animals", nil, KEEP_BACKUP_OPTIONS, function()
			return "Keep " .. tostring(STATE.keepBest)
		end, function(option)
			STATE.keepBest = tonumber(option:match("%d+")) or STATE.keepBest
		end)
		choice(sellBox, "Auto Sell Interval", nil, SELL_INTERVAL_OPTIONS, function()
			return "Every " .. tostring(STATE.sellMinutes) .. (STATE.sellMinutes == 1 and " minute" or " minutes")
		end, function(option)
			STATE.sellMinutes = tonumber(option:match("%d+")) or STATE.sellMinutes
		end)
		button(sellBox, "Sell Matching Animals Now", "Shows what will be sold and asks first", "trash-2", function()
			local preview = STATE.sellPreview(true)
			if not preview or preview.eligible <= 0 then
				notify("sale", "Nothing to sell", "Nothing matches your Safe Auto Sell filters")
				return
			end
			local warning = STATE.sellRiskWarning()
			confirm("Sell " .. tostring(preview.eligible) .. " animals?", "Only backpack animals that pass every filter are sold." .. (warning and ("\n" .. warning) or ""), function()
				task.spawn(function()
					local sold = STATE.sellJunkNow(true)
					notify("sale", sold > 0 and ("Sold " .. sold .. " animals") or "Nothing sold", tostring(STATE.sellStatus))
				end)
			end)
		end)
		sellInfo = info(sellBox, "Status", "Checking protected animals...")

		local espBox = section(animalTab, "Animal ESP", "eye", false)
		toggle(espBox, "Animal ESP", "espEnabled", "Names, rarity and income through walls")
		toggle(espBox, "Only Show My Animals", "espOwnOnly")
		toggle(espBox, "Show All Matching Animals", "espAllAnimals", "Off shows only the best animal per plot")
		multiChoice(espBox, "Rarities to Display", nil, RARITY_OPTIONS, "espRarities", function()
			task.defer(STATE.refreshEsp)
		end)
		choice(espBox, "Maximum Display Distance", nil, ESP_DISTANCE_OPTIONS, function()
			return STATE.espMaxDistance
		end, function(option)
			STATE.espMaxDistance = option
			task.defer(STATE.refreshEsp)
		end)
		espInfo = info(espBox, "Status", STATE.espStatus or "ESP off")
	end

	-- Progress -------------------------------------------------------------
	local upgradeInfo, rewardInfo, dreamInfo, indexInfo
	do
		local upgradeBox = section(progressTab, "Upgrades", "arrow-up-circle")
		toggle(upgradeBox, "Auto Buy Food Upgrades", "autoFood")
		toggle(upgradeBox, "Auto Buy Training Stands", "autoStand")
		toggle(upgradeBox, "Auto Buy Plot Slots", "autoFence")
		choice(upgradeBox, "Keep Cash Reserve", "Upgrades never spend below this", CASH_RESERVE_OPTIONS, function()
			return STATE.cashReserve
		end, function(option)
			STATE.cashReserve = option
		end)
		upgradeInfo = info(upgradeBox, "Status", tostring(STATE.upgradeStatus))

		local dreamBox = section(progressTab, "Dreamland Research", "moon")
		toggle(dreamBox, "Spend Tokens on Boosts", "dreamBuy", "2x Cash and 2x Training boosts")
		toggle(dreamBox, "Buy Dream Potions", "dreamPotionBuy", "Spends research tokens (350 each) after any boosts")
		toggle(dreamBox, "Auto Infuse Best Animals", "dreamInfuse", "4 Dream Potions per animal = 100% Dream mutation (x1.2 income). Strongest placed animal first")
		dreamInfo = info(dreamBox, "Dreamland", tostring(STATE.dreamStatus))

		local indexBox = section(progressTab, "Index Trails", "book-open")
		toggle(indexBox, "Wear Best Trail", "autoTrail")
		indexInfo = info(indexBox, "Index", tostring(STATE.indexStatus))

		local rewardBox = section(progressTab, "Rewards", "gift")
		toggle(rewardBox, "Claim Offline Earnings", "autoOffline")
		toggle(rewardBox, "Claim Free Animal", "autoFree")
		rewardInfo = info(rewardBox, "Status", tostring(STATE.rewardStatus))
	end

	-- Player ---------------------------------------------------------------
	local potatoInfo, serverInfo
	do
		local moveBox = section(playerTab, "Movement", "footprints")
		toggle(moveBox, "Custom Walk Speed", "walkSpeed")
		choice(moveBox, "Walk Speed", "16 is the normal speed", SPEED_OPTIONS, function()
			return tostring(STATE.speed)
		end, function(option)
			STATE.speed = tonumber(option) or STATE.speed
		end)
		toggle(moveBox, "Infinite Jump", "infiniteJump")
		toggle(moveBox, "Noclip", "noclip")
		toggle(moveBox, "Instant Interactions", "instantPrompts", "No hold time on prompts")
		toggle(moveBox, "Fly", "fly", "PC: WASD, Space up, Left Ctrl down")
		choice(moveBox, "Fly Speed", nil, FLY_SPEED_OPTIONS, function()
			return tostring(STATE.flySpeed)
		end, function(option)
			STATE.flySpeed = tonumber(option) or STATE.flySpeed
		end)

		local teleportBox = section(playerTab, "Teleport", "map-pin", false)
		for _, spot in ipairs({
			{ "Throw Line", "Throw", "target" },
			{ "Food Shop", "Shop", "store" },
			{ "Training", "Training", "dumbbell" },
			{ "Sell Shop", "Sell", "badge-dollar-sign" },
		}) do
			button(teleportBox, spot[1], nil, spot[3], function()
				if not STATE.teleportTo(spot[2]) then
					notify("system", spot[1] .. " unavailable", "Try again in a moment")
				end
			end)
		end

		local clientBox = section(playerTab, "Performance & AFK", "cpu", false)
		toggle(clientBox, "Anti AFK", "antiAfk")
		toggle(clientBox, "Auto Reconnect on Kick", "autoReconnect")
		toggle(clientBox, "Reload Hub After Server Change", "autoReload", STATE.autoReloadAvailable and "Loads the hub again after a rejoin, server hop or update" or "Your executor can't do this (no queue_on_teleport)")
		toggle(clientBox, "Hide Roblox Pause Popup", "noPausePopup")
		toggle(clientBox, "Potato Mode", "fpsBoost", "Low detail for more FPS. Fully reversible")
		toggle(clientBox, "AFK Black Screen", "disable3d", "Black screen with your live progress. Stops drawing the world to save GPU and battery")
		potatoInfo = info(clientBox, "Status", STATE.potatoStatus or "Potato Mode off")

		local serverBox = section(playerTab, "Server", "server", false)
		serverInfo = info(serverBox, "This Server", "Job " .. string.sub(game.JobId, 1, 8) .. "... · Place " .. tostring(game.PlaceId))
		button(serverBox, "Rejoin", nil, "rotate-ccw", function()
			STATE.rejoin()
		end)
		button(serverBox, "Server Hop", nil, "shuffle", function()
			if not STATE.hop(false) then
				notify("system", "No other server found", "Try again in a moment")
			end
		end)
		button(serverBox, "Lowest Player Server", nil, "users", function()
			if not STATE.hop(true) then
				notify("system", "No other server found", "Try again in a moment")
			end
		end)
		button(serverBox, "Copy Job ID", nil, "copy", function()
			notify("system", STATE.copyJobId() and "Job ID copied" or "Copy is not available", game.JobId)
		end)
	end

	-- Settings -------------------------------------------------------------
	do
		local notifyBox = section(settingsTab, "Notifications", "bell")
		toggle(notifyBox, "Hub Notifications", "notifications")
		toggle(notifyBox, "Catch Notifications", "notifyCatches")
		toggle(notifyBox, "Sale Notifications", "notifySales")
		toggle(notifyBox, "Upgrade & Reward Notifications", "notifyProgress")
		choice(notifyBox, "Minimum Catch Rarity", nil, NOTIFY_RARITY_OPTIONS, function()
			return STATE.notifyMinRarity
		end, function(option)
			STATE.notifyMinRarity = option
		end)
		button(notifyBox, "Test Notification", nil, "bell-ring", function()
			notify("system", "Notifications are working", "Catches, sales and progress show up here")
		end)

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
				if a == "Zinoos" then return true end
				if b == "Zinoos" then return false end
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
			return STATE.hubSize or "Normal"
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

		local configBox = section(settingsTab, "Config", "save", false)
		info(configBox, "Saving", "Changes save automatically for this Roblox account.")
		button(configBox, "Save Now", nil, "save", function()
			saveConfig()
			notify("system", "Saved", "Settings saved for " .. LocalPlayer.DisplayName)
		end)
		button(configBox, "Reset to Safe Defaults", "Auto Sell is turned off", "rotate-ccw", function()
			confirm("Reset every setting?", "All options go back to safe defaults and Auto Sell turns off.", function()
				local safeValues = {
					autoThrow = true, perfectMeter = true, autoSkip = true, autoTrain = false,
					autoTapBonus = true, autoFood = true, autoStand = true, autoFence = false,
					equipBest = true, autoSell = false, autoOffline = true, autoFree = true,
					autoSuper = false, stopOnRarity = false, stopOnMutation = false,
					trainToTarget = false, resumeThrowAfterTraining = true,
					walkSpeed = false, antiAfk = true, infiniteJump = false, noclip = false,
					instantPrompts = false, fly = false, noPausePopup = true, autoReconnect = false,
					disable3d = false, fpsBoost = false, hidePets = true,
					notifications = true, notifyCatches = true, notifySales = true, notifyProgress = true,
					espEnabled = false, espOwnOnly = false, espAllAnimals = false, hideOnStart = false,
					trainOnBoost = true, autoRingRush = true, dreamBuy = false, dreamPotionBuy = false, dreamInfuse = false, autoTrail = true, cycleTrain = false,
					indexHunt = false, collectClaim = true, collectStop = true, collectSuper = false,
				}
				STATE.collectTarget = "Auto"
				for key, value in pairs(safeValues) do
					STATE[key] = value
					syncToggle(key)
				end
				STATE.keepBest = 10
				STATE.sellMinutes = 2
				STATE.sellRarities = { "Common", "Uncommon", "Rare" }
				STATE.protectedMutations = table.clone(MUTATION_OPTIONS)
				STATE.stopTargetRarity = "Supreme"
				STATE.stopTargetMutations = { "Rainbow" }
				STATE.trainTargetPower = "10K"
				STATE.cashReserve = "$0"
				STATE.superThrowReserve = 0
				STATE.notifyMinRarity = "All"
				STATE.espRarities = table.clone(RARITY_OPTIONS)
				STATE.espMaxDistance = "500"
				task.spawn(stopTraining)
				pcall(STATE.apply3d)
				pcall(STATE.applyFpsBoost)
				pcall(STATE.applyHidePets)
				pcall(STATE.refreshEsp)
				local hum = humanoid()
				if hum then hum.WalkSpeed = 16 end
				refreshDropdowns()
				nextSellAt = 0
				saveConfig()
				notify("system", "Safe defaults restored", "Auto Sell is off")
			end)
		end)

		local communityBox = section(settingsTab, "Community", "message-circle", false)
		button(communityBox, "Copy Discord Invite", "discord.gg/94pC3T6NZG", "copy", function()
			local invite = "https://discord.gg/94pC3T6NZG"
			if typeof(setclipboard) == "function" and pcall(setclipboard, invite) then
				notify("system", "Invite copied", "Paste it in your browser")
			else
				notify("system", "Discord invite", invite)
			end
		end)
		info(communityBox, "Diagnostics", table.concat({
			"Config saving · " .. ((typeof(writefile) == "function" and typeof(readfile) == "function") and "available" or "unavailable"),
			"Clipboard · " .. (typeof(setclipboard) == "function" and "available" or "unavailable"),
			"Reconnect queue · " .. ((typeof(queue_on_teleport) == "function" or (syn and typeof(syn.queue_on_teleport) == "function")) and "available" or "unavailable"),
		}, "\n"))
		button(communityBox, "Unload Hub", "Stops everything and removes the menu", "log-out", function()
			confirm("Unload Zinoos Hub?", "All automation stops until you run the loader again.", function()
				task.defer(unloadHub)
			end)
		end)
	end

	-- WindUI opens with no tab chosen; show Home.
	pcall(Window.SelectTab, Window, 1)
	-- Re-measure the boxes on screen once the layout has settled and each
	-- time another tab is opened.
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
	local function countSummary(counts, order)
		local parts = {}
		for _, name in ipairs(order) do
			local count = tonumber(counts[name]) or 0
			if count > 0 then
				table.insert(parts, tostring(name) .. " " .. tostring(count))
			end
		end
		return #parts > 0 and table.concat(parts, " · ") or "None yet"
	end

	local sessionStarted = os.time()
	local fpsCount = 0
	local fpsConnection = trackConnection(RunService.RenderStepped:Connect(function()
		fpsCount += 1
	end))
	local lastFps, lastFpsAt = 0, os.clock()

	local function refresh()
		-- Read everything from the game first, then write the menu, so the
		-- thread still has permission to touch the UI.
		local money = getData("Money")
		local animals = getData("Animals")
		local food = getData("EquippedFood") or 0
		local stand = getData("Stand") or 0
		local fence = getData("FenceLevel") or 0
		local animalCount, placedCount = 0, 0
		if type(animals) == "table" then
			for _, entry in pairs(animals) do
				if type(entry) == "table" then
					animalCount += 1
					if entry.Placed then
						placedCount += 1
					end
				end
			end
		end
		local preview = STATE.sellPreview()
		local warning = STATE.sellRiskWarning()
		local ping = 0
		pcall(function()
			ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
		end)
		local now = os.clock()
		if now - lastFpsAt >= 1 then
			lastFps = math.floor(fpsCount / (now - lastFpsAt) + 0.5)
			fpsCount, lastFpsAt = 0, now
		end
		local elapsed = math.max(0, os.time() - sessionStarted)
		local clock = elapsed >= 3600
			and string.format("%d:%02d:%02d", elapsed // 3600, elapsed % 3600 // 60, elapsed % 60)
			or string.format("%d:%02d", elapsed // 60, elapsed % 60)
		elevate()

		setInfo(overview, string.format(
			"%s  ·  %s\nMoney $%s  ·  %d animals (%d placed)\nFood %s · Stand %s · Fence %s\nSession %s  ·  %d fps  ·  %d ms",
			STATE.autoThrow == true and "Farming ON" or (STATE.autoTrain == true and "Training" or "Farming OFF"),
			STATE.cycleTrain == true and STATE.cycleInfo and STATE.cycleInfo() and ("Cycle: " .. tostring(STATE.cycleStatus)) or publicStatus(STATE.status),
			shortNumber(money),
			animalCount,
			placedCount,
			tostring(food),
			tostring(stand),
			tostring(fence),
			clock,
			lastFps,
			ping
		))
		setInfo(sessionInfo, string.format(
			"%d throws · %d new animals · %d target stops\nRarities: %s\nMutations: %s",
			stats.throws,
			stats.catches,
			stats.targetStops,
			countSummary(stats.rarityCounts, RARITY_OPTIONS),
			countSummary(stats.mutationCounts, MUTATION_OPTIONS)
		))
		local history = {}
		for index = 1, math.min(6, #STATE.catchHistory) do
			local catch = STATE.catchHistory[index]
			history[#history + 1] = string.format("%s · %s", tostring(catch.title), tostring(catch.message))
		end
		setInfo(historyInfo, #history > 0 and table.concat(history, "\n") or "No new animals caught yet.")
		local lines = {
			"Training · " .. publicStatus(STATE.trainingStatus),
			"Upgrades · " .. publicStatus(STATE.upgradeStatus),
			"Selling · " .. publicStatus(STATE.sellStatus),
			"Rewards · " .. publicStatus(STATE.rewardStatus),
			"Boosts · " .. tostring(STATE.boostStatus),
			"Aim · " .. tostring(STATE.aimStatus),
		}
		if STATE.antiAfk == true then
			lines[#lines + 1] = STATE.antiAfkOperational == true and "Anti AFK active" or "Anti AFK waiting for idle"
		end
		for _, item in ipairs(STATE.activity) do
			lines[#lines + 1] = tostring(item)
		end
		setInfo(activityInfo, table.concat(lines, "\n"))
		setInfo(throwInfo, publicStatus(STATE.throwStatus))
		setInfo(superInfo, publicStatus(STATE.superThrowStatus))
		setInfo(trainInfo, publicStatus(STATE.trainingStatus) .. (STATE.cycleTrain == true and ("\nCycle: " .. tostring(STATE.cycleStatus)) or ""))
		setInfo(boostInfo, tostring(STATE.boostStatus))
		if STATE.ringRushText then
			local ok, text = pcall(STATE.ringRushText)
			elevate()
			setInfo(ringInfo, ok and tostring(text) or "Checking Ring Rush...")
		end
		setInfo(aimInfo, tostring(STATE.aimStatus))
		setInfo(upgradeInfo, string.format("%s\nFood %s · Stand %s · Fence %s", publicStatus(STATE.upgradeStatus), tostring(food), tostring(stand), tostring(fence)))
		setInfo(rewardInfo, publicStatus(STATE.rewardStatus))
		setInfo(dreamInfo, tostring(STATE.dreamStatus))
		setInfo(indexInfo, tostring(STATE.indexStatus))
		setInfo(collectInfo, tostring(STATE.collectStatus))
		if collectUpdate and STATE.collectRows then
			pcall(collectUpdate, STATE.collectRows)
			elevate()
		end
		setInfo(animalInfo, string.format("Equip · %s\n%d animals · %d placed · %d backpack\n%s", publicStatus(STATE.equipStatus or "Ready"), animalCount, placedCount, animalCount - placedCount, STATE.petVisibilityStatus or "Checking animal visibility"))
		if preview then
			setInfo(sellInfo, string.format(
				"%s\n%d ready to sell · %d allowed rarities\n%d best backups safe · %d mutations safe · placed animals always safe%s",
				publicStatus(STATE.sellStatus),
				preview.eligible,
				#STATE.sellRarities,
				preview.protectedBest,
				preview.protectedMutation,
				warning and ("\n" .. warning) or ""
			))
		else
			setInfo(sellInfo, publicStatus(STATE.sellStatus))
		end
		setInfo(espInfo, STATE.espStatus or "ESP off")
		setInfo(potatoInfo, STATE.potatoStatus or "Potato Mode off")
	end
	STATE.refreshActivity = refresh

	task.spawn(function()
		while running() and not windowGone do
			pcall(refresh)
			pcall(reflowShown)
			task.wait(1)
		end
		pcall(function()
			fpsConnection:Disconnect()
		end)
	end)

	if STATE.hideOnStart == true then
		task.defer(function()
			elevate()
			pcall(Window.Close, Window)
		end)
	end

	STATE.hubWindow = {
		Unload = function()
			unloadHub()
		end,
	}
end
loadSaved()
if STATE.configMigratedSellSafety == true then
	STATE.sellStatus = "Safety update: old all-rarity Auto Sell was turned off"
	saveConfig()
end

if running() then
	elevate()
	local ok, err = xpcall(installHub, debug.traceback)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
		if running() then
			shutdownHub()
		end
	end
end

-- Native throw loop.
task.spawn(function()
	while running() do
		local ok, pause = pcall(stepThrow)
		if not ok then
			STATE.throwStatus = "Throw error: " .. tostring(pause)
			pause = 2
		end
		task.wait(type(pause) == "number" and pause or 0.5)
	end
end)

-- Training, upgrades, team management and rewards.
task.spawn(function()
	local nextEvents = 0
	while running() do
		if os.clock() >= nextEvents then
			nextEvents = os.clock() + 1
			pcall(stepEvents)
		end
		pcall(stepTraining)
		pcall(stepUpgrades)
		pcall(stepRewards)
		if STATE.equipBest == true and os.clock() >= nextEquip then
			nextEquip = os.clock() + 8
			pcall(STATE.equipBestNow)
		end
		task.wait(0.55)
	end
end)

task.spawn(function()
	while running() do
		if STATE.autoSell == true then
			if os.clock() >= nextSellAt then
				local ok = pcall(STATE.sellJunkNow, false)
				local waiting = type(STATE.sellStatus) == "string" and string.sub(STATE.sellStatus, 1, 11) == "Waiting for"
				nextSellAt = os.clock() + ((ok and not waiting) and math.max(1, STATE.sellMinutes) * 60 or 1)
			end
		else
			STATE.sellStatus = "Off"
			nextSellAt = 0
		end
		task.wait(0.5)
	end
end)

task.spawn(function()
	while running() do
		pcall(stepSpeed)
		pcall(hidePausePopup)
		task.wait(0.25)
	end
end)
pcall(STATE.apply3d)
pcall(STATE.applyFpsBoost)
pcall(STATE.applyHidePets)
pcall(STATE.applyInstantPrompts)
pcall(stepAnimalNotifications)
pcall(STATE.refreshEsp)

task.spawn(function()
	while running() do
		pcall(stepAnimalNotifications)
		if STATE.espEnabled == true then
			pcall(STATE.refreshEsp)
		end
		task.wait(0.6)
	end
end)

task.spawn(function()
	while running() do
		task.wait(3)
		if STATE.hidePets == true then
			pcall(STATE.applyHidePets)
		end
	end
end)

task.spawn(function()
	while running() do
		task.wait(2 * 60)
		pulseAntiAfk()
	end
end)
