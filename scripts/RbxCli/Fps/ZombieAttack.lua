
-- Game name: Zombie Attack
-- Game Id: 504035427
-- Game UniverseId: 504035427
-- Game PlaceIds: 1240123653, 
-- Game link: https://www.roblox.com/games/1240123653/Zombie-Attack
-- Script version: 1.0.0


--!grant Filesystem
--!grant Hybrid


if not rbxcli or game.UniverseId ~= 504035427 then error("You seem to be in the wrong game or not using rbxcli?") end


--#region Helpers

local CurrentLogFile = nil
local ScriptStart = os.clock()

local DebugRateLimit = {}
local DebugPrefixHandler = { print = '+', debug = '!', warn = '-' }
local DebugHandler = { print = print, debug = print, warn = warn }


if _G.KittyDebugEnabled then
  local Path = "KittyScripts/Babft/logs/"
  local FileName = Path .. "log_" .. os.date("%Y-%m-%d") .. "_" .. ".diff"

  local Header = {
    "! Date: " .. os.date("%A, %B %d, %Y"),
    "! Time: " .. os.date("%X"),
    "\n\n"
  }

  if not fs.is_directory(Path) then fs.create_directory(Path) end
  if not fs.is_file(FileName) then fs.create_file(FileName) end

  fs.write_async(FileName, buffer.fromstring(table.concat(Header, "\n")))

  warn("Debug mode is on. Logging to: Workspace/" .. Path .. FileName)

  CurrentLogFile = FileName
end


local function DebugPrint(mode: "print" | "debug" | "warn", maxAmount: number, stackOffset: number, ...: string | number): ()
  if not _G.KittyDebugEnabled then return end

  local ModeLower = string.lower(mode)

  local args = table.pack(...)
  local MessageParts = table.create(args.n)

  for i = 1, args.n do MessageParts[i] = tostring(args[i]) end

  local FinalMessage = table.concat(MessageParts, " ")
  local RateKey = ModeLower .. ":" .. FinalMessage

  if  maxAmount ~= 0 then
    local CurrentTime = os.clock()
    local RateData = DebugRateLimit[RateKey]

    if not RateData then
      RateData = { WindowStart = CurrentTime, Count = 0 }
      DebugRateLimit[RateKey] = RateData
    end

    if CurrentTime - RateData.WindowStart >= 1 then
      RateData.WindowStart = CurrentTime
      RateData.Count = 0
    end

    if RateData.Count >= maxAmount then return end

    RateData.Count += 1
  end

  local DebugLine, FunctionName = debug.info((stackOffset or 1) + 1, "ln")
  local TimestampFormatted = string.format("%.4f", os.clock() - ScriptStart)
  local RealFinalMessage = string.format("%s [%s] [line: %s || func: %s] [%s]: %s", DebugPrefixHandler[ModeLower], TimestampFormatted, tostring(DebugLine), ((FunctionName and FunctionName ~= "") and FunctionName or "<none>"), ModeLower, FinalMessage)

  DebugHandler[ModeLower](RealFinalMessage)

  if CurrentLogFile then fs.append_async(CurrentLogFile, buffer.fromstring(RealFinalMessage .. "\n")) end
end



local function IsValid(instance: Instance): boolean
  return (instance and not instance:IsInvalidInstance())
end

local function TraversePath(root: Instance, ...: string): Instance?
  local CurrentInstance = root

  for _, name in {...} do
    if not CurrentInstance then return nil end

    local NextInstance = CurrentInstance:FindFirstChild(name); if not IsValid(NextInstance) then return nil end
    CurrentInstance = NextInstance
  end

  return CurrentInstance
end





local function GetOffsets()
  local RobloxVersion = nil; for index, value in rbxcli.get_product_information() do if index ~= "built_for_roblox_version" then continue end; RobloxVersion = value; DebugPrint("debug", nil, 1, "Found the roblox version: " .. tostring(RobloxVersion), ". Proceeding with fetching offsets") end
  local OffsetsJson = game:GetService("HttpService"):RequestAsync({ Body = nil, Headers = nil, Method = "GET", Url = "https://imtheo.lol/Offsets/" .. tostring(RobloxVersion) .. "/Offsets.json" }); if not OffsetsJson then DebugPrint("warn", 1, 1, "Failed to fetch offsets?"); return nil end

  local OffsetsDecoded = game:GetService("HttpService"):JSONDecode(OffsetsJson.Body); if not OffsetsDecoded then return nil end

  return OffsetsDecoded
end; local FakeOffsets = GetOffsets(); if not FakeOffsets or not next(FakeOffsets) then DebugPrint("warn", nil, 0, "Failed to fetch offsets corectly. Offsets: " .. tostring(FakeOffsets)); return end





--#endregion Helpers

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local CurrentCharacter = LocalPlayer.Character



local EnemiesFolder = Workspace:WaitForChild("enemies")
local BossFolder = Workspace:WaitForChild("BossFolder")

local AmICurrentlyInGame = false

local ModifiedEnemies: {string: boolean} = {}

--#region Functions
local function GetCharacter(player: Player) return player.Character :: Model end
local function GetHrp(character: Model) return character:FindFirstChildCached("HumanoidRootPart") end
local function GetHumanoid(character: Model) return character:FindFirstChildCached("Humanoid") end


local function AmIInGame(): boolean
  local Backpack = LocalPlayer:FindFirstChild("Backpack"); if not IsValid(Backpack) then return false end
  return Backpack:FindFirstChildOfClass("Tool") ~= nil
end


local function EquipGun()
  local CharacterGun = CurrentCharacter:FindFirstChildOfClass("Tool")

  if CharacterGun then -- may be sword
    if TraversePath(CharacterGun, "Handle", "Fire") then
      DebugPrint("debug", 2, 1, "The gun seems to be already equipped.")
      return
    end 
  end -- So gun is equipped

  local Gun = nil
  for _, tool in LocalPlayer:WaitForChild("Backpack"):GetChildren() do
    if TraversePath(tool, "Handle", "Fire") then
      Gun = tool
      DebugPrint("debug", 2, 1, "Sucesfully found the gun inside backpack.")
    end
  end 

  if not IsValid(Gun) then return end
  rbxcli.reparent(Gun, CurrentCharacter)
  DebugPrint("debug", 2, 1, "Sucesfully re-parented the gun to the current character.")
end


local function SmartPositioning(currentPosition: Vector3, direction: Vector3, maxDistance: number)
  local Result = physics.raycast(currentPosition, direction, maxDistance)
end


--#endregion Functions

LocalPlayer.CharacterAdded:Connect(function(character)
  CurrentCharacter = character
end)



for _, tbl in gc.getgc("table") do
  if not tbl.Value:ContainsKey("BulletsPerShot") then continue end
  tbl.Value.Spread = 0
  tbl.Value.Automatic = true
end


task.spawn(function()
  while task.wait(1) do
    AmICurrentlyInGame = AmIInGame()
    EquipGun()
  end
end)

task.spawn(function()
  while task.wait(1/15) do
    for _, enemy in EnemiesFolder:GetChildren() do
      if not ModifiedEnemies[enemy.Address] then
        local Hrp = GetHrp(enemy); if not IsValid(Hrp) then continue end
        Hrp.Size = Vector3.new(5, 5, 5)
        ModifiedEnemies[enemy.Address] = true
      end
    end
  end
end)


RunService.PreRender:Connect(function(delta)
  if not AmICurrentlyInGame then return end
  local Enemy = EnemiesFolder:FindFirstChildOfClass("Model") or BossFolder:FindFirstChildOfClass("Model")
  
  if not IsValid(Enemy) then DebugPrint("debug", 3, 0, "No enemy found?"); return end
  local EnemyHrp = GetHrp(Enemy); if not IsValid(EnemyHrp) then return end
  
  local TargetPos = EnemyHrp.Position
  local ScreenTargetPos = rendering.world_to_screen(TargetPos)


  local MyHrp = GetHrp(CurrentCharacter); if not IsValid(MyHrp) then return end

  MyHrp.Position = TargetPos + Vector3.new(0, 12, 0)

  if rendering.is_on_screen(TargetPos) and ScreenTargetPos then
    input.mouse_move_absolute(ScreenTargetPos)
    input.mouse_click(1)
  end
end)
