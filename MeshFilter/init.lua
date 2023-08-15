-- [[ Module Definition ]] --

local MeshFilter = {}
MeshFilter.__index = MeshFilter

-- [[ Roblox Services ]] --

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [[ Dependencies ]] --

local Icosahedron = require(script.Icosahedron)
local Component = require(ReplicatedStorage.EngineFeatures.Component)
local Signal = require(ReplicatedStorage.EngineFeatures.Signal)

-- [[ Type Definitions ]] --

type Face = { [number]: number }
type Vertex = {
	position: Vector3,
	faces: { [number]: Face }
}

-- [[ Variables ]] --

local ICOSAHEDRON_VERTICES, ICOSAHEDRON_FACES = Icosahedron[1], Icosahedron[2]

local VALID_MESH_FILTER_SHAPES = {
	"None",
	"Sphere"
}

local wedge = Instance.new("WedgePart");
wedge.Anchored = true;
wedge.TopSurface = Enum.SurfaceType.Smooth;
wedge.BottomSurface = Enum.SurfaceType.Smooth;

local function draw3dTriangle(a, b, c, parent, w1, w2)
	local ab, ac, bc = b - a, c - a, c - b;
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc);

	if (abd > acd and abd > bcd) then
		c, a = a, c;
	elseif (acd > bcd and acd > abd) then
		a, b = b, a;
	end

	ab, ac, bc = b - a, c - a, c - b;

	local right = ac:Cross(ab).unit;
	local up = bc:Cross(right).unit;
	local back = bc.unit;

	local height = math.abs(ab:Dot(up));

	w1 = w1 or wedge:Clone();
	w1.Size = Vector3.new(0, height, math.abs(ab:Dot(back)));
	w1.CFrame = CFrame.fromMatrix((a + b)/2, right, up, back);
	w1.Parent = parent;

	w2 = w2 or wedge:Clone();
	w2.Size = Vector3.new(0, height, math.abs(ac:Dot(back)));
	w2.CFrame = CFrame.fromMatrix((a + c)/2, -right, up, -back);
	w2.Parent = parent;

	return w1, w2;
end

-- [[ Public ]] --

function MeshFilter.Construct(instance: Instance, componentValue: ObjectValue, gameObject: any)
	local self = setmetatable(Component.new("MeshFilter", instance, componentValue, gameObject), MeshFilter)
	
	self.primeNumber = 17
	self.vertices = {}
	self.faces = {}
	self.shape = "None"
	
	Component.DeepCopyAttributes(self)
	
	return self
end

function MeshFilter:Start()
	if self.shape == "None" then
		return
	end
	
	if not table.find(VALID_MESH_FILTER_SHAPES, self.shape) then
		self.shape = "None"
		warn(`"{self.shape}" is not a valid \`MeshFilter\` shape.`)
		
		return
	end
	
	MeshFilter[`Generate{self.shape}`](self)
end

function MeshFilter:_generateHashForVertex(vertex: Vector3): number
	local hash = self.primeNumber
	
	hash = hash * 31 + math.floor(vertex.x * 1000 + 0.5)
	hash = hash * 31 + math.floor(vertex.y * 1000 + 0.5)
	hash = hash * 31 + math.floor(vertex.z * 1000 + 0.5)
	
	return hash
end

function MeshFilter:_registerVertex(vertex: Vector3, face: Face): number
	local hash: number = self:_generateHashForVertex(vertex)
	
	if not self.vertices[hash] then
		self.vertices[hash] = {
			position = vertex,
			faces = {}
		}
	end
	
	table.insert(self.vertices[hash].faces, face)
	
	return hash
end

function MeshFilter:_registerFace(vertex1: Vector3, vertex2: Vector3, vertex3: Vector3)
	local face = {}
	
	table.insert(face, self:_registerVertex(vertex1, face))
	table.insert(face, self:_registerVertex(vertex2, face))
	table.insert(face, self:_registerVertex(vertex3, face))
	
	table.insert(self.faces, face)
end

function MeshFilter:_searchVertexForFace(vertex: Vertex, face: Face): number
	for i = 1, #vertex.faces do
		if vertex.faces[i] ~= face then
			continue
		end

		return i
	end
end

function MeshFilter:Subdivide(subdivisions: number)
	if subdivisions <= 0 then
		return
	end
	
	local radius = self.radius
	
	local oldFaces = self.faces
	local newFaces = {}

	self.faces = newFaces
	
	if self.shape == "Sphere" then
		for _, vertices in ipairs(oldFaces) do
			local A = self.vertices[vertices[1]].position
			local B = self.vertices[vertices[2]].position
			local C = self.vertices[vertices[3]].position
			
			local AB = (A + B).Unit * radius
			local BC = (B + C).Unit * radius
			local CA = (C + A).Unit * radius
			
			local AR = A.Unit * radius
			local BR = B.Unit * radius
			local CR = C.Unit * radius
			
			self:_registerFace(AR, AB, CA)
			self:_registerFace(BR, BC, AB)
			self:_registerFace(CR, CA, BC)
			self:_registerFace(AB, BC, CA)
		end
	end
	
	task.defer(function()
		for i = 1, #oldFaces do
			local face: Face = oldFaces[i]
			
			for _, vertexId in ipairs(face) do
				local vertex: Vertex = self.vertices[vertexId]
				table.remove(vertex.faces, self:_searchVertexForFace(vertex, face))
			end
			
			oldFaces[i] = nil
		end
	end)
	
	self:Subdivide(subdivisions - 1)
end

function MeshFilter:GenerateSphere()
	local radius = self.radius
	local subdivisions = self.subdivisions
	
	-->>	Copy icosahedron faces to MeshFilter
	for _, face in ipairs(ICOSAHEDRON_FACES) do
		self:_registerFace(
			ICOSAHEDRON_VERTICES[face[1]].Unit * radius,
			ICOSAHEDRON_VERTICES[face[2]].Unit * radius,
			ICOSAHEDRON_VERTICES[face[3]].Unit * radius
		)
	end
	
	-->>	Subdivide faces
	if subdivisions > 0 then
		self:Subdivide(subdivisions)
	end
	
	local location = self.gameObject:GetRealObject()
	
	for _, face in ipairs(self.faces) do
		draw3dTriangle(
			self.vertices[face[1]].position,
			self.vertices[face[2]].position,
			self.vertices[face[3]].position,
			location
		)
	end
	
	print(#self.faces*8)
end

return (MeshFilter)
