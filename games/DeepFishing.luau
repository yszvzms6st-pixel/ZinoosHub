-- Zinoos hub for Deep Fishing.
-- Auto Fish drives the game's own AutoFishing controller (skips its Level 5 gate).
-- Perfect Casts makes it cast like the AutoBoost enchant: faster, mostly Perfect, some Good.
-- Auto Sell hops to the sell NPC, sells, and hops back between casts.
-- Auto Upgrade buys the cheapest upgrade. Auto Rod buys and equips the best affordable rod.

local Players = game:GetService("Players")
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
local SELL_OPTIONS = { "30", "60", "100", "200" }
local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/DeepFishing.rfld"

-- One copy at a time: a new run stops the old one first.
if typeof(genv.ZinoosFishingStop) == "function" then
	pcall(genv.ZinoosFishingStop)
end
genv.ZinoosFishingGen = (typeof(genv.ZinoosFishingGen) == "number" and genv.ZinoosFishingGen or 0) + 1
local token = genv.ZinoosFishingGen
local function running()
	return genv.ZinoosFishingGen == token
end

-- Calling into the game's own code drops this thread's identity, and CoreGui then reads as nil.
-- Raise it again before touching the hub.
local function elevate()
	if typeof(setthreadidentity) == "function" then
		pcall(setthreadidentity, 8)
	end
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
genv.ZinoosFishingStop = shutdownHub
if typeof(STATE) == "table" and typeof(STATE.onCleanup) == "function" then
	STATE.onCleanup(shutdownHub)
end

local settings = {
	autoFish = true,
	perfect = true,
	sell = true,
	sellAt = 60,
	upgrade = true,
	rod = true,
	antiAfk = true,
}

local FLAG_KEYS = {
	AutoFish = "autoFish",
	PerfectCasts = "perfect",
	AutoSell = "sell",
	AutoUpgrade = "upgrade",
	AutoRod = "rod",
	AntiAfk = "antiAfk",
}

local layout = {}

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
			settings[key] = saved[flag]
		end
	end
	if type(saved.SellAt) == "number" then
		settings.sellAt = saved.SellAt
	end
	for _, key in ipairs({ "MenuX", "MenuY", "DockX", "DockY" }) do
		if type(saved[key]) == "number" then
			layout[key] = saved[key]
		end
	end
	layout.DockCustom = saved.DockCustom == true
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
		SellAt = settings.sellAt,
		MenuX = layout.MenuX,
		MenuY = layout.MenuY,
		DockX = layout.DockX,
		DockY = layout.DockY,
		DockCustom = layout.DockCustom == true,
	}
	for flag, key in pairs(FLAG_KEYS) do
		payload[flag] = settings[key] == true
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if ok then
		pcall(writefile, CONFIG_PATH, encoded)
	end
end

loadSaved()

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
local selling = false
local fishSpot = nil
local status = "Starting"
local stats = { caught = 0, sold = 0, earned = 0, casts = 0 }

local function readData()
	local ok, data = pcall(function()
		return AF.PlayerData:Get()
	end)
	return ok and data or nil
end

local function shortNumber(value)
	local ok, text = pcall(function()
		return AF.Vendors.MoneyLib.HandleMoney(value)
	end)
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
	if running() and settings.perfect then
		return math.max(real or 0, PERFECT_CHANCE)
	end
	return real
end
AF.DriveCast = function(self, fishing)
	if running() and selling then
		return
	end
	if running() then
		stats.casts += 1
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
		stats.caught += if fish.Name then 1 else #fish
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
	if not settings.autoFish then
		if AF.On then
			AF:SetOn(false)
		end
		status = "Idle"
		return
	end
	if selling then
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
	status = busy() and "Fishing" or "Casting"
end

local function stepSell()
	if not settings.sell or selling or busy() then
		return
	end
	if fishCount() < settings.sellAt then
		return
	end
	local npc = interactable("NPC_Sell")
	local hrp = hrpOf()
	if not npc or not hrp then
		return
	end
	selling = true
	status = "Selling"
	local back = fishSpot or hrp.CFrame
	local pivot = npc:GetPivot()
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(pivot.Position + pivot.LookVector * 6 + Vector3.new(0, 2, 0))
	task.wait(0.35)
	local ok, result = pcall(function()
		return AF.Events.Client("SellAll"):Invoke(5, "Fish", nil)
	end)
	if ok and type(result) == "table" then
		stats.sold += tonumber(result.Amount) or 0
		stats.earned += tonumber(result.Value) or 0
	end
	hrp = hrpOf()
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = back
	end
	task.wait(0.3)
	selling = false
end

local function stepRod()
	if not settings.rod or busy() or selling then
		return
	end
	local data = readData()
	if not data then
		return
	end
	local Rod = AF.Content.Item.Rod
	local current = Rod:Get(data.RodEquipped or "Wooden Rod", true)
	local bestOwned, bestOwnedStrength = nil, current and current.Strength or 0
	local bestBuy, bestBuyStrength = nil, bestOwnedStrength
	for name, rod in pairs(Rod.Items) do
		if type(rod) == "table" and (rod.LayoutOrder or 0) < 100 and not rod.MazeOnly and not rod.CaveOnly and not rod.VolcanoOnly then
			local locked = Rod:LockedBehind(rod, data)
			local cursed = AF.Config.EventGearConfig.CursedHere(data, name)
			if not locked and not cursed then
				local strength = rod.Strength or 0
				if data.Rods[name] then
					if strength > bestOwnedStrength then
						bestOwned, bestOwnedStrength = name, strength
					end
				elseif (rod.Price or 0) <= (data.Cash or 0) and strength > bestBuyStrength then
					bestBuy, bestBuyStrength = name, strength
				end
			end
		end
	end
	if bestBuy and bestBuyStrength > bestOwnedStrength then
		status = "Buying " .. bestBuy
		AF.Events.Client("RodShop"):Fire(true, "Buy", bestBuy)
		task.wait(1)
		AF.Events.Client("RodShop"):Fire(true, "Equip", bestBuy)
		task.wait(0.8)
		equipRod()
	elseif bestOwned then
		AF.Events.Client("RodShop"):Fire(true, "Equip", bestOwned)
		task.wait(0.8)
		equipRod()
	end
end

local function stepUpgrade()
	if not settings.upgrade then
		return
	end
	local data = readData()
	if not data then
		return
	end
	local U = AF.Config.UpgradesConfig
	local key = U.KeyForData(data)
	local cheapest, cheapestPrice = nil, math.huge
	for _, name in ipairs(U.Order) do
		local level = U.LevelOf(data, name, key)
		if level < U.MaxLevelFor(name, key) then
			local ok, price = pcall(U.GetPrice, name, level, key)
			if ok and type(price) == "number" and price < cheapestPrice then
				cheapest, cheapestPrice = name, price
			end
		end
	end
	if cheapest and cheapestPrice <= (data.Cash or 0) then
		AF.Events.Client("Upgrades"):Fire(true, "Buy", cheapest)
	end
end

local antiAfkMethod = nil
local function pulseAntiAfk()
	if not running() or settings.antiAfk ~= true then
		return false
	end
	local userOk = pcall(function()
		local virtual = game:GetService("VirtualUser") :: any
		virtual:CaptureController()
		virtual:ClickButton2(Vector2.new(-1, -1))
	end)
	local moveOk = pcall(function()
		local input = game:GetService("VirtualInputManager") :: any
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local x = math.clamp(view.X * 0.5, 1, math.max(1, view.X - 1))
		local y = math.clamp(view.Y * 0.92, 1, math.max(1, view.Y - 1))
		input:SendMouseMoveEvent(x, y, game)
		input:SendMouseMoveEvent(x + 2, y, game)
		input:SendMouseMoveEvent(x, y, game)
	end)
	antiAfkMethod = if moveOk then "VirtualInputManager" elseif userOk then "VirtualUser" else nil
	return antiAfkMethod ~= nil
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
hubCleanup(destroyMenus)

local function installHub()
	elevate()
	destroyMenus()

	local accent = Color3.fromRGB(255, 79, 158)
	local ink = Color3.fromRGB(245, 240, 248)
	local muted = Color3.fromRGB(176, 160, 190)
	local panel = Color3.fromRGB(24, 18, 32)
	local side = Color3.fromRGB(32, 24, 42)
	local cardColor = Color3.fromRGB(40, 30, 52)
	local off = Color3.fromRGB(62, 48, 76)
	local line = Color3.fromRGB(70, 52, 86)

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
	brandSub.Text = "Deep Fishing"
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
		local pageLayout = Instance.new("UIListLayout")
		pageLayout.Padding = UDim.new(0, 10)
		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		pageLayout.Parent = page
		pages[name] = page
		return page
	end

	local homePage = newPage("Home")
	local mainPage = newPage("Main")
	local settingsPage = newPage("Settings")

	local function showPage(name)
		for pageName, page in pairs(pages) do
			page.Visible = pageName == name
		end
		pageTitle.Text = name
		for buttonName, button in pairs(navButtons) do
			button.BackgroundTransparency = buttonName == name and 0 or 1
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
	addNav("Settings", 3)

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
	profileGame.Text = "Deep Fishing"
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
		local page = "Main"
		local current = row
		while current do
			if current == settingsPage then
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

	local function paintSwitch(track, knob, on)
		track.BackgroundColor3 = on and accent or off
		knob.Position = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
	end

	local function onToggle(key, on)
		settings[key] = on
		if key == "antiAfk" and on then
			task.defer(pulseAntiAfk)
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
		paintSwitch(track, knob, settings[key] == true)
		onActivate(track, function()
			local on = not (settings[key] == true)
			paintSwitch(track, knob, on)
			onToggle(key, on)
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

	local function openPopup(anchor, options, current, callback)
		closePopup()
		local rowHeight = 28
		local selectedIndex = 1
		for index, option in ipairs(options) do
			local on = option == current
			if on then
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
			choice.BackgroundColor3 = on and Color3.fromRGB(64, 36, 58) or Color3.fromRGB(32, 24, 44)
			choice.BackgroundTransparency = on and 0 or 1
			choice.Text = (on and "  ✓ " or "    ") .. option
			choice.Parent = popupScroll
			onActivate(choice, function()
				callback(option)
				closePopup()
			end)
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
		popup.Size = UDim2.fromOffset(180, popupHeight)
		popupScroll.CanvasSize = UDim2.fromOffset(0, contentHeight)
		local openAbove = roomBelow + 1 < popupPixels and roomAbove > roomBelow
		local pixelY = openAbove and (anchorPos.Y - popupPixels - 6) or (anchorPos.Y + anchorHeight + 6)
		pixelY = math.clamp(pixelY, 8, math.max(8, view.Y - popupPixels - 8))
		local pixelX = math.clamp(anchorPos.X, 8, math.max(8, view.X - 180 * scale - 8))
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

	local function makeDropdown(parentBox, name, getValue, options, callback)
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
		title.Size = UDim2.new(0.48, 0, 1, 0)
		title.ZIndex = 6
		title.Parent = row
		local pick = Instance.new("TextButton")
		pick.AutoButtonColor = false
		pick.Font = Enum.Font.Gotham
		pick.TextSize = 13
		pick.TextColor3 = ink
		pick.Text = getValue()
		pick.BackgroundColor3 = Color3.fromRGB(28, 20, 38)
		pick.AnchorPoint = Vector2.new(1, 0.5)
		pick.Position = UDim2.new(1, 0, 0.5, 0)
		pick.Size = UDim2.fromOffset(132, 26)
		pick.ZIndex = 7
		pick.Parent = row
		local pickCorner = Instance.new("UICorner")
		pickCorner.CornerRadius = UDim.new(0, 8)
		pickCorner.Parent = pick
		onActivate(pick, function()
			openPopup(pick, options, getValue(), function(option)
				callback(option)
				pick.Text = getValue()
			end)
		end)
		remember(row, parentBox, name)
		return pick
	end

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
		local frameLayout = Instance.new("UIListLayout")
		frameLayout.Padding = UDim.new(0, 10)
		frameLayout.SortOrder = Enum.SortOrder.LayoutOrder
		frameLayout.Parent = frame
		return frame
	end
	local leftColumn = column(1)
	local rightColumn = column(2)

	local fishingCard = card(leftColumn, "FISHING", 1)
	makeSwitch(fishingCard, "Auto Fish", "autoFish", "Casts, steers to fish and reels in for you")
	makeSwitch(fishingCard, "Perfect Casts", "perfect", "Faster casts, mostly Perfect throws")

	local sellCard = card(leftColumn, "SELLING", 2)
	makeSwitch(sellCard, "Auto Sell", "sell", "Sells at the NPC between casts, then comes back")
	makeDropdown(sellCard, "Sell At", function()
		return tostring(settings.sellAt) .. " fish"
	end, SELL_OPTIONS, function(option)
		settings.sellAt = tonumber(option) or settings.sellAt
		saveConfig()
	end)

	local upgradesCard = card(rightColumn, "UPGRADES", 1)
	makeSwitch(upgradesCard, "Auto Upgrade", "upgrade")
	makeSwitch(upgradesCard, "Auto Rod", "rod", "Buys and equips the best rod you can afford")

	local miscCard = card(rightColumn, "MISC", 2)
	makeSwitch(miscCard, "Anti AFK", "antiAfk", "Stays in the game while you are idle")

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
		chipValue.TextTruncate = Enum.TextTruncate.AtEnd
		chipValue.Position = UDim2.fromOffset(12, 26)
		chipValue.Size = UDim2.new(1, -20, 0, 24)
		chipValue.ZIndex = 6
		chipValue.Parent = chip
		return chipValue
	end

	local welcome = label(homePage, "Welcome", 22, ink, Enum.Font.GothamBold, 28)
	welcome.LayoutOrder = 1
	local blurb = label(homePage, "Fishes for you, sells when the bag fills up, and spends the cash on upgrades and rods.", 14, muted, Enum.Font.Gotham, 36)
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
	local cashText = statChip(statGrid, "Cash", 1)
	cashText.Parent.Position = UDim2.fromOffset(0, 0)
	local levelText = statChip(statGrid, "Level", 2)
	levelText.Parent.Position = UDim2.new(0.5, 5, 0, 0)
	local bagText = statChip(statGrid, "Fish In Bag", 3)
	bagText.Parent.Position = UDim2.fromOffset(0, 68)
	local rodText = statChip(statGrid, "Rod", 4)
	rodText.Parent.Position = UDim2.new(0.5, 5, 0, 68)

	local trackerCard = card(homePage, "SESSION", 5)
	local trackerStatus = label(trackerCard, "Starting...", 13, muted, Enum.Font.Gotham, 78)
	trackerStatus.LayoutOrder = 1
	remember(trackerStatus, trackerCard, "session status fish caught sold")

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

	local settingsBlurb = label(settingsPage, "Your toggles save on their own and load next time. Right Ctrl opens and closes the hub.", 14, muted, Enum.Font.Gotham, 40)
	settingsBlurb.LayoutOrder = 1
	local hubCard = card(settingsPage, "HUB", 2)
	actionButton(hubCard, "Sell Now", 1, false, function()
		task.spawn(function()
			local saved = settings.sellAt
			settings.sellAt = 1
			while running() and busy() do
				task.wait(0.2)
			end
			pcall(stepSell)
			settings.sellAt = saved
		end)
	end)
	actionButton(hubCard, "Unload", 2, true, function()
		task.defer(shutdownHub)
	end)

	local function applySearch()
		local query = string.lower(search.Text)
		local used = {}
		local found = {}
		for _, item in ipairs(searchRows) do
			local show = query == "" or string.find(item.text, query, 1, true) ~= nil
			item.row.Visible = show
			if show and query ~= "" then
				used[item.card] = true
				found[item.page or "Main"] = true
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
		elseif settingsPage.Visible then
			current = "Settings"
		end
		if found[current] then
			return
		end
		for _, name in ipairs({ "Main", "Home", "Settings" }) do
			if found[name] then
				showPage(name)
				return
			end
		end
	end
	trackConnection(search:GetPropertyChangedSignal("Text"):Connect(applySearch))

	local function refreshHome()
		local data = readData()
		local cash = shortNumber((data and data.Cash) or 0)
		local level = tostring((data and data.Level) or 0)
		local bag = tostring(fishCount())
		local rod = tostring((data and data.RodEquipped) or "-")
		local lines = {
			"Status: " .. status,
			string.format("%d casts · %d fish caught", stats.casts, stats.caught),
			string.format("%d sold for %s", stats.sold, shortNumber(stats.earned)),
		}
		if settings.antiAfk then
			lines[#lines + 1] = antiAfkMethod and ("Anti AFK working through " .. antiAfkMethod) or "Anti AFK requested but unavailable"
		end
		elevate()
		cashText.Text = cash
		levelText.Text = level
		bagText.Text = bag
		rodText.Text = rod
		trackerStatus.Text = table.concat(lines, "\n")
		trackerStatus.TextColor3 = (status == "Fishing" or status == "Casting") and accent or muted
	end
	local function refreshSession()
		elevate()
		local clockText = sessionClock()
		sessionText.Text = "Session " .. clockText
		launcher.Text = "Zinoos  " .. clockText
	end
	refreshHome()
	refreshSession()
	task.spawn(function()
		while running() and gui.Parent do
			pcall(refreshHome)
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
		layout[keyX] = pos.X / view.X
		layout[keyY] = pos.Y / view.Y
		saveConfig()
	end

	local function refit()
		fitScale()
		task.defer(function()
			if gui.Parent then
				clampObject(holder)
				clampObject(launcher)
			end
		end)
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
		if type(layout.MenuX) == "number" and type(layout.MenuY) == "number" then
			placeTopLeft(holder, layout.MenuX * view.X, layout.MenuY * view.Y)
			clampObject(holder)
		end
		if layout.DockCustom and type(layout.DockX) == "number" and type(layout.DockY) == "number" then
			placeTopLeft(launcher, layout.DockX * view.X, layout.DockY * view.Y)
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

	local function setOpen(open)
		holder.Visible = open
		shadow.Visible = open
		launcher.Visible = not open
	end

	trackConnection(UserInputService.InputChanged:Connect(function(input)
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
	trackConnection(UserInputService.InputEnded:Connect(function(input)
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
				rememberSpot(holder, "MenuX", "MenuY")
			else
				layout.DockCustom = true
				rememberSpot(launcher, "DockX", "DockY")
			end
			return
		end
		if target == launcher then
			setOpen(true)
		end
	end))

	onActivate(closeButton, function()
		if not layout.DockCustom then
			local spot = holder.AbsolutePosition
			placeTopLeft(launcher, spot.X + 16, spot.Y + 16)
		end
		setOpen(false)
	end)

	trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or search:IsFocused() then
			return
		end
		if input.KeyCode == Enum.KeyCode.RightControl then
			setOpen(not holder.Visible)
		end
	end))
end

task.spawn(function()
	local ok, err = xpcall(installHub, debug.traceback)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
	end
end)

task.spawn(function()
	while running() do
		pcall(stepFish)
		task.wait(0.5)
	end
end)

task.spawn(function()
	while running() do
		pcall(stepSell)
		task.wait(1)
		if not running() then
			break
		end
		pcall(stepRod)
		task.wait(1)
		if not running() then
			break
		end
		pcall(stepUpgrade)
		task.wait(1)
	end
end)
