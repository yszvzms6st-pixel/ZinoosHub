-- Zinoos hub for Barber Empire.
-- Same WindUI window as the other Zinoos games. It calls your customers in, gives
-- every one the haircut they asked for (5 stars), posts the ClipTok videos, builds
-- the shop, hires staff, buys better tools and claims the free rewards.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

if game.GameId ~= 10773971368 then
	warn("[Zinoos hub] This only runs in Barber Empire")
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
if typeof(genv.ZinoosBarberStop) == "function" then
	pcall(genv.ZinoosBarberStop)
	elevate()
end
genv.ZinoosBarberGen = (typeof(genv.ZinoosBarberGen) == "number" and genv.ZinoosBarberGen or 0) + 1
local token = genv.ZinoosBarberGen
local function running()
	return genv.ZinoosBarberGen == token
end

local STATE = {
	_gen = token,
	autoCut = true,
	callCustomers = true,
	cutSpeed = "Normal",
	autoPost = true,
	autoBuild = true,
	autoHire = true,
	autoSweepers = true,
	autoChair = true,
	autoStations = true,
	autoTools = true,
	autoSkills = true,
	autoTips = true,
	useProducts = "Smart",
	autoBuyProducts = true,
	autoDrops = true,
	autoCoins = true,
	autoClaim = true,
	walkSpeed = false,
	speed = 32,
	antiAfk = true,
	autoReconnect = false,
	noPausePopup = true,
	fpsBoost = false,
	disable3d = false,
	hideOnStart = false,
	notifications = true,
	toggleKey = "RightControl",
	hubSize = "Compact",
	windTheme = "Zinoos",
	toggleControls = {},
	status = "Starting",
	detail = "",
}
genv.ZinoosBarberState = STATE

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

local function shutdownHub()
	if genv.ZinoosBarberGen == token then
		genv.ZinoosBarberGen = token + 1
	end
	STATE._unloaded = true
	STATE.walkSpeed = false
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
end
genv.ZinoosBarberStop = shutdownHub
local function unloadHub()
	shutdownHub()
end

local CONFIG_PATH = "Rayfield/Configurations/ZinoosHub/BarberEmpire_" .. tostring(LocalPlayer.UserId) .. ".rfld"

local FLAG_KEYS = {
	AutoCut = "autoCut",
	CallCustomers = "callCustomers",
	AutoPost = "autoPost",
	AutoBuild = "autoBuild",
	AutoHire = "autoHire",
	AutoSweepers = "autoSweepers",
	AutoChair = "autoChair",
	AutoStations = "autoStations",
	AutoTools = "autoTools",
	AutoSkills = "autoSkills",
	AutoTips = "autoTips",
	AutoBuyProducts = "autoBuyProducts",
	AutoDrops = "autoDrops",
	AutoCoins = "autoCoins",
	AutoClaim = "autoClaim",
	WalkSpeed = "walkSpeed",
	AntiAfk = "antiAfk",
	AutoReconnect = "autoReconnect",
	NoPausePopup = "noPausePopup",
	FpsBoost = "fpsBoost",
	Disable3d = "disable3d",
	HideOnStart = "hideOnStart",
	Notifications = "notifications",
}

-- How long one haircut takes. The cut is done in steps over this time, like a
-- real barber working round the head.
local SPEED_OPTIONS_CUT = { "Fast", "Normal", "Slow" }
local CUT_SECONDS = { Fast = 7, Normal = 12, Slow = 20 }
local PRODUCT_OPTIONS = { "Smart", "Always best", "Fast only", "Off" }
local SPEED_OPTIONS = { "16", "24", "32", "50", "75", "100" }
local KEY_OPTIONS = { "RightControl", "RightShift", "LeftAlt", "Insert", "End", "Home" }
local CHOICES = {
	CutSpeed = { key = "cutSpeed", options = SPEED_OPTIONS_CUT },
	UseProducts = { key = "useProducts", options = PRODUCT_OPTIONS },
	ToggleKey = { key = "toggleKey", options = KEY_OPTIONS },
	WindTheme = { key = "windTheme" },
	HubSize = { key = "hubSize", options = { "Compact", "Normal", "Large" } },
}

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
	local payload = { Speed = STATE.speed }
	for flag, key in pairs(FLAG_KEYS) do
		payload[flag] = STATE[key] == true
	end
	for flag, choice in pairs(CHOICES) do
		payload[flag] = STATE[choice.key]
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if ok then
		pcall(writefile, CONFIG_PATH, encoded)
	end
end
STATE.writeConfig = saveConfig

local stats = { cuts = 0, fives = 0, earned = 0, videos = 0, followers = 0, built = 0, hired = 0, bought = 0, claimed = 0, tips = 0, products = 0, drops = 0, coins = 0 }
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

local function notify(title, message)
	noteActivity(tostring(title) .. (message and message ~= "" and (" · " .. tostring(message)) or ""))
	if STATE.notifications == false then
		return
	end
	if typeof(STATE.toast) == "function" then
		pcall(STATE.toast, { title = tostring(title), message = tostring(message or "") })
	end
end

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function shortNumber(value)
	value = tonumber(value) or 0
	local sign = value < 0 and "-" or ""
	value = math.abs(value)
	if value < 1000 then
		return sign .. tostring(math.floor(value))
	end
	local index = 0
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	return sign .. string.format(value >= 100 and "%.0f%s" or "%.2f%s", value, SUFFIXES[index])
end
STATE.shortNumber = shortNumber

local function attr(name)
	return LocalPlayer:GetAttribute(name)
end

-- Several of the game's player attributes are JSON strings.
local function jsonAttr(name)
	local raw = attr(name)
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and type(decoded) == "table" and decoded or {}
end

local function cash()
	local value = LocalPlayer:FindFirstChild("Cash")
	return value and tonumber(value.Value) or 0
end

local function character()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then
		return char, root, hum
	end
	return nil
end

-- Game modules.
local HairLab = ReplicatedStorage:WaitForChild("HairLab")
local Remotes = HairLab:WaitForChild("Remotes")
local ClientModules = HairLab:WaitForChild("Client")
local function gameModule(parent, name)
	local ok, result = pcall(function()
		return require(parent:WaitForChild(name, 20))
	end)
	elevate()
	return ok and result or nil
end
local HairCuts = gameModule(HairLab, "HairCuts")
local Economy = gameModule(HairLab, "Economy")
local BuildPlan = gameModule(HairLab, "BuildPlan")
local ToolTiers = gameModule(HairLab, "ToolTiers")
local SkillTree = gameModule(HairLab, "SkillTree")
local BarberPass = gameModule(HairLab, "BarberPass")
local Passes = gameModule(HairLab, "Passes")
local Depth = gameModule(HairLab, "Depth")
local Payout = gameModule(HairLab, "Payout")
local CutStation = gameModule(ClientModules, "CutStation")
local Customers = gameModule(ClientModules, "Customers")
local ClipTok = gameModule(ClientModules, "ClipTok")
local Finish = gameModule(ClientModules, "Finish")
local CoinsModule = gameModule(ClientModules, "Coins")
local StaffShop = gameModule(ClientModules, "StaffShop")
local Playtime = gameModule(ClientModules, "Playtime")
elevate()

local function invoke(remoteName, ...)
	if not running() then
		return false, "stopped"
	end
	local remote = Remotes:FindFirstChild(remoteName)
	if not remote then
		return false, "missing remote " .. remoteName
	end
	local packed = table.pack(...)
	local ok, a, b = pcall(function()
		return remote:InvokeServer(table.unpack(packed, 1, packed.n))
	end)
	elevate()
	if not ok then
		return false, a
	end
	return a, b
end

-- Haircuts -------------------------------------------------------------------

local cutting = { busy = false, current = nil, lastCall = 0, startedAt = 0 }
STATE.cutting = cutting

local function hasPass(key)
	if not Passes or type(Passes.has) ~= "function" then
		return false
	end
	local ok, owned = pcall(Passes.has, LocalPlayer, key)
	return ok and owned == true
end

-- The cut record the game keeps for the customer in the chair (target lengths,
-- start lengths). It sits in the upvalues of the game's own finish function,
-- which is an upvalue of the onDone it hands to CutStation.begin.
local function findCutRecord(onDone)
	if type(onDone) ~= "function" then
		return nil
	end
	for _, up in ipairs(debug.getupvalues(onDone)) do
		if type(up) == "function" then
			for _, inner in ipairs(debug.getupvalues(up)) do
				if type(inner) == "table" and inner.target and inner.start and inner.c then
					return inner
				end
			end
		end
	end
	return nil
end

-- Freestyle customers want a big change: cutting each strand to under half of
-- its length counts as changed for every strand that has hair to change.
local function freestyleTarget(start)
	local target = {}
	for index, length in ipairs(start) do
		target[index] = length * 0.42
	end
	return target
end

local function orderText(order)
	order = order or {}
	if order.freestyle then
		return "Freestyle"
	end
	return tostring(order.title or order.baseTitle or order.scalp or "Haircut")
end

local function doCut(args)
	local order = args.order or {}
	local hair = args.hair
	if type(hair) ~= "table" or type(hair.lengths) ~= "function" or type(hair.setLengths) ~= "function" then
		return
	end
	task.wait(0.6)
	local record = findCutRecord(args.onDone)
	local start = record and record.start or hair:lengths()
	local target
	if order.freestyle then
		target = freestyleTarget(start)
	else
		target = record and record.target
		if not target and HairCuts then
			local ok, made = pcall(HairCuts.target, hair, order, start)
			target = ok and made or nil
		end
	end
	if type(target) ~= "table" then
		STATE.detail = "Couldn't read what " .. tostring(args.name or "the customer") .. " wants. Finish this one yourself"
		return
	end
	local who = record and record.c and record.c.name
	STATE.status = "Cutting: " .. orderText(order)
	STATE.detail = tostring(who or "Customer")
	local seconds = CUT_SECONDS[STATE.cutSpeed] or 12
	local steps = math.max(4, math.floor(seconds / 1.5))
	-- A cut that has started is always finished, even if this copy of the hub
	-- is unloaded meanwhile; otherwise the customer would sit in the chair forever.
	for step = 1, steps do
		if not CutStation.isActive() then
			return
		end
		local mid = {}
		for index, length in ipairs(start) do
			local want = target[index] or length
			mid[index] = length + (want - length) * step / steps
		end
		pcall(hair.setLengths, hair, mid)
		task.wait(seconds / steps)
	end
	if not CutStation.isActive() then
		return
	end
	elevate()
	-- The tools a barber would really have used for this order.
	local used = debug.getupvalue(CutStation.toolsUsed, 1)
	if type(used) == "table" then
		used.Clippers = true
		if order.tool then
			used[order.tool] = true
		end
		if order.lineup then
			used.Trimmer = true
		end
	end
	-- Combed, slicked back or twisted styles.
	if HairCuts and type(HairCuts.styleTarget) == "function" and not order.freestyle then
		pcall(HairCuts.styleTarget, hair, order)
	end
	-- Dye only with the game's Hair Dye pass, like a normal player.
	if order.dye and hasPass("HairDye") and HairCuts and type(hair.setColors) == "function" then
		local ok, colors = pcall(HairCuts.dyedColors, hair, order)
		if ok and type(colors) == "table" then
			pcall(hair.setColors, hair, colors)
		end
	end
	task.wait(0.5)
	cutting.lastOrder = orderText(order) .. (order.dye and " (dye)" or "") .. (order.designTip and " (design tip)" or "")
	-- Press Done. During the game's tutorial Done can be held back for a moment,
	-- so keep pressing until the chair is free.
	for _ = 1, 20 do
		if not CutStation.isActive() then
			break
		end
		pcall(args.onDone)
		task.wait(1.5)
	end
end

do
	local original = genv.ZinoosBarberBegin
	if type(original) ~= "function" then
		original = CutStation and CutStation.begin
		genv.ZinoosBarberBegin = original
	end
	if CutStation and type(original) == "function" then
		CutStation.begin = function(args, ...)
			local results = table.pack(original(args, ...))
			if running() and STATE.autoCut == true and type(args) == "table" and not cutting.busy then
				cutting.busy = true
				cutting.startedAt = os.clock()
				cutting.current = orderText(args.order)
				task.spawn(function()
					elevate()
					local ok, err = pcall(doCut, args)
					if not ok then
						STATE.detail = "Cut error: " .. tostring(err)
						warn("[Zinoos hub] " .. tostring(err))
					end
					cutting.busy = false
					cutting.current = nil
				end)
			end
			return table.unpack(results, 1, results.n)
		end
		hubCleanup(function()
			CutStation.begin = original
		end)
	end
end

-- Finishing products ----------------------------------------------------------
-- After a cut the game offers your products (wax, spray, hot towel...). The one
-- you pick has a little mini-game, then pays extra. The hub picks the best one
-- and plays the mini-game the way a controller does: hold A to fill the bar
-- (about 19 s), or tap A for the Hot Towel (about 2 s).
local VirtualInput = game:GetService("VirtualInputManager")
local productModes = nil
local function productMode(id)
	if productModes == nil then
		productModes = {}
		if Finish and type(Finish.apply) == "function" then
			for _, up in ipairs(debug.getupvalues(Finish.apply)) do
				if type(up) == "table" then
					local found = false
					for _, value in pairs(up) do
						if value == "mash" or value == "rub" then
							found = true
							break
						end
					end
					if found then
						productModes = up
						break
					end
				end
			end
		end
	end
	return productModes[id] or "rub"
end
local function productSeconds(id)
	return productMode(id) == "mash" and 2.5 or 19
end
local function productPower()
	local power = 1
	if Payout and type(Payout.productPower) == "function" then
		pcall(function()
			power = Payout.productPower(LocalPlayer) or 1
		end)
	end
	return power
end
local function productBoost(product, order)
	local pay, views = product.pay or 1, product.views or 1
	if Depth and type(Depth.productBoost) == "function" then
		local ok, a, b = pcall(Depth.productBoost, product, order, productPower())
		if ok and tonumber(a) then
			pay, views = tonumber(a), tonumber(b) or views
		end
	end
	return pay, views
end
-- Smart: a product is used when its extra pay is worth the extra seconds
-- (a full haircut round is about 40 s). Hot Towel always is; the slow ones
-- only when the bonus is big (Gold Serum, or the one the customer asked for).
local function productWorthIt(product, order)
	local pay = productBoost(product, order)
	local mode = STATE.useProducts
	if mode == "Always best" then
		return true
	elseif mode == "Fast only" then
		return productSeconds(product.id) < 5
	end
	return pay - 1 >= productSeconds(product.id) / 40
end
local function pickProduct(order)
	if not Depth or type(Depth.PRODUCTS) ~= "table" or STATE.useProducts == "Off" then
		return nil
	end
	local owned = jsonAttr("Products")
	local best, bestScore
	for _, product in ipairs(Depth.PRODUCTS) do
		if (tonumber(owned[product.id]) or 0) > 0 and productWorthIt(product, order) then
			local pay, views = productBoost(product, order)
			local score = (pay - 1) + (views - 1) * 0.25 - productSeconds(product.id) / 200
			if not bestScore or score > bestScore then
				best, bestScore = product, score
			end
		end
	end
	return best
end
STATE.pickProduct = pickProduct

local function pressA(down)
	elevate()
	pcall(function()
		VirtualInput:SendKeyEvent(down, Enum.KeyCode.ButtonA, false, game)
	end)
end

local function playProduct(customer, product, order)
	local finished = false
	local mash = productMode(product.id) == "mash"
	task.spawn(function()
		-- The game calls this from its own script, which can't send input.
		elevate()
		task.wait(0.4)
		elevate()
		local started = os.clock()
		if mash then
			while not finished and os.clock() - started < 20 do
				pressA(true)
				pressA(false)
				task.wait()
			end
		else
			pressA(true)
			while not finished and os.clock() - started < 45 do
				task.wait(0.1)
			end
			pressA(false)
		end
	end)
	local ok, cover = pcall(Finish.apply, customer, product, order)
	finished = true
	-- Release A from a hub thread; this one belongs to the game's script.
	task.spawn(pressA, false)
	return ok and tonumber(cover) or 0
end

do
	local original = genv.ZinoosBarberChoose
	if type(original) ~= "function" then
		original = Finish and Finish.choose
		genv.ZinoosBarberChoose = original
	end
	if Finish and type(original) == "function" then
		Finish.choose = function(customer, order, ...)
			if not running() or STATE.autoCut ~= true then
				return original(customer, order, ...)
			end
			local product = pickProduct(order)
			if not product then
				-- Skip the game's 10 s product picker.
				return nil, nil
			end
			STATE.status = "Finishing with " .. tostring(product.name)
			local cover = playProduct(customer, product, order)
			if cover < 0.05 then
				return nil, nil
			end
			pcall(Finish.show, customer, product)
			task.wait(0.7)
			stats.products += 1
			noteActivity("Used " .. tostring(product.name))
			return product.id, nil
		end
		hubCleanup(function()
			Finish.choose = original
		end)
	end
end

-- Haircuts and five-star cuts are counted by the game in the Stats attribute.
do
	local function readStats()
		local data = jsonAttr("Stats")
		return tonumber(data.cuts) or 0, tonumber(data.five) or 0
	end
	local cutsBefore, fivesBefore = readStats()
	trackConnection(LocalPlayer:GetAttributeChangedSignal("Stats"):Connect(function()
		local cuts, fives = readStats()
		if cuts > cutsBefore then
			stats.cuts += cuts - cutsBefore
			stats.fives += math.max(0, fives - fivesBefore)
			local five = fives > fivesBefore
			noteActivity((five and "5 stars: " or "Under 5 stars: ") .. tostring(cutting.lastOrder or "haircut"))
			STATE.cutHistory = STATE.cutHistory or {}
			table.insert(STATE.cutHistory, { order = cutting.lastOrder, five = five })
			while #STATE.cutHistory > 40 do
				table.remove(STATE.cutHistory, 1)
			end
		end
		cutsBefore, fivesBefore = cuts, fives
	end))
	local cashBefore = cash()
	local cashValue = LocalPlayer:WaitForChild("Cash", 10)
	if cashValue then
		trackConnection(cashValue.Changed:Connect(function(value)
			local now = tonumber(value) or 0
			if now > cashBefore then
				stats.earned += now - cashBefore
			end
			cashBefore = now
		end))
	end
end

-- Customers waiting in your shop have a prompt; pressing it calls them to the chair.
local function waitingCustomers()
	local list = {}
	for _, customer in pairs(Customers and Customers.list or {}) do
		if type(customer) == "table" and customer.state == "waiting" and typeof(customer.prompt) == "Instance" and customer.prompt.Parent and not customer.dead then
			list[#list + 1] = customer
		end
	end
	-- Specials (rich, critics, rush) first: they pay more.
	table.sort(list, function(a, b)
		local sa = (a.rich and 2 or 0) + (a.special and 1 or 0)
		local sb = (b.rich and 2 or 0) + (b.special and 1 or 0)
		return sa > sb
	end)
	return list
end
STATE.waitingCustomers = waitingCustomers

local function chairBusy()
	if cutting.busy or (CutStation and CutStation.isActive()) then
		return true
	end
	for _, customer in pairs(Customers and Customers.list or {}) do
		if type(customer) == "table" and (customer.state == "called" or customer.state == "inChair") then
			return true
		end
	end
	return false
end

local function stepCall()
	if STATE.autoCut ~= true or STATE.callCustomers ~= true then
		return
	end
	if chairBusy() or (ClipTok and ClipTok.isOpen()) or os.clock() - cutting.lastCall < 4 then
		return
	end
	local list = waitingCustomers()
	local customer = list[1]
	if not customer then
		STATE.status = "Waiting for customers"
		STATE.detail = ""
		return
	end
	cutting.lastCall = os.clock()
	STATE.status = "Calling " .. tostring(customer.name or "a customer")
	STATE.detail = orderText(customer.order)
	elevate()
	if typeof(fireproximityprompt) == "function" then
		pcall(fireproximityprompt, customer.prompt)
	end
end

-- ClipTok: every cut is filmed. Post it for followers, then close the results.
local FOLLOWER_CAP = 1e290
local video = { closeSeen = nil, resultsAt = nil, lastPress = 0 }
local function stepVideo()
	if not ClipTok or not ClipTok.isOpen() then
		video.resultsAt = nil
		return
	end
	if STATE.autoCut ~= true and STATE.autoPost ~= true then
		return
	end
	local closeResults = ClipTok._closeResults
	if type(closeResults) == "function" and closeResults ~= video.closeSeen then
		-- Results are on screen. Leave them up for a moment, then close.
		video.resultsAt = video.resultsAt or os.clock()
		if os.clock() - video.resultsAt > 2.5 then
			video.closeSeen = closeResults
			video.resultsAt = nil
			pcall(closeResults)
		end
		return
	end
	if os.clock() - video.lastPress < 1 then
		return
	end
	video.lastPress = os.clock()
	-- Followers multiply with every video. Near the biggest number Roblox can
	-- hold (about 1e308) the next post would turn them into infinity, which can
	-- break the save, so past FOLLOWER_CAP the hub discards videos instead.
	local followers = tonumber(attr("Followers")) or 0
	if STATE.autoPost == true and followers < FOLLOWER_CAP then
		pcall(ClipTok._press, "post")
	elseif STATE.autoPost == true then
		if not video.capNoted then
			video.capNoted = true
			noteActivity("Followers maxed out: videos are discarded now so the number can't overflow")
		end
		pcall(ClipTok._press, "skip")
	else
		pcall(ClipTok._press, "skip")
	end
end

do
	local followersBefore = tonumber(attr("Followers")) or 0
	trackConnection(LocalPlayer:GetAttributeChangedSignal("Followers"):Connect(function()
		local now = tonumber(attr("Followers")) or 0
		if now > followersBefore then
			stats.followers += now - followersBefore
			stats.videos += 1
		end
		followersBefore = now
	end))
end

-- Shop upgrades --------------------------------------------------------------

local shop = { nextBuy = 0, nextBuild = 0, lastText = "" }
STATE.shop = shop

local function storeLevel()
	return tonumber(attr("StoreLevel")) or 1
end

local function nextBuildPiece()
	if not BuildPlan then
		return nil
	end
	local ok, _, _, piece = pcall(BuildPlan.nextPiece, {
		level = tonumber(attr("BuildLevel")) or 1,
		built = tonumber(attr("BuildBuilt")) or 0,
	})
	if ok and type(piece) == "table" and tonumber(piece.cost) then
		return piece
	end
	return nil
end

local function barbersList()
	if not StaffShop or type(StaffShop.pressStation) ~= "function" then
		return {}
	end
	local fn = debug.getupvalue(StaffShop.pressStation, 1)
	if type(fn) ~= "function" then
		return {}
	end
	local ok, list = pcall(fn)
	elevate()
	return ok and type(list) == "table" and list or {}
end

local TOOL_ATTRS = { Clippers = "ClipperTier", Trimmer = "TrimmerTier", Razor = "RazorTier", Scissors = "ScissorsTier", Sponge = "SpongeTier" }

-- Everything the hub could buy right now, each with its price and how to buy it.
local function shopOptions()
	local options = {}
	if STATE.autoBuild == true then
		local piece = nextBuildPiece()
		if piece and os.clock() >= shop.nextBuild then
			options[#options + 1] = {
				cost = piece.cost,
				label = "Built " .. tostring(piece.name),
				counter = "built",
				buy = function()
					local ok = invoke("Build", "piece")
					shop.nextBuild = os.clock() + 4
					return ok == true
				end,
			}
		end
	end
	if Economy then
		local level = storeLevel()
		if STATE.autoHire == true then
			local count = #barbersList()
			local room = 0
			pcall(function()
				room = Economy.barberRoom(level, attr("Pass_ExtraBarber") == true)
			end)
			local cost = Economy.HIRE_COST[count + 1]
			if cost and count < (tonumber(room) or 0) then
				options[#options + 1] = {
					cost = cost,
					label = "Hired a barber",
					counter = "hired",
					buy = function()
						return invoke("Hire", "hire") == true
					end,
				}
			end
		end
		if STATE.autoSweepers == true then
			local count = tonumber(attr("Sweepers")) or 0
			local max = Economy.MAX_SWEEPERS_BY_LEVEL[level] or 0
			local cost = Economy.SWEEPER_COST[count + 1]
			if cost and count < max then
				options[#options + 1] = {
					cost = cost,
					label = "Hired a sweeper",
					counter = "hired",
					buy = function()
						return invoke("Hire", "sweeper") == true
					end,
				}
			end
		end
		if STATE.autoChair == true then
			local chair = tonumber(attr("ChairLevel")) or 1
			local cost = Economy.CHAIR_COST[chair + 1]
			local needs = Economy.CHAIR_LEVEL and Economy.CHAIR_LEVEL[chair + 1]
			if cost and (not needs or level >= needs) then
				options[#options + 1] = {
					cost = cost,
					label = "Upgraded your chair",
					counter = "bought",
					buy = function()
						return invoke("Hire", "chair") == true
					end,
				}
			end
		end
		if STATE.autoStations == true then
			for index, barber in ipairs(barbersList()) do
				if type(barber) == "table" and tonumber(barber.stationCost) and level >= (tonumber(barber.stationAt) or 99) then
					options[#options + 1] = {
						cost = barber.stationCost,
						label = "Upgraded a barber station",
						counter = "bought",
						buy = function()
							return invoke("Hire", "station", index) == true
						end,
					}
				end
			end
		end
	end
	if STATE.autoTools == true and ToolTiers and type(ToolTiers.STATS) == "table" then
		for tool, data in pairs(ToolTiers.STATS) do
			local have = tonumber(attr(TOOL_ATTRS[tool] or "")) or 1
			local nextTier = have + 1
			local price = data.price and data.price[nextTier]
			local needs = data.level and data.level[nextTier]
			if price and (not needs or storeLevel() >= needs) then
				local owned = false
				pcall(function()
					owned = ToolTiers.ownsTier(LocalPlayer, tool, nextTier) == true
				end)
				options[#options + 1] = {
					cost = owned and 0 or price,
					label = (owned and "Equipped " or "Bought ") .. tostring(ToolTiers.TIERS[nextTier] and ToolTiers.TIERS[nextTier].name or "") .. " " .. tool,
					counter = "bought",
					buy = function()
						local ok = invoke("ToolShop", owned and "equip" or "buy", tool, nextTier)
						if ok == true and not owned then
							invoke("ToolShop", "equip", tool, nextTier)
						end
						return ok == true
					end,
				}
			end
		end
	end
	if STATE.autoBuyProducts == true and STATE.useProducts ~= "Off" and Depth and Payout and type(Depth.PRODUCTS) == "table" then
		local owned = jsonAttr("Products")
		for _, product in ipairs(Depth.PRODUCTS) do
			if (tonumber(product.level) or 1) <= storeLevel() and (tonumber(owned[product.id]) or 0) < 3 and productWorthIt(product, nil) then
				local ok, price = pcall(Payout.packPrice, LocalPlayer, product)
				if ok and tonumber(price) then
					options[#options + 1] = {
						cost = tonumber(price),
						label = "Bought " .. tostring(product.pack or 10) .. " " .. tostring(product.name),
						counter = "bought",
						buy = function()
							return invoke("ToolShop", "product", product.id) == true
						end,
					}
				end
			end
		end
	end
	if STATE.autoSkills == true and SkillTree and type(SkillTree.NODES) == "table" then
		local mine = nil
		pcall(function()
			mine = SkillTree.ofPlayer(LocalPlayer)
		end)
		for _, node in ipairs(SkillTree.NODES) do
			if (tonumber(node.cost) or 0) > 0 then
				local can = false
				pcall(function()
					can = SkillTree.canBuy(mine, node.id) == true
				end)
				if can then
					options[#options + 1] = {
						cost = node.cost,
						label = "Learned " .. tostring(node.name),
						counter = "bought",
						buy = function()
							return invoke("Build", "skill", node.id) == true
						end,
					}
				end
			end
		end
	end
	table.sort(options, function(a, b)
		return a.cost < b.cost
	end)
	return options
end
STATE.shopOptions = shopOptions

-- Buys the cheapest thing it can afford, one at a time.
local function stepShop()
	if os.clock() < shop.nextBuy then
		return
	end
	shop.nextBuy = os.clock() + 1.5
	local options = shopOptions()
	local cheapest = options[1]
	if cheapest then
		shop.lastText = string.format("Next: %s ($%s)", cheapest.label:gsub("^%w+ ", ""), shortNumber(cheapest.cost))
	else
		shop.lastText = "Nothing left to buy right now"
	end
	if not cheapest or cheapest.cost > cash() then
		return
	end
	local ok, bought = pcall(cheapest.buy)
	elevate()
	if ok and bought then
		stats[cheapest.counter] = (stats[cheapest.counter] or 0) + 1
		notify(cheapest.label, cheapest.cost > 0 and ("$" .. shortNumber(cheapest.cost)) or "")
		shop.nextBuy = os.clock() + 1
	else
		shop.nextBuy = os.clock() + 8
	end
end

-- Errands between customers: tip jar, product drops, coins ---------------------

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Walks (no teleports) round the chairs and counters with PathfindingService.
-- Stops early when done() says so, when a cut starts or after `timeout` seconds.
local function walkTo(goal, timeout, done)
	local _, root, hum = character()
	if not root then
		return false
	end
	local points = {}
	pcall(function()
		local path = game:GetService("PathfindingService"):CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		path:ComputeAsync(root.Position, goal)
		if path.Status == Enum.PathStatus.Success then
			for _, point in ipairs(path:GetWaypoints()) do
				points[#points + 1] = point
			end
		end
	end)
	if #points == 0 then
		points[1] = { Position = goal, Action = Enum.PathWaypointAction.Walk }
	end
	local started = os.clock()
	local index = 1
	while running() and os.clock() - started < timeout do
		_, root, hum = character()
		if not root or (CutStation and CutStation.isActive()) then
			return false
		end
		if done(root) then
			return true
		end
		local point = points[index]
		if not point then
			-- Path finished but not there yet: step straight at the goal.
			hum:MoveTo(goal)
		elseif flat(root.Position, point.Position) < 2 then
			index += 1
		else
			if point.Action == Enum.PathWaypointAction.Jump then
				hum.Jump = true
			end
			hum:MoveTo(point.Position)
		end
		task.wait(0.1)
	end
	local _, rootNow = character()
	return rootNow ~= nil and done(rootNow)
end

-- Tip jar: the server only pays it out when you stand next to it; the game's
-- own code empties it once you're within ~4 studs.
local tips = { nextTry = 0 }
-- Every tip jar carries the "TipJar" tag and its owner's UserId.
local function myTipJar()
	for _, model in ipairs(game:GetService("CollectionService"):GetTagged("TipJar")) do
		if model:GetAttribute("OwnerId") == LocalPlayer.UserId then
			return model
		end
	end
	return nil
end
local function stepTips()
	if STATE.autoTips ~= true or os.clock() < tips.nextTry then
		return
	end
	if not tips.jar or not tips.jar.Parent then
		tips.jar = myTipJar()
	end
	local jar = tips.jar
	local amount = jar and tonumber(jar:GetAttribute("Amount")) or 0
	if amount < 1 then
		tips.nextTry = os.clock() + 10
		return
	end
	local _, root = character()
	local spot = jar:GetPivot().Position
	if not root or flat(root.Position, spot) > 150 then
		tips.nextTry = os.clock() + 10
		return
	end
	tips.nextTry = os.clock() + 60
	STATE.status = "Emptying the tip jar"
	STATE.detail = "$" .. shortNumber(amount)
	local pad = jar:FindFirstChild("Pad")
	walkTo(pad and pad.Position or spot, 12, function(rootNow)
		return flat(rootNow.Position, spot) <= 3 or (tonumber(jar:GetAttribute("Amount")) or 0) < 1
	end)
	-- The game takes it from here; wait for the jar to read empty.
	local waitUntil = os.clock() + 3
	while running() and os.clock() < waitUntil and (tonumber(jar:GetAttribute("Amount")) or 0) >= 1 do
		task.wait(0.2)
	end
	if (tonumber(jar:GetAttribute("Amount")) or 0) < 1 then
		stats.tips += amount
		noteActivity("Emptied the tip jar: $" .. shortNumber(amount))
	end
end

-- Product drops: a free crate of finishing products lands somewhere nearby for
-- 3 minutes. The game picks it up once you're within ~4 studs of it.
local drop = nil
do
	local remote = Remotes:FindFirstChild("Drop")
	if remote and remote:IsA("RemoteEvent") then
		trackConnection(remote.OnClientEvent:Connect(function(kind, data)
			if kind == "spawn" and type(data) == "table" and typeof(data.pos) == "Vector3" then
				drop = { id = data.id, pos = data.pos, untilT = os.clock() + (tonumber(data.life) or 180), tries = 0 }
				noteActivity("A product drop landed nearby")
			else
				drop = nil
			end
		end))
	end
end
local function stepDrops()
	if STATE.autoDrops ~= true or not drop then
		return
	end
	if os.clock() > drop.untilT or drop.tries >= 3 then
		drop = nil
		return
	end
	local _, root = character()
	if not root or (root.Position - drop.pos).Magnitude > 600 then
		return
	end
	local target = drop
	target.tries += 1
	STATE.status = "Grabbing a product drop"
	STATE.detail = string.format("%d studs away", math.floor(flat(root.Position, target.pos)))
	walkTo(target.pos, 45, function(rootNow)
		return drop ~= target or flat(rootNow.Position, target.pos) < 3
	end)
	local waitUntil = os.clock() + 3
	while running() and drop == target and os.clock() < waitUntil do
		task.wait(0.2)
	end
	if drop ~= target then
		stats.drops += 1
		noteActivity("Grabbed a product drop")
	end
end

-- Coins (copper to diamond) pop up around the shop, most of all during Money
-- Rain. The game collects one when you walk within ~8 studs of it.
local coinList = nil
local function coins()
	if coinList == nil then
		coinList = false
		if CoinsModule and type(CoinsModule.init) == "function" then
			for _, up in ipairs(debug.getupvalues(CoinsModule.init)) do
				if type(up) == "function" then
					local first = debug.getupvalues(up)[1]
					if type(first) == "table" then
						coinList = first
						break
					end
				end
			end
		end
	end
	return coinList or {}
end
local coinSkip = setmetatable({}, { __mode = "k" })
local function nearestCoin(root)
	local best, bestDistance
	local home = tips.jar and tips.jar.Parent and tips.jar:GetPivot().Position or root.Position
	for _, coin in pairs(coins()) do
		if type(coin) == "table" and coin.state == "idle" and typeof(coin.pos) == "Vector3" and (coinSkip[coin] or 0) < os.clock()
			and flat(coin.pos, home) < 120 and math.abs(coin.pos.Y - root.Position.Y) < 20 then
			local distance = flat(coin.pos, root.Position)
			if not bestDistance or distance < bestDistance then
				best, bestDistance = coin, distance
			end
		end
	end
	return best
end
local function stepCoins()
	if STATE.autoCoins ~= true then
		return
	end
	local _, root = character()
	if not root or not nearestCoin(root) then
		return
	end
	local started = os.clock()
	local got = 0
	while running() and os.clock() - started < 25 do
		_, root = character()
		local coin = root and nearestCoin(root)
		if not coin then
			break
		end
		STATE.status = "Collecting coins"
		STATE.detail = got .. " so far"
		local reach = coin.kind == "diamond" and 9 or 6
		walkTo(coin.pos, 8, function(rootNow)
			return coin.state ~= "idle" or flat(rootNow.Position, coin.pos) < reach
		end)
		task.wait(0.15)
		if coin.state ~= "idle" then
			got += 1
		else
			-- Couldn't reach it (on a roof, behind a wall): leave it for a while.
			coinSkip[coin] = os.clock() + 60
		end
	end
	if got > 0 then
		stats.coins += got
		noteActivity("Collected " .. got .. " coins")
	end
end

local function stepErrands()
	if chairBusy() or (ClipTok and ClipTok.isOpen()) then
		return
	end
	stepTips()
	if chairBusy() then
		return
	end
	stepDrops()
	if chairBusy() then
		return
	end
	stepCoins()
end

-- Free rewards ----------------------------------------------------------------

local claims = { nextTry = 0 }

-- The game stores "already claimed" either as a list [1, 2] or as {"1": true}.
local function claimedSet(value)
	local set = {}
	if type(value) == "table" then
		for key, item in pairs(value) do
			if item == true then
				set[tostring(key)] = true
			elseif type(item) == "number" or type(item) == "string" then
				set[tostring(item)] = true
			end
		end
	end
	return set
end

-- Every claim goes through the Goals remote; the reply says if it worked.
local function claimed(...)
	local result = invoke("Goals", ...)
	return type(result) == "table" and result.ok == true, result
end

local function stepClaims(force)
	if not force and (STATE.autoClaim ~= true or os.clock() < claims.nextTry) then
		return 0
	end
	claims.nextTry = os.clock() + 15
	local count = 0
	-- Daily login reward.
	local login = jsonAttr("Login")
	if login.can == true and claimed("login") then
		count += 1
		noteActivity("Claimed the daily reward")
	end
	-- Quests: daily and weekly, then their chests.
	local quests = jsonAttr("Quests")
	for _, kind in ipairs({ "daily", "weekly" }) do
		local list = type(quests[kind]) == "table" and quests[kind] or {}
		local allDone = #list > 0
		for index, quest in ipairs(list) do
			if quest.claimed ~= true then
				if (tonumber(quest.at) or 0) >= (tonumber(quest.n) or math.huge) and claimed("claim", kind, index) then
					count += 1
					noteActivity("Quest done: " .. tostring(quest.label))
				else
					allDone = false
				end
			end
		end
		if allDone and quests[kind .. "Chest"] ~= true and claimed("chest", kind) then
			count += 1
			noteActivity("Opened the " .. kind .. " quest chest")
		end
	end
	-- Barber Pass free track.
	local pass = jsonAttr("PassData")
	if BarberPass then
		local reached = 0
		pcall(function()
			reached = tonumber(BarberPass.tierAt(tonumber(pass.xp) or 0)) or 0
		end)
		local got = claimedSet(pass.free)
		for tier = 1, math.min(reached, tonumber(BarberPass.TIERS) or 30) do
			if not got[tostring(tier)] and BarberPass.FREE and BarberPass.FREE[tier] and claimed("pass", "free", tier) then
				count += 1
				noteActivity("Barber Pass tier " .. tier .. " claimed")
			end
		end
	end
	-- The gift the game offers in its menu now and then.
	if os.clock() >= (claims.nextMenuGift or 0) then
		claims.nextMenuGift = os.clock() + 300
		local opened = invoke("EscMenu", "open")
		if type(opened) == "table" and opened.offer then
			local result = invoke("EscMenu", "claim")
			if type(result) == "table" and result.ok == true then
				count += 1
				noteActivity("Claimed the menu gift")
			end
		end
	end
	-- Playtime gifts.
	if Playtime and type(Playtime.claim) == "function" then
		local list = debug.getupvalue(Playtime.claim, 1)
		local got = claimedSet(jsonAttr("PlayGot"))
		local played = tonumber(attr("PlaySecs")) or 0
		if type(list) == "table" then
			for index, gift in ipairs(list) do
				if type(gift) == "table" and not got[tostring(index)] and played >= (tonumber(gift.at) or math.huge) * 60 and claimed("play", index) then
					count += 1
					noteActivity("Playtime gift " .. index .. " claimed")
				end
			end
		end
	end
	stats.claimed += count
	return count
end
STATE.claimNow = function()
	return stepClaims(true)
end

-- Player helpers.
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
	local _, _, hum = character()
	if hum and STATE.walkSpeed == true and not chairBusy() and hum.WalkSpeed > 0 then
		if walkSpeedsBefore[hum] == nil then
			walkSpeedsBefore[hum] = hum.WalkSpeed
		end
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
trackConnection(LocalPlayer.Idled:Connect(function()
	pulseAntiAfk()
end))

local pauseGuisBefore = setmetatable({}, { __mode = "k" })
local function restorePausePopup()
	elevate()
	for gui, enabled in pairs(pauseGuisBefore) do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	table.clear(pauseGuisBefore)
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

local reconnectPending = false
pcall(function()
	trackConnection(GuiService.ErrorMessageChanged:Connect(function(message)
		if STATE.autoReconnect == true and reconnectPending ~= true and type(message) == "string" and message ~= "" then
			reconnectPending = true
			task.delay(2, function()
				if not running() or STATE.autoReconnect ~= true then
					reconnectPending = false
					return
				end
				local ok = pcall(function()
					TeleportService:Teleport(game.PlaceId, LocalPlayer)
				end)
				task.delay(ok and 15 or 0, function()
					reconnectPending = false
				end)
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

-- Potato Mode turns off effects only; the world and the hub stay visible.
local POTATO_CLASSES = {
	ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true,
	PointLight = true, SpotLight = true, SurfaceLight = true,
	BloomEffect = true, BlurEffect = true, SunRaysEffect = true, DepthOfFieldEffect = true,
}
local potato = nil
local function potatoOff(profile, instance)
	if potato ~= profile or not POTATO_CLASSES[instance.ClassName] then
		return
	end
	local ok, enabled = pcall(function()
		return instance.Enabled
	end)
	if ok and enabled then
		profile.items[instance] = true
		pcall(function()
			instance.Enabled = false
		end)
	end
end
function STATE.applyFpsBoost()
	if STATE.fpsBoost == true and running() then
		if potato then
			return
		end
		local profile = { items = setmetatable({}, { __mode = "k" }), connections = {} }
		potato = profile
		pcall(function()
			profile.quality = settings().Rendering.QualityLevel
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
		pcall(function()
			profile.shadows = Lighting.GlobalShadows
			Lighting.GlobalShadows = false
		end)
		table.insert(profile.connections, Workspace.DescendantAdded:Connect(function(instance)
			if POTATO_CLASSES[instance.ClassName] then
				task.defer(potatoOff, profile, instance)
			end
		end))
		task.spawn(function()
			local stack = { Workspace, Lighting }
			local scanned = 0
			while #stack > 0 and potato == profile do
				local current = table.remove(stack)
				local ok, children = pcall(current.GetChildren, current)
				if ok then
					for _, child in ipairs(children) do
						stack[#stack + 1] = child
						potatoOff(profile, child)
					end
				end
				scanned += 1
				if scanned % 80 == 0 then
					RunService.Heartbeat:Wait()
				end
			end
		end)
	elseif potato then
		local profile = potato
		potato = nil
		for _, connection in ipairs(profile.connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		for instance in pairs(profile.items) do
			pcall(function()
				instance.Enabled = true
			end)
		end
		pcall(function()
			if profile.quality then
				settings().Rendering.QualityLevel = profile.quality
			end
			if profile.shadows ~= nil then
				Lighting.GlobalShadows = profile.shadows
			end
		end)
	end
end
hubCleanup(function()
	STATE.fpsBoost = false
	STATE.applyFpsBoost()
end)

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

-- The dashboard is the same WindUI window the other Zinoos games use.
local WINDUI_URL = "https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua"

local function loadWindUI()
	local caches = type(genv.ZinoosWindUISources) == "table" and genv.ZinoosWindUISources or {}
	genv.ZinoosWindUISources = caches
	local source = caches[WINDUI_URL]
	if type(source) ~= "string" or #source < 1000 then
		local ok, body = pcall(function()
			return game:HttpGet(WINDUI_URL)
		end)
		elevate()
		if not ok or type(body) ~= "string" or #body < 1000 then
			return nil, "download failed"
		end
		source = body
		caches[WINDUI_URL] = source
	end
	local chunk, compileError = loadstring(source, "=WindUI")
	if not chunk then
		caches[WINDUI_URL] = nil
		return nil, compileError
	end
	local ok, library = pcall(chunk)
	elevate()
	if not ok or type(library) ~= "table" then
		caches[WINDUI_URL] = nil
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

	local WindUI, loadError = loadWindUI()
	if not WindUI then
		warn("[Zinoos hub] Menu could not load (" .. tostring(loadError) .. "). Automation is still running with your saved settings.")
		return
	end
	pcall(WindUI.AddTheme, WindUI, ZINOOS_THEME)
	pcall(WindUI.SetNotificationLower, WindUI, true)
	elevate()

	local camera = Workspace.CurrentCamera
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
		Author = "Barber Empire",
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
		elseif key == "walkSpeed" and not on then
			restoreWalkSpeed()
		elseif key == "autoClaim" and on then
			task.spawn(STATE.claimNow)
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
		STATE.toggleControls[key] = element
		return element
	end

	local function syncToggle(key)
		local element = STATE.toggleControls[key]
		if type(element) == "table" and element.Value ~= (STATE[key] == true) then
			elevate()
			pcall(element.Set, element, STATE[key] == true, false)
		end
	end

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
					if type(value) == "table" then
						value = value.Title or value.Name
					end
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
		if parent.__type == "Section" then
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
						notify(title .. " failed", tostring(err))
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
	local cutTab = Window:Tab({ Title = "Barbering", Icon = "scissors" })
	local shopTab = Window:Tab({ Title = "Shop", Icon = "store" })
	local rewardTab = Window:Tab({ Title = "Rewards", Icon = "gift" })
	local playerTab = Window:Tab({ Title = "Player", Icon = "user" })
	local settingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
	elevate()

	local overview = info(homeTab, "Overview", "Loading your stats...")
	button(homeTab, "Start / Stop Cutting", "Turns Auto Cut on or off", "power", function()
		local on = STATE.autoCut ~= true
		onToggle("autoCut", on)
		syncToggle("autoCut")
		notify(on and "Cutting started" or "Cutting stopped", "")
	end)
	button(homeTab, "Claim Now", "Daily reward, quests, quest chests, Barber Pass and playtime gifts", "gift", function()
		task.spawn(function()
			local count = STATE.claimNow()
			notify(count > 0 and ("Claimed " .. count) or "Nothing ready", "")
		end)
	end)
	local activityInfo = info(homeTab, "Activity", "Waiting for the next thing the hub does.")

	local cutInfo
	do
		local cutBox = section(cutTab, "Haircuts", "scissors")
		toggle(cutBox, "Auto Cut", "autoCut", "Gives every customer in your chair exactly the cut they asked for (5 stars)")
		toggle(cutBox, "Call Customers", "callCustomers", "Calls the next waiting customer to the chair. VIPs and special guests go first")
		choice(cutBox, "Cut Speed", "How long each haircut takes. Fast 7s, Normal 12s, Slow 20s", SPEED_OPTIONS_CUT, function()
			return STATE.cutSpeed
		end, function(option)
			STATE.cutSpeed = option
		end)
		cutInfo = info(cutBox, "Status", "Starting")

		local productBox = section(cutTab, "Finishing Products", "sparkles")
		choice(productBox, "Use Products", "Smart: Hot Towel every cut (2s mini-game), slow ones only when the bonus is worth it. Always best: best product every cut (slow ones take ~19s)", PRODUCT_OPTIONS, function()
			return STATE.useProducts
		end, function(option)
			STATE.useProducts = option
		end)
		toggle(productBox, "Auto Buy Products", "autoBuyProducts", "Keeps a few of the products it uses in stock")

		local videoBox = section(cutTab, "ClipTok Videos", "camera")
		toggle(videoBox, "Auto Post Videos", "autoPost", "Posts the before & after video of every cut for followers and more customers (stops by itself just before followers max out). Off = discards them")
	end

	local shopInfo
	do
		local buildBox = section(shopTab, "Build & Staff", "hammer")
		toggle(buildBox, "Auto Build", "autoBuild", "Builds the next piece of your shop. Bigger shop = more pay, more staff and better tools")
		toggle(buildBox, "Auto Hire Barbers", "autoHire", "Barbers cut hair and earn for you, even while you're away")
		toggle(buildBox, "Auto Station Upgrades", "autoStations", "Upgrades your barbers' stations")
		toggle(buildBox, "Auto Hire Sweepers", "autoSweepers", "Keeps the floor clean for the Clean Shop bonus")
		toggle(buildBox, "Auto Upgrade Chair", "autoChair", "Upgrades your own barber chair")

		local toolBox = section(shopTab, "Tools & Skills", "wrench")
		toggle(toolBox, "Auto Buy Tools", "autoTools", "Buys and equips the next tier of clippers, trimmer, razor, scissors and sponge")
		toggle(toolBox, "Auto Skill Tree", "autoSkills", "Learns skills from the Skill Tree")
		shopInfo = info(toolBox, "Spending", "The hub buys the cheapest upgrade it can afford first.")
	end

	do
		local claimBox = section(rewardTab, "Free Rewards", "gift")
		toggle(claimBox, "Auto Claim", "autoClaim", "Daily reward, finished quests, quest chests, Barber Pass (free) and playtime gifts")
		toggle(claimBox, "Auto Empty Tip Jar", "autoTips", "Walks over and empties your tip jar between customers")
		toggle(claimBox, "Grab Product Drops", "autoDrops", "Walks to the free product crates that land nearby")
		toggle(claimBox, "Collect Coins", "autoCoins", "Picks up the coins round your shop between customers (lots during Money Rain)")
	end

	do
		local moveBox = section(playerTab, "Movement", "footprints")
		toggle(moveBox, "Custom Walk Speed", "walkSpeed")
		choice(moveBox, "Walk Speed", "16 is the normal speed", SPEED_OPTIONS, function()
			return tostring(STATE.speed)
		end, function(option)
			STATE.speed = tonumber(option) or STATE.speed
		end)

		local clientBox = section(playerTab, "Performance & AFK", "cpu")
		toggle(clientBox, "Anti AFK", "antiAfk")
		toggle(clientBox, "Auto Reconnect on Kick", "autoReconnect")
		toggle(clientBox, "Hide Roblox Pause Popup", "noPausePopup")
		toggle(clientBox, "Potato Mode", "fpsBoost", "Turns off particles, trails, lights and shadows")
		toggle(clientBox, "AFK Black Screen", "disable3d", "Stops drawing the world")

		local serverBox = section(playerTab, "Server", "server")
		info(serverBox, "This Server", "Job " .. string.sub(game.JobId, 1, 8) .. "... · Place " .. tostring(game.PlaceId))
		button(serverBox, "Rejoin", nil, "rotate-ccw", function()
			STATE.rejoin()
		end)
		button(serverBox, "Server Hop", nil, "shuffle", function()
			if not STATE.hop(false) then
				notify("No other server found", "Try again in a moment")
			end
		end)
		button(serverBox, "Lowest Player Server", nil, "users", function()
			if not STATE.hop(true) then
				notify("No other server found", "Try again in a moment")
			end
		end)
		button(serverBox, "Copy Job ID", nil, "copy", function()
			if typeof(setclipboard) == "function" and pcall(setclipboard, game.JobId) then
				notify("Job ID copied", game.JobId)
			else
				notify("Copy is not available", game.JobId)
			end
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
			return STATE.hubSize or "Compact"
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
			notify("Saved", "Settings saved for " .. LocalPlayer.DisplayName)
		end)

		local communityBox = section(settingsTab, "Community", "message-circle")
		button(communityBox, "Copy Discord Invite", "discord.gg/94pC3T6NZG", "copy", function()
			local invite = "https://discord.gg/94pC3T6NZG"
			if typeof(setclipboard) == "function" and pcall(setclipboard, invite) then
				notify("Invite copied", "Paste it in your browser")
			else
				notify("Discord invite", invite)
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
		local rating = tonumber(attr("Rating")) or 0
		if rating > 5 then
			rating = 5
		end
		setInfo(overview, string.format(
			"%s\n$%s  ·  %s followers  ·  %.1f stars\nShop level %s  ·  %d barbers  ·  Streak %s\nSession %s",
			tostring(STATE.status or "Waiting"),
			shortNumber(cash()),
			shortNumber(attr("Followers") or 0),
			rating,
			tostring(storeLevel()),
			#barbersList(),
			tostring(attr("Streak") or 0),
			clock
		))
		local lines = {
			string.format("Haircuts %d (%d five-star)  ·  Earned $%s", stats.cuts, stats.fives, shortNumber(stats.earned)),
			string.format("Videos %d (+%s followers)  ·  Tips $%s", stats.videos, shortNumber(stats.followers), shortNumber(stats.tips)),
			string.format("Products used %d  ·  Drops %d  ·  Coins %d", stats.products, stats.drops, stats.coins),
			string.format("Built %d  ·  Hired %d  ·  Bought %d  ·  Claimed %d", stats.built, stats.hired, stats.bought, stats.claimed),
		}
		if attr("Tutorial") == "on" then
			lines[#lines + 1] = "The game's tutorial is still on. Cuts still work"
		end
		if STATE.antiAfk == true then
			lines[#lines + 1] = STATE.antiAfkOperational == true and "Anti AFK active" or "Anti AFK waiting for idle"
		end
		for _, item in ipairs(STATE.activity) do
			lines[#lines + 1] = tostring(item)
		end
		setInfo(activityInfo, table.concat(lines, "\n"))
		local waiting = #waitingCustomers()
		setInfo(cutInfo, tostring(STATE.status or "Waiting") .. (STATE.detail ~= "" and ("\n" .. tostring(STATE.detail)) or "") .. "\n" .. waiting .. " waiting")
		setInfo(shopInfo, "The hub buys the cheapest upgrade it can afford first.\n" .. tostring(shop.lastText or ""))
	end

	task.spawn(function()
		while running() and not windowGone do
			pcall(refresh)
			task.wait(1)
		end
	end)

	if STATE.hideOnStart == true then
		-- WindUI opens itself again just after it is made (with an animation),
		-- so an immediate Close left the menu open. Close it once it settles,
		-- and only while it is showing, so a close can never flip it open.
		for _, delay in ipairs({ 0.8, 1.6, 3 }) do
			task.delay(delay, function()
				if windowGone or not running() then
					return
				end
				elevate()
				local frame = Window.UIElements and Window.UIElements.Main
				if typeof(frame) == "Instance" and frame.Parent and frame:IsA("GuiObject") and frame.Visible then
					pcall(Window.Close, Window)
				end
			end)
		end
	end
end

loadSaved()
STATE.version = "1.1.1"

if running() then
	elevate()
	local ok, err = xpcall(installHub, debug.traceback)
	if not ok then
		warn("[Zinoos hub] " .. tostring(err))
	end
end

-- Customers and videos.
task.spawn(function()
	elevate()
	while running() do
		local ok, err = pcall(function()
			stepVideo()
			stepErrands()
			stepCall()
		end)
		if not ok then
			STATE.detail = tostring(err)
			warn("[Zinoos hub] " .. tostring(err))
			task.wait(2)
		else
			task.wait(0.4)
		end
	end
end)

-- Shop, tips and rewards.
task.spawn(function()
	elevate()
	task.wait(3)
	while running() do
		pcall(stepShop)
		pcall(stepClaims)
		elevate()
		task.wait(1)
	end
end)

task.spawn(function()
	elevate()
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
