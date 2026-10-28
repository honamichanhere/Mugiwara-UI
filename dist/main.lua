-- Mugiwara UI v0.2.1
-- Glass + neon Gear 5 UI library for Roblox script hubs.
-- https://github.com/honamichanhere/Mugiwara-UI  |  MIT License

local __modules, __cache = {}, {}

local function Import(name)
	local cached = __cache[name]
	if cached then
		return cached.Value
	end
	local factory = __modules[name]
	if not factory then
		error("MugiwaraUI: missing module " .. tostring(name), 2)
	end
	local value = factory(Import)
	__cache[name] = { Value = value }
	return value
end

__modules["components/Base"] = function(Import)
--// Base: shared building blocks for every element (glass card, gradient helper,
--// expandable drawer, flag registration).

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")

local Create, Tween = Utility.Create, Utility.Tween
local WHITE = Color3.new(1, 1, 1)

local Base = {}

--// Element: common methods every control inherits ---------------------------
local Element = {}
Element.__index = Element

function Element:SetTitle(text)
	self.TitleLabel.Text = text or ""
	self.TitleLabel.Visible = text ~= nil and text ~= ""
end

function Element:SetDesc(text)
	self.DescLabel.Text = text or ""
	self.DescLabel.Visible = text ~= nil and text ~= ""
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
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
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
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		RichText = true,
		Visible = opts.Desc ~= nil and opts.Desc ~= "",
		LayoutOrder = 2,
		Parent = info,
	})
	theme:Bind(desc, { TextColor3 = "SubText" })

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
function Base.Extra(el, height)
	local extra = Create("Frame", {
		Name = "Extra",
		Size = UDim2.new(1, 0, 0, height + 10),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = el.Content,
	})
	Utility.Padding(extra, 10, 0, 0, 0)
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
end

__modules["components/Container"] = function(Import)
--// Container: anything that can hold elements (Tab pages and Sections). Elements are
--// created through methods so scripts read `tab:Toggle({ ... })`.

local Utility = Import("core/Utility")
local Icons = Import("core/Icons")
local Base = Import("components/Base")
local Button = Import("components/elements/Button")
local Toggle = Import("components/elements/Toggle")
local Slider = Import("components/elements/Slider")
local Dropdown = Import("components/elements/Dropdown")
local Input = Import("components/elements/Input")
local Keybind = Import("components/elements/Keybind")
local Colorpicker = Import("components/elements/Colorpicker")
local Text = Import("components/elements/Text")

local Create, Tween = Utility.Create, Utility.Tween

local Container = {}
Container.__index = Container

-- tab -> section -> section is the deepest allowed layout ("double section")
Container.MaxSectionDepth = 2

function Container.new(window, holder, page, depth)
	return setmetatable({
		Window = window,
		Holder = holder,
		Page = page,
		Depth = depth or 0, -- how many sections deep this container is
		Elements = {},
		_order = 0,
	}, Container)
end

function Container:NextOrder()
	self._order = self._order + 1
	return self._order
end

function Container:Button(opts)
	return Button(self, opts)
end

function Container:Toggle(opts)
	return Toggle(self, opts)
end

function Container:Slider(opts)
	return Slider(self, opts)
end

function Container:Dropdown(opts)
	return Dropdown(self, opts)
end

function Container:Input(opts)
	return Input(self, opts)
end

function Container:Keybind(opts)
	return Keybind(self, opts)
end

function Container:Colorpicker(opts)
	return Colorpicker(self, opts)
end
Container.ColorPicker = Container.Colorpicker

function Container:Label(opts)
	return Text.Label(self, opts)
end

function Container:Paragraph(opts)
	return Text.Paragraph(self, opts)
end

function Container:Divider(opts)
	return Text.Divider(self, opts)
end

-- Collapsible group. Returns another Container, so sections can hold any element.
function Container:Section(opts)
	opts = opts or {}
	if self.Depth >= Container.MaxSectionDepth then
		error("MugiwaraUI: sections can only be nested " .. Container.MaxSectionDepth .. " levels deep (section > section)", 2)
	end
	local window = self.Window
	local theme = window.Theme

	local wrap = Create("Frame", {
		Name = opts.Title or "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = self:NextOrder(),
		Parent = self.Holder,
	})
	Utility.Corner(wrap, 12)
	local stroke = Utility.Stroke(wrap, Color3.new(1, 1, 1), 0.9, 1)
	theme:Bind(wrap, {
		BackgroundColor3 = "Card",
		BackgroundTransparency = function(tokens)
			return math.min(1, tokens.CardAlpha + 0.03)
		end,
	})
	theme:Bind(stroke, { Color = "Stroke", Transparency = "StrokeAlpha" })

	local inner = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = wrap,
	})
	Utility.List(inner, 0)

	local header = Create("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 42),
		LayoutOrder = 1,
		Parent = inner,
	})
	local title = Create("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Text = opts.Title or "Section",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	Base.Gradient(theme, title, 0)

	local chevron = Icons.Chevron(header, 12, 2)
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Position = UDim2.new(1, -24, 0.5, 0)
	Icons.Bind(theme, chevron, "SubText")

	local body = Create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = inner,
	})
	local bodyInner = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	})
	Utility.Padding(bodyInner, 2, 12, 10, 10)
	Utility.List(bodyInner, 8)

	local section = Container.new(window, bodyInner, self.Page, self.Depth + 1)
	section.Frame = wrap
	section.Open = opts.Opened ~= false

	local function bodyHeight()
		return bodyInner.AbsoluteSize.Y / window.UIScale.Scale
	end

	local function update(animate)
		local height = section.Open and bodyHeight() or 0
		local size = UDim2.new(1, 0, 0, height)
		if animate then
			Tween(body, { Size = size }, 0.28)
		else
			body.Size = size
		end
		Tween(chevron, { Rotation = section.Open and 0 or -90 }, 0.25)
	end

	function section:SetOpen(open)
		self.Open = open
		update(true)
	end

	-- not named Toggle: that is the element constructor inherited from Container
	function section:ToggleOpen()
		self:SetOpen(not self.Open)
	end

	function section:SetTitle(text)
		title.Text = text
	end

	function section:Destroy()
		wrap:Destroy()
	end

	bodyInner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if section.Open then
			body.Size = UDim2.new(1, 0, 0, bodyHeight())
		end
	end)
	header.MouseButton1Click:Connect(function()
		section:ToggleOpen()
	end)

	chevron.Rotation = section.Open and 0 or -90
	update(false)
	table.insert(self.Elements, section)
	return section
end

return Container
end

__modules["components/Dialog"] = function(Import)
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

	-- CanvasGroup so the title, text and buttons fade together with the card
	local card = Create("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 330, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(0, 0, 0),
		GroupTransparency = 1,
		Active = true,
		ZIndex = 51,
		Parent = overlay,
	})
	Utility.Corner(card, 14)
	theme:Bind(card, { BackgroundColor3 = "Popup", BackgroundTransparency = "PopupAlpha" })
	-- not covered by GroupTransparency (it sits on the CanvasGroup itself): tweened by hand
	local outline = Utility.Stroke(card, Color3.new(1, 1, 1), 1, 1.4)
	Base.Gradient(theme, outline, 45)
	Utility.Padding(card, 18, 18, 18, 18)
	Utility.List(card, 10)

	local pop = Create("UIScale", { Scale = 0.9, Parent = card })
	Tween(pop, { Scale = 1 }, 0.4, Enum.EasingStyle.Quint)
	Tween(card, { GroupTransparency = 0 }, 0.25)
	Tween(outline, { Transparency = 0.3 }, 0.25)

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
		if self.Closed then
			return
		end
		self.Closed = true
		Tween(pop, { Scale = 0.93 }, 0.2)
		Tween(card, { GroupTransparency = 1 }, 0.2)
		Tween(outline, { Transparency = 1 }, 0.2)
		Tween(overlay, { BackgroundTransparency = 1 }, 0.2)
		task.delay(0.22, function()
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
end

__modules["components/Notification"] = function(Import)
--// Notifications: glass toasts stacked at the bottom-right of the screen.

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

local Notification = {}

local MAX_VISIBLE = 6
local WIDTH = 300

local function getHolder(library)
	if library._notifyHolder and library._notifyHolder.Parent then
		return library._notifyHolder
	end

	local gui = Create("ScreenGui", {
		Name = "MugiwaraUI_Notifications",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10001,
	})
	Compat.Protect(gui)
	gui.Parent = Compat.GetGuiParent()

	local holder = Create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, WIDTH, 1, -32),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Utility.List(holder, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)

	library._notifyGui = gui
	library._notifyHolder = holder
	library._notifyCount = 0
	return holder
end

-- opts: Title, Content, Duration (seconds, 0 = sticky), Type ("info" | "success" | "warning" | "error")
function Notification.Notify(library, opts)
	opts = opts or {}
	local theme = library.Theme
	local holder = getHolder(library)
	local duration = opts.Duration or 4
	local kind = string.lower(opts.Type or "info")

	library._notifyCount = library._notifyCount + 1

	local wrapper = Create("Frame", {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		LayoutOrder = library._notifyCount,
		Parent = holder,
	})

	local card = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromScale(1.15, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Parent = wrapper,
	})
	Utility.Corner(card, 12)
	theme:Bind(card, { BackgroundColor3 = "Popup", BackgroundTransparency = "PopupAlpha" })

	local outline = Utility.Stroke(card, Color3.new(1, 1, 1), 0.35, 1.2)
	Base.Gradient(theme, outline, 45)

	local stripe = Create("Frame", {
		Size = UDim2.new(0, 3, 1, -20),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = card,
	})
	Utility.Corner(stripe, Utility.Pill)
	if kind == "success" then
		theme:Bind(stripe, { BackgroundColor3 = "Success" })
	elseif kind == "warning" then
		theme:Bind(stripe, { BackgroundColor3 = "Warning" })
	elseif kind == "error" then
		theme:Bind(stripe, { BackgroundColor3 = "Danger" })
	else
		Base.Gradient(theme, stripe, 90)
	end

	local body = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	})
	Utility.Padding(body, 12, 12, 26, 14)
	Utility.List(body, 4)

	local title = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = opts.Title or "Notification",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextWrapped = true,
		LayoutOrder = 1,
		Parent = body,
	})
	theme:Bind(title, { TextColor3 = "Text" })

	if opts.Content and opts.Content ~= "" then
		local content = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Content,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextWrapped = true,
			RichText = true,
			LayoutOrder = 2,
			Parent = body,
		})
		theme:Bind(content, { TextColor3 = "SubText" })
	end

	local progress
	if duration > 0 then
		local track = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = body,
		})
		progress = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = track,
		})
		Utility.Corner(progress, Utility.Pill)
		Base.Gradient(theme, progress, 0)
	end

	local clicker = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })

	-- Oldest toasts leave first when the stack is full.
	local visible = {}
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(visible, child)
		end
	end
	table.sort(visible, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #visible - MAX_VISIBLE do
		visible[index]:Destroy()
	end

	Tween(card, { Position = UDim2.fromScale(0, 0) }, 0.45, Enum.EasingStyle.Back)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		if not wrapper.Parent then
			return
		end
		Tween(card, { Position = UDim2.fromScale(1.15, 0) }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.28, function()
			if not wrapper.Parent then
				return
			end
			local height = wrapper.AbsoluteSize.Y
			wrapper.AutomaticSize = Enum.AutomaticSize.None
			wrapper.ClipsDescendants = true
			wrapper.Size = UDim2.new(1, 0, 0, height)
			Tween(wrapper, { Size = UDim2.new(1, 0, 0, 0) }, 0.2)
			task.delay(0.22, function()
				wrapper:Destroy()
			end)
		end)
	end

	clicker.MouseButton1Click:Connect(close)

	if progress then
		Tween(progress, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)
		task.delay(duration, close)
	end

	return { Close = close }
end

return Notification
end

__modules["components/Popup"] = function(Import)
--// Popup: floating card drawn over the window (color picker, theme menu).
--// Clicking outside closes it. Only one popup is open at a time.

local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

-- opts: Width, Dim (default true), AnchorPoint, Position, OnClose
return function(window, opts)
	opts = opts or {}
	local theme = window.Theme

	if window.ActivePopup then
		window.ActivePopup:Close(true)
	end

	local overlay = Create("TextButton", {
		Name = "Popup",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 60,
		Parent = window.Frame,
	})
	local dim = opts.Dim ~= false
	if dim then
		Tween(overlay, { BackgroundTransparency = 0.5 }, 0.25)
	end

	-- the card is anchored where it should grow from, so the UIScale pop is centered on it
	local card = Create("CanvasGroup", {
		Name = "Card",
		AnchorPoint = opts.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = opts.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, opts.Width or 280, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(0, 0, 0),
		GroupTransparency = 1,
		Active = true,
		ZIndex = 61,
		Parent = overlay,
	})
	Utility.Corner(card, 14)
	theme:Bind(card, { BackgroundColor3 = "Popup", BackgroundTransparency = "PopupAlpha" })
	-- A UIStroke on the CanvasGroup itself is NOT covered by GroupTransparency,
	-- so its transparency is tweened by hand together with the group.
	local outline = Utility.Stroke(card, Color3.new(1, 1, 1), 1, 1.4)
	Base.Gradient(theme, outline, 45)
	Utility.Padding(card, 14, 14, 14, 14)
	Utility.List(card, 10)

	local pop = Create("UIScale", { Scale = 0.94, Parent = card })
	Tween(pop, { Scale = 1 }, 0.35, Enum.EasingStyle.Quint)
	Tween(card, { GroupTransparency = 0 }, 0.25)
	Tween(outline, { Transparency = 0.3 }, 0.25)

	local popup = { Card = card, Overlay = overlay, Closed = false }

	function popup:Close(instant)
		if self.Closed then
			return
		end
		self.Closed = true
		if window.ActivePopup == self then
			window.ActivePopup = nil
		end
		if instant then
			overlay:Destroy()
		else
			-- every part runs for the same time so nothing lingers after the fade ends
			Tween(pop, { Scale = 0.95 }, 0.2)
			Tween(card, { GroupTransparency = 1 }, 0.2)
			Tween(outline, { Transparency = 1 }, 0.2)
			Tween(overlay, { BackgroundTransparency = 1 }, 0.2)
			task.delay(0.22, function()
				overlay:Destroy()
			end)
		end
		Utility.SafeCall(opts.OnClose)
	end

	overlay.MouseButton1Click:Connect(function()
		popup:Close()
	end)

	window.ActivePopup = popup
	return popup
end
end

__modules["components/Tab"] = function(Import)
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
	local image = Icons.Resolve(opts.Icon)
	local iconImage, iconLetter
	if image then
		iconImage = Create("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			Image = image,
			ImageColor3 = theme.Tokens.SubText,
			Parent = iconBox,
		})
	else
		iconLetter = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(string.sub(name, 1, 1)),
			Font = Enum.Font.GothamBlack,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = theme.Tokens.SubText,
			Parent = iconBox,
		})
	end

	local label = Create("TextLabel", {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -52, 1, 0),
		Text = name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
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

		Tween(background, { BackgroundTransparency = state and 0.8 or 1 }, 0.25)
		Tween(indicator, { Size = UDim2.fromOffset(3, state and 18 or 0) }, 0.3, Enum.EasingStyle.Back)
		Tween(label, { TextColor3 = tint }, 0.2)
		if iconImage then
			Tween(iconImage, { ImageColor3 = tint }, 0.2)
		else
			Tween(iconLetter, { TextColor3 = tint }, 0.2)
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
		if iconImage then
			iconImage.ImageColor3 = tint
		else
			iconLetter.TextColor3 = tint
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

	function self:Destroy()
		stopListening()
		button:Destroy()
		page:Destroy()
		window:_removeTab(self)
	end

	return self
end
end

__modules["components/TabSection"] = function(Import)
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
end

__modules["components/Window"] = function(Import)
--// Window: glass shell with a neon rotating border, topbar, tab sidebar and page area.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Icons = Import("core/Icons")
local Config = Import("core/Config")
local Theme = Import("core/Theme")
local Base = Import("components/Base")
local Tab = Import("components/Tab")
local TabSection = Import("components/TabSection")
local Dialog = Import("components/Dialog")
local Popup = Import("components/Popup")

local Create, Tween = Utility.Create, Utility.Tween
local WHITE = Color3.new(1, 1, 1)

local TOPBAR = 54
local FOOTER = 56
local MARGIN = 24 -- breathing room kept around a maximized window
local MORPH_TIME = 0.45

-- Concentric strokes around the window fake a soft neon glow without any image asset.
local NEON_LAYERS = {
	{ pad = 0, thickness = 3, transparency = 0.5 },
	{ pad = 3, thickness = 7, transparency = 0.8 },
	{ pad = 10, thickness = 14, transparency = 0.92 },
}

local Window = {}
Window.__index = Window

local function toVector(size, fallback)
	if typeof(size) == "UDim2" then
		return Vector2.new(size.X.Offset, size.Y.Offset)
	end
	if typeof(size) == "Vector2" then
		return size
	end
	return fallback
end

local function spin(maid, gradient, seconds)
	local tween = TweenService:Create(
		gradient,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{ Rotation = gradient.Rotation + 360 }
	)
	tween:Play()
	maid:Give(function()
		tween:Cancel()
	end)
end

-- opts: Title, Subtitle, Version, Icon, Size, MinSize, MaxSize, Resizable, Folder, ToggleKey, Blur,
--       Neon, OpenButton, ConfirmClose, ShowUser, SideBarWidth, ThemeSwitcher, Background
function Window.new(library, opts)
	opts = opts or {}
	local theme = library.Theme

	local self = setmetatable({}, Window)
	self.Library = library
	self.Theme = theme
	self.Maid = Utility.Maid.new()
	self.Tabs = {}
	self.Flags = {}
	self.Folder = opts.Folder or "MugiwaraUI"
	self.Title = opts.Title or "Mugiwara UI"
	self.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
	self.Opened = false
	self.Maximized = false
	self.UserScale = 1
	self._tabOrder = 0
	self.OnDestroy = opts.OnDestroy

	local maid = self.Maid
	local size = toVector(opts.Size, Vector2.new(640, 430))
	local minSize = toVector(opts.MinSize, Vector2.new(470, 320))
	local maxSize = toVector(opts.MaxSize, Vector2.new(1000, 760))
	local sidebarWidth = opts.SideBarWidth or (Compat.IsMobile and 150 or 176)

	--// root gui
	local gui = Create("ScreenGui", {
		Name = "MugiwaraUI_" .. string.sub(HttpService:GenerateGUID(false), 1, 8),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10000,
	})
	Compat.Protect(gui)
	gui.Parent = Compat.GetGuiParent()
	maid:Give(gui)
	self.Gui = gui

	local main = Create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	self.Main = main
	self.UIScale = Create("UIScale", { Parent = main })

	-- Everything lives in `pop`. It is anchored at its center: UIScale scales around the
	-- anchor point, so a top-left anchor made open / close / minimize grow from the corner.
	local pop = Create("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = main,
	})
	self.PopScale = Create("UIScale", { Parent = pop })

	--// neon glow
	self.Neon = {}
	if opts.Neon ~= false then
		for _, layer in ipairs(NEON_LAYERS) do
			local ring = Create("Frame", {
				Name = "Glow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, layer.pad * 2, 1, layer.pad * 2),
				BackgroundTransparency = 1,
				Parent = pop,
			})
			Utility.Corner(ring, 16 + layer.pad)
			local stroke = Utility.Stroke(ring, WHITE, layer.transparency, layer.thickness)
			spin(maid, Base.Gradient(theme, stroke, 0, "CycleSeq"), 9)
			table.insert(self.Neon, { Stroke = stroke, Base = layer.transparency })
		end
	end

	--// glass body (CanvasGroup so the whole window fades as one)
	local win = Create("CanvasGroup", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		GroupTransparency = 1,
		Parent = pop,
	})
	Utility.Corner(win, 16)
	theme:Bind(win, { BackgroundColor3 = "Background", BackgroundTransparency = "BackgroundAlpha" })
	self.Frame = win

	-- optional wallpaper (Window:SetBackground) with a dark scrim to keep text readable
	self.BackgroundImage = Create("ImageLabel", {
		Name = "Wallpaper",
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop,
		ImageTransparency = 1,
		Visible = false,
		Parent = win,
	})
	self.BackgroundScrim = Create("Frame", {
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = win,
	})

	-- one UIGradient per instance: Roblox ignores extra ones, so color + transparency share it
	local wash = Create("Frame", { Name = "Wash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = win })
	Base.Gradient(theme, wash, 35).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.86),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.9),
	})

	local sheen = Create("Frame", { Name = "Sheen", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = win })
	Create("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.92),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(1, 0.97),
		}),
		Parent = sheen,
	})

	--// neon border
	local border = Create("Frame", {
		Name = "Border",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = pop,
	})
	Utility.Corner(border, 16)
	local borderStroke = Utility.Stroke(border, WHITE, 0.3, 1.5)
	spin(maid, Base.Gradient(theme, borderStroke, 0, "CycleSeq"), 9)
	table.insert(self.Neon, { Stroke = borderStroke, Base = 0.3 })

	--// topbar
	local topbar = Create("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, TOPBAR),
		BackgroundTransparency = 1,
		Parent = win,
	})

	local brand = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = WHITE,
		Parent = topbar,
	})
	Utility.Corner(brand, 9)
	local logo = Icons.Resolve(opts.Icon)
	if logo then
		Create("ImageLabel", { Size = UDim2.fromScale(1, 1), Image = logo, Parent = brand })
		brand.BackgroundTransparency = 1
	else
		Base.Gradient(theme, brand, 45)
		local letter = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(string.sub(self.Title, 1, 1)),
			Font = Enum.Font.GothamBlack,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = brand,
		})
		theme:Bind(letter, { TextColor3 = "OnAccent" })
	end

	local hasSubtitle = opts.Subtitle ~= nil or opts.Author ~= nil
	local titleRow = Create("Frame", {
		Name = "TitleRow",
		Position = UDim2.new(0, 56, 0, hasSubtitle and 8 or 0),
		Size = UDim2.new(1, -230, 0, hasSubtitle and 22 or TOPBAR),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = topbar,
	})
	Utility.List(titleRow, 8, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)

	local titleLabel = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = self.Title,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		LayoutOrder = 1,
		Parent = titleRow,
	})
	Base.Gradient(theme, titleLabel, 0)
	self.TitleLabel = titleLabel

	-- version badge next to the title
	local versionPill = Create("Frame", {
		Name = "Version",
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		LayoutOrder = 2,
		Visible = false,
		Parent = titleRow,
	})
	Utility.Corner(versionPill, Utility.Pill)
	Utility.Padding(versionPill, 0, 0, 8, 8)
	Base.Gradient(theme, versionPill, 0)
	local versionLabel = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = versionPill,
	})
	theme:Bind(versionLabel, { TextColor3 = "OnAccent" })
	self.VersionPill = versionPill
	self.VersionLabel = versionLabel

	if hasSubtitle then
		local subtitle = Create("TextLabel", {
			Position = UDim2.new(0, 56, 0, 30),
			Size = UDim2.new(1, -230, 0, 14),
			Text = opts.Subtitle or opts.Author,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = topbar,
		})
		theme:Bind(subtitle, { TextColor3 = "SubText" })
		self.SubtitleLabel = subtitle
	end

	local function hoverFeedback(button, glyphs, tint)
		button.MouseEnter:Connect(function()
			Tween(button, { BackgroundTransparency = 0.88 }, 0.15)
			for _, glyph in ipairs(glyphs) do
				Icons.SetColor(glyph, tint and theme.Tokens[tint] or theme.Tokens.Text)
			end
		end)
		button.MouseLeave:Connect(function()
			Tween(button, { BackgroundTransparency = 1 }, 0.2)
			for _, glyph in ipairs(glyphs) do
				Icons.SetColor(glyph, theme.Tokens.SubText)
			end
		end)
	end

	-- 30x30 hit area; glyphs are centered inside it
	local function controlButton(offset)
		local button = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			Parent = topbar,
		})
		Utility.Corner(button, 9)
		return button
	end

	local closeButton = controlButton(-14)
	local closeGlyph = Icons.Bind(theme, Icons.Close(closeButton, 14, 2), "SubText")
	hoverFeedback(closeButton, { closeGlyph }, "Danger")

	local maximizeButton = controlButton(-50)
	local squareGlyph = Icons.Bind(theme, Icons.Square(maximizeButton, 14, 2), "SubText")
	local restoreGlyph = Icons.Bind(theme, Icons.Restore(maximizeButton, 14, 2), "SubText")
	restoreGlyph.Visible = false
	hoverFeedback(maximizeButton, { squareGlyph, restoreGlyph }, nil)
	self._squareGlyph, self._restoreGlyph = squareGlyph, restoreGlyph

	local minimizeButton = controlButton(-86)
	local minusGlyph = Icons.Bind(theme, Icons.Minus(minimizeButton, 14, 2), "SubText")
	hoverFeedback(minimizeButton, { minusGlyph }, nil)

	local themeButton
	if opts.ThemeSwitcher ~= false then
		themeButton = controlButton(-122)
		local dot = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = WHITE,
			Parent = themeButton,
		})
		Utility.Corner(dot, Utility.Pill)
		Base.Gradient(theme, dot, 45)
		Utility.Stroke(dot, WHITE, 0.55, 1.2)
		themeButton.MouseEnter:Connect(function()
			Tween(themeButton, { BackgroundTransparency = 0.88 }, 0.15)
			Tween(dot, { Size = UDim2.fromOffset(18, 18) }, 0.2, Enum.EasingStyle.Back)
		end)
		themeButton.MouseLeave:Connect(function()
			Tween(themeButton, { BackgroundTransparency = 1 }, 0.2)
			Tween(dot, { Size = UDim2.fromOffset(16, 16) }, 0.2)
		end)
	end

	local topLine = Create("Frame", {
		Position = UDim2.fromOffset(0, TOPBAR),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = WHITE,
		Parent = win,
	})
	Base.Gradient(theme, topLine, 0).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 0.9),
	})

	--// sidebar
	local sidebar = Create("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(0, TOPBAR + 1),
		Size = UDim2.new(0, sidebarWidth, 1, -(TOPBAR + 1)),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Parent = win,
	})
	theme:Bind(sidebar, { BackgroundColor3 = "Sidebar", BackgroundTransparency = "SidebarAlpha" })

	local sideEdge = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = WHITE,
		Parent = sidebar,
	})
	theme:Bind(sideEdge, { BackgroundColor3 = "Stroke", BackgroundTransparency = "StrokeAlpha" })

	local showUser = opts.ShowUser ~= false
	local footerHeight = showUser and FOOTER or 0

	self.TabList = Create("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 1, -footerHeight),
		ScrollBarThickness = 0,
		Parent = sidebar,
	})
	Utility.Padding(self.TabList, 10, 10, 8, 9)
	Utility.List(self.TabList, 4)

	if showUser then
		local footer = Create("Frame", {
			Name = "Footer",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, -1, 0, FOOTER),
			BackgroundTransparency = 1,
			Parent = sidebar,
		})
		local footerLine = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = WHITE,
			Parent = footer,
		})
		theme:Bind(footerLine, { BackgroundColor3 = "Stroke", BackgroundTransparency = "StrokeAlpha" })

		local player = Players.LocalPlayer
		local avatar = Create("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.9,
			Parent = footer,
		})
		Utility.Corner(avatar, Utility.Pill)
		local avatarStroke = Utility.Stroke(avatar, WHITE, 0.3, 1.5)
		Base.Gradient(theme, avatarStroke, 45)

		local display = Create("TextLabel", {
			Position = UDim2.fromOffset(52, 10),
			Size = UDim2.new(1, -60, 0, 18),
			Text = player and player.DisplayName or "Player",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = footer,
		})
		theme:Bind(display, { TextColor3 = "Text" })
		local handle = Create("TextLabel", {
			Position = UDim2.fromOffset(52, 28),
			Size = UDim2.new(1, -60, 0, 16),
			Text = "@" .. (player and player.Name or "player"),
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = footer,
		})
		theme:Bind(handle, { TextColor3 = "SubText" })

		if player then
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(
						player.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size100x100
					)
				end)
				if ok and avatar.Parent then
					avatar.Image = image
				end
			end)
		end
	end

	--// pages
	self.Pages = Create("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(sidebarWidth, TOPBAR + 1),
		Size = UDim2.new(1, -sidebarWidth, 1, -(TOPBAR + 1)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = win,
	})

	--// resize grip
	if opts.Resizable ~= false then
		local grip = Create("TextButton", {
			Name = "Resize",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -3),
			Size = UDim2.fromOffset(22, 22),
			ZIndex = 20,
			Parent = pop,
		})
		for _, spec in ipairs({ { 12, 0 }, { 6, 4 } }) do
			local line = Create("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -4 - spec[2], 1, -4),
				Size = UDim2.fromOffset(spec[1], 2),
				Rotation = -45,
				BackgroundColor3 = WHITE,
				Parent = grip,
			})
			Utility.Corner(line, Utility.Pill)
			theme:Bind(line, { BackgroundColor3 = "Muted" })
		end
		self.Grip = grip

		local startSize, startPosition, startPointer
		Utility.DragInput(grip, maid, function(input)
			startSize = main.Size
			startPosition = main.Position
			startPointer = input.Position
		end, function(position)
			if not startPointer or self.Maximized then
				return
			end
			local scale = self.UIScale.Scale
			local delta = (position - startPointer) / scale
			local width = Utility.Clamp(startSize.X.Offset + delta.X, minSize.X, maxSize.X)
			local height = Utility.Clamp(startSize.Y.Offset + delta.Y, minSize.Y, maxSize.Y)
			main.Size = UDim2.fromOffset(width, height)
			-- keep the top-left corner anchored while the center-anchored frame grows
			main.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + (width - startSize.X.Offset) * scale / 2,
				startPosition.Y.Scale,
				startPosition.Y.Offset + (height - startSize.Y.Offset) * scale / 2
			)
		end, function()
			startPointer = nil
			self:_fit()
		end)
	end

	--// floating open button
	if opts.OpenButton ~= false then
		local button = Create("TextButton", {
			Name = "OpenButton",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 52),
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			Visible = false,
			Parent = gui,
		})
		Utility.Corner(button, Utility.Pill)
		theme:Bind(button, { BackgroundColor3 = "Popup", BackgroundTransparency = "PopupAlpha" })
		local ring = Utility.Stroke(button, WHITE, 0.15, 2)
		spin(maid, Base.Gradient(theme, ring, 0, "CycleSeq"), 6)
		local halo = Utility.Stroke(button, WHITE, 0.7, 6)
		spin(maid, Base.Gradient(theme, halo, 0, "CycleSeq"), 6)

		local mark = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = (opts.OpenButton and opts.OpenButton.Title) or string.upper(string.sub(self.Title, 1, 1)),
			Font = Enum.Font.GothamBlack,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
		Base.Gradient(theme, mark, 45)

		Utility.Draggable(button, button, maid, nil, function()
			self:Open()
		end)
		self.OpenButton = button
	end

	--// wiring
	Utility.Draggable(topbar, main, maid, function()
		return self.UIScale.Scale
	end, nil, function()
		return not self.Maximized
	end)

	maid:Give(closeButton.MouseButton1Click:Connect(function()
		self:RequestClose()
	end))
	maid:Give(minimizeButton.MouseButton1Click:Connect(function()
		self:Close()
	end))
	maid:Give(maximizeButton.MouseButton1Click:Connect(function()
		self:ToggleMaximized()
	end))
	if themeButton then
		maid:Give(themeButton.MouseButton1Click:Connect(function()
			self:OpenThemeMenu()
		end))
	end

	maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and self.ToggleKey and input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end))

	maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end))
	maid:Give(main:GetPropertyChangedSignal("Size"):Connect(function()
		self:_fit()
	end))

	self.ConfirmClose = opts.ConfirmClose ~= false
	self:SetVersion(opts.Version)
	if type(opts.Background) == "table" then
		self:SetBackground(opts.Background.Image, opts.Background.Transparency, opts.Background.Dim)
	elseif opts.Background then
		self:SetBackground(opts.Background)
	end
	self:_fit()
	self:SetBlur(opts.Blur == true)
	library.Windows[self] = true

	self:Open()
	return self
end

--// Layout ------------------------------------------------------------------------
function Window:_area()
	local area = self.Gui.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		local camera = workspace.CurrentCamera
		area = camera and camera.ViewportSize or Vector2.new(1280, 720)
	end
	return area
end

-- Shrinks the window on small screens (phones) so it never overflows the viewport.
function Window:_fitScale(size)
	local area = self:_area()
	local fit = math.min(1, (area.X - MARGIN) / size.X, (area.Y - MARGIN) / size.Y)
	return math.max(fit, 0.4) * self.UserScale
end

function Window:_maximizedSize()
	local area = self:_area()
	return UDim2.fromOffset((area.X - MARGIN) / self.UserScale, (area.Y - MARGIN) / self.UserScale)
end

function Window:_fit()
	if self._morphing then
		return
	end
	if self.Maximized then
		self.UIScale.Scale = self.UserScale
		self.Main.Size = self:_maximizedSize()
		return
	end
	local size = self.Main.Size
	self.UIScale.Scale = self:_fitScale(Vector2.new(size.X.Offset, size.Y.Offset))
end

function Window:SetScale(scale)
	self.UserScale = Utility.Clamp(scale, 0.5, 1.6)
	self:_fit()
end

function Window:NextTabOrder()
	self._tabOrder = self._tabOrder + 1
	return self._tabOrder
end

--// Maximize ------------------------------------------------------------------------
function Window:SetMaximized(state)
	state = state and true or false
	if state == self.Maximized then
		return
	end
	local main = self.Main
	self._morphing = true -- freeze _fit while the size / scale tweens run

	if state then
		self._restore = { Size = main.Size, Position = main.Position }
		self.Maximized = true
		Tween(main, { Size = self:_maximizedSize(), Position = UDim2.fromScale(0.5, 0.5) }, MORPH_TIME)
		Tween(self.UIScale, { Scale = self.UserScale }, MORPH_TIME)
	else
		self.Maximized = false
		local restore = self._restore or { Size = UDim2.fromOffset(640, 430), Position = UDim2.fromScale(0.5, 0.5) }
		Tween(main, { Size = restore.Size, Position = restore.Position }, MORPH_TIME)
		Tween(
			self.UIScale,
			{ Scale = self:_fitScale(Vector2.new(restore.Size.X.Offset, restore.Size.Y.Offset)) },
			MORPH_TIME
		)
	end

	self._squareGlyph.Visible = not state
	self._restoreGlyph.Visible = state
	if self.Grip then
		self.Grip.Visible = not state
	end

	task.delay(MORPH_TIME + 0.05, function()
		self._morphing = false
		if not self.Destroyed then
			self:_fit()
		end
	end)
end

function Window:ToggleMaximized()
	self:SetMaximized(not self.Maximized)
end

--// Visibility --------------------------------------------------------------------
function Window:Open()
	if self.Opened then
		return
	end
	self.Opened = true
	self.Main.Visible = true
	self.PopScale.Scale = 0.9
	Tween(self.PopScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Quint)
	Tween(self.Frame, { GroupTransparency = 0 }, 0.3)
	for _, neon in ipairs(self.Neon) do
		Tween(neon.Stroke, { Transparency = neon.Base }, 0.4)
	end

	if self.OpenButton then
		local button = self.OpenButton
		Tween(button, { Size = UDim2.fromOffset(0, 0) }, 0.18)
		task.delay(0.18, function()
			if self.Opened then
				button.Visible = false
			end
		end)
	end
	self:_syncBlur()
end

function Window:Close()
	if not self.Opened then
		return
	end
	self.Opened = false
	if self.ActivePopup then
		self.ActivePopup:Close(true)
	end
	Tween(self.PopScale, { Scale = 0.92 }, 0.3, Enum.EasingStyle.Quint)
	Tween(self.Frame, { GroupTransparency = 1 }, 0.24)
	for _, neon in ipairs(self.Neon) do
		Tween(neon.Stroke, { Transparency = 1 }, 0.2)
	end
	task.delay(0.3, function()
		if not self.Opened then
			self.Main.Visible = false
		end
	end)

	if self.OpenButton then
		local button = self.OpenButton
		button.Visible = true
		Tween(button, { Size = UDim2.fromOffset(52, 52) }, 0.5, Enum.EasingStyle.Back)
	end
	self:_syncBlur()
end

function Window:Toggle()
	if self.Opened then
		self:Close()
	else
		self:Open()
	end
end

function Window:RequestClose()
	if not self.ConfirmClose then
		self:Destroy()
		return
	end
	self:Dialog({
		Title = "Close " .. self.Title .. "?",
		Content = "The interface will be destroyed. Run the script again to reopen it.",
		Buttons = {
			{ Title = "Cancel", Style = "Secondary" },
			{
				Title = "Close",
				Style = "Danger",
				Callback = function()
					self:Destroy()
				end,
			},
		},
	})
end

function Window:SetToggleKey(key)
	self.ToggleKey = key
end

--// Blur ----------------------------------------------------------------------------
function Window:SetBlur(enabled, size)
	self.BlurEnabled = enabled
	self.BlurSize = size or 14
	self:_syncBlur()
end

function Window:_syncBlur()
	local existing = Lighting:FindFirstChild("MugiwaraBlur")
	if self.BlurEnabled and self.Opened then
		if not existing then
			existing = Create("BlurEffect", { Name = "MugiwaraBlur", Size = 0, Parent = Lighting })
		end
		Tween(existing, { Size = self.BlurSize }, 0.4)
	elseif existing then
		Tween(existing, { Size = 0 }, 0.3)
	end
end

--// Background image ------------------------------------------------------------------
-- image: asset id, "rbxassetid://...", or an http(s) URL (needs request + writefile + getcustomasset).
-- transparency: 0-1, higher = fainter (default 0.55). dim: 0-1 dark scrim over the image (default 0.45).
-- Pass nil / "" to remove it.
function Window:SetBackground(image, transparency, dim)
	local label, scrim = self.BackgroundImage, self.BackgroundScrim
	if image == nil or image == "" then
		label.Visible = false
		scrim.Visible = false
		return
	end
	local target = transparency or 0.55
	local shade = dim or 0.45
	task.spawn(function()
		local asset, reason = Compat.ResolveImage(image, self.Folder)
		if not label.Parent then
			return
		end
		if not asset then
			self:Notify({ Title = "Wallpaper", Content = reason or "Could not load the image.", Type = "warning", Duration = 6 })
			return
		end
		label.Image = asset
		label.Visible = true
		scrim.Visible = true
		Tween(label, { ImageTransparency = target }, 0.6)
		Tween(scrim, { BackgroundTransparency = 1 - shade }, 0.6)

		if Compat.ImageLoaded(label) == false then
			self:Notify({
				Title = "Wallpaper",
				Content = "Roblox could not load this image. It may be private, moderated, or not an Image asset.",
				Type = "warning",
				Duration = 7,
			})
		end
	end)
end

--// Title / version ---------------------------------------------------------------------
function Window:SetTitle(text)
	self.Title = text
	self.TitleLabel.Text = text
end

function Window:SetVersion(text)
	if text == nil or text == "" then
		self.VersionPill.Visible = false
		return
	end
	self.VersionLabel.Text = tostring(text)
	self.VersionPill.Visible = true
end

--// Theme menu ---------------------------------------------------------------------------
function Window:OpenThemeMenu()
	local library = self.Library
	local theme = self.Theme
	local popup = Popup(self, {
		Width = 210,
		Dim = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, TOPBAR - 2),
	})
	local card = popup.Card
	card:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 4)

	local caption = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Text = "THEME",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		LayoutOrder = 0,
		Parent = card,
	})
	theme:Bind(caption, { TextColor3 = "Muted" })

	for index, name in ipairs(library:GetThemes()) do
		local selected = name == library:GetTheme()
		local row = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = selected and 0.86 or 1,
			LayoutOrder = index,
			Parent = card,
		})
		Utility.Corner(row, 9)
		row.MouseEnter:Connect(function()
			if not selected then
				Tween(row, { BackgroundTransparency = 0.93 }, 0.15)
			end
		end)
		row.MouseLeave:Connect(function()
			if not selected then
				Tween(row, { BackgroundTransparency = 1 }, 0.2)
			end
		end)

		local swatch = Create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(38, 12),
			BackgroundColor3 = WHITE,
			Parent = row,
		})
		Utility.Corner(swatch, Utility.Pill)
		Create("UIGradient", { Color = Theme.Preview(name).GradientSeq, Parent = swatch })

		local label = Create("TextLabel", {
			Position = UDim2.fromOffset(58, 0),
			Size = UDim2.new(1, -86, 1, 0),
			Text = name,
			Font = selected and Enum.Font.GothamBold or Enum.Font.GothamMedium,
			TextSize = 13,
			Parent = row,
		})
		theme:Bind(label, { TextColor3 = "Text" })

		if selected then
			local check = Icons.Check(row, 14, 2)
			check.AnchorPoint = Vector2.new(0.5, 0.5)
			check.Position = UDim2.new(1, -18, 0.5, 0)
			Icons.Bind(theme, check, "Text")
		end

		row.MouseButton1Click:Connect(function()
			library:SetTheme(name)
			popup:Close()
		end)
	end
	return popup
end

--// Content ---------------------------------------------------------------------
function Window:_createTab(opts, parent)
	local tab = Tab(self, opts, parent)
	table.insert(self.Tabs, tab)
	if not self.CurrentTab then
		self:SelectTab(tab)
	end
	return tab
end

function Window:Tab(opts)
	return self:_createTab(opts, nil)
end

-- Titled, collapsible group of tabs in the sidebar: Window:TabSection({ Title }):Tab({ ... })
function Window:TabSection(opts)
	return TabSection(self, opts)
end

function Window:_removeTab(tab)
	local index = table.find(self.Tabs, tab)
	if index then
		table.remove(self.Tabs, index)
	end
	if self.CurrentTab == tab then
		self.CurrentTab = nil
		if self.Tabs[1] then
			self:SelectTab(self.Tabs[1])
		end
	end
end

function Window:SelectTab(target)
	if type(target) == "number" then
		target = self.Tabs[target]
	end
	if not target or target == self.CurrentTab then
		return
	end
	local previous = self.CurrentTab
	self.CurrentTab = target
	if previous then
		previous:_setSelected(false)
	end
	target:_setSelected(true)
end

-- Small caption inside the sidebar tab list.
function Window:SidebarLabel(text)
	local label = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		Text = "  " .. string.upper(text),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		LayoutOrder = self:NextTabOrder(),
		Parent = self.TabList,
	})
	self.Theme:Bind(label, { TextColor3 = "Muted" })
	return label
end

function Window:SidebarDivider()
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 9),
		BackgroundTransparency = 1,
		LayoutOrder = self:NextTabOrder(),
		Parent = self.TabList,
	})
	local line = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = WHITE,
		Parent = holder,
	})
	self.Theme:Bind(line, { BackgroundColor3 = "Stroke", BackgroundTransparency = "StrokeAlpha" })
	return holder
end

function Window:Dialog(opts)
	return Dialog(self, opts)
end

function Window:Notify(opts)
	return self.Library:Notify(opts)
end

function Window:SetTheme(name)
	return self.Library:SetTheme(name)
end

--// Config --------------------------------------------------------------------------
function Window:SaveConfig(name)
	return Config.Save(self, name)
end

function Window:LoadConfig(name)
	return Config.Load(self, name)
end

function Window:DeleteConfig(name)
	return Config.Delete(self, name)
end

function Window:GetConfigs()
	return Config.List(self)
end

-- Loads the config marked as auto-load (call after building the whole UI).
function Window:LoadAutoConfig()
	local name = Config.GetAutoLoad(self)
	if name then
		return Config.Load(self, name)
	end
	return false
end

-- Drops a ready-made config manager (name box, list, save/load/delete) into a tab or section.
function Window:ConfigSection(parent, opts)
	opts = opts or {}
	local section = parent:Section({ Title = opts.Title or "Configuration", Opened = opts.Opened ~= false })
	local typed, selected = "", Config.GetAutoLoad(self)
	local dropdown
	local autoToggle

	local function report(ok, message, success)
		self:Notify({
			Title = "Config",
			Content = ok and success or message,
			Type = ok and "success" or "error",
			Duration = 3,
		})
	end

	section:Input({
		Title = "Config name",
		Placeholder = "my-config",
		Callback = function(value)
			typed = value
		end,
	})

	dropdown = section:Dropdown({
		Title = "Saved configs",
		Values = Config.List(self),
		Value = selected,
		Searchable = false,
		AllowNone = true,
		Callback = function(value)
			selected = value
		end,
	})

	section:Button({
		Title = "Save",
		Desc = "Saves under the typed name, or overwrites the selected config.",
		Callback = function()
			local name = typed ~= "" and typed or selected
			local ok, message = Config.Save(self, name or "")
			if ok then
				name = Config.Sanitize(name)
				dropdown:Refresh(Config.List(self), false)
				dropdown:Set(name, true)
				selected = name
			end
			report(ok, message, "Saved \"" .. tostring(name) .. "\"")
		end,
	})

	section:Button({
		Title = "Load",
		Callback = function()
			local ok, message = Config.Load(self, selected or "")
			report(ok, message, "Loaded \"" .. tostring(selected) .. "\"")
		end,
	})

	section:Button({
		Title = "Delete",
		Callback = function()
			if not selected then
				report(false, "Select a config first")
				return
			end
			Config.Delete(self, selected)
			dropdown:Refresh(Config.List(self), false)
			report(true, nil, "Deleted \"" .. selected .. "\"")
			selected = nil
		end,
	})

	autoToggle = section:Toggle({
		Title = "Auto load on execute",
		Desc = "Loads the selected config automatically next time (call window:LoadAutoConfig()).",
		Value = Config.GetAutoLoad(self) ~= nil,
		Callback = function(value)
			if value and not selected then
				autoToggle:Set(false, true)
				report(false, "Select a config first")
				return
			end
			Config.SetAutoLoad(self, value and selected or nil)
		end,
	})

	return section
end

--// Lifecycle ------------------------------------------------------------------------
function Window:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Opened = false
	self.BlurEnabled = false
	self:_syncBlur()
	self.Library.Windows[self] = nil
	Utility.SafeCall(self.OnDestroy)
	self.Maid:Clean()
end

return Window
end

__modules["components/elements/Button"] = function(Import)
local Utility = Import("core/Utility")
local Icons = Import("core/Icons")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local el = Base.Card(container, opts, 34, 26)

	-- centered anchor: the press animation shrinks toward the middle, not the top-left
	local pill = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = el.Right,
	})
	Utility.Corner(pill, 8)
	Base.Gradient(theme, pill, 0)

	local arrow = Icons.Chevron(pill, 14, 2)
	arrow.Rotation = -90
	Icons.Bind(theme, arrow, "OnAccent")

	function el:Fire()
		Tween(pill, { Size = UDim2.new(1, -6, 1, -6) }, 0.08)
		task.delay(0.09, function()
			if pill.Parent then
				Tween(pill, { Size = UDim2.fromScale(1, 1) }, 0.35, Enum.EasingStyle.Back)
			end
		end)
		Utility.SafeCall(opts.Callback)
	end

	function el:SetCallback(fn)
		opts.Callback = fn
	end

	el.Maid:Give(el.Top.MouseButton1Click:Connect(function()
		if not el.Locked then
			el:Fire()
		end
	end))

	return Base.Finish(container, el, opts, "Button")
end
end

__modules["components/elements/Colorpicker"] = function(Import)
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
local SQUARE = 176 -- saturation / value square
local BAR = 18

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

local function marker(parent, size)
	local dot = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	})
	Utility.Corner(dot, Utility.Pill)
	Utility.Stroke(dot, WHITE, 0, 2)
	return dot
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
			ui.HueMarker.Position = UDim2.fromScale(0.5, hue)
			ui.AlphaBar.BackgroundColor3 = color
			ui.AlphaMarker.Position = UDim2.fromScale(0.5, 1 - alpha)
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
		local alphaWidth = 58
		local fieldWidth = math.floor((236 - alphaWidth - 6 * count) / count)

		for index = 1, count do
			local field = Base.Field(theme, row, UDim2.fromOffset(fieldWidth, 28))
			field.LayoutOrder = index
			local box = Create("TextBox", {
				Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
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

		local alphaField = Base.Field(theme, row, UDim2.fromOffset(alphaWidth, 28))
		alphaField.LayoutOrder = 10
		local alphaBox = Create("TextBox", {
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
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
			Width = 264,
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
		local header = Create("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
		local title = Create("TextLabel", {
			Size = UDim2.new(1, -60, 1, 0),
			Text = opts.Title or "Color",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		Base.Gradient(theme, title, 0)

		ui.Preview = Create("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -30, 0.5, 0),
			Size = UDim2.fromOffset(32, 16),
			BackgroundColor3 = current(),
			Parent = header,
		})
		Utility.Corner(ui.Preview, 5)
		Utility.Stroke(ui.Preview, WHITE, 0.6, 1)

		local closeButton = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(22, 22),
			Parent = header,
		})
		local closeGlyph = Icons.Close(closeButton, 12, 2)
		Icons.Bind(theme, closeGlyph, "SubText")
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
		ui.SquareMarker = marker(ui.Square, 14)
		local squareHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = ui.Square })

		local hueBar = Create("Frame", {
			Position = UDim2.fromOffset(SQUARE + 10, 0),
			Size = UDim2.fromOffset(BAR, SQUARE),
			BackgroundColor3 = WHITE,
			Parent = area,
		})
		Utility.Corner(hueBar, Utility.Pill)
		Create("UIGradient", { Rotation = 90, Color = RAINBOW, Parent = hueBar })
		ui.HueMarker = marker(hueBar, 16)
		local hueHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = hueBar })

		ui.AlphaBar = Create("Frame", {
			Position = UDim2.fromOffset(SQUARE + 10 + BAR + 8, 0),
			Size = UDim2.fromOffset(BAR, SQUARE),
			BackgroundColor3 = current(),
			Parent = area,
		})
		Utility.Corner(ui.AlphaBar, Utility.Pill)
		Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.95), Parent = ui.AlphaBar })
		Utility.Stroke(ui.AlphaBar, WHITE, 0.85, 1)
		ui.AlphaMarker = marker(ui.AlphaBar, 16)
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
		local tabs = Create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 3, Parent = card })
		Utility.List(tabs, 4, Enum.FillDirection.Horizontal)
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
				Size = UDim2.new(1 / #MODES, -3, 1, 0),
				LayoutOrder = index,
				Parent = tabs,
			})
			local background = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = button })
			Utility.Corner(background, 7)
			Base.Gradient(theme, background, 0)
			local label = Create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Text = name,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
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
		row = Create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 4, Parent = card })
		Utility.List(row, 6, Enum.FillDirection.Horizontal)

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
end

__modules["components/elements/Dropdown"] = function(Import)
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
		Font = Enum.Font.Gotham,
		TextSize = 12,
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
			Font = Enum.Font.Gotham,
			TextSize = 12,
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
					Font = Enum.Font.Gotham,
					TextSize = 12,
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
end

__modules["components/elements/Input"] = function(Import)
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
		Font = Enum.Font.Gotham,
		TextSize = 12,
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
end

__modules["components/elements/Keybind"] = function(Import)
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
		TextSize = 12,
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
end

__modules["components/elements/Slider"] = function(Import)
local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

-- opts: Title, Desc, Value = { Min, Max, Default }, Step, Suffix, Callback, Flag
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local range = opts.Value or {}
	local min = range.Min or opts.Min or 0
	local max = range.Max or opts.Max or 100
	local step = opts.Step or 1
	local suffix = opts.Suffix or ""
	local decimals = Utility.Decimals(step)

	local el = Base.Card(container, opts, 74, 26)
	local extra = Base.Extra(el, 18)

	--// value box
	local box = Base.Field(theme, el.Right)
	local input = Create("TextBox", {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,
		Parent = box,
	})
	theme:Bind(input, { TextColor3 = "Text" })

	--// bar
	local hit = Create("TextButton", { Size = UDim2.fromScale(1, 1), Parent = extra })
	local rail = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = hit,
	})
	Utility.Corner(rail, Utility.Pill)
	theme:Bind(rail, { BackgroundColor3 = "Track", BackgroundTransparency = "TrackAlpha" })

	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = rail,
	})
	Utility.Corner(fill, Utility.Pill)
	Base.Gradient(theme, fill, 0)
	local halo = Utility.Stroke(fill, Color3.new(1, 1, 1), 0.6, 2)
	Base.Gradient(theme, halo, 0)

	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = rail,
	})
	Utility.Corner(knob, Utility.Pill)
	local knobStroke = Utility.Stroke(knob, Color3.new(1, 1, 1), 0.2, 2)
	Base.Gradient(theme, knobStroke, 0)

	local function format(value)
		return Utility.FormatNumber(value, decimals) .. suffix
	end

	local function render(value, instant)
		local alpha = max == min and 0 or (value - min) / (max - min)
		input.Text = format(value)
		if instant then
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
		else
			Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, 0.1, Enum.EasingStyle.Quad)
			Tween(knob, { Position = UDim2.fromScale(alpha, 0.5) }, 0.1, Enum.EasingStyle.Quad)
		end
	end

	el.Value = Utility.Clamp(range.Default or opts.Default or min, min, max)
	render(el.Value, true)

	-- `instant` is used while dragging: restarting a tween every frame makes the knob lag
	function el:Set(value, silent, instant)
		value = Utility.Clamp(Utility.Snap(value, min, step), min, max)
		local changed = value ~= self.Value
		self.Value = value
		render(value, instant == true)
		if changed and not silent then
			Utility.SafeCall(opts.Callback, value)
		end
	end

	function el:SetRange(newMin, newMax)
		min, max = newMin, newMax
		self:Set(self.Value, true)
	end

	function el:SetCallback(fn)
		opts.Callback = fn
	end

	el.Serialize = function()
		return el.Value
	end
	el.Deserialize = function(value)
		if type(value) == "number" then
			el:Set(value)
		end
	end

	local page = container.Page
	Utility.DragInput(hit, el.Maid, function()
		if page then
			page.ScrollingEnabled = false
		end
	end, function(position)
		local alpha = Utility.Clamp((position.X - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1)
		el:Set(min + (max - min) * alpha, false, true)
	end, function()
		if page then
			page.ScrollingEnabled = true
		end
	end)

	el.Maid:Give(input.FocusLost:Connect(function()
		local typed = tonumber(string.match(input.Text, "-?%d+%.?%d*"))
		if typed then
			el:Set(typed)
		else
			render(el.Value, true)
		end
	end))

	return Base.Finish(container, el, opts, "Slider")
end
end

__modules["components/elements/Text"] = function(Import)
--// Static text rows: Label (title only), Paragraph (title + description), Divider.

local TextService = game:GetService("TextService")

local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create = Utility.Create

local Text = {}

function Text.Label(container, opts)
	if type(opts) == "string" then
		opts = { Title = opts }
	end
	opts = opts or {}
	local el = Base.Card(container, opts)
	el.Top.Active = false
	function el:Set(text)
		self:SetTitle(text)
	end
	return Base.Finish(container, el, opts, "Label")
end

function Text.Paragraph(container, opts)
	opts = opts or {}
	local el = Base.Card(container, opts)
	el.Top.Active = false
	function el:Set(title, desc)
		self:SetTitle(title)
		if desc ~= nil then
			self:SetDesc(desc)
		end
	end
	return Base.Finish(container, el, opts, "Paragraph")
end

-- Divider({ Title = "optional caption" })
function Text.Divider(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme

	local frame = Create("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, opts.Title and 20 or 8),
		BackgroundTransparency = 1,
		LayoutOrder = container:NextOrder(),
		Parent = container.Holder,
	})

	local caption = opts.Title and string.upper(opts.Title) or nil
	local gap = 0
	if caption then
		local bounds = TextService:GetTextSize(caption, 10, Enum.Font.GothamBold, Vector2.new(1000, 20))
		gap = bounds.X + 24
	end

	local function line(anchorX, positionX, sizeX, fadeLeft)
		local piece = Create("Frame", {
			AnchorPoint = Vector2.new(anchorX, 0.5),
			Position = UDim2.new(positionX.Scale, positionX.Offset, 0.5, 0),
			Size = sizeX,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = frame,
		})
		local ends = fadeLeft and { 1, 0.5 } or { 0.5, 1 }
		Base.Gradient(theme, piece, 0).Transparency = NumberSequence.new(ends[1], ends[2])
		return piece
	end

	if caption then
		line(0, UDim.new(0, 0), UDim2.new(0.5, -gap / 2, 0, 1), true)
		line(1, UDim.new(1, 0), UDim2.new(0.5, -gap / 2, 0, 1), false)
		local label = Create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, gap, 1, 0),
			Text = caption,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = frame,
		})
		theme:Bind(label, { TextColor3 = "SubText" })
	else
		line(0, UDim.new(0, 0), UDim2.new(1, 0, 0, 1), true)
	end

	local el = { Frame = frame, Type = "Divider", Maid = Utility.Maid.new(), Window = container.Window }
	function el:SetVisible(visible)
		frame.Visible = visible
	end
	function el:Destroy()
		frame:Destroy()
	end
	table.insert(container.Elements, el)
	return el
end

return Text
end

__modules["components/elements/Toggle"] = function(Import)
local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local el = Base.Card(container, opts, 44, 24)

	local track = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = el.Right,
	})
	Utility.Corner(track, Utility.Pill)
	theme:Bind(track, { BackgroundColor3 = "Track", BackgroundTransparency = "TrackAlpha" })

	local fill = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Parent = track,
	})
	Utility.Corner(fill, Utility.Pill)
	Base.Gradient(theme, fill, 0)

	-- neon halo around the track while on
	local halo = Utility.Stroke(fill, Color3.new(1, 1, 1), 1, 3)
	Base.Gradient(theme, halo, 0)

	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	})
	Utility.Corner(knob, Utility.Pill)

	local function render(value, instant)
		local goals = {
			{ fill, { BackgroundTransparency = value and 0 or 1 } },
			{ halo, { Transparency = value and 0.5 or 1 } },
			{ knob, { Position = UDim2.new(0, value and 23 or 3, 0.5, 0) } },
		}
		for _, entry in ipairs(goals) do
			if instant then
				for property, goal in pairs(entry[2]) do
					entry[1][property] = goal
				end
			else
				Tween(entry[1], entry[2], 0.22, Enum.EasingStyle.Quint)
			end
		end
	end

	el.Value = (opts.Value or opts.Default) == true
	render(el.Value, true)

	function el:Set(value, silent)
		value = value and true or false
		self.Value = value
		render(value, false)
		if not silent then
			Utility.SafeCall(opts.Callback, value)
		end
	end

	function el:Toggle()
		self:Set(not self.Value)
	end

	function el:SetCallback(fn)
		opts.Callback = fn
	end

	el.Serialize = function()
		return el.Value
	end
	el.Deserialize = function(value)
		el:Set(value == true)
	end

	el.Maid:Give(el.Top.MouseButton1Click:Connect(function()
		if not el.Locked then
			el:Toggle()
		end
	end))

	return Base.Finish(container, el, opts, "Toggle")
end
end

__modules["core/Compat"] = function(Import)
--// Executor compatibility layer. Every executor function is optional; each helper
--// degrades gracefully so the UI still works on weak executors (Solara, Xeno, Delta...).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Compat = {}

local function try(fn, ...)
	local ok, result = pcall(fn, ...)
	if ok then
		return result
	end
	return nil
end

Compat.Env = (getgenv and try(getgenv)) or _G

Compat.Executor = (identifyexecutor and try(identifyexecutor)) or "Unknown"

Compat.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function service(name)
	local raw = game:GetService(name)
	if cloneref then
		return try(cloneref, raw) or raw
	end
	return raw
end

Compat.Service = service

--// GUI parent -----------------------------------------------------------------
local function canParentTo(container)
	if not container then
		return false
	end
	return (pcall(function()
		local probe = Instance.new("Folder")
		probe.Parent = container
		probe:Destroy()
	end))
end

function Compat.GetGuiParent()
	if gethui then
		local hui = try(gethui)
		if hui and canParentTo(hui) then
			return hui
		end
	end

	local coreGui = try(service, "CoreGui")
	if coreGui and canParentTo(coreGui) then
		return coreGui
	end

	local player = Players.LocalPlayer
	local playerGui = player and (player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5))
	return playerGui
end

function Compat.Protect(gui)
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	elseif protect_gui then
		pcall(protect_gui, gui)
	end
end

--// Files ---------------------------------------------------------------------
Compat.FilesSupported = (writefile ~= nil and readfile ~= nil and isfile ~= nil and makefolder ~= nil and isfolder ~= nil)

function Compat.EnsureFolder(path)
	if not Compat.FilesSupported then
		return false
	end
	local built = ""
	for part in string.gmatch(path, "[^/\\]+") do
		built = built == "" and part or (built .. "/" .. part)
		if not try(isfolder, built) then
			pcall(makefolder, built)
		end
	end
	return try(isfolder, path) == true
end

function Compat.WriteFile(path, content)
	if not Compat.FilesSupported then
		return false
	end
	return (pcall(writefile, path, content))
end

function Compat.ReadFile(path)
	if not Compat.FilesSupported then
		return nil
	end
	if not try(isfile, path) then
		return nil
	end
	return try(readfile, path)
end

function Compat.FileExists(path)
	return Compat.FilesSupported and try(isfile, path) == true
end

function Compat.DeleteFile(path)
	if delfile and Compat.FileExists(path) then
		return (pcall(delfile, path))
	end
	return false
end

--// Images --------------------------------------------------------------------
local function hashText(text)
	local hash = 5381
	for index = 1, #text do
		hash = (hash * 33 + string.byte(text, index)) % 4294967296
	end
	return string.format("%08x", hash)
end

local ASSET_IMAGE, ASSET_DECAL = 1, 13
local resolvedAssets = {}

-- Roblox Store images are almost always Decal assets, and an ImageLabel cannot show a Decal id
-- (it renders nothing). A Decal wraps the real image, so the image id is read from the Decal.
-- Returns the usable image string, or nil plus the reason it cannot be used.
local function imageFromAssetId(id)
	if resolvedAssets[id] then
		return resolvedAssets[id]
	end

	local assetType
	local ok, info = pcall(function()
		return service("MarketplaceService"):GetProductInfo(id, Enum.InfoType.Asset)
	end)
	if ok and type(info) == "table" then
		assetType = info.AssetTypeId
	end

	local image, reason
	if assetType == ASSET_DECAL then
		-- only Decals are ever loaded as objects, and the result is destroyed right away
		local loaded, objects = pcall(function()
			return game:GetObjects("rbxassetid://" .. id)
		end)
		local root = loaded and objects and objects[1]
		if root then
			local decal = root:IsA("Decal") and root or root:FindFirstChildWhichIsA("Decal", true)
			image = decal and decal.Texture
			pcall(function()
				root:Destroy()
			end)
		end
		if not image or image == "" then
			image = nil
			reason = "Asset " .. id .. " is a Decal and this executor cannot convert it (needs game:GetObjects). Use its Image id instead."
		end
	elseif assetType == nil or assetType == ASSET_IMAGE then
		image = "rbxassetid://" .. id
	else
		reason = "Asset " .. id .. " is not an image (asset type " .. tostring(assetType) .. ")."
	end

	if image then
		resolvedAssets[id] = image
	end
	return image, reason
end

-- Turns an asset id / "rbxassetid://..." / http(s) URL into something an ImageLabel accepts.
-- URLs are downloaded once into <folder>/cache and served through getcustomasset
-- (needs request + writefile + getcustomasset). May yield, so call it from a task.
-- Returns the image, or nil plus a reason.
function Compat.ResolveImage(source, folder)
	if type(source) == "string" then
		source = string.gsub(source, "^%s+", "")
		source = string.gsub(source, "%s+$", "")
	end
	if source == nil or source == "" then
		return nil
	end

	local id = tonumber(source) or tonumber(string.match(tostring(source), "^rbxassetid://(%d+)$"))
	if id then
		return imageFromAssetId(id)
	end
	if type(source) ~= "string" then
		return nil, "Unsupported image value"
	end
	if string.find(source, "^rbxasset") then
		return source
	end

	if string.find(source, "^https?://") then
		local requester = request or http_request or (syn and syn.request)
		local assetOf = getcustomasset or getsynasset
		if not (requester and assetOf and Compat.FilesSupported) then
			return nil, "This executor cannot download URLs (needs request, writefile and getcustomasset)."
		end
		local path = (folder or "MugiwaraUI") .. "/cache/" .. hashText(source) .. ".png"
		if not Compat.FileExists(path) then
			local response = try(requester, { Url = source, Method = "GET" })
			if not (response and response.Body and (response.StatusCode == nil or response.StatusCode == 200)) then
				return nil, "Could not download the image."
			end
			Compat.EnsureFolder((folder or "MugiwaraUI") .. "/cache")
			if not Compat.WriteFile(path, response.Body) then
				return nil, "Could not save the image to the executor folder."
			end
		end
		local asset = try(assetOf, path)
		if not asset then
			return nil, "getcustomasset failed for the downloaded image."
		end
		return asset
	end
	return nil, "Unrecognized image. Use an asset id, rbxassetid://id, or an http(s) URL."
end

-- true / false when Roblox reports the load result, nil when it cannot be checked
function Compat.ImageLoaded(label)
	local ok, status = pcall(function()
		local provider = service("ContentProvider")
		provider:PreloadAsync({ label })
		return provider:GetAssetFetchStatus(label.Image)
	end)
	if not ok or status == nil then
		return nil
	end
	if status == Enum.AssetFetchStatus.Success then
		return true
	elseif status == Enum.AssetFetchStatus.Failure then
		return false
	end
	return nil
end

--// Clipboard -----------------------------------------------------------------
function Compat.SetClipboard(text)
	local setter = setclipboard or toclipboard or (Clipboard and Clipboard.set)
	if setter then
		return (pcall(setter, tostring(text)))
	end
	return false
end

return Compat
end

__modules["core/Config"] = function(Import)
--// Config: saves/loads every flagged element to <Folder>/configs/<name>.json.
--// A small index file is kept so listing works even on executors without listfiles.

local HttpService = game:GetService("HttpService")

local Compat = Import("core/Compat")

local Config = {}

local function root(window)
	return window.Folder .. "/configs"
end

local function indexPath(window)
	return root(window) .. "/_index.json"
end

local function filePath(window, name)
	return root(window) .. "/" .. name .. ".json"
end

function Config.Sanitize(name)
	name = string.gsub(tostring(name or ""), "[^%w%-_ ]", "")
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	return name
end

function Config.List(window)
	local raw = Compat.ReadFile(indexPath(window))
	if not raw then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(decoded) ~= "table" then
		return {}
	end
	local names = {}
	for _, name in ipairs(decoded) do
		if Compat.FileExists(filePath(window, name)) then
			table.insert(names, name)
		end
	end
	return names
end

local function writeIndex(window, names)
	table.sort(names)
	Compat.WriteFile(indexPath(window), HttpService:JSONEncode(names))
end

function Config.Save(window, name)
	name = Config.Sanitize(name)
	if name == "" then
		return false, "Config name is empty"
	end
	if not Compat.FilesSupported then
		return false, "This executor has no file access"
	end

	local data = {}
	for flag, element in pairs(window.Flags) do
		if element.Serialize then
			data[flag] = element.Serialize()
		end
	end

	Compat.EnsureFolder(root(window))
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, { Version = 1, Data = data })
	if not ok then
		return false, "Could not encode config"
	end
	if not Compat.WriteFile(filePath(window, name), encoded) then
		return false, "Could not write file"
	end

	local names = Config.List(window)
	if not table.find(names, name) then
		table.insert(names, name)
	end
	writeIndex(window, names)
	return true
end

function Config.Load(window, name)
	name = Config.Sanitize(name)
	local raw = Compat.ReadFile(filePath(window, name))
	if not raw then
		return false, "Config not found"
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(decoded) ~= "table" or type(decoded.Data) ~= "table" then
		return false, "Config is corrupted"
	end
	for flag, value in pairs(decoded.Data) do
		local element = window.Flags[flag]
		if element and element.Deserialize then
			pcall(element.Deserialize, value)
		end
	end
	return true
end

function Config.Delete(window, name)
	name = Config.Sanitize(name)
	Compat.DeleteFile(filePath(window, name))
	local names = {}
	for _, existing in ipairs(Config.List(window)) do
		if existing ~= name then
			table.insert(names, existing)
		end
	end
	writeIndex(window, names)
	return true
end

function Config.GetAutoLoad(window)
	local raw = Compat.ReadFile(root(window) .. "/_autoload.txt")
	if raw and raw ~= "" then
		return raw
	end
	return nil
end

function Config.SetAutoLoad(window, name)
	Compat.EnsureFolder(root(window))
	Compat.WriteFile(root(window) .. "/_autoload.txt", name and Config.Sanitize(name) or "")
end

return Config
end

__modules["core/Icons"] = function(Import)
--// Icons: asset-id resolver + small glyphs drawn from frames, so core controls
--// (chevron, check, close...) never depend on uploaded images.

local Utility = Import("core/Utility")

local Create = Utility.Create

local Icons = {}
Icons.Registry = {}

local function normalize(icon)
	if type(icon) == "number" then
		return "rbxassetid://" .. icon
	end
	if type(icon) == "string" then
		if string.find(icon, "^rbxasset") then
			return icon
		end
		if tonumber(icon) then
			return "rbxassetid://" .. icon
		end
	end
	return nil
end

-- Icons.Register({ home = "rbxassetid://123", sword = 456 })
function Icons.Register(map)
	for name, id in pairs(map) do
		Icons.Registry[string.lower(name)] = normalize(id)
	end
end

-- Accepts "rbxassetid://id", a number, or a registered name ("lucide:home" / "home").
function Icons.Resolve(icon)
	if icon == nil or icon == "" then
		return nil
	end
	local direct = normalize(icon)
	if direct then
		return direct
	end
	if type(icon) == "string" then
		local key = string.gsub(string.lower(icon), "^%w+:", "")
		return Icons.Registry[key]
	end
	return nil
end

local function bar(parent, length, thickness, rotation, x, y)
	local frame = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(length, thickness),
		Rotation = rotation,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	})
	Utility.Corner(frame, Utility.Pill)
	return frame
end

local function holder(parent, name, size)
	return Create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
end

-- Points down. Rotate the returned holder for other directions.
function Icons.Chevron(parent, size, thickness)
	local root = holder(parent, "Chevron", size)
	local length = size * 0.56
	bar(root, length, thickness or 2, 45, 0.31, 0.5)
	bar(root, length, thickness or 2, -45, 0.69, 0.5)
	return root
end

function Icons.Check(parent, size, thickness)
	local root = holder(parent, "Check", size)
	bar(root, size * 0.34, thickness or 2, 42, 0.3, 0.63)
	bar(root, size * 0.64, thickness or 2, -48, 0.63, 0.51)
	return root
end

function Icons.Close(parent, size, thickness)
	local root = holder(parent, "Close", size)
	bar(root, size * 0.78, thickness or 2, 45, 0.5, 0.5)
	bar(root, size * 0.78, thickness or 2, -45, 0.5, 0.5)
	return root
end

function Icons.Minus(parent, size, thickness)
	local root = holder(parent, "Minus", size)
	bar(root, size * 0.7, thickness or 2, 0, 0.5, 0.5)
	return root
end

-- Outlined square (maximize).
function Icons.Square(parent, size, thickness)
	local root = holder(parent, "Square", size)
	local box = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.62, size * 0.62),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Utility.Corner(box, 3)
	Utility.Stroke(box, Color3.new(1, 1, 1), 0, thickness or 2)
	return root
end

-- Two overlapping squares (restore from maximized).
function Icons.Restore(parent, size, thickness)
	local root = holder(parent, "Restore", size)
	local th = thickness or 2
	local front = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.4, 0.6),
		Size = UDim2.fromOffset(size * 0.5, size * 0.5),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Utility.Corner(front, 3)
	Utility.Stroke(front, Color3.new(1, 1, 1), 0, th)
	bar(root, size * 0.4, th, 0, 0.66, 0.16)
	bar(root, size * 0.38, th, 90, 0.86, 0.34)
	return root
end

-- Glyph parts are either filled bars or stroked outlines; recolor whichever applies.
local function eachPart(glyph, apply)
	for _, child in ipairs(glyph:GetChildren()) do
		if child:IsA("Frame") then
			local stroke = child:FindFirstChildOfClass("UIStroke")
			apply(child, stroke)
		end
	end
end

-- Binds every part of a drawn glyph to a theme color token.
function Icons.Bind(theme, glyph, token)
	eachPart(glyph, function(part, stroke)
		if stroke then
			theme:Bind(stroke, { Color = token })
		else
			theme:Bind(part, { BackgroundColor3 = token })
		end
	end)
	return glyph
end

function Icons.SetColor(glyph, color)
	eachPart(glyph, function(part, stroke)
		if stroke then
			stroke.Color = color
		else
			part.BackgroundColor3 = color
		end
	end)
end

-- Empties a glyph holder so another shape can be drawn into the same slot.
function Icons.Clear(glyph)
	for _, child in ipairs(glyph:GetChildren()) do
		child:Destroy()
	end
end

return Icons
end

__modules["core/Theme"] = function(Import)
--// Theme: design tokens + live re-theming. Every themed instance is registered
--// through Theme:Bind(instance, { Property = "Token" | function(tokens) }).

local RunService = game:GetService("RunService")

local Utility = Import("core/Utility")

local Theme = {}
Theme.__index = Theme

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function linear(stops)
	local count = #stops
	local points = table.create(count)
	for index, color in ipairs(stops) do
		points[index] = ColorSequenceKeypoint.new((index - 1) / (count - 1), color)
	end
	return ColorSequence.new(points)
end

-- A -> B -> C -> B -> A so a rotating gradient loops without a visible seam.
local function cycle(stops)
	local mirrored = table.clone(stops)
	for index = #stops - 1, 1, -1 do
		table.insert(mirrored, stops[index])
	end
	return linear(mirrored)
end

--// Presets ----------------------------------------------------------------------
-- Gear 5: black glass, Nika white -> sun gold -> drum orange -> Gomu red.
local Gear5 = {
	Background = rgb(8, 8, 13),
	BackgroundAlpha = 0.2,
	Sidebar = rgb(0, 0, 0),
	SidebarAlpha = 0.5,
	Card = rgb(255, 255, 255),
	CardAlpha = 0.94,
	CardHoverAlpha = 0.89,
	Stroke = rgb(255, 255, 255),
	StrokeAlpha = 0.9,
	Field = rgb(0, 0, 0),
	FieldAlpha = 0.45,
	Popup = rgb(14, 14, 20),
	PopupAlpha = 0.08,
	Track = rgb(255, 255, 255),
	TrackAlpha = 0.84,
	Text = rgb(247, 247, 252),
	SubText = rgb(172, 174, 190),
	Muted = rgb(112, 114, 132),
	OnAccent = rgb(28, 12, 8),
	Accent = rgb(255, 150, 40),
	Success = rgb(80, 230, 150),
	Warning = rgb(255, 205, 70),
	Danger = rgb(255, 72, 92),
	Gradient = {
		rgb(255, 246, 222),
		rgb(255, 200, 62),
		rgb(255, 122, 26),
		rgb(255, 52, 82),
	},
}

Theme.Presets = {
	Gear5 = Gear5,
	Sunrise = {
		Background = rgb(18, 9, 6),
		BackgroundAlpha = 0.16,
		Accent = rgb(255, 130, 40),
		Gradient = { rgb(255, 214, 102), rgb(255, 150, 40), rgb(255, 86, 40), rgb(214, 32, 60) },
	},
	Joyboy = {
		Background = rgb(16, 16, 24),
		BackgroundAlpha = 0.26,
		CardAlpha = 0.91,
		CardHoverAlpha = 0.85,
		Accent = rgb(255, 214, 120),
		Gradient = { rgb(255, 255, 255), rgb(255, 238, 176), rgb(255, 200, 80), rgb(255, 156, 52) },
	},
	Gomu = {
		Background = rgb(14, 6, 9),
		BackgroundAlpha = 0.18,
		Accent = rgb(255, 80, 92),
		Gradient = { rgb(255, 138, 112), rgb(255, 64, 76), rgb(214, 22, 56), rgb(255, 168, 64) },
	},
}

local function resolve(name)
	local tokens = table.clone(Gear5)
	local preset = Theme.Presets[name]
	if preset then
		for key, value in pairs(preset) do
			tokens[key] = value
		end
	end
	tokens.GradientSeq = linear(tokens.Gradient)
	tokens.CycleSeq = cycle(tokens.Gradient)
	return tokens
end

--// Instance ---------------------------------------------------------------------
function Theme.new(name)
	local self = setmetatable({}, Theme)
	self.Name = Theme.Presets[name] and name or "Gear5"
	self.Tokens = resolve(self.Name)
	self.Bindings = {}
	self.Listeners = {}
	return self
end

local FADE_TIME = 0.4

local function canBlend(from, to)
	return from ~= nil and from.Keypoints ~= nil and to.Keypoints ~= nil and #from.Keypoints == #to.Keypoints
end

local function blend(from, to, alpha)
	local a, b = from.Keypoints, to.Keypoints
	local points = table.create(#b)
	for index = 1, #b do
		points[index] = ColorSequenceKeypoint.new(b[index].Time, a[index].Value:Lerp(b[index].Value, alpha))
	end
	return ColorSequence.new(points)
end

-- `jobs` collects gradient swaps so they can cross-fade instead of snapping.
function Theme:_apply(binding, animate, jobs)
	local inst = binding.Instance
	local tweenable = {}
	for property, source in pairs(binding.Map) do
		local value
		if type(source) == "function" then
			value = source(self.Tokens)
		else
			value = self.Tokens[source]
		end
		if value ~= nil then
			local kind = typeof(value)
			if animate and (kind == "Color3" or kind == "number") then
				tweenable[property] = value
			elseif animate and jobs and kind == "ColorSequence" and canBlend(inst[property], value) then
				table.insert(jobs, { Instance = inst, Property = property, From = inst[property], To = value })
			else
				inst[property] = value
			end
		end
	end
	if next(tweenable) then
		Utility.Tween(inst, tweenable, FADE_TIME, Enum.EasingStyle.Quad)
	end
end

function Theme:_blendSequences(jobs)
	if self._blendConnection then
		self._blendConnection:Disconnect()
		self._blendConnection = nil
	end
	if #jobs == 0 then
		return
	end
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local progress = math.min((os.clock() - started) / FADE_TIME, 1)
		local eased = 1 - (1 - progress) ^ 3
		for _, job in ipairs(jobs) do
			job.Instance[job.Property] = progress >= 1 and job.To or blend(job.From, job.To, eased)
		end
		if progress >= 1 then
			connection:Disconnect()
			if self._blendConnection == connection then
				self._blendConnection = nil
			end
		end
	end)
	self._blendConnection = connection
end

function Theme:Bind(inst, map)
	local binding = { Instance = inst, Map = map }
	self.Bindings[binding] = true
	self:_apply(binding, false)
	inst.Destroying:Connect(function()
		self.Bindings[binding] = nil
	end)
	return inst
end

function Theme:Set(name)
	if not Theme.Presets[name] then
		return false
	end
	self.Name = name
	self.Tokens = resolve(name)
	local jobs = {}
	for binding in pairs(self.Bindings) do
		self:_apply(binding, true, jobs)
	end
	self:_blendSequences(jobs)
	for listener in pairs(self.Listeners) do
		task.spawn(listener, self.Tokens, name)
	end
	return true
end

-- For state-dependent colors that can't be a plain binding. Returns a disconnect function.
function Theme:OnChange(listener)
	self.Listeners[listener] = true
	return function()
		self.Listeners[listener] = nil
	end
end

function Theme:Add(name, overrides)
	Theme.Presets[name] = overrides
end

-- Tokens of any theme without applying it (theme menu previews).
function Theme.Preview(name)
	return resolve(name)
end

function Theme:List()
	local names = {}
	for name in pairs(Theme.Presets) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return Theme
end

__modules["core/Utility"] = function(Import)
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Utility = {}

--// Maid: collects connections / instances / callbacks and cleans them in one go
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ Tasks = {} }, Maid)
end

function Maid:Give(task)
	table.insert(self.Tasks, task)
	return task
end

function Maid:Clean()
	local tasks = self.Tasks
	self.Tasks = {}
	for _, task in ipairs(tasks) do
		local kind = typeof(task)
		if kind == "RBXScriptConnection" then
			task:Disconnect()
		elseif kind == "Instance" then
			task:Destroy()
		elseif kind == "function" then
			pcall(task)
		elseif kind == "table" then
			if task.Disconnect then
				pcall(task.Disconnect, task)
			elseif task.Destroy then
				pcall(task.Destroy, task)
			end
		end
	end
end

Utility.Maid = Maid

--// Instance creation
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

function Utility.Create(className, props, children)
	local inst = Instance.new(className)

	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	if TEXT_CLASSES[className] then
		inst.Font = Enum.Font.GothamMedium
		inst.TextSize = 14
		inst.TextColor3 = Color3.new(1, 1, 1)
		inst.TextXAlignment = Enum.TextXAlignment.Left
		inst.BackgroundTransparency = 1
	end
	if className == "TextButton" then
		inst.Text = ""
		inst.AutoButtonColor = false
	elseif className == "ImageButton" then
		inst.AutoButtonColor = false
		inst.BackgroundTransparency = 1
	elseif className == "ImageLabel" then
		inst.BackgroundTransparency = 1
	elseif className == "ScrollingFrame" then
		inst.BackgroundTransparency = 1
		inst.ScrollBarThickness = 3
		inst.ScrollBarImageColor3 = Color3.new(1, 1, 1)
		inst.ScrollBarImageTransparency = 0.55
		inst.CanvasSize = UDim2.new()
		inst.AutomaticCanvasSize = Enum.AutomaticSize.Y
		inst.ScrollingDirection = Enum.ScrollingDirection.Y
		inst.ElasticBehavior = Enum.ElasticBehavior.Never
	elseif className == "UIStroke" then
		inst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	elseif className == "UIListLayout" then
		inst.SortOrder = Enum.SortOrder.LayoutOrder
	end

	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then
				inst[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local Create = Utility.Create

function Utility.Corner(parent, radius)
	if typeof(radius) ~= "UDim" then
		radius = UDim.new(0, radius or 8)
	end
	return Create("UICorner", { CornerRadius = radius, Parent = parent })
end

function Utility.Stroke(parent, color, transparency, thickness)
	return Create("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		Parent = parent,
	})
end

function Utility.Padding(parent, top, bottom, left, right)
	top = top or 0
	return Create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or top),
		PaddingRight = UDim.new(0, right or left or top),
		Parent = parent,
	})
end

function Utility.List(parent, padding, direction, horizontal, vertical)
	return Create("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

Utility.Pill = UDim.new(1, 0)

--// Tweening
function Utility.Tween(inst, goal, duration, style, direction)
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(duration or 0.25, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

--// Math / formatting
function Utility.Clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

function Utility.Decimals(step)
	local text = string.format("%.6f", step)
	text = string.gsub(text, "0+$", "")
	local dot = string.find(text, ".", 1, true)
	if not dot then
		return 0
	end
	return #text - dot
end

function Utility.Snap(value, min, step)
	local snapped = min + math.floor((value - min) / step + 0.5) * step
	local decimals = Utility.Decimals(step)
	return tonumber(string.format("%." .. decimals .. "f", snapped))
end

function Utility.FormatNumber(value, decimals)
	return string.format("%." .. (decimals or 0) .. "f", value)
end

function Utility.ToHex(color)
	return string.format(
		"%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function Utility.FromHex(text)
	text = string.gsub(tostring(text), "[^%x]", "")
	if #text == 3 then
		text = string.gsub(text, "%x", "%0%0")
	end
	if #text ~= 6 then
		return nil
	end
	return Color3.fromRGB(
		tonumber(string.sub(text, 1, 2), 16),
		tonumber(string.sub(text, 3, 4), 16),
		tonumber(string.sub(text, 5, 6), 16)
	)
end

--// Callbacks
function Utility.SafeCall(fn, ...)
	if typeof(fn) ~= "function" then
		return false
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[MugiwaraUI] callback error: " .. tostring(err))
	end
	return ok
end

--// Input helpers
function Utility.IsPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- Calls onUpdate(position) while the pointer is held on `object` (sliders, color pickers...).
function Utility.DragInput(object, maid, onBegin, onUpdate, onEnd)
	local dragging = false
	maid:Give(object.InputBegan:Connect(function(input)
		if not Utility.IsPress(input) then
			return
		end
		dragging = true
		if onBegin then
			onBegin(input)
		end
		onUpdate(input.Position)
		local connection
		connection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				connection:Disconnect()
				dragging = false
				if onEnd then
					onEnd()
				end
			end
		end)
	end))
	maid:Give(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			onUpdate(input.Position)
		end
	end))
end

-- Moves `target` when `handle` is dragged. Fires onClick when released without moving.
function Utility.Draggable(handle, target, maid, getScale, onClick, enabled)
	local dragging = false
	local moved = false
	local startPointer, startPosition

	maid:Give(handle.InputBegan:Connect(function(input)
		if not Utility.IsPress(input) then
			return
		end
		if enabled and not enabled() then
			return
		end
		dragging = true
		moved = false
		startPointer = input.Position
		startPosition = target.Position
		local connection
		connection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				connection:Disconnect()
				dragging = false
				if not moved and onClick then
					onClick()
				end
			end
		end)
	end))

	maid:Give(UserInputService.InputChanged:Connect(function(input)
		if not (dragging and isMove(input)) then
			return
		end
		local delta = input.Position - startPointer
		if delta.Magnitude > 5 then
			moved = true
		end
		if moved then
			local scale = getScale and getScale() or 1
			target.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X / scale,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y / scale
			)
		end
	end))
end

return Utility
end

__modules["init"] = function(Import)
--// Mugiwara UI entry point.

local Compat = Import("core/Compat")
local Icons = Import("core/Icons")
local Theme = Import("core/Theme")
local Window = Import("components/Window")
local Notification = Import("components/Notification")

-- Re-executing the script replaces the previous instance instead of stacking UIs.
local env = Compat.Env
if env.MugiwaraUI and type(env.MugiwaraUI.Destroy) == "function" then
	pcall(function()
		env.MugiwaraUI:Destroy()
	end)
end

local Library = {
	Version = "0.2.1",
	Windows = {},
	Theme = Theme.new("Gear5"),
	Icons = Icons,
	Compat = Compat,
}

function Library:CreateWindow(opts)
	return Window.new(self, opts)
end

function Library:Notify(opts)
	return Notification.Notify(self, opts)
end

function Library:SetTheme(name)
	return self.Theme:Set(name)
end

function Library:GetTheme()
	return self.Theme.Name
end

function Library:GetThemes()
	return self.Theme:List()
end

-- Library:AddTheme("Mine", { Accent = Color3..., Gradient = { Color3... } })
function Library:AddTheme(name, tokens)
	self.Theme:Add(name, tokens)
end

function Library:Destroy()
	for window in pairs(self.Windows) do
		window:Destroy()
	end
	if self._notifyGui then
		self._notifyGui:Destroy()
		self._notifyGui = nil
		self._notifyHolder = nil
	end
	if env.MugiwaraUI == self then
		env.MugiwaraUI = nil
	end
end

env.MugiwaraUI = Library

return Library
end

return Import("init")
