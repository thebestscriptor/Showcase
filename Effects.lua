--/ Types
export type Character = Model & {Humanoid: Humanoid, HumanoidRootPart: BasePart}

--/ Services
local ReplicatedStorage = game:GetService('ReplicatedStorage');

--/ Modules
local Effects = {}; Effects.__index = Effects
local Private = {}; Private.__index = Private

--/ Imports
local Remotes, Remote

--/ Preload List
local PreloadList = {
	'rbxassetid://17825863674'
};

--/ Cache
Effects.Cache = {};
Effects.Descriptions = {};

--/ Preloading
task.spawn(function()
	game.ContentProvider:PreloadAsync(PreloadList)
end)

--/ Caching
for _, Effect in next, script:GetChildren() do
	if Effect:IsA('ModuleScript') then
		task.synchronize('a')
		
		task.spawn(function()
			Effects.Cache[Effect.Name] = require(Effect)
		end)
		
		task.desynchronize('a')
	end
end

--/ Local Functions
local function PlayerAdded(Player: Player)
	local Connections = {};
	
	if (Player.Character) then
		task.spawn(function(Character: Character)
			Character:WaitForChild('Humanoid')

			Effects.Descriptions[Player.Name] = Character.Humanoid:GetAppliedDescription()
		end, Player.Character)
	end
	
	Connections[1] = Player.CharacterAdded:Connect(function(Character: Character)
		Character:WaitForChild('Humanoid')
		
		Effects.Descriptions[Player.Name] = Character.Humanoid:GetAppliedDescription()
	end)
end

--/ Description Cache Handling
game.Players.PlayerAdded:Connect(PlayerAdded)
game.Players.PlayerRemoving:Connect(function(Player: Player)
	if Effects.Descriptions[Player.Name] then
		Effects.Descriptions[Player.Name] = nil
	end
end)

for _, Player in next, game.Players:GetPlayers() do
	task.spawn(PlayerAdded, Player)
end

--/ Private Functionality
function Private:GetDescription(Character: Character)
	if (not Effects.Descriptions[Character.Name]) and Character:FindFirstChild('Humanoid') then
		Effects.Descriptions[Character.Name] = Character.Humanoid:GetAppliedDescription()
	end
	
	return Effects.Descriptions[Character.Name]
end

function Private:Anchor(Character: Character)
	for _, Part in next, Character:GetDescendants() do
		if Part:IsA('BasePart') then
			Part.AssemblyLinearVelocity = Vector3.zero
			Part.AssemblyAngularVelocity = Vector3.zero
			Part.Anchored = true
		end
	end
end

function Private:MimicCharacter(Character: Character)
	for _, Part in next, Character:GetDescendants() do
		if Part:IsA('Decal') then Part:Destroy() end
		if Part:IsA('BasePart') then
			Part.Anchored = true
			Part.Transparency = 1
		end
	end
	
	local Dummy = script.Dummy:Clone();
	game.Debris:AddItem(Dummy, 6)
	
	Dummy:SetAttribute('Mim', true)
	Dummy.HumanoidRootPart.CFrame = Character.HumanoidRootPart.CFrame
	
	Dummy.Parent = workspace
	Dummy.Humanoid:ApplyDescription(self:GetDescription(Character))
	Dummy.HumanoidRootPart.CFrame = Character.HumanoidRootPart.CFrame
	
	return Dummy
end

--/ Module Functionality
function Effects:Play(Character: Character, Effect: string)
	assert(self.Cache[Effect], `Effect {Effect} does not exist.`)
	
	if not Character:GetAttribute('Mim') then
		Character = Private:MimicCharacter(Character)
	end

	if (Character.Humanoid.RigType == Enum.HumanoidRigType.R15) then
		Character.Head.TextureID = PreloadList[1]
	else
		Character.Head:FindFirstChildWhichIsA('SpecialMesh').TextureId = PreloadList[1]
	end
	
	Private:Anchor(Character)
	self.Cache[Effect](Character)
end

function Effects:TestPlay(Character: Character, Effect: string)
	assert(self.Cache[Effect], `Effect {Effect} does not exist.`)
	assert(game["Run Service"]:IsStudio(), 'Can only TestPlay in Studio Mode')
	
	if not Character:GetAttribute('Mim') then
		Character = Private:MimicCharacter(Character)
	end
	
	Character.Humanoid.Health = 0
	self:Play(Character, Effect)
end

--/ Misc (ignore, just for promise/knit ran bootstrapper)
function Effects:Init()
	Remotes = require(ReplicatedStorage.Shared.Remotes)
	return
end

function Effects:Start()
	Remote = Remotes.Client:GetNamespace("Deaths"):Get("RunEffect");
	Remote:Connect(function(...)
		Effects:Play(...)
	end)
	
	return
end

--/ Return
return Effects
