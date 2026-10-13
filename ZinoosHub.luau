-- Zinoos hub for Lift Rock For Eggs.
-- The bench grants strength. The treadmill grants speed.
-- Strength only, until rebirth is maxed. After that, the treadmill only.
-- Rebirth, gym/floor/basement upgrades, and the best affordable trail use the game's own remotes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if game.PlaceId ~= 76731343328034 then
	warn("[Zinoos hub] This only runs in Lift Rock For Eggs.")
	return
end
local existingHub = CoreGui:FindFirstChild("ZinoosHub")
if existingHub then
	if typeof(STATE) == "table" and STATE._replaceHub == true then
		existingHub:Destroy()
		STATE._replaceHub = false
	else
		warn("[Zinoos hub] Already running.")
		return
	end
end
local hubMarker = Instance.new("Folder")
hubMarker.Name = "ZinoosHub"
hubMarker.Parent = CoreGui

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
if STATE.autoSell == nil then
	STATE.autoSell = true
end
if STATE.autoDaily == nil then
	STATE.autoDaily = true
end
if STATE.autoIndex == nil then
	STATE.autoIndex = true
end
if STATE.freeStash == nil then
	STATE.freeStash = true
end
if type(STATE.stealZone) ~= "string" or FLOORS[STATE.stealZone] == nil then
	STATE.stealZone = "Prehistoric"
end
STATE._alive = false
STATE._gen = (STATE._gen or 0) + 1
local myGen = STATE._gen
task.wait(2)
local function running()
	return STATE._gen == myGen
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

STATE.onCleanup(function()
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
		if hrp and typeof(STATE.stealGoal) == "CFrame" then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = STATE.stealGoal
			task.defer(function()
				if STATE.liftSteal and hrp.Parent and typeof(STATE.stealGoal) == "CFrame" then
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.CFrame = STATE.stealGoal
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
	STATE.stealGoal = CFrame.new(homeSpot())
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
				list[#list + 1] = {
					model = egg,
					prompt = prompt,
					pos = pos,
					rarity = rarityOfName[egg.Name] or 0,
					weight = weightOfName[egg.Name] or 999,
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
	LocalPlayer:SetAttribute("CodexMode", "steal")
	homeSpot()
	local grabbed = false
	local stolenName = target.model.Name
	local stand = target.model:GetPivot().Position + Vector3.new(0, 4, 0)
	STATE.stealGoal = CFrame.new(stand)
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = STATE.stealGoal
	end
	for _ = 1, 12 do
		if not running() then
			break
		end
		if releaseGym() then
			break
		end
		task.wait(0.2)
	end
	for _ = 1, 6 do
		if not running() or STATE.autoSteal ~= true or grabbed then
			break
		end
		if not target.model.Parent then
			break
		end
		stolenName = target.model.Name
		STATE.stealGoal = CFrame.new(target.model:GetPivot().Position + Vector3.new(0, 4, 0))
		task.wait(0.3)
		local character = LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local dist = hrp and (target.model:GetPivot().Position - hrp.Position).Magnitude or 999
		if dist <= 18 and target.prompt.Parent then
			fireproximityprompt(target.prompt)
			task.wait(0.45)
			grabbed = LocalPlayer:GetAttribute("holdingFriend") == true
		end
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
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	homeSpot()
	if hrp and typeof(STATE.homePos) == "Vector3" and (hrp.Position - STATE.homePos).Magnitude > 80 then
		STATE.liftSteal = true
		STATE.stealGoal = CFrame.new(STATE.homePos)
		task.wait(0.35)
	end
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

local function petIncome(pet)
	local ok, income = pcall(Pets.IncomeFor, pet)
	if ok and type(income) == "number" then
		return income
	end
	return 0
end

local function stepSellWeak()
	if STATE.autoSell ~= true then
		return
	end
	if os.clock() < (STATE.nextSell or 0) then
		return
	end
	local data = readData()
	if not data then
		return
	end
	local worst = math.huge
	local anyPlot = false
	for _, pet in pairs(data.plotPets or {}) do
		if type(pet) == "table" and pet.hatchAt == nil then
			local spec = Pets.Specs[pet.key]
			if not (spec and spec.IsEgg) then
				anyPlot = true
				worst = math.min(worst, petIncome(pet))
			end
		end
	end
	if not anyPlot then
		return
	end
	local victim = nil
	local victimIncome = math.huge
	for _, pet in pairs(data.backpack or {}) do
		if type(pet) == "table" and pet.uid and pet.hatchAt == nil then
			local spec = Pets.Specs[pet.key]
			if not (spec and spec.IsEgg) then
				local income = petIncome(pet)
				if income < worst and income < victimIncome then
					victim = pet
					victimIncome = income
				end
			end
		end
	end
	if not victim then
		return
	end
	STATE.nextSell = os.clock() + 0.4
	Net:FireServer("SellPet", victim.uid)
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

local function installHub()
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
		{ "Auto Steal", "Takes the rarest egg in the zone you pick, only when one is there.", "autoSteal", "AutoSteal" },
		{ "Auto Open", "Opens a placed egg when its timer is ready.", "autoOpen", "AutoOpen" },
		{ "Equip Best", "Equips your best pets when your animals change.", "equipBest", "EquipBest" },
		{ "Auto Sell Weak", "Sells stored pets that earn less than the ones on your plot.", "autoSell", "AutoSell" },
		{ "Auto Daily", "Claims the daily reward when it is ready.", "autoDaily", "AutoDaily" },
		{ "Auto Index", "Claims index rewards you have unlocked.", "autoIndex", "AutoIndex" },
		{ "Free Stash", "Takes Brock's free stash card and leaves the paid ones.", "freeStash", "FreeStash" },
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
		pcall(runStealTrip)
		task.wait(1)
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

local function stepEquipBest()
	if STATE.equipBest ~= true then
		return
	end
	local signature = rosterSignature()
	local better = backpackBeatsPlot()
	if not better and (signature == "" or signature == STATE.equipRoster) then
		return
	end
	if os.clock() - lastEquipAt < 0.2 then
		return
	end
	lastEquipAt = os.clock()
	STATE.equipRoster = signature
	Net:FireServer("EquipBestPets")
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
			end
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
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(homeSpot())
end

local nextBubble = 0
STATE.connect(RunService.Heartbeat, function()
	if not running() then
		return
	end
	STATE.train = false
	STATE.stealing = false
	syncToggles()
	stepTrain()
	task.defer(function()
		task.defer(pullHomeIfEmpty)
	end)
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
	pcall(stepSellWeak)
	pcall(stepDaily)
	pcall(stepIndex)
	pcall(stepStash)
end)
