--[[ 
information:
  * Game name: Attack on Titans Revolution
  * Game Id: 4658598196
  * Game UniverseId: 4658598196
  * Game link: https://www.roblox.com/games/13379208636/Attack-on-Titan-Revolution

  * Script version: 1.0.0





  * I have decided to take another aproach and use a lot of caching, so if stuff breaks, blame me.
  * todo:
    * 
]]



warn("Kitty script running")




local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local CurrentMission: string?;
local GasTank;


local SafePos = Vector3.new(900, 9999, 900) -- Maybe search a better version instead of just air..?

local MathSin = math.sin
local MathPi = math.pi

local OsClock = os.clock

local StringLower = string.lower

type TitanEntry = {
  Instance: Instance?,

  Info: {
    Name: string?,
    Type: string?
  },

  Parts: {
    Nape: BasePart?,
    Hrp: BasePart?
  },

  Nape: {
    OriginalSize: Vector3?,
    CurrentSize: Vector3?
  },
  State: {
    Alive: boolean
  },

  Esp: {
    Lines: any
  }
}


--#region -- Start of functions!
local function DebugPrint(Mode: string, ...: string)
  local Message = ...
  local ModeLower = StringLower(Mode)

  if ModeLower == "print" then
    print("[Kitty's Aotr] [print]: " .. Message)
  elseif ModeLower == "warn" then
    warn("[Kitty's Aotr] [warn]: " .. Message)
  elseif ModeLower == "debug" then
    print("[Kitty's Aotr] [debug]: " .. Message)
  end



end





local function GetPath(root: Instance, Warning: boolean, ...): Instance?
  local CurrentInstance = root
  local args = {...}

  for _, name in ipairs(args) do
    if not CurrentInstance then
      if Warning then warn("Path broke for: " .. name) end
      return nil
    end

    local NextInstance = CurrentInstance:FindFirstChild(name)
    if not NextInstance then
      if Warning then warn("Missing: " .. name .. " in " .. CurrentInstance:GetFullName()) end
      return nil
    end

    CurrentInstance = NextInstance
  end

  return CurrentInstance
end


local function GetOffsets()
  local ok, res = pcall(function()
    return game:HttpGet("https://imtheo.lol/Offsets/Offsets.json")
  end)

  if not ok or not res then
    warn("Failed to fetch offsets: " .. tostring(res))
    return {}
  end

  local success, decoded = pcall(function()
    return HttpService:JSONDecode(res)
  end)

  if not success then
    warn("JSON decode failed")
    return {}
  end

  return decoded
end


local function HandleDifferentGasTankPaths()
  local Shiganshina = GetPath(Workspace, false, "Climbable", "Walls", "Gate", "GasTanks"); if Shiganshina then print("Shiganshina detected!"); GasTank = Shiganshina; return Shiganshina end
  local Trost = GetPath(Workspace, false,       "Unclimbable", "Camps", "Camp", "GasTanks"); if Trost then print("Trost detected!"); GasTank = Trost; return Trost end
  local OutSkirts = GetPath(Workspace, false,   "Climbable", "_Walls", "Gate", "GasTanks"); if OutSkirts then print("Outskirts detected!"); GasTank = OutSkirts; return OutSkirts end
  local Forest = GetPath(Workspace, false,      "Unclimbable", "Camps", "Camp", "GasTanks"); if Forest then print("Forest detected!"); GasTank = Forest; return Forest end
  local UtGard = GetPath(Workspace, false,      "Climbable", "Utgard", "GasTanks"); if UtGard then print("UtGard detected!"); GasTank = UtGard; return UtGard end
  local Docks = GetPath(Workspace, false,       "Unclimbable", "World", "Buildings", "Hanger", "GasTanks"); if Docks then print("Docks detected!"); GasTank = Docks; return Docks end
  local Stohess = GetPath(Workspace, false,     "Unclimbable", "Props", "HQ", "GasTanks"); if Stohess then print("Stohess detected!"); GasTank = Stohess; return Stohess end
  local Chapel = GetPath(Workspace, false,      "Unclimbable", "Reloads", "GasTanks"); if Chapel then print("Chapel detected!"); GasTank = Chapel; return Chapel end

  local Waves = GetPath(Workspace, false, "Unclimbable", "Objective", "Waves", "GasTanks");  if Waves then print("Waves detected!"); GasTank = Waves; return Waves end

  warn("No known GasTank path found!")
  return nil
end



-- // A little more variables!
local Offsets = GetOffsets().Offsets


local DownMiddlePartUi = GetPath(PlayerGui, true, "Interface", "HUD", "Main", "Top", "7"); if not DownMiddlePartUi then return end
local TitansFolder = GetPath(Workspace, true, "Titans"); if not TitansFolder then return end

local TitansCache: { [number]: TitanEntry } = {}

local function GetTitanCache(titan): TitanEntry?
  if not titan or not titan.Address then return nil end
  return TitansCache[titan.Address]
end


--== Offsets ==--
local PrimaryPartOffset = Offsets.Model.PrimaryPart; if not PrimaryPartOffset or PrimaryPartOffset == 0 then return end
local BaseToPrimitiveOffset = Offsets.BasePart.Primitive; if not BaseToPrimitiveOffset or BaseToPrimitiveOffset == 0 then return end
local PrimitivePositionOffset = Offsets.Primitive.Position; if not PrimitivePositionOffset or PrimitivePositionOffset == 0 then return end
local VisibleOffset = Offsets.GuiObject.Visible; if not VisibleOffset or VisibleOffset == 0 then return end

local ReloadingBlades = false
local LastReloadingTime = 0



local TitansInfo = {
  ["HeightStall"] = 100, -- idk if this is HRP OR NAPE, needs testng
  ["HeightAttack"] = 160,
  ["HeightColossal"] = 200, -- idk if this is HRP OR NAPE, needs testing

  ["BobAmplitude"] = 2,
  ["BobSpeed"] = 10,

}

local UserConfigs = {
  Autofarm = true
}


HandleDifferentGasTankPaths(); if not GasTank then error("No gas found? Please report this to @roguekitty. ( with dot )"); return end

-- // Generic functions \\ --
local function GetCharacter(player: Player): Model?
  local Character = player.Character
  return Character
end


local function GetHrp(instance: Instance): BasePart?
  local Hrp = instance:FindFirstChild("HumanoidRootPart")
  return Hrp
end


local function GetHumanoid(instance: Instance): Humanoid?
  local Humanoid = instance:FindFirstChildOfClass("Humanoid")
  return Humanoid
end


local function HandleDifferentMissions()
  -- Logic to get mission
end



-- // Titan functions \\ --
local function GetNapePart(titan): BasePart?
  if not titan or not titan.Parent then return nil end

  local TitanCache = GetTitanCache(titan); if not TitanCache then return end
  local CachedNape = TitanCache.Parts.Nape; if CachedNape then return CachedNape end

  local NapePart = GetPath(titan, true, "Hitboxes", "Hit", "Nape"); if not NapePart then return nil end

  TitanCache.Parts.Nape = NapePart
  return NapePart
end


local function ModifyNapeHitbox(titan, x: number, y: number, z: number): boolean?
  if not titan or not titan.Parent then return end

  local TitanCache = GetTitanCache(titan); if not TitanCache then return nil end
  local TitanNape: BasePart? = GetNapePart(titan); if not TitanNape then return nil end

  local Size = Vector3.new(x, y, z) -- Slighty more optimized, why not?

  TitanNape.Size = Size
  TitanCache.Nape.CurrentSize = Size
  return true
end


local function GetTitanType(titan: Instance): string? -- Needs more research
  local TitanCache = GetTitanCache(titan); if not TitanCache then return nil end
  local TitanTypeCached = TitanCache.Info.Type; if TitanTypeCached then return TitanTypeCached end

  local TitanType = titan:GetAttribute("Type") or "Attack"

  TitanCache.Info.Type = TitanType
  return TitanType
end


local function GetTitanBobHeight(titan: Instance): number?
  local TitanType = GetTitanType(titan); if not TitanType then return nil end

  return TitansInfo["Height" .. TitanType]
end


local function IsTitanAlive(titan): boolean
    if not titan or not titan.Parent then return false end

    local TitanCache = GetTitanCache(titan)
    local TitanHumanoid = GetHumanoid(titan); if not TitanHumanoid then return false end
    

    if not TitanCache then return TitanHumanoid.Health > 0 or false end

    local Alive = TitanHumanoid.Health > 0 or false
    TitanCache.State.Alive = Alive

    return Alive
end


local function TpAboveTitan(titan) -- This might require changes!
  if not titan or not titan.Parent then return end

  local TitanCache = GetTitanCache(titan); if not TitanCache then return end
 
  local TitanType: string? =  GetTitanType(titan); if not TitanType then return end

  local Character = GetCharacter(LocalPlayer); if not Character then return end
  local Hrp = GetHrp(Character); if not Hrp then return end


  local TitanNape: BasePart? = GetNapePart(titan); if not TitanNape then return end
  local NapePosition: Vector3 = TitanNape.Position

  local BobHeight = GetTitanBobHeight(titan)
  local BobOffset = MathSin(OsClock() * MathPi * 2) * TitansInfo.BobAmplitude


  Hrp.CFrame = CFrame.new(NapePosition.X, NapePosition.Y + BobHeight + BobOffset, NapePosition.Z)
end


local function BringNapeToPlayer(titan: Instance, size: Vector3?)
  if not titan or not titan.Parent then return end

  local TitanCache = GetTitanCache(titan); if not TitanCache then return end
  local Nape: BasePart? = TitanCache.Parts.Nape; if not Nape then return end

  local Character: Model? = GetCharacter(LocalPlayer); if not Character then return end
  local Hrp: BasePart? = GetHrp(Character); if not Hrp then return end

  Nape.CFrame = Hrp.CFrame * CFrame.new(0, 2, 0)
  if size then Nape.Size = size end
end


local function BringPartsToPlayer(titan: Instance, partNames: {string}, size: Vector3?)
  if not titan or not titan.Parent then return end

  local Character: Model? = GetCharacter(LocalPlayer); if not Character then return end
  local Hrp: BasePart? = GetHrp(Character); if not Hrp then return end
  local PlayerPos = Hrp.CFrame

  for _, partName in ipairs(partNames) do
    local part = GetPath(titan, false, "Hitboxes", "Hit", partName)
    if part and part:IsA("BasePart") then
      part.CFrame = PlayerPos * CFrame.new(0, 2, 0)
      if size then part.Size = size end
    end
  end
end


local function GetNearestTitan(): Instance? -- todo: Implement cache ( stop using TitanFolder:GetChildreN() ) !!
  local Character: Model? = GetCharacter(LocalPlayer); if not Character then return end
  local Hrp: BasePart? = GetHrp(Character); if not Hrp then return end
  local HrpPosition = Hrp.Position; if not HrpPosition then return end

  local ShortestDistance = math.huge
  local ShortestTitan = nil

  
  for i, titan in ipairs(TitansFolder:GetChildren()) do
    local TitanCache = GetTitanCache(titan); if not TitanCache then continue end

    local TitanHrp: BasePart? = TitanCache.Parts.Hrp or GetHrp(titan); if not TitanHrp then TitanCache.Parts.Hrp = TitanHrp; continue end
    local Distance = (HrpPosition - TitanHrp.Position).Magnitude

    if Distance < ShortestDistance then
      ShortestTitan = titan
      ShortestDistance = Distance
    end
  end

  if ShortestTitan then
    -- print("Shortest distance titan is: " .. tostring(ShortestTitan.Name))
  end

  return ShortestTitan
end


local function RegisterTitan(titan)
  if not titan or not titan.Address then warn("RegisterTitan: invalid titan or missing Address"); return end
  local address = titan.Address

  -- print("Cache lookup:", titan, TitansCache[address])
  -- print("Instance: ", titan, titan:GetFullName(), tostring(address))
  if TitansCache[address] then --[[print("Titan already cached: ", titan);]] return end


  TitansCache[address] = {
    Instance = titan,

    Info = {
      Name = titan.Name,
      Type = nil
    },

    Parts = {
      Nape = nil,
      Hrp = nil, -- Maybe later we add more :o
    },

    Nape = {
      OriginalSize = nil,
      CurrentSize = nil,
    },

    State = {
      Alive = false
    },

    Esp = {
      Lines = nil
    }
  }

  local TitanCache = TitansCache[address]

  TitanCache.Info.Type = GetTitanType(titan)
  TitanCache.Parts.Nape = GetNapePart(titan)
  TitanCache.Parts.Hrp = GetHrp(titan)
  TitanCache.State.Alive = IsTitanAlive(titan)

  print("Register: " .. titan.Name .. ", nape: " .. tostring(TitanCache.Parts.Nape))
end



-- // Blade functions \\ --
local function AreBladesFullyBroken()
  local Character = GetCharacter(LocalPlayer); if not Character then return false end
  local Rig_ = Character:FindFirstChild("Rig_" .. LocalPlayer.Name); if not Rig_ then return false end

  local RightHand, LeftHand = Rig_:FindFirstChild("RightHand"), Rig_:FindFirstChild("LeftHand"); if not RightHand or not LeftHand then return false end
  local RightBlade, LeftBlade = RightHand:FindFirstChild("Blade_1"), LeftHand:FindFirstChild("Blade_1"); if not RightBlade or not LeftBlade then return false end

  local ok, AreBroken = pcall(function()
    local one = memory_read("float", RightBlade.Address + 240)
    local two = memory_read("float", LeftBlade.Address + 240)

    return (one >= 0.9 and two >= 0.9)
  end)

  if not ok then
    warn("Memory read failed: ", AreBroken)
    AreBroken = false
  end


  return ok and AreBroken
end


local function DoINeedToRefill(): boolean -- the 0 / 3 counter
  local Blades = DownMiddlePartUi:FindFirstChild("Blades"); if not Blades then return true end
  local TextForBlades = Blades:FindFirstChild("Sets"); if not TextForBlades then return true end

  local Gas = DownMiddlePartUi:FindFirstChild("Gas"); if not Gas then return true end
  local TextForGas = Gas:FindFirstChild("Percentage"); if not TextForGas then return true end

  local BladesValue = tonumber(TextForBlades.Text:match("%d+")) or 0
  local GasValue = tonumber(TextForGas.Text:match("%d+")) or 0

  -- print("Blades are broken!")

  if BladesValue == 0 or GasValue == 0 then return true end

  return false
end


local function IsReloadingBlades(): boolean
  local Character = GetCharacter(LocalPlayer); if not Character then return false end
  local Hrp = GetHrp(Character); if not Hrp then return false end

  if Hrp:FindFirstChild("BV") then return false end -- Basically, when reloading the 0 / 3 counter, the BV is missing, not sure why.

  return true
end


local function HandleAllReloads()
  if not AreBladesFullyBroken() then return end  -- Only act when blade is actually broken
  
  local Character: Model? = GetCharacter(LocalPlayer); if not Character then return end
  local Hrp: BasePart? = GetHrp(Character); if not Hrp then return end

  local Time = OsClock()

  -- Case 1: No charges -> need refill
  if DoINeedToRefill() then
    warn("Detected refilling!")
    while DoINeedToRefill() do

      if OsClock() - Time > 10 then warn("Timeout happened for refill!"); break end
      if IsReloadingBlades() then task.wait(0.5); continue end

      local PartAddress = memory_read("uintptr_t", GasTank.Address + PrimaryPartOffset); if PartAddress == 0 then warn("No PrimaryPart"); return end
      local Primitive = memory_read("uintptr_t", PartAddress + BaseToPrimitiveOffset); if Primitive == 0 then warn("No Primitive"); return end


      local x = memory_read("float", Primitive + PrimitivePositionOffset)
      local y = memory_read("float", Primitive + PrimitivePositionOffset + 4)
      local z = memory_read("float", Primitive + PrimitivePositionOffset + 8)

      -- print(x, y, z)

      Hrp.AssemblyLinearVelocity = Vector3.zero
      task.wait(0.1)
      Hrp.AssemblyLinearVelocity = Vector3.zero
      Hrp.CFrame = CFrame.new(x + 6 , y, z)


      task.wait(0.3)
      keypress(0x52); task.wait(2)
      keyrelease(0x52) 

      task.wait(1)
    end


  else  -- Case 2: Only needs to reload blades
    
    if ReloadingBlades then return end
    if os.clock() - LastReloadingTime < 3 then return end

    warn("Detected reloading!")
    ReloadingBlades = true 
    LastReloadingTime = os.clock()

    task.spawn(function()
      if not isrbxactive() then ReloadingBlades = false; return end

      print("Proceeding to reload blades")
      Hrp.Position = SafePos
      keypress(0x52)
      task.wait(2)
      keyrelease(0x52) 
      task.wait(0.5)
      ReloadingBlades = false   
    end)
  end

  return true
end


local function KillTitan(titan)
  if not titan or not titan.Parent then return end
  
  local StartTime = OsClock()

  local Character: Model? = GetCharacter(LocalPlayer); if not Character then return end
  local Hrp: BasePart? = GetHrp(Character); if not Hrp then return end

  while true do
    task.wait(0.06)
    if not IsTitanAlive(titan) then break end -- Alive check
    if OsClock() - StartTime > 10 then warn("Timeout happened for a titan!"); break end -- Timeout
    if AreBladesFullyBroken() then break end

    if not isrbxactive() then
      Hrp.Position = SafePos
      task.wait(1)

    else
      TpAboveTitan(titan)
      BringNapeToPlayer(titan, Vector3.new(10, 10, 10))

      task.wait()
      mouse1click()
      task.wait(0.03)
      keypress(0x20)
      task.wait(0.03)
      keyrelease(0x20)

    end
  end

  local TitanCache = GetTitanCache(titan); if not TitanCache then return end
  TitanCache.State.Alive = false
  TitanCache = nil
end


-- // Ui logic \\ --
-- #region UI & Retry Logic
local function IsObjectVisible(object): boolean?
  if not object or not object.Address then return false end

  local ok, value = pcall(function()
    return memory_read("byte", object.Address + VisibleOffset)
  end)

  if not ok then warn("Something went wrong in memory reading for the object: " .. tostring(object:GetFullName()) .. "."); return nil end

  if value == 0 then
    return false
  else
    return true
  end
end

local function IsRetryVisible(): boolean? -- Fixed!
  local Path = GetPath(PlayerGui, true, "Interface", "Rewards"); if not Path then return false end
  return IsObjectVisible(Path)
end

local function PressRetry() 
  if not IsRetryVisible() then return end
  print("Pressing the retry button!")
  task.wait(0.5)
  keypress(0xDE); task.wait(0.3); keyrelease(0xDE); task.wait(1.0)
  keypress(0xDC); task.wait(0.3); keyrelease(0xDC); task.wait(1.0) 
  keypress(0x44); task.wait(0.2); keyrelease(0x44); task.wait(0.4)
  keypress(0x44); task.wait(0.2); keyrelease(0x44); task.wait(0.4) 
  keypress(0x0D); task.wait(0.3); keyrelease(0x0D); task.wait(0.6)
  keypress(0xDE); task.wait(0.3); keyrelease(0xDE); task.wait(0.5) 
  keypress(0xDC); task.wait(0.3); keyrelease(0xDC); task.wait(0.5) 
end


task.spawn(function()
  while true do
    task.wait(0.1)
    -- print("Loop running!")
    -- if not UserConfigs.Autofarm then task.wait(1); continue end

    if IsRetryVisible() then task.wait(0.5); PressRetry(); continue end
    if AreBladesFullyBroken() then HandleAllReloads(); continue end
    -- lowkey need more logic /:

    local NearestTitan = GetNearestTitan(); if not NearestTitan then continue end -- I want to use this but it needs fixing! For now, I shall use something else
    for i, v in ipairs(TitansFolder:GetChildren()) do
      if AreBladesFullyBroken() then break end
      KillTitan(v)
      task.wait(0.1)
    end
  end
end)




task.spawn(function()
  while true do
    print("Cache loop running!")
    
    for key, cache in pairs(TitansCache) do
      local Titan = cache.Instance; if not Titan or not Titan.Parent then TitansCache[key] = nil end
    end

    for i, titan in ipairs(TitansFolder:GetChildren()) do
      RegisterTitan(titan)
    end
    task.wait(5)
  end
end)
