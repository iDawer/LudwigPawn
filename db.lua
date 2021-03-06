--[[
	database.lua
		The database portion Of Ludwig
--]]

local MAXID = 40000 --probably need to increase this to 40k by Wrath
local MAXIMUM_LEVEL = 70

local lastSearch --this is a hack to allow for 3 variables when sorting.  Its used to give the name filter
local filteredList = {}
local searchList = {}
local db, itemInfo


--[[ Sorting Functions ]]--

local GetItemInfo = GetItemInfo

--returns the difference between two strings, where one is known to be within the other.
local function GetDist(str1, str2)
	--a few optimizations for when we already know distance
	if str1 == str2 then
		return 0
	end

	if not str1 then
		return #str2
	end

	if not str2 then
		return #str1
	end

	return abs(#str1 - #str2)
end

--sorts a list by rarity, either closeness to the searchString if there's been a search, then level, then name
local function SortByEverything(id1, id2)
	local name1 = db[id1]
	local name2 = db[id2]
	local rarity1 = itemInfo[3][id1]
	local rarity2 = itemInfo[3][id2]
	local level1 = itemInfo[4][id1]
	local level2 = itemInfo[4][id2]

	if rarity1 ~= rarity2 then
		return rarity1 > rarity2
	end

	if lastSearch then
		local dist1 = GetDist(lastSearch, name1)
		local dist2 = GetDist(lastSearch, name2)
		if dist1 ~= dist2 then
			return dist1 < dist2
		end
	end

	if level1 ~= level2 then
		return level1 > level2
	end

	return name1 < name2
end

--sort by distance to the searchTerm
local function SortByDistance(id1, id2)
	return GetDist(lastSearch, db[id1]) < GetDist(lastSearch, db[id2])
end

local function CreateItemCacheTable()
	local info = {}
	for i = 1, 10 do
		info[i] = setmetatable({}, {
			__index = function(t, k)
				local stats = (select(i, GetItemInfo(k)))
				if stats then
					t[k] = stats
				end
				return stats
			end
		})
	end
	return info
end

local function ToSearch(name)
	return name:gsub('%p', '%%%1')
end


--[[ Usable Functions ]]--

Ludwig = {}

function Ludwig:GetAllItems(refresh)
	if not itemInfo then
		itemInfo = CreateItemCacheTable()
	end

	if not db or refresh then
		db = db or {}
		for i = 1, MAXID do
			local name = itemInfo[1][i]
			if not db[i] and name then
				db[i] = name:lower()
			end
		end
	end
	return db
end

function Ludwig:GetItems(name, quality, typefilters, minLevel, maxLevel)
	local db = self:GetAllItems()
	local stats = itemInfo
	local search, addItem, addItemByType

	if name and name ~= '' then
		name = name:lower()
		search = ToSearch(name)
		--this is a hack to obtain better performance, we're not filtering searches by closeness for short strings
		if #name > 2 then
			lastSearch = name
		else
			lastSearch = nil
		end
	else
		lastSearch = nil
		name = nil
	end

	for i in pairs(filteredList) do
		filteredList[i] = nil
	end

	local count = 0

	for id, itemName in pairs(db) do
		addItem = true
		addItemByType = true

		if quality and stats[3][id] ~= quality then
			addItem = nil
		elseif minLevel and stats[5][id] < minLevel then
			addItem = nil
		elseif maxLevel and stats[5][id] > maxLevel then
			addItem = nil
		elseif name then
			if not(name == itemName or itemName:find(search)) then
				addItem = nil
			end
		end

		if typefilters then
			local type, subType, equipLoc
			for _,filter in pairs(typefilters) do
				type, subType, equipLoc = filter.type, filter.subType, filter.equipLoc
				if filter then
					addItemByType = true
					if type and stats[6][id] ~= type then
						addItemByType = nil
					elseif subType and stats[7][id] ~= subType then
						addItemByType = nil
					elseif equipLoc and stats[9][id] ~= equipLoc then
						addItemByType = nil
					else
						break
					end
				end
			end
		end

		if addItem and addItemByType then
			count = count + 1
			filteredList[count] = id
		end
	end

	table.sort(filteredList, SortByEverything)

	return filteredList
end

function Ludwig:GetItemsNamedLike(name)
	if name == '' then return end

	local name = name:lower()
	local search = '^' .. ToSearch(name)

	for i in pairs(searchList) do
		searchList[i] = nil
	end

	local db = self:GetAllItems()
	for id, itemName in pairs(db) do
		if itemName == name or itemName:find(search) then
			table.insert(searchList, id)
			if itemName == name then
				break
			end
		end
	end

	lastSearch = search
	if next(searchList) then
		table.sort(searchList, SortByDistance)
	end
	return searchList
end

function Ludwig:GetItemName(id, inColor)
	local stats = itemInfo
	local name = stats[1][id]
	if name and inColor then
		local rarity = stats[3][id]
		local hex = (select(4, GetItemQualityColor(rarity)))
		return format('%s%s|r', hex, name)
	end
	return name
end

function Ludwig:GetItemLink(id)
	return (select(2, GetItemInfo(id)))
end

function Ludwig:GetItemTexture(id)
	return itemInfo[10][id]
end

function Ludwig:ReloadDB()
	self:GetAllItems(true)
end

Ludwig.SortByEverything = SortByEverything
