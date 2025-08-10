--[[
 * color.lua
 *
 * Derived from https://github.com/linebender/color (Apache 2.0 / MIT)
]]

---@class ColorSpace
---@field fromLinear fun(self: ColorSpace, r: number, g: number, b: number): number, number, number
---@field toLinear fun(self: ColorSpace, a: number, b: number, c: number): number, number, number
---@field clip fun(self: ColorSpace, a: number, b: number, c: number): number, number, number

---@param x number
---@param y number
local function copysign(x, y)
  if y < 0 then
    return -math.abs(x)
  else
    return math.abs(x)
  end
end
---@param x number
---@param y number
local function hypot(x, y)
  return math.sqrt(x * x + y * y)
end

---@param m [ [number,number,number], [number,number,number], [number,number,number] ]
---@param x [number,number,number]
local function matvecmul(m, x)
  return {
    m[1][1] * x[1] + m[1][2] * x[2] + m[1][3] * x[3],
    m[2][1] * x[1] + m[2][2] * x[2] + m[2][3] * x[3],
    m[3][1] * x[1] + m[3][2] * x[2] + m[3][3] * x[3],
  }
end

---@param x number
local function srgb_to_lin(x)
  if math.abs(x) <= 0.04045 then
    return x * (1 / 12.92)
  else
    return copysign(((math.abs(x) + 0.055) * (1 / 1.055)) ^ 2.4, x)
  end
end

---@param x number
local function lin_to_srgb(x)
  if math.abs(x) <= 0.0031308 then
    return x * 12.92
  else
    return copysign((1.055 * (math.abs(x) ^ (1 / 2.4))) - 0.055, x)
  end
end


---@class Linear: ColorSpace
local Linear = {
  name = "Linear"
}

---@param r number
---@param g number
---@param b number
---@return number, number, number
function Linear:fromLinear(r, g, b)
  return r, g, b
end

---@param r number
---@param g number
---@param b number
---@return number, number, number
function Linear:toLinear(r, g, b)
  return r, g, b
end

---@param r number
---@param g number
---@param b number
---@return number, number, number
function Linear:clip(r, g, b)
  return math.min(math.max(r, 0), 1), math.min(math.max(g, 0), 1), math.min(math.max(b, 0), 1)
end

---@class Srgb: ColorSpace
local Srgb = {
  name = "Srgb"
}

---@param r number
---@param g number
---@param b number
---@return number, number, number
function Srgb:fromLinear(r, g, b)
  return lin_to_srgb(r), lin_to_srgb(g), lin_to_srgb(b)
end

---@param r number
---@param g number
---@param b number
---@return number, number, number
function Srgb:toLinear(r, g, b)
  return srgb_to_lin(r), srgb_to_lin(g), srgb_to_lin(b)
end

---@param r number
---@param g number
---@param b number
---@return number, number, number
function Srgb:clip(r, g, b)
  return math.min(math.max(r, 0), 1), math.min(math.max(g, 0), 1), math.min(math.max(b, 0), 1)
end

---@param h number
---@param s number
---@param l number
---@return number, number, number
local function hsl_to_rgb(h, s, l)
  local sat = s * 0.01
  local light = l * 0.01
  local a = sat * math.min(light, 1 - light)

  local n, x, k
  n = 0
  x = n + h * (1 / 30)
  k = x - 12 * math.floor(x * (1 / 12))
  local r = light - a * math.min(math.max(math.min(k - 3, 9 - k), -1), 1)
  n = 8
  x = n + h * (1 / 30)
  k = x - 12 * math.floor(x * (1 / 12))
  local g = light - a * math.min(math.max(math.min(k - 3, 9 - k), -1), 1)
  n = 4
  x = n + h * (1 / 30)
  k = x - 12 * math.floor(x * (1 / 12))
  local b = light - a * math.min(math.max(math.min(k - 3, 9 - k), -1), 1)

  return r, g, b
end

---@param r number
---@param g number
---@param b number
---@return number, number, number
local function rgb_to_hsl(r, g, b)
  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local hue = 0
  local sat = 0
  local light = 0.5 * (min + max)
  local d = max - min

  local epsilon = 1e-6
  if d > epsilon then
    local denom = math.min(light, 1 - light)
    if math.abs(denom) > epsilon then
      sat = (max - light) / denom
    end
    if max == r then
      hue = (g - b) / d
    elseif max == g then
      hue = (b - r) / d + 2
    else
      hue = (r - g) / d + 4
    end
    hue = hue * 60
    -- hue hack
    if sat < 0 then
      hue = hue + 180
      sat = math.abs(sat)
    end
    hue = hue - (360 * math.floor(hue * (1 / 360)))
  end

  return hue, sat * 100, light * 100
end

---@class Hsl: ColorSpace
local Hsl = {
  name = "Hsl"
}

---@param r number
---@param g number
---@param b number
---@return number, number, number
function Hsl:fromLinear(r, g, b)
  local r, g, b = Srgb:fromLinear(r, g, b)
  local h, s, l = rgb_to_hsl(r, g, b)
  return h, s, l
end

---@param h number
---@param s number
---@param l number
---@return number, number, number
function Hsl:toLinear(h, s, l)
  local r, g, b = hsl_to_rgb(h, s, l)
  r, g, b = Srgb:toLinear(r, g, b)
  return r, g, b
end

---@param h number
---@param s number
---@param l number
---@return number, number, number
function Hsl:clip(h, s, l)
  return h, math.max(s, 0), math.min(math.max(l, 0), 100)
end

local OKLAB_LAB_TO_LMS = {
  { 1.0, 0.39633778,   0.21580376 },
  { 1.0, -0.105561346, -0.06385417 },
  { 1.0, -0.08948418,  -1.2914855 },
}

local OKLAB_LMS_TO_SRGB = {
  { 4.0767417,     -3.3077116, 0.23096994 },
  { -1.268438,     2.6097574,  -0.34131938 },
  { -0.0041960863, -0.7034186, 1.7076147 },
}

local OKLAB_SRGB_TO_LMS = {
  { 0.41222146, 0.53633255, 0.051445995 },
  { 0.2119035,  0.6806995,  0.10739696 },
  { 0.08830246, 0.28171885, 0.6299787 },
}

local OKLAB_LMS_TO_LAB = {
  { 0.21045426,  0.7936178,  -0.004072047 },
  { 1.9779985,   -2.4285922, 0.4505937 },
  { 0.025904037, 0.78277177, -0.80867577 },
}

---@class Oklab: ColorSpace
local Oklab = {
  name = "Oklab"
}

---@param r number
---@param g number
---@param b number
---@return number, number, number
function Oklab:fromLinear(r, g, b)
  local lms = matvecmul(OKLAB_SRGB_TO_LMS, { r, g, b })
  lms[1] = lms[1] ^ (1 / 3)
  lms[2] = lms[2] ^ (1 / 3)
  lms[3] = lms[3] ^ (1 / 3)
  local lab = matvecmul(OKLAB_LMS_TO_LAB, lms)
  return lab[1], lab[2], lab[3]
end

---@param l number
---@param a number
---@param b number
---@return number, number, number
function Oklab:toLinear(l, a, b)
  local lms = matvecmul(OKLAB_LAB_TO_LMS, { l, a, b })
  lms[1] = lms[1] * lms[1] * lms[1]
  lms[2] = lms[2] * lms[2] * lms[2]
  lms[3] = lms[3] * lms[3] * lms[3]
  local rgb = matvecmul(OKLAB_LMS_TO_SRGB, lms)
  return rgb[1], rgb[2], rgb[3]
end

---@param l number
---@param a number
---@param b number
---@return number, number, number
function Oklab:clip(l, a, b)
  return math.min(math.max(l, 0), 1), a, b
end

local function lab_to_lch(l, a, b)
  local h = math.atan2(b, a) * (180 / math.pi)
  if h < 0 then
    h = h + 360
  end
  local c = hypot(b, a)
  return l, c, h
end

local function lch_to_lab(l, c, h)
  local x = h * (math.pi / 180)
  local a = c * math.cos(x)
  local b = c * math.sin(x)
  return l, a, b
end

---@class Oklch: ColorSpace
local Oklch = {
  name = "Oklch"
}

---@param r number
---@param g number
---@param b number
---@return number, number, number
function Oklch:fromLinear(r, g, b)
  local l, a, b = Oklab:fromLinear(r, g, b)
  local l, c, h = lab_to_lch(l, a, b)
  return l, c, h
end

---@param l number
---@param c number
---@param h number
---@return number, number, number
function Oklch:toLinear(l, c, h)
  local l, a, b = lch_to_lab(l, c, h)
  local r, g, b = Oklab:toLinear(l, a, b)
  return r, g, b
end

---@param l number
---@param c number
---@param h number
---@return number, number, number
function Oklch:clip(l, c, h)
  return math.min(math.max(l, 0), 1), math.max(c, 0), h
end

---@class Color: [number,number,number]
---@field space ColorSpace
local Color = {}

---@param a number
---@param b number
---@param c number
---@param space ColorSpace
function Color:new(a, b, c, space)
  local o = { a, b, c, space = space }

  self.__index = self
  return setmetatable(o, self)
end

---@param toSpace ColorSpace
---@return Color
function Color:convert(toSpace)
  if self.space == toSpace then
    return self
  end

  local r, g, b = self.space:toLinear(self[1], self[2], self[3])
  r, g, b = toSpace:fromLinear(r, g, b)
  return Color:new(r, g, b, toSpace)
end

function Color:clip()
  local a, b, c = self.space:clip(self[1], self[2], self[3])
  self[1] = a
  self[2] = b
  self[3] = c
end

---@return Color
function Color:clone()
  return Color:new(self[1], self[2], self[3], self.space)
end

return {
  Color = Color,
  Linear = Linear,
  Srgb = Srgb,
  Hsl = Hsl,
  Oklab = Oklab,
  Oklch = Oklch
}
