-- Zinoos hub for Climb For Animals Eggs.
-- Same menu as the Lift Rock hub. The egg farm takes only eggs that beat your weakest team
-- animal, from any biome, and trains speed on the treadmill the rest of the time. Placing,
-- hatching, equip best, fusing, rebirth, base upgrades and selling all go through the game's
-- own controllers and remotes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

if game.PlaceId ~= 85738654635245 then
	warn("[Zinoos hub] This only runs in Climb For Animals Eggs.")
	return
end

local LocalPlayer = Players.LocalPlayer
local genv = getgenv()

-- One copy at a time: a new run stops the old one first.
if typeof(genv.ZinoosClimbStop) == "function" then
	pcall(genv.ZinoosClimbStop)
end
genv.ZinoosClimbGen = (typeof(genv.ZinoosClimbGen) == "number" and genv.ZinoosClimbGen or 0) + 1
local token = genv.ZinoosClimbGen
local function running()
	return genv.ZinoosClimbGen == token
end

local STATE = {
	_gen = token,
	eggFarm = true,
	onlyUpgrades = true,
	treadmill = true,
	guardSafe = true,
	autoPlace = true,
	autoHatch = true,
	equipBest = true,
	autoFuse = true,
	autoRebirth = true,
	autoUpgrade = false,
	autoSell = true,
	sellMinutes = 2,
	candyFarm = false,
	buyCandyEgg = false,
	godMode = true,
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
	hideOnStart = false,
	farmPickMode = "Best egg",
	farmRarities = {},
	farmBiomes = {},
	farmEggs = {},
	farmSpecialOnly = false,
	farmMinIncome = "Any",
	placePickMode = "Best for team",
	placeRarities = {},
	placeEggs = {},
	placeBeatsOnly = true,
	hatchPickMode = "Everything",
	hatchRarities = {},
	hatchEggs = {},
	autoStamina = true,
	autoTreadmillUpgrade = true,
	toggleKey = "RightControl",
	toggleControls = {},
	themeSwitches = {},
}
genv.ZinoosClimbState = STATE

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
		local old = root and root:FindFirstChild("ZinoosClimbMenu")
		if old then
			old:Destroy()
		end
	end
end

local function shutdownHub()
	if genv.ZinoosClimbGen == token then
		genv.ZinoosClimbGen = token + 1
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
genv.ZinoosClimbStop = shutdownHub
local function unloadHub()
	shutdownHub()
end

local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/ClimbAnimals_" .. tostring(LocalPlayer.UserId) .. ".rfld"
local SPEED_OPTIONS = { "16", "24", "32", "50", "75", "100" }
local SELL_MINUTE_OPTIONS = { "1", "2", "5", "10", "30" }

local FLAG_KEYS = {
	EggFarm = "eggFarm",
	OnlyUpgrades = "onlyUpgrades",
	Treadmill = "treadmill",
	GuardSafe = "guardSafe",
	AutoPlace = "autoPlace",
	AutoHatch = "autoHatch",
	EquipBest = "equipBest",
	AutoFuse = "autoFuse",
	AutoRebirth = "autoRebirth",
	AutoUpgrade = "autoUpgrade",
	AutoSell = "autoSell",
	CandyFarm = "candyFarm",
	BuyCandyEgg = "buyCandyEgg",
	GodMode = "godMode",
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
	HideOnStart = "hideOnStart",
	FarmSpecialOnly = "farmSpecialOnly",
	PlaceBeatsOnly = "placeBeatsOnly",
	AutoStamina = "autoStamina",
	AutoTreadmillUpgrade = "autoTreadmillUpgrade",
}

local FLY_SPEED_OPTIONS = { "30", "60", "100", "150", "200" }
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
STATE.FARM_MODES = { "Best egg", "My picks" }
STATE.PLACE_MODES = { "Best for team", "My picks" }
STATE.HATCH_MODES = { "Everything", "My picks" }
STATE.MIN_INCOME = { Any = 0, ["1K"] = 1e3, ["100K"] = 1e5, ["1M"] = 1e6, ["100M"] = 1e8, ["1B"] = 1e9, ["100B"] = 1e11, ["1T"] = 1e12, ["100T"] = 1e14 }
STATE.MIN_INCOME_OPTIONS = { "Any", "1K", "100K", "1M", "100M", "1B", "100B", "1T", "100T" }
local CHOICES = {
	ToggleKey = { key = "toggleKey", options = KEY_OPTIONS },
	FarmPickMode = { key = "farmPickMode", options = STATE.FARM_MODES },
	PlacePickMode = { key = "placePickMode", options = STATE.PLACE_MODES },
	HatchPickMode = { key = "hatchPickMode", options = STATE.HATCH_MODES },
	FarmMinIncome = { key = "farmMinIncome", options = STATE.MIN_INCOME_OPTIONS },
}
-- Picked egg names, rarities and biomes, saved as lists of strings.
STATE.LIST_KEYS = {
	FarmRarities = "farmRarities",
	FarmBiomes = "farmBiomes",
	FarmEggs = "farmEggs",
	PlaceRarities = "placeRarities",
	PlaceEggs = "placeEggs",
	HatchRarities = "hatchRarities",
	HatchEggs = "hatchEggs",
}
local NUMBERS = { FlySpeed = { "flySpeed", 10, 300 }, SellMinutes = { "sellMinutes", 1, 30 } }
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

-- Game modules. Knit can still be starting right after a join, so wait for it.
local function timed(fn, seconds)
	local done, value = false, nil
	task.spawn(function()
		local ok, result = pcall(fn)
		value = ok and result or nil
		done = true
	end)
	local started = os.clock()
	while not done and os.clock() - started < seconds do
		task.wait(0.05)
	end
	return value
end

local knit
for _ = 1, 240 do
	if not running() then
		return
	end
	knit = timed(function()
		return require(ReplicatedStorage.src.Packages.knit)
	end, 2)
	if knit and timed(function()
		return knit.GetController("DataController")
	end, 1.5) then
		break
	end
	knit = nil
	task.wait(0.5)
end
if not knit then
	warn("[Zinoos hub] Climb For Animals Eggs did not finish loading.")
	shutdownHub()
	return
end
local function controller(name)
	return timed(function()
		return knit.GetController(name)
	end, 5)
end

local DataController = controller("DataController")
local BaseController = controller("BaseController")
local AutoHatchController = controller("AutoHatchController")
local EggCarryController = controller("EggCarryController")
local FallController = controller("FallController")
local TreadmillController = controller("TreadmillController")
local ZoneController = controller("ZoneController")
local BaseUpgradeController = controller("BaseUpgradeController")
local RebirthController = controller("RebirthController")
local GuardController = controller("GuardController")
local AnimalSellController = controller("AnimalSellController")
local FuseService = timed(function()
	return knit.GetService("FuseService")
end, 5)

local knitServices = ReplicatedStorage.src.Packages._Index["sleitnick_knit@1.7.0"].knit.Services
local equipRemote = knitServices.AnimalLoadoutService.RF.Request
local placeRemote = knitServices.EggPlacementService.RF.RequestToPlace

local earningCurve = require(ReplicatedStorage.src.utility.earningCurve)
local dayCycle = require(ReplicatedStorage.src.utility.dayCycle)
local fuseConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.fuseConfig)
local rebirthConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.rebirthConfig)
local baseUpgradeConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.baseUpgradeConfig)
local sellConfig = require(ReplicatedStorage.src.GameConfiguration.Economy.animalSellConfig)

-- Egg picks and stamina reach. Kept on STATE so this big chunk doesn't run out of locals.
STATE.eggCfg = require(ReplicatedStorage.src.GameConfiguration.Gameplay.eggConfig)
STATE.zoneCfg = require(ReplicatedStorage.src.GameConfiguration.Gameplay.zoneConfig)
STATE.staminaCfg = require(ReplicatedStorage.src.GameConfiguration.Economy.staminaUpgradeConfig)
STATE.staminaController = controller("StaminaUpgradeController")

function STATE.eggRarity(name)
	local entry = type(STATE.eggCfg.Eggs) == "table" and STATE.eggCfg.Eggs[name]
	return type(entry) == "table" and entry.Rarity or nil
end

-- Rarities ordered by how much their weakest egg earns, so the list reads Common up to the rarest.
do
	local cheapest, names, biomeSet = {}, {}, {}
	for name, entry in pairs(type(STATE.eggCfg.Eggs) == "table" and STATE.eggCfg.Eggs or {}) do
		if type(entry) == "table" and type(entry.Rarity) == "string" then
			local ok, income = pcall(earningCurve.GetCashPerSecond, name, 1, "Normal", nil)
			income = ok and tonumber(income) or 0
			cheapest[entry.Rarity] = math.min(cheapest[entry.Rarity] or math.huge, income)
			table.insert(names, name)
			if type(entry.Biome) == "string" and type(STATE.zoneCfg[entry.Biome]) == "table" then
				biomeSet[entry.Biome] = tonumber(STATE.zoneCfg[entry.Biome].Height) or 0
			end
		end
	end
	STATE.RARITY_OPTIONS = {}
	for rarity in pairs(cheapest) do
		table.insert(STATE.RARITY_OPTIONS, rarity)
	end
	table.sort(STATE.RARITY_OPTIONS, function(a, b)
		return cheapest[a] < cheapest[b]
	end)
	table.sort(names)
	STATE.EGG_OPTIONS = names
	STATE.BIOME_OPTIONS = {}
	for biome in pairs(biomeSet) do
		table.insert(STATE.BIOME_OPTIONS, biome)
	end
	table.sort(STATE.BIOME_OPTIONS, function(a, b)
		return biomeSet[a] < biomeSet[b]
	end)
end

function STATE.listHas(list, value)
	if type(list) ~= "table" then
		return false
	end
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

function STATE.toggleListItem(key, value)
	local list = type(STATE[key]) == "table" and STATE[key] or {}
	local index = table.find(list, value)
	if index then
		table.remove(list, index)
	else
		table.insert(list, value)
	end
	STATE[key] = list
end

-- prefix is "farm", "place" or "hatch". An empty pick list means "any".
function STATE.eggMatches(prefix, name, rarity, biome, variant, mutation)
	local rarities, eggs, biomes = STATE[prefix .. "Rarities"], STATE[prefix .. "Eggs"], STATE[prefix .. "Biomes"]
	if type(rarities) == "table" and #rarities > 0 and not STATE.listHas(rarities, rarity) then
		return false
	end
	if type(eggs) == "table" and #eggs > 0 and not STATE.listHas(eggs, name) then
		return false
	end
	if biome and type(biomes) == "table" and #biomes > 0 and not STATE.listHas(biomes, biome) then
		return false
	end
	if prefix == "farm" and STATE.farmSpecialOnly == true then
		local special = (variant ~= nil and variant ~= "" and variant ~= "Normal") or (mutation ~= nil and mutation ~= "")
		if not special then
			return false
		end
	end
	return true
end

-- The highest biome this account's stamina can climb to, as a height. Unknown means no limit.
function STATE.reachHeight()
	local level = tonumber(DataController:GetValue("StaminaLevel")) or 0
	local ok, zone = pcall(STATE.staminaCfg.GetReachableBiome, level)
	local entry = ok and type(zone) == "string" and STATE.zoneCfg[zone]
	return type(entry) == "table" and tonumber(entry.Height) or math.huge
end

function STATE.biomeHeight(biome)
	local entry = STATE.zoneCfg[biome]
	return type(entry) == "table" and tonumber(entry.Height) or nil
end

local function shortNumber(value)
	value = tonumber(value) or 0
	local units = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }
	local index = 1
	while math.abs(value) >= 1000 and index < #units do
		value /= 1000
		index += 1
	end
	return (index == 1 and tostring(math.floor(value)) or string.format("%.2f", value)) .. units[index]
end
STATE.shortNumber = shortNumber

local function waitFor(predicate, seconds)
	local deadline = os.clock() + seconds
	repeat
		local ok, value = pcall(predicate)
		if ok and value then
			return value
		end
		task.wait(0.1)
	until os.clock() >= deadline or not running()
	return nil
end

-- Values. Animals use the game's earning curve; eggs use the animal they hatch into.
local function itemFields(item)
	local custom = type(item.CustomData) == "table" and item.CustomData or {}
	return tonumber(custom.AssetScale) or 1, custom.Variant or item.Variant or "Normal", custom.Mutation or item.Mutation
end

local function itemIncome(item)
	if type(item) ~= "table" then
		return 0
	end
	if item.Handler == "Egg" then
		local ok, quote = pcall(sellConfig.GetQuote, item, 0, 1)
		local base = 1
		pcall(function()
			base = rebirthConfig.ForSource(0, "AnimalIncome")
		end)
		return ok and quote and quote.Income / (base ~= 0 and base or 1) or 0
	end
	local scale, variant, mutation = itemFields(item)
	local ok, income = pcall(earningCurve.GetCashPerSecond, item.Name, scale, variant, mutation)
	return ok and tonumber(income) or 0
end

local function teamSnapshot()
	local inventory = DataController:GetValue("Inventory") or {}
	local equipped = DataController:GetValue("EquippedAnimals") or {}
	local maxAnimals = tonumber(DataController:GetValue("MaxAnimals")) or 0
	local count, weakest = 0, nil
	for ref, active in pairs(equipped) do
		local item = inventory[ref]
		if active ~= false and type(item) == "table" and item.Handler == "Animal" then
			count += 1
			local income = itemIncome(item)
			if not weakest or income < weakest.income then
				weakest = { ref = ref, name = item.Name, income = income }
			end
		end
	end
	return inventory, equipped, count, maxAnimals, weakest
end
STATE.teamSnapshot = teamSnapshot

function STATE.equipBestNow()
	for _ = 1, 4 do
		local ok, response = pcall(function()
			return equipRemote:InvokeServer("EquipBest")
		end)
		if ok and (type(response) ~= "table" or response.Status ~= false) then
			return true
		end
		task.wait(2)
	end
	return false
end

-- Guards can't stun you while the farm is carrying an egg home.
local farmMode = "idle"
local originalCapture = GuardController.requestCapture
GuardController.requestCapture = function(self, ...)
	if
		STATE.guardSafe == true
		and STATE.eggFarm == true
		and (farmMode == "moving-to-egg" or farmMode == "delivering" or farmMode == "climbing" or LocalPlayer:GetAttribute("CarryingEgg") ~= nil)
	then
		stats.guardBlocks += 1
		return nil
	end
	return originalCapture(self, ...)
end
hubCleanup(function()
	GuardController.requestCapture = originalCapture
end)

-- Auto Hatch runs the game's own auto hatch, without its gamepass gate.
local originalHatchEnabled = AutoHatchController.IsEnabled
AutoHatchController.IsEnabled = function(...)
	if STATE.autoHatch == true then
		return true
	end
	return originalHatchEnabled(...)
end
hubCleanup(function()
	AutoHatchController.IsEnabled = originalHatchEnabled
end)

-- Hatch picks: the game's auto hatch asks nextReadyEgg which placed egg to hatch next, so only
-- hand it eggs that match the picks. Placed egg ids start with the egg's name.
STATE.originalNextReadyEgg = AutoHatchController.nextReadyEgg
AutoHatchController.nextReadyEgg = function(self, ...)
	if STATE.autoHatch ~= true or STATE.hatchPickMode ~= "My picks" then
		return STATE.originalNextReadyEgg(self, ...)
	end
	local placed = DataController:GetValue("PlacedEggs")
	if typeof(placed) ~= "table" then
		return nil
	end
	local now = os.clock()
	local pending = self.EggHatchController and self.EggHatchController.Pending or {}
	for ref, data in pairs(placed) do
		local tried = type(self.Tried) == "table" and self.Tried[ref]
		if typeof(data) == "table" and data.CanHatch and not pending[ref] and (not tried or now - tried >= 5) then
			local name = string.split(tostring(ref), "_")[1]
			if STATE.eggMatches("hatch", name, STATE.eggRarity(name), nil, data.Variant, data.Mutation) then
				return ref
			end
		end
	end
	return nil
end
hubCleanup(function()
	AutoHatchController.nextReadyEgg = STATE.originalNextReadyEgg
end)

-- Egg farm and treadmill.
-- The server only lets you teleport up to the highest point you have climbed in this server, and
-- refuses the pickup above it. So when an egg worth taking is higher than that, the farm walks to
-- the climbing wall and climbs to the top once; after that every biome on the tower is reachable.
-- Anything that still pulls you out (the Halloween dimension has its own ladder) is skipped for a while.
local goHome
local failedEggs = {}
local biomeFailures = {}
local blockedBiomes = {}
local BIOME_BLOCK_SECONDS = 600
local CLIMB_TOP = 12170
local TOP_ISLAND = Vector3.new(2163, 0, -751)
local WALL_FOOT = Vector3.new(2213, 0, -754.5)
local CLIMB_RETRY_SECONDS = 300
local climbFailedUntil = 0
-- The Halloween dimension has its own ladder, and the server keeps a separate height for it.
local HALLOWEEN_FOOT = Vector3.new(2213, 0, 4553)
local HALLOWEEN_TOP = 3745
local HALLOWEEN_ISLAND = Vector3.new(2097, 0, 4551)
local function inHalloween(position)
	return position.Z > 3000
end
genv.ZinoosClimbHeights = type(genv.ZinoosClimbHeights) == "table" and genv.ZinoosClimbHeights or {}
local function heightKey(halloween)
	return game.JobId .. (halloween and ":halloween" or "")
end
local function climbedTo(halloween)
	return tonumber(genv.ZinoosClimbHeights[heightKey(halloween)]) or 0
end
local function noteClimbed(y, halloween)
	if y > climbedTo(halloween) then
		genv.ZinoosClimbHeights[heightKey(halloween)] = y
	end
end
STATE.climbedTo = climbedTo

-- Counts climbs you do yourself too.
do
	local lastCheck = 0
	trackConnection(RunService.Heartbeat:Connect(function()
		if os.clock() - lastCheck < 0.25 then
			return
		end
		lastCheck = os.clock()
		local character = LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if hum and root and hum:GetState() == Enum.HumanoidStateType.Climbing then
			noteClimbed(root.Position.Y, inHalloween(root.Position))
		end
	end))
end

local function onTower(position)
	return math.abs(position.Z - WALL_FOOT.Z) < 400 and math.abs(position.X - WALL_FOOT.X) < 400
end

local function characterParts()
	local character = LocalPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root then
		return nil
	end
	return character, hum, root
end

local function pivotTo(cframe)
	local character, hum, root = characterParts()
	if not character then
		return false
	end
	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	hum.Jump = false
	character:PivotTo(cframe)
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

-- The treadmill switches itself back on 1.25s after you step off if you are still standing on it,
-- anchoring you in place, so hold its activation off while the farm is away from it.
local treadmillHold = false
trackConnection(RunService.Heartbeat:Connect(function()
	if treadmillHold then
		TreadmillController.DisableActivation = true
	end
end))
hubCleanup(function()
	treadmillHold = false
	TreadmillController.DisableActivation = false
end)

local function stopTraining()
	treadmillHold = true
	if TreadmillController.OnTreadmill then
		pcall(TreadmillController.DeactivateTreadmill, TreadmillController)
		waitFor(function()
			return not TreadmillController.OnTreadmill
		end, 2)
		task.wait(0.3)
	end
end
STATE.stopTraining = stopTraining

local function startTraining()
	if LocalPlayer:GetAttribute("CarryingEgg") ~= nil then
		return false
	end
	treadmillHold = false
	TreadmillController.DisableActivation = false
	if TreadmillController.OnTreadmill then
		return true
	end
	local base = BaseController:GetBase()
	local container = base and base:FindFirstChild("Treadmill")
	local treadmill = container and container:FindFirstChildOfClass("Model")
	local character = LocalPlayer.Character
	if not treadmill or not character then
		return false
	end
	pivotTo(treadmill:GetPivot() * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0, character:GetExtentsSize().Y / 2 + 1.25, 0))
	return waitFor(function()
		return TreadmillController.OnTreadmill
	end, 2) == true
end

-- The game only removes a bonus bubble when it is clicked, so take claimed ones off the screen
-- the way its own treadmill UI does: unlink the button, then destroy the frame named after the id.
local ButtonsController = controller("ButtonsController")
local function removeBonusBubble(bonusId)
	local general = LocalPlayer:FindFirstChildOfClass("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("General")
	local bubble = general and general:FindFirstChild(tostring(bonusId))
	if bubble and bubble.Name ~= "BonusClick" then
		local button = bubble:FindFirstChildOfClass("ImageButton")
		if button and ButtonsController then
			pcall(ButtonsController.Unlink, ButtonsController, button)
		end
		bubble:Destroy()
	end
end

trackConnection(TreadmillController.Signals.ShowMultiplierButton:Connect(function(bonusId, sessionId)
	if STATE.treadmill == true and running() and TreadmillController:IsCurrentTreadmillSession(sessionId) then
		if pcall(TreadmillController.ClaimMultiplier, TreadmillController, bonusId) then
			stats.bonuses += 1
			task.delay(0.2, removeBonusBubble, bonusId)
		end
	end
end))

local function safeWindow()
	local now = Workspace:GetServerTimeNow()
	return not dayCycle.IsNight(now) and dayCycle.GetPhaseTimeLeft(now) > 8
end

local function eggIncome(egg)
	local ok, income = pcall(
		earningCurve.GetCashPerSecond,
		egg:GetAttribute("EggName") or egg.Name,
		tonumber(egg:GetAttribute("AssetScale")) or 1,
		egg:GetAttribute("Variant") or "Normal",
		egg:GetAttribute("Mutation")
	)
	return ok and tonumber(income) or 0
end

local function bestWorldEgg()
	if not safeWindow() then
		return nil, "night"
	end
	local spawned = Workspace:FindFirstChild("SpawnedEggs")
	if not spawned then
		return nil, "no eggs spawned"
	end
	local _, _, count, maxAnimals, weakest = teamSnapshot()
	local picks = STATE.farmPickMode == "My picks"
	-- In My picks mode the player chose what they want, so Only Upgrades doesn't apply.
	local floor = (not picks and STATE.onlyUpgrades == true and weakest and count >= maxAnimals) and weakest.income or 0
	floor = math.max(floor, STATE.MIN_INCOME[STATE.farmMinIncome] or 0)
	local reach = STATE.reachHeight()
	local now, best, skipped = os.clock(), nil, nil
	for _, biome in ipairs(spawned:GetChildren()) do
		local blocked = (blockedBiomes[biome.Name] or 0) > now
		local biomeHeight = STATE.biomeHeight(biome.Name)
		-- Skip biomes higher than this account's stamina can climb.
		local outOfReach = biomeHeight ~= nil and biomeHeight > reach
		for _, egg in ipairs((blocked or outOfReach) and {} or biome:GetChildren()) do
			local id = egg:GetAttribute("EggId")
			if id and egg:IsA("Model") and (failedEggs[tostring(id)] or 0) <= now then
				local income = eggIncome(egg)
				local part = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)
				local needsClimb = part ~= nil
					and onTower(part.Position)
					and climbedTo() < CLIMB_TOP - 10
					and part.Position.Y > climbedTo() - 3
				local climbable = not needsClimb or climbFailedUntil <= now
				local wanted = not picks
					or STATE.eggMatches(
						"farm",
						egg:GetAttribute("EggName") or egg.Name,
						egg:GetAttribute("Rarity") or STATE.eggRarity(egg:GetAttribute("EggName") or egg.Name),
						biome.Name,
						egg:GetAttribute("Variant"),
						egg:GetAttribute("Mutation")
					)
				if climbable and wanted and income > floor and (not best or income > best.income) then
					local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt and prompt.Enabled and part then
						best = {
							egg = egg,
							prompt = prompt,
							part = part,
							id = tostring(id),
							income = income,
							name = egg:GetAttribute("EggName") or egg.Name,
							biome = biome.Name,
							needsClimb = needsClimb,
						}
					end
				end
			end
		end
		if blocked and not skipped then
			for _, egg in ipairs(biome:GetChildren()) do
				if egg:GetAttribute("EggId") and eggIncome(egg) > floor then
					skipped = biome.Name
					break
				end
			end
		end
	end
	if best then
		return best
	end
	if skipped then
		return nil, "best egg is in " .. skipped .. ", which the game won't let you teleport to"
	end
	return nil, picks and "no egg matches your picks" or "no egg beats your team"
end

local function deliverEgg()
	local base = BaseController:GetBase()
	local off = base and base:FindFirstChild("TreadmillOffCFrame")
	local character = LocalPlayer.Character
	if not off or not character then
		return false
	end
	local pivot = off:IsA("Model") and off:GetPivot() or off.CFrame
	local height = character:GetExtentsSize().Y / 2 + 1
	local deadline = os.clock() + 9
	while LocalPlayer:GetAttribute("CarryingEgg") ~= nil and os.clock() < deadline and running() do
		pivotTo(pivot * CFrame.new(0, height, 0))
		if ZoneController.Zone == "Lobby" and not FallController.IsFalling then
			pcall(EggCarryController.tryClaimEgg, EggCarryController)
		end
		task.wait(0.15)
	end
	return LocalPlayer:GetAttribute("CarryingEgg") == nil
end

local function collectEgg(target)
	stopTraining()
	if not target.egg.Parent or not target.prompt.Enabled then
		return false
	end
	farmMode = "moving-to-egg"
	STATE.status = "Grabbing " .. target.name .. " in " .. target.biome
	local character = LocalPlayer.Character
	if not character then
		return false
	end
	local standOn = CFrame.new(target.part.Position + Vector3.new(0, character:GetExtentsSize().Y / 2 + 1, 0))
	pivotTo(standOn)
	task.wait(0.35)
	for attempt = 1, 4 do
		if not target.egg.Parent then
			break
		end
		local _, _, root = characterParts()
		if attempt > 1 and root and (root.Position - target.part.Position).Magnitude > 200 then
			break
		end
		if attempt > 1 and root and (root.Position - target.part.Position).Magnitude > 8 then
			pivotTo(standOn)
			task.wait(0.35)
		end
		fireproximityprompt(target.prompt)
		if waitFor(function()
			return LocalPlayer:GetAttribute("CarryingEgg") ~= nil
		end, 2.5) then
			break
		end
	end
	if LocalPlayer:GetAttribute("CarryingEgg") == nil then
		failedEggs[target.id] = os.clock() + 60
		biomeFailures[target.biome] = (biomeFailures[target.biome] or 0) + 1
		local _, _, root = characterParts()
		if root and (root.Position - target.part.Position).Magnitude > 200 and onTower(target.part.Position) and biomeFailures[target.biome] == 1 then
			genv.ZinoosClimbHeights[game.JobId] = 0
			noteActivity("The game pulled you back from " .. target.biome .. ", so the farm will climb again")
		elseif biomeFailures[target.biome] >= 3 then
			biomeFailures[target.biome] = 0
			blockedBiomes[target.biome] = os.clock() + BIOME_BLOCK_SECONDS
			noteActivity("Couldn't pick up eggs in " .. target.biome .. ", skipping it for 10 minutes")
		end
		goHome()
		return false
	end
	biomeFailures[target.biome] = 0
	farmMode = "delivering"
	STATE.status = "Bringing " .. target.name .. " home"
	if not deliverEgg() then
		failedEggs[target.id] = os.clock() + 10
		return false
	end
	stats.eggs += 1
	noteActivity(string.format("Took %s (%s/s) from %s", target.name, shortNumber(target.income), target.biome))
	return true
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function goHome()
	local base = BaseController:GetBase()
	local off = base and base:FindFirstChild("TreadmillOffCFrame")
	local character, hum = characterParts()
	if off and character then
		hum:ChangeState(Enum.HumanoidStateType.Running)
		pivotTo((off:IsA("Model") and off:GetPivot() or off.CFrame) * CFrame.new(0, character:GetExtentsSize().Y / 2 + 1, 0))
	end
end

-- Walks to the foot of a ladder and climbs it like a player, walking into the truss.
-- keepGoing is the STATE key that must stay on for the climb to continue.
local function climbWall(targetY, foot, island, keepGoing)
	foot = foot or WALL_FOOT
	island = island or TOP_ISLAND
	keepGoing = keepGoing or "eggFarm"
	local halloween = inHalloween(foot)
	farmMode = "climbing"
	stopTraining()
	local character, hum, root = characterParts()
	if not character then
		return false
	end
	if root.Position.Y < 200 or flatDistance(root.Position, foot) > 6 then
		STATE.status = "Walking to the climbing wall"
		local goal = Vector3.new(foot.X, root.Position.Y, foot.Z)
		local deadline = os.clock() + 20
		while running() and os.clock() < deadline and flatDistance(root.Position, goal) > 2.5 do
			hum:MoveTo(goal)
			task.wait(0.25)
		end
		if flatDistance(root.Position, goal) > 4 then
			return false
		end
		root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(-1, 0, 0))
	end
	-- Night sends everyone on the wall back to the lobby, and one day is too short to climb the whole
	-- tower. The server still lets you return to the highest point you reached in this server, so carry
	-- on from there instead of starting at the bottom again.
	local resumeY = math.min(climbedTo(halloween), targetY) - 6
	if resumeY > root.Position.Y + 50 then
		STATE.status = string.format("Going back to %s on the wall", shortNumber(resumeY))
		pivotTo(CFrame.lookAt(Vector3.new(foot.X - 1, resumeY, foot.Z - 0.5), Vector3.new(foot.X - 2, resumeY, foot.Z - 0.5)))
		task.wait(0.4)
	end
	local lastY, movedAt = root.Position.Y, os.clock()
	-- Stop just before night instead of being thrown back mid-climb.
	local deadline = os.clock() + 600
	local nowServer = Workspace:GetServerTimeNow()
	if not dayCycle.IsNight(nowServer) then
		deadline = math.min(deadline, os.clock() + dayCycle.GetPhaseTimeLeft(nowServer) - 1)
	end
	STATE.climbEndedByNight = false
	while running() and STATE[keepGoing] == true and root.Parent and root.Position.Y < targetY and os.clock() < deadline do
		hum:MoveTo(Vector3.new(foot.X - 13, root.Position.Y, foot.Z))
		STATE.status = string.format("Climbing the wall (%s / %s)", shortNumber(root.Position.Y), shortNumber(targetY))
		task.wait(0.2)
		if root.Position.Y > lastY + 5 then
			lastY, movedAt = root.Position.Y, os.clock()
			noteClimbed(lastY, halloween)
		elseif os.clock() - movedAt > 6 then
			break
		end
	end
	noteClimbed(root.Position.Y, halloween)
	if root.Position.Y < targetY - 5 then
		local serverNow = Workspace:GetServerTimeNow()
		STATE.climbEndedByNight = os.clock() >= deadline - 0.5 or dayCycle.IsNight(serverNow) or dayCycle.GetPhaseTimeLeft(serverNow) < 3
		return false
	end
	-- The server only counts a biome once you stand in it, so climb over the top onto the island.
	STATE.status = "Stepping onto the top island"
	local zoneBefore = ZoneController.Zone
	local stepDeadline = os.clock() + 8
	while running() and os.clock() < stepDeadline do
		hum:MoveTo(Vector3.new(island.X, root.Position.Y, island.Z))
		task.wait(0.25)
		if hum:GetState() ~= Enum.HumanoidStateType.Climbing and flatDistance(root.Position, foot) > 12 then
			break
		end
	end
	task.wait(1)
	noteClimbed(root.Position.Y, halloween)
	noteActivity(string.format("Reached the top island (%s, was %s)", tostring(ZoneController.Zone), tostring(zoneBefore)))
	return true
end

-- Halloween event: kill mini monsters with the Bat for candy, then spend it on Halloween eggs.
local MiniMonsterService = timed(function()
	return knit.GetService("MiniMonsterService")
end, 5)
local HalloweenShopService = timed(function()
	return knit.GetService("HalloweenShopService")
end, 5)
local robuxEggConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.robuxEggConfig)
local portalConfig = require(ReplicatedStorage.src.GameConfiguration.Gameplay.portalConfig)
local PORTAL_TRIGGER = Vector3.new(2216, 0, -790)
-- Monster damage is dealt by the server from distance, so it can't be blocked from the client.
-- God Mode keeps you alive instead: it breaks off a fight and heals at the dimension's spawn,
-- where no monsters roam, before your health gets low.
local SAFE_SPOT = Vector3.new(2327, 80, 4552)
local RETREAT_BELOW = 0.5
local BAIL_BELOW = 0.35
local HEALED_AT = 0.95
local pulledBackFromMonster = 0
local candyDrops = {}
local candyFailedUntil = 0
stats.kills = 0
stats.candyEggs = 0
STATE.candyStatus = "Off"
if MiniMonsterService then
	trackConnection(MiniMonsterService.CandyDropped:Connect(function(list)
		if type(list) == "table" then
			for _, drop in pairs(list) do
				if type(drop) == "table" and drop.Id and typeof(drop.To) == "Vector3" then
					candyDrops[tostring(drop.Id)] = drop
				end
			end
		end
	end))
	trackConnection(MiniMonsterService.CandyCollected:Connect(function(list)
		if type(list) == "table" then
			for _, id in pairs(list) do
				candyDrops[tostring(id)] = nil
			end
		end
	end))
end

local function candyFarmBlocked()
	if not MiniMonsterService then
		return "the game's monster service is missing"
	end
	if ReplicatedStorage:GetAttribute(portalConfig.OpenAttribute) ~= true then
		return "the Halloween portal is closed"
	end
	if (tonumber(DataController:GetValue("Speed")) or 0) < (portalConfig.UnlockSpeed or 0) then
		return "you need " .. shortNumber(portalConfig.UnlockSpeed) .. " speed for the portal"
	end
	if candyFailedUntil > os.clock() then
		return "retrying the Halloween trip soon"
	end
	return nil
end

local function enterHalloween()
	local character, hum, root = characterParts()
	if not character then
		return false
	end
	if inHalloween(root.Position) then
		return true
	end
	stopTraining()
	STATE.status = "Walking into the Halloween portal"
	local deadline = os.clock() + 15
	while running() and os.clock() < deadline and not inHalloween(root.Position) do
		hum:MoveTo(Vector3.new(PORTAL_TRIGGER.X, root.Position.Y, PORTAL_TRIGGER.Z))
		task.wait(0.25)
	end
	task.wait(1.5)
	return inHalloween(root.Position)
end

local function nearestMonster(root)
	local folder = Workspace:FindFirstChild("HalloweenDimension") and Workspace.HalloweenDimension:FindFirstChild("ActiveMiniMonsters")
	local best, bestDistance = nil, math.huge
	for _, monster in ipairs(folder and folder:GetChildren() or {}) do
		if
			monster:IsA("Model")
			and not monster:GetAttribute("Boss")
			and not monster:GetAttribute("Minion")
			and not monster:GetAttribute("Dead")
			and not monster:GetAttribute("Dying")
		then
			local position = monster:GetPivot().Position
			if position.Y <= climbedTo(true) + 5 then
				local distance = (position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = monster, distance
				end
			end
		end
	end
	return best
end

local function collectCandy(character)
	for id, drop in pairs(candyDrops) do
		if (tonumber(drop.ExpiresAt) or math.huge) > Workspace:GetServerTimeNow() then
			pivotTo(CFrame.new(drop.To + Vector3.new(0, character:GetExtentsSize().Y / 2 + 0.5, 0)))
			waitFor(function()
				return candyDrops[id] == nil
			end, 1.5)
		end
		candyDrops[id] = nil
	end
end

local function stepCandy()
	local blocked = candyFarmBlocked()
	if blocked then
		STATE.candyStatus = "Waiting: " .. blocked
		return nil
	end
	if not enterHalloween() then
		candyFailedUntil = os.clock() + CLIMB_RETRY_SECONDS
		noteActivity("Couldn't get through the Halloween portal, trying again in 5 minutes")
		goHome()
		return 1
	end
	if climbedTo(true) < HALLOWEEN_TOP - 10 then
		noteActivity("Climbing the Halloween ladder to reach every monster island")
		if not climbWall(HALLOWEEN_TOP, HALLOWEEN_FOOT, HALLOWEEN_ISLAND, "candyFarm") then
			candyFailedUntil = os.clock() + CLIMB_RETRY_SECONDS
			noteActivity("The Halloween climb stalled, trying again in 5 minutes")
			goHome()
			return 1
		end
	end
	local character, hum, root = characterParts()
	if not character then
		return 1
	end
	if STATE.godMode == true and hum.Health < hum.MaxHealth * RETREAT_BELOW then
		hum:UnequipTools()
		farmMode = "healing"
		pivotTo(CFrame.new(SAFE_SPOT))
		local deadline = os.clock() + 75
		while running() and STATE.candyFarm == true and hum.Parent and hum.Health > 0 and hum.Health < hum.MaxHealth * HEALED_AT and os.clock() < deadline do
			STATE.status = string.format("God Mode: healing at spawn (%d%%)", math.floor(hum.Health / hum.MaxHealth * 100))
			task.wait(0.5)
		end
		stats.heals = (stats.heals or 0) + 1
		return 0.2
	end
	local monster = nearestMonster(root)
	if not monster then
		STATE.candyStatus = "No monsters up right now"
		STATE.status = "Waiting for Halloween monsters"
		return 2
	end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local bat = character:FindFirstChild("Bat") or (backpack and backpack:FindFirstChild("Bat"))
	if not bat then
		STATE.candyStatus = "No Bat in your backpack"
		return nil
	end
	if bat.Parent ~= character then
		hum:EquipTool(bat)
		task.wait(0.2)
	end
	farmMode = "candy"
	STATE.status = "Fighting " .. tostring(monster:GetAttribute("MonsterName") or monster.Name) .. " on " .. tostring(monster:GetAttribute("Island") or "?")
	local deadline = os.clock() + 12
	while running() and STATE.candyFarm == true and monster.Parent and not monster:GetAttribute("Dead") and not monster:GetAttribute("Dying") and os.clock() < deadline do
		if STATE.godMode == true and hum.Health < hum.MaxHealth * BAIL_BELOW then
			break
		end
		local position = monster:GetPivot().Position
		if (root.Position - position).Magnitude > 5 then
			local away = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
			pivotTo(CFrame.lookAt(position + away * 3.5 + Vector3.new(0, 1, 0), position))
			task.wait(0.3)
			-- After a respawn the server can forget the climb and put you back; climb again then.
			if (root.Position - position).Magnitude > 60 then
				pulledBackFromMonster += 1
				if pulledBackFromMonster >= 3 then
					pulledBackFromMonster = 0
					genv.ZinoosClimbHeights[heightKey(true)] = 0
					noteActivity("The game pulled you back from the monster islands, climbing again")
					return 0.5
				end
			else
				pulledBackFromMonster = 0
			end
		end
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(position.X, root.Position.Y, position.Z))
		bat:Activate()
		task.wait(0.4)
	end
	if not monster.Parent or monster:GetAttribute("Dead") or monster:GetAttribute("Dying") then
		stats.kills += 1
	end
	task.wait(0.8)
	collectCandy(character)
	STATE.candyStatus = string.format("%s candy, %d kills", shortNumber(DataController:GetValue("Candy")), stats.kills)
	return 0.2
end

function STATE.stepCandyShop()
	if STATE.buyCandyEgg ~= true or not HalloweenShopService then
		return
	end
	local egg = robuxEggConfig.Eggs["Halloween Dimension Egg"]
	local price = egg and tonumber(egg.CandyPrice) or math.huge
	if (tonumber(DataController:GetValue("Candy")) or 0) < price then
		return
	end
	local ok, success, message = pcall(function()
		local result, extra = HalloweenShopService:BuyCandyEgg()
		if type(result) == "table" and type(result.await) == "function" then
			local _, value, more = result:await()
			return value, more
		end
		return result, extra
	end)
	if ok and success then
		stats.candyEggs += 1
		noteActivity("Bought a Halloween egg for " .. shortNumber(price) .. " candy")
	elseif ok and type(message) == "string" then
		noteActivity("Halloween egg: " .. message)
	end
end

-- Calling into the game's own modules drops this thread's identity; get it back before the
-- client helpers below connect to CoreGui-level signals.
pcall(setthreadidentity, 8)

local function stepFarm()
	if STATE.candyFarm ~= true then
		STATE.candyStatus = "Off"
		local character, hum, root = characterParts()
		if character and character:FindFirstChild("Bat") and farmMode == "candy" then
			hum:UnequipTools()
		end
		if root and inHalloween(root.Position) and LocalPlayer:GetAttribute("CarryingEgg") == nil then
			goHome()
		end
	end
	if STATE.eggFarm ~= true and STATE.treadmill ~= true and STATE.candyFarm ~= true then
		farmMode = "idle"
		STATE.status = "Idle"
		stopTraining()
		return 1
	end
	if STATE.eggFarm == true and LocalPlayer:GetAttribute("CarryingEgg") ~= nil then
		stopTraining()
		farmMode = "delivering"
		STATE.status = "Bringing an egg home"
		deliverEgg()
		return 0.1
	end
	local target, why = nil, "egg farm off"
	if STATE.eggFarm == true then
		target, why = bestWorldEgg()
	end
	if target then
		if target.needsClimb then
			-- Climb only as high as this account can reach. At max stamina that is the top, as before.
			local reachTop = STATE.reachHeight()
			local climbTarget = reachTop >= CLIMB_TOP - 20 and CLIMB_TOP or math.min(CLIMB_TOP, math.max(target.part.Position.Y + 8, reachTop))
			noteActivity(string.format("%s (%s/s) is in %s, climbing to %s", target.name, shortNumber(target.income), target.biome, shortNumber(climbTarget)))
			if not climbWall(climbTarget) then
				if STATE.climbEndedByNight then
					-- Progress is kept, so carry on from the same height once night is over.
					climbFailedUntil = os.clock() + 12
					noteActivity(string.format("Night stopped the climb at %s, carrying on after it", shortNumber(climbedTo())))
				else
					climbFailedUntil = os.clock() + CLIMB_RETRY_SECONDS
					noteActivity("The climb stalled, trying again in 5 minutes")
				end
				goHome()
				return 1
			end
			noteActivity(climbTarget >= CLIMB_TOP and "Climbed to the top, every biome is reachable now" or "Climbed high enough for " .. target.biome)
		end
		local character, hum = characterParts()
		if character and character:FindFirstChild("Bat") then
			hum:UnequipTools()
		end
		collectEgg(target)
		return 0.3
	end
	if STATE.candyFarm == true then
		local pause = stepCandy()
		if pause then
			return pause
		end
	end
	if STATE.treadmill == true then
		farmMode = "training"
		STATE.status = "Training speed (" .. tostring(why) .. ")"
		startTraining()
		return 0.5
	end
	farmMode = "idle"
	STATE.status = "Waiting (" .. tostring(why) .. ")"
	stopTraining()
	return 1
end
hubCleanup(function()
	pcall(stopTraining)
end)

-- Placing: only eggs that beat your weakest animal, or that fill an empty team slot.
local placeCooldown = {}
STATE.placeStatus = "Starting"

local function freeSpot()
	local base = BaseController:GetBase()
	local fences = base and base:FindFirstChild("Fences")
	local placed = base and base:FindFirstChild("PlacedEggs")
	local ground = Workspace:FindFirstChild("Ground")
	if not fences or not placed or not ground then
		return nil
	end
	local plot, size = fences:GetBoundingBox()
	local groundY = ground.Position.Y + ground.Size.Y / 2
	for x = -size.X / 2 + 6, size.X / 2 - 6, 6 do
		for z = -size.Z / 2 + 6, size.Z / 2 - 6, 6 do
			local world = plot:PointToWorldSpace(Vector3.new(x, 0, z))
			local spot = Vector3.new(world.X, groundY, world.Z)
			local free = true
			for _, egg in ipairs(placed:GetChildren()) do
				local gap = egg:GetPivot().Position - spot
				if Vector3.new(gap.X, 0, gap.Z).Magnitude < 6 then
					free = false
					break
				end
			end
			if free then
				return CFrame.new(spot)
			end
		end
	end
	return nil
end

local function stepPlace()
	if STATE.autoPlace ~= true then
		STATE.placeStatus = "Off"
		return
	end
	local inventory, _, count, maxAnimals, weakest = teamSnapshot()
	local placedCount = 0
	for _ in pairs(DataController:GetValue("PlacedEggs") or {}) do
		placedCount += 1
	end
	local openSlots = math.max(0, maxAnimals - count - placedCount)
	local picks = STATE.placePickMode == "My picks"
	local best
	for ref, item in pairs(inventory) do
		if type(item) == "table" and item.Handler == "Egg" and (placeCooldown[ref] or 0) <= os.clock() then
			local income = itemIncome(item)
			local beatsTeam = openSlots > 0 or (weakest and income > weakest.income)
			local wanted = beatsTeam
			if picks then
				local _, variant, mutation = itemFields(item)
				wanted = STATE.eggMatches("place", item.Name, STATE.eggRarity(item.Name), nil, variant, mutation)
					and (STATE.placeBeatsOnly ~= true or beatsTeam)
			end
			if wanted and (not best or income > best.income) then
				best = { ref = ref, income = income, name = item.Name }
			end
		end
	end
	if not best then
		STATE.placeStatus = picks and "No egg matches your picks" or "No egg beats your team"
		return
	end
	local spot = freeSpot()
	if not spot then
		STATE.placeStatus = "No free space on your base"
		return
	end
	local ok, response = pcall(function()
		return placeRemote:InvokeServer(best.ref, spot)
	end)
	local accepted = ok and (type(response) ~= "table" or response.Status ~= false)
	if accepted and waitFor(function()
		local placed = DataController:GetValue("PlacedEggs") or {}
		return placed[best.ref] ~= nil or (DataController:GetValue("Inventory") or {})[best.ref] == nil
	end, 5) then
		stats.placed += 1
		STATE.placeStatus = "Placed " .. best.name
		noteActivity(string.format("Placed %s (%s/s)", best.name, shortNumber(best.income)))
	else
		placeCooldown[best.ref] = os.clock() + 15
		STATE.placeStatus = "Placing rejected: " .. tostring(type(response) == "table" and (response.Reason or response.Message) or response)
	end
end

local equipQueued = false
trackConnection(DataController:GetValueChangedSignal("Inventory"):Connect(function()
	if STATE.equipBest ~= true or equipQueued then
		return
	end
	equipQueued = true
	task.delay(1.5, function()
		equipQueued = false
		if running() and STATE.equipBest == true then
			STATE.equipBestNow()
		end
	end)
end))

-- Rebirth once every requirement is met; base upgrade when affordable.
local lastRebirthTry, lastRebirthFor = 0, nil
STATE.rebirthStatus = "Starting"
local function stepRebirth()
	if STATE.autoRebirth ~= true then
		STATE.rebirthStatus = "Off"
		return
	end
	local rebirths = tonumber(DataController:GetValue("Rebirths")) or 0
	if rebirthConfig.MaxRebirths > 0 and rebirths >= rebirthConfig.MaxRebirths then
		STATE.rebirthStatus = "Max rebirths"
		return
	end
	for resource, required in pairs(rebirthConfig.GetRequirements(rebirths)) do
		local current = tonumber(DataController:GetValue(resource)) or 0
		if type(required) ~= "number" or current < required then
			STATE.rebirthStatus = string.format("Needs %s %s / %s", tostring(resource), shortNumber(current), shortNumber(required))
			return
		end
	end
	if RebirthController.Pending then
		STATE.rebirthStatus = "Rebirthing"
		return
	end
	if lastRebirthFor == rebirths and os.clock() - lastRebirthTry < 60 then
		STATE.rebirthStatus = "Ready, retrying soon"
		return
	end
	lastRebirthFor, lastRebirthTry = rebirths, os.clock()
	STATE.rebirthStatus = "Rebirthing"
	if pcall(RebirthController.Request, RebirthController, false) then
		stats.rebirths += 1
		noteActivity("Rebirth " .. tostring(rebirths + 1))
	end
end

-- Stamina decides how high you can climb, so new accounts need it to reach better biomes.
STATE.staminaRetryAt = 0
function STATE.stepStamina()
	if STATE.autoStamina ~= true or os.clock() < STATE.staminaRetryAt then
		return
	end
	local controllerNow = STATE.staminaController
	if not controllerNow or controllerNow.Pending then
		return
	end
	local level = tonumber(DataController:GetValue("StaminaLevel")) or 0
	local ok, price = pcall(STATE.staminaCfg.GetPrice, level)
	if not ok or type(price) ~= "number" then
		return
	end
	if (tonumber(DataController:GetValue("Cash")) or 0) < price then
		return
	end
	STATE.staminaRetryAt = os.clock() + 10
	if pcall(controllerNow.Purchase, controllerNow) then
		task.delay(3, function()
			local now = tonumber(DataController:GetValue("StaminaLevel")) or 0
			if now > level then
				noteActivity(string.format("Bought stamina level %d (%s)", now, shortNumber(price)))
			end
		end)
	end
end

-- The treadmill level sets how fast Speed trains, which rebirths need.
STATE.treadmillRetryAt = 0
function STATE.stepTreadmillUpgrade()
	if STATE.autoTreadmillUpgrade ~= true or os.clock() < STATE.treadmillRetryAt then
		return
	end
	local ok, level = pcall(TreadmillController.GetLevel, TreadmillController)
	if not ok or type(level) ~= "number" then
		return
	end
	local okCost, cost = pcall(TreadmillController.GetLevelCost, TreadmillController, level + 1)
	if not okCost or type(cost) ~= "number" then
		return
	end
	if (tonumber(DataController:GetValue("Cash")) or 0) < cost then
		return
	end
	STATE.treadmillRetryAt = os.clock() + 10
	if pcall(TreadmillController.UpgradeTreadmill, TreadmillController) then
		task.delay(3, function()
			local okNow, now = pcall(TreadmillController.GetLevel, TreadmillController)
			if okNow and type(now) == "number" and now > level then
				noteActivity(string.format("Upgraded the treadmill to level %d (%s)", now, shortNumber(cost)))
			end
		end)
	end
end

local function stepUpgrade()
	if STATE.autoUpgrade ~= true then
		return
	end
	local level = tonumber(DataController:GetValue("BaseLevel")) or 0
	local nextLevel = baseUpgradeConfig.Levels[level + 1]
	local cash = tonumber(DataController:GetValue("Cash")) or 0
	if nextLevel and cash >= nextLevel.UpgradeCost then
		if pcall(BaseUpgradeController.Upgrade, BaseUpgradeController) then
			noteActivity("Base upgraded to level " .. tostring(level + 1))
		end
		task.wait(3)
	end
end

-- Fusing: three matching animals, only when the result beats your weakest animal.
local SLOT_WAIT = 2.5
STATE.fuseStatus = "Starting"

local function slotValue(slot)
	local fuse = DataController:GetValue("Fuse") or {}
	return fuse.Slots and fuse.Slots[tostring(slot)]
end

local function setSlot(slot, ref)
	for _ = 1, 8 do
		if not running() then
			return false
		end
		local ok, response = FuseService:SetSlot(slot, ref):await()
		if ok and (type(response) ~= "table" or response.Status ~= false) and waitFor(function()
			return slotValue(slot) == ref
		end, 3) then
			return true
		end
		local reason = string.lower(tostring(type(response) == "table" and (response.Reason or response.Message) or response))
		if not string.find(reason, "wait", 1, true) then
			return false
		end
		task.wait(SLOT_WAIT)
	end
	return false
end

local function clearSlots()
	for slot = 3, 1, -1 do
		if slotValue(slot) ~= nil then
			setSlot(slot, nil)
			task.wait(SLOT_WAIT)
		end
	end
end

local function findFuse()
	local inventory, equipped, count, maxAnimals, weakest = teamSnapshot()
	if not weakest or count < maxAnimals then
		return nil, "Team not full yet"
	end
	local cash = tonumber(DataController:GetValue("Cash")) or 0
	local groups = {}
	for ref, item in pairs(inventory) do
		if type(item) == "table" and item.Handler == "Animal" and equipped[ref] == nil then
			local scale, variant, mutation = itemFields(item)
			if mutation == nil and fuseConfig.GetNextVariant(variant) ~= nil then
				local key = item.Name .. "\0" .. variant
				groups[key] = groups[key] or {}
				table.insert(groups[key], { ref = ref, scale = scale })
			end
		end
	end
	local best
	for _, group in pairs(groups) do
		if #group >= 3 then
			table.sort(group, function(a, b)
				return a.scale > b.scale
			end)
			local plan = { Slots = { ["1"] = group[1].ref, ["2"] = group[2].ref, ["3"] = group[3].ref } }
			local result = fuseConfig.GetResult(plan, inventory)
			if result and result.CustomData and result.CustomData.Mutation == nil then
				local gain = itemIncome(result) - weakest.income
				local cost = fuseConfig.GetPrice(plan, inventory)
				if gain > 0 and cost <= cash and (not best or gain > best.gain) then
					best = { refs = { group[1].ref, group[2].ref, group[3].ref }, gain = gain, name = result.Name, variant = result.CustomData.Variant }
				end
			end
		end
	end
	return best, best and nil or "Nothing worth fusing"
end

local function collectFuse()
	if waitFor(function()
		return fuseConfig.GetStatus(DataController:GetValue("Fuse") or {}, Workspace:GetServerTimeNow()) == "Ready"
	end, 10) then
		local ok, response = FuseService:Collect():await()
		if ok and (type(response) ~= "table" or response.Status ~= false) then
			stats.fused += 1
			noteActivity("Collected a fused animal")
			STATE.equipBestNow()
			return true
		end
	end
	return false
end

local function stepFuse()
	if STATE.autoFuse ~= true then
		STATE.fuseStatus = "Off"
		return 5
	end
	local fuse = DataController:GetValue("Fuse") or { Slots = {} }
	if fuse.FinishAt then
		local left = math.ceil(fuse.FinishAt - Workspace:GetServerTimeNow())
		if left > 0 then
			STATE.fuseStatus = "Fusing, " .. left .. "s left"
			return math.clamp(left, 1, 5)
		end
		STATE.fuseStatus = "Collecting"
		collectFuse()
		return 2
	end
	if next(fuse.Slots or {}) ~= nil then
		STATE.fuseStatus = "Machine has your own picks in it, leaving it"
		return 15
	end
	local plan, why = findFuse()
	if not plan then
		STATE.fuseStatus = why
		return 30
	end
	STATE.fuseStatus = string.format("Fusing 3 %s into %s", tostring(plan.name), tostring(plan.variant))
	for slot, ref in ipairs(plan.refs) do
		if slot > 1 then
			task.wait(SLOT_WAIT)
		end
		if not setSlot(slot, ref) then
			clearSlots()
			STATE.fuseStatus = "A slot was rejected, trying later"
			return 15
		end
	end
	task.wait(SLOT_WAIT)
	local ok, response = FuseService:Start():await()
	if ok and (type(response) ~= "table" or response.Status ~= false) then
		noteActivity(string.format("Started fusing %s into %s", tostring(plan.name), tostring(plan.variant)))
		return 2
	end
	clearSlots()
	STATE.fuseStatus = "Start rejected: " .. tostring(type(response) == "table" and (response.Reason or response.Message) or response)
	return 15
end

-- Selling: only items that earn less than your weakest animal. Equipped, placed, fuse inputs
-- and mutated items are kept, and so is any stack that could fuse into a team upgrade.
STATE.sellStatus = "Starting"
local function sellPlan()
	local inventory, equipped, count, maxAnimals, weakest = teamSnapshot()
	if not weakest or count < maxAnimals then
		return {}, "Team not full yet"
	end
	local keep = {}
	for ref in pairs(equipped) do
		keep[ref] = true
	end
	for ref in pairs(DataController:GetValue("PlacedEggs") or {}) do
		keep[ref] = true
	end
	for _, ref in pairs((DataController:GetValue("Fuse") or {}).Slots or {}) do
		keep[ref] = true
	end
	local stacks = {}
	for ref, item in pairs(inventory) do
		if type(item) == "table" and item.Handler == "Animal" and not keep[ref] then
			local scale, variant, mutation = itemFields(item)
			if mutation == nil then
				local key = item.Name .. "\0" .. variant
				stacks[key] = stacks[key] or { name = item.Name, variant = variant, scales = {} }
				table.insert(stacks[key].scales, scale)
			end
		end
	end
	local keepStack = {}
	for key, stack in pairs(stacks) do
		table.sort(stack.scales, function(a, b)
			return a > b
		end)
		local left, scale, variant = #stack.scales, stack.scales[1] or 1, stack.variant
		while left >= 3 do
			local nextVariant = fuseConfig.GetNextVariant(variant)
			if not nextVariant then
				break
			end
			left, scale, variant = math.floor(left / 3), scale * 3 ^ (1 / 3), nextVariant
			local ok, income = pcall(earningCurve.GetCashPerSecond, stack.name, scale, variant, nil)
			if ok and income > weakest.income then
				keepStack[key] = true
				break
			end
		end
	end
	local refs = {}
	for ref, item in pairs(inventory) do
		if type(item) == "table" and not keep[ref] then
			local _, variant, mutation = itemFields(item)
			-- Never sell eggs the player picked to farm or place.
			if item.Handler == "Egg" then
				local rarity = STATE.eggRarity(item.Name)
				if
					(STATE.farmPickMode == "My picks" and STATE.eggMatches("farm", item.Name, rarity, nil, variant, mutation))
					or (STATE.placePickMode == "My picks" and STATE.eggMatches("place", item.Name, rarity, nil, variant, mutation))
				then
					continue
				end
			end
			if
				itemIncome(item) < weakest.income
				and (mutation == nil or mutation == "")
				and not (item.Handler == "Animal" and keepStack[item.Name .. "\0" .. variant])
				and sellConfig.GetQuote(item, 0, 1) ~= nil
			then
				refs[#refs + 1] = ref
			end
		end
	end
	return refs
end

function STATE.sellJunkNow()
	local refs, why = sellPlan()
	if #refs == 0 then
		STATE.sellStatus = why or "Nothing to sell"
		return 0
	end
	local cashBefore = tonumber(DataController:GetValue("Cash")) or 0
	local sold = 0
	for first = 1, #refs, sellConfig.MaxSellList do
		local batch = table.move(refs, first, math.min(first + sellConfig.MaxSellList - 1, #refs), 1, {})
		waitFor(function()
			return not AnimalSellController.Pending
		end, 5)
		AnimalSellController:Request("SellList", batch)
		waitFor(function()
			return not AnimalSellController.Pending
		end, 10)
		local inventory = DataController:GetValue("Inventory") or {}
		for _, ref in ipairs(batch) do
			if inventory[ref] == nil then
				sold += 1
			end
		end
		task.wait(0.8)
	end
	local gained = math.max(0, (tonumber(DataController:GetValue("Cash")) or 0) - cashBefore)
	stats.sold += sold
	stats.soldCash += gained
	STATE.sellStatus = "Sold " .. sold .. " junk items"
	if sold > 0 then
		noteActivity(string.format("Sold %d junk items for $%s", sold, shortNumber(gained)))
	end
	return sold
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
	gui.Name = "ZinoosClimbMenu"
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
	dockGame.Text = STATE.admin and "Admin" or "Climb Animals"
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
	brandSub.Text = "Climb Animals"
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
	profileGame.Text = STATE.admin and "Admin" or "Climb Animals"
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
		elseif key == "treadmill" and not on then
			task.spawn(STATE.stopTraining)
		elseif (key == "equipBest" or key == "autoFuse") and on then
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
	local farmCard = card(leftColumn, "EGG FARM", 1)
	makeSwitch(farmCard, "Auto Egg Farm", "eggFarm", "Grabs an egg you can reach and brings it home")
	makeSwitch(farmCard, "Only Upgrades", "onlyUpgrades", "Best egg mode: only takes eggs that beat your weakest team animal")
	makeSwitch(farmCard, "Guard Protection", "guardSafe", "Guards can't stun you while you carry an egg")
	do
		-- Picks: an empty list means any.
		STATE.pickLabel = function(list)
			if type(list) ~= "table" or #list == 0 then
				return "Any"
			elseif #list <= 2 then
				return table.concat(list, ", ")
			end
			return #list .. " picked"
		end
		local function pickList(cardFrame, title, key, options)
			makeMultiDropdown(cardFrame, title, function()
				return STATE[key]
			end, options, function(option)
				STATE.toggleListItem(key, option)
				saveConfig()
			end, STATE.pickLabel)
		end
		STATE.pickList = pickList
		makeDropdown(farmCard, "Farm Mode", function()
			return STATE.farmPickMode
		end, STATE.FARM_MODES, function(option)
			STATE.farmPickMode = option
			saveConfig()
		end)
		pickList(farmCard, "Farm Rarities", "farmRarities", STATE.RARITY_OPTIONS)
		pickList(farmCard, "Farm Biomes", "farmBiomes", STATE.BIOME_OPTIONS)
		pickList(farmCard, "Farm Eggs", "farmEggs", STATE.EGG_OPTIONS)
		makeSwitch(farmCard, "Special Eggs Only", "farmSpecialOnly", "My picks mode: only Golden, Diamond, Ruby, Rainbow or mutated eggs")
		makeDropdown(farmCard, "Min Income /s", function()
			return STATE.farmMinIncome
		end, STATE.MIN_INCOME_OPTIONS, function(option)
			STATE.farmMinIncome = option
			saveConfig()
		end)
	end

	local trainCard = card(leftColumn, "TRAINING", 2)
	makeSwitch(trainCard, "Treadmill When Idle", "treadmill", "Trains speed when no egg is worth taking, and claims the bonus")

	local teamCard = card(leftColumn, "TEAM", 3)
	makeSwitch(teamCard, "Auto Place", "autoPlace", "Places the eggs you choose below on your base")
	do
		makeDropdown(teamCard, "Place Mode", function()
			return STATE.placePickMode
		end, STATE.PLACE_MODES, function(option)
			STATE.placePickMode = option
			saveConfig()
		end)
		STATE.pickList(teamCard, "Place Rarities", "placeRarities", STATE.RARITY_OPTIONS)
		STATE.pickList(teamCard, "Place Eggs", "placeEggs", STATE.EGG_OPTIONS)
		makeSwitch(teamCard, "Only If It Beats Team", "placeBeatsOnly", "My picks mode: only places an egg that beats your weakest animal")
	end
	makeSwitch(teamCard, "Auto Hatch", "autoHatch", "Hatches placed eggs as soon as they're ready")
	do
		makeDropdown(teamCard, "Hatch Mode", function()
			return STATE.hatchPickMode
		end, STATE.HATCH_MODES, function(option)
			STATE.hatchPickMode = option
			saveConfig()
		end)
		STATE.pickList(teamCard, "Hatch Rarities", "hatchRarities", STATE.RARITY_OPTIONS)
		STATE.pickList(teamCard, "Hatch Eggs", "hatchEggs", STATE.EGG_OPTIONS)
	end
	makeSwitch(teamCard, "Auto Equip Best", "equipBest", "Re-equips your best animals when your inventory changes")
	-- Switch rows default to order 1 and dropdown rows to 2; keep these cards in build order instead.
	for _, cardFrame in ipairs({ farmCard, teamCard }) do
		local order = 0
		for _, child in ipairs(cardFrame:GetChildren()) do
			if child:IsA("GuiObject") and child.LayoutOrder ~= 0 then
				order += 1
				child.LayoutOrder = order
			end
		end
	end

	local progressCard = card(rightColumn, "PROGRESS", 1)
	makeSwitch(progressCard, "Safe Auto Fuse", "autoFuse", "Fuses 3 matching animals only when the result beats your team")
	makeSwitch(progressCard, "Auto Rebirth", "autoRebirth", "Rebirths as soon as every requirement is met")
	makeSwitch(progressCard, "Auto Base Upgrade", "autoUpgrade", "Buys the next base level when you can afford it")
	makeSwitch(progressCard, "Auto Stamina", "autoStamina", "Buys the next stamina level when you can afford it, so you can climb to higher biomes")
	makeSwitch(progressCard, "Auto Treadmill Upgrade", "autoTreadmillUpgrade", "Buys the next treadmill level when you can afford it, so Speed trains faster")

	local eventCard = card(rightColumn, "HALLOWEEN EVENT", 3)
	makeSwitch(eventCard, "Auto Candy Farm", "candyFarm", "Goes through the portal and kills mini monsters for candy when no egg is worth grabbing")
	makeSwitch(eventCard, "Auto Buy Halloween Egg", "buyCandyEgg", "Spends candy on Halloween eggs, 250 each")
	makeSwitch(eventCard, "God Mode", "godMode", "Keeps you alive: breaks off fights and heals at spawn before your health gets low")

	local sellCard = card(rightColumn, "SELLING", 2)
	makeSwitch(sellCard, "Auto Sell Junk", "autoSell", "Sells items earning less than your weakest animal. Keeps mutated ones")
	makeDropdown(sellCard, "Sell Every (min)", function()
		return tostring(STATE.sellMinutes)
	end, SELL_MINUTE_OPTIONS, function(option)
		STATE.sellMinutes = tonumber(option) or STATE.sellMinutes
		saveConfig()
	end)

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
	local blurb = label(intro, "Grabs eggs that beat your team, trains speed, and keeps your team and inventory sorted.", 14, muted, Enum.Font.Gotham, 36)
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
	local solvesText = statChip(statGrid, "Cash", 1)
	solvesText.Parent.Position = UDim2.fromOffset(0, 0)
	local movesText = statChip(statGrid, "Speed", 2)
	movesText.Parent.Position = UDim2.new(0.5, 5, 0, 0)
	local tableText = statChip(statGrid, "Rebirths", 3)
	tableText.Parent.Position = UDim2.fromOffset(0, 68)
	local statusText = statChip(statGrid, "Doing", 4)
	statusText.Parent.Position = UDim2.new(0.5, 5, 0, 68)
	statusText.TextSize = 14
	statusText.TextTruncate = Enum.TextTruncate.AtEnd
	local refreshHealth = nil
	STATE.refreshHealth = nil

	local note = card(homePage, "HOW IT WORKS", 7)
	local noteBody = label(note, "Everything is judged against your weakest equipped animal. The farm only takes eggs that beat it, placing only uses eggs that beat it, and selling only sells what earns less than it. Mutated animals are never sold.", 13, ink, Enum.Font.Gotham, 56)
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
			"Placing · " .. tostring(STATE.placeStatus),
			"Fuse · " .. tostring(STATE.fuseStatus),
			"Rebirth · " .. tostring(STATE.rebirthStatus),
			"Selling · " .. tostring(STATE.sellStatus),
			"Halloween · " .. tostring(STATE.candyStatus) .. (stats.candyEggs > 0 and string.format(", %d eggs bought", stats.candyEggs) or "") .. ((stats.heals or 0) > 0 and string.format(", healed %d times", stats.heals) or ""),
			string.format("Session · %d eggs, %d placed, %d fused, %d sold ($%s), %d bonuses", stats.eggs, stats.placed, stats.fused, stats.sold, STATE.shortNumber(stats.soldCash), stats.bonuses),
			string.format("Guards · %d stuns blocked", stats.guardBlocks),
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
		solvesText.Text = "$" .. STATE.shortNumber(DataController:GetValue("Cash"))
		movesText.Text = STATE.shortNumber(DataController:GetValue("Speed"))
		tableText.Text = tostring(DataController:GetValue("Rebirths") or 0)
		statusText.Text = tostring(STATE.status)
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
		if input.KeyCode == Enum.KeyCode.LeftControl then
			gui.Enabled = not gui.Enabled
			return
		end
		if input.KeyCode.Name == STATE.toggleKey then
			setOpen(not holder.Visible)
		end
	end))

	local actionsCard = card(homePage, "ACTIONS", 9)
	local actionsNote = label(actionsCard, "Run these now instead of waiting for the next pass.", 12, muted, Enum.Font.Gotham, 16)
	actionsNote.LayoutOrder = 1
	actionButton(actionsCard, "Sell Junk Now", 2, true, function()
		task.spawn(function()
			local sold = STATE.sellJunkNow()
			actionsNote.Text = sold > 0 and ("Sold " .. sold .. " junk items") or tostring(STATE.sellStatus)
		end)
	end)
	actionButton(actionsCard, "Equip Best Now", 3, false, function()
		task.spawn(function()
			actionsNote.Text = STATE.equipBestNow() and "Best animals equipped" or "Equip Best was rejected"
		end)
	end)

	do
		local discordInvite = "https://discord.gg/94pC3T6NZG"
		local communityCard = card(homePage, "COMMUNITY", 2)
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

	local saveCard = card(homePage, "CONFIG", 10)
	local saveNote = label(saveCard, "Saves the toggles, timings and theme for this account. Your other account keeps its own save.", 13, muted, Enum.Font.Gotham, 40)
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

-- The farm moves your character, so it has a loop of its own.
task.spawn(function()
	while running() do
		local ok, pause = pcall(stepFarm)
		if not ok then
			STATE.status = "Farm error: " .. tostring(pause)
			pause = 2
		end
		task.wait(pause or 0.5)
	end
end)

task.spawn(function()
	if STATE.equipBest == true then
		pcall(STATE.equipBestNow)
	end
	while running() do
		pcall(stepPlace)
		pcall(stepRebirth)
		pcall(STATE.stepStamina)
		pcall(STATE.stepTreadmillUpgrade)
		pcall(stepUpgrade)
		task.wait(1.5)
	end
end)

task.spawn(function()
	while running() do
		local ok, pause = pcall(stepFuse)
		task.wait(ok and pause or 10)
	end
end)

task.spawn(function()
	while running() do
		if STATE.autoSell == true then
			pcall(STATE.sellJunkNow)
		else
			STATE.sellStatus = "Off"
		end
		local waitUntil = os.clock() + math.max(1, STATE.sellMinutes) * 60
		while running() and os.clock() < waitUntil do
			task.wait(1)
		end
	end
end)

task.spawn(function()
	while running() do
		pcall(STATE.stepCandyShop)
		task.wait(2)
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

task.spawn(function()
	while running() do
		task.wait(4 * 60)
		pulseAntiAfk()
	end
end)
