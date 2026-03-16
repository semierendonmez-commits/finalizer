-- finalizer
-- v2.0.0 @semi
--
-- master bus processor mod
-- EQ + compressor + limiter + width
-- params menu integrated

local mod = require 'core/mods'

local state = {
  active = false,
  node_id = nil,
}

-- SynthDef source (sent to sclang at boot)
local SYNTHDEF_CODE = [[
SynthDef(\finalizer, {
  arg in_bus=0, out_bus=0,
      eq_lo_freq=80, eq_lo_gain=0, eq_lo_q=0.7,
      eq_mid_freq=2000, eq_mid_gain=0, eq_mid_q=1.0,
      eq_hi_freq=8000, eq_hi_gain=0, eq_hi_q=0.7,
      eq_on=1,
      comp_thresh=0.25, comp_ratio=0.25,
      comp_attack=0.01, comp_release=0.1,
      comp_makeup=1.0, comp_on=1,
      lim_level=0.95, lim_on=1,
      width=1.0, amp=1.0, bypass=0;
  var sig, dry, eq_sig, comp_sig, lim_sig;
  var sig_l, sig_r, mid, side;
  sig = In.ar(in_bus, 2);
  dry = sig;
  eq_sig = BPeakEQ.ar(sig,
    eq_lo_freq.clip(20,500), eq_lo_q.clip(0.1,10), eq_lo_gain.clip(-18,18));
  eq_sig = BPeakEQ.ar(eq_sig,
    eq_mid_freq.clip(100,8000), eq_mid_q.clip(0.1,10), eq_mid_gain.clip(-18,18));
  eq_sig = BPeakEQ.ar(eq_sig,
    eq_hi_freq.clip(1000,20000), eq_hi_q.clip(0.1,10), eq_hi_gain.clip(-18,18));
  sig = Select.ar(eq_on, [sig, eq_sig]);
  comp_sig = Compander.ar(sig, sig,
    thresh: comp_thresh.clip(0.001, 1.0),
    slopeAbove: comp_ratio.clip(0.05, 1.0),
    slopeBelow: 1.0,
    clampTime: comp_attack.clip(0.001, 0.5),
    relaxTime: comp_release.clip(0.01, 2.0));
  comp_sig = comp_sig * comp_makeup.clip(0.1, 10.0);
  sig = Select.ar(comp_on, [sig, comp_sig]);
  sig_l = sig[0]; sig_r = sig[1];
  mid = (sig_l + sig_r) * 0.5;
  side = (sig_l - sig_r) * 0.5 * width;
  sig = [mid + side, mid - side];
  lim_sig = Limiter.ar(sig, lim_level.clip(0.1, 1.0), 0.01);
  sig = Select.ar(lim_on, [sig, lim_sig]);
  sig = sig * amp;
  sig = Select.ar(bypass, [sig, dry]);
  ReplaceOut.ar(out_bus, sig);
}).add;
]]

-- send SC code
local function sc(code)
  if norns.sclang and norns.sclang.run then
    norns.sclang.run(code)
  elseif _norns and _norns.sclang then
    _norns.sclang(code)
  end
end

-- start the finalizer synth
local function start()
  if state.active then return end
  -- create synth after the default group (runs after all engines)
  sc("~finalizer = Synth(\\finalizer, [\\in_bus, 0, \\out_bus, 0], Server.default.defaultGroup, \\addAfter);")
  state.active = true
  print("finalizer: active")
end

-- stop
local function stop()
  if not state.active then return end
  sc("if(~finalizer.notNil, { ~finalizer.free; ~finalizer = nil; });")
  state.active = false
  print("finalizer: stopped")
end

-- set a parameter
local function set_param(key, val)
  if state.active then
    sc(string.format("if(~finalizer.notNil, { ~finalizer.set(\\%s, %s); });", key, val))
  end
end

-- convert dB threshold to linear for Compander
local function db_to_amp(db)
  return math.pow(10, db / 20)
end

-- ============ PARAMS ============

local function add_params()
  params:add_separator("FINALIZER")

  params:add_option("fnl_bypass", "bypass", {"OFF", "ON"}, 1)
  params:set_action("fnl_bypass", function(v) set_param("bypass", v - 1) end)

  -- compressor
  params:add_separator("fnl_comp_sep", "compressor")

  params:add_option("fnl_comp_on", "comp on", {"OFF", "ON"}, 2)
  params:set_action("fnl_comp_on", function(v) set_param("comp_on", v - 1) end)

  params:add_control("fnl_thresh", "threshold",
    controlspec.new(-48, 0, "lin", 0.5, -12, "dB"))
  params:set_action("fnl_thresh", function(v) set_param("comp_thresh", db_to_amp(v)) end)

  params:add_control("fnl_ratio", "ratio",
    controlspec.new(1, 20, "lin", 0.5, 4))
  params:set_action("fnl_ratio", function(v) set_param("comp_ratio", 1 / v) end)

  params:add_control("fnl_attack", "attack",
    controlspec.new(1, 500, "exp", 1, 10, "ms"))
  params:set_action("fnl_attack", function(v) set_param("comp_attack", v / 1000) end)

  params:add_control("fnl_release", "release",
    controlspec.new(10, 2000, "exp", 1, 100, "ms"))
  params:set_action("fnl_release", function(v) set_param("comp_release", v / 1000) end)

  params:add_control("fnl_makeup", "makeup gain",
    controlspec.new(0, 24, "lin", 0.5, 0, "dB"))
  params:set_action("fnl_makeup", function(v) set_param("comp_makeup", db_to_amp(v)) end)

  -- eq
  params:add_separator("fnl_eq_sep", "equalizer")

  params:add_option("fnl_eq_on", "eq on", {"OFF", "ON"}, 2)
  params:set_action("fnl_eq_on", function(v) set_param("eq_on", v - 1) end)

  params:add_control("fnl_lo_freq", "lo freq",
    controlspec.new(20, 500, "exp", 1, 80, "Hz"))
  params:set_action("fnl_lo_freq", function(v) set_param("eq_lo_freq", v) end)

  params:add_control("fnl_lo_gain", "lo gain",
    controlspec.new(-18, 18, "lin", 0.5, 0, "dB"))
  params:set_action("fnl_lo_gain", function(v) set_param("eq_lo_gain", v) end)

  params:add_control("fnl_mid_freq", "mid freq",
    controlspec.new(100, 8000, "exp", 1, 2000, "Hz"))
  params:set_action("fnl_mid_freq", function(v) set_param("eq_mid_freq", v) end)

  params:add_control("fnl_mid_gain", "mid gain",
    controlspec.new(-18, 18, "lin", 0.5, 0, "dB"))
  params:set_action("fnl_mid_gain", function(v) set_param("eq_mid_gain", v) end)

  params:add_control("fnl_hi_freq", "hi freq",
    controlspec.new(1000, 20000, "exp", 1, 8000, "Hz"))
  params:set_action("fnl_hi_freq", function(v) set_param("eq_hi_freq", v) end)

  params:add_control("fnl_hi_gain", "hi gain",
    controlspec.new(-18, 18, "lin", 0.5, 0, "dB"))
  params:set_action("fnl_hi_gain", function(v) set_param("eq_hi_gain", v) end)

  -- master
  params:add_separator("fnl_master_sep", "master")

  params:add_option("fnl_lim_on", "limiter on", {"OFF", "ON"}, 2)
  params:set_action("fnl_lim_on", function(v) set_param("lim_on", v - 1) end)

  params:add_control("fnl_ceiling", "ceiling",
    controlspec.new(-12, 0, "lin", 0.1, -0.5, "dB"))
  params:set_action("fnl_ceiling", function(v) set_param("lim_level", db_to_amp(v)) end)

  params:add_control("fnl_width", "stereo width",
    controlspec.new(0, 200, "lin", 1, 100, "%"))
  params:set_action("fnl_width", function(v) set_param("width", v / 100) end)

  params:add_control("fnl_amp", "output level",
    controlspec.new(-24, 6, "lin", 0.1, 0, "dB"))
  params:set_action("fnl_amp", function(v) set_param("amp", db_to_amp(v)) end)
end

-- ============ HOOKS ============

-- compile SynthDef at system startup
mod.hook.register("system_post_startup", "finalizer", function()
  -- small delay to ensure SC is ready
  clock.run(function()
    clock.sleep(3)
    sc(SYNTHDEF_CODE)
    print("finalizer: SynthDef compiled")
  end)
end)

-- add params and start after each script loads
mod.hook.register("script_post_init", "finalizer", function()
  add_params()
  -- delay to ensure engine is allocated
  clock.run(function()
    clock.sleep(0.5)
    start()
    -- apply current param values
    clock.sleep(0.2)
    params:bang()
  end)
end)

-- stop when script changes
mod.hook.register("script_post_cleanup", "finalizer", function()
  stop()
end)

-- ============ MOD MENU ============

local m = {}
local menu_items = {"bypass", "comp", "thresh", "ratio", "attack", "release",
                    "makeup", "eq", "lo gain", "mid gain", "hi gain",
                    "limiter", "ceiling", "width", "output"}
local menu_sel = 1

m.key = function(n, z)
  if n == 2 and z == 1 then
    mod.menu.exit()
  elseif n == 3 and z == 1 then
    -- toggle active
    if state.active then stop() else start() end
    mod.menu.redraw()
  end
end

m.enc = function(n, d)
  if n == 2 then
    menu_sel = util.clamp(menu_sel + d, 1, #menu_items)
  elseif n == 3 then
    local pid_map = {
      "fnl_bypass", "fnl_comp_on", "fnl_thresh", "fnl_ratio",
      "fnl_attack", "fnl_release", "fnl_makeup", "fnl_eq_on",
      "fnl_lo_gain", "fnl_mid_gain", "fnl_hi_gain",
      "fnl_lim_on", "fnl_ceiling", "fnl_width", "fnl_amp"
    }
    local pid = pid_map[menu_sel]
    if pid then pcall(function() params:delta(pid, d) end) end
  end
  mod.menu.redraw()
end

m.redraw = function()
  screen.clear()
  screen.font_face(1); screen.font_size(8)
  screen.level(10)
  screen.move(1, 7)
  screen.text("FINALIZER")
  screen.level(state.active and 12 or 3)
  screen.move(128, 7); screen.text_right(state.active and "ON" or "OFF")

  local start_i = math.max(1, menu_sel - 3)
  for i = start_i, math.min(#menu_items, start_i + 5) do
    local y = 14 + (i - start_i) * 8
    screen.level(i == menu_sel and 15 or 4)
    screen.move(4, y)
    screen.text(menu_items[i])
  end
  screen.level(2)
  screen.move(1, 63); screen.text("E2:sel E3:adj K3:on/off")
  screen.update()
end

m.init = function() end
m.deinit = function() end
mod.menu.register(mod.this_name, m)
