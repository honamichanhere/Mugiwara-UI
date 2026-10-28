local Utility = Import("core/Utility")
local Icons = Import("core/Icons")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

local ROW_HEIGHT = 32
local DESC_ROW_HEIGHT = 48
local ROW_GAP = 4
local LIST_MAX = 200
local LIST_INSET = 2
local WHITE = Color3.new(1, 1, 1)

-- Values entries are plain strings or tables { Title, Desc, Icon, IconColor }; Title is the value that
-- Get() / Callback return. Returns the names in order plus a name -> { Desc, Icon, IconColor } lookup.
local function normalize(list)
	local names, meta = {}, {}
	for _, item in ipairs(list or {}) do
		if type(item) == "table" then
			local name = item.Title or item.Name or item.Value
			if name ~= nil then
				table.insert(names, name)
				meta[name] = { Desc = item.Desc, Icon = item.Icon, IconColor = item.IconColor }
			end
		else
			table.insert(names, item)
		end
	end
	return names, meta
end

-- opts: Title, Desc, Values = { "a", { Title = "b", Desc = "...", Icon = "lucide:sword", IconColor = Color3 } },
--       Value (string | table when Multi), Multi, AllowNone, Searchable, Placeholder, Callback, Flag
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local multi = opts.Multi == true

	local el = Base.Card(container, opts, 156, 28)
	local drawer = Base.Expandable(el)

	local values, meta = normalize(opts.Values)
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

	-- icon of the chosen item (single select), shown before the text in the closed button
	local fieldIcon

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
	Utility.List(list, ROW_GAP)
	-- row borders are drawn outside the row: this inset keeps the scroll frame from clipping them
	Utility.Padding(list, LIST_INSET, LIST_INSET, LIST_INSET, LIST_INSET)

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
		if fieldIcon then
			fieldIcon:Destroy()
			fieldIcon = nil
		end
		if #names == 0 then
			label.Text = opts.Placeholder or "Select..."
			label.TextTransparency = 0.45
		else
			label.Text = table.concat(names, ", ")
			label.TextTransparency = 0
			local info = not multi and #names == 1 and meta[names[1]] or nil
			if info and info.Icon then
				local slot = Create("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 9, 0.5, 0),
					Size = UDim2.fromOffset(16, 16),
					BackgroundTransparency = 1,
					Parent = field,
				})
				local image = Icons.Create(info.Icon, slot)
				if image then
					Base.PaintIcon(theme, image, info.IconColor)
					fieldIcon = slot
				else
					slot:Destroy()
				end
			end
		end
		local left = fieldIcon and 32 or 10
		label.Position = UDim2.fromOffset(left, 0)
		label.Size = UDim2.new(1, -(left + 24), 1, 0)
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

	local function paintRow(row, hovered)
		local on = isSelected(row.Name)
		local tokens = theme.Tokens
		row.Frame.BackgroundTransparency = on and 0.78 or (hovered and 0.92 or 1)
		row.Check.Visible = on
		row.Stroke.Color = on and tokens.Accent or tokens.Stroke
		row.Stroke.Transparency = on and 0.45 or (hovered and 0.78 or tokens.StrokeAlpha)
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
		local shown, total = 0, 0
		for _, name in ipairs(values) do
			local info = meta[name]
			local haystack = string.lower(tostring(name) .. " " .. tostring(info and info.Desc or ""))
			if query == "" or string.find(haystack, query, 1, true) then
				shown = shown + 1
				local height = (info and info.Desc) and DESC_ROW_HEIGHT or ROW_HEIGHT
				total = total + height
				local button = Create("TextButton", {
					Name = tostring(name),
					Size = UDim2.new(1, 0, 0, height),
					BackgroundColor3 = WHITE,
					BackgroundTransparency = 1,
					LayoutOrder = shown,
					Parent = list,
				})
				Utility.Corner(button, 8)
				Base.Gradient(theme, button, 0)
				local stroke = Utility.Stroke(button, WHITE, 0.9, 1)

				-- icon column
				local left = 12
				if info and info.Icon then
					local slot = Create("Frame", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 10, 0.5, 0),
						Size = UDim2.fromOffset(20, 20),
						BackgroundTransparency = 1,
						Parent = button,
					})
					local image = Icons.Create(info.Icon, slot)
					if image then
						Base.PaintIcon(theme, image, info.IconColor)
						left = 40
					else
						slot:Destroy()
					end
				end

				local text = Create("TextLabel", {
					Position = UDim2.fromOffset(left, info and info.Desc and 7 or 0),
					Size = UDim2.new(1, -(left + 34), 0, info and info.Desc and 18 or height),
					Text = tostring(name),
					Font = Utility.Fonts.Label,
					TextSize = 13,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = button,
				})
				theme:Bind(text, { TextColor3 = "Text" })

				if info and info.Desc then
					local desc = Create("TextLabel", {
						Position = UDim2.fromOffset(left, 25),
						Size = UDim2.new(1, -(left + 34), 0, 16),
						Text = tostring(info.Desc),
						Font = Utility.Fonts.Desc,
						TextSize = 12,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Parent = button,
					})
					theme:Bind(desc, { TextColor3 = "SubText" })
				end

				local check = Icons.Check(button, 14, 2)
				check.AnchorPoint = Vector2.new(0.5, 0.5)
				check.Position = UDim2.new(1, -18, 0.5, 0)
				Icons.Bind(theme, check, "Text")

				local row = { Frame = button, Check = check, Stroke = stroke, Name = name }
				table.insert(rows, row)
				paintRow(row, false)

				button.MouseEnter:Connect(function()
					paintRow(row, true)
				end)
				button.MouseLeave:Connect(function()
					paintRow(row, false)
				end)
				button.MouseButton1Click:Connect(function()
					choose(name)
				end)
			end
		end
		local height = math.min(total + math.max(shown - 1, 0) * ROW_GAP + LIST_INSET * 2, LIST_MAX)
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
		elseif value ~= nil and not (type(value) == "table") then
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
		values, meta = normalize(newValues)
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

	-- row borders and the selection color are painted by hand, so they follow the theme through this listener
	el.Maid:Give(theme:OnChange(function()
		for _, row in ipairs(rows) do
			paintRow(row, false)
		end
	end))

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

	-- test access
	el.Rows = function()
		return rows
	end

	return Base.Finish(container, el, opts, "Dropdown")
end
