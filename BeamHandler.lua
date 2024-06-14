--/ Yielding
script:WaitForChild('Spring')

--/ Types
export type Beam = {
	Tweens: {any},
	Springs: {any},
	SetCharacter: (Character: Model & {Humanoid: Humanoid}) -> Beam,
	SetProperties: (Properties: {[string]: any}) -> Beam,
	TweenProperties: (Properties: {[string]: any}, TweenInfo_: TweenInfo, Yield: boolean) -> Beam,
	MotionProperties: (TweenData: {[string]: any}, Properties: {[string]: number | Vector3}) -> Beam
}

--/ Services
local Debris = game:GetService('Debris');
local TweenService = game:GetService('TweenService');

--/ Effects Folder
local Effects = workspace:FindFirstChild('Effects') or Instance.new('Folder', workspace);
Effects.Name = 'Effects'

--/ Modules
local Module = {};
local Spring = require(script.Spring);

--/ Private Functionality
local function CreateBeam(): BasePart
	local MainBeam = Instance.new("Part")
	
	MainBeam.Shape = Enum.PartType.Cylinder
	MainBeam.Anchored = true
	MainBeam.CanCollide = false
	MainBeam.Material = Enum.Material.Neon
	MainBeam.Color = Color3.fromRGB(170, 0, 255)
	MainBeam.Transparency = 0.75
	MainBeam.Orientation = Vector3.new(0, 90, 90)
	MainBeam.Size = Vector3.new(600, 0, 0)
	
	return MainBeam
end

--/ Module Functionality
function Module:AddBeam(Properties: {[string]: any}): Beam
	--/ Variables
	local self = {};
	local Beam = CreateBeam();
	
	--/ Cache
	self.Tweens = {}
	self.Springs = {}
	
	--/ self Functionality
	function self:Destroy(): nil
		Beam:Destroy()
		table.clear(self.Tweens)
		table.clear(self.Springs)
		table.clear(self)
		self = nil
	end
	
	function self:SetProperties(Properties: {[string]: any}): self
		for Property, Value in Properties do
			Beam[Property] = Value
		end
		
		return self
	end
	
	function self:SetCharacter(Character: Model & {Humanoid: Humanoid}): self
		Beam.Parent = Effects
		Beam.Position = Character.Head.Position - Vector3.new(0, 10, 0)
		
		return self
	end
	
	function self:MotionProperties(TweenData: {[string]: any}, Properties: {[string]: number | Vector3}): self
		TweenData = TweenData or {}
		TweenData.Push = TweenData.Push or 1
		
		for _, Spring in self.Springs do
			Spring.Target = (typeof(Spring.Position) == 'Vector3' and Vector3.zero or 0)
			Spring.Position = (typeof(Spring.Position) == 'Vector3' and Vector3.zero or 0)
			Spring = nil
		end
		
		table.clear(self.Springs)
		self.Springs = {}
		
		for	Property, Value in Properties do
			if (typeof(Value) == 'number') or (typeof(Value) == 'Vector3') then
				warn(Property, Beam[Property], Value)
				
				local MotionSpring = Spring.new(Beam[Property]);
				MotionSpring.Target = Value
				MotionSpring.Damper = TweenData.Damper or 1
				MotionSpring.Speed = TweenData.Speed or 1
				MotionSpring:Impulse(typeof(Value) == 'Vector3' and Vector3.one*TweenData.Push or TweenData.Push)
				
				task.spawn(function()
					local Last = tick();
					
					repeat task.wait()
						Beam[Property] = MotionSpring.Position
					until (tick() - Last) > 1
					
					table.remove(self.Springs, table.find(self.Springs, MotionSpring))
				end)
				
				table.insert(self.Springs, MotionSpring)
			end
		end
		
		return self
	end
	
	function self:TweenProperties(Properties: {[string]: any}, TweenInfo_: TweenInfo, Yield: boolean): self
		TweenInfo_ = TweenInfo_ or TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		
		if (Yield) then
			for _, Tween in self.Tweens do
				Tween:Pause()
				Tween:Destroy()
			end
			
			table.clear(self.Tweens)
			self.Tweens = {}
		end
		
		local Tween = game.TweenService:Create(Beam, TweenInfo_, Properties);
		Tween:Play()
		
		table.insert(self.Tweens, Tween)
		
		Tween.Destroying:Connect(function()
			if (not self.Tweens) then return end
			table.remove(self.Tweens, table.find(self.Tweens, Tween))
		end)
		
		Debris:AddItem(Tween, Tween.TweenInfo.Time)
		return self
	end
	
	--/ Return
	self:SetProperties(Properties)
	return self :: Beam
end

--/ Return
return Module
