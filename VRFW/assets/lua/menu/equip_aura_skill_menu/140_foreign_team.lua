-- menu_engine: «Comandos de hipertécnicas» (equip_aura_skill_menu) opened from the team dock of a foreign team
-- (VRFW_TeamEditor with spec.foreign, lua\_all\81_team_editor.lua, docs/framework/team-editor.md): it shows the dock's
-- team (the throwaway copy) and stays view only (VRFW_TeamEditor.ViewOnly): no Accept («Equipar»), and no guide entry
-- but Back; its function keys only page the detail window. No engine call at load time.
if type(VRFW_TeamEditor) == "table" and type(VRFW_TeamEditor.ViewOnly) == "function" then
  VRFW_TeamEditor.ViewOnly({
    stem = "equip_aura_skill_menu",
    guides = { "SetupButtonGuide" },
  })
end
