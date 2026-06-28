local GameId = game.GameId

local CoreGui = game:GetService("CoreGui")

local BasePath = "KittyScripts/decompiler/" .. GameId
local Path = BasePath
local Index = 0

while fs.is_directory(Path) do
  Path = BasePath .. "." .. Index
  Index += 1
end

warn("Outputing at: " .. Path)

if not fs.is_directory(Path) then
  fs.create_directory(Path)
end

local LocalScriptPath = Path .. "/LocalScripts"; if not fs.is_directory(LocalScriptPath) then fs.create_directory(LocalScriptPath) end
local ModuleScriptsPath = Path .. "/ModuleScripts"; if not fs.is_directory(ModuleScriptsPath) then fs.create_directory(ModuleScriptsPath) end
local Scripts = Path .. "/Scripts"; if not fs.is_directory(Scripts) then fs.create_directory(Scripts) end

local AlreadyFoundScripts: { [string]: boolean } = {}

local function GetType(script: Instance)
  if script:IsA("LocalScript") and script.BytecodeAvailable then
    return "local"
  elseif script:IsA("ModuleScript") and script.BytecodeAvailable then
    return "module"
  elseif script:IsA("Script") and script.BytecodeAvailable then
    return "script"
  end
  return nil
end


local function GetUniqueFilePath(folder, name)
  local path = string.format("%s/%s%s", folder, name, ".lua")
  local index = 0

  while fs.is_file(path) do

    path = string.format("%s/%s.%d%s", folder, name, index, ".lua")
    index += 1
  end

  return path
end

local function IsDescendantOf(instance: Instance, descendant: Instance)
  local CurrentInstance = instance

  while task.wait() do
    if CurrentInstance == descendant then return true end
    if CurrentInstance == game then return false end

    CurrentInstance = CurrentInstance.Parent
  end
  return false
end

local number = 0

for _, script in game:GetDescendants() do
  if not script or script:IsInvalidInstance() then continue end
  local Type = GetType(script); if not Type then continue end

  if IsDescendantOf(script, CoreGui) then continue end

  local Bytecode = script.Bytecode
  local Sha256 = crypt.hash(Bytecode, "sha256")

  if AlreadyFoundScripts[Sha256] then continue end; AlreadyFoundScripts[Sha256] = true

  local folder;

  if Type == "local" then
    folder = LocalScriptPath
  elseif Type == "module" then
    folder = ModuleScriptsPath
  else
    folder = Scripts
  end

  number += 1
  print(number)
  
  local ScriptPath = script:GetFullName(); if not ScriptPath then warn("wtf no path..?"); continue end
  local FilePath = GetUniqueFilePath(folder, script.Name)

  fs.create_file(FilePath)
  fs.write_async(FilePath, buffer.fromstring(" -- File path: " .. ScriptPath .. "\n" .. rbxcli.decompile(script, { DecompilationKind = "Luau" })))
end

print("Found this many LocalScripts, ModuleScripts, Scripts: " .. #fs.list_files(LocalScriptPath), #fs.list_files(ModuleScriptsPath), #fs.list_scripts(Scripts))
