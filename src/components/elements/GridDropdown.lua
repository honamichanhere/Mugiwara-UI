--// GridDropdown: a searchable picker that shows its options as a grid of pictures instead of a list.

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Icons = Import("core/Icons")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

local WHITE = Color3.new(1, 1, 1)
local GAP = 8
local INSET = 3 -- cell borders are drawn outside the cell: this keeps the scroll frame from clipping them
local TITLE_HEIGHT = 26

local SCALE_TYPES = {
	Crop = Enum.ScaleType.Crop,
	Fit = Enum.ScaleType.Fit,
	Stretch = Enum.ScaleType.Stretch,
}

-- Values entries are strings or tables { Title, Image, Icon, IconColor }. Title is the value Get() / Callback return.
local function normalize(list)
	local names, meta = {}, {}
	for _, item in ipairs(list or {}) do
		if type(item) == "table" then
			local name = item.Title or item.Name or item.Value
			if name ~= nil then
				table.insert(names, name)
				meta[name] = { Image = item.Image, Icon = item.Icon, IconColor = item.IconColor }
			end
		else
			table.insert(names, item)
		end
	end
	return names, meta
end

-- opts: Title, Desc, Icon, Values = { "a", { Title = "Sword", Image = "rbxassetid://...", Icon = "lucide:sword" } },
--       Value (string | table when Multi), Multi, AllowNone, Searchable (default true), Placeholder, Callback, Flag,
--       Columns (3), CellHeight (104), MaxHeight (260, the grid scrolls beyond it), Titles (false = pictures only),
--       Scale ("Crop" | "Fit" | "Stretch")
-- Image takes an asset id, rbxassetid://, or an http(s) URL (Store ids are Decals and are converted, see
-- Compat.ResolveImage). Icon takes an icon-set name and is drawn small in the middle when there is no Image.
-- el:SetGrid({ Columns, CellHeight, MaxHeight }) changes the grid later.
return function(container, opts)
	opts = opts or {}
	local window = container.Window
	local theme = window.Theme
	local multi = opts.Multi == true

	local columns = math.max(1, math.floor(opts.Columns or 3))
	local cellHeight = opts.CellHeight or 104
	local maxHeight = opts.MaxHeight or 260
	local showTitles = opts.Titles ~= false
	local scaleType = SCALE_TYPES[opts.Scale or "Crop"] or Enum.ScaleType.Crop

	local el = Base.Card(container, opts, 156, 28)
	local drawer = Base.Expandable(el)

	local values, meta = normalize(opts.Values)
	local selected = {}
	local cells = {}
	local assets = {} -- name -> resolved image, so a rebuild (typing in the search box) does not load pictures again
	local query = ""

	--// pictures -------------------------------------------------------------------
	-- Fills `slot` with the item's picture, its icon, or the first letter of its title.
	local function paintThumb(name, slot, radius, iconSize)
		local info = meta[name]
		local letter
		if not (info and (info.Image or info.Icon)) or (info.Image and not info.Icon) then
			letter = Create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Text = string.upper(string.sub(tostring(name), 1, 1)),
				Font = Enum.Font.GothamBlack,
				TextSize = math.max(12, math.floor(slot.Size.Y.Offset * 0.5)),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = slot,
			})
			theme:Bind(letter, { TextColor3 = "Muted" })
		end
		if not info then
			return
		end

		if info.Image then
			local image = Create("ImageLabel", {
				Name = "Picture",
				Size = UDim2.fromScale(1, 1),
				ScaleType = scaleType,
				ImageTransparency = 1,
				Parent = slot,
			})
			Utility.Corner(image, radius)
			local function show(asset, instant)
				image.Image = asset
				if letter then
					letter.Visible = false
				end
				if instant then
					image.ImageTransparency = 0
				else
					Tween(image, { ImageTransparency = 0 }, 0.35)
				end
			end
			if assets[name] then
				show(assets[name], true)
			else
				task.spawn(function()
					local asset = Compat.ResolveImage(info.Image, window.Folder)
					if asset then
						assets[name] = asset
						if image.Parent then
							show(asset, false)
						end
					end
				end)
			end
		elseif info.Icon then
			local holder = Create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(iconSize, iconSize),
				BackgroundTransparency = 1,
				Parent = slot,
			})
			local label = Icons.Create(info.Icon, holder)
			if label then
				Base.PaintIcon(theme, label, info.IconColor)
			else
				holder:Destroy()
				-- unknown icon: fall back to the letter
				Create("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					Text = string.upper(string.sub(tostring(name), 1, 1)),
					Font = Enum.Font.GothamBlack,
					TextSize = math.max(12, math.floor(slot.Size.Y.Offset * 0.5)),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = theme.Tokens.Muted,
					Parent = slot,
				})
			end
		end
	end

	--// closed-state button ---------------------------------------------------------
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

	local fieldThumb -- small picture of the chosen item (single select)

	--// drawer: search box + grid ---------------------------------------------------
	local searchField, searchBox
	if opts.Searchable ~= false then
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

	local grid = Create("ScrollingFrame", {
		Name = "Grid",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = drawer.Frame,
	})
	Utility.Padding(grid, INSET, INSET, INSET, INSET)
	local layout = Create("UIGridLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellPadding = UDim2.fromOffset(GAP, GAP),
		Parent = grid,
	})

	local function applyGrid()
		-- Offsets are whole pixels: rounding the shared gap up keeps the row from overflowing and wrapping
		local share = math.ceil(GAP * (columns - 1) / columns)
		layout.CellSize = UDim2.new(1 / columns, -share, 0, cellHeight)
	end
	applyGrid()

	--// helpers ----------------------------------------------------------------------
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
		if fieldThumb then
			fieldThumb:Destroy()
			fieldThumb = nil
		end
		if #names == 0 then
			label.Text = opts.Placeholder or "Select..."
			label.TextTransparency = 0.45
		else
			label.Text = table.concat(names, ", ")
			label.TextTransparency = 0
			local info = not multi and #names == 1 and meta[names[1]] or nil
			if info and (info.Image or info.Icon) then
				fieldThumb = Create("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 6, 0.5, 0),
					Size = UDim2.fromOffset(20, 20),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Parent = field,
				})
				Utility.Corner(fieldThumb, 5)
				paintThumb(names[1], fieldThumb, 5, 14)
			end
		end
		local left = fieldThumb and 32 or 10
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

	local function paintCell(cell, hovered)
		local on = isSelected(cell.Name)
		local tokens = theme.Tokens
		cell.Frame.BackgroundTransparency = on and 0.82 or (hovered and 0.9 or 0.95)
		cell.Badge.Visible = on
		cell.Stroke.Color = on and tokens.Accent or tokens.Stroke
		cell.Stroke.Transparency = on and 0.2 or (hovered and 0.7 or tokens.StrokeAlpha)
		cell.Stroke.Thickness = on and 1.5 or 1
	end

	local function clearCells()
		for _, cell in ipairs(cells) do
			cell.Frame:Destroy()
		end
		cells = {}
	end

	local choose

	local function rebuild()
		clearCells()
		local shown = 0
		for _, name in ipairs(values) do
			if query == "" or string.find(string.lower(tostring(name)), query, 1, true) then
				shown = shown + 1
				local button = Create("TextButton", {
					Name = tostring(name),
					BackgroundColor3 = WHITE,
					BackgroundTransparency = 0.95,
					LayoutOrder = shown,
					Parent = grid,
				})
				Utility.Corner(button, 10)
				local stroke = Utility.Stroke(button, WHITE, 0.9, 1)

				local titleSpace = showTitles and TITLE_HEIGHT or 0
				local thumbHeight = cellHeight - 10 - titleSpace
				local thumb = Create("Frame", {
					Name = "Thumb",
					Position = UDim2.fromOffset(5, 5),
					Size = UDim2.new(1, -10, 0, thumbHeight),
					BackgroundColor3 = Color3.new(0, 0, 0),
					ClipsDescendants = true,
					Parent = button,
				})
				Utility.Corner(thumb, 7)
				theme:Bind(thumb, { BackgroundColor3 = "Field", BackgroundTransparency = "FieldAlpha" })
				paintThumb(name, thumb, 7, 30)

				if showTitles then
					local text = Create("TextLabel", {
						Position = UDim2.new(0, 6, 0, cellHeight - TITLE_HEIGHT - 2),
						Size = UDim2.new(1, -12, 0, TITLE_HEIGHT),
						Text = tostring(name),
						Font = Utility.Fonts.Label,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Parent = button,
					})
					theme:Bind(text, { TextColor3 = "Text" })
				end

				-- check badge in the corner of the picture while selected
				local badge = Create("Frame", {
					Name = "Badge",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -9, 0, 9),
					Size = UDim2.fromOffset(18, 18),
					BackgroundColor3 = WHITE,
					Visible = false,
					Parent = button,
				})
				Utility.Corner(badge, Utility.Pill)
				theme:Bind(badge, { BackgroundColor3 = "Accent" })
				local check = Icons.Check(badge, 12, 2)
				check.AnchorPoint = Vector2.new(0.5, 0.5)
				check.Position = UDim2.fromScale(0.5, 0.5)
				Icons.Bind(theme, check, "OnAccent")

				local cell = { Frame = button, Stroke = stroke, Badge = badge, Name = name }
				table.insert(cells, cell)
				paintCell(cell, false)

				button.MouseEnter:Connect(function()
					paintCell(cell, true)
				end)
				button.MouseLeave:Connect(function()
					paintCell(cell, false)
				end)
				button.MouseButton1Click:Connect(function()
					choose(name)
				end)
			end
		end

		local rows = math.ceil(shown / columns)
		local height = rows * cellHeight + math.max(rows - 1, 0) * GAP + INSET * 2
		grid.Size = UDim2.new(1, 0, 0, math.min(height, maxHeight))
		grid.Visible = shown > 0
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

	--// public api -------------------------------------------------------------------
	local function load(value)
		selected = {}
		if multi then
			for _, name in ipairs(type(value) == "table" and value or {}) do
				selected[name] = true
			end
		elseif value ~= nil and type(value) ~= "table" then
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
		assets = {}
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

	-- { Columns, CellHeight, MaxHeight }: only the fields you pass change
	function el:SetGrid(options)
		options = options or {}
		if options.Columns then
			columns = math.max(1, math.floor(options.Columns))
		end
		cellHeight = options.CellHeight or cellHeight
		maxHeight = options.MaxHeight or maxHeight
		applyGrid()
		repaint()
		if drawer.Open then
			drawer:Update(false)
		end
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

	-- borders and the selection color are painted by hand, so they follow the theme through this listener
	el.Maid:Give(theme:OnChange(function()
		for _, cell in ipairs(cells) do
			paintCell(cell, false)
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
	el.Cells = function()
		return cells
	end
	el.GridLayout = layout
	el.GridFrame = grid

	return Base.Finish(container, el, opts, "GridDropdown")
end
