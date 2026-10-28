-- Mugiwara UI v0.6.1
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
	local function applyIcon(icon)
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
				Icons.BindImage(theme, iconLabel, "Accent")
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
end

__modules["components/ChatTransports"] = function(Import)
--// Chat transports: how the Chat element talks to a backend. A transport is a table with:
--//
--//   transport.User                      { UserId, Name, DisplayName }  (who "me" is)
--//   transport:History({ Limit, Before }) -> { Messages, Cursor, More } | nil, error
--//   transport:Poll(cursor)               -> { Messages, Cursor }       | nil, error   (new messages AND deletions)
--//   transport:Send({ Text, ReplyTo })    -> message                    | nil, error
--//   transport:Delete(id)                 -> true                       | nil, error
--//   transport:Destroy()                  (optional)
--//
--// A message is { Id, UserId, Name, DisplayName, Text, Time (unix seconds), Deleted, Reply = { Id, Name, Text } }.
--// All calls may yield. Ready-made transports: Http (the Cloudflare Worker in server/worker) and Memory (demo).

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Compat = Import("core/Compat")

local Transports = {}

local function localUser()
	local player = Players.LocalPlayer
	return {
		UserId = player and player.UserId or 0,
		Name = player and player.Name or "player",
		DisplayName = player and player.DisplayName or "Player",
	}
end

local function copyMessage(message)
	local copy = table.clone(message)
	if message.Reply then
		copy.Reply = table.clone(message.Reply)
	end
	return copy
end

local function urlEncode(value)
	return (string.gsub(tostring(value), "[^%w%-_%.~]", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

--// Http ------------------------------------------------------------------------------------
-- opts: Url (the Worker URL), Channel ("global"), Folder (where the device token is kept)
-- The device token is a random secret stored in <Folder>/chat-token.txt. The server binds your UserId
-- to its hash the first time you send, so nobody else can post as you or delete your messages.
function Transports.Http(opts)
	opts = opts or {}
	if type(opts.Url) ~= "string" or opts.Url == "" then
		error("ChatTransports.Http needs the Url of your chat Worker", 2)
	end

	local base = string.gsub(opts.Url, "/+$", "")
	local channel = opts.Channel or "global"
	local tokenPath = (opts.Folder or "MugiwaraUI") .. "/chat-token.txt"

	local transport = { User = localUser(), Channel = channel }

	local token = Compat.ReadFile(tokenPath)
	if not token or #token < 16 then
		token = string.gsub(HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false), "-", "")
		Compat.EnsureFolder(opts.Folder or "MugiwaraUI")
		Compat.WriteFile(tokenPath, token)
	end

	local function call(method, path, query, body)
		local url = base .. path
		if query then
			local parts = {}
			for key, value in pairs(query) do
				table.insert(parts, urlEncode(key) .. "=" .. urlEncode(value))
			end
			table.sort(parts)
			url = url .. "?" .. table.concat(parts, "&")
		end

		local response, reason = Compat.HttpRequest({
			Url = url,
			Method = method,
			Headers = body and { ["Content-Type"] = "application/json" } or nil,
			Body = body and HttpService:JSONEncode(body) or nil,
		})
		if not response then
			return nil, reason
		end

		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body or "")
		if not ok then
			decoded = nil
		end
		local failed = (response.StatusCode and response.StatusCode >= 400) or (decoded and decoded.error)
		if failed then
			return nil, (decoded and decoded.message) or ("HTTP " .. tostring(response.StatusCode))
		end
		return decoded or {}
	end

	local function map(raw)
		local message = {
			Id = raw.id,
			UserId = raw.userId,
			Name = raw.name,
			DisplayName = raw.displayName,
			Text = raw.text or "",
			Time = raw.time,
			Deleted = raw.deleted == true,
		}
		if raw.replyTo then
			message.Reply = { Id = raw.replyTo, Name = raw.replyName, Text = raw.replyText }
		end
		return message
	end

	local function mapAll(list)
		local out = {}
		for _, raw in ipairs(list or {}) do
			table.insert(out, map(raw))
		end
		return out
	end

	function transport:History(options)
		options = options or {}
		local result, reason = call("GET", "/v1/history", {
			channel = channel,
			limit = options.Limit or 50,
			before = options.Before,
		})
		if not result then
			return nil, reason
		end
		return { Messages = mapAll(result.messages), Cursor = result.rev, More = result.more == true }
	end

	function transport:Poll(cursor)
		local result, reason = call("GET", "/v1/poll", { channel = channel, since = cursor or 0 })
		if not result then
			return nil, reason
		end
		return { Messages = mapAll(result.messages), Cursor = result.rev }
	end

	function transport:Send(options)
		local result, reason = call("POST", "/v1/send", nil, {
			channel = channel,
			userId = self.User.UserId,
			name = self.User.Name,
			displayName = self.User.DisplayName,
			text = options.Text,
			replyTo = options.ReplyTo,
			token = token,
		})
		if not result or not result.message then
			return nil, reason or "Could not send"
		end
		return map(result.message)
	end

	function transport:Delete(id)
		local result, reason = call("POST", "/v1/delete", nil, {
			channel = channel,
			id = id,
			userId = self.User.UserId,
			token = token,
		})
		if not result then
			return nil, reason
		end
		return true
	end

	return transport
end

--// Memory ----------------------------------------------------------------------------------
-- A chat that lives inside this script only: for trying the UI before you have a backend.
-- opts: Bots (default true: a few fake players talk now and then), Seed (messages to start with)
function Transports.Memory(opts)
	opts = opts or {}
	local transport = { User = localUser(), Channel = "memory" }
	local messages, byId = {}, {}
	local rev, nextId = 0, 1
	local alive = true

	local BOTS = {
		{ UserId = 1001, Name = "Zoro_Roronoa", DisplayName = "Zoro" },
		{ UserId = 1002, Name = "Nami_Navigator", DisplayName = "Nami" },
		{ UserId = 1003, Name = "Usopp_Sniper", DisplayName = "Usopp" },
		{ UserId = 1004, Name = "Sanji_Cook", DisplayName = "Sanji" },
	}
	local LINES = {
		"anyone farming right now?",
		"this hub is so smooth",
		"which server are you on?",
		"found a new spot, dm me",
		"lol that boss is free",
		"brb getting food",
		"who wants to team up?",
		"update when?",
	}

	local function add(user, text, replyId)
		rev = rev + 1
		local message = {
			Id = nextId,
			Rev = rev,
			UserId = user.UserId,
			Name = user.Name,
			DisplayName = user.DisplayName,
			Text = text,
			Time = os.time(),
			Deleted = false,
		}
		local original = replyId and byId[replyId]
		if original then
			local preview = original.Deleted and "Message deleted" or string.sub(original.Text, 1, 80)
			message.Reply = { Id = original.Id, Name = original.DisplayName, Text = preview }
		end
		nextId = nextId + 1
		table.insert(messages, message)
		byId[message.Id] = message
		return message
	end

	for index, text in ipairs(opts.Seed or {}) do
		local bot = BOTS[(index - 1) % #BOTS + 1]
		add(bot, text)
	end
	if opts.Seed == nil and opts.Bots ~= false then
		add(BOTS[1], "welcome to the chat!")
		add(BOTS[2], "say something, replies and deleting your own messages work too")
	end

	function transport:History(options)
		options = options or {}
		local limit = options.Limit or 50
		local picked = {}
		for index = #messages, 1, -1 do
			local message = messages[index]
			if not options.Before or message.Id < options.Before then
				table.insert(picked, 1, copyMessage(message))
				if #picked >= limit then
					break
				end
			end
		end
		local more = #picked > 0 and picked[1].Id > 1
		return { Messages = picked, Cursor = rev, More = more }
	end

	function transport:Poll(cursor)
		local changes = {}
		for _, message in ipairs(messages) do
			if message.Rev > (cursor or 0) then
				table.insert(changes, copyMessage(message))
			end
		end
		return { Messages = changes, Cursor = rev }
	end

	function transport:Send(options)
		return copyMessage(add(self.User, options.Text, options.ReplyTo))
	end

	function transport:Delete(id)
		local message = byId[id]
		if not message or message.UserId ~= self.User.UserId then
			return nil, "You can only delete your own messages"
		end
		message.Deleted = true
		message.Text = ""
		rev = rev + 1
		message.Rev = rev
		return true
	end

	-- Posts as another (fake) user. Handy for demos and tests.
	function transport:Say(user, text, replyId)
		return copyMessage(add(user, text, replyId))
	end

	-- Removes any message, whoever wrote it. Handy for demos and tests.
	function transport:Remove(id)
		local message = byId[id]
		if not message then
			return false
		end
		message.Deleted = true
		message.Text = ""
		rev = rev + 1
		message.Rev = rev
		return true
	end

	function transport:Destroy()
		alive = false
	end

	if opts.Bots ~= false then
		task.spawn(function()
			while alive do
				task.wait(math.random(60, 120) / 10)
				if not alive then
					break
				end
				local bot = BOTS[math.random(1, #BOTS)]
				local replyId = (#messages > 0 and math.random() < 0.3) and messages[#messages].Id or nil
				add(bot, LINES[math.random(1, #LINES)], replyId)
			end
		end)
	end

	return transport
end

return Transports
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
			Font = Utility.Fonts.Desc,
			TextSize = 14,
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

__modules["components/KeySystem"] = function(Import)
--// Key UI: a separate, wide (21:9) glass card that asks for a key and validates it with YOUR function.
--// Left side: who you are (icon, title, note). Right side: key field, status, Verify, link buttons.
--// An accepted key is always saved (when the executor has file access); next run it is validated again
--// and, if it still passes, the Key UI never appears.
--//
--//   local KeyUI = MugiwaraUI:KeySystem({
--//       Title = "Mugiwara Hub",
--//       Folder = "MugiwaraHub",
--//       Links = { { Title = "Get Key", Link = "https://example.com/key" } },
--//       Validate = function(key) return key == "abc", "Invalid key" end,
--//   })
--//   local key = KeyUI:Wait()   -- yields until a key is accepted; nil if the user closed the card

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Icons = Import("core/Icons")
local Base = Import("components/Base")
local Shell = Import("components/Shell")

local Create, Tween = Utility.Create, Utility.Tween

-- 21:9
local WIDTH, HEIGHT = 700, 300
local SIDE = 250

local function trim(text)
	text = string.gsub(tostring(text or ""), "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

-- opts: Title, Subtitle, Icon, Note (false hides it), Heading, Placeholder, Folder,
--       SaveKey (default true; false = never save the key), Links = { { Title, Link, Icon, Callback } },
--       Validate(key) -> true | false, message  (required, may yield; only `true` accepts),
--       OnSuccess(key), OnClose()
return function(library, opts)
	opts = opts or {}
	if type(opts.Validate) ~= "function" then
		error("MugiwaraUI:KeySystem needs a Validate(key) function that returns true or false, message", 2)
	end

	local theme = library.Theme
	local folder = opts.Folder or "MugiwaraUI"
	local keyPath = folder .. "/key.txt"
	local canSave = opts.SaveKey ~= false and Compat.FilesSupported
	local links = opts.Links or {}

	local KeyUI = {
		Completed = Utility.Signal.new(true),
		Key = nil,
		Destroyed = false,
	}

	if library._keyUI and not library._keyUI.Destroyed then
		library._keyUI:Close()
	end
	library._keyUI = KeyUI

	local shell, status, box, submitButton, submitLabel
	local busy, finished = false, false

	--// validation ---------------------------------------------------------------------
	-- returns valid (bool), message (string|nil); errors inside Validate count as invalid
	local function runValidate(key)
		local ok, valid, message = pcall(opts.Validate, key)
		if not ok then
			warn("[MugiwaraUI] Validate error: " .. tostring(valid))
			return false, "Validation failed. Try again."
		end
		return valid == true, message
	end

	local function setStatus(text, kind)
		if not status then
			return
		end
		local colors = {
			info = theme.Tokens.SubText,
			error = theme.Tokens.Danger,
			success = theme.Tokens.Success,
			busy = theme.Tokens.Accent,
		}
		status.Text = text or ""
		status.TextColor3 = colors[kind or "info"]
	end

	function KeyUI:SetStatus(text, kind)
		setStatus(text, kind)
	end

	function KeyUI:ClearSavedKey()
		Compat.DeleteFile(keyPath)
	end

	local function finish(key)
		if finished then
			return
		end
		finished = true
		KeyUI.Key = key
		local function done()
			KeyUI.Destroyed = true
			KeyUI.Completed:Fire(key)
		end
		if shell then
			shell:Hide(done)
		else
			done()
		end
	end

	function KeyUI:Close()
		if finished then
			return
		end
		Utility.SafeCall(opts.OnClose)
		finish(nil)
	end

	function KeyUI:Wait()
		return self.Completed:Wait()
	end

	--// UI ------------------------------------------------------------------------------
	local function shake()
		local offsets = { 10, -9, 7, -5, 3, 0 }
		for index, dx in ipairs(offsets) do
			task.delay((index - 1) * 0.05, function()
				if shell and shell.Pop.Parent then
					Tween(shell.Pop, { Position = UDim2.new(0.5, dx, 0.5, 0) }, 0.05, Enum.EasingStyle.Sine)
				end
			end)
		end
	end

	local function submit(typed)
		if busy or finished then
			return
		end
		local key = trim(typed or (box and box.Text) or "")
		if key == "" then
			setStatus("Please enter your key.", "error")
			shake()
			return
		end

		busy = true
		setStatus("Checking key...", "busy")
		if submitLabel then
			submitLabel.Text = "Checking..."
		end

		task.spawn(function()
			local valid, message = runValidate(key)
			if not valid then
				busy = false -- an accepted key keeps the card locked while it plays the success animation
				setStatus(message or "Invalid key.", "error")
				if submitLabel then
					submitLabel.Text = "Verify Key"
				end
				shake()
				return
			end

			setStatus(message or "Key accepted.", "success")
			if submitLabel then
				submitLabel.Text = "Access granted"
			end
			if submitButton then
				submitButton.BackgroundColor3 = theme.Tokens.Success
			end
			if canSave then
				Compat.EnsureFolder(folder)
				Compat.WriteFile(keyPath, key)
			end
			Utility.SafeCall(opts.OnSuccess, key)
			task.delay(0.9, function()
				finish(key)
			end)
		end)
	end

	function KeyUI:Submit(key)
		submit(key)
	end

	local function build()
		shell = Shell.new(library, {
			Name = "Key",
			Size = Vector2.new(WIDTH, HEIGHT),
			Backdrop = 0.45,
			-- covers the whole screen including the top bar strip (the backdrop used to stop below it)
			IgnoreGuiInset = true,
			MinScale = 0.5,
		})
		local maid = shell.Maid
		local card = shell.Card

		--// left panel: identity ---------------------------------------------------------
		local side = Create("Frame", {
			Name = "Side",
			Size = UDim2.new(0, SIDE, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			Parent = card,
		})
		theme:Bind(side, { BackgroundColor3 = "Sidebar", BackgroundTransparency = "SidebarAlpha" })
		local sideEdge = Create("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = side,
		})
		theme:Bind(sideEdge, { BackgroundColor3 = "Stroke", BackgroundTransparency = "StrokeAlpha" })

		local identity = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = side,
		})
		Utility.Padding(identity, 26, 26, 28, 24)
		Utility.List(identity, 10, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local brand = Create("Frame", {
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = 1,
			Parent = identity,
		})
		Utility.Corner(brand, 16)
		Base.Gradient(theme, brand, 45)
		local slot = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			Parent = brand,
		})
		local logo, monochrome = Icons.Create(opts.Icon or "lucide:key-round", slot)
		if logo and monochrome then
			Icons.BindImage(theme, logo, "OnAccent")
		elseif logo then
			brand.BackgroundTransparency = 1
			slot.Size = UDim2.fromScale(1, 1)
		else
			slot:Destroy()
			local letter = Create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Text = string.upper(string.sub(opts.Title or "M", 1, 1)),
				Font = Enum.Font.GothamBlack,
				TextSize = 30,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = brand,
			})
			theme:Bind(letter, { TextColor3 = "OnAccent" })
		end

		local title = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Title or "Mugiwara Hub",
			Font = Utility.Fonts.Title,
			TextSize = 23,
			TextWrapped = true,
			LayoutOrder = 2,
			Parent = identity,
		})
		Base.Gradient(theme, title, 0)

		local subtitle = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Subtitle or "Key System",
			Font = Utility.Fonts.Label,
			TextSize = 14,
			TextWrapped = true,
			LayoutOrder = 3,
			Parent = identity,
		})
		theme:Bind(subtitle, { TextColor3 = "Text" })

		if opts.Note ~= false then
			local note = Create("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = opts.Note or "Enter your key to continue.",
				Font = Utility.Fonts.Desc,
				TextSize = 13,
				TextWrapped = true,
				LayoutOrder = 4,
				Parent = identity,
			})
			theme:Bind(note, { TextColor3 = "SubText" })
		end

		--// right panel: the form -----------------------------------------------------------
		local form = Create("Frame", {
			Name = "Form",
			Position = UDim2.fromOffset(SIDE, 0),
			Size = UDim2.new(1, -SIDE, 1, 0),
			BackgroundTransparency = 1,
			Parent = card,
		})
		Utility.Padding(form, 24, 24, 34, 34)
		Utility.List(form, 12, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local heading = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 26),
			Text = opts.Heading or "Enter your key",
			Font = Utility.Fonts.Title,
			TextSize = 20,
			LayoutOrder = 1,
			Parent = form,
		})
		theme:Bind(heading, { TextColor3 = "Text" })

		local field, fieldStroke = Base.Field(theme, form, UDim2.new(1, 0, 0, 48))
		field.LayoutOrder = 2
		local keyIconSlot = Create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Parent = field,
		})
		local keyIcon = Icons.Create("lucide:key-round", keyIconSlot)
		if keyIcon then
			Icons.BindImage(theme, keyIcon, "Muted")
		end

		local getClipboard = Compat.GetClipboard
		local pasteWidth = getClipboard and 64 or 0
		box = Create("TextBox", {
			Position = UDim2.fromOffset(46, 0),
			Size = UDim2.new(1, -(46 + 10 + pasteWidth), 1, 0),
			Text = "",
			PlaceholderText = opts.Placeholder or "Enter your key...",
			Font = Utility.Fonts.Body,
			TextSize = 15,
			ClearTextOnFocus = false,
			Parent = field,
		})
		theme:Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })
		KeyUI.Box = box

		maid:Give(box.Focused:Connect(function()
			Tween(fieldStroke, { Transparency = 0.2 }, 0.2)
			fieldStroke.Color = theme.Tokens.Accent
		end))
		maid:Give(box.FocusLost:Connect(function(enterPressed)
			Tween(fieldStroke, { Transparency = theme.Tokens.StrokeAlpha }, 0.2)
			fieldStroke.Color = theme.Tokens.Stroke
			if enterPressed then
				submit()
			end
		end))

		if getClipboard then
			local paste = Create("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(52, 32),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Text = "Paste",
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = field,
			})
			Utility.Corner(paste, 8)
			theme:Bind(paste, { BackgroundColor3 = "Card", BackgroundTransparency = "CardHoverAlpha", TextColor3 = "Text" })
			maid:Give(paste.MouseButton1Click:Connect(function()
				local text = getClipboard()
				if text and text ~= "" then
					box.Text = trim(text)
				end
			end))
		end

		status = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			Text = "",
			Font = Utility.Fonts.Label,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 3,
			Parent = form,
		})
		KeyUI.Status = status

		-- centered anchor so the press animation shrinks toward the middle
		local verifyHolder = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Parent = form,
		})
		submitButton = Create("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = verifyHolder,
		})
		Utility.Corner(submitButton, 12)
		Base.Gradient(theme, submitButton, 0)
		submitLabel = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = "Verify Key",
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = submitButton,
		})
		theme:Bind(submitLabel, { TextColor3 = "OnAccent" })

		maid:Give(submitButton.MouseButton1Click:Connect(function()
			Tween(submitButton, { Size = UDim2.new(1, -8, 1, -6) }, 0.08)
			task.delay(0.09, function()
				if submitButton.Parent then
					Tween(submitButton, { Size = UDim2.fromScale(1, 1) }, 0.35, Enum.EasingStyle.Back)
				end
			end)
			submit()
		end))

		--// links ------------------------------------------------------------------------------
		KeyUI.LinkButtons = {}
		if #links > 0 then
			local row = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 5,
				Parent = form,
			})
			local gap = 8
			local count = #links
			Utility.List(row, gap, Enum.FillDirection.Horizontal)
			for index, link in ipairs(links) do
				local button = Create("TextButton", {
					Size = UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0),
					LayoutOrder = index,
					BackgroundColor3 = Color3.new(1, 1, 1),
					Parent = row,
				})
				KeyUI.LinkButtons[index] = button
				Utility.Corner(button, 10)
				theme:Bind(button, { BackgroundColor3 = "Card", BackgroundTransparency = "CardHoverAlpha" })
				local buttonStroke = Utility.Stroke(button, Color3.new(1, 1, 1), 0.9, 1)
				theme:Bind(buttonStroke, { Color = "Stroke", Transparency = "StrokeAlpha" })

				-- icon + text centered as one group
				local group = Create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(0, 20),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Parent = button,
				})
				Utility.List(group, 8, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
				if link.Icon then
					local iconSlot = Create("Frame", { Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, LayoutOrder = 1, Parent = group })
					local icon = Icons.Create(link.Icon, iconSlot)
					if icon then
						Icons.BindImage(theme, icon, "Accent")
					else
						iconSlot:Destroy()
					end
				end
				local text = Create("TextLabel", {
					Size = UDim2.fromOffset(0, 20),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = link.Title or "Link",
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					LayoutOrder = 2,
					Parent = group,
				})
				theme:Bind(text, { TextColor3 = "Text" })

				maid:Give(button.MouseButton1Click:Connect(function()
					if link.Callback then
						Utility.SafeCall(link.Callback)
					elseif link.Link then
						-- executors cannot open a browser, so the link goes to the clipboard
						if Compat.SetClipboard(link.Link) then
							setStatus("Link copied to your clipboard.", "success")
						else
							setStatus(link.Link, "info")
						end
					end
				end))
			end
		end

		--// close ---------------------------------------------------------------------------------
		local closeButton = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 14),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = card,
		})
		Utility.Corner(closeButton, 9)
		local closeGlyph = Icons.Bind(theme, Icons.Close(closeButton, 20, 2), "SubText")
		closeButton.MouseEnter:Connect(function()
			Tween(closeButton, { BackgroundTransparency = 0.88 }, 0.15)
			Icons.SetColor(closeGlyph, theme.Tokens.Danger)
		end)
		closeButton.MouseLeave:Connect(function()
			Tween(closeButton, { BackgroundTransparency = 1 }, 0.2)
			Icons.SetColor(closeGlyph, theme.Tokens.SubText)
		end)
		maid:Give(closeButton.MouseButton1Click:Connect(function()
			KeyUI:Close()
		end))

		shell:Show()
		if not Compat.IsMobile then
			task.delay(0.5, function()
				if box and box.Parent then
					box:CaptureFocus()
				end
			end)
		end
	end

	--// start: a saved key that still validates skips the UI entirely -------------------------
	task.spawn(function()
		if canSave then
			local saved = Compat.ReadFile(keyPath)
			saved = saved and trim(saved) or ""
			if saved ~= "" then
				local valid = runValidate(saved)
				if valid then
					Utility.SafeCall(opts.OnSuccess, saved)
					finish(saved)
					return
				end
				Compat.DeleteFile(keyPath)
			end
		end
		if not finished then
			build()
		end
	end)

	return KeyUI
end
end

__modules["components/Loading"] = function(Import)
--// Loading UI: terminal-style loading card. The behavior (scrambled title, typed fake logs, progress that
--// follows real stages, staggered enter / exit) is the Mugiwara Hub loading screen; only the look follows
--// the active Mugiwara theme.
--//
--//   local Loader = MugiwaraUI:Loading({ Title = "Mugiwara Hub", Owner = "Honami", Version = "v1.0.0" })
--//   Loader:SetStatus("Loading modules")
--//   Loader:SetProgress(40, 70)     -- jump to 40%, then creep up to 70% while the stage runs
--//   Loader:Log("Fetching data", "info")
--//   Loader:Finish("Welcome!")      -- the loader never ends on its own
--//   Loader.Finished:Wait()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Base = Import("components/Base")
local Shell = Import("components/Shell")

local Create, Tween = Utility.Create, Utility.Tween

local DEFAULT_LOGS = {
	"Establishing secure connection",
	"Verifying key session",
	"Fetching UI library",
	"Decrypting payload",
	"Scanning game environment",
	"Resolving game modules",
	"Mounting global tabs",
	"Syncing configuration",
	"Allocating memory blocks",
	"Compiling feature modules",
	"Checking for updates",
	"Optimizing render pipeline",
}

local SCRAMBLE_CHARS = "!@#$%&*<>?/\\|01ABCDEFXZ"
local HEX_CHARS = "0123456789ABCDEF"
local ENTER_STAGGER = 0.1
local EXIT_STAGGER = 0.06

local function randomHex(length)
	local out = table.create(length)
	for index = 1, length do
		local pick = math.random(1, #HEX_CHARS)
		out[index] = string.sub(HEX_CHARS, pick, pick)
	end
	return table.concat(out)
end

local function hex(color)
	return "#" .. Utility.ToHex(color)
end

-- opts: Title, Owner, Version, Terminal (window title), Prompt, Logs (fake log lines), MaxLogLines, InstantCover
return function(library, opts)
	opts = opts or {}
	local theme = library.Theme
	local tokens = theme.Tokens

	-- the previous loader (if any) is replaced instead of stacking
	if library._loader and not library._loader.Destroyed then
		library._loader:Destroy()
	end

	-- palette comes from the active theme
	local C = {
		accent = tokens.Accent,
		gold = tokens.Gradient[2] or tokens.Accent,
		text = tokens.Text,
		dim = tokens.SubText,
		ok = tokens.Success,
		warn = tokens.Warning,
		err = tokens.Danger,
	}
	local config = {
		Title = opts.Title or "Mugiwara Hub",
		Owner = opts.Owner or opts.Author,
		Version = opts.Version,
		Terminal = opts.Terminal or "root@mugiwara: ~/loader",
		Prompt = opts.Prompt or "root@mugiwara",
		MaxLogLines = opts.MaxLogLines or 6,
		Logs = opts.Logs or DEFAULT_LOGS,
	}

	local state = {
		finishing = false,
		finished = false,
		titleBusy = false,
		status = "Initializing",
		startTime = os.clock(),
		lastHex = 0,
		-- Progress: with Loader:SetProgress(target, cap) the percent follows the real stages (jumps to
		-- `target`, then creeps toward `cap`). Without it a time curve is used.
		manualProgress = false,
		target = 0,
		cap = 0,
	}
	local logOrder = 0

	local shell = Shell.new(library, {
		Name = "Loading",
		Size = Vector2.new(460, 312),
		Backdrop = 0.35,
		InstantBackdrop = opts.InstantCover == true,
		IgnoreGuiInset = true,
		MinScale = 0.55,
		MaxScale = 1.3,
	})
	local maid = shell.Maid
	local card = shell.Card

	--// content blocks: separate CanvasGroups so they enter / leave one after another
	local content = Create("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = card })

	local function createBlock(name)
		return Create("CanvasGroup", {
			Name = name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Position = UDim2.fromOffset(0, 14),
			Parent = content,
		})
	end

	local HeaderBlock = createBlock("HeaderBlock")
	local DividerBlock = createBlock("DividerBlock")
	local TerminalBlock = createBlock("TerminalBlock")
	local ProgressBlock = createBlock("ProgressBlock")
	local FooterBlock = createBlock("FooterBlock")
	local Blocks = { HeaderBlock, DividerBlock, TerminalBlock, ProgressBlock, FooterBlock }

	--// header
	local Title = Create("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -60, 0, 32),
		Font = Enum.Font.GothamBlack,
		Text = "",
		TextSize = 26,
		Parent = HeaderBlock,
	})
	Base.Gradient(theme, Title, 0)

	local PulseDot = Create("Frame", {
		Name = "PulseDot",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0, 32),
		Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = C.accent,
		Parent = HeaderBlock,
	})
	Utility.Corner(PulseDot, Utility.Pill)

	local parts = {}
	if config.Owner then
		table.insert(parts, string.format('Owner: <font color="%s">%s</font>', hex(C.accent), config.Owner))
	end
	if config.Version and config.Version ~= "" then
		table.insert(parts, string.format('Version: <font color="%s">%s</font>', hex(C.gold), config.Version))
	end
	local subtitle = Create("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.fromOffset(20, 50),
		Size = UDim2.new(1, -40, 0, 16),
		Font = Enum.Font.Code,
		RichText = true,
		TextSize = 13,
		TextColor3 = C.dim,
		Text = table.concat(parts, "   |   "),
		Parent = HeaderBlock,
	})
	theme:Bind(subtitle, { TextColor3 = "SubText" })

	--// divider (grows from the center when its block enters)
	local DIVIDER_SIZE = UDim2.new(1, -40, 0, 1)
	local DividerLine = Create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.new(0, 0, 0, 1),
		BackgroundColor3 = C.dim,
		Parent = DividerBlock,
	})
	Base.Gradient(theme, DividerLine, 0).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})

	--// terminal
	local TerminalBox = Create("Frame", {
		Name = "Terminal",
		Position = UDim2.fromOffset(20, 86),
		Size = UDim2.new(1, -40, 0, 150),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ClipsDescendants = true,
		Parent = TerminalBlock,
	})
	Utility.Corner(TerminalBox, 8)
	theme:Bind(TerminalBox, { BackgroundColor3 = "Field", BackgroundTransparency = "FieldAlpha" })
	local terminalStroke = Utility.Stroke(TerminalBox, C.dim, 0.8, 1)
	theme:Bind(terminalStroke, { Color = "Stroke", Transparency = "StrokeAlpha" })

	for index, color in ipairs({ C.err, C.warn, C.ok }) do
		local dot = Create("Frame", {
			Position = UDim2.fromOffset(10 + (index - 1) * 14, 7),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = color,
			Parent = TerminalBox,
		})
		Utility.Corner(dot, Utility.Pill)
	end

	local terminalTitle = Create("TextLabel", {
		Name = "TerminalTitle",
		Position = UDim2.fromOffset(56, 3),
		Size = UDim2.new(1, -66, 0, 16),
		Font = Enum.Font.Code,
		TextSize = 12,
		Text = config.Terminal,
		Parent = TerminalBox,
	})
	theme:Bind(terminalTitle, { TextColor3 = "SubText" })

	local terminalRule = Create("Frame", {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = TerminalBox,
	})
	theme:Bind(terminalRule, { BackgroundColor3 = "Stroke", BackgroundTransparency = "StrokeAlpha" })

	local LogFrame = Create("Frame", {
		Name = "Logs",
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 1, -50),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = TerminalBox,
	})
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 2),
		Parent = LogFrame,
	})

	local PROMPT_TEXT = string.format(
		'<font color="%s">%s</font><font color="%s">:~$</font> ',
		hex(C.gold),
		config.Prompt,
		hex(C.dim)
	)
	local PromptLabel = Create("TextLabel", {
		Name = "Prompt",
		Position = UDim2.new(0, 10, 1, -20),
		Size = UDim2.new(1, -20, 0, 16),
		Font = Enum.Font.Code,
		RichText = true,
		TextSize = 12,
		TextColor3 = C.text,
		Text = PROMPT_TEXT,
		Parent = TerminalBox,
	})

	-- scanline sweeping down the terminal
	local Scanline = Create("Frame", {
		Name = "Scanline",
		Position = UDim2.fromScale(0, -0.05),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = C.gold,
		BackgroundTransparency = 0.85,
		ZIndex = 5,
		Parent = TerminalBox,
	})

	local function loop(inst, info, goal)
		local tween = TweenService:Create(inst, info, goal)
		tween:Play()
		maid:Give(function()
			tween:Cancel()
		end)
	end
	loop(Scanline, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Position = UDim2.fromScale(0, 1.05) })

	--// status + progress
	local StatusLabel = Create("TextLabel", {
		Name = "Status",
		Position = UDim2.fromOffset(20, 246),
		Size = UDim2.new(1, -100, 0, 16),
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = C.text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = ProgressBlock,
	})

	local PercentLabel = Create("TextLabel", {
		Name = "Percent",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 246),
		Size = UDim2.fromOffset(70, 16),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = C.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0%",
		Parent = ProgressBlock,
	})

	local BAR_SIZE = UDim2.new(1, -40, 0, 6)
	local BarTrack = Create("Frame", {
		Name = "BarTrack",
		Position = UDim2.fromOffset(20, 268),
		Size = UDim2.new(0, 0, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = ProgressBlock,
	})
	Utility.Corner(BarTrack, Utility.Pill)
	theme:Bind(BarTrack, { BackgroundColor3 = "Track", BackgroundTransparency = "TrackAlpha" })

	local Fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = BarTrack,
	})
	Utility.Corner(Fill, Utility.Pill)
	local FillGradient = Base.Gradient(theme, Fill, 0)

	local Shimmer = Create("Frame", {
		Name = "Shimmer",
		Position = UDim2.fromScale(-0.3, 0),
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = BarTrack,
	})
	Create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = Shimmer,
	})
	loop(Shimmer, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Position = UDim2.fromScale(1, 0) })

	-- random hex line under the bar (decoration)
	local HexFooter = Create("TextLabel", {
		Name = "HexFooter",
		Position = UDim2.fromOffset(20, 284),
		Size = UDim2.new(1, -40, 0, 14),
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = C.dim,
		TextTransparency = 0.45,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = FooterBlock,
	})

	--// text animations ---------------------------------------------------------------
	-- title "decodes" letter by letter
	local function scrambleText(label, finalText, duration)
		state.titleBusy = true
		local length = #finalText
		local stepTime = duration / math.max(length, 1)

		for revealed = 0, length do
			if not label.Parent then
				break
			end
			local out = { string.sub(finalText, 1, revealed) }
			for index = revealed + 1, length do
				if string.sub(finalText, index, index) == " " then
					table.insert(out, " ")
				else
					local pick = math.random(1, #SCRAMBLE_CHARS)
					table.insert(out, string.sub(SCRAMBLE_CHARS, pick, pick))
				end
			end
			label.Text = table.concat(out)
			task.wait(stepTime)
		end

		if label.Parent then
			label.Text = finalText
		end
		state.titleBusy = false
	end

	local LOG_TYPES = {
		info = { tag = "*", color = C.warn },
		ok = { tag = "+", color = C.ok },
		warn = { tag = "!", color = C.warn },
		error = { tag = "x", color = C.err },
	}

	-- one log line with a typing effect
	local function addLog(message, kind)
		if not LogFrame.Parent then
			return nil
		end

		local logType = LOG_TYPES[kind] or LOG_TYPES.info
		local timeStr = os.date("%H:%M:%S")
		logOrder = logOrder + 1

		local richText = string.format(
			'<font color="%s">[%s]</font> <font color="%s">[%s]</font> %s',
			hex(C.dim),
			timeStr,
			hex(logType.color),
			logType.tag,
			message
		)
		-- length without RichText tags (for the typing effect)
		local plainLength = #string.format("[%s] [%s] %s", timeStr, logType.tag, message)

		local line = Create("TextLabel", {
			Name = "Log",
			Size = UDim2.new(1, 0, 0, 15),
			Font = Enum.Font.Code,
			RichText = true,
			TextSize = 12,
			TextColor3 = C.text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = logOrder,
			MaxVisibleGraphemes = 0,
			Text = richText,
			Parent = LogFrame,
		})

		-- drop the oldest lines when there are too many
		local lines = {}
		for _, child in ipairs(LogFrame:GetChildren()) do
			if child:IsA("TextLabel") then
				table.insert(lines, child)
			end
		end
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		while #lines > config.MaxLogLines do
			table.remove(lines, 1):Destroy()
		end

		task.spawn(function()
			for index = 1, plainLength do
				if not line.Parent then
					return
				end
				line.MaxVisibleGraphemes = index
				task.wait(0.012)
			end
			if line.Parent then
				line.MaxVisibleGraphemes = -1
			end
		end)

		return { Label = line, Base = richText }
	end

	-- appends " OK" / " RETRY" to a log line
	local function completeLog(entry, word, color)
		if not entry or not entry.Label.Parent then
			return
		end
		entry.Label.MaxVisibleGraphemes = -1
		entry.Label.Text = string.format('%s <font color="%s">%s</font>', entry.Base, hex(color), word)
	end

	--// per-frame loop -----------------------------------------------------------------
	local percentValue = Instance.new("NumberValue")
	percentValue.Value = 0
	maid:Give(percentValue)

	maid:Give(RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()

		PulseDot.BackgroundTransparency = 0.35 + 0.35 * math.sin(now * 5)
		PromptLabel.Text = PROMPT_TEXT .. ((math.floor(now * 2.5) % 2 == 0) and "_" or "")

		-- percent: follows the real stages with SetProgress, otherwise a time curve.
		-- Never goes down and stops at 99% until Finish is called.
		if not state.finishing then
			local current = percentValue.Value
			if state.manualProgress then
				if current < state.target then
					current = current + (state.target - current) * (1 - math.exp(-dt * 7))
				elseif current < state.cap then
					current = current + (state.cap - current) * (1 - math.exp(-dt / 5))
				end
			else
				current = math.max(current, 99 * (1 - math.exp(-(now - state.startTime) / 12)))
			end
			percentValue.Value = math.min(current, 99)
		end
		local percent = percentValue.Value
		PercentLabel.Text = string.format("%d%%", math.floor(percent))
		Fill.Size = UDim2.fromScale(percent / 100, 1)

		if not state.finished then
			local dots = string.rep(".", math.floor(now * 3) % 4)
			StatusLabel.Text = state.status .. dots
		end

		-- random hex (rate limited)
		if now - state.lastHex > 0.07 then
			state.lastHex = now
			HexFooter.Text = string.format(
				"0x%s  %s %s  %s  MEM:0x%s",
				randomHex(8),
				randomHex(4),
				randomHex(4),
				randomHex(6),
				randomHex(4)
			)
		end
	end))

	--// API -------------------------------------------------------------------------------
	local Loader = { Gui = shell.Gui, Destroyed = false }

	-- Loader.FinishEvent:Fire(message) finishes the loader; Loader.Finished fires once the UI is gone
	Loader.FinishEvent = Utility.Signal.new()
	local closed = Utility.Signal.new(true)
	Loader.Finished = closed

	function Loader:SetStatus(text)
		if state.finishing then
			return
		end
		state.status = tostring(text)
	end

	-- `target` = percent to reach quickly, `cap` = slow creep limit while the stage is still running
	function Loader:SetProgress(target, cap)
		if state.finishing then
			return
		end
		state.manualProgress = true
		state.target = math.max(state.target, tonumber(target) or 0)
		state.cap = math.max(state.target, tonumber(cap) or state.target)
	end

	-- kind: "info" | "ok" | "warn" | "error"
	function Loader:Log(text, kind)
		return addLog(tostring(text), kind)
	end

	-- removes the UI immediately, without the exit animation
	function Loader:Destroy()
		if self.Destroyed then
			return
		end
		self.Destroyed = true
		shell:Destroy()
		if Compat.Env.MugiwaraLoader == self then
			Compat.Env.MugiwaraLoader = nil
		end
	end

	function Loader:Finish(message)
		if state.finishing then
			return
		end
		state.finishing = true

		task.spawn(function()
			state.status = "Finalizing"
			addLog("All modules loaded successfully", "ok")

			Tween(percentValue, { Value = 100 }, 0.6)
			task.wait(0.35)
			FillGradient.Color = ColorSequence.new(C.ok)
			local player = Players.LocalPlayer
			addLog(message or ("Access granted. Welcome, " .. (player and player.DisplayName or "player")), "ok")
			task.wait(0.35)

			state.finished = true
			StatusLabel.Text = "Ready"
			StatusLabel.TextColor3 = C.ok
			PulseDot.BackgroundColor3 = C.ok
			scrambleText(Title, config.Title, 0.35)
			task.wait(0.6)

			-- exit: the reverse of the enter, bottom block first, then the card and backdrop
			for index = #Blocks, 1, -1 do
				local block = Blocks[index]
				task.delay((#Blocks - index) * EXIT_STAGGER, function()
					Tween(block, { GroupTransparency = 1, Position = UDim2.fromOffset(0, 12) }, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
					if block == DividerBlock then
						Tween(DividerLine, { Size = UDim2.new(0, 0, 0, 1) }, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
					elseif block == ProgressBlock then
						Tween(BarTrack, { Size = UDim2.new(0, 0, 0, 6) }, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
					end
				end)
			end
			task.wait(#Blocks * EXIT_STAGGER + 0.05)

			shell:Hide(function()
				Loader.Destroyed = true
				if Compat.Env.MugiwaraLoader == Loader then
					Compat.Env.MugiwaraLoader = nil
				end
				closed:Fire()
			end)
		end)
	end

	Loader.FinishEvent:Connect(function(message)
		Loader:Finish(message)
	end)

	-- reachable from other scripts (executor)
	Compat.Env.MugiwaraLoader = Loader
	library._loader = Loader

	--// enter animation ---------------------------------------------------------------------
	shell:Show()

	-- blocks slide up + fade in one after another; the divider and the bar grow as their block shows
	for index, block in ipairs(Blocks) do
		task.delay(0.2 + (index - 1) * ENTER_STAGGER, function()
			if not block.Parent then
				return
			end
			Tween(block, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.5)
			if block == DividerBlock then
				Tween(DividerLine, { Size = DIVIDER_SIZE }, 0.6)
			elseif block == ProgressBlock then
				Tween(BarTrack, { Size = BAR_SIZE }, 0.6)
			end
		end)
	end
	task.delay(0.25, scrambleText, Title, config.Title, 0.9)

	task.delay(0.3, function()
		addLog("Booting " .. config.Title .. ((config.Version and config.Version ~= "") and (" " .. config.Version) or ""), "ok")
	end)

	-- fake log loop, runs until Finish
	task.spawn(function()
		task.wait(0.9)
		local index = 0
		while not state.finishing and shell.Gui.Parent do
			index = index % #config.Logs + 1
			local entry = addLog(config.Logs[index] .. "...", "info")
			task.wait(math.random(40, 95) / 100)
			if state.finishing then
				break
			end

			-- now and then a "warning" so it looks real
			if math.random() < 0.12 then
				completeLog(entry, "RETRY", C.warn)
				task.wait(0.3)
				addLog("Packet timeout, retrying connection", "warn")
			else
				completeLog(entry, "OK", C.ok)
			end
			task.wait(math.random(15, 40) / 100)
		end
	end)

	-- small glitch on the title every few seconds
	task.spawn(function()
		while shell.Gui.Parent and not state.finishing do
			task.wait(math.random(35, 65) / 10)
			if not state.finishing and not state.titleBusy and Title.Parent then
				local original = config.Title
				local position = math.random(1, #original)
				local pick = math.random(1, #SCRAMBLE_CHARS)
				Title.Text = string.sub(original, 1, position - 1) .. string.sub(SCRAMBLE_CHARS, pick, pick) .. string.sub(original, position + 1)
				Title.Position = UDim2.fromOffset(22, 16)
				task.wait(0.06)
				Title.Position = UDim2.fromOffset(19, 16)
				task.wait(0.05)
				Title.Position = UDim2.fromOffset(20, 16)
				Title.Text = original
			end
		end
	end)

	return Loader
end
end

__modules["components/Neon"] = function(Import)
--// Neon: the shared look of every Mugiwara surface (Window, Key UI, Loading UI):
--// soft glow rings, a rotating gradient border and the glass wash + sheen layers.

local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create = Utility.Create
local WHITE = Color3.new(1, 1, 1)

local Neon = {}

-- Concentric strokes around the surface fake a soft neon glow without any image asset.
local LAYERS = {
	{ pad = 0, thickness = 3, transparency = 0.5 },
	{ pad = 3, thickness = 7, transparency = 0.8 },
	{ pad = 10, thickness = 14, transparency = 0.92 },
}

-- Glow rings behind the surface. Returns { { Stroke, Base } } so callers can fade them in and out.
function Neon.Glow(parent, theme, maid, radius)
	local entries = {}
	for _, layer in ipairs(LAYERS) do
		local ring = Create("Frame", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, layer.pad * 2, 1, layer.pad * 2),
			BackgroundTransparency = 1,
			Parent = parent,
		})
		Utility.Corner(ring, radius + layer.pad)
		local stroke = Utility.Stroke(ring, WHITE, layer.transparency, layer.thickness)
		Utility.Spin(maid, Base.Gradient(theme, stroke, 0, "CycleSeq"), 9)
		table.insert(entries, { Stroke = stroke, Base = layer.transparency })
	end
	return entries
end

-- Thin rotating border drawn above the surface.
function Neon.Border(parent, theme, maid, radius, zindex)
	local border = Create("Frame", {
		Name = "Border",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = zindex or 5,
		Parent = parent,
	})
	Utility.Corner(border, radius)
	local stroke = Utility.Stroke(border, WHITE, 0.3, 1.5)
	Utility.Spin(maid, Base.Gradient(theme, stroke, 0, "CycleSeq"), 9)
	return { Stroke = stroke, Base = 0.3 }
end

-- Accent wash + glass sheen inside a surface.
-- One UIGradient per instance: Roblox ignores extra ones, so color and transparency share it.
function Neon.Glass(surface, theme)
	local wash = Create("Frame", { Name = "Wash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = surface })
	Base.Gradient(theme, wash, 35).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.86),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.9),
	})

	local sheen = Create("Frame", { Name = "Sheen", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = surface })
	Create("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.92),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(1, 0.97),
		}),
		Parent = sheen,
	})
end

return Neon
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
		Font = Utility.Fonts.Title,
		TextSize = 15,
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
			Font = Utility.Fonts.Desc,
			TextSize = 13,
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

-- opts: Width, Padding (14), Gap (10), Dim (default true), AnchorPoint, Position, OnClose
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
	Utility.Padding(card, opts.Padding or 14)
	Utility.List(card, opts.Gap or 10)

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

__modules["components/Shell"] = function(Import)
--// Shell: a centered glass card with the Mugiwara neon look, its own ScreenGui and open / close
--// animations. The Key UI and the Loading UI are built on it (the main Window has its own chrome).

local HttpService = game:GetService("HttpService")

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Neon = Import("components/Neon")

local Create, Tween = Utility.Create, Utility.Tween

local RADIUS = 16

local Shell = {}
Shell.__index = Shell

-- opts: Name, Size (Vector2), Backdrop (transparency to dim to, nil = none), InstantBackdrop,
--       IgnoreGuiInset, MinScale, MaxScale, Glow (default true)
function Shell.new(library, opts)
	local theme = library.Theme
	local self = setmetatable({}, Shell)
	self.Library = library
	self.Theme = theme
	self.Maid = Utility.Maid.new()
	self.DesignSize = opts.Size
	self.MinScale = opts.MinScale or 0.4
	self.MaxScale = opts.MaxScale or 1
	self.BackdropTarget = opts.Backdrop
	self.Neon = {}
	local maid = self.Maid

	local gui = Create("ScreenGui", {
		Name = "MugiwaraUI_" .. (opts.Name or "Shell") .. "_" .. string.sub(HttpService:GenerateGUID(false), 1, 8),
		ResetOnSpawn = false,
		IgnoreGuiInset = opts.IgnoreGuiInset == true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10002,
	})
	Compat.Protect(gui)
	gui.Parent = Compat.GetGuiParent()
	maid:Give(gui)
	self.Gui = gui

	if opts.Backdrop then
		self.Backdrop = Create("Frame", {
			Name = "Backdrop",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(8, 4, 2),
			BackgroundTransparency = opts.InstantBackdrop and opts.Backdrop or 1,
			Parent = gui,
		})
	end

	local main = Create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self.DesignSize.X, self.DesignSize.Y),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	self.Main = main
	self.UIScale = Create("UIScale", { Parent = main })

	-- centered anchor: UIScale scales around the anchor point, so the pop animation grows from the middle
	local pop = Create("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = main,
	})
	self.Pop = pop
	self.PopScale = Create("UIScale", { Scale = 0.88, Parent = pop })

	if opts.Glow ~= false then
		self.Neon = Neon.Glow(pop, theme, maid, RADIUS)
	end

	local card = Create("CanvasGroup", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		GroupTransparency = 1,
		Parent = pop,
	})
	Utility.Corner(card, RADIUS)
	theme:Bind(card, { BackgroundColor3 = "Popup", BackgroundTransparency = "PopupAlpha" })
	Neon.Glass(card, theme)
	self.Card = card

	table.insert(self.Neon, Neon.Border(pop, theme, maid, RADIUS, 5))
	for _, entry in ipairs(self.Neon) do
		entry.Stroke.Transparency = 1
	end

	maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end))
	self:_fit()
	return self
end

function Shell:_fit()
	local area = self.Gui.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		local camera = workspace.CurrentCamera
		area = camera and camera.ViewportSize or Vector2.new(1280, 720)
	end
	local fit = math.min((area.X - 32) / self.DesignSize.X, (area.Y - 32) / self.DesignSize.Y)
	self.UIScale.Scale = Utility.Clamp(fit, self.MinScale, self.MaxScale)
end

function Shell:Show()
	if self.Backdrop and self.Backdrop.BackgroundTransparency > self.BackdropTarget then
		Tween(self.Backdrop, { BackgroundTransparency = self.BackdropTarget }, 0.5)
	end
	Tween(self.PopScale, { Scale = 1 }, 0.7, Enum.EasingStyle.Back)
	Tween(self.Card, { GroupTransparency = 0 }, 0.5)
	for _, entry in ipairs(self.Neon) do
		Tween(entry.Stroke, { Transparency = entry.Base }, 0.5)
	end
end

-- Plays the exit animation, then destroys everything and calls onDone.
function Shell:Hide(onDone)
	if self.Hiding then
		return
	end
	self.Hiding = true
	Tween(self.PopScale, { Scale = 0.88 }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Tween(self.Card, { GroupTransparency = 1 }, 0.35)
	for _, entry in ipairs(self.Neon) do
		Tween(entry.Stroke, { Transparency = 1 }, 0.3)
	end
	if self.Backdrop then
		Tween(self.Backdrop, { BackgroundTransparency = 1 }, 0.4)
	end
	task.delay(0.45, function()
		self:Destroy()
		if onDone then
			onDone()
		end
	end)
end

function Shell:Destroy()
	self.Maid:Clean()
end

return Shell
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
	local iconImage, iconLetter = Icons.Create(opts.Icon, iconBox), nil
	if iconImage then
		Icons.Tint(iconImage, theme.Tokens.SubText)
		self.IconLabel = iconImage
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

		Tween(background, { BackgroundTransparency = state and 0.8 or 1 }, 0.25)
		Tween(indicator, { Size = UDim2.fromOffset(3, state and 18 or 0) }, 0.3, Enum.EasingStyle.Back)
		Tween(label, { TextColor3 = tint }, 0.2)
		if iconImage then
			Icons.Tint(iconImage, tint, 0.2)
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
			Icons.Tint(iconImage, tint)
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
		TextSize = 11,
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
local Neon = Import("components/Neon")

local Create, Tween = Utility.Create, Utility.Tween
local WHITE = Color3.new(1, 1, 1)

local TOPBAR = 54
local FOOTER = 56
local MARGIN = 24 -- breathing room kept around a maximized window
local MORPH_TIME = 0.45

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

-- opts: Title, Subtitle, Version, Icon, Size, MinSize, MaxSize, Resizable, Folder, ToggleKey, Blur,
--       Neon, OpenButton, ConfirmClose, ShowUser, SideBarWidth, ThemeSwitcher, Background, Theme
function Window.new(library, opts)
	opts = opts or {}
	local theme = library.Theme
	if opts.Theme then
		theme:Set(opts.Theme) -- unknown names are ignored
	end

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
	local minSize = toVector(opts.MinSize, Vector2.new(480, 340))
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

	--// neon glow (rings behind the window); entries are faded in / out by Open / Close
	self.Neon = opts.Neon ~= false and Neon.Glow(pop, theme, maid, 16) or {}

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

	Neon.Glass(win, theme)

	--// neon border (above the window)
	table.insert(self.Neon, Neon.Border(pop, theme, maid, 16, 5))

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
	-- Icon: asset id (full color logo) or an icon-set name such as "lucide:sun" (tinted on the gradient badge)
	local logo, monochrome
	if opts.Icon then
		local slot = Create("Frame", {
			Name = "Logo",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = brand,
		})
		logo, monochrome = Icons.Create(opts.Icon, slot)
		if not logo then
			slot:Destroy()
		elseif monochrome then
			slot.Size = UDim2.fromOffset(18, 18)
			Base.Gradient(theme, brand, 45)
			Icons.BindImage(theme, logo, "OnAccent")
		else
			brand.BackgroundTransparency = 1
		end
	end
	if not logo then
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
		Size = UDim2.new(1, -240, 0, hasSubtitle and 22 or TOPBAR),
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
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = versionPill,
	})
	theme:Bind(versionLabel, { TextColor3 = "OnAccent" })
	self.VersionPill = versionPill
	self.VersionLabel = versionLabel

	if hasSubtitle then
		local subtitle = Create("TextLabel", {
			Position = UDim2.new(0, 56, 0, 30),
			Size = UDim2.new(1, -240, 0, 14),
			Text = opts.Subtitle or opts.Author,
			Font = Utility.Fonts.Desc,
			TextSize = 12,
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

	-- 34x34 hit area; glyphs are centered inside it
	local function controlButton(offset)
		local button = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			Parent = topbar,
		})
		Utility.Corner(button, 9)
		return button
	end

	local closeButton = controlButton(-12)
	local closeGlyph = Icons.Bind(theme, Icons.Close(closeButton, 20, 2), "SubText")
	hoverFeedback(closeButton, { closeGlyph }, "Danger")

	local maximizeButton = controlButton(-50)
	local squareGlyph = Icons.Bind(theme, Icons.Square(maximizeButton, 20, 2), "SubText")
	local restoreGlyph = Icons.Bind(theme, Icons.Restore(maximizeButton, 20, 2), "SubText")
	restoreGlyph.Visible = false
	hoverFeedback(maximizeButton, { squareGlyph, restoreGlyph }, nil)
	self._squareGlyph, self._restoreGlyph = squareGlyph, restoreGlyph

	local minimizeButton = controlButton(-88)
	local minusGlyph = Icons.Bind(theme, Icons.Minus(minimizeButton, 20, 2), "SubText")
	hoverFeedback(minimizeButton, { minusGlyph }, nil)

	local themeButton
	if opts.ThemeSwitcher ~= false then
		themeButton = controlButton(-126)
		-- ring + inner dot, sized to match the other 20px glyphs
		local ring = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Parent = themeButton,
		})
		Utility.Corner(ring, Utility.Pill)
		local ringStroke = Utility.Stroke(ring, WHITE, 0.2, 2)
		Base.Gradient(theme, ringStroke, 45)
		local dot = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = WHITE,
			Parent = ring,
		})
		Utility.Corner(dot, Utility.Pill)
		Base.Gradient(theme, dot, 45)
		themeButton.MouseEnter:Connect(function()
			Tween(themeButton, { BackgroundTransparency = 0.88 }, 0.15)
			Tween(dot, { Size = UDim2.fromOffset(13, 13) }, 0.25, Enum.EasingStyle.Back)
		end)
		themeButton.MouseLeave:Connect(function()
			Tween(themeButton, { BackgroundTransparency = 1 }, 0.2)
			Tween(dot, { Size = UDim2.fromOffset(10, 10) }, 0.2)
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
			Font = Utility.Fonts.Desc,
			TextSize = 12,
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
		Utility.Spin(maid, Base.Gradient(theme, ring, 0, "CycleSeq"), 6)
		local halo = Utility.Stroke(button, WHITE, 0.7, 6)
		Utility.Spin(maid, Base.Gradient(theme, halo, 0, "CycleSeq"), 6)

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
		TextSize = 11,
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
			Font = selected and Enum.Font.GothamBold or Utility.Fonts.Label,
			TextSize = 14,
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
		TextSize = 11,
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

__modules["components/elements/Chat"] = function(Import)
--// Chat: live chat between everyone running your hub. Shows Roblox names + avatars, keeps history,
--// supports replies and deleting your own messages. It talks to a backend through a transport
--// (see components/ChatTransports.lua); it never touches the network itself.
--//
--//   tab:Chat({
--//       Title = "Live Chat",
--//       Transport = MugiwaraUI.ChatTransports.Http({ Url = "https://mugiwara-chat.you.workers.dev" }),
--//   })

local Players = game:GetService("Players")

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Icons = Import("core/Icons")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween
local WHITE = Color3.new(1, 1, 1)

-- headshots are cached for the whole session (every chat shares them)
local avatars = {}
local function loadAvatar(userId, apply)
	if avatars[userId] then
		apply(avatars[userId])
		return
	end
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		if ok and image then
			avatars[userId] = image
			apply(image)
		end
	end)
end

local function formatTime(stamp)
	if type(stamp) ~= "number" then
		return ""
	end
	if os.time() - stamp > 86400 then
		return os.date("%d/%m %H:%M", stamp)
	end
	return os.date("%H:%M", stamp)
end

local function trim(text)
	text = string.gsub(tostring(text or ""), "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

local function hex(color)
	return "#" .. Utility.ToHex(color)
end

-- opts: Title, Icon, Transport (required), Height (340), MaxLength (200), Cooldown (1.5 s between sends),
--       History (messages per page, 50), PollInterval (3 s while chatting), IdlePollInterval (8 s),
--       BackgroundPoll (seconds; keep polling this slowly while the chat is NOT on screen, so OnMessage can
--       notify. Default: stop polling when hidden, which saves free-tier requests),
--       Placeholder, OnMessage(message) (new messages from other people; called one at a time,
--       NotifySpacing seconds apart (0.8), and only for the newest NotifyLimit (5) of a burst)
-- Methods: Send(text), Refresh(), Clear(), Mute(userId), Unmute(userId), GetMuted(), GetMessages()
return function(container, opts)
	opts = opts or {}
	local transport = opts.Transport
	if type(transport) ~= "table" or type(transport.History) ~= "function" or type(transport.Send) ~= "function" then
		error("Chat needs a Transport, e.g. MugiwaraUI.ChatTransports.Http({ Url = ... })", 2)
	end

	local window = container.Window
	local theme = window.Theme
	local height = opts.Height or 340
	local maxLength = opts.MaxLength or 200
	local cooldown = opts.Cooldown or 1.5
	local fastPoll = opts.PollInterval or 3
	local slowPoll = opts.IdlePollInterval or 8
	local pageSize = opts.History or 50
	local notifySpacing = opts.NotifySpacing or 0.8
	local notifyLimit = opts.NotifyLimit or 5
	local me = transport.User or { UserId = 0, Name = "player", DisplayName = "Player" }

	local cardOpts = table.clone(opts)
	cardOpts.Title = opts.Title or "Live Chat"
	if cardOpts.Icon == nil then
		cardOpts.Icon = "lucide:message-circle"
	end
	local el = Base.Card(container, cardOpts, 124, 24)

	--// header status (right side of the title row) ------------------------------------
	local dot = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = theme.Tokens.Muted,
		Parent = el.Right,
	})
	Utility.Corner(dot, Utility.Pill)
	local statusLabel = Create("TextLabel", {
		Size = UDim2.new(1, -16, 1, 0),
		Text = "Connecting",
		Font = Utility.Fonts.Label,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = theme.Tokens.Muted,
		Parent = el.Right,
	})

	local connection = "connecting" -- connecting | live | offline
	local function paintStatus()
		local colors = { connecting = theme.Tokens.Muted, live = theme.Tokens.Success, offline = theme.Tokens.Danger }
		local labels = { connecting = "Connecting", live = "Live", offline = "Offline" }
		dot.BackgroundColor3 = colors[connection]
		statusLabel.TextColor3 = colors[connection]
		statusLabel.Text = labels[connection]
	end
	paintStatus()

	local noticeToken = 0
	-- short message in the header (errors, slow down...), then back to the connection state
	local function notice(text)
		noticeToken = noticeToken + 1
		local mine = noticeToken
		statusLabel.Text = text
		statusLabel.TextColor3 = theme.Tokens.Warning
		task.delay(3, function()
			if mine == noticeToken then
				paintStatus()
			end
		end)
	end

	--// message list ---------------------------------------------------------------------
	local listWrap = Create("Frame", {
		Name = "ChatList",
		Size = UDim2.new(1, 0, 0, height + 10),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = el.Content,
	})
	Utility.Padding(listWrap, 10, 0, 0, 0)
	local listBox = Base.Field(theme, listWrap)

	local scroll = Create("ScrollingFrame", { Size = UDim2.fromScale(1, 1), Parent = listBox })
	Utility.Padding(scroll, 8, 8, 8, 10)
	Utility.List(scroll, 4)

	local emptyLabel = Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = "No messages yet. Say hi!",
		Font = Utility.Fonts.Desc,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = listBox,
	})
	theme:Bind(emptyLabel, { TextColor3 = "Muted" })

	local olderButton = Create("TextButton", {
		Name = "LoadOlder",
		Size = UDim2.new(1, 0, 0, 28),
		Text = "Load older messages",
		Font = Utility.Fonts.Label,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = -1,
		Visible = false,
		Parent = scroll,
	})
	theme:Bind(olderButton, { TextColor3 = "SubText" })

	local newPill = Create("TextButton", {
		Name = "NewMessages",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		Text = "",
		Visible = false,
		ZIndex = 5,
		Parent = listBox,
	})
	Utility.Corner(newPill, Utility.Pill)
	Utility.Padding(newPill, 0, 0, 14, 14)
	Base.Gradient(theme, newPill, 0)
	local newPillText = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "New messages",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		ZIndex = 6,
		Parent = newPill,
	})
	theme:Bind(newPillText, { TextColor3 = "OnAccent" })

	--// reply bar + input -------------------------------------------------------------------
	local replyWrap = Create("Frame", {
		Name = "ReplyBar",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Visible = false,
		LayoutOrder = 3,
		Parent = el.Content,
	})
	Utility.Padding(replyWrap, 10, 0, 0, 0)
	local replyBox = Base.Field(theme, replyWrap)
	local replyAccent = Create("Frame", {
		Position = UDim2.fromOffset(8, 7),
		Size = UDim2.new(0, 3, 1, -14),
		BackgroundColor3 = WHITE,
		Parent = replyBox,
	})
	Utility.Corner(replyAccent, Utility.Pill)
	Base.Gradient(theme, replyAccent, 90)
	local replyText = Create("TextLabel", {
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Font = Utility.Fonts.Desc,
		TextSize = 12,
		RichText = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = replyBox,
	})
	theme:Bind(replyText, { TextColor3 = "SubText" })
	local replyClose = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		Parent = replyBox,
	})
	Icons.Bind(theme, Icons.Close(replyClose, 14, 2), "SubText")

	local inputWrap = Create("Frame", {
		Name = "Input",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = el.Content,
	})
	Utility.Padding(inputWrap, 10, 0, 0, 0)
	local inputField, inputStroke = Base.Field(theme, inputWrap, UDim2.new(1, -84, 1, 0))
	local box = Create("TextBox", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = "",
		PlaceholderText = opts.Placeholder or "Message...",
		Font = Utility.Fonts.Body,
		TextSize = 14,
		ClearTextOnFocus = false,
		Parent = inputField,
	})
	theme:Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })

	local sendHolder = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 76, 1, 0),
		BackgroundTransparency = 1,
		Parent = inputWrap,
	})
	local sendButton = Create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		Parent = sendHolder,
	})
	Utility.Corner(sendButton, 9)
	Base.Gradient(theme, sendButton, 0)
	local sendLabel = Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = "Send",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = sendButton,
	})
	theme:Bind(sendLabel, { TextColor3 = "OnAccent" })

	--// state ---------------------------------------------------------------------------------
	local byId, rows = {}, {}
	local muted = {}
	local oldestId, hasMore = nil, false
	local cursor = nil
	local loaded = false
	local alive = true
	local sending = false
	local lastSent = -math.huge
	local lastActivity = -math.huge
	local replyTarget, selectedId
	local pendingNew = 0

	local function rowCount()
		local count = 0
		for _ in pairs(rows) do
			count = count + 1
		end
		return count
	end

	local function refreshEmpty()
		emptyLabel.Visible = loaded and rowCount() == 0
		olderButton.Visible = hasMore
	end

	local function isNearBottom()
		return scroll.CanvasPosition.Y + scroll.AbsoluteWindowSize.Y >= scroll.AbsoluteCanvasSize.Y - 40
	end

	local function scrollToBottom()
		pendingNew = 0
		newPill.Visible = false
		task.delay(0.05, function()
			if scroll.Parent then
				scroll.CanvasPosition = Vector2.new(0, math.max(scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y, 0))
			end
		end)
	end

	--// rows -------------------------------------------------------------------------------------
	local function replyPreview(message)
		local reply = message.Reply
		if not reply then
			return nil
		end
		local original = byId[reply.Id]
		local text = (original and original.Deleted) and "Message deleted" or (reply.Text or "")
		return Utility.EscapeRich(tostring(reply.Name or "?")) .. ": " .. Utility.EscapeRich(text)
	end

	local selectRow
	local deleteMessage

	local function setReply(message)
		replyTarget = message
		if message then
			replyText.Text = "Replying to <b>" .. Utility.EscapeRich(message.DisplayName or message.Name) .. "</b>  " .. Utility.EscapeRich(string.sub(message.Text, 1, 80))
			replyWrap.Visible = true
		else
			replyWrap.Visible = false
		end
	end

	local function pill(parent, text, order, onClick)
		local button = Create("TextButton", {
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = WHITE,
			Text = "",
			LayoutOrder = order,
			Parent = parent,
		})
		Utility.Corner(button, 8)
		Utility.Padding(button, 0, 0, 10, 10)
		theme:Bind(button, { BackgroundColor3 = "Card", BackgroundTransparency = "CardHoverAlpha" })
		local label = Create("TextLabel", {
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			Parent = button,
		})
		theme:Bind(label, { TextColor3 = "Text" })
		button.MouseButton1Click:Connect(onClick)
		return button
	end

	local function paintRow(row)
		local message = row.Message
		local mine = message.UserId == me.UserId
		row.Text.Text = message.Deleted and "Message deleted" or message.Text
		row.Text.TextColor3 = message.Deleted and theme.Tokens.Muted or theme.Tokens.Text
		row.Frame.BackgroundTransparency = mine and 0.9 or 1

		-- actions (only for a selected, living message)
		row.Actions.Visible = selectedId == message.Id and not message.Deleted
	end

	local function createRow(message)
		local mine = message.UserId == me.UserId
		local frame = Create("TextButton", {
			Name = "Message" .. tostring(message.Id),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = theme.Tokens.Accent,
			BackgroundTransparency = mine and 0.9 or 1,
			LayoutOrder = message.Id,
			Parent = scroll,
		})
		Utility.Corner(frame, 8)
		Utility.Padding(frame, 6, 6, 6, 6)
		theme:Bind(frame, { BackgroundColor3 = "Accent" })

		local avatar = Create("ImageLabel", {
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.88,
			Parent = frame,
		})
		Utility.Corner(avatar, Utility.Pill)
		local initial = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(string.sub(message.DisplayName or message.Name or "?", 1, 1)),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = avatar,
		})
		theme:Bind(initial, { TextColor3 = "SubText" })
		loadAvatar(message.UserId, function(image)
			if avatar.Parent then
				avatar.Image = image
				initial.Visible = false
			end
		end)

		local body = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = frame,
		})
		Utility.Padding(body, 0, 0, 42, 0)
		Utility.List(body, 3)

		local header = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = string.format(
				'<b>%s</b>  <font color="%s">@%s</font>  <font color="%s">%s</font>',
				Utility.EscapeRich(message.DisplayName or message.Name),
				hex(theme.Tokens.Muted),
				Utility.EscapeRich(message.Name),
				hex(theme.Tokens.Muted),
				formatTime(message.Time)
			),
			Font = Utility.Fonts.Label,
			TextSize = 13,
			RichText = true,
			TextWrapped = true,
			LayoutOrder = 1,
			Parent = body,
		})
		theme:Bind(header, { TextColor3 = "Text" })

		local quoteLabel
		if message.Reply then
			local quote = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Parent = body,
			})
			Utility.Padding(quote, 0, 0, 10, 0)
			local bar = Create("Frame", {
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = WHITE,
				Parent = quote,
			})
			Utility.Corner(bar, Utility.Pill)
			theme:Bind(bar, { BackgroundColor3 = "Muted" })
			local quoteText = Create("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = replyPreview(message),
				Font = Utility.Fonts.Desc,
				TextSize = 12,
				RichText = true,
				TextWrapped = true,
				Parent = quote,
			})
			theme:Bind(quoteText, { TextColor3 = "SubText" })
			quoteLabel = quoteText
		end

		-- user text is NEVER parsed as RichText
		local text = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Utility.Fonts.Body,
			TextSize = 14,
			TextWrapped = true,
			RichText = false,
			LayoutOrder = 3,
			Parent = body,
		})

		local actions = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = false,
			LayoutOrder = 4,
			Parent = body,
		})
		Utility.Padding(actions, 4, 0, 0, 0)
		Utility.List(actions, 6, Enum.FillDirection.Horizontal)

		local row = { Frame = frame, Text = text, Actions = actions, Message = message, Quote = quoteLabel }

		pill(actions, "Reply", 1, function()
			setReply(row.Message)
			if box.Parent then
				box:CaptureFocus()
			end
		end)
		pill(actions, "Copy", 2, function()
			Compat.SetClipboard(row.Message.Text)
		end)
		if mine then
			pill(actions, "Delete", 3, function()
				deleteMessage(row.Message)
			end)
		else
			pill(actions, "Mute", 3, function()
				el:Mute(row.Message.UserId)
			end)
		end

		frame.MouseButton1Click:Connect(function()
			selectRow(message.Id)
		end)
		return row
	end

	selectRow = function(id)
		selectedId = (selectedId ~= id) and id or nil
		for _, row in pairs(rows) do
			paintRow(row)
		end
	end

	local function upsert(message)
		local known = byId[message.Id]
		if known and known.Deleted then
			message.Deleted = true -- a deletion never comes back
		end
		byId[message.Id] = message
		if muted[message.UserId] then
			if rows[message.Id] then
				rows[message.Id].Frame:Destroy()
				rows[message.Id] = nil
			end
			return known == nil
		end
		local row = rows[message.Id]
		if not row then
			row = createRow(message)
			rows[message.Id] = row
		end
		row.Message = message
		paintRow(row)
		return known == nil
	end

	-- replies whose original was deleted switch to "Message deleted"
	local function repaintQuotes()
		for _, row in pairs(rows) do
			if row.Quote then
				row.Quote.Text = replyPreview(row.Message)
			end
		end
	end

	-- New messages arrive in batches (everything since the last poll). OnMessage is fed through a queue so
	-- toasts show up one by one instead of all at once; a long backlog only notifies for the newest few.
	local notifyQueue, notifying = {}, false
	local function drainNotifications()
		if notifying then
			return
		end
		notifying = true
		task.spawn(function()
			while alive and #notifyQueue > 0 do
				Utility.SafeCall(opts.OnMessage, table.remove(notifyQueue, 1))
				if #notifyQueue > 0 then
					task.wait(notifySpacing)
				end
			end
			notifying = false
		end)
	end
	local function queueNotification(message)
		if type(opts.OnMessage) ~= "function" or muted[message.UserId] then
			return
		end
		table.insert(notifyQueue, message)
		while #notifyQueue > notifyLimit do
			table.remove(notifyQueue, 1)
		end
	end

	-- mode: "history" (first load), "older" (prepended page) or "live" (poll results)
	local function apply(list, mode)
		local wasNear = isNearBottom()
		local oldCanvas = scroll.AbsoluteCanvasSize.Y
		local fresh, fromOthers = 0, 0

		for _, message in ipairs(list) do
			local isNew = upsert(message)
			if message.Id and (oldestId == nil or message.Id < oldestId) then
				oldestId = message.Id
			end
			if isNew and mode == "live" then
				fresh = fresh + 1
				if message.UserId ~= me.UserId then
					fromOthers = fromOthers + 1
					queueNotification(message)
				end
			end
		end
		repaintQuotes()
		refreshEmpty()
		-- start delivering only after the whole batch is queued, otherwise the first message goes out alone
		-- and the rest of the same batch would each start their own delivery
		drainNotifications()

		if mode == "older" then
			-- keep the reading position when older messages appear above
			task.delay(0.05, function()
				if scroll.Parent then
					local grown = scroll.AbsoluteCanvasSize.Y - oldCanvas
					scroll.CanvasPosition = Vector2.new(0, scroll.CanvasPosition.Y + grown)
				end
			end)
		elseif fresh > 0 then
			lastActivity = os.clock()
			if wasNear then
				scrollToBottom()
			elseif fromOthers > 0 then
				pendingNew = pendingNew + fromOthers
				newPillText.Text = pendingNew == 1 and "1 new message" or (pendingNew .. " new messages")
				newPill.Visible = true
			end
		end
	end

	--// network ---------------------------------------------------------------------------------
	local function setConnection(state)
		connection = state
		paintStatus()
	end

	local function loadHistory()
		local result, reason = transport:History({ Limit = pageSize })
		if not result then
			setConnection("offline")
			return false, reason
		end
		cursor = result.Cursor
		hasMore = result.More == true
		apply(result.Messages, "history")
		loaded = true
		refreshEmpty()
		scrollToBottom()
		setConnection("live")
		return true
	end

	local loadingOlder = false
	local function loadOlder()
		if loadingOlder or not hasMore or not oldestId then
			return
		end
		loadingOlder = true
		olderButton.Text = "Loading..."
		task.spawn(function()
			local result = transport:History({ Limit = pageSize, Before = oldestId })
			loadingOlder = false
			olderButton.Text = "Load older messages"
			if result then
				hasMore = result.More == true
				apply(result.Messages, "older")
			else
				notice("Could not load older messages")
			end
		end)
	end

	local function isActive()
		if not window.Opened then
			return false
		end
		local node = el.Frame
		while node and node ~= window.Gui do
			if node:IsA("GuiObject") and not node.Visible then
				return false
			end
			node = node.Parent
		end
		return true
	end

	local function pollOnce()
		local result = transport:Poll(cursor)
		if not result then
			setConnection("offline")
			return false
		end
		cursor = result.Cursor
		apply(result.Messages, "live")
		if connection ~= "live" then
			setConnection("live")
		end
		return true
	end

	function el:Refresh()
		task.spawn(function()
			if loaded then
				pollOnce()
			else
				loadHistory()
			end
		end)
	end

	-- poll loop: only while the chat is actually on screen, faster while people are talking
	task.spawn(function()
		local failures = 0
		while alive and el.Frame:IsDescendantOf(game) do
			local waitFor = 1
			local active = isActive()
			if active or opts.BackgroundPoll then
				local ok
				if not loaded then
					ok = loadHistory()
				else
					ok = pollOnce()
				end
				if ok then
					failures = 0
					if active then
						waitFor = (os.clock() - lastActivity < 20) and fastPoll or slowPoll
					else
						waitFor = opts.BackgroundPoll
					end
				else
					failures = failures + 1
					waitFor = math.min(slowPoll * (2 ^ failures), 30)
				end
			end
			task.wait(waitFor)
		end
	end)

	--// actions -------------------------------------------------------------------------------------
	local function doSend(raw)
		local text = trim(raw)
		if text == "" or sending then
			return
		end
		if #text > maxLength then
			text = string.sub(text, 1, maxLength)
		end
		if os.clock() - lastSent < cooldown then
			notice("Slow down a little")
			return
		end

		sending = true
		sendLabel.Text = "..."
		local replyId = replyTarget and replyTarget.Id or nil

		task.spawn(function()
			local message, reason = transport:Send({ Text = text, ReplyTo = replyId })
			sending = false
			sendLabel.Text = "Send"
			if not message then
				notice(reason or "Could not send")
				return
			end
			lastSent = os.clock()
			lastActivity = os.clock()
			box.Text = ""
			setReply(nil)
			loaded = true
			upsert(message)
			refreshEmpty()
			scrollToBottom()
		end)
	end

	deleteMessage = function(message)
		task.spawn(function()
			local ok, reason = transport:Delete(message.Id)
			if not ok then
				notice(reason or "Could not delete")
				return
			end
			message.Deleted = true
			message.Text = ""
			selectedId = nil
			upsert(message)
			repaintQuotes()
		end)
	end

	function el:Send(text)
		doSend(text)
	end

	function el:Clear()
		for _, row in pairs(rows) do
			row.Frame:Destroy()
		end
		rows, byId = {}, {}
		refreshEmpty()
	end

	function el:Mute(userId)
		muted[userId] = true
		for id, row in pairs(rows) do
			if row.Message.UserId == userId then
				row.Frame:Destroy()
				rows[id] = nil
			end
		end
		refreshEmpty()
	end

	function el:Unmute(userId)
		muted[userId] = nil
		for _, message in pairs(byId) do
			if message.UserId == userId then
				upsert(message)
			end
		end
		refreshEmpty()
	end

	function el:GetMuted()
		local list = {}
		for userId in pairs(muted) do
			table.insert(list, userId)
		end
		table.sort(list)
		return list
	end

	function el:GetMessages()
		local list = {}
		for _, message in pairs(byId) do
			table.insert(list, message)
		end
		table.sort(list, function(a, b)
			return a.Id < b.Id
		end)
		return list
	end

	--// wiring --------------------------------------------------------------------------------------
	el.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > maxLength then
			box.Text = string.sub(box.Text, 1, maxLength)
		end
	end))
	el.Maid:Give(box.Focused:Connect(function()
		Tween(inputStroke, { Transparency = 0.2 }, 0.2)
		inputStroke.Color = theme.Tokens.Accent
	end))
	el.Maid:Give(box.FocusLost:Connect(function(enterPressed)
		Tween(inputStroke, { Transparency = theme.Tokens.StrokeAlpha }, 0.2)
		inputStroke.Color = theme.Tokens.Stroke
		if enterPressed then
			doSend(box.Text)
		end
	end))
	el.Maid:Give(sendButton.MouseButton1Click:Connect(function()
		Tween(sendButton, { Size = UDim2.new(1, -6, 1, -6) }, 0.08)
		task.delay(0.09, function()
			if sendButton.Parent then
				Tween(sendButton, { Size = UDim2.fromScale(1, 1) }, 0.3, Enum.EasingStyle.Back)
			end
		end)
		doSend(box.Text)
	end))
	el.Maid:Give(replyClose.MouseButton1Click:Connect(function()
		setReply(nil)
	end))
	el.Maid:Give(olderButton.MouseButton1Click:Connect(loadOlder))
	el.Maid:Give(newPill.MouseButton1Click:Connect(scrollToBottom))
	el.Maid:Give(scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if newPill.Visible and isNearBottom() then
			pendingNew = 0
			newPill.Visible = false
		end
	end))

	el.Maid:Give(function()
		alive = false
		if type(transport.Destroy) == "function" then
			pcall(transport.Destroy, transport)
		end
	end)

	el.Transport = transport
	el.Scroll = scroll
	el.Box = box
	el.SendButton = sendButton
	el.Rows = rows
	el.ReplyBar = replyWrap
	el.OlderButton = olderButton
	el.NewPill = newPill
	el.Status = statusLabel
	el.SelectRow = selectRow

	return Base.Finish(container, el, opts, "Chat")
end
end

__modules["components/elements/Code"] = function(Import)
local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Base = Import("components/Base")

local Create = Utility.Create

local KEYWORDS = {}
for word in string.gmatch(
	"and break do else elseif end false for function goto if in local nil not or repeat return then true until while continue",
	"%a+"
) do
	KEYWORDS[word] = true
end

-- RichText needs & < > escaped
local function escape(text)
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	return text
end

local function hex(color)
	return "#" .. Utility.ToHex(color)
end

-- Small Lua highlighter: comments, strings, numbers, keywords. Returns RichText.
local function highlight(code, tokens)
	local colors = {
		comment = hex(tokens.Muted),
		string = hex(tokens.Success),
		number = hex(tokens.Warning),
		keyword = hex(tokens.Accent),
		default = hex(tokens.Text),
	}
	local out = {}
	local function emit(kind, text)
		table.insert(out, string.format('<font color="%s">%s</font>', colors[kind], escape(text)))
	end

	local index, length = 1, #code
	while index <= length do
		local char = string.sub(code, index, index)
		local two = string.sub(code, index, index + 1)

		if two == "--" then
			local longClose = string.match(code, "^%-%-%[(=*)%[", index) -- --[[ ... ]]
			local stop
			if longClose then
				local _, closeEnd = string.find(code, "]" .. longClose .. "]", index, true)
				stop = closeEnd or length
			else
				stop = (string.find(code, "\n", index, true) or (length + 1)) - 1
			end
			emit("comment", string.sub(code, index, stop))
			index = stop + 1
		elseif char == '"' or char == "'" then
			local stop = index + 1
			while stop <= length do
				local current = string.sub(code, stop, stop)
				if current == "\\" then
					stop = stop + 2
				elseif current == char or current == "\n" then
					break
				else
					stop = stop + 1
				end
			end
			emit("string", string.sub(code, index, math.min(stop, length)))
			index = stop + 1
		elseif string.find(code, "^%[=*%[", index) then
			local level = string.match(code, "^%[(=*)%[", index)
			local _, closeEnd = string.find(code, "]" .. level .. "]", index, true)
			local stop = closeEnd or length
			emit("string", string.sub(code, index, stop))
			index = stop + 1
		elseif string.find(char, "%d") and not string.find(string.sub(code, index - 1, index - 1), "[%w_]") then
			local number = string.match(code, "^0[xX]%x+", index) or string.match(code, "^%d+%.?%d*", index)
			emit("number", number)
			index = index + #number
		elseif string.find(char, "[%a_]") then
			local word = string.match(code, "^[%w_]+", index)
			emit(KEYWORDS[word] and "keyword" or "default", word)
			index = index + #word
		else
			emit("default", char)
			index = index + 1
		end
	end
	return table.concat(out)
end

-- opts: Title, Desc, Code, Language ("lua" highlights; anything else is plain), Copy (default true),
--       Height (max pixel height of the code area, default 220)
-- el:Set(code) replaces the code, el:Get() returns it.
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local showCopy = opts.Copy ~= false
	local el = Base.Card(container, opts, showCopy and 76 or nil, 30)

	local code = tostring(opts.Code or "")
	local lines = select(2, string.gsub(code, "\n", "\n")) + 1
	local maxHeight = opts.Height or 220
	local hasHeader = el.Top.Visible
	local extra = Base.Extra(el, math.min(math.max(lines * 16 + 22, 56), maxHeight), hasHeader and 10 or 0)

	local box = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ClipsDescendants = true,
		Parent = extra,
	})
	Utility.Corner(box, 8)
	theme:Bind(box, { BackgroundColor3 = "Field", BackgroundTransparency = "FieldAlpha" })
	local boxStroke = Utility.Stroke(box, Color3.new(1, 1, 1), 0.9, 1)
	theme:Bind(boxStroke, { Color = "Stroke", Transparency = "StrokeAlpha" })

	-- scrolls both ways: long lines are not wrapped
	local scroll = Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ScrollingDirection = Enum.ScrollingDirection.XY,
		ScrollBarThickness = 3,
		Parent = box,
	})
	Utility.Padding(scroll, 10, 10, 12, 12)

	local text = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Font = Enum.Font.Code,
		TextSize = 13,
		RichText = true,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = scroll,
	})
	theme:Bind(text, { TextColor3 = "Text" })
	el.TextLabel = text

	local function render()
		if (opts.Language or "lua") == "lua" then
			text.Text = highlight(code, theme.Tokens)
		else
			text.Text = escape(code)
		end
	end
	render()
	el.Value = code
	el.Maid:Give(theme:OnChange(render))

	function el:Set(newCode)
		code = tostring(newCode or "")
		self.Value = code
		render()
	end

	if showCopy then
		local copy = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(76, 30),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = "Copy",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = el.Right,
		})
		el.CopyButton = copy
		Utility.Corner(copy, 8)
		theme:Bind(copy, { BackgroundColor3 = "Card", BackgroundTransparency = "CardHoverAlpha", TextColor3 = "Text" })

		local token = 0
		el.Maid:Give(copy.MouseButton1Click:Connect(function()
			token = token + 1
			local mine = token
			copy.Text = Compat.SetClipboard(code) and "Copied" or "No clipboard"
			task.delay(1.3, function()
				if mine == token and copy.Parent then
					copy.Text = "Copy"
				end
			end)
		end))
	end

	return Base.Finish(container, el, opts, "Code")
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
local SQUARE = 168 -- saturation / value square
local BAR = 14 -- hue / opacity slider thickness (handles are wider than the bar on purpose)
local HANDLE = 22
local INNER = 230 -- content width of the popup (card width minus padding)
local GAP = 8 -- space between fields / tabs
local PAD = 16

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

-- Ring handle: white ring with the picked color inside, so it reads on any background.
local function marker(parent, size)
	local dot = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = WHITE,
		ZIndex = 5,
		Parent = parent,
	})
	Utility.Corner(dot, Utility.Pill)
	Utility.Stroke(dot, Color3.new(0, 0, 0), 0.55, 1)
	local fill = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = WHITE,
		ZIndex = 6,
		Parent = dot,
	})
	Utility.Corner(fill, Utility.Pill)
	return dot, fill
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
			ui.SquareFill.BackgroundColor3 = color
			ui.HueMarker.Position = UDim2.fromScale(0.5, hue)
			ui.HueFill.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			ui.AlphaBar.BackgroundColor3 = color
			ui.AlphaMarker.Position = UDim2.fromScale(0.5, 1 - alpha)
			ui.AlphaFill.BackgroundColor3 = color
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
		local alphaWidth = 60
		local fieldWidth = math.floor((INNER - alphaWidth - GAP * count) / count)

		for index = 1, count do
			local field = Base.Field(theme, row, UDim2.fromOffset(fieldWidth, 32))
			field.LayoutOrder = index
			local box = Create("TextBox", {
				Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
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

		local alphaField = Base.Field(theme, row, UDim2.fromOffset(alphaWidth, 32))
		alphaField.LayoutOrder = 10
		local alphaBox = Create("TextBox", {
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
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
			Width = INNER + PAD * 2,
			Padding = PAD,
			Gap = 12,
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
		local header = Create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
		local title = Create("TextLabel", {
			Size = UDim2.new(1, -90, 1, 0),
			Text = opts.Title or "Color",
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		Base.Gradient(theme, title, 0)

		ui.Preview = Create("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -38, 0.5, 0),
			Size = UDim2.fromOffset(36, 20),
			BackgroundColor3 = current(),
			Parent = header,
		})
		Utility.Corner(ui.Preview, 6)
		Utility.Stroke(ui.Preview, WHITE, 0.6, 1)

		local closeButton = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			Parent = header,
		})
		Utility.Corner(closeButton, 9)
		local closeGlyph = Icons.Close(closeButton, 18, 2)
		Icons.Bind(theme, closeGlyph, "SubText")
		closeButton.MouseEnter:Connect(function()
			Tween(closeButton, { BackgroundTransparency = 0.88 }, 0.15)
			Icons.SetColor(closeGlyph, theme.Tokens.Danger)
		end)
		closeButton.MouseLeave:Connect(function()
			Tween(closeButton, { BackgroundTransparency = 1 }, 0.2)
			Icons.SetColor(closeGlyph, theme.Tokens.SubText)
		end)
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
		ui.SquareMarker, ui.SquareFill = marker(ui.Square, 20)
		local squareHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = ui.Square })

		local hueBar = Create("Frame", {
			Position = UDim2.fromOffset(SQUARE + 16, 0),
			Size = UDim2.fromOffset(BAR, SQUARE),
			BackgroundColor3 = WHITE,
			Parent = area,
		})
		Utility.Corner(hueBar, Utility.Pill)
		Create("UIGradient", { Rotation = 90, Color = RAINBOW, Parent = hueBar })
		ui.HueMarker, ui.HueFill = marker(hueBar, HANDLE)
		local hueHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = hueBar })

		ui.AlphaBar = Create("Frame", {
			Position = UDim2.fromOffset(SQUARE + 16 + BAR + 16, 0),
			Size = UDim2.fromOffset(BAR, SQUARE),
			BackgroundColor3 = current(),
			Parent = area,
		})
		Utility.Corner(ui.AlphaBar, Utility.Pill)
		Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.95), Parent = ui.AlphaBar })
		Utility.Stroke(ui.AlphaBar, WHITE, 0.85, 1)
		ui.AlphaMarker, ui.AlphaFill = marker(ui.AlphaBar, HANDLE)
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
		local tabs = Create("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 3, Parent = card })
		Utility.List(tabs, GAP, Enum.FillDirection.Horizontal)
		local tabWidth = math.floor((INNER - GAP * (#MODES - 1)) / #MODES)
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
				Size = UDim2.fromOffset(tabWidth, 32),
				LayoutOrder = index,
				Parent = tabs,
			})
			local background = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = button })
			Utility.Corner(background, 9)
			Base.Gradient(theme, background, 0)
			local label = Create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Text = name,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
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
		row = Create("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 4, Parent = card })
		Utility.List(row, GAP, Enum.FillDirection.Horizontal)

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
end

__modules["components/elements/Image"] = function(Import)
local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

local SCALE_TYPES = {
	Crop = Enum.ScaleType.Crop,
	Fit = Enum.ScaleType.Fit,
	Stretch = Enum.ScaleType.Stretch,
}

-- opts: Image (asset id, rbxassetid://, or http(s) URL), Height (default 150), Scale ("Crop" | "Fit" | "Stretch"),
--       Title, Desc. Roblox Store ids are Decals: they are converted automatically (see Compat.ResolveImage).
-- el:SetImage(image) swaps the picture.
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local el = Base.Card(container, opts)

	local hasHeader = el.Top.Visible
	local extra = Base.Extra(el, opts.Height or 150, hasHeader and 10 or 0)

	local frame = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ClipsDescendants = true,
		Parent = extra,
	})
	Utility.Corner(frame, 8)
	theme:Bind(frame, { BackgroundColor3 = "Field", BackgroundTransparency = "FieldAlpha" })

	local image = Create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		ScaleType = SCALE_TYPES[opts.Scale or "Crop"] or Enum.ScaleType.Crop,
		ImageTransparency = 1,
		Visible = false,
		Parent = frame,
	})

	el.ImageLabel = image

	local note = Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = "Loading image...",
		Font = Utility.Fonts.Desc,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	theme:Bind(note, { TextColor3 = "Muted" })

	local version = 0

	function el:SetImage(source)
		version = version + 1
		local mine = version
		el.Value = source
		image.Visible = false
		note.Visible = true
		note.Text = "Loading image..."
		task.spawn(function()
			local asset, reason = Compat.ResolveImage(source, container.Window.Folder)
			if mine ~= version or not image.Parent then
				return
			end
			if not asset then
				note.Text = reason or "Image unavailable"
				return
			end
			image.Image = asset
			image.Visible = true
			Tween(image, { ImageTransparency = 0 }, 0.5)
			if Compat.ImageLoaded(image) == false and mine == version then
				image.Visible = false
				note.Text = "Roblox could not load this image"
			else
				note.Visible = false
			end
		end)
	end

	if opts.Image then
		el:SetImage(opts.Image)
	else
		note.Text = "No image"
	end

	return Base.Finish(container, el, opts, "Image")
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
		Font = Utility.Fonts.Body,
		TextSize = 13,
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
end

__modules["components/elements/ProgressBar"] = function(Import)
local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

-- opts: Title, Desc, Value (default 0), Min (0), Max (100), Suffix ("%")
-- el:Set(value) animates the bar; el:SetText("custom") replaces the value text.
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local min = opts.Min or 0
	local max = opts.Max or 100
	local suffix = opts.Suffix or "%"

	local el = Base.Card(container, opts, 70, 24)
	local extra = Base.Extra(el, 10)

	local valueLabel = Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = el.Right,
	})
	theme:Bind(valueLabel, { TextColor3 = "Text" })

	local rail = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = extra,
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

	local customText

	local function render(value, instant)
		local alpha = max == min and 0 or Utility.Clamp((value - min) / (max - min), 0, 1)
		valueLabel.Text = customText or (string.format("%d", math.floor(value + 0.5)) .. suffix)
		if instant then
			fill.Size = UDim2.fromScale(alpha, 1)
		else
			Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, 0.35)
		end
	end

	el.Value = Utility.Clamp(opts.Value or opts.Default or min, min, max)
	render(el.Value, true)

	function el:Set(value, instant)
		self.Value = Utility.Clamp(tonumber(value) or min, min, max)
		render(self.Value, instant == true)
	end

	function el:SetText(text)
		customText = text
		render(self.Value, true)
	end

	return Base.Finish(container, el, opts, "ProgressBar")
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
		TextSize = 13,
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
		local bounds = TextService:GetTextSize(caption, 11, Enum.Font.GothamBold, Vector2.new(1000, 20))
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
			TextSize = 11,
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

--// HTTP -----------------------------------------------------------------------
-- Plain GET for executors: game:HttpGet first, request() as a fallback. Returns the body or nil.
function Compat.HttpGet(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" and body ~= "" then
		return body
	end
	local requester = request or http_request or (syn and syn.request)
	if requester then
		local response = try(requester, { Url = url, Method = "GET" })
		if response and type(response.Body) == "string" and (response.StatusCode == nil or response.StatusCode == 200) then
			return response.Body
		end
	end
	return nil
end

-- Full request (method, headers, body). Returns the response table, or nil plus a reason.
function Compat.HttpRequest(options)
	local requester = request or http_request or (syn and syn.request)
	if not requester then
		return nil, "This executor has no request function"
	end
	local ok, response = pcall(requester, options)
	if not ok then
		return nil, tostring(response)
	end
	return response
end

--// Clipboard -----------------------------------------------------------------
-- Reading the clipboard is only offered by some executors; nil when unavailable.
Compat.GetClipboard = (getclipboard or readclipboard) and function()
	local reader = getclipboard or readclipboard
	local ok, text = pcall(reader)
	return ok and type(text) == "string" and text or nil
end or nil

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

__modules["core/IconSets"] = function(Import)
--// IconSets: icons from the Footagesus/Icons collection (https://github.com/Footagesus/Icons, MIT).
--//
--// Nothing is bundled. A set (a few hundred KB of asset ids) is downloaded the first time one of its
--// icons is used, then cached in the executor workspace so later runs work offline.
--// The download is pinned to one commit: a raw URL for a commit never changes, so the code that
--// gets executed on users' machines cannot be swapped by a later push to that repository.

local Compat = Import("core/Compat")
local Utility = Import("core/Utility")

local REPO = "Footagesus/Icons"
local COMMIT = "46d30c19ba7bc601d6ec794a48dc3a89568b1eec"
local CACHE_DIR = "MugiwaraUI/cache"
local RETRY_AFTER = 30 -- seconds before a failed download is attempted again

local IconSets = {}

IconSets.Default = "lucide"

-- "sfsymbols" exists in that repository but is left out on purpose: Apple's license only
-- allows SF Symbols in apps for Apple platforms.
IconSets.Available = { "lucide", "craft", "geist", "gravity", "solar" }

local allowed = {}
for _, name in ipairs(IconSets.Available) do
	allowed[name] = true
end

-- loaded sets live on the executor environment so re-running the script does not download again
local store = Compat.Env.__MugiwaraIconSets
if not store then
	store = {}
	Compat.Env.__MugiwaraIconSets = store
end
local failedAt = {}

local function sourceUrl(set)
	return string.format("https://raw.githubusercontent.com/%s/%s/%s/dist/Icons.lua", REPO, COMMIT, set)
end

local function cachePath(set)
	return string.format("%s/icons-%s-%s.lua", CACHE_DIR, set, string.sub(COMMIT, 1, 8))
end

-- A set file is a Lua table of data only (asset ids and Vector2 values).
local function readSet(set)
	local path = cachePath(set)
	local source = Compat.ReadFile(path)
	local fromCache = source ~= nil
	if not source then
		source = Compat.HttpGet(sourceUrl(set))
	end
	if not source or not loadstring then
		return nil
	end

	local compiled = loadstring(source)
	local ok, data = false, nil
	if compiled then
		ok, data = pcall(compiled)
	end
	if not ok or type(data) ~= "table" then
		if fromCache then
			Compat.DeleteFile(path) -- corrupted cache: next run downloads it again
		end
		return nil
	end

	if not fromCache then
		Compat.EnsureFolder(CACHE_DIR)
		Compat.WriteFile(path, source)
	end
	return data
end

-- Downloads (or reads from cache) a set. May yield on the first call. Returns the data or nil.
function IconSets.Load(set)
	if not allowed[set] then
		return nil
	end
	if store[set] then
		return store[set]
	end
	if failedAt[set] and os.clock() - failedAt[set] < RETRY_AFTER then
		return nil
	end
	local data = readSet(set)
	if data then
		store[set] = data
		failedAt[set] = nil
		return data
	end
	failedAt[set] = os.clock()
	return nil
end

-- Loads sets in the background so the first icon does not stall the UI build.
function IconSets.Preload(sets)
	task.spawn(function()
		for _, set in ipairs(sets or { IconSets.Default }) do
			IconSets.Load(set)
		end
	end)
end

function IconSets.SetDefault(set)
	set = string.lower(tostring(set))
	if not allowed[set] then
		return false
	end
	IconSets.Default = set
	return true
end

-- "house" -> default set; "craft:folder-stroke" -> that set; unknown prefix (or a disabled set) -> nil
function IconSets.Parse(icon)
	if type(icon) ~= "string" then
		return nil
	end
	local set, name = string.match(icon, "^(%w+):(.+)$")
	if set then
		set = string.lower(set)
		if allowed[set] then
			return set, name
		end
		return nil
	end
	return IconSets.Default, icon
end

-- Turns a raw entry into { Image, RectSize, RectOffset, Parts }.
-- Flat sets map name -> "rbxassetid://..."; spritesheet sets (craft, geist) store a cell inside a sheet.
-- Parts are extra layers (duotone icons); they are resolved one level deep.
local function describe(data, name, depth)
	local entry = data.Icons and data.Icons[name]
	if entry then
		local sheet = data.Spritesheets and data.Spritesheets[tostring(entry.Image)] or entry.Image
		if type(sheet) == "number" then
			sheet = "rbxassetid://" .. sheet
		end
		local descriptor = {
			Image = sheet,
			RectSize = entry.ImageRectSize,
			RectOffset = entry.ImageRectPosition,
		}
		if entry.Parts and depth < 1 then
			descriptor.Parts = {}
			for _, partName in ipairs(entry.Parts) do
				local part = describe(data, partName, depth + 1)
				if part then
					table.insert(descriptor.Parts, part)
				end
			end
		end
		return descriptor
	end

	local flat = data[name]
	if type(flat) == "string" then
		return { Image = flat }
	end
	return nil
end

-- Returns a descriptor, or nil when the set is disabled / unreachable / has no such icon.
function IconSets.Get(icon)
	local set, name = IconSets.Parse(icon)
	if not set then
		return nil
	end
	local data = IconSets.Load(set)
	if not data then
		return nil
	end
	return describe(data, name, 0)
end

-- Writes a descriptor into an ImageLabel (extra layers become child ImageLabels).
function IconSets.Apply(label, descriptor)
	label.Image = descriptor.Image
	if descriptor.RectSize then
		label.ImageRectSize = descriptor.RectSize
		label.ImageRectOffset = descriptor.RectOffset or Vector2.new(0, 0)
	end
	for _, part in ipairs(descriptor.Parts or {}) do
		local layer = Utility.Create("ImageLabel", {
			Name = "Part",
			Size = UDim2.fromScale(1, 1),
			Parent = label,
		})
		IconSets.Apply(layer, part)
	end
end

IconSets.Commit = COMMIT

return IconSets
end

__modules["core/Icons"] = function(Import)
--// Icons: asset-id resolver + small glyphs drawn from frames, so core controls
--// (chevron, check, close...) never depend on uploaded images.

local Utility = Import("core/Utility")
local IconSets = Import("core/IconSets")

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

--// Image icons -----------------------------------------------------------------
-- Fills `parent` with an ImageLabel for:
--   * an asset id / rbxassetid / registered name -> full color image
--   * a Footagesus icon ("house", "lucide:house", "craft:folder-stroke") -> monochrome, tintable
-- Returns label, isMonochrome; nil when the icon cannot be found (unknown name, offline...).
function Icons.Create(icon, parent)
	if icon == nil or icon == "" then
		return nil
	end

	local direct = Icons.Resolve(icon)
	if direct then
		return Create("ImageLabel", { Name = "Icon", Size = UDim2.fromScale(1, 1), Image = direct, Parent = parent }), false
	end

	local descriptor = IconSets.Get(icon)
	if not descriptor then
		return nil
	end
	local label = Create("ImageLabel", { Name = "Icon", Size = UDim2.fromScale(1, 1), Parent = parent })
	IconSets.Apply(label, descriptor)
	return label, true
end

-- Tints an icon and its extra layers; pass a duration to animate.
function Icons.Tint(label, color, duration)
	local function paint(target)
		if duration then
			Utility.Tween(target, { ImageColor3 = color }, duration)
		else
			target.ImageColor3 = color
		end
	end
	paint(label)
	for _, child in ipairs(label:GetChildren()) do
		if child:IsA("ImageLabel") then
			paint(child)
		end
	end
end

function Icons.BindImage(theme, label, token)
	theme:Bind(label, { ImageColor3 = token })
	for _, child in ipairs(label:GetChildren()) do
		if child:IsA("ImageLabel") then
			theme:Bind(child, { ImageColor3 = token })
		end
	end
	return label
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
-- BASE holds every token. It is also the "Normal" theme (orange / red / white / black / yellow);
-- the other presets only list what they change.
local BASE = {
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
	SubText = rgb(192, 194, 210),
	Muted = rgb(134, 136, 154),
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

local DEFAULT = "Gear 5"

-- order shown in menus; themes added later come after these, alphabetically
Theme.Order = { "Gear 5", "Gear 4", "Gear 3", "Normal" }

Theme.Presets = {
	-- Gear 5: white is the identity (Nika's hair, clouds), a little cool silver and soft gold for depth.
	["Gear 5"] = {
		Background = rgb(12, 13, 21),
		BackgroundAlpha = 0.22,
		CardAlpha = 0.91,
		CardHoverAlpha = 0.84,
		StrokeAlpha = 0.84,
		TrackAlpha = 0.8,
		Text = rgb(252, 252, 255),
		SubText = rgb(200, 204, 220),
		Muted = rgb(142, 146, 164),
		OnAccent = rgb(16, 18, 30),
		Accent = rgb(255, 255, 255),
		Gradient = {
			rgb(255, 255, 255),
			rgb(224, 234, 255),
			rgb(255, 247, 226),
			rgb(255, 224, 160),
		},
	},

	-- Gear 4: black and red.
	["Gear 4"] = {
		Background = rgb(5, 5, 8),
		BackgroundAlpha = 0.14,
		SidebarAlpha = 0.6,
		Popup = rgb(10, 8, 10),
		OnAccent = rgb(255, 255, 255),
		Accent = rgb(240, 46, 58),
		Gradient = {
			rgb(255, 116, 116),
			rgb(244, 56, 68),
			rgb(214, 32, 52),
			rgb(180, 20, 44),
		},
	},

	-- Gear 3: yellow into red.
	["Gear 3"] = {
		Background = rgb(20, 12, 4),
		BackgroundAlpha = 0.18,
		Popup = rgb(22, 14, 6),
		OnAccent = rgb(34, 14, 4),
		Accent = rgb(255, 204, 52),
		Gradient = {
			rgb(255, 246, 160),
			rgb(255, 208, 52),
			rgb(255, 142, 34),
			rgb(232, 52, 52),
		},
	},

	-- Normal: orange, red, white, black and yellow (the BASE tokens).
	["Normal"] = {},
}

local function resolve(name)
	local tokens = table.clone(BASE)
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
	self.Name = Theme.Presets[name] and name or DEFAULT
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
	local names, listed = {}, {}
	for _, name in ipairs(Theme.Order) do
		if Theme.Presets[name] then
			table.insert(names, name)
			listed[name] = true
		end
	end
	local extra = {}
	for name in pairs(Theme.Presets) do
		if not listed[name] then
			table.insert(extra, name)
		end
	end
	table.sort(extra)
	for _, name in ipairs(extra) do
		table.insert(names, name)
	end
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

--// Fonts: change the whole library's typography here.
-- Plain "Gotham" renders too thin on the glass background, so body text starts at Medium.
Utility.Fonts = {
	Title = Enum.Font.GothamBold,
	Heading = Enum.Font.GothamBold,
	Label = Enum.Font.GothamSemibold,
	Body = Enum.Font.GothamMedium,
	Desc = Enum.Font.GothamMedium,
}

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

-- Endless rotation of a UIGradient (neon borders). Stopped through the maid.
function Utility.Spin(maid, gradient, seconds)
	local tween = TweenService:Create(
		gradient,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{ Rotation = gradient.Rotation + 360 }
	)
	tween:Play()
	maid:Give(function()
		tween:Cancel()
	end)
	return tween
end

--// Signal: small event with Connect / Once / Wait / Fire (used for Loader.Finished, KeyUI.Completed...)
-- A sticky signal remembers its last Fire, so Wait() called afterwards returns immediately.
local Signal = {}
Signal.__index = Signal

function Signal.new(sticky)
	return setmetatable({ Handlers = {}, Waiters = {}, Sticky = sticky == true, Fired = false, Args = nil }, Signal)
end

function Signal:Connect(fn)
	local entry = { Fn = fn }
	table.insert(self.Handlers, entry)
	return {
		Disconnect = function()
			local index = table.find(self.Handlers, entry)
			if index then
				table.remove(self.Handlers, index)
			end
		end,
	}
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	if self.Sticky then
		self.Fired = true
		self.Args = table.pack(...)
	end
	for _, entry in ipairs(table.clone(self.Handlers)) do
		task.spawn(entry.Fn, ...)
	end
	local waiters = self.Waiters
	self.Waiters = {}
	for _, thread in ipairs(waiters) do
		task.spawn(thread, ...)
	end
end

-- Yields the calling thread until the signal fires; returns the fired arguments.
function Signal:Wait()
	if self.Sticky and self.Fired then
		return table.unpack(self.Args, 1, self.Args.n)
	end
	table.insert(self.Waiters, (coroutine.running())) -- parentheses: keep only the thread
	return coroutine.yield()
end

Utility.Signal = Signal

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

-- RichText needs & < > escaped (user text must never be interpreted as markup)
function Utility.EscapeRich(text)
	text = string.gsub(tostring(text or ""), "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	return text
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
local IconSets = Import("core/IconSets")
local Theme = Import("core/Theme")
local Window = Import("components/Window")
local Notification = Import("components/Notification")
local ChatTransports = Import("components/ChatTransports")
local KeySystem = Import("components/KeySystem")
local Loading = Import("components/Loading")

-- Re-executing the script replaces the previous instance instead of stacking UIs.
local env = Compat.Env
if env.MugiwaraUI and type(env.MugiwaraUI.Destroy) == "function" then
	pcall(function()
		env.MugiwaraUI:Destroy()
	end)
end

local Library = {
	Version = "0.6.1",
	Windows = {},
	Theme = Theme.new("Gear 5"),
	Icons = Icons,
	IconSets = IconSets,
	ChatTransports = ChatTransports, -- Http (Cloudflare Worker backend) and Memory (offline demo)
	Compat = Compat,
}

function Library:CreateWindow(opts)
	return Window.new(self, opts)
end

-- Key UI: a separate card that validates a key with your Validate(key) function. KeyUI:Wait() -> key | nil
function Library:KeySystem(opts)
	return KeySystem(self, opts)
end

-- Loading UI: terminal-style loader. Drive it with SetStatus / SetProgress / Log, end it with Finish().
function Library:Loading(opts)
	return Loading(self, opts)
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

-- Default icon set for names without a prefix ("house" vs "lucide:house"): lucide, craft, geist, gravity, solar
function Library:SetIconSet(name)
	return IconSets.SetDefault(name)
end

-- Downloads icon sets ahead of time (in the background) so the first icons do not wait on the network.
function Library:PreloadIcons(...)
	IconSets.Preload({ ... })
end

function Library:Destroy()
	for window in pairs(self.Windows) do
		window:Destroy()
	end
	if self._loader then
		self._loader:Destroy()
	end
	if self._keyUI then
		self._keyUI:Close()
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
