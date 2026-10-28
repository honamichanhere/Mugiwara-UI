--// Dialog: modal confirmation card drawn over the window.

local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

-- opts: Title, Content, Buttons = { { Title, Style = "Primary" | "Secondary" | "Danger", Callback } }
return function(window, opts)
	opts = opts or {}
	local theme = window.Theme

	local overlay = Create("TextButton", {
		Name = "Dialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = window.Frame,
	})
	Tween(overlay, { BackgroundTransparency = 0.42 }, 0.25)

	local card = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 330, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 51,
		Parent = overlay,
	})
	Utility.Corner(card, 14)
	theme:Bind(card, { BackgroundColor3 = "Popup", BackgroundTransparency = "PopupAlpha" })
	local outline = Utility.Stroke(card, Color3.new(1, 1, 1), 0.3, 1.4)
	Base.Gradient(theme, outline, 45)
	Utility.Padding(card, 18, 18, 18, 18)
	Utility.List(card, 10)

	local pop = Create("UIScale", { Scale = 0.9, Parent = card })
	Tween(pop, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)

	local title = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = opts.Title or "Dialog",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextWrapped = true,
		ZIndex = 52,
		LayoutOrder = 1,
		Parent = card,
	})
	Base.Gradient(theme, title, 0)

	if opts.Content then
		local content = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Content,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextWrapped = true,
			RichText = true,
			ZIndex = 52,
			LayoutOrder = 2,
			Parent = card,
		})
		theme:Bind(content, { TextColor3 = "SubText" })
	end

	local row = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		ZIndex = 52,
		LayoutOrder = 3,
		Parent = card,
	})
	Utility.List(row, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)

	local dialog = {}

	function dialog:Close()
		Tween(pop, { Scale = 0.92 }, 0.2)
		Tween(overlay, { BackgroundTransparency = 1 }, 0.2)
		task.delay(0.2, function()
			overlay:Destroy()
		end)
	end

	for index, spec in ipairs(opts.Buttons or { { Title = "OK", Style = "Primary" } }) do
		local style = spec.Style or "Secondary"
		local button = Create("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 36),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Text = spec.Title or "Button",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 53,
			LayoutOrder = index,
			Parent = row,
		})
		Utility.Padding(button, 0, 0, 18, 18)
		Utility.Corner(button, 9)

		if style == "Primary" then
			Base.Gradient(theme, button, 0)
			theme:Bind(button, { TextColor3 = "OnAccent" })
		elseif style == "Danger" then
			theme:Bind(button, { BackgroundColor3 = "Danger", TextColor3 = "OnAccent" })
		else
			theme:Bind(button, {
				BackgroundColor3 = "Card",
				BackgroundTransparency = "CardHoverAlpha",
				TextColor3 = "Text",
			})
		end

		button.MouseButton1Click:Connect(function()
			dialog:Close()
			Utility.SafeCall(spec.Callback)
		end)
	end

	return dialog
end
