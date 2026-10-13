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
local existingHub = CoreGui:FindFirstChild("ZinoosHub")
if existingHub then
	local okGenv, genvEarly = pcall(getgenv)
	genvEarly = okGenv and typeof(genvEarly) == "table" and genvEarly or nil
	local saved = genvEarly and genvEarly.STATE or nil
	local replace = (typeof(STATE) == "table" and STATE._replaceHub == true)
		or (typeof(saved) == "table" and saved._replaceHub == true)
		or (genvEarly and genvEarly.ZinoosReplace == true)
	if replace then
		existingHub:Destroy()
		if typeof(STATE) == "table" then
			STATE._replaceHub = false
		end
		if typeof(saved) == "table" then
			saved._replaceHub = false
		end
		if genvEarly then
			genvEarly.ZinoosReplace = false
		end
	else
		warn("[Zinoos hub] Already running.")
		return
	end
end
local hubMarker = Instance.new("Folder")
hubMarker.Name = "ZinoosHub"
hubMarker.Parent = CoreGui

do
	local genv = getgenv()
	local injected = typeof(STATE) == "table" and STATE or nil
	local shared = typeof(genv.STATE) == "table" and genv.STATE or nil
	if shared then
		if injected and injected ~= shared then
			if typeof(injected.onCleanup) == "function" then
				shared.onCleanup = injected.onCleanup
			end
			if typeof(injected.connect) == "function" then
				shared.connect = injected.connect
			end
			if typeof(injected.override) == "function" then
				shared.override = injected.override
			end
		end
		STATE = shared
	elseif not injected then
		STATE = {}
	end
	genv.STATE = STATE
end

local function closeLeftoverMenus()
	for _, child in ipairs(CoreGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Name == "ZinoosHubMenu" then
			child:Destroy()
		end
	end
	local root = CoreGui:FindFirstChild("RobloxGui")
	if not root then
		return
	end
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("ScreenGui") and (child.Name == "ZinoosHubMenu" or child:FindFirstChild("Zinoos hub")) then
			child:Destroy()
		end
	end
end

local function stopOlderCopies()
	if typeof(filtergc) == "function" then
		local ok, copies = pcall(filtergc, "table", { Keys = { "stealZone", "_gen", "autoSteal" } }, false)
		if ok and type(copies) == "table" then
			for _, copy in ipairs(copies) do
				if copy ~= STATE then
					copy._alive = false
					copy._gen = -1
					local window = rawget(copy, "hubWindow")
					if type(window) == "table" and type(window.Unload) == "function" then
						pcall(window.Unload, window)
					end
				end
			end
		end
	end
	closeLeftoverMenus()
end

stopOlderCopies()

local LocalPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
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
local netFireServer = STATE and STATE._rawNetFire
if typeof(netFireServer) ~= "function" then
	netFireServer = unwrapNetFire(Net.FireServer)
	if typeof(STATE) == "table" and typeof(netFireServer) == "function" then
		STATE._rawNetFire = netFireServer
	end
end
Net.FireServer = function(self, remoteName, ...)
	if remoteName == "LeaveBench" and not allowLeaveBench() then
		return
	end
	return netFireServer(self, remoteName, ...)
end
local Rebirths = require(Shared.Configs.Rebirths)
local Gym = require(Shared.Configs.Gym)
local Plot = require(Shared.Configs.Plot)
local Trails = require(Shared.Configs.Trails)
local Pets = require(Shared.Configs.Pets)
local Rarities = require(Shared.Configs.Rarities)
local Wild = require(Shared.Configs.Wild)
local Zones = require(Shared.Configs.Zones)
local DailyRewards = require(Shared.Configs.DailyRewards)
local Format = require(Shared.Format)
local Grades = require(Shared.Configs.Grades)
local ClientRegistry = require(LocalPlayer:WaitForChild("PlayerScripts").Client.Lib.ClientRegistry)

local LOOK_POS = Vector3.new(190, 8, -6420)
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
local rarityRank = {}
for index, name in ipairs(Rarities.Order) do
	rarityRank[name] = index
end
local mutationRank = { None = 0, Golden = 1, Diamond = 2, Rainbow = 3, Cursed = 4 }
local rarityOfName = {}
local weightOfName = {}
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
local rarityByDisplay = {}
for _, spec in pairs(Pets.Specs) do
	if type(spec) == "table" and type(spec.DisplayName) == "string" and type(spec.Rarity) == "string" then
		rarityByDisplay[spec.DisplayName] = spec.Rarity
	end
end
local queueRare

local ON_COLOR = Color3.fromRGB(255, 65, 65)
local OFF_TRACK = Color3.fromRGB(100, 100, 100)
local OFF_INNER = Color3.fromRGB(20, 20, 20)
local STRENGTH_SECONDS = 20
local SPEED_SECONDS = 8

do
	local genv = getgenv()
	if typeof(STATE) ~= "table" then
		STATE = typeof(genv.STATE) == "table" and genv.STATE or {}
		genv.STATE = STATE
	end
	if typeof(STATE.alive) ~= "function" then
		STATE._alive = true
		function STATE.alive()
			return STATE._alive == true
		end
	end
	if typeof(STATE.connect) ~= "function" then
		STATE._connections = {}
		function STATE.connect(signal, fn)
			local connection = signal:Connect(fn)
			table.insert(STATE._connections, connection)
			return connection
		end
	end
	if typeof(STATE.onCleanup) ~= "function" then
		STATE._cleanups = {}
		function STATE.onCleanup(fn)
			table.insert(STATE._cleanups, fn)
		end
	end
	if typeof(STATE.override) ~= "function" then
		function STATE.override(tbl, key, value)
			tbl[key] = value
		end
	end
end

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
if type(STATE.webhook) ~= "string" then
	STATE.webhook = ""
end
if rarityRank[STATE.webhookRarity] == nil then
	STATE.webhookRarity = "Divine"
end
if type(STATE.stealZone) ~= "string" or FLOORS[STATE.stealZone] == nil then
	STATE.stealZone = "Prehistoric"
end
local genv = getgenv()
genv.ZinoosGen = (typeof(genv.ZinoosGen) == "number" and genv.ZinoosGen or 0) + 1
local token = genv.ZinoosGen
STATE._alive = false
STATE._gen = math.floor(os.clock() * 1000)
local myGen = STATE._gen
task.wait(2)
local function running()
	return genv.ZinoosGen == token and STATE._gen == myGen
end
STATE.alive = running

STATE.liftSteal = false
STATE.stealing = false
STATE.stealGoal = nil
STATE.nextSteal = 0
STATE.stashGen = (STATE.stashGen or 0) + 1
local stashGen = STATE.stashGen
Net:OnClient("BrockStashStart", function(payload)
	if STATE.stashGen ~= stashGen or type(payload) ~= "table" or type(payload.cards) ~= "table" then
		return
	end
	STATE.stashCards = payload.cards
	STATE.stashTaken = {}
	for index = 1, tonumber(payload.stage) or 0 do
		STATE.stashTaken[index] = true
	end
end)
Net:OnClient("BrockStashState", function(payload)
	if STATE.stashGen ~= stashGen or type(payload) ~= "table" then
		return
	end
	for key in pairs(payload.taken or {}) do
		local index = tonumber(key)
		if index then
			STATE.stashTaken[index] = true
		end
	end
end)
Net:OnClient("BrockStashEnd", function()
	if STATE.stashGen ~= stashGen then
		return
	end
	STATE.stashCards = nil
	STATE.stashTaken = {}
end)

local added = {}
local lastRebirthAt = 0
local lastSwitchAt = 0
local popped = setmetatable({}, { __mode = "k" })

local function setToggleVisual(row, on)
	local track = row:FindFirstChildWhichIsA("ImageLabel")
	if not track then
		return
	end
	local inner = track:FindFirstChildWhichIsA("ImageLabel")
	local knob = track:FindFirstChildWhichIsA("Frame")
	track.ImageColor3 = if on then ON_COLOR else OFF_TRACK
	if inner then
		inner.ImageColor3 = if on then ON_COLOR else OFF_INNER
	end
	if knob then
		knob.Size = if on then UDim2.new(1, -8, 1, -8) else UDim2.new(0, 0, 1, -8)
	end
end

local function addRow(menu, template, label, key, order)
	local row = template:Clone()
	row.Name = "Codex" .. key
	row.Text = " " .. label
	row.LayoutOrder = order
	row.Active = true
	row.Parent = menu
	setToggleVisual(row, STATE[key] == true)
	table.insert(added, row)
	STATE.connect(row.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		STATE[key] = not STATE[key]
		setToggleVisual(row, STATE[key] == true)
	end)
end

local function contentHeight(menu)
	local height = 0
	for _, child in ipairs(menu:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, 5) ~= "Codex" then
			height += child.Size.Y.Offset
		end
	end
	return height
end

local function installUi()
	local gui = CoreGui:FindFirstChild("ToraScript")
	local title = gui and gui:FindFirstChildWhichIsA("ImageButton")
	local menu = title and title:FindFirstChild("Frame")
	if not menu then
		return false
	end
	if menu:FindFirstChild("Codextrain") and menu:FindFirstChild("Codexupgrade") and menu:FindFirstChild("Codextrails") then
		return true
	end

	for _, child in ipairs(menu:GetChildren()) do
		if string.sub(child.Name, 1, 5) == "Codex" then
			child:Destroy()
		end
	end
	table.clear(added)

	local template = nil
	local youtube = nil
	for _, child in ipairs(menu:GetChildren()) do
		if child:IsA("TextLabel") and string.find(child.Text, "Auto Hatch", 1, true) then
			template = child
		elseif child:IsA("TextLabel") and string.find(child.Text, "YouTube", 1, true) then
			youtube = child
		end
	end
	if not template then
		return false
	end

	local order = 1
	for _, child in ipairs(menu:GetChildren()) do
		if child:IsA("GuiObject") and child ~= youtube then
			child.LayoutOrder = order
			order += 1
		end
	end

	local height = contentHeight(menu)
	local labels = {
		{ "Auto Train", "autoTrain" },
		{ "Auto Rebirth", "rebirth" },
		{ "Auto Upgrade", "upgrade" },
		{ "Auto Trails", "trails" },
	}
	for _, item in ipairs(labels) do
		addRow(menu, template, item[1], item[2], order)
		order += 1
	end
	if youtube then
		youtube.LayoutOrder = order
	end
	menu.Size = UDim2.new(1, 0, 0, height + 31 * #labels)
	return true
end

local function installOwnMenu()
	if CoreGui:FindFirstChild("CodexLiftRock") then
		return true
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CodexLiftRock"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = CoreGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	panel.BorderSizePixel = 0
	panel.Position = UDim2.new(0, 12, 0.35, 0)
	panel.Size = UDim2.fromOffset(230, 196)
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "LIFT ROCK"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Parent = panel

	local rows = {
		{ "Auto Train", "autoTrain" },
		{ "Auto Rebirth", "rebirth" },
		{ "Auto Upgrade", "upgrade" },
		{ "Auto Trails", "trails" },
	}
	for index, item in ipairs(rows) do
		local button = Instance.new("TextButton")
		button.Name = "Codex" .. item[2]
		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		button.Font = Enum.Font.GothamBold
		button.Text = "  " .. item[1]
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextSize = 14
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Position = UDim2.fromOffset(8, 32 + (index - 1) * 32)
		button.Size = UDim2.new(1, -16, 0, 30)
		button.Parent = panel
		local mark = Instance.new("Frame")
		mark.Name = "Mark"
		mark.AnchorPoint = Vector2.new(1, 0.5)
		mark.Position = UDim2.new(1, -4, 0.5, 0)
		mark.Size = UDim2.fromOffset(18, 18)
		mark.BorderSizePixel = 0
		mark.Parent = button
		local markCorner = Instance.new("UICorner")
		markCorner.CornerRadius = UDim.new(0, 4)
		markCorner.Parent = mark
		local function paint()
			mark.BackgroundColor3 = STATE[item[2]] == true and ON_COLOR or OFF_TRACK
		end
		paint()
		button.MouseButton1Click:Connect(function()
			STATE[item[2]] = not STATE[item[2]]
			paint()
		end)
		table.insert(added, button)
	end

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.Font = Enum.Font.Gotham
	note.Text = "Steal waits for a Prehistoric egg"
	note.TextColor3 = Color3.fromRGB(180, 180, 180)
	note.TextSize = 12
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.Position = UDim2.fromOffset(12, 164)
	note.Size = UDim2.new(1, -20, 0, 22)
	note.Parent = panel
	table.insert(added, gui)
	return true
end

local hubCleanups = {}
local function hubCleanup(fn)
	table.insert(hubCleanups, fn)
	STATE.onCleanup(fn)
end

local function unloadHub()
	if STATE._unloaded then
		return
	end
	STATE._unloaded = true
	local genv = getgenv()
	genv.ZinoosGen = (typeof(genv.ZinoosGen) == "number" and genv.ZinoosGen or 0) + 1
	STATE._gen = -1
	STATE._alive = false
	for index = #hubCleanups, 1, -1 do
		pcall(hubCleanups[index])
	end
end

hubCleanup(function()
	if typeof(netFireServer) == "function" then
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
	local own = CoreGui:FindFirstChild("CodexLiftRock")
	if own then
		own:Destroy()
	end
	if hubMarker.Parent then
		hubMarker:Destroy()
	end
	local live = workspace:FindFirstChild("Live")
	if live then
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
			elseif child:GetAttribute("ZinoosHid") == true then
				child.Enabled = true
				child:SetAttribute("ZinoosHid", nil)
			end
		end
	end
	local hubWindow = STATE.hubWindow
	if hubWindow then
		pcall(function()
			hubWindow:Unload()
		end)
		STATE.hubWindow = nil
	end
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

task.defer(function()
	local notifications = ClientRegistry.TryGet("NotificationController")
	if not notifications then
		return
	end
	local show = notifications.Show
	STATE.override(notifications, "Show", function(self, text, kind, gradient)
		if hideBestNotice(text) then
			return
		end
		return show(self, text, kind, gradient)
	end)
	clearBestNotices()
end)

local function readData()
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
	local data = readData()
	local maxed = data ~= nil and Rebirths[(data.rebirths or 0) + 1] == nil
	STATE.trainFocus = maxed and "speed" or "strength"
end

local function releaseGym()
	if LocalPlayer:GetAttribute("Benching") then
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

local function stepTrain()
	if STATE.liftSteal then
		releaseGym()
		local character = LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and activeGoal then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = activeGoal
			task.defer(function()
				if STATE.liftSteal and hrp.Parent and activeGoal then
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.CFrame = activeGoal
				end
			end)
		end
		return
	end
	if STATE.autoTrain ~= true then
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
	if STATE.rebirth ~= true then
		return
	end
	local data = readData()
	if not data then
		return
	end
	local nextTier = Rebirths[(data.rebirths or 0) + 1]
	if not nextTier then
		return
	end
	if (data.strength or 0) < nextTier.StrengthRequirement then
		return
	end
	if os.clock() - lastRebirthAt < 4 then
		return
	end
	lastRebirthAt = os.clock()
	Net:FireServer("RequestRebirth")
end

local function stepUpgrade()
	if STATE.upgrade ~= true then
		return
	end
	local data = readData()
	if not data then
		return
	end
	local cash = data.cash or 0
	if data.gymOwned ~= true then
		if cash >= Gym.UnlockCost then
			Net:InvokeServer("BuyGym")
		end
		return
	end
	local level = Gym.LevelOf(data.gymLevel)
	if level < #Gym.Levels and cash >= Gym.Levels[level + 1].Price then
		Net:InvokeServer("UpgradeGym")
		return
	end
	local nextFloor = (data.baseLevel or 0) + 1
	if nextFloor <= Plot.MaxLevel and cash >= Plot.FloorPrice(nextFloor) then
		Net:InvokeServer("BuyFloorLevel", nextFloor)
		return
	end
	local nextBasement = (data.basementLevel or 0) + 1
	if nextBasement <= Plot.MaxBasementLevel and cash >= Plot.BasementPrice(nextBasement) then
		Net:InvokeServer("BuyBasementLevel", nextBasement)
	end
end

local function stepTrails()
	if STATE.trails ~= true then
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
	if buyName then
		Net:FireServer("BuyTrail", buyName)
		return
	end
	if bestOwned and data.trail ~= bestOwned then
		Net:FireServer("EquipTrail", bestOwned)
	end
end

local prehistoricEggs

local function eggSpot()
	local eggs = prehistoricEggs()
	if eggs[1] and eggs[1].model.Parent then
		STATE.lastEggPos = eggs[1].model:GetPivot().Position
		return STATE.lastEggPos + Vector3.new(0, 4, 0)
	end
	if typeof(STATE.lastEggPos) == "Vector3" then
		return STATE.lastEggPos + Vector3.new(0, 4, 0)
	end
	return Vector3.new(171, 8, -6451)
end

local function homeSpot()
	local gym = myGym()
	local bench = gym and gym:FindFirstChild("Bench")
	local seat = bench and bench:FindFirstChild("Seat")
	if seat then
		STATE.homePos = seat.Position + Vector3.new(0, 6, 0)
	end
	return STATE.homePos or Vector3.new(299, 10, 314)
end

local function placeOneEgg()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	local tool = character:FindFirstChildWhichIsA("Tool")
	if not (tool and tool:GetAttribute("isEgg") and tool:GetAttribute("petUID")) then
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		tool = nil
		if backpack then
			for _, child in ipairs(backpack:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("isEgg") and child:GetAttribute("petUID") then
					tool = child
					break
				end
			end
		end
		if not tool then
			return false
		end
		humanoid:EquipTool(tool)
		task.wait(0.15)
	end
	local uid = tool:GetAttribute("petUID")
	if not uid then
		return false
	end
	local plot = ClientRegistry.Get("PlotController"):GetPlot(LocalPlayer)
	local base = plot and plot:FindFirstChild("Base")
	if not (base and base:IsA("BasePart")) then
		return false
	end
	local x = (math.random() - 0.5) * math.min(base.Size.X * 0.35, 16)
	local z = (math.random() - 0.5) * math.min(base.Size.Z * 0.35, 16)
	Net:FireServer("PlacePet", uid, x, z)
	task.wait(0.4)
	return tool.Parent == nil
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
		if not placeOneEgg() then
			return true
		end
	end
	return LocalPlayer:GetAttribute("holdingFriend") ~= true
end

local function stealZone()
	local name = STATE.stealZone
	if type(name) == "string" and FLOORS[name] then
		return name
	end
	return "Prehistoric"
end

local function zoneChoice(value)
	if type(value) == "table" then
		value = value[1]
	end
	if type(value) == "string" and FLOORS[value] then
		return value
	end
	return "Prehistoric"
end

local spottedEggs = {}

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

local function eggRank(model)
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

local function scanPoints(zone)
	local floor = FLOORS[zone or stealZone()] or FLOORS.Prehistoric
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
	local zone = stealZone()
	local live = workspace:FindFirstChild("Live")
	local folder = live and live:FindFirstChild("Friends")
	if not folder then
		return {}
	end
	local list = {}
	for _, egg in ipairs(folder:GetChildren()) do
		if egg:IsA("Model") and egg:GetAttribute("SpawnZone") == zone then
			local pos = egg:GetPivot().Position
			if not inZone(pos, zone) then
				continue
			end
			local bonusId = egg:GetAttribute("BonusRock")
			if type(bonusId) == "string" and not rockIsLifted(bonusId) then
				continue
			end
			local prompt = egg:FindFirstChild("StealPrompt", true)
			local rank = eggRank(egg)
			if rank >= alertRank() and prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled and prompt.MaxActivationDistance > 0 then
				local spotKey = string.format("%d:%d:%s", math.floor(pos.X), math.floor(pos.Z), egg.Name)
				if not spottedEggs[spotKey] and queueRare then
					spottedEggs[spotKey] = true
					queueRare("Rare egg", egg.Name, nil, "spot|" .. spotKey)
				end
				local mutation = egg:GetAttribute("Mutation")
				local petName = string.gsub(egg.Name, " Egg$", "")
				list[#list + 1] = {
					model = egg,
					prompt = prompt,
					pos = pos,
					rarity = rank,
					weight = weightOfName[petName] or weightOfName[egg.Name] or 999,
					mutation = mutationRank[tostring(mutation)] or 0,
				}
			end
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

local activeGoal = nil

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

local function placeHeldPet()
	return deliverHeld()
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
	if LocalPlayer:GetAttribute("holdingFriend") == true then
		return true
	end
	local function scan(container)
		if not container then
			return false
		end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("isEgg") and child:GetAttribute("petUID") then
				return true
			end
		end
		return false
	end
	return scan(LocalPlayer:FindFirstChild("Backpack")) or scan(LocalPlayer.Character)
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

local function runStealTrip()
	if STATE.autoSteal ~= true then
		return
	end
	if hasEggTool() and os.clock() >= (STATE.nextPlace or 0) then
		STATE.liftSteal = true
		deliverHeld()
		STATE.liftSteal = false
		STATE.stealGoal = nil
		if hasEggTool() then
			STATE.nextPlace = os.clock() + 8
		end
		return
	end
	if os.clock() < (STATE.nextSteal or 0) then
		return
	end
	local target = peekPrehistoric()
	if not target or not target.model.Parent then
		STATE.liftSteal = false
		STATE.stealGoal = nil
		activeGoal = nil
		LocalPlayer:SetAttribute("CodexMode", "train")
		STATE.nextSteal = os.clock() + 8
		return
	end
	STATE.liftSteal = true
	STATE.stealGoal = nil
	LocalPlayer:SetAttribute("CodexMode", "steal")
	homeSpot()
	local grabbed = false
	local stolenName = target.model.Name
	local releaseLimit = os.clock() + 0.6
	while not releaseGym() and os.clock() < releaseLimit and running() do
		task.wait(0.1)
	end
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if hrp and target.model.Parent and target.prompt and target.prompt.Parent then
		target.prompt.HoldDuration = 0
		target.prompt.RequiresLineOfSight = false
		if target.prompt.MaxActivationDistance < 20 then
			target.prompt.MaxActivationDistance = 20
		end
		for _, part in ipairs(target.model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
		if humanoid then
			humanoid.PlatformStand = false
			humanoid.Sit = false
		end
		local stand = target.model:GetPivot().Position + Vector3.new(0, 4, 0)
		activeGoal = CFrame.new(stand)
		STATE.stealGoal = activeGoal
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = activeGoal
		local grabUntil = os.clock() + 0.8
		while os.clock() < grabUntil and running() and target.prompt.Parent do
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = activeGoal
			fireproximityprompt(target.prompt)
			if LocalPlayer:GetAttribute("holdingFriend") == true then
				grabbed = true
				break
			end
			task.wait(0.1)
		end
		grabbed = grabbed or LocalPlayer:GetAttribute("holdingFriend") == true
	end
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local carryingEgg = LocalPlayer:GetAttribute("holdingFriend") == true
	if backpack and not carryingEgg then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("isEgg") then
				carryingEgg = true
				break
			end
		end
	end
	if grabbed or carryingEgg then
		deliverHeld()
	end
	LocalPlayer:SetAttribute("CodexMode", "train")
	LocalPlayer:SetAttribute("CodexStolen", grabbed and 1 or 0)
	LocalPlayer:SetAttribute("CodexStealName", stolenName)
	if grabbed and queueRare then
		queueRare("Stolen egg", stolenName)
	end
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	homeSpot()
	if hrp and typeof(STATE.homePos) == "Vector3" and (hrp.Position - STATE.homePos).Magnitude > 80 then
		STATE.liftSteal = true
		activeGoal = CFrame.new(STATE.homePos)
		STATE.stealGoal = activeGoal
		hrp.CFrame = activeGoal
		task.wait(0.35)
	end
	activeGoal = nil
	STATE.liftSteal = false
	STATE.stealGoal = nil
	STATE.nextSteal = os.clock() + (grabbed and 12 or 3)
end

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
			trigger.CanTouch = false
		end
	end
end

local function stepDaily()
	if STATE.autoDaily ~= true then
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
	if claimed[tostring(day)] == true or claimed[day] == true then
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
	if STATE.autoIndex ~= true then
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
	if STATE.freeStash ~= true then
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
for _, spec in pairs(Pets.Specs) do
	if type(spec) == "table" and type(spec.DisplayName) == "string" and type(spec.Income) == "number" and not spec.IsEgg then
		eggValue[spec.DisplayName] = spec.Income
		eggValue[spec.DisplayName .. " Egg"] = spec.Income
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
	return model.Name .. "  $" .. Format.Short(income) .. "/s"
end

local function webhookUrl()
	local url = type(STATE.webhook) == "string" and STATE.webhook or ""
	url = string.match(url, "^%s*(https://%S+)%s*$") or ""
	if not string.find(url, "/api/webhooks/", 1, true) then
		return nil
	end
	return url
end

queueRare = function(kind, name, money, mark)
	if STATE.webhookOn == false or STATE._unloaded then
		return
	end
	local url = webhookUrl()
	if not url then
		return
	end
	local clean = string.gsub(tostring(name), " Egg$", "")
	local rarity = rarityByDisplay[clean] or ""
	local minRank = rarityRank[STATE.webhookRarity] or rarityRank.Divine or 1
	if (rarityRank[rarity] or 0) < minRank then
		return
	end
	if type(money) ~= "string" or money == "" then
		for _, spec in pairs(Pets.Specs) do
			if type(spec) == "table" and spec.DisplayName == clean and type(spec.Income) == "number" then
				money = "$" .. Format.Short(spec.Income) .. "/s"
				break
			end
		end
	end
	local stamp = mark or (kind .. "|" .. clean .. "|" .. rarity)
	local now = os.clock()
	if STATE._hookStamp == stamp and now - (STATE._hookAt or 0) < 12 then
		return
	end
	STATE._hookStamp = stamp
	STATE._hookAt = now
	task.spawn(function()
		local okEncode, body = pcall(function()
			return game:GetService("HttpService"):JSONEncode({
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
		if not okEncode then
			return
		end
		pcall(request, {
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = body,
		})
	end)
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
	if model:GetAttribute("ZinoosLite") == true then
		return
	end
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
	if not liteHooked[model] then
		liteHooked[model] = true
		STATE.connect(model.DescendantAdded, function(child)
			if STATE.litePets == true then
				hideOne(child)
			end
		end)
	end
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
		elseif child:GetAttribute("ZinoosHid") == true then
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

local savedQuality
pcall(function()
	savedQuality = settings().Rendering.QualityLevel
end)
local savedShadows = Lighting.GlobalShadows
local bloomEffect = Lighting:FindFirstChildOfClass("BloomEffect")
local sunEffect = Lighting:FindFirstChildOfClass("SunRaysEffect")
local savedBloom = bloomEffect and bloomEffect.Enabled == true
local savedSun = sunEffect and sunEffect.Enabled == true
local savedAnim
local savedInterp
pcall(function()
	savedAnim = workspace.ClientAnimatorThrottling
end)
pcall(function()
	savedInterp = workspace.InterpolationThrottling
end)

local function applyLowEnd(on)
	local low = on == true
	pcall(function()
		if low then
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		elseif savedQuality ~= nil then
			settings().Rendering.QualityLevel = savedQuality
		end
	end)
	Lighting.GlobalShadows = (not low) and savedShadows
	if bloomEffect then
		bloomEffect.Enabled = (not low) and savedBloom
	end
	if sunEffect then
		sunEffect.Enabled = (not low) and savedSun
	end
	pcall(function()
		if low then
			workspace.ClientAnimatorThrottling = Enum.ClientAnimatorThrottlingMode.Enabled
			workspace.InterpolationThrottling = Enum.InterpolationThrottlingMode.Enabled
		else
			if savedAnim ~= nil then
				workspace.ClientAnimatorThrottling = savedAnim
			end
			if savedInterp ~= nil then
				workspace.InterpolationThrottling = savedInterp
			end
		end
	end)
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
	local row = Rebirths[rebirths]
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
	local spec = Pets.Specs[pet.key]
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
	local ok, base = pcall(Pets.IncomeFor, pet)
	base = ok and type(base) == "number" and base or 0
	local level, grade = 1, 1
	pcall(function()
		level = Plot.PetLevelMultiplier(pet.level) or 1
	end)
	pcall(function()
		grade = Grades.Multiplier(pet.grade) or 1
	end)
	local amount = base * level * grade * cash
	incomeByUid[uid] = {
		sig = sig,
		amount = amount,
		text = "$" .. Format.Short(amount) .. "/s",
	}
	return amount
end

local function ensureInvGui()
	if invGui and invGui.Parent and invLabel and invLabel.Parent then
		invGui.Enabled = true
		return invLabel
	end
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
	if STATE.invEsp ~= true then
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
	local text = "Bag  $" .. Format.Short(total) .. "/s"
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
	applyLowEnd(false)
	clearInvEsp()
	if invGui then
		invGui:Destroy()
		invGui = nil
		invLabel = nil
	end
end)

local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/ZinoosHub.rfld"

local FLAG_KEYS = {
	AutoTrain = "autoTrain",
	AutoRebirth = "rebirth",
	AutoUpgrade = "upgrade",
	AutoTrails = "trails",
	AutoSteal = "autoSteal",
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
}

local function loadSaved()
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" or not isfile(CONFIG_PATH) then
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
	STATE.autoSell = false
	local zone = saved.StealZone
	if type(zone) == "table" then
		zone = zone[1]
	end
	if type(zone) == "string" then
		STATE.stealZone = zoneChoice(zone)
	end
	local rarity = saved.WebhookRarity
	if type(rarity) == "table" then
		rarity = rarity[1]
	end
	if type(rarity) == "string" and rarityRank[rarity] then
		STATE.webhookRarity = rarity
	end
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
	applyLowEnd(STATE.lowEnd == true)
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
		AutoSell = false,
		StealZone = { STATE.stealZone or "Prehistoric" },
		WebhookRarity = { STATE.webhookRarity or "Divine" },
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
		pcall(writefile, CONFIG_PATH, encoded)
	end
end

local function installHub()
	closeLeftoverMenus()
	loadSaved()

	local accent = Color3.fromRGB(255, 79, 158)
	local ink = Color3.fromRGB(245, 240, 248)
	local muted = Color3.fromRGB(176, 160, 190)
	local panel = Color3.fromRGB(24, 18, 32)
	local side = Color3.fromRGB(32, 24, 42)
	local cardColor = Color3.fromRGB(40, 30, 52)
	local off = Color3.fromRGB(62, 48, 76)
	local line = Color3.fromRGB(70, 52, 86)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ZinoosHubMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 220
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = CoreGui

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local function fitScale()
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local scale = math.min(view.X / 760, view.Y / 540, 1)
		uiScale.Scale = math.clamp(scale, 0.62, 1)
	end
	fitScale()

	local launcher = Instance.new("TextButton")
	launcher.Name = "Zinoos hub"
	launcher.AutoButtonColor = false
	launcher.Text = "Zinoos"
	launcher.Font = Enum.Font.GothamBold
	launcher.TextSize = 14
	launcher.TextColor3 = ink
	launcher.BackgroundColor3 = panel
	launcher.Size = UDim2.fromOffset(92, 36)
	launcher.Position = UDim2.new(1, -110, 0.62, 0)
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
		pages[name] = page
		return page
	end

	local homePage = newPage("Home")
	local mainPage = newPage("Main")
	local discordPage = newPage("Discord")

	local function showPage(name)
		for pageName, page in pairs(pages) do
			page.Visible = pageName == name
		end
		pageTitle.Text = name
		for buttonName, button in pairs(navButtons) do
			button.BackgroundTransparency = buttonName == name and 0 or 1
		end
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
		button.MouseButton1Click:Connect(function()
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
		searchRows[#searchRows + 1] = { row = row, card = cardFrame, text = string.lower(text) }
	end

	local function paintSwitch(track, knob, on)
		track.BackgroundColor3 = on and accent or off
		knob.Position = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
	end

	local function onToggle(key, on)
		STATE[key] = on
		if key == "autoTrain" and not on then
			lastSwitchAt = 0
			releaseGym()
		elseif key == "equipBest" and on then
			STATE.equipRoster = nil
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
		row.Size = UDim2.new(1, 0, 0, hint and 40 or 30)
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
			note.TextXAlignment = Enum.TextXAlignment.Left
			note.Position = UDim2.fromOffset(0, 18)
			note.Size = UDim2.new(1, -52, 0, 16)
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
		paintSwitch(track, knob, control.value)
		track.MouseButton1Click:Connect(function()
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
	popup.Visible = false
	popup.ZIndex = 21
	popup.AutomaticSize = Enum.AutomaticSize.Y
	popup.Size = UDim2.fromOffset(180, 0)
	popup.Parent = window
	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 10)
	popupCorner.Parent = popup
	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = line
	popupStroke.Parent = popup
	local popupLayout = Instance.new("UIListLayout")
	popupLayout.Parent = popup
	local popupPad = Instance.new("UIPadding")
	popupPad.PaddingTop = UDim.new(0, 4)
	popupPad.PaddingBottom = UDim.new(0, 4)
	popupPad.Parent = popup

	local function closePopup()
		popup.Visible = false
		popupBlock.Visible = false
		for _, child in ipairs(popup:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end
	popupBlock.MouseButton1Click:Connect(closePopup)

	local function openPopup(anchor, options, current, callback)
		closePopup()
		for _, option in ipairs(options) do
			local choice = Instance.new("TextButton")
			choice.AutoButtonColor = false
			choice.BackgroundColor3 = option == current and Color3.fromRGB(64, 36, 58) or Color3.fromRGB(32, 24, 44)
			choice.BackgroundTransparency = option == current and 0 or 1
			choice.Text = "  " .. option
			choice.Font = Enum.Font.Gotham
			choice.TextSize = 13
			choice.TextColor3 = ink
			choice.TextXAlignment = Enum.TextXAlignment.Left
			choice.Size = UDim2.new(1, 0, 0, 28)
			choice.ZIndex = 22
			choice.Parent = popup
			choice.MouseButton1Click:Connect(function()
				callback(option)
				closePopup()
			end)
		end
		local scale = uiScale.Scale
		if scale <= 0 then
			scale = 1
		end
		local origin = window.AbsolutePosition
		local pos = anchor.AbsolutePosition
		local height = anchor.AbsoluteSize.Y
		popup.Position = UDim2.fromOffset((pos.X - origin.X) / scale, (pos.Y - origin.Y + height + 6) / scale)
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
		pick.MouseButton1Click:Connect(function()
			openPopup(pick, options, getValue(), function(option)
				callback(option)
				pick.Text = getValue()
			end)
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
		value = STATE.webhookRarity,
		currentOption = { STATE.webhookRarity or "Divine" },
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
	makeSwitch(eggs, "Auto Steal", "autoSteal", "Teleports onto a rare egg, then comes back")
	local zoneOptions = {}
	for _, zoneName in ipairs(Zones.Order) do
		zoneOptions[#zoneOptions + 1] = zoneName
	end
	if #zoneOptions == 0 then
		zoneOptions[1] = "Prehistoric"
	end
	makeDropdown(eggs, "Steal Zone", function()
		return STATE.stealZone or "Prehistoric"
	end, zoneOptions, function(option)
		STATE.stealZone = zoneChoice(option)
		STATE.zoneControl.value = STATE.stealZone
		STATE.zoneControl.currentOption = { STATE.stealZone }
		saveConfig()
	end)
	makeDropdown(eggs, "Alert Rarity", function()
		return STATE.webhookRarity or "Divine"
	end, { "Secret", "Eternal", "Divine", "Exclusive" }, function(option)
		if rarityRank[option] then
			STATE.webhookRarity = option
			STATE.rarityControl.value = option
			STATE.rarityControl.currentOption = { option }
			saveConfig()
		end
	end)

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
	local blurb = label(homePage, "Stays on your bench. Teleports onto a rare egg, grabs it, and comes back.", 14, muted, Enum.Font.Gotham, 36)
	blurb.LayoutOrder = 2
	local statGrid = Instance.new("Frame")
	statGrid.BackgroundTransparency = 1
	statGrid.LayoutOrder = 3
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

	local note = card(homePage, "HOW IT WORKS", 4)
	local noteBody = label(note, "Alert Rarity decides which eggs are worth standing up for. Weaker eggs leave you training. Nothing here sells pets.", 13, ink, Enum.Font.Gotham, 48)
	noteBody.LayoutOrder = 1

	local discordBlurb = label(discordPage, "Get a Discord message when a rare egg shows up, when you steal it, and when it hatches.", 14, muted, Enum.Font.Gotham, 40)
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
		button.MouseButton1Click:Connect(callback)
		remember(button, parentFrame, text)
		return button
	end

	actionButton(discordCard, "Test Webhook", 4, false, function()
		local url = webhookUrl()
		if not url then
			return
		end
		task.spawn(function()
			local okEncode, body = pcall(function()
				return game:GetService("HttpService"):JSONEncode({
					username = "Zinoos hub",
					content = "Webhook connected. You'll get a ping when a rare egg shows up, is stolen, or hatches.",
				})
			end)
			if okEncode then
				pcall(request, {
					Url = url,
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = body,
				})
			end
		end)
	end)
	actionButton(discordCard, "Unload", 5, true, function()
		task.defer(unloadHub)
	end)

	local function applySearch()
		local query = string.lower(search.Text)
		local used = {}
		for _, item in ipairs(searchRows) do
			local show = query == "" or string.find(item.text, query, 1, true) ~= nil
			item.row.Visible = show
			if show then
				used[item.card] = true
			end
		end
		for _, item in ipairs(searchRows) do
			item.card.Visible = used[item.card] == true or query == ""
		end
		if query ~= "" and not mainPage.Visible and not discordPage.Visible then
			showPage("Main")
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(applySearch)

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
		strengthText.Text = Format.Short(strength or 0)
		cashText.Text = "$" .. Format.Short((data and data.cash) or 0)
		rebirthText.Text = tostring(rebirths or 0)
		speedText.Text = Format.Short(speed or 0)
	end
	refreshHome()
	task.spawn(function()
		while running() and gui.Parent do
			if homePage.Visible then
				pcall(refreshHome)
			end
			task.wait(1)
		end
	end)

	showPage("Home")

	local function viewSize()
		local camera = workspace.CurrentCamera
		return camera and camera.ViewportSize or Vector2.new(1280, 720)
	end

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

	local function setOpen(open)
		holder.Visible = open
		shadow.Visible = open
		launcher.Visible = not open
	end

	local dragConn = UserInputService.InputChanged:Connect(function(input)
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
	end)
	local dragEndConn = UserInputService.InputEnded:Connect(function(input)
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
	end)

	closeButton.MouseButton1Click:Connect(function()
		if not STATE.dockCustom then
			local spot = holder.AbsolutePosition
			placeTopLeft(launcher, spot.X + 16, spot.Y + 16)
		end
		setOpen(false)
	end)

	local keyConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or search:IsFocused() or urlBox:IsFocused() then
			return
		end
		if input.KeyCode == Enum.KeyCode.RightControl then
			setOpen(not holder.Visible)
		end
	end)

	STATE.hubWindow = {
		Unload = function()
			if keyConn then
				keyConn:Disconnect()
			end
			if dragConn then
				dragConn:Disconnect()
			end
			if dragEndConn then
				dragEndConn:Disconnect()
			end
			if gui.Parent then
				gui:Destroy()
			end
		end,
	}
end

task.spawn(function()
	if not running() then
		return
	end
	local ok, err = pcall(installHub)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
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
		local ok, err = pcall(runStealTrip)
		if not ok then
			STATE.stealError = tostring(err)
			STATE.liftSteal = false
			STATE.stealGoal = nil
			STATE.nextSteal = os.clock() + 2
			warn("[Zinoos hub] steal " .. tostring(err))
		end
		task.wait(0.6)
	end
end)

local openTried = {}

local function stepOpenEggs()
	if STATE.autoOpen ~= true then
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
			local last = openTried[uid]
			if not last or os.clock() - last > 3 then
				openTried[uid] = os.clock()
				Net:FireServer("OpenEgg", uid)
				sent += 1
			end
		elseif openTried[uid] then
			openTried[uid] = nil
		end
	end
end

local lastEquipAt = 0

local function addHatched(parts, pets, prefix)
	if type(pets) ~= "table" then
		return
	end
	for uid, pet in pairs(pets) do
		if type(pet) == "table" and pet.hatchAt == nil then
			parts[#parts + 1] = table.concat({
				prefix,
				tostring(uid),
				tostring(pet.key),
				tostring(pet.mutation),
				tostring(pet.weight),
			}, ":")
		end
	end
end

local function rosterSignature()
	local parts = {}
	local data = readData()
	addHatched(parts, data and data.plotPets, "plot")
	addHatched(parts, data and data.backpack, "bag")
	if #parts == 0 then
		local live = workspace:FindFirstChild("Live")
		local owned = live and live:FindFirstChild("PlayerFriends")
		owned = owned and owned:FindFirstChild(LocalPlayer.Name)
		if owned then
			for _, model in ipairs(owned:GetChildren()) do
				if model:IsA("Model") and model:GetAttribute("incubating") ~= true then
					parts[#parts + 1] = model.Name .. ":" .. tostring(model:GetAttribute("renderId"))
				end
			end
		end
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

local nextIncomeCheck = 0

local function backpackBeatsPlot()
	local now = os.clock()
	if now < nextIncomeCheck then
		return false
	end
	nextIncomeCheck = now + 4
	local data = readData()
	if not data then
		return false
	end
	local bestBag = 0
	local worstPlot = math.huge
	local anyPlot = false
	local function scan(list, fromBag)
		if type(list) ~= "table" then
			return
		end
		for _, pet in pairs(list) do
			if type(pet) == "table" and pet.hatchAt == nil then
				local ok, income = pcall(Pets.IncomeFor, pet)
				income = ok and income or 0
				if fromBag then
					if income > bestBag then
						bestBag = income
					end
				else
					anyPlot = true
					if income < worstPlot then
						worstPlot = income
					end
				end
			end
		end
	end
	scan(data.backpack, true)
	scan(data.plotPets, false)
	if not anyPlot then
		return bestBag > 0
	end
	return bestBag > worstPlot
end

local function shownIncome(pet)
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
	local row = Rebirths[rebirths]
	local cash = type(row) == "table" and row.CashMulti or 1
	if type(cash) ~= "number" then
		cash = 1
	end
	return base * level * grade * cash
end

local function stepEquipBest()
	if STATE.equipBest ~= true then
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
			local spec = Pets.Specs[pet.key]
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
			local spec = Pets.Specs[pet.key]
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
	task.spawn(function()
		Net:FireServer("EquipBestPets")
		if not (pickupUid and best > worst) then
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
		Net:FireServer("PlacePet", placeUid, x, z)
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
			elseif key == "equipBest" and control.value == true then
				STATE.equipRoster = nil
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
	if type(rareControl) == "table" then
		local picked = rareControl.value or rareControl.currentOption
		if type(picked) == "table" then
			picked = picked[1]
		end
		if type(picked) == "string" and rarityRank[picked] and picked ~= STATE.webhookRarity then
			STATE.webhookRarity = picked
		end
	end
end

local function pullHomeIfEmpty()
	if not running() then
		return
	end
	local eggs = prehistoricEggs()
	if STATE.liftSteal and eggs[1] and eggs[1].model.Parent then
		return
	end
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	if hrp.Position.Z > -4000 and not inZone(hrp.Position, stealZone()) then
		return
	end
	STATE.liftSteal = false
	STATE.stealing = false
	STATE.stealGoal = nil
	activeGoal = nil
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(homeSpot())
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
			local money = Format.Short(shownIncome(pet))
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
					local spec = Pets.Specs[pet.key]
					if spec and not spec.IsEgg and queueRare then
						queueRare("Hatched", spec.DisplayName or spec.Name or pet.key, "$" .. Format.Short(shownIncome(pet)) .. "/s")
					end
				end
			end
		end
	end
	walk(data.plotPets)
	walk(data.backpack)
	petsReady = true
end

loadSaved()

local nextBubble = 0
STATE.connect(RunService.Heartbeat, function()
	if not running() then
		return
	end
	STATE.train = false
	STATE.stealing = false
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
