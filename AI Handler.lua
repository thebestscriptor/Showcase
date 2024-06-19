--/ Types
type Dummy = Model & {Humanoid: Humanoid, HumanoidRootPart: BasePart}
export type Handler = {
	--/ Constants/Variables
	Model: Dummy,
	Status: string,
	Moving: string,
	CFrame: CFrame,
	Events: {[string]: BindableEvent},
	Humanoid: Humanoid,
	RootPart: BasePart,
	MaxHealth: number,
	BodyParts: {BasePart},
	
	--/ Events
	Died: RBXScriptSignal,
	OnMove: RBXScriptSignal,
	OnJump: RBXScriptSignal,
	OnStand: RBXScriptSignal,
	OnCrouch: RBXScriptSignal,
	DamageTaken: RBXScriptSignal,
	
	--/ Functions
	Run: (nil) -> nil,
	Walk: (nil) -> nil,
	Jump: (nil) -> nil,
	Stand: (nil) -> nil,
	Crouch: (nil) -> nil,
	Damage: (number) -> nil,
	MoveTo: (Position: CFrame) -> nil,
	Destroy: (nil) -> nil,
	GetSpeed: (nil) -> number,
	GetParts: (nil) -> {BasePart},
	PeakCorner: (Direction: string, Wall: BasePart) -> nil,
	AdjustSpeed: (Speed: number) -> nil
}

--/ Services
local Players = game:GetService('Players');
local ReplicatedStorage = game:GetService('ReplicatedStorage');

--/ Module
local Cache = {};
local Handler = {};
local Private = {}; Private.__index = Private

--/ Raycast Params
local Params = RaycastParams.new();
Params.FilterType = Enum.RaycastFilterType.Include
Params.FilterDescendantsInstances = {workspace:WaitForChild('Baseplate')}

--/ Local Functions
local function CreateEvent(): BindableEvent
	return Instance.new('BindableEvent')
end

local function CreateAnimation(AnimationId: string): Animation
	if (Cache[AnimationId]) then
		return Cache[AnimationId]
	end
	
	local Animation = Instance.new('Animation')
	Animation.AnimationId = AnimationId
	Cache[AnimationId] = Animation
	return Animation
end

--/ Private Functionality
function Private:GetSpeed(): number
	assert(self and self.Humanoid, 'Attempted to call on missing class')
	return self.Humanoid.WalkSpeed
end

function Private:AdjustSpeed(Speed: number): nil
	assert(self and self.Humanoid, 'Attempted to call on missing class')
	assert(Speed > 0 and Speed < 1000, 'Incorrect amount of speed passed')
	
	self.Humanoid.WalkSpeed = Speed
end

function Private:MoveTo(Position: CFrame): nil
	assert(self and self.Humanoid, 'Attempted to call on missing class')
	
	if (self.Moving) then
		return 'Already Moving'
	end
	
	local Cast = workspace:Raycast(Position.Position, Vector3.new(0, -10, 0), Params);
	if not (Cast and Cast.Instance) then
		return 'Can not walk to this position, no ground!'
	end
	
	self.Moving = true
	self.Humanoid:MoveTo(Position.Position)
	
	repeat task.wait() until not (self and self.RootPart) or self.RootPart.Velocity.Magnitude > 1
	repeat task.wait() until not (self and self.RootPart) or self.RootPart.Velocity.Magnitude <= 1
	
	self.Moving = false
end

function Private:Jump(): nil
	assert(self and self.Status, 'Attempted to call on missing class')

	if (self.Status == 'Jumping') then
		return 'Already Jumping'
	end

	self.Status = 'Jumping'
	self.Humanoid.Jump = true
	self.Humanoid.WalkSpeed = 16
	self.Events.OnJump:Fire()
end

function Private:Run(): nil
	assert(self and self.Status, 'Attempted to call on missing class')

	if (self.Status == 'Running') then
		return 'Already Running'
	end

	self.Status = 'Running'
	self.Humanoid.WalkSpeed = 26
end

function Private:Walk(): nil
	assert(self and self.Status, 'Attempted to call on missing class')

	if (self.Status == 'Walking') then
		return 'Already Walking'
	end

	self.Status = 'Walking'
	self.Humanoid.WalkSpeed = 16
end

function Private:Stand(): nil
	assert(self and self.Status, 'Attempted to call on missing class')
	
	if (self.Status == 'Standing') then
		return 'Already Standing'
	end
	
	self.Status = 'Standing'
	self.Humanoid.WalkSpeed = 0
	self.Events.OnStand:Fire()
end

function Private:Crouch(): nil
	assert(self and self.Status, 'Attempted to call on missing class')
	
	if (self.Status == 'Crouching') then
		return 'Already Crouching'
	end
	
	self.Status = 'Crouching'
	self.Humanoid.WalkSpeed = 6
	self.Events.OnCrouch:Fire()
end

function Private:Damage(Damage: number): nil
	assert(self and self.Humanoid, 'Attempted to call on missing class')
	
	self.Health = math.clamp(self.Health - Damage, 0, self.MaxHealth)
	
	if (self.Health <= 0) then
		self.Events.Died:Fire()
	else
		self.Events.DamageTaken:Fire(Damage, self.Health)
	end
end

function Private:GetParts(): {BasePart}
	return self.BodyParts
end

function Private:Destroy(): nil
	assert(self and self.Humanoid, 'Attempted to call on missing class')
	
	self.CFrame = nil
	self.Humanoid.Parent:Destroy()
	
	for _, Event in next, self.Events do
		local Name = Event.Name
		Event:Destroy()
		
		self[Name] = nil
	end
	
	table.clear(self.Events)
	table.clear(self.BodyParts)
	
	self.Events = nil
	self.BodyParts = nil
	
	setmetatable(self, {})
	setmetatable(getmetatable(self), {})
	
	table.clear(self)
	self = nil
end

function Private:PeakCorner(Direction: string, Wall: BasePart): nil
	
end

--/ Module Functionality
function Handler.new(SpawnPoint: CFrame): Handler
	local self = setmetatable({}, Private);
	local Dummy: Dummy = script.Dummy:Clone();
	
	local Events = {
		['Died'] = CreateEvent(),
		['OnMove'] = CreateEvent(),
		['OnJump'] = CreateEvent(),
		['OnStand'] = CreateEvent(),
		['OnCrouch'] = CreateEvent(),
		['DamageTaken'] = CreateEvent()
	};
	
	for Name: string, Event: BindableEvent in Events do
		self[Name] = Event.Event
		Event.Name = Name
	end
	
	self.Model = Dummy :: Dummy
	self.Status = '' :: string
	self.CFrame = nil :: CFrame
	self.Events = Events :: {[string]: BindableEvent}
	self.Moving = false :: boolean
	self.Health = 100 :: number
	self.Humanoid = Dummy.Humanoid :: Humanoid
	self.RootPart = Dummy.HumanoidRootPart :: BasePart
	self.BodyParts = {} :: {BasePart}
	self.MaxHealth = 100 :: number
	
	for _, BodyPart in next, Dummy:GetChildren() do
		if BodyPart:IsA('BasePart') then
			table.insert(self.BodyParts, BodyPart)
		end
	end
	
	self.CFrame = self.RootPart.CFrame
	self.RootPart:GetPropertyChangedSignal('CFrame'):Connect(function()
		self.CFrame = self.RootPart.CFrame
		Events.OnMove:Fire(self.CFrame)
	end)
	
	Dummy.Parent = workspace.Dummies
	Dummy:PivotTo(SpawnPoint)
	
	task.spawn(Handler.LoadAnimations, Dummy)
	
	return self :: Handler
end

function Handler.LoadAnimations(Character: Dummy): nil
	local Humanoid = Character.Humanoid
	local RootPart = Character.HumanoidRootPart
	
	local function LoadAnimation(AnimationId: string): AnimationTrack
		local Animation = CreateAnimation('rbxassetid://'..AnimationId);
		local Animation = Humanoid:LoadAnimation(Animation);
		return Animation
	end
	
	local Animations = {
		['Run'] = LoadAnimation('17890479454'),
		['Walk'] = LoadAnimation('17890480996'),
		['Jump'] = LoadAnimation('17890476890'),
		['Idle'] = LoadAnimation('17890458531')
	};
	
	Humanoid:GetPropertyChangedSignal('Jump'):Connect(function()
		if (Humanoid.Jump and not Animations.Jump.IsPlaying) then
			Animations['Jump']:Play()
		end
	end)
	
	Humanoid.Running:Connect(function(Speed: number)
		if (Speed < 1) then
			if (Animations.Idle.IsPlaying) then
				return
			end
			
			Animations['Run']:Stop()
			Animations['Walk']:Stop()
			
			Animations['Idle']:Play()
			Animations['Idle'].Looped = true
		elseif (Speed <= 16) then
			if (Animations.Walk.IsPlaying) then
				return
			end
			
			Animations['Run']:Stop()
			Animations['Idle']:Stop()
			
			Animations['Walk']:Play()
			Animations['Walk'].Looped = true
		else
			if (Animations.Run.IsPlaying) then
				return
			end
			
			Animations['Walk']:Stop()
			Animations['Idle']:Stop()
			
			Animations['Run']:Play()
			Animations['Run'].Looped = true
		end
	end)
end

--/ End
return Handler
