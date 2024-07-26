local DataStoreService = game:GetService('DataStoreService');
local DataStores = {};
local Cache = {};
local Cur = nil

local Remote = game.ReplicatedStorage:WaitForChild('LBRemote');
local Names = {'Kills', 'Time', 'Level'};

game.Players.PlayerAdded:Connect(function(Player: Player)
	Player:GetAttributeChangedSignal('Loaded'):Wait()
	
	task.delay(1, function()
		if (not Cur) then
			return
		end
		
		Remote:FireClient(Player, Cur)
	end)
end)

game.Players.PlayerRemoving:Connect(function(Player: Player)
	Cache[Player] = nil
end)

for _, Name in next, Names do
	DataStores[Name] = DataStoreService:GetOrderedDataStore(Name)
end

local function LoadPlayers()
	for _, Player in next, game.Players:GetPlayers() do
		local Profile = shared.GetProfile(Player);
		if (not Profile) then
			continue
		end
		
		if (not Cache[Player]) then
			Cache[Player] = {}
		end
		
		for _, Name in next, Names do
			Cache[Player][Name] = Profile.Data.Stats[Name]
			
			if (Cache[Player][Name]) then
				DataStores[Name]:SetAsync(Player.UserId..Name, Cache[Player][Name])
			end
		end
	end
end

local function UpdateLeaderboards()
	local Current = {};
	
	local Last = nil
	local PageNum = 1

	for _, Name in next, Names do
		local DataStore = DataStores[Name];
		
		if (not Current[Name]) then
			Current[Name] = {}
		end
		
		local Last = nil
		local PageNum = 1
		
		repeat
			local Page = DataStore:GetSortedAsync(false, 100, nil, Last);
			
			while task.wait(0.1) do
				for Order, Data in Page:GetCurrentPage() do
					local UserId = Data.key:sub(1, #Data.key - #Name);
					local Value = Data.value

					Current[Name][Order] = {Order, Name, UserId, Value}
				end

				if (Page.IsFinished) then
					break
				end

				Page:AdvanceToNextPage()
			end
			
			PageNum += 1
		until (PageNum == 2) or (Page.IsFinished)
	end
	
	Cur = Current
	Remote:FireAllClients(Current)
end

task.delay(5, function()
	LoadPlayers()
	UpdateLeaderboards()
end)

while task.wait(120) do
	LoadPlayers()
	UpdateLeaderboards()
end
