-- EVT INAROGUE slot 4 on the title (docs/game/modes/inarogue-own-scene-plan.md). INAROGUE is entered only from the
-- slot screen: loading its slot (4) opens evt_inarogue_menu as the root of its own menu scene ([[VRFW.SaveSlot]]
-- root_menu). A title in slot 4 (the first entry of a new INAROGUE game, back from a match or the team dock) is black
-- and inactive while the framework resets straight into the menu (graft save_slots, VRFW_Slots.forward); this file
-- only keeps the base game out of that title: none of its layers shows and none of its own popups opens there.
local EVT_IR = {
  ROGUE = @crc:CMND_EVT_SLOT_ROGUE@,        -- () -> rogueSlot, active, returnSlot, rogueHasGame
  LOG = @crc:CMND_EVT_LOG@,
  LAYER_VISIBLE = @crc:CMND_SET_LAYER_VISIBLE@,
}

function EVT_IR_Call(cmd, ...) -- EVT INAROGUE
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

function EVT_IR_Log(...) -- EVT INAROGUE
  EVT_IR_Call(EVT_IR.LOG, "inarogue slot", ...)
end

-- slot 4 is the loaded game: asked once per title instance (OnInit clears the answer)
EVT_IR.in_rogue = nil -- EVT INAROGUE
function EVT_IR_InRogueSlot() -- EVT INAROGUE
  if EVT_IR.in_rogue == nil then
    local rs, act = EVT_IR_Call(EVT_IR.ROGUE)
    EVT_IR.in_rogue = type(rs) == "number" and act == rs
  end
  return EVT_IR.in_rogue
end

function EVT_IR_SlotChanged() -- EVT INAROGUE
  EVT_IR.in_rogue = nil
end

-- every layer of the title stays hidden in slot 4 (OnOpenLayer hides each one as it opens)
function EVT_IR_HideLayer(layer) -- EVT INAROGUE
  local n = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, layer) or 0
  for i = 0, math.max(n, 1) - 1 do
    funcLuaMenuCommand(EVT_IR.LAYER_VISIBLE, layer, i, false)
  end
end

-- a base-game popup the title opens by itself (notices, tutorial pages, network invites) never runs in slot 4
function EVT_IR_BlockInRogueSlot(name) -- EVT INAROGUE
  local orig = _ENV[name]
  if type(orig) ~= "function" then
    return
  end
  _ENV[name] = function(...)
    if EVT_IR_InRogueSlot() then
      return
    end
    return orig(...)
  end
end
