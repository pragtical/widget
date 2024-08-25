--
-- Color Picker Dialog Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local Button = require "widget.button"
local ColorPicker = require "widget.colorpicker"
local Dialog = require "widget.dialog"

---@class widget.colorpickerdialog : widget.dialog
---@overload fun(title?:string, color?:renderer.color|string):widget.colorpickerdialog
---@field super widget.dialog
---@field picker widget.colorpicker
---@field apply widget.button
---@field cancel widget.button
local ColorPickerDialog = Dialog:extend()

---Constructor
---@param title? string
---@param color? renderer.color | string
function ColorPickerDialog:new(title, color)
  ColorPickerDialog.super.new(self, title or "Color Picker")

  self.type_name = "widget.colorpickerdialog"
  self.picker = ColorPicker(self.panel, color)

  local this = self

  self.apply = Button(self.panel, "Apply")
  self.apply:set_icon("S")
  function self.apply:on_click()
    this:on_apply(this.picker:get_color())
    this:on_close()
  end

  self.cancel = Button(self.panel, "Cancel")
  self.cancel:set_icon("C")
  function self.cancel:on_click()
    this:on_close()
  end
end

function ColorPickerDialog:show()
  ColorPickerDialog.super.show(self)
  self:centered()
end

---Called when the user clicks on apply
---@param value renderer.color
function ColorPickerDialog:on_apply(value) end

function ColorPickerDialog:update_size_position()
  ColorPickerDialog.super.update_size_position(self)

  self.picker:set_position(style.padding.x/2, 0)

  self.apply:set_position(
    style.padding.x/2,
    self.picker:get_bottom() + style.padding.y
  )
  self.cancel:set_position(
    self.apply:get_right() + style.padding.x,
    self.picker:get_bottom() + style.padding.y
  )

  self.panel.size.y = self.panel:get_real_height() + style.padding.y / 2

  local size = self:get_size()
  size.x = self.picker:get_right() + style.padding.x / 2
  size.y = self:get_real_height() + style.padding.y / 2

  self.close:set_position(
    size.x - self.close:get_width() - (style.padding.x / 2),
    style.padding.y / 2
  )
end


return ColorPickerDialog
