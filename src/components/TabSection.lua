--// TabSection: a titled, collapsible group of tabs inside the sidebar.
--//   local combat = Window:TabSection({ Title = "Combat" })
--//   combat:Tab({ Title = "Aimbot" })
--// Tab sections are one level only (they cannot contain other tab sections).

local Utility = Import("core/Utility")
local Icons = Import("core/Icons")

local Create, Tween = Utility.Create, Utility.Tween

-- opts: Title, Opened (default true), Collapsible (default true)
return function(window, opts)
	opts = opts or {}
	local theme = window.Theme
	local collapsible = opts.Collapsible ~= false

	local wrap = Create("Frame", {
		Name = opts.Title or "TabSection",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = window:NextTabOrder(),
		Parent = window.TabList,
	})
	Utility.List(wrap, 2)

	local header = Create("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 1,
		Parent = wrap,
	})
	local caption = Create("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Text = string.upper(opts.Title or "Group"),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	theme:Bind(caption, { TextColor3 = "Muted" })

	local chevron
	if collapsible then
		chevron = Icons.Chevron(header, 10, 2)
		chevron.AnchorPoint = Vector2.new(0.5, 0.5)
		chevron.Position = UDim2.new(1, -16, 0.5, 0)
		Icons.Bind(theme, chevron, "Muted")
	end

	local body = Create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = wrap,
	})
	local bodyInner = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	})
	Utility.List(bodyInner, 4)

	local group = { Frame = wrap, Body = bodyInner, Open = opts.Opened ~= false, Tabs = {} }

	local function bodyHeight()
		return bodyInner.AbsoluteSize.Y / window.UIScale.Scale
	end

	local function update(animate)
		local size = UDim2.new(1, 0, 0, group.Open and bodyHeight() or 0)
		if animate then
			Tween(body, { Size = size }, 0.3)
		else
			body.Size = size
		end
		if chevron then
			Tween(chevron, { Rotation = group.Open and 0 or -90 }, 0.25)
		end
	end

	function group:Tab(tabOpts)
		local tab = window:_createTab(tabOpts, bodyInner)
		table.insert(self.Tabs, tab)
		return tab
	end

	function group:SetOpen(open)
		self.Open = open
		update(true)
	end

	function group:ToggleOpen()
		self:SetOpen(not self.Open)
	end

	function group:SetTitle(text)
		caption.Text = string.upper(text)
	end

	function group:Destroy()
		for _, tab in ipairs(self.Tabs) do
			tab:Destroy()
		end
		wrap:Destroy()
	end

	bodyInner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if group.Open then
			body.Size = UDim2.new(1, 0, 0, bodyHeight())
		end
	end)

	if collapsible then
		header.MouseButton1Click:Connect(function()
			group:ToggleOpen()
		end)
	else
		header.Active = false
	end

	if chevron then
		chevron.Rotation = group.Open and 0 or -90
	end
	update(false)
	return group
end
