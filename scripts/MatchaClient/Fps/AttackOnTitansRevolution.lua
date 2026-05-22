--!strict

--[[ 
- information:
  * Game name: Attack on Titans Revolution
  * Game Id: 4658598196
  * Game UniverseId: 4658598196
  * Game PlaceIds: 13379208636 (Lobby), 13379349730 (Mission) 4658598196 ( x )
  * Game link: https://www.roblox.com/games/13379208636/Attack-on-Titan-Revolution

  * Script version: 1.0.5

- Notes for kitty:
  * The titan cache SHALL only use the titan's address as a key.
  * The character cache SHALL only use the player address as a key.
]]

-- // Global variables defined as local ones \\ --
local StringLower = string.lower
local OsClock = os.clock
local DebugInfo = debug.info
local MathSin = math.sin
local MathPi = math.pi


local ScriptStart = OsClock()

local UserConfigs = {
  Autofarm = true,
  DebugMode = true
}

local DebugEnabled = UserConfigs.DebugMode
local CurrentLogFile = nil
local DebugRateLimit = {}

if DebugEnabled then
  local DateString = os.date("%Y-%m-%d")
  local TimeString = os.date("%H-%M-%S")
  local Path = "KittyScripts/Aotr/logs/"
  local FileName = Path .. "log_" .. DateString .. "_" .. TimeString .. ".txt"

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

local function DebugPrint(mode: "warn" | "debug", maxAmount: number?, stackOffset: number?, functionName: string?, ...)

  local Prefix = "[Kitty's Aotr]"
  local ModeLower = StringLower(mode)

  local Handlers = {
    print = print,
    warn = warn,
    debug = print
  }

  local Handler = Handlers[ModeLower]

  local args = table.pack(...)
  local MessageParts = {}

  for i = 1, args.n do
    MessageParts[i] = tostring(args[i])
  end

  local FinalMessage = table.concat(MessageParts, " ")
  local RateKey = ModeLower .. ":" .. FinalMessage

  -- Basically, maxAmount = 0 or nil means infinite prints
  if maxAmount and maxAmount ~= 0  then
    local CurrentTime = os.clock()
    local RateData = DebugRateLimit[RateKey]

    if not RateData then
      RateData = {
        WindowStart = CurrentTime,
        Count = 0
      }

      DebugRateLimit[RateKey] = RateData
    end

    if CurrentTime - RateData.WindowStart >= 1 then
      RateData.WindowStart = CurrentTime
      RateData.Count = 0
    end

    if RateData.Count >= maxAmount then
      return
    end

    RateData.Count += 1
  end

  local DebugLine = DebugInfo((stackOffset or 1) + 1, "l") -- function name doesn't work, returns " ", thank you matcha.

  local Timestamp = OsClock() - ScriptStart
  local TimestampFormatted = string.format("%.4f", Timestamp)

  -- local FinalFinalMessage = "[ " .. TimestampFormatted .. " ]" .. " [ line && name: " .. DebugLine .. " " .. FunctionName or "<anonymous> " .. " ]" .. Prefix .. " [" .. ModeLower .. "]: " .. FinalMessage
  local RealFinalMessage = string.format("[%s] [line: %s || func: %s] %s [%s]: %s",
    TimestampFormatted,
    tostring(DebugLine),
    functionName or "<anonymouse>",
    Prefix,
    ModeLower,
    FinalMessage
)

  
  Handler(RealFinalMessage)

  if CurrentLogFile then
    appendfile(CurrentLogFile, RealFinalMessage .. "\n")
  end
end


DebugPrint("debug", nil, nil, nil, "Proceeding to check the game and wait for services...")

task.wait(0.5)

if identifyexecutor and identifyexecutor() ~= "Matcha" then DebugPrint("warn", nil, nil, nil, "Not using matcha..?"); return end
if game.GameId ~= 4658598196 then DebugPrint("debug", nil, nil, nil, "Wrong game detected..?"); return end


local Workspace = nil;    repeat task.wait(0.03);   Workspace = game:GetService("Workspace") until Workspace
local Players = nil;      repeat task.wait(0.03);     Players = game:GetService("Players") until Players
local LocalPlayer = nil;  repeat task.wait(0.03); LocalPlayer = Players.LocalPlayer until LocalPlayer
local PlayerGui = nil;    repeat task.wait(0.03);   PlayerGui = LocalPlayer:FindFirstChild("PlayerGui") until PlayerGui
local HttpService = nil;  repeat task.wait(0.03); HttpService = game:GetService("HttpService") until HttpService

local TitansFolder = nil;     repeat task.wait(0.03); TitansFolder = Workspace:FindFirstChild("Titans") until TitansFolder
local Interface = nil;        repeat task.wait(0.03); Interface = PlayerGui:FindFirstChild("Interface") until Interface
local CharactersFolder = nil; repeat task.wait(0.03); CharactersFolder = Workspace:FindFirstChild("Characters") until CharactersFolder
                              repeat task.wait(0.03); until TitansFolder:FindFirstChildOfClass("Model")

DebugPrint("debug", nil, nil, nil, "Sucesfully loaded all services and titans folder / interface.")

--#region -- Game update check --
local ExpectedUpdateTime = "2026-05-21T15:43:01.2837514Z" -- This is for the current one


local ok, result = pcall(function()
  return game:HttpGet("https://games.roblox.com/v1/games?universeIds=4658598196")
end)

if not ok or not result then
  DebugPrint("warn", nil, nil, nil, "Something went wrong in grabbing offsets: " .. tostring(result))
  return
end

local success, decoded = pcall(function()
  return HttpService:JSONDecode(result)
end)

if not success or not decoded then
  DebugPrint("warn", nil, nil, nil, "Failed to decoede offsets: " .. tostring(result))
  return
end

if decoded.data[1].updated ~= ExpectedUpdateTime then
   DebugPrint("warn", nil, nil, nil, "Update detected. Script will NOT run. Game version vs excepted: ", decoded.data[1].updated or "nil", " vs ", ExpectedUpdateTime)
  return
end

DebugPrint("debug", nil, nil, nil, "No updated detected. Proceeding :D")

--#endregion -- Game update check --


--#region -- Types, Tables && Caches, Variables --


-- // Types && Caches \\ --
type OffsetsData = {
  Offsets: {
    [string]: {
      [string]: number
    }
  }
}

type TitanEntry = {
  Instance: Instance?,

  Info: {
    Name: string?,
    Type: string?,

    Alive: boolean?,
    LastAliveCheck: number?,

    Ignored: boolean?,
    IgnoredTime: number?,
    IgnoreDuration: number?
  },

  Parts: {
    Nape: BasePart?,
    HumanoidRootPart: BasePart?,
    Humanoid: Humanoid?
  },

  Nape: {
    CurrentSize: Vector3?
  },

  TpFails: {
    Count: number
  }
}

type CharacterCacheType = {
  Character: Instance?,
  Hrp: BasePart?,
  Humanoid: Humanoid?,

  Username: string?,
  DisplayName: string?,
  UserId: number?
}

type UiCacheType = {
  RewardsFrame: GuiObject?
}

type BladeCacheType = {
  RightBlade: Instance?,
  LeftBlade: Instance?,
  RightHand: Instance?,
  LeftHand: Instance?
}



local TitansCache: { [number]: TitanEntry } = {}
local KnownTitans: { [number]: Instance } = {} -- Childrens of the titans folder
local CharacterCache: { [number]: CharacterCacheType } = {}
local UiCache: UiCacheType = {}
local BladeCache: BladeCacheType = {}

local TitansInfo = {
  ["HeightStall"] = 100,
  ["HeightAttack"] = 160,
  ["HeightColossal"] = 200,

  ["BobAmplitude"] = 2,
  ["BobSpeed"] = 10
}

local GasTankModel: Instance? = nil
local GasTankPosition: Vector3? = nil

--#endregion -- Types, Tables && Caches, Variables --


--#region Small functions


local function GetPath(root: Instance, Warning: boolean, ...): Instance?
  local CurrentInstance = root
  local args = {...}

  for _, name in ipairs(args) do
    if not CurrentInstance then
      if Warning then
        DebugPrint("warn", nil, nil, "GetPath", "Couldn't find a children: ", name)
      end

      return nil
    end

    local NextInstance = CurrentInstance:FindFirstChild(name)

    if not NextInstance then
      if Warning then
        DebugPrint( "warn", nil, nil, "GetPath", "Missing: ", name , " in ", (CurrentInstance:GetFullName() or "<unknown>") )
      end
      return nil
    end

    CurrentInstance = NextInstance
    task.wait()
  end

  return CurrentInstance
end


local function HandleDifferentGasTankPaths(): Instance?
  local Shiganshina = GetPath(Workspace, false, "Climbable",   "Walls",      "Gate",      "GasTanks"); if Shiganshina then DebugPrint("debug", nil, nil, "GasTank", "Shiganshina detected!"); GasTankModel = Shiganshina; return Shiganshina end
  local Trost       = GetPath(Workspace, false, "Unclimbable", "Camps",      "Camp",      "GasTanks"); if Trost       then DebugPrint("debug", nil, nil, "GasTank", "Trost detected!");       GasTankModel = Trost;       return Trost       end
  local OutSkirts   = GetPath(Workspace, false, "Climbable",   "_Walls",     "Gate",      "GasTanks"); if OutSkirts   then DebugPrint("debug", nil, nil, "GasTank", "Outskirts detected!");   GasTankModel = OutSkirts;   return OutSkirts   end
  local Forest      = GetPath(Workspace, false, "Unclimbable", "Camps",      "Camp",      "GasTanks"); if Forest      then DebugPrint("debug", nil, nil, "GasTank", "Forest detected!");      GasTankModel = Forest;      return Forest      end
  local UtGard      = GetPath(Workspace, false, "Climbable",   "Utgard",     "GasTanks");              if UtGard      then DebugPrint("debug", nil, nil, "GasTank", "UtGard detected!");      GasTankModel = UtGard;      return UtGard      end
  local Docks       = GetPath(Workspace, false, "Unclimbable", "World",      "Buildings", "Hanger",   "GasTanks"); if Docks  then DebugPrint("debug", nil, nil, "GasTank", "Docks detected!");       GasTankModel = Docks;       return Docks       end
  local Stohess     = GetPath(Workspace, false, "Unclimbable", "Props",      "HQ",        "GasTanks"); if Stohess     then DebugPrint("debug", nil, nil, "GasTank", "Stohess detected!");     GasTankModel = Stohess;     return Stohess     end
  local Chapel      = GetPath(Workspace, false, "Unclimbable", "Reloads",    "GasTanks");              if Chapel      then DebugPrint("debug", nil, nil, "GasTank", "Chapel detected!");      GasTankModel = Chapel;      return Chapel      end

  local Waves       = GetPath(Workspace, false, "Unclimbable", "Objective",  "Waves",     "GasTanks"); if Waves       then DebugPrint("debug", nil, nil, "GasTank", "Waves detected!");       GasTankModel = Waves;       return Waves       end

  DebugPrint("warn", nil, nil, "GasTank", "No known GasTankModel path found. Please report this to me on discord, @roguekitty. ( with dot yes ).")
  return nil
end; HandleDifferentGasTankPaths(); if not GasTankModel then return end


local function GetOffsets(): OffsetsData?
  local ok, res = pcall(function()
    return game:HttpGet("https://imtheo.lol/Offsets/Offsets.json")
  end)

  if not ok or not res then
    DebugPrint("warn", nil, nil, "GetOffsets", "Failed to fetch offsets: ", tostring(res))

    return nil
  end

  local success, decoded = pcall(function()
    return HttpService:JSONDecode(res)
  end)

  if not success then
    DebugPrint("warn", nil, nil, "GetOffsets", "JSON decode failed: ", decoded)

    return nil
  end

  return decoded :: OffsetsData
end; local OffsetsFake = GetOffsets()

if not OffsetsFake or next(OffsetsFake) == nil then
  DebugPrint("warn", nil, nil, "Offset check", "Offsets or next offset is missing..?")
  return
end


--#endregion Small functions



--#region -- variables section --


local Vector3New = Vector3.new
local Vector3Zero: Vector3 = Vector3New(0, 0, 0)

local SafePos: CFrame = CFrame.new(900, 9999, 900) -- Maybe search a better version instead of just air..?
local CurrentMission: string? = nil



local CachedNearestTitan: Instance? = nil
local LastNearestUpdate: number = 0

local CurrentTitanTarget: Instance? = nil

local CachedBladesBroken: boolean = false
local LastBladeCheck: number = 0

local CachedRefill: boolean = false
local LastRefillCheck: number = 0


local ReloadingBlades: boolean = false
local LastReloadingTime: number = 0


local DownMiddlePartUi: Instance? = GetPath(PlayerGui, true, "Interface", "HUD", "Main", "Top", "7"); if not DownMiddlePartUi then return end


--== Offsets ==--
local Offsets: { [string]: { [string]: number } } = OffsetsFake.Offsets

local PrimaryPartOffset = Offsets.Model.PrimaryPart;              if not PrimaryPartOffset or PrimaryPartOffset == 0 then return end
local BaseToPrimitiveOffset = Offsets.BasePart.Primitive;         if not BaseToPrimitiveOffset or BaseToPrimitiveOffset == 0 then return end
local PrimitivePositionOffset = Offsets.Primitive.Position;       if not PrimitivePositionOffset or PrimitivePositionOffset == 0 then return end
local VisibleOffset = Offsets.GuiObject.Visible;                  if not VisibleOffset or VisibleOffset == 0 then return end
local TransparencyBasePartOffset = Offsets.BasePart.Transparency; if not TransparencyBasePartOffset or TransparencyBasePartOffset == 0 then return end


--#endregion -- Variables section --



--#region  -- Functions --


--#region -- Player's character and Titan's character related functions --

local function GetCharacter(player: Player): Model?
  return player.Character :: Model
end


local function GetHrp(instance: Instance): BasePart?
  return instance:FindFirstChild("HumanoidRootPart") :: BasePart
end


local function GetHumanoid(instance: Instance): Humanoid?
  return instance:FindFirstChildOfClass("Humanoid") :: Humanoid
end


local function GetPlayerCharacter(player: Player): Model?
  local PlayerCharacterCache = CharacterCache[player.Address]
  if not PlayerCharacterCache then return nil end

  local CachedCharacter = PlayerCharacterCache.Character :: Model?
  if CachedCharacter and CachedCharacter.Parent then return CachedCharacter end

  local Character = player.Character :: Model
  if not Character then return nil end

  PlayerCharacterCache.Character = Character
  return Character
end


local function GetPlayerHrp(player: Player): BasePart?
  local PlayerCharacterCache = CharacterCache[player.Address]
  if not PlayerCharacterCache then return nil end

  local CachedHrp = PlayerCharacterCache.Hrp
  if CachedHrp and CachedHrp.Parent then return CachedHrp end

  local Character = GetPlayerCharacter(player)
  if not Character then return nil end

  local Hrp = GetHrp(Character)
  if not Hrp then return nil end

  PlayerCharacterCache.Hrp = Hrp
  return Hrp
end


local function GetPlayerHumanoid(player: Player): Humanoid?
  local PlayerCharacterCache = CharacterCache[player.Address]
  if not PlayerCharacterCache then return nil end

  local CachedHumanoid = PlayerCharacterCache.Humanoid
  if CachedHumanoid and CachedHumanoid.Parent then return CachedHumanoid end

  local Character = GetPlayerCharacter(player)
  if not Character then return nil end

  local Humanoid = GetHumanoid(Character)
  if not Humanoid then return nil end

  PlayerCharacterCache.Humanoid = Humanoid
  return Humanoid
end


local function GetTitanHrp(titan: Instance): BasePart?
  if not titan or not titan.Parent then return nil end

  local TitanCache = TitansCache[titan.Address]
  if not TitanCache then return nil end

  local CachedHrp = TitanCache.Parts.HumanoidRootPart
  if CachedHrp and CachedHrp.Parent then return CachedHrp end

  local TitanHrp = GetHrp(titan)
  if not TitanHrp then return nil end

  TitanCache.Parts.HumanoidRootPart = TitanHrp
  return TitanHrp
end


local function GetTitanHumanoid(titan: Instance): Humanoid?
  if not titan or not titan.Parent then return nil end

  local TitanCache = TitansCache[titan.Address]
  if not TitanCache then return nil end

  local CachedHumanoid = TitanCache.Parts.Humanoid
  if CachedHumanoid and CachedHumanoid.Parent then return CachedHumanoid end

  local TitanHumanoid = GetHumanoid(titan)
  if not TitanHumanoid then return nil end

  TitanCache.Parts.Humanoid = TitanHumanoid
  return TitanHumanoid
end


local function RegisterPlayer(player: Player)
  local existing = CharacterCache[player.Address]

  if existing then
    existing.Character = player.Character
    return
  end

  CharacterCache[player.Address] = {
    Character = player.Character,
    Hrp = nil,
    Humanoid = nil,

    Username = player.Name,
    DisplayName = player.DisplayName,
    UserId = player.UserId
  }
end

--#endregion -- Player's character and Titan's character related functions --


--#region -- Titan functions --

local function IsTitanIgnored(titan: Instance?): boolean
  if not titan or not titan.Parent then return false end

  local TitanCache = TitansCache[titan.Address]
  if not TitanCache then return false end

  local TitanInfo = TitanCache.Info
  if not TitanInfo.Ignored then return false end

  local IgnoredTime = TitanInfo.IgnoredTime
  if not IgnoredTime then return false end

  local IgnoreDuration = TitanInfo.IgnoreDuration
  if not IgnoreDuration then return false end

  if OsClock() - IgnoredTime >= IgnoreDuration then
    TitanCache.TpFails.Count = 0
    TitanInfo.Ignored = false
    TitanInfo.IgnoredTime = nil
    TitanInfo.IgnoreDuration = nil
    return false
  end

  return true
end


local function RegisterTitanFail(titan: Instance?)
  if not titan or not titan.Parent then return end

  local TitanCache = TitansCache[titan.Address]
  if not TitanCache then return end

  local TitanInfo = TitanCache.Info

  TitanCache.TpFails.Count += 1

  if TitanCache.TpFails.Count > 3 then
    TitanInfo.Ignored = true
    TitanInfo.IgnoredTime = OsClock()
    TitanInfo.IgnoreDuration = 5
  end
end


local function GetTitanType(titan: Instance): string -- Needs more research
  local TitanCache = TitansCache[titan.Address]
  if not TitanCache then return "Normal" end

  local TitanTypeCached = TitanCache.Info.Type
  if TitanTypeCached then return TitanTypeCached end

  local TitanType = titan:GetAttribute("Type") :: string? or "Normal"

  TitanCache.Info.Type = TitanType
  return TitanType
end


local function GetTitanNape(titan: Instance): BasePart?
  if not titan or not titan.Parent then return nil end

  local TitanCache = TitansCache[titan.Address]
  if not TitanCache then return nil end

  local CachedNape = TitanCache.Parts.Nape
  if CachedNape and CachedNape.Parent then return CachedNape end

  local NapePart = GetPath(titan, true, "Hitboxes", "Hit", "Nape") :: BasePart
  if not NapePart then return nil end

  TitanCache.Parts.Nape = NapePart
  return NapePart
end


local function IsTitanAlive(titan: Instance?): boolean
  if not titan or not titan.Parent then return false end

  local TitanAddress = titan.Address
  if not TitanAddress then return false end

  local TitanCache = TitansCache[TitanAddress]
  if not TitanCache then return false end

  local TitanHumanoid = GetTitanHumanoid(titan)
  if not TitanHumanoid then return false end

  local now = OsClock()

  if TitanCache.Info.LastAliveCheck and now - TitanCache.Info.LastAliveCheck < 0.2 then
    return TitanCache.Info.Alive or false
  end

  local ok, alive = pcall(function()
    return TitanHumanoid.Health > 0
  end)

  if not ok then return false end

  TitanCache.Info.LastAliveCheck = now
  TitanCache.Info.Alive = alive
  return TitanCache.Info.Alive :: boolean
end


local function BringNapeToPlayer(titan: Instance, size: Vector3?)
  if not titan or not titan.Parent then return end

  local TitanCache = TitansCache[titan.Address]
  if not TitanCache then return end

  local NapePartCached = TitanCache.Parts.Nape
  if not NapePartCached or not NapePartCached.Parent then return end

  local NapePart = GetTitanNape(titan)
  if not NapePart or not NapePart.Parent then return end

  local PlayerHrp = GetPlayerHrp(LocalPlayer)
  if not PlayerHrp then return end

  TitanCache.Parts.Nape = NapePart

  NapePart.CFrame = PlayerHrp.CFrame * CFrame.new(0, 2, 0)

  if size then
    NapePart.Size = size
    TitanCache.Nape.CurrentSize = size
  end
end


local function GetTitanBobHeight(titan: Instance): number
  local TitanType = GetTitanType(titan)
  if not TitanType then return 120 end -- default for "Attack" titan

  return TitansInfo["Height" .. TitanType] or 120
end


local function GetNearestTitan(): Instance?
  if OsClock() - LastNearestUpdate < 1
    and CachedNearestTitan
    and CachedNearestTitan.Parent
    and IsTitanAlive(CachedNearestTitan)
    and not IsTitanIgnored(CachedNearestTitan)
  then
    return CachedNearestTitan
  end -- Honestly, why update so much?

  local NearestTitan: Instance? = nil
  local NearestDistance = math.huge

  local PlayerHrp = GetPlayerHrp(LocalPlayer)
  if not PlayerHrp then return nil end

  for _, titan in pairs(KnownTitans) do
    if not titan or not titan.Parent then continue end
    -- if not titan:IsA("Model") then continue end
    if IsTitanIgnored(titan) then continue end
    if not IsTitanAlive(titan) then continue end

    local TitanHrp = GetTitanHrp(titan)
    if not TitanHrp then continue end

    local ok, Distance = pcall(function()
      return (TitanHrp.Position - PlayerHrp.Position).Magnitude
    end)

    if not ok or not Distance then
      DebugPrint( "warn", 0, nil, nil, "Failed to calculate distance to titan: ", tostring(titan.Name), " Error: ", tostring(Distance) )

      continue
    end

    if Distance < NearestDistance then
      NearestDistance = Distance
      NearestTitan = titan
    end
  end

  CachedNearestTitan = NearestTitan
  LastNearestUpdate = OsClock()

  return NearestTitan
end


local function TpAboveTitan(titan): boolean -- This might require changes!
  if not titan or not titan.Parent then return false end

  local TitanCache = TitansCache[titan.Address]
  if not TitanCache then return false end

  local LocalPlayerCache = CharacterCache[LocalPlayer.Address]
  if not LocalPlayerCache then return false end

  local Hrp = LocalPlayerCache.Hrp or GetPlayerHrp(LocalPlayer)
  if not Hrp then return false end

  local TitanHrp: BasePart? = GetTitanHrp(titan)
  if not TitanHrp or not TitanHrp:IsA("BasePart") then return false end

  local TitanPosition: Vector3 = TitanHrp.Position

  local BobHeight = GetTitanBobHeight(titan)
  if not BobHeight then return false end

  local BobOffset = MathSin(OsClock() * MathPi * 2) * TitansInfo.BobAmplitude

  DebugPrint("debug", 3, nil, nil, "Teleporting to the titan: " .. tostring(titan.Name))

  local ok, err = pcall(function()
    Hrp.CFrame = CFrame.new(
      TitanPosition.X,
      TitanPosition.Y + BobHeight + BobOffset,
      TitanPosition.Z
    )
  end)

  if not ok then
    DebugPrint("warn", 0, nil, nil, "Error happened while setting CFrame to titan: " .. err)
    return false
  end

  return true
end


local function RegisterTitan(titan: Instance?)
  if not titan or not titan.Parent then
    DebugPrint( "warn", 0, nil, nil, "RegisterTitan: invalid titan or missing Address: ", titan and tostring(titan.Name) or "nil", titan and tostring(titan.Address) or "0" )
    return
  end

  if TitansCache[titan.Address] then return end

  TitansCache[titan.Address] = {
    Instance = titan,

    Info = {
      Name = titan.Name,
      Type = nil,

      Alive = true,

      Ignored = false,
      IgnoredTime = nil,
      IgnoreDuration = nil
    },

    Parts = {
      Nape = nil,
      HumanoidRootPart = nil,
      Humanoid = nil
    },

    Nape = {
      CurrentSize = nil
    },

    TpFails = {
      Count = 0
    }
  }

  local Parts = TitansCache[titan.Address].Parts
  Parts.Nape = GetTitanNape(titan)
  Parts.HumanoidRootPart = GetTitanHrp(titan)
  Parts.Humanoid = GetTitanHumanoid(titan)

  DebugPrint("debug", 0, nil, nil, string.format("Register information: Titan Info: %s", titan.Name))
end

--#endregion -- Titan functions --



--#region Gas tank functions --

local function GetCached(cacheKey: string, parent: Instance, ...)
  local cached = UiCache[cacheKey]
  if cached then return cached end

  local obj = GetPath(parent, false, ...)
  if not obj then return nil end

  UiCache[cacheKey] = obj
  return obj
end


local function AreBladesFullyBroken(): boolean
  if OsClock() - LastBladeCheck < 0.5 then return CachedBladesBroken end

  LastBladeCheck = OsClock()

  local RightBlade = BladeCache.RightBlade :: Instance
  local LeftBlade = BladeCache.LeftBlade :: Instance

  if not RightBlade or not RightBlade.Parent or not LeftBlade or not LeftBlade.Parent then
    local LocalPlayerCharacterCache = CharacterCache[LocalPlayer.Address]
    if not LocalPlayerCharacterCache then return false end

    local Character = LocalPlayerCharacterCache.Character :: Instance
      or GetPlayerCharacter(LocalPlayer)
    if not Character then return false end

    local Rig_ = Character:FindFirstChild("Rig_" .. LocalPlayer.Name)
    if not Rig_ then return false end

    local RightHand = BladeCache.RightHand :: Instance
    local LeftHand = BladeCache.LeftHand :: Instance

    if not RightHand or not LeftHand then
      RightHand = Rig_:FindFirstChild("RightHand")
      LeftHand = Rig_:FindFirstChild("LeftHand")

      if not RightHand or not LeftHand then return false end

      BladeCache.RightHand = RightHand
      BladeCache.LeftHand = LeftHand
    end

    RightBlade = RightHand:FindFirstChild("Blade_1")
    LeftBlade = LeftHand:FindFirstChild("Blade_1")

    if not RightBlade or not LeftBlade then return false end

    BladeCache.RightBlade = RightBlade
    BladeCache.LeftBlade = LeftBlade
  end

  local ok, AreBroken = pcall(function()
    local RightTransparency = memory_read(
      "float",
      RightBlade.Address :: number + TransparencyBasePartOffset
    )

    local LeftTransparency = memory_read(
      "float",
      LeftBlade.Address :: number + TransparencyBasePartOffset
    )

    return RightTransparency >= 0.9 and LeftTransparency >= 0.9
  end)

  if not ok then
    DebugPrint("warn", 0, nil, nil, "Memory read failed:", AreBroken)
    return false
  end

  CachedBladesBroken = AreBroken
  return AreBroken
end


local function DoINeedToRefill(): boolean -- The 0 / 3 counter
  local Blades = GetCached("Blades", DownMiddlePartUi, "Blades")
  if not Blades then return true end

  local TextForBlades = GetCached("TextForBlades", Blades, "Sets") :: TextLabel?
  if not TextForBlades then return true end

  local Gas = GetCached("Gas", DownMiddlePartUi, "Gas")
  if not Gas then return true end

  local TextForGas = GetCached("TextForGas", Gas, "Percentage") :: TextLabel?
  if not TextForGas then return true end

  local BladesValue = tonumber(TextForBlades.Text:match("%d+")) or 0
  local GasValue = tonumber(TextForGas.Text:match("%d+")) or 0

  return BladesValue == 0 or GasValue == 0
end


local function IsReloadingBlades(): boolean
  local LocalPlayerCache = CharacterCache[LocalPlayer.Address]
  if not LocalPlayerCache then return false end

  local Hrp = LocalPlayerCache.Hrp or GetPlayerHrp(LocalPlayer)
  if not Hrp then return false end

  if Hrp:FindFirstChild("BV") then return false end
  -- Basically, when reloading the 0 / 3 counter, the BV is missing.

  return true
end


local function HandleAllReloads()
  if not AreBladesFullyBroken() then return end

  local LocalPlayerCharacterCache = CharacterCache[LocalPlayer.Address]
  if not LocalPlayerCharacterCache then return end

  local Hrp = LocalPlayerCharacterCache.Hrp or GetPlayerHrp(LocalPlayer)
  if not Hrp then return end

  local Time = OsClock()

  if DoINeedToRefill() then
    DebugPrint("debug", 0, nil, nil, "Detected that the local player needs refilling.")

    while true do
      if not DoINeedToRefill() then break end
      if IsReloadingBlades() then
        task.wait(0.5)
        continue
      end

      if OsClock() - Time > 10 then
        DebugPrint("warn", 0, nil, nil, "Timeout happened while trying to refill?")
        break
      end

      if GasTankPosition then
        Hrp.AssemblyLinearVelocity = Vector3Zero
        task.wait(0.24)

        Hrp.Position = GasTankPosition + Vector3New(5, 0, 0)
        Hrp.AssemblyLinearVelocity = Vector3Zero

        task.wait(0.5)

        keypress(0x52)
        task.wait(0.5)
        keyrelease(0x52)

        task.wait(1)
        continue
      end

      local PartAddress = memory_read("uintptr_t", GasTankModel.Address + PrimaryPartOffset )

      if PartAddress == 0 then
        DebugPrint("warn", 0, nil, nil, "No PrimaryPart for gas tank found!")
        return
      end

      local Primitive = memory_read( "uintptr_t", PartAddress + BaseToPrimitiveOffset )

      if Primitive == 0 then
        DebugPrint("warn", 0, nil, nil, "No Primitive part found for 'PartAdress'!")
        return
      end

      local x = memory_read("float", Primitive + PrimitivePositionOffset)
      local y = memory_read("float", Primitive + PrimitivePositionOffset + 4)
      local z = memory_read("float", Primitive + PrimitivePositionOffset + 8)

      GasTankPosition = Vector3New(x, y, z)
      DebugPrint("debug", 0, nil, nil, "Fetched gas tank position from memory: ", GasTankPosition)
    end

  else
    -- Case 2: Only needs to reload blades
    if ReloadingBlades then return end
    if OsClock() - LastReloadingTime < 3 then return end

    DebugPrint("debug", 0, nil, nil, "Detected that the local player needs reloading.")

    ReloadingBlades = true
    LastReloadingTime = OsClock()

    task.spawn(function()
      -- To not fall while reloading
      if not isrbxactive() then
        ReloadingBlades = false
        return
      end

      DebugPrint("debug", 0, nil, nil, "Proceeding to reload blades.")

      Hrp.CFrame = SafePos

      keypress(0x52)
      task.wait(0.5)
      keyrelease(0x52)
      task.wait(0.5)

      ReloadingBlades = false
    end)
  end
end

--#endregion Gas tank functions --


--#region -- Ui elements functions --

local function IsObjectVisible(object: GuiObject): boolean
  if not object or not object.Address then return false end

  local ok, value = pcall(function()
    return memory_read("byte", object.Address + VisibleOffset)
  end)

  if not ok then
    DebugPrint( "warn", 0, nil, nil, "Something went wrong in memory reading for the object: ", tostring(object:GetFullName()) )
    return false
  end

  return value ~= 0
end


local function IsRetryVisible(): boolean
  local RewardsFrame

  if UiCache.RewardsFrame and UiCache.RewardsFrame.Parent then
    return IsObjectVisible(UiCache.RewardsFrame)
  end

  RewardsFrame = GetPath(PlayerGui, true, "Interface", "Rewards") :: GuiObject
  if not RewardsFrame then return false end

  UiCache.RewardsFrame = RewardsFrame
  return IsObjectVisible(RewardsFrame)
end


local function PressRetry()
  if not IsRetryVisible() then return end

  DebugPrint("debug", 0, nil, nil, "Pressing the retry button!")
  task.wait(0.5)

  -- keypress(0xDE); task.wait(0.3); keyrelease(0xDE); task.wait(1.0)

  keypress(0xDC)
  task.wait(0.3)
  keyrelease(0xDC)
  task.wait(1.0) -- Backslash key

  keypress(0x44)
  task.wait(0.2)
  keyrelease(0x44)
  task.wait(0.4) -- D key

  keypress(0x44)
  task.wait(0.2)
  keyrelease(0x44)
  task.wait(0.4) -- D key

  keypress(0x0D)
  task.wait(0.3)
  keyrelease(0x0D)
  task.wait(0.6) -- Enter key

  -- keypress(0xDE); task.wait(0.3); keyrelease(0xDE); task.wait(0.5)
  -- keypress(0xDC); task.wait(0.3); keyrelease(0xDC); task.wait(0.5)
end

--#endregion -- Ui elements functions --



-- // Some functions that couldn't fit before \\ --
local function KillTitan(titan: Instance)
  if not titan or not titan.Parent then return end

  local StartTime = OsClock()

  local LocalPlayerCharacterCache = CharacterCache[LocalPlayer.Address]; if not LocalPlayerCharacterCache then return end
  local Hrp = LocalPlayerCharacterCache.Hrp or GetPlayerHrp(LocalPlayer); if not Hrp then return end

  while true do
    task.wait(0.06)
    if not IsTitanAlive(titan) then break end
    if AreBladesFullyBroken() then break end
    if OsClock() - StartTime > 10 then 
      DebugPrint("warn", 0, nil, nil, "Timeout happened while trying to kill the titan: " .. tostring(titan.Name))
      break
    end

    if not isrbxactive() then
      Hrp.CFrame = SafePos
      Hrp.AssemblyLinearVelocity = Vector3Zero
      task.wait(0.5)
    
    else
      local Success = TpAboveTitan(titan)

      if not Success then
        RegisterTitanFail(titan)
        DebugPrint("warn", 0, nil, nil, "Failed to teleport above the titan: " .. tostring(titan.Name))
        task.wait(0.1)
        break

      end

      BringNapeToPlayer(titan, Vector3New(15, 15, 15))

      task.wait()
      mouse1click()
      task.wait(0.03)
      keypress(0x20)
      task.wait(0.03)
      keyrelease(0x20)
    end
  end
end


--#endregion -- Functions --



--#region -- Main loops and events --

task.spawn(function() -- KnownTitans updater and TitansCache cleanup
  while true do
    DebugPrint("debug", 4, nil, nil, "The known titans updater is running!")

    for _, titan in ipairs(TitansFolder:GetChildren()) do
      if not titan:IsA("Model") then continue end

      if not KnownTitans[titan.Address] then
        KnownTitans[titan.Address] = titan
      end
    end

    for address, titan in pairs(KnownTitans) do
      if not titan or not titan.Parent or not GetHumanoid(titan) then
        KnownTitans[address] = nil
        TitansCache[address] = nil
      end
    end

    task.wait(1)
  end
end)


task.spawn(function() -- Titans cache
  while true do
    DebugPrint("debug", 4, nil, nil, "The titan cache loop is running!")
    for _, titan in pairs(KnownTitans) do
      if titan and titan.Parent and GetHumanoid(titan) then
        RegisterTitan(titan)
      end
      task.wait()
    end

    task.wait(3)
  end
end)


task.spawn(function() -- The main loop, where the magic happens
  while true do
    DebugPrint("debug", 4, nil, nil, "The main loop is running!")

    if not UserConfigs.Autofarm then
      task.wait(1)
      continue
    end

    if IsRetryVisible() then
      DebugPrint("debug", nil, nil, nil, "Detected that the retry button is visible.")
      PressRetry()
      task.wait(3)
      continue
    end

    if AreBladesFullyBroken() then
      DebugPrint("debug", nil, nil, nil, "Detected that the lp needs reload / refill")
      HandleAllReloads()
      task.wait(1)
      continue
    end

    local NearestTitan = GetNearestTitan()

    if not NearestTitan then
      DebugPrint("debug", nil, nil, nil, "No nearest titan found?")
      task.wait(0.1)
      continue
    end

    KillTitan(NearestTitan)
    task.wait(0.1)
  end
end)


task.spawn(function() -- Players cache
  while true do
    DebugPrint("debug", 4, nil, nil, "The player cache loop is running!")
    for _, player in ipairs(Players:GetPlayers()) do
      RegisterPlayer(player)
      task.wait()
    end

    for playerAddress, cache in pairs(CharacterCache) do
      local character = cache.Character

      if not character or not character.Parent then
        CharacterCache[playerAddress] = nil
      end
      task.wait()
    end

    task.wait(10)
  end
end)

--#endregion -- Main loops and events --



task.spawn(function() -- loop to fix matcha's weird task's bug
  while true do
    task.wait(math.huge)
  end

  task.spawn(function()
    while true do
      task.wait(math.huge)
    end

    task.spawn(function()
      while true do
        task.wait(math.huge)
      end
    end)
  end)
end)


