--[[
	Author: Dakota
	Credits: DateTime/Time-Span Modules (https://devforum.roblox.com/t/datetime-and-timespan-module/530563)
]]

--/ Players Service
local Players = game:GetService('Players');

--/ DateTime Module
local DateTime = require(script.DateTime);

--/ Codes List (I'd prefer modularizing this but won't for showcase purposes)
local Codes = {
	['Opening'] = {
		LimitedTime = true,
		EndSale = DateTime.DateTime.new(2024, 12, 25, 6, 0, 0),
		
		Callback = function(Player: Player, Profile: any)
			Profile.Data.Stats.Spins = (Profile.Data.Stats.Spins + 3)
			Profile.Data.Stats.Time = (Profile.Data.Stats.Time + 1000)

			shared.ForceUpdate(Player)
			shared.Network:Fire('Notify', Player, 'Success', '+1,000 Time | +3 Spins')
		end
	};
	
	['Expired'] = {
		LimitedTime = true,
		EndSale = DateTime.DateTime.new(2024, 7, 6, 6, 0, 0),

		Callback = function(Player: Player, Profile: any)
			Profile.Data.Stats.Spins = (Profile.Data.Stats.Spins + 3)
			Profile.Data.Stats.Time = (Profile.Data.Stats.Time + 1000)
			
			shared.ForceUpdate(Player)
			shared.Network:Fire('Notify', Player, 'Success', '+1,000 Time | +3 Spins')
		end
	};
};

--/ Remote Setup
local Remote = Instance.new('RemoteFunction', game.ReplicatedStorage);
Remote.Name = 'CodeRemote'
Remote.OnServerInvoke = function(Player: Player, Code: string)
	if not (Code and typeof(Code) == 'string' and Codes[Code]) then
		return shared.Network:Fire('Notify', Player, 'Alert', 'This code does not exist!')
	end
	
	local Profile = shared.GetProfile(Player);
	if (not Profile) then
		return shared.Network:Fire('Notify', Player, 'Alert', 'Your data is not loaded!')
	end
	
	if table.find(Profile.Data.Codes, Code) then
		return shared.Network:Fire('Notify', Player, 'Alert', 'Already Redeemed!')
	end
	
	if (Codes[Code].LimitedTime) and (DateTime.DateTime.Now() > Codes[Code].EndSale) then
		return shared.Network:Fire('Notify', Player, 'Alert', 'Code Expired!')
	end
	
	Codes[Code].Callback(Player, Profile)
	table.insert(Profile.Data.Codes, Code)
	
	return true
end
