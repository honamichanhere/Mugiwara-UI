local Utility = Import("core/Utility")
local Icons = Import("core/Icons")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

local ROW_HEIGHT = 30
local LIST_MAX = 170

-- opts: Title, Desc, Values = { "a", "b" }, Value (string | table when Multi), Multi,
--       AllowNone, Searchable, Placeholder, Callback, Flag
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local multi = opts.Multi == true

	local el = Base.Card(container, opts, 156, 28)
	local drawer = Base.Expandable(el)

	local values = table.clone(opts.Values or {})
	local selected = {}
	local rows = {}
	local query = ""

	--// closed-state button
	local field = Base.Field(theme, el.Right)
	local label = Create("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Font = Utility.Fonts.Body,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = field,
	})
	theme:Bind(label, { TextColor3 = "Text" })

	local chevron = Icons.Chevron(field, 12, 2)
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Position = UDim2.new(1, -14, 0.5, 0)
	Icons.Bind(theme, chevron, "SubText")

	--// drawer content
	local searchField, searchBox
	local wantSearch = opts.Searchable
	if wantSearch == nil then
		wantSearch = #values > 8
	end
	if wantSearch then
		searchField = Base.Field(theme, drawer.Frame, UDim2.new(1, 0, 0, 30))
		searchField.LayoutOrder = 1
		searchBox = Create("TextBox", {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			PlaceholderText = "Search...",
			Text = "",
			Font = Utility.Fonts.Body,
			TextSize = 13,
			ClearTextOnFocus = false,
			Parent = searchField,
		})
		theme:Bind(searchBox, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })
	end

	local list = Create("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = drawer.Frame,
	})
	Utility.List(list, 2)

	--// helpers
	local function isSelected(name)
		return selected[name] == true
	end

	local function selectedNames()
		local names = {}
		for _, name in ipairs(values) do
			if selected[name] then
				table.insert(names, name)
			end
		end
		return names
	end

	local function renderLabel()
		local names = selectedNames()
		if #names == 0 then
			label.Text = opts.Placeholder or "Select..."
			label.TextTransparency = 0.45
		else
			label.Text = table.concat(names, ", ")
			label.TextTransparency = 0
		end
	end

	local function currentValue()
		if multi then
			return selectedNames()
		end
		return selectedNames()[1]
	end

	local function fire()
		Utility.SafeCall(opts.Callback, currentValue())
	end

	local function paintRow(row, name, hovered)
		local on = isSelected(name)
		row.Frame.BackgroundTransparency = on and 0.78 or (hovered and 0.93 or 1)
		row.Check.Visible = on
	end

	local function clearRows()
		for _, row in ipairs(rows) do
			row.Frame:Destroy()
		end
		rows = {}
	end

	local choose

	local function rebuild()
		clearRows()
		local shown = 0
		for _, name in ipairs(values) do
			if query == "" or string.find(string.lower(name), query, 1, true) then
				shown = shown + 1
				local button = Create("TextButton", {
					Name = name,
					Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					LayoutOrder = shown,
					Parent = list,
				})
				Utility.Corner(button, 7)
				Base.Gradient(theme, button, 0)

				local text = Create("TextLabel", {
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(1, -36, 1, 0),
					Text = name,
					Font = Utility.Fonts.Body,
					TextSize = 13,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = button,
				})
				theme:Bind(text, { TextColor3 = "Text" })

				local check = Icons.Check(button, 14, 2)
				check.AnchorPoint = Vector2.new(0.5, 0.5)
				check.Position = UDim2.new(1, -16, 0.5, 0)
				Icons.Bind(theme, check, "Text")

				local row = { Frame = button, Check = check }
				table.insert(rows, row)
				paintRow(row, name, false)

				button.MouseEnter:Connect(function()
					paintRow(row, name, true)
				end)
				button.MouseLeave:Connect(function()
					paintRow(row, name, false)
				end)
				button.MouseButton1Click:Connect(function()
					choose(name)
				end)
			end
		end
		local height = math.min(shown * (ROW_HEIGHT + 2), LIST_MAX)
		list.Size = UDim2.new(1, 0, 0, height)
		list.Visible = shown > 0
	end

	local function repaint()
		rebuild()
		renderLabel()
	end

	local function setOpen(open)
		drawer:Set(open)
		Tween(chevron, { Rotation = open and 180 or 0 }, 0.25)
	end

	choose = function(name)
		if multi then
			selected[name] = not selected[name] or nil
		else
			if selected[name] then
				if opts.AllowNone then
					selected[name] = nil
				end
			else
				selected = { [name] = true }
			end
		end
		repaint()
		fire()
		if not multi then
			setOpen(false)
		end
	end

	--// public api
	local function load(value)
		selected = {}
		if multi then
			for _, name in ipairs(type(value) == "table" and value or {}) do
				selected[name] = true
			end
		elseif type(value) == "string" then
			selected[value] = true
		end
	end

	load(opts.Value or opts.Default)
	repaint()

	function el:Set(value, silent)
		load(value)
		repaint()
		if not silent then
			fire()
		end
	end

	function el:Get()
		return currentValue()
	end

	function el:Refresh(newValues, keepSelection)
		values = table.clone(newValues or {})
		if keepSelection then
			for name in pairs(selected) do
				if not table.find(values, name) then
					selected[name] = nil
				end
			end
		else
			selected = {}
		end
		repaint()
	end

	function el:Open()
		setOpen(true)
	end

	function el:Close()
		setOpen(false)
	end

	function el:SetCallback(fn)
		opts.Callback = fn
	end

	el.Serialize = function()
		return currentValue()
	end
	el.Deserialize = function(value)
		el:Set(value)
	end

	if searchBox then
		el.Maid:Give(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			query = string.lower(searchBox.Text)
			rebuild()
		end))
	end

	el.Maid:Give(el.Top.MouseButton1Click:Connect(function()
		if not el.Locked then
			setOpen(not drawer.Open)
		end
	end))

	return Base.Finish(container, el, opts, "Dropdown")
end
