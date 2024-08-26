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
    self.title:get_width() + (style.padding.x * 3) + self.close:get_width(),
    min_width,
    size.x
  )

  local height = math.max(
    self.title:get_height() + (style.padding.y * 3),
    min_height,
    size.y
  )

  self:set_size(width, height)

  self.title:set_position(
    style.padding.x / 2,
    style.padding.y / 2
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

---We overwrite default draw function to draw the title background.
function Dialog:draw()
  if not self:is_visible() then return false end

  Dialog.super.draw(self)

  self:draw_border()

  if self.background_color then
    self:draw_background(self.background_color)
  else
    self:draw_background(
      self.parent and style.background or style.background2
    )
  end

  if #self.childs > 0 then
    core.push_clip_rect(
      self.position.x,
      self.position.y,
      self.size.x,
      self.size.y
    )
  end

  -- draw the title background
  renderer.draw_rect(
    self.position.x,
    self.position.y,
    self.size.x, self.title:get_height() + style.padding.y,
    style.selection
  )

  for i=#self.childs, 1, -1 do
    self.childs[i]:draw()
  end

  if #self.childs > 0 then
    core.pop_clip_rect()
  end

  return true
end


return Dialog
