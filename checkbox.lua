--
-- CheckBox Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local common = require "core.common"
local Widget = require "widget"

---@class widget.checkbox : widget
---@overload fun(parent?:widget, label?:string):widget.checkbox
---@field private checked boolean
local CheckBox = Widget:extend()

---Constructor
---@param parent widget
---@param label string
function CheckBox:new(parent, label)
  CheckBox.super.new(self, parent)
  self.type_name = "widget.checkbox"
  self.checked = false
  self:set_label(label or "")
  self.animating = false
  self.animating_color = style.caret
end

---Set the checkbox label and recalculates the widget size.
---@param text string
function CheckBox:set_label(text)
  CheckBox.super.set_label(self, text)

  local _, _, bw, bh = self:get_box_rect()

  local font = self:get_font()

  local size = self:get_size()
  self.label_lines = { self.label }
  if self.wrap_width then
    local available = math.max(1, self.wrap_width - bw - style.padding.x / 2)
    self.label_lines = {}
    for paragraph in (self.label .. "\n"):gmatch "([^\n]*)\n" do
      local line = ""
      for word in paragraph:gmatch "%S+" do
        local candidate = line == "" and word or line .. " " .. word
        if line ~= "" and font:get_width(candidate) > available then
          self.label_lines[#self.label_lines + 1], line = line, word
        else
          line = candidate
        end
      end
      self.label_lines[#self.label_lines + 1] = line
    end
  end
  local width = 0
  for _, line in ipairs(self.label_lines) do
    width = math.max(width, font:get_width(line))
  end
  size.x = width + bw + (style.padding.x / 2)
  size.y = math.max(bh, font:get_height() * #self.label_lines)
end

---Constrain label width with word wrapping; nil restores single-line labels.
---@param width? number
function CheckBox:set_wrap_width(width)
  self.wrap_width = width
  self:set_label(self.label)
end

---Change the status of the checkbox.
---@param checked boolean
function CheckBox:set_checked(checked)
  self.checked = checked
  self:on_change(self.checked)
end

---Get the status of the checkbox.
---@return boolean
function CheckBox:is_checked()
  return self.checked
end

---Called when the checkbox is (un)checked.
---@param checked boolean
function CheckBox:on_checked(checked) end

function CheckBox:on_mouse_enter(...)
  CheckBox.super.on_mouse_enter(self, ...)
  self.hover_text = style.accent
end

function CheckBox:on_mouse_leave(...)
  CheckBox.super.on_mouse_leave(self, ...)
  self.hover_text = nil
end

function CheckBox:on_click()
  self.checked = not self.checked
  self:on_checked(self.checked)
  self:on_change(self.checked)

  self.animating = true
  local unchecked_color = self.border.color or style.text
  self.animating_color = {table.unpack(self.checked and unchecked_color or style.caret)}
  local target_color = self.checked and style.caret or unchecked_color
  self:animate(self.animating_color, {table.unpack(target_color)}, {
    on_complete = function()
      self.animating = false
    end
  })
end

---Get the icon bounds used for drawing and label layout.
---@return number x
---@return number y
---@return number width
---@return number height
function CheckBox:get_box_rect()
  return
    self.position.x,
    self.position.y,
    math.max(style.icon_font:get_width("☐"), style.icon_font:get_width("☑")),
    math.max(self:get_font():get_height(), style.icon_font:get_height())
end

function CheckBox:update_size_position()
  CheckBox.super.update_size_position(self)
  self:set_label(self.label)
end

function CheckBox:draw()
  if not self:is_visible() then
    return false
  end

  local bx, by, bw, bh = self:get_box_rect()

  local color = self.animating and self.animating_color
    or (self.checked and style.caret or self.border.color or style.text)
  common.draw_text(style.icon_font, color, self.checked and "☑" or "☐", "center", bx, by, bw, bh)

  local font = self:get_font()
  for i, line in ipairs(self.label_lines or { self.label }) do
    renderer.draw_text(
      font,
      line,
      self.position.x + bw + (style.padding.x / 2),
      self.position.y + (i - 1) * font:get_height(),
      self.hover_text or self.foreground_color or style.text
    )
  end

  return true
end


return CheckBox
