-- Chronicle Deluxe: the free-match list («Competir contra bots», soccer_vs_cpu_list_menu) asks this mod to deal its
-- swapped teams (docs/game/mods/chronicle-deluxe-free-match.md §16) before it draws a line-up: before OnInit (the list
-- opens) and before OnChangeFocus of a row (mainmenu90_19_vs_cpu_list_item), CMND_ChronicleDeluxe_FreeMatchShuffle.
-- The script deals a team again only after a match ended, so every redraw of the list shows the line-up the next match
-- plays. Handlers of the VRFW host of this script; no engine call at load time.
if VRFW_Host ~= nil then
  local SHUFFLE = 4142888348        -- CMND_ChronicleDeluxe_FreeMatchShuffle
  local ITEM = 1074924810           -- mainmenu90_19_vs_cpu_list_item

  local function deal()
    pcall(funcLuaCommand, SHUFFLE)
  end

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnInit", {
    id = "ChronicleDeluxe.FreeMatchShuffle", phase = "before",
    fn = function()
      deal()
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnChangeFocus", {
    id = "ChronicleDeluxe.FreeMatchShuffle", phase = "before",
    fn = function(a1)
      if a1 == ITEM then
        deal()
      end
    end,
  })
end
