-- ===== EVT training ground hub BEGIN =====
-- Training Ground (graft.toml; docs/game/mods/training-ground.md), the Competición top menu (soccer_top_menu): the
-- title fallback of the top bar's «Free Mode» (content\menus\top_bar.toml, step `training_ground`), for a hub that
-- could not serve it in place (training_ground_start.lua): the drill starts here through TrainingGround_Launch.start
-- (the framework's match start service; black from the hub's first frame, the hub's init settles first).
-- Wrapper only (OnInit). Nothing at chunk load.
TrainingGround_Hub = TrainingGround_Hub or {}
do
  local H = TrainingGround_Hub
  H.SETTLE = 20 -- frames after the hub opened before the launch
  H.C = { LOG = 3661580131 }

  function H.log(...)
    pcall(funcLuaCommand, H.C.LOG, "EVT training_ground hub", ...)
  end

  local prev_init = OnInit
  if type(prev_init) == "function" then
    function OnInit(...)
      local r = table.pack(prev_init(...))
      pcall(function()
        if type(VRFW_TopBarStep) ~= "function" or not VRFW_TopBarStep("training_ground") then return end
        H.log("top bar step: training_ground (title fallback)")
        local S = TrainingGround_Launch
        if type(S) ~= "table" or type(S.start) ~= "function" or not S.start(H.SETTLE) then
          H.log("the drill could not start here")
        end
      end)
      return table.unpack(r, 1, r.n)
    end
  end
end
-- ===== EVT training ground hub END =====
