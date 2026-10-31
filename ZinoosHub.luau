-- Zinoos hub loader. One loadstring for every supported game.
-- It works out which game you are in and loads that game's hub from games/.

local BASE = "https://raw.githubusercontent.com/yszvzms6st-pixel/ZinoosHub/main/games/"

local GAMES = {
	{ name = "Lift Rock For Eggs", file = "LiftRock.luau", placeId = 76731343328034 },
	{ name = "Deep Fishing", file = "DeepFishing.luau", gameId = 10526853622 },
	{ name = "Solve The Cube", file = "SolveTheCube.luau", gameId = 10769259605 },
	{ name = "Climb For Animals Eggs", file = "ClimbAnimals.luau", gameId = 10765490774 },
	{ name = "Throw Food For Animals", file = "ThrowFoodAnimals.luau", gameId = 10766972131 },
}

local entry = nil
for _, candidate in ipairs(GAMES) do
	if (candidate.placeId and game.PlaceId == candidate.placeId) or (candidate.gameId and game.GameId == candidate.gameId) then
		entry = candidate
		break
	end
end
if not entry then
	local names = {}
	for _, candidate in ipairs(GAMES) do
		names[#names + 1] = candidate.name
	end
	warn("[Zinoos hub] This game is not supported yet. Supported: " .. table.concat(names, ", ") .. ".")
	return
end

local ok, source = pcall(function()
	return game:HttpGet(BASE .. entry.file .. "?t=" .. tostring(os.time()))
end)
if not ok or type(source) ~= "string" or source == "" then
	warn("[Zinoos hub] Could not download the " .. entry.name .. " hub: " .. tostring(source))
	return
end

local chunk, err = loadstring(source, "=ZinoosHub/" .. entry.file)
if not chunk then
	warn("[Zinoos hub] The " .. entry.name .. " hub did not compile: " .. tostring(err))
	return
end
return chunk(...)
