--
-- ToggleButton Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local Widget = require "widget"

---@class widget.togglebutton : widget
---@overload fun(parent:widget?, enable:boolean?, label:string?, icon:string?):widget.togglebutton
---@field public enabled boolean
---@field public padding widget.position
---@field public icon widget.button.icon
---@field public expanded boolean
local ToggleButton = Widget:extend()

---Constructor
---@param parent widget
---@param enable? boolean
---@param label? string
---@param icon? string
function ToggleButton:new(parent, enable, label, icon)
  ToggleButton.super.new(self, parent)

  self.type_name = "widget.togglebutton"

  self.enabled = enable or false

  self.toggle_hovered = false

  self.icon = {
    code = nil, color = nil, hover_color = nil
  }

  self.padding = {
    x = style.padding.x / 2,
    y = style.padding.y / 5
  }

  self.expanded = false

  self:set_label(label or "")
  if icon then self:set_icon(icon) end
end

---@param enabled boolean
function ToggleButton:set_toggle(enabled)
  self.enabled = enabled
  self:on_change(self.enabled)
end

---@return boolean
function ToggleButton:is_toggled()
  return self.enabled
end

function ToggleButton:toggle()
  self.enabled = not self.enabled
  self:on_change(self.enabled)
end

---When set to true the button width will be the same as parent
---@param expand? boolean | nil
function ToggleButton:toggle_expand(expand)
  if type(expand) == "boolean" then
    self.expanded = expand
  else
    self.expanded = not self.expanded
  end
  self:update_position()
end

---Set the icon drawn alongside the button text.
---@param code? string
---@param color? renderer.color
---@param hover_color? renderer.color
function ToggleButton:set_icon(code, color, hover_color)
  self.icon.code = code
  self.icon.color = color
  self.icon.hover_color = hover_color

  self:set_label(self.label)
end

---Set the button text and recalculates the widget size.
---@param text string
function ToggleButton:set_label(text)
  ToggleButton.super.set_label(self, text)

  local font = self:get_font()
  local border = self.border.width * 2

  local size = self:get_size()

  if self.expanded and self.parent then
    size.x = self.parent:get_size().x - self.position.rx - border
  else
    size.x = font:get_width(self.label) + (self.padding.x * 2) - border
  end

  size.y = font:get_height() + (self.padding.y * 2) - border

  if self.icon.code then
    local icon_w = style.icon_font:get_width(self.icon.code)

    if self.label ~= "" then
      icon_w = icon_w + (self.padding.x / 2)
    end

    local icon_h = style.icon_font:get_height() + (self.padding.y * 2) - border

    size.x = size.x + icon_w
    size.y = math.max(size.y, icon_h)
  end
end

function ToggleButton:on_click()
  self:toggle()
end

function ToggleButton:on_mouse_enter(...)
  ToggleButton.super.on_mouse_enter(self, ...)
  self.toggle_hovered = true
end

function ToggleButton:on_mouse_leave(...)
  ToggleButton.super.on_mouse_leave(self, ...)
  self.toggle_hovered = false
end

function ToggleButton:on_scale_change(new_scale, prev_scale)
  ToggleButton.super.on_scale_change(self, new_scale, prev_scale)
  self.padding.x = self.padding.x * (new_scale / prev_scale)
  self.padding.y = self.padding.y * (new_scale / prev_scale)
end

function ToggleButton:update_size_position()
  ToggleButton.super.update_size_position(self)
  self:set_label(self.label)
end

function ToggleButton:draw()
  if self.toggle_hovered or self.enabled then
    self.background_color = style.line_highlight
  else
    self.background_color = style.background
  end

  self.border.color = self.enabled and style.caret or style.text

  if not ToggleButton.super.draw(self) then return false end

  local font = self:get_font()

  local offsetx = self.position.x + self.padding.x
  local offsety = self.position.y
  local h = self:get_height()
  local ih, th = style.icon_font:get_height(), font:get_height()

  if self.icon.code then
    local icon_color
    if self.toggle_hovered or self.enabled then
      icon_color = self.icon.hover_color or style.accent
    else
      icon_color = self.icon.color or style.text
    end
    renderer.draw_text(
      style.icon_font,
      self.icon.code,
      offsetx,
      th > ih and (offsety + (h / 2)) - (ih/2) or (offsety + self.padding.y),
      icon_color
    )
    offsetx = offsetx + style.icon_font:get_width(self.icon.code) + (style.padding.x / 2)
  end

  if self.label ~= "" then
    local label_color
    if self.hover_text or self.enabled then
      label_color = style.accent
    else
      label_color = self.foreground_color or style.text
    end
    renderer.draw_text(
      font,
      self.label,
      offsetx,
      ih > th and (offsety + (h / 2)) - (th/2) or (offsety + self.padding.y),
      label_color
    )
  end

  return true
end


return ToggleButton
