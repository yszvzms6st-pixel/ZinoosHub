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

local RARITY_OPTIONS = {
	"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
	"Secret", "Divine", "Celestial", "Eternal", "Cosmic", "Supreme",
}
local MUTATION_OPTIONS = { "Gold", "Diamond", "Emerald", "Ruby", "Rainbow" }
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
	version = "2.5.4",
	autoThrow = true,
	perfectMeter = true,
	autoSkip = true,
	autoTrain = false,
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
}

local FLY_SPEED_OPTIONS = { "30", "60", "100", "150", "200" }
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
local CHOICES = {
	ToggleKey = { key = "toggleKey", options = KEY_OPTIONS },
	NotifyMinRarity = { key = "notifyMinRarity", options = NOTIFY_RARITY_OPTIONS },
	EspMaxDistance = { key = "espMaxDistance", options = ESP_DISTANCE_OPTIONS },
	StopTargetRarity = { key = "stopTargetRarity", options = RARITY_OPTIONS },
	TrainTargetPower = { key = "trainTargetPower", options = TRAIN_TARGET_OPTIONS },
	CashReserve = { key = "cashReserve", options = CASH_RESERVE_OPTIONS },
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
	STATE.antiAfkOperational = ok
	return ok
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
STATE.throwMeterOriginalNew = STATE.throwMeter.new
hubCleanup(function()
	if STATE.throwMeter and STATE.throwMeterOriginalNew then
		STATE.throwMeter.new = STATE.throwMeterOriginalNew
	end
end)

local function readAll()
	local ok, value = pcall(GameDataController.GetData, GameDataController)
	return ok and type(value) == "table" and value or {}
end

local function getData(key)
	local ok, value = pcall(GameDataController.Get, GameDataController, key)
	return ok and value or nil
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

local lastObservedThrows = tonumber(getData("Throws")) or 0
local nextThrowTrigger = 0
local function stepThrow()
	if STATE.autoThrow ~= true or STATE.autoTrain == true then
		if STATE.autoThrow ~= true then
			STATE.throwStatus = "Off"
		end
		return 0.5
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
		STATE.status = "Throwing food"
		STATE.throwStatus = STATE.perfectMeter and "Perfect throw running" or "Throw running"
		return 0.25
	elseif busy then
		STATE.status = "Waiting for " .. publicStatus(busy)
		STATE.throwStatus = "Waiting for game"
		return 0.5
	end
	if os.clock() < nextThrowTrigger then
		return 0.25
	end
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
	if STATE.autoSuper == true
		and (tonumber(getData("SuperThrows")) or 0) > (tonumber(STATE.superThrowReserve) or 0) then
		invoke("Throw_UseSuper")
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
		releaseBusy(throwToken)
		local sequenceOk, sequenceError = pcall(STATE.throwController.Start)
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
		lastObservedThrows = after
		STATE.status = "Waiting for next throw"
		nextThrowTrigger = os.clock() + 0.35
		return 0.25
	end
	local started = invoke("Throw_Start")
	local result = nil
	if started.Ok then
		result = invoke("Throw_Resolve", STATE.perfectMeter == true and 1 or 0.75)
		if result.Ok then
			invoke("Throw_Complete")
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
	if STATE.autoTrain ~= true or STATE.trainToTarget ~= true then
		return false
	end
	local level = tonumber(getData("Level")) or 1
	local trainedPower = tonumber(getData("ThrowPower")) or 0
	local power = tonumber(LevelConfig.EffectiveThrowPower(level, trainedPower)) or 0
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

local function stepTraining()
	if STATE.autoTrain ~= true then
		stopTraining()
		STATE.trainingStatus = "Off"
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
			if best > equipped then
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

function STATE.sellPreview()
	local _, _, summary = buildSellPlan()
	return summary
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
}
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

local function installHub()
	elevate()
	destroyMenus()
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
	gui.Name = "ZinoosThrowFoodMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 220
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = CoreGui

	local toastHost = Instance.new("Frame")
	toastHost.Name = "Notifications"
	toastHost.BackgroundTransparency = 1
	toastHost.AnchorPoint = Vector2.new(1, 0)
	toastHost.Position = UDim2.new(1, -18, 0, 18)
	toastHost.Size = UDim2.fromOffset(320, 420)
	toastHost.ZIndex = 80
	toastHost.Parent = gui
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.Padding = UDim.new(0, 8)
	toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.Parent = toastHost
	local activeToasts = {}
	local toastSerial = 0
	local lastToastKey = nil
	local lastToastAt = 0

	STATE.toast = function(entry)
		local key = tostring(entry.title) .. "\0" .. tostring(entry.message)
		if key == lastToastKey and os.clock() - lastToastAt < 1.5 then
			return true
		end
		lastToastKey = key
		lastToastAt = os.clock()

		-- Rendering must never hold up farming, selling, or upgrade loops. Some
		-- executors can yield when a CoreGui tree is built from an event callback.
		task.spawn(function()
			local ok = pcall(function()
				toastSerial += 1
				while #activeToasts >= 4 do
					local oldest = table.remove(activeToasts, 1)
					if oldest and oldest.Parent then oldest:Destroy() end
				end

				local color = entry.rarity and ESP_COLORS[entry.rarity]
					or (entry.category == "sale" and Color3.fromRGB(92, 230, 150))
					or (entry.category == "progress" and Color3.fromRGB(255, 190, 80))
					or accent
				local toast = Instance.new("CanvasGroup")
				toast.Name = "Toast"
				toast.BackgroundColor3 = cardColor
				toast.BackgroundTransparency = 0.04
				toast.BorderSizePixel = 0
				toast.GroupTransparency = 1
				toast.LayoutOrder = -toastSerial
				toast.Size = UDim2.fromOffset(310, 72)
				toast.ZIndex = 81
				toast:SetAttribute("ZinoosRole", "card")
				toast.Parent = toastHost
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 10)
				corner.Parent = toast
				local stroke = Instance.new("UIStroke")
				stroke.Color = color
				stroke.Transparency = 0.25
				stroke.Thickness = 1
				stroke.Parent = toast
				local bar = Instance.new("Frame")
				bar.BackgroundColor3 = color
				bar.BorderSizePixel = 0
				bar.Size = UDim2.fromOffset(4, 48)
				bar.Position = UDim2.fromOffset(10, 12)
				bar.ZIndex = 82
				bar.Parent = toast
				local barCorner = Instance.new("UICorner")
				barCorner.CornerRadius = UDim.new(1, 0)
				barCorner.Parent = bar
				local title = Instance.new("TextLabel")
				title.BackgroundTransparency = 1
				title.Font = Enum.Font.GothamBold
				title.Text = tostring(entry.title)
				title.TextColor3 = ink
				title.TextSize = 14
				title.TextTruncate = Enum.TextTruncate.AtEnd
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.Position = UDim2.fromOffset(24, 10)
				title.Size = UDim2.new(1, -56, 0, 20)
				title.ZIndex = 82
				title:SetAttribute("ZinoosRole", "ink")
				title.Parent = toast
				local body = Instance.new("TextLabel")
				body.BackgroundTransparency = 1
				body.Font = Enum.Font.Gotham
				body.Text = tostring(entry.message)
				body.TextColor3 = muted
				body.TextSize = 12
				body.TextWrapped = true
				body.TextXAlignment = Enum.TextXAlignment.Left
				body.TextYAlignment = Enum.TextYAlignment.Top
				body.Position = UDim2.fromOffset(24, 32)
				body.Size = UDim2.new(1, -38, 0, 30)
				body.ZIndex = 82
				body:SetAttribute("ZinoosRole", "muted")
				body.Parent = toast
				local close = Instance.new("TextButton")
				close.BackgroundTransparency = 1
				close.Font = Enum.Font.GothamBold
				close.Text = "×"
				close.TextColor3 = muted
				close.TextSize = 18
				close.Position = UDim2.new(1, -30, 0, 5)
				close.Size = UDim2.fromOffset(24, 24)
				close.ZIndex = 83
				close:SetAttribute("ZinoosRole", "muted")
				close.Parent = toast
				table.insert(activeToasts, toast)

				local closing = false
				local function dismiss()
					if closing or not toast.Parent then return end
					closing = true
					TweenService:Create(toast, tweenInfo.fade, { GroupTransparency = 1 }):Play()
					task.delay(0.22, function()
						local index = table.find(activeToasts, toast)
						if index then table.remove(activeToasts, index) end
						if toast.Parent then toast:Destroy() end
					end)
				end
				close.Activated:Connect(dismiss)
				TweenService:Create(toast, tweenInfo.fade, { GroupTransparency = 0 }):Play()
				task.delay(4.5, dismiss)
			end)
			if not ok then
				-- Notifications are optional UI; never let a renderer failure stop automation.
				return
			end
		end)
		return true
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local function viewSize()
		local camera = workspace.CurrentCamera
		return camera and camera.ViewportSize or Vector2.new(1280, 720)
	end
	local holder
	local launcher
	local fullMode = false
	local applyHubLayout
	local function fitScale()
		local view = viewSize()
		local phone = UserInputService.TouchEnabled and math.min(view.X, view.Y) < 820
		local compact = phone or view.X < 760 or view.Y < 560 or (UserInputService.TouchEnabled and view.X < 900)
		local margin = (compact or fullMode) and 0 or 16
		local baseW, baseH
		local phoneScale = 1
		if phone and not fullMode then
			-- Phones get their own size table: scale, share of screen width, share of screen height.
			local fit = STATE.phoneHubSizes[STATE.hubSize or "Compact"] or STATE.phoneHubSizes.Compact
			phoneScale = fit[1]
			local pixelsW = math.min(math.floor(view.X * fit[2]), view.X - 20)
			local pixelsH = math.min(math.floor(view.Y * fit[3]), view.Y - 20)
			baseW = math.max(280, math.floor(pixelsW / phoneScale))
			baseH = math.max(300, math.floor(pixelsH / phoneScale))
		elseif compact or fullMode then
			baseW = math.max(320, view.X - margin * 2)
			baseH = math.max(480, view.Y - margin * 2)
		else
			local wanted = STATE.hubScaleValue and STATE.hubScaleValue() or 1
			baseW = math.min(972, math.max(640, math.floor((view.X - 32) / wanted)))
			baseH = math.min(668, math.max(480, math.floor((view.Y - 32) / wanted)))
		end
		holder.Size = UDim2.fromOffset(baseW, baseH)
		local desktopScale = (phone or compact or fullMode) and 1 or (STATE.hubScaleValue and STATE.hubScaleValue() or 1)
		if phone and not fullMode then
			desktopScale = phoneScale
		end
		uiScale.Scale = desktopScale
		if launcher then
			launcher.Size = phone and UDim2.fromOffset(232, 120) or UDim2.fromOffset(300, 136)
		end
		if applyHubLayout then
			applyHubLayout(view, compact, baseW)
		end
	end

	launcher = Instance.new("CanvasGroup")
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
	dockName.Text = "ZinoosHub"
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
	dockGame.Text = "Throw Food For Animals · v" .. STATE.version
	dockGame.TextColor3 = muted
	role(dockGame, "muted")
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
	dockHint.Text = "Open dashboard  →"
	dockHint.TextColor3 = muted
	role(dockHint, "muted")
	dockHint.TextSize = 12
	dockHint.TextXAlignment = Enum.TextXAlignment.Left
	dockHint.Position = UDim2.fromOffset(14, 100)
	dockHint.Size = UDim2.new(1, -28, 0, 18)
	dockHint.Parent = launcher
	local launcherOpenButton = Instance.new("TextButton")
	launcherOpenButton.Name = "Open"
	launcherOpenButton.AutoButtonColor = false
	launcherOpenButton.BackgroundTransparency = 1
	launcherOpenButton.Text = ""
	launcherOpenButton.Position = UDim2.fromOffset(8, 94)
	launcherOpenButton.Size = UDim2.new(1, -16, 0, 34)
	launcherOpenButton.ZIndex = 10
	launcherOpenButton.Parent = launcher
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
	brand.Text = "ZinoosHub"
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
	brandSub.Text = "Throw Food · v" .. STATE.version
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

	local homePage = newPage("Dashboard")
	newPage("Farming")
	newPage("Animals")
	newPage("Progress")
	newPage("Selling")
	local playerPage = newPage("Player")
	newPage("Settings")

	local currentPage = "Dashboard"
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
		local targetPage = pages[name]
		if not targetPage then
			return
		end
		currentPage = name
		for pageName, page in pairs(pages) do
			page.Visible = pageName == name
		end
		pageTitle.Text = name
		targetPage.CanvasPosition = Vector2.zero
		local themeNow = STATE.hubThemeDef()
		for buttonName, button in pairs(navButtons) do
			local on = buttonName == name
			button.BackgroundColor3 = on and themeNow.selected or themeNow.hover
			playMotion(button, { BackgroundTransparency = on and themeNow.selectedFade or 1 }, tweenInfo.hover)
		end
		if holder.Visible then
			playCards(pages[name])
		end
		if name == "Player" then
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
		if kind == "Dashboard" then
			mark(10, 7, 3, 8, false)
			local roof = mark(2, 8, 7, 1, false)
			roof.Rotation = 40
		elseif kind == "Farming" then
			mark(6, 6, 0, 0, false)
			mark(6, 6, 9, 0, false)
			mark(6, 6, 0, 9, false)
			mark(6, 6, 9, 9, false)
		elseif kind == "Animals" then
			mark(3, 3, 0, 2, true)
			mark(3, 3, 4, 0, true)
			mark(3, 3, 9, 0, true)
			mark(3, 3, 13, 2, true)
			mark(10, 7, 3, 8, true)
		elseif kind == "Progress" then
			mark(3, 5, 1, 10, false)
			mark(3, 9, 6, 6, false)
			mark(3, 13, 11, 2, false)
		elseif kind == "Selling" then
			mark(12, 5, 2, 1, true)
			mark(12, 5, 2, 6, true)
			mark(12, 5, 2, 11, true)
		elseif kind == "Player" then
			mark(6, 6, 5, 1, true)
			mark(12, 6, 2, 9, true)
		elseif kind == "Settings" then
			mark(12, 2, 2, 2, false)
			mark(3, 3, 4, 1, true)
			mark(12, 2, 2, 7, false)
			mark(3, 3, 10, 6, true)
			mark(12, 2, 2, 12, false)
			mark(3, 3, 6, 11, true)
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
	addNav("Dashboard", 1)
	addNav("Farming", 2)
	addNav("Animals", 3)
	addNav("Progress", 4)
	addNav("Selling", 5)
	addNav("Player", 6)
	addNav("Settings", 7)

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
	profileGame.Text = STATE.admin and "Admin" or "Throw Food Animals"
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
		local page = "Dashboard"
		local current = row
		while current do
			for pageName, pageObject in pairs(pages) do
				if current == pageObject then
					page = pageName
					current = nil
					break
				end
			end
			if current then
				current = current.Parent
			end
		end
		searchRows[#searchRows + 1] = { row = row, card = cardFrame, text = string.lower(text), page = page }
	end

	local function paintSwitch(track, knob, on, instant)
		local themeNow = STATE.hubThemeDef()
		local goal = on and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)
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

	local syncToggle
	local function onToggle(key, on)
		STATE[key] = on
		if key == "autoThrow" and on then
			STATE.autoTrain = false
			task.spawn(stopTraining)
			if syncToggle then syncToggle("autoTrain") end
		elseif key == "autoTrain" and on then
			STATE.autoThrow = false
			if syncToggle then syncToggle("autoThrow") end
		elseif key == "antiAfk" and on and pulseAntiAfk then
			task.defer(pulseAntiAfk)
		elseif key == "disable3d" then
			STATE.apply3d()
		elseif key == "autoSkip" then
			lastSkip = nil
			task.spawn(syncAutoSkip)
			task.defer(notify, "system", on and "Catch animation skipped" or "Catch animation enabled", on and "Auto Throw will use the fast catch path" or "Auto Throw will show the full game reveal")
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
		saveConfig()
	end

	local function makeSwitch(parentBox, name, key, hint)
		local row = Instance.new("Frame")
		row.Name = name
		row.BackgroundTransparency = 1
		row.LayoutOrder = 1
		row.Size = UDim2.new(1, 0, 0, hint and 58 or 44)
		row.Active = true
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
			note.Size = UDim2.new(1, -60, 0, 34)
			note.ZIndex = 6
			note.Parent = row
		end
		local track = Instance.new("TextButton")
		track.AutoButtonColor = false
		track.Text = ""
		track.AnchorPoint = Vector2.new(1, 0.5)
		track.Position = UDim2.new(1, 0, 0.5, 0)
		track.Size = UDim2.fromOffset(42, 24)
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
		knob.Size = UDim2.fromOffset(16, 16)
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
		local function toggleValue()
			control.value = not control.value
			paintSwitch(track, knob, control.value)
			onToggle(key, control.value == true)
		end
		onActivate(track, toggleValue)
		local rowButton = Instance.new("TextButton")
		rowButton.Name = "RowButton"
		rowButton.BackgroundTransparency = 1
		rowButton.Text = ""
		rowButton.Size = UDim2.fromScale(1, 1)
		rowButton.ZIndex = 5
		rowButton.Parent = row
		onActivate(rowButton, toggleValue)
		STATE.themeSwitches[#STATE.themeSwitches + 1] = { track = track, knob = knob, key = key }
		remember(row, parentBox, name .. " " .. (hint or ""))
		return row
	end
	syncToggle = function(key)
		local control = STATE.toggleControls[key]
		if type(control) == "table" then
			control.value = STATE[key] == true
		end
		for _, entry in ipairs(STATE.themeSwitches) do
			if entry.key == key and entry.track.Parent then
				paintSwitch(entry.track, entry.knob, STATE[key] == true)
			end
		end
	end
	STATE.syncToggle = syncToggle

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

	local dropdownRefreshers = {}
	local function makeDropdown(parentBox, name, getValue, options, callback, stacked, hint)
		local hasHint = type(hint) == "string" and hint ~= ""
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = 2
		row.Size = UDim2.new(1, 0, 0, stacked and (hasHint and 82 or 52) or (hasHint and 58 or 30))
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
		title.Size = stacked and UDim2.new(1, 0, 0, 18)
			or (hasHint and UDim2.new(0.55, -8, 0, 18) or UDim2.new(0.48, 0, 1, 0))
		title.ZIndex = 6
		title.Parent = row
		if hasHint then
			local note = Instance.new("TextLabel")
			note.BackgroundTransparency = 1
			note.Font = Enum.Font.Gotham
			note.Text = hint
			note.TextColor3 = muted
			role(note, "muted")
			note.TextSize = 11
			note.TextWrapped = true
			note.TextXAlignment = Enum.TextXAlignment.Left
			note.TextYAlignment = Enum.TextYAlignment.Top
			note.Position = UDim2.fromOffset(0, 19)
			note.Size = stacked and UDim2.new(1, 0, 0, 32) or UDim2.new(0.55, -8, 0, 36)
			note.ZIndex = 6
			note.Parent = row
		end
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
		table.insert(dropdownRefreshers, function()
			if pick.Parent then
				pick.Text = stacked and (" " .. getValue()) or getValue()
			end
		end)
		remember(row, parentBox, name .. " " .. (hint or ""))
		return pick
	end

	local function makeMultiDropdown(parentBox, name, getList, options, onToggleName, labelOf, hint)
		local hasHint = type(hint) == "string" and hint ~= ""
		local showList = labelOf or function(list)
			return tostring(type(list) == "table" and #list or 0) .. " selected"
		end
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = 2
		row.Size = UDim2.new(1, 0, 0, hasHint and 58 or 30)
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
		title.Size = hasHint and UDim2.new(0.55, -8, 0, 18) or UDim2.new(0.42, 0, 1, 0)
		title.ZIndex = 6
		title.Parent = row
		if hasHint then
			local note = Instance.new("TextLabel")
			note.BackgroundTransparency = 1
			note.Font = Enum.Font.Gotham
			note.Text = hint
			note.TextColor3 = muted
			role(note, "muted")
			note.TextSize = 11
			note.TextWrapped = true
			note.TextXAlignment = Enum.TextXAlignment.Left
			note.TextYAlignment = Enum.TextYAlignment.Top
			note.Position = UDim2.fromOffset(0, 19)
			note.Size = UDim2.new(0.55, -8, 0, 36)
			note.ZIndex = 6
			note.Parent = row
		end
		local pick = Instance.new("TextButton")
		pick.AutoButtonColor = false
		pick.Font = Enum.Font.Gotham
		pick.TextSize = 13
		pick.TextColor3 = ink
		role(pick, "field")
		pick.TextXAlignment = Enum.TextXAlignment.Left
		pick.TextTruncate = Enum.TextTruncate.AtEnd
		pick.Text = " " .. showList(getList())
		pick.BackgroundColor3 = panel
		pick.BackgroundTransparency = cardFade
		pick.AnchorPoint = Vector2.new(1, 0.5)
		pick.Position = UDim2.new(1, 0, 0.5, 0)
		pick.Size = UDim2.fromOffset(210, 26)
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
				pick.Text = " " .. showList(getList())
			end, true)
		end)
		table.insert(dropdownRefreshers, function()
			if pick.Parent then
				pick.Text = " " .. showList(getList())
			end
		end)
		remember(row, parentBox, name .. " " .. (hint or ""))
		return pick
	end

	STATE.toggleControls = {}
	local function selectedLabel(list, options)
		local count = type(list) == "table" and #list or 0
		if count == 0 then
			return "None selected"
		end
		if count == #options then
			return "All " .. tostring(count) .. " selected"
		end
		if count <= 2 then
			return table.concat(list, ", ")
		end
		return tostring(count) .. " selected"
	end
	local function toggleSelection(key, option, options)
		local selected = {}
		for _, value in ipairs(STATE[key] or {}) do
			selected[value] = true
		end
		selected[option] = not selected[option]
		local ordered = {}
		for _, value in ipairs(options) do
			if selected[value] then
				table.insert(ordered, value)
			end
		end
		STATE[key] = ordered
		if key == "espRarities" then
			task.defer(STATE.refreshEsp)
		elseif key == "sellRarities" or key == "protectedMutations" then
			nextSellAt = 0
		end
		saveConfig()
	end
	local function refreshDropdowns()
		for _, refresh in ipairs(dropdownRefreshers) do
			pcall(refresh)
		end
	end
	STATE.refreshDropdowns = refreshDropdowns

	STATE.uiStatusLabels = {}
	do
	local throwCard = card(pages.Farming, "THROW FARMING", 1)
	makeSwitch(throwCard, "Auto Throw", "autoThrow", "Repeats the game's normal food throw and catch cycle")
	makeSwitch(throwCard, "Always Land Maximum Throws (+20)", "perfectMeter", "Locks the game's throw meter at its full +20 power result")
	makeSwitch(throwCard, "Skip Catch Animation", "autoSkip", "Skips the animal reveal animation so the next throw starts sooner")
	makeSwitch(throwCard, "Use Super Throws Automatically", "autoSuper", "Uses Super Throws only while your chosen reserve remains untouched")
	makeDropdown(throwCard, "Super Throw Reserve", function()
		return STATE.superThrowReserve > 0 and ("Keep " .. tostring(STATE.superThrowReserve)) or "Use all"
	end, SUPER_RESERVE_OPTIONS, function(option)
		STATE.superThrowReserve = tonumber(option:match("%d+")) or 0
		saveConfig()
	end, false, "Example: Keep 10 means Auto Throw never spends your last 10 Super Throws")
	STATE.uiStatusLabels.throw = label(throwCard, "Status · " .. tostring(STATE.throwStatus), 12, accent, Enum.Font.GothamMedium, 18)
	STATE.uiStatusLabels.throw.LayoutOrder = 90
	end

	do
	local trainCard = card(pages.Farming, "TRAINING", 2)
	makeSwitch(trainCard, "Auto Train Throw Power", "autoTrain", "Auto Throw pauses while training is active")
	makeSwitch(trainCard, "Claim Training Bonuses", "autoTapBonus", "Claims the game's timed tap bonuses during Auto Train")
	makeSwitch(trainCard, "Stop at Target Power", "trainToTarget", "Stops training when the Throw Power shown on your HUD reaches the selected target")
	makeDropdown(trainCard, "Target Throw Power", function()
		return STATE.trainTargetPower
	end, TRAIN_TARGET_OPTIONS, function(option)
		STATE.trainTargetPower = option
		saveConfig()
	end, false, "Only used when Stop at Target Power is enabled")
	makeSwitch(trainCard, "Resume Auto Throw After Target", "resumeThrowAfterTraining", "Automatically returns to throwing after the target is reached")
	STATE.uiStatusLabels.training = label(trainCard, "Status · " .. tostring(STATE.trainingStatus), 12, accent, Enum.Font.GothamMedium, 18)
	STATE.uiStatusLabels.training.LayoutOrder = 90
	end

	do
	local targetCard = card(pages.Farming, "STOP ON TARGET CATCH", 3)
	makeSwitch(targetCard, "Stop on Minimum Rarity", "stopOnRarity", "Turns Auto Throw off when a new animal meets or exceeds your target rarity")
	makeDropdown(targetCard, "Minimum Target Rarity", function()
		return STATE.stopTargetRarity
	end, RARITY_OPTIONS, function(option)
		STATE.stopTargetRarity = option
		saveConfig()
	end, false, "Example: Mythic also stops for Secret, Divine and every higher rarity")
	makeSwitch(targetCard, "Stop on Selected Mutations", "stopOnMutation", "Turns Auto Throw off when a new animal has any selected mutation")
	makeMultiDropdown(targetCard, "Mutations That Stop Farming", function()
		return STATE.stopTargetMutations
	end, MUTATION_OPTIONS, function(option)
		toggleSelection("stopTargetMutations", option, MUTATION_OPTIONS)
	end, function(list)
		return selectedLabel(list, MUTATION_OPTIONS)
	end, "Rarity and mutation targets use OR: either match stops Auto Throw")
	end

	do
	local animalCard = card(pages.Animals, "ANIMALS", 1)
	makeSwitch(animalCard, "Keep Best Animals Equipped", "equipBest", "Keeps the strongest available animals earning money on your plot")
	makeSwitch(animalCard, "Hide Animal Models (FPS)", "hidePets", "Hides placed and carried animals locally but keeps catch reveals visible; nothing is unequipped or sold")
	STATE.uiStatusLabels.animals = label(animalCard, "Checking your animals...", 12, accent, Enum.Font.GothamMedium, 56)
	STATE.uiStatusLabels.animals.LayoutOrder = 90
	end

	do
	local espCard = card(pages.Animals, "ANIMAL ESP", 2)
	makeSwitch(espCard, "Animal ESP", "espEnabled", "Shows names, rarity, mutation, income, distance and owner through walls")
	makeSwitch(espCard, "Only Show My Animals", "espOwnOnly", "Hides ESP labels belonging to other players")
	makeSwitch(espCard, "Show All Matching Animals", "espAllAnimals", "Off shows only the strongest matching animal per plot to prevent label clutter")
	makeMultiDropdown(espCard, "Rarities to Display", function()
		return STATE.espRarities
	end, RARITY_OPTIONS, function(option)
		toggleSelection("espRarities", option, RARITY_OPTIONS)
	end, function(list)
		return selectedLabel(list, RARITY_OPTIONS)
	end, "Only selected rarities receive ESP labels")
	makeDropdown(espCard, "Maximum Display Distance", function()
		return STATE.espMaxDistance
	end, ESP_DISTANCE_OPTIONS, function(option)
		STATE.espMaxDistance = option
		saveConfig()
		task.defer(STATE.refreshEsp)
	end, false, "Animals farther away than this are hidden from ESP")
	STATE.uiStatusLabels.esp = label(espCard, STATE.espStatus or "ESP off", 12, accent, Enum.Font.GothamMedium, 18)
	STATE.uiStatusLabels.esp.LayoutOrder = 90
	end

	do
	local historyCard = card(pages.Animals, "RECENT CATCHES", 3)
	STATE.uiStatusLabels.history = label(historyCard, "No new animals caught during this session.", 12, ink, Enum.Font.Gotham, 48)
	STATE.uiStatusLabels.history.LayoutOrder = 1
	STATE.uiStatusLabels.history.AutomaticSize = Enum.AutomaticSize.Y
	STATE.uiStatusLabels.history.Size = UDim2.new(1, 0, 0, 0)
	end

	do
	local progressCard = card(pages.Progress, "UPGRADES", 1)
	makeSwitch(progressCard, "Auto Buy Food Upgrades", "autoFood", "Buys the next affordable food and equips your best owned food")
	makeSwitch(progressCard, "Auto Buy Training Stands", "autoStand", "Buys the next affordable training stand")
	makeSwitch(progressCard, "Auto Buy Plot Slots", "autoFence", "Upgrades the fence when affordable to unlock another animal slot")
	makeDropdown(progressCard, "Keep Cash Reserve", function()
		return STATE.cashReserve
	end, CASH_RESERVE_OPTIONS, function(option)
		STATE.cashReserve = option
		saveConfig()
	end, false, "Automatic upgrades never spend money below this amount")
	STATE.uiStatusLabels.upgrade = label(progressCard, "Status · " .. tostring(STATE.upgradeStatus), 12, accent, Enum.Font.GothamMedium, 38)
	STATE.uiStatusLabels.upgrade.LayoutOrder = 90
	end

	do
	local sellCard = card(pages.Selling, "SAFE AUTO SELL", 1)
	makeSwitch(sellCard, "Auto Sell Matching Backpack Animals", "autoSell", "Placed animals are always safe; only backpack animals passing every filter can be sold")
	makeMultiDropdown(sellCard, "Rarities Allowed to Sell", function()
		return STATE.sellRarities
	end, RARITY_OPTIONS, function(option)
		toggleSelection("sellRarities", option, RARITY_OPTIONS)
	end, function(list)
		return selectedLabel(list, RARITY_OPTIONS)
	end, "Checked means allowed to sell. Unchecked rarities are always protected")
	makeMultiDropdown(sellCard, "Never Sell These Mutations", function()
		return STATE.protectedMutations
	end, MUTATION_OPTIONS, function(option)
		toggleSelection("protectedMutations", option, MUTATION_OPTIONS)
	end, function(list)
		return selectedLabel(list, MUTATION_OPTIONS)
	end, "Selected mutations are protected even when their rarity is allowed to sell")
	makeDropdown(sellCard, "Keep Best Backpack Animals", function()
		return "Keep " .. tostring(STATE.keepBest)
	end, KEEP_BACKUP_OPTIONS, function(option)
		STATE.keepBest = tonumber(option:match("%d+")) or STATE.keepBest
		saveConfig()
	end, false, "Protects this many highest-income backpack animals in addition to every placed animal")
	makeDropdown(sellCard, "Auto Sell Interval", function()
		return "Every " .. tostring(STATE.sellMinutes) .. (STATE.sellMinutes == 1 and " minute" or " minutes")
	end, SELL_INTERVAL_OPTIONS, function(option)
		STATE.sellMinutes = tonumber(option:match("%d+")) or STATE.sellMinutes
		saveConfig()
	end, false, "How often Auto Sell checks for matching backpack animals")
	STATE.uiStatusLabels.sell = label(sellCard, "Checking protected animals...", 12, accent, Enum.Font.GothamMedium, 62)
	STATE.uiStatusLabels.sell.LayoutOrder = 90
	end

	do
	local rewardCard = card(pages.Progress, "REWARDS", 2)
	makeSwitch(rewardCard, "Claim Offline Earnings", "autoOffline", "Automatically claims pending offline animal income")
	makeSwitch(rewardCard, "Claim Free Animal", "autoFree", "Automatically claims the free shop animal when available")
	STATE.uiStatusLabels.reward = label(rewardCard, "Status · " .. tostring(STATE.rewardStatus), 12, accent, Enum.Font.GothamMedium, 18)
	STATE.uiStatusLabels.reward.LayoutOrder = 90
	end

	local notificationCard = card(pages.Settings, "NOTIFICATIONS", 1)
	makeSwitch(notificationCard, "Hub Notifications", "notifications", "Shows clean on-screen updates even while the dashboard is closed")
	makeSwitch(notificationCard, "Catch Notifications", "notifyCatches", "Shows the animal, mutation, rarity and income you just received")
	makeSwitch(notificationCard, "Sale Notifications", "notifySales", "Shows how many filtered animals Smart Sell removed")
	makeSwitch(notificationCard, "Upgrade & Reward Notifications", "notifyProgress", "Shows food, stand, fence, team and reward progress")
	local notificationNote
	makeDropdown(notificationCard, "Minimum Catch Rarity", function()
		return STATE.notifyMinRarity
	end, NOTIFY_RARITY_OPTIONS, function(option)
		STATE.notifyMinRarity = option
		if notificationNote then
			notificationNote.Text = option == "All" and "Catch filter · All catches" or ("Catch filter · " .. tostring(option) .. " and above")
		end
		saveConfig()
	end, false, "Only catch notifications at or above this rarity are shown")
	notificationNote = label(notificationCard, STATE.notifyMinRarity == "All" and "Catch filter · All catches" or ("Catch filter · " .. tostring(STATE.notifyMinRarity) .. " and above"), 12, accent, Enum.Font.GothamMedium, 18)
	notificationNote.LayoutOrder = 90

	local screenCard = card(pages.Settings, "DISPLAY", 2)
	makeDropdown(screenCard, "Hub Size", function()
		return STATE.hubSize or "Compact"
	end, { "Compact", "Normal", "Large" }, function(option)
		if STATE.hubSizes[option] then
			STATE.hubSize = option
		end
		saveConfig()
		fitScale()
		task.defer(function()
			if typeof(STATE.clampHub) == "function" then
				pcall(STATE.clampHub)
			end
		end)
	end, true, "Changes the dashboard size without affecting the game")

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

	local lookCard = card(pages.Settings, "THEME", 3)
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
	local welcome = label(intro, "ZinoosHub is ready", 22, ink, Enum.Font.GothamBold, 28)
	welcome.LayoutOrder = 1
	local blurb = label(intro, "Throw, train, upgrade and manage your animals from one clear dashboard.", 14, muted, Enum.Font.Gotham, 36)
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
	local solvesText = statChip(statGrid, "Money", 1)
	solvesText.Parent.Position = UDim2.fromOffset(0, 0)
	local movesText = statChip(statGrid, "Animals", 2)
	movesText.Parent.Position = UDim2.new(0.5, 5, 0, 0)
	local tableText = statChip(statGrid, "Food", 3)
	tableText.Parent.Position = UDim2.fromOffset(0, 68)
	local statusText = statChip(statGrid, "Stand / Fence", 4)
	statusText.Parent.Position = UDim2.new(0.5, 5, 0, 68)
	statusText.TextSize = 14
	statusText.TextTruncate = Enum.TextTruncate.AtEnd
	local refreshHealth = nil
	STATE.refreshHealth = nil

	local sessionCard = card(homePage, "SESSION RESULTS", 6)
	STATE.uiStatusLabels.session = label(sessionCard, "No new animals caught during this session.", 12, ink, Enum.Font.Gotham, 54)
	STATE.uiStatusLabels.session.LayoutOrder = 1
	STATE.uiStatusLabels.session.AutomaticSize = Enum.AutomaticSize.Y
	STATE.uiStatusLabels.session.Size = UDim2.new(1, 0, 0, 0)

	local note = card(homePage, "HOW IT WORKS", 7)
	local noteBody = label(note, "Auto Throw repeats normal throws. Automatic upgrades respect your cash reserve. Safe Auto Sell only sells matching backpack animals after protecting placed animals, your best backups and selected mutations.", 13, ink, Enum.Font.Gotham, 72)
	noteBody.LayoutOrder = 1

	local activityCard = card(homePage, "ACTIVITY", 8)
	local activityBody = label(activityCard, "Waiting for the next thing the hub does.", 13, muted, Enum.Font.Gotham, 72)
	activityBody.LayoutOrder = 1
	activityBody.AutomaticSize = Enum.AutomaticSize.Y
	activityBody.Size = UDim2.new(1, 0, 0, 0)
	activityBody.TextWrapped = true
	remember(activityBody, activityCard, "activity status solves")
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
	local function refreshActivity()
		local lines = {
			"Status · " .. tostring(STATE.status),
			"Throwing · " .. tostring(STATE.throwStatus),
			"Training · " .. tostring(STATE.trainingStatus),
			"Upgrades · " .. tostring(STATE.upgradeStatus),
			"Selling · " .. tostring(STATE.sellStatus),
			"Rewards · " .. tostring(STATE.rewardStatus),
			string.format("Session · %d throws, %d catches, %d training starts, %d bonuses, %d upgrades, %d sold", stats.throws, stats.catches, stats.trained, stats.bonuses, stats.foods + stats.stands + stats.fences, stats.sold),
		}
		if STATE.antiAfk == true then
			lines[#lines + 1] = STATE.antiAfkOperational == true and "Anti AFK active" or "Anti AFK waiting for idle"
		end
		if #STATE.activity > 0 then
			lines[#lines + 1] = table.concat(STATE.activity, "\n")
		end
		local text = table.concat(lines, "\n")
		if activityBody.Text ~= text then activityBody.Text = text end
		activityBody.TextColor3 = STATE.hubThemeDef().ink
		STATE.uiStatusLabels.throw.Text = "Status · " .. publicStatus(STATE.throwStatus)
		STATE.uiStatusLabels.training.Text = "Status · " .. publicStatus(STATE.trainingStatus)
		local foodLevel = DataController:GetValue("EquippedFood") or 0
		local standLevel = DataController:GetValue("Stand") or 0
		local fenceLevel = DataController:GetValue("FenceLevel") or 0
		elevate()
		STATE.uiStatusLabels.upgrade.Text = string.format("%s\nFood %s · Stand %s · Fence %s", publicStatus(STATE.upgradeStatus), tostring(foodLevel), tostring(standLevel), tostring(fenceLevel))
		STATE.uiStatusLabels.reward.Text = "Status · " .. publicStatus(STATE.rewardStatus)
		local preview = STATE.sellPreview()
		elevate()
		if preview then
			local warning = STATE.sellRiskWarning()
			STATE.uiStatusLabels.sell.Text = string.format(
				"%s\n%d ready to sell · %d allowed rarities\n%d best backups safe · %d mutations safe · placed animals always safe%s",
				publicStatus(STATE.sellStatus),
				preview.eligible,
				#STATE.sellRarities,
				preview.protectedBest,
				preview.protectedMutation,
				warning and ("\n" .. warning) or ""
			)
			STATE.uiStatusLabels.sell.TextColor3 = warning and risky or accent
		else
			STATE.uiStatusLabels.sell.Text = publicStatus(STATE.sellStatus)
		end
		local historyLines = {}
		for index = 1, math.min(6, #STATE.catchHistory) do
			local catch = STATE.catchHistory[index]
			historyLines[#historyLines + 1] = string.format("%d. %s · %s", index, tostring(catch.title), tostring(catch.message))
		end
		STATE.uiStatusLabels.history.Text = #historyLines > 0
			and table.concat(historyLines, "\n")
			or "No new animals caught during this session."
		STATE.uiStatusLabels.session.Text = string.format(
			"%d new animals · %d target stops\nRarities: %s\nMutations: %s",
			stats.catches,
			stats.targetStops,
			countSummary(stats.rarityCounts, RARITY_OPTIONS),
			countSummary(stats.mutationCounts, MUTATION_OPTIONS)
		)
		local animals = DataController:GetValue("Animals")
		elevate()
		local animalCount, placedCount = 0, 0
		if type(animals) == "table" then
			for _, entry in pairs(animals) do
				if type(entry) == "table" then
					animalCount += 1
					if entry.Placed then placedCount += 1 end
				end
			end
		end
		STATE.uiStatusLabels.animals.Text = string.format("Equip · %s\n%d animals · %d placed · %d backpack\n%s", publicStatus(STATE.equipStatus or "Ready"), animalCount, placedCount, animalCount - placedCount, STATE.petVisibilityStatus or "Checking animal visibility")
		if STATE.uiStatusLabels.esp then
			STATE.uiStatusLabels.esp.Text = STATE.espStatus or "ESP off"
		end
		if STATE.uiStatusLabels.potato then
			STATE.uiStatusLabels.potato.Text = STATE.potatoStatus or "Potato Mode off"
		end
	end
	STATE.refreshActivity = refreshActivity

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
	actionButton(notificationCard, "Test Notification", 91, false, function()
		notify("system", "Notifications are working", "ZinoosHub will show catches, sales and progress here")
	end)
	local playerSlot = Instance.new("Frame")
	playerSlot.BackgroundTransparency = 1
	playerSlot.BorderSizePixel = 0
	playerSlot.LayoutOrder = 1
	playerSlot.AutomaticSize = Enum.AutomaticSize.Y
	playerSlot.Size = UDim2.new(1, 0, 0, 0)
	playerSlot:SetAttribute("ZinoosSlot", true)
	playerSlot.Parent = playerPage
	local playerMotion = Instance.new("CanvasGroup")
	playerMotion.Name = "Motion"
	playerMotion.BackgroundTransparency = 1
	playerMotion.AutomaticSize = Enum.AutomaticSize.Y
	playerMotion.Size = UDim2.new(1, 0, 0, 0)
	playerMotion.Parent = playerSlot
	local playerBlurb = label(playerMotion, "Movement and client options. WalkSpeed is left alone while you are seated.", 14, muted, Enum.Font.Gotham, 36)
	playerBlurb.LayoutOrder = 1

	local movement = card(playerPage, "MOVEMENT", 2)
	makeSwitch(movement, "Custom Walk Speed", "walkSpeed", "Overrides your normal walking speed while enabled")
	makeDropdown(movement, "Walk Speed", function()
		return tostring(STATE.speed)
	end, SPEED_OPTIONS, function(option)
		STATE.speed = tonumber(option) or STATE.speed
		saveConfig()
	end, false, "16 is the game's normal walking speed")
	makeSwitch(movement, "Infinite Jump", "infiniteJump", "Allows another jump while you are already in the air")
	makeSwitch(movement, "Noclip", "noclip", "Lets your character move through walls and objects")
	makeSwitch(movement, "Instant Interactions", "instantPrompts", "Removes the hold time from proximity prompts")

	local flyCard = card(playerPage, "FLY", 3)
	makeSwitch(flyCard, "Fly", "fly", "WASD to move, Space up, Left Ctrl down")
	makeDropdown(flyCard, "Fly Speed", function()
		return tostring(STATE.flySpeed)
	end, FLY_SPEED_OPTIONS, function(option)
		STATE.flySpeed = tonumber(option) or STATE.flySpeed
		saveConfig()
	end, false, "Higher values move your character faster while Fly is enabled")

	local clientCard = card(playerPage, "CLIENT", 4)
	makeSwitch(clientCard, "Anti AFK", "antiAfk", "Stays in the game while you are idle")
	makeSwitch(clientCard, "Hide Roblox Pause Popup", "noPausePopup", "Hides the Gameplay Paused message while Roblox is unfocused")
	makeSwitch(clientCard, "Auto Reconnect on Kick", "autoReconnect", "Rejoins the game when you get disconnected")
	makeSwitch(clientCard, "AFK Black Screen — Maximum FPS", "disable3d", "Stops rendering the 3D world while automation continues; turn it off to see the game again")
	makeSwitch(clientCard, "Potato Mode", "fpsBoost", "Reversible low-detail mode: strips textures, smooths materials, disables effects, clouds, environment lighting, water effects and shadows")
	makeSwitch(clientCard, "Hide UI On Start", "hideOnStart", "Starts hidden. Press the toggle key to show it")
	makeDropdown(clientCard, "Toggle Key", function()
		return STATE.toggleKey
	end, KEY_OPTIONS, function(option)
		STATE.toggleKey = option
		saveConfig()
	end, false, "Keyboard key used to open or hide the dashboard")
	STATE.uiStatusLabels.potato = label(clientCard, STATE.potatoStatus or "Potato Mode off", 12, accent, Enum.Font.GothamMedium, 18)
	STATE.uiStatusLabels.potato.LayoutOrder = 90

	local serverCard = card(playerPage, "SERVER", 5)
	local serverNote = label(serverCard, "Job " .. string.sub(game.JobId, 1, 8) .. "...  ·  Place " .. tostring(game.PlaceId), 12, muted, Enum.Font.Gotham, 16)
	serverNote.LayoutOrder = 1
	actionButton(serverCard, "Rejoin", 2, false, function()
		STATE.rejoin()
	end)
	actionButton(serverCard, "Server Hop", 3, false, function()
		if not STATE.hop(false) then
			serverNote.Text = "No other server found"
		end
	end)
	actionButton(serverCard, "Lowest Server", 4, false, function()
		if not STATE.hop(true) then
			serverNote.Text = "No other server found"
		end
	end)
	actionButton(serverCard, "Copy Job ID", 5, false, function()
		serverNote.Text = STATE.copyJobId() and "Job ID copied" or "Copy is not available"
	end)
	actionButton(serverCard, "Unload", 6, true, function()
		task.defer(unloadHub)
	end)

	local function applySearch()
		local query = string.lower(search.Text)
		local used = {}
		local matchingPages = {}
		for _, item in ipairs(searchRows) do
			local show = query == "" or string.find(item.text, query, 1, true) ~= nil
			item.row.Visible = show
			if show and query ~= "" then
				used[item.card] = true
				matchingPages[item.page or "Dashboard"] = true
			end
		end
		for _, item in ipairs(searchRows) do
			item.card.Visible = query == "" or used[item.card] == true
		end
		if query == "" then
			return
		end
		if matchingPages[currentPage] then
			return
		end
		for _, name in ipairs({ "Dashboard", "Farming", "Animals", "Progress", "Selling", "Player", "Settings" }) do
			if matchingPages[name] then
				showPage(name)
				break
			end
		end
	end
	trackConnection(search:GetPropertyChangedSignal("Text"):Connect(applySearch))
	local function refreshHome()
		local money = DataController:GetValue("Money")
		local animals = DataController:GetValue("Animals")
		local animalCount = 0
		if type(animals) == "table" then
			for _ in pairs(animals) do animalCount += 1 end
		end
		local food = DataController:GetValue("EquippedFood") or 0
		local stand = DataController:GetValue("Stand") or 0
		local fence = DataController:GetValue("FenceLevel") or 0
		elevate()
		solvesText.Text = "$" .. STATE.shortNumber(money)
		movesText.Text = tostring(animalCount)
		tableText.Text = "Level " .. tostring(food)
		statusText.Text = tostring(stand) .. " / " .. tostring(fence)
	end
	refreshHome()
	refreshActivity()
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
		elevate()
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
			pcall(refreshActivity)
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

	showPage("Dashboard")

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
	STATE.clampHub = function()
		clampObject(holder)
		if launcher then
			clampObject(launcher)
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
		sideWrap.Size = compact and UDim2.new(0, 72, 1, 0) or UDim2.new(0.25, 0, 1, 0)
		content.Position = compact and UDim2.fromOffset(72, 0) or UDim2.new(0.25, 0, 0, 0)
		content.Size = compact and UDim2.new(1, -72, 1, 0) or UDim2.new(0.75, 0, 1, 0)
		brand.Visible = not compact
		brandSub.Visible = not compact
		profile.Visible = not compact
		for index, name in ipairs({ "Dashboard", "Farming", "Animals", "Progress", "Selling", "Player", "Settings" }) do
			local button = navButtons[name]
			if button then
				local label = button:FindFirstChild("Label")
				if label then
					label.Visible = not compact
				end
				button.Size = compact and UDim2.fromOffset(48, 42) or UDim2.new(1, -24, 0, 36)
				button.Position = UDim2.fromOffset(12, compact and (60 + (index - 1) * 46) or (70 + (index - 1) * 42))
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

	bindPress(launcherOpenButton)
	onActivate(launcherOpenButton, function()
		setOpen(true)
	end)
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
		if processed or search:IsFocused() then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftControl then
			gui.Enabled = not gui.Enabled
			return
		end
		if input.KeyCode.Name == STATE.toggleKey then
			setOpen(not holder.Visible)
		end
	end))

	do
	local function applyPreset(values, name)
		for key, value in pairs(values) do
			STATE[key] = value
			if syncToggle then syncToggle(key) end
		end
		if STATE.autoTrain ~= true then
			task.spawn(stopTraining)
		end
		nextSellAt = 0
		saveConfig()
		STATE.status = name .. " preset active"
		noteActivity(STATE.status)
	end

	local quickCard = card(homePage, "QUICK START", 5)
	local quickNote = label(quickCard, "Choose a safe starting point. You can still change every option afterwards.", 12, muted, Enum.Font.Gotham, 34)
	quickNote.LayoutOrder = 1
	actionButton(quickCard, "Safe AFK — No Auto Sell", 2, true, function()
		applyPreset({
			autoThrow = true, perfectMeter = true, autoSkip = true, autoSuper = false,
			autoTrain = false, autoTapBonus = true, autoFood = true, autoStand = true,
			autoFence = true, equipBest = true, autoSell = false,
			autoOffline = true, autoFree = true,
		}, "Safe AFK")
		quickNote.Text = "Safe AFK enabled · protected selling remains off"
	end)
	actionButton(quickCard, "Fast Progress — No Auto Sell", 3, false, function()
		applyPreset({
			autoThrow = true, perfectMeter = true, autoSkip = true, autoSuper = true,
			autoTrain = false, autoTapBonus = true, autoFood = true, autoStand = true,
			autoFence = true, equipBest = true, autoSell = false,
			autoOffline = true, autoFree = true,
		}, "Fast Progress")
		quickNote.Text = "Fast Progress enabled · review Safe Auto Sell filters before turning selling on"
	end)
	actionButton(quickCard, "Stop Automation", 4, false, function()
		applyPreset({
			autoThrow = false, autoTrain = false, autoFood = false, autoStand = false,
			autoFence = false, equipBest = false, autoSell = false,
			autoOffline = false, autoFree = false,
		}, "Stopped")
		quickNote.Text = "All game automation stopped"
	end)

	local actionsCard = card(homePage, "MANUAL ACTIONS", 9)
	local actionsNote = label(actionsCard, "Run these now instead of waiting for the next pass.", 12, muted, Enum.Font.Gotham, 16)
	actionsNote.LayoutOrder = 1
	local sellConfirmUntil = 0
	actionButton(actionsCard, "Sell Matching Animals Now", 2, true, function()
		local preview = STATE.sellPreview()
		if not preview or preview.eligible <= 0 then
			sellConfirmUntil = 0
			actionsNote.Text = "Nothing matches your current Safe Auto Sell filters"
			return
		end
		if os.clock() > sellConfirmUntil then
			sellConfirmUntil = os.clock() + 6
			local warning = STATE.sellRiskWarning()
			actionsNote.Text = string.format(
				"Preview: %d backpack animals will be sold. Click again within 6 seconds to confirm.%s",
				preview.eligible,
				warning and (" " .. warning) or ""
			)
			return
		end
		sellConfirmUntil = 0
		task.spawn(function()
			local sold = STATE.sellJunkNow(true)
			actionsNote.Text = sold > 0 and ("Sold " .. sold .. " matching backpack animals") or tostring(STATE.sellStatus)
		end)
	end)
	actionButton(actionsCard, "Equip Best Now", 3, false, function()
		task.spawn(function()
			actionsNote.Text = STATE.equipBestNow() and "Best animals equipped" or "Equip Best was rejected"
		end)
	end)

	actionButton(actionsCard, "Teleport To Throw Line", 4, false, function()
		actionsNote.Text = STATE.teleportTo("Throw") and "Moved to throw line" or "Throw line unavailable"
	end)
	actionButton(actionsCard, "Teleport To Shop", 5, false, function()
		actionsNote.Text = STATE.teleportTo("Shop") and "Moved to food shop" or "Shop unavailable"
	end)
	actionButton(actionsCard, "Teleport To Training", 6, false, function()
		actionsNote.Text = STATE.teleportTo("Training") and "Moved to training" or "Training unavailable"
	end)
	actionButton(actionsCard, "Teleport To Sell", 7, false, function()
		actionsNote.Text = STATE.teleportTo("Sell") and "Moved to sell shop" or "Sell shop unavailable"
	end)
	end
	do
		local discordInvite = "https://discord.gg/94pC3T6NZG"
		local communityCard = card(pages.Settings, "COMMUNITY", 4)
		local communityNote = label(communityCard, "Join the ZinoosHub Discord for updates, support and new games.", 13, muted, Enum.Font.Gotham, 36)
		communityNote.LayoutOrder = 1
		local communityResult = label(communityCard, "", 13, accent, Enum.Font.Gotham, 18)
		communityResult.LayoutOrder = 3
		actionButton(communityCard, "Copy Discord Invite", 2, true, function()
			if typeof(setclipboard) == "function" and pcall(setclipboard, discordInvite) then
				communityResult.Text = "Invite copied. Paste it in your browser."
			else
				communityResult.Text = discordInvite
			end
		end)
	end

	do
	local compatibilityCard = card(pages.Settings, "DIAGNOSTICS", 6)
	local capabilityLines = {
		"Executor · connected",
		"Config saving · " .. ((typeof(writefile) == "function" and typeof(readfile) == "function") and "available" or "unavailable"),
		"Clipboard · " .. (typeof(setclipboard) == "function" and "available" or "unavailable"),
		"Reconnect queue · " .. ((typeof(queue_on_teleport) == "function" or (syn and typeof(syn.queue_on_teleport) == "function")) and "available" or "unavailable"),
	}
	local compatibilityText = label(compatibilityCard, table.concat(capabilityLines, "\n"), 13, ink, Enum.Font.Gotham, 74)
	compatibilityText.LayoutOrder = 1
	end

	do
	local saveCard = card(pages.Settings, "CONFIG & RESET", 5)
	local saveNote = label(saveCard, "Changes save automatically for this Roblox account. Save Again forces an immediate write.", 13, muted, Enum.Font.Gotham, 40)
	saveNote.LayoutOrder = 1
	local saveResult = label(saveCard, "", 13, accent, Enum.Font.Gotham, 18)
	saveResult.LayoutOrder = 4
	actionButton(saveCard, "Save Again", 2, true, function()
		saveConfig()
		saveResult.Text = "Saved for " .. LocalPlayer.DisplayName
		saveResult.TextColor3 = accent
	end)
	local resetConfirmUntil = 0
	actionButton(saveCard, "Reset to Safe Defaults", 3, false, function()
		if os.clock() > resetConfirmUntil then
			resetConfirmUntil = os.clock() + 6
			saveResult.Text = "Click Reset again within 6 seconds to confirm"
			saveResult.TextColor3 = risky
			return
		end
		resetConfirmUntil = 0
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
		}
		for key, value in pairs(safeValues) do
			STATE[key] = value
			if syncToggle then syncToggle(key) end
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
		saveResult.Text = "Safe defaults restored · Auto Sell is off"
		saveResult.TextColor3 = accent
	end)
	end

	windowScale.Scale = 0.9
	sideWrap.GroupTransparency = 1
	headWrap.GroupTransparency = 1
	pageWrap.GroupTransparency = 1
	holder.Visible = false
	shadow.Visible = false
	launcher.Visible = STATE.hideOnStart ~= true
	dockHint.Text = "Open dashboard · " .. tostring(STATE.toggleKey)

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
	while running() do
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
		task.wait(4 * 60)
		pulseAntiAfk()
	end
end)
