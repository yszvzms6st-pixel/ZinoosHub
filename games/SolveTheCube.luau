-- Zinoos hub for Solve The Cube.
-- Same menu as the Lift Rock hub. Auto Solve feeds the guide's next correct move into the
-- game's own CubeStage:TwistLayer, so every turn goes through the real input path
-- (pressed keys, view batches, Tw remote). Auto Ready presses the game's own Ready button.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

if game.PlaceId ~= 104488514364885 then
	warn("[Zinoos hub] This only runs in Solve The Cube.")
	return
end

local LocalPlayer = Players.LocalPlayer
local genv = getgenv()

-- One copy at a time: a new run stops the old one first.
if typeof(genv.ZinoosCubeStop) == "function" then
	pcall(genv.ZinoosCubeStop)
end
genv.ZinoosCubeGen = (typeof(genv.ZinoosCubeGen) == "number" and genv.ZinoosCubeGen or 0) + 1
local token = genv.ZinoosCubeGen
local function running()
	return genv.ZinoosCubeGen == token
end

local STATE = {
	_gen = token,
	autoSolve = true,
	autoZeroAssist = true,
	zaTps = 12,
	tps = 20,
	humanize = false,
	autoReady = true,
	autoSit = false,
	tableType = "Normal",
	walkSpeed = false,
	speed = 32,
	antiAfk = true,
	preferWaiting = true,
	autoSkipReplay = true,
	autoBot = false,
	botWait = 10,
	botId = "Doom",
	autoModifiers = false,
	voteGameplay = "Default",
	voteModifier = "SuddenDeath",
	votePowerup = "Freeze",
	autoBuyChairs = false,
	autoBuyCrates = false,
	crateId = "Golden",
	autoOpenCrates = false,
	autoDaily = true,
	autoQuests = true,
	autoAchievements = true,
	infiniteJump = false,
	noclip = false,
	instantPrompts = false,
	fly = false,
	flySpeed = 60,
	noPausePopup = true,
	-- Keep the current server after a match or a transient game message. Rejoining
	-- wipes the loaded hub and made the first verification impossible.
	autoReconnect = false,
	disable3d = false,
	fpsBoost = false,
	hideOnStart = false,
	toggleKey = "RightControl",
	toggleControls = {},
	themeSwitches = {},
}
genv.ZinoosCubeState = STATE

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
		local old = root and root:FindFirstChild("ZinoosCubeMenu")
		if old then
			old:Destroy()
		end
	end
end

local function shutdownHub()
	if genv.ZinoosCubeGen == token then
		genv.ZinoosCubeGen = token + 1
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
genv.ZinoosCubeStop = shutdownHub
local function unloadHub()
	shutdownHub()
end

local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/SolveTheCube_" .. tostring(LocalPlayer.UserId) .. ".rfld"
local TABLE_TYPES = { "Normal", "Pro" }
local TPS_OPTIONS = { "5", "8", "10", "12", "15", "20", "25", "30", "40" }
local SPEED_OPTIONS = { "16", "24", "32", "50", "75", "100" }

local FLAG_KEYS = {
	AutoSolve = "autoSolve",
	AutoZeroAssist = "autoZeroAssist",
	Humanize = "humanize",
	AutoReady = "autoReady",
	AutoSit = "autoSit",
	WalkSpeed = "walkSpeed",
	AntiAfk = "antiAfk",
	PreferWaiting = "preferWaiting",
	AutoSkipReplay = "autoSkipReplay",
	AutoBot = "autoBot",
	AutoModifiers = "autoModifiers",
	AutoBuyChairs = "autoBuyChairs",
	AutoBuyCrates = "autoBuyCrates",
	AutoOpenCrates = "autoOpenCrates",
	AutoDaily = "autoDaily",
	AutoQuests = "autoQuests",
	AutoAchievements = "autoAchievements",
	InfiniteJump = "infiniteJump",
	Noclip = "noclip",
	InstantPrompts = "instantPrompts",
	Fly = "fly",
	NoPausePopup = "noPausePopup",
	AutoReconnect = "autoReconnect",
	Disable3d = "disable3d",
	FpsBoost = "fpsBoost",
	HideOnStart = "hideOnStart",
}

-- Choices saved by name. Each value must be one of its options to load.
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BOTS, BOT_LABELS = {}, {}
for _, bot in ipairs(Config.BotLadder and Config.BotLadder.Bots or {}) do
	local text = string.format("%s (%d)", tostring(bot.Name), tonumber(bot.Rating) or 0)
	BOTS[#BOTS + 1] = { id = bot.Id, label = text }
	BOT_LABELS[#BOT_LABELS + 1] = text
end
local CRATES, CRATE_LABELS = {}, {}
for _, crate in ipairs(Config.Crates or {}) do
	local text = string.format("%s (%s)", tostring(crate.Name), tostring(crate.Price))
	CRATES[#CRATES + 1] = { id = crate.Id, price = crate.Price, label = text }
	CRATE_LABELS[#CRATE_LABELS + 1] = text
end
local function columnOptions(name, extra)
	local list = extra and { extra } or {}
	for _, column in ipairs(Config.Modifiers and Config.Modifiers.Columns or {}) do
		if column.Id == name or column.Name == name then
			for _, option in ipairs(column.Options or {}) do
				list[#list + 1] = type(option) == "table" and tostring(option.Id or option.Name) or tostring(option)
			end
		end
	end
	return list
end
local GAMEPLAY_OPTIONS = columnOptions("Gameplay", "Default")
local MODIFIER_OPTIONS = columnOptions("Modifier")
local POWERUP_OPTIONS = columnOptions("Powerup")
local BOT_WAIT_OPTIONS = { "5", "10", "15", "20", "30", "60" }
local FLY_SPEED_OPTIONS = { "30", "60", "100", "150", "200" }
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
local CHOICES = {
	BotId = { key = "botId" },
	CrateId = { key = "crateId" },
	VoteGameplay = { key = "voteGameplay", options = GAMEPLAY_OPTIONS },
	VoteModifier = { key = "voteModifier", options = MODIFIER_OPTIONS },
	VotePowerup = { key = "votePowerup", options = POWERUP_OPTIONS },
	ToggleKey = { key = "toggleKey", options = KEY_OPTIONS },
}
local NUMBERS = { BotWait = { "botWait", 1, 120 }, FlySpeed = { "flySpeed", 10, 300 }, ZaTps = { "zaTps", 1, 20 } }
local ZA_TPS_OPTIONS = { "2", "3", "4", "5", "6", "8", "10", "12", "15", "20" }
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
	if type(saved.TPS) == "number" then
		STATE.tps = math.clamp(saved.TPS, 1, 40)
	end
	if type(saved.Speed) == "number" then
		STATE.speed = math.clamp(saved.Speed, 16, 100)
	end
	if table.find(TABLE_TYPES, saved.TableType) then
		STATE.tableType = saved.TableType
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
		TPS = STATE.tps,
		Speed = STATE.speed,
		TableType = STATE.tableType,
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
	local ok, encoded = pcall(function()
		return game:GetService("HttpService"):JSONEncode(payload)
	end)
	if ok then
		pcall(writefile, CONFIG_PATH, encoded)
	end
end
STATE.writeConfig = saveConfig

local Client = ReplicatedStorage:WaitForChild("Client")
local Match = require(Client:WaitForChild("Controllers"):WaitForChild("MatchController"))
local MoveMap = require(Client:WaitForChild("Match"):WaitForChild("MoveMap"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

STATE.status = "Starting"
local stats = { solves = 0, moves = 0, readies = 0, sits = 0 }
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

local function screen()
	local ok, result = pcall(Match.GetScreen, Match)
	return ok and result or nil
end

local function humanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- After a match the server can free the seat while the client still holds SeatPart.
-- Only a seat whose Occupant is us counts.
local function seated()
	local hum = humanoid()
	local seat = hum and hum.SeatPart
	return seat ~= nil and seat.Occupant == hum
end

local function leaveGhostSeat()
	local hum = humanoid()
	local seat = hum and hum.SeatPart
	if seat and seat.Occupant ~= hum then
		for _, weld in ipairs(seat:GetChildren()) do
			if weld:IsA("Weld") and weld.Part1 and weld.Part1:IsDescendantOf(hum.Parent) then
				weld:Destroy()
			end
		end
		hum.Sit = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		task.wait(0.3)
	end
end

-- The key the player would have pressed for this move, so the server sees a normal key tag.
local function keyTag(move)
	local ok, key = pcall(MoveMap.keyFor, move, "Keyboard")
	if ok and typeof(key) == "EnumItem" then
		return key.Name
	elseif ok and type(key) == "string" then
		return key
	end
	return nil
end

local function solving(stage)
	return stage
		and stage.mode == "Keys"
		and stage.phase == "Racing"
		and not stage.solved
		and stage.inputEnabled
		and not stage.frozen
end

local function stepSolve()
	if STATE.autoSolve ~= true then
		return
	end
	local current = screen()
	local stage = current and current.Stage
	if not solving(stage) or type(stage.guide) ~= "table" then
		return
	end
	STATE.status = "Solving"
	local typed = 0
	while running() and STATE.autoSolve == true and solving(stage) do
		local ok, move = pcall(stage.guide.next, stage.guide)
		if not ok or move == nil then
			break
		end
		stage.inputTag = keyTag(move)
		pcall(stage.TwistLayer, stage, move)
		stats.moves += 1
		typed += 1
		local gap = 1 / math.max(STATE.tps, 1)
		if STATE.humanize then
			gap *= 0.75 + math.random() * 0.5
		end
		task.wait(gap)
	end
	if stage.solved then
		stats.solves += 1
		STATE.status = "Solved"
		noteActivity(string.format("Solved in %d moves", typed))
	end
end

-- Zero Assist has no guide: read the real cube, solve it, and turn it through the same input path.
-- The solver itself is defined further down.
local CubeSolver

local function zeroAssistRacing(stage)
	return stage
		and stage.mode == "Free"
		and not stage.two
		and stage.phase == "Racing"
		and not stage.solved
		and stage.inputEnabled
		and not stage.frozen
end

local function stepZeroAssist()
	if STATE.autoZeroAssist ~= true or type(CubeSolver) ~= "table" then
		return
	end
	local current = screen()
	local stage = current and current.Stage
	if not zeroAssistRacing(stage) then
		return
	end
	if not CubeSolver.ready() then
		STATE.status = "Zero Assist solver still loading"
		return
	end
	STATE.status = "Solving Zero Assist"
	-- A short look at the cube first, like a person would.
	task.wait(1.2 + math.random() * 1.3)
	local typed = 0
	for _ = 1, 3 do
		if not running() or STATE.autoZeroAssist ~= true or not zeroAssistRacing(stage) then
			break
		end
		local ok, state = pcall(function()
			return stage.Cube:GetState()
		end)
		local solvedOk, moves, solveErr = false, nil, nil
		if ok and type(state) == "string" then
			solvedOk, moves = pcall(CubeSolver.solve, state)
		else
			solveErr = ok and "cube state was not a string" or state
		end
		if not solvedOk or type(moves) ~= "table" then
			noteActivity("Zero Assist solver error: " .. tostring(solveErr or moves or "no solution"))
			break
		end
		for _, move in ipairs(moves) do
			if not running() or STATE.autoZeroAssist ~= true or not zeroAssistRacing(stage) then
				break
			end
			stage.inputTag = keyTag(move) or "Tap"
			pcall(stage.TwistLayer, stage, move)
			typed += 1
			stats.moves += 1
			local gap = 1 / math.max(STATE.zaTps, 1)
			if STATE.humanize then
				gap *= 0.6 + math.random() * 0.8
				if math.random() < 0.08 then
					gap += 0.4 + math.random() * 0.8
				end
			end
			task.wait(gap)
		end
		if stage.solved then
			break
		end
	end
	if stage.solved then
		stats.solves += 1
		STATE.status = "Solved"
		noteActivity(string.format("Solved Zero Assist in %d moves", typed))
	end
end

local lastVote = nil
local function stepReady()
	if STATE.autoReady ~= true then
		return
	end
	local current = screen()
	if not current then
		return
	end
	local stage = current.Stage
	if stage and stage.phase == "Inspect" and not current.readySent then
		task.wait(0.4 + math.random() * 0.4)
		if stage.phase == "Inspect" and not current.readySent and typeof(current._pressReady) == "function" then
			pcall(current._pressReady, current)
			stats.readies += 1
			STATE.status = "Ready"
			noteActivity("Pressed Ready")
		end
	end
	-- Modifier vote screen has its own ready button.
	-- With Auto Modifiers on, the vote handler readies up itself once its picks are in.
	local vote = current.vote
	if vote and not vote.ready and vote ~= lastVote and STATE.autoModifiers ~= true and not STATE.voting then
		lastVote = vote
		task.wait(0.6 + math.random() * 0.6)
		pcall(function()
			Net.event("TableInput"):FireServer({ Type = "VoteReady" })
		end)
	end
end

local function freeSeat()
	local tables = workspace:FindFirstChild("Tables")
	if not tables then
		return nil
	end
	local wantPro = STATE.tableType == "Pro"
	local best, bestScore = nil, -math.huge
	for _, tbl in ipairs(tables:GetChildren()) do
		local attrs = tbl:GetAttributes()
		local usable = attrs.Disabled ~= true and attrs.Kind ~= "Group" and attrs.Mode ~= "Powerup" and attrs.State ~= nil
		if usable and (attrs.IsPro == true) == wantPro then
			for slot = 1, 2 do
				local seat = tbl:FindFirstChild("Seat" .. slot)
				local prompt = seat and seat:FindFirstChild("SitPrompt")
				local open = prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled
				if open and seat.Occupant == nil and (attrs["P" .. slot .. "UserId"] or 0) == 0 then
					local other = attrs["P" .. (3 - slot) .. "UserId"] or 0
					local score = ((STATE.preferWaiting and other ~= 0) and 10 or 0) + (attrs.State == "Idle" and 1 or 0)
					if score > bestScore then
						best, bestScore = seat, score
					end
				end
			end
		end
	end
	return best
end

local function stepSit()
	if STATE.autoSit ~= true or seated() or Match.InMatch then
		return
	end
	leaveGhostSeat()
	local seat = freeSeat()
	local hum = humanoid()
	local root = hum and hum.RootPart
	if not seat or not root then
		STATE.status = "No free " .. STATE.tableType .. " seat"
		return
	end
	-- The server only seats you through the seat's own Sit prompt; sitting client-side is ignored.
	STATE.status = "Sitting"
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = seat.CFrame * CFrame.new(0, 1, -4)
	task.wait(0.6)
	pcall(fireproximityprompt, seat.SitPrompt)
	task.wait(1.5)
	if seated() then
		stats.sits += 1
		noteActivity("Sat at " .. seat.Parent.Name)
	end
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
		local virtual = game:GetService("VirtualUser") :: any
		virtual:CaptureController()
		virtual:ClickButton2(Vector2.new(-1, -1))
	end)
	STATE.antiAfkOperational = ok
	return ok
end

-- Zero Assist: a two-phase solver, inlined so the hub stays one file.
CubeSolver = (function()
-- Two-phase (Kociemba) 3x3 solver for facelet strings in URFDLB order.
-- Tables are built once and kept in getgenv().ZinoosCubeSolverTables.
-- Returns a list of quarter turns ("R", "R'"), since Zero Assist has no half-turn key.

local Solver = {}

local FACES = { "U", "R", "F", "D", "L", "B" }
local N_TWIST, N_FLIP, N_SLICE = 2187, 2048, 495
local N_PERM8, N_PERM4 = 40320, 24
local PHASE2_MOVES = { 0, 1, 2, 9, 10, 11, 4, 13, 7, 16 } -- U U2 U' D D2 D' R2 L2 F2 B2

-- Corner and edge stickers, by facelet index (0-based) and the colour each piece carries.
local CORNER_FACELET = {
	{ 8, 9, 20 }, { 6, 18, 38 }, { 0, 36, 47 }, { 2, 45, 11 },
	{ 29, 26, 15 }, { 27, 44, 24 }, { 33, 53, 42 }, { 35, 17, 51 },
}
local CORNER_COLOR = {
	{ "U", "R", "F" }, { "U", "F", "L" }, { "U", "L", "B" }, { "U", "B", "R" },
	{ "D", "F", "R" }, { "D", "L", "F" }, { "D", "B", "L" }, { "D", "R", "B" },
}
local EDGE_FACELET = {
	{ 5, 10 }, { 7, 19 }, { 3, 37 }, { 1, 46 }, { 32, 16 }, { 28, 25 },
	{ 30, 43 }, { 34, 52 }, { 23, 12 }, { 21, 41 }, { 50, 39 }, { 48, 14 },
}
local EDGE_COLOR = {
	{ "U", "R" }, { "U", "F" }, { "U", "L" }, { "U", "B" }, { "D", "R" }, { "D", "F" },
	{ "D", "L" }, { "D", "B" }, { "F", "R" }, { "F", "L" }, { "B", "L" }, { "B", "R" },
}

-- Basic face turns as cubie permutations (0-based values, 1-based Lua arrays).
local BASIC = {
	{ cp = { 3, 0, 1, 2, 4, 5, 6, 7 }, co = { 0, 0, 0, 0, 0, 0, 0, 0 }, ep = { 3, 0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11 }, eo = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } },
	{ cp = { 4, 1, 2, 0, 7, 5, 6, 3 }, co = { 2, 0, 0, 1, 1, 0, 0, 2 }, ep = { 8, 1, 2, 3, 11, 5, 6, 7, 4, 9, 10, 0 }, eo = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } },
	{ cp = { 1, 5, 2, 3, 0, 4, 6, 7 }, co = { 1, 2, 0, 0, 2, 1, 0, 0 }, ep = { 0, 9, 2, 3, 4, 8, 6, 7, 1, 5, 10, 11 }, eo = { 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0 } },
	{ cp = { 0, 1, 2, 3, 5, 6, 7, 4 }, co = { 0, 0, 0, 0, 0, 0, 0, 0 }, ep = { 0, 1, 2, 3, 5, 6, 7, 4, 8, 9, 10, 11 }, eo = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } },
	{ cp = { 0, 2, 6, 3, 4, 1, 5, 7 }, co = { 0, 1, 2, 0, 0, 2, 1, 0 }, ep = { 0, 1, 10, 3, 4, 5, 9, 7, 8, 2, 6, 11 }, eo = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } },
	{ cp = { 0, 1, 3, 7, 4, 5, 2, 6 }, co = { 0, 0, 1, 2, 0, 0, 2, 1 }, ep = { 0, 1, 2, 11, 4, 5, 6, 10, 8, 9, 3, 7 }, eo = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1 } },
}

local function identity()
	return { cp = { 0, 1, 2, 3, 4, 5, 6, 7 }, co = { 0, 0, 0, 0, 0, 0, 0, 0 }, ep = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, eo = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } }
end

-- a * b: apply b after a.
local function multiply(a, b)
	local r = { cp = {}, co = {}, ep = {}, eo = {} }
	for i = 1, 8 do
		local from = b.cp[i] + 1
		r.cp[i] = a.cp[from]
		r.co[i] = (a.co[from] + b.co[i]) % 3
	end
	for i = 1, 12 do
		local from = b.ep[i] + 1
		r.ep[i] = a.ep[from]
		r.eo[i] = (a.eo[from] + b.eo[i]) % 2
	end
	return r
end

-- MOVES[m + 1] for m = face * 3 + power - 1 (power 1, 2, 3).
local MOVES = {}
for face = 1, 6 do
	local c = identity()
	for power = 1, 3 do
		c = multiply(c, BASIC[face])
		MOVES[(face - 1) * 3 + power] = c
	end
end

local function choose(n, k)
	if k < 0 or k > n then
		return 0
	end
	local r = 1
	for i = 1, k do
		r = r * (n - k + i) / i
	end
	return math.floor(r + 0.5)
end

local function rankPerm(p, n)
	local idx = 0
	for i = 1, n do
		local smaller = 0
		for j = i + 1, n do
			if p[j] < p[i] then
				smaller += 1
			end
		end
		idx = idx * (n - i + 1) + smaller
	end
	return idx
end

local function unrankPerm(idx, n)
	local digits = table.create(n, 0)
	for i = n, 1, -1 do
		local base = n - i + 1
		digits[i] = idx % base
		idx = idx // base
	end
	local pool = {}
	for v = 0, n - 1 do
		pool[#pool + 1] = v
	end
	local p = table.create(n, 0)
	for i = 1, n do
		p[i] = table.remove(pool, digits[i] + 1)
	end
	return p
end

local function twistOf(co)
	local t = 0
	for i = 1, 7 do
		t = t * 3 + co[i]
	end
	return t
end

local function flipOf(eo)
	local f = 0
	for i = 1, 11 do
		f = f * 2 + eo[i]
	end
	return f
end

-- Which 4 of the 12 edge positions hold the E-slice edges (FR FL BL BR).
local function sliceOf(occupied)
	local a, x = 0, 0
	for j = 12, 1, -1 do
		if occupied[j] then
			a += choose(12 - j, x + 1)
			x += 1
		end
	end
	return a
end

local function buildTables(yield)
	local t = {}
	local work = 0
	local function tick()
		work += 1
		if yield and work % 20000 == 0 then
			task.wait()
		end
	end

	t.twistMove = table.create(N_TWIST * 18, 0)
	for tw = 0, N_TWIST - 1 do
		local co = table.create(8, 0)
		local v, sum = tw, 0
		for i = 7, 1, -1 do
			co[i] = v % 3
			sum += co[i]
			v = v // 3
		end
		co[8] = (3 - sum % 3) % 3
		for m = 1, 18 do
			local mv = MOVES[m]
			local nco = table.create(8, 0)
			for i = 1, 8 do
				nco[i] = (co[mv.cp[i] + 1] + mv.co[i]) % 3
			end
			t.twistMove[tw * 18 + m] = twistOf(nco)
		end
		tick()
	end

	t.flipMove = table.create(N_FLIP * 18, 0)
	for fl = 0, N_FLIP - 1 do
		local eo = table.create(12, 0)
		local v, sum = fl, 0
		for i = 11, 1, -1 do
			eo[i] = v % 2
			sum += eo[i]
			v = v // 2
		end
		eo[12] = sum % 2
		for m = 1, 18 do
			local mv = MOVES[m]
			local neo = table.create(12, 0)
			for i = 1, 12 do
				neo[i] = (eo[mv.ep[i] + 1] + mv.eo[i]) % 2
			end
			t.flipMove[fl * 18 + m] = flipOf(neo)
		end
		tick()
	end

	local sliceMask = {}
	for mask = 0, 4095 do
		local count, occ = 0, {}
		for i = 1, 12 do
			occ[i] = bit32.btest(mask, bit32.lshift(1, i - 1))
			if occ[i] then
				count += 1
			end
		end
		if count == 4 then
			sliceMask[sliceOf(occ)] = occ
		end
	end
	t.sliceMove = table.create(N_SLICE * 18, 0)
	for s = 0, N_SLICE - 1 do
		local occ = sliceMask[s]
		for m = 1, 18 do
			local mv = MOVES[m]
			local nocc = {}
			for i = 1, 12 do
				nocc[i] = occ[mv.ep[i] + 1]
			end
			t.sliceMove[s * 18 + m] = sliceOf(nocc)
		end
	end

	-- Phase 2 tables use only the ten moves that keep the cube in <U, D, R2, L2, F2, B2>.
	t.cpMove = buffer.create(N_PERM8 * 10 * 2)
	t.epMove = buffer.create(N_PERM8 * 10 * 2)
	for r = 0, N_PERM8 - 1 do
		local p = unrankPerm(r, 8)
		for k, m in ipairs(PHASE2_MOVES) do
			local mv = MOVES[m + 1]
			local nc, ne = table.create(8, 0), table.create(8, 0)
			for i = 1, 8 do
				nc[i] = p[mv.cp[i] + 1]
				ne[i] = p[mv.ep[i] + 1]
			end
			buffer.writeu16(t.cpMove, (r * 10 + k - 1) * 2, rankPerm(nc, 8))
			buffer.writeu16(t.epMove, (r * 10 + k - 1) * 2, rankPerm(ne, 8))
		end
		tick()
	end
	t.spMove = table.create(N_PERM4 * 10, 0)
	for r = 0, N_PERM4 - 1 do
		local p = unrankPerm(r, 4)
		for k, m in ipairs(PHASE2_MOVES) do
			local mv = MOVES[m + 1]
			local ns = table.create(4, 0)
			for i = 1, 4 do
				ns[i] = p[mv.ep[i + 8] + 1 - 8]
			end
			t.spMove[r * 10 + k] = rankPerm(ns, 4)
		end
	end

	-- Breadth-first pruning tables, one byte per entry (255 = not reached yet).
	local function prune(size, width, nMoves, step)
		local depthOf = buffer.create(size)
		buffer.fill(depthOf, 0, 255)
		local queue = buffer.create(size * 4)
		local head, tail = 0, 1
		buffer.writeu8(depthOf, 0, 0)
		buffer.writeu32(queue, 0, 0)
		while head < tail do
			local idx = buffer.readu32(queue, head * 4)
			head += 1
			local d = buffer.readu8(depthOf, idx)
			local a, b = idx // width, idx % width
			for k = 1, nMoves do
				local n = step(a, b, k)
				if buffer.readu8(depthOf, n) == 255 then
					buffer.writeu8(depthOf, n, d + 1)
					buffer.writeu32(queue, tail * 4, n)
					tail += 1
				end
			end
			tick()
		end
		return depthOf
	end
	local twistMove, flipMove, sliceMove = t.twistMove, t.flipMove, t.sliceMove
	t.pruneTwist = prune(N_SLICE * N_TWIST, N_TWIST, 18, function(s, tw, m)
		return sliceMove[s * 18 + m] * N_TWIST + twistMove[tw * 18 + m]
	end)
	t.pruneFlip = prune(N_SLICE * N_FLIP, N_FLIP, 18, function(s, fl, m)
		return sliceMove[s * 18 + m] * N_FLIP + flipMove[fl * 18 + m]
	end)
	local cpMove, epMove, spMove = t.cpMove, t.epMove, t.spMove
	t.pruneCp = prune(N_PERM4 * N_PERM8, N_PERM8, 10, function(sp, cp, k)
		return spMove[sp * 10 + k] * N_PERM8 + buffer.readu16(cpMove, (cp * 10 + k - 1) * 2)
	end)
	t.pruneEp = prune(N_PERM4 * N_PERM8, N_PERM8, 10, function(sp, ep, k)
		return spMove[sp * 10 + k] * N_PERM8 + buffer.readu16(epMove, (ep * 10 + k - 1) * 2)
	end)
	return t
end

function Solver.ready()
	return type(getgenv().ZinoosCubeSolverTables) == "table"
end

function Solver.prepare(yield)
	local genv = getgenv()
	if type(genv.ZinoosCubeSolverTables) ~= "table" then
		genv.ZinoosCubeSolverTables = buildTables(yield)
	end
	return genv.ZinoosCubeSolverTables
end

-- The colour on each centre tells us which face each letter belongs to right now.
local CENTER = { U = 4, R = 13, F = 22, D = 31, L = 40, B = 49 }
local function toCubie(facelets)
	local relabel = {}
	for face, index in pairs(CENTER) do
		relabel[string.sub(facelets, index + 1, index + 1)] = face
	end
	local f = {}
	for i = 1, 54 do
		f[i - 1] = relabel[string.sub(facelets, i, i)]
		if not f[i - 1] then
			return nil, "bad sticker"
		end
	end
	local c = identity()
	for i = 1, 8 do
		local ori = 0
		for o = 0, 2 do
			local col = f[CORNER_FACELET[i][o + 1]]
			if col == "U" or col == "D" then
				ori = o
				break
			end
		end
		local c1 = f[CORNER_FACELET[i][(ori + 1) % 3 + 1]]
		local c2 = f[CORNER_FACELET[i][(ori + 2) % 3 + 1]]
		local found = false
		for j = 1, 8 do
			if CORNER_COLOR[j][2] == c1 and CORNER_COLOR[j][3] == c2 then
				c.cp[i], c.co[i], found = j - 1, ori, true
			end
		end
		if not found then
			return nil, "bad corner"
		end
	end
	for i = 1, 12 do
		local a, b = f[EDGE_FACELET[i][1]], f[EDGE_FACELET[i][2]]
		local found = false
		for j = 1, 12 do
			if EDGE_COLOR[j][1] == a and EDGE_COLOR[j][2] == b then
				c.ep[i], c.eo[i], found = j - 1, 0, true
			elseif EDGE_COLOR[j][1] == b and EDGE_COLOR[j][2] == a then
				c.ep[i], c.eo[i], found = j - 1, 1, true
			end
		end
		if not found then
			return nil, "bad edge"
		end
	end
	return c
end

local function isPhase2Move(m)
	local face, power = m // 3, m % 3
	return face == 0 or face == 3 or power == 1
end

local function allowed(face, lastFace)
	if lastFace == nil then
		return true
	end
	return face ~= lastFace and face ~= lastFace - 3
end

function Solver.solve(facelets, maxPhase2)
	local t = Solver.prepare(false)
	local cube, err = toCubie(facelets)
	if not cube then
		return nil, err
	end
	local twistMove, flipMove, sliceMove = t.twistMove, t.flipMove, t.sliceMove
	local pruneTwist, pruneFlip = t.pruneTwist, t.pruneFlip
	local cpMove, epMove, spMove = t.cpMove, t.epMove, t.spMove
	local pruneCp, pruneEp = t.pruneCp, t.pruneEp
	maxPhase2 = maxPhase2 or 18

	local occ = {}
	for i = 1, 12 do
		occ[i] = cube.ep[i] >= 8
	end
	local tw0, fl0, sl0 = twistOf(cube.co), flipOf(cube.eo), sliceOf(occ)
	local path1, path2 = {}, {}
	local solution = nil

	local function phase2(cp, ep, sp, depth, lastFace)
		if depth == 0 then
			return cp == 0 and ep == 0 and sp == 0
		end
		local h = math.max(buffer.readu8(pruneCp, sp * N_PERM8 + cp), buffer.readu8(pruneEp, sp * N_PERM8 + ep))
		if h > depth then
			return false
		end
		for k, m in ipairs(PHASE2_MOVES) do
			local face = m // 3
			if allowed(face, lastFace) then
				local base = (k - 1) * 2
				path2[#path2 + 1] = m
				if phase2(buffer.readu16(cpMove, cp * 20 + base), buffer.readu16(epMove, ep * 20 + base), spMove[sp * 10 + k], depth - 1, face) then
					return true
				end
				path2[#path2] = nil
			end
		end
		return false
	end

	local function startPhase2()
		local c = cube
		for _, m in ipairs(path1) do
			c = multiply(c, MOVES[m + 1])
		end
		local cp = rankPerm(c.cp, 8)
		local e8, s4 = table.create(8, 0), table.create(4, 0)
		for i = 1, 8 do
			e8[i] = c.ep[i]
		end
		for i = 1, 4 do
			s4[i] = c.ep[i + 8] - 8
		end
		local ep, sp = rankPerm(e8, 8), rankPerm(s4, 4)
		local lastFace = #path1 > 0 and path1[#path1] // 3 or nil
		for depth = 0, maxPhase2 do
			table.clear(path2)
			if phase2(cp, ep, sp, depth, lastFace) then
				return true
			end
		end
		return false
	end

	local function phase1(tw, fl, sl, depth, lastFace)
		if depth == 0 then
			if tw == 0 and fl == 0 and sl == 0 then
				local last = path1[#path1]
				if last == nil or not isPhase2Move(last) then
					return startPhase2()
				end
			end
			return false
		end
		local h = math.max(buffer.readu8(pruneTwist, sl * N_TWIST + tw), buffer.readu8(pruneFlip, sl * N_FLIP + fl))
		if h > depth then
			return false
		end
		for m = 0, 17 do
			local face = m // 3
			if allowed(face, lastFace) then
				path1[#path1 + 1] = m
				if phase1(twistMove[tw * 18 + m + 1], flipMove[fl * 18 + m + 1], sliceMove[sl * 18 + m + 1], depth - 1, face) then
					return true
				end
				path1[#path1] = nil
			end
		end
		return false
	end

	for depth = 0, 14 do
		table.clear(path1)
		if phase1(tw0, fl0, sl0, depth, nil) then
			local quarter = {}
			for _, list in ipairs({ path1, path2 }) do
				for _, m in ipairs(list) do
					local face, power = FACES[m // 3 + 1], m % 3 + 1
					if power == 1 then
						quarter[#quarter + 1] = face
					elseif power == 2 then
						quarter[#quarter + 1] = face
						quarter[#quarter + 1] = face
					else
						quarter[#quarter + 1] = face .. "'"
					end
				end
			end
			return quarter
		end
	end
	return nil, "no solution found"
end

return Solver
end)()

local State = require(Client:WaitForChild("State"))
local ReplayController = Client.Controllers:FindFirstChild("ReplayController")
ReplayController = ReplayController and select(2, pcall(require, ReplayController))
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

stats.botRequests = 0
stats.chairs = 0
stats.crates = 0
stats.opened = 0
stats.claims = 0

local function tableInput(payload)
	pcall(function()
		Net.event("TableInput"):FireServer(payload)
	end)
end

local function playerData()
	local ok, data = pcall(function()
		return State.Data
	end)
	return ok and type(data) == "table" and data or nil
end

function STATE.coins()
	local data = playerData()
	return data and tonumber(data.Coins) or 0
end

-- Votes and powerup picks answer the match events the game sends.
trackConnection(Net.event("MatchEvent").OnClientEvent:Connect(function(event)
	if type(event) ~= "table" or not running() then
		return
	end
	if event.Type == "ModifierVote" and STATE.autoModifiers == true then
		-- Voting closes the moment both sides are ready, and a bot is ready at once.
		-- So every pick goes in first, and only then does Auto Ready ready up.
		STATE.voting = true
		task.spawn(function()
			task.wait(0.3 + math.random() * 0.3)
			local wanted = { Gameplay = STATE.voteGameplay, Modifier = STATE.voteModifier, Powerup = STATE.votePowerup }
			local voted, locked = {}, {}
			for _, column in ipairs(type(event.Columns) == "table" and event.Columns or {}) do
				local pick = wanted[column.Id]
				local offered, readable, isLocked = false, false, false
				for _, cardInfo in ipairs(type(column.Cards) == "table" and column.Cards or {}) do
					local id = type(cardInfo) == "table" and (cardInfo.Id or cardInfo.Option or cardInfo.Key) or cardInfo
					readable = readable or type(id) == "string"
					if id == pick then
						offered = true
						-- Ladder bots you haven't beaten, first games and new players lock the cards; the server drops those votes.
						isLocked = type(cardInfo) == "table" and (cardInfo.Locked == true or cardInfo.ComingSoon == true)
					end
				end
				-- If the cards carry no id we can read, vote anyway and let the server decide.
				offered = offered or not readable
				if pick and offered and isLocked then
					locked[#locked + 1] = pick
				elseif pick and offered then
					tableInput({ Type = "Vote", Column = column.Id, Option = pick })
					voted[#voted + 1] = pick
					task.wait(0.12)
				end
			end
			if #voted > 0 then
				noteActivity("Voted " .. table.concat(voted, " · "))
			end
			if #locked > 0 then
				local why = event.LadderLock and "beat this bot first" or (event.FirstGame and "first game is defaults only") or "locked this match"
				noteActivity("Skipped " .. table.concat(locked, " · ") .. " (" .. why .. ")")
			end
			if STATE.autoReady == true then
				task.wait(0.4)
				tableInput({ Type = "VoteReady" })
			end
			STATE.voting = false
		end)
	elseif event.Type == "PowerupPick" and STATE.autoModifiers == true then
		task.delay(0.6 + math.random() * 0.6, function()
			tableInput({ Type = "PickPowerup", Id = STATE.votePowerup })
		end)
	elseif event.Type == "PowerupIntro" and STATE.autoReady == true then
		task.delay(0.8, function()
			tableInput({ Type = "PowerupIntroOk" })
		end)
	end
end))

local function stepReplay()
	if STATE.autoSkipReplay ~= true or type(ReplayController) ~= "table" then
		return
	end
	local ok, playing = pcall(ReplayController.IsPlaying)
	if ok and playing then
		pcall(ReplayController.Skip)
	end
end

local waitingSince, lastBotAt = nil, 0
local function stepBot()
	local slot = Match.CurrentSlot
	local tableId = Match.CurrentTableId
	if STATE.autoBot ~= true or not seated() or Match.InMatch or not slot or not tableId then
		waitingSince = nil
		return
	end
	local tbl
	for _, candidate in ipairs(workspace.Tables:GetChildren()) do
		if candidate:GetAttribute("TableId") == tableId then
			tbl = candidate
		end
	end
	local other = tbl and tbl:GetAttribute("P" .. (3 - slot) .. "UserId") or 0
	if other ~= 0 or (tbl and tbl:GetAttribute("CubeSize") == 2) then
		waitingSince = nil
		return
	end
	waitingSince = waitingSince or os.clock()
	if os.clock() - waitingSince < STATE.botWait or os.clock() - lastBotAt < 15 then
		return
	end
	lastBotAt = os.clock()
	-- The ladder only lets you pick a bot once the one before it is beaten;
	-- a locked pick is ignored by the server, so fall back to the highest unlocked bot.
	local data = playerData()
	local beaten = data and type(data.BotLadder) == "table" and type(data.BotLadder.Beaten) == "table" and data.BotLadder.Beaten or {}
	local botId, label = nil, nil
	for index, bot in ipairs(BOTS) do
		local unlocked = index == 1 or beaten[BOTS[index - 1].id] == true
		if not unlocked then
			break
		end
		botId, label = bot.id, bot.label
		if bot.id == STATE.botId then
			break
		end
	end
	if not botId then
		return
	end
	tableInput({ Type = "ReserveBot" })
	task.wait(0.4)
	tableInput({ Type = "RequestBot", BotId = botId })
	stats.botRequests += 1
	noteActivity("Asked for " .. label .. (botId ~= STATE.botId and " (your pick is still locked)" or ""))
end

local function stepShop()
	local data = playerData()
	if not data then
		return
	end
	if STATE.autoBuyChairs == true and type(data.ChairShop) == "table" and type(data.ChairShop.Items) == "table" then
		for _, item in ipairs(data.ChairShop.Items) do
			local owned = type(data.Chairs) == "table" and data.Chairs[item.ChairId]
			if not owned and tonumber(item.Price) and STATE.coins() >= item.Price then
				local ok, result = pcall(function()
					return Net.func("BuyWithCoins"):InvokeServer("Chair:" .. tostring(item.ChairId))
				end)
				if ok and type(result) == "table" and result.Ok then
					stats.chairs += 1
					noteActivity("Bought " .. tostring(item.ChairId))
				end
				task.wait(1)
			end
		end
	end
	if STATE.autoBuyCrates == true then
		for _, crate in ipairs(CRATES) do
			if crate.id == STATE.crateId and STATE.coins() >= (tonumber(crate.price) or math.huge) then
				local ok, result = pcall(function()
					return Net.func("OpenCrate"):InvokeServer(crate.id, "Buy")
				end)
				if ok and type(result) == "table" and result.Ok then
					stats.crates += 1
					noteActivity("Bought a " .. crate.label)
				end
			end
		end
	end
	if STATE.autoOpenCrates == true and type(data.CrateInv) == "table" then
		for crateId, count in pairs(data.CrateInv) do
			if (tonumber(count) or 0) > 0 then
				local ok, result = pcall(function()
					return Net.func("OpenCrate"):InvokeServer(crateId)
				end)
				if ok and type(result) == "table" and result.Ok then
					stats.opened += 1
					noteActivity("Opened a " .. tostring(crateId) .. " crate")
				end
				task.wait(1.5)
				break
			end
		end
	end
end

-- Rewards: claim only what the game's own data says is ready, the same checks its menus use.
local function invoke(name, ...)
	local args = table.pack(...)
	local ok, result = pcall(function()
		return Net.func(name):InvokeServer(table.unpack(args, 1, args.n))
	end)
	return ok and type(result) == "table" and result.Ok == true, result
end

local questTargets = {}
for _, quest in ipairs(type(Config.Quests) == "table" and type(Config.Quests.Pool) == "table" and Config.Quests.Pool or {}) do
	if type(quest) == "table" and quest.Id then
		questTargets[quest.Id] = tonumber(quest.Target)
	end
end

local lastClaimScan = 0
local function stepRewards()
	if os.clock() - lastClaimScan < 10 then
		return
	end
	lastClaimScan = os.clock()
	local data = playerData()
	if not data then
		return
	end
	local daily = type(data.Daily) == "table" and data.Daily
	if STATE.autoDaily == true and daily then
		local due = daily.CanClaim == true or (tonumber(daily.NextClaimAt) and workspace:GetServerTimeNow() >= daily.NextClaimAt)
		if due then
			local ok, result = invoke("ClaimDaily")
			if ok then
				local reward = type(result.Reward) == "table" and result.Reward or {}
				stats.claims += 1
				noteActivity("Claimed daily reward" .. (reward.Day and (" (day " .. tostring(reward.Day) .. ")") or ""))
			end
		end
	end
	local quests = type(data.Quests) == "table" and type(data.Quests.Items) == "table" and data.Quests.Items or {}
	if STATE.autoQuests == true then
		-- ClaimQuest takes the quest's slot number, not its Id.
		for slot, quest in ipairs(quests) do
			local target = questTargets[quest.Id]
			if not quest.Claimed and target and (tonumber(quest.Progress) or 0) >= target then
				if invoke("ClaimQuest", slot) then
					stats.claims += 1
					noteActivity("Claimed quest " .. tostring(quest.Id))
				end
				task.wait(0.5)
			end
		end
	end
	if STATE.autoAchievements == true then
		local claimed = type(data.AchClaimed) == "table" and data.AchClaimed or {}
		for _, achievement in ipairs(type(Config.Achievements) == "table" and Config.Achievements or {}) do
			local value = tonumber(data[achievement.Stat])
			if value == nil and achievement.Stat == "QuestsClaimed" and type(data.Quests) == "table" then
				value = tonumber(data.Quests.Total)
			end
			if not claimed[achievement.Id] and value and value >= (tonumber(achievement.Target) or math.huge) then
				if invoke("ClaimAchievement", achievement.Id) then
					stats.claims += 1
					noteActivity("Claimed achievement " .. tostring(achievement.Id))
				end
				task.wait(0.5)
			end
		end
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
		for part in pairs(noclipParts) do
			if part.Parent then
				part.CanCollide = true
			end
		end
		table.clear(noclipParts)
	end
end))

trackConnection(ProximityPromptService.PromptShown:Connect(function(prompt)
	if STATE.instantPrompts == true then
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
local function hidePausePopup()
	if STATE.noPausePopup ~= true then
		return
	end
	local robloxGui = CoreGui:FindFirstChild("RobloxGui")
	local pause = robloxGui and robloxGui:FindFirstChild("CoreScripts/NetworkPause")
	if pause then
		pcall(function()
			if pause:IsA("ScreenGui") then
				pause.Enabled = false
			else
				pause.Visible = false
			end
		end)
	end
end

trackConnection(GuiService.ErrorMessageChanged:Connect(function(message)
	if STATE.autoReconnect == true and type(message) == "string" and message ~= "" then
		task.wait(2)
		pcall(function()
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		end)
	end
end))

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
function STATE.applyFpsBoost()
	if STATE.fpsBoost == true then
		graphicsBefore = graphicsBefore or { shadows = Lighting.GlobalShadows, effects = {} }
		pcall(function()
			graphicsBefore.quality = graphicsBefore.quality or settings().Rendering.QualityLevel
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
		Lighting.GlobalShadows = false
		for _, effect in ipairs(Lighting:GetChildren()) do
			if effect:IsA("PostEffect") and effect.Enabled then
				graphicsBefore.effects[effect] = true
				effect.Enabled = false
			end
		end
	elseif graphicsBefore then
		Lighting.GlobalShadows = graphicsBefore.shadows
		pcall(function()
			if graphicsBefore.quality then
				settings().Rendering.QualityLevel = graphicsBefore.quality
			end
		end)
		for effect in pairs(graphicsBefore.effects) do
			if effect.Parent then
				effect.Enabled = true
			end
		end
		graphicsBefore = nil
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

local function installHub()
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
	gui.Name = "ZinoosCubeMenu"
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
	local launcher
	local fullMode = false
	local applyHubLayout
	local function fitScale()
		local view = viewSize()
		local phone = UserInputService.TouchEnabled and math.min(view.X, view.Y) < 820
		local compact = phone or view.X < 760 or view.Y < 560 or (UserInputService.TouchEnabled and view.X < 900)
		local margin = (compact or fullMode) and 0 or 16
		local baseW, baseH
		if phone and not fullMode then
			baseW = math.max(280, math.floor(view.X * 0.84))
			baseH = math.max(320, math.floor(view.Y * 0.76))
			baseW = math.min(baseW, math.max(280, view.X - 20))
			baseH = math.min(baseH, math.max(280, view.Y - 20))
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
	dockGame.Text = STATE.admin and "Admin" or "Solve The Cube"
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
	brandSub.Text = "Solve The Cube"
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
	local playerPage = newPage("Player")

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
	addNav("Player", 3)

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
	profileGame.Text = STATE.admin and "Admin" or "Solve The Cube"
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
			if current == playerPage then
				page = "Player"
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
		if key == "antiAfk" and on and pulseAntiAfk then
			task.defer(pulseAntiAfk)
		elseif key == "disable3d" then
			STATE.apply3d()
		elseif key == "fpsBoost" then
			STATE.applyFpsBoost()
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

	local function makeMultiDropdown(parentBox, name, getList, options, onToggleName, labelOf)
		local showList = labelOf or STATE.rarityLabel
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
		remember(row, parentBox, name)
		return pick
	end

	STATE.toggleControls = {}

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
	local solveCard = card(leftColumn, "SOLVING", 1)
	makeSwitch(solveCard, "Auto Solve", "autoSolve", "Types the right key for every move during a race")
	makeDropdown(solveCard, "Moves Per Second", function()
		return tostring(STATE.tps)
	end, TPS_OPTIONS, function(option)
		STATE.tps = tonumber(option) or STATE.tps
		saveConfig()
	end)
	makeSwitch(solveCard, "Humanize", "humanize", "Small random gaps between moves")
	makeSwitch(solveCard, "Auto Solve Zero Assist", "autoZeroAssist", "Reads the real 3x3 and solves it. Not 2x2 yet")
	makeDropdown(solveCard, "Zero Assist Speed", function()
		return tostring(STATE.zaTps)
	end, ZA_TPS_OPTIONS, function(option)
		STATE.zaTps = tonumber(option) or STATE.zaTps
		saveConfig()
	end)

	local matchCard = card(rightColumn, "MATCHES", 1)
	makeSwitch(matchCard, "Auto Ready", "autoReady", "Presses Ready as soon as the cube is shown")
	makeSwitch(matchCard, "Auto Sit", "autoSit", "Takes a free seat, preferring tables with a player waiting")
	makeDropdown(matchCard, "Table Type", function()
		return STATE.tableType
	end, TABLE_TYPES, function(option)
		STATE.tableType = option
		saveConfig()
	end)
	makeSwitch(matchCard, "Prefer Tables With A Player", "preferWaiting")
	makeSwitch(matchCard, "Auto Skip Replay", "autoSkipReplay", "Skips the replay after each game")

	local function labelFor(list, id)
		for _, entry in ipairs(list) do
			if entry.id == id then
				return entry.label
			end
		end
		return tostring(id)
	end
	local function idFor(list, text)
		for _, entry in ipairs(list) do
			if entry.label == text then
				return entry.id
			end
		end
		return nil
	end

	local botCard = card(leftColumn, "BOT", 2)
	makeSwitch(botCard, "Auto Bot If No Players", "autoBot", "Asks for a bot when nobody sits down in time")
	makeDropdown(botCard, "Wait Before Bot (s)", function()
		return tostring(STATE.botWait)
	end, BOT_WAIT_OPTIONS, function(option)
		STATE.botWait = tonumber(option) or STATE.botWait
		saveConfig()
	end)
	makeDropdown(botCard, "Bot", function()
		return labelFor(BOTS, STATE.botId)
	end, BOT_LABELS, function(option)
		STATE.botId = idFor(BOTS, option) or STATE.botId
		saveConfig()
	end, true)

	local modCard = card(leftColumn, "MODIFIERS", 3)
	makeSwitch(modCard, "Auto Modifiers", "autoModifiers", "Votes your picks and chooses your powerup")
	makeDropdown(modCard, "Gameplay", function()
		return STATE.voteGameplay
	end, GAMEPLAY_OPTIONS, function(option)
		STATE.voteGameplay = option
		saveConfig()
	end)
	makeDropdown(modCard, "Modifier", function()
		return STATE.voteModifier
	end, MODIFIER_OPTIONS, function(option)
		STATE.voteModifier = option
		saveConfig()
	end)
	makeDropdown(modCard, "Powerup", function()
		return STATE.votePowerup
	end, POWERUP_OPTIONS, function(option)
		STATE.votePowerup = option
		saveConfig()
	end)

	local shopCard = card(rightColumn, "SHOP", 2)
	makeSwitch(shopCard, "Auto Buy Chairs", "autoBuyChairs", "Buys chairs from today's shop you don't own yet")
	makeSwitch(shopCard, "Auto Buy Crates", "autoBuyCrates", "Keeps buying the crate below while you have the coins")
	makeDropdown(shopCard, "Crate", function()
		return labelFor(CRATES, STATE.crateId)
	end, CRATE_LABELS, function(option)
		STATE.crateId = idFor(CRATES, option) or STATE.crateId
		saveConfig()
	end, true)
	makeSwitch(shopCard, "Open Bought Crates", "autoOpenCrates")

	local rewardsCard = card(rightColumn, "REWARDS", 3)
	makeSwitch(rewardsCard, "Auto Claim Daily", "autoDaily", "Claims the daily login reward when it's ready")
	makeSwitch(rewardsCard, "Auto Claim Quests", "autoQuests", "Claims daily quests once they're complete")
	makeSwitch(rewardsCard, "Auto Claim Achievements", "autoAchievements", "Claims achievements once you reach them")

	local screenCard = card(rightColumn, "SCREEN", 4)
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
	end, true)

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
	local blurb = label(intro, "Sits at a table, readies up, and types every move of the solve for you.", 14, muted, Enum.Font.Gotham, 36)
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
	local solvesText = statChip(statGrid, "Coins", 1)
	solvesText.Parent.Position = UDim2.fromOffset(0, 0)
	local movesText = statChip(statGrid, "Solves", 2)
	movesText.Parent.Position = UDim2.new(0.5, 5, 0, 0)
	local tableText = statChip(statGrid, "Table", 3)
	tableText.Parent.Position = UDim2.fromOffset(0, 68)
	local statusText = statChip(statGrid, "Phase", 4)
	statusText.Parent.Position = UDim2.new(0.5, 5, 0, 68)
	statusText.TextSize = 14
	statusText.TextTruncate = Enum.TextTruncate.AtEnd
	local refreshHealth = nil
	STATE.refreshHealth = nil

	local note = card(homePage, "HOW IT WORKS", 7)
	local noteBody = label(note, "Sit at a table. When the race starts, Auto Solve types the right key for every move at the speed you picked. Zero Assist rounds are left to you.", 13, ink, Enum.Font.Gotham, 56)
	noteBody.LayoutOrder = 1

	local activityCard = card(homePage, "ACTIVITY", 8)
	local activityBody = label(activityCard, "Waiting for the next thing the hub does.", 13, muted, Enum.Font.Gotham, 72)
	activityBody.LayoutOrder = 1
	activityBody.AutomaticSize = Enum.AutomaticSize.Y
	activityBody.Size = UDim2.new(1, 0, 0, 0)
	activityBody.TextWrapped = true
	remember(activityBody, activityCard, "activity status solves")
	local function refreshActivity()
		local lines = {
			"Status · " .. tostring(STATE.status),
			string.format("Session · %d solves, %d moves, %d bot requests", stats.solves, stats.moves, stats.botRequests),
			string.format("Bought · %d chairs, %d crates, %d opened", stats.chairs, stats.crates, stats.opened),
			string.format("Rewards · %d claimed", stats.claims),
		}
		if STATE.antiAfk == true then
			lines[#lines + 1] = STATE.antiAfkOperational == true and "Anti AFK working through VirtualUser" or "Anti AFK waiting for idle"
		end
		if #STATE.activity > 0 then
			lines[#lines + 1] = table.concat(STATE.activity, "\n")
		end
		local text = table.concat(lines, "\n")
		if activityBody.Text ~= text then
			activityBody.Text = text
		end
		activityBody.TextColor3 = STATE.hubThemeDef().ink
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
	makeSwitch(movement, "WalkSpeed", "walkSpeed")
	makeDropdown(movement, "Speed", function()
		return tostring(STATE.speed)
	end, SPEED_OPTIONS, function(option)
		STATE.speed = tonumber(option) or STATE.speed
		saveConfig()
	end)
	makeSwitch(movement, "Infinite Jump", "infiniteJump")
	makeSwitch(movement, "Noclip", "noclip")
	makeSwitch(movement, "Instant ProximityPrompt", "instantPrompts", "Prompts fire without holding the key")

	local flyCard = card(playerPage, "FLY", 3)
	makeSwitch(flyCard, "Fly", "fly", "WASD to move, Space up, Left Ctrl down")
	makeDropdown(flyCard, "Fly Speed", function()
		return tostring(STATE.flySpeed)
	end, FLY_SPEED_OPTIONS, function(option)
		STATE.flySpeed = tonumber(option) or STATE.flySpeed
		saveConfig()
	end)

	local clientCard = card(playerPage, "CLIENT", 4)
	makeSwitch(clientCard, "Anti AFK", "antiAfk", "Stays in the game while you are idle")
	makeSwitch(clientCard, "No Gameplay Paused", "noPausePopup", "Hides the Gameplay Paused popup")
	makeSwitch(clientCard, "Auto Reconnect on Kick", "autoReconnect", "Rejoins the game when you get disconnected")
	makeSwitch(clientCard, "Disable 3D Rendering", "disable3d", "Big FPS saver while you AFK")
	makeSwitch(clientCard, "FPS Boost", "fpsBoost", "Lowest graphics, no shadows or effects")
	makeSwitch(clientCard, "Hide UI On Start", "hideOnStart", "Starts hidden. Press the toggle key to show it")
	makeDropdown(clientCard, "Toggle Key", function()
		return STATE.toggleKey
	end, KEY_OPTIONS, function(option)
		STATE.toggleKey = option
		saveConfig()
	end)

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
		elseif playerPage.Visible then
			current = "Player"
		end
		if pages[current] then
			return
		end
		if pages.Home and not pages.Main and not pages.Player then
			showPage("Home")
		elseif pages.Main and not pages.Home and not pages.Player then
			showPage("Main")
		elseif pages.Player and not pages.Home and not pages.Main then
			showPage("Player")
		elseif pages.Home then
			showPage("Home")
		elseif pages.Main then
			showPage("Main")
		elseif pages.Player then
			showPage("Player")
		end
	end
	trackConnection(search:GetPropertyChangedSignal("Text"):Connect(applySearch))
	local function refreshHome()
		local coins = STATE.coins()
		solvesText.Text = coins >= 1000 and string.format("%.2fK", coins / 1000) or tostring(coins)
		movesText.Text = tostring(stats.solves)
		local tableId = Match.CurrentTableId
		tableText.Text = tableId and ("Table " .. tostring(tableId)) or "Not seated"
		local stage = screen() and screen().Stage
		statusText.Text = stage and stage.phase and stage.phase ~= "Hidden" and tostring(stage.phase) or "Idle"
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
		for index, name in ipairs({ "Home", "Main", "Player" }) do
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
		if processed or search:IsFocused() then
			return
		end
		if input.KeyCode.Name == STATE.toggleKey then
			setOpen(not holder.Visible)
		end
	end))

	local saveCard = card(homePage, "CONFIG", 10)
	local saveNote = label(saveCard, "Saves the toggles, speed, table type and theme for this account. Your other account keeps its own save.", 13, muted, Enum.Font.Gotham, 40)
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
	launcher.Visible = STATE.hideOnStart ~= true
	dockHint.Text = "Click or press " .. tostring(STATE.toggleKey) .. " to open"

	STATE.hubWindow = {
		Unload = function()
			unloadHub()
		end,
	}
end
loadSaved()

task.spawn(function()
	if not running() then
		return
	end
	local ok, err = pcall(installHub)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
		if running() then
			shutdownHub()
		end
	end
end)

-- Solving runs on its own fast loop so a long solve never delays the others.
task.spawn(function()
	while running() do
		pcall(stepSolve)
		pcall(stepZeroAssist)
		task.wait(0.05)
	end
end)

-- The solver's tables take a few seconds to build, so do it in the background, once per session.
task.spawn(function()
	if STATE.autoZeroAssist == true and type(CubeSolver) == "table" and not CubeSolver.ready() then
		local ok = pcall(CubeSolver.prepare, true)
		noteActivity(ok and "Zero Assist solver ready" or "Zero Assist solver failed to load")
	end
end)

task.spawn(function()
	while running() do
		pcall(stepReady)
		pcall(stepSpeed)
		pcall(stepReplay)
		pcall(hidePausePopup)
		if STATE.status ~= "Solving" then
			if Match.InMatch then
				STATE.status = "In match"
			elseif seated() then
				STATE.status = "Seated, waiting for a match"
			elseif STATE.autoSit ~= true then
				STATE.status = "Idle"
			end
		end
		task.wait(0.25)
	end
end)

task.spawn(function()
	while running() do
		pcall(stepSit)
		pcall(stepBot)
		task.wait(1)
	end
end)

task.spawn(function()
	while running() do
		task.wait(5)
		pcall(stepShop)
		pcall(stepRewards)
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
