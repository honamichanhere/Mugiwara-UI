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
