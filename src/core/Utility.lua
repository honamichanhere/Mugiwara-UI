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
