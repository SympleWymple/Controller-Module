local Controller = {}
local LoadModule = require(game:GetService("ReplicatedStorage").LoadModule)
-- these are to be ignored
local xboxControls = {
	ButtonA = Enum.KeyCode.ButtonA, 
	ButtonB = Enum.KeyCode.ButtonB, 
	ButtonX = Enum.KeyCode.ButtonX, 
	ButtonY = Enum.KeyCode.ButtonY, 
	ButtonLB = Enum.KeyCode.ButtonL1, 
	ButtonLT = Enum.KeyCode.ButtonL2, 
	ButtonLS = Enum.KeyCode.ButtonL3, 
	DPadUp = Enum.KeyCode.DPadUp, 
	DPadDown = Enum.KeyCode.DPadDown, 
	DPadLeft = Enum.KeyCode.DPadLeft, 
	DPadRight = Enum.KeyCode.DPadRight, 
	ButtonRB = Enum.KeyCode.ButtonR1, 
	ButtonRT = Enum.KeyCode.ButtonR2, 
	ButtonRS = Enum.KeyCode.ButtonR3, 
	ButtonStart = Enum.KeyCode.ButtonStart, 
	ButtonSelect = Enum.KeyCode.ButtonSelect
}
local ps4Controls = {
	ButtonA = "ButtonCross", 
	ButtonB = "ButtonCircle", 
	ButtonX = "ButtonSquare", 
	ButtonY = "ButtonTriangle", 
	ButtonLB = "ButtonL1", 
	ButtonLT = "ButtonL2", 
	ButtonLS = "ButtonL3", 
	DPadUp = "DPadUp", 
	DPadDown = "DPadDown", 
	DPadLeft = "DPadLeft", 
	DPadRight = "DPadRight", 
	ButtonRB = "ButtonR1", 
	ButtonRT = "ButtonR2", 
	ButtonRS = "ButtonR3", 
	ButtonStart = "ButtonOptions", 
	ButtonSelect = "ButtonTouchpad"
}
----------------------------------------------------------------------------
local actualPs4ControlInfo = {}
local actualXboxControlInfo = {}
for key, value in pairs(ps4Controls) do
	actualPs4ControlInfo[value] = key
end
for key, value in pairs(xboxControls) do
	actualXboxControlInfo[value] = true
end
local keyState = {}
local ButtonParents = {}
local keyCodeStrings = {}
local keyCodeImages = {}
local StringImages = {}
local consoleType = nil
local platform = nil

Controller.GetConsoleType = function()
	return consoleType
end

StringForKeyCode = function(keycode)
	assert(keycode)
	if not keyCodeStrings[keycode] then
		keyCodeStrings[keycode] = LoadModule.UserInputService:GetStringForKeyCode(keycode)
	end
	local returnedKeyString = keyCodeStrings[keycode]
	return consoleType == "PlayStation" and actualPs4ControlInfo[returnedKeyString] or returnedKeyString
end

ImageForKeyCode = function(keycode)
	assert(keycode)
	if not keyCodeImages[keycode] then
		keyCodeImages[keycode] = LoadModule.UserInputService:GetImageForKeyCode(keycode)
	end
	return keyCodeImages[keycode]
end

ImageForString = function(keycode)
	assert(keycode)
	if not StringImages[keycode] then
		local status, _ = pcall(function()
			StringImages[keycode] = LoadModule.UserInputService:GetImageForKeyCode(xboxControls[keycode])
		end)
		if not status then
			print("Failed", xboxControls, keycode)
		end
	end
	return StringImages[keycode]
end

local buttonParentCache  = {}
FindFirstButtonParent = function(object)
	if not buttonParentCache [object] then
		local current = object
		while current.Parent do
			if current.Parent:IsA("TextButton") or current.Parent:IsA("ImageButton") then
				buttonParentCache [object] = current.Parent
			end
			current = current.Parent
		end
	end
	return buttonParentCache[object]
end

local buttonScanCache  = {}
ScanButtons = function(object, callback)
	if not buttonScanCache [object.Name] then
		buttonScanCache [object.Name] = {}
		for _, descendant  in ipairs(object:GetDescendants()) do
			local consoleButtonAttribute  = descendant:GetAttribute("ConsoleButton")
			if (descendant:isA("ImageLabel") and consoleButtonAttribute) and descendant.Name == "ConsoleButton" then
				local buttonParent  = FindFirstButtonParent(descendant )
				if not buttonParent  then
					return 
				else
					table.insert(buttonScanCache [object.Name], {
						Button = buttonParent , 
						Attribute = consoleButtonAttribute
					})
				end
			end
		end
	end
	for _, buttonData  in ipairs(buttonScanCache [object.Name]) do
		callback(buttonData.Button, buttonData.Attribute)
	end
end

Controller.ElementIsVisibleOnScreen = function(element)
	local currentElement = element
	while true do
		if currentElement:IsA("ScreenGui") then
			return currentElement.Enabled
		elseif currentElement.Visible == false then
			return false
		elseif currentElement.Parent then
			currentElement = currentElement.Parent
		else
			return false
		end
	end
end
FindVisibleButton = function(attributeValue)
	local visibleButtons = {}
	for button, attribute in pairs(ButtonParents) do
		if attribute == attributeValue and Controller.ElementIsVisibleOnScreen(button) then
			if not visibleButtons then
				visibleButtons = {}
			end
			table.insert(visibleButtons, button)
		end
	end
	return #visibleButtons > 0, visibleButtons
end

local cachedConsoleButtons  = {}
FindChildConsoleBind = function(element)
	if not cachedConsoleButtons [element] then
		for _, descendant  in ipairs(element:GetDescendants()) do
			if descendant .Name == "ConsoleButton" then
				cachedConsoleButtons [element] = descendant 
				break
			end
		end
	end
	return cachedConsoleButtons [element]
end

local cachedScreenGuis = {}
GetScreenGui = function(obj)
	if not cachedScreenGuis[obj] then
		local objParent = obj.Parent
		while not (not (objParent:IsA("ScreenGui") == false) or string.sub(objParent.Name, 1, 2) == "__") or objParent.Parent and objParent:IsA("ScreenGui") == false do
			objParent = objParent.Parent
		end
		cachedScreenGuis[obj] = objParent
	end
	return cachedScreenGuis[obj]
end
IsHoldingKeycode = function(key)
	return keyState[key]
end

local processedButtons = {}
ApplyConsoleButtonFX = function(button, keyTriggered)
	if processedButtons[button] then
		return
	end processedButtons[button] = true
	local isPressed = false
	local isSpecialButton = button:IsA("ImageButton") and button.Image == "rbxassetid://14148073526" -- exit button decal
	local textLabel = nil
	-- Find the associated TextLabel with text "X" (if applicable)
	if isSpecialButton then
		for _, child in ipairs(button:GetChildren()) do
			if child:IsA("TextLabel") and child.Text == "X" then
				textLabel = child
				break
			end
		end
	end
	-- Ensure UIScale exists for the TextLabel
	local textLabelScale = nil
	if textLabel and not textLabel:FindFirstChildOfClass("UIScale") then
		local scale = Instance.new("UIScale")
		scale.Name = "ButtonUIScale"
		scale.Parent = textLabel
		textLabelScale = scale
	elseif textLabel then
		textLabelScale = textLabel:FindFirstChildOfClass("UIScale")
	end
	-- Ensure UIScale exists for the button
	local buttonScale = button:FindFirstChildOfClass("UIScale")
	if not buttonScale then
		local scale = Instance.new("UIScale")
		scale.Name = "ButtonUIScale"
		scale.Parent = button
		buttonScale = scale
	end
	assert(buttonScale, "UIScale instance could not be created or found for the button")
	-- Button press effect
	local function onPress()
		if not isPressed then
			isPressed = true
			LoadModule.Functions.FastTween(buttonScale, { Scale = 0.9 }, { 0.065, Enum.EasingStyle.Exponential, "Out" })
			if textLabelScale then
				LoadModule.Functions.FastTween(textLabelScale, { Scale = 0.9 }, { 0.065, Enum.EasingStyle.Exponential, "Out" })
				LoadModule.Functions.FastTween(textLabel, { Position = UDim2.new(0.5, 0, 0.6, 0) }, { 0.065, Enum.EasingStyle.Exponential, "Out" })
			end
		end
	end
	-- Button release effect
	local function onRelease()
		if isPressed then
			isPressed = false
			LoadModule.Functions.FastTween(buttonScale, { Scale = 1 }, { 0.25, Enum.EasingStyle.Circular, "Out" })
			if textLabelScale then
				LoadModule.Functions.FastTween(textLabelScale, { Scale = 1 }, { 0.25, Enum.EasingStyle.Circular, "Out" })
				LoadModule.Functions.FastTween(textLabel, { Position = UDim2.new(0.5, 0, 0.5, 0) }, { 0.25, Enum.EasingStyle.Circular, "Out" })
			end
		end
	end
	LoadModule.Signal.Fired("Console: Pressed"):Connect(function(keyString)
		if button.Name == "Close" and keyString == "ButtonB" then
			local isVisible, onScreenButtons = LoadModule.Signal.Invoke("Console: Button Visible on Screen", "ButtonB")
			for _, btn in ipairs(onScreenButtons) do
				if btn:GetAttribute("IgnoreOnScreenCheck") then
					isVisible = false
				end
			end
			if isVisible then return end
		end
		local parentGui = GetScreenGui(button)
		if keyString ~= keyTriggered then
			return
		elseif Controller.ElementIsVisibleOnScreen(button) == false then
			return
		else
			local consoleBind = FindChildConsoleBind(button)
			if consoleBind and not consoleBind.Visible then 
				return
			else
				onPress()
				LoadModule.Signal.Fire("Console: Pressed Button", button, keyString)
			end
		end
	end)
	LoadModule.Signal.Fired("Console: Released"):Connect(function(keyString)
		if button.Name == "Close" and keyString == "ButtonB" then
			local isVisible, onScreenButtons = LoadModule.Signal.Invoke("Console: Button Visible on Screen", "ButtonB")
			for _, btn in ipairs(onScreenButtons) do
				if btn:GetAttribute("IgnoreOnScreenCheck") then
					isVisible = false
				end
			end
			if isVisible then return end
		end
		local parentGui = GetScreenGui(button)
		if keyString ~= keyTriggered then
			return
		elseif Controller.ElementIsVisibleOnScreen(button) == false then
			return
		else
			local consoleBind = FindChildConsoleBind(button)
			if consoleBind and not consoleBind.Visible then 
				return
			else
				onRelease()
				LoadModule.Signal.Fire("Console: Released Button", button, keyString)
			end
		end
	end)
end

Controller.UpdateInterface = function(currentPlatform)
	if currentPlatform == nil then
		currentPlatform = LoadModule.Signal.Invoke("Get Platform")
	end
	if platform == currentPlatform then
		return
	end
	platform = currentPlatform
	local isConsole = platform == "Console"
	if isConsole then
		consoleType = LoadModule.UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonX) == "ButtonSquare" and "PlayStation" or "Xbox"
	else
		consoleType = nil
	end
	for _, guiObject in ipairs(LoadModule.LocalPlayer.PlayerGui:GetDescendants()) do
		if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
			if guiObject.Name == "ConsoleButton" then
				local guiObjectAttribute = guiObject:GetAttribute("ConsoleButton")
				if guiObjectAttribute then
					local HideOnLoadAttribute = guiObject:GetAttribute("HideOnLoad")
					if not isConsole then
						guiObject.Visible = false
						continue
					else
						guiObject.Visible = not HideOnLoadAttribute
						guiObject.Image = ImageForString(guiObjectAttribute)
						if not guiObject:GetAttribute("IgnoreDefaultHooks") then
							task.spawn(function()
								local buttonParent = FindFirstButtonParent(guiObject)
								print(buttonParent)
								if not buttonParent then
									return 
								else
									if not ButtonParents[buttonParent] then
										ButtonParents[buttonParent] = guiObjectAttribute
									end
									ApplyConsoleButtonFX(buttonParent, guiObjectAttribute)
									return 
								end
							end)
						else
							continue
						end
					end
				else
					continue
				end
			end
			if guiObject.Name == "Close" then
				ApplyConsoleButtonFX(guiObject, "ButtonB")
			end
		end
	end
	LoadModule.Signal.Fire("Console Updated")
	return
end

LoadModule.Signal.Fired("Changed Platform"):Connect(function(...)
	Controller.UpdateInterface(...)
end)
LoadModule.Signal.Invoked("Console: Get Console Type").OnInvoke = function()
	return Controller.GetConsoleType()
end
LoadModule.Signal.Invoked("Console: Get Image For String").OnInvoke = function(keyString)
	return ImageForString(keyString)
end
LoadModule.Signal.Invoked("Console: Element Visible On Screen").OnInvoke = function(...)
	return Controller.ElementIsVisibleOnScreen(...)
end
LoadModule.Signal.Invoked("Console: Button Visible on Screen").OnInvoke = function(...)
	return FindVisibleButton(...)
end

LoadModule.UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
	if not actualXboxControlInfo[input.KeyCode] then
		return
	else
		LoadModule.Signal.Fire("Console: Released", StringForKeyCode(input.KeyCode))
		if keyState[input.KeyCode] then
			LoadModule.Signal.Fire("Console: Full Press", StringForKeyCode(input.KeyCode))
			keyState[input.KeyCode] = nil
		end
		return
	end
end)

LoadModule.UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if not actualXboxControlInfo[input.KeyCode] then
		return
	else
		if input.KeyCode == Enum.KeyCode.ButtonSelect and not LoadModule.GuiService.GuiNavigationEnabled then
			LoadModule.GuiService.GuiNavigationEnabled = true
		end
		keyState[input.KeyCode] = true
		LoadModule.Signal.Fire("Console: Pressed", StringForKeyCode(input.KeyCode))
		return
	end
end)

LoadModule.UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return 
	else
		if input.KeyCode == Enum.KeyCode.ButtonSelect then
			if LoadModule.GuiService.GuiNavigationEnabled then
				LoadModule.GuiService.GuiNavigationEnabled = false
				return 
			else
				LoadModule.GuiService.GuiNavigationEnabled = true
			end
		end
		return
	end
end)

do
	task.spawn(function()
		repeat task.wait(1) until LoadModule.LocalPlayer.PlayerGui:FindFirstChild("Main")
		Controller.UpdateInterface()
	end)
end

return Controller
