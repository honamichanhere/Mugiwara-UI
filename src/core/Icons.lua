--// Icons: asset-id resolver + small glyphs drawn from frames, so core controls
--// (chevron, check, close...) never depend on uploaded images.

local Utility = Import("core/Utility")
local IconSets = Import("core/IconSets")

local Create = Utility.Create

local Icons = {}
Icons.Registry = {}

local function normalize(icon)
	if type(icon) == "number" then
		return "rbxassetid://" .. Utility.IdText(icon)
	end
	if type(icon) == "string" then
		if string.find(icon, "^rbxasset") then
			return icon
		end
		if string.find(icon, "^%d+$") then
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

--// Glyphs --------------------------------------------------------------------------
-- The small controls (chevron, check, close, minimize, maximize, restore) are lucide icons.
-- Each one is first drawn from frames, so it works offline and before the icon set has
-- downloaded, then swapped for the icon as soon as it is available.
-- Icons.Glyphs[name] = "lucide:x" | any icon-set name | asset id; false / nil keeps the drawn version.
Icons.Glyphs = {
	Chevron = "lucide:chevron-down",
	Check = "lucide:check",
	Close = "lucide:x",
	Minus = "lucide:minus",
	Square = "lucide:square",
	Restore = "lucide:copy",
}

-- Icons.SetGlyphs({ Check = "lucide:circle-check", Close = "lucide:circle-x" }); false keeps the drawn glyph.
-- Affects the UI created after the call.
function Icons.SetGlyphs(map)
	for name, icon in pairs(map or {}) do
		if Icons.Glyphs[name] ~= nil then
			Icons.Glyphs[name] = icon
		end
	end
end

-- these icons sit inside a 24px canvas with padding: scaled up so they match the drawn glyphs' visual size
local GLYPH_SCALE = { Chevron = 1.35, Check = 1.15, Close = 1.4, Minus = 1.3, Square = 1.2, Restore = 1.2 }

-- holder -> { Theme, Token } for glyphs bound to a theme color; weak so destroyed glyphs vanish
local boundGlyphs = setmetatable({}, { __mode = "k" })

local function describeGlyph(icon)
	local direct = Icons.Resolve(icon)
	if direct then
		return { Image = direct }
	end
	return IconSets.Get(icon)
end

-- Glyph parts are drawn frames (bars / outlines) or the icon image; recolor whichever applies.
local function eachPart(glyph, applyFrame, applyImage)
	for _, child in ipairs(glyph:GetChildren()) do
		if child:IsA("Frame") then
			applyFrame(child, child:FindFirstChildOfClass("UIStroke"))
		elseif child:IsA("ImageLabel") and applyImage then
			applyImage(child)
		end
	end
end

local function readColor(glyph)
	local found
	eachPart(glyph, function(part, stroke)
		found = found or (stroke and stroke.Color or part.BackgroundColor3)
	end, function(image)
		found = found or image.ImageColor3
	end)
	return found or Color3.new(1, 1, 1)
end

local function swapForIcon(root, kind, size, descriptor)
	local color = readColor(root)
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("Frame") or child:IsA("ImageLabel") then
			child:Destroy()
		end
	end
	local span = size * (GLYPH_SCALE[kind] or 1.2)
	local image = Create("ImageLabel", {
		Name = "Image",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(span, span),
		ImageColor3 = color,
		Parent = root,
	})
	IconSets.Apply(image, descriptor)
	local bound = boundGlyphs[root]
	if bound then
		Icons.BindImage(bound.Theme, image, bound.Token)
	end
end

-- Upgrades run one at a time on a single thread: the first one may download the icon set, and the
-- glyphs created in the meantime wait for it instead of each starting their own download.
local queue, draining = {}, false

local function drain()
	if draining then
		return
	end
	draining = true
	task.spawn(function()
		while #queue > 0 do
			local job = table.remove(queue, 1)
			pcall(job)
		end
		draining = false
	end)
end

local function upgrade(root, kind, size)
	table.insert(queue, function()
		local icon = Icons.Glyphs and Icons.Glyphs[kind]
		if not icon or not root.Parent then
			return
		end
		local descriptor = describeGlyph(icon)
		if descriptor and root.Parent then
			swapForIcon(root, kind, size, descriptor)
		end
	end)
	drain()
end

-- Points down. Rotate the returned holder for other directions.
function Icons.Chevron(parent, size, thickness)
	local root = holder(parent, "Chevron", size)
	local length = size * 0.56
	bar(root, length, thickness or 2, 45, 0.31, 0.5)
	bar(root, length, thickness or 2, -45, 0.69, 0.5)
	upgrade(root, "Chevron", size)
	return root
end

function Icons.Check(parent, size, thickness)
	local root = holder(parent, "Check", size)
	bar(root, size * 0.34, thickness or 2, 42, 0.3, 0.63)
	bar(root, size * 0.64, thickness or 2, -48, 0.63, 0.51)
	upgrade(root, "Check", size)
	return root
end

function Icons.Close(parent, size, thickness)
	local root = holder(parent, "Close", size)
	bar(root, size * 0.78, thickness or 2, 45, 0.5, 0.5)
	bar(root, size * 0.78, thickness or 2, -45, 0.5, 0.5)
	upgrade(root, "Close", size)
	return root
end

function Icons.Minus(parent, size, thickness)
	local root = holder(parent, "Minus", size)
	bar(root, size * 0.7, thickness or 2, 0, 0.5, 0.5)
	upgrade(root, "Minus", size)
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
	upgrade(root, "Square", size)
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
	upgrade(root, "Restore", size)
	return root
end

-- Binds every part of a glyph to a theme color token (an icon that arrives later is bound too).
function Icons.Bind(theme, glyph, token)
	boundGlyphs[glyph] = { Theme = theme, Token = token }
	eachPart(glyph, function(part, stroke)
		if stroke then
			theme:Bind(stroke, { Color = token })
		else
			theme:Bind(part, { BackgroundColor3 = token })
		end
	end, function(image)
		Icons.BindImage(theme, image, token)
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
	end, function(image)
		Icons.Tint(image, color)
	end)
end

--// Image icons -----------------------------------------------------------------
-- Fills `parent` with an ImageLabel for:
--   * an asset id / rbxassetid / registered name -> full color image
--   * a Footagesus icon ("house", "lucide:house", "craft:folder-stroke") -> monochrome, tintable
-- Returns label, isMonochrome; nil when the icon cannot be found (unknown name, offline...).
function Icons.Create(icon, parent)
	if icon == nil or icon == "" then
		return nil
	end

	local direct = Icons.Resolve(icon)
	if direct then
		return Create("ImageLabel", { Name = "Icon", Size = UDim2.fromScale(1, 1), Image = direct, Parent = parent }), false
	end

	local descriptor = IconSets.Get(icon)
	if not descriptor then
		return nil
	end
	local label = Create("ImageLabel", { Name = "Icon", Size = UDim2.fromScale(1, 1), Parent = parent })
	IconSets.Apply(label, descriptor)
	return label, true
end

-- Tints an icon and its extra layers; pass a duration to animate.
function Icons.Tint(label, color, duration)
	local function paint(target)
		if duration then
			Utility.Tween(target, { ImageColor3 = color }, duration)
		else
			target.ImageColor3 = color
		end
	end
	paint(label)
	for _, child in ipairs(label:GetChildren()) do
		if child:IsA("ImageLabel") then
			paint(child)
		end
	end
end

function Icons.BindImage(theme, label, token)
	theme:Bind(label, { ImageColor3 = token })
	for _, child in ipairs(label:GetChildren()) do
		if child:IsA("ImageLabel") then
			theme:Bind(child, { ImageColor3 = token })
		end
	end
	return label
end

return Icons
