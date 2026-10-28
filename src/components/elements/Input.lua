local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

-- opts: Title, Desc, Value, Placeholder, Numeric, Type ("Input" | "Textarea"), Callback, Flag
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local textarea = opts.Type == "Textarea"

	local el = Base.Card(container, opts, (not textarea) and 176 or nil, 28)

	local field, stroke
	if textarea then
		local extra = Base.Extra(el, 84)
		field, stroke = Base.Field(theme, extra)
	else
		field, stroke = Base.Field(theme, el.Right)
	end

	local box = Create("TextBox", {
		Position = UDim2.fromOffset(10, textarea and 8 or 0),
		Size = UDim2.new(1, -20, 1, textarea and -16 or 0),
		Text = opts.Value or opts.Default or "",
		PlaceholderText = opts.Placeholder or "Type here...",
		Font = Utility.Fonts.Body,
		TextSize = 13,
		ClearTextOnFocus = false,
		MultiLine = textarea,
		TextWrapped = textarea,
		TextYAlignment = textarea and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
		Parent = field,
	})
	theme:Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })

	el.Value = box.Text

	function el:Set(value, silent)
		value = tostring(value or "")
		box.Text = value
		self.Value = value
		if not silent then
			Utility.SafeCall(opts.Callback, value)
		end
	end

	function el:SetPlaceholder(text)
		box.PlaceholderText = text
	end

	function el:SetCallback(fn)
		opts.Callback = fn
	end

	el.Serialize = function()
		return el.Value
	end
	el.Deserialize = function(value)
		el:Set(value)
	end

	el.Maid:Give(box.Focused:Connect(function()
		Tween(stroke, { Transparency = 0.2 }, 0.2)
		stroke.Color = theme.Tokens.Accent
	end))

	el.Maid:Give(box.FocusLost:Connect(function()
		Tween(stroke, { Transparency = theme.Tokens.StrokeAlpha }, 0.2)
		stroke.Color = theme.Tokens.Stroke
		if opts.Numeric then
			local number = tonumber(box.Text)
			box.Text = number and tostring(number) or (el.Value or "")
		end
		el.Value = box.Text
		Utility.SafeCall(opts.Callback, el.Value)
	end))

	if opts.Numeric then
		el.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
			local cleaned = string.gsub(box.Text, "[^%d%.%-]", "")
			if cleaned ~= box.Text then
				box.Text = cleaned
			end
		end))
	end

	return Base.Finish(container, el, opts, "Input")
end
