-- New Recruitment: the Chronicle board's «Quitar aparición de ÍDOLOS ya obtenidos» toggle is gone (owner request
-- 2026-10-16): with this mod no player drops in a match, so hiding the owned ones means nothing. The retail command
-- list (vs_route_town_command_select_menu) shows that entry in its bottom guide («Tab» + a check box) only on the rows
-- whose heroDropControlEnabled is true, and its key (OnFunction 692387310) works only while IsHeroDropControlActived()
-- says yes. While NewRecruitment.Applies() holds (not in a mode's reserved slot):
--   * SetupButtonGuide gets a copy of the row with heroDropControlEnabled = false: the entry is not added and the
--     guide's key is switched off;
--   * IsHeroDropControlActived answers false: the key does nothing.
-- Without this mod, or in a reserved slot, the toggle stays as the game has it.
-- Handlers of the framework's board host (VRFW_Host); nothing runs at load but their registration.
if VRFW_Host ~= nil and type(NewRecruitment) == "table" then
  local function applies()
    local ok, yes = pcall(NewRecruitment.Applies)
    return ok and yes == true
  end

  VRFW_Host.on("vs_route_town_command_select_menu", "IsHeroDropControlActived", {
    id = "new_recruitment.idol_toggle_key", phase = "around",
    fn = function(nxt, ...)
      if applies() then
        return false
      end
      return nxt(...)
    end,
  })

  VRFW_Host.on("vs_route_town_command_select_menu", "SetupButtonGuide", {
    id = "new_recruitment.idol_toggle_guide", phase = "around",
    fn = function(nxt, row, ...)
      if type(row) == "table" and row.heroDropControlEnabled and applies() then
        local copy = {}
        for key, value in pairs(row) do
          copy[key] = value
        end
        copy.heroDropControlEnabled = false
        return nxt(copy, ...)
      end
      return nxt(row, ...)
    end,
  })
end
