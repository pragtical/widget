--
-- Dialog object that serves as base to implement other dialogs.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local style = require "core.style"
local Widget = require "widget"
local Button = require "widget.button"
local Label = require "widget.label"

---@class widget.dialog : widget
---@overload fun(title?:string):widget.dialog
---@field protected title widget.label
---@field protected close widget.button
---@field protected panel widget
local Dialog = Widget:extend()

---Constructor
---@param title string
function Dialog:new(title)
  Dialog.super.new(self)

  self.type_name = "widget.dialog"

  self.draggable = true
  self.scrollable = false

  -- minimum width and height
  self.size.mx = 400
  self.size.my = 150

  self.title = Label(self, "")
  self.close = Button(self, "")
  self.close:set_icon("X")
  self.close.border.width = 0
  self.close:toggle_background(false)
  self.close.padding.x = 4
  self.close.padding.y = 0
  self.panel = Widget(self)
  self.panel.border.width = 0
  self.panel.scrollable = true

  local this = self

  function self.close:on_click()
    this:on_close()
    this:hide()
  end

  self:set_title(title or "")
end

---Returns the widget where you can add child widgets to this dialog.
---@return widget
function Dialog:get_panel()
  return self.panel
end

---Change the dialog title.
---@param text string|widget.styledtext
function Dialog:set_title(text)
  self.title:set_label(text)
end

---Calculate the dialog size, centers it relative to screen and shows it.
function Dialog:show()
  Dialog.super.show(self)
  self:update_size_position()
  self:centered()
end

---Called when the user clicks the close button of the dialog.
function Dialog:on_close()
  self:hide()
end

function Dialog:update_size_position()
  Dialog.super.update_size_position(self)

  local min_width = self.size.mx * SCALE
  local min_height = self.size.my * SCALE

  local size = self:get_size()

  local width = math.max(
    self.title:get_content_size() + (style.padding.x * 3)
      + self.close:get_width(),
    min_width,
    size.x
  )

  local height = math.max(
    self.title:get_height() + (style.padding.y * 3),
    min_height,
    size.y
  )

  width = math.min(width,
    math.max(1, core.root_view.size.x - style.padding.x * 2))
  height = math.min(height,
    math.max(1, core.root_view.size.y - style.padding.y * 2))

  self:set_size(width, height)

  self.title:set_position(
    style.padding.x / 2,
    style.padding.y / 2
  )
  self.title.scrollable = false
  self.title:set_size(
    math.max(1, width - self.close:get_width() - style.padding.x * 2),
    self.title:get_font():get_height()
  )

  self.close:set_position(
    size.x - self.close.size.x - (style.padding.x / 2),
    style.padding.y / 2
  )

  self.panel:set_position(
    0,
    self.title:get_bottom() + (style.padding.y / 2)
  )

  self.panel:set_size(
    size.x,
    size.y - self.title.size.y - style.padding.y
  )
end

---Keep the dialog chrome inside bounds constrained by the floating layout.
---Oversized panel contents remain accessible through the panel's scrollbars.
---@param x number Outer screen x coordinate
---@param y number Outer screen y coordinate
---@param w number Width including the border
---@param h number Height including the border
function Dialog:set_floating_bounds(x, y, w, h)
  local width, height = self.size.x, self.size.y
  Dialog.super.set_floating_bounds(self, x, y, w, h)
  if width ~= self.size.x or height ~= self.size.y then
    self.close:set_position(
      self.size.x - self.close:get_width() - style.padding.x / 2,
      style.padding.y / 2
    )
    self.panel:set_size(
      self.size.x,
      math.max(0, self.size.y - self.panel:get_position().y)
    )
  end
end

---Paint the title as part of the normal Widget background pass.
---@param color renderer.color Dialog background color
function Dialog:draw_background(color)
  Dialog.super.draw_background(self, color)
  renderer.draw_rect(
    self.position.x,
    self.position.y,
    self.size.x, math.min(self.size.y, self.title:get_height() + style.padding.y),
    style.selection
  )
end


return Dialog
