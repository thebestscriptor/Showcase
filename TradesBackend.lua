--/ Module
local Trades = {};
local Private = {};
local ActiveTrades = {};

--/ Remote
local Remote = game.ReplicatedStorage:WaitForChild('Trade');

--/ Local Functions
local function IsInTrade(Player: Player)
	for _, TradeData in next, Trades do
		if table.find(TradeData.Traders, Player) then
			return TradeData
		end
	end

	return false
end

--/ Private Functionality
function Private.OpenTrade(Player: Player, PlayerTwo: Player)
	table.insert(Trades, {
		Traders = {Player, PlayerTwo},
		Items = {
			[Player] = {},
			[PlayerTwo] = {}
		}
	})
end

function Private.AlterData(Player: Player, TradeData: {any})
	local Profile = shared.GetProfile(Player);
	if (not Profile) then
		return
	end

	local Data = IsInTrade(Player);
	if (not Data) then
		return 'You are not in a trade', Color3.fromRGB(255, 0, 0)
	end

	for _, Data in next, TradeData do
		local Passed = false
		for _, SwordData in next, Profile.Data.Swords do
			if (SwordData.n == Data.n) and (SwordData.l == Data.l) and (SwordData.k == Data.k) then
				Passed = true
				break
			end
		end

		if (not Passed) then
			return `You do not own {Data.n}`, Color3.fromRGB(255, 0, 0)
		end
	end

	Data.Items[Player] = TradeData
	
	for _, OtherPlayer in next, Data.Traders do
		if (OtherPlayer ~= Player) then
			Remote:InvokeClient(Player, 'Altered', OtherPlayer, TradeData)
			break
		end
	end
end

function Private.SendTrade(Player: Player, PlayerTwo: Player)
	local Start = tick()
	local Response = nil

	task.spawn(function()
		Response = Remote:InvokeClient(PlayerTwo, Player)
	end)

	while task.wait(0.5) do
		if (Response) then
			break
		end

		if (tick() - Start) >= 5 then
			return 'Player did not respond.'
		end
	end

	return Response
end

--/ Module Functionality
function Trades.SendTrade(Player: Player, PlayerTwo: Player)
	if IsInTrade(Player) then
		return 'You are already in a trade.', Color3.fromRGB(255, 0, 0)
	end

	if IsInTrade(PlayerTwo) then
		return `{PlayerTwo.Name}'s already in a trade.`, Color3.fromRGB(255, 0, 0)
	end

	local Response = Private.SendTrade(Player, PlayerTwo);
	if (not Response) then
		return `{PlayerTwo.Name} has denied your response`, Color3.fromRGB(255, 0, 0)
	end

	if (typeof(Response) == 'string') then
		return Response, Color3.fromRGB(255, 0, 0)
	end

	Private.OpenTrade(Player, PlayerTwo)
	return 'Success! Trade Opened!', Color3.fromRGB(0, 255, 0)
end

--/ Events
Remote.OnServerInvoke = function(Player: Player, Action: string, ...)
	local Arguments = {...};
	
	if (Action == 'Alter') then
		return Private.AlterData(Player, Arguments[1])
	elseif (Action == 'Send') then
		return Trades.SendTrade(Player, Arguments[1])
	end
end

--/ Return
return Trades
