--
-- CheckBox Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
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

  local _, _, bw, _ = self:get_box_rect()

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
  size.y = font:get_height() * #self.label_lines
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
  self.hover_back = style.dim
end

function CheckBox:on_mouse_leave(...)
  CheckBox.super.on_mouse_leave(self, ...)
  self.hover_text = nil
  self.hover_back = nil
end

function CheckBox:on_click()
  self.checked = not self.checked
  self:on_checked(self.checked)
  self:on_change(self.checked)

  self.animating = true
  self.animating_color = {table.unpack(style.caret)}
  local target_color = {table.unpack(style.caret)}

  if self.checked then
    self.animating_color[4] = 0
    target_color[4] = 255
  else
    self.animating_color[4] = 255
    target_color[4] = 0
  end
  self:animate(self.animating_color, {table.unpack(target_color)}, {
    on_complete = function()
      self.animating = false
    end
  })
end

function CheckBox:get_box_rect()
  local size = 1.6
  local font = self:get_font()
  local fh = font:get_height() / size
  return
    self.position.x,
    self.position.y + (fh / (size * 2)),
    font:get_width("x") + 4,
    fh
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

  self:draw_border(bx, by, bw, bh)

  renderer.draw_rect(
    bx,
    by,
    bw,
    bh,
    self.hover_back or self.background_color or style.background
  )

  if self.animating then
    renderer.draw_rect(bx + 2, by + 2, bw - 4, bh - 4, self.animating_color)
  elseif self.checked then
    renderer.draw_rect(bx + 2, by + 2, bw - 4, bh - 4, style.caret)
  end

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
