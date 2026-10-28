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
