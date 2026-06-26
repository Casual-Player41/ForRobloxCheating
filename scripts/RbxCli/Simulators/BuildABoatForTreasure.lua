--!grant Filesystem


-- Game name: Build A Boat For Treasure
-- Game Id: 537413528
-- Game UniverseId: 210851291
-- Game PlaceIds: 537413528
-- Game link: https://www.roblox.com/games/537413528/Build-A-Boat-For-Treasure

-- Script version: 1.0.0




if not rbxcli or game.UniverseId ~= 210851291 then return end


--#region Helpers

local CurrentLogFile = nil
local ScriptStart = os.clock()

local DebugRateLimit = {}
local DebugPrefixHandler = { print = '+', debug = '!', warn = '-' }
local DebugHandler = { print = print, debug = print, warn = warn }


if _G.KittyDebugEnabled then
  local Path = "KittyScripts/x/logs/"
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


local function WaitForChild(root: Instance, child: string, timeout: number?): Instance?
  local Start = os.clock()

  while true do
    if timeout and os.clock() - Start > timeout then break end
    local ChildInstance = root:FindFirstChild(child)

    if IsValid(ChildInstance) then return ChildInstance end
    task.wait(1/15)
  end
  return nil
end


local function WaitForChildOfClass(root: Instance, class: string, timeout: number?): Instance?
  local Start = os.clock()

  while true do
    if timeout and os.clock() - Start > timeout then break end
    local ChildInstance = root:FindFirstChildOfClass(class)

    if IsValid(ChildInstance) then return ChildInstance end

    task.wait(1/15)
  end
  return nil
end


local function WaitForService(serviceName: string): any-- gotta define a service bs
  local Service = nil; repeat DebugPrint("debug", 5, 1, "Attempting to load the service: " .. serviceName); Service = game:GetService(serviceName); task.wait(1/15) until Service
  return Service
end

local function GetCharacter(player: Player) return player.Character :: Model end
local function GetHrp(character: Model) return character:FindFirstChildCached("HumanoidRootPart") end
local function GetHumanoid(character: Model) return character:FindFirstChildCached("Humanoid") end


DebugPrint("debug", 1, 0, "Attempting to load services and other esential features.")

local Players = WaitForService("Players")
local Workspace = WaitForService("Workspace")
local TweenService = WaitForService("TweenService")

local LocalPlayer = nil; repeat task.wait(1/15); LocalPlayer = Players.LocalPlayer until LocalPlayer

local CurrentCharacter = LocalPlayer.Character



local function TraversePath(root: Instance, ...: string): Instance?
  local CurrentInstance = root

  for _, name in {...} do
    if not CurrentInstance then return nil end

    local NextInstance = CurrentInstance:FindFirstChild(name); if not IsValid(NextInstance) then return nil end
    CurrentInstance = NextInstance
  end

  return CurrentInstance
end


local function WaitForTween(tween: any, timeout: number): boolean
  local Finished = false
  local Result = nil

  local Connection;
  Connection = tween.Completed:Connect(function(state)
    Finished = true
    Result = state

    Connection:Disconnect()
  end)

  local CurrentStart = os.clock()

  while not Finished do
    if os.clock() - CurrentStart > timeout then tween:Cancel(); return Enum.PlaybackState.Cancelled end
    task.wait(1/15)
  end

  return Result
end


local function TweenTpTo(hrp: BasePart, humanoid: Humanoid, endPosition: Vector3, speed: number, timeout: number, easingStyle: EasingStyle?, easingDirection: EasingDirection?, repeatCount: number?, reverses: boolean?, delayTime: number?)
  local NewChar = CurrentCharacter; if not IsValid(NewChar) then return Enum.PlaybackState.Cancelled end
  local NewHrp = GetHrp(NewChar); if not IsValid(NewHrp) or NewHrp ~= hrp then return Enum.PlaybackState.Cancelled end

  local CurrentPos = hrp.Position
  local Duration = (CurrentPos - endPosition).Magnitude / speed; if Duration <= 0 then return end

  local TweenInfo = TweenInfo.new(Duration, easingStyle or Enum.EasingStyle.Linear, easingDirection or Enum.EasingDirection.InOut, repeatCount or 0, reverses or false, delayTime or 0)
  local Tween = TweenService:Create(hrp, TweenInfo, { CFrame = CFrame.new(endPosition, endPosition + (endPosition - CurrentPos).Unit) }); Tween:Play()

  local Result = WaitForTween(Tween, (timeout or math.huge))

  if Result ~= Enum.PlaybackState.Completed then
    DebugPrint("debug", 5, 1, "Something happened during tweening.")
  end

  return Result == Enum.PlaybackState.Completed and humanoid.Health > 0
end


-- local function GetOffsets()
--   local RobloxVersion = nil; for index, value in rbxcli.get_product_information() do if index ~= "built_for_roblox_version" then continue end; RobloxVersion = value; DebugPrint("debug", nil, 1, "Found the roblox version: " .. tostring(RobloxVersion), ". Proceeding with fetching offsets") end
--   local OffsetsJson = HttpService:RequestAsync({ Body = nil, Headers = nil, Method = "GET", Url = "https://imtheo.lol/Offsets/" .. tostring(RobloxVersion) .. "/Offsets.json" }); if not OffsetsJson then DebugPrint("warn", 1, 1, "Failed to fetch offsets?"); return nil end

--   local OffsetsDecoded = HttpService:JSONDecode(OffsetsJson.Body); if not OffsetsDecoded then return nil end

--   return OffsetsDecoded
-- end; local FakeOffsets = GetOffsets(); if not FakeOffsets or not next(FakeOffsets) then DebugPrint("warn", nil, 0, "Failed to fetch offsets corectly. Offsets: " .. tostring(FakeOffsets)); return end



--#endregion Helpers


local OtherData = WaitForChild(LocalPlayer, "OtherData", 20)
local BoatStages = WaitForChild(Workspace, "BoatStages", 20)
local NormalStages = WaitForChild(BoatStages, "NormalStages")


--#region Functions


local function GetNonFinishedStages(): {}
  local Stages = {}

  for _, child in OtherData:GetChildren() do
    if child.Name:find("Stage") or child.Name == "End" then
      if child.Value ~= "" then continue end
      DebugPrint("debug", 10, 1, "Inserting the stage: ", child.Name)
      table.insert(Stages, child)
    end
  end

  table.sort(Stages, function(a, b)
    local NumberA = tonumber(string.match(a.Name, "%d+")) or -1
    local NumberB = tonumber(string.match(b.Name, "%d+")) or -1

    return NumberA < NumberB
  end)

  return Stages
end

local function GetStagePosBasedOnNumber(value: number): Vector3?
	local StageFolder = NormalStages:FindFirstChild("CaveStage" .. tostring(value)); if not StageFolder then return end
  local PartOne = StageFolder:FindFirstChild("DarknessPart"); if IsValid(PartOne) then return PartOne.Position end

	for _, stage in NormalStages:GetChildren() do
		if not string.find(stage.Name, "CaveStage") then continue end
		if not string.find(stage.Name, tostring(value)) then continue end

		local PartTwo = stage:FindFirstChild("DarknessPart"); if IsValid(PartTwo) then DebugPrint("debug", 10, 1, "Returning position for stage: ", value, PartTwo.Position); return PartTwo.Position end -- lowkey this part needs fixeing and uhhhhhhhhh, if it currently works then it works fine
	end
	
	return nil
end


--#endregion Functions

LocalPlayer.CharacterAdded:Connect(function(character)
  CurrentCharacter = character
end)



task.spawn(function()
  while task.wait(1/15) do
    local Character = CurrentCharacter; if not IsValid(Character) then continue end
    local Hrp = GetHrp(Character); if not IsValid(Hrp) then continue end
    local Humanoid = GetHumanoid(Character); if not IsValid(Humanoid) or Humanoid.Health <= 0 then continue end


    local TweenState1 = TweenTpTo(Hrp, Humanoid, Vector3.new(-55, 80, 1210), 500, 60); if not TweenState1 then continue end; DebugPrint("debug", 1, 0, "Sucesfully finished 'Tween1'")
    local TweenState2 = TweenTpTo(Hrp, Humanoid, Vector3.new(-55, 80, 8718), 500, 60); if not TweenState2 then continue end; DebugPrint("debug", 1, 0, "Sucesfully finished 'Tween2'")

    local EndReached = OtherData:FindFirstChild("EndReached"); if not EndReached then continue end

    local LastTpPos
    local ChestTrigger = TraversePath(NormalStages, "TheEnd", "GoldenChest", "Trigger"); if IsValid(ChestTrigger) then LastTpPos = ChestTrigger.Position + Vector3.new(0, 4, 0) end
    if not ChestTrigger then LastTpPos = Vector3.new(-55, -360, 9496) end

    repeat
      task.wait(1/15)
      local TweenState3 = TweenTpTo(Hrp, Humanoid, LastTpPos, 600, 20); if not TweenState3 then continue end; DebugPrint("debug", 2, 0, "Sucesfully finished 'Tween3")
      task.wait(0.1)
      Hrp.CFrame *= CFrame.new(0, 5, 0)
    until EndReached.Value ~= ""


    local UnFinishedStages = GetNonFinishedStages(); DebugPrint("debug", 3, 0, "There are: ", #UnFinishedStages, " un-finished stages.")

    for i = #UnFinishedStages, 1, -1 do
      DebugPrint("debug", 10, 0, "Checking the number ( stage but not actually ordered ): ", i)
			local TargetStage = UnFinishedStages[i]
			local StageNumber = tonumber(string.match(TargetStage.Name, "%d+")); if not StageNumber then continue end
		
			local TargetPosition = GetStagePosBasedOnNumber(StageNumber + 1); if not TargetPosition then DebugPrint("warn", 10, 0, "Failed to find position for stage number: " .. tostring(StageNumber)); continue end

      TweenTpTo(Hrp, Humanoid, Hrp.Position + Vector3.new(0, 400, 0), 10000, 60)

			repeat
        if CurrentCharacter ~= Character then break end
				task.wait(1/15) 
				local TweenState4 = TweenTpTo(Hrp, Humanoid, TargetPosition, 10000, 60); if not TweenState4 then continue end
				Hrp.Position = TargetPosition - Vector3.new(0, -10, 50)

			until TargetStage.Value ~= ""
		end

    local time = 0

    repeat
      task.wait(1/5)
      time += 0.25; if time > 20 then break end
      if CurrentCharacter ~= Character then
        break
      else
        Hrp.CFrame *= CFrame.new(0, 5, 0)
      end

    until false

  end
end)




