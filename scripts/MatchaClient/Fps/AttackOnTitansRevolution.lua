--!strict

--[[ 
- information:
  * Game name: Attack on Titans Revolution
  * Game Id: 4658598196
  * Game UniverseId: 4658598196
  * Game PlaceIds: 13379208636 (Lobby), 13379349730 (Mission) 4658598196 ( x )
  * Game link: https://www.roblox.com/games/13379208636/Attack-on-Titan-Revolution

  * Script version: 1.0.5 -- Rewrite


- Notes for kitty:
  * The titan cache SHALL only use the titan's address as a key.
  * The character cache SHALL only use the player address as a key.

]]


task.wait(1)

if game.GameId ~= 4658598196 then
  warn("[Kitty's Aotr] This script is only made for Attack on Titans Revolution, and it seems like you are not in the right game. Please execute this script in the game, and if you think this is a mistake, report this to me on discord, @roguekitty. ( with dot yes ).")
  return
end


local Workspace = nil; repeat task.wait(0.1);   Workspace = game:GetService("Workspace") until Workspace
local Players = nil; repeat task.wait(0.1);     Players = game:GetService("Players") until Players
local LocalPlayer = nil; repeat task.wait(0.1); LocalPlayer = Players.LocalPlayer until LocalPlayer
local PlayerGui = nil; repeat task.wait(0.1);   PlayerGui = LocalPlayer:FindFirstChild("PlayerGui") until PlayerGui
local HttpService = nil; repeat task.wait(0.1); HttpService = game:GetService("HttpService") until HttpService


local TitansFolder = nil; repeat task.wait(0.1); TitansFolder = Workspace:FindFirstChild("Titans") until TitansFolder
local Interface = nil; repeat task.wait(0.1); Interface = PlayerGui:FindFirstChild("Interface") until Interface
local CharactersFolder = nil; repeat task.wait(0.1); CharactersFolder = Workspace:FindFirstChild("Characters") until CharactersFolder
repeat task.wait(0.1) until TitansFolder:FindFirstChildOfClass("Model")


task.wait(1); warn("[Kitty's aotr] (debug): Sucesfully loaded the Titans folder!")

-- // Global variables defined as local ones \\ --
local MathSin = math.sin
local MathPi = math.pi

local StringLower = string.lower
local OsClock = os.clock


-- // Some variables \\ --
local UserConfigs = {
  Autofarm = true,
  DebugMode = true
}

local DebugRateLimit: {
  [string]: {
    WindowStart: number,
    Count: number
  }
} = {}


local DebugEnabled = UserConfigs.DebugMode
local CurrentLogFile = nil

if UserConfigs.DebugMode then
  local DateString = os.date("%Y-%m-%d")
  local TimeString = os.date("%H-%M-%S")
  local Path       = "KittyScripts/Aotr/logs/"
  local FileName   = Path .. "log_" .. DateString .. "_" .. TimeString .. ".txt"

    -- Build a detailed header
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
    -- Address: number?,

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


-- // Some functions \\ --
local function DebugPrint(mode: string, maxAmount: number, ...)
  if not UserConfigs.DebugMode then return end

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

  local args = table.pack(...)
  local MessageParts = {}

  for i = 1, args.n do
    MessageParts[i] = tostring(args[i])
  end

  local FinalMessage = table.concat(MessageParts, " ")
  local RateKey = ModeLower .. ":" .. FinalMessage

  if maxAmount ~= 0 then -- Basically, the ones that have 0 are infinite
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
    if not CurrentInstance then if Warning and DebugEnabled then DebugPrint("warn", 0, "Path broke for: " .. name) end; return nil end
    local NextInstance = CurrentInstance:FindFirstChild(name); if not NextInstance then if Warning and DebugEnabled then DebugPrint("warn", 0, "Missing: " .. name .. " in " .. (CurrentInstance and CurrentInstance:GetFullName() or "<unknown>")) end; return nil end

    CurrentInstance = NextInstance
  end

  return CurrentInstance
end


local function GetOffsets(): OffsetsData?
  local ok, res = pcall(function() 
    return game:HttpGet("https://imtheo.lol/Offsets/Offsets.json")
  end)
    
  if not ok or not res then 
    if DebugEnabled then
      DebugPrint("warn", 0, "Failed to fetch offsets: " .. tostring(res)) 
    end
    return nil
  end

  local success, decoded = pcall(function() 
    return HttpService:JSONDecode(res) 
  end)
  
  if not success then
    if DebugEnabled then
      DebugPrint("warn", 0, "JSON decode failed")
    end
    return nil
  end

  return decoded :: OffsetsData
end

local OffsetsFake = GetOffsets(); if not OffsetsFake or next(OffsetsFake) == nil then return end









-- // Random variables section \\ --
local Vector3New = Vector3.new
local Vector3Zero: Vector3 = Vector3New(0, 0, 0)

local SafePos: CFrame = CFrame.new(900, 9999, 900) -- Maybe search a better version instead of just air..?
local CurrentMission: string? = nil

local GasTankModel: Instance? = nil
local GasTankPosition: Vector3? = nil

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






-- // More functions \\ --
local function GetCached(cacheKey: string, parent: Instance, ...)
  local cached = UiCache[cacheKey]; if cached then return cached end

  local obj = GetPath(parent, false, ...); if not obj then return nil end

  UiCache[cacheKey] = obj
  return obj
end

local function HandleDifferentGasTankPaths(): Instance?
  local Shiganshina = GetPath(Workspace, false, "Climbable",   "Walls",      "Gate",      "GasTanks"); if Shiganshina then if DebugEnabled then DebugPrint("debug", 0, "Shiganshina detected!") end; GasTankModel = Shiganshina; return Shiganshina end
  local Trost       = GetPath(Workspace, false, "Unclimbable", "Camps",      "Camp",      "GasTanks"); if Trost       then if DebugEnabled then DebugPrint("debug", 0, "Trost detected!") end;       GasTankModel = Trost;       return Trost       end
  local OutSkirts   = GetPath(Workspace, false, "Climbable",   "_Walls",     "Gate",      "GasTanks"); if OutSkirts   then if DebugEnabled then DebugPrint("debug", 0, "Outskirts detected!") end;   GasTankModel = OutSkirts;   return OutSkirts   end
  local Forest      = GetPath(Workspace, false, "Unclimbable", "Camps",      "Camp",      "GasTanks"); if Forest      then if DebugEnabled then DebugPrint("debug", 0, "Forest detected!") end;      GasTankModel = Forest;      return Forest      end
  local UtGard      = GetPath(Workspace, false, "Climbable",   "Utgard",     "GasTanks");              if UtGard      then if DebugEnabled then DebugPrint("debug", 0, "UtGard detected!") end;      GasTankModel = UtGard;      return UtGard      end
  local Docks       = GetPath(Workspace, false, "Unclimbable", "World",      "Buildings", "Hanger",   "GasTanks"); if Docks  then if DebugEnabled then DebugPrint("debug", 0, "Docks detected!") end;       GasTankModel = Docks;       return Docks       end
  local Stohess     = GetPath(Workspace, false, "Unclimbable", "Props",      "HQ",        "GasTanks"); if Stohess     then if DebugEnabled then DebugPrint("debug", 0, "Stohess detected!") end;     GasTankModel = Stohess;     return Stohess     end
  local Chapel      = GetPath(Workspace, false, "Unclimbable", "Reloads",    "GasTanks");              if Chapel      then if DebugEnabled then DebugPrint("debug", 0, "Chapel detected!") end;      GasTankModel = Chapel;      return Chapel      end

  local Waves       = GetPath(Workspace, false, "Unclimbable", "Objective",  "Waves",     "GasTanks"); if Waves       then if DebugEnabled then DebugPrint("debug", 0, "Waves detected!") end;       GasTankModel = Waves;       return Waves       end

  if DebugEnabled then DebugPrint("warn", 0, "No known GasTankModel path found. Please report this to me on discord, @roguekitty. ( with dot yes ).") end
  return nil
end; HandleDifferentGasTankPaths(); if not GasTankModel then return end



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
  local PlayerCharacterCache = CharacterCache[player.Address]; if not PlayerCharacterCache then return nil end
  local CachedCharacter= PlayerCharacterCache.Character :: Model?; if CachedCharacter and CachedCharacter.Parent then return CachedCharacter end

  local Character = player.Character :: Model; if not Character then return nil end
  PlayerCharacterCache.Character = Character
  return Character
end


local function GetPlayerHrp(player: Player): BasePart?
  local PlayerCharacterCache = CharacterCache[player.Address]; if not PlayerCharacterCache then return nil end
  local CachedHrp = PlayerCharacterCache.Hrp; if CachedHrp and CachedHrp.Parent then return CachedHrp end

  local Character = GetPlayerCharacter(player); if not Character then return nil end
  local Hrp = GetHrp(Character); if not Hrp then return nil end
  PlayerCharacterCache.Hrp = Hrp
  return Hrp  
end


local function GetPlayerHumanoid(player: Player): Humanoid?
  local PlayerCharacterCache = CharacterCache[player.Address]; if not PlayerCharacterCache then return nil end
  local CachedHumanoid = PlayerCharacterCache.Humanoid; if CachedHumanoid and CachedHumanoid.Parent then return CachedHumanoid end

  local Character = GetPlayerCharacter(player); if not Character then return nil end
  local Humanoid = GetHumanoid(Character); if not Humanoid then return nil end
  PlayerCharacterCache.Humanoid = Humanoid
  return Humanoid  
end





local function GetTitanHrp(titan: Instance): BasePart?
  if not titan or not titan.Parent then return nil end

  local TitanCache = TitansCache[titan.Address]; if not TitanCache then return nil end
  local CachedHrp = TitanCache.Parts.HumanoidRootPart; if CachedHrp and CachedHrp.Parent then return CachedHrp end

  local TitanHrp = GetHrp(titan); if not TitanHrp then return nil end

  TitanCache.Parts.HumanoidRootPart = TitanHrp
  return TitanHrp
end


local function GetTitanHumanoid(titan: Instance): Humanoid?
  if not titan or not titan.Parent then return nil end

  local TitanCache = TitansCache[titan.Address]; if not TitanCache then return nil end
  local CachedHumanoid = TitanCache.Parts.Humanoid; if CachedHumanoid and CachedHumanoid.Parent then return CachedHumanoid end

  local TitanHumanoid = GetHumanoid(titan); if not TitanHumanoid then return nil end

  TitanCache.Parts.Humanoid = TitanHumanoid
  return TitanHumanoid
end


local function RegisterPlayer(player: Player)
  local existing = CharacterCache[player.Address]

  if existing then existing.Character = player.Character; return end

  CharacterCache[player.Address] = {
    Character = player.Character,
    Hrp = nil,
    Humanoid = nil,

    Username = player.Name,
    DisplayName = player.DisplayName,
    UserId = player.UserId
  }
end

-- // Titan functions \\ --
local function IsTitanIgnored(titan: Instance?): boolean
  if not titan or not titan.Parent then return false end

  local TitanCache = TitansCache[titan.Address]; if not TitanCache then return false end
  local TitanInfo = TitanCache.Info
    
  if not TitanInfo.Ignored then return false end

  local IgnoredTime = TitanInfo.IgnoredTime; if not IgnoredTime then return false end
  local IgnoreDuration = TitanInfo.IgnoreDuration; if not IgnoreDuration then return false end


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

  local TitanCache = TitansCache[titan.Address]; if not TitanCache then return end

  local TitanInfo = TitanCache.Info

  TitanCache.TpFails.Count += 1

  if TitanCache.TpFails.Count > 3 then
    TitanInfo.Ignored = true
    TitanInfo.IgnoredTime = OsClock()
    TitanInfo.IgnoreDuration = 5
  end
end


local function GetTitanType(titan: Instance): string -- Needs more research
  local TitanCache = TitansCache[titan.Address]; if not TitanCache then return "Normal" end
  local TitanTypeCached = TitanCache.Info.Type; if TitanTypeCached then return TitanTypeCached end

  local TitanType = titan:GetAttribute("Type") :: string? or "Normal"

  TitanCache.Info.Type = TitanType
  return TitanType
end


local function GetTitanNape(titan: Instance): BasePart?
  if not titan or not titan.Parent then return nil end

  local TitanCache = TitansCache[titan.Address]; if not TitanCache then return nil end
  local CachedNape = TitanCache.Parts.Nape; if CachedNape and CachedNape.Parent then return CachedNape end

  local NapePart = GetPath(titan, true, "Hitboxes", "Hit", "Nape") :: BasePart; if not NapePart then return nil end

  TitanCache.Parts.Nape = NapePart
  return NapePart
end


local function IsTitanAlive(titan: Instance?): boolean

  if not titan or not titan.Parent then return false end
  local TitanAddress = titan.Address; if not TitanAddress then return false end


  local TitanCache = TitansCache[TitanAddress]; if not TitanCache then return false end
  local TitanHumanoid = GetTitanHumanoid(titan); if not TitanHumanoid then return false end

  local now = OsClock()

  if TitanCache.Info.LastAliveCheck and now - TitanCache.Info.LastAliveCheck < 0.2 then return TitanCache.Info.Alive or false end


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

  local TitanCache = TitansCache[titan.Address]; if not TitanCache then return end
  local NapePartCached = TitanCache.Parts.Nape; if not NapePartCached or not NapePartCached.Parent then return end

  local NapePart = GetTitanNape(titan); if not NapePart or not NapePart.Parent then return end
  local PlayerHrp = GetPlayerHrp(LocalPlayer); if not PlayerHrp then return end

  TitanCache.Parts.Nape = NapePart



  NapePart.CFrame = PlayerHrp.CFrame * CFrame.new(0, 2, 0)





  if size then
    NapePart.Size = size
    TitanCache.Nape.CurrentSize = size
  end
end

local function GetTitanBobHeight(titan: Instance): number
  local TitanType = GetTitanType(titan); if not TitanType then return 120 end -- default for "Attack" titan

  return TitansInfo["Height" .. TitanType] or 120
end


local function GetNearestTitan(): Instance?
  if OsClock() - LastNearestUpdate < 1 and CachedNearestTitan and CachedNearestTitan.Parent and IsTitanAlive(CachedNearestTitan) and not IsTitanIgnored(CachedNearestTitan) then return CachedNearestTitan end -- Honestly, why update so much?

  local NearestTitan: Instance? = nil
  local NearestDistance = math.huge

  local PlayerHrp = GetPlayerHrp(LocalPlayer); if not PlayerHrp then return nil end

  for _, titan in pairs(KnownTitans) do
    if not titan or not titan.Parent then continue end
    -- if not titan:IsA("Model") then continue end -- Pretty sure all children are models.
    if IsTitanIgnored(titan) then continue end
    if not IsTitanAlive(titan) then continue end

    local TitanHrp = GetTitanHrp(titan); if not TitanHrp then continue end
    if not PlayerHrp then continue end

    local ok, Distance = pcall(function()
      return (TitanHrp.Position - PlayerHrp.Position).Magnitude
    end)
    
    if not ok or not Distance then
      if DebugEnabled then DebugPrint("warn", 0, "Failed to calculate distance to titan: " .. tostring(titan.Name) .. " Error: " .. tostring(Distance)) end
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

  local TitanCache = TitansCache[titan.Address]; if not TitanCache then return false end
 

  local LocalPlayerCache = CharacterCache[LocalPlayer.Address]; if not LocalPlayerCache then return false end
  local Hrp = LocalPlayerCache.Hrp or GetPlayerHrp(LocalPlayer); if not Hrp then return false end


  local TitanHrp: BasePart? = GetTitanHrp(titan); if not TitanHrp or not TitanHrp:IsA("BasePart") then return false end
  local TitanPosition: Vector3 = TitanHrp.Position

  local BobHeight = GetTitanBobHeight(titan); if not BobHeight then return false end
  local BobOffset = MathSin(OsClock() * MathPi * 2) * TitansInfo.BobAmplitude

  DebugPrint("debug", 3, "Teleporting to the titan: " .. tostring(titan.Name))

  local ok, err = pcall(function()
    Hrp.CFrame = CFrame.new(TitanPosition.X, TitanPosition.Y + BobHeight + BobOffset, TitanPosition.Z)
  end)
  
  if not ok then
    DebugPrint("warn", 0, "Error happened while setting CFrame to titan: " .. err)
    return false
  end

  return true
end

local function RegisterTitan(titan: Instance?)
  if not titan or not titan.Parent then
    DebugPrint("warn", 0, ("RegisterTitan: invalid titan or missing Address: "), titan and tostring(titan.Name) or "nil", titan and tostring(titan.Address) or "0");
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
      CurrentSize = nil,
    },

    TpFails = {
      Count = 0
    }
  }

  local Parts = TitansCache[titan.Address].Parts
  Parts.Nape = GetTitanNape(titan)
  Parts.HumanoidRootPart = GetTitanHrp(titan)
  Parts.Humanoid = GetTitanHumanoid(titan)

  DebugPrint("debug", 0, string.format("Register information: Titan Info: %s", titan.Name ))
end







-- // Gas tank functions \\ --
local function AreBladesFullyBroken(): boolean
  if OsClock() - LastBladeCheck < 0.5 then return CachedBladesBroken end
  LastBladeCheck = OsClock()

  local RightBlade = BladeCache.RightBlade :: Instance
  local LeftBlade = BladeCache.LeftBlade :: Instance

  if not RightBlade or not RightBlade.Parent or not LeftBlade or not LeftBlade.Parent then
    local LocalPlayerCharacterCache = CharacterCache[LocalPlayer.Address]; if not LocalPlayerCharacterCache then return false end
    local Character = LocalPlayerCharacterCache.Character :: Instance or GetPlayerCharacter(LocalPlayer); if not Character then return false end
    local Rig_ = Character:FindFirstChild("Rig_" .. LocalPlayer.Name); if not Rig_ then return false end

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
    local RightTransparency = memory_read("float", RightBlade.Address :: number + TransparencyBasePartOffset)
    local LeftTransparency = memory_read("float", LeftBlade.Address :: number  + TransparencyBasePartOffset)

    return RightTransparency >= 0.9 and LeftTransparency >= 0.9
  end)

  if not ok then
    DebugPrint("warn", 0, "Memory read failed:", AreBroken)
    return false
  end
  CachedBladesBroken = AreBroken
  return AreBroken
end


local function DoINeedToRefill(): boolean -- The 0 / 3 counter
  local Blades = GetCached("Blades", DownMiddlePartUi, "Blades"); if not Blades then return true end
  local TextForBlades = GetCached("TextForBlades", Blades, "Sets") :: TextLabel?; if not TextForBlades then return true end
  local Gas = GetCached("Gas", DownMiddlePartUi, "Gas"); if not Gas then return true end
  local TextForGas = GetCached("TextForGas", Gas, "Percentage") :: TextLabel?; if not TextForGas then return true end

  local BladesValue = tonumber(TextForBlades.Text:match("%d+")) or 0
  local GasValue = tonumber(TextForGas.Text:match("%d+")) or 0

  return BladesValue == 0 or GasValue == 0
end


local function IsReloadingBlades(): boolean
  local LocalPlayerCache = CharacterCache[LocalPlayer.Address]; if not LocalPlayerCache then return false end
  local Hrp = LocalPlayerCache.Hrp or GetPlayerHrp(LocalPlayer); if not Hrp then return false end

  if Hrp:FindFirstChild("BV") then return false end -- Basically, when reloading the 0 / 3 counter, the BV is missing, not sure why.

  return true
end


local function HandleAllReloads()
  if not AreBladesFullyBroken() then return end

  local LocalPlayerCharacterCache = CharacterCache[LocalPlayer.Address]; if not LocalPlayerCharacterCache then return end
  local Hrp = LocalPlayerCharacterCache.Hrp or GetPlayerHrp(LocalPlayer); if not Hrp then return end
  local Time = OsClock()

  if DoINeedToRefill() then -- Case 1: No charges ( 0 / 3 ) -> needs refill
    DebugPrint("debug", 0, "Detected that the local player needs refilling.")

    while true do
      if not DoINeedToRefill() then break end
      if IsReloadingBlades() then task.wait(0.5); continue end
      if OsClock() - Time > 10 then DebugPrint("warn", 0, "Timeout happened while trying to refill?"); break end

      if GasTankPosition then
        Hrp.AssemblyLinearVelocity = Vector3Zero
        task.wait(0.24)
        Hrp.Position = GasTankPosition + Vector3New(5, 0, 0)
        Hrp.AssemblyLinearVelocity = Vector3Zero
        task.wait(0.5)

        keypress(0x52); task.wait(0.5); keyrelease(0x52)
        task.wait(1)
        continue
      else
        if OsClock() - Time > 10 then DebugPrint("warn", 0, "Timeout happened while trying to refill?"); break end
        if IsReloadingBlades() then task.wait(0.5); continue end


        local PartAddress = memory_read("uintptr_t", GasTankModel.Address + PrimaryPartOffset); if PartAddress == 0 then DebugPrint("warn", 0, "No PrimaryPart for gas tank found!"); return end
        local Primitive = memory_read("uintptr_t", PartAddress + BaseToPrimitiveOffset); if Primitive == 0 then DebugPrint("warn", 0, "No Primitive part found for 'PartAdress'!"); return end


        local x = memory_read("float", Primitive + PrimitivePositionOffset)
        local y = memory_read("float", Primitive + PrimitivePositionOffset + 4)
        local z = memory_read("float", Primitive + PrimitivePositionOffset + 8)

        GasTankPosition = Vector3New(x, y, z)
        DebugPrint("debug", 0, "Fetched gas tank position from memory: ", GasTankPosition)

      end
    end
  else -- Case 2: Only needs to reload blades -> Press r
    if ReloadingBlades then return end
    if OsClock() - LastReloadingTime < 3 then return end

    DebugPrint("debug", 0, "Detected that the local player needs reloading.")
    ReloadingBlades = true
    LastReloadingTime = OsClock()

    task.spawn(function() -- To not fall while reloading ( to lazy to implement in the kill titan a check )
      if not isrbxactive() then ReloadingBlades = false; return end

      DebugPrint("debug", 0, "Proceeding to reload blades.")
      Hrp.CFrame = SafePos
      keypress(0x52); task.wait(0.5); keyrelease(0x52); task.wait(0.5)
      ReloadingBlades = false
    end)
  end
end


-- // Ui elements functions \\ --
local function IsObjectVisible(object: GuiObject): boolean
  if not object or not object.Address then return false end

  local ok, value = pcall(function()
    return memory_read("byte", object.Address + VisibleOffset)
  end)

  if not ok then if DebugEnabled then DebugPrint("warn", 0, "Something went wrong in memory reading for the object: " .. tostring(object:GetFullName()) .. "."); end; return false end 

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
    RewardsFrame = GetPath(PlayerGui, true, "Interface", "Rewards") :: GuiObject; if not RewardsFrame then return false end
    UiCache.RewardsFrame = RewardsFrame
    return IsObjectVisible(RewardsFrame)
  end

end


local function PressRetry() 
  if not IsRetryVisible() then return end
  DebugPrint("debug", 0,"Pressing the retry button!")
  task.wait(0.5)
  -- keypress(0xDE); task.wait(0.3); keyrelease(0xDE); task.wait(1.0)
  keypress(0xDC); task.wait(0.3); keyrelease(0xDC); task.wait(1.0) -- Backslash key
  keypress(0x44); task.wait(0.2); keyrelease(0x44); task.wait(0.4) -- D key
  keypress(0x44); task.wait(0.2); keyrelease(0x44); task.wait(0.4) -- D key 
  keypress(0x0D); task.wait(0.3); keyrelease(0x0D); task.wait(0.6) -- Enter key
  -- keypress(0xDE); task.wait(0.3); keyrelease(0xDE); task.wait(0.5) 
  -- keypress(0xDC); task.wait(0.3); keyrelease(0xDC); task.wait(0.5) -- Backslash key
end


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
    if OsClock() - StartTime > 10 then if DebugEnabled then DebugPrint("warn", 0, "Timeout happened while trying to kill the titan: " .. tostring(titan.Name)); end; break end

    if not isrbxactive() then
      Hrp.CFrame = SafePos
      Hrp.AssemblyLinearVelocity = Vector3Zero
      task.wait(0.5)
    
    else
      local Success = TpAboveTitan(titan)

      if not Success then
        RegisterTitanFail(titan)
        DebugPrint("warn", 0, "Failed to teleport above the titan: " .. tostring(titan.Name))
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


task.spawn(function()
  while true do
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
    for addy, titan in pairs(KnownTitans) do
      if titan and titan.Parent and GetHumanoid(titan) then
        RegisterTitan(titan)
      end
    end
    task.wait(3)
  end
end)


task.spawn(function() -- The main loop, where the magic happens
  while true do
    DebugPrint("debug", 4, "The main loop is running!")
    
    if not UserConfigs.Autofarm then task.wait(1); continue end

    if IsRetryVisible() then warn("Retry button is visible!"); PressRetry(); task.wait(3); continue end
    if AreBladesFullyBroken() then warn("Refill needed!"); HandleAllReloads(); task.wait(1); continue end


  
    local NearestTitan = GetNearestTitan(); if not NearestTitan then warn("no nearest titan"); task.wait(0.1); continue end
    KillTitan(NearestTitan);
    task.wait(0.1)
  end
end)

task.spawn(function() -- Players cache
  while true do 
    for _, player in ipairs(Players:GetPlayers()) do 
      RegisterPlayer(player) 
    end 
    
    for playerAddress, cache in pairs(CharacterCache) do 
      local character = cache.Character; if not character or not character.Parent then
        CharacterCache[playerAddress] = nil
      end
    end
    task.wait(10)
  end
end)
