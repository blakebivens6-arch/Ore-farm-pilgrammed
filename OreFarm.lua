-- OreFarm.lua
-- Ore farming engine (depends on ReplicatedStorage.LoaderReady)
-- Equips any "Gemstone" "Pickaxe" in backpack/character and fires LocalPlayer.Slash with args {[1]=1}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local task = task

local player = Players.LocalPlayer

local OreFarm = {}
OreFarm.Enabled = false
OreFarm.SelectedLocation = "BearIsland"
OreFarm.SelectedOreType = nil
OreFarm.TeleportDelay = 1.5
OreFarm.MINE_DELAY = 1.4
OreFarm.AUTO_RANDOM_FALLBACK = true
OreFarm.MIN_DISTANCE_FOR_TP = 6
OreFarm.TP_RETRIES = 12
OreFarm.SAFEZONE_PATH = {"Map","PrairieVillage","Statue"}
OreFarm.MINER_REMOTE_NAME = nil -- not used; we use LocalPlayer.Slash
OreFarm.LOG = true

-- Known ore types fallback list (you gave these)
OreFarm.KNOWN_ORES = {"Zinc","Tin","Copper","Iron","Silver","Sulfur","Demetal","Mythril","Ruby","Emerald","Diamond","Sapphire"}

local root
local function log(...) if OreFarm.LOG then print("[OreFarm]", ...) end end

local function getAnyPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart end
        for _, c in ipairs(obj:GetDescendants()) do
            if c:IsA("BasePart") then return c end
        end
    end
    return nil
end

local function waitForLoader()
    local loaderFlag = ReplicatedStorage:WaitForChild("LoaderReady")
    repeat task.wait(0.2) until loaderFlag.Value
    log("LoaderReady detected.")
end

local function ensureRoot()
    if root and root.Parent then return end
    local char = player.Character or player.CharacterAdded:Wait()
    root = char:WaitForChild("HumanoidRootPart")
end

local function TryTP(target)
    ensureRoot()
    local part = getAnyPart(target)
    if not part then return false end

    for i = 1, OreFarm.TP_RETRIES do
        pcall(function() root.CFrame = part.CFrame end)
        task.wait(0.12)
        local ok, dist = pcall(function() return (root.Position - part.Position).Magnitude end)
        if ok and dist and dist < OreFarm.MIN_DISTANCE_FOR_TP then
            return true
        end
    end

    -- emergency safezone reposition then final retry
    local safe = Workspace
    for _, name in ipairs(OreFarm.SAFEZONE_PATH) do
        safe = safe:FindFirstChild(name) or safe
    end
    local safePart = getAnyPart(safe)
    if safePart then
        pcall(function() root.CFrame = safePart.CFrame end)
        task.wait(0.25)
    end

    local part2 = getAnyPart(target)
    if part2 then
        pcall(function() root.CFrame = part2.CFrame end)
        task.wait(0.12)
    end
    return true
end

function OreFarm.GetAvailableLocations()
    local out = {}
    local oresRoot = Workspace:FindFirstChild("Ores")
    if not oresRoot then return out end
    for _, loc in ipairs(oresRoot:GetChildren()) do
        if loc:IsA("Folder") or loc:IsA("Model") then
            table.insert(out, loc.Name)
        end
    end
    return out
end

function OreFarm.ScanAllOreTypes()
    local types = {}
    local seen = {}
    local oresRoot = Workspace:FindFirstChild("Ores")
    if not oresRoot then
        -- fallback to known list
        for _, v in ipairs(OreFarm.KNOWN_ORES) do table.insert(types, v) end
        return types
    end

    for _, loc in ipairs(oresRoot:GetChildren()) do
        for _, node in ipairs(loc:GetChildren()) do
            local part = node:FindFirstChild("Part") or node:FindFirstChildWhichIsA("BasePart")
            if part then
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA("BasePart") or child:IsA("Model") or child:IsA("MeshPart") or child:IsA("UnionOperation") or child:IsA("Folder") then
                        local tname = child.Name
                        if tname and not seen[tname] then
                            seen[tname] = true
                            table.insert(types, tname)
                        end
                    end
                end
            end
        end
    end

    if #types == 0 then
        for _, v in ipairs(OreFarm.KNOWN_ORES) do table.insert(types, v) end
    else
        table.sort(types)
    end
    return types
end

local function getNodesWithOre(locationName, oreName)
    local out = {}
    local oresRoot = Workspace:FindFirstChild("Ores")
    if not oresRoot then return out end
    local loc = oresRoot:FindFirstChild(locationName)
    if not loc then return out end

    for _, node in ipairs(loc:GetChildren()) do
        local part = node:FindFirstChild("Part") or node:FindFirstChildWhichIsA("BasePart")
        if part then
            if not oreName then
                if #part:GetChildren() > 0 then table.insert(out, node) end
            else
                local child = part:FindFirstChild(oreName)
                if child then table.insert(out, node) end
            end
        end
    end
    return out
end

local function chooseNode()
    local location = OreFarm.SelectedLocation
    if not location then return nil end

    if OreFarm.SelectedOreType and OreFarm.SelectedOreType ~= "" then
        local nodes = getNodesWithOre(location, OreFarm.SelectedOreType)
        if #nodes > 0 then
            return nodes[math.random(1,#nodes)], OreFarm.SelectedOreType
        end
        if not OreFarm.AUTO_RANDOM_FALLBACK then
            return nil
        end
    end

    local anyNodes = getNodesWithOre(location, nil)
    if #anyNodes > 0 then
        local chosen = anyNodes[math.random(1,#anyNodes)]
        local part = chosen:FindFirstChild("Part") or chosen:FindFirstChildWhichIsA("BasePart")
        if part then
            local children = part:GetChildren()
            if #children > 0 then
                local oreChild = children[math.random(1,#children)]
                return chosen, oreChild.Name
            end
        end
    end
    return nil
end

-- equip any Gemstone pickaxe found (search Backpack and Character)
local function equipGemstonePickaxe()
    ensureRoot()
    local humanoid = root.Parent and root.Parent:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then return false end

    -- search Character first
    for _, item in ipairs(player.Character:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower():find("gem") and item.Name:lower():find("pick") then
            pcall(function() humanoid:EquipTool(item) end)
            return true
        end
    end

    -- search Backpack
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find("gem") and item.Name:lower():find("pick") then
                pcall(function() humanoid:EquipTool(item) end)
                return true
            end
        end
    end

    return false
end

local function mineAtNode(node, oreType)
    if not node then return false end
    local part = node:FindFirstChild("Part") or node:FindFirstChildWhichIsA("BasePart")
    if not part then return false end

    local oreChild = (oreType and part:FindFirstChild(oreType)) or part:GetChildren()[1]
    if not oreChild then return false end

    local tpTarget = oreChild:IsA("BasePart") and oreChild or oreChild:FindFirstChildWhichIsA("BasePart") or part
    TryTP(tpTarget)
    task.wait(OreFarm.TeleportDelay)

    -- equip pickaxe if available
    pcall(function()
        equipGemstonePickaxe()
    end)

    -- call player Slash remote
    local ok, fired = pcall(function()
        local slash = player:WaitForChild("Slash", 2)
        if slash and slash.FireServer then
            local args = {[1] = 1}
            slash:FireServer(unpack(args))
        elseif slash and slash.InvokeServer then
            local args = {[1] = 1}
            slash:InvokeServer(unpack(args))
        else
            -- fallback: nothing, just wait MINE_DELAY
        end
    end)

    task.wait(OreFarm.MINE_DELAY)
    return true
end

task.spawn(function()
    waitForLoader()
    ensureRoot()
    while true do
        task.wait(0.12)
        if not OreFarm.Enabled then continue end
        if not OreFarm.SelectedLocation then task.wait(0.5); continue end

        local node, oreType = chooseNode()
        if not node then
            log("No nodes found; waiting then retrying...")
            task.wait(1.5)
            continue
        end

        local ok = mineAtNode(node, oreType)
        if ok then
            log("Mined ore:", oreType, "at node:", node.Name)
        else
            log("Failed to mine:", node and node.Name or "nil")
        end

        task.wait(0.2)
    end
end)

return OreFarm

