--TODO: Destroy
--TODO: Incorporate features from Engine (GetComponent)

-- [[ Module Definition ]] --

local GameObject = {}

-- [[ Roblox Services ]] --

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- [[ Dependencies ]] --

local Symbol = require(script.Parent.Symbol)
local Signal = require(script.Parent.Signal)
local SharedConstants = require(script.Parent.EngineSharedConstants)
local GenerateGUID = require(script.Parent.Utility.generateGUID)

-- [[ Type Definitions ]] --

type Array<ValueType> = { [number]: ValueType }
type Dictionary<KeyType, ValueType> = { [KeyType]: ValueType }
type Symbol = typeof(Symbol(""))
type Connection = RBXScriptConnection | Signal.SignalConnection

-- [[ Variables ]] --

local KEY_COMPONENTS = Symbol("Components")
local KEY_COLLECTOR = Symbol("Collector")
local KEY_SCOPE = Symbol("Scope")
local KEY_INSTANCE = Symbol("Instance")

local COMPONENTS_IDENTIFIER = SharedConstants.ComponentsIdentifier

local IsServer = RunService:IsServer()
local StepSignal = IsServer and RunService.Heartbeat or RunService.RenderStepped

-- [[ Function ]] --

local function HasProperty(object: any, propertyName: string): boolean
	local success = pcall(function()
		return object[propertyName]
	end)
	
	return success
end

local function IsComponent(object: Instance): boolean
	if typeof(object) ~= "Instance" then
		return false
	end
	
	if not object:IsA("ModuleScript") then
		return false
	end
	
	if object:IsDescendantOf(ReplicatedStorage.Components) then
		return true
	elseif IsServer and object:IsDescendantOf(ServerStorage.Components) then
		return true
	end
	
	return false
end

local function GetComponent(name: string): ModuleScript?
	if IsServer and ServerStorage.Modules:FindFirstChild(name) then
		return ServerStorage.Modules[name]
	elseif ReplicatedStorage.Modules:FindFirstChild(name) then
		return ReplicatedStorage.Modules[name]
	end
end

local function DeepCopy(obj, copies)
	copies = copies or setmetatable({}, {__mode = "k"})

	if type(obj) ~= "table" then
		return obj
	end

	if copies[obj] then
		return copies[obj]
	end

	local copy = setmetatable({}, getmetatable(obj))
	copies[obj] = copy

	for key, value in pairs(obj) do
		copy[DeepCopy(key, copies)] = DeepCopy(value, copies)
	end

	return copy
end

-- [[ Public ]] --

local PublicGameObjectMeta = {
	__index = function(self, key: any)
		local instance = self[KEY_INSTANCE]
		
		if HasProperty(instance, key) then
			local wrapValue = type(instance[key]) == "function"
			
			if wrapValue then
				return function(...)
					return instance[key](instance, select(2, ...))
				end
			end
			
			return instance[key]
		else
			return GameObject[key]
		end
	end,

	__newindex = function(self, key: any, value: any)
		local instance = self[KEY_INSTANCE]
		
		if type(value) == "function" then
			rawset(self, key, value)
			return
		end
		
		if HasProperty(instance, key) then
			instance[key] = value
		else
			error(`{tostring(key)} is not a valid member of {self.className}.`, 2)
		end
	end,
	
	__tostring = function(self)
		return self.className
	end,
}

export type ClassType = typeof(setmetatable(
	{} :: {
		[Symbol | string]: any,
		className: string
	},
	PublicGameObjectMeta
))

function GameObject.new(className: string, realObject: Instance): ClassType
	if not realObject:FindFirstChild(COMPONENTS_IDENTIFIER) then
		error(`"realObject" must contain {COMPONENTS_IDENTIFIER}`)
	end
	
	local self = {}
	
	self[KEY_COMPONENTS] = {}
	self[KEY_COLLECTOR] = {}
	self[KEY_SCOPE] = GenerateGUID()
	self[KEY_INSTANCE] = realObject
	self.className = className
	
	setmetatable(self, PublicGameObjectMeta)
	
	for _, component in pairs(realObject[COMPONENTS_IDENTIFIER]:GetChildren()) do
		if not component:IsA("ObjectValue") then
			warn(`"{component.Name}" must be a \`ObjectValue\`.`)
			continue
		end
		
		local componentName = component.Name
		local componentModule = component.Value
		
		self:_initializeComponent(componentName, componentModule, component)
	end
	
	return self
end

function GameObject:_initializeComponent(componentName: string, component: ModuleScript, componentValue: ObjectValue)
	if not IsComponent(component) then
		error("Invalid component.", 2)
	end
	
	if self[KEY_COMPONENTS][componentName] then
		warn(`Component "{componentName}" already exists.`)
		return
	end
	
	local componentModule = require(component)

	local newComponent = componentModule.Construct(self[KEY_INSTANCE], componentValue, self)
	self[KEY_COMPONENTS][componentName] = newComponent
	
	if type(newComponent.Start) == "function" then
		task.spawn(function()
			newComponent:Start()
			newComponent.started = true
		end)
	end
	
	if type(newComponent.Update) == "function" then
		self:AddToCollection(StepSignal:Connect(function(deltaTime: number)
			newComponent:Update(deltaTime)
		end), newComponent:_getCollectionScope())
	end
end

function GameObject:RemoveComponent(componentName: string)
	local componentsFolder: Folder = self[KEY_INSTANCE][COMPONENTS_IDENTIFIER]
	
	if not componentsFolder:FindFirstChild(componentName) or not self[KEY_COMPONENTS][componentName] then
		error(`\`GameObject\` does not contain component, "{componentName}".`, 2)
	end
	
	local component = self[KEY_COMPONENTS][componentName]
	
	self[KEY_COMPONENTS][componentName] = nil
	self:CleanUpScope(component:_getCollectionScope())
	setmetatable(component, nil)
	table.clear(component)
	
	componentsFolder[componentName]:Destroy()
end

function GameObject:AddComponent(inGameObjectName: string, componentName: string)
	if type(inGameObjectName) ~= "string" then
		error("\"inGameObjectName\" must be a string.", 2)
	end
	
	if type(componentName) ~= "string" then
		error("\"componentName\" must be a string.", 2)
	end
	
	local component = GetComponent(componentName)
	
	if not component then
		error(`Component, "{componentName}", does not exist.`, 2)
	end
	
	local realComponent = Instance.new("ObjectValue")
	realComponent.Name = inGameObjectName
	realComponent.Value = component
	realComponent.Parent = self[KEY_INSTANCE][COMPONENTS_IDENTIFIER]
	
	self:_initializeComponent(inGameObjectName, component)
end

function GameObject:FindComponentOfType(componentType: string)
	if type(componentType) ~= "string" then
		error("\componentType\" must be a string.", 2)
	end
	
	for _, component in pairs(self[KEY_COMPONENTS]) do
		if component.name ~= componentType then
			continue
		end
		
		return component
	end
end

function GameObject:Reconcile(properties: Dictionary<string, any>)
	for propertyName: string, defaultValue: any in pairs(properties) do
		if rawget(self, propertyName) or HasProperty(self[KEY_INSTANCE], propertyName) then
			continue
		end
		
		if type(defaultValue) == "table" then
			defaultValue = DeepCopy(defaultValue)
		end
		
		rawset(self, propertyName, defaultValue)
	end
end

function GameObject:GetComponent(name: string)
	if type(name) ~= "string" then
		error("\"name\" must be a string.", 2)
	end
	
	local component = self[KEY_COMPONENTS][name]
	
	if not component then
		error(`Component, "{name}", does not exist.`, 2)
	end
	
	return component
end

function GameObject:GetComponentList(): Dictionary<string, any>
	return self[KEY_COMPONENTS]
end

function GameObject:_checkScopeExists(scope: any): boolean?
	if type(scope) ~= "string" then
		error("\"scope\" must be a string.", 2)
	end

	if not self[KEY_COLLECTOR][scope] then
		warn(`Scope, "{scope}", does not exist.`, 2)
		return false
	end
	
	return true
end

function GameObject:AddToCollection(object: Connection, scope: string?)
	local scope = scope or KEY_SCOPE
	
	if typeof(object) ~= "RBXScriptConnection" and type(object) ~= "table" then
		error("Invalid object.", 2)
	end
	
	if type(scope) ~= "string" then
		error("\"scope\" must be a string.", 2)
	end
	
	if not self[KEY_COLLECTOR][scope] then
		self[KEY_COLLECTOR][scope] = {}
	end
	
	table.insert(self[KEY_COLLECTOR][scope], object)
end

function GameObject:CleanUpScope(scope: string)
	local scope = scope or KEY_SCOPE
	
	if not self:_checkScopeExists(scope) then
		return
	end
	
	for _, object in ipairs(self[KEY_COLLECTOR][scope]) do
		object:Disconnect()
	end
	
	table.clear(self[KEY_COLLECTOR][scope])
end

function GameObject:RemoveFromCollection(object: Connection, scope: string)
	local scope = scope or KEY_SCOPE
	
	if typeof(object) ~= "RBXScriptConnection" or type(object) ~= "table" then
		error("Invalid object.", 2)
	end
	
	if not self:_checkScopeExists(scope) then
		return
	end
	
	local location = table.find(self[KEY_COLLECTOR][scope], object)
	
	if location then
		table.remove(self[KEY_COLLECTOR][scope], location)
	else
		warn("Object was not apart of collection.")
	end
end

function GameObject:GetRealObject(): Instance
	return self[KEY_INSTANCE]
end

return (GameObject)
