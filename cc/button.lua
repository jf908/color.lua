local Button = {}

---@param text string
---@param x number
---@param y number
---@param action function
---@param backgroundColor string|nil
---@param textColor string|nil
---@param width number|nil
---@param height number|nil
function Button:new(text, x, y, action, backgroundColor, textColor, width, height)
  local o = {
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
  term.setBackgroundColor(self.backgroundColor)
  term.setTextColor(self.textColor)
  term.setCursorPos(self.x, self.y)
  term.write(self.text)
end

---@param x number
---@param y number
function Button:mouseCheck(x, y)
  return x >= self.x and x < self.x + self.width and y >= self.y and y < self.y + self.height
end

return Button
