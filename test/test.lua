local c = require("../color")

local epsilon = 1e-6

local function difference(value1, value2)
  return math.sqrt((value1[1] - value2[1]) ^ 2 + (value1[2] - value2[2]) ^ 2 + (value1[3] - value2[3]) ^ 2)
end

local function tests()
  local colors = {
    c.Color:new(0, 0, 0, c.Linear),
    c.Color:new(1, 0, 0, c.Linear),
    c.Color:new(0, 1, 0, c.Linear),
    c.Color:new(0, 0, 1, c.Linear),
    c.Color:new(1, 1, 1, c.Linear),
    c.Color:new(0.5, 0.5, 0.5, c.Linear),
    c.Color:new(0.2, 0.3, 0.4, c.Linear),
    c.Color:new(0.9, 0.8, 0.7, c.Linear),
  }

  local color_spaces = {
    c.Srgb,
    c.Hsl,
    c.Oklab,
    c.Oklch,
  }

  for i = 1, #color_spaces do
    for j = 1, #colors do
      local distance = difference(colors[j], colors[j]:convert(color_spaces[i]):convert(c.Linear))
      if distance > epsilon then
        error(string.format("Color conversion failed for color %d in space %s: distance = %f", i, color_spaces[i].name,
          distance))
      end
    end
  end
end

tests()
