-- ===== AuraPoints hyper gauge BEGIN =====
-- Aura Points (mod aura_points): match HUD layers hidden while its PE and its PEG or SP points are both on. Owner
-- 2026-10-16: the PEG / SP bar under the PE bar takes the role of the retail hyper gauge under the tension bar, both
-- teams. Which layers: the mod's command CMND_AURAPOINTS_HUD_HIDDEN_LAYERS (features\pe\content\game\stamina.toml)
-- answers true + the layer hashes of config.toml [hud_hidden_layers]; with the option «pe» off the command is not
-- registered (nothing answers), with «peg» and «sp» off it answers false: nothing is hidden. Only the drawing goes: the
-- gauge still fills, pays and gates moves as retail. Was the mod Stamina Points' graft stamina_points_hyper_gauge until
-- 2026-10-16.
-- Every instance of each layer is hidden after the retail gauge updates (PostStepSoccerMenu, every frame: the retail
-- update shows them again). Engine calls only inside the wrapped updates; every call goes through pcall.
AuraPoints_HyperGauge = AuraPoints_HyperGauge or {}
local G = AuraPoints_HyperGauge
G.MAX_ASKS = 600                       -- frames the command is asked without an answer, then the layers stay retail
G.asks = 0
G.answered = false                     -- the command answered once (the mod's parts cannot change in a session)
G.layers = {}                          -- the layer hashes to hide

local COMMAND_HIDDEN_LAYERS = @crc:CMND_AURAPOINTS_HUD_HIDDEN_LAYERS@
local CMND_SET_LAYER_VISIBLE = 711242136
local CMND_GET_CREATE_LAYER_NUM = 1175615627

local function MenuCommand(...)
  if type(funcLuaMenuCommand) ~= "function" then
    return nil
  end
  local result = table.pack(pcall(funcLuaMenuCommand, ...))
  if not result[1] then
    return nil
  end
  return table.unpack(result, 2, result.n)
end

-- asks the command until it answers (a busy script answers nothing for that frame)
local function AskHiddenLayers()
  if G.answered or G.asks >= G.MAX_ASKS or type(funcLuaCommand) ~= "function" then
    return
  end
  G.asks = G.asks + 1
  local result = table.pack(pcall(funcLuaCommand, COMMAND_HIDDEN_LAYERS))
  if not result[1] or result[2] == nil then
    return
  end
  G.answered = true
  if result[2] ~= true and result[2] ~= 1 then
    return
  end
  for i = 3, result.n do
    if type(result[i]) == "number" then
      G.layers[#G.layers + 1] = result[i]
    end
  end
end

function G.Step()
  AskHiddenLayers()
  for _, layer in ipairs(G.layers) do
    local count = MenuCommand(CMND_GET_CREATE_LAYER_NUM, layer)
    if type(count) ~= "number" or count < 1 then
      count = 2
    end
    for instance = 0, count - 1 do
      MenuCommand(CMND_SET_LAYER_VISIBLE, layer, instance, false)
    end
  end
end

local previousUpdateOwnGauge = UpdateHyperdimensionalPowerGauge
function UpdateHyperdimensionalPowerGauge(...)
  local result = {n = 0}
  if type(previousUpdateOwnGauge) == "function" then
    result = table.pack(previousUpdateOwnGauge(...))
  end
  pcall(G.Step)
  return table.unpack(result, 1, result.n)
end

local previousUpdateRivalGauge = UpdateEnemyHyperdimensionalPowerGauge
function UpdateEnemyHyperdimensionalPowerGauge(...)
  local result = {n = 0}
  if type(previousUpdateRivalGauge) == "function" then
    result = table.pack(previousUpdateRivalGauge(...))
  end
  pcall(G.Step)
  return table.unpack(result, 1, result.n)
end
-- ===== AuraPoints hyper gauge END =====
