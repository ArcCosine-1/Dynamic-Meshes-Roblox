local HttpService = game:GetService("HttpService")

return function(): string
	return `{HttpService:GenerateGUID(false)}-{HttpService:GenerateGUID(false)}`
end
