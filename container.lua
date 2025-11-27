--
-- Container Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local Widget = require "widget"

---@class widget.container : widget
---@overload fun(parent:widget,direction?:widget.container.direction,alignment?:widget.container.alignment):widget.container
local Container = Widget:extend()

---@enum widget.container.alignment
Container.alignment = {
  LEFT = 1,
  RIGHT = 2,
  CENTER = 3
  -- TODO: add space-around and space-between (as in css) alignment options
}

---@enum widget.container.direction
Container.direction = {
  HORIZONTAL = 1,
  VERTICAL = 2
}

---Constructor
---@param parent widget
---@param direction widget.container.direction
---@param alignment widget.container.alignment
function Container:new(parent, direction, alignment)
  Container.super.new(self, parent)
  self.type_name = "widget.container"
  self.border.width = 0
  self.alignment = alignment or Container.alignment.CENTER
  self.direction = direction or Container.direction.HORIZONTAL
  self.padding = { x = style.padding.x / SCALE, y = style.padding.y / SCALE }
  self.spacing = style.padding.x / SCALE
  self.old_size = {x = self.size.x, y = self.size.y}
  self.default_proprties = nil
end

---Set the internal padding for the container.
---@param padding widget.padding
function Container:set_padding(padding)
  self.padding = padding or {
    x = style.padding.x / SCALE,
    y = style.padding.y / SCALE
  }
end

---Set the amount of space to separate a widget from another.
---@param spacing number
function Container:set_spacing(spacing)
  self.spacing = spacing or style.padding.x / SCALE
end

---A child widget sizing and alignment properties.
---@class widget.container.properties
---@field stretch? integer A stretch factor proportional to other childs
---@field expand? boolean Take the whole width of parent without the padding?
---@field min_size? {x: number, y:number}
---@field padding? {top:number, right:number, bottom:number, left:number}

---Allows setting a child properties
---@param child widget
---@param properties? widget.container.properties
function Container:set_child_properties(child, properties)
  -- TODO: implement various child properties like expand.
  child.properties = properties
end

---Set default properties for all childs not having any.
---@param properties? widget.container.properties
function Container:set_default_child_properties(properties)
  -- TODO: implement default child properties
  self.default_proprties = properties
end

---Same as Widget:add_child() but also allows setting the container properties.
---@param child widget
---@param properties widget.container.properties
function Container:add_child(child, properties)
  Container.super.add_child(self, child)
  self:set_child_properties(child, properties)
end

---@param self widget.container
---@param from integer
---@param to integer
---@return integer from
---@return integer to
---@return number x
---@return number y
local function get_childs_fit(self, from, to, y)
  local e = from
  local spacing = self.spacing * SCALE
  local pxscale = self.padding.x * SCALE
  local space = 2 * pxscale
  local width = 0
  local height = 0

  for i=from, to, -1 do
    local visible = self.childs[i]:is_visible()
    local cw = visible and self.childs[i]:get_width() or 0
    height = math.max(height, visible and self.childs[i]:get_height() or 0)
    if width + space + cw < self.size.x then
      width = width + cw
      space = visible and space + spacing or space
      e = i
    else
      if i == from and visible then width = cw end
      break
    end
  end

  if space ~= 2 * pxscale then
    space = space - spacing -- remove spacing added from last widget
  end

  local x = pxscale -- default left alignment
  if self.alignment == Container.alignment.CENTER then
    x = (self.size.x / 2) - ((width + space) / 2) + pxscale
  elseif self.alignment == Container.alignment.RIGHT then
    x = self.size.x
      - width - space
      + pxscale
  end

  return from, e, x, y + height
end

---@param self widget.container
local function position_horizontal(self)
  local from, to, x = #self.childs, 1, 0
  local y, ny = self.padding.y * SCALE, 0
  while true do
    from, to, x, ny = get_childs_fit(self, from, 1, y)
    for i=from, to, -1 do
      if self.childs[i]:is_visible() then
        self.childs[i]:set_position(x, y)
        self.childs[i]:get_width()
        x = x + self.childs[i]:get_width() + self.spacing * SCALE
      end
    end
    if to == 1 then break end
    from = to - 1
    y = ny + (self.spacing * SCALE)
  end
end

---@param self widget.container
local function position_vertical(self)
  local from, to, x = #self.childs, 1, 0
  local y, ny = self.padding.y * SCALE, 0
  for i=from, to, -1 do
    from, to, x, ny = get_childs_fit(self, i, i, y)
    if self.childs[i]:is_visible() then
      self.childs[i]:set_position(x, y)
      y = ny + (self.spacing * SCALE)
    end
  end
end

function Container:update()
  if Container.super.update(self) then
    if self.old_size.x ~= self.size.x or self.old_size.y ~= self.size.y then
      if self.direction == Container.direction.HORIZONTAL then
        position_horizontal(self)
      else
        position_vertical(self)
      end
      self:set_size(nil, self:get_real_height() + self.padding.y * SCALE)
      self.old_size.x = self.size.x
      self.old_size.y = self.size.y
    end
    return true
  end
  return false
end


return Container
