-- finalizer
-- v4.0.0 @semi
--
-- master bus processor mod
-- EQ + compressor + limiter + width
-- SynthDef in FinalizerDefs.sc (compiled at boot)
-- controlled via OSC to scsynth

local mod = require 'core/mods'

local FNL_NODE = 90909  -- fixed scsynth node ID
local SC_PORT = 57110   -- scsynth OSC port

local state = {
  active = false,
}

-- send OSC to scsynth
local function sc_osc(path, args)
  osc.send({"localhost", SC_PORT}, path, args)
end

-- create finalizer synth on main bus (addToTail of default group)
local function start()
  if state.active then return end
  -- s_new: defName, nodeID, addAction(1=addToTail), targetID(1=default group)
  sc_osc("/s_new", {"fnl_master", FNL_NODE, 1, 1})
  state.active = true
  print("finalizer: started (node " .. FNL_NODE .. ")")
end

-- free synth
local function stop()
  if not state.active then return end
  sc_osc("/n_free", {FNL_NODE})
  state.active = false
  print("finalizer: stopped")
end

-- set a single parameter
local function set_param(key, val)
  if state.active then
    sc_osc("/n_set", {FNL_NODE, key, val})
  end
end

local function db_to_amp(db)
  return math.pow(10, db / 20)
end

-- ============ PARAMS ============

local function add_params()
  params:add_separator("FINALIZER")

  params:add_option("fnl_bypass", "bypass", {"OFF", "ON"}, 1)
  params:set_action("fnl_bypass", function(v) set_param("bypass", v - 1) end)

  params:add_separator("fnl_comp", "compressor")
  params:add_option("fnl_comp_on", "comp", {"OFF", "ON"}, 2)
  params:set_action("fnl_comp_on", function(v) set_param("comp_on", v - 1) end)

  params:add_control("fnl_thresh", "threshold",
    controlspec.new(-48, 0, "lin", 0.5, -12, "dB"))
  params:set_action("fnl_thresh", function(v) set_param("thresh", db_to_amp(v)) end)

  params:add_control("fnl_ratio", "ratio",
    controlspec.new(1, 20, "lin", 0.5, 4))
  params:set_action("fnl_ratio", function(v) set_param("ratio", 1 / v) end)

  params:add_control("fnl_attack", "attack",
    controlspec.new(1, 500, "exp", 1, 10, "ms"))
  params:set_action("fnl_attack", function(v) set_param("atk", v / 1000) end)

  params:add_control("fnl_release", "release",
    controlspec.new(10, 2000, "exp", 1, 100, "ms"))
  params:set_action("fnl_release", function(v) set_param("rel", v / 1000) end)

  params:add_control("fnl_makeup", "makeup",
    controlspec.new(0, 24, "lin", 0.5, 0, "dB"))
  params:set_action("fnl_makeup", function(v) set_param("makeup", db_to_amp(v)) end)

  params:add_separator("fnl_eq", "equalizer")
  params:add_option("fnl_eq_on", "eq", {"OFF", "ON"}, 2)
  params:set_action("fnl_eq_on", function(v) set_param("eq_on", v - 1) end)

  params:add_control("fnl_lo_gain", "lo gain",
    controlspec.new(-18, 18, "lin", 0.5, 0, "dB"))
  params:set_action("fnl_lo_gain", function(v) set_param("lo_gain", v) end)

  params:add_control("fnl_lo_freq", "lo freq",
    controlspec.new(20, 500, "exp", 1, 80, "Hz"))
  params:set_action("fnl_lo_freq", function(v) set_param("lo_freq", v) end)

  params:add_control("fnl_mid_gain", "mid gain",
    controlspec.new(-18, 18, "lin", 0.5, 0, "dB"))
  params:set_action("fnl_mid_gain", function(v) set_param("mid_gain", v) end)

  params:add_control("fnl_mid_freq", "mid freq",
    controlspec.new(100, 8000, "exp", 1, 2000, "Hz"))
  params:set_action("fnl_mid_freq", function(v) set_param("mid_freq", v) end)

  params:add_control("fnl_hi_gain", "hi gain",
    controlspec.new(-18, 18, "lin", 0.5, 0, "dB"))
  params:set_action("fnl_hi_gain", function(v) set_param("hi_gain", v) end)

  params:add_control("fnl_hi_freq", "hi freq",
    controlspec.new(1000, 20000, "exp", 1, 8000, "Hz"))
  params:set_action("fnl_hi_freq", function(v) set_param("hi_freq", v) end)

  params:add_separator("fnl_master", "master output")
  params:add_option("fnl_lim_on", "limiter", {"OFF", "ON"}, 2)
  params:set_action("fnl_lim_on", function(v) set_param("lim_on", v - 1) end)

  params:add_control("fnl_ceiling", "ceiling",
    controlspec.new(-12, 0, "lin", 0.1, -0.5, "dB"))
  params:set_action("fnl_ceiling", function(v) set_param("ceiling", db_to_amp(v)) end)

  params:add_control("fnl_width", "width",
    controlspec.new(0, 200, "lin", 1, 100, "%"))
  params:set_action("fnl_width", function(v) set_param("width", v / 100) end)

  params:add_control("fnl_amp", "output",
    controlspec.new(-24, 6, "lin", 0.1, 0, "dB"))
  params:set_action("fnl_amp", function(v) set_param("amp", db_to_amp(v)) end)
end

-- ============ HOOKS ============

mod.hook.register("script_post_init", "finalizer", function()
  add_params()
  -- delay start to ensure engine synths are allocated first
  clock.run(function()
    clock.sleep(1.0)
    start()
    clock.sleep(0.3)
    pcall(function() params:bang() end)
  end)
end)

mod.hook.register("script_post_cleanup", "finalizer", function()
  stop()
end)

-- ============ MOD MENU ============

local m = {}

m.key = function(n, z)
  if n == 2 and z == 1 then mod.menu.exit()
  elseif n == 3 and z == 1 then
    if state.active then stop() else start() end
    mod.menu.redraw()
  end
end

m.enc = function(n, d) mod.menu.redraw() end

m.redraw = function()
  screen.clear()
  screen.font_face(1); screen.font_size(8)
  screen.level(10); screen.move(1, 7); screen.text("FINALIZER")
  screen.level(state.active and 15 or 3)
  screen.move(128, 7); screen.text_right(state.active and "ON" or "OFF")
  screen.level(4)
  screen.move(64, 28); screen.text_center("controls in params menu")
  screen.move(64, 38); screen.text_center("PARAMS > FINALIZER")
  screen.level(6)
  screen.move(64, 50)
  screen.text_center("OSC node: " .. FNL_NODE)
  screen.level(2); screen.move(1, 63); screen.text("K3: on/off")
  screen.update()
end

m.init = function() end
m.deinit = function() stop() end
mod.menu.register(mod.this_name, m)
