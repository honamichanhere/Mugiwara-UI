--// Tab: a sidebar button + a scrolling page. It is also a Container, so elements
--// are added straight onto it (`tab:Toggle({ ... })`).

local Utility = Import("core/Utility")
local Icons = Import("core/Icons")
local Base = Import("components/Base")
local Container = Import("components/Container")

local Create, Tween = Utility.Create, Utility.Tween

-- `parent` is the sidebar list the button goes into (a TabSection body); defaults to the main list.
return function(window, opts, parent)
	opts = opts or {}
	local theme = window.Theme
	local name = opts.Title or "Tab"

	--// page
	local page = Create("CanvasGroup", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = window.Pages,
	})
	local scroll = Create("ScrollingFrame", { Size = UDim2.fromScale(1, 1), Parent = page })
	Utility.Padding(scroll, 14, 14, 16, 16)
	Utility.List(scroll, 8)

	local self = Container.new(window, scroll, scroll)
	self.Title = name
	self.Page = scroll
	self.PageFrame = page

	--// sidebar button
	local button = Create("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = window:NextTabOrder(),
		Parent = parent or window.TabList,
	})

	local background = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Parent = button,
	})
	Utility.Corner(background, 10)
	Base.Gradient(theme, background, 0)

	local indicator = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(3, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = button,
	})
	Utility.Corner(indicator, Utility.Pill)
	Base.Gradient(theme, indicator, 90)

	local iconBox = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Parent = button,
	})
	-- IconColor / IconColorActive: a Color3 or a theme token name; default is SubText idle, Text when selected
	local customColor, customActive = opts.IconColor, opts.IconColorActive
	local function iconTint(selected, tokens)
		local custom = selected and (customActive or customColor) or customColor
		if typeof(custom) == "Color3" then
			return custom
		elseif type(custom) == "string" and tokens[custom] ~= nil then
			return tokens[custom]
		end
		return selected and tokens.Text or tokens.SubText
	end

	local iconImage, iconLetter = Icons.Create(opts.Icon, iconBox), nil
	if iconImage then
		Icons.Tint(iconImage, iconTint(false, theme.Tokens))
		self.IconLabel = iconImage
	else
		iconLetter = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(string.sub(name, 1, 1)),
			Font = Enum.Font.GothamBlack,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = iconTint(false, theme.Tokens),
			Parent = iconBox,
		})
	end

	local label = Create("TextLabel", {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -52, 1, 0),
		Text = name,
		Font = Utility.Fonts.Label,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = theme.Tokens.SubText,
		Parent = button,
	})

	--// selection visuals
	self.Selected = false
	local token = 0

	function self:_setSelected(state)
		self.Selected = state
		token = token + 1
		local mine = token
		local tint = state and theme.Tokens.Text or theme.Tokens.SubText
		local iconColor = iconTint(state, theme.Tokens)

		Tween(background, { BackgroundTransparency = state and 0.8 or 1 }, 0.25)
		Tween(indicator, { Size = UDim2.fromOffset(3, state and 18 or 0) }, 0.3, Enum.EasingStyle.Back)
		Tween(label, { TextColor3 = tint }, 0.2)
		if iconImage then
			Icons.Tint(iconImage, iconColor, 0.2)
		else
			Tween(iconLetter, { TextColor3 = iconColor }, 0.2)
		end

		if state then
			-- slide up + fade in
			page.Position = UDim2.fromOffset(0, 14)
			page.Visible = true
			Tween(page, { GroupTransparency = 0, Position = UDim2.new() }, 0.4)
		else
			Tween(page, { GroupTransparency = 1 }, 0.14)
			task.delay(0.16, function()
				if mine == token and not self.Selected then
					page.Visible = false
				end
			end)
		end
	end

	local stopListening = theme:OnChange(function(tokens)
		local tint = self.Selected and tokens.Text or tokens.SubText
		label.TextColor3 = tint
		local iconColor = iconTint(self.Selected, tokens)
		if iconImage then
			Icons.Tint(iconImage, iconColor)
		else
			iconLetter.TextColor3 = iconColor
		end
	end)

	button.MouseButton1Click:Connect(function()
		window:SelectTab(self)
	end)
	button.MouseEnter:Connect(function()
		if not self.Selected then
			Tween(background, { BackgroundTransparency = 0.94 }, 0.15)
		end
	end)
	button.MouseLeave:Connect(function()
		if not self.Selected then
			Tween(background, { BackgroundTransparency = 1 }, 0.2)
		end
	end)

	function self:Select()
		window:SelectTab(self)
	end

	function self:SetTitle(text)
		self.Title = text
		label.Text = text
	end

	-- color / active: Color3 or theme token name; nil goes back to the theme colors. `active` defaults to `color`.
	function self:SetIconColor(color, active)
		customColor, customActive = color, active
		local tint = iconTint(self.Selected, theme.Tokens)
		if iconImage then
			Icons.Tint(iconImage, tint, 0.2)
		else
			Tween(iconLetter, { TextColor3 = tint }, 0.2)
		end
	end

	function self:Destroy()
		stopListening()
		button:Destroy()
		page:Destroy()
		window:_removeTab(self)
	end

	return self
end
