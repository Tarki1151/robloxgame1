--[[
	Create
	Instance olusturmayi kisaltan yardimci.
	  Create("Frame", { Size = ..., Parent = gui }, { childInstance, ... })
	Parent daima en son atanir (tek seferde render, daha az layout maliyeti).
]]

return function(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)

	if props then
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if props and props.Parent then
		instance.Parent = props.Parent
	end

	return instance
end
