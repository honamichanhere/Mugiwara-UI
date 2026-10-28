-- Key UI and Loading UI against the mock.

local function check(condition, message)
	if not condition then
		error("ASSERT: " .. message, 2)
	end
end

local function drain(times)
	for _ = 1, times or 8 do
		task.flush()
	end
end

local UI = assert(load(DIST_SOURCE, "=dist"))()
local RenderStepped = MOCK.services.RunService.RenderStepped

--// Key UI ------------------------------------------------------------------------------
local noValidate, noValidateError = pcall(function()
	UI:KeySystem({ Title = "x" })
end)
check(not noValidate and string.find(noValidateError, "Validate"), "KeySystem must require a Validate function")

local attempts, accepted = {}, nil
local KeyUI = UI:KeySystem({
	Title = "Test Hub",
	Folder = "FlowTest",
	Links = {
		{ Title = "Get Key", Link = "https://example.com/key", Icon = "lucide:house" },
		{ Title = "Custom", Callback = function() MOCK.customLinkClicked = true end },
	},
	Validate = function(key)
		table.insert(attempts, key)
		if key == "bad" then
			return false, "Nope"
		end
		return true
	end,
	OnSuccess = function(key)
		accepted = key
	end,
})
check(KeyUI.Box ~= nil and KeyUI.Status ~= nil, "key UI builds its widgets")

local result, resolved = "unset", false
task.spawn(function()
	result = KeyUI:Wait()
	resolved = true
end)
check(not resolved, "Wait yields until a key is accepted")

KeyUI.Box.Text = "   "
KeyUI:Submit()
check(#attempts == 0 and KeyUI.Status.Text ~= "", "an empty key is rejected without calling Validate")

KeyUI.Box.Text = "  bad  "
KeyUI:Submit()
drain(2)
check(attempts[1] == "bad", "the key is trimmed before Validate")
check(KeyUI.Status.Text == "Nope", "the Validate message is shown")
check(not resolved and accepted == nil, "a rejected key does not complete")

KeyUI.LinkButtons[1].MouseButton1Click:Fire()
check(MOCK.clipboard == "https://example.com/key", "a link button copies the URL")
KeyUI.LinkButtons[2].MouseButton1Click:Fire()
check(MOCK.customLinkClicked, "a link Callback runs")

KeyUI.Box.Text = "good"
KeyUI:Submit()
KeyUI:Submit() -- double submit while accepting must not validate twice
check(accepted == "good", "OnSuccess receives the key")
drain(8)
check(resolved and result == "good" and KeyUI.Destroyed, "Wait returns the accepted key and the card closes")
check(#attempts == 2, "an accepted key locks the card")
check(MOCK.files["FlowTest/key.txt"] == "good", "an accepted key is always saved")

-- Validate raising an error counts as invalid and never crashes
local broken = UI:KeySystem({ Folder = "FlowBroken", Validate = function() error("boom") end })
broken.Box.Text = "anything"
broken:Submit()
drain(2)
check(string.find(broken.Status.Text, "failed"), "a Validate error is reported")
check(#WARNINGS == 1, "a Validate error is logged once")
WARNINGS = {}
broken:Close()
drain(4)

-- SaveKey = false never writes the key
local unsaved = UI:KeySystem({ Folder = "FlowNoSave", SaveKey = false, Validate = function() return true end })
unsaved.Box.Text = "tmp"
unsaved:Submit()
drain(8)
check(MOCK.files["FlowNoSave/key.txt"] == nil, "SaveKey = false does not save the key")

-- the second run skips the UI when the saved key is still valid
local remembered = UI:KeySystem({ Folder = "FlowRemember", Validate = function() return true end })
remembered.Box.Text = "saved-key"
remembered:Submit()
drain(8)
check(MOCK.files["FlowRemember/key.txt"] == "saved-key", "the key is saved after success")

local auto = UI:KeySystem({ Folder = "FlowRemember", Validate = function(key) return key == "saved-key" end })
check(auto.Box == nil, "a valid saved key skips the key UI")
check(auto:Wait() == "saved-key", "the saved key is returned")

local stale = UI:KeySystem({ Folder = "FlowRemember", Validate = function() return false end })
check(stale.Box ~= nil, "a saved key that no longer validates shows the UI")
check(MOCK.files["FlowRemember/key.txt"] == nil, "and the stale key is removed")

-- closing the card: Wait returns nil and OnClose runs
local closed = false
local closable = UI:KeySystem({ Folder = "FlowClose", Validate = function() return true end, OnClose = function() closed = true end })
local closeResult, closeDone = "unset", false
task.spawn(function()
	closeResult = closable:Wait()
	closeDone = true
end)
closable:Close()
drain(4)
check(closed and closeDone and closeResult == nil, "closing the key UI resumes Wait with nil")

--// Loading UI ----------------------------------------------------------------------------
local Loader = UI:Loading({ Title = "Hub", Owner = "Me", Version = "v1" })
Loader:SetStatus("Stage 1")
Loader:SetProgress(30, 50)
local entry = Loader:Log("custom line", "ok")
check(entry and entry.Label, "Log returns the line")
for _ = 1, 6 do
	RenderStepped:Fire(1 / 60)
	task.flush()
end
check(MOCK.env_loader == nil and _G.MugiwaraLoader == Loader, "the loader is reachable through getgenv")

local replaced = UI:Loading({ Title = "Second" })
check(Loader.Destroyed, "a new loader replaces the previous one")
replaced:Destroy()

local Third = UI:Loading({ Title = "Event", InstantCover = true })
local finishedFired = false
Third.Finished:Connect(function() finishedFired = true end)
Third.FinishEvent:Fire("via event")
for _ = 1, 60 do
	RenderStepped:Fire(1 / 60)
	task.flush()
end
check(Third.Destroyed and finishedFired, "FinishEvent finishes the loader and Finished fires")
Third.Finished:Wait() -- sticky: returns immediately after the fact
check(_G.MugiwaraLoader == nil, "the loader unregisters itself")

local Fourth = UI:Loading({ Title = "Plain" })
Fourth:Finish()
Fourth:SetStatus("ignored after finish")
Fourth:SetProgress(80)
for _ = 1, 60 do
	RenderStepped:Fire(1 / 60)
	task.flush()
end
check(Fourth.Destroyed, "Finish() runs the whole exit animation")

check(#WARNINGS == 0, "no warnings: " .. table.concat(WARNINGS, " | "))
UI:Destroy()
print("flow test passed")
