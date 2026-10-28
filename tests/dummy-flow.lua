-- Drives examples/dummy-flow.lua end to end: Key UI > Loading UI > Main UI.
-- The script yields (KeyUI:Wait, task.wait, Loader.Finished:Wait), so it runs in its own thread.

local RenderStepped = MOCK.services.RunService.RenderStepped
local function pump(times)
	for _ = 1, times do
		RenderStepped:Fire(1 / 60)
		task.flush()
	end
end

local chunk = assert(load(FLOW_SOURCE, "=dummy-flow"))
local finished = false
task.spawn(function()
	chunk()
	finished = true
end)
pump(3)

local UI = _G.MugiwaraUI
assert(UI, "the flow script creates the library")
assert(UI._keyUI and UI._keyUI.Box, "step 1: the Key UI is shown first")
assert(next(UI.Windows) == nil and UI._loader == nil, "the Loading UI and Main UI must not exist yet")

UI._keyUI.Box.Text = "my-random-key"
UI._keyUI:Submit() -- any key is valid in the demo
pump(20)
assert(UI._loader ~= nil, "step 2: the Loading UI appears after the key is accepted")
assert(next(UI.Windows) == nil, "the Main UI waits for the loader")

local guard = 0
while not finished and guard < 600 do
	pump(1)
	guard = guard + 1
end
assert(finished, "the flow completes")
assert(next(UI.Windows) ~= nil, "step 3: the Main UI is created last")
assert(#WARNINGS == 0, "no warnings: " .. table.concat(WARNINGS, " | "))
print("flow demo ok (" .. guard .. " frames)")
