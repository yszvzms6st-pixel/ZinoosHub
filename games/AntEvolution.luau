-- Zinoos hub for Ant Evolution.
-- Same WindUI window as Throw Food For Animals. The farm steps you onto nearby food
-- and lets the game collect it, then evolves, rebirths, hatches and claims.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

if game.GameId ~= 10773487349 then
	warn("[Zinoos hub] This only runs in Ant Evolution.")
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
if typeof(genv.ZinoosAntStop) == "function" then
	pcall(genv.ZinoosAntStop)
	elevate()
end
genv.ZinoosAntGen = (typeof(genv.ZinoosAntGen) == "number" and genv.ZinoosAntGen or 0) + 1
local token = genv.ZinoosAntGen
local function running()
	return genv.ZinoosAntGen == token
end

local STATE = {
	_gen = token,
	autoOrb = true,
	autoBite = true,
	autoAbility = true,
	autoPvp = false,
	critterEsp = true,
	playerEsp = true,
	autoEvolve = true,
	autoRebirth = true,
	autoHatch = true,
	egg = "Royal",
	autoEquip = true,
	autoFuse = false,
	autoBestBreed = true,
	autoRoll = false,
	autoMutations = false,
	rollSize = "1",
	breed = "Keep",
	autoClaim = true,
	autoCodes = true,
	autoUpgrade = false,
	upgradeJaws = true,
	upgradeShell = true,
	upgradeLegs = true,
	upgradeMagnet = true,
	upgradeAppetite = true,
	upgradeRegen = true,
	dnaReserve = "1000",
	smartEvents = true,
	questAssist = true,
	pvpQuest = false,
	luckyRollsOnly = false,
	rollTargetRarity = "Off",
	rollTargetMutation = "Off",
	petTarget = "Off",
	autoBattlePass = true,
	autoKillRewards = true,
	autoWorms = true,
	autoPowerUps = true,
	autoLostEggs = true,
	autoMole = false,
	moleItem = "Roll",
	wormReserve = "0",
	autoDungeon = false,
	autoCosmeticCrates = false,
	cosmeticSlot = "Aura",
	godStyle = "Sky",
	autoBestAura = false,
	blockRobuxCapsule = true,
	godMode = true,
	walkSpeed = false,
	speed = 32,
	antiAfk = true,
	infiniteJump = false,
	infiniteStamina = false,
	noclip = false,
	instantPrompts = false,
	fly = false,
	autoSprint = false,
	chaseBugs = false,
	flySpeed = 60,
	noPausePopup = true,
	autoReconnect = false,
	autoReload = true,
	ghostWhenStuck = false,
	disable3d = false,
	fpsBoost = false,
	hideOnStart = false,
	streamerMode = false,
	toggleKey = "RightControl",
	toggleControls = {},
	themeSwitches = {},
	status = "Starting",
	detail = "",
	power = 0,
	stageName = "",
	rebirths = 0,
	dna = 0,
}
genv.ZinoosAntState = STATE

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

local function destroyMenus()
	for _, root in ipairs({ CoreGui, typeof(gethui) == "function" and gethui() or nil }) do
		local old = root and root:FindFirstChild("ZinoosAntMenu")
		if old then
			old:Destroy()
		end
	end
end

local function shutdownHub()
	if genv.ZinoosAntGen == token then
		genv.ZinoosAntGen = token + 1
	end
	STATE._unloaded = true
	-- A task can already be inside its loop body when the generation changes.
	-- Turn off client mutations before restoring them so that final iteration
	-- cannot apply them again after the cleanup handlers have run.
	STATE.walkSpeed = false
	STATE.noclip = false
	STATE.instantPrompts = false
	STATE.fly = false
	STATE.autoSprint = false
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
	destroyMenus()
end
genv.ZinoosAntStop = shutdownHub
local function unloadHub()
	shutdownHub()
end

local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/AntEvolution_" .. tostring(LocalPlayer.UserId) .. ".rfld"
local SPEED_OPTIONS = { "16", "24", "32", "50", "75", "100" }

local FLAG_KEYS = {
	AutoOrb = "autoOrb",
	AutoBite = "autoBite",
	AutoAbility = "autoAbility",
	AutoPvp = "autoPvp",
	CritterEsp = "critterEsp",
	PlayerEsp = "playerEsp",
	AutoEvolve = "autoEvolve",
	AutoRebirth = "autoRebirth",
	AutoHatch = "autoHatch",
	AutoEquip = "autoEquip",
	AutoFuse = "autoFuse",
	AutoBestBreed = "autoBestBreed",
	AutoRoll = "autoRoll",
	AutoMutations = "autoMutations",
	AutoClaim = "autoClaim",
	AutoCodes = "autoCodes",
	AutoUpgrade = "autoUpgrade",
	UpgradeJaws = "upgradeJaws",
	UpgradeShell = "upgradeShell",
	UpgradeLegs = "upgradeLegs",
	UpgradeMagnet = "upgradeMagnet",
	UpgradeAppetite = "upgradeAppetite",
	UpgradeRegen = "upgradeRegen",
	SmartEvents = "smartEvents",
	QuestAssist = "questAssist",
	PvpQuest = "pvpQuest",
	LuckyRollsOnly = "luckyRollsOnly",
	AutoBattlePass = "autoBattlePass",
	AutoKillRewards = "autoKillRewards",
	AutoWorms = "autoWorms",
	AutoPowerUps = "autoPowerUps",
	AutoLostEggs = "autoLostEggs",
	AutoMole = "autoMole",
	AutoDungeon = "autoDungeon",
	AutoCosmeticCrates = "autoCosmeticCrates",
	AutoBestAura = "autoBestAura",
	BlockRobuxCapsule = "blockRobuxCapsule",
	GodMode = "godMode",
	WalkSpeed = "walkSpeed",
	AntiAfk = "antiAfk",
	InfiniteJump = "infiniteJump",
	InfiniteStamina = "infiniteStamina",
	Noclip = "noclip",
	InstantPrompts = "instantPrompts",
	Fly = "fly",
	AutoSprint = "autoSprint",
	ChaseBugs = "chaseBugs",
	NoPausePopup = "noPausePopup",
	AutoReconnect = "autoReconnect",
	AutoReload = "autoReload",
	GhostWhenStuck = "ghostWhenStuck",
	Disable3d = "disable3d",
	FpsBoost = "fpsBoost",
	HideOnStart = "hideOnStart",
	StreamerMode = "streamerMode",
	Notifications = "notifications",
}

local FLY_SPEED_OPTIONS = { "30", "60", "100", "150", "200" }
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
local EGG_OPTIONS = { "Best Affordable", "Royal", "Colony" }
local RESERVE_OPTIONS = { "0", "250", "500", "1000", "2500", "5000", "10000", "25000", "50000" }
local WORM_RESERVE_OPTIONS = { "0", "10", "15", "30", "45", "60", "90" }
local MOLE_OPTIONS = { "Roll", "Egg", "Power", "Luck", "Royal", "Rolls5", "Drizzle", "Puddle" }
local COSMETIC_SLOTS = { "Aura", "Trail", "Hat", "Face", "Back", "Mouth" }
local CHOICES = {
	ToggleKey = { key = "toggleKey", options = KEY_OPTIONS },
	Egg = { key = "egg", options = EGG_OPTIONS },
	RollSize = { key = "rollSize", options = { "1", "5" } },
	Breed = { key = "breed" },
	DnaReserve = { key = "dnaReserve", options = RESERVE_OPTIONS },
	WormReserve = { key = "wormReserve", options = WORM_RESERVE_OPTIONS },
	MoleItem = { key = "moleItem", options = MOLE_OPTIONS },
	CosmeticSlot = { key = "cosmeticSlot", options = COSMETIC_SLOTS },
	GodStyle = { key = "godStyle", options = { "Sky", "Safe Zone" } },
	RollTargetRarity = { key = "rollTargetRarity", options = { "Off", "Legendary", "Mythic", "Secret" } },
	RollTargetMutation = { key = "rollTargetMutation" },
	PetTarget = { key = "petTarget" },
	WindTheme = { key = "windTheme" },
	HubSize = { key = "hubSize", options = { "Compact", "Normal", "Large" } },
}
STATE.LIST_KEYS = {}
local NUMBERS = { FlySpeed = { "flySpeed", 10, 300 } }
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

function STATE.themeStillCurrent(gen, tokenNow)
	return running() and STATE._gen == gen and genv.ZinoosAntGen == tokenNow and STATE._unloaded ~= true
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
	token = token or genv.ZinoosAntGen
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
	local token = genv.ZinoosAntGen
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
	if ok and type(saved) == "table" and type(saved.ThemeData) == "table" then
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
			local list = {}
			for _, value in ipairs(saved[flag]) do
				if type(value) == "string" then
					table.insert(list, value)
				end
			end
			STATE[key] = list
		end
	end
	if saved.HubSize == "Compact" or saved.HubSize == "Normal" or saved.HubSize == "Large" then
		STATE.hubSize = saved.HubSize
	end
	if type(saved.ThemeData) == "table" then
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
		Speed = STATE.speed,
		HubSize = STATE.hubSize or "Compact",
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
local stats = { eggs = 0, placed = 0, fused = 0, sold = 0, soldCash = 0, guardBlocks = 0, bonuses = 0, rebirths = 0 }
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

local function humanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function seated()
	local hum = humanoid()
	return hum ~= nil and hum.SeatPart ~= nil
end

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
	local hum = humanoid()
	if hum and STATE.walkSpeed == true and not seated() then
		if walkSpeedsBefore[hum] == nil then
			walkSpeedsBefore[hum] = hum.WalkSpeed
		end
		hum.WalkSpeed = STATE.speed
	end
end

local staminaBags
local function staminaBag(fn)
	if typeof(fn) ~= "function" then
		return nil
	end
	for index = 1, 12 do
		local ok, value = pcall(debug.getupvalue, fn, index)
		if not ok then
			break
		end
		if type(value) == "table" and type(value.stamina) == "number" then
			return value
		end
	end
	return nil
end

local function fillStamina()
	if STATE.infiniteStamina ~= true then
		return
	end
	if staminaBags == nil then
		staminaBags = {}
		local ok, sprint, flight = pcall(function()
			return require(ReplicatedStorage.Ant.Client.Sprint), require(ReplicatedStorage.Ant.Client.Flight)
		end)
		if ok then
			staminaBags.sprint = staminaBag(sprint.Start)
			staminaBags.flight = staminaBag(flight.Start)
		end
	end
	local sprintBag = staminaBags.sprint
	if sprintBag then
		sprintBag.stamina = 1
		sprintBag.winded = false
	end
	local flightBag = staminaBags.flight
	if flightBag then
		flightBag.stamina = 1000
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
	-- The game has its own AFK check (Ant.Client.AfkRejoin: 19.5 minutes
	-- with no UserInputService input, then it moves you to another server).
	-- VirtualUser does not count for it, so also send a mouse move to where
	-- the mouse already is, and reset the game's own timer as a backup.
	local reset = pcall(function()
		local mouse = UserInputService:GetMouseLocation()
		game:GetService("VirtualInputManager"):SendMouseMoveEvent(mouse.X, mouse.Y, game)
	end)
	pcall(function()
		local afk = ReplicatedStorage:FindFirstChild("Ant")
		afk = afk and afk:FindFirstChild("Client")
		afk = afk and afk:FindFirstChild("AfkRejoin")
		if not afk or typeof(debug.getupvalues) ~= "function" then
			return
		end
		local module = require(afk) :: any
		if type(module) ~= "table" or type(module.Start) ~= "function" then
			return
		end
		for _, value in pairs(debug.getupvalues(module.Start)) do
			if type(value) == "table" and type(value.lastInput) == "number" then
				value.lastInput = os.clock()
				value.asked = false
				reset = true
			end
		end
	end)
	STATE.antiAfkOperational = ok or reset
	return ok or reset
end

local function shortNumber(value)
	value = tonumber(value) or 0
	local sign = value < 0 and "-" or ""
	value = math.abs(value)
	if value >= 1e6 then
		return sign .. string.format("%.2fM", value / 1e6)
	end
	if value >= 1e3 then
		return sign .. string.format("%.1fK", value / 1e3)
	end
	return sign .. tostring(math.floor(value))
end
STATE.shortNumber = shortNumber

local Net = require(ReplicatedStorage:WaitForChild("Ant"):WaitForChild("Net"))
local Config = require(ReplicatedStorage:WaitForChild("Ant"):WaitForChild("Config"))
local GameState = require(ReplicatedStorage:WaitForChild("Ant"):WaitForChild("Client"):WaitForChild("State"))
local Content = require(ReplicatedStorage:WaitForChild("Ant"):WaitForChild("Content"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Ant"):WaitForChild("Cosmetics"))
local EventsConfig = require(ReplicatedStorage:WaitForChild("Ant"):WaitForChild("EventsConfig"))

-- The game's EvoOrb client periodically spawns a local "+3 EVO" capsule near the
-- player. Touching it opens a developer-product prompt without a button click, so
-- an automated character can trigger it by simply farming nearby. Disable only
-- that local capsule while the protection is on; normal DNA/worm purchases remain
-- untouched because they never use MarketplaceService.
local evoOrbState
local evoOrbWasSuppressed = false
local function findEvoOrbState()
	if type(evoOrbState) == "table" then
		return evoOrbState
	end
	local okModule, module = pcall(function()
		return require(ReplicatedStorage.Ant.Client.EvoOrb)
	end)
	if not okModule or type(module) ~= "table" or typeof(module.Start) ~= "function" then
		return nil
	end
	local okUpvalues, upvalues = pcall(debug.getupvalues, module.Start)
	if not okUpvalues or type(upvalues) ~= "table" then
		return nil
	end
	for _, value in pairs(upvalues) do
		if type(value) == "table"
			and type(value.nextAt) == "number"
			and type(value.parts) == "table"
			and (value.conn == nil or typeof(value.conn) == "RBXScriptConnection") then
			evoOrbState = value
			return value
		end
	end
	return nil
end

local function suppressRobuxCapsule()
	local capsule = findEvoOrbState()
	if not capsule then
		STATE.robuxCapsuleBlocked = false
		return
	end
	if STATE.blockRobuxCapsule ~= true then
		if evoOrbWasSuppressed then
			capsule.prompted = false
			capsule.nextAt = os.clock() + 5
			evoOrbWasSuppressed = false
		end
		STATE.robuxCapsuleBlocked = false
		return
	end
	local model = capsule.model
	capsule.model = nil
	capsule.parts = {}
	capsule.at = nil
	capsule.prompted = true
	capsule.nextAt = math.huge
	evoOrbWasSuppressed = true
	STATE.robuxCapsuleBlocked = true
	if typeof(model) == "Instance" and model.Parent then
		model:Destroy()
	end
end

hubCleanup(function()
	if type(evoOrbState) == "table" and evoOrbWasSuppressed then
		evoOrbState.prompted = false
		evoOrbState.nextAt = os.clock() + 5
	end
end)

local globalValue, activeEvent, dungeonState, inDungeon, activeQuestKeys, questNeeds, dnaAvailable

local function invoke(name, ...)
	local packed = table.pack(...)
	task.spawn(function()
		if not running() then
			return
		end
		pcall(function()
			Net.Get(name):InvokeServer(table.unpack(packed, 1, packed.n))
		end)
	end)
end

local function invokeResult(name, ...)
	if not running() then
		return false, nil
	end
	local packed = table.pack(...)
	local ok, result = pcall(function()
		return Net.Get(name):InvokeServer(table.unpack(packed, 1, packed.n))
	end)
	return ok and result ~= false, result
end

local farm = {
	orbs = {},
	eat = nil :: any,
	ready = false,
	nextRefresh = 0,
	skip = {},
	chase = nil,
	powerUpSkip = {},
	powerUpChase = nil,
	esp = {},
	codesDone = false,
	communityDone = false,
	nextEvolve = 0,
	nextHatch = 0,
	nextEquip = 0,
	nextFuse = 0,
	nextBreed = 0,
	nextRoll = 0,
	nextMutations = 0,
	nextClaim = 0,
	claiming = false,
	nextCommunity = 0,
	nextBite = 0,
	nextAbility = 0,
	nextEsp = 0,
	nextUpgrade = 0,
	nextPass = 0,
	nextKillClaim = 0,
	nextMole = 0,
	nextCosmetic = 0,
	nextAura = 0,
	dungeonEnterAt = 0,
	godRecovering = false,
	godHold = nil,
	godReturn = nil,
	godEscapes = 0,
}

local function readJson(value)
	if type(value) == "table" then
		return value
	end
	if type(value) ~= "string" or value == "" then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(value)
	end)
	if ok and type(decoded) == "table" then
		return decoded
	end
	return nil
end

local function stateJson(name)
	local ok, value = pcall(function()
		return GameState.Json(name)
	end)
	if ok and type(value) == "table" then
		return value
	end
	local got, raw = pcall(function()
		return GameState.Get(name)
	end)
	if got then
		return readJson(raw)
	end
	return nil
end

local function stateNumber(name)
	local ok, value = pcall(function()
		return GameState.Get(name)
	end)
	if ok then
		return tonumber(value) or 0
	end
	return tonumber(LocalPlayer:GetAttribute(name)) or 0
end

local function living()
	local character = LocalPlayer.Character
	if not character or character:GetAttribute("Dead") == true then
		return nil
	end
	local evolving = character:GetAttribute("Evolving")
	if type(evolving) == "number" and evolving > Workspace:GetServerTimeNow() then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	return character, root
end

local function magnetRadius()
	local ok, radius = pcall(function()
		return require(ReplicatedStorage.Ant.Client.OrbRender).MagnetRadius()
	end)
	if ok and type(radius) == "number" and radius > 4 then
		return radius
	end
	return 14
end

local function orbValue(tier)
	local info = Config.OrbTiers[tier]
	if type(info) == "table" and type(info.value) == "number" then
		return info.value, info.key or "Food"
	end
	return 1, "Food"
end

local function rememberOrb(id, tier, pos)
	if type(id) == "number" and typeof(pos) == "Vector3" then
		farm.orbs[id] = { tier = tier, pos = pos }
	end
end

local function ingestOrbs(payload)
	if typeof(payload) ~= "buffer" then
		return
	end
	local count = buffer.len(payload) // Net.ORB_BYTES
	for index = 0, count - 1 do
		local id, tier, pos = Net.ReadOrb(payload, index)
		rememberOrb(id, tier, pos)
	end
	farm.ready = true
end

local function ingestTaken(payload)
	if typeof(payload) ~= "buffer" then
		return
	end
	local count = buffer.len(payload) // Net.TAKEN_BYTES
	for index = 0, count - 1 do
		local id = Net.ReadTaken(payload, index)
		farm.orbs[id] = nil
		farm.skip[id] = nil
	end
end

local function refreshOrbs()
	local now = os.clock()
	if now < farm.nextRefresh then
		return
	end
	farm.nextRefresh = now + 20
	task.spawn(function()
		local ok, payload = pcall(function()
			return Net.Get("GetOrbs"):InvokeServer()
		end)
		if ok and running() then
			farm.orbs = {}
			ingestOrbs(payload)
		end
	end)
end

local function pickOrb(origin)
	local now = os.clock()
	local bestId, bestOrb, bestScore
	local nearId, nearOrb, nearDist
	for id, orb in pairs(farm.orbs) do
		if (farm.skip[id] or 0) <= now then
			local flat = Vector3.new(orb.pos.X - origin.X, 0, orb.pos.Z - origin.Z)
			local distance = flat.Magnitude
			if not nearDist or distance < nearDist then
				nearId, nearOrb, nearDist = id, orb, distance
			end
			if distance <= 80 then
				local value = orbValue(orb.tier)
				local score = value * 4 - distance
				if not bestScore or score > bestScore then
					bestId, bestOrb, bestScore = id, orb, score
				end
			end
		end
	end
	if bestOrb then
		return bestId, bestOrb
	end
	if nearOrb and nearDist <= 160 then
		return nearId, nearOrb
	end
	return nil
end

local SURFACE_VOID_Y = -40
local safeSpots = { surface = nil, dungeon = nil }

local function voidY()
	local inside = inDungeon()
	return inside and -4000 or SURFACE_VOID_Y
end

local function rayFilter(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return params
end

local function groundAt(xz, character, fromY)
	local hit = Workspace:Raycast(Vector3.new(xz.X, fromY + 12, xz.Z), Vector3.new(0, -50, 0), rayFilter(character))
	if hit and hit.Position.Y > voidY() and hit.Normal.Y > 0.45 then
		return hit.Position
	end
	return nil
end

local function spawnStand()
	local gameFolder = Workspace:FindFirstChild("Game")
	local spawns = gameFolder and gameFolder:FindFirstChild("Spawns")
	local pad = spawns and spawns:FindFirstChildWhichIsA("BasePart")
	if pad then
		return pad.Position + Vector3.new(0, 5, 0)
	end
	return Vector3.new(0, 16, 0)
end

local function healthRatio(character)
	local hp = tonumber(character:GetAttribute("HP"))
	local maxHp = tonumber(character:GetAttribute("MaxHP"))
	if not hp or not maxHp or maxHp <= 0 then
		return nil, hp, maxHp
	end
	return math.clamp(hp / maxHp, 0, 1), hp, maxHp
end

local function stepGodMode(character, root)
	local ratio, hp, maxHp = healthRatio(character)
	if STATE.godMode ~= true then
		if farm.godHold then
			-- Switched off while waiting up in the sky: come back down.
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(farm.godReturn or spawnStand())
		end
		farm.godRecovering = false
		farm.godHold = nil
		farm.godReturn = nil
		STATE.godRecovering = false
		return false
	end
	if not ratio then
		return false
	end
	if STATE.godStyle ~= "Safe Zone" then
		-- "Sky" escape (the original God Mode, brought back on 2026-11-24 at the
		-- user's request after walking escapes still got caught): teleport 180
		-- studs up out of reach, wait there while the game's regen heals, then
		-- teleport back to spawn. It never dies, but these are big instant
		-- teleports, the kind of movement the game's movement check can kick for.
		if farm.godRecovering == true then
			if ratio >= 0.99 then
				if farm.godHold then
					root.AssemblyLinearVelocity = Vector3.zero
					root.CFrame = CFrame.new(farm.godReturn or spawnStand())
				end
				farm.godRecovering = false
				farm.godHold = nil
				farm.godReturn = nil
				STATE.godRecovering = false
				STATE.status = "God Mode recovered"
				STATE.detail = string.format("HP %d/%d", math.floor(hp or 0), math.floor(maxHp or 0))
				return true
			end
			local hold = farm.godHold or Vector3.new(root.Position.X, math.max(root.Position.Y + 180, 180), root.Position.Z)
			farm.godHold = hold
			farm.godReturn = farm.godReturn or spawnStand()
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(hold)
			STATE.godRecovering = true
			STATE.status = "God Mode healing"
			STATE.detail = string.format("HP %d/%d  ·  %d%%", math.floor(hp or 0), math.floor(maxHp or 0), math.floor(ratio * 100))
			return true
		end
		local skyEscapeAt = STATE.autoPvp == true and 0.82 or 0.72
		if ratio <= skyEscapeAt then
			farm.godRecovering = true
			farm.godEscapes += 1
			farm.godReturn = spawnStand()
			farm.godHold = Vector3.new(root.Position.X, math.max(root.Position.Y + 180, 180), root.Position.Z)
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(farm.godHold)
			STATE.godRecovering = true
			STATE.godEscapes = farm.godEscapes
			STATE.status = "God Mode escaped"
			STATE.detail = string.format("HP %d/%d  ·  healing safely", math.floor(hp or 0), math.floor(maxHp or 0))
			return true
		end
		STATE.godRecovering = false
		return false
	end
	-- Since v1.5.0 God Mode never teleports (it used to park the ant 180 studs
	-- up in the air). v1.5.1: it sprints to the spawn safe zone
	-- (Config.SafeZone, radius 80; no damage there once the 6 s CombatTag runs
	-- out), heals with the game's own regen, then goes back to farming. Just
	-- walking away was not enough: a chaser killed the ant 3 times, and every
	-- death costs Combat.DeathLoss (25%).
	local function inSafeZone(position)
		local ok, safe = pcall(Config.InSafeZone, position)
		return ok and safe == true
	end
	local function getAway()
		if not inDungeon() and farm.walkTo then
			local spot = spawnStand()
			if not inSafeZone(root.Position) or Vector3.new(root.Position.X - spot.X, 0, root.Position.Z - spot.Z).Magnitude > 45 then
				farm.walkTo(character, root, spot, 12)
				farm.godSafe = false
				return "God Mode: running to the safe zone"
			end
			farm.godSafe = true
			return "God Mode: healing in the safe zone"
		end
		local threat = farm.threatPos
		local away
		if typeof(threat) == "Vector3" then
			local off = Vector3.new(root.Position.X - threat.X, 0, root.Position.Z - threat.Z)
			if off.Magnitude < 70 then
				away = off.Magnitude > 0.5 and off.Unit or root.CFrame.LookVector
			end
		end
		if away and farm.walkTo then
			farm.walkTo(character, root, root.Position + away * 40, 3)
			return "God Mode: getting away"
		end
		return "God Mode healing"
	end
	if farm.godRecovering == true then
		if ratio >= 0.99 then
			farm.godRecovering = false
			STATE.godRecovering = false
			STATE.status = "God Mode recovered"
			STATE.detail = string.format("HP %d/%d", math.floor(hp or 0), math.floor(maxHp or 0))
			return true
		end
		STATE.godRecovering = true
		STATE.status = getAway()
		STATE.detail = string.format("HP %d/%d  ·  %d%%", math.floor(hp or 0), math.floor(maxHp or 0), math.floor(ratio * 100))
		return true
	end
	-- One hit can take up to Combat.MaxHitShare (34%) and the run to spawn
	-- takes a few seconds, so leave earlier than the old teleport did.
	local escapeAt = STATE.autoPvp == true and 0.88 or 0.78
	if ratio <= escapeAt then
		farm.godRecovering = true
		farm.godEscapes += 1
		STATE.godRecovering = true
		STATE.godEscapes = farm.godEscapes
		STATE.status = getAway()
		STATE.detail = string.format("HP %d/%d  ·  healing safely", math.floor(hp or 0), math.floor(maxHp or 0))
		return true
	end
	STATE.godRecovering = false
	return false
end

local function standOn(ground, character, root)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local lift = root.Size.Y * 0.5 + (hum and hum.HipHeight or 0) + 0.25
	return Vector3.new(ground.X, ground.Y + lift, ground.Z)
end

local function putBack(root)
	local inside = inDungeon()
	local spot = safeSpots[inside and "dungeon" or "surface"] or spawnStand()
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(spot)
	STATE.status = "Back on the map"
	STATE.detail = "The last step had no ground"
end

local function sugarCube()
	local gameFolder = Workspace:FindFirstChild("Game")
	local model = gameFolder and gameFolder:FindFirstChild("SugarCube")
	local cube = model and model:FindFirstChild("Cube")
	if cube and cube:IsA("BasePart") and cube.Parent then
		return cube
	end
	return nil
end

local function stepSugar(character, root, cube)
	local center = cube.Position
	local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	if flat.Magnitude <= 12 and math.abs(root.Position.Y - center.Y) < 16 then
		STATE.status = "In the sugar ring"
		STATE.detail = "Scoring for Sugar Rush"
		return
	end
	local stand = center + (flat.Magnitude > 1 and flat.Unit or Vector3.new(1, 0, 0)) * 8
	if not farm.walkTo(character, root, stand, 2) then
		STATE.status = "Path to the sugar cube is blocked"
		STATE.detail = string.format("Sugar Rush  ·  %d away", math.floor(flat.Magnitude))
		return
	end
	STATE.status = "Going to the sugar ring"
	STATE.detail = string.format("Sugar Rush  ·  %d away", math.floor(flat.Magnitude))
end

local OrbRender
local function orbRender()
	if OrbRender == nil then
		local ok, render = pcall(function()
			return require(ReplicatedStorage.Ant.Client.OrbRender)
		end)
		OrbRender = ok and render or false
	end
	if OrbRender == false then
		return nil
	end
	return OrbRender
end

local function liveTarget(origin)
	local render = orbRender()
	local now = os.clock()
	if render then
		local id, pos = render.Nearest(origin, 140)
		if type(id) == "number" and typeof(pos) == "Vector3" and (farm.skip[id] or 0) <= now then
			local tier = render.Get(id)
			return id, { tier = tier, pos = pos }
		end
		local bestId, bestOrb, bestDist
		for cachedId in pairs(farm.orbs) do
			if (farm.skip[cachedId] or 0) <= now then
				local tier, livePos = render.Get(cachedId)
				if typeof(livePos) == "Vector3" then
					local dist = (livePos - origin).Magnitude
					if dist <= 140 and (not bestDist or dist < bestDist) then
						bestId = cachedId
						bestOrb = { tier = tier, pos = livePos }
						bestDist = dist
					end
				end
			end
		end
		if bestOrb then
			return bestId, bestOrb
		end
	end
	return pickOrb(origin)
end

do
	-- Move Like A Player (v1.5.0). The hub used to CFrame the ant 14 studs at a
	-- time (about 70 studs/s), which is faster than any ant can walk, and the
	-- game kicks for "moving in a way it can't". Now it only ever holds the
	-- ant's movement input, exactly like a player holding a key: the input is
	-- written right after Roblox's ControlModule (RenderPriority.Input), so the
	-- game's own walk speed, sprint, wall climbing (WallWalk reads
	-- MoveDirection), turning and animations do all of the moving.
	local drive = { goal = nil, radius = 1.5, untilT = 0, moving = false }
	farm.drive = drive
	local function release()
		drive.goal = nil
		if drive.moving then
			drive.moving = false
			local hum = humanoid()
			if hum then
				pcall(hum.Move, hum, Vector3.zero, false)
			end
		end
	end
	farm.releaseWalk = release
	pcall(function()
		RunService:BindToRenderStep("ZinoosAntWalk", Enum.RenderPriority.Input.Value + 5, function()
			local goal = drive.goal
			if not goal then
				return
			end
			if not running() or os.clock() > drive.untilT then
				release()
				return
			end
			local hum = humanoid()
			local root = hum and hum.RootPart
			if not root or hum.Health <= 0 then
				return
			end
			local flat = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
			if flat.Magnitude < drive.radius then
				hum:Move(Vector3.zero, false)
				return
			end
			drive.moving = true
			hum:Move(flat.Unit, false)
		end)
	end)
	hubCleanup(function()
		pcall(function()
			RunService:UnbindFromRenderStep("ZinoosAntWalk")
		end)
		release()
	end)

	-- Ask PathfindingService for a way round (worked out in the background)
	-- once plain walking has stopped getting closer: a drop, a pit or a wall
	-- the ant cannot climb.
	local ghosted = {}
	farm.ghostAhead = function(character, root, point)
		local from = root.Position
		local flat = Vector3.new(point.X - from.X, 0, point.Z - from.Z)
		if flat.Magnitude < 2 then
			return false
		end
		local params = rayFilter(character)
		local hit
		for _, lift in ipairs({ 0, 2, -1 }) do
			hit = Workspace:Raycast(from + Vector3.new(0, lift, 0), flat.Unit * math.min(flat.Magnitude, 12), params)
			if hit then
				break
			end
		end
		local part = hit and hit.Instance
		if not part or not part:IsA("BasePart") or part:IsA("Terrain") or not part.CanCollide then
			return false
		end
		if math.abs(hit.Normal.Y) >= 0.5 then
			return false
		end
		-- Allow-list only: signs/shop/portal frame and the props inside a zone.
		-- Never Map.Environment.Walls/Dividers/Edge/Boundary (the walls between
		-- and around the zones), Game.Gates (locked zones), Map.Colliders.
		local gameFolder = Workspace:FindFirstChild("Game")
		local map = Workspace:FindFirstChild("Map")
		local environment = map and map:FindFirstChild("Environment")
		local allowed = false
		for _, holder in ipairs({
			gameFolder and gameFolder:FindFirstChild("Boards"),
			gameFolder and gameFolder:FindFirstChild("MoleShop"),
			gameFolder and gameFolder:FindFirstChild("DungeonPortal"),
			environment and environment:FindFirstChild("Meadow"),
			environment and environment:FindFirstChild("Picnic"),
			environment and environment:FindFirstChild("Garden"),
			environment and environment:FindFirstChild("Hollow"),
		}) do
			if holder and part:IsDescendantOf(holder) then
				allowed = true
				break
			end
		end
		if not allowed then
			return false
		end
		-- Too big to be a prop (a cliff or a floor slab): leave it solid.
		if part.Size.Magnitude > 220 then
			return false
		end
		part.CanCollide = false
		ghosted[part] = os.clock() + 5
		noteActivity("Walked through " .. part.Name)
		return true
	end
	local function restoreGhosts(all)
		local now = os.clock()
		for part, untilT in pairs(ghosted) do
			if all or now >= untilT then
				ghosted[part] = nil
				if part.Parent then
					pcall(function()
						part.CanCollide = true
					end)
				end
			end
		end
	end
	task.spawn(function()
		while running() do
			task.wait(0.5)
			restoreGhosts(false)
		end
		restoreGhosts(true)
	end)
	hubCleanup(function()
		restoreGhosts(true)
	end)

	local function startRoute(from, point)
		local pending = { goal = point, at = os.clock() }
		farm.route = pending
		farm.routeRetry = os.clock() + 4
		task.spawn(function()
			local ok, points = pcall(function()
				local path = game:GetService("PathfindingService"):CreatePath({
					AgentRadius = 3,
					AgentHeight = 5,
					AgentCanJump = true,
					AgentCanClimb = true,
					WaypointSpacing = 8,
				})
				path:ComputeAsync(from, point)
				if path.Status ~= Enum.PathStatus.Success then
					return nil
				end
				local list = {}
				for _, waypoint in ipairs(path:GetWaypoints()) do
					list[#list + 1] = { pos = waypoint.Position, jump = waypoint.Action == Enum.PathWaypointAction.Jump }
				end
				return list
			end)
			if farm.route == pending then
				if ok and type(points) == "table" and #points > 0 then
					pending.points = points
					pending.index = 1
					pending.at = os.clock()
				else
					farm.route = nil
				end
			end
		end)
	end

	-- Walk toward point. Returns false only once walking (with jumps and a
	-- route) has made no progress for a while, so callers can skip the target.
	farm.walkTo = function(character, root, point, radius)
		local now = os.clock()
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return false
		end
		radius = radius or 1.5
		local pos = root.Position
		local distance = Vector3.new(point.X - pos.X, 0, point.Z - pos.Z).Magnitude
		local track = farm.walkTrack
		if not track or (track.goal - point).Magnitude > 12 then
			track = { goal = point, best = distance, bestAt = now, nextJump = 0 }
			farm.walkTrack = track
		elseif distance < track.best - 1.5 or distance <= radius + 1 then
			track.best = math.min(track.best, distance)
			track.bestAt = now
		end
		track.goal = point
		-- Stuck = the ant itself has not really moved, whatever the target is.
		-- (Judging only by the current target reset the timer every time the
		-- food changed, so the ant could stay wedged in a corner forever.)
		local moved = farm.movedFrom
		if not moved or (pos - moved).Magnitude > 3 or distance <= radius + 1 then
			farm.movedFrom = pos
			farm.movedAt = now
		end
		local stuckFor = math.max(now - track.bestAt, now - (farm.movedAt or now))
		if STATE.ghostWhenStuck == true and now - (farm.movedAt or now) > 1.5 and now >= (farm.nextGhost or 0) then
			-- Walk Through When Stuck: only the one solid thing right in front
			-- (a leaderboard, the shop, a rock) stops colliding, on this client
			-- only, for 5 s. Never the ground, the zone gates or the map's
			-- invisible edge walls.
			farm.nextGhost = now + 1
			if farm.ghostAhead(character, root, point) then
				farm.movedAt = now
			end
		end
		if now - (farm.movedAt or now) > 3.5 and now >= (farm.unstickUntil or 0) + 3 then
			-- Back out of the corner the way a player would: a short walk in
			-- another direction, then carry on.
			local away = Vector3.new(pos.X - point.X, 0, pos.Z - point.Z)
			away = away.Magnitude > 0.5 and away.Unit or root.CFrame.LookVector
			local angle = math.rad(math.random(-70, 70))
			away = Vector3.new(away.X * math.cos(angle) - away.Z * math.sin(angle), 0, away.X * math.sin(angle) + away.Z * math.cos(angle))
			farm.unstickGoal = pos + away * 10
			farm.unstickUntil = now + 1.2
			farm.movedAt = now
			farm.route = nil
			farm.routeRetry = 0
			hum.Jump = true
		end
		if now < (farm.unstickUntil or 0) and farm.unstickGoal then
			drive.goal = farm.unstickGoal
			drive.radius = 1.5
			drive.untilT = now + 0.6
			farm.walkWanted = true
			return true
		end
		if stuckFor > 9 then
			-- Nothing worked: give this target up for now.
			farm.walkTrack = nil
			farm.route = nil
			release()
			return false
		end
		local target = point
		local route = farm.route
		if route and ((route.goal - point).Magnitude > 20 or now - route.at > 15) then
			farm.route = nil
			route = nil
		end
		if not route and stuckFor > 2.5 and now >= (farm.routeRetry or 0) then
			startRoute(pos, point)
			route = farm.route
		end
		if route and route.points then
			local step = route.points[route.index]
			while step and Vector3.new(step.pos.X - pos.X, 0, step.pos.Z - pos.Z).Magnitude < 3 do
				route.index += 1
				step = route.points[route.index]
			end
			if step then
				target = step.pos
				if step.jump and Vector3.new(step.pos.X - pos.X, 0, step.pos.Z - pos.Z).Magnitude < 6 then
					hum.Jump = true
				end
			else
				farm.route = nil
			end
		end
		-- A small step or ledge in the way: hop, like a player would.
		if stuckFor > 1.2 and now >= track.nextJump then
			hum.Jump = true
			track.nextJump = now + 1.2
		end
		drive.goal = target
		drive.radius = radius
		drive.untilT = now + 0.6
		farm.walkWanted = true
		return true
	end
end

local function stepToward(character, root, point, status, detail)
	if farm.walkTo(character, root, point) then
		STATE.status = status
		STATE.detail = detail
		return true
	end
	return false
end

-- Out Of Sealed Holes (v1.5.6). There are pockets under the rocks (the
-- terrain) with no way out on foot, and food still spawns inside them, so an
-- ant that ends up in one walks around in there forever. Food buried under
-- the rocks is skipped, and an ant that has been under the rocks for 15 s
-- walks out if PathfindingService finds a way; if not, it hops once onto the
-- nearest open ground right above (at most once a minute).
local function buriedAt(pos, character)
	local params = rayFilter(character)
	local up = Workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, 60, 0), params)
	if not up or up.Instance ~= Workspace.Terrain then
		return false
	end
	local top = Workspace:Raycast(Vector3.new(pos.X, pos.Y + 200, pos.Z), Vector3.new(0, -200, 0), params)
	return top ~= nil and top.Instance == Workspace.Terrain and top.Position.Y > pos.Y + 8
end
farm.buriedAt = buriedAt

local function openGroundNear(pos, character)
	local params = rayFilter(character)
	local best, bestGap
	for _, dist in ipairs({ 14, 20, 26, 32 }) do
		for step = 0, 15 do
			local angle = step * math.pi / 8
			local spot = pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * dist
			local hit = Workspace:Raycast(Vector3.new(spot.X, pos.Y + 200, spot.Z), Vector3.new(0, -260, 0), params)
			if hit and hit.Normal.Y > 0.7 and hit.Position.Y > voidY() and hit.Position.Y > pos.Y + 4 then
				local gap = (hit.Position - pos).Magnitude
				if gap <= 55 and (not bestGap or gap < bestGap) then
					best, bestGap = hit.Position, gap
				end
			end
		end
	end
	return best
end

local function stepOutOfHole(character, root)
	if inDungeon() then
		farm.buried = nil
		return false
	end
	local now = os.clock()
	local hole = farm.buried
	if not hole or now >= hole.nextCheck then
		if not buriedAt(root.Position, character) then
			farm.buried = nil
			return false
		end
		hole = hole or { since = now }
		hole.nextCheck = now + 2
		farm.buried = hole
	end
	if now - hole.since < 15 or now < (farm.nextHop or 0) then
		return false
	end
	hole.exit = hole.exit or openGroundNear(root.Position, character)
	local exit = hole.exit
	if not exit then
		return false
	end
	if hole.way == nil then
		hole.way = "checking"
		local from = root.Position
		task.spawn(function()
			local ok, status = pcall(function()
				local path = game:GetService("PathfindingService"):CreatePath({
					AgentRadius = 1.5,
					AgentHeight = 3,
					AgentCanJump = true,
					AgentCanClimb = true,
					WaypointSpacing = 6,
				})
				path:ComputeAsync(from, exit + Vector3.new(0, 2, 0))
				return path.Status
			end)
			if farm.buried == hole then
				hole.way = (ok and status == Enum.PathStatus.Success) and "walk" or "hop"
				hole.wayAt = os.clock()
			end
		end)
		return false
	end
	if hole.way == "walk" then
		if now - (hole.wayAt or now) < 45 and stepToward(character, root, exit, "Climbing out", "Under the rocks  ·  walking out") then
			return true
		end
		hole.way = "hop"
	end
	if hole.way == "hop" then
		farm.nextHop = now + 60
		farm.buried = nil
		farm.walkTrack = nil
		farm.route = nil
		if farm.releaseWalk then
			farm.releaseWalk()
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(exit + Vector3.new(0, 3, 0)) * root.CFrame.Rotation
		STATE.status = "Got out of a sealed hole"
		STATE.detail = "Hopped onto the ground above"
		return true
	end
	return false
end

local function vectorFromData(row)
	if typeof(row) == "Vector3" then
		return row
	end
	if type(row) ~= "table" then
		return nil
	end
	local value = type(row.p) == "table" and row.p or type(row.pos) == "table" and row.pos or row
	local x = tonumber(value.x or value.X or value[1])
	local y = tonumber(value.y or value.Y or value[2])
	local z = tonumber(value.z or value.Z or value[3])
	if x and y and z then
		return Vector3.new(x, y, z)
	end
	return nil
end

local function nearestWorm(origin)
	local gameFolder = Workspace:FindFirstChild("Game")
	local folder = gameFolder and gameFolder:FindFirstChild("Worms")
	local best, bestDist
	if folder then
		for _, part in ipairs(folder:GetChildren()) do
			if part:IsA("BasePart") and not part:GetAttribute("TakenBy") and part:GetAttribute("Dig") ~= true then
				local distance = (part.Position - origin).Magnitude
				if not bestDist or distance < bestDist then
					best, bestDist = part, distance
				end
			end
		end
	end
	return best, bestDist
end

local function nearestPowerUp(origin)
	local folder = Workspace:FindFirstChild("AntPowerUps")
	local best, bestDist
	local configuredNear = type(Config.PowerUps) == "table" and type(Config.PowerUps.Near) == "table" and tonumber(Config.PowerUps.Near[2]) or 120
	local maxDistance = configuredNear + 30
	if folder then
		local now = Workspace:GetServerTimeNow()
		local clock = os.clock()
		for _, part in ipairs(folder:GetChildren()) do
			local ends = tonumber(part:GetAttribute("Ends"))
			local skipUntil = tonumber(farm.powerUpSkip[part]) or 0
			if skipUntil <= clock then
				farm.powerUpSkip[part] = nil
			end
			if part:IsA("BasePart")
				and part:GetAttribute("TakenBy") == nil
				and part:GetAttribute("Gone") ~= true
				and skipUntil <= clock
				and (not ends or ends > now) then
				local distance = (part.Position - origin).Magnitude
				if distance <= maxDistance and (not bestDist or distance < bestDist) then
					best, bestDist = part, distance
				end
			end
		end
	end
	return best, bestDist
end

local function foundLostEggs()
	local found = {}
	for _, value in pairs(stateJson("LostEggs") or {}) do
		local index = tonumber(value)
		if index then
			found[index] = true
		end
	end
	return found
end

local function nearestLostEgg(origin)
	local gameFolder = Workspace:FindFirstChild("Game")
	local folder = gameFolder and gameFolder:FindFirstChild("LostEggs")
	local found = foundLostEggs()
	local best, bestDist, bestIndex
	if folder then
		for _, part in ipairs(folder:GetChildren()) do
			local index = tonumber(part:GetAttribute("EggIndex")) or tonumber(string.match(part.Name, "%d+"))
			if part:IsA("BasePart") and index and not found[index] then
				local distance = (part.Position - origin).Magnitude
				if not bestDist or distance < bestDist then
					best, bestDist, bestIndex = part, distance, index
				end
			end
		end
	end
	STATE.lostEggsFound = 0
	for _ in pairs(found) do
		STATE.lostEggsFound += 1
	end
	STATE.lostEggsTotal = type(Config.LostEggs) == "table" and type(Config.LostEggs.Spots) == "table" and #Config.LostEggs.Spots or 20
	return best, bestDist, bestIndex
end

local function nearestTreasure(origin, data)
	local best, bestDist
	for _, row in pairs(type(data) == "table" and type(data.chests) == "table" and data.chests or {}) do
		if type(row) == "table" and not row.open then
			local position = vectorFromData(row)
			if position then
				local distance = (position - origin).Magnitude
				if not bestDist or distance < bestDist then
					best, bestDist = position, distance
				end
			end
		end
	end
	return best, bestDist
end

local function dungeonPortalPosition()
	local gameFolder = Workspace:FindFirstChild("Game")
	local portal = gameFolder and gameFolder:FindFirstChild("DungeonPortal")
	if portal and portal:IsA("Model") then
		return portal:GetPivot().Position
	end
	if portal and portal:IsA("BasePart") then
		return portal.Position
	end
	return type(Content.Dungeon) == "table" and type(Content.Dungeon.Portal) == "table" and Content.Dungeon.Portal.at or nil
end

local function stepSpecialTravel(character, root)
	local inside, dungeon = inDungeon()
	if inside then
		STATE.dungeon = string.upper(tostring(dungeon.st or "ACTIVE"))
		return false
	end
	STATE.dungeon = "Surface"
	local eventKey, eventData = activeEvent()
	if STATE.smartEvents == true and eventKey == "TreasureHunt" then
		local position, distance = nearestTreasure(root.Position, eventData)
		if position then
			if distance <= 5 then
				STATE.status = "Opening treasure"
				STATE.detail = "Treasure Hunt chest"
				return true
			end
			return stepToward(character, root, position, "Going to treasure", string.format("Treasure chest  %d away", math.floor(distance)))
		end
	end
	if STATE.autoWorms == true and globalValue("WormRain") == "rain" then
		local worm, distance = nearestWorm(root.Position)
		if worm then
			if distance <= 4 then
				STATE.status = "Collecting worm"
				STATE.detail = "Worm rain"
				return true
			end
			return stepToward(character, root, worm.Position, "Going to worm", string.format("Worm  %d away", math.floor(distance)))
		end
	end
	if STATE.autoPowerUps == true then
		local powerUp, distance = nearestPowerUp(root.Position)
		if powerUp then
			local kind = tostring(powerUp:GetAttribute("Kind") or "Power-Up")
			if distance <= 4 then
				farm.powerUpChase = nil
				STATE.status = "Collecting " .. kind
				STATE.detail = "Temporary power-up"
				return true
			end
			local now = os.clock()
			local chase = farm.powerUpChase
			if not chase or chase.target ~= powerUp then
				farm.powerUpChase = { target = powerUp, best = distance, at = now }
			elseif distance < chase.best - 3 then
				chase.best = distance
				chase.at = now
			elseif now - chase.at >= 3.5 then
				farm.powerUpSkip[powerUp] = now + 30
				farm.powerUpChase = nil
				STATE.status = "Skipped unreachable " .. kind
				STATE.detail = "Blocked power-up ignored for 30 seconds"
				return true
			end
			if stepToward(character, root, powerUp.Position, "Going to " .. kind, string.format("Power-up  %d away", math.floor(distance))) then
				return true
			end
		else
			farm.powerUpChase = nil
		end
	end
	if STATE.autoLostEggs == true then
		local egg, distance, index = nearestLostEgg(root.Position)
		if egg then
			local total = tonumber(STATE.lostEggsTotal) or 20
			local found = tonumber(STATE.lostEggsFound) or 0
			if distance <= 5.5 then
				STATE.status = "Collecting lost egg " .. tostring(index)
				STATE.detail = string.format("Lost Eggs  %d/%d", found, total)
				return true
			end
			-- Several eggs sit on crags, cacti and the giant mushroom. Walking into
			-- them lets the game's wall climbing carry the ant up (no teleport).
			if (farm.eggSkip and farm.eggSkip[index] or 0) <= os.clock() then
				if stepToward(character, root, egg.Position, "Going to lost egg " .. tostring(index), string.format("Lost Eggs  %d/%d  ·  %d away", found, total, math.floor(distance))) then
					return true
				end
				farm.eggSkip = farm.eggSkip or {}
				farm.eggSkip[index] = os.clock() + 120
			end
		end
	end
	local wantsDungeon = STATE.autoDungeon == true or questNeeds("dungeon")
	if wantsDungeon
		and stateNumber("DungeonRuns") > 0
		and stateNumber("Tutorial") >= (tonumber(Config.MaxTutorial) or 8)
		and stateNumber("Rebirths") >= (tonumber(Content.Dungeon and Content.Dungeon.MinRebirths) or 1)
		and stateNumber("Stage") >= (tonumber(Content.Dungeon and Content.Dungeon.MinStage) or 4) then
		local position = dungeonPortalPosition()
		if typeof(position) == "Vector3" then
			local distance = (position - root.Position).Magnitude
			-- Keep moving into the portal trigger. Stopping six studs away leaves the
			-- ant parked on "Waiting for the portal" without ever touching it.
			if distance <= 1.25 then
				STATE.status = "Entering dungeon"
				STATE.detail = "Waiting for the portal"
				return true
			end
			return stepToward(character, root, position, "Going to dungeon", string.format("Dungeon portal  %d away", math.floor(distance)))
		end
	end
	return false
end

local nearestCritter, nearestAnt, nearestPvpTarget
local function stepFarm()
	if STATE.autoOrb ~= true
		and STATE.autoDungeon ~= true
		and STATE.autoWorms ~= true
		and STATE.autoPowerUps ~= true
		and STATE.autoLostEggs ~= true
		and STATE.smartEvents ~= true
		and STATE.questAssist ~= true
		and STATE.chaseBugs ~= true
		and STATE.autoPvp ~= true then
		STATE.detail = "Farm off"
		return
	end
	local character, root = living()
	if not character then
		STATE.status = "Waiting to move"
		return
	end
	if STATE.godMode == true and (farm.godRecovering == true or (healthRatio(character) or 1) <= 0.85) then
		-- Whatever is closest and can hurt us: God Mode walks away from it.
		local _, antRoot, antDist = nearestAnt(root.Position, 70)
		local _, bugRoot, bugDist = nearestCritter(root.Position, 50)
		if bugRoot and bugDist and bugDist > 50 then
			bugRoot = nil
		end
		if antRoot and (not bugRoot or antDist <= bugDist) then
			farm.threatPos = antRoot.Position
		else
			farm.threatPos = bugRoot and bugRoot.Position or nil
		end
	end
	if stepGodMode(character, root) then
		return
	end
	if stepOutOfHole(character, root) then
		return
	end
	-- The Anteater locks its tongue onto one ant, then grabs whoever is still at
	-- that spot. Step sideways out of the line while it is aiming at us.
	local dodge = farm.anteaterDodge
	if dodge and STATE.smartEvents == true and os.clock() < dodge.untilT then
		local from = dodge.at
		local bossRoot = nil
		local critters = Workspace:FindFirstChild("Ants") and Workspace.Ants:FindFirstChild("Critters")
		if critters and dodge.boss then
			for _, model in ipairs(critters:GetChildren()) do
				if model:GetAttribute("EntityId") == dodge.boss then
					bossRoot = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
					break
				end
			end
		end
		local away
		if bossRoot then
			local line = Vector3.new(root.Position.X - bossRoot.Position.X, 0, root.Position.Z - bossRoot.Position.Z)
			if line.Magnitude > 0.5 then
				away = Vector3.new(-line.Z, 0, line.X).Unit * (dodge.side or 1)
			end
		end
		if not away and typeof(from) == "Vector3" then
			local off = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
			if off.Magnitude > 0.5 then
				away = off.Unit
			end
		end
		away = away or root.CFrame.RightVector
		stepToward(character, root, root.Position + away * 30, "Dodging the Anteater", "It locked onto you")
		return
	end
	if root.Position.Y < voidY() then
		putBack(root)
		return
	end
	local under = groundAt(root.Position, character, root.Position.Y)
	if under and math.abs(root.Position.Y - under.Y) < 12 then
		safeSpots[inDungeon() and "dungeon" or "surface"] = root.Position
	end
	if STATE.autoPvp == true then
		local model, foeRoot, foeDist = nearestPvpTarget(root.Position, 450)
		if foeRoot then
			local targetName = tostring(model:GetAttribute("DisplayName") or model.Name)
			STATE.pvpTarget = targetName
			local length = tonumber(character:GetAttribute("Length")) or 10
			local reach = 18
			local reachOk, gotReach = pcall(Config.BiteRange, length)
			if reachOk and type(gotReach) == "number" then
				reach = gotReach + 6
			end
			local giveUp = false
			if foeDist <= reach then
				-- Bites that never take any health off (the spawn safe bubble, a
				-- shield) used to keep the ant "fighting" one player forever.
				local hpNow = tonumber(model:GetAttribute("HP")) or 0
				local fight = farm.pvpFight
				if not fight or fight.model ~= model then
					farm.pvpFight = { model = model, hp = hpNow, at = os.clock() }
				elseif hpNow < fight.hp - 0.5 then
					fight.hp = hpNow
					fight.at = os.clock()
				elseif os.clock() - fight.at > 8 then
					farm.pvpSkip = farm.pvpSkip or setmetatable({}, { __mode = "k" })
					farm.pvpSkip[model] = os.clock() + 90
					farm.pvpFight = nil
					STATE.pvpTarget = ""
					noteActivity("Left " .. targetName .. ": bites were not landing")
					giveUp = true
				end
				if not giveUp then
					STATE.status = "PvP fighting " .. targetName
					STATE.detail = string.format("Weakest safe target  ·  %d HP", math.floor(hpNow))
					return
				end
			end
			if foeDist > reach then
				farm.pvpFight = nil
			end
			if not giveUp and stepToward(character, root, foeRoot.Position, "PvP chasing " .. targetName, string.format("Weakest safe target  ·  %d away", math.floor(foeDist))) then
				return
			end
		else
			STATE.pvpTarget = ""
		end
	end
	if stepSpecialTravel(character, root) then
		return
	end
	local cube = sugarCube()
	if cube then
		stepSugar(character, root, cube)
		return
	end
	local dungeonActive = inDungeon()
	local eventKey = activeEvent()
	local eventHasTarget = eventKey == "MantisBoss"
		or eventKey == "GoldenAphid"
		or eventKey == "AphidStampede"
		or eventKey == "SpiderNest"
		or eventKey == "LadybugSwarm"
		or eventKey == "RedSwarm"
		or eventKey == "Anteater"
	if STATE.chaseBugs == true or questNeeds("bugs") or dungeonActive or (STATE.smartEvents == true and eventHasTarget) then
		local model, foeRoot, foeDist = nearestCritter(root.Position, 140)
		if foeRoot and eventKey == "Anteater" and STATE.chaseBugs ~= true and not questNeeds("bugs") and not dungeonActive
			and model:GetAttribute("EntityId") ~= tonumber(globalValue("BossId")) then
			-- Only the Anteater itself is worth leaving the food for.
			foeRoot = nil
		end
		if foeRoot then
			local length = tonumber(character:GetAttribute("Length")) or 10
			local reach = 18
			local reachOk, gotReach = pcall(function()
				return Config.BiteRange(length)
			end)
			if reachOk and type(gotReach) == "number" then
				reach = gotReach + 6
			end
			if foeDist <= reach then
				STATE.status = "Fighting " .. model.Name
				STATE.detail = string.format("%s  %d away", model.Name, math.floor(foeDist))
				return
			end
			if stepToward(character, root, foeRoot.Position, "Chasing " .. model.Name, string.format("%s  %d away", model.Name, math.floor(foeDist))) then
				return
			end
		end
	end
	if STATE.pvpQuest == true and questNeeds("ants") then
		local model, foeRoot, foeDist = nearestAnt(root.Position, 140)
		if foeRoot then
			local length = tonumber(character:GetAttribute("Length")) or 10
			local reach = 18
			local reachOk, gotReach = pcall(Config.BiteRange, length)
			if reachOk and type(gotReach) == "number" then
				reach = gotReach + 6
			end
			if foeDist <= reach then
				STATE.status = "Fighting " .. tostring(model:GetAttribute("DisplayName") or model.Name)
				return
			end
			if stepToward(character, root, foeRoot.Position, "Chasing quest ant", string.format("Ant  %d away", math.floor(foeDist))) then
				return
			end
		end
	end
	if STATE.autoOrb ~= true and not questNeeds("eat") then
		STATE.detail = "Orb farm off"
		return
	end
	local id, orb = liveTarget(root.Position)
	if not orb then
		STATE.status = "No food nearby"
		refreshOrbs()
		return
	end
	if not farm.buried then
		-- Food sealed under the rocks: walking to it is how ants get trapped.
		farm.buriedFood = farm.buriedFood or {}
		local seen = farm.buriedFood[id]
		if not seen or (seen.pos - orb.pos).Magnitude > 2 then
			seen = { pos = orb.pos, buried = buriedAt(orb.pos, character) }
			farm.buriedFood[id] = seen
		end
		if seen.buried then
			farm.skip[id] = os.clock() + 120
			farm.chase = nil
			STATE.status = "Skipped food inside the rocks"
			return
		end
	end
	local _, foodName = orbValue(orb.tier)
	local offset = Vector3.new(orb.pos.X - root.Position.X, 0, orb.pos.Z - root.Position.Z)
	local distance = offset.Magnitude
	local gap = (orb.pos - root.Position).Magnitude
	if gap <= magnetRadius() * 0.95 then
		if not farm.eat or farm.eat.id ~= id then
			farm.eat = { id = id, at = os.clock(), power = stateNumber("Power") }
		elseif os.clock() - farm.eat.at > 2.5 and math.abs(stateNumber("Power") - farm.eat.power) < 0.05 then
			farm.skip[id] = os.clock() + 10
			farm.eat = nil
			farm.chase = nil
			STATE.status = "Skipped food that would not collect"
			return
		end
		STATE.status = "Eating " .. foodName
		farm.chase = nil
		return
	end
	if not farm.chase or farm.chase.id ~= id then
		farm.chase = { id = id, at = os.clock(), from = distance }
	elseif os.clock() - farm.chase.at > 4 and distance > farm.chase.from - 4 then
		farm.skip[id] = os.clock() + 8
		farm.chase = nil
		STATE.status = "Skipped stuck food"
		return
	end
	local aim = orb.pos
	if distance > 6 and offset.Magnitude > 0 then
		aim = orb.pos - offset.Unit * 5
	end
	if not stepToward(character, root, aim, string.format("Walking to %s", foodName), string.format("%s  %d away", foodName, math.floor(distance))) then
		farm.skip[id] = os.clock() + 8
		farm.chase = nil
		STATE.status = "Skipped food off the ground"
	end
end

local function critterRoot(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart")
end

function nearestCritter(origin, limit)
	local folder = Workspace:FindFirstChild("Ants")
	local critters = folder and folder:FindFirstChild("Critters")
	if not critters then
		return nil
	end
	local bestModel, bestRoot, bestDist, bestPriority
	local eventKey, eventData = activeEvent()
	local bossId = tonumber(globalValue("BossId"))
	local wanted = {
		MantisBoss = "mantis",
		GoldenAphid = "goldenaphid",
		AphidStampede = "aphid",
		SpiderNest = "spider",
		LadybugSwarm = "ladybug",
		RedSwarm = "fireant",
		Anteater = "anteater",
	}
	for _, model in ipairs(critters:GetChildren()) do
		if model:IsA("Model") and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
			local root = critterRoot(model)
			if root then
				local distance = (root.Position - origin).Magnitude
				local priority = 1
				if STATE.smartEvents == true and type(eventKey) == "string" then
					local identity = string.lower(table.concat({
						tostring(model.Name),
						tostring(model:GetAttribute("Kind") or ""),
						tostring(model:GetAttribute("Species") or ""),
						tostring(model:GetAttribute("EventTag") or model:GetAttribute("Tag") or ""),
					}, "")):gsub("[^%w]", "")
					local eventWanted = wanted[eventKey]
					if (bossId and bossId > 0 and model:GetAttribute("EntityId") == bossId)
						or (eventWanted and string.find(identity, eventWanted, 1, true))
						or (type(eventData) == "table" and tonumber(eventData.follow) == model:GetAttribute("EntityId")) then
						priority = 4
					end
				end
				if distance <= limit and (not bestPriority or priority > bestPriority or (priority == bestPriority and (not bestDist or distance < bestDist))) then
					bestModel, bestRoot, bestDist, bestPriority = model, root, distance, priority
				end
			end
		end
	end
	return bestModel, bestRoot, bestDist
end

local function antFolders()
	local folders = { Workspace }
	local ants = Workspace:FindFirstChild("Ants")
	if ants then
		local bots = ants:FindFirstChild("Bots")
		if bots then
			table.insert(folders, bots)
		end
	end
	return folders
end

function nearestAnt(origin, limit)
	local bestModel, bestRoot, bestDist
	for _, folder in ipairs(antFolders()) do
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") and model ~= LocalPlayer.Character and model:GetAttribute("Kind") == "Ant" and model:GetAttribute("IsCritter") ~= true and model:GetAttribute("Dead") ~= true then
				local hp = model:GetAttribute("HP")
				if hp == nil or (tonumber(hp) or 0) > 0 then
					local root = critterRoot(model)
					if root then
						local distance = (root.Position - origin).Magnitude
						if distance <= limit and (not bestDist or distance < bestDist) then
							bestModel, bestRoot, bestDist = model, root, distance
						end
					end
				end
			end
		end
	end
	return bestModel, bestRoot, bestDist
end

-- PvP is opt-in and deliberately avoids bad fights. Target the lowest-current-HP
-- real player whose maximum health is not above ours and whose stage is inside
-- the game's MercyGap protection, then use distance as the tiebreaker. Bots
-- remain available to the separate quest helper.
function nearestPvpTarget(origin, limit)
	local character = LocalPlayer.Character
	local myMaxHp = character and tonumber(character:GetAttribute("MaxHP")) or 0
	local myStage = character and tonumber(character:GetAttribute("Stage")) or stateNumber("Stage")
	local mercyGap = math.max(0, tonumber(Config.Combat and Config.Combat.MercyGap) or 2)
	if myMaxHp <= 0 or myStage <= 0 then
		return nil
	end
	local bestModel, bestRoot, bestDist, bestHp
	for _, model in ipairs(Workspace:GetChildren()) do
		if model:IsA("Model")
			and model ~= character
			and model:GetAttribute("Kind") == "Ant"
			and model:GetAttribute("IsBot") ~= true
			and model:GetAttribute("Dead") ~= true
			and tonumber(model:GetAttribute("OwnerId")) ~= LocalPlayer.UserId then
			local hp = tonumber(model:GetAttribute("HP")) or 0
			local maxHp = tonumber(model:GetAttribute("MaxHP")) or 0
			local stage = tonumber(model:GetAttribute("Stage")) or 0
			local attackable = stage > 0 and stage >= myStage - mercyGap
			local root = hp > 0 and maxHp > 0 and maxHp <= myMaxHp and attackable and critterRoot(model) or nil
			if root and select(2, pcall(Config.InSafeZone, root.Position)) == true then
				-- Nobody can be hurt inside the spawn safe zone.
				root = nil
			end
			if root and farm.pvpSkip and (farm.pvpSkip[model] or 0) > os.clock() then
				-- Our bites were not landing on this one (spawn safe bubble etc.).
				root = nil
			end
			if root then
				local distance = (root.Position - origin).Magnitude
				if distance <= limit and (not bestHp or hp < bestHp or (hp == bestHp and distance < bestDist)) then
					bestModel, bestRoot, bestDist, bestHp = model, root, distance, hp
				end
			end
		end
	end
	return bestModel, bestRoot, bestDist
end

local function stepBite()
	local dungeonActive = inDungeon()
	local questCombat = questNeeds("bugs") or (STATE.pvpQuest == true and questNeeds("ants"))
	if (STATE.autoBite ~= true and STATE.autoPvp ~= true and not dungeonActive and not questCombat) or os.clock() < farm.nextBite then
		return
	end
	if farm.godRecovering == true and not dungeonActive then
		-- God Mode is healing: biting keeps us in combat and stops the regen.
		return
	end
	local character, root = living()
	if not character then
		return
	end
	local length = tonumber(character:GetAttribute("Length")) or 10
	local range = 18
	local ok, got = pcall(function()
		return Config.BiteRange(length)
	end)
	if ok and type(got) == "number" then
		range = got + 4
	end
	local foe = STATE.autoPvp == true and nearestPvpTarget(root.Position, range) or nil
	if not foe then
		foe = nearestCritter(root.Position, range)
	end
	if not foe and STATE.pvpQuest == true and questNeeds("ants") then
		foe = nearestAnt(root.Position, range)
	end
	local entityId = foe and foe:GetAttribute("EntityId")
	if type(entityId) ~= "number" then
		return
	end
	-- Match the native client's accepted cadence instead of firing exactly on the
	-- server boundary, where normal network jitter can silently drop a bite.
	farm.nextBite = os.clock() + (tonumber(Config.Combat and Config.Combat.BiteCooldown) or 0.55) + 0.03
	pcall(function()
		Net.Get("Bite"):FireServer(entityId)
	end)
end

local function equippedAbility()
	local equipped = stateJson("Equipped")
	if type(equipped) ~= "table" then
		local character = LocalPlayer.Character
		equipped = character and readJson(character:GetAttribute("Muts"))
	end
	if type(equipped) ~= "table" then
		return nil
	end
	for _, name in pairs(equipped) do
		if type(name) == "string" then
			local mutation = Config.MutationByKey[name]
			if type(mutation) == "table" then
				local ok, button = pcall(function()
					return Config.IsButtonAbility(mutation.ability)
				end)
				if ok and button and type(mutation.ability) == "string" then
					return mutation.ability
				end
			end
		end
	end
	return nil
end

local function stepAbility()
	local dungeonActive = inDungeon()
	local questCombat = questNeeds("bugs") or (STATE.pvpQuest == true and questNeeds("ants"))
	if (STATE.autoAbility ~= true and STATE.autoPvp ~= true and not dungeonActive and not questCombat) or os.clock() < farm.nextAbility then
		return
	end
	if farm.godRecovering == true and not dungeonActive then
		return
	end
	local character, root = living()
	if not character then
		return
	end
	local name = equippedAbility()
	if name ~= "Spit" and name ~= "Meteor" and name ~= "Web" and name ~= "Stomp" and name ~= "Tornado" and name ~= "Drain" then
		return
	end
	local info = Config.Abilities[name]
	local length = tonumber(character:GetAttribute("Length")) or 10
	local reach = 40
	if type(info) == "table" and type(info.Range) == "number" then
		reach = info.Range + length * 4
	elseif type(info) == "table" and type(info.Radius) == "number" then
		reach = info.Radius * length + (tonumber(info.RadiusAdd) or 0)
	end
	local foeRoot
	if STATE.autoPvp == true then
		local _, pvpRoot = nearestPvpTarget(root.Position, reach)
		foeRoot = pvpRoot
	end
	if not foeRoot then
		local _, critterTarget = nearestCritter(root.Position, reach)
		foeRoot = critterTarget
	end
	if not foeRoot and STATE.pvpQuest == true and questNeeds("ants") then
		local _, antRoot = nearestAnt(root.Position, reach)
		foeRoot = antRoot
	end
	if not foeRoot then
		return
	end
	local cooldown = type(info) == "table" and tonumber(info.Cooldown) or 8
	farm.nextAbility = os.clock() + cooldown + 0.2
	local aim = foeRoot.Position
	if name == "Stomp" or name == "Tornado" or name == "Drain" then
		aim = root.Position
	end
	pcall(function()
		Net.Get("Ability"):FireServer(name, aim)
	end)
end

local function stepEvolve()
	local power = stateNumber("Power")
	local need = stateNumber("Need")
	local stage = stateNumber("Stage")
	local rebirths = stateNumber("Rebirths")
	STATE.power = power
	STATE.rebirths = rebirths
	STATE.dna = stateNumber("DNA")
	local species = Config.SpeciesAt(stage)
	STATE.stageName = type(species) == "table" and (species.name or species.short) or tostring(stage)
	if os.clock() < farm.nextEvolve or not living() then
		return
	end
	if need <= 0 or power < need then
		return
	end
	local top = Config.TopStage(rebirths)
	farm.nextEvolve = os.clock() + 1.6
	if type(top) == "number" and top <= stage then
		if STATE.autoRebirth == true then
			invoke("Rebirth")
			STATE.status = "Rebirth"
		end
		return
	end
	if STATE.autoEvolve == true or questNeeds("evolve") then
		invoke("Evolve")
		STATE.status = "Evolving"
	end
end

local function stepHatch()
	if (STATE.autoHatch ~= true and not questNeeds("pets")) or os.clock() < farm.nextHatch then
		return
	end
	local owned = stateJson("PetsOwned") or {}
	if type(STATE.petTarget) == "string" and STATE.petTarget ~= "Off" and (tonumber(owned[STATE.petTarget]) or 0) > 0 then
		STATE.detail = "Pet target owned"
		return
	end
	local eggKey = STATE.egg
	if eggKey == "Best Affordable" then
		local royal = Config.PetEggByKey.Royal
		eggKey = type(royal) == "table" and dnaAvailable() >= (tonumber(royal.cost) or math.huge) and "Royal" or "Colony"
	end
	if eggKey ~= "Royal" and eggKey ~= "Colony" then
		return
	end
	local egg = Config.PetEggByKey[eggKey]
	local cost = type(egg) == "table" and tonumber(egg.cost) or nil
	if not cost or dnaAvailable() < cost then
		return
	end
	farm.nextHatch = os.clock() + 2
	invoke("HatchPet", eggKey)
end

local RARITY_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
}

local function stepRoll()
	if (STATE.autoRoll ~= true and not questNeeds("roll")) or os.clock() < farm.nextRoll then
		return
	end
	local eventKey = activeEvent()
	local luckActive = eventKey == "LuckyHour"
		or (stateNumber("BoostMult_Luck") > 1 and stateNumber("BoostEnd_Luck") > Workspace:GetServerTimeNow())
	if STATE.luckyRollsOnly == true and not luckActive then
		STATE.detail = "Saving rolls for Lucky Hour"
		return
	end
	local owned = stateJson("Mutations") or {}
	if type(STATE.rollTargetMutation) == "string" and STATE.rollTargetMutation ~= "Off" and (tonumber(owned[STATE.rollTargetMutation]) or 0) > 0 then
		STATE.detail = "Mutation target owned"
		return
	end
	local rarityGoal = RARITY_RANK[STATE.rollTargetRarity]
	if rarityGoal then
		for key, amount in pairs(owned) do
			local info = type(key) == "string" and Config.MutationByKey[key] or nil
			if (tonumber(amount) or 0) > 0 and type(info) == "table" and (RARITY_RANK[info.rarity] or 0) >= rarityGoal then
				STATE.detail = "Mutation rarity target owned"
				return
			end
		end
	end
	local count = STATE.rollSize == "5" and 5 or 1
	local tokens = math.max(0, math.floor(stateNumber("RollTokens")))
	local cost = tonumber(Config.RollCostDna) or 120
	local afford = tokens + math.floor(dnaAvailable() / cost)
	if count == 5 and afford < 5 and afford >= 1 then
		count = 1
	end
	if afford < count then
		farm.nextRoll = os.clock() + 5
		return
	end
	farm.nextRoll = os.clock() + 6
	invoke("RollMutation", count)
	noteActivity(count == 1 and "Rolled 1 mutation" or "Rolled 5 mutations")
end

local function stepMutations()
	if STATE.autoMutations ~= true or os.clock() < farm.nextMutations then
		return
	end
	farm.nextMutations = os.clock() + 8
	local owned = stateJson("Mutations")
	if type(owned) ~= "table" then
		return
	end
	local slots = math.clamp(math.floor(stateNumber("Slots")), 1, tonumber(Config.MaxSlots) or 3)
	local ranked = {}
	for key, amount in pairs(owned) do
		local info = type(key) == "string" and Config.MutationByKey[key] or nil
		if type(info) == "table" and (tonumber(amount) or 0) > 0 then
			table.insert(ranked, {
				key = key,
				rank = RARITY_RANK[info.rarity] or 0,
				amount = tonumber(amount) or 0,
			})
		end
	end
	table.sort(ranked, function(a, b)
		if a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return a.amount > b.amount
	end)
	local equipped = stateJson("Equipped")
	if type(equipped) ~= "table" then
		equipped = {}
	end
	for slot = 1, slots do
		local want = ranked[slot]
		if want and equipped[slot] ~= want.key then
			invoke("EquipMutation", want.key, slot)
		end
	end
end

local function breedInfo(key)
	if type(key) ~= "string" or key == "" or key == "Keep" then
		return nil
	end
	local info = type(Config.BreedByKey) == "table" and Config.BreedByKey[key] or nil
	if type(info) ~= "table" then
		return nil
	end
	if type(Config.LimitedBreeds) == "table" then
		for _, breed in ipairs(Config.LimitedBreeds) do
			if type(breed) == "table" and breed.key == key then
				if type(Config.BreedUnlocked) ~= "function" then
					return nil
				end
				local ok, unlocked = pcall(Config.BreedUnlocked, key, stateNumber("Rebirths"), stateJson("LimitedOwned"))
				if not ok or unlocked ~= true then
					return nil
				end
				break
			end
		end
	end
	return info
end

function STATE.wearBreed()
	local info = breedInfo(STATE.breed)
	if not info or GameState.Get("Breed") == STATE.breed then
		return false
	end
	invoke("SetBreed", STATE.breed)
	noteActivity("Wearing " .. tostring(info.name or STATE.breed))
	return true
end

local function stepSprint()
	local signals = require(ReplicatedStorage.Ant.Client.Signals)
	if STATE.autoSprint == true then
		farm.sprintHeld = true
		signals.Action:Fire("Sprint", true)
		return
	end
	if farm.sprintHeld then
		farm.sprintHeld = false
		signals.Action:Fire("Sprint", false)
	end
end

function STATE.equipBestNow()
	invoke("EquipPet", "best")
	return true
end

local function savedTable(name)
	local ok, raw = pcall(function()
		return GameState.Get(name)
	end)
	if ok and type(raw) == "string" then
		return readJson(raw) or {}
	end
	if ok and type(raw) == "table" then
		return raw
	end
	return stateJson(name) or {}
end

local function breedOrder(key)
	local info = type(key) == "string" and type(Config.BreedByKey) == "table" and Config.BreedByKey[key] or nil
	if type(info) ~= "table" then
		return 0
	end
	return tonumber(info.order) or 0
end

local function bestBreedKey()
	local rebirths = stateNumber("Rebirths")
	local bestKey, bestOrder = nil, -1
	local function consider(breed, limited)
		if type(breed) ~= "table" or type(breed.key) ~= "string" then
			return
		end
		if limited then
			if type(Config.BreedUnlocked) ~= "function" then
				return
			end
			local ok, open = pcall(Config.BreedUnlocked, breed.key, rebirths, stateJson("LimitedOwned"))
			if not ok or open ~= true then
				return
			end
		elseif rebirths < (tonumber(breed.rebirths) or 0) then
			return
		end
		local order = tonumber(breed.order) or 0
		if order > bestOrder then
			bestKey = breed.key
			bestOrder = order
		end
	end
	if type(Config.Breeds) == "table" then
		for _, breed in ipairs(Config.Breeds) do
			consider(breed, false)
		end
	end
	if type(Config.LimitedBreeds) == "table" then
		for _, breed in ipairs(Config.LimitedBreeds) do
			consider(breed, true)
		end
	end
	return bestKey
end

local function stepBestBreed()
	if STATE.autoBestBreed ~= true or os.clock() < farm.nextBreed then
		return
	end
	farm.nextBreed = os.clock() + 8
	local key = bestBreedKey()
	local wearing = GameState.Get("Breed")
	if not key or wearing == key or breedOrder(key) <= breedOrder(wearing) then
		return
	end
	local sent = invokeResult("SetBreed", key)
	if sent then
		task.delay(0.5, function()
			local ok, current = pcall(GameState.Get, "Breed")
			if running() and ok and current == key then
				noteActivity("Wearing " .. key)
			end
		end)
	end
end

local function equippedPetCounts()
	local counts = {}
	local character = LocalPlayer.Character
	local raw = character and character:GetAttribute("Pets")
	local list = nil
	if type(raw) == "string" then
		list = readJson(raw)
	elseif type(raw) == "table" then
		list = raw
	end
	if type(list) == "table" then
		for _, key in ipairs(list) do
			if type(key) == "string" then
				counts[key] = (counts[key] or 0) + 1
			end
		end
	end
	return counts
end

local function stepFuse()
	if STATE.autoFuse ~= true or os.clock() < farm.nextFuse then
		return
	end
	farm.nextFuse = os.clock() + 3
	if type(Config.PetFuseCost) ~= "function" then
		return
	end
	local maxLevel = 5
	if type(Config.PetMaxLevel) == "function" then
		local ok, value = pcall(Config.PetMaxLevel)
		if ok and type(value) == "number" then
			maxLevel = value
		end
	end
	local owned = savedTable("PetsOwned")
	local levels = savedTable("PetLevels")
	local equipped = equippedPetCounts()
	for key, amount in pairs(owned) do
		if type(key) == "string" then
			local count = math.floor(tonumber(amount) or 0)
			local level = math.clamp(math.floor(tonumber(levels[key]) or 1), 1, maxLevel)
			if level < maxLevel then
				local ok, cost = pcall(Config.PetFuseCost, level)
				cost = ok and tonumber(cost) or nil
				local spare = math.max(0, count - math.max(1, equipped[key] or 0))
				if cost and cost > 0 and spare >= cost then
					local sent = invokeResult("FusePet", key)
					if sent then
						local beforeCount = count
						local beforeLevel = level
						task.delay(0.5, function()
							if not running() then
								return
							end
							local nowOwned = savedTable("PetsOwned")
							local nowLevels = savedTable("PetLevels")
							if (tonumber(nowOwned[key]) or 0) ~= beforeCount or (tonumber(nowLevels[key]) or 1) > beforeLevel then
								noteActivity("Fused " .. key)
							end
						end)
					end
					return
				end
			end
		end
	end
end

local function stepEquip()
	if STATE.autoEquip ~= true or os.clock() < farm.nextEquip then
		return
	end
	farm.nextEquip = os.clock() + 12
	STATE.equipBestNow()
end

local function remoteAccepted(sent, result)
	return sent and (type(result) ~= "table" or result.ok ~= false)
end

local UPGRADE_FLAGS = {
	Jaws = "upgradeJaws",
	Shell = "upgradeShell",
	Legs = "upgradeLegs",
	Magnet = "upgradeMagnet",
	Appetite = "upgradeAppetite",
	Regen = "upgradeRegen",
}

local function stepUpgrades()
	if STATE.autoUpgrade ~= true or os.clock() < farm.nextUpgrade then
		return
	end
	farm.nextUpgrade = os.clock() + 1.5
	local available = dnaAvailable()
	local best, bestCost
	for _, info in ipairs(type(Config.Upgrades) == "table" and Config.Upgrades or {}) do
		if type(info) == "table" and type(info.key) == "string" and STATE[UPGRADE_FLAGS[info.key]] == true then
			local level = math.max(0, math.floor(stateNumber("Up_" .. info.key)))
			local ok, cost = pcall(Config.UpgradeCost, info.key, level)
			cost = ok and tonumber(cost) or nil
			if cost and cost <= available and (not bestCost or cost < bestCost) then
				best, bestCost = info, cost
			end
		end
	end
	if not best then
		return
	end
	local sent, result = invokeResult("BuyUpgrade", best.key)
	if remoteAccepted(sent, result) then
		noteActivity("Upgraded " .. tostring(best.name or best.key))
		return
	end
	if sent and type(result) == "table" and result.ok == false then
		local message = tostring(result.msg or "")
		local lower = string.lower(message)
		if string.find(lower, "gone", 1, true)
			or string.find(lower, "removed", 1, true)
			or string.find(lower, "unavailable", 1, true) then
			-- The v427 server still exposes BuyUpgrade and the old upgrade data, but
			-- rejects purchases with "Upgrades are gone". Stop retrying the dead
			-- feature and persist the correction for the next loader run.
			STATE.autoUpgrade = false
			STATE.upgradesUnavailable = message ~= "" and message or "Unavailable on this server"
			noteActivity("Auto upgrades off: " .. STATE.upgradesUnavailable)
			if STATE.writeConfig then
				STATE.writeConfig()
			end
		end
	end
end

local function stepPassClaims()
	if STATE.autoBattlePass ~= true or os.clock() < farm.nextPass then
		return
	end
	farm.nextPass = os.clock() + 25
	local sent, result = invokeResult("PassAction", "claimAll")
	if remoteAccepted(sent, result) and type(result) == "table" and result.ok == true then
		noteActivity("Claimed battle pass rewards")
	end
	local bp = stateJson("BP")
	local weekly = type(bp) == "table" and bp.w or nil
	if type(weekly) == "table" and type(weekly.q) == "table" then
		local complete = 0
		for index, row in ipairs(weekly.q) do
			if type(row) == "table" then
				if row[4] == 1 then
					complete += 1
				elseif (tonumber(row[3]) or 0) >= (tonumber(row[2]) or math.huge) then
					-- The server takes the quest's slot number (1..n), not its key:
					-- a key gets "Pick a quest!" (place v502). PassAction also has a
					-- short per-player cooldown: a call straight after claimAll gets
					-- "Slow down!", so wait before every call.
					task.wait(1.25)
					local okClaim, claimResult = invokeResult("PassAction", "weekly", index)
					if remoteAccepted(okClaim, claimResult) then
						complete += 1
						noteActivity("Claimed a weekly quest")
					end
				end
			end
		end
		if complete >= #weekly.q and weekly.b ~= 1 then
			task.wait(1.25)
			invokeResult("PassAction", "weeklyBonus")
		end
	end
end

local function stepKillClaims()
	if STATE.autoKillRewards ~= true or os.clock() < farm.nextKillClaim then
		return
	end
	farm.nextKillClaim = os.clock() + 30
	local track = stateJson("KillTrack") or {}
	local claimed = {}
	for key, value in pairs(type(track.c) == "table" and track.c or {}) do
		local index = tonumber(value) or tonumber(key)
		if index then
			claimed[index] = true
		end
	end
	local kills = stateNumber("Kills")
	for index, milestone in ipairs(type(Content.Kills) == "table" and type(Content.Kills.Milestones) == "table" and Content.Kills.Milestones or {}) do
		if not claimed[index] and kills >= (tonumber(milestone.n) or math.huge) then
			local sent, result = invokeResult("ClaimKill", index)
			if remoteAccepted(sent, result) then
				noteActivity("Claimed kill milestone " .. tostring(milestone.n))
			end
			task.wait(0.7)
		end
	end
end

local function stepMole()
	if STATE.autoMole ~= true or os.clock() < farm.nextMole then
		return
	end
	farm.nextMole = os.clock() + 4
	local item = type(Content.MoleByKey) == "table" and Content.MoleByKey[STATE.moleItem] or nil
	if type(item) ~= "table" then
		return
	end
	local bought = stateJson("MoleBought") or {}
	if item.once and bought[item.key] ~= nil then
		return
	end
	if stateNumber("Worms") - (tonumber(STATE.wormReserve) or 0) < (tonumber(item.cost) or math.huge) then
		return
	end
	-- Boosts stack their time on the server, so buying them all at once would
	-- bank hours of boost that a cap could throw away. Buy the next one only
	-- when the running boost is about to end, so it stays on without a gap.
	local boost = type(item.reward) == "table" and item.reward.boost or nil
	if type(boost) == "table" and boost.kind then
		local left = (tonumber(LocalPlayer:GetAttribute("BoostEnd_" .. tostring(boost.kind))) or 0) - os.time()
		if left > 45 then
			return
		end
	end
	local sent, result = invokeResult("MoleBuy", item.key)
	if remoteAccepted(sent, result) then
		noteActivity("Traded worms for " .. tostring(item.name or item.key))
	end
end

local function stepCosmeticCrate()
	if STATE.autoCosmeticCrates ~= true or os.clock() < farm.nextCosmetic then
		return
	end
	farm.nextCosmetic = os.clock() + 4
	if type(Cosmetics.SlotByKey) ~= "table" or not Cosmetics.SlotByKey[STATE.cosmeticSlot] then
		return
	end
	local cost = type(Cosmetics.CrateCost) == "function" and Cosmetics.CrateCost(stateNumber("Rebirths")) or math.huge
	if dnaAvailable() < cost then
		return
	end
	local sent, result = invokeResult("CosmeticCrate", STATE.cosmeticSlot)
	if remoteAccepted(sent, result) then
		noteActivity("Opened " .. tostring(STATE.cosmeticSlot) .. " crate")
	end
end

local function stepBestAura()
	if STATE.autoBestAura ~= true or os.clock() < farm.nextAura then
		return
	end
	farm.nextAura = os.clock() + 15
	local ownedList = stateJson("CosOwned") or {}
	local equipped = stateJson("Cosm") or {}
	local bestKey, bestRank
	for _, key in pairs(ownedList) do
		local info = type(Cosmetics.ByKey) == "table" and Cosmetics.ByKey[key] or nil
		if type(info) == "table" and info.slot == "Aura" then
			local rarity = type(Cosmetics.RarityByKey) == "table" and Cosmetics.RarityByKey[info.rarity] or nil
			local rank = type(rarity) == "table" and tonumber(rarity.order) or 0
			if not bestRank or rank > bestRank then
				bestKey, bestRank = key, rank
			end
		end
	end
	if bestKey and equipped.Aura ~= bestKey then
		local sent, result = invokeResult("CosmeticEquip", "Aura", bestKey)
		if remoteAccepted(sent, result) then
			noteActivity("Equipped best aura")
		end
	end
end

local CODES = { "ANTS", "EVOLVE", "QUEEN", "RELEASE" }

local RewardTheme
local function rewardNow()
	if RewardTheme == nil then
		local ok, theme = pcall(function()
			return require(ReplicatedStorage.Ant.UI.Theme)
		end)
		RewardTheme = ok and theme or false
	end
	if RewardTheme and RewardTheme.Now then
		return RewardTheme.Now()
	end
	return Workspace:GetServerTimeNow()
end

local function callClaim(name, ...)
	local args = table.pack(...)
	local function once()
		local ok, result = pcall(function()
			return Net.Get(name):InvokeServer(table.unpack(args, 1, args.n))
		end)
		if not ok or type(result) ~= "table" then
			return { ok = false, msg = ok and "" or tostring(result) }
		end
		return result
	end
	local result = once()
	if result.msg == "Slow down!" and running() then
		task.wait(1.2)
		result = once()
	end
	return result
end

local function claimedPlay()
	local claimed = {}
	local list = stateJson("PlaytimeClaimed")
	if type(list) ~= "table" then
		return claimed
	end
	for _, entry in pairs(list) do
		local index = tonumber(entry)
		if index then
			claimed[index] = true
		end
	end
	return claimed
end

local function takeRewards()
	local count = 0
	local gap = 0.9
	local function took(result, text)
		task.wait(gap)
		if result.ok then
			count += 1
			noteActivity(text)
		end
	end
	if STATE.autoClaim == true then
		local okDaily, dailyNext = pcall(function()
			return GameState.Get("DailyNext")
		end)
		dailyNext = okDaily and tonumber(dailyNext) or nil
		if dailyNext and dailyNext <= rewardNow() then
			took(callClaim("ClaimDaily"), "Claimed the daily")
		end
		local started = stateNumber("PlayStart")
		local played = started > 0 and math.max(0, rewardNow() - started) or 0
		local claimed = claimedPlay()
		for index, reward in ipairs(Config.Playtime) do
			if not running() then
				return count
			end
			if type(reward) == "table" and not claimed[index] then
				local need = (tonumber(reward.minutes) or 9999) * 60
				if played < need then
					break
				end
				local result = callClaim("ClaimPlaytime", index)
				if result.ok then
					claimed[index] = true
				end
				took(result, "Claimed a playtime gift")
			end
		end
		local quests = stateJson("Quests")
		if type(quests) == "table" and type(quests.q) == "table" then
			local finished = 0
			for index, row in ipairs(quests.q) do
				if not running() then
					return count
				end
				if type(row) == "table" then
					if row[5] == 1 then
						finished += 1
					elseif (tonumber(row[4]) or 0) >= (tonumber(row[3]) or 1) then
						local result = callClaim("ClaimQuest", index)
						took(result, "Claimed a quest")
						if result.ok then
							finished += 1
						end
					end
				end
			end
			if finished >= #quests.q and quests.b ~= 1 then
				took(callClaim("ClaimQuest", "bonus"), "Claimed the quest bonus")
			end
		end
		local records = stateJson("Records")
		local list = type(Config.Records) == "table" and Config.Records.List or nil
		if type(records) == "table" and type(list) == "table" then
			for index, spec in ipairs(list) do
				if not running() then
					return count
				end
				local row = records[index]
				if type(spec) == "table" and type(spec.goals) == "table" and type(spec.key) == "string" and type(row) == "table" then
					local tier = math.floor(tonumber(row[1]) or 0)
					local goal = spec.goals[tier + 1]
					if goal and (tonumber(row[2]) or 0) >= goal then
						took(callClaim("ClaimRecord", spec.key), "Claimed a record")
					end
				end
			end
		end
		if GameState.Get("CommunityClaimed") ~= true and os.clock() >= farm.nextCommunity then
			farm.nextCommunity = os.clock() + 120
			took(callClaim("CommunityClaim"), "Claimed the group reward")
		end
	end
	if STATE.autoCodes == true and not farm.codesDone then
		farm.codesDone = true
		for _, code in ipairs(CODES) do
			if not running() then
				return count
			end
			callClaim("Redeem", code)
			task.wait(gap)
		end
	end
	if count > 0 then
		STATE.detail = "Claimed " .. count
	end
	return count
end

function STATE.claimNow()
	if farm.claiming then
		return 0
	end
	farm.claiming = true
	local count = 0
	local ok, err = xpcall(function()
		count = takeRewards()
	end, debug.traceback)
	farm.claiming = false
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
		return 0
	end
	return count
end

local function stepClaims()
	if farm.claiming or os.clock() < farm.nextClaim then
		return
	end
	if STATE.autoClaim ~= true and not (STATE.autoCodes == true and not farm.codesDone) then
		return
	end
	farm.nextClaim = os.clock() + 20
	task.spawn(STATE.claimNow)
end

local function espBoard(model, text, color)
	local existing = farm.esp[model]
	if existing and existing.Parent then
		local label = existing:FindFirstChild("Label")
		if label then
			label.Text = text
		end
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "ZinoosAntEsp"
	board.Size = UDim2.fromOffset(140, 28)
	board.StudsOffset = Vector3.new(0, 3, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	local espLabel = Instance.new("TextLabel")
	espLabel.Name = "Label"
	espLabel.BackgroundTransparency = 0.35
	espLabel.BackgroundColor3 = Color3.fromRGB(16, 12, 24)
	espLabel.Size = UDim2.fromScale(1, 1)
	espLabel.Font = Enum.Font.GothamMedium
	espLabel.TextSize = 12
	espLabel.TextColor3 = color
	espLabel.Text = text
	espLabel.Parent = board
	local espCorner = Instance.new("UICorner")
	espCorner.CornerRadius = UDim.new(0, 6)
	espCorner.Parent = espLabel
	board.Adornee = critterRoot(model)
	board.Parent = model
	farm.esp[model] = board
end

local function stepEsp()
	if os.clock() < farm.nextEsp then
		return
	end
	farm.nextEsp = os.clock() + 1
	local seen = {}
	if STATE.critterEsp == true then
		local folder = Workspace:FindFirstChild("Ants")
		local critters = folder and folder:FindFirstChild("Critters")
		if critters then
			for _, model in ipairs(critters:GetChildren()) do
				if model:IsA("Model") then
					local hp = tonumber(model:GetAttribute("HP")) or 0
					if hp > 0 then
						seen[model] = true
						espBoard(model, model.Name .. "  " .. shortNumber(hp), Color3.fromRGB(255, 120, 140))
					end
				end
			end
		end
	end
	if STATE.playerEsp == true then
		for _, model in ipairs(Workspace:GetChildren()) do
			if model:IsA("Model") and model ~= LocalPlayer.Character and model:GetAttribute("Kind") == "Ant" and model:GetAttribute("IsCritter") ~= true then
				seen[model] = true
				espBoard(model, tostring(model:GetAttribute("DisplayName") or model.Name), Color3.fromRGB(180, 210, 255))
			end
		end
	end
	for model, board in pairs(farm.esp) do
		if not seen[model] then
			board:Destroy()
			farm.esp[model] = nil
		end
	end
end

hubCleanup(function()
	for _, board in pairs(farm.esp) do
		if board then
			board:Destroy()
		end
	end
	table.clear(farm.esp)
end)

trackConnection(Net.Get("OrbSpawn").OnClientEvent:Connect(function(payload)
	if running() then
		ingestOrbs(payload)
	end
end))
trackConnection(Net.Get("OrbTaken").OnClientEvent:Connect(function(payload)
	if running() then
		ingestTaken(payload)
	end
end))
refreshOrbs()

do
	local ok, anteaterFx = pcall(Net.Get, "AnteaterFx")
	if ok and anteaterFx then
		trackConnection(anteaterFx.OnClientEvent:Connect(function(kind, data)
			if not running() or type(data) ~= "table" then
				return
			end
			local character = LocalPlayer.Character
			local me = tonumber(character and character:GetAttribute("EntityId")) or LocalPlayer.UserId
			if kind == "aim" then
				if tonumber(data.v) == me then
					farm.anteaterDodge = {
						boss = tonumber(data.b),
						untilT = os.clock() + (tonumber(data.s) or 1.2) + 0.6,
						side = math.random() < 0.5 and -1 or 1,
					}
				end
			elseif kind == "lock" then
				if farm.anteaterDodge and typeof(data.at) == "Vector3" then
					farm.anteaterDodge.at = data.at
				end
			elseif kind == "grab" then
				-- Grabs of other ants must not end our own dodge.
				if tonumber(data.v) == me then
					farm.anteaterDodge = nil
				end
			elseif kind == "miss" then
				local dodge = farm.anteaterDodge
				if dodge and typeof(dodge.at) == "Vector3" and typeof(data.at) == "Vector3" and (dodge.at - data.at).Magnitude < 15 then
					farm.anteaterDodge = nil
				end
			elseif kind == "down" or kind == "left" then
				farm.anteaterDodge = nil
			end
		end))
	end
end

-- Movement helpers.
trackConnection(UserInputService.JumpRequest:Connect(function()
	local hum = humanoid()
	if STATE.infiniteJump == true and hum and not seated() then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end))

local noclipParts = {}
local function restoreNoclip()
	for part in pairs(noclipParts) do
		if part.Parent then
			part.CanCollide = true
		end
	end
	table.clear(noclipParts)
end

globalValue = function(name)
	local ok, value = pcall(function()
		return GameState.Global(name)
	end)
	return ok and value or nil
end

activeEvent = function()
	local key = globalValue("Event")
	if type(key) ~= "string" or key == "" then
		STATE.eventKey = ""
		STATE.eventName = "No live event"
		return nil, nil
	end
	local data = readJson(globalValue("EventData")) or {}
	local spec = type(EventsConfig.List) == "table" and EventsConfig.List[key] or nil
	STATE.eventKey = key
	STATE.eventName = (type(spec) == "table" and spec.name) or data.name or key
	STATE.eventEnd = tonumber(data.ends) or tonumber(globalValue("EventEnd")) or 0
	return key, data
end

dungeonState = function()
	return stateJson("Dungeon")
end

inDungeon = function()
	local data = dungeonState()
	return type(data) == "table" and type(data.st) == "string", data
end

activeQuestKeys = function()
	local keys = {}
	local quests = stateJson("Quests")
	if type(quests) == "table" and type(quests.q) == "table" then
		for _, row in ipairs(quests.q) do
			if type(row) == "table" and row[5] ~= 1 and (tonumber(row[4]) or 0) < (tonumber(row[3]) or 0) then
				keys[tostring(row[1])] = true
			end
		end
	end
	local bp = stateJson("BP")
	local weekly = type(bp) == "table" and bp.w or nil
	if type(weekly) == "table" and type(weekly.q) == "table" then
		for _, row in ipairs(weekly.q) do
			if type(row) == "table" and row[4] ~= 1 and (tonumber(row[3]) or 0) < (tonumber(row[2]) or 0) then
				keys[tostring(row[1])] = true
			end
		end
	end
	return keys
end

questNeeds = function(kind)
	if STATE.questAssist ~= true then
		return false
	end
	local keys = activeQuestKeys()
	return keys[kind] == true or keys["w_" .. kind] == true
end

dnaAvailable = function()
	return math.max(0, stateNumber("DNA") - (tonumber(STATE.dnaReserve) or 0))
end
hubCleanup(restoreNoclip)
trackConnection(RunService.Stepped:Connect(function()
	local character = LocalPlayer.Character
	if not character then
		return
	end
	if STATE.noclip == true then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				noclipParts[part] = true
				part.CanCollide = false
			end
		end
	elseif next(noclipParts) then
		restoreNoclip()
	end
end))

local promptDurationsBefore = setmetatable({}, { __mode = "k" })
local function restoreInstantPrompts()
	for prompt, duration in pairs(promptDurationsBefore) do
		if prompt.Parent then
			prompt.HoldDuration = duration
		end
	end
	table.clear(promptDurationsBefore)
end
hubCleanup(restoreInstantPrompts)
trackConnection(ProximityPromptService.PromptShown:Connect(function(prompt)
	if STATE.instantPrompts == true then
		if promptDurationsBefore[prompt] == nil then
			promptDurationsBefore[prompt] = prompt.HoldDuration
		end
		prompt.HoldDuration = 0
	end
end))

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
local pauseGuisBefore = setmetatable({}, { __mode = "k" })
local function restorePausePopup()
	if next(pauseGuisBefore) == nil then
		return
	end
	elevate()
	local pending = {}
	for gui, enabled in pairs(pauseGuisBefore) do
		if gui.Parent then
			gui.Enabled = enabled
			table.insert(pending, { gui = gui, enabled = enabled })
		end
	end
	table.clear(pauseGuisBefore)
	-- One loop body may already be yielding when unload starts. Repeat the
	-- restoration after those threads have had a chance to observe the stop.
	task.defer(function()
		elevate()
		if running() and STATE.noPausePopup == true then
			return
		end
		for _, entry in ipairs(pending) do
			if entry.gui.Parent then
				entry.gui.Enabled = entry.enabled
			end
		end
	end)
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

-- Auto reload: when this client is teleported (Auto Reconnect, the game's own
-- AFK rejoin, a server hop, an update shutdown), queue a small script that
-- loads this hub again in the new server. Same as the Throw Food hub.
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
if env.ZinoosAntGen ~= nil then return end
local ok, source = pcall(function()
	return game:HttpGet("https://raw.githubusercontent.com/yszvzms6st-pixel/ZinoosHub/refs/heads/main/games/AntEvolution.luau")
end)
if not ok or type(source) ~= "string" or #source < 1000 or env.ZinoosAntGen ~= nil then return end
local chunk = loadstring(source, "=ZinoosHub/AntEvolution.luau")
if chunk then chunk() end
]==]
	RELOAD_BODY = string.gsub(RELOAD_BODY, "__PLACE__", tostring(game.PlaceId))
	STATE.autoReloadAvailable = typeof(queueTeleport) == "function"
	local reloadQueued = false
	STATE.queueReload = function()
		if reloadQueued or not running() or STATE.autoReload ~= true or not STATE.autoReloadAvailable then
			return
		end
		reloadQueued = pcall(queueTeleport, "getgenv().ZinoosReloadSrc = " .. string.format("%q", RELOAD_BODY) .. "\nloadstring(getgenv().ZinoosReloadSrc)()")
	end
	trackConnection(LocalPlayer.OnTeleport:Connect(function(teleportState)
		if teleportState == Enum.TeleportState.Started or teleportState == Enum.TeleportState.InProgress then
			STATE.queueReload()
		end
	end))
end

-- Auto Reconnect on Kick. v1.5.5: it used to try ONE teleport, only when
-- GuiService.ErrorMessageChanged fired; on 2026-11-24 05:58 a kick left the
-- client on the home screen for 5 hours with no attempt at all. Now any sign
-- of a disconnect (the error prompt, or the ClientReplicator going away) starts
-- a loop that keeps trying every 10 s until the teleport takes us away.
local reconnecting = false
local function startReconnect()
	if reconnecting or STATE.autoReconnect ~= true then
		return
	end
	reconnecting = true
	task.spawn(function()
		task.wait(2)
		for _ = 1, 90 do
			if not running() or STATE.autoReconnect ~= true then
				break
			end
			pcall(STATE.queueReload)
			pcall(function()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			end)
			task.wait(10)
		end
		reconnecting = false
	end)
end
pcall(function()
	trackConnection(GuiService.ErrorMessageChanged:Connect(function(message)
		if type(message) == "string" and message ~= "" then
			startReconnect()
		end
	end))
end)
pcall(function()
	local networkClient = game:GetService("NetworkClient")
	trackConnection(networkClient.ChildRemoved:Connect(function()
		startReconnect()
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

local POTATO_VISUAL_CLASSES = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Smoke = true,
	Fire = true,
	Sparkles = true,
	Highlight = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
	Decal = true,
	Texture = true,
	BloomEffect = true,
	BlurEffect = true,
	ColorCorrectionEffect = true,
	DepthOfFieldEffect = true,
	SunRaysEffect = true,
	Atmosphere = true,
	Clouds = true,
	Sky = true,
}

local function isPotatoVisual(instance)
	return instance ~= nil and POTATO_VISUAL_CLASSES[instance.ClassName] == true
end

local function lowGraphicsProperty(profile, instance, property, value, keepSuppressed)
	if graphicsBefore ~= profile or STATE.fpsBoost ~= true or not instance then
		return
	end
	local okRead, previous = pcall(function()
		return instance[property]
	end)
	if not okRead then
		return
	end
	if previous ~= value then
		local okWrite = pcall(function()
			instance[property] = value
		end)
		if not okWrite then
			return
		end
		local saved = profile.instances[instance]
		if not saved then
			saved = {}
			profile.instances[instance] = saved
		end
		if saved[property] == nil then
			saved[property] = { value = previous }
		end
	end
	if keepSuppressed then
		local suppressed = profile.suppressed[instance]
		if not suppressed then
			suppressed = {}
			profile.suppressed[instance] = suppressed
		end
		suppressed[property] = value
	end
end

local function optimizeVisual(profile, instance)
	if graphicsBefore ~= profile or STATE.fpsBoost ~= true or not instance then
		return
	end
	if not isPotatoVisual(instance) then
		return
	end
	if instance:IsA("ParticleEmitter") then
		lowGraphicsProperty(profile, instance, "Enabled", false, true)
		lowGraphicsProperty(profile, instance, "Rate", 0, true)
		lowGraphicsProperty(profile, instance, "Lifetime", NumberRange.new(0), true)
		pcall(function() instance:Clear() end)
	elseif instance:IsA("Trail") or instance:IsA("Beam") or instance:IsA("Smoke")
		or instance:IsA("Fire") or instance:IsA("Sparkles") or instance:IsA("Highlight")
		or instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
		lowGraphicsProperty(profile, instance, "Enabled", false, true)
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		lowGraphicsProperty(profile, instance, "Transparency", 1, true)
	elseif instance:IsA("PostEffect") then
		lowGraphicsProperty(profile, instance, "Enabled", false, true)
	elseif instance:IsA("Atmosphere") then
		lowGraphicsProperty(profile, instance, "Density", 0, true)
		lowGraphicsProperty(profile, instance, "Haze", 0, true)
		lowGraphicsProperty(profile, instance, "Glare", 0, true)
	elseif instance:IsA("Clouds") then
		lowGraphicsProperty(profile, instance, "Enabled", false, true)
	elseif instance:IsA("Sky") then
		lowGraphicsProperty(profile, instance, "CelestialBodiesShown", false, true)
		lowGraphicsProperty(profile, instance, "StarCount", 0, true)
	end
end

local function scanVisualTree(profile, root)
	local stack = { root }
	local scanned = 0
	local optimized = 0
	while #stack > 0 and graphicsBefore == profile and STATE.fpsBoost == true do
		local current = table.remove(stack)
		local ok, children = pcall(function()
			return current:GetChildren()
		end)
		if ok then
			for index = #children, 1, -1 do
				local child = children[index]
				stack[#stack + 1] = child
				if isPotatoVisual(child) then
					optimizeVisual(profile, child)
					optimized += 1
				end
			end
		end
		scanned += 1
		if scanned % 80 == 0 then
			RunService.Heartbeat:Wait()
		end
	end
	return scanned, optimized
end

local function restoreGraphics(profile)
	for _, connection in ipairs(profile.connections) do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(profile.connections)
	for instance, properties in pairs(profile.instances) do
		if instance.Parent then
			for property, record in pairs(properties) do
				pcall(function()
					instance[property] = record.value
				end)
			end
		end
	end
	pcall(function()
		if profile.quality then
			settings().Rendering.QualityLevel = profile.quality
		end
	end)
	if type(profile.gameQuality) == "table" then
		pcall(function()
			profile.gameQuality.Perf = profile.gamePerf
		end)
	end
end

function STATE.applyFpsBoost()
	if STATE.fpsBoost == true then
		if graphicsBefore then
			return
		end
		local profile = {
			instances = setmetatable({}, { __mode = "k" }),
			suppressed = setmetatable({}, { __mode = "k" }),
			connections = {},
		}
		graphicsBefore = profile
		pcall(function()
			profile.quality = settings().Rendering.QualityLevel
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
		pcall(function()
			local quality = require(ReplicatedStorage.Ant.Client.Quality)
			if type(quality) == "table" then
				profile.gameQuality = quality
				profile.gamePerf = quality.Perf
				quality.Perf = true
			end
		end)
		lowGraphicsProperty(profile, Lighting, "GlobalShadows", false, false)
		lowGraphicsProperty(profile, Lighting, "EnvironmentDiffuseScale", 0, false)
		lowGraphicsProperty(profile, Lighting, "EnvironmentSpecularScale", 0, false)
		lowGraphicsProperty(profile, Lighting, "ShadowSoftness", 0, false)
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			lowGraphicsProperty(profile, terrain, "Decoration", false, false)
			lowGraphicsProperty(profile, terrain, "WaterWaveSize", 0, false)
			lowGraphicsProperty(profile, terrain, "WaterWaveSpeed", 0, false)
			lowGraphicsProperty(profile, terrain, "WaterReflectance", 0, false)
			lowGraphicsProperty(profile, terrain, "WaterTransparency", 1, false)
		end
		table.insert(profile.connections, Workspace.DescendantAdded:Connect(function(instance)
			if isPotatoVisual(instance) then
				task.defer(optimizeVisual, profile, instance)
			end
		end))
		table.insert(profile.connections, Lighting.DescendantAdded:Connect(function(instance)
			if isPotatoVisual(instance) then
				task.defer(optimizeVisual, profile, instance)
			end
		end))
		task.spawn(function()
			local worldScanned, worldOptimized = scanVisualTree(profile, Workspace)
			local _, lightingOptimized = scanVisualTree(profile, Lighting)
			STATE.detail = string.format("Potato Mode optimized %d effects across %d objects", worldOptimized + lightingOptimized, worldScanned)
			while running() and graphicsBefore == profile and STATE.fpsBoost == true do
				for instance, properties in pairs(profile.suppressed) do
					if instance.Parent then
						for property, value in pairs(properties) do
							pcall(function()
								if instance[property] ~= value then
									instance[property] = value
								end
							end)
						end
					end
				end
				task.wait(2)
			end
		end)
	elseif graphicsBefore then
		local profile = graphicsBefore
		graphicsBefore = nil
		restoreGraphics(profile)
	end
end
hubCleanup(function()
	STATE.fpsBoost = false
	STATE.applyFpsBoost()
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

local function notify(category, title, message)
	if STATE.notifications == false then
		return false
	end
	noteActivity(tostring(title) .. " · " .. tostring(message or ""))
	if typeof(STATE.toast) == "function" then
		return pcall(STATE.toast, {
			category = category,
			title = tostring(title or "Zinoos Hub"),
			message = tostring(message or ""),
		})
	end
	return false
end

-- The dashboard is the same WindUI window Throw Food For Animals uses.
local WINDUI_URL = "https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua"
local WINDUI_CACHE_KEY = WINDUI_URL

local function loadWindUI()
	local caches = type(genv.ZinoosWindUISources) == "table" and genv.ZinoosWindUISources or {}
	genv.ZinoosWindUISources = caches
	local source = caches[WINDUI_CACHE_KEY]
	if type(source) ~= "string" or #source < 1000 then
		local ok, body = pcall(function()
			return game:HttpGet(WINDUI_URL)
		end)
		elevate()
		if not ok or type(body) ~= "string" or #body < 1000 then
			return nil, "download failed"
		end
		source = body
		caches[WINDUI_CACHE_KEY] = source
		genv.ZinoosWindUISource = source
		genv.ZinoosWindUISourceKey = WINDUI_CACHE_KEY
	end
	local chunk, compileError = loadstring(source, "=WindUI")
	if not chunk then
		caches[WINDUI_CACHE_KEY] = nil
		if genv.ZinoosWindUISourceKey == WINDUI_CACHE_KEY then
			genv.ZinoosWindUISource = nil
			genv.ZinoosWindUISourceKey = nil
		end
		return nil, compileError
	end
	local ok, library = pcall(chunk)
	elevate()
	if not ok or type(library) ~= "table" then
		caches[WINDUI_CACHE_KEY] = nil
		if genv.ZinoosWindUISourceKey == WINDUI_CACHE_KEY then
			genv.ZinoosWindUISource = nil
			genv.ZinoosWindUISourceKey = nil
		end
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

	local WindUI, loadError = loadWindUI()
	if not WindUI then
		warn("[Zinoos hub] Menu could not load (" .. tostring(loadError) .. "). Automation is still running with your saved settings.")
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
		Author = "Ant Evolution",
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

	local streamer = { names = {}, boards = {}, images = {} }
	local function maskNames(hide)
		local aliases = {}
		if type(LocalPlayer.Name) == "string" and #LocalPlayer.Name >= 4 then
			table.insert(aliases, LocalPlayer.Name)
		end
		if type(LocalPlayer.DisplayName) == "string" and #LocalPlayer.DisplayName >= 4 and LocalPlayer.DisplayName ~= LocalPlayer.Name then
			table.insert(aliases, LocalPlayer.DisplayName)
		end
		local userId = tostring(LocalPlayer.UserId)
		local function isPlayerThumb(image)
			local at = string.find(image, userId, 1, true)
			if not at then
				return false
			end
			local after = string.sub(image, at + #userId, at + #userId)
			return after == "" or string.match(after, "%d") == nil
		end
		local function hideInText(text)
			local changed = false
			for _, name in ipairs(aliases) do
				if string.find(text, name, 1, true) then
					local parts = {}
					local startAt = 1
					while true do
						local found = string.find(text, name, startAt, true)
						if not found then
							table.insert(parts, string.sub(text, startAt))
							break
						end
						table.insert(parts, string.sub(text, startAt, found - 1))
						table.insert(parts, "Anonymous")
						startAt = found + #name
						changed = true
					end
					text = table.concat(parts)
				end
			end
			return text, changed
		end
		local function cover(inst)
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				local text, changed = hideInText(inst.Text)
				if changed then
					if streamer.names[inst] == nil then
						streamer.names[inst] = inst.Text
					end
					inst.Text = text
				end
			elseif (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and type(inst.Image) == "string" and isPlayerThumb(inst.Image) then
				if streamer.images[inst] == nil then
					streamer.images[inst] = inst.Image
				end
				inst.Image = "rbxthumb://type=AvatarHeadShot&id=1&w=420&h=420"
			end
		end
		local function scan(root)
			if typeof(root) ~= "Instance" then
				return
			end
			for _, inst in root:GetDescendants() do
				cover(inst)
			end
		end
		local function scanHubs(root)
			if typeof(root) ~= "Instance" then
				return
			end
			for _, child in root:GetChildren() do
				if child:IsA("ScreenGui") and string.sub(child.Name, 1, 6) == "Zinoos" then
					scan(child)
				end
			end
		end
		if hide then
			for inst in pairs(streamer.names) do
				if typeof(inst) ~= "Instance" or inst.Parent == nil then
					streamer.names[inst] = nil
				end
			end
			for inst in pairs(streamer.images) do
				if typeof(inst) ~= "Instance" or inst.Parent == nil then
					streamer.images[inst] = nil
				end
			end
			if type(Window) == "table" then
				local user = Window.User
				if type(user) == "table" and type(user.SetAnonymous) == "function" then
					pcall(user.SetAnonymous, user, true)
				end
			end
			local core = game:GetService("CoreGui")
			scan(LocalPlayer:FindFirstChild("PlayerGui"))
			scan(core:FindFirstChild("PlayerList"))
			scan(core:FindFirstChild("ExperienceChat"))
			scanHubs(core)
			if typeof(gethui) == "function" then
				pcall(function()
					scanHubs(gethui())
				end)
			end
			local character = LocalPlayer.Character
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
			if character then
				for _, board in character:GetDescendants() do
					if board:IsA("BillboardGui") and board.Enabled then
						board.Enabled = false
						streamer.boards[board] = true
					end
				end
			end
		else
			if type(Window) == "table" then
				local user = Window.User
				if type(user) == "table" and type(user.SetAnonymous) == "function" then
					pcall(user.SetAnonymous, user, false)
				end
			end
			for inst, text in pairs(streamer.names) do
				if typeof(inst) == "Instance" and inst.Parent then
					inst.Text = text
				end
			end
			table.clear(streamer.names)
			for inst, image in pairs(streamer.images) do
				if typeof(inst) == "Instance" and inst.Parent then
					inst.Image = image
				end
			end
			table.clear(streamer.images)
			for board in pairs(streamer.boards) do
				if typeof(board) == "Instance" and board.Parent then
					board.Enabled = true
				end
			end
			table.clear(streamer.boards)
			local character = LocalPlayer.Character
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			end
		end
	end
	local function applyStreamer(on)
		maskNames(on == true)
	end
	STATE.applyStreamer = applyStreamer
	task.spawn(function()
		while running() do
			if STATE.streamerMode == true then
				maskNames(true)
			end
			task.wait(1)
		end
	end)

	local function onToggle(key, on)
		STATE[key] = on
		if key == "streamerMode" and STATE.applyStreamer then
			STATE.applyStreamer(on)
		end
		if key == "antiAfk" and on then
			task.defer(pulseAntiAfk)
		elseif key == "disable3d" then
			STATE.apply3d()
		elseif key == "fpsBoost" then
			STATE.applyFpsBoost()
		elseif key == "noPausePopup" then
			hidePausePopup()
		elseif key == "instantPrompts" and not on then
			restoreInstantPrompts()
		elseif key == "autoEquip" and on then
			task.spawn(STATE.equipBestNow)
		elseif key == "autoClaim" and on then
			task.spawn(STATE.claimNow)
		elseif key == "walkSpeed" and not on then
			restoreWalkSpeed()
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
		local control = STATE.toggleControls[key]
		if type(control) ~= "table" then
			control = {}
			STATE.toggleControls[key] = control
		end
		control.value = STATE[key] == true
		control.element = element
		return element
	end

	local function syncToggle(key)
		local control = STATE.toggleControls[key]
		if type(control) ~= "table" then
			return
		end
		local value = STATE[key] == true
		control.value = value
		local element = control.element
		if element and element.Value ~= value then
			elevate()
			pcall(element.Set, element, value, false)
		end
	end

	local function optionName(value)
		if type(value) == "table" then
			return value.Title or value.Name
		end
		return value
	end

	local dropdowns = {}
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
					value = optionName(value)
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
		table.insert(dropdowns, { element = element, get = getValue })
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
						notify("system", title .. " failed", tostring(err))
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
	local farmTab = Window:Tab({ Title = "Farm", Icon = "target" })
	local progressTab = Window:Tab({ Title = "Progress", Icon = "trending-up" })
	local playerTab = Window:Tab({ Title = "Player", Icon = "user" })
	local settingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
	elevate()

	local overview = info(homeTab, "Overview", "Loading your stats...")
	button(homeTab, "Start / Stop Farm", "Turns Auto Orb Farm on or off", "power", function()
		local on = STATE.autoOrb ~= true
		onToggle("autoOrb", on)
		syncToggle("autoOrb")
		notify("system", on and "Farm started" or "Farm stopped", on and "Walking to nearby food" or "Auto Orb Farm is off")
	end)
	button(homeTab, "Claim Now", "Claims daily, playtime, quests and records", "gift", function()
		task.spawn(function()
			local count = STATE.claimNow()
			if count > 0 then
				notify("system", "Claimed " .. count, "")
			else
				notify("system", "Nothing ready", "")
			end
		end)
	end)
	button(homeTab, "Equip Best Now", "Equips your best pets", "paw-print", function()
		STATE.equipBestNow()
		notify("system", "Best pets equipped", "")
	end)
	local activityInfo = info(homeTab, "Activity", "Waiting for the next thing the hub does.")

	local farmInfo
	local eventInfo
	do
		local farmBox = section(farmTab, "Food", "apple")
		toggle(farmBox, "Auto Orb Farm", "autoOrb", "Steps you onto nearby food. During Sugar Rush it stays in the ring")
		toggle(farmBox, "Auto Bite", "autoBite", "Bites an enemy in reach at the game's accepted maximum rate")
		toggle(farmBox, "Auto Ability", "autoAbility", "Uses your equipped mutation ability on a nearby enemy")
		toggle(farmBox, "Smart PvP / Kill Aura", "autoPvp", "Chases the weakest attackable real player, skips stage-protected and stronger ants; God Mode retreats earlier")
		toggle(farmBox, "Chase Bugs", "chaseBugs", "Walks up to a bug so bite and the ability can land")
		toggle(farmBox, "Smart Event Priority", "smartEvents", "Prioritises bosses (Mantis, Anteater), event creatures, treasure chests and event drops, and dodges the Anteater's tongue")
		farmInfo = info(farmBox, "Status", tostring(STATE.status or "Starting"))

		local eventBox = section(farmTab, "Events & Quests", "calendar-clock")
		eventInfo = info(eventBox, "Live State", "Checking the current event and dungeon...")
		toggle(eventBox, "Quest Objective Assist", "questAssist", "Uses the matching farm, evolve, roll, hatch, worm and dungeon actions for unfinished quests")
		toggle(eventBox, "PvP Ant Quests", "pvpQuest", "Targets other ants only when an unfinished defeat-ants quest needs it")
		toggle(eventBox, "Auto Collect Worms", "autoWorms", "Collects worms during the hourly worm rain")
		toggle(eventBox, "Auto Power-Ups", "autoPowerUps", "Collects temporary Speed, Mega Bite, Magnet, x2 Power and Shield pickups")
		toggle(eventBox, "Auto Lost Eggs", "autoLostEggs", "Finds all 20 hidden eggs for DNA, mutation rolls and the completion reward")
		toggle(eventBox, "Auto Dungeon", "autoDungeon", "Uses available daily runs and fights every dungeon wave")

		local espBox = section(farmTab, "ESP", "eye")
		toggle(espBox, "Critter ESP", "critterEsp", "Shows bug names and health")
		toggle(espBox, "Player ESP", "playerEsp", "Shows other players")
	end

	do
		local growBox = section(progressTab, "Evolve", "sparkles")
		toggle(growBox, "Auto Evolve", "autoEvolve", "Evolves when you have the power")
		toggle(growBox, "Auto Rebirth", "autoRebirth", "Rebirths only when you are at the top stage")

		local upgradeBox = section(progressTab, "DNA Upgrades", "arrow-up-circle")
		toggle(upgradeBox, "Auto Buy Upgrades", "autoUpgrade", "Buys the cheapest selected upgrade while keeping the DNA reserve")
		choice(upgradeBox, "DNA Reserve", "Hatching, rolling, upgrades and cosmetic crates will keep this much DNA", RESERVE_OPTIONS, function()
			return STATE.dnaReserve
		end, function(option)
			STATE.dnaReserve = option
		end)
		toggle(upgradeBox, "Jaws", "upgradeJaws", "Bite damage")
		toggle(upgradeBox, "Shell", "upgradeShell", "Health")
		toggle(upgradeBox, "Legs", "upgradeLegs", "Movement speed")
		toggle(upgradeBox, "Antennae", "upgradeMagnet", "Orb magnet")
		toggle(upgradeBox, "Appetite", "upgradeAppetite", "Power from everything")
		toggle(upgradeBox, "Healing", "upgradeRegen", "Health regeneration")

		local hatchBox = section(progressTab, "Pets", "egg")
		toggle(hatchBox, "Auto Hatch", "autoHatch", "Hatches Royal or Colony when you can pay the DNA")
		choice(hatchBox, "Egg", "Best Affordable prefers Royal and falls back to Colony", EGG_OPTIONS, function()
			return STATE.egg
		end, function(option)
			STATE.egg = option
		end)
		local petTargets = { "Off" }
		for key, pet in pairs(type(Config.PetByKey) == "table" and Config.PetByKey or {}) do
			if type(key) == "string" and type(pet) == "table" and pet.egg ~= "Golden" then
				table.insert(petTargets, key)
			end
		end
		table.sort(petTargets, function(a, b)
			if a == "Off" then return b ~= "Off" end
			if b == "Off" then return false end
			return a < b
		end)
		choice(hatchBox, "Stop At Pet", "Stops hatching after this pet is owned", petTargets, function()
			return table.find(petTargets, STATE.petTarget) and STATE.petTarget or "Off"
		end, function(option)
			STATE.petTarget = option
		end)
		toggle(hatchBox, "Auto Equip Best Pet", "autoEquip", "Equips your strongest pets")
		toggle(hatchBox, "Auto Fuse Pets", "autoFuse", "Levels a pet when you own enough spare copies. It keeps one of each")

		local mutateBox = section(progressTab, "Mutations", "sparkles")
		toggle(mutateBox, "Auto Roll", "autoRoll", "Rolls when you have tokens or the DNA")
		choice(mutateBox, "Roll Size", "1 uses one roll. 5 uses five", { "1", "5" }, function()
			return STATE.rollSize
		end, function(option)
			STATE.rollSize = option
		end)
		toggle(mutateBox, "Roll Only With Luck", "luckyRollsOnly", "Saves rolls until Lucky Hour or a personal luck boost is active")
		choice(mutateBox, "Stop At Rarity", "Stops rolling when you own this rarity or better", { "Off", "Legendary", "Mythic", "Secret" }, function()
			return STATE.rollTargetRarity
		end, function(option)
			STATE.rollTargetRarity = option
		end)
		local mutationTargets = { "Off" }
		for key in pairs(type(Config.MutationByKey) == "table" and Config.MutationByKey or {}) do
			if type(key) == "string" then
				table.insert(mutationTargets, key)
			end
		end
		table.sort(mutationTargets, function(a, b)
			if a == "Off" then return b ~= "Off" end
			if b == "Off" then return false end
			return a < b
		end)
		choice(mutateBox, "Stop At Mutation", "Stops rolling after this mutation is owned", mutationTargets, function()
			return table.find(mutationTargets, STATE.rollTargetMutation) and STATE.rollTargetMutation or "Off"
		end, function(option)
			STATE.rollTargetMutation = option
		end)
		toggle(mutateBox, "Auto Equip Best Mutations", "autoMutations", "Fills your slots with the rarest mutations you own")
		toggle(mutateBox, "Auto Best Breed", "autoBestBreed", "Wears the strongest breed you have unlocked")
		local breedNames = { "Keep" }
		local breedKeyByName = { Keep = "Keep" }
		local function addBreed(breed)
			if type(breed) ~= "table" or type(breed.key) ~= "string" or not breedInfo(breed.key) then
				return
			end
			local name = breed.name or breed.key
			table.insert(breedNames, name)
			breedKeyByName[name] = breed.key
		end
		if type(Config.Breeds) == "table" then
			for _, breed in ipairs(Config.Breeds) do
				addBreed(breed)
			end
		end
		if type(Config.LimitedBreeds) == "table" then
			for _, breed in ipairs(Config.LimitedBreeds) do
				addBreed(breed)
			end
		end
		choice(mutateBox, "Breed", "Keep leaves the breed you already have on", breedNames, function()
			if STATE.breed == "Keep" then
				return "Keep"
			end
			local info = breedInfo(STATE.breed)
			return type(info) == "table" and (info.name or info.key) or "Keep"
		end, function(option)
			STATE.breed = breedKeyByName[option] or "Keep"
		end)
		button(mutateBox, "Wear Breed", "Puts on the breed picked above", "user", function()
			if STATE.wearBreed() then
				notify("system", "Wearing " .. tostring(STATE.breed), "")
			else
				notify("system", "Breed left as it is", "Pick a breed other than Keep")
			end
		end)

		local claimBox = section(progressTab, "Rewards", "gift")
		toggle(claimBox, "Auto Claim Rewards", "autoClaim", "Claims daily, playtime, quests and records")
		toggle(claimBox, "Auto Battle Pass", "autoBattlePass", "Claims free and owned-premium pass rewards, weekly quests and the weekly bonus")
		toggle(claimBox, "Auto Kill Rewards", "autoKillRewards", "Claims reached ant-kill milestones")
		toggle(claimBox, "Redeem Codes", "autoCodes", "Redeems the known codes once")

		local moleBox = section(progressTab, "Worms & Mole", "bug")
		toggle(moleBox, "Auto Mole Trade", "autoMole", "Trades worms for the selected free reward")
		choice(moleBox, "Mole Reward", nil, MOLE_OPTIONS, function()
			return STATE.moleItem
		end, function(option)
			STATE.moleItem = option
		end)
		choice(moleBox, "Worm Reserve", "Keeps this many worms unspent", WORM_RESERVE_OPTIONS, function()
			return STATE.wormReserve
		end, function(option)
			STATE.wormReserve = option
		end)

		local cosmeticBox = section(progressTab, "Wardrobe", "shirt")
		toggle(cosmeticBox, "Auto Cosmetic Crates", "autoCosmeticCrates", "Opens the selected DNA crate while keeping the DNA reserve")
		choice(cosmeticBox, "Crate Slot", nil, COSMETIC_SLOTS, function()
			return STATE.cosmeticSlot
		end, function(option)
			STATE.cosmeticSlot = option
		end)
		toggle(cosmeticBox, "Auto Best Aura", "autoBestAura", "Equips your highest-rarity owned aura")
	end

	do
		local safetyBox = section(playerTab, "Survival", "shield-check")
		toggle(safetyBox, "God Mode", "godMode", "At low HP it stops fighting, heals out of reach, then carries on")
		choice(safetyBox, "God Mode Escape", "Sky: teleports up out of reach (never dies, but it is a big teleport). Safe Zone: runs to the spawn safe zone (no teleport)", { "Sky", "Safe Zone" }, function()
			return STATE.godStyle
		end, function(option)
			STATE.godStyle = option
		end)
		toggle(safetyBox, "Block Robux Capsule", "blockRobuxCapsule", "Stops the game's +3 EVO capsule from opening purchase prompts while auto farming")

		local moveBox = section(playerTab, "Movement", "footprints")
		toggle(moveBox, "Custom Walk Speed", "walkSpeed")
		choice(moveBox, "Walk Speed", "16 is the normal speed", SPEED_OPTIONS, function()
			return tostring(STATE.speed)
		end, function(option)
			STATE.speed = tonumber(option) or STATE.speed
		end)
		toggle(moveBox, "Infinite Jump", "infiniteJump")
		toggle(moveBox, "Infinite Stamina", "infiniteStamina", "Sprint and wing fly do not run out")
		toggle(moveBox, "Walk Through When Stuck", "ghostWhenStuck", "Only the sign, shop or rock you are stuck on stops being solid for 5 s, on your screen only. Never the ground, zone gates or map edges")
		toggle(moveBox, "Noclip", "noclip")
		toggle(moveBox, "Instant Interactions", "instantPrompts", "No hold time on prompts")
		toggle(moveBox, "Fly", "fly", "PC: WASD, Space up, Left Ctrl down")
		toggle(moveBox, "Auto Sprint", "autoSprint", "Holds the game's sprint for you")
		choice(moveBox, "Fly Speed", nil, FLY_SPEED_OPTIONS, function()
			return tostring(STATE.flySpeed)
		end, function(option)
			STATE.flySpeed = tonumber(option) or STATE.flySpeed
		end)

		local clientBox = section(playerTab, "Performance & AFK", "cpu")
		toggle(clientBox, "Anti AFK", "antiAfk")
		toggle(clientBox, "Auto Reconnect on Kick", "autoReconnect")
		toggle(clientBox, "Reload Hub After Server Change", "autoReload", "Loads the hub again by itself after a rejoin, server hop or reconnect")
		toggle(clientBox, "Hide Roblox Pause Popup", "noPausePopup")
		toggle(clientBox, "Potato Mode", "fpsBoost", "Suppresses particles, trails, beams, lights, decals, water and post effects while keeping the game and hub visible")
		toggle(clientBox, "AFK Black Screen", "disable3d", "Stops drawing the world")

		local serverBox = section(playerTab, "Server", "server")
		info(serverBox, "This Server", "Job " .. string.sub(game.JobId, 1, 8) .. "... · Place " .. tostring(game.PlaceId))
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
		toggle(lookBox, "Streamer Mode", "streamerMode", "Hides your username and display name on the hub, the player list and your nametag")
		toggle(lookBox, "Hub Notifications", "notifications")

		local configBox = section(settingsTab, "Config", "save")
		info(configBox, "Saving", "Changes save automatically for this Roblox account.")
		button(configBox, "Save Now", nil, "save", function()
			saveConfig()
			notify("system", "Saved", "Settings saved for " .. LocalPlayer.DisplayName)
		end)

		local communityBox = section(settingsTab, "Community", "message-circle")
		button(communityBox, "Copy Discord Invite", "discord.gg/94pC3T6NZG", "copy", function()
			local invite = "https://discord.gg/94pC3T6NZG"
			if typeof(setclipboard) == "function" and pcall(setclipboard, invite) then
				notify("system", "Invite copied", "Paste it in your browser")
			else
				notify("system", "Discord invite", invite)
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
		local eventKey = activeEvent()
		local eventLeft = math.max(0, (tonumber(STATE.eventEnd) or 0) - Workspace:GetServerTimeNow())
		local eventLine = eventKey and string.format("%s  ·  %ds left", tostring(STATE.eventName), math.floor(eventLeft)) or "No live event"
		local questKeys = activeQuestKeys()
		local questList = {}
		for key in pairs(questKeys) do table.insert(questList, key) end
		table.sort(questList)
		local questLine = #questList > 0 and ("Open quests: " .. table.concat(questList, ", ")) or "All tracked quests complete"
		setInfo(eventInfo, eventLine .. "\n" .. questLine .. "\nDungeon: " .. tostring(STATE.dungeon or "Surface") .. "  ·  Runs " .. tostring(math.floor(stateNumber("DungeonRuns"))))
		setInfo(overview, string.format(
			"%s\nPower %s  ·  %s  ·  Rebirth %s\nDNA %s  ·  Egg %s\nSession %s",
			tostring(STATE.status or "Waiting"),
			STATE.shortNumber(STATE.power or 0),
			tostring(STATE.stageName or ""),
			tostring(STATE.rebirths or 0),
			STATE.shortNumber(STATE.dna or 0),
			tostring(STATE.egg or "Royal"),
			clock
		))
		local lines = {
			"Food · " .. tostring(STATE.detail or ""),
			"Stage · " .. tostring(STATE.stageName or ""),
		}
		if STATE.antiAfk == true then
			lines[#lines + 1] = STATE.antiAfkOperational == true and "Anti AFK active" or "Anti AFK waiting for idle"
		end
		for _, item in ipairs(STATE.activity) do
			lines[#lines + 1] = tostring(item)
		end
		setInfo(activityInfo, table.concat(lines, "\n"))
		setInfo(farmInfo, tostring(STATE.status or "Waiting") .. "\n" .. tostring(STATE.detail or ""))
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
if STATE.notifications == nil then
	STATE.notifications = true
end
STATE.version = "1.5.7"

if running() then
	elevate()
	local ok, err = xpcall(installHub, debug.traceback)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
	end
end

task.spawn(function()
	elevate()
	while running() do
		farm.walkWanted = false
		local ok, err = pcall(stepFarm)
		if not farm.walkWanted and farm.releaseWalk then
			-- This tick wants the ant standing still (eating, fighting, in the
			-- ring, farm off): let go of the movement input.
			farm.releaseWalk()
		end
		if not ok then
			STATE.status = "Farm error"
			warn("[Zinoos hub] " .. tostring(err))
			task.wait(2)
		else
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	elevate()
	while running() do
		pcall(stepBite)
		pcall(stepAbility)
		pcall(stepEvolve)
		pcall(stepHatch)
		pcall(stepRoll)
		pcall(stepMutations)
		pcall(stepBestBreed)
		pcall(stepEquip)
		pcall(stepFuse)
		pcall(stepClaims)
		pcall(stepUpgrades)
		pcall(stepPassClaims)
		pcall(stepKillClaims)
		pcall(stepMole)
		pcall(stepCosmeticCrate)
		pcall(stepBestAura)
		pcall(stepEsp)
		task.wait(0.35)
	end
end)

task.spawn(function()
	elevate()
	while running() do
		pcall(suppressRobuxCapsule)
		pcall(stepSpeed)
		pcall(fillStamina)
		pcall(stepSprint)
		pcall(hidePausePopup)
		task.wait(0.25)
	end
end)

pcall(STATE.apply3d)
pcall(STATE.applyFpsBoost)

task.spawn(function()
	task.wait(5)
	pulseAntiAfk()
	while running() do
		task.wait(4 * 60)
		pulseAntiAfk()
	end
end)
