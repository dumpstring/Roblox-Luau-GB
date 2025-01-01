local StudioService = game:GetService("StudioService")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")
local Gameboy = require(script.Parent.Gameboy)

local success = pcall(function()
	local test = AssetService:CreateEditableImage({Size = Vector2.new(1,1)})
	local buf = buffer.create(4)
	for i = 0, 3 do
		buffer.writeu8(buf, i, 1)
	end
	test:WritePixelsBuffer(Vector2.zero, Vector2.new(1, 1), buf)
end)

if not success then
	warn("Test to see if EditableImages work failed!")
	return
end

local toolbar = plugin:CreateToolbar("Gameboy Emulator")
-- local loadRomBtn = toolbar:CreateButton("Insert ROM", "Load a *.gb ROM file.", "rbxassetid://11422139020")
local windowToggle = toolbar:CreateButton("Emulator Window", "Toggle the emulator window.", "rbxassetid://12975609170")
-- local ejectCartridge = toolbar:CreateButton("Remove Cartridge", "Forces the currently loaded ROM to be stopped.", "rbxassetid://12578031451")

local WIDTH = 160
local HEIGHT = 144

local WIDGET_INFO = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, true, WIDTH, HEIGHT, WIDTH, HEIGHT)

local gui = plugin:CreateDockWidgetPluginGui("LUAU_GB", WIDGET_INFO)
gui.Title = "Gameboy Emulator"
gui.Name = gui.Title

local guiFrame = script.Parent.UI:Clone()
guiFrame.Parent = gui

local loadRomBtn = guiFrame.Sidebar.Insert
local pauseBtn = guiFrame.Sidebar.Pause
local ejectCartridge = guiFrame.Sidebar.Eject
ejectCartridge.Visible = false
pauseBtn.Visible = false

local gb = Gameboy.new()
local size = Vector2.new(WIDTH, HEIGHT)

local noCartridge = buffer.fromstring(require(script.Parent.Gameboy.nocartridge))

local window : ImageLabel = guiFrame.Screen:Clone()
guiFrame.Screen:Destroy()
window.Parent = guiFrame

local aspectRatio = Instance.new("UIAspectRatioConstraint")
aspectRatio.AspectRatio = WIDTH / HEIGHT
aspectRatio.Parent = window

local screen = AssetService:CreateEditableImage({Size = size})
window.ImageContent = Content.fromObject(screen)

screen:WritePixelsBuffer(Vector2.zero, size, noCartridge)

local ticker = 0
local paused = false
local runner: thread?
local lastTick = os.clock()

local function updatePaused(pause)
	paused = pause
	pauseBtn.Icon.Image = if paused then "rbxassetid://11423157473" else "rbxassetid://11422923102"
end

local inputMap = {
	[Enum.KeyCode.Up] = "Up",
	[Enum.KeyCode.Down] = "Down",
	[Enum.KeyCode.Left] = "Left",
	[Enum.KeyCode.Right] = "Right",

	[Enum.KeyCode.X] = "A",
	[Enum.KeyCode.Z] = "B",

	[Enum.KeyCode.W] = "Up",
	[Enum.KeyCode.S] = "Down",
	[Enum.KeyCode.A] = "Left",
	[Enum.KeyCode.D] = "Right",

	[Enum.KeyCode.Return] = "Start",
	[Enum.KeyCode.RightShift] = "Select",

	[Enum.KeyCode.DPadUp] = "Up",
	[Enum.KeyCode.DPadDown] = "Down",
	[Enum.KeyCode.DPadLeft] = "Left",
	[Enum.KeyCode.DPadRight] = "Right",

	[Enum.KeyCode.ButtonY] = "A",
	[Enum.KeyCode.ButtonX] = "B",
}

local function onInputBegan(input: InputObject)
	local key = inputMap[input.KeyCode]

	if key then
		gb.input.keys[key] = 1
		gb.input.update()
	end
end

local function onInputEnded(input: InputObject)
	local key = inputMap[input.KeyCode]

	if key then
		gb.input.keys[key] = 0
		gb.input.update()
	end
end

local function runThread()
	local self = assert(runner)
	assert(self == coroutine.running())

	while true do
		local now = os.clock()
		local dt = now - lastTick

		lastTick = now
		ticker = math.min(ticker + dt * 60, 3)

		while ticker >= 1 do
			for i = 1, HEIGHT do
				if self ~= runner then
					return
				end

				debug.profilebegin(`hblank {i}`)
				gb:run_until_hblank()
				debug.profileend()
			end

			ticker -= 1
		end

		-- -- read pixels
		local pixels = gb.graphics.game_screen
		-- frameBuffer = buffer.create(buffer.len(pixels))
		-- buffer.copy(frameBuffer, 0, pixels)

		screen:WritePixelsBuffer(Vector2.zero, size, pixels)
		
		RunService.Heartbeat:Wait()
	end
end

local function onEjectCartridge()
	if runner then
		task.cancel(runner)
		runner = nil
		updatePaused(false)
	end

	gb.cartridge.reset()
	ejectCartridge.Visible = false
	pauseBtn.Visible = false
	screen:WritePixelsBuffer(Vector2.zero, size, noCartridge)
end

local function onEnabledChanged()
	windowToggle:SetActive(gui.Enabled)
end

local function onWindowToggle()
	gui.Enabled = not gui.Enabled
	windowToggle:SetActive(gui.Enabled)
end

local function onLoadRom()
	local file: File? = StudioService:PromptImportFile({ "gb", "gbc" })

	if file then
		local rom = file:GetBinaryContents()
		gb.cartridge.load(rom)
		gb:reset()

		gui.Enabled = true
		runner = task.defer(runThread)
		updatePaused(false)

		ejectCartridge.Visible = true
		pauseBtn.Visible = true
	end
end

local enabledListener = gui:GetPropertyChangedSignal("Enabled")
enabledListener:Connect(onEnabledChanged)
onEnabledChanged()

window.InputBegan:Connect(onInputBegan)
window.InputEnded:Connect(onInputEnded)

ejectCartridge.MouseButton1Click:Connect(onEjectCartridge)
windowToggle.Click:Connect(onWindowToggle)
loadRomBtn.MouseButton1Click:Connect(onLoadRom)
pauseBtn.MouseButton1Click:Connect(function()
	if paused then
		updatePaused(false)
        runner = task.defer(runThread)
    else
		updatePaused(true)
        if runner then
            task.cancel(runner)
            runner = nil
        end
    end
end)
