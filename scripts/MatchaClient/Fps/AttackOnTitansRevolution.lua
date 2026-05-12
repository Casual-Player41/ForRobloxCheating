
--[[ 
information:
  * Game name: Attack on Titans Revolution
  * Game Id: 4658598196
  * Game UniverseId: 4658598196
  * Game PlaceIds: 13379208636 (Lobby), 13379349730 (Mission) 4658598196 ( x )
  * Game link: https://www.roblox.com/games/13379208636/Attack-on-Titan-Revolution

  * Script version: 1.0.3

  -- Todo: Improve debug function to allow x messages / second ( depending on where it's called );
]]

task.wait(1)

if game.GameId ~= 4658598196 then 
  warn("[Kitty's Aotr] This script is only made for Attack on Titans Revolution, and it seems like you are not in the game. Please execute this script in the game, and if you think this is a mistake, report this to me on discord, @roguekitty. ( with dot yes ).")
  return
end

local Workspace = nil; repeat task.wait(0.1);   Workspace = game:GetService("Workspace") until Workspace
local Players = nil; repeat task.wait(0.1);     Players = game:GetService("Players") until Players
local LocalPlayer = nil; repeat task.wait(0.1); LocalPlayer = Players.LocalPlayer until LocalPlayer
local PlayerGui = nil; repeat task.wait(0.1);   PlayerGui = LocalPlayer:FindFirstChild("PlayerGui") until PlayerGui
local HttpService = nil; repeat task.wait(0.1); HttpService = game:GetService("HttpService") until HttpService



local TitansFolder = nil
local CurrentLogFile = nil


repeat task.wait(0.1); TitansFolder = Workspace:FindFirstChild("Titans") until TitansFolder
repeat task.wait(0.1) until TitansFolder:FindFirstChildOfClass("Model")
repeat task.wait(0.1) until PlayerGui:FindFirstChild("Interface")

task.wait(1)

warn("[Kitty's aotr] (debug): Sucesfully loaded the Titans folder!")


local MathSin = math.sin
local MathPi = math.pi

local OsClock = os.clock
local StringLower = string.lower



local UserConfigs = {
  Autofarm = true,
  DebugMode = false,
}


local DebugRateLimit = {
  WindowStart = 0,
  Count = 0
}


local DebugEnabled = UserConfigs.DebugMode

local function DebugPrint(mode: string, maxAmount: number, ...)
  if not DebugEnabled then return end

  local Prefix = "[Kitty's Aotr]"
  local ModeLower = StringLower(mode)

  local Handlers = {
    print = print,
    warn = warn,
    debug = print
  }

  local Handler = Handlers[ModeLower]
  if not Handler then
    warn(Prefix .. " [invalid mode]: " .. tostring(mode))
    return
  end

  if maxAmount ~= 0 then -- Basically, the ones that have 0 are infinite

    local CurrentTime = os.clock()

    
    if CurrentTime - DebugRateLimit.WindowStart >= 1 then
      DebugRateLimit.WindowStart = CurrentTime
      DebugRateLimit.Count = 0
    end

    if DebugRateLimit.Count >= maxAmount then
      return
    end

    DebugRateLimit.Count += 1
  end

  local args = table.pack(...)
  local MessageParts = {}

  for i = 1, args.n do
    MessageParts[i] = tostring(args[i])
  end

  local FinalMessage = table.concat(MessageParts, " ")
  local ConsoleLine = Prefix .. " [" .. ModeLower .. "]: " .. FinalMessage

  Handler(ConsoleLine)

  if CurrentLogFile then
    local Timestamp = os.date("[%X]")
    local FileLine = Timestamp .. " [" .. ModeLower .. "] " .. FinalMessage .. "\n"

    appendfile(CurrentLogFile, FileLine)
  end
end


local function GetPath(root: Instance, Warning: boolean, ...): Instance?
  local CurrentInstance = root
  local args = {...}

  for _, name in ipairs(args) do
    if not CurrentInstance then
      if Warning and DebugEnabled then DebugPrint("warn", 0, "Path broke for: " .. name) end
      return nil
    end

    local NextInstance = CurrentInstance:FindFirstChild(name)
    if not NextInstance then
      if Warning and DebugEnabled then DebugPrint("warn", 0, "Missing: " .. name .. " in " .. CurrentInstance:GetFullName()) end
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
    if DebugEnabled then DebugPrint("warn", 0, "Failed to fetch offsets: " .. tostring(res)) end
    return {}
  end

  local success, decoded = pcall(function()
    return HttpService:JSONDecode(res)
  end)

  if not success then
    if DebugEnabled then DebugPrint("warn", 0, "JSON decode failed") end
    return {}
  end

  return decoded
end; local OffsetsFake = GetOffsets(); if not OffsetsFake or next(OffsetsFake) == nil then return end



-- // Titans section && Cache \\ --
type TitanEntry = {
  Instance: Instance?,

  Info: {
    Name: string?,
    Type: string?
  },

  Parts: {
    Nape: BasePart?,
    Hrp: BasePart?,
    Humanoid: Humanoid?
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

type IgnoredTitansEntry = { 
  [string]: number 
}

type BladeCacheType = {
  LeftHand: Instance?,
  RightHand: Instance?,

  LeftBlade: Instance?,
  RightBlade: Instance?

}

type CharacterCacheType = {
  Character: Model?,
  Hrp: BasePart?,
  Humanoid: Humanoid?,

  Name: string?,
  DisplayName: string?
}

type UiCacheType = {
  DownMiddlePartUi: Instance?,
  RewardsFrame: Instance?,

  GasText: TextLabel?,

  Blades: Instance?,
  TextForBlades: TextLabel?,
  Gas: Instance?,
  TextForGas: TextLabel?,
}



local TitansCache: { [number]: TitanEntry } = {}
local CachedTitanList = {} -- ex to remember because im stupid: CachedTitanList[titan] = true
local IgnoredTitansCache: IgnoredTitansEntry = {}
local TpFailCount = {}


local BladeCache: BladeCacheType = {
  LeftHand = nil,
  RightHand = nil,

  LeftBlade = nil,
  RightBlade = nil
}


local CharacterCache: CharacterCacheType = {
  Character = nil,
  Hrp = nil,
  Humanoid = nil,

  Name = nil,
  DisplayName = nil

}


local UiCache: UiCacheType = {
  DownMiddlePartUi = nil,
  RewardsFrame = nil,

  GasText = nil,

  Blades = nil,
  TextForBlades = nil,
  Gas = nil,
  TextForGas = nil
}


local TitansInfo = {
  ["HeightStall"] = 100,
  ["HeightAttack"] = 160,
  ["HeightColossal"] = 200,

  ["BobAmplitude"] = 2,
  ["BobSpeed"] = 10

}

-- // User section \\ --



if UserConfigs.DebugMode then
  local DateString = os.date("%Y-%m-%d")
  local TimeString = os.date("%H-%M-%S")
  local Path       = "KittyScripts/Aotr/logs/"
  local FileName   = Path .. "log_" .. DateString .. "_" .. TimeString .. ".txt"

  local Header = { 
    string.rep("-", 50),
    "Debug file for the script",
    "Date: " .. os.date("%A, %B %d, %Y"),
    "Time: " .. os.date("%X"),
    "File Path: C:/matcha/workspace/" .. FileName,
    string.rep("-", 50),
    "\n"
  }

  writefile(FileName, table.concat(Header, "\n"))

  warn("Debug mode is on. Logging to: " .. FileName)
    
  CurrentLogFile = FileName
end




-- // Random variables section \\ --
local Vector3New = Vector3.new
local Vector3Zero = Vector3New(0, 0, 0)

local SafePos: Vector3 = Vector3New(900, 9999, 900) -- Maybe search a better version instead of just air..?
local _CurrentMission: string?;

local GasTank;

local CachedNearestTitan = nil
local LastNearestUpdate = 0

local CurrentTitanTarget = nil

local CachedBladesBroken = false
local LastBladeCheck = 0

local CachedRefill = false
local LastRefillCheck = 0






local function HandleDifferentGasTankPaths(): Instance?
  local Shiganshina = GetPath(Workspace, false, "Climbable",   "Walls",      "Gate",      "GasTanks"); if Shiganshina then if DebugEnabled then DebugPrint("debug", 0, "Shiganshina detected!") end; GasTank = Shiganshina; return Shiganshina end
  local Trost       = GetPath(Workspace, false, "Unclimbable", "Camps",      "Camp",      "GasTanks"); if Trost       then if DebugEnabled then DebugPrint("debug", 0, "Trost detected!") end;       GasTank = Trost;       return Trost       end
  local OutSkirts   = GetPath(Workspace, false, "Climbable",   "_Walls",     "Gate",      "GasTanks"); if OutSkirts   then if DebugEnabled then DebugPrint("debug", 0, "Outskirts detected!") end;   GasTank = OutSkirts;   return OutSkirts   end
  local Forest      = GetPath(Workspace, false, "Unclimbable", "Camps",      "Camp",      "GasTanks"); if Forest      then if DebugEnabled then DebugPrint("debug", 0, "Forest detected!") end;      GasTank = Forest;      return Forest      end
  local UtGard      = GetPath(Workspace, false, "Climbable",   "Utgard",     "GasTanks");              if UtGard      then if DebugEnabled then DebugPrint("debug", 0, "UtGard detected!") end;      GasTank = UtGard;      return UtGard      end
  local Docks       = GetPath(Workspace, false, "Unclimbable", "World",      "Buildings", "Hanger",   "GasTanks"); if Docks  then if DebugEnabled then DebugPrint("debug", 0, "Docks detected!") end;       GasTank = Docks;       return Docks       end
  local Stohess     = GetPath(Workspace, false, "Unclimbable", "Props",      "HQ",        "GasTanks"); if Stohess     then if DebugEnabled then DebugPrint("debug", 0, "Stohess detected!") end;     GasTank = Stohess;     return Stohess     end
  local Chapel      = GetPath(Workspace, false, "Unclimbable", "Reloads",    "GasTanks");              if Chapel      then if DebugEnabled then DebugPrint("debug", 0, "Chapel detected!") end;      GasTank = Chapel;      return Chapel      end

  local Waves       = GetPath(Workspace, false, "Unclimbable", "Objective",  "Waves",     "GasTanks"); if Waves       then if DebugEnabled then DebugPrint("debug", 0, "Waves detected!") end;       GasTank = Waves;       return Waves       end

  if DebugEnabled then DebugPrint("warn", 0, "No known GasTank path found. Please report this to me on discord, @roguekitty. ( with dot yes ).") end
  return nil
end; HandleDifferentGasTankPaths(); if not GasTank then return end


-- // A little more variables
local Offsets: { [string]: { [string]: number } } = OffsetsFake.Offsets
local DownMiddlePartUi: Instance? = GetPath(PlayerGui, true, "Interface", "HUD", "Main", "Top", "7"); if not DownMiddlePartUi then return end


--== Offsets ==--
local PrimaryPartOffset = Offsets.Model.PrimaryPart; if not PrimaryPartOffset or PrimaryPartOffset == 0 then return end
local BaseToPrimitiveOffset = Offsets.BasePart.Primitive; if not BaseToPrimitiveOffset or BaseToPrimitiveOffset == 0 then return end
local PrimitivePositionOffset = Offsets.Primitive.Position; if not PrimitivePositionOffset or PrimitivePositionOffset == 0 then return end
local VisibleOffset = Offsets.GuiObject.Visible; if not VisibleOffset or VisibleOffset == 0 then return end
local TransparencyBasePartOffset = Offsets.BasePart.Transparency; if not TransparencyBasePartOffset or TransparencyBasePartOffset == 0 then return end

local ReloadingBlades = false
local LastReloadingTime = 0
  


local CachedAddressesOrParts = {
  GasTank = GasTank,
  GasTankAddress = nil :: number?,

  PrimaryPart = nil,
  PrimaryPartOffset = nil :: number?,

  GasTankPosition = nil :: Vector3?,
}


--#region Functions

-- // General character related functions \\ --
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


-- // Specific local player character functions \\ --
local function GetLocalPlayerCharacter(): Model?
  local Character; 


  if CharacterCache.Character and CharacterCache.Character.Parent then
    Character = CharacterCache.Character
  else
    Character = GetCharacter(LocalPlayer); if Character then CharacterCache.Character = Character end
  end


  return Character
end


local function GetLocalPlayerHrp(): BasePart?
  local Character: Model? = CharacterCache.Character or GetLocalPlayerCharacter(); if not Character then return nil end
  local Hrp: BasePart? = CharacterCache.Hrp or GetHrp(Character); if not Hrp then return nil end

  CharacterCache.Character = Character
  CharacterCache.Hrp = Hrp

  return Hrp
end


local function _GetLocalPlayerHumanoid(): Humanoid?
  local Character = CharacterCache.Character or GetLocalPlayerCharacter(); if not Character then return nil end
  local Humanoid = CharacterCache.Humanoid or GetHumanoid(Character); if not Humanoid then return nil end

  CharacterCache.Character = Character
  CharacterCache.Humanoid = Humanoid

  return Humanoid
end





-- // Titan functions \\ --
local function GetTitanCache(titan): TitanEntry?
  if not titan or not titan.Address then return nil end
  return TitansCache[titan.Address]
end


local function GetNapePart(titan): BasePart?
  if not titan or not titan.Parent then return nil end

  local TitanCache = GetTitanCache(titan); if not TitanCache then return end
  local CachedNape = TitanCache.Parts.Nape; if CachedNape then return CachedNape end

  local NapePart = GetPath(titan, true, "Hitboxes", "Hit", "Nape") :: BasePart; if not NapePart then return nil end

  TitanCache.Parts.Nape = NapePart
  return NapePart
end


local function GetTitanHrp(titan): BasePart?
  if not titan or not titan.Parent then return nil end

  local TitanCache = GetTitanCache(titan); if not TitanCache then return GetHrp(titan) end
  local Hrp = TitanCache.Parts.Hrp or GetHrp(titan); if not Hrp then return nil end

  TitanCache.Parts.Hrp = Hrp
  return Hrp
end


local function GetTitanHumanoid(titan): Humanoid?
  if not titan or not titan.Parent then return nil end

  local TitanCache = GetTitanCache(titan); if not TitanCache then return GetHumanoid(titan) end
  local Humanoid = TitanCache.Parts.Humanoid or GetHumanoid(titan); if not Humanoid then return nil end

  TitanCache.Parts.Humanoid = Humanoid
  return Humanoid
end



local function GetTitanType(titan: Instance): string -- Needs more research
  local TitanCache = GetTitanCache(titan); if not TitanCache then return "Attack" end
  local TitanTypeCached = TitanCache.Info.Type; if TitanTypeCached then return TitanTypeCached end

  local TitanType = titan:GetAttribute("Type") or "Attack"

  TitanCache.Info.Type = TitanType
  return TitanType
end


local function GetTitanBobHeight(titan: Instance): number
  local TitanType = GetTitanType(titan); if not TitanType then return 120 end -- default for "Attack" titan

  return TitansInfo["Height" .. TitanType]
end


local function IsTitanAlive(titan): boolean
  if not titan or not titan.Parent then return false end

  local TitanCache = GetTitanCache(titan)
  local TitanHumanoid = GetTitanHumanoid(titan); if not TitanHumanoid then return false end
    

  if not TitanCache then return TitanHumanoid.Health > 0 or false end

  local Alive = TitanHumanoid.Health > 0 or false
  TitanCache.State.Alive = Alive

  return Alive
end


local function TpAboveTitan(titan): boolean -- This might require changes!
  if not titan or not titan.Parent then return false end

  local TitanCache = GetTitanCache(titan); if not TitanCache then return false end
 

  local Hrp: BasePart? = CharacterCache.Hrp or GetLocalPlayerHrp(); if not Hrp then return false end


  local TitanHrp: BasePart? = GetTitanHrp(titan); if not TitanHrp or not TitanHrp:IsA("BasePart") then return false end
  local Position: Vector3 = TitanHrp.Position

  local BobHeight = GetTitanBobHeight(titan); if not BobHeight then return false end
  local BobOffset = MathSin(OsClock() * MathPi * 2) * TitansInfo.BobAmplitude

  if DebugEnabled then DebugPrint("debug", 3, "Teleporting to the titan: " .. tostring(titan.Name)) end

  local ok, err = pcall(function()
    Hrp.CFrame = CFrame.new(Position.X, Position.Y + BobHeight + BobOffset, Position.Z)
  end)
  
  if not ok then
    if DebugEnabled then DebugPrint("warn", 0, "Error happened while setting CFrame to titan: " .. err) end
    return false
  end

  return true
end


local function BringNapeToPlayer(titan: Instance, size: Vector3?)
  if not titan or not titan.Parent then return end

  local TitanCache = GetTitanCache(titan); if not TitanCache then return end
  local Nape: BasePart? = TitanCache.Parts.Nape; if not Nape then return end

  local Hrp: BasePart? = CharacterCache.Hrp or GetLocalPlayerHrp(); if not Hrp then return end

  Nape.CFrame = Hrp.CFrame * CFrame.new(0, 2, 0)
  if size then Nape.Size = size end
end


local function RegisterTitan(titan)
  if not titan or not titan.Address then 
    if DebugEnabled then DebugPrint("warn", 0, ("RegisterTitan: invalid titan or missing Address: "), titan and tostring(titan.Name) or "nil", titan and tostring(titan.Address) or "0") end; return end
  local TitanAddress = titan.Address


  if TitansCache[TitanAddress] then return end


  TitansCache[TitanAddress] = {
    Instance = titan,

    Info = {
      Name = titan.Name,
      Type = nil
    },

    Parts = {
      Nape = nil,
      Hrp = nil,
      Humanoid = nil,
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

  local TitanCache = TitansCache[TitanAddress]

  TitanCache.Info.Type = GetTitanType(titan)
  TitanCache.Parts.Nape = GetNapePart(titan)
  TitanCache.Parts.Hrp = GetTitanHrp(titan)
  TitanCache.Parts.Humanoid = GetTitanHumanoid(titan)
  TitanCache.State.Alive = IsTitanAlive(titan)

  if DebugEnabled then DebugPrint( "debug", 0, string.format("Register information: Titan Info: %s", titan.Name  )) end
end


local function _IgnoreTitan(titan, duration)
  if not titan or not titan.Parent then return end

  local address = titan.Address; if not address then return end

  if DebugEnabled then DebugPrint("debug", 0, "Ignoring titan: " .. tostring(titan.Name) .. "for " .. tostring(duration) .. "seconds.") end
  IgnoredTitansCache[address] = OsClock() + duration
end


local function IsTitanIgnored(titan): boolean
  if not titan then return true end
  local ExpireTime = IgnoredTitansCache[titan.Address]; if not ExpireTime then return false end

  if OsClock() > ExpireTime then IgnoredTitansCache[titan.Address] = nil; if DebugEnabled then DebugPrint("debug", 0, "Titan is no longer ignored: " .. tostring(titan.Name)) end; return false end

  return true
end


local function RegisterFail(titan)
  if not titan or not titan.Parent then return end

  local TitanAddress = titan.Address; if not TitanAddress then return end

  TpFailCount[TitanAddress] = (TpFailCount[TitanAddress] or 0) + 1

  if TpFailCount[TitanAddress] >= 3 then
    IgnoredTitansCache[TitanAddress] = OsClock() + 5
    TpFailCount[TitanAddress] = nil
  end
end


local function GetNearestTitan(): Instance?

  local Hrp: BasePart? = CharacterCache.Hrp or GetLocalPlayerHrp(); if not Hrp then return end
  local HrpPosition = Hrp.Position

  local ShortestDistance = math.huge
  local ShortestTitan = nil


  for titan, _ in pairs(CachedTitanList) do
    if not titan or not titan.Parent then continue end

    if IsTitanIgnored(titan) then continue end

    local TitanCache = GetTitanCache(titan); if not TitanCache then continue end
    if not IsTitanAlive(titan) then continue end

    local CachedHrp: BasePart? = TitanCache.Parts.Hrp

    if CachedHrp and not CachedHrp.Parent then
      CachedHrp = nil
      TitanCache.Parts.Hrp = nil
    end

    local TitanHrp: BasePart? = CachedHrp or GetTitanHrp(titan); if not TitanHrp or not TitanHrp:IsA("BasePart") then continue end
    TitanCache.Parts.Hrp = TitanHrp

    local TitanPosition = TitanHrp.Position
    local ok, Distance = pcall(function() -- because cool environments still throws error without pcall.
      return (HrpPosition - TitanPosition).Magnitude
    end)

      if not ok or not Distance then
        if DebugEnabled then DebugPrint("warn", 0, "Error getting distance, saved by pcall: " .. Distance) end
        RegisterFail(titan)
        continue
      end

    if Distance < ShortestDistance then
      ShortestTitan = titan
      ShortestDistance = Distance
    end
  end

 
  if ShortestTitan and DebugEnabled then
    DebugPrint("debug", 3, "Shortest distance titan is: " .. tostring(ShortestTitan.Name))
  end

  return ShortestTitan
end

local function GetCachedNearestTitan()
    local Now = OsClock()

    if not CachedNearestTitan
        or not CachedNearestTitan.Parent
        or Now - LastNearestUpdate > 0.35
    then
        CachedNearestTitan = GetNearestTitan()
        LastNearestUpdate = Now
    end

    return CachedNearestTitan
end



-- // Blade functions \\ --
local function AreBladesFullyBroken(): boolean
  local Now = OsClock()

  if Now - LastBladeCheck < 0.3 then return false end

  LastBladeCheck = Now

 local RightBlade, LeftBlade;

  RightBlade = BladeCache.RightBlade
  LeftBlade = BladeCache.LeftBlade


  if not RightBlade or not RightBlade.Parent or not LeftBlade or not LeftBlade.Parent then 
    local Character = CharacterCache.Character or GetLocalPlayerCharacter(); if not Character then return false end
    local Rig_ = Character:FindFirstChild("Rig_" .. LocalPlayer.Name); if not Rig_ then return false end

    local RightHand, LeftHand; RightHand = BladeCache.RightHand; LeftHand = BladeCache.LeftHand

    -- if not RightHand or not RightHand.Parent or not LeftHand or not LeftHand.Parent then -- I highly doubt that the Parent can be nil, due to the fact of how character is gotten.

    if not RightHand or not LeftHand then
      RightHand = Rig_:FindFirstChild("RightHand"); LeftHand = Rig_:FindFirstChild("LeftHand")
      if not RightHand or not RightHand.Parent or not LeftHand or not LeftHand.Parent then return false end

      BladeCache.RightHand = RightHand
      BladeCache.LeftHand = LeftHand
    end



    RightBlade, LeftBlade = RightHand:FindFirstChild("Blade_1"), LeftHand:FindFirstChild("Blade_1"); if not RightBlade or not LeftBlade then return false end

    BladeCache.RightBlade = RightBlade
    BladeCache.LeftBlade = LeftBlade
  end

  local ok, AreBroken = pcall(function()
    local one = memory_read("float", RightBlade.Address + TransparencyBasePartOffset)
    local two = memory_read("float", LeftBlade.Address + TransparencyBasePartOffset)

    return (one >= 0.9 and two >= 0.9)
  end)

  if not ok then
    if DebugEnabled then DebugPrint("warn", 0, "Memory read failed: ", AreBroken) end
    AreBroken = false
  end


  return ok and AreBroken
end


local function DoINeedToRefill(): boolean -- the 0 / 3 counter
  local Now = OsClock()

  if Now - LastRefillCheck < 0.5 then return false end
  LastRefillCheck = Now

  local Blades = UiCache.Blades or GetPath(DownMiddlePartUi, false, "Blades"); if not Blades then return true end
  UiCache.Blades = Blades

  local TextForBlades = UiCache.TextForBlades or GetPath(Blades, false, "Sets"); if not TextForBlades then return true end
  UiCache.TextForBlades = TextForBlades

  local Gas = UiCache.Gas or GetPath(DownMiddlePartUi, false, "Gas"); if not Gas then return true end
  UiCache.Gas = Gas

  local TextForGas = UiCache.TextForGas or GetPath(Gas, false, "Percentage"); if not TextForGas then return true end
  UiCache.TextForGas = TextForGas

  local BladesValue = tonumber(TextForBlades.Text:match("%d+")) or 0
  local GasValue = tonumber(TextForGas.Text:match("%d+")) or 0

  if BladesValue == 0 or GasValue == 0 then return true end

  return false
end


local function IsReloadingBlades(): boolean
  local Hrp = CharacterCache.Hrp or GetLocalPlayerHrp(); if not Hrp then return false end

  if Hrp:FindFirstChild("BV") then return false end -- Basically, when reloading the 0 / 3 counter, the BV is missing, not sure why.

  return true
end


local function GetGasTankPosition(): Vector3?
  -- Check cache first
  if CachedAddressesOrParts.GasTankPosition then
    return CachedAddressesOrParts.GasTankPosition
  end

  -- Try to read from memory if not cached
  local GasTankAddress = CachedAddressesOrParts.GasTankAddress or GasTank.Address
  if not GasTankAddress or GasTankAddress == 0 then 
    if DebugEnabled then DebugPrint("warn", 0, "No GasTank address found!") end
    return nil 
  end

  local PartAddress = CachedAddressesOrParts.PrimaryPartOffset or memory_read("uintptr_t", GasTankAddress + PrimaryPartOffset)
  if PartAddress == 0 then 
    if DebugEnabled then DebugPrint("warn", 0, "No PrimaryPart for gas tank found!") end
    return nil 
  end

  local Primitive = memory_read("uintptr_t", PartAddress + BaseToPrimitiveOffset)
  if Primitive == 0 then 
    if DebugEnabled then DebugPrint("warn", 0, "No Primitive part found for gas tank!") end
    return nil 
  end

  local x = memory_read("float", Primitive + PrimitivePositionOffset)
  local y = memory_read("float", Primitive + PrimitivePositionOffset + 4)
  local z = memory_read("float", Primitive + PrimitivePositionOffset + 8)

  local Position = Vector3New(x, y, z)
  CachedAddressesOrParts.GasTankPosition = Position
  
  if DebugEnabled then DebugPrint("debug", 3, "Gas tank position cached: " .. tostring(Position)) end
  return Position
end


local function HandleAllReloads()
  if not AreBladesFullyBroken() then return end
  
  local Hrp: BasePart? = CharacterCache.Hrp or GetLocalPlayerHrp(); if not Hrp then return end

  local Time = OsClock()

  -- Case 1: No charges -> need refill
  if DoINeedToRefill() then
    if DebugEnabled then DebugPrint("debug", 0, "Detected that the local player needs refilling.") end
    while DoINeedToRefill() do
      if IsReloadingBlades() then task.wait(0.5); continue end

      local GasTankPosition = GetGasTankPosition()
      if not GasTankPosition then
        if OsClock() - Time > 10 then if DebugEnabled then DebugPrint("warn", 0, "Timeout happened for refill.") end; break end
        task.wait(0.5)
        continue
      end

      Hrp.AssemblyLinearVelocity = Vector3Zero
      task.wait(0.24)
      Hrp.CFrame = CFrame.new(GasTankPosition + Vector3New(5, 0, 0))
      Hrp.AssemblyLinearVelocity = Vector3Zero
      task.wait(0.5)

      keypress(0x52); task.wait(0.5); keyrelease(0x52)

      task.wait(1)
    end
  else  -- Case 2: Only needs to reload blades
    if ReloadingBlades then return end
    if os.clock() - LastReloadingTime < 3 then return end

    if DebugEnabled then DebugPrint("debug", 0, "Detected that the local player needs reloading.") end
    ReloadingBlades = true 
    LastReloadingTime = os.clock()

    task.spawn(function()
      if not isrbxactive() then ReloadingBlades = false; return end

      if DebugEnabled then DebugPrint("debug", 0, "Proceeding to reload blades.") end
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

  local Hrp: BasePart? = CharacterCache.Hrp or GetLocalPlayerHrp(); if not Hrp then return end

  while true do
    task.wait(0.06)
    if not IsTitanAlive(titan) then break end -- Alive check
    if OsClock() - StartTime > 10 then if DebugEnabled then DebugPrint("warn", 0, "Timeout happened while trying to kill the titan: " .. tostring(titan.Name)) end; break end -- Timeout
    if AreBladesFullyBroken() then break end

    if not isrbxactive() then
      Hrp.Position = SafePos
      Hrp.AssemblyLinearVelocity = Vector3Zero
      task.wait(0.1)

    else  
      local Success = TpAboveTitan(titan)
      if not Success then
        RegisterFail(titan)
        if DebugEnabled then DebugPrint("warn", 5, "Failed to tp. Abandoning") end
        task.wait(0.1)
        break
      end

      BringNapeToPlayer(titan, Vector3New(15, 15, 15))
      Hrp.AssemblyLinearVelocity = Vector3New(15, -180, -20) 

      task.wait()
      mouse1click()
      task.wait(0.03)
      keypress(0x20)
      task.wait(0.03)
      keyrelease(0x20)

    end
  end

  if not IsTitanAlive(titan) then
    local TitanCache = GetTitanCache(titan); if not TitanCache then return end
    TitanCache.State.Alive = false
    TitansCache[titan.Address] = nil
    CachedTitanList[titan] = nil
  end
end



-- // UI & Retry Logic\\ --
local function IsObjectVisible(object): boolean
  if not object or not object.Address then return false end

  local ok, value = pcall(function()
    return memory_read("byte", object.Address + VisibleOffset)
  end)

  if not ok then if DebugEnabled then DebugPrint("warn", 0, "Something went wrong in memory reading for the object: " .. tostring(object:GetFullName()) .. ".") end; return false end

  if value == 0 then
    return false
  else
    return true
  end
end


local function IsRetryVisible(): boolean
  local RewardsFrame 
  
  if UiCache.RewardsFrame and UiCache.RewardsFrame.Parent then
    return IsObjectVisible(UiCache.RewardsFrame)
  else
    RewardsFrame = GetPath(PlayerGui, true, "Interface", "Rewards"); if not RewardsFrame then return false end
    UiCache.RewardsFrame = RewardsFrame
    return IsObjectVisible(RewardsFrame)
  end

end


local function PressRetry() 
  if not IsRetryVisible() then return end
  if DebugEnabled then DebugPrint("debug", 0,"Pressing the retry button!") end
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
    if not UserConfigs.Autofarm then task.wait(1); continue end
    if DebugEnabled then DebugPrint("debug", 4, "The main loop is running!") end

    if IsRetryVisible() then task.wait(0.5); PressRetry(); continue end
    if AreBladesFullyBroken() then HandleAllReloads(); continue end



    if not CurrentTitanTarget or not CurrentTitanTarget.Parent or not IsTitanAlive(CurrentTitanTarget) then
      CurrentTitanTarget = GetCachedNearestTitan()
      if DebugEnabled then DebugPrint("debug", 0, "New titan target: " .. tostring(CurrentTitanTarget.Name)) end
    end

    KillTitan(CurrentTitanTarget)

    task.wait(0.1)
  end
end)




task.spawn(function() -- Loop for caching and removing titans from cache.
  while true do
    if DebugEnabled then DebugPrint("debug", 5, "Cache loop is running.") end
    
    for key, cache in pairs(TitansCache) do
      local Titan = cache.Instance

      if not Titan or not Titan.Parent then
        if Titan then
          CachedTitanList[Titan] = nil
        end

        TitansCache[key] = nil
      end
    end

    for i, titan in ipairs(TitansFolder:GetChildren()) do
      if not CachedTitanList[titan] then
        CachedTitanList[titan] = true
        RegisterTitan(titan)
        if DebugEnabled then DebugPrint("debug", 0, "New titan detected and registered: " .. tostring(titan.Name)) end
      end
    end
    task.wait(3)
  end
end)

