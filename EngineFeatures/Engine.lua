--TODO: Error handling
--TODO: Rework _tagsGameObjectMap
--TODO: makeGameObjectOfType

-- [[ Module Definition ]] --

local Engine = {
	_tagsGameObjectMap = {},
	_activeGameObjects = {}
}

-- [[ Roblox Services ]] --

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- [[ Dependencies ]] --

local GameObject = require(script.Parent.GameObject)
local SharedConstants = require(script.Parent.EngineSharedConstants)

-- [[ Type Definitions ]] --

type Array<ValueType> = { [number]: ValueType }
type Dictionary<KeyType, ValueType> = { [KeyType]: ValueType }
type StorageService = ReplicatedStorage | ServerStorage

type GameObjectConfigs = {
	RealClassName: string,
	Components: Dictionary<string, string>?
}

-- [[ Variables ]] --

local IsServer = RunService:IsServer()

-- [[ Functions ]] --

local function findModule(storage: StorageService, moduleName: string): ModuleScript?
	local moduleScript = storage:FindFirstChild(moduleName)
	if moduleScript and moduleScript:IsA("ModuleScript") then
		return moduleScript
	end
	return nil
end

local function getTagsFromStorage(storage: StorageService): Array<string>
	local tags = {}

	for _, gameObject in ipairs(storage.GameObjects:GetChildren()) do
		table.insert(tags, gameObject.Name)
	end

	return tags
end

-- [[ Public ]] --

function Engine.getGameObjectModule(objectName: string): ModuleScript?
	local replicatedGameObject = findModule(ReplicatedStorage.GameObjects, objectName)
	local serverGameObject = findModule(ServerStorage.GameObjects, objectName)

	if IsServer then
		return serverGameObject or replicatedGameObject
	else
		return replicatedGameObject
	end
end

function Engine.getComponentModule(componentName: string): ModuleScript?
	local replicatedComponent = findModule(ReplicatedStorage.Components, componentName)
	local serverComponent = findModule(ServerStorage.Components, componentName)

	if IsServer then
		return serverComponent or replicatedComponent
	else
		return replicatedComponent
	end
end

function Engine.getAllGameObjectTags(): Array<string>
	local tags = getTagsFromStorage(ReplicatedStorage)

	if IsServer then
		local serverTags = getTagsFromStorage(ServerStorage)
		for _, tag in ipairs(serverTags) do
			table.insert(tags, tag)
		end
	end

	return tags
end

function Engine.getActiveGameObjects(): Array<any>
	local copy = {}
	
	for _, v in ipairs(Engine._activeGameObjects) do
		table.insert(copy, v)
	end
	
	return copy
end

function Engine.initializeGameObjectOnEnter(tag: string, realObject: Instance)
	local gameObject = GameObject.new(tag, realObject)
	table.insert(Engine._activeGameObjects, gameObject)
end

function Engine.makeGameObjectOfType(name: string, objectType: string, location: Instance?)
	local gameObjectModule = Engine.getGameObjectModule(objectType)
	
	if not gameObjectModule then
		error(`"{objectType}" is not a valid \`GameObject\` type.`, 2)
	end
	
	local configs: GameObjectConfigs = require(gameObjectModule)
	local realObject: Instance = Instance.new(configs.RealClassName)
	realObject.Name = name
	
	local components: Folder = Instance.new("Folder")
	components.Name = SharedConstants.ComponentsIdentifier
	components.Parent = realObject
	
	if type(configs.Components) == "table" then
		for componentName: string, componentType: string in pairs(configs.Components) do
			local componentModule: ModuleScript? = Engine.getComponentModule(componentType)
			
			if not componentModule then
				warn(`"{componentType}" is not a valid \`Component\` type.`)
				continue
			end
			
			local componentLocation = Instance.new("ObjectValue")
			componentLocation.Name = componentName
			componentLocation.Value = componentModule
			componentLocation.Parent = components
		end
	end
	
	
end

-- Initialization --
local tags = Engine.getAllGameObjectTags()

for _, tag in ipairs(tags) do
	Engine._tagsGameObjectMap[tag] = require(Engine.getGameObjectModule(tag))

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(realObject: Instance)
		Engine.initializeGameObjectOnEnter(tag, realObject)
	end)
	
	for _, realObject: Instance in ipairs(CollectionService:GetTagged(tag)) do
		Engine.initializeGameObjectOnEnter(tag, realObject)
	end
end

return Engine
