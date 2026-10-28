--// Icons: asset-id resolver + small glyphs drawn from frames, so core controls
--// (chevron, check, close...) never depend on uploaded images.

local Utility = Import("core/Utility")

local Create = Utility.Create

local Icons = {}
Icons.Registry = {}

local function normalize(icon)
	if type(icon) == "number" then
		return "rbxassetid://" .. icon
	end
	if type(icon) == "string" then
		if string.find(icon, "^rbxasset") then
			return icon
		end
		if tonumber(icon) then
			return "rbxassetid://" .. icon
		end
	end
	return nil
end

-- Icons.Register({ home = "rbxassetid://123", sword = 456 })
function Icons.Register(map)
	for name, id in pairs(map) do
		Icons.Registry[string.lower(name)] = normalize(id)
	end
end

-- Accepts "rbxassetid://id", a number, or a registered name ("lucide:home" / "home").
function Icons.Resolve(icon)
	if icon == nil or icon == "" then
		return nil
	end
	local direct = normalize(icon)
	if direct then
		return direct
	end
	if type(icon) == "string" then
		local key = string.gsub(string.lower(icon), "^%w+:", "")
		return Icons.Registry[key]
	end
	return nil
end

local function bar(parent, length, thickness, rotation, x, y)
	local frame = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(length, thickness),
		Rotation = rotation,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	})
	Utility.Corner(frame, Utility.Pill)
	return frame
end

local function holder(parent, name, size)
	return Create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
end

-- Points down. Rotate the returned holder for other directions.
function Icons.Chevron(parent, size, thickness)
	local root = holder(parent, "Chevron", size)
	local length = size * 0.56
	bar(root, length, thickness or 2, 45, 0.31, 0.5)
	bar(root, length, thickness or 2, -45, 0.69, 0.5)
	return root
end

function Icons.Check(parent, size, thickness)
	local root = holder(parent, "Check", size)
	bar(root, size * 0.34, thickness or 2, 42, 0.3, 0.63)
	bar(root, size * 0.64, thickness or 2, -48, 0.63, 0.51)
	return root
end

function Icons.Close(parent, size, thickness)
	local root = holder(parent, "Close", size)
	bar(root, size * 0.78, thickness or 2, 45, 0.5, 0.5)
	bar(root, size * 0.78, thickness or 2, -45, 0.5, 0.5)
	return root
end

function Icons.Minus(parent, size, thickness)
	local root = holder(parent, "Minus", size)
	bar(root, size * 0.7, thickness or 2, 0, 0.5, 0.5)
	return root
end

-- Outlined square (maximize).
function Icons.Square(parent, size, thickness)
	local root = holder(parent, "Square", size)
	local box = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.62, size * 0.62),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Utility.Corner(box, 3)
	Utility.Stroke(box, Color3.new(1, 1, 1), 0, thickness or 2)
	return root
end

-- Two overlapping squares (restore from maximized).
function Icons.Restore(parent, size, thickness)
	local root = holder(parent, "Restore", size)
	local th = thickness or 2
	local front = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.4, 0.6),
		Size = UDim2.fromOffset(size * 0.5, size * 0.5),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Utility.Corner(front, 3)
	Utility.Stroke(front, Color3.new(1, 1, 1), 0, th)
	bar(root, size * 0.4, th, 0, 0.66, 0.16)
	bar(root, size * 0.38, th, 90, 0.86, 0.34)
	return root
end

-- Glyph parts are either filled bars or stroked outlines; recolor whichever applies.
local function eachPart(glyph, apply)
	for _, child in ipairs(glyph:GetChildren()) do
		if child:IsA("Frame") then
			local stroke = child:FindFirstChildOfClass("UIStroke")
			apply(child, stroke)
		end
	end
end

-- Binds every part of a drawn glyph to a theme color token.
function Icons.Bind(theme, glyph, token)
	eachPart(glyph, function(part, stroke)
		if stroke then
			theme:Bind(stroke, { Color = token })
		else
			theme:Bind(part, { BackgroundColor3 = token })
		end
	end)
	return glyph
end

function Icons.SetColor(glyph, color)
	eachPart(glyph, function(part, stroke)
		if stroke then
			stroke.Color = color
		else
			part.BackgroundColor3 = color
		end
	end)
end

-- Empties a glyph holder so another shape can be drawn into the same slot.
function Icons.Clear(glyph)
	for _, child in ipairs(glyph:GetChildren()) do
		child:Destroy()
	end
end

return Icons
