{ -- the pairing confirmation's parameter keys: the bank (bank_create_moves_hooks.lua) writes them, the general window
    -- (pair_confirm_window_hooks.lua) reads and clears them; character_reforged_pair_<name>
    N = 3845463003, BASE = 3138498002, PARTNER = 3239651284, MOVE = 2493211851,   -- _n / _base / _partner / _move
    KIND = 1080160106, MASK = 80384131, ICON = 4064933282,                          -- _kind / _mask / _icon_sprite
    PE_S = 2347582693, PE_G = 2436337816, PE_F = 3861946382,                        -- _pe_s / _pe_g / _pe_f
    -- _s0 .. _s8 (the base's stats), then _g0 .. _g8 (what the pair adds)
    S = {[0] = 441683322, 1834270188, 4099796054, 2203770048, 490621283, 1782151669, 4080019535, 2218203353, 344458568},
    G = {[0] = 889018927, 1140484793, 3673373443, 2918452117, 865115702, 1150791328, 3718184730, 2862206860, 975622685}}
