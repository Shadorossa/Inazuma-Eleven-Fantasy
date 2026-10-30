-- menu_engine: «Vínculo de Afinidad» (kizuna_menu) opened from the team dock of a foreign team (VRFW_TeamEditor with
-- spec.foreign, lua\_all\81_team_editor.lua, docs/framework/team-editor.md): it shows the dock's team (the throwaway
-- copy) and stays view only (VRFW_TeamEditor.ViewOnly): no Accept, no paste list (the photos and seals: 206718306),
-- no photo manager (330777687), and no guide entry but Back. No engine call at load time.
if type(VRFW_TeamEditor) == "table" and type(VRFW_TeamEditor.ViewOnly) == "function" then
  VRFW_TeamEditor.ViewOnly({
    stem = "kizuna_menu",
    functions = { [206718306] = true, [330777687] = true },
    guides = { "SetButtonGuide" },
  })
end
