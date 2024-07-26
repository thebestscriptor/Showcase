repeat task.wait() until (shared.Formatter and shared.ProfileHandler)

--/ Boards
local Boards = workspace:WaitForChild('Terrain'):WaitForChild('Boards');

--/ Services
local Players = game:GetService('Players');
local ReplicatedStorage = game:GetService('ReplicatedStorage');

--/ Remote
local Remote = ReplicatedStorage:WaitForChild('LBRemote');

--/ Player
local Player = Players.LocalPlayer

--/ Cache
local Cache = nil
local TimeTable = {
	{60 * 60 * 24 * 7 * 4 * 12, 'Year'},
	{60 * 60 * 24 * 7 * 4, 'Month'},
	{60 * 60 * 24 * 7, 'Week'},
	{60 * 60 * 24, 'Day'},
	{60 * 60, 'Hour'},
	{60, 'Minute'},
	{1, 'Second'}
};

--/ Local Functions
shared.ProfileHandler.Updated:Connect(function(ProfileData: {[string]: any})
	local Stats = ProfileData.Stats
	
	for Name, Value in Stats do
		local Board = Boards:FindFirstChild(Name);
		if (Board) then
			Board.Gui.Top.Yours.Text = `Your {Name}: {shared.Formatter:Comma(Value)}`
		end
	end
end)

local function GetTimeFormat(Time: number)
	for _, Data in next, TimeTable do
		local Int = (Time / Data[1]);
		if (Int >= 1) then
			local TimeLeft = Time - (math.floor(Int) * Data[1])
			return `{math.floor(Int)} {Data[2]}{if (math.floor(Int) > 1) then 's' else ''}{if (Data[2] ~= 'Second') then ` and {TimeLeft} Second{if (TimeLeft > 1) then 's' else ''}` else ''}`
		end
	end

	return `{Time} Seconds`
end

local function ClearItems(BoardName: string)
	local Board = Boards:FindFirstChild(BoardName);
	if (Board) then
		for _, Frame in next, Board.Gui.Holder.List:GetChildren() do
			if Frame:IsA('Frame') then
				Frame:Destroy()
			end
		end
	end
end

local function ListItems(BoardName: string, Data: {})
	local Board = Boards:FindFirstChild(BoardName);
	if (not Board) then
		return
	end
	
	Board:SetAttribute('TimeLeft', 119)
	
	local HasRank = false
	local Value = if (shared.ProfileHandler) then shared.ProfileHandler.GetStat(nil, BoardName) else 0
	Board.Gui.Top.Yours.Text = `Your {BoardName}: {shared.Formatter:Comma(Value)}`
	
	for _, Table in next, Data do
		local Order = Table[1];
		local Name = Table[2];
		local UserId = tonumber(Table[3]);
		local Value = Table[4];
		
		if (UserId == Player.UserId) then
			HasRank = true
			Board.Gui.Top.Rank.Text = `Your Rank: #{Order}`
		end
		
		local Frame = script.Frame:Clone();
		
		if (UserId < 0) then
			Frame.User.Text = `@Test Account #{-UserId}`
			Frame.Image.Image = Players:GetUserThumbnailAsync(game.CreatorId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		else
			Frame.User.Text = `@{Players:GetNameFromUserIdAsync(UserId)}`
			Frame.Image.Image = Players:GetUserThumbnailAsync(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end
		
		Frame.Order.Text = `#{Order}`
		Frame.Value.Text = if (BoardName == 'Level') then `{BoardName} {shared.Formatter:Comma(Value)}` else `{shared.Formatter:Comma(Value)} {BoardName}`
		Frame.LayoutOrder = Order
		Frame.Parent = Board.Gui.Holder.List
	end
	
	if (not HasRank) then
		Board.Gui.Top.Rank.Text = `Your Rank: Undefined`
	end
end

--/ Event Setup
Remote.OnClientEvent:Connect(function(Data: {})
	Cache = Data
	
	for Name, Table in Data do
		ClearItems(Name)
		ListItems(Name, Table)
	end
end)

while task.wait(1) do
	for _, Board in next, Boards:GetChildren() do
		local TimeLeft = Board:GetAttribute('TimeLeft');
		if (TimeLeft) then
			if (TimeLeft > 0) then
				Board:SetAttribute('TimeLeft', TimeLeft - 1)
				Board.Gui.Top.Reset.Text = `Resets In {GetTimeFormat(TimeLeft)}`
			else
				Board.Gui.Top.Reset.Text = `Resetting..`
			end
		end
	end
end
