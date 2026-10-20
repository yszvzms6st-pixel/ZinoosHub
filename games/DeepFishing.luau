-- Zinoos hub for Deep Fishing.
-- Auto Fish drives the game's own AutoFishing controller (skips its Level 5 gate).
-- Perfect Casts makes it cast like the AutoBoost enchant: faster, mostly Perfect, some Good.
-- Auto Sell hops to the sell NPC, sells, and hops back between casts.
-- Auto Upgrade buys the cheapest upgrade. Auto Rod buys and equips the best affordable rod.
-- The window, theme, dashboard and launcher are the Lift Rock hub's own.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

if game.GameId ~= 10526853622 then
	warn("[Zinoos hub] This only runs in Deep Fishing.")
	return
end

local LocalPlayer = Players.LocalPlayer
local genv = getgenv()

local DEFAULT_SPOT = Vector3.new(-1246, 22.6, 95)
local PERFECT_CHANCE = 0.75
local SELL_OPTIONS = { "30 fish", "60 fish", "100 fish", "200 fish" }
local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/DeepFishing.rfld"
local LOADER_URL = "https://raw.githubusercontent.com/yszvzms6st-pixel/ZinoosHub/main/ZinoosHub.luau"

-- Calling into the game's own code drops this thread's identity, and CoreGui then reads as nil.
-- Raise it again before touching the hub.
local function elevate()
	if typeof(setthreadidentity) == "function" then
		pcall(setthreadidentity, 8)
	end
end

-- The live-reload runner hands scripts a STATE of its own; keep it apart from the hub's.
local reloadState = STATE
local STATE = {
	featureFaults = {},
	activity = {},
	status = "Starting",
	selling = false,
	fishing = false,
	stats = { caught = 0, sold = 0, earned = 0, casts = 0, startedAt = os.time() },
	autoFish = true,
	perfect = true,
	sell = true,
	sellAt = 60,
	upgrade = true,
	rod = true,
	antiAfk = true,
	autoReload = false,
	hubSize = "Compact",
}

-- One copy at a time: a new run stops the old one first.
if typeof(genv.ZinoosFishingStop) == "function" then
	pcall(genv.ZinoosFishingStop)
end
genv.ZinoosFishingGen = (typeof(genv.ZinoosFishingGen) == "number" and genv.ZinoosFishingGen or 0) + 1
local token = genv.ZinoosFishingGen
local function running()
	return genv.ZinoosFishingGen == token
end

local runtime = { connections = {}, cleanups = {} }
local function trackConnection(connection)
	table.insert(runtime.connections, connection)
	return connection
end
local function hubCleanup(fn)
	table.insert(runtime.cleanups, fn)
end
local function shutdownHub()
	if genv.ZinoosFishingGen == token then
		genv.ZinoosFishingGen = token + 1
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
local function unloadHub()
	shutdownHub()
end
genv.ZinoosFishingStop = shutdownHub
if typeof(reloadState) == "table" and typeof(reloadState.onCleanup) == "function" then
	reloadState.onCleanup(shutdownHub)
end

function STATE.noteFault(name, ok, err)
	if ok then
		STATE.featureFaults[name] = nil
		return true
	end
	local message = tostring(err)
	if #message > 140 then
		message = string.sub(message, 1, 137) .. "..."
	end
	STATE.featureFaults[name] = message
	return false
end

function STATE.noteActivity(text)
	if type(text) ~= "string" or text == "" or STATE.activity[#STATE.activity] == text then
		return
	end
	STATE.activity[#STATE.activity + 1] = text
	while #STATE.activity > 8 do
		table.remove(STATE.activity, 1)
	end
end

local function toast(text)
	if typeof(STATE.toast) == "function" then
		STATE.toast(text)
	end
end

local function findController()
	return filtergc("table", { Keys = { "On", "DrivingThrow", "ThrowFinds", "FilterButtons" } }, true)
end
local AF = findController()
while not AF and running() do
	task.wait(1)
	AF = findController()
end
if not AF then
	return
end

local Fishing = AF.Controllers.Fishing
local Cinematic = AF.Controllers.ThrowCinematic
local fishSpot = nil

local function readData()
	local ok, data = pcall(function()
		return AF.PlayerData:Get()
	end)
	elevate()
	return ok and data or nil
end

local function shortNumber(value)
	local ok, text = pcall(function()
		return AF.Vendors.MoneyLib.HandleMoney(value)
	end)
	elevate()
	text = if ok and text ~= nil then tostring(text) else tostring(value)
	if string.sub(text, 1, 1) ~= "$" then
		text = "$" .. text
	end
	return text
end

local function hrpOf()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function busy()
	return Cinematic.Active == true or Fishing.Charging == true or AF.DrivingThrow == true
end

local function fishCount()
	local data = readData()
	local count = 0
	for _, item in pairs(data and data.Inventory or {}) do
		if type(item) == "table" and item.Type == "Fish" then
			count += 1
		end
	end
	return count
end

local function interactable(name)
	local data = readData()
	local world = workspace:FindFirstChild("World")
	world = world and world:FindFirstChild(data and data.World or "World 1")
	local folder = world and world:FindFirstChild("Interactable")
	return folder and folder:FindFirstChild(name)
end

-- Keep the game's own functions across reloads, so a second run never wraps the first one's wrapper.
local originals = genv.ZinoosFishingOriginals
if type(originals) ~= "table" or originals.controller ~= AF then
	originals = { controller = AF, Boost = AF.Boost, DriveCast = AF.DriveCast }
	genv.ZinoosFishingOriginals = originals
end
AF.Boost = function(self)
	local real = originals.Boost(self)
	if running() and STATE.perfect == true then
		return math.max(real or 0, PERFECT_CHANCE)
	end
	return real
end
AF.DriveCast = function(self, fishing)
	if running() and STATE.selling then
		return
	end
	if running() then
		STATE.stats.casts += 1
	end
	return originals.DriveCast(self, fishing)
end
hubCleanup(function()
	AF.Boost = originals.Boost
	AF.DriveCast = originals.DriveCast
	if AF.On then
		pcall(AF.SetOn, AF, false)
	end
end)

trackConnection(AF.Events.Client("FishesReceivedNotification"):Connect(function(fish, info)
	if type(info) == "table" and (info.Offline or info.Pet) then
		return
	end
	if type(fish) == "table" then
		STATE.stats.caught += if fish.Name then 1 else #fish
	end
end))

local function equipRod()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = readData()
	local name = data and data.RodEquipped
	if not humanoid or not name then
		return
	end
	local held = character:FindFirstChildOfClass("Tool")
	if held and held.Name == name then
		return
	end
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild(name)
	if tool then
		humanoid:EquipTool(tool)
	end
end

local function stepFish()
	if STATE.autoFish ~= true then
		if AF.On then
			AF:SetOn(false)
		end
		STATE.fishing = false
		STATE.status = "Idle"
		return
	end
	if STATE.selling then
		return
	end
	local hrp = hrpOf()
	if not hrp then
		return
	end
	if Fishing:InArea() then
		if not busy() then
			fishSpot = hrp.CFrame
		end
	elseif not busy() then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = fishSpot or CFrame.new(DEFAULT_SPOT)
	end
	equipRod()
	if not AF.On then
		AF:SetOn(true)
	end
	STATE.fishing = busy()
	STATE.status = STATE.fishing and "Fishing" or "Casting"
end

local function sellOnce(minimum)
	if STATE.selling or busy() then
		return
	end
	if fishCount() < minimum then
		return
	end
	local npc = interactable("NPC_Sell")
	local hrp = hrpOf()
	if not npc or not hrp then
		return
	end
	STATE.selling = true
	STATE.status = "Selling"
	local back = fishSpot or hrp.CFrame
	local pivot = npc:GetPivot()
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(pivot.Position + pivot.LookVector * 6 + Vector3.new(0, 2, 0))
	task.wait(0.35)
	local ok, result = pcall(function()
		return AF.Events.Client("SellAll"):Invoke(5, "Fish", nil)
	end)
	hrp = hrpOf()
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = back
	end
	if ok and type(result) == "table" and (tonumber(result.Amount) or 0) > 0 then
		local amount = tonumber(result.Amount) or 0
		local value = tonumber(result.Value) or 0
		STATE.stats.sold += amount
		STATE.stats.earned += value
		local text = string.format("Sold %d fish for %s", amount, shortNumber(value))
		STATE.noteActivity(text)
		toast(text)
	end
	task.wait(0.3)
	STATE.selling = false
end

local function stepSell()
	if STATE.sell == true then
		sellOnce(STATE.sellAt)
	end
end

function STATE.sellNow()
	task.spawn(function()
		while running() and busy() do
			task.wait(0.2)
		end
		STATE.watchFeature("Auto Sell", function()
			sellOnce(1)
		end)
	end)
end

function STATE.watchFeature(name, fn)
	local ok, result = pcall(fn)
	STATE.noteFault(name, ok, result)
	return ok, result
end

-- Rods the shop will sell you here: no event, Maze, Cave or Volcano rods, nothing locked or cursed.
local function shopRods(data)
	local Rod = AF.Content.Item.Rod
	local list = {}
	for name, rod in pairs(Rod.Items) do
		if type(rod) == "table" and (rod.LayoutOrder or 0) < 100 and not rod.MazeOnly and not rod.CaveOnly and not rod.VolcanoOnly then
			if not Rod:LockedBehind(rod, data) and not AF.Config.EventGearConfig.CursedHere(data, name) then
				list[#list + 1] = { name = name, strength = rod.Strength or 0, price = rod.Price or 0, owned = data.Rods[name] ~= nil }
			end
		end
	end
	return list
end

function STATE.nextRod()
	local data = readData()
	if not data then
		return nil
	end
	local current = AF.Content.Item.Rod:Get(data.RodEquipped or "Wooden Rod", true)
	local strength = current and current.Strength or 0
	local pick = nil
	for _, rod in ipairs(shopRods(data)) do
		if not rod.owned and rod.strength > strength and (not pick or rod.price < pick.price) then
			pick = rod
		end
	end
	return pick, data.Cash or 0
end

local function stepRod()
	if STATE.rod ~= true or busy() or STATE.selling then
		return
	end
	local data = readData()
	if not data then
		return
	end
	local current = AF.Content.Item.Rod:Get(data.RodEquipped or "Wooden Rod", true)
	local bestOwned, bestOwnedStrength = nil, current and current.Strength or 0
	local bestBuy, bestBuyStrength = nil, bestOwnedStrength
	for _, rod in ipairs(shopRods(data)) do
		if rod.owned then
			if rod.strength > bestOwnedStrength then
				bestOwned, bestOwnedStrength = rod.name, rod.strength
			end
		elseif rod.price <= (data.Cash or 0) and rod.strength > bestBuyStrength then
			bestBuy, bestBuyStrength = rod.name, rod.strength
		end
	end
	if bestBuy and bestBuyStrength > bestOwnedStrength then
		STATE.status = "Buying " .. bestBuy
		AF.Events.Client("RodShop"):Fire(true, "Buy", bestBuy)
		task.wait(1)
		AF.Events.Client("RodShop"):Fire(true, "Equip", bestBuy)
		task.wait(0.8)
		equipRod()
		STATE.noteActivity("Bought " .. bestBuy)
		toast("Bought " .. bestBuy)
	elseif bestOwned then
		AF.Events.Client("RodShop"):Fire(true, "Equip", bestOwned)
		task.wait(0.8)
		equipRod()
		STATE.noteActivity("Equipped " .. bestOwned)
	end
end

function STATE.nextUpgrade()
	local data = readData()
	if not data then
		return nil
	end
	local U = AF.Config.UpgradesConfig
	local key = U.KeyForData(data)
	local cheapest, cheapestPrice, cheapestLevel = nil, math.huge, 0
	for _, name in ipairs(U.Order) do
		local level = U.LevelOf(data, name, key)
		if level < U.MaxLevelFor(name, key) then
			local ok, price = pcall(U.GetPrice, name, level, key)
			if ok and type(price) == "number" and price < cheapestPrice then
				cheapest, cheapestPrice, cheapestLevel = name, price, level
			end
		end
	end
	elevate()
	if not cheapest then
		return nil
	end
	return { name = cheapest, price = cheapestPrice, level = cheapestLevel }, data.Cash or 0
end

local function stepUpgrade()
	if STATE.upgrade ~= true then
		return
	end
	local pick, cash = STATE.nextUpgrade()
	if pick and pick.price <= cash then
		AF.Events.Client("Upgrades"):Fire(true, "Buy", pick.name)
		STATE.noteActivity(string.format("Upgraded %s to level %d", pick.name, pick.level + 1))
	end
end

local pulseAntiAfk = function()
	if not running() or STATE.antiAfk ~= true then
		return false
	end
	local userOk = pcall(function()
		local virtual = game:GetService("VirtualUser") :: any
		virtual:CaptureController()
		virtual:ClickButton2(Vector2.new(-1, -1))
	end)
	local moveOk, moveErr = pcall(function()
		local input = game:GetService("VirtualInputManager") :: any
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local x = math.clamp(view.X * 0.5, 1, math.max(1, view.X - 1))
		local y = math.clamp(view.Y * 0.92, 1, math.max(1, view.Y - 1))
		input:SendMouseMoveEvent(x, y, game)
		input:SendMouseMoveEvent(x + 2, y, game)
		input:SendMouseMoveEvent(x, y, game)
	end)
	STATE.antiAfkOperational = userOk or moveOk
	STATE.antiAfkMethod = if moveOk then "VirtualInputManager" elseif userOk then "VirtualUser" else nil
	STATE.antiAfkError = if STATE.antiAfkOperational then nil else tostring(moveErr)
	return STATE.antiAfkOperational
end
trackConnection(LocalPlayer.Idled:Connect(function()
	pulseAntiAfk()
end))
local antiAfkThread = task.spawn(function()
	task.wait(1)
	pulseAntiAfk()
	while running() do
		task.wait(4 * 60)
		pulseAntiAfk()
	end
end)
hubCleanup(function()
	pcall(task.cancel, antiAfkThread)
end)

function STATE.applyAutoReload()
	if typeof(queue_on_teleport) ~= "function" then
		return
	end
	if STATE.autoReload == true then
		pcall(queue_on_teleport, "if not game:IsLoaded() then game.Loaded:Wait() end task.wait(8) loadstring(game:HttpGet(\"" .. LOADER_URL .. "?t=\" .. tostring(os.time())))()")
		STATE._queuedReload = true
	elseif STATE._queuedReload == true and typeof(clear_teleport_queue) == "function" then
		pcall(clear_teleport_queue)
		STATE._queuedReload = false
	end
end

function STATE.sessionLines()
	local stats = STATE.stats
	local hours = math.max(1 / 60, (os.time() - stats.startedAt) / 3600)
	local lines = {
		"Status · " .. tostring(STATE.status),
		string.format("%d casts · %d fish caught · %d an hour", stats.casts, stats.caught, math.floor(stats.caught / hours)),
		string.format("Sold %d fish for %s · %s an hour", stats.sold, shortNumber(stats.earned), shortNumber(math.floor(stats.earned / hours))),
	}
	if STATE.antiAfk == true then
		lines[#lines + 1] = STATE.antiAfkOperational and ("Anti AFK working through " .. tostring(STATE.antiAfkMethod)) or "Anti AFK requested but unavailable"
	end
	return lines
end

local function destroyMenus()
	local roots = { game:GetService("CoreGui") }
	if typeof(gethui) == "function" then
		table.insert(roots, gethui())
	end
	for _, root in ipairs(roots) do
		if root then
			for _, name in ipairs({ "ZinoosFishingMenu", "CodexDeepFishing" }) do
				local old = root:FindFirstChild(name)
				if old then
					old:Destroy()
				end
			end
		end
	end
end
local function closeLeftoverMenus()
	destroyMenus()
end
hubCleanup(destroyMenus)

local FLAG_KEYS = {
	AutoFish = "autoFish",
	PerfectCasts = "perfect",
	AutoSell = "sell",
	AutoUpgrade = "upgrade",
	AutoRod = "rod",
	AntiAfk = "antiAfk",
	AutoReload = "autoReload",
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

STATE.hubSizes = { Compact = 0.8, Normal = 0.9, Large = 1 }

function STATE.hubScaleValue()
	return STATE.hubSizes[STATE.hubSize or "Compact"] or STATE.hubSizes.Compact
end

STATE.dashFeatures = {
	{ label = "Fish", key = "autoFish", fault = "Auto Fish", busy = "fishing" },
	{ label = "Perfect", key = "perfect" },
	{ label = "Sell", key = "sell", fault = "Auto Sell", busy = "selling" },
	{ label = "Upgrade", key = "upgrade", fault = "Auto Upgrade" },
	{ label = "Rod", key = "rod", fault = "Auto Rod" },
	{ label = "Anti AFK", key = "antiAfk" },
	{ label = "Rejoin", key = "autoReload" },
}

STATE.dashColors = {
	off = Color3.fromRGB(110, 110, 110),
	ok = Color3.fromRGB(70, 205, 110),
	busy = Color3.fromRGB(255, 184, 64),
	fault = Color3.fromRGB(235, 80, 80),
}

function STATE.buildDashboard(gui, homePage, card, label)
	local box = card(homePage, "DASHBOARD", 5)
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.LayoutOrder = 1
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.ZIndex = 6
	grid.Parent = box
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.2, -4, 0, 18)
	gridLayout.CellPadding = UDim2.fromOffset(4, 4)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	local lights = {}
	for index, feature in ipairs(STATE.dashFeatures) do
		local chip = Instance.new("Frame")
		chip.BackgroundTransparency = 1
		chip.LayoutOrder = index
		chip.ZIndex = 6
		chip.Parent = grid
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.new(0, 0, 0.5, 0)
		dot.Size = UDim2.fromOffset(8, 8)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = STATE.dashColors.off
		dot.ZIndex = 7
		dot.Parent = chip
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
		local name = label(chip, feature.label, 12, Color3.new(1, 1, 1), Enum.Font.GothamMedium, 18)
		name.Position = UDim2.fromOffset(12, 0)
		name.Size = UDim2.new(1, -12, 1, 0)
		name.TextYAlignment = Enum.TextYAlignment.Center
		name.TextWrapped = false
		name.ZIndex = 7
		lights[index] = { dot = dot, name = name }
	end
	local bars = {}
	for index = 1, 3 do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = 1 + index
		row.Size = UDim2.new(1, 0, 0, 30)
		row.ZIndex = 6
		row.Parent = box
		local text = label(row, "", 12, Color3.new(1, 1, 1), Enum.Font.Gotham, 16)
		text.Size = UDim2.new(1, 0, 0, 16)
		text.TextWrapped = false
		text.TextTruncate = Enum.TextTruncate.AtEnd
		text.ZIndex = 7
		local track = Instance.new("Frame")
		track.Position = UDim2.fromOffset(0, 20)
		track.Size = UDim2.new(1, 0, 0, 6)
		track.BorderSizePixel = 0
		track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		track.BackgroundTransparency = 0.85
		track.ZIndex = 7
		track.Parent = row
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = STATE.dashColors.ok
		fill.ZIndex = 8
		fill.Parent = track
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill
		bars[index] = { text = text, fill = fill }
	end
	local function setBar(bar, text, fraction, color)
		elevate()
		if bar.text.Text ~= text then
			bar.text.Text = text
		end
		local size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		if bar.fill.Size ~= size then
			bar.fill.Size = size
		end
		if bar.fill.BackgroundColor3 ~= color then
			bar.fill.BackgroundColor3 = color
		end
	end
	STATE.refreshDashboard = function()
		local theme = STATE.hubThemeDef()
		local faults = type(STATE.featureFaults) == "table" and STATE.featureFaults or {}
		for index, feature in ipairs(STATE.dashFeatures) do
			local light = lights[index]
			local color = STATE.dashColors.ok
			if STATE[feature.key] ~= true then
				color = STATE.dashColors.off
			elseif feature.fault and type(faults[feature.fault]) == "string" and faults[feature.fault] ~= "" then
				color = STATE.dashColors.fault
			elseif feature.busy and STATE[feature.busy] == true then
				color = STATE.dashColors.busy
			end
			if light.dot.BackgroundColor3 ~= color then
				light.dot.BackgroundColor3 = color
			end
			if light.name.TextColor3 ~= theme.ink then
				light.name.TextColor3 = theme.ink
			end
		end
		local fish = fishCount()
		local sellAt = math.max(1, tonumber(STATE.sellAt) or 60)
		if STATE.sell ~= true then
			setBar(bars[1], string.format("Bag · %d fish · Auto Sell off", fish), 0, STATE.dashColors.off)
		else
			setBar(bars[1], string.format("Bag · %d / %d fish until Auto Sell", fish, sellAt), fish / sellAt, STATE.selling and STATE.dashColors.busy or STATE.dashColors.ok)
		end
		local upgrade, cash = STATE.nextUpgrade()
		if not upgrade then
			setBar(bars[2], "Upgrades · all maxed here", 1, STATE.dashColors.ok)
		else
			setBar(bars[2], string.format("Next upgrade · %s %d · %s / %s", upgrade.name, upgrade.level + 1, shortNumber(cash), shortNumber(upgrade.price)), cash / math.max(1, upgrade.price), STATE.upgrade == true and STATE.dashColors.busy or STATE.dashColors.off)
		end
		local rod, rodCash = STATE.nextRod()
		if not rod then
			setBar(bars[3], "Rods · you have the best one here", 1, STATE.dashColors.ok)
		else
			setBar(bars[3], string.format("Next rod · %s · %s / %s", rod.name, shortNumber(rodCash), shortNumber(rod.price)), rodCash / math.max(1, rod.price), STATE.rod == true and STATE.dashColors.ok or STATE.dashColors.off)
		end
	end
	local toast = Instance.new("TextLabel")
	toast.Name = "ZinoosToast"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -130)
	toast.Size = UDim2.fromOffset(340, 36)
	toast.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	toast.BackgroundTransparency = 1
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 14
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.TextTransparency = 1
	toast.Text = ""
	toast.Visible = false
	toast.ZIndex = 50
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 10)
	toastCorner.Parent = toast
	local toastStroke = Instance.new("UIStroke")
	toastStroke.Color = STATE.dashColors.ok
	toastStroke.Thickness = 1.5
	toastStroke.Transparency = 1
	toastStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toastStroke.Parent = toast
	local queue = {}
	local showing = false
	local tweens = game:GetService("TweenService")
	local fadeInfo = TweenInfo.new(0.25)
	STATE.toast = function(text)
		if type(text) ~= "string" or text == "" or #queue >= 5 then
			return
		end
		queue[#queue + 1] = text
		if showing then
			return
		end
		showing = true
		task.spawn(function()
			elevate()
			while #queue > 0 and toast.Parent do
				toast.Text = table.remove(queue, 1)
				toast.Visible = true
				tweens:Create(toast, fadeInfo, { BackgroundTransparency = 0.05, TextTransparency = 0 }):Play()
				tweens:Create(toastStroke, fadeInfo, { Transparency = 0.2 }):Play()
				task.wait(3.5)
				tweens:Create(toast, fadeInfo, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
				tweens:Create(toastStroke, fadeInfo, { Transparency = 1 }):Play()
				task.wait(0.3)
			end
			toast.Visible = false
			showing = false
		end)
	end
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

function STATE.configPath()
	local id = LocalPlayer.UserId
	if type(id) == "number" and id > 0 then
		return "Rayfield/Configurations/ZinoosHub/DeepFishing_" .. tostring(id) .. ".rfld"
	end
	return CONFIG_PATH
end

local function loadSaved()
	local path = CONFIG_PATH
	if typeof(isfile) == "function" and isfile(STATE.configPath()) then
		path = STATE.configPath()
	end
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" or not isfile(path) then
		return
	end
	local ok, saved = pcall(function()
		return game:GetService("HttpService"):JSONDecode(readfile(path))
	end)
	if not ok or type(saved) ~= "table" then
		return
	end
	for flag, key in pairs(FLAG_KEYS) do
		if type(saved[flag]) == "boolean" then
			STATE[key] = saved[flag]
		end
	end
	if type(saved.SellAt) == "number" and saved.SellAt >= 1 then
		STATE.sellAt = saved.SellAt
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
		SellAt = STATE.sellAt,
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
	local ok, encoded = pcall(function()
		return game:GetService("HttpService"):JSONEncode(payload)
	end)
	if ok then
		pcall(writefile, STATE.configPath(), encoded)
	end
end
STATE.writeConfig = saveConfig

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

function STATE.themeStillCurrent()
	return running() and STATE._unloaded ~= true
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
	elevate()
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
	gui.Name = "ZinoosFishingMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 220
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local core = game:GetService("CoreGui")
	pcall(function()
		gui.Parent = core
	end)
	if (core == nil or gui.Parent ~= core) and typeof(gethui) == "function" then
		gui.Parent = gethui()
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
	dockGame.Text = STATE.admin and "Admin" or "Deep Fishing"
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
	brandSub.Text = "Deep Fishing"
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
	local discordPage = newPage("Settings")

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
		if name == "Settings" then
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
	addNav("Settings", 3)

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
	profileGame.Text = STATE.admin and "Admin" or "Deep Fishing"
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
				page = "Settings"
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
		elseif key == "autoReload" and STATE.applyAutoReload then
			STATE.applyAutoReload()
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

	local fishingCard = card(leftColumn, "FISHING", 1)
	makeSwitch(fishingCard, "Auto Fish", "autoFish", "Casts, steers the bait to fish and reels them in. Works below the Level 5 unlock")
	makeSwitch(fishingCard, "Perfect Casts", "perfect", "Faster casts, about three Perfect throws in four")

	local sellCard = card(leftColumn, "SELLING", 2)
	makeSwitch(sellCard, "Auto Sell", "sell", "Sells at the NPC between casts, then comes back")
	makeDropdown(sellCard, "Sell At", function()
		return tostring(STATE.sellAt) .. " fish"
	end, SELL_OPTIONS, function(option)
		local amount = tonumber(string.match(option, "%d+"))
		if amount then
			STATE.sellAt = amount
		end
		saveConfig()
	end, true)

	local screenCard = card(leftColumn, "SCREEN", 3)
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

	local upgrades = card(rightColumn, "UPGRADES", 1)
	makeSwitch(upgrades, "Auto Upgrade", "upgrade", "Buys the cheapest of Capacity, Strength, Weight and Bounce")
	makeSwitch(upgrades, "Auto Rod", "rod", "Buys and equips the best rod you can afford. Skips event rods")

	local general = card(rightColumn, "GENERAL", 2)
	makeSwitch(general, "Anti AFK", "antiAfk", "Stays in the game while you are idle")
	makeSwitch(general, "Auto-load on Rejoin", "autoReload", "Loads the newest hub again by itself after a rejoin or server hop")

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
	local blurb = label(intro, "Fishes for you, sells when the bag fills up, and spends the cash on upgrades and rods.", 14, muted, Enum.Font.Gotham, 36)
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
	local cashText = statChip(statGrid, "Cash", 1)
	cashText.Parent.Position = UDim2.fromOffset(0, 0)
	local levelText = statChip(statGrid, "Level", 2)
	levelText.Parent.Position = UDim2.new(0.5, 5, 0, 0)
	local bagText = statChip(statGrid, "Fish In Bag", 3)
	bagText.Parent.Position = UDim2.fromOffset(0, 68)
	local rodText = statChip(statGrid, "Rod", 4)
	rodText.Parent.Position = UDim2.new(0.5, 5, 0, 68)
	rodText.TextTruncate = Enum.TextTruncate.AtEnd

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

	do
		local sessionCard = card(homePage, "SESSION", 6)
		local sessionBody = label(sessionCard, "Reading your progress...", 13, ink, Enum.Font.Gotham, 90)
		sessionBody.LayoutOrder = 1
		sessionBody.AutomaticSize = Enum.AutomaticSize.Y
		sessionBody.Size = UDim2.new(1, 0, 0, 0)
		sessionBody.TextWrapped = true
		remember(sessionBody, sessionCard, "session stats progress per hour")
		STATE.refreshSessionStats = function()
			local lines = STATE.sessionLines and STATE.sessionLines()
			elevate()
			local text = lines and table.concat(lines, "\n") or "Reading your progress..."
			if sessionBody.Text ~= text then
				sessionBody.Text = text
			end
			sessionBody.TextColor3 = STATE.hubThemeDef().ink
		end
		local dashOk, dashErr = pcall(STATE.buildDashboard, gui, homePage, card, label)
		if not dashOk then
			STATE.refreshDashboard = nil
			STATE.noteFault("Dashboard", false, dashErr)
		end
	end

	local note = card(homePage, "HOW IT WORKS", 7)
	local noteBody = label(note, "Stand at the water with your rod out. Auto Fish casts and reels in, Auto Sell empties the bag at the sell NPC once it reaches Sell At, and the cash goes on upgrades and better rods.", 13, ink, Enum.Font.Gotham, 56)
	noteBody.LayoutOrder = 1

	local activityCard = card(homePage, "ACTIVITY", 8)
	local activityBody = label(activityCard, "Waiting for the next thing the hub does.", 13, muted, Enum.Font.Gotham, 72)
	activityBody.LayoutOrder = 1
	activityBody.AutomaticSize = Enum.AutomaticSize.Y
	activityBody.Size = UDim2.new(1, 0, 0, 0)
	activityBody.TextWrapped = true
	remember(activityBody, activityCard, "activity sold bought upgraded")
	local function refreshActivity()
		local lines = { "Status · " .. tostring(STATE.status) }
		local log = STATE.activity
		if type(log) == "table" and #log > 0 then
			lines[#lines + 1] = table.concat(log, "\n")
		end
		local text = table.concat(lines, "\n")
		elevate()
		if activityBody.Text ~= text then
			activityBody.Text = text
		end
		activityBody.TextColor3 = STATE.hubThemeDef().ink
	end
	STATE.refreshActivity = refreshActivity

	local function refreshTracker() end
	STATE.refreshTracker = nil

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
	local discordBlurb = label(discordMotion, "Your toggles save on their own and load next time. Right Ctrl opens and closes the hub.", 14, muted, Enum.Font.Gotham, 48)
	discordBlurb.LayoutOrder = 1
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

	local hubCard = card(discordPage, "HUB", 2)
	actionButton(hubCard, "Sell Now", 1, false, function()
		STATE.sellNow()
	end)
	actionButton(hubCard, "Unload", 2, true, function()
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
			current = "Settings"
		end
		if pages[current] then
			return
		end
		if pages.Home and not pages.Main and not pages.Discord then
			showPage("Home")
		elseif pages.Main and not pages.Home and not pages.Discord then
			showPage("Main")
		elseif pages.Discord and not pages.Home and not pages.Main then
			showPage("Settings")
		elseif pages.Home then
			showPage("Home")
		elseif pages.Main then
			showPage("Main")
		elseif pages.Discord then
			showPage("Settings")
		end
	end
	trackConnection(search:GetPropertyChangedSignal("Text"):Connect(applySearch))

	local function refreshHome()
		local data = readData()
		local cash = shortNumber((data and data.Cash) or 0)
		local level = tostring((data and data.Level) or 0)
		local bag = tostring(fishCount())
		local rod = tostring((data and data.RodEquipped) or "-")
		elevate()
		cashText.Text = cash
		levelText.Text = level
		bagText.Text = bag
		rodText.Text = rod
	end
	refreshHome()
	refreshTracker()
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
			pcall(refreshTracker)
			pcall(refreshActivity)
			if typeof(STATE.refreshSessionStats) == "function" then
				pcall(STATE.refreshSessionStats)
			end
			if typeof(STATE.refreshDashboard) == "function" then
				pcall(STATE.refreshDashboard)
			end
			if refreshHealth then
				pcall(refreshHealth)
			end
			pcall(refreshSession)
			task.wait(1)
		end
	end)

	local function applyLook()
		elevate()
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
		for index, name in ipairs({ "Home", "Main", "Settings" }) do
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
		if input.KeyCode == Enum.KeyCode.RightControl then
			setOpen(not holder.Visible)
		end
	end))

	local saveCard = card(homePage, "CONFIG", 10)
	local saveNote = label(saveCard, "Saves the toggles, Sell At, theme and hub size for this account. Your other account keeps its own save.", 13, muted, Enum.Font.Gotham, 40)
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

loadSaved()
STATE.applyAutoReload()

task.spawn(function()
	if not running() then
		return
	end
	local ok, err = xpcall(installHub, debug.traceback)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
	end
end)

task.spawn(function()
	while running() do
		STATE.watchFeature("Auto Fish", stepFish)
		task.wait(0.5)
	end
end)

task.spawn(function()
	while running() do
		STATE.watchFeature("Auto Sell", stepSell)
		task.wait(1)
		if not running() then
			break
		end
		STATE.watchFeature("Auto Rod", stepRod)
		task.wait(1)
		if not running() then
			break
		end
		STATE.watchFeature("Auto Upgrade", stepUpgrade)
		task.wait(1)
	end
end)
