local ControllersModule = script.Parent:WaitForChild('Controllers');
local Controllers = require(ControllersModule):Init();

local function InitialLoop()
	while task.wait(0.5) do
		for _, Player in next, game.Players:GetPlayers() do
			if (Player and Player.Parent) and Controllers:IsACheater(Player) then
				local Reason = Controllers:GetActiveReason(Player);
				Player:Kick(Reason)
			end
		end
	end
end

task.wait(3)
InitialLoop()
