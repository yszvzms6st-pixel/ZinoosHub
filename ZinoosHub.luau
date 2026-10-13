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
	local root = CoreGui:FindFirstChild("RobloxGui")
	if not root then
		return
	end
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("ScreenGui") and child:FindFirstChild("Zinoos hub") then
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

local activeGoal = nil

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
			local prompt = egg:FindFirstChild("StealPrompt", true)
			if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
				local mutation = egg:GetAttribute("Mutation")
				local petName = string.gsub(egg.Name, " Egg$", "")
				list[#list + 1] = {
					model = egg,
					prompt = prompt,
					pos = pos,
					rarity = rarityOfName[petName] or rarityOfName[egg.Name] or 0,
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

queueRare = function(kind, name, money)
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
	local stamp = kind .. "|" .. clean .. "|" .. rarity
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

local function installHub()
	closeLeftoverMenus()
	local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
	local window = Rayfield:CreateWindow({
		name = "Zinoos hub",
		subtitle = "Lift Rock",
		sidebarLayout = true,
		configuration = {
			autoSave = true,
			autoLoad = true,
			fileName = "ZinoosHub",
			customFolder = "ZinoosHub",
		},
	})
	STATE.hubWindow = window
	local tab = window:CreateTab({ name = "Main" })
	local toggles = {
		{ "Auto Train", "Bench for strength until max rebirth, then the treadmill.", "autoTrain", "AutoTrain" },
		{ "Auto Rebirth", "Rebirths when your strength is high enough.", "rebirth", "AutoRebirth" },
		{ "Auto Upgrade", "Buys the gym, floors, and basement you can afford.", "upgrade", "AutoUpgrade" },
		{ "Auto Trails", "Buys the best trail you can afford.", "trails", "AutoTrails" },
		{ "Auto Steal", "Grabs the rarest egg in the zone you pick the moment one is there.", "autoSteal", "AutoSteal" },
		{ "Auto Open", "Opens a placed egg when its timer is ready.", "autoOpen", "AutoOpen" },
		{ "Equip Best", "Equips your best pets when your animals change.", "equipBest", "EquipBest" },
		{ "Auto Daily", "Claims the daily reward when it is ready.", "autoDaily", "AutoDaily" },
		{ "Auto Index", "Claims index rewards you have unlocked.", "autoIndex", "AutoIndex" },
		{ "Free Stash", "Takes Brock's free stash card and leaves the paid ones.", "freeStash", "FreeStash" },
		{ "Lite Pets", "Hides pet models on your screen so the game runs lighter. Your pets stay saved.", "litePets", "LitePets" },
		{ "Egg ESP", "A small label with the egg name and cash per second.", "eggEsp", "EggEsp" },
		{ "Inventory ESP", "Shows what each bag pet earns, plus the bag total.", "invEsp", "InvEsp" },
		{ "Low End", "Turns graphics down and skips extra effects for phones and weaker PCs.", "lowEnd", "LowEnd" },
		{ "Webhook Alerts", "Sends a Discord message when you steal or hatch something rare.", "webhookOn", "WebhookAlerts" },
	}
	STATE.toggleControls = {}
	for _, item in ipairs(toggles) do
		local toggle = tab:CreateToggle({
			name = item[1],
			description = item[2],
			flag = item[4],
			value = STATE[item[3]] == true,
			callback = function(value)
				local on = value == true
				STATE[item[3]] = on
				if item[3] == "autoTrain" and not on then
					lastSwitchAt = 0
					releaseGym()
				elseif item[3] == "equipBest" and on then
					STATE.equipRoster = nil
				elseif item[3] == "lowEnd" then
					applyLowEnd(on)
				elseif item[3] == "invEsp" and not on then
					STATE._invShown = false
					clearInvEsp()
				end
			end,
		})
		STATE.toggleControls[item[3]] = toggle or window.controls[item[4]]
	end
	pcall(function()
		local options = {}
		for _, name in ipairs(Zones.Order) do
			options[#options + 1] = name
		end
		local dropdown = tab:CreateDropdown({
			name = "Steal Zone",
			description = "Only steals when an egg is in this zone.",
			options = options,
			currentOption = { STATE.stealZone or "Prehistoric" },
			flag = "StealZone",
			callback = function(value)
				STATE.stealZone = zoneChoice(value)
			end,
		})
		STATE.zoneControl = dropdown or window.controls.StealZone
	end)
	local sectionOk, sectionErr = pcall(function()
		tab:CreateSection({ name = "Discord" })
	end)
	if not sectionOk then
		warn("[Zinoos hub] discord section " .. tostring(sectionErr))
	end
	local inputOk, inputErr = pcall(function()
		local input = tab:CreateInput({
			name = "Discord Webhook",
			description = "Paste your Discord webhook here.",
			placeholder = "https://discord.com/api/webhooks/...",
			default = STATE.webhook or "",
			currentValue = STATE.webhook or "",
			flag = "WebhookUrl",
			callback = function(text)
				if type(text) == "string" then
					STATE.webhook = text
				end
			end,
		})
		STATE.webhookControl = input or window.controls.WebhookUrl
	end)
	if not inputOk then
		warn("[Zinoos hub] webhook box " .. tostring(inputErr))
	end
	local rarityOk, rarityErr = pcall(function()
		local options = { "Secret", "Eternal", "Divine", "Exclusive" }
		local dropdown = tab:CreateDropdown({
			name = "Alert Rarity",
			description = "Ping when the pet is this rarity or higher.",
			options = options,
			currentOption = { STATE.webhookRarity or "Divine" },
			flag = "WebhookRarity",
			callback = function(value)
				local picked = value
				if type(picked) == "table" then
					picked = picked[1]
				end
				if type(picked) == "string" and rarityRank[picked] then
					STATE.webhookRarity = picked
				end
			end,
		})
		STATE.rarityControl = dropdown or window.controls.WebhookRarity
	end)
	if not rarityOk then
		warn("[Zinoos hub] alert rarity " .. tostring(rarityErr))
	end
	local testOk, testErr = pcall(function()
		tab:CreateButton({
			name = "Test Webhook",
			description = "Sends a test message to the webhook you pasted.",
			callback = function()
				local url = webhookUrl()
				if not url then
					return
				end
				task.spawn(function()
					local okEncode, body = pcall(function()
						return game:GetService("HttpService"):JSONEncode({
							username = "Zinoos hub",
							content = "Webhook connected. You'll get a ping when a rare pet is stolen or hatches.",
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
			end,
		})
	end)
	if not testOk then
		warn("[Zinoos hub] test webhook " .. tostring(testErr))
	end
	local unloadOk, unloadErr = pcall(function()
		tab:CreateButton({
			name = "Unload",
			description = "Stops the hub and removes everything it added.",
			callback = function()
				task.defer(unloadHub)
			end,
		})
	end)
	if not unloadOk then
		warn("[Zinoos hub] unload button " .. tostring(unloadErr))
	end
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
