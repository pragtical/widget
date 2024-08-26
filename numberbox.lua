--
-- NumberBox Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local style = require "core.style"
local Widget = require "widget"
local Button = require "widget.button"
local TextBox = require "widget.textbox"

---@class widget.numberbox : widget
---@overload fun(parent?:widget, value:number, min?:number, max?:number, step?:number):widget.numberbox
---@field private textbox widget.textbox
---@field private decrease_button widget.button
---@field private increase_button widget.button
---@field private minimum number
---@field private maximum number
---@field private step number
local NumberBox = Widget:extend()

---Constructor
---@param parent widget
---@param value number
---@param min? number
---@param max? number
---@param step? number
function NumberBox:new(parent, value, min, max, step)
  NumberBox.super.new(self, parent)

  self.type_name = "widget.numberbox"

  self:set_range(min, max)
  self:set_step(step)

  self.textbox = TextBox(self, "")
  self.textbox.scrollable = true

  self.decrease_button = Button(self, "-")
  self.increase_button = Button(self, "+")

  self:set_value(value)

  local this = self
  function self.textbox.textview.doc:on_text_change(type)
    if not tonumber(this.textbox:get_text()) then
      if not this.coroutine_run then
        this.coroutine_run = true
        core.add_thread(function()
          this.textbox:set_text(this.current_text)
          this.coroutine_run = false
        end)
      end
    else
      this.textbox.placeholder_active = false
      this.current_text = this.textbox:get_text()
      this:on_change(tonumber(this.current_text))
    end
  end
  function self.textbox:on_mouse_wheel(y)
    if self.active then
      if y > 0 then this:increase() else this:decrease() end
      return true
    end
    return false
  end
  function self.decrease_button:on_mouse_pressed(button, x, y, clicks)
    if Button.super.on_mouse_pressed(self, button, x, y, clicks) then
      this.mouse_is_pressed = true
      this:mouse_pressed(false)
      return true
    end
    return false
  end
  function self.increase_button:on_mouse_pressed(button, x, y, clicks)
    if Button.super.on_mouse_pressed(self, button, x, y, clicks) then
      this.mouse_is_pressed = true
      this:mouse_pressed(true)
      return true
    end
    return false
  end
  function self.decrease_button:on_mouse_released(button, x, y)
    if Button.super.on_mouse_released(self, button, x, y) then
      this.mouse_is_pressed = false
      return true
    end
    return false
  end
  function self.increase_button:on_mouse_released(button, x, y)
    if Button.super.on_mouse_released(self, button, x, y) then
      this.mouse_is_pressed = false
      return true
    end
    return false
  end

  self.border.width = 0
end

---Set a new value.
---@param value number
function NumberBox:set_value(value)
  if type(value) == "number" then
    self.textbox:set_text(tostring(value))
  elseif type(value) == "string" and tonumber(value) then
    self.textbox:set_text(value)
  else
    self.textbox:set_text(tostring(self.minimum))
  end
  self.textbox.placeholder_active = false
  self.current_text = self.textbox:get_text()
  self:on_change(tonumber(self.current_text))
end

---Get the current value.
---@return number
function NumberBox:get_value()
  return tonumber(self.textbox:get_text()) or self.minimum
end

---Set the minimum and maximum values allowed.
---@param min? number
---@param max? number
function NumberBox:set_range(min, max)
  self.minimum = min or math.mininteger
  self.maximum = max or math.maxinteger
end

---Set the value used to increase or decrease the number when the
---buttons are pressed.
---@param step number
function NumberBox:set_step(step)
  self.step = step or 1
end

---Decrease the current value.
function NumberBox:decrease()
  self.textbox.placeholder_active = false
  local value = tonumber(self.textbox:get_text()) or self.maximum
  if (value - self.step) >= self.minimum then
    self:set_value(value - self.step)
  end
end

---Increase the current value.
function NumberBox:increase()
  self.textbox.placeholder_active = false
  local value = tonumber(self.textbox:get_text()) or self.minimum
  if (value + self.step) <= self.maximum then
    self:set_value(value + self.step)
  end
end

---Triggered when the mouse is pressed on the increase/decrease buttons.
---@param increase boolean
function NumberBox:mouse_pressed(increase)
  if increase then self:increase() else self:decrease() end

  local elapsed = system.get_time() + 0.3
  local this = self

  core.add_thread(function()
    while this.mouse_is_pressed do
      if elapsed < system.get_time() then
        if increase then
          this:increase()
        else
          this:decrease()
        end
        elapsed = system.get_time() + 0.1
      end
      core.redraw = true
      coroutine.yield()
    end
  end)
end

function NumberBox:on_scale_change(new_scale, prev_scale)
  NumberBox.super.on_scale_change(self, new_scale, prev_scale)
  -- if a button was pressed while a scale change occured release it
  -- to prevent losing focus and losing the on_mouse_released
  if self.increase_button.mouse_is_pressed then
    self.increase_button:on_mouse_released("left", 0, 0)
  elseif self.decrease_button.mouse_is_pressed then
    self.decrease_button:on_mouse_released("left", 0, 0)
  end
end

function NumberBox:update_size_position()
  NumberBox.super.update_size_position(self)

  self.textbox:set_position(0, 0)
  self.textbox:set_size(125 * SCALE)

  self.decrease_button:set_position(
    self.textbox:get_right() - self.decrease_button.border.width,
    0
  )

  self.increase_button:set_position(
    self.decrease_button:get_right() - self.increase_button.border.width,
    0
  )

  self:set_size(
    self.textbox:get_width()
      + self.decrease_button:get_width()
      + self.increase_button:get_width(),
    math.max(
      self.textbox:get_height(),
      self.decrease_button:get_height(),
      self.increase_button:get_height()
    )
    -- TODO: check what causes the need for this border size addition since
    -- it shouldn't be needed but for now fixes occasional bottom border cut.
    + self.textbox.border.width * 2
  )
end


return NumberBox
