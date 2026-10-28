local UserInputService = game:GetService("UserInputService")

local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create = Utility.Create

-- opts: Title, Desc, Value ("RightShift"), Callback (fires when the key is pressed),
--       OnChange (fires when a new key is bound), Flag
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local el = Base.Card(container, opts, 96, 28)

	local field, stroke = Base.Field(theme, el.Right)
	local label = Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = field,
	})
	theme:Bind(label, { TextColor3 = "Text" })

	local listening = false

	local function keyName(value)
		if typeof(value) == "EnumItem" then
			return value.Name
		end
		return value
	end

	local function render()
		if listening then
			label.Text = "..."
		else
			label.Text = el.Value or "None"
		end
	end

	el.Value = keyName(opts.Value or opts.Default)
	render()

	function el:Set(value, silent)
		self.Value = keyName(value)
		listening = false
		render()
		if not silent then
			Utility.SafeCall(opts.OnChange, self.Value)
		end
	end

	function el:SetCallback(fn)
		opts.Callback = fn
	end

	el.Serialize = function()
		return el.Value
	end
	el.Deserialize = function(value)
		el:Set(value, true)
	end

	local function stopListening()
		listening = false
		stroke.Color = theme.Tokens.Stroke
		stroke.Transparency = theme.Tokens.StrokeAlpha
		render()
	end

	el.Maid:Give(el.Top.MouseButton1Click:Connect(function()
		if el.Locked then
			return
		end
		listening = not listening
		if listening then
			stroke.Color = theme.Tokens.Accent
			stroke.Transparency = 0.1
		else
			stopListening()
		end
		render()
	end))

	el.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if listening then
			if input.KeyCode == Enum.KeyCode.Escape then
				stopListening()
			elseif input.KeyCode == Enum.KeyCode.Backspace then
				el:Set(nil)
				stopListening()
			elseif input.KeyCode ~= Enum.KeyCode.Unknown then
				el:Set(input.KeyCode)
				stopListening()
			end
			return
		end

		if not processed and el.Value and input.KeyCode.Name == el.Value then
			Utility.SafeCall(opts.Callback, el.Value)
		end
	end))

	return Base.Finish(container, el, opts, "Keybind")
end
