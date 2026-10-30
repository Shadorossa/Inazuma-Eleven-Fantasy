-- InaRogue, the post-match rewards page (soccer_result_menu_item: OBJETOS and ESPÍRITUS): in the INAROGUE save, when
-- the match gave no item and no spirit (config.toml [drops] retail = false, content\items\no_retail_drops.toml), the
-- empty page is skipped: the game's own ToNextScene runs as soon as the page has opened, as its button would.
-- The counts are the game's SetupParam(list, n) answers (token list 3037531346, spirit list 1836544624). No engine call
-- at load time.
if VRFW_Host ~= nil then
  local STEM = "soccer_result_menu_item"
  local TOKEN_LIST, SPIRIT_LIST = 3037531346, 1836544624
  local OPEN_LAYER = 708596341           -- the page's root layer: its open end starts the reward effect
  local SLOT_ROGUE = VRFW_Cmd.EVT_SLOT_ROGUE          -- () -> rogueSlot, active slot
  local LOG = VRFW_Cmd.EVT_LOG
  local counts = {}

  local function rogue_save()
    local ok, rs, act = pcall(funcLuaCommand, SLOT_ROGUE)
    return ok and type(rs) == "number" and rs > 0 and rs == act
  end

  VRFW_Host.on(STEM, "SetupParam", {
    id = "inarogue.result_counts", phase = "around",
    fn = function(nxt, list, n, ...)
      counts[list] = n
      return nxt(list, n, ...)
    end,
  })

  VRFW_Host.on(STEM, "OnOpenEndLayer", {
    id = "inarogue.skip_empty_rewards", phase = "around",
    fn = function(nxt, layer, ...)
      if layer == OPEN_LAYER and (counts[TOKEN_LIST] or 0) == 0 and (counts[SPIRIT_LIST] or 0) == 0 and rogue_save()
          and type(ToNextScene) == "function" then
        pcall(funcLuaCommand, LOG, "inarogue", "result rewards page empty: skipped")
        counts = {}
        return ToNextScene()
      end
      return nxt(layer, ...)
    end,
  })
end
