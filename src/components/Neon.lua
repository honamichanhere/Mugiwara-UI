--// Neon: the shared look of every Mugiwara surface (Window, Key UI, Loading UI):
--// soft glow rings, a rotating gradient border and the glass wash + sheen layers.

local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create = Utility.Create
local WHITE = Color3.new(1, 1, 1)

local Neon = {}

-- Concentric strokes around the surface fake a soft neon glow without any image asset.
local LAYERS = {
	{ pad = 0, thickness = 3, transparency = 0.5 },
	{ pad = 3, thickness = 7, transparency = 0.8 },
	{ pad = 10, thickness = 14, transparency = 0.92 },
}

-- Glow rings behind the surface. Returns { { Stroke, Base } } so callers can fade them in and out.
function Neon.Glow(parent, theme, maid, radius)
	local entries = {}
	for _, layer in ipairs(LAYERS) do
		local ring = Create("Frame", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, layer.pad * 2, 1, layer.pad * 2),
			BackgroundTransparency = 1,
			Parent = parent,
		})
		Utility.Corner(ring, radius + layer.pad)
		local stroke = Utility.Stroke(ring, WHITE, layer.transparency, layer.thickness)
		Utility.Spin(maid, Base.Gradient(theme, stroke, 0, "CycleSeq"), 9)
		table.insert(entries, { Stroke = stroke, Base = layer.transparency })
	end
	return entries
end

-- Thin rotating border drawn above the surface.
function Neon.Border(parent, theme, maid, radius, zindex)
	local border = Create("Frame", {
		Name = "Border",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = zindex or 5,
		Parent = parent,
	})
	Utility.Corner(border, radius)
	local stroke = Utility.Stroke(border, WHITE, 0.3, 1.5)
	Utility.Spin(maid, Base.Gradient(theme, stroke, 0, "CycleSeq"), 9)
	return { Stroke = stroke, Base = 0.3 }
end

-- Accent wash + glass sheen inside a surface.
-- One UIGradient per instance: Roblox ignores extra ones, so color and transparency share it.
function Neon.Glass(surface, theme)
	local wash = Create("Frame", { Name = "Wash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = surface })
	Base.Gradient(theme, wash, 35).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.86),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.9),
	})

	local sheen = Create("Frame", { Name = "Sheen", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = surface })
	Create("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.92),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(1, 0.97),
		}),
		Parent = sheen,
	})
end

return Neon
