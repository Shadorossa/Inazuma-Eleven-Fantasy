-- menu_scene (VR-Framework): MENU PICK. Runs in every menu VM (lua\_all, after the retail chunk); no engine call at load.
-- A menu scene's menu_pick hotspot (docs/framework/menu-scene.md §2.2.3) sets the params vrfw_menu_scene_pick_layer
-- (a list layer) and vrfw_menu_scene_pick_index (its entry + 1) and presses its tile; the title then ends. The first
-- menu that holds that layer (CMND_GET_CREATE_LAYER_NUM > 0) takes the params, keeps the screen white (the title left in
-- white over the push-in) until its list holds the focus, moves the focus to the entry and runs its own OnDecideFocus
-- for it, as a press of A (a locked entry or a first-time question plays as in the game). The white is released once the
-- press has run a while (RELEASE_FRAMES), so the menu the entry opens appears instead of the list. Wraps this VM's Step.
-- With vrfw_menu_scene_pick_option (a hotspot's pick_option + 1) the entry's own choice is answered behind the white
-- while the press runs: its sub-window's selection (SUBWIN_SELECTED) gives the option and its yes / no confirmation
-- (CONFIRM_RESULT) yes, and its yes / no window is not opened at all (the hotspot's choice is the confirmation); the white
-- stays until the menu the press opens is up (e.g. the Battle Bay campaign: continue / new, then straight into the team
-- selection). With vrfw_menu_scene_pick_return (the hotspot's return = "title"), Back from the menu the press opened does
-- not show this menu again: its fade-in back is skipped and this menu's own BackToTitle runs (the retail Back of a top
-- menu), so the title comes back (on the mode the hotspot was on, CMND_VRFW_MENU_SCENE_COME_BACK).
if VRFW_MenuPick == nil then
  local P = {
    LOG = 3661580131,          -- CMND_EVT_LOG
    PARAM_HAS = 2947612279, PARAM_GET = 3522198769, PARAM_CLEAR = 3363400568,
    PICK_LAYER = 2283875177,   -- param vrfw_menu_scene_pick_layer
    PICK_INDEX = 3968429426,   -- param vrfw_menu_scene_pick_index (entry + 1)
    PICK_OPTION = 2481379900,   -- param vrfw_menu_scene_pick_option (option + 1)
    PICK_RETURN = 1862198659,   -- param vrfw_menu_scene_pick_return: Back from the opened menu goes to the title
    CONFIRM_OPEN = 2289627655,  -- (window, 0, 0): the yes / no window opened (its answer read with CONFIRM_RESULT)
    OPEN_MENU = 433545986,      -- CMND_OPEN_MENU_OBJECT (menu, …): the press opens the next menu
    MENU_EXISTS = 2231168902,   -- CMND_IS_EXIST_MENU_OBJECT (menu) (menu command)
    BRIGHT_FADE = 609722083,    -- (0 = in | 1 = out, seconds): the screen's fade (a top menu fades in again after a menu)
    SUBWIN_SELECTED = 1394177278, -- () -> the open sub-window's chosen row (-1 while none)
    CONFIRM_RESULT = 1523741473,  -- () -> the yes / no window's answer (0 yes; -1 while none), cancelled
    LAYER_NUM = 1175615627,    -- CMND_GET_CREATE_LAYER_NUM (layer)
    FOCUS_ACTIVE = 102308320,  -- (layer) -> the layer holds the control focus
    FOCUS_INDEX = 2603265800,  -- (layer) -> its focused instance
    FOCUS_MARK = 1778826357,   -- (layer, instance, true): the focus moves there
    WHITE_FADE = 4011714927,   -- (alpha, seconds): the full-screen white fade (the title's)
    READY_FRAMES = 15,         -- frames the list holds the focus before the press
    RELEASE_FRAMES = 20,       -- frames after the press before the white goes
    GIVE_UP_FRAMES = 600,
    ANSWER_FRAMES = 600,       -- the option's answers (and the white) at most this long, if the opened menu never comes up
  }
  local st = { layer = nil, row = nil, frames = 0, ready = 0, marked = false, co = nil, after = nil, option = -1,
    answering = false, real = nil, back_to_title = false, opened = nil, opened_up = 0, confirm_skipped = false,
    back_co = nil }
  VRFW_MenuPick = st

  local function Log(...)
    pcall(funcLuaCommand, P.LOG, "menu_scene", "menu_pick", ...)
  end
  local function F(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end
  local function M(...)
    local r = table.pack(pcall(funcLuaMenuCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end
  local function White(on)
    F(P.WHITE_FADE, on and 1 or 0, on and 0 or 0.3)
  end

  local function Take()
    if F(P.PARAM_HAS, P.PICK_LAYER) ~= true then return false end
    local layer = tonumber(F(P.PARAM_GET, P.PICK_LAYER)) or 0
    if layer < 0 then layer = layer + 4294967296 end
    local n = M(P.LAYER_NUM, layer)
    if type(n) ~= "number" or n <= 0 then return false end     -- not this menu
    local row = (tonumber(F(P.PARAM_GET, P.PICK_INDEX)) or 0) - 1
    st.option = -1
    if F(P.PARAM_HAS, P.PICK_OPTION) == true then st.option = (tonumber(F(P.PARAM_GET, P.PICK_OPTION)) or 0) - 1 end
    st.back_to_title = F(P.PARAM_HAS, P.PICK_RETURN) == true
    F(P.PARAM_CLEAR, P.PICK_LAYER)
    F(P.PARAM_CLEAR, P.PICK_INDEX)
    F(P.PARAM_CLEAR, P.PICK_OPTION)
    if st.back_to_title then F(P.PARAM_CLEAR, P.PICK_RETURN) end
    if row < 0 or row >= n then
      Log(string.format("layer 0x%08X: entry %d of %d: not picked", layer, row, n))
      return false
    end
    st.layer, st.row, st.frames, st.ready, st.marked = layer, row, 0, 0, false
    Log(string.format("layer 0x%08X entry %d asked by the menu scene", layer, row))
    return true
  end

  -- the press's view of this VM's funcLuaCommand, while it runs: the entry's own choice answered (pick_option: the
  -- sub-window's option, yes without its yes / no window), the menu it opens noted, and (return = "title") the fade-in
  -- back to this menu once that menu is gone skipped
  local function Wrap(on)
    if on and not st.real then
      local real = funcLuaCommand
      st.real = real
      funcLuaCommand = function(h, ...)
        if st.answering then
          if h == P.SUBWIN_SELECTED then return st.option end
          if h == P.CONFIRM_RESULT then return 0, false end
          if h == P.CONFIRM_OPEN and not st.confirm_skipped then
            st.confirm_skipped = true
            Log("the yes / no window skipped: the hotspot's choice is the confirmation")
            return true
          end
        end
        if h == P.OPEN_MENU and st.opened == nil then
          st.opened = ...
          Log(string.format("the press opens menu 0x%08X", (tonumber(st.opened) or 0) % 4294967296))
        end
        if h == P.BRIGHT_FADE and st.back_to_title and st.opened and (...) == 0 and M(P.MENU_EXISTS, st.opened) ~= true then
          Log("the fade back into this menu skipped: back to the title")
          return true
        end
        return real(h, ...)
      end
    elseif not on and st.real then
      funcLuaCommand = st.real
      st.real = nil
    end
  end

  local function Answer(on)
    if on and not st.answering then
      st.answering, st.answer_frames, st.confirm_skipped = true, 0, false
      Log("option", st.option, "answered for the entry's own choice")
    elseif not on and st.answering then
      st.answering = false
    end
  end

  local function PickStep()
    if st.co ~= nil then
      if coroutine.status(st.co) ~= "dead" then
        local ok, err = coroutine.resume(st.co)
        if not ok then Log("press error:", tostring(err)) st.co = nil end
      else
        st.co = nil
      end
      -- the option's answers (and the white) end once the menu the press opened is up a moment, or the press ended
      if st.answering then
        st.answer_frames = (st.answer_frames or 0) + 1
        if st.opened and M(P.MENU_EXISTS, st.opened) == true then st.opened_up = st.opened_up + 1 end
        if st.co == nil or st.opened_up >= P.RELEASE_FRAMES or st.answer_frames > P.ANSWER_FRAMES then
          Answer(false)
          st.after = st.opened_up >= P.RELEASE_FRAMES and P.RELEASE_FRAMES or 0   -- the opened menu already waited
          Log("the option's answers off:", st.co == nil and "the press ended" or (st.opened_up > 0 and "the opened menu is up" or "time"))
        end
      end
      if st.co == nil then
        Wrap(false)
        -- Back from the opened menu came here: this menu's own Back to the title (return = "title")
        if st.back_to_title and st.opened and M(P.MENU_EXISTS, st.opened) ~= true then
          st.back_to_title = false
          if type(BackToTitle) == "function" then
            st.back_co = coroutine.create(BackToTitle)
            Log("back from the opened menu: this menu's BackToTitle")
          else
            Log("back from the opened menu: this menu has no BackToTitle (left to the player)")
          end
        end
      end
    end
    if st.back_co ~= nil then
      if coroutine.status(st.back_co) ~= "dead" then
        local ok, err = coroutine.resume(st.back_co)
        if not ok then Log("BackToTitle error:", tostring(err)) st.back_co = nil end
      else
        st.back_co = nil
      end
    end
    if st.after ~= nil and not st.answering then
      st.after = st.after + 1
      if st.after >= P.RELEASE_FRAMES then
        st.after = nil
        White(false)
        Log("white released")
      end
    end
    if st.layer == nil and not Take() then return end
    if st.layer == nil then return end
    White(true)
    st.frames = st.frames + 1
    if st.frames > P.GIVE_UP_FRAMES then
      Log("entry", st.row, "not picked: the list never took the focus")
      st.layer = nil
      White(false)
      return
    end
    if M(P.FOCUS_ACTIVE, st.layer) ~= true then st.ready = 0 return end
    st.ready = st.ready + 1
    if st.ready < P.READY_FRAMES then return end
    if M(P.FOCUS_INDEX, st.layer) ~= st.row then
      if not st.marked then
        st.marked = true
        M(P.FOCUS_MARK, st.layer, st.row, true)
      end
      return
    end
    local layer, row = st.layer, st.row
    st.layer, st.after = nil, 0
    if type(OnDecideFocus) ~= "function" then
      Log("entry", row, "focused, no OnDecideFocus: left to the player")
      return
    end
    Log("entry", row, "pressed", st.option >= 0 and ("option " .. st.option) or "")
    st.opened, st.opened_up = nil, 0
    if st.option >= 0 or st.back_to_title then Wrap(true) end
    if st.option >= 0 then Answer(true) end
    st.co = coroutine.create(function() OnDecideFocus(layer, row) end)
    local ok, err = coroutine.resume(st.co)
    if not ok then Log("press error:", tostring(err)) st.co = nil end
  end

  if type(Step) == "function" then
    local step_before = Step
    Step = function(...)
      local r = table.pack(step_before(...))
      local ok, err = pcall(PickStep)
      if not ok then Log("error:", tostring(err)) end
      return table.unpack(r, 1, r.n)
    end
  end
end
