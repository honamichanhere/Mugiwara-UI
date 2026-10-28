local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

-- opts: Title, Desc, Value = { Min, Max, Default }, Step, Suffix, Callback, Flag
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local range = opts.Value or {}
	local min = range.Min or opts.Min or 0
	local max = range.Max or opts.Max or 100
	local step = opts.Step or 1
	local suffix = opts.Suffix or ""
	local decimals = Utility.Decimals(step)

	local el = Base.Card(container, opts, 74, 26)
	local extra = Base.Extra(el, 18)

	--// value box
	local box = Base.Field(theme, el.Right)
	local input = Create("TextBox", {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,
		Parent = box,
	})
	theme:Bind(input, { TextColor3 = "Text" })

	--// bar
	local hit = Create("TextButton", { Size = UDim2.fromScale(1, 1), Parent = extra })
	local rail = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = hit,
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
	local halo = Utility.Stroke(fill, Color3.new(1, 1, 1), 0.6, 2)
	Base.Gradient(theme, halo, 0)

	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = rail,
	})
	Utility.Corner(knob, Utility.Pill)
	local knobStroke = Utility.Stroke(knob, Color3.new(1, 1, 1), 0.2, 2)
	Base.Gradient(theme, knobStroke, 0)

	local function format(value)
		return Utility.FormatNumber(value, decimals) .. suffix
	end

	local function render(value, instant)
		local alpha = max == min and 0 or (value - min) / (max - min)
		input.Text = format(value)
		if instant then
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
		else
			Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, 0.1, Enum.EasingStyle.Quad)
			Tween(knob, { Position = UDim2.fromScale(alpha, 0.5) }, 0.1, Enum.EasingStyle.Quad)
		end
	end

	el.Value = Utility.Clamp(range.Default or opts.Default or min, min, max)
	render(el.Value, true)

	function el:Set(value, silent)
		value = Utility.Clamp(Utility.Snap(value, min, step), min, max)
		local changed = value ~= self.Value
		self.Value = value
		render(value, false)
		if changed and not silent then
			Utility.SafeCall(opts.Callback, value)
		end
	end

	function el:SetRange(newMin, newMax)
		min, max = newMin, newMax
		self:Set(self.Value, true)
	end

	function el:SetCallback(fn)
		opts.Callback = fn
	end

	el.Serialize = function()
		return el.Value
	end
	el.Deserialize = function(value)
		if type(value) == "number" then
			el:Set(value)
		end
	end

	local page = container.Page
	Utility.DragInput(hit, el.Maid, function()
		if page then
			page.ScrollingEnabled = false
		end
	end, function(position)
		local alpha = Utility.Clamp((position.X - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1)
		el:Set(min + (max - min) * alpha)
	end, function()
		if page then
			page.ScrollingEnabled = true
		end
	end)

	el.Maid:Give(input.FocusLost:Connect(function()
		local typed = tonumber(string.match(input.Text, "-?%d+%.?%d*"))
		if typed then
			el:Set(typed)
		else
			render(el.Value, true)
		end
	end))

	return Base.Finish(container, el, opts, "Slider")
end
