-- Chat element + transports against the mock.

local HttpService = game:GetService("HttpService")
local RenderStepped = MOCK.services.RunService.RenderStepped

local function check(condition, message)
	if not condition then
		error("ASSERT: " .. message, 2)
	end
end

local function pump(times)
	for _ = 1, times or 6 do
		RenderStepped:Fire(1 / 60)
		task.flush()
	end
end

local function count(rows)
	local total = 0
	for _ in pairs(rows) do
		total = total + 1
	end
	return total
end

-- the pill with a given layout order inside a row's action bar
local function action(row, order)
	for _, child in ipairs(row.Actions:GetChildren()) do
		if child:IsA("TextButton") and child.LayoutOrder == order then
			return child
		end
	end
end

local UI = assert(load(DIST_SOURCE, "=dist"))()
local Window = UI:CreateWindow({ Title = "Chat test" })
local Tab = Window:Tab({ Title = "Chat" })
local me = { UserId = 1, Name = "Tester", DisplayName = "Tester" } -- the mocked LocalPlayer
local zoro = { UserId = 1001, Name = "Zoro_Roronoa", DisplayName = "Zoro" }

--// requirements ------------------------------------------------------------------------------
local noTransport, noTransportError = pcall(function()
	Tab:Chat({})
end)
check(not noTransport and string.find(noTransportError, "Transport"), "Chat requires a Transport")
local noUrl = pcall(function()
	UI.ChatTransports.Http({})
end)
check(not noUrl, "Http transport requires a Url")

--// history, paging --------------------------------------------------------------------------------
local transport = UI.ChatTransports.Memory({ Bots = false, Seed = { "first", "second", "third" } })
local notified = {}
local chat = Tab:Chat({
	Transport = transport,
	History = 2,
	Cooldown = 0,
	OnMessage = function(message)
		table.insert(notified, message.Text)
	end,
})
pump(3)
check(count(chat.Rows) == 2, "the first page of history is shown (2 of 3)")
check(chat.OlderButton.Visible, "older messages are available")
check(chat.Status.Text == "Live", "connected state is shown")
check(#notified == 0, "history is not reported as new messages")
chat.OlderButton.MouseButton1Click:Fire()
pump(3)
check(count(chat.Rows) == 3 and not chat.OlderButton.Visible, "load older prepends the rest")

--// sending, replying, deleting ---------------------------------------------------------------------
chat.Box.Text = "hello everyone"
chat.SendButton.MouseButton1Click:Fire()
pump(3)
check(chat.Box.Text == "", "the input is cleared after sending")
local messages = chat:GetMessages()
local mine = messages[#messages]
check(mine.Text == "hello everyone" and mine.UserId == me.UserId, "the message was sent as the local player")
check(count(chat.Rows) == 4, "the sent message appears immediately")

chat.SelectRow(messages[1].Id) -- someone else's message: Reply / Copy / Mute
local firstRow = chat.Rows[messages[1].Id]
check(firstRow.Actions.Visible, "selecting a message shows its actions")
action(firstRow, 1).MouseButton1Click:Fire() -- Reply
check(chat.ReplyBar.Visible, "Reply opens the reply bar")
chat.Box.Text = "answering that"
chat:Send(chat.Box.Text)
pump(3)
local afterReply = chat:GetMessages()
local replyMessage = afterReply[#afterReply]
check(replyMessage.Reply and replyMessage.Reply.Id == messages[1].Id, "the reply references the original")
check(not chat.ReplyBar.Visible, "the reply bar closes after sending")

-- own message: Delete is offered
chat.SelectRow(mine.Id)
check(action(chat.Rows[mine.Id], 3) ~= nil, "own messages have an action")
action(chat.Rows[mine.Id], 3).MouseButton1Click:Fire() -- Delete
pump(3)
check(chat.Rows[mine.Id].Text.Text == "Message deleted", "a deleted message is shown as deleted")
check(transport:History({ Limit = 50 }).Messages[4].Deleted, "the deletion reached the backend")
check(chat.Rows[mine.Id].Actions.Visible == false, "a deleted message has no actions")

--// live updates ----------------------------------------------------------------------------------------
transport:Say(zoro, "live message from zoro")
pump(8)
check(#notified == 1 and notified[1] == "live message from zoro", "OnMessage reports new messages from others")
local lastId = chat:GetMessages()[#chat:GetMessages()].Id
check(chat.Rows[lastId] ~= nil, "polling brings in new messages")

-- reading older messages while new ones arrive: a pill instead of jumping
chat.Scroll.AbsoluteCanvasSize = Vector2.new(0, 1000)
transport:Say(zoro, "while you read")
pump(8)
check(chat.NewPill.Visible, "new messages while scrolled up show the pill")
chat.NewPill.MouseButton1Click:Fire()
check(not chat.NewPill.Visible, "the pill is dismissed by scrolling down")
chat.Scroll.AbsoluteCanvasSize = Vector2.new(0, 100)

-- a message deleted by its author disappears for everyone, quotes follow
local victim = transport:Say(zoro, "I will regret this")
local quoter = transport:Say(me, "quoting", victim.Id)
pump(8)
check(chat.Rows[victim.Id] ~= nil and chat.Rows[quoter.Id].Quote ~= nil, "a quoted reply is rendered")
transport:Remove(victim.Id)
pump(8)
check(chat.Rows[victim.Id].Text.Text == "Message deleted", "a remote deletion arrives through polling")
check(string.find(chat.Rows[quoter.Id].Quote.Text, "Message deleted", 1, true), "quotes of a deleted message say so")

--// muting ---------------------------------------------------------------------------------------------------
local before = count(chat.Rows)
local firstMessage = chat:GetMessages()[1]
chat.SelectRow(firstMessage.Id)
action(chat.Rows[firstMessage.Id], 3).MouseButton1Click:Fire() -- Mute
check(#chat:GetMuted() == 1 and chat:GetMuted()[1] == 1001, "Mute remembers the user id")
check(count(chat.Rows) < before, "muted users disappear from the list")
local notifiedBefore = #notified
transport:Say(zoro, "muted message")
pump(8)
check(chat.Rows[chat:GetMessages()[#chat:GetMessages()].Id] == nil, "new messages from a muted user stay hidden")
chat:Unmute(1001)
check(#chat:GetMuted() == 0 and count(chat.Rows) >= before, "Unmute brings the messages back")

--// safety / limits ----------------------------------------------------------------------------------------------
local evil = transport:Say({ UserId = 7, Name = "evil", DisplayName = "<i>Bad</i>" }, "<b>not bold</b> <font color='#f00'>x</font>")
pump(8)
check(chat.Rows[evil.Id].Text.RichText == false and chat.Rows[evil.Id].Text.Text == "<b>not bold</b> <font color='#f00'>x</font>", "message text is never parsed as RichText")
local headerFound = false
for _, child in ipairs(chat.Rows[evil.Id].Frame:GetDescendants()) do
	if child:IsA("TextLabel") and string.find(child.Text, "&lt;i&gt;Bad&lt;/i&gt;", 1, true) then
		headerFound = true
	end
end
check(headerFound, "names are escaped in the RichText header")

local limited = Tab:Chat({ Transport = UI.ChatTransports.Memory({ Bots = false, Seed = {} }), MaxLength = 10, Cooldown = 60 })
pump(3)
limited.Box.Text = string.rep("x", 30)
check(#limited.Box.Text == 10, "the input is capped at MaxLength")
limited:Send("first")
pump(3)
limited:Send("second too soon")
check(limited.Status.Text == "Slow down a little", "the cooldown tells the user (checked before the mock runs the 3 s revert)")
pump(3)
check(#limited:GetMessages() == 1, "the cooldown blocks a second message")

--// polling only while the chat is on screen -----------------------------------------------------------------
Window:Close()
transport:Say(zoro, "sent while hidden")
local hiddenCount = count(chat.Rows)
pump(8)
check(count(chat.Rows) == hiddenCount, "no polling while the window is hidden")
Window:Open()
pump(8)
check(count(chat.Rows) == hiddenCount + 1, "polling resumes when the window is shown again")

-- BackgroundPoll keeps listening while hidden (for notifications)
local background = Tab:Chat({ Transport = UI.ChatTransports.Memory({ Bots = false, Seed = { "x" } }), BackgroundPoll = 20 })
pump(3)
local backgroundBefore = count(background.Rows)
Window:Close()
background.Transport:Say(zoro, "while hidden")
pump(8)
check(count(background.Rows) == backgroundBefore + 1, "BackgroundPoll keeps polling while the window is hidden")
Window:Open()
pump(3)

--// offline handling ----------------------------------------------------------------------------------------------
local flaky = UI.ChatTransports.Memory({ Bots = false, Seed = { "hi" } })
local healthy = true
local realHistory, realPoll = flaky.History, flaky.Poll
function flaky:History(options)
	if not healthy then
		return nil, "down"
	end
	return realHistory(self, options)
end
function flaky:Poll(cursor)
	if not healthy then
		return nil, "down"
	end
	return realPoll(self, cursor)
end
healthy = false
local offline = Tab:Chat({ Transport = flaky })
pump(4)
check(offline.Status.Text == "Offline", "a failing backend shows Offline")
healthy = true
pump(20)
check(offline.Status.Text == "Live" and count(offline.Rows) == 1, "the chat recovers by itself")

--// destroy ------------------------------------------------------------------------------------------------------
chat:Destroy()
pump(3)
check(not chat.Frame:IsDescendantOf(game), "destroy removes the element and stops its poll loop")

--// Http transport ----------------------------------------------------------------------------------------------
local calls = {}
request = function(options)
	table.insert(calls, options)
	local path = string.match(options.Url, "^https://chat%.example%.com(/v1/%a+)")
	local body = options.Body and HttpService:JSONDecode(options.Body) or nil
	local payload
	if path == "/v1/history" then
		payload = { rev = 7, more = false, messages = { { id = 1, userId = 1001, name = "z", displayName = "Z", text = "hi", time = os.time(), deleted = false } } }
	elseif path == "/v1/poll" then
		payload = { rev = 7, messages = {} }
	elseif path == "/v1/send" then
		if body.text == "limit me" then
			return { StatusCode = 429, Body = HttpService:JSONEncode({ error = "rate_limited", message = "slow down" }) }
		end
		payload = { rev = 8, message = { id = 2, userId = body.userId, name = body.name, displayName = body.displayName, text = body.text, time = os.time(), deleted = false, replyTo = body.replyTo, replyName = "Z", replyText = "hi" } }
	elseif path == "/v1/delete" then
		payload = { ok = true }
	else
		return { StatusCode = 404, Body = HttpService:JSONEncode({ error = "not_found", message = "nope" }) }
	end
	return { StatusCode = 200, Body = HttpService:JSONEncode(payload) }
end

local http = UI.ChatTransports.Http({ Url = "https://chat.example.com/", Channel = "room", Folder = "ChatTest" })
check(http.User.UserId == me.UserId, "the transport identifies the local player")
local token = MOCK.files["ChatTest/chat-token.txt"]
check(token and #token >= 16, "a device token is created and stored")

local page = http:History({ Limit = 10, Before = 5 })
check(page.Messages[1].DisplayName == "Z" and page.Cursor == 7 and page.More == false, "History maps the server format")
check(string.find(calls[1].Url, "channel=room&limit=10", 1, true) and string.find(calls[1].Url, "before=5", 1, true), "History sends its query: " .. calls[1].Url)
check(http:Poll(7).Cursor == 7, "Poll maps the cursor")
local sent = http:Send({ Text = "hello", ReplyTo = 1 })
check(sent.Id == 2 and sent.Reply.Id == 1 and sent.Reply.Name == "Z", "Send maps the reply snapshot")
local sentBody = HttpService:JSONDecode(calls[#calls].Body)
check(sentBody.token == token and sentBody.userId == me.UserId and sentBody.channel == "room", "Send identifies the user with the stored token")
check(http:Delete(2) == true, "Delete maps success")
local limitedSend, limitedReason = http:Send({ Text = "limit me" })
check(limitedSend == nil and limitedReason == "slow down", "server errors surface their message")
local second = UI.ChatTransports.Http({ Url = "https://chat.example.com", Folder = "ChatTest" })
second:Send({ Text = "again" })
check(HttpService:JSONDecode(calls[#calls].Body).token == token, "the same device token is reused")

request = nil
local offlineTransport = UI.ChatTransports.Http({ Url = "https://chat.example.com", Folder = "ChatTest" })
local noResult, noReason = offlineTransport:History({})
check(noResult == nil and string.find(noReason, "request"), "no request function: a clear error")

check(#WARNINGS == 0, "no warnings: " .. table.concat(WARNINGS, " | "))
UI:Destroy()
print("chat test passed")
