-- Build script of the `telop` type: special-move name banners per technique and text language.
-- input.step == "boot": picks the winner per (language, telop) (lib/telop_resolve), the offered languages, and the output plan (lib/telop_plan).
-- input.step == "info" (after the technique skill rows): applies the telop TOMLs' `margins` / `eldorado` / `info` to skill_telop_info_config (lib/telop_info).
-- returns: boot = { picks, choices, plan, keep }; info = { serve = { key } }.

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
