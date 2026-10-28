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
