local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

local DEFAULT_THEME = "Default"
local THEME_ATTRIBUTE = "Theme"
local TOUCH_IMAGE = "rbxasset://textures/ui/Controls/TouchTapIcon.png"

local CustomProximityPrompts = {}

local Themes = {} :: { [string]: Theme }
local Container = nil :: ScreenGui?

local function getKeyDisplay(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): (string?, string?)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return nil, TOUCH_IMAGE
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
		if image ~= "" then
			return nil, image
		end

		return UserInputService:GetStringForKeyCode(prompt.GamepadKeyCode), nil
	else
		local text = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode, Enum.KeyCodeStringFormat.Abbreviated)
		return if text ~= "" then text else prompt.KeyboardKeyCode.Name, nil
	end
end

local function refresh(context: Context, baseSizeOffset: Vector2)
	local prompt = context.Prompt
	local gui = context.Gui

	local actionText = gui:FindFirstChild("ActionText", true)
	if actionText and actionText:IsA("TextLabel") then
		actionText.Text = prompt.ActionText
		actionText.AutoLocalize = prompt.AutoLocalize
		actionText.RootLocalizationTable = prompt.RootLocalizationTable
	end

	local objectText = gui:FindFirstChild("ObjectText", true)
	if objectText and objectText:IsA("TextLabel") then
		objectText.Text = prompt.ObjectText
		objectText.AutoLocalize = prompt.AutoLocalize
		objectText.RootLocalizationTable = prompt.RootLocalizationTable
	end

	local text, image = getKeyDisplay(prompt, context.InputType)

	local keyText = gui:FindFirstChild("KeyText", true)
	if keyText and keyText:IsA("TextLabel") then
		keyText.Text = text or ""
		keyText.Visible = text ~= nil
	end

	local keyImage = gui:FindFirstChild("KeyImage", true)
	if keyImage and keyImage:IsA("ImageLabel") then
		keyImage.Image = image or ""
		keyImage.Visible = image ~= nil
	end

	-- UIOffset is in pixels, so it can only shift a gui whose size has a pixel part.
	local size = gui.Size
	gui.SizeOffset = baseSizeOffset
		+ Vector2.new(
			if size.X.Offset ~= 0 then prompt.UIOffset.X / size.X.Offset else 0,
			if size.Y.Offset ~= 0 then prompt.UIOffset.Y / size.Y.Offset else 0
		)
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType, theme: Theme)
	local connections = {} :: { RBXScriptConnection }
	local progressConnection = nil :: RBXScriptConnection?
	local buttonDown = false
	local hidden = false

	local gui = theme.Template:Clone()
	local baseSizeOffset = gui.SizeOffset

	local context = {
		Prompt = prompt,
		Gui = gui,
		InputType = inputType,
	}

	local function stopProgress()
		if progressConnection then
			progressConnection:Disconnect()
			progressConnection = nil
		end
	end

	local function hide()
		if not hidden then
			hidden = true

			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			stopProgress()

			if buttonDown then
				buttonDown = false
				prompt:InputHoldEnd()
			end

			task.spawn(function()
				if theme.OnHidden then
					theme.OnHidden(context)
				end

				gui:Destroy()
			end)
		end
	end

	local button = gui:FindFirstChild("Button", true)
	if button and button:IsA("GuiButton") then
		table.insert(
			connections,
			button.InputBegan:Connect(function(input: InputObject)
				local isPress = input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseButton1

				if
					isPress
					and input.UserInputState ~= Enum.UserInputState.Change
					and (inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt)
				then
					buttonDown = true
					prompt:InputHoldBegin()
				end
			end)
		)

		table.insert(
			connections,
			button.InputEnded:Connect(function(input: InputObject)
				local isPress = input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseButton1

				if isPress and buttonDown then
					buttonDown = false
					prompt:InputHoldEnd()
				end
			end)
		)
	end

	table.insert(
		connections,
		prompt.PromptButtonHoldBegan:Connect(function()
			local startTime = os.clock()

			stopProgress()
			progressConnection = RunService.PreRender:Connect(function()
				if theme.OnProgress then
					local duration = prompt.HoldDuration
					local alpha = if duration > 0 then math.clamp((os.clock() - startTime) / duration, 0, 1) else 1

					theme.OnProgress(context, alpha)
				end
			end)

			if theme.OnHoldBegan then
				task.spawn(theme.OnHoldBegan, context)
			end
		end)
	)

	table.insert(
		connections,
		prompt.PromptButtonHoldEnded:Connect(function()
			stopProgress()

			if theme.OnHoldEnded then
				task.spawn(theme.OnHoldEnded, context)
			end
		end)
	)

	table.insert(
		connections,
		prompt.Triggered:Connect(function()
			if theme.OnTriggered then
				task.spawn(theme.OnTriggered, context)
			end
		end)
	)

	table.insert(
		connections,
		prompt.TriggerEnded:Connect(function()
			if theme.OnTriggerEnded then
				task.spawn(theme.OnTriggerEnded, context)
			end
		end)
	)

	table.insert(
		connections,
		prompt.Changed:Connect(function()
			refresh(context, baseSizeOffset)
		end)
	)

	table.insert(connections, prompt.PromptHidden:Connect(hide))
	table.insert(connections, prompt.Destroying:Connect(hide))
	table.insert(
		connections,
		prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			if not prompt.Enabled then
				hide()
			end
		end)
	)

	refresh(context, baseSizeOffset)

	gui.Adornee = prompt.Parent
	gui.Enabled = true
	gui.Parent = Container

	if theme.OnShown then
		task.spawn(theme.OnShown, context)
	end
end

function CustomProximityPrompts.RegisterTheme(self: CustomProximityPrompts, name: string, theme: Theme)
	if not theme.Template:IsA("BillboardGui") then
		error("Template of the " .. name .. " theme is not a BillboardGui!")
	end

	Themes[name] = theme
end

function CustomProximityPrompts.Start(self: CustomProximityPrompts)
	if Container then
		error("CustomProximityPrompts is already started!")
	end

	local container = Instance.new("ScreenGui")
	container.Name = "CustomProximityPrompts"
	container.ResetOnSpawn = false
	container.Parent = Player:WaitForChild("PlayerGui", 9e9)

	Container = container

	ProximityPromptService.PromptShown:Connect(
		function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
			if prompt.Style == Enum.ProximityPromptStyle.Custom then
				local themeName = prompt:GetAttribute(THEME_ATTRIBUTE)
				local theme = (if typeof(themeName) == "string" then Themes[themeName] else nil)
					or Themes[DEFAULT_THEME]

				if theme then
					show(prompt, inputType, theme)
				else
					warn("No theme to show " .. prompt:GetFullName() .. " with!")
				end
			end
		end
	)
end

function CustomProximityPrompts.Create(self: CustomProximityPrompts, properties: { [string]: any }): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom

	for property, value in pairs(properties) do
		if property == THEME_ATTRIBUTE then
			prompt:SetAttribute(THEME_ATTRIBUTE, value)
		elseif property ~= "Parent" then
			(prompt :: any)[property] = value
		end
	end

	prompt.Parent = properties.Parent

	return prompt
end

export type Context = {
	Prompt: ProximityPrompt,
	Gui: BillboardGui,
	InputType: Enum.ProximityPromptInputType,
}

export type Theme = {
	Template: BillboardGui,
	OnShown: ((context: Context) -> ())?,
	OnHidden: ((context: Context) -> ())?,
	OnHoldBegan: ((context: Context) -> ())?,
	OnHoldEnded: ((context: Context) -> ())?,
	OnProgress: ((context: Context, alpha: number) -> ())?,
	OnTriggered: ((context: Context) -> ())?,
	OnTriggerEnded: ((context: Context) -> ())?,
}

type CustomProximityPrompts = typeof(CustomProximityPrompts)

return CustomProximityPrompts
