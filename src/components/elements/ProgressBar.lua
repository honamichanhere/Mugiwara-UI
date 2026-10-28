local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

-- opts: Title, Desc, Value (default 0), Min (0), Max (100), Suffix ("%")
-- el:Set(value) animates the bar; el:SetText("custom") replaces the value text.
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local min = opts.Min or 0
	local max = opts.Max or 100
	local suffix = opts.Suffix or "%"

	local el = Base.Card(container, opts, 70, 24)
	local extra = Base.Extra(el, 10)

	local valueLabel = Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = el.Right,
	})
	theme:Bind(valueLabel, { TextColor3 = "Text" })

	local rail = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = extra,
	})
	Utility.Corner(rail, Utility.Pill)
	theme:Bind(rail, { BackgroundColor3 = "Track", BackgroundTransparency = "TrackAlpha" })

	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = rail,
	})
	Utility.Corner(fill, Utility.Pill)
	Base.Gradient(theme, fill, 0)

	local customText

	local function render(value, instant)
		local alpha = max == min and 0 or Utility.Clamp((value - min) / (max - min), 0, 1)
		valueLabel.Text = customText or (string.format("%d", math.floor(value + 0.5)) .. suffix)
		if instant then
			fill.Size = UDim2.fromScale(alpha, 1)
		else
			Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, 0.35)
		end
	end

	el.Value = Utility.Clamp(opts.Value or opts.Default or min, min, max)
	render(el.Value, true)

	function el:Set(value, instant)
		self.Value = Utility.Clamp(tonumber(value) or min, min, max)
		render(self.Value, instant == true)
	end

	function el:SetText(text)
		customText = text
		render(self.Value, true)
	end

	return Base.Finish(container, el, opts, "ProgressBar")
end
