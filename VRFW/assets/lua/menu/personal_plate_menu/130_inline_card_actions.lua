-- menu_engine: INLINE CARD ACTIONS, the player plate's part (VRFW_TeamEditor.Run with spec.inline_card_actions; the
-- dock's part: soccer_team_dock_menu\137_inline_card_actions.lua, docs/framework/team-editor.md). Definitions only; no
-- engine call at load.
--
-- While the dock's hidden lineup screen runs a card's popup (card action POPUP), the plate it opens is hidden too
-- (the retail full-screen hide of a menu), at its OnInit and once more when its first layer opens. With the card
-- action PAGE the plate stays: it is the player page.
if VRFW_Host ~= nil then
  local STEM = "personal_plate_menu"
  local K = {
    PLATE = 1427722143,              -- personal_plate_menu
    MENU_HIDE = 1670867360,          -- (1, menu): the whole menu not drawn
    LOG = VRFW_Cmd.EVT_LOG,          -- CMND_EVT_LOG
  }
  local S = { hides = 0 }

  local function popup()
    local E = VRFW_TeamEditor
    if type(E) ~= "table" or type(E.CardAction) ~= "function" then
      return false
    end
    return E.CardAction() == E.CARD_ACTION.POPUP
  end

  VRFW_Host.on(STEM, "OnInit", {
    id = "menu_engine.team_editor_card_actions", phase = "after",
    fn = function()
      S.hides = 0
      if popup() then
        pcall(funcLuaMenuCommand, K.MENU_HIDE, 1, K.PLATE)
        S.hides = 1
        pcall(funcLuaCommand, K.LOG, "VRFW team editor", "plate: hidden under the card's popup")
      end
    end,
  })

  VRFW_Host.on(STEM, "OnOpenLayer", {
    id = "menu_engine.team_editor_card_actions", phase = "before",
    fn = function()
      if S.hides == 1 and popup() then
        pcall(funcLuaMenuCommand, K.MENU_HIDE, 1, K.PLATE)
        S.hides = 2
      end
    end,
  })
end
