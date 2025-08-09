---@class Slider
---@field window ccTweaked.term.Redirect|ccTweaked.peripherals.Monitor
---@field x number
---@field y number
---@field width number
---@field height number
---@field action fun(value: number)
local Slider = {}

-- From PrimeUI
---@return number, number
local function getWindowPos(win, x, y)
  if win == term then return x, y end
  while win ~= term.native() and win ~= term.current() do
    if not win.getPosition then return x, y end
    local wx, wy = win.getPosition()
    x, y = x + wx - 1, y + wy - 1
    _, win = debug.getupvalue(select(2, debug.getupvalue(win.isColor, 1)), 1) -- gets the parent window through an upvalue
  end
  return x, y
end

---@param window ccTweaked.term.Redirect|ccTweaked.peripherals.Monitor
---@param x number
---@param y number
---@param action function
---@param width number
---@param height number
function Slider:new(window, x, y, action, width, height)
  local o = {
    window = window,
    x = x,
    y = y,
    action = action,
    width = width,
    height = height,
  }

  self.__index = self
  return setmetatable(o, self)
end

---@param clickX number
---@param clickY number
---@return boolean
function Slider:mouseCheck(clickX, clickY)
  local x, y = getWindowPos(self.window, self.x, self.y)

  if clickX >= x and clickX < x + self.width and clickY >= y and clickY < y + self.height then
    self.action((clickX - x) / (self.width - 1))
    return true
  end

  return false
end

---@param x number
---@param y number
---@param width number
---@param height number
function Slider:reposition(x, y, width, height)
  self.x = x
  self.y = y
  self.width = width
  self.height = height
end

return Slider
