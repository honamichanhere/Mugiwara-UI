local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create = Utility.Create
local WHITE = Color3.new(1, 1, 1)

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
})

local function marker(parent, size)
	local dot = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	})
	Utility.Corner(dot, Utility.Pill)
	Utility.Stroke(dot, WHITE, 0, 2)
	return dot
end

-- opts: Title, Desc, Default (Color3), Transparency (number, enables the alpha bar), Callback, Flag
-- Callback(color, transparency)
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local el = Base.Card(container, opts, 40, 24)
	local drawer = Base.Expandable(el)

	local useAlpha = opts.Alpha == true or type(opts.Transparency) == "number"
	local start = opts.Default or opts.Value or Color3.fromRGB(255, 150, 40)
	local hue, sat, val = start:ToHSV()
	local alpha = 1 - (opts.Transparency or 0)

	--// swatch (closed state)
	local swatch = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = start,
		Parent = el.Right,
	})
	Utility.Corner(swatch, 7)
	Utility.Stroke(swatch, WHITE, 0.55, 1.5)

	--// saturation / value square
	local svBox = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		LayoutOrder = 1,
		Parent = drawer.Frame,
	})
	Utility.Corner(svBox, 8)

	local whiteLayer = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = svBox })
	Utility.Corner(whiteLayer, 8)
	Create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = whiteLayer })

	local blackLayer = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Parent = svBox,
	})
	Utility.Corner(blackLayer, 8)
	Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = blackLayer })

	local svMarker = marker(svBox, 14)
	local svHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = svBox })

	--// hue bar
	local hueBar = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = WHITE,
		LayoutOrder = 2,
		Parent = drawer.Frame,
	})
	Utility.Corner(hueBar, Utility.Pill)
	Create("UIGradient", { Color = RAINBOW, Parent = hueBar })
	local hueMarker = marker(hueBar, 16)
	hueMarker.Position = UDim2.fromScale(hue, 0.5)
	local hueHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = hueBar })

	--// alpha bar (optional)
	local alphaBar, alphaMarker, alphaHit
	if useAlpha then
		alphaBar = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundColor3 = start,
			LayoutOrder = 3,
			Parent = drawer.Frame,
		})
		Utility.Corner(alphaBar, Utility.Pill)
		Create("UIGradient", { Transparency = NumberSequence.new(0.9, 0), Parent = alphaBar })
		Utility.Stroke(alphaBar, WHITE, 0.85, 1)
		alphaMarker = marker(alphaBar, 16)
		alphaHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = alphaBar })
	end

	--// hex input
	local hexField = Base.Field(theme, drawer.Frame, UDim2.new(1, 0, 0, 28))
	hexField.LayoutOrder = 4
	local hexBox = Create("TextBox", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,
		Parent = hexField,
	})
	theme:Bind(hexBox, { TextColor3 = "Text" })

	--// state
	local function current()
		return Color3.fromHSV(hue, sat, val)
	end

	local function render()
		local color = current()
		swatch.BackgroundColor3 = color
		swatch.BackgroundTransparency = useAlpha and (1 - alpha) * 0.85 or 0
		svBox.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svMarker.Position = UDim2.fromScale(sat, 1 - val)
		hueMarker.Position = UDim2.fromScale(hue, 0.5)
		hexBox.Text = "#" .. Utility.ToHex(color)
		if alphaBar then
			alphaBar.BackgroundColor3 = color
			alphaMarker.Position = UDim2.fromScale(alpha, 0.5)
		end
	end

	local function fire()
		Utility.SafeCall(opts.Callback, current(), 1 - alpha)
	end

	local function commit()
		render()
		fire()
	end

	el.Value = current()
	render()

	function el:Set(value, silent)
		local color, transparency = value, nil
		if typeof(value) == "table" then
			color = Utility.FromHex(value.Hex or "") or current()
			transparency = value.Transparency
		elseif typeof(value) == "string" then
			color = Utility.FromHex(value)
		end
		if typeof(color) ~= "Color3" then
			return
		end
		hue, sat, val = color:ToHSV()
		if transparency then
			alpha = 1 - transparency
		end
		self.Value = color
		render()
		if not silent then
			fire()
		end
	end

	function el:GetTransparency()
		return 1 - alpha
	end

	function el:SetCallback(fn)
		opts.Callback = fn
	end

	el.Serialize = function()
		return { Hex = Utility.ToHex(current()), Transparency = 1 - alpha }
	end
	el.Deserialize = function(value)
		el:Set(value)
	end

	--// interaction
	local page = container.Page
	local function lockScroll()
		if page then
			page.ScrollingEnabled = false
		end
	end
	local function unlockScroll()
		if page then
			page.ScrollingEnabled = true
		end
	end

	local function ratio(frame, position, axis)
		local origin = axis == "X" and frame.AbsolutePosition.X or frame.AbsolutePosition.Y
		local length = axis == "X" and frame.AbsoluteSize.X or frame.AbsoluteSize.Y
		local point = axis == "X" and position.X or position.Y
		return Utility.Clamp((point - origin) / math.max(length, 1), 0, 1)
	end

	Utility.DragInput(svHit, el.Maid, lockScroll, function(position)
		sat = ratio(svBox, position, "X")
		val = 1 - ratio(svBox, position, "Y")
		el.Value = current()
		commit()
	end, unlockScroll)

	Utility.DragInput(hueHit, el.Maid, lockScroll, function(position)
		hue = ratio(hueBar, position, "X")
		el.Value = current()
		commit()
	end, unlockScroll)

	if alphaHit then
		Utility.DragInput(alphaHit, el.Maid, lockScroll, function(position)
			alpha = ratio(alphaBar, position, "X")
			commit()
		end, unlockScroll)
	end

	el.Maid:Give(hexBox.FocusLost:Connect(function()
		local color = Utility.FromHex(hexBox.Text)
		if color then
			el:Set(color)
		else
			render()
		end
	end))

	el.Maid:Give(el.Top.MouseButton1Click:Connect(function()
		if not el.Locked then
			drawer:Toggle()
		end
	end))

	return Base.Finish(container, el, opts, "Colorpicker")
end
