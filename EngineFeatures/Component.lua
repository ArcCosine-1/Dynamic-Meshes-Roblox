--!strict

-- [[ Module Definition ]]--

local Component = {}
Component.__index = Component

-- [[ Roblox Services ]] --

local RunService = game:GetService("RunService")

-- [[ Dependencies ]] --

local Symbol = require(script.Parent.Symbol)
local GenerateGUID = require(script.Parent.Utility.generateGUID)

-- [[ Variables ]] --

local KEY_SCOPE = Symbol("Scope")

-- [[ Functions ]] --

local function FormatAttributeName(attributeName: string)
	return attributeName:sub(1, 1):lower() .. attributeName:sub(2)
end

-- [[ Public ]] --

export type ClassType = typeof(setmetatable(
	{} :: {
		[typeof(KEY_SCOPE)]: string,
		name: string,
		adornee: Instance,
		componentValue: ObjectValue,
		gameObject: any,
		started: boolean
	},
	Component
))

function Component.new(name: string, adornee: Instance, componentValue: ObjectValue, gameObject: any): ClassType
	local self = {}
	
	self[KEY_SCOPE] = GenerateGUID()
	self.name = name
	self.adornee = adornee
	self.componentValue = componentValue
	self.gameObject = gameObject
	self.started = false
	
	return setmetatable(self, Component)
end

--[[
function Component.Construct() end
function Component:Start() end
function Component:Update() end
]]

function Component:Reconcile()
	for attributeName: string, value: any in pairs(self.componentValue:GetAttributes()) do
		attributeName = FormatAttributeName(attributeName)
		
		if self[attributeName] ~= nil then
			continue
		end
		
		self[attributeName] = value
	end
end

function Component:DeepCopyAttributes()
	for attributeName: string, value: any in pairs(self.componentValue:GetAttributes()) do
		attributeName = FormatAttributeName(attributeName)
		self[attributeName] = value
	end
end

function Component:WaitForComponent()
	while not self.started do
		RunService.Heartbeat:Wait()
	end
	
	return self
end

function Component:_getCollectionScope(): string
	return self[KEY_SCOPE]
end

return (Component)
