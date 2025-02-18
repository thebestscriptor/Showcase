local TradingHandler = {};
TradingHandler.__index = TradingHandler

TradingHandler.ActiveTrades = {}
TradingHandler.PlayerHandler = nil

local function GetItemCount(Inventory: {}, Name: string)
	local Count = 0
	
	for _, SwordName in next, Inventory do
		if (SwordName == Name) then
			Count += 1
		end
	end
	
	return Count
end

function TradingHandler:_LoadNetwork(PlayerHandler: {})
	self.PlayerHandler = PlayerHandler
end

function TradingHandler:_AddItem(Player: Player, SwordName: string?)
	if (not SwordName) or (typeof(SwordName) ~= 'string') then
		return
	end
	
	if (not self.ActiveTrades[Player]) then
		return
	end
	
	local Controller
	
	if not Player:GetAttribute('IsFake') then
		Controller = self.PlayerHandler:GetController(Player);
		if (not Controller) then
			return
		end
	else
		Controller = {}
		
		function Controller:GetData()
			return {
				Inventory = {SwordName, SwordName, SwordName}
			}
		end
	end
	
	local Inventory = Controller:GetData().Inventory
	local InventoryCount = GetItemCount(Inventory, SwordName)
	
	if (InventoryCount < 1) then
		return
	end
	
	if (GetItemCount(self.ActiveTrades[Player].Items, SwordName) == InventoryCount) then
		return
	end
	
	table.insert(self.ActiveTrades[Player].Items, SwordName)
	
	return true
end

function TradingHandler:BeginTrade(Player: Player, PlayerTwo: Player)
	if self.ActiveTrades[Player] or self.ActiveTrades[PlayerTwo] then
		return false
	end
	
	self.ActiveTrades[Player] = {
		Items = {},
		OtherPlayer = PlayerTwo
	}
	
	self.ActiveTrades[PlayerTwo] = {
		Items = {},
		OtherPlayer = Player
	}
	
	return true
end

function TradingHandler:CommitTrade(Player: Player, PlayerTwo: Player, TradeStatus: string?)
	if not (self.ActiveTrades[Player] and self.ActiveTrades[PlayerTwo]) then
		return false
	end
	
	if (self.ActiveTrades[Player].OtherPlayer ~= PlayerTwo) or (self.ActiveTrades[PlayerTwo].OtherPlayer ~= Player) then
		return false
	end
	
	if (TradeStatus == 'Cancelled') or (TradeStatus == 'Aborted') then
		self.ActiveTrades[Player] = nil
		self.ActiveTrades[PlayerTwo] = nil
	elseif (TradeStatus == 'Accepted') then
		
		local Controller
		local ControllerTwo
		
		if not Player:GetAttribute('IsFake') then
			Controller = self.PlayerHandler:GetController(Player);
			if (not Controller) then
				return
			end
		else
			Controller = {}
			Controller.ActiveTrades = self.ActiveTrades

			function Controller:GetData()
				return {
					Inventory = table.clone(self.ActiveTrades[Player].Items)
				}
			end
		end
		
		if not PlayerTwo:GetAttribute('IsFake') then
			ControllerTwo = self.PlayerHandler:GetController(PlayerTwo);
			if (not ControllerTwo) then
				return
			end
		else
			ControllerTwo = {}
			ControllerTwo.ActiveTrades = self.ActiveTrades
			
			function ControllerTwo:GetData()
				return {
					Inventory = table.clone(self.ActiveTrades[PlayerTwo].Items)
				}
			end
		end
		
		if not (Controller and ControllerTwo) then
			return
		end
		
		for _, SwordName in next, self.ActiveTrades[Player].Items do
			local Inventory = Controller:GetData().Inventory
			
			table.remove(Inventory, table.find(Inventory, SwordName))
		
			if not Player:GetAttribute('IsFake') then
				ControllerTwo:AppendData('Inventory', SwordName)
			else
				table.remove(self.ActiveTrades[Player].Items, table.find(self.ActiveTrades[Player].Items, SwordName))
				table.insert(self.ActiveTrades[PlayerTwo].Items, SwordName)
			end
			
			Inventory = nil
		end
		
		for _, SwordName in next, self.ActiveTrades[PlayerTwo].Items do
			local Inventory = ControllerTwo:GetData().Inventory

			table.remove(Inventory, table.find(Inventory, SwordName))
			
			if not PlayerTwo:GetAttribute('IsFake') then
				Controller:AppendData('Inventory', SwordName)
			else
				table.remove(self.ActiveTrades[PlayerTwo].Items, table.find(self.ActiveTrades[PlayerTwo].Items, SwordName))
				table.insert(self.ActiveTrades[Player].Items, SwordName)
			end
			
			Inventory = nil
		end
		
		self.ActiveTrades[Player] = nil
		self.ActiveTrades[PlayerTwo] = nil
	end
	
	return true
end

require(script.FakeScenario):_set(TradingHandler)

return TradingHandlerlocal TradingHandler = {};
TradingHandler.__index = TradingHandler

TradingHandler.ActiveTrades = {}
TradingHandler.PlayerHandler = nil

local function GetItemCount(Inventory: {}, Name: string)
	local Count = 0

	for _, SwordName in next, Inventory do
		if (SwordName == Name) then
			Count += 1
		end
	end

	return Count
end

function TradingHandler:_LoadNetwork(PlayerHandler: {})
	self.PlayerHandler = PlayerHandler
end

function TradingHandler:_AddItem(Player: Player, SwordName: string?)
	if (not SwordName) or (typeof(SwordName) ~= 'string') then
		return
	end

	if (not self.ActiveTrades[Player]) then
		return
	end

	local Controller

	if not Player:GetAttribute('IsFake') then
		Controller = self.PlayerHandler:GetController(Player);
		if (not Controller) then
			return
		end
	else
		Controller = {}

		function Controller:GetData()
			return {
				Inventory = {SwordName, SwordName, SwordName}
			}
		end
	end

	local Inventory = Controller:GetData().Inventory
	local InventoryCount = GetItemCount(Inventory, SwordName)

	if (InventoryCount < 1) then
		return
	end

	if (GetItemCount(self.ActiveTrades[Player].Items, SwordName) == InventoryCount) then
		return
	end

	table.insert(self.ActiveTrades[Player].Items, SwordName)

	return true
end

function TradingHandler:BeginTrade(Player: Player, PlayerTwo: Player)
	if self.ActiveTrades[Player] or self.ActiveTrades[PlayerTwo] then
		return false
	end

	self.ActiveTrades[Player] = {
		Items = {},
		OtherPlayer = PlayerTwo
	}

	self.ActiveTrades[PlayerTwo] = {
		Items = {},
		OtherPlayer = Player
	}

	return true
end

function TradingHandler:CommitTrade(Player: Player, PlayerTwo: Player, TradeStatus: string?)
	if not (self.ActiveTrades[Player] and self.ActiveTrades[PlayerTwo]) then
		return false
	end

	if (self.ActiveTrades[Player].OtherPlayer ~= PlayerTwo) or (self.ActiveTrades[PlayerTwo].OtherPlayer ~= Player) then
		return false
	end

	if (TradeStatus == 'Cancelled') or (TradeStatus == 'Aborted') then
		self.ActiveTrades[Player] = nil
		self.ActiveTrades[PlayerTwo] = nil
	elseif (TradeStatus == 'Accepted') then

		local Controller
		local ControllerTwo

		if not Player:GetAttribute('IsFake') then
			Controller = self.PlayerHandler:GetController(Player);
			if (not Controller) then
				return
			end
		else
			Controller = {}
			Controller.ActiveTrades = self.ActiveTrades

			function Controller:GetData()
				return {
					Inventory = table.clone(self.ActiveTrades[Player].Items)
				}
			end
		end

		if not PlayerTwo:GetAttribute('IsFake') then
			ControllerTwo = self.PlayerHandler:GetController(PlayerTwo);
			if (not ControllerTwo) then
				return
			end
		else
			ControllerTwo = {}
			ControllerTwo.ActiveTrades = self.ActiveTrades

			function ControllerTwo:GetData()
				return {
					Inventory = table.clone(self.ActiveTrades[PlayerTwo].Items)
				}
			end
		end

		if not (Controller and ControllerTwo) then
			return
		end

		for _, SwordName in next, self.ActiveTrades[Player].Items do
			local Inventory = Controller:GetData().Inventory

			table.remove(Inventory, table.find(Inventory, SwordName))

			if not Player:GetAttribute('IsFake') then
				ControllerTwo:AppendData('Inventory', SwordName)
			else
				table.remove(self.ActiveTrades[Player].Items, table.find(self.ActiveTrades[Player].Items, SwordName))
				table.insert(self.ActiveTrades[PlayerTwo].Items, SwordName)
			end

			Inventory = nil
		end

		for _, SwordName in next, self.ActiveTrades[PlayerTwo].Items do
			local Inventory = ControllerTwo:GetData().Inventory

			table.remove(Inventory, table.find(Inventory, SwordName))

			if not PlayerTwo:GetAttribute('IsFake') then
				Controller:AppendData('Inventory', SwordName)
			else
				table.remove(self.ActiveTrades[PlayerTwo].Items, table.find(self.ActiveTrades[PlayerTwo].Items, SwordName))
				table.insert(self.ActiveTrades[Player].Items, SwordName)
			end

			Inventory = nil
		end

		self.ActiveTrades[Player] = nil
		self.ActiveTrades[PlayerTwo] = nil
	end

	return true
end

require(script.FakeScenario):_set(TradingHandler)

return TradingHandler
