--// Container: anything that can hold elements (Tab pages and Sections). Elements are
--// created through methods so scripts read `tab:Toggle({ ... })`.

local Utility = Import("core/Utility")
local Icons = Import("core/Icons")
local Base = Import("components/Base")
local Button = Import("components/elements/Button")
local Toggle = Import("components/elements/Toggle")
local Slider = Import("components/elements/Slider")
local Dropdown = Import("components/elements/Dropdown")
local GridDropdown = Import("components/elements/GridDropdown")
local Input = Import("components/elements/Input")
local Keybind = Import("components/elements/Keybind")
local Colorpicker = Import("components/elements/Colorpicker")
local Text = Import("components/elements/Text")
local ProgressBar = Import("components/elements/ProgressBar")
local Code = Import("components/elements/Code")
local ImageElement = Import("components/elements/Image")
local Chat = Import("components/elements/Chat")

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

-- Searchable picker that shows pictures in a grid (Columns, CellHeight, MaxHeight).
function Container:GridDropdown(opts)
	return GridDropdown(self, opts)
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

function Container:ProgressBar(opts)
	return ProgressBar(self, opts)
end

function Container:Code(opts)
	return Code(self, opts)
end

function Container:Image(opts)
	return ImageElement(self, opts)
end

-- Live chat between everyone running the hub. Needs a Transport (MugiwaraUI.ChatTransports).
function Container:Chat(opts)
	return Chat(self, opts)
end

-- Blank vertical gap: tab:Space() or tab:Space(24)
function Container:Space(height)
	local frame = Create("Frame", {
		Name = "Space",
		Size = UDim2.new(1, 0, 0, type(height) == "number" and height or 12),
		BackgroundTransparency = 1,
		LayoutOrder = self:NextOrder(),
		Parent = self.Holder,
	})
	return { Frame = frame, SetVisible = function(_, visible) frame.Visible = visible end, Destroy = function() frame:Destroy() end }
end

-- Row: the elements created on the returned container share the width equally, side by side.
--   local row = tab:Group({ Gap = 8 })
--   row:Button({ Title = "A" }); row:Button({ Title = "B" })
-- Best with Buttons, Toggles and ProgressBars; wide controls (dropdown, input) get cramped.
function Container:Group(opts)
	opts = opts or {}
	local gap = opts.Gap or 8

	local row = Create("Frame", {
		Name = "Group",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:NextOrder(),
		Parent = self.Holder,
	})
	Utility.List(row, gap, Enum.FillDirection.Horizontal)

	local group = Container.new(self.Window, row, self.Page, self.Depth)
	group.Frame = row

	local function rebalance()
		local items = {}
		for _, child in ipairs(row:GetChildren()) do
			if child:IsA("GuiObject") then
				table.insert(items, child)
			end
		end
		local count = #items
		for _, item in ipairs(items) do
			item.Size = UDim2.new(1 / count, -gap * (count - 1) / count, 0, 0) -- height stays automatic
		end
	end
	row.ChildAdded:Connect(rebalance)
	row.ChildRemoved:Connect(rebalance)

	function group:Destroy()
		row:Destroy()
	end

	table.insert(self.Elements, group)
	return group
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
