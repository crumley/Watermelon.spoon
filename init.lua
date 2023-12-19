--- === Hammerdora ===
---
---

local logger = require("hs.logger")
local timer = require("hs.timer")
local menubar = require("hs.menubar")
local settings = require("hs.settings")

local m = {}
m.__index = m

-- Metadata
m.name = "Watermelon"
m.version = "0.1"
m.author = "crumley@gmail.com"
m.license = "MIT"
m.homepage = "https://github.com/Hammerspoon/Spoons"

-- Settings

m.logFilePath = nil
m.settingsKey = m.name .. ".pomoState"

-- set this to true to always show the menubar item
m.alwaysShowMenuBar = true
m.desktopDisplay = true

-- Font size for alert
m.alertTextSize = 80

m.logger = logger.new('Hammerdora', 'debug')
m.timer = nil
m.startTime = nil
m.pauseTime = nil
m.stopTime = nil
m.aggregatedState = {
  week = {
    date = 0,
    count = 0
  },
  day = {
    date = 0,
    count = 0
  }
}

function m:init()
  m.logger.d('init')
  m.menu = menubar.new(m.alwaysShowMenuBar)
  m.timer = timer.doEvery(hs.timer.seconds(10),
    function(t)
      m:_tick()
    end
  ):stop()

  m:_loadState()

  if m.desktopDisplay then
    local screen = hs.screen.primaryScreen()
    local res = screen:fullFrame()
    m.canvas = hs.canvas.new({
      x = res.w - 300,
      y = res.h - 18,
      w = 280,
      h = 18
    })
    m.canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    m.canvas:level(hs.canvas.windowLevels.desktopIcon)
    m.canvas[1] = {
      type = "rectangle",
      action = "fill",
      fillColor = { color = hs.drawing.color.black, alpha = 0.5 },
      roundedRectRadii = { xRadius = 5, yRadius = 5 },
    }
    m.canvas[2] = {
      id = "cal_title",
      type = "text",
      text = m:_desktopText(),
      textFont = "Courier",
      textSize = 16,
      textColor = hs.drawing.color.osx_green,
      textAlignment = "left",
    }
    m.canvas:show()

    -- Rollover count at end of day
    hs.timer.doAt("0:00","1d", function()
      m.logger.d('Rolling over day...')
      m:_saveState()
      m:_loadState()
      m.canvas[2] = m:_desktopText()
    end)

    -- m.screen_watcher = hs.screen.watcher.new(function()
    --   m.logger.d('screen changed')
    --   -- TODO update positioning of text
    -- end):start()
  end
end

function m:_saveState()
  settings.set(m.settingsKey .. ".aggregatedState.day", m.aggregatedState.day)
  settings.set(m.settingsKey .. ".aggregatedState.week", m.aggregatedState.week)
  settings.setDate(m.settingsKey .. ".startTime", m.startTime or 0)
  settings.setDate(m.settingsKey .. ".pauseTime", m.pauseTime or 0)
  settings.setDate(m.settingsKey .. ".stopTime", m.stopTime or 0)

  -- TODO DRY this up...
  if m.canvas ~= nil then
    m.canvas[2].text = m:_desktopText()
  end
end

function m:_loadState()
  local startTime = settings.get(m.settingsKey .. ".startTime") or 0
  local pauseTime = settings.get(m.settingsKey .. ".pauseTime") or 0
  local stopTime = settings.get(m.settingsKey .. ".stopTime") or 0

  m.startTime = startTime
  m.pauseTime = pauseTime
  m.stopTime = stopTime

  -- Ensure aggregatedState.day != week are not the same table in memory by loading seperately and creating a new table for aggregatedState
  m.aggregatedState = {
    day = settings.get(m.settingsKey .. ".aggregatedState.day") or m.aggregatedState.day,
    week = settings.get(m.settingsKey .. ".aggregatedState.week") or m.aggregatedState.week,
  }

  m.logger.i('_loadState 1', hs.inspect(m.aggregatedState))

  -- See if what is stored should be rolled over...
  local date = os.date("%x")
  if date ~= m.aggregatedState.day.date then
    m.aggregatedState.day.date = date
    m.aggregatedState.day.count = 0
  end

  local weekStart = os.date("%x", m:_getWeekStart())
  if weekStart ~= m.aggregatedState.week.date then
    m.aggregatedState.week.date = weekStart
    m.aggregatedState.week.count = 0
  end

  if os.time() >= stopTime then
    -- or should this be complete?
    self:reset()
    return
  end

  if pauseTime ~= 0 and os.time() >= pauseTime then
    self:pause(pauseTime)
    return
  end

  if os.time() >= startTime then
    self:start(nil, nil, startTime)
    return
  end

  self:reset()
end

function m:isPaused()
  return m.pauseTime ~= 0
end

function m:isIdle()
  return m.startTime == 0
end

function m:start(onStart, onStop, startTime)
  if onStart ~= nil then
    m.onStart = onStart
    m.onStart()
  end

  if onStop ~= nil then
    m.onStart = onStop
  end

  -- TODO when unpausing should we add the paused time to stopTime?

  m.logger.i('start/resume')
  m.startTime = startTime and startTime or os.time()
  m.stopTime = m.startTime + (25 * 60)
  m.pauseTime = 0
  m.timer:start()
  local items = {
    { title = "Pause", fn = function() self:pause() end },
    { title = "Abort", fn = function() self:reset() end }
  }
  m.menu:setMenu(items)

  m:_tick()
  m:_saveState()
end

function m:pause(pauseTime)
  m.logger.i('pause')

  m.pauseTime = pauseTime and pauseTime or os.time()

  local items = {
    { title = "Resume", fn = function() self:start() end },
    { title = "Abort",  fn = function() self:reset() end }
  }
  m.menu:setMenu(items)
  m.menu:setTitle("⏯️ 🍉")

  m:_saveState()
end

function m:reset()
  m.logger.i('reset')

  m.timer:stop()
  m.startTime = 0
  m.pauseTime = 0
  m.stopTime = 0

  if m.onStop ~= nil then
    m.onStop()
  end

  m.onStart = nil
  m.onStop = nil

  m:_saveState()

  local items = {
    { title = "Start", fn = function() self:start() end }
  }
  m.menu:setMenu(items)
  m.menu:setTitle("🍉")
end

function m:complete()
  m.logger.d('complete')

  m:_incrementWatermelon()
  m:_saveState()

  -- TODO log failure
  pcall(function() m:_writeLogEntry() end)

  hs.alert.show("🍉 Watermelon! 🍉", { textSize = m.alertTextSize }, m.alertDuration)
  hs.sound.getByName("Submarine"):play()
  hs.screen.setInvertedPolarity(true)
  hs.timer.doAfter(2, function()
    hs.sound.getByName("Submarine"):play()
    hs.screen.setInvertedPolarity(false)
  end)

  self:reset()
end

function m:toggle()
  m.logger.d('toggle')

  if m:isPaused() then
    m:start(m.onStart, m.onStop, m.startTime)
    return
  end

  if m:isIdle() then
    m:start()
    return
  end

  self:pause()
end

function m:_incrementWatermelon()
  local date = os.date("%x")
  m.logger.d('_incrementWatermelon', hs.inspect(m.aggregatedState), date)
  if date == m.aggregatedState.day.date then
    m.aggregatedState.day.count = m.aggregatedState.day.count + 1
  else
    m.aggregatedState.day.date = date
    m.aggregatedState.day.count = 1
  end

  local weekStart = os.date("%x", m:_getWeekStart())
  if weekStart == m.aggregatedState.week.date then
    m.aggregatedState.week.count = m.aggregatedState.week.count + 1
  else
    m.aggregatedState.week.date = weekStart
    m.aggregatedState.week.count = 1
  end
  m.logger.d('_incrementWatermelon done', hs.inspect(m.aggregatedState))
end

function m:_getWeekStart()
  local now = os.time()
  local nowTable = os.date("*t", now)
  local weekStart = now - ((nowTable.wday - 1) * 86400)
  return weekStart
end

function m:_desktopText()
  local timeLeft = m:_timeLeft()
  if timeLeft == nil then
    timeLeft = "Idle"
  end

  local melonBar = "🥚"
  if m.aggregatedState.day.count > 0 then 
    melonBar = string.rep("🍉", m.aggregatedState.day.count)
  end

  return string.format("Today: %s Week: %s (%s)",
    melonBar,
    m.aggregatedState.week.count > 0 and m.aggregatedState.week.count or "🥚",
    timeLeft
  )
end

function m:_timeLeft()
  if not m:isIdle() then
    local minutes = math.ceil((m.stopTime - os.time()) / 60)
    return string.format("%02dm", minutes)
  end

  return nil
end

function m:_tick()
  if not m:isPaused() then
    local minutes = math.ceil((m.stopTime - os.time()) / 60)
    local title = string.format("%02dm 🍉", minutes)
    m.menu:setTitle(title)

    if m.canvas ~= nil then
      m.canvas[2].text = m:_desktopText()
    end

    if os.time() >= m.stopTime then
      m:complete()
    end
  end
end

function m:_writeLogEntry()
  if m.logFilePath ~= nil then
    local f = io.open(m.logFilePath, "a")
    f:write(string.format("%s %s: \"Description\" #tag\n",
      os.date("!%Y-%m-%dT%T", m.startTime),
      os.date("!%Y-%m-%dT%T", m.stopTime)
    ))
    f:close()
  end
end

return m
