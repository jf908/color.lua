local c = require("../color")
local r = require("reactive")
local Button = require("button")
local Slider = require("slider")

local TEXT_COLOR = colors.white
local BACKGROUND_COLOR = colors.black
local PICKER_COLOR = colors.red
local GRADIENT_COLORS = {
  colors.magenta,
  colors.lightBlue,
  colors.yellow,
  colors.lime,
  colors.pink,
  colors.gray,
  colors.lightGray,
  colors.cyan,
  colors.purple,
  colors.blue,
  colors.brown,
  colors.green
}

local holding_shift = false
local holding_ctrl = false
local keep_running = true
local base = r.signal(c.Color:new(1, 0, 0, c.Srgb))

---@type Button[]
local buttons = {}
---@type Slider[]
local sliders = {}
---@class SliderMeta
---@field property ColorProperty
---@field index number
---@type SliderMeta[]
local slidersMeta = {}
local active_slider = r.signal(1)
local previous_slider = 1
local to_reposition = {}

local w, h = term.getSize()
local width = r.signal(w)
local height = r.signal(h)
local slider_window = window.create(term.current(), 4, 3, w - 3, h - 2)

---@param str string
---@param targetLength number
---@param char string|nil defaults to ' '
---@return string, boolean
local function padEnd(str, targetLength, char)
  local res = str .. string.rep(char or ' ', targetLength - #str)

  return res, res ~= str
end

---@class ColorPropertyConfig
---@field name string
---@field dp number
---@field multiplier number|nil
---@field step number|nil
---@field rotate boolean|nil
---@field min number|nil
---@field max number|nil
---@field gradient_1 fun(a: number, b: number, c: number): number, number, number
---@field gradient_2 fun(a: number, b: number, c: number): number, number, number

---@class ColorProperty
---@field inner fun(): Color
---@field colorSpace ColorSpace
---@field properties ColorPropertyConfig[]
---@field y number
---@field increment fun(i: number)
---@field decrement fun(i: number)
local ColorProperty = {}

---@param name string
---@param properties ColorPropertyConfig[]
---@param y number
---@param colorSpace table
function ColorProperty:new(name, properties, y, colorSpace, altName)
  local inner = r.computed(function()
    local converted = base():convert(colorSpace)
    converted:clip()
    return converted
  end)

  local slider_offset = #sliders

  local o = {
    inner = inner,
    colorSpace = colorSpace,
    properties = properties,
    y = y,
    increment = function(i)
      local value = inner()

      local mult = properties[i].multiplier or 1
      local step = properties[i].step or (1 / mult)

      if holding_shift then
        step = step * 10
      elseif holding_ctrl and properties[i].dp > 0 then
        step = step / 10
      end
      value[i] = value[i] + step

      if properties[i].rotate then
        local max = properties[i].max or 1
        value[i] = math.fmod(value[i] + max, max)
      else
        local min = properties[i].min or 0
        local max = properties[i].max or 1
        value[i] = math.min(math.max(value[i], min), max)
      end

      base(value:clone())
      active_slider(slider_offset + i)
    end,
    decrement = function(i)
      local value = inner()
      local mult = properties[i].multiplier or 1
      local step = properties[i].step or (1 / mult)
      if holding_shift then
        step = step * 10
      elseif holding_ctrl and properties[i].dp > 0 then
        step = step / 10
      end
      value[i] = value[i] - step

      if properties[i].rotate then
        local max = properties[i].max or 1
        value[i] = math.fmod(value[i] + max, max)
      else
        local min = properties[i].min or 0
        local max = properties[i].max or 1
        value[i] = math.min(math.max(value[i], min), max)
      end

      base(value:clone())
      active_slider(slider_offset + i)
    end,
    reposition = function()
      for i = 1, #to_reposition do
        to_reposition[i]()
      end
    end
  }

  slider_window.setTextColor(TEXT_COLOR)
  slider_window.setBackgroundColor(BACKGROUND_COLOR)

  slider_window.setCursorPos(1, y)
  slider_window.write("<" .. name .. ">")

  for i = 1, #properties do
    slider_window.setCursorPos(1, y + i)
    slider_window.write(properties[i].name)

    buttons[#buttons + 1] = Button:new(
      slider_window,
      "-",
      14,
      y + i,
      function()
        o.decrement(i)
      end
    )
    buttons[#buttons]:draw()

    local btn_index = #buttons + 1
    local btn_y = y + i
    buttons[btn_index] = Button:new(
      slider_window,
      "+",
      width() - 5,
      btn_y,
      function()
        o.increment(i)
      end
    )
    buttons[btn_index]:draw()
    to_reposition[#to_reposition + 1] = function()
      buttons[btn_index]:reposition(width() - 5, btn_y)
      buttons[btn_index]:draw()
    end

    local slider_index = #sliders + 1
    local slider_y = y + i
    sliders[slider_index] = Slider:new(
      slider_window,
      16,
      slider_y,
      function(frac)
        active_slider(slider_index)

        local value = inner()

        local min = properties[i].min or 0
        local max = properties[i].max or 1
        value[i] = min + (max - min) * frac

        base(value:clone())
      end,
      width() - 22,
      1
    )
    slidersMeta[slider_index] = {
      property = o,
      index = i,
    }

    to_reposition[#to_reposition + 1] = function()
      sliders[slider_index]:reposition(16, slider_y, width() - 22, 1)
    end
  end


  r.effect(function()
    slider_window.setTextColor(TEXT_COLOR)
    slider_window.setBackgroundColor(BACKGROUND_COLOR)

    local abc = inner()

    -- Draw values
    for i = 1, 3 do
      local mult = properties[i].multiplier or 1
      slider_window.setCursorPos(3, y + i)
      local formatted = string.format("%." .. properties[i].dp .. "f", abc[i] * mult)
      slider_window.write(padEnd(formatted, 7))
    end

    -- Draw alt name
    if altName then
      slider_window.setCursorPos(4 + #name, y)
      slider_window.write(padEnd(altName(abc), 7))
    end
  end)

  self.__index = self
  return setmetatable(o, self)
end

ColorProperty:new("RGB", {
  {
    name       = "R",
    multiplier = 255,
    dp         = 0,
    gradient_1 = function(_, _, _)
      return 0, 0, 0
    end,
    gradient_2 = function(_, _, _)
      return 1, 0, 0
    end
  },
  {
    name = "G",
    multiplier = 255,
    dp = 0,
    gradient_1 = function(_, _, _)
      return 0, 0, 0
    end,
    gradient_2 = function(_, _, _)
      return 0, 1, 0
    end
  },
  {
    name = "B",
    multiplier = 255,
    dp = 0,
    gradient_1 = function(_, _, _)
      return 0, 0, 0
    end,
    gradient_2 = function(_, _, _)
      return 0, 0, 1
    end
  }
}, 1, c.Srgb, function(rgb)
  return string.format("#%02X%02X%02X", rgb[1] * 255, rgb[2] * 255, rgb[3] * 255)
end)
ColorProperty:new("HSL", {
  {
    name = "H",
    rotate = true,
    max = 360,
    dp = 1,
    gradient_1 = function(_, _, _)
      return 0, 100, 50
    end,
    gradient_2 = function(_, _, _)
      return 360, 100, 50
    end
  },
  {
    name = "S",
    max = 100,
    dp = 1,
    gradient_1 = function(h, _, l)
      return h, 0, l
    end,
    gradient_2 = function(h, _, l)
      return h, 100, l
    end
  },
  {
    name = "L",
    max = 100,
    dp = 1,
    gradient_1 = function(h, s, _)
      return h, s, 0
    end,
    gradient_2 = function(h, s, _)
      return h, s, 100
    end
  }
}, 6, c.Hsl)
ColorProperty:new("OKLCH", {
  {
    name = "L",
    dp = 3,
    step = 0.01,
    gradient_1 = function(_, c, h)
      return 0, c, h
    end,
    gradient_2 = function(_, c, h)
      return 1, c, h
    end
  },
  {
    name = "C",
    max = 0.4,
    dp = 3,
    step = 0.01,
    gradient_1 = function(l, _, h)
      return l, 0, h
    end,
    gradient_2 = function(l, _, h)
      return l, 0.4, h
    end
  },
  {
    name = "H",
    rotate = true,
    max = 360,
    dp = 1,
    gradient_1 = function(l, c, _)
      return l, c, 0
    end,
    gradient_2 = function(l, c, _)
      return l, c, 360
    end
  }
}, 11, c.Oklch)

local exit_button = Button:new(
  term.current(),
  "X",
  width(),
  1,
  function()
    keep_running = false
  end
)
buttons[#buttons + 1] = exit_button
to_reposition[#to_reposition + 1] = function()
  exit_button:reposition(width(), exit_button.y)
  exit_button:draw()
end


-- Full redraw on resize
local function full_draw()
  term.setBackgroundColor(BACKGROUND_COLOR)
  term.clear()

  for i = 1, #to_reposition do
    to_reposition[i]()
  end

  slider_window.reposition(4, 3, width() - 3, height() - 2)
  slider_window.redraw()
end

-- Draw picked color around border
local function draw_color_border()
  term.setCursorPos(1, slider_window.getSize())

  local value = base()
  local rgb = value:convert(c.Srgb)
  rgb:clip()

  term.setPaletteColor(PICKER_COLOR, rgb[1], rgb[2], rgb[3])
  term.setBackgroundColor(PICKER_COLOR)
  term.setCursorPos(1, 1)
  term.write(string.rep(" ", width() - 1))

  term.setCursorPos(1, height())
  term.write(string.rep(" ", width()))

  for i = 2, height() - 1 do
    term.setCursorPos(1, i)
    term.write(" ")
    term.setCursorPos(width(), i)
    term.write(" ")
  end

  -- Debug
  -- term.setCursorPos(1, 1)
  -- term.write(value.space.name .. ":" .. value[1] .. ", " .. value[2] .. ", " .. value[3])
end

-- Set slider color palette
local function set_slider_palette()
  local meta = slidersMeta[active_slider()]

  -- Optimisation because gradient won't change while slider is active
  r.pauseTracking()
  local value = meta.property.inner()
  r.resumeTracking()

  local single_prop = meta.property.properties[meta.index]
  local g1x, g1y, g1z = single_prop.gradient_1(value[1], value[2], value[3])
  local g2x, g2y, g2z = single_prop.gradient_2(value[1], value[2], value[3])

  for i = 1, #GRADIENT_COLORS do
    local frac = (i - 1) / (#GRADIENT_COLORS - 1)
    local x = g1x + (g2x - g1x) * frac
    local y = g1y + (g2y - g1y) * frac
    local z = g1z + (g2z - g1z) * frac
    local col = c.Color:new(x, y, z, meta.property.colorSpace)
    local srgb = col:convert(c.Srgb)
    srgb:clip()
    term.setPaletteColor(GRADIENT_COLORS[i], srgb[1], srgb[2], srgb[3])
  end
end

local function draw_slider()
  set_slider_palette()

  -- Clear previous slider
  local slider = sliders[previous_slider]
  slider.window.setBackgroundColor(BACKGROUND_COLOR)
  slider.window.setCursorPos(slider.x, slider.y)
  slider.window.write(string.rep(" ", slider.width))

  -- Draw new slider
  slider = sliders[active_slider()]

  local splits = {}
  for i = 0, #GRADIENT_COLORS do
    splits[i + 1] = math.floor(slider.width * i / (#GRADIENT_COLORS))
  end

  for i = 1, #splits - 1 do
    slider.window.setBackgroundColor(GRADIENT_COLORS[i])
    slider.window.setCursorPos(slider.x + splits[i], slider.y)
    slider.window.write(string.rep(" ", splits[i + 1] - splits[i]))
  end

  previous_slider = active_slider()

  -- Border seems to glitch out without this
  r.pauseTracking()
  draw_color_border()
  r.resumeTracking()
end


r.effect(full_draw)
r.effect(draw_color_border)
r.effect(draw_slider)

while keep_running do
  local ev = { os.pullEvent() }

  if ev[1] == "mouse_click" and ev[2] == 1 then
    for i = 1, #buttons do
      local button = buttons[i]
      if button:mouseCheck(ev[3], ev[4]) then
        break
      end
    end

    for i = 1, #sliders do
      local slider = sliders[i]
      if slider:mouseCheck(ev[3], ev[4]) then
        active_slider(i)
        break
      end
    end
  end

  if ev[1] == "mouse_drag" and ev[2] == 1 then
    local slider = sliders[active_slider()]
    slider:mouseCheck(ev[3], ev[4])
  end

  if ev[1] == "key" then
    local key = keys.getName(ev[2])

    if key == "q" then
      keep_running = false
    elseif key == "leftShift" then
      holding_shift = true
    elseif key == "leftCtrl" then
      holding_ctrl = true
    elseif key == "up" then
      local index = active_slider()
      if index > 1 then
        active_slider(index - 1)
      end
    elseif key == "down" then
      local index = active_slider()
      if index < #sliders then
        active_slider(index + 1)
      end
    elseif key == "left" then
      local meta = slidersMeta[active_slider()]
      meta.property.decrement(meta.index)
    elseif key == "right" then
      local meta = slidersMeta[active_slider()]
      meta.property.increment(meta.index)
    end
  end

  if ev[1] == "key_up" then
    local key = keys.getName(ev[2])

    if key == "leftShift" then
      holding_shift = false
    elseif key == "leftCtrl" then
      holding_ctrl = false
    end
  end

  if ev[1] == "term_resize" then
    local w, h = term.getSize()
    width(w)
    height(h)
  end
end

-- Reset
for i = 1, #GRADIENT_COLORS do
  term.setPaletteColor(GRADIENT_COLORS[i], term.nativePaletteColor(GRADIENT_COLORS[i]))
end
term.setPaletteColor(PICKER_COLOR, term.nativePaletteColor(PICKER_COLOR))
term.setTextColor(colors.white)
term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()
