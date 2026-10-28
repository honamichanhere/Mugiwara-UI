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
