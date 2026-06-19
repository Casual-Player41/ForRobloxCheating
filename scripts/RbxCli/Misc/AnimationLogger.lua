local function IsValid(instance: Instance): boolean
  return instance and not instance:IsInvalidInstance()
end

local function WaitForService(serviceName: string): any
  local service; repeat service = game:GetService(serviceName); task.wait(1 / 15) until service
  return service
end

local Workspace = WaitForService("Workspace")

local Animators: { [number]: Animator } = {}
local FoundAnimations: { [string]: boolean } = {}


local function GetTracks(animator: Animator)
  local ok, tracks = pcall(function()
    return animator:GetActiveAnimationTracks()
  end)

  if not ok then
    warn("Failed to get active animation tracks: " .. tostring(tracks))
    return nil
  end

  return tracks
end

task.spawn(function()
  while true do
    task.wait(1)

    for _, animator in Workspace:GetDescendants() do
      if not IsValid(animator) then continue end
      if not animator:IsA("Animator") then continue end
      if Animators[animator.Address] then continue end

      Animators[animator.Address] = animator
    end

    for address, animator in Animators do
      if not IsValid(animator) then
        Animators[address] = nil
      end
    end
  end
end)

task.spawn(function()
  while true do
    task.wait(1/15)

    for _, animator in Animators do
      if not IsValid(animator) then continue end

      local tracks = GetTracks(animator); if not tracks then continue end

      for _, track in tracks do
        if not IsValid(track) then continue end

        local ok, animation = pcall(function()
          return track.Animation
        end)

        if not ok then
          warn("Failed to read animation: " .. tostring(animation))
          continue
        end

        if not IsValid(animation) then
          continue
        end

        local animationId = animation.AnimationId
        if not animationId then continue end

        if not FoundAnimations[animationId] then
          FoundAnimations[animationId] = true
          print("Found a new animation: " .. tostring(animationId))
        end
      end
    end
  end
end)
