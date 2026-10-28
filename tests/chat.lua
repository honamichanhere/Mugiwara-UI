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

-- notifications come one by one (spaced), only the newest of a burst, never for muted users
local queued = {}
local burst = Tab:Chat({
	Transport = UI.ChatTransports.Memory({ Bots = false, Seed = {} }),
	NotifyLimit = 3,
	OnMessage = function(message)
		table.insert(queued, message.Text)
	end,
})
pump(3)
for index = 1, 5 do
	burst.Transport:Say(zoro, "m" .. index)
end
pump(1) -- a single poll delivers all five at once...
check(#queued == 1 and queued[1] == "m3", "...but only the newest three are queued and the first is delivered alone: " .. table.concat(queued, ","))
pump(1)
check(#queued == 2 and queued[2] == "m4", "the next notification follows on its own")
pump(1)
check(#queued == 3 and queued[3] == "m5", "in order, one at a time")
burst:Mute(zoro.UserId)
burst.Transport:Say(zoro, "muted")
pump(6)
check(#queued == 3, "muted users never notify")

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

--// safeguards: kill switch, server info, privacy banner ---------------------------------------------------------------
local function withInfo(info)
	local base = UI.ChatTransports.Memory({ Bots = false, Seed = { "x" } })
	local control = { info = info }
	function base:Info()
		return control.info
	end
	return base, control
end

local fakeClock = 1000
local realClock = os.clock
os.clock = function()
	return fakeClock
end

-- chat turned off by the owner: locked input, clear status, and it wakes up again when switched on
local offTransport, offControl = withInfo({ Mode = "off" })
local lockedChat = Tab:Chat({ Transport = offTransport, Notice = false })
pump(3)
check(lockedChat.Status.Text == "Disabled", "an owner-disabled chat says Disabled")
check(lockedChat.Box.TextEditable == false and string.find(lockedChat.Box.PlaceholderText, "turned off", 1, true), "the input is locked")
lockedChat:Send("hello?")
check(string.find(lockedChat.Status.Text, "turned off", 1, true), "sending explains why it is locked")
offControl.info = { Mode = "on" }
fakeClock = fakeClock + 31 -- the lock is re-checked every 30 s
pump(6)
check(lockedChat.Status.Text == "Live" and lockedChat.Box.TextEditable == true, "the chat unlocks by itself when switched back on")

-- read-only: history works, sending is refused
local roTransport = withInfo({ Mode = "readonly" })
local readOnly = Tab:Chat({ Transport = roTransport, Notice = false })
pump(3)
check(readOnly.Status.Text == "Read-only" and readOnly.Box.TextEditable == false, "read-only locks the input")
check(count(readOnly.Rows) == 1, "history is still shown")

-- the backend flips to read-only while someone is typing: the refused Send locks the input
local lateTransport = withInfo({ Mode = "on" })
function lateTransport:Send()
	return nil, "Chat is read-only right now", "readonly"
end
local late = Tab:Chat({ Transport = lateTransport, Notice = false, Cooldown = 0 })
pump(3)
check(late.Box.TextEditable == true, "unlocked while the backend says on")
late:Send("too late")
pump(3)
check(late.Box.TextEditable == false and late.Status.Text ~= "Live", "a readonly refusal locks the input")

-- limits announced by the server tighten the client's own
local capped = Tab:Chat({ Transport = withInfo({ Mode = "on", MaxLength = 5 }), Notice = false, MaxLength = 200 })
pump(3)
capped.Box.Text = "123456789"
check(#capped.Box.Text == 5, "the server's MaxLength wins when it is smaller")

-- privacy banner
local banner = Tab:Chat({ Transport = withInfo({ Mode = "on", Notice = "Custom server text.", RetentionHours = 48 }) })
pump(3)
check(banner.Notice.Visible, "the privacy banner is shown")
local bannerText
for _, child in ipairs(banner.Notice:GetDescendants()) do
	if child:IsA("TextLabel") and string.find(child.Text, "Custom server text.", 1, true) then
		bannerText = child.Text
	end
end
check(bannerText and string.find(bannerText, "48 hours", 1, true), "the server's notice and retention are shown: " .. tostring(bannerText))
local gotIt
for _, child in ipairs(banner.Notice:GetDescendants()) do
	if child:IsA("TextButton") then
		gotIt = child
	end
end
gotIt.MouseButton1Click:Fire()
check(not banner.Notice.Visible, "Got it hides the banner")
check(MOCK.files["MugiwaraUI/chat-notice.txt"] == bannerText, "the dismissal is remembered on this device")
local again = Tab:Chat({ Transport = withInfo({ Mode = "on", Notice = "Custom server text.", RetentionHours = 48 }) })
pump(3)
check(not again.Notice.Visible, "a dismissed notice stays hidden")
local changed = Tab:Chat({ Transport = withInfo({ Mode = "on", Notice = "A different notice." }) })
pump(3)
check(changed.Notice.Visible, "a changed notice is shown again")
check(not Tab:Chat({ Transport = withInfo({ Mode = "on" }), Notice = false }).Notice.Visible, "Notice = false never shows it")
local ownText = Tab:Chat({ Transport = withInfo({ Mode = "on", Notice = "ignored" }), Notice = "Our own rules." })
pump(3)
local ownShown = false
for _, child in ipairs(ownText.Notice:GetDescendants()) do
	if child:IsA("TextLabel") and child.Text == "Our own rules." then
		ownShown = true
	end
end
check(ownShown, "a string Notice overrides the built-in and the server text")

os.clock = realClock

--// destroy ------------------------------------------------------------------------------------------------------
chat:Destroy()
pump(3)
check(not chat.Frame:IsDescendantOf(game), "destroy removes the element and stops its poll loop")

--// Http transport ----------------------------------------------------------------------------------------------
local calls = {}
local serverMode = "on"
request = function(options)
	table.insert(calls, options)
	local path = string.match(options.Url, "^https://chat%.example%.com(/v1/%a+)")
	local body = options.Body and HttpService:JSONDecode(options.Body) or nil
	if serverMode == "off" and path ~= "/v1/info" then
		return { StatusCode = 503, Body = HttpService:JSONEncode({ error = "chat_disabled", message = "Chat is turned off right now" }) }
	end
	if serverMode == "readonly" and (path == "/v1/send" or path == "/v1/delete") then
		return { StatusCode = 503, Body = HttpService:JSONEncode({ error = "chat_readonly", message = "Chat is read-only right now" }) }
	end
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
	elseif path == "/v1/info" then
		payload = { mode = serverMode, maxLength = 150, cooldownMs = 2000, retentionHours = 24, notice = "Be kind.", filter = {} }
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

-- the owner's kill switch reaches the client as a code, not just an error string
local info = http:Info()
check(info.Mode == "on" and info.MaxLength == 150 and info.RetentionHours == 24 and info.Notice == "Be kind." and info.CooldownMs == 2000, "Info maps the server settings")
serverMode = "readonly"
check(http:Info().Mode == "readonly", "Info reports read-only")
local roSend, roReason, roCode = http:Send({ Text = "nope" })
check(roSend == nil and roCode == "readonly" and string.find(roReason, "read-only", 1, true), "a read-only refusal carries the code")
check(select(3, http:Delete(2)) == "readonly", "deleting is refused with the same code")
check(http:History({ Limit = 5 }) ~= nil, "reading still works in read-only mode")
serverMode = "off"
local offHistory, offReason, offCode = http:History({ Limit = 5 })
check(offHistory == nil and offCode == "disabled" and string.find(offReason, "turned off", 1, true), "an off switch carries the disabled code")
check(select(3, http:Poll(1)) == "disabled", "polling reports disabled too")
check(http:Info().Mode == "off", "Info still answers while the chat is off")
serverMode = "on"

request = nil
local offlineTransport = UI.ChatTransports.Http({ Url = "https://chat.example.com", Folder = "ChatTest" })
local noResult, noReason = offlineTransport:History({})
check(noResult == nil and string.find(noReason, "request"), "no request function: a clear error")

check(#WARNINGS == 0, "no warnings: " .. table.concat(WARNINGS, " | "))
UI:Destroy()
print("chat test passed")
