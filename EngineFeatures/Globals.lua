local Global = {_didSetup = false}

if not Global._didSetup then
	for _, module in ipairs(script.Parent.Utility:GetChildren()) do
		Global[module.Name] = require(module)
	end
	
	Global._didSetup = true
end

return Global
