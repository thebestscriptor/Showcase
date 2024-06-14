--/ Types
export type ClanData = {
	i: number, -- Id
	t: string | number, -- Tag
	n: string | number, -- Name
	d: {[string | number]: any}, -- Data
	ig: string | number, -- ImageId
	o: number, -- OwnerId
	m: table, -- Members
	mc: number, -- MemberCount
	ds: string | number -- Description
}; -- reason any strings also include numbers is because technically players can name their clans just numbers if we don't block that

export type ClanLeaderData = {
	p: number, -- Points
	k: number, -- Kills
	l: number, -- Level
	lu: number -- LastUpdate
};

--/ Services
local Players = game:GetService('Players');
local HttpService = game:GetService('HttpService');
local DataStoreService = game:GetService('DataStoreService');
local ReplicatedStorage = game:GetService('ReplicatedStorage');

--/ Imports
local Remotes
local DataRemote, ServerRemote, ClientRemote

--/ TabledTypes
local Keys = {'t', 'n', 'ig', 'ds'}; -- list of NEEDED arguments

--/ Data Store
local ClanDatastore = DataStoreService:GetDataStore('Clans1');

--/ Module
local Cache = {};
local ClanModule = {};

--/ Tracker
local Tracker = require(script.CountTracker);
local CountKeeper = Tracker('ClanCount');

--/ Request Settings
local RequestSettings = {
	PageSize = 50,
	IsAscending = false
};

--/ Setup
Players.PlayerRemoving:Connect(function(Player: Player)
	for	UserId, ClanData in next, Cache do
		if (ClanData:Get('o') == Player.UserId) then
			Cache[UserId] = nil
			break
		end
	end
end)

--/ Local Functions
local function GetTopClans(Number: number)
	local ReturnData = {};
	
	local Pages = ClanDatastore:ListKeysAsync()
	
	while true do
		local Page = Pages:GetCurrentPage();
		
		if (#ReturnData >= Number) then
			break
		end

		for Position, Data in ipairs(Page) do
			ReturnData[Position] = {UserId = Data.KeyName:gsub('-Clan', ''), ClanData = HttpService:JSONDecode(ClanDatastore:GetAsync(Data.KeyName))}
			
			if (#ReturnData >= Number) then
				break
			end
		end
		
		if (Pages.IsFinished) then
			break
		end
		
		Pages:AdvanceToNextPageAsync()
	end
	
	table.sort(ReturnData, function(A, B)
		return A.ClanData.mc > B.ClanData.mc --TODO: sorted by member count for now, soon to change to data when we add it
	end)
	
	return ReturnData
end

--/ Generating tag function
local function GenerateTag(StringCount: number)
	local Tag = string.gsub(HttpService:GenerateGUID(false):sub(1, 7), "-", "")
	return Tag:sub(1, StringCount)
end

--/ Function to filter strings
local function FilterAsync(Player: Player, String: string)
	local Filtered = ''
	local Success, Error = pcall(function()
		Filtered = game.TextService:FilterStringAsync(String, Player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	
	return Filtered or ''
end

local function Filter(Player: Player, String: string, MaxLetters: number)
	String = tostring(String) or ''
	MaxLetters = MaxLetters or (#String + 1)
	
	while task.wait() do
		local Change = false
		local First = String:sub(1, 1);

		if (First == '') or (First == ' ') or (First == '	') then
			String = String:sub(2, #String)
			Change = true
		end

		local Last = String:sub(#String, #String);

		if (Last == ' ') or (Last == '	') or (Last == '') then
			String = String:sub(1, #String - 1)
			Change = true
		end

		if (not Change) then
			break
		end
	end
	
	local Tag = String:sub(1, MaxLetters);
	if (not Tag) then
		return ''
	end
	
	return FilterAsync(Player, Tag):sub(1, MaxLetters)
end

--/ Local Functions to get a clan by userid
local function GetClanData(OwnerId: number)
	local Data
	local Success, Error = pcall(function()
		Data = ClanDatastore:GetAsync(`{OwnerId}-Clan`)
		return Data
	end)

	if not (Success and Error) then
		return nil
	end
	
	return HttpService:JSONDecode(Data)
end

local function GetClanId(OwnerId: number)
	local Data = GetClanData(OwnerId);
	return Data and Data.i
end

--/ Local Functions to create clans
local function ListClan(ClanData: ClanData)
	local Trimmed = {
		['i'] = ClanData.Id or ClanData.i,
		['t'] = ClanData.Tag or ClanData.t,
		['n'] = ClanData.Name or ClanData.n,
		['d'] = HttpService:JSONEncode(ClanData.Data or ClanData.d or {}),
		['ig'] = ClanData.ImageId or ClanData.ig,
		["o"] = ClanData.OwnerId or ClanData.o,
		['m'] = HttpService:JSONEncode(ClanData.Members or ClanData.m or {}),
		['mc'] = ClanData.MemberCount or ClanData.mc,
		['ds'] = ClanData.Description or ClanData.ds
	}
	
	local ClanKey = `{Trimmed.o}-Clan` -- OwnerId-Clan
	
	ClanDatastore:SetAsync(ClanKey, HttpService:JSONEncode(Trimmed))
end

local function CreateClan(Player: Player, ClanData: ClanData)
	if GetClanData(Player.UserId) then
		return
	end
	
	if (ClanData.Tag) then
		ClanData.Tag = Filter(Player, tostring(ClanData.Tag), 5)
	end
	
	local Count = CountKeeper.try('Clans');
	local Data = {
		['Id'] = Count,
		['Tag'] = ClanData.Tag or ClanData.t or GenerateTag(math.random(1, 5)),
		['Name'] = ClanData.Name or ClanData.n or `{Player.Name}'s Clan`,
		['Data'] = ClanData.Data or ClanData.d or {},
		['ImageId'] = ClanData.ImageId or ClanData.ig or 'rbxasset://textures/ui/GuiImagePlaceholder.png',
		['OwnerId'] = Player.UserId,
		['Members'] = {Player.UserId},
		['MemberCount'] = 1,
		['Description'] = ClanData.Description or ClanData.ds or 'None'
	};
	
	ListClan(Data)
end

local function UpdateClan(OwnerId: number, ClanData: ClanData)
	local CurrentData = GetClanData(OwnerId);
	if (not CurrentData) then
		return
	end
	
	if (CurrentData.i ~= (ClanData.Id or ClanData.i)) then
		return
	end

	local DetectedChange = false
	
	for Key, Value in next, CurrentData do
		if (not ClanData[Key]) then
			return warn(`ClanData[{Key}] doesn't exist` )
		end
		
		if (ClanData[Key] ~= Value) then
			DetectedChange = true
			break
		end
	end
	
	if (DetectedChange) then
		ListClan(ClanData)
	else
		warn(`No change detected in {OwnerId}'s clan`)
	end
end

--/ Misc
function ClanModule:Init()
	Remotes = require(ReplicatedStorage.Shared.Remotes)
	return
end

function ClanModule:Start()
	local Namespace = Remotes.Server:GetNamespace("Clans");

	DataRemote = Namespace:Get('GetData');
	ClientRemote = Namespace:Get('ClientAction')
	ServerRemote = Namespace:Get('ServerAction');
	
	DataRemote:SetCallback(function(Player: Player, ToGet: string)
		if (ToGet == 'TopClans') then
			return GetTopClans(10)
		elseif (ToGet == 'ClanData') then
			return Cache[Player.UserId] and Cache[Player.UserId].Data or {}
			--return Cache[Player.UserId] and Cache[Player.UserId]:RetrieveSafeData() or {}
		end
	end)
	
	ClientRemote:Connect(function(...)
		local Arguments = {...};
		
		local Caller: Player = Arguments[1];
		local Action: string = Arguments[2];
		local ClanData: ClanData = Arguments[3];
		
		if (not Action) then return end

		if (Action == 'Update') then
			assert(Cache[Caller.UserId], `Cache for {Caller.Name} doesn't exist.`)
			
			for _, Key in next, Keys do
				assert(ClanData[Key], `ClanData[{Key}] doesn't exist.`)
			end
			
			for _, Key in next, Keys do
				Cache[Caller.UserId]:Set(Key, ClanData[Key])
			end
			
			Cache[Caller.UserId]:Update()
		elseif (Action == 'Create') then
			assert(not Cache[Caller.UserId], `Clan for {Caller.Name} already exists.`)
			
			for _, Key in next, Keys do
				assert(ClanData[Key], `ClanData[{Key}] doesn't exist.`)
			end
			
			local Clan = ClanModule.cache(Caller.UserId);

			for _, Key in next, Keys do
				Clan:Set(Key, ClanData[Key])
			end
			
			Clan:Init()
			Clan:Update()
			
			return Clan
		end
	end)

	return nil
end

--/ Clan Meta
function ClanModule.cache(OwnerId: number)
	if (Cache[OwnerId]) then
		return Cache[OwnerId]
	end
	
	local ClanData = GetClanData(OwnerId);
	
	local self = {};
	
	self.Data = ClanData or {}
	self.Created = ClanData and true or false
	
	function self:SetMany(Keys: {string}, Values: {any})
		for Int = 1, #Keys do
			local Key = Keys[Int];
			local Value = Values[Int];
			
			if (Key and Value) then
				self.Data[Key] = Value
			end
		end
	end
	
	function self:GetMany(...)
		local New = {};
		local Keys = {...};
		
		for Int = 1, #Keys do
			local Key = Keys[Int];
			
			if (Key) then
				table.insert(New, self.Data[Key])
			end
		end
		
		return New
	end
	
	function self:RetrieveSafeData()
		local Data = {};
		
		for _, Key in next, Keys do
			Data[Key] = self.Data[Key]
		end
		
		return Data
	end
	
	function self:Set(Key: string, Value: any)
		self.Data[Key] = Value
	end
	
	function self:Get(Key: string)
		return self.Data[Key]
	end
	
	function self:Init()
		assert(not self.Created, 'The clan is already setup')
		
		if (OwnerId == 1) then
			self.Created = true
			return CreateClan({UserId = OwnerId, Name = 'Staff'}, self.Data)
		else
			local Player = Players:GetPlayerByUserId(OwnerId);
			assert(Player, `Player {OwnerId} is not ingame.`)
			
			self.Created = true
			return CreateClan(Player, self.Data)
		end
	end
	
	function self:Update()
		assert(self.Created, 'Please create the clan before updating it.')
		
		return UpdateClan(OwnerId, self.Data)
	end
	
	Cache[OwnerId] = self
	return self
end

--/ Testing API
task.spawn(function()
	local Player = Players:WaitForChild('ThaBronxDevelopment');
	
	local Clan = ClanModule.cache(Player.UserId);
	local StaffClan = ClanModule.cache(1);
	
	StaffClan:SetMany({'t', 'n', 'd', 'ig', 'ds'}, { -- not required to set them all but it'd look terrible if u didn't
		'Staff',
		'Official Staff',
		{},
		nil,
		'This is a clan for official staff'
	})

	Clan:SetMany({'t', 'n', 'd', 'ig', 'ds'}, {
		'Coup',
		"Tha Bronx's Clan",
		{},
		'rbxassetid://17851823387',
		'This is a clan created by the greatest person'
	})
	
	if (not Clan.Created) then
		Clan:Init()
	end
	
	if (not StaffClan.Created) then
		StaffClan:Init()
	end
	
	warn(GetTopClans(5))
	
	task.wait(2)
	
	Clan:Set('t', 'Test')
	Clan:Set('m', {StaffClan:Get('o')})
	Clan:Set('mc', 3)
	
	StaffClan:Set('m', {StaffClan:Get('o'), Players:GetUserIdFromNameAsync('pulledupinnaufo'), Players:GetUserIdFromNameAsync('spiralapi')})
	StaffClan:Set('mc', 3)
	
	Clan:Update()
	StaffClan:Update()
	
	warn(GetTopClans(5))
end)

--/ End
return ClanModule
