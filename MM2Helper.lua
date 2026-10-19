-- MM2 helper: role tags, player ESP, gun ESP (after the sheriff dies), aimbot, and a menu
-- RightShift = show/hide menu

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local CONFIG = {
	ShowRoles = true,
	ShowESP = true,
	ShowGun = true,
	GunAlways = false,       -- false = gun only shows after the sheriff dies
	Aimbot = false,
	AimTarget = "Murderer",  -- "Murderer" or "Nearest"
	FOV = 150,               -- pixels from the center of the screen
	Smooth = 0.3,            -- 1 = snap instantly, lower = smoother
	RefreshRate = 0.25,
}

local COLORS = {
	Murderer = Color3.fromRGB(255, 60, 60),
	Sheriff = Color3.fromRGB(60, 140, 255),
	Innocent = Color3.fromRGB(60, 230, 110),
	Gun = Color3.fromRGB(255, 220, 60),
}

-- player -> {r = "Murderer" | "Sheriff", c = the character they had when seen}
local roles = {}
local visuals = {}
local sheriffDead = false
local gunObj, gunHL, gunBB

local function roleOf(p)
	local rec = roles[p]
	return rec and rec.r or "Innocent"
end

-- Tools are only visible on other players while they're holding them
local function holds(p, tool)
	local c = p.Character
	if c and c:FindFirstChild(tool) then return true end
	local bp = p:FindFirstChildOfClass("Backpack")
	return bp ~= nil and bp:FindFirstChild(tool) ~= nil
end

local function alive(p)
	local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

local function scan()
	sheriffDead = false
	for _, p in ipairs(Players:GetPlayers()) do
		local rec = roles[p]
		-- a new character means a respawn, which means a new round: forget the old role
		if rec and rec.c ~= p.Character then
			roles[p] = nil
			rec = nil
		end
		local r
		if holds(p, "Knife") then
			r = "Murderer"
		elseif holds(p, "Gun") then
			r = "Sheriff"
		end
		if r and (not rec or rec.r ~= r) then
			roles[p] = {r = r, c = p.Character}
			rec = roles[p]
		end
		if rec and rec.r == "Sheriff" and not alive(p) then
			sheriffDead = true
		end
	end
end

local function resetRoles()
	roles = {}
	sheriffDead = false
end

-- player visuals: highlight + name/role tag, rebuilt when the character changes
local function ensureVisual(p)
	local c = p.Character
	local head = c and c:FindFirstChild("Head")
	local v = visuals[p]
	if v and v.char ~= c then
		pcall(function() v.hl:Destroy() v.bb:Destroy() end)
		visuals[p] = nil
		v = nil
	end
	if not c or not head then return nil end
	if not v then
		local hl = Instance.new("Highlight")
		hl.Adornee = c
		hl.FillTransparency = 0.6
		hl.OutlineTransparency = 0
		hl.Parent = c

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(200, 36)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = head
		bb.Parent = c

		local lb = Instance.new("TextLabel")
		lb.Size = UDim2.fromScale(1, 1)
		lb.BackgroundTransparency = 1
		lb.Font = Enum.Font.GothamBold
		lb.TextSize = 14
		lb.TextStrokeTransparency = 0
		lb.Parent = bb

		v = {char = c, hl = hl, bb = bb, lb = lb}
		visuals[p] = v
	end
	return v
end

local function refreshPlayers()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local v = ensureVisual(p)
			if v then
				local role = roleOf(p)
				local col = COLORS[role]
				local dead = not alive(p)
				v.hl.Enabled = CONFIG.ShowESP
				v.hl.FillColor = col
				v.hl.OutlineColor = col
				v.bb.Enabled = CONFIG.ShowRoles
				v.lb.TextColor3 = col
				v.lb.Text = (dead and "[DEAD] " or "") .. role .. " | " .. p.DisplayName
			end
		end
	end
end

-- gun ESP
local function refreshGun()
	local show = CONFIG.ShowGun and (CONFIG.GunAlways or sheriffDead)
	local g = show and workspace:FindFirstChild("GunDrop", true) or nil
	if not g then
		if gunHL then gunHL.Enabled = false end
		if gunBB then gunBB.Enabled = false end
		return
	end
	if g ~= gunObj then
		pcall(function() gunHL:Destroy() gunBB:Destroy() end)
		gunObj = g
		local part = g:IsA("BasePart") and g or g:FindFirstChildWhichIsA("BasePart", true)
		if not part then return end
		gunHL = Instance.new("Highlight")
		gunHL.Adornee = g
		gunHL.FillColor = COLORS.Gun
		gunHL.OutlineColor = COLORS.Gun
		gunHL.FillTransparency = 0.4
		gunHL.Parent = g
		gunBB = Instance.new("BillboardGui")
		gunBB.Size = UDim2.fromOffset(120, 24)
		gunBB.StudsOffset = Vector3.new(0, 2, 0)
		gunBB.AlwaysOnTop = true
		gunBB.Adornee = part
		gunBB.Parent = g
		local lb = Instance.new("TextLabel")
		lb.Size = UDim2.fromScale(1, 1)
		lb.BackgroundTransparency = 1
		lb.Font = Enum.Font.GothamBold
		lb.TextSize = 14
		lb.TextColor3 = COLORS.Gun
		lb.TextStrokeTransparency = 0
		lb.Text = "GUN"
		lb.Parent = gunBB
	end
	gunHL.Enabled = true
	gunBB.Enabled = true
end

-- aimbot
local function aimHead()
	local cam = workspace.CurrentCamera
	local ctr = cam.ViewportSize / 2
	local wantMurd = CONFIG.AimTarget == "Murderer" and roleOf(LP) ~= "Murderer"
	local best, bestD
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and alive(p) and (not wantMurd or roleOf(p) == "Murderer") then
			local hd = p.Character and p.Character:FindFirstChild("Head")
			if hd then
				local sp, on = cam:WorldToViewportPoint(hd.Position)
				if on and sp.Z > 0 then
					local d = (Vector2.new(sp.X, sp.Y) - ctr).Magnitude
					if d <= CONFIG.FOV and (not bestD or d < bestD) then
						best, bestD = hd, d
					end
				end
			end
		end
	end
	return best
end

RS.RenderStepped:Connect(function()
	if not CONFIG.Aimbot then return end
	local hd = aimHead()
	if hd then
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, hd.Position), CONFIG.Smooth)
	end
end)

-- main loop
local acc = 0
RS.Heartbeat:Connect(function(dt)
	acc = acc + dt
	if acc < CONFIG.RefreshRate then return end
	acc = 0
	scan()
	refreshPlayers()
	refreshGun()
end)

Players.PlayerRemoving:Connect(function(p)
	roles[p] = nil
	local v = visuals[p]
	if v then
		pcall(function() v.hl:Destroy() v.bb:Destroy() end)
		visuals[p] = nil
	end
end)

-- ===== menu =====
local gui = Instance.new("ScreenGui")
gui.Name = "AetherHub!"
gui.ResetOnSpawn = false
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local PURPLE = Color3.fromRGB(120, 60, 220)
local DARK = Color3.fromRGB(40, 34, 56)

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(230, 360)
main.Position = UDim2.new(0, 20, 0.5, -180)
main.BackgroundColor3 = Color3.fromRGB(20, 14, 30)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = PURPLE
title.BorderSizePixel = 0
title.Text = "Aether"
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

-- drag by the title bar
do
	local dragging, startPos, startFrame
	title.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startPos = i.Position
			startFrame = main.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startPos
			main.Position = UDim2.new(startFrame.X.Scale, startFrame.X.Offset + d.X, startFrame.Y.Scale, startFrame.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local list = Instance.new("Frame")
list.Position = UDim2.fromOffset(10, 40)
list.Size = UDim2.new(1, -20, 1, -50)
list.BackgroundTransparency = 1
list.Parent = main
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function makeButton(order, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 28)
	b.LayoutOrder = order
	b.BackgroundColor3 = DARK
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.Parent = list
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.Activated:Connect(onClick)
	return b
end

local function paintToggle(b, label, on)
	b.Text = label .. ": " .. (on and "ON" or "OFF")
	b.BackgroundColor3 = on and PURPLE or DARK
end

local function toggleButton(order, label, key, onChange)
	local b
	b = makeButton(order, function()
		CONFIG[key] = not CONFIG[key]
		paintToggle(b, label, CONFIG[key])
		if onChange then onChange(CONFIG[key]) end
	end)
	paintToggle(b, label, CONFIG[key])
	return b
end

toggleButton(1, "Role Tags", "ShowRoles")
toggleButton(2, "Player ESP", "ShowESP")
toggleButton(3, "Gun ESP", "ShowGun")
toggleButton(4, "Gun Always", "GunAlways")
toggleButton(5, "AIMBOT", "Aimbot")

local targetBtn
targetBtn = makeButton(6, function()
	CONFIG.AimTarget = (CONFIG.AimTarget == "Murderer") and "Nearest" or "Murderer"
	targetBtn.Text = "Aim at: " .. CONFIG.AimTarget
end)
targetBtn.Text = "Aim at: " .. CONFIG.AimTarget

-- number boxes for FOV and smoothness
local function numberRow(order, label, key, mn, mx)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.LayoutOrder = order
	row.BackgroundColor3 = DARK
	row.BorderSizePixel = 0
	row.Parent = list
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(.6, 0, 1, 0)
	l.Position = UDim2.fromOffset(8, 0)
	l.BackgroundTransparency = 1
	l.Text = label
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 12
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = row
	local tb = Instance.new("TextBox")
	tb.Size = UDim2.new(.36, -6, 0, 20)
	tb.Position = UDim2.new(.64, 0, .5, -10)
	tb.BackgroundColor3 = Color3.fromRGB(30, 24, 44)
	tb.BorderSizePixel = 0
	tb.Text = tostring(CONFIG[key])
	tb.Font = Enum.Font.Gotham
	tb.TextSize = 12
	tb.TextColor3 = Color3.new(1, 1, 1)
	tb.ClearTextOnFocus = false
	tb.Parent = row
	tb.FocusLost:Connect(function()
		local n = tonumber(tb.Text)
		if n then
			CONFIG[key] = math.clamp(n, mn, mx)
		end
		tb.Text = tostring(CONFIG[key])
	end)
end
numberRow(7, "FOV", "FOV", 10, 800)
numberRow(8, "Smoothness (0-1)", "Smooth", 0.01, 1)

makeButton(9, function() resetRoles() end).Text = "Reset Roles (new round)"

local closeBtn = makeButton(10, function() main.Visible = false end)
closeBtn.Text = "Hide Menu (RightShift)"

UIS.InputBegan:Connect(function(i, g)
	if g then return end
	if i.KeyCode == Enum.KeyCode.RightShift then
		main.Visible = not main.Visible
	end
end)

print("[MM2 Helper] loaded. RightShift = menu")
