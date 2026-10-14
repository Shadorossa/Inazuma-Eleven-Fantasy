-- skill_tabs (VR-Framework service S3, the Lua side): the «Habilidades» / «Técnicas» list's icons, titles and filters
-- follow the tab row the mods declare (content\skill_tabs\*.toml: a game tab hidden, a new tab with its own look).
-- docs/framework/card-types.md §3.3; the handlers are VRFW_SkillTabs.Attach (lua\_all\22_skill_tabs.lua) on this
-- script's host (000_host.lua). No engine call at load time.
if VRFW_SkillTabs ~= nil then
  VRFW_SkillTabs.Attach("ability_list_menu")
end
