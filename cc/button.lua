---@class Button
---@field window ccTweaked.term.Redirect|ccTweaked.peripherals.Monitor
---@field text string
---@field x number
---@field y number
---@field width number
---@field height number
---@field action fun(x: number, y: number)
---@field backgroundColor integer
---@field textColor integer
local Button = {}

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
---@param text string
---@param x number
---@param y number
---@param action function
---@param backgroundColor string|nil
---@param textColor string|nil
---@param width number|nil
---@param height number|nil
function Button:new(window, text, x, y, action, backgroundColor, textColor, width, height)
  local o = {
    window = window,
    text = text,
    x = x,
    y = y,
    action = action,
    backgroundColor = backgroundColor or colors.black,
    textColor = textColor or colors.white,
    width = width or string.len(text),
    height = height or 1,
  }

  self.__index = self
  return setmetatable(o, self)
end

function Button:draw()
  self.window.setBackgroundColor(self.backgroundColor)
  self.window.setTextColor(self.textColor)
  self.window.setCursorPos(self.x, self.y)
  self.window.write(self.text)
end

---@param clickX number
---@param clickY number
---@return boolean
function Button:mouseCheck(clickX, clickY)
  local x, y = getWindowPos(self.window, self.x, self.y)

  if clickX >= x and clickX < x + self.width and clickY >= y and clickY < y + self.height then
    self.action(clickX - x, clickY - y)
    return true
  end

  return false
end

---@param x number
---@param y number
---@param width number|nil
---@param height number|nil
function Button:reposition(x, y, width, height)
  self.x = x
  self.y = y
  if width ~= nil then
    self.width = width
  end
  if height ~= nil then
    self.height = height
  end
end

return Button
