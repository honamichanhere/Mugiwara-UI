local Utility = Import("core/Utility")
local Icons = Import("core/Icons")
local Base = Import("components/Base")
local Popup = Import("components/Popup")

local Create, Tween = Utility.Create, Utility.Tween
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

local MODES = { "HEX", "RGB", "HSV", "HSL" }
local SQUARE = 168 -- saturation / value square
local BAR = 14 -- hue / opacity slider thickness (handles are wider than the bar on purpose)
local HANDLE = 22
local INNER = 230 -- content width of the popup (card width minus padding)
local GAP = 8 -- space between fields / tabs
local PAD = 16

--// HSL helpers (HSV comes from Color3) ----------------------------------------
local function toHSL(color)
	local r, g, b = color.R, color.G, color.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local l = (max + min) / 2
	local h, s = 0, 0
	if max ~= min then
		local d = max - min
		s = l > 0.5 and d / (2 - max - min) or d / (max + min)
		if max == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end
	return h, s, l
end

local function fromHSL(h, s, l)
	if s == 0 then
		return Color3.new(l, l, l)
	end
	local function channel(p, q, t)
		if t < 0 then
			t = t + 1
		elseif t > 1 then
			t = t - 1
		end
		if t < 1 / 6 then
			return p + (q - p) * 6 * t
		elseif t < 1 / 2 then
			return q
		elseif t < 2 / 3 then
			return p + (q - p) * (2 / 3 - t) * 6
		end
		return p
	end
	local q = l < 0.5 and l * (1 + s) or l + s - l * s
	local p = 2 * l - q
	return Color3.new(channel(p, q, h + 1 / 3), channel(p, q, h), channel(p, q, h - 1 / 3))
end

local function round(value)
	return math.floor(value + 0.5)
end

-- Ring handle: white ring with the picked color inside, so it reads on any background.
local function marker(parent, size)
	local dot = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = WHITE,
		ZIndex = 5,
		Parent = parent,
	})
	Utility.Corner(dot, Utility.Pill)
	Utility.Stroke(dot, Color3.new(0, 0, 0), 0.55, 1)
	local fill = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = WHITE,
		ZIndex = 6,
		Parent = dot,
	})
	Utility.Corner(fill, Utility.Pill)
	return dot, fill
end

-- opts: Title, Desc, Default (Color3), Transparency (0 = opaque), Callback(color, transparency), Flag
-- The picker opens as a popup: color square, hue slider, opacity slider (0-100), HEX / RGB / HSV / HSL fields.
return function(container, opts)
	opts = opts or {}
	local window = container.Window
	local theme = window.Theme
	local el = Base.Card(container, opts, 40, 24)

	local start = opts.Default or opts.Value or Color3.fromRGB(255, 150, 40)
	local hue, sat, val = start:ToHSV()
	local alpha = 1 - (opts.Transparency or 0) -- opacity, 1 = fully visible
	local mode = "HEX"
	local ui -- widgets of the open popup, nil while closed

	--// swatch (closed state)
	local swatch = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = start,
		Parent = el.Right,
	})
	Utility.Corner(swatch, 7)
	Utility.Stroke(swatch, WHITE, 0.55, 1.5)

	local function current()
		return Color3.fromHSV(hue, sat, val)
	end

	-- keeps the old hue when the new color is gray / black (hue is undefined there)
	local function setFromColor(color)
		local h, s, v = color:ToHSV()
		if s > 0 and v > 0 then
			hue = h
		end
		sat, val = s, v
	end

	local function renderFields()
		if not ui then
			return
		end
		local color = current()
		local values
		if mode == "HEX" then
			values = { "#" .. Utility.ToHex(color) }
		elseif mode == "RGB" then
			values = { round(color.R * 255), round(color.G * 255), round(color.B * 255) }
		elseif mode == "HSV" then
			values = { round(hue * 360), round(sat * 100), round(val * 100) }
		else
			local h, s, l = toHSL(color)
			values = { round((s > 0 and l > 0 and l < 1) and h * 360 or hue * 360), round(s * 100), round(l * 100) }
		end
		for index, box in ipairs(ui.Boxes) do
			box.Text = tostring(values[index])
		end
		ui.Alpha.Text = round(alpha * 100) .. "%"
	end

	local function render()
		local color = current()
		swatch.BackgroundColor3 = color
		swatch.BackgroundTransparency = (1 - alpha) * 0.85
		if ui then
			ui.Square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			ui.SquareMarker.Position = UDim2.fromScale(sat, 1 - val)
			ui.SquareFill.BackgroundColor3 = color
			ui.HueMarker.Position = UDim2.fromScale(0.5, hue)
			ui.HueFill.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			ui.AlphaBar.BackgroundColor3 = color
			ui.AlphaMarker.Position = UDim2.fromScale(0.5, 1 - alpha)
			ui.AlphaFill.BackgroundColor3 = color
			ui.Preview.BackgroundColor3 = color
			ui.Preview.BackgroundTransparency = 1 - alpha
			renderFields()
		end
	end

	local function fire()
		Utility.SafeCall(opts.Callback, current(), 1 - alpha)
	end

	local function commit()
		el.Value = current()
		render()
		fire()
	end

	el.Value = current()
	render()

	--// public api
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
		setFromColor(color)
		if transparency then
			alpha = 1 - transparency
		end
		self.Value = current()
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

	--// popup ----------------------------------------------------------------------
	local function applyField(index, text)
		local number = tonumber(string.match(text, "-?%d+%.?%d*"))
		if mode == "HEX" then
			local color = Utility.FromHex(text)
			if color then
				setFromColor(color)
			end
		elseif not number then
			return
		elseif mode == "RGB" then
			local channels = {
				round(current().R * 255),
				round(current().G * 255),
				round(current().B * 255),
			}
			channels[index] = Utility.Clamp(round(number), 0, 255)
			setFromColor(Color3.fromRGB(channels[1], channels[2], channels[3]))
		elseif mode == "HSV" then
			if index == 1 then
				hue = Utility.Clamp(number, 0, 360) / 360
			elseif index == 2 then
				sat = Utility.Clamp(number, 0, 100) / 100
			else
				val = Utility.Clamp(number, 0, 100) / 100
			end
		else
			local h, s, l = toHSL(current())
			if index == 1 then
				h = Utility.Clamp(number, 0, 360) / 360
			elseif index == 2 then
				s = Utility.Clamp(number, 0, 100) / 100
			else
				l = Utility.Clamp(number, 0, 100) / 100
			end
			setFromColor(fromHSL(h, s, l))
			if s > 0 and l > 0 and l < 1 then
				hue = h
			end
		end
		commit()
	end

	local function buildFields(row, popMaid)
		for _, child in ipairs(row:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		ui.Boxes = {}

		local count = mode == "HEX" and 1 or 3
		local alphaWidth = 60
		local fieldWidth = math.floor((INNER - alphaWidth - GAP * count) / count)

		for index = 1, count do
			local field = Base.Field(theme, row, UDim2.fromOffset(fieldWidth, 32))
			field.LayoutOrder = index
			local box = Create("TextBox", {
				Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
				ClearTextOnFocus = false,
				Parent = field,
			})
			theme:Bind(box, { TextColor3 = "Text" })
			popMaid:Give(box.FocusLost:Connect(function()
				applyField(index, box.Text)
			end))
			ui.Boxes[index] = box
		end

		local alphaField = Base.Field(theme, row, UDim2.fromOffset(alphaWidth, 32))
		alphaField.LayoutOrder = 10
		local alphaBox = Create("TextBox", {
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			ClearTextOnFocus = false,
			Parent = alphaField,
		})
		theme:Bind(alphaBox, { TextColor3 = "Text" })
		popMaid:Give(alphaBox.FocusLost:Connect(function()
			local number = tonumber(string.match(alphaBox.Text, "-?%d+%.?%d*"))
			if number then
				alpha = Utility.Clamp(number, 0, 100) / 100
				commit()
			else
				render()
			end
		end))
		ui.Alpha = alphaBox
		renderFields()
	end

	local function open()
		local popMaid = Utility.Maid.new()
		local popup = Popup(window, {
			Width = INNER + PAD * 2,
			Padding = PAD,
			Gap = 12,
			OnClose = function()
				popMaid:Clean()
				ui = nil
				el._ui = nil
			end,
		})
		local card = popup.Card
		ui = {}
		el._ui = ui
		el.Popup = popup

		--// header
		local header = Create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
		local title = Create("TextLabel", {
			Size = UDim2.new(1, -90, 1, 0),
			Text = opts.Title or "Color",
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		Base.Gradient(theme, title, 0)

		ui.Preview = Create("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -38, 0.5, 0),
			Size = UDim2.fromOffset(36, 20),
			BackgroundColor3 = current(),
			Parent = header,
		})
		Utility.Corner(ui.Preview, 6)
		Utility.Stroke(ui.Preview, WHITE, 0.6, 1)

		local closeButton = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			Parent = header,
		})
		Utility.Corner(closeButton, 9)
		local closeGlyph = Icons.Close(closeButton, 18, 2)
		Icons.Bind(theme, closeGlyph, "SubText")
		closeButton.MouseEnter:Connect(function()
			Tween(closeButton, { BackgroundTransparency = 0.88 }, 0.15)
			Icons.SetColor(closeGlyph, theme.Tokens.Danger)
		end)
		closeButton.MouseLeave:Connect(function()
			Tween(closeButton, { BackgroundTransparency = 1 }, 0.2)
			Icons.SetColor(closeGlyph, theme.Tokens.SubText)
		end)
		popMaid:Give(closeButton.MouseButton1Click:Connect(function()
			popup:Close()
		end))

		--// square + sliders
		local area = Create("Frame", { Size = UDim2.new(1, 0, 0, SQUARE), BackgroundTransparency = 1, LayoutOrder = 2, Parent = card })

		ui.Square = Create("Frame", {
			Size = UDim2.fromOffset(SQUARE, SQUARE),
			BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
			Parent = area,
		})
		Utility.Corner(ui.Square, 8)
		local whiteLayer = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = ui.Square })
		Utility.Corner(whiteLayer, 8)
		Create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = whiteLayer })
		local blackLayer = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = ui.Square })
		Utility.Corner(blackLayer, 8)
		Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = blackLayer })
		ui.SquareMarker, ui.SquareFill = marker(ui.Square, 20)
		local squareHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = ui.Square })

		local hueBar = Create("Frame", {
			Position = UDim2.fromOffset(SQUARE + 16, 0),
			Size = UDim2.fromOffset(BAR, SQUARE),
			BackgroundColor3 = WHITE,
			Parent = area,
		})
		Utility.Corner(hueBar, Utility.Pill)
		Create("UIGradient", { Rotation = 90, Color = RAINBOW, Parent = hueBar })
		ui.HueMarker, ui.HueFill = marker(hueBar, HANDLE)
		local hueHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = hueBar })

		ui.AlphaBar = Create("Frame", {
			Position = UDim2.fromOffset(SQUARE + 16 + BAR + 16, 0),
			Size = UDim2.fromOffset(BAR, SQUARE),
			BackgroundColor3 = current(),
			Parent = area,
		})
		Utility.Corner(ui.AlphaBar, Utility.Pill)
		Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.95), Parent = ui.AlphaBar })
		Utility.Stroke(ui.AlphaBar, WHITE, 0.85, 1)
		ui.AlphaMarker, ui.AlphaFill = marker(ui.AlphaBar, HANDLE)
		local alphaHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = ui.AlphaBar })

		local function ratio(frame, position, axis)
			local origin = axis == "X" and frame.AbsolutePosition.X or frame.AbsolutePosition.Y
			local length = axis == "X" and frame.AbsoluteSize.X or frame.AbsoluteSize.Y
			local point = axis == "X" and position.X or position.Y
			return Utility.Clamp((point - origin) / math.max(length, 1), 0, 1)
		end

		Utility.DragInput(squareHit, popMaid, nil, function(position)
			sat = ratio(ui.Square, position, "X")
			val = 1 - ratio(ui.Square, position, "Y")
			commit()
		end)
		Utility.DragInput(hueHit, popMaid, nil, function(position)
			hue = ratio(hueBar, position, "Y")
			commit()
		end)
		Utility.DragInput(alphaHit, popMaid, nil, function(position)
			alpha = 1 - ratio(ui.AlphaBar, position, "Y")
			commit()
		end)

		--// mode tabs
		local tabs = Create("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 3, Parent = card })
		Utility.List(tabs, GAP, Enum.FillDirection.Horizontal)
		local tabWidth = math.floor((INNER - GAP * (#MODES - 1)) / #MODES)
		local row
		local tabButtons = {}

		local function paintTabs()
			for name, button in pairs(tabButtons) do
				local selected = name == mode
				Tween(button.Background, { BackgroundTransparency = selected and 0.78 or 1 }, 0.2)
				button.Label.TextColor3 = selected and theme.Tokens.Text or theme.Tokens.SubText
			end
		end

		for index, name in ipairs(MODES) do
			local button = Create("TextButton", {
				Size = UDim2.fromOffset(tabWidth, 32),
				LayoutOrder = index,
				Parent = tabs,
			})
			local background = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = button })
			Utility.Corner(background, 9)
			Base.Gradient(theme, background, 0)
			local label = Create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Text = name,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = button,
			})
			tabButtons[name] = { Background = background, Label = label }
			popMaid:Give(button.MouseButton1Click:Connect(function()
				ui.SetMode(name)
			end))
		end

		ui.SetMode = function(name)
			mode = name
			paintTabs()
			buildFields(row, popMaid)
		end

		--// fields
		row = Create("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 4, Parent = card })
		Utility.List(row, GAP, Enum.FillDirection.Horizontal)

		paintTabs()
		buildFields(row, popMaid)
		render()
	end

	function el:Open()
		if not ui then
			open()
		end
	end

	function el:Close()
		if el.Popup and not el.Popup.Closed then
			el.Popup:Close()
		end
	end

	el.Maid:Give(el.Top.MouseButton1Click:Connect(function()
		if not el.Locked then
			el:Open()
		end
	end))

	el.Maid:Give(function()
		el:Close()
	end)

	return Base.Finish(container, el, opts, "Colorpicker")
end
