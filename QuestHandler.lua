--/ Types
export type QuestData = {
	Type: string,
	Goal: number,
	Level: number,
	Owner: Player | nil,
	Status: number | nil,
	Format: number | nil,
	Profile: {any} | nil,
	LastUse: number | nil,
	Claimed: boolean,
	QuestType: string,
	ProfileData: string,
	Description: string,
	StartedAmount: number | nil
}

--/ Server Detection
local Server = game["Run Service"]:IsServer();

--/ Module
local QuestData = {};
QuestData.Tracking = {}

--/ Quest Types
local QuestTypes = {
	['Kills'] = {Starter = 150, ProfileData = 'Kills', Increment = 150, DescFormat = 'Kill a total of %s Players to complete this quest.'},
	['Boxes'] = {Starter = 15, ProfileData = 'Statistics.Orbs', Increment = 35, DescFormat = 'Collect a total of %s Timeboxes to complete this quest.'},
	['Time'] = {Starter = 15000, ProfileData = 'Time', Increment = 16500, DescFormat = 'Collect a total of %s Time outside of the safezone to complete this quest.'},
	['Streak'] = {Starter = 5, ProfileData = 'Streak', Increment = 10, DescFormat = 'Kill a total %s Players consecutively to complete this quest.'},
	['Play-Time'] = {Starter = (60 * 15), ProfileData = 'Statistics.PlayTime', Increment = (60 * 20), DescFormat = 'Play the game for a total of %s Minutes to complete this quest.'},
	['Time-Stolen'] = {Starter = 50000, ProfileData = 'Statistics.Stolen', Increment = 150_000, DescFormat = 'Steal a total of %s Time from other players to complete this quest.'}
};

--/ Local Functions
local function GenerateGoal(Type: string, Level: number)
	local Type = QuestTypes[Type];
	if (not Type) then
		return
	end
	
	return Type.Starter + (Type.Increment * Level)
end

local function DeepCopy(Table: {any})
	local New = {};

	for Key, Value in pairs(Table) do
		if Key ~= 'Profile' and Key ~= 'Owner' then
			if typeof(Value) == 'table' then
				Value = DeepCopy(Value)
			end
			
			New[Key] = Value
		end
	end

	return New
end


local function GenerateQuest(Type: string, Level: number)
	local Goal = GenerateGoal(Type, Level);
	if (not Goal) then
		return
	end
	
	return {
		['Type'] = Type,
		['Goal'] = Goal,
		['Level'] = Level,
		['Claimed'] = false,
		['ProfileData'] = QuestTypes[Type].ProfileData,
		['Description'] = QuestTypes[Type].DescFormat:format(Goal)
	};
end

local function GetProfileData(Profile: any, DataName: string)
	local Split = DataName:split('.');
	if Split[2] then
		return Profile.Data[Split[1]][Split[2]]
	end
	
	return Profile.Data[DataName]
end

--/ Module Functionality
function QuestData:GenerateQuest(Player: Player, QuestType: string, Type: string, Level: number)
	local Profile = shared:GetProfile(Player);
	
	if not (Profile and Profile.Data) then
		return warn('no prof')
	end
	
	if (Profile.Data.Quests[QuestType][Type]) then
		return warn('already has')
	end
	
	local QuestTable = GenerateQuest(Type, Level);
	
	QuestTable.Owner = Player
	QuestTable.Status = 0
	QuestTable.Claimed = false
	QuestTable.Profile = Profile
	QuestTable.QuestType = QuestType
	QuestTable.StartedAmount = GetProfileData(Profile, QuestTable.ProfileData);
	
	return QuestTable
end

function QuestData:ClaimQuest(Player: Players, QuestValue: NumberValue)
	local Profile = shared:GetProfile(Player);
	if (not Profile) then
		warn('no profile')
		return false
	end
	
	local Data: QuestData = shared:GetData(Player, QuestValue);
	if (not Data) then
		warn('no data')
		return false
	end
	
	if (QuestValue.Value < 1) then
		return false
	end
	
	if Data.Format and (Data.Format < 1) then
		return false
	end
	
	local Folder = Player:WaitForChild('Quests');
	local Value = Folder:FindFirstChild(`{Data.QuestType}-{Data.Type}`); -- idk if destroying one passed by client works, it prob does tho
	
	if (Value) then
		Value:Destroy()
	else
		warn('no value')
		return false
	end
	
	QuestData:StopTracking(Data)
	
	Data.Claimed = true
	Profile.Data.Quests[Data.QuestType][Data.Type] = DeepCopy(Data)
	
	Profile.Data.QuestStats[Data.QuestType] = Profile.Data.QuestStats[Data.QuestType] or {}
	Profile.Data.QuestStats[Data.QuestType][Data.Type] = {
		Level = Data.Level or 1
	}
	
	return true
end

function QuestData:SetupQuest(Player: Player, Data: QuestData)
	local Folder = Player:FindFirstChild('Quests') or Instance.new('Folder', Player);
	Folder.Name = 'Quests'
	
	if Folder:FindFirstChild(`{Data.QuestType}-{Data.Type}`) then
		return
	end
	
	if (Data.Claimed == nil) then
		Data.Claimed = false
	end
	
	if (Data.Claimed) then
		return
	end
	
	local Stat = Instance.new('NumberValue', Folder);
	Stat.Name = `{Data.QuestType}-{Data.Type}`
	Stat.Value = math.clamp((Data.Status - Data.StartedAmount) / Data.Goal, 0, 1)
	
	Stat:SetAttribute('Claimed', Data.Claimed)
	Stat:SetAttribute('Goal', Data.Goal)
	Stat:SetAttribute('Desc', Data.Description)
	Stat:SetAttribute('Start', Data.StartedAmount)
	Stat:SetAttribute('Stat', (Data.Status - Data.StartedAmount))
end

function QuestData:GetValue(Player: Player, Name: string)
	return Player:WaitForChild('Quests'):FindFirstChild(Name)
end

if (Server) then
	--/ Tracking Function
	function QuestData:TrackQuest(Player: Player, QuestTable: QuestData)
		QuestTable = DeepCopy(QuestTable)
		
		local Profile = shared:GetProfile(Player);

		if not (Profile and Profile.Data) then
			return
		end
		
		if not (Profile.Data.Quests[QuestTable.QuestType][QuestTable.Type]) then
			return
		end
		
		local Goal = QuestTable.Goal
		local Started = QuestTable.StartedAmount

		if (not QuestTable.Profile) then
			QuestTable.Profile = Profile
		end

		if (not QuestTable.Owner) then
			QuestTable.Owner = Player
		end

		QuestTable.Status = GetProfileData(Profile, QuestTable.ProfileData)
		QuestTable.Format = (QuestTable.Status - Started) / Goal
		
		table.insert(QuestData.Tracking, QuestTable)
		
		return QuestTable
	end
	
	function QuestData:StopTracking(QuestTable: QuestData)
		local Found = table.find(QuestData.Tracking, QuestTable);
		if (Found) then
			table.remove(QuestData.Tracking, Found)
		end
	end
	
	--/ Tracking Loop
	task.spawn(function()
		local Break = false
		
		while task.wait(0.1) do
			if (Break) then
				break
			end
			
			if (#QuestData.Tracking <= 0) then
				continue
			end
			
			for _, Data: QuestData in next, QuestData.Tracking do
				if (Break) then
					break
				end
								
				local Goal = Data.Goal
				local Started = Data.StartedAmount
				
				Data.Status = GetProfileData(Data.Profile, Data.ProfileData)
				Data.Format = (Data.Status - Started) / Goal
				
				local LastUse = Data.LastUse or 0
				
				if (tick() - LastUse) > 2 and (Data.Format > 0) then
					Data.LastUse = tick()
					
					local Table = DeepCopy(Data);
					Data.Profile.Data.Quests[Data.QuestType][Data.Type] = Table
				end
				
				local Value = QuestData:GetValue(Data.Owner, `{Data.QuestType}-{Data.Type}`);
				if (Value) then
					Value.Value = Data.Format
					
					Value:SetAttribute('Stat', (Data.Status - Data.StartedAmount))
				end
			end
		end
		
		game:BindToClose(function()
			Break = true
		end)
	end)
end

--/ Misc
QuestData.QuestTypes = QuestTypes

--/ End
return QuestData
