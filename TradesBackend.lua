local TradingHandler = {};
TradingHandler.__index = TradingHandler

TradingHandler.Pending = {}
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

function TradingHandler:_LoadNetwork(PlayerHandler: {}, Networking: {})
	self.PlayerHandler = PlayerHandler
	self.NetworkHandler = Networking
	
	self.Remote = self.NetworkHandler.new('Remote');
	self.Remote:Rename('TradeRemote')
	
	self.Remote:SetCallback(function(Player: Player, Action: string, ...)
		if (Action == 'SendTrade') then
			local Player2 = ({...})[1];
			if (not Player2) then
				return
			end
			
			self.Pending[Player] = Player2
			self.Remote:Fire(Player, 'UpdateSent', Player2)
			
			task.delay(45, function()
				self.Pending[Player] = nil
				self.Remote:Fire(Player, 'UpdateSent')
			end)
		elseif (Action == 'BeginTrade') then
			local OtherPlayer = ({...})[1];
			if (not OtherPlayer) then
				return
			end
			
			if (self.Pending[OtherPlayer] ~= Player) then
				return
			end
			
			self:BeginTrade(OtherPlayer, Player)
		else
			if (not self.ActiveTrades[Player]) then
				return
			end
		end
		
		if (Action == 'AddItem') then
			self:_AddItem(Player, ...)
		elseif (Action == 'AcceptTrade') then
			local TradeStatus = self:_UpdateAndGetStatus(Player, true)
			local TradeStatus2 = self:_UpdateAndGetStatus(self.ActiveTrades[Player].OtherPlayer)
			
			if (TradeStatus == 'Accepted') and (TradeStatus2 == 'Accepted') then
				self:CommitTrade(Player, self.ActiveTrades[Player].OtherPlayer, 'Accepted')
			else
				self.Remote:Fire(Player, 'UpdateStatus', TradeStatus, TradeStatus2)
				self.Remote:Fire(self.ActiveTrades[Player].OtherPlayer, TradeStatus2, TradeStatus)
			end
		elseif (Action == 'DeclineTrade') then
			self:CommitTrade(Player, self.ActiveTrades[Player].OtherPlayer, 'Aborted')
		end
	end)
end

function TradingHandler:_UpdateAndGetStatus(Player: Player, ForceUpdate: boolean)
	if (not self.ActiveTrades[Player]._Ready) then
		if (ForceUpdate) then
			self.ActiveTrades[Player]._Ready = true
			return 'Ready'
		else
			return 'Must Ready'
		end
	end
	
	if (not self.ActiveTrades[Player]._Confirmed) then
		if (ForceUpdate) then
			self.ActiveTrades[Player]._Confirmed = true
			return 'Confirmed'
		else
			return 'Must Confirm'
		end
	end
	
	return 'Accepted'
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
	
	local ActiveTrades = {
		[Player] = self.ActiveTrades[Player].Items,
		[self.ActiveTrades[Player].OtherPlayer] = self.ActiveTrades[self.ActiveTrades[Player].OtherPlayer].Items
	};
	
	self.Remote:Fire(Player, 'UpdateItems', ActiveTrades)
	self.Remote:Fire(self.ActiveTrades[Player].OtherPlayer, 'UpdateItems', ActiveTrades)
	
	return true
end

function TradingHandler:BeginTrade(Player: Player, PlayerTwo: Player)
	if self.ActiveTrades[Player] or self.ActiveTrades[PlayerTwo] then
		return false
	end
	
	if not (self.Pending[Player] and self.Pending[Player].Accepted) then
		return false
	end
	
	self.Pending[Player] = nil
	self.ActiveTrades[Player] = {
		Items = {},
		OtherPlayer = PlayerTwo
	}
	
	self.ActiveTrades[PlayerTwo] = {
		Items = {},
		OtherPlayer = Player
	}
	
	local ActiveTrades = {
		[Player] = self.ActiveTrades[Player].Items,
		[self.ActiveTrades[Player].OtherPlayer] = self.ActiveTrades[self.ActiveTrades[Player].OtherPlayer].Items
	};

	self.Remote:Fire(Player, 'StartTrade', ActiveTrades)
	self.Remote:Fire(self.ActiveTrades[Player].OtherPlayer, 'StartTrade', ActiveTrades)
	
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
		
		self.Remote:Fire(Player, 'TradeEnded')
		self.Remote:Fire(PlayerTwo, 'TradeEnded')
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

		self.Remote:Fire(Player, 'TradeAccepted')
		self.Remote:Fire(PlayerTwo, 'TradeAccepted')
	end
	
	return true
end

require(script.FakeScenario):_set(TradingHandler)

return TradingHandler
