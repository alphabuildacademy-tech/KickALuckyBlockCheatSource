local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getRemoteEvent(name)
    local networkFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Network")
    return networkFolder:WaitForChild("rev_" .. name, 5)
end

local KickEventRemote, SpeedUpgradeRemote, BCollectRemote
local function ensureRemotes()
    if not KickEventRemote then KickEventRemote = getRemoteEvent("KickEvent") end
    if not SpeedUpgradeRemote then SpeedUpgradeRemote = getRemoteEvent("SPEED_UPGRADE") end
    if not BCollectRemote then BCollectRemote = getRemoteEvent("B_Collect") end
end

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kurbywtww/customui/refs/heads/main/custom.lua"))()

local autoFarm = false
local antiAFK = false
local infiniteJump = false
local autoUpgradeSpeed = false
local autoCollectMoney = false

local autoFarmTask = nil
local autoUpgradeTask = nil
local autoCollectTask = nil
local infiniteJumpConn = nil
local antiAFKConn = nil

local toggles = {}

local function randomWait(min, max)
    task.wait(math.random(min * 1000, max * 1000) / 1000)
end

local function getCharacter()
    return LocalPlayer.Character
end

local function waitForCharacter()
    local char = getCharacter()
    if not char or not char.Parent then
        char = LocalPlayer.CharacterAdded:Wait()
    end
    return char
end

local function getPlayerCoins()
    local hud = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    if not hud then return 0 end
    local coinsFrame = hud:FindFirstChild("BottomLeft") and hud.BottomLeft:FindFirstChild("CoinsFrame")
    if not coinsFrame then return 0 end
    local inside = coinsFrame:FindFirstChild("InsideFrame")
    if not inside then return 0 end
    local label = inside:FindFirstChild("CoinLabel")
    if not label then return 0 end
    local text = label.Text
    if not text or text == "" then return 0 end
    local numStr = text:gsub("[^%d.]", "")
    local num = tonumber(numStr)
    if not num then return 0 end
    if text:find("K") then
        return num * 1000
    elseif text:find("M") then
        return num * 1000000
    elseif text:find("B") then
        return num * 1000000000
    end
    return num
end

local function startAntiAFK()
    if antiAFKConn then antiAFKConn:Disconnect() end
    if not antiAFK then return end
    local vu = game:GetService("VirtualUser")
    antiAFKConn = LocalPlayer.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end

local function setupInfiniteJump()
    if infiniteJumpConn then infiniteJumpConn:Disconnect() end
    if not infiniteJump then return end
    infiniteJumpConn = UserInputService.JumpRequest:Connect(function()
        local char = getCharacter()
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Jump = true
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(0.05)
            humanoid:ChangeState(Enum.HumanoidStateType.Landed)
        end
    end)
end

local function autoUpgradeLoop()
    local lastWarn = 0
    while autoUpgradeSpeed do
        ensureRemotes()
        local coins = getPlayerCoins()
        if coins < 100 then
            if tick() - lastWarn > 10 then
                Library:Notify("Auto Upgrade Speed", "Insufficient coins to upgrade!", 3)
                lastWarn = tick()
            end
        end
        if SpeedUpgradeRemote and coins >= 100 then
            SpeedUpgradeRemote:FireServer(1)
        end
        randomWait(1, 2)
    end
end

local function autoFarmLoop()
    while autoFarm do
        local char = waitForCharacter()
        local humanoid = char:FindFirstChild("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart then
            randomWait(0.5, 1)
            continue
        end

        local kickReady = workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild("KickReady")
        if not kickReady then
            randomWait(2, 3)
            continue
        end

        rootPart.CFrame = kickReady.CFrame + Vector3.new(0, 5, 0)
        randomWait(0.5, 1)

        ensureRemotes()
        if KickEventRemote then
            KickEventRemote:FireServer(1)
        end

        randomWait(2, 3)

        local targetPos = kickReady.Position
        humanoid:MoveTo(targetPos)

        while autoFarm and (rootPart.Position - targetPos).Magnitude > 10 do
            task.wait(0.2)
            char = getCharacter()
            if not char or not char.Parent then break end
            rootPart = char:FindFirstChild("HumanoidRootPart")
            humanoid = char:FindFirstChild("Humanoid")
            if not rootPart or not humanoid then break end
            if humanoid.MoveDirection.Magnitude < 0.2 then
                humanoid:MoveTo(targetPos)
            end
        end

        if humanoid then humanoid:MoveTo(rootPart.Position) end
        randomWait(0.5, 1)
    end
end

local function getPlayerPlot()
    for _, plot in ipairs(workspace.Plots:GetChildren()) do
        if plot:IsA("Model") and plot:GetAttribute("Owner") == LocalPlayer.Name then
            return plot
        end
    end
    return nil
end

local function autoCollectMoneyLoop()
    while autoCollectMoney do
        ensureRemotes()
        local plot = getPlayerPlot()
        if plot and plot:FindFirstChild("Slots") then
            for _, slotPart in ipairs(plot.Slots:GetChildren()) do
                if slotPart:IsA("BasePart") then
                    local slotNum = tonumber((slotPart.Name:gsub("Slot", "")))
                    if slotNum and BCollectRemote then
                        pcall(function()
                            BCollectRemote:FireServer(slotNum)
                        end)
                        randomWait(0.2, 0.5)
                    end
                end
            end
        end
        randomWait(5, 10)
    end
end

local function resetAllSettings()
    autoFarm = false
    antiAFK = false
    infiniteJump = false
    autoUpgradeSpeed = false
    autoCollectMoney = false

    if autoFarmTask then task.cancel(autoFarmTask) autoFarmTask = nil end
    if autoUpgradeTask then task.cancel(autoUpgradeTask) autoUpgradeTask = nil end
    if autoCollectTask then task.cancel(autoCollectTask) autoCollectTask = nil end
    if infiniteJumpConn then infiniteJumpConn:Disconnect() infiniteJumpConn = nil end
    if antiAFKConn then antiAFKConn:Disconnect() antiAFKConn = nil end

    if toggles.autoFarmToggle then toggles.autoFarmToggle:Set(false) end
    if toggles.autoUpgradeToggle then toggles.autoUpgradeToggle:Set(false) end
    if toggles.autoCollectToggle then toggles.autoCollectToggle:Set(false) end
    if toggles.antiAFKToggle then toggles.antiAFKToggle:Set(false) end
    if toggles.infiniteJumpToggle then toggles.infiniteJumpToggle:Set(false) end

    Library:Notify("Settings", "All settings have been reset", 3)
end

local function onCharacterAdded(character)
    if infiniteJump then setupInfiniteJump() end
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if getCharacter() then onCharacterAdded(getCharacter()) end

local Window = Library:CreateWindow("Kick A Lucky Block")
local MainTab = Window:CreateTab("Main", "home")
local VisualsTab = Window:CreateTab("Visuals", "eye")
local SettingsTab = Window:CreateTab("Settings", "settings")

local MainSub = MainTab:CreateSubTab("Main", "home")
local MainContent = MainSub:CreateSection("Main Features")

local autoFarmToggle = MainContent:CreateToggle("Auto Farm (Kick)", false, function(state)
    autoFarm = state
    if autoFarmTask then task.cancel(autoFarmTask) end
    if autoFarm then autoFarmTask = task.spawn(autoFarmLoop) end
end)
toggles.autoFarmToggle = autoFarmToggle

local autoUpgradeToggle = MainContent:CreateToggle("Auto Upgrade Speed", false, function(state)
    autoUpgradeSpeed = state
    if autoUpgradeTask then task.cancel(autoUpgradeTask) end
    if autoUpgradeSpeed then autoUpgradeTask = task.spawn(autoUpgradeLoop) end
end)
toggles.autoUpgradeToggle = autoUpgradeToggle

local autoCollectToggle = MainContent:CreateToggle("Auto Collect Money", false, function(state)
    autoCollectMoney = state
    if autoCollectTask then task.cancel(autoCollectTask) end
    if autoCollectMoney then autoCollectTask = task.spawn(autoCollectMoneyLoop) end
end)
toggles.autoCollectToggle = autoCollectToggle

local antiAFKToggle = MainContent:CreateToggle("Anti-AFK", false, function(state)
    antiAFK = state
    if antiAFK then startAntiAFK()
    elseif antiAFKConn then antiAFKConn:Disconnect() end
end)
toggles.antiAFKToggle = antiAFKToggle

local VisualsSub = VisualsTab:CreateSubTab("Movement", "zap")
local VisualsContent = VisualsSub:CreateSection("Movement")

local infiniteJumpToggle = VisualsContent:CreateToggle("Infinite Jump", false, function(state)
    infiniteJump = state
    if infiniteJump then setupInfiniteJump()
    elseif infiniteJumpConn then infiniteJumpConn:Disconnect() end
end)
toggles.infiniteJumpToggle = infiniteJumpToggle

local SettingsSub = SettingsTab:CreateSubTab("Settings", "settings")
local SettingsContent = SettingsSub:CreateSection("Utility")

SettingsContent:CreateButton("Rejoin Game", function()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

SettingsContent:CreateButton("Reset Settings", function()
    resetAllSettings()
end)

Library:Notify("Kick A Lucky Block", "Script loaded! Use RightShift to toggle GUI.", 5)