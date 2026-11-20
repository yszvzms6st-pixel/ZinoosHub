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
	critterEsp = true,
	playerEsp = true,
	autoEvolve = true,
	autoRebirth = true,
	autoHatch = true,
	egg = "Royal",
	autoEquip = true,
	autoClaim = true,
	autoCodes = true,
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
	CritterEsp = "critterEsp",
	PlayerEsp = "playerEsp",
	AutoEvolve = "autoEvolve",
	AutoRebirth = "autoRebirth",
	AutoHatch = "autoHatch",
	AutoEquip = "autoEquip",
	AutoClaim = "autoClaim",
	AutoCodes = "autoCodes",
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
	Notifications = "notifications",
}

local FLY_SPEED_OPTIONS = { "30", "60", "100", "150", "200" }
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
local EGG_OPTIONS = { "Royal", "Colony" }
local CHOICES = {
	ToggleKey = { key = "toggleKey", options = KEY_OPTIONS },
	Egg = { key = "egg", options = EGG_OPTIONS },
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

local farm = {
	orbs = {},
	ready = false,
	nextRefresh = 0,
	skip = {},
	chase = nil,
	esp = {},
	codesDone = false,
	communityDone = false,
	recordIndex = 1,
	nextEvolve = 0,
	nextHatch = 0,
	nextEquip = 0,
	nextClaim = 0,
	nextBite = 0,
	nextAbility = 0,
	nextEsp = 0,
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

local VOID_Y = -40
local lastSafe = nil

local function rayFilter(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return params
end

local function groundAt(xz, character, fromY)
	local hit = Workspace:Raycast(Vector3.new(xz.X, fromY + 6, xz.Z), Vector3.new(0, -28, 0), rayFilter(character))
	if hit and hit.Position.Y > VOID_Y then
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

local function standOn(ground, character, root)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local lift = root.Size.Y * 0.5 + (hum and hum.HipHeight or 0) + 0.25
	return Vector3.new(ground.X, ground.Y + lift, ground.Z)
end

local function putBack(root)
	local spot = lastSafe or spawnStand()
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

local function stepOnto(character, root, aim, lookAt)
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	if flat.Magnitude < 1.5 then
		return true
	end
	local point = root.Position + flat.Unit * math.min(flat.Magnitude, 14)
	local ground = groundAt(point, character, root.Position.Y)
	if not ground or math.abs(ground.Y - root.Position.Y) > 18 then
		return false
	end
	local goal = standOn(ground, character, root)
	local look = Vector3.new(lookAt.X, goal.Y, lookAt.Z)
	root.AssemblyLinearVelocity = Vector3.zero
	if (look - goal).Magnitude < 1 then
		root.CFrame = CFrame.new(goal)
	else
		root.CFrame = CFrame.lookAt(goal, look)
	end
	return true
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
	if not stepOnto(character, root, stand, center) then
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

local function stepFarm()
	if STATE.autoOrb ~= true then
		STATE.detail = "Farm off"
		return
	end
	local character, root = living()
	if not character then
		STATE.status = "Waiting to move"
		return
	end
	if root.Position.Y < VOID_Y then
		putBack(root)
		return
	end
	local under = groundAt(root.Position, character, root.Position.Y)
	if under and math.abs(root.Position.Y - under.Y) < 12 then
		lastSafe = root.Position
	end
	local cube = sugarCube()
	if cube then
		stepSugar(character, root, cube)
		return
	end
	local id, orb = liveTarget(root.Position)
	if not orb then
		STATE.status = "No food nearby"
		refreshOrbs()
		return
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
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	if flat.Magnitude > 14 then
		aim = root.Position + flat.Unit * 14
	end
	local ground = groundAt(aim, character, root.Position.Y)
	if not ground or math.abs(ground.Y - root.Position.Y) > 10 then
		farm.skip[id] = os.clock() + 8
		farm.chase = nil
		STATE.status = "Skipped food off the ground"
		return
	end
	local goal = standOn(ground, character, root)
	local look = Vector3.new(orb.pos.X, goal.Y, orb.pos.Z)
	root.AssemblyLinearVelocity = Vector3.zero
	if (look - goal).Magnitude < 1 then
		root.CFrame = CFrame.new(goal)
	else
		root.CFrame = CFrame.lookAt(goal, look)
	end
	STATE.status = string.format("Walking to %s", foodName)
	STATE.detail = string.format("%s  %d away", foodName, math.floor(distance))
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

local function nearestCritter(origin, limit)
	local folder = Workspace:FindFirstChild("Ants")
	local critters = folder and folder:FindFirstChild("Critters")
	if not critters then
		return nil
	end
	local bestModel, bestRoot, bestDist
	for _, model in ipairs(critters:GetChildren()) do
		if model:IsA("Model") and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
			local root = critterRoot(model)
			if root then
				local distance = (root.Position - origin).Magnitude
				if distance <= limit and (not bestDist or distance < bestDist) then
					bestModel, bestRoot, bestDist = model, root, distance
				end
			end
		end
	end
	return bestModel, bestRoot, bestDist
end

local function stepBite()
	if STATE.autoBite ~= true or os.clock() < farm.nextBite then
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
	local foe = nearestCritter(root.Position, range)
	local entityId = foe and foe:GetAttribute("EntityId")
	if type(entityId) ~= "number" then
		return
	end
	farm.nextBite = os.clock() + 0.55
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
	if STATE.autoAbility ~= true or os.clock() < farm.nextAbility then
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
	local _, foeRoot = nearestCritter(root.Position, reach)
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
	if STATE.autoEvolve == true then
		invoke("Evolve")
		STATE.status = "Evolving"
	end
end

local function stepHatch()
	if STATE.autoHatch ~= true or os.clock() < farm.nextHatch then
		return
	end
	if STATE.egg ~= "Royal" and STATE.egg ~= "Colony" then
		return
	end
	local egg = Config.PetEggByKey[STATE.egg]
	local cost = type(egg) == "table" and tonumber(egg.cost) or nil
	if not cost or stateNumber("DNA") < cost then
		return
	end
	farm.nextHatch = os.clock() + 2
	invoke("HatchPet", STATE.egg)
end

function STATE.equipBestNow()
	invoke("EquipPet", "best")
	return true
end

local function stepEquip()
	if STATE.autoEquip ~= true or os.clock() < farm.nextEquip then
		return
	end
	farm.nextEquip = os.clock() + 12
	STATE.equipBestNow()
end

local CODES = { "ANTS", "EVOLVE", "QUEEN", "RELEASE" }
local RECORD_KEYS = {
	"ants", "boss", "bugs", "eggs", "evolve", "feast", "food",
	"grow", "mutate", "pets", "play", "rebirth", "roll", "sugar",
}

local function claimedSet(value)
	local decoded = readJson(value)
	local claimed = {}
	if type(decoded) ~= "table" then
		return claimed
	end
	for _, entry in pairs(decoded) do
		claimed[tonumber(entry) or entry] = true
	end
	return claimed
end

function STATE.claimNow()
	if STATE.autoCodes == true and not farm.codesDone then
		farm.codesDone = true
		for _, code in ipairs(CODES) do
			invoke("Redeem", code)
		end
	end
	if STATE.autoClaim ~= true then
		return false
	end
	invoke("ClaimDaily")
	local played = 0
	local started = tonumber(LocalPlayer:GetAttribute("PlayStart"))
	if started then
		played = (os.time() - started) / 60
	end
	local already = claimedSet(LocalPlayer:GetAttribute("PlaytimeClaimed"))
	for index, reward in ipairs(Config.Playtime) do
		if type(reward) == "table" and played >= (tonumber(reward.minutes) or 9999) and not already[index] then
			invoke("ClaimPlaytime", index)
			break
		end
	end
	local quests = stateJson("Quests")
	if type(quests) == "table" and type(quests.q) == "table" then
		local finished = 0
		for index, row in ipairs(quests.q) do
			if type(row) == "table" then
				if row[5] == 1 then
					finished += 1
				elseif (tonumber(row[4]) or 0) >= (tonumber(row[3]) or 1) then
					invoke("ClaimQuest", index)
				end
			end
		end
		if finished >= #quests.q and quests.b ~= 1 then
			invoke("ClaimQuest", "bonus")
		end
	end
	if LocalPlayer:GetAttribute("CommunityClaimed") ~= true and not farm.communityDone then
		farm.communityDone = true
		invoke("CommunityClaim")
	end
	local key = RECORD_KEYS[farm.recordIndex]
	farm.recordIndex = farm.recordIndex % #RECORD_KEYS + 1
	if key then
		invoke("ClaimRecord", key)
	end
	noteActivity("Claimed what was ready")
	return true
end

local function stepClaims()
	if os.clock() < farm.nextClaim then
		return
	end
	farm.nextClaim = os.clock() + 25
	STATE.claimNow()
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

pcall(function()
	trackConnection(GuiService.ErrorMessageChanged:Connect(function(message)
		if STATE.autoReconnect == true and type(message) == "string" and message ~= "" then
			task.wait(2)
			pcall(function()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
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
		elseif key == "autoEquip" and on then
			task.spawn(STATE.equipBestNow)
		elseif key == "autoClaim" and on then
			task.spawn(STATE.claimNow)
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
				local ok, err = pcall(callback)
				if not ok then
					notify("system", title .. " failed", tostring(err))
				end
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
		STATE.claimNow()
		notify("system", "Claimed what was ready", "")
	end)
	button(homeTab, "Equip Best Now", "Equips your best pets", "paw-print", function()
		STATE.equipBestNow()
		notify("system", "Best pets equipped", "")
	end)
	local activityInfo = info(homeTab, "Activity", "Waiting for the next thing the hub does.")

	local farmInfo
	do
		local farmBox = section(farmTab, "Food", "apple")
		toggle(farmBox, "Auto Orb Farm", "autoOrb", "Steps you onto nearby food. During Sugar Rush it stays in the ring")
		toggle(farmBox, "Auto Bite", "autoBite", "Bites a bug when it is already in reach")
		toggle(farmBox, "Auto Ability", "autoAbility", "Uses your mutation ability on a nearby bug")
		farmInfo = info(farmBox, "Status", tostring(STATE.status or "Starting"))

		local espBox = section(farmTab, "ESP", "eye")
		toggle(espBox, "Critter ESP", "critterEsp", "Shows bug names and health")
		toggle(espBox, "Player ESP", "playerEsp", "Shows other players")
	end

	do
		local growBox = section(progressTab, "Evolve", "sparkles")
		toggle(growBox, "Auto Evolve", "autoEvolve", "Evolves when you have the power")
		toggle(growBox, "Auto Rebirth", "autoRebirth", "Rebirths only when you are at the top stage")

		local hatchBox = section(progressTab, "Pets", "egg")
		toggle(hatchBox, "Auto Hatch", "autoHatch", "Hatches the egg below when you can pay for it")
		choice(hatchBox, "Egg", "Royal waits until you can afford it", EGG_OPTIONS, function()
			return STATE.egg
		end, function(option)
			STATE.egg = option
		end)
		toggle(hatchBox, "Auto Equip Best Pet", "autoEquip", "Equips your best pets")

		local claimBox = section(progressTab, "Rewards", "gift")
		toggle(claimBox, "Auto Claim Rewards", "autoClaim", "Claims daily, playtime, quests and records")
		toggle(claimBox, "Redeem Codes", "autoCodes", "Redeems the known codes once")
	end

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

		local clientBox = section(playerTab, "Performance & AFK", "cpu")
		toggle(clientBox, "Anti AFK", "antiAfk")
		toggle(clientBox, "Auto Reconnect on Kick", "autoReconnect")
		toggle(clientBox, "Hide Roblox Pause Popup", "noPausePopup")
		toggle(clientBox, "Potato Mode", "fpsBoost", "Lowest graphics, no shadows or effects")
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
STATE.version = "1.0.1"

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
		local ok, err = pcall(stepFarm)
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
		pcall(stepEquip)
		pcall(stepClaims)
		pcall(stepEsp)
		task.wait(0.35)
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
