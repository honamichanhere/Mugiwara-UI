--// Base: shared building blocks for every element (glass card, gradient helper,
--// expandable drawer, flag registration).

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Icons = Import("core/Icons")

local Create, Tween = Utility.Create, Utility.Tween
local WHITE = Color3.new(1, 1, 1)

local Base = {}

--// Element: common methods every control inherits ---------------------------
local Element = {}
Element.__index = Element

function Element:SetTitle(text)
	self.TitleLabel.Text = text or ""
	self.TitleLabel.Visible = text ~= nil and text ~= ""
	if self.TitleLabel.Visible then
		self.Top.Visible = true
	end
end

function Element:SetDesc(text)
	self.DescLabel.Text = text or ""
	self.DescLabel.Visible = text ~= nil and text ~= ""
	if self.DescLabel.Visible then
		self.Top.Visible = true
	end
end

-- icon: asset id or icon-set name ("lucide:house"); nil removes it. Returns false when it was not found.
function Element:SetIcon(icon)
	return self._applyIcon(icon)
end

-- color: a Color3, a theme token name ("Accent", "Success", "Danger"...) or nil for the theme accent
function Element:SetIconColor(color)
	return self._applyIcon(self._icon, color or false)
end

function Element:SetVisible(visible)
	self.Frame.Visible = visible
end

function Element:Lock(state)
	self.Locked = state ~= false
	self.LockOverlay.Visible = self.Locked
end

function Element:Unlock()
	self:Lock(false)
end

function Element:Get()
	return self.Value
end

function Element:Destroy()
	if self.Flag then
		self.Window.Flags[self.Flag] = nil
	end
	self.Maid:Clean()
	self.Frame:Destroy()
end

--// Gradient bound to the theme -------------------------------------------------
-- kind: "GradientSeq" (default, static) or "CycleSeq" (seamless when rotating)
function Base.Gradient(theme, parent, rotation, kind)
	local gradient = Create("UIGradient", { Rotation = rotation or 0, Parent = parent })
	theme:Bind(gradient, { Color = kind or "GradientSeq" })
	return gradient
end

-- Colors an icon image: a Color3 stays fixed, a token name ("Success") follows the theme, nil = theme accent.
function Base.PaintIcon(theme, label, color)
	if typeof(color) == "Color3" then
		Icons.Tint(label, color)
	elseif type(color) == "string" and theme.Tokens[color] ~= nil then
		Icons.BindImage(theme, label, color)
	else
		Icons.BindImage(theme, label, "Accent")
	end
end

-- Dark inset field used by inputs, dropdown buttons and so on.
function Base.Field(theme, parent, size, position)
	local field = Create("Frame", {
		Size = size or UDim2.fromScale(1, 1),
		Position = position or UDim2.new(),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Parent = parent,
	})
	Utility.Corner(field, 8)
	local stroke = Utility.Stroke(field, WHITE, 0.9, 1)
	theme:Bind(field, { BackgroundColor3 = "Field", BackgroundTransparency = "FieldAlpha" })
	theme:Bind(stroke, { Color = "Stroke", Transparency = "StrokeAlpha" })
	return field, stroke
end

--// Card -------------------------------------------------------------------------
-- Builds the glass row every element lives in. `rightWidth`/`rightHeight` reserve a
-- control slot on the right (el.Right); pass nil for text-only rows.
function Base.Card(container, opts, rightWidth, rightHeight)
	opts = opts or {}
	local window = container.Window
	local theme = window.Theme

	local el = setmetatable({
		Container = container,
		Window = window,
		Options = opts,
		Maid = Utility.Maid.new(),
		Locked = false,
	}, Element)

	local frame = Create("Frame", {
		Name = opts.Title or "Element",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		LayoutOrder = container:NextOrder(),
		Parent = container.Holder,
	})
	Utility.Corner(frame, 10)
	local stroke = Utility.Stroke(frame, WHITE, 0.9, 1)
	theme:Bind(frame, { BackgroundColor3 = "Card", BackgroundTransparency = "CardAlpha" })
	theme:Bind(stroke, { Color = "Stroke", Transparency = "StrokeAlpha" })

	-- Optional card background image (opts.Image = asset id / rbxassetid / http URL).
	-- It fades in from the right so the title on the left stays readable.
	if opts.Image then
		local image = Create("ImageLabel", {
			Name = "Image",
			Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Crop,
			ImageTransparency = 1,
			Visible = false,
			Parent = frame,
		})
		Utility.Corner(image, 10)
		Create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 0.75),
				NumberSequenceKeypoint.new(1, 0.05),
			}),
			Parent = image,
		})
		task.spawn(function()
			local asset = Compat.ResolveImage(opts.Image, window.Folder)
			if asset and image.Parent then
				image.Image = asset
				image.Visible = true
				Tween(image, { ImageTransparency = opts.ImageTransparency or 0.25 }, 0.6)
			end
		end)
	end

	local content = Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Utility.Padding(content, 11, 11, 14, 14)
	Utility.List(content, 0)

	local top = Create("TextButton", {
		Name = "Top",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = content,
	})
	Create("UISizeConstraint", { MinSize = Vector2.new(0, rightHeight or 24), Parent = top })
	Utility.List(top, 10, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)

	local reserved = rightWidth and (rightWidth + 10) or 0
	local info = Create("Frame", {
		Name = "Info",
		Size = UDim2.new(1, -reserved, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = top,
	})
	Utility.List(info, 2)

	local title = Create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = opts.Title or "",
		Font = Utility.Fonts.Title,
		TextSize = 15,
		TextWrapped = true,
		RichText = true,
		Visible = opts.Title ~= nil and opts.Title ~= "",
		LayoutOrder = 1,
		Parent = info,
	})
	theme:Bind(title, { TextColor3 = "Text" })

	local desc = Create("TextLabel", {
		Name = "Desc",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = opts.Desc or "",
		Font = Utility.Fonts.Desc,
		TextSize = 13,
		TextWrapped = true,
		RichText = true,
		Visible = opts.Desc ~= nil and opts.Desc ~= "",
		LayoutOrder = 2,
		Parent = info,
	})
	theme:Bind(desc, { TextColor3 = "SubText" })

	-- optional icon before the title (opts.Icon); the text column shrinks by the icon's width
	local iconHolder, iconLabel
	local iconColor = opts.IconColor
	local function applyIcon(icon, color)
		if color ~= nil then
			iconColor = color or nil -- SetIconColor(nil) passes false: back to the theme accent
		end
		el._icon = icon
		if iconLabel then
			iconLabel:Destroy()
			iconLabel = nil
		end
		if icon ~= nil and icon ~= "" then
			if not iconHolder then
				iconHolder = Create("Frame", {
					Name = "IconHolder",
					Size = UDim2.fromOffset(22, 22),
					BackgroundTransparency = 1,
					LayoutOrder = 0,
					Parent = top,
				})
			end
			iconLabel = Icons.Create(icon, iconHolder)
			if iconLabel then
				Base.PaintIcon(theme, iconLabel, iconColor)
			end
		end
		if iconHolder then
			iconHolder.Visible = iconLabel ~= nil
		end
		info.Size = UDim2.new(1, -(reserved + (iconLabel and 32 or 0)), 0, 0)
		return iconLabel ~= nil or icon == nil or icon == ""
	end
	el._applyIcon = applyIcon
	applyIcon(opts.Icon)

	-- no text, icon or control slot: the header row is hidden so it does not leave an empty strip
	local hasHeader = (opts.Title ~= nil and opts.Title ~= "") or (opts.Desc ~= nil and opts.Desc ~= "") or iconLabel ~= nil or rightWidth ~= nil
	top.Visible = hasHeader

	if rightWidth then
		el.Right = Create("Frame", {
			Name = "Right",
			Size = UDim2.fromOffset(rightWidth, rightHeight or 24),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = top,
		})
	end

	local lock = Create("TextButton", {
		Name = "Lock",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Visible = false,
		ZIndex = 10,
		Parent = frame,
	})
	Utility.Corner(lock, 10)

	el.Frame = frame
	el.Content = content
	el.Top = top
	el.TitleLabel = title
	el.DescLabel = desc
	el.LockOverlay = lock

	el.Maid:Give(top.MouseEnter:Connect(function()
		if not el.Locked then
			Tween(frame, { BackgroundTransparency = theme.Tokens.CardHoverAlpha }, 0.15)
		end
	end))
	el.Maid:Give(top.MouseLeave:Connect(function()
		Tween(frame, { BackgroundTransparency = theme.Tokens.CardAlpha }, 0.2)
	end))

	return el
end

--// Drawers ----------------------------------------------------------------------
-- Fixed-height strip under the title row (slider bar, textarea...).
-- topPad: space above the strip (default 10; pass 0 when the card has no header row)
function Base.Extra(el, height, topPad)
	local pad = topPad == nil and 10 or topPad
	local extra = Create("Frame", {
		Name = "Extra",
		Size = UDim2.new(1, 0, 0, height + pad),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = el.Content,
	})
	Utility.Padding(extra, pad, 0, 0, 0)
	return extra
end

-- Collapsible area under the title row (dropdown list, color picker...).
function Base.Expandable(el)
	local extra = Create("Frame", {
		Name = "Drawer",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = el.Content,
	})
	Utility.Padding(extra, 10, 0, 0, 0)
	local layout = Utility.List(extra, 8)

	local drawer = { Frame = extra, Layout = layout, Open = false }

	-- Sums the children's fixed pixel heights instead of reading AbsoluteContentSize,
	-- which is reported in screen pixels and drifts when the window is scaled down.
	local function contentHeight()
		local total, count = 0, 0
		for _, child in ipairs(extra:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				total = total + child.Size.Y.Offset
				count = count + 1
			end
		end
		return total + math.max(count - 1, 0) * layout.Padding.Offset
	end

	function drawer:Update(animate)
		local height = 0
		if self.Open then
			height = contentHeight() + 10
		end
		local size = UDim2.new(1, 0, 0, height)
		if animate == false then
			extra.Size = size
		else
			Tween(extra, { Size = size }, 0.28)
		end
	end

	function drawer:Set(open, animate)
		self.Open = open
		self:Update(animate)
	end

	function drawer:Toggle()
		self:Set(not self.Open)
	end

	el.Maid:Give(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if drawer.Open then
			drawer:Update(false)
		end
	end))

	return drawer
end

--// Registration -----------------------------------------------------------------
-- Call last in every element constructor.
function Base.Finish(container, el, opts, kind)
	el.Type = kind
	if opts.Flag then
		el.Flag = opts.Flag
		container.Window.Flags[opts.Flag] = el
	end
	if opts.Locked then
		el:Lock(true)
	end
	table.insert(container.Elements, el)
	return el
end

return Base
