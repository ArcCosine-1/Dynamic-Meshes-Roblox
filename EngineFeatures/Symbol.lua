type Symbol = typeof(newproxy(true))

return function(name: string): Symbol
	if type(name) ~= "string" then
		error("\"name\" must be a string.", 2)
	end
	
	local symbol = newproxy(true)
	
	getmetatable(symbol).__tostring = function()
		return name
	end
	
	return symbol
end
