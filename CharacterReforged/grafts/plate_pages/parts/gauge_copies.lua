-- Player page block (plate_pages.lua): the gauge copies' placement bookkeeping
  -- ---- the gauge copies never drawn raw (2026-10-14, owner: a whole «ENERGÍA» gauge with its empty bar across
  -- Plantilla / Formación, Inazuma Fantasy off) -------------------------------------------------------------------
  -- Every btl06_13 stamina gauge copy of the page (evt_pp_tag, _ptile, _ptrule, _sxbar, _sxplate, _csband, _fbadge)
  -- is the retail gauge («ENERGÍA» title, empty bar) until this block hides its gauge parts and gives it its sprite,
  -- size and place (its G.ready flag; the empty special passive's box: G.emptyOn). An instance open but not set up
  -- (opened by a piece that stopped before placing it, or opened / reopened by the engine) is kept hidden every frame;
  -- a (re)opened instance is set up again by its piece (G.ForgetGaugeCopy from OnOpenLayer).
  function G.GaugeCopyCount(layer)
    if G.gaugeCopyCounts == nil then
      G.gaugeCopyCounts = {[G.TAG] = 1, [G.PT] = 5, [G.PTRULE] = 1, [G.SXBAR] = 1, [G.SXPLATE] = 1, [G.CSB] = 2,
        [G.FBADGE] = 3}
    end
    return G.gaugeCopyCounts[layer]
  end
  function G.IsGaugeCopyPlaced(layer, instance)
    if layer == G.PT and instance == 0 and G.emptyOn then
      return true
    end
    return G.ready[layer * 16 + instance] == true
  end
  function G.HideUnplacedGaugeCopies()
    G.GaugeCopyCount(G.TAG)
    for layer, count in pairs(G.gaugeCopyCounts) do
      if Exists(layer) then
        for instance = 0, count - 1 do
          if not G.IsGaugeCopyPlaced(layer, instance) and Cmd(C.IS_OPEN, layer, instance) == true then
            Cmd(C.VIS, layer, instance, false)
          end
        end
      end
    end
  end
  function G.ForgetGaugeCopy(layer, instance)
    if type(instance) ~= "number" or G.GaugeCopyCount(layer) == nil then
      return
    end
    G.ready[layer * 16 + instance] = false
    if layer == G.PT and instance == 0 then
      G.emptyOn = false
    elseif layer == G.FBADGE then
      G.fbKey = nil
    end
    Cmd(C.VIS, layer, instance, false)
  end
