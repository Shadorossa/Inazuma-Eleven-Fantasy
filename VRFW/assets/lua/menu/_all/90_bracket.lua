-- VRFW_Bracket: the host side of the knockout bracket screen vrfw_bracket_menu (assets\lua\screens\
-- vrfw_bracket_menu.lua, its [[screen]] in content\menus\bracket.toml). Definitions only: no engine call at load.
-- The bracket screen is a draw-only child menu: it never takes a key. Its host keeps the keys, its header and its
-- background, and calls (the handshake is VRFW_ChildMenu, 89_child_menu.lua):
--   VRFW_Bracket.Show(page, opts)  the bracket shown (the child opened, or drawn again when it is up)
--       page  the view page the view command is asked for (-1 = the command's own first page)
--       opts  { host = crc32 of the host menu's name (the child closes when the host menu closes),
--               view = crc32 of the command that answers the view: page -> a view of kind "tree"
--                      (scripts\lib\competition.lua bracket_view; optional fmt, outcome, place, next,
--                      final_stadium = { map, id }),
--               animate = true: the round just played advances (crests walk, the retail strips grow),
--               top = the first screen row (px) the bracket may use (0 = the default layout),
--               lift = draw priority added to the retail art (a host whose background draws above it) }
--   VRFW_Bracket.Hide(why)   the child closed (another page, the host leaving)
--   VRFW_Bracket.Step()      every Step of the host: opens the child after an earlier one closed
--   VRFW_Bracket.Busy()      true while an advance is still to finish (the host's Enter skips it)
--   VRFW_Bracket.Skip()      the advance to its end at once
--   VRFW_Bracket.Shown()     true while the bracket is wanted on screen
if VRFW_Bracket == nil then
  local Bracket = {}

  local MENU = "vrfw_bracket_menu"
  local PARAM_PREFIX = "vrfw_bracket_"

  local S = { want = nil, opts = {} }

  local logger
  local function Log(...)
    logger = logger or VRFW_Log.New("VRFW.bracket")
    logger(...)
  end

  local function P(name)
    return VRFW_Crc32(PARAM_PREFIX .. name)
  end

  local function param_set(name, n)
    VRFW_Param.Replace(P(name), n)
  end

  -- what the child reads besides the page and the host: the view command, the layout, the advance
  local function send()
    local o = S.opts
    VRFW_Param.SetU32(PARAM_PREFIX .. "view", o.view or 0)
    param_set("top", math.floor(tonumber(o.top) or 0))
    param_set("lift", math.floor(tonumber(o.lift) or 0))
    if o.animate then
      param_set("busy", 1)
    end
  end

  -- the child menu's handshake (VRFW_ChildMenu, 89_child_menu.lua), made at the first call
  local child
  local function Child()
    child = child or VRFW_ChildMenu.Host(MENU, { prefix = PARAM_PREFIX, label = "bracket menu", send = send,
      log = function(...) Log("bracket menu:", ...) end })
    return child
  end

  function Bracket.Show(page, opts)
    S.want = page or -1
    S.opts = type(opts) == "table" and opts or {}
    VRFW_Param.Clear(P("skip"))
    if not S.opts.animate then
      VRFW_Param.Clear(P("busy"))
    end
    Child().Show(S.want, S.opts.host, S.opts.animate == true)
  end

  function Bracket.Hide(why)
    S.want = nil
    Child().Hide(why or "the host left the bracket")
    VRFW_Param.Clear(P("busy"))
  end

  function Bracket.Busy()
    if S.want == nil then
      return false
    end
    return VRFW_Param.Has(P("busy"))
  end

  function Bracket.Skip()
    VRFW_Param.Clear(P("busy"))
    param_set("skip", 1)
    Child().Call("VRFW_Bracket_Skip")
  end

  function Bracket.Shown()
    return S.want ~= nil
  end

  function Bracket.Step()
    Child().Step()
  end

  VRFW_Bracket = Bracket
end
