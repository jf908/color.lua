local c = require("color")
local r = require("reactive")
local Button = require("button")

local TEXT_COLOR = colors.white
local BACKGROUND_COLOR = colors.black

local holding_shift = false
local keep_running = true
local base = r.signal({ 1, 1, 1 })
local buttons = {}

local function rpad(s, l, c)
  local res = s .. string.rep(c or ' ', l - #s)

  return res, res ~= s
end


---@class ColorPropertyConfig
---@field name string
---@field dp number
---@field multiplier number|nil
---@field step number|nil
---@field rotate boolean|nil
---@field min number|nil
---@field max number|nil

local ColorProperty = {}

---@param name string
---@param properties ColorPropertyConfig[]
---@param y number
---@param colorSpace table
function ColorProperty:new(name, properties, y, colorSpace)
  local o = {}

  local inner = r.computed(function()
    local a, b, c = colorSpace:fromLinear(table.unpack(base()))
    a, b, c = colorSpace:clip(a, b, c)
    return { a, b, c }
  end)

  term.setTextColor(TEXT_COLOR)
  term.setBackgroundColor(BACKGROUND_COLOR)

  term.setCursorPos(1, y)
  term.write(name .. ":")

  for i = 1, #properties do
    term.setCursorPos(1, y + i)
    term.write(properties[i].name)

    buttons[#buttons + 1] = Button:new(
      "min",
      10,
      y + i,
      function()
        local value = inner()
        value[i] = properties[i].min or 0
        base({ colorSpace:toLinear(table.unpack(value)) })
      end
    )
    buttons[#buttons]:draw()

    buttons[#buttons + 1] = Button:new(
      "-1",
      14,
      y + i,
      function()
        local value = inner()
        local mult = properties[i].multiplier or 1
        local step = properties[i].step or (1 / mult)
        if holding_shift then
          step = step * 10
        end
        value[i] = value[i] - step

        if properties[i].rotate then
          value[i] = math.fmod(value[i], properties[i].max or 1)
        else
          local min = properties[i].min or 0
          local max = properties[i].max or 1
          value[i] = math.min(math.max(value[i], min), max)
        end

        base({ colorSpace:toLinear(table.unpack(value)) })
      end
    )
    buttons[#buttons]:draw()

    buttons[#buttons + 1] = Button:new(
      "+1",
      17,
      y + i,
      function()
        local value = inner()
        local mult = properties[i].multiplier or 1
        local step = properties[i].step or (1 / mult)
        if holding_shift then
          step = step * 10
        end
        value[i] = value[i] + step

        if properties[i].rotate then
          value[i] = math.fmod(value[i], properties[i].max or 1)
        else
          local min = properties[i].min or 0
          local max = properties[i].max or 1
          value[i] = math.min(math.max(value[i], min), max)
        end

        base({ colorSpace:toLinear(table.unpack(value)) })
      end
    )
    buttons[#buttons]:draw()

    buttons[#buttons + 1] = Button:new(
      "max",
      20,
      y + i,
      function()
        local value = inner()
        value[i] = properties[i].max or 1
        base({ colorSpace:toLinear(table.unpack(value)) })
      end
    )
    buttons[#buttons]:draw()
  end


  r.effect(function()
    term.setTextColor(TEXT_COLOR)
    term.setBackgroundColor(BACKGROUND_COLOR)

    local xyz = inner()

    for i = 1, 3 do
      local mult = properties[i].multiplier or 1
      term.setCursorPos(3, y + i)
      local formatted = string.format("%." .. properties[i].dp .. "f", xyz[i] * mult)
      term.write(rpad(formatted, 7))
    end
  end)

  self.__index = self
  return setmetatable(o, self)
end

term.setBackgroundColor(BACKGROUND_COLOR)
term.clear()

ColorProperty:new("RGB", {
  {
    name = "R",
    multiplier = 255,
    dp = 0,
  },
  {
    name = "G",
    multiplier = 255,
    dp = 0,
  },
  {
    name = "B",
    multiplier = 255,
    dp = 0,
  }
}, 2, c.Srgb)
ColorProperty:new("HSL", {
  {
    name = "H",
    rotate = true,
    max = 360,
    dp = 1,
  },
  {
    name = "S",
    max = 100,
    dp = 1,
  },
  {
    name = "L",
    max = 100,
    dp = 1,
  }
}, 7, c.Hsl)
ColorProperty:new("OKLCH", {
  {
    name = "L",
    dp = 2,
    step = 0.01,
  },
  {
    name = "C",
    max = 0.4,
    dp = 2,
    step = 0.01,
  },
  {
    name = "H",
    rotate = true,
    max = 360,
    dp = 1,
  }
}, 12, c.Oklch)

buttons[#buttons + 1] = Button:new(
  "Exit",
  1,
  17,
  function()
    keep_running = false
  end
)
buttons[#buttons]:draw()

r.effect(function()
  term.setCursorPos(1, term.getSize())

  local r, g, b = c.Srgb:fromLinear(table.unpack(base()))

  term.setPaletteColor(colors.red, r, g, b)
  term.setBackgroundColor(colors.red)
  term.setCursorPos(1, 1)
  term.write(string.rep(" ", term.getSize() - 1))
end)

while keep_running do
  local ev = { os.pullEvent() }

  if ev[1] == "mouse_click" then
    for i = 1, #buttons do
      local button = buttons[i]
      if button:mouseCheck(ev[3], ev[4]) then
        button.action()
        break
      end
    end
  end

  if ev[1] == "key" then
    local key = keys.getName(ev[2])

    if key == "q" then
      keep_running = false
    end

    if key == "leftShift" then
      holding_shift = true
    end
  end

  if ev[1] == "key_up" then
    local key = keys.getName(ev[2])
    if key == "leftShift" then
      holding_shift = false
    end
  end
end

term.setTextColor(colors.white)
term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()
