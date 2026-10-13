-- Build script of the type `telop` (docs/framework/build-scripts.md `telop`, docs/framework/types/telop.md): the
-- special-move name banners per technique and text language.
--
-- Two steps, one entry:
--   * input.step == "boot" (the telop type): the winner of each (language, telop) (lib/telop_resolve), the languages
--     «Rótulos personalizados» offers, and the plan of the outputs (lib/telop_plan: routes, menu objects, served
--     files). Pictures, layouts and the cache are native (VRFW.telop.*).
--   * input.step == "info" (the technique type, after its skill rows): the skill_telop_info_config rows of the telop
--     TOMLs' `margins` / `eldorado` / `info` (lib/telop_info), applied with the one row engine.
--
-- returns: boot = { picks, choices, plan, keep } (telop_engine::script::Scripted); info = { serve = { key } }.

local R = require "lib/telop_resolve"
local P = require "lib/telop_plan"
local I = require "lib/telop_info"

return function(input)
  if input.step == "info" then
    return I.build(input)
  end
  local picks = R.resolve(input.entries)
  local choices = R.choices(input, picks)
  local plan, keep = P.plan(input.entries, picks)
  return { picks = picks, choices = choices, plan = plan, keep = keep }
end
