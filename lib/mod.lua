-- finalizer
-- v1.0.0 @semi
--
-- master bus processor mod
-- EQ + compressor + limiter
-- applied after every script

local mod = require 'core/mods'

local state = {
  enabled = true,
  page = 1,  -- 1=COMP, 2=EQ, 3=MASTER
  -- compressor
  comp_on = 1,
  comp_thresh = -12,
  comp_ratio = 4,
  comp_attack = 0.01,
  comp_release = 0.1,
  comp_makeup = 0,
  -- eq
  eq_on = 1,
  eq_lo_freq = 80, eq_lo_gain = 0, eq_lo_q = 0.7,
  eq_mid_freq = 2000, eq_mid_gain = 0, eq_mid_q = 1.0,
  eq_hi_freq = 8000, eq_hi_gain = 0, eq_hi_q = 0.7,
  -- master
  lim_on = 1,
  lim_level = 0.95,
  width = 1.0,
  amp = 1.0,
  bypass = 0,
  -- ui
  param_idx = 1,
}

-- parameter definitions per page
local PAGES = {
  { name = "COMP", params = {
    {key="comp_on", name="comp", min=0, max=1, step=1, fmt=function(v) return v==1 and "ON" or "OFF" end},
    {key="comp_thresh", name="thresh", min=-48, max=0, step=0.5, fmt=function(v) return string.format("%.1fdB", v) end},
    {key="comp_ratio", name="ratio", min=1, max=20, step=0.5, fmt=function(v) return string.format("%.1f:1", v) end},
    {key="comp_attack", name="attack", min=0.001, max=0.5, step=0.001, fmt=function(v) return string.format("%.0fms", v*1000) end},
    {key="comp_release", name="release", min=0.01, max=2.0, step=0.01, fmt=function(v) return string.format("%.0fms", v*1000) end},
    {key="comp_makeup", name="makeup", min=0, max=24, step=0.5, fmt=function(v) return string.format("+%.1fdB", v) end},
  }},
  { name = "EQ", params = {
    {key="eq_on", name="eq", min=0, max=1, step=1, fmt=function(v) return v==1 and "ON" or "OFF" end},
    {key="eq_lo_freq", name="lo freq", min=20, max=500, step=5, fmt=function(v) return string.format("%.0fHz", v) end},
    {key="eq_lo_gain", name="lo gain", min=-18, max=18, step=0.5, fmt=function(v) return string.format("%.1fdB", v) end},
    {key="eq_mid_freq", name="mid freq", min=100, max=8000, step=50, fmt=function(v) return string.format("%.0fHz", v) end},
    {key="eq_mid_gain", name="mid gain", min=-18, max=18, step=0.5, fmt=function(v) return string.format("%.1fdB", v) end},
    {key="eq_hi_freq", name="hi freq", min=1000, max=20000, step=100, fmt=function(v) return string.format("%.0fkHz", v/1000) end},
    {key="eq_hi_gain", name="hi gain", min=-18, max=18, step=0.5, fmt=function(v) return string.format("%.1fdB", v) end},
  }},
  { name = "MASTER", params = {
    {key="lim_on", name="limiter", min=0, max=1, step=1, fmt=function(v) return v==1 and "ON" or "OFF" end},
    {key="lim_level", name="ceiling", min=0.1, max=1.0, step=0.01, fmt=function(v) return string.format("%.1fdB", 20*math.log(v, 10)) end},
    {key="width", name="width", min=0, max=2.0, step=0.05, fmt=function(v) return string.format("%.0f%%", v*100) end},
    {key="amp", name="volume", min=0, max=2.0, step=0.01, fmt=function(v) return string.format("%.1fdB", 20*math.log(math.max(0.001,v), 10)) end},
    {key="bypass", name="bypass", min=0, max=1, step=1, fmt=function(v) return v==1 and "BYPASS" or "ACTIVE" end},
  }},
}

local function send_param(key, val)
  -- send to SC via OSC
  if _norns and _norns.send_osc then
    -- use the Finalizer class method
    -- actually we need to set synth params
    -- the SC Finalizer class stores the synth reference
    _norns.send_osc("/set_finalizer", key, val)
  end
end

local function send_all()
  for _, page in ipairs(PAGES) do
    for _, p in ipairs(page.params) do
      send_param(p.key, state[p.key])
    end
  end
end

-- SC communication: since we can't easily call class methods from Lua,
-- we use a different approach: send raw s_new and n_set OSC messages
local finalizer_node = nil

local function start_finalizer()
  -- create synth on the default group, after everything else
  -- node ID -1 = let server assign
  if not finalizer_node then
    -- we need to wait a moment for the engine to be ready
    clock.run(function()
      clock.sleep(1.0)
      -- use sclang eval to start the finalizer
      if _norns and _norns.sc_send then
        _norns.sc_send("Finalizer.start(Server.default.defaultGroup, \\addAfter)")
        finalizer_node = true
        -- send all current params
        clock.sleep(0.2)
        for _, page in ipairs(PAGES) do
          for _, p in ipairs(page.params) do
            local cmd = string.format("Finalizer.set(\\%s, %s)", p.key, state[p.key])
            _norns.sc_send(cmd)
          end
        end
        print("finalizer: chain active")
      end
    end)
  end
end

local function stop_finalizer()
  if finalizer_node then
    if _norns and _norns.sc_send then
      _norns.sc_send("Finalizer.stop")
    end
    finalizer_node = nil
  end
end

local function update_param(key, val)
  state[key] = val
  if finalizer_node and _norns and _norns.sc_send then
    _norns.sc_send(string.format("Finalizer.set(\\%s, %s)", key, val))
  end
end

-- hooks
mod.hook.register("script_post_init", "finalizer", function()
  if state.enabled then
    start_finalizer()
  end
end)

mod.hook.register("script_post_cleanup", "finalizer", function()
  stop_finalizer()
end)

-- mod menu
local m = {}

m.key = function(n, z)
  if n == 2 and z == 1 then
    mod.menu.exit()
  elseif n == 3 and z == 1 then
    -- toggle page
    state.page = (state.page % #PAGES) + 1
    state.param_idx = 1
    mod.menu.redraw()
  end
end

m.enc = function(n, d)
  local page = PAGES[state.page]
  if not page then return end

  if n == 2 then
    -- scroll params
    state.param_idx = util.clamp(state.param_idx + d, 1, #page.params)
  elseif n == 3 then
    -- adjust value
    local p = page.params[state.param_idx]
    if p then
      local v = state[p.key] + d * p.step
      v = util.clamp(v, p.min, p.max)
      update_param(p.key, v)
    end
  end
  mod.menu.redraw()
end

m.redraw = function()
  screen.clear()
  screen.font_face(1)
  screen.font_size(8)

  -- header
  screen.level(10)
  screen.move(1, 7)
  screen.text("FINALIZER")
  -- page tabs
  for i, pg in ipairs(PAGES) do
    screen.level(i == state.page and 15 or 3)
    screen.move(65 + (i-1) * 22, 7)
    screen.text(pg.name)
  end

  -- bypass indicator
  if state.bypass == 1 then
    screen.level(12)
    screen.move(128, 7)
    screen.text_right("BYP")
  end

  -- params list
  local page = PAGES[state.page]
  if page then
    for i, p in ipairs(page.params) do
      if i <= 6 then  -- max 6 visible
        local y = 14 + i * 8
        local is_sel = (i == state.param_idx)
        screen.level(is_sel and 15 or 4)
        screen.move(4, y)
        screen.text(p.name)
        screen.move(70, y)
        screen.text(p.fmt(state[p.key]))
        -- value bar
        if p.min ~= 0 or p.max ~= 1 then
          local norm = (state[p.key] - p.min) / (p.max - p.min)
          screen.level(is_sel and 6 or 2)
          screen.rect(95, y - 6, math.floor(norm * 30), 4)
          screen.fill()
        end
      end
    end
  end

  -- footer
  screen.level(2)
  screen.move(1, 63)
  screen.text("E2:sel E3:adj K3:page")
  screen.update()
end

m.init = function() end
m.deinit = function() end

mod.menu.register(mod.this_name, m)
