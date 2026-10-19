-- MM2 helper: role tags (Murderer / Sheriff / Innocent), player ESP, and gun ESP
-- The gun ESP appears after the sheriff dies (or always, if you set GunAlways = true).

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local CONFIG = {
	ShowRoles = true,
	ShowESP = true,
	ShowGun = true,
	GunAlways = false,   -- false = gun only shows after the sheriff dies
	RefreshRate = 0.25,
}

local COLORS = {
	Murderer = Color3.fromRGB(255, 60, 60),
	Sheriff = Color3.fromRGB(60, 140, 255),
	Innocent = Color3.fromRGB(60, 230, 110),
	Gun = Color3.fromRGB(255, 220, 60),
}

local roles = {}        -- player -> "Murderer" | "Sheriff" (kept after the tool is put away)
local visuals = {}      -- player -> {char, hl, bb, lb}
local sheriffDead = false
local gunObj, gunHL, gunBB

-- Tools are only visible on other players while they're holding them, so roles are cached once seen.
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
	for _, p in ipairs(Players:GetPlayers()) do
		if roles[p] == nil then
			if holds(p, "Knife") then
				roles[p] = "Murderer"
			elseif holds(p, "Gun") then
				roles[p] = "Sheriff"
			end
		end
		if roles[p] == "Sheriff" and not alive(p) then
			sheriffDead = true
		end
	end
end

local function resetRound()
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
				local role = roles[p] or "Innocent"
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
local function findGun()
	return workspace:FindFirstChild("GunDrop", true)
end

local function refreshGun()
	local show = CONFIG.ShowGun and (CONFIG.GunAlways or sheriffDead)
	local g = show and findGun() or nil
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

-- hotkeys: F6 toggles player ESP, F7 toggles the gun ESP, F8 clears the cached roles
UIS.InputBegan:Connect(function(i, g)
	if g then return end
	if i.KeyCode == Enum.KeyCode.F6 then
		CONFIG.ShowESP = not CONFIG.ShowESP
	elseif i.KeyCode == Enum.KeyCode.F7 then
		CONFIG.ShowGun = not CONFIG.ShowGun
	elseif i.KeyCode == Enum.KeyCode.F8 then
		resetRound()
	end
end)

Players.PlayerRemoving:Connect(function(p)
	roles[p] = nil
	local v = visuals[p]
	if v then
		pcall(function() v.hl:Destroy() v.bb:Destroy() end)
		visuals[p] = nil
	end
end)

-- a new round usually respawns your character, so clear the old roles then
LP.CharacterAdded:Connect(function()
	task.wait(1)
	resetRound()
end)

print("[AetherHub] running. F6 = player ESP, F7 = gun ESP, F8 = reset roles")
