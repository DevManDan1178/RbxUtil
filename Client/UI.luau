
function UI.ToggleFrameVisible(frame : Frame, visible : boolean) : boolean
	frame.Visible = if typeof(visible) == "boolean" then visible else not frame.Visible
	return frame.Visible
end

--VIEWPORTS
--[[Sets up a vieewport with a clone of the model or part]]
function UI.SetupViewport(viewport : ViewportFrame, model : Model | Part, relativeCameraPosition : Vector3) : (Model | Part, Camera)
	viewport.Visible = true
	model.Archivable = true
	local worldModel = viewport:FindFirstChild("WorldModel") or Instance.new("WorldModel", viewport)

	local viewPortPoint = Vector3.zero
	
	local modelClone = model:Clone()
	modelClone.Parent = worldModel
	local PrimaryPart = if modelClone:IsA("Model") then modelClone.PrimaryPart or modelClone:FindFirstChildWhichIsA("BasePart") else modelClone
	PrimaryPart.CFrame = CFrame.new(viewPortPoint)

	for each, element in pairs(modelClone:GetChildren()) do
		if element:IsA("LocalScript") or element:IsA("Script") or element:IsA("ModuleScript") then
			element:Destroy()
		end
	end

	local viewPortCamera = Instance.new("Camera", viewport)
	viewPortCamera.CFrame = CFrame.new(relativeCameraPosition or Vector3.new(0, 0, -2.25), viewPortPoint) -- camera looks at viewportpoint
	viewport.CurrentCamera = viewPortCamera
	return modelClone, viewPortCamera
end

--[[Sets up a viewport with a clone of the model or part that updates CFrame with the model]]
function UI.SetupUpdatingViewport(viewport : ViewportFrame, model : Model | Part, getLookFromVector : () -> (Vector3),  lookAtRootOffset : Vector3?) : (Model | Part, ({RBXScriptConnection}))
	local modelClone, viewportCam = UI.SetupViewport(viewport, model, Vector3.new(0,0,0))
	local function linkPartCFrames(originPart : Part, linkedPart : Part) : RBXScriptConnection
		linkedPart.Anchored = true
		return RunService.Heartbeat:Connect(function()
			if not (originPart and originPart.Parent and linkedPart and linkedPart.Parent) then
				return
			end
			linkedPart.CFrame = originPart.CFrame
		end)
	end
	local rootPart : Part = if modelClone:IsA("Part") then modelClone else Util.GetModelRootPart(modelClone)
	if not rootPart then
		return modelClone, {}
	end
	local cameraConnection = RunService.Heartbeat:Connect(function()
		viewportCam.CFrame = CFrame.new(rootPart.Position + getLookFromVector(), rootPart.Position + (lookAtRootOffset or Vector3.zero))
	end)
	if model:IsA("BasePart") then
		return modelClone, {linkPartCFrames(model, modelClone), cameraConnection}
	elseif model:IsA("Model") then
		local connections : {RBXScriptConnection} = {cameraConnection}
		for each, part in pairs(model:GetChildren()) do
			if part:IsA("Part") then
				local clonedPart = modelClone:FindFirstChild(part.Name)
				if clonedPart then
					table.insert(connections, linkPartCFrames(part, clonedPart))
				end
			elseif part:IsA("Tool") then
				local clonedPart = modelClone:FindFirstChild(part.Name)
				if clonedPart then
					clonedPart:Destroy()
				end
			end
		end
		return modelClone, connections
	end
end

local guiInset : Vector2 = game:GetService("GuiService"):GetGuiInset()

--QUERIES ABOUT UI
--[[Checks if the UI element is in the screen's bounds]]
function UI.IsInScreen(ui : GuiBase)
	local pos = ui.AbsolutePosition
	local size = ui.AbsoluteSize
	
	return pos.X --[[+ size.X]] <= workspace.CurrentCamera.ViewportSize.X and pos.X >= 0
	and pos.Y + size.Y <= workspace.CurrentCamera.ViewportSize.Y and pos.Y >= 0
end
      
--[[Gets the highest Z index among its parent's children]]
function UI.GetHighestSiblingZindex(frame : GuiObject, addZ : number)
	local highestZIndex : number
	for each, sibling in pairs(frame.Parent:GetChildren()) do
		if sibling:IsA("GuiObject") and sibling ~= frame then
			if not highestZIndex or sibling.ZIndex > highestZIndex then
				highestZIndex = sibling.ZIndex
			end
		end
	end
	return highestZIndex ~= nil and highestZIndex + addZ or frame.ZIndex
end

--[[Checks if a UI is covered by other UI elements]]
function UI.CheckCovered(currentGUI : GuiObject) : boolean	
	local UIsAtPosition : {GuiObject} = PlayerGUI:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y)
	local otherZIndex = 0
	local currentZIndex, foundSuper = 0, false
	for each, ui in pairs(UIsAtPosition) do
		if ui.Parent:IsA("GuiObject") then continue end --filter for first layer frames only
		if ui == currentGUI or currentGUI:IsDescendantOf(ui) then
			foundSuper = true
			currentZIndex = ui.ZIndex
		end
		if ui.Visible and ui.ZIndex > otherZIndex then
			otherZIndex = ui.ZIndex
		end
	end
	if not foundSuper then
		local function getSuper(ui : GuiObject) : GuiObject
			if not ui.Parent:IsA("GuiObject") then
				return ui
			else
				return getSuper(ui.Parent)
			end
		end
		currentZIndex = getSuper(currentGUI).ZIndex
	end
	return currentZIndex < otherZIndex
end
      
--UI CONNECTIONS
--[[Connects the button to the visibility of the frame (GUIObject), calls openFunc when the frame is set visible, closeFunc when it is set invisible, returns the connection]]
function UI.ConnectToggle(button : GuiButton, frame : GuiObject, openFunc : () -> ()?, closeFunc : () -> ()?) : RBXScriptConnection
	return button.Activated:Connect(function()
		if UI.CheckCovered(button) then return end
		local visible = UI.ToggleFrameVisible(frame)
		--sfx
		if visible and openFunc then
			openFunc()
		end
		if not visible and closeFunc then
			closeFunc()
		end
	end)
end

--[[Connects the button to closing the frame (GUIObject), returns the connection]]
function UI.ConnectClose(button : GuiButton, frame : GuiObject) : RBXScriptConnection
	return button.Activated:Connect(function()
		if UI.CheckCovered(button) then return end
		--SFX
		frame.Visible = false
	end)
end

--[[Connects UI element 1 and 2 such that when element 1 closes, so will element 2, returns the connection]]
function UI.ConnectBindingClose(element1 : GuiObject, element2 : GuiObject) : RBXScriptConnection
	return element1:GetPropertyChangedSignal("Visible"):Connect(function()
		if not element1.Visible then
			element2.Visible = false
		end
	end)
end
      
--[[Connects the frames (GuiObject) so that only one may be visible at a time, returns the list of connections (visibility deteections for each frame)]]
function UI.SetFramesMutuallyExclusive(frames : {GuiObject}) : {[GuiObject] : RBXScriptConnection}
	local function closeFramesWithException(exception : Frame)
		for each, frame in pairs(frames) do
			if frame:IsA("GuiObject") and frame ~= exception and frame.Visible then
				frame.Visible = false
				--SFX
			end
		end
	end
	
	local connections : {[GuiObject] : RBXScriptConnection} = {}
	for each, frame in pairs(frames) do
		if frame:IsA("GuiObject") then
			connections[frame] = frame:GetPropertyChangedSignal("Visible"):Connect(function()
				if frame.Visible then
					closeFramesWithException(frame)
				end
			end)
		end
	end
	return connections
end


--TEXT DISPLAY
--[[Displays text in the label gradually, calling letterAddFunc (or nothing) whenever a letter is added. THIS IS NOT A SEPERATE THREAD, CALLS TASK.WAIT()]]
function UI.ShowOrderedTextAppearance(textLabel : TextLabel, lettersPerSecond : number, text : string?, letterAddFunc : () -> ())
	local fullText = text or textLabel.Text
	textLabel.Text = fullText
	local t = 1/lettersPerSecond
	for i = 1, #fullText:gsub("<[^>]->", ""), 1 do
		textLabel.MaxVisibleGraphemes = i
		if letterAddFunc then
			letterAddFunc()
		end
		task.wait(t)
	end
	textLabel.MaxVisibleGraphemes = -1
end
      
