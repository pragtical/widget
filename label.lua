--
-- Label Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local style = require "core.style"
local Widget = require "widget"

---@class widget.label : widget
---@overload fun(parent:widget?, label?:string):widget.label
---@field clickable boolean
local Label = Widget:extend()

---Constructor
---@param parent widget
---@param label string
function Label:new(parent, label)
  Label.super.new(self, parent)
  self.type_name = "widget.label"
  self.clickable = false
  self.border.width = 0
  self.custom_size = {x = 0, y = 0}

  self:set_label(label or "")
  self.default_height = true
end

---@param width? integer
---@param height? integer
function Label:set_size(width, height)
  Label.super.set_size(self, width, height)
  self.custom_size.x = self.size.x
  self.custom_size.y = self.size.y
  if height then
    self.default_height = false
  end
  if self.default_height then
    local font_height = self:get_font():get_height()
    if self.border.width > 0 then
      font_height = font_height + style.padding.y
    end
    Label.super.set_size(self, nil, font_height)
  end
end

---Set the label text and recalculates the widget size.
---@param text string|widget.styledtext
function Label:set_label(text)
  Label.super.set_label(self, text)

  local font = self:get_font()

  if self.custom_size.x <= 0 then
    if type(text) == "table" then
      self.size.x, self.size.y = self:draw_styled_text(text, 0, 0, true)
    else
      self.size.x = font:get_width(self.label)
      self.size.y = font:get_height()
    end

    if self.border.width > 0 then
      self.size.x = self.size.x + style.padding.x
      self.size.y = self.size.y + style.padding.y
    end
  end
end

function Label:update_size_position()
  Label.super.update_size_position(self)
  if self.custom_size.x <= 0 then
    self:set_label(self.label)
  end
  if self.border.width > 0 then
    self.scrollable = true
  end
end

function Label:draw()
  if not self:is_visible() then return false end

  self:draw_border()

  local px = self.border.width > 0 and (style.padding.x / 2) or 0
  local py = self.border.width > 0 and (style.padding.y / 2) or 0

  local posx, posy = self.position.x + px, self.position.y + py

  core.push_clip_rect(
    self.position.x,
    self.position.y,
    self.size.x,
    self.size.y
  )

  if type(self.label) == "table" then
    self:draw_styled_text(self.label, posx, posy)
  else
    renderer.draw_text(
      self:get_font(),
      self.label,
      posx,
      posy,
      self.foreground_color or style.text
    )
  end

  core.pop_clip_rect()

  self:draw_scrollbar()

  return true
end


return Label
