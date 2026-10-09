--
-- TextBox widget re-using code from pragtical's DocView.
--

local core = require "core"
local command = require "core.command"
local common = require "core.common"
local keymap = require "core.keymap"
local style = require "core.style"
local Doc = require "core.doc"
local DocView = require "core.docview"
local Highlighter = require "core.doc.highlighter"
local View = require "core.view"
local Widget = require "widget"

local PASSWORD_CHAR = "•"

---@param text string
---@return string
local function password_visible_text(text)
  return (text:gsub("[\r\n]", ""))
end

---@param text string
---@return string
local function password_text(text)
  return password_visible_text(text):ugsub(".", PASSWORD_CHAR)
end

---@param text string
---@param col integer
---@return integer
local function password_chars_before_col(text, col)
  local count = 0
  local pos = 1
  for char in text:ugmatch(".") do
    if pos >= col then break end
    if char ~= "\n" and char ~= "\r" then
      count = count + 1
    end
    pos = pos + #char
  end
  return count
end

---Customized Highlighter to disable the coroutine.
---@class widget.textbox.SingleLineHighlighter
local SingleLineHighlighter = Highlighter:extend()

function SingleLineHighlighter:get_line(idx)
  return {text=self.doc.lines[1], tokens={"normal", self.doc.lines[1]}}
end

function SingleLineHighlighter:start() end

---@class widget.textbox.SingleLineDoc : core.doc
---@overload fun():widget.textbox.SingleLineDoc
---@field super core.doc
local SingleLineDoc = Doc:extend()

function SingleLineDoc:reset()
  SingleLineDoc.super.reset(self)
  self.highlighter = SingleLineHighlighter(self)
  self:reset_syntax()
end

function SingleLineDoc:insert(line, col, text)
  SingleLineDoc.super.insert(self, line, col, text:gsub("\n", ""))
end

---@class widget.textbox.TextView : core.docview
---@overload fun(parent:widget,subparent:widget):widget.textbox.TextView
---@field super core.docview
local TextView = DocView:extend()

TextView.disable_save = true

function TextView:new(parent, subparent)
  TextView.super.new(self, SingleLineDoc())
  self.parent = parent
  self.subparent = subparent
  self.gutter_width = 0
  self.hide_lines_gutter = true
  self.gutter_text_brightness = 0
  self.scrollable = true
  self.font = "font"
  self.name = View.get_name(self)

  self.size.y = 0
  self.label = ""
end

function TextView:get_name()
  return self.name
end

function TextView:get_scrollable_size()
  return 0
end

function TextView:update()
  TextView.super.update(self)
  local width = self:get_col_x_offset(1, #self.doc.lines[1])
  local margin = 3 * self:get_font():get_width(" ")
  local max_x = math.max(0, width + margin - self.size.x)
  self.scroll.x = common.clamp(self.scroll.x, 0, max_x)
  self.scroll.to.x = common.clamp(self.scroll.to.x, 0, max_x)
end

function TextView:get_text()
  return self.doc:get_text(1, 1, 1, math.huge)
end

function TextView:set_text(text, select)
  self.doc:remove(1, 1, math.huge, math.huge)
  self.doc:text_input(text)
  if select then
    self.doc:set_selection(math.huge, math.huge, 1, 1)
  end
end

function TextView:get_gutter_width()
  return self.gutter_width or 0
end

function TextView:get_line_height()
  return math.floor(self:get_font():get_height() * 1.2)
end

function TextView:draw_line_gutter(idx, x, y)
  if self.hide_lines_gutter then
    return
  end
  TextView.super.draw_line_gutter(self, idx, x, y)
end

function TextView:draw_line_highlight()
  -- no-op function to disable this functionality
end

function TextView:draw_line_text(line, x, y)
  if self.subparent.password then
    local text = self.doc.lines[line] or ""
    local ty = y + self:get_line_text_y_offset()
    renderer.draw_text(
      self:get_font(),
      password_text(text),
      x,
      ty,
      style.syntax["normal"]
    )
    local placeholder = self.subparent.placeholder or ""
    if placeholder ~= "" and #text < 2 then
      renderer.draw_text(self:get_font(), placeholder, x, ty, style.dim)
    end
    return self:get_line_height()
  end

  TextView.super.draw_line_text(self, line, x, y)
  local placeholder = self.subparent.placeholder or ""
  if placeholder ~= "" and #self.doc.lines[line] < 2 then
    renderer.draw_text(self:get_font(), placeholder, x, y, style.dim)
  end
end

function TextView:get_col_x_offset(line, col)
  if self.subparent.password then
    local text = self.doc.lines[line] or ""
    return self:get_font():get_width(PASSWORD_CHAR)
      * password_chars_before_col(text, col)
  end
  return TextView.super.get_col_x_offset(self, line, col)
end

function TextView:get_x_offset_col(line, x)
  if self.subparent.password then
    local text = password_visible_text(self.doc.lines[line] or "")
    local char_width = self:get_font():get_width(PASSWORD_CHAR)
    if char_width <= 0 then return 1 end
    local offset = 0
    local col = 1
    for char in text:ugmatch(".") do
      if x <= offset + (char_width / 2) then
        return col
      end
      offset = offset + char_width
      col = col + #char
    end
    return col
  end
  return TextView.super.get_x_offset_col(self, line, x)
end

-- Overwrite this function just to disable the core.push_clip_rect
function TextView:draw()
  self:draw_background(style.background)
  local _, indent_size = self.doc:get_indent_info()
  self:get_font():set_tab_size(indent_size)

  local minline, maxline = self:get_visible_line_range()
  local lh = self:get_line_height()

  local x, y = self:get_line_screen_position(minline)
  for i = minline, maxline do
    self:draw_line_gutter(i, self.position.x, y)
    y = y + lh
  end

  x, y = self:get_line_screen_position(minline)
  for i = minline, maxline do
    self:draw_line_body(i, x, y)
    y = y + lh
  end
  self:draw_overlay()

  self:draw_scrollbar()
end

---@class widget.textbox : widget
---@overload fun(parent?:widget, text?:string, placeholder?:string, options?:table):widget.textbox
---@field textview widget.textbox.TextView
---@field placeholder string
---@field password boolean
local TextBox = Widget:extend()

function TextBox:new(parent, text, placeholder, options)
  TextBox.super.new(self, parent)
  self.type_name = "widget.textbox"
  self.textview = TextView(parent, self) -- allow finding containing parent
  self.textview.name = self:get_name()
  self.size.x = 200 + (style.padding.x * 2)
  self.textview.size.x = math.max(0, self.size.x - style.padding.x)
  self.size.y = self:get_font():get_height() + (style.padding.y * 2)
  self.placeholder = placeholder or ""
  -- this widget is for text input
  self.input_text = true
  self.cursor = "ibeam"
  self.active = false
  self.password = options and options.password or false

  if text ~= "" then
    self.textview:set_text(text)
  end

  local this = self

  function self.textview.doc:on_text_change()
    this:on_change(this:get_text())
  end

  -- more granular listening of text changing events
  local doc_raw_insert = self.textview.doc.raw_insert
  function self.textview.doc:raw_insert(...)
    doc_raw_insert(self, ...)
    this:on_text_change("insert", ...)
  end

  local doc_raw_remove = self.textview.doc.raw_remove
  function self.textview.doc:raw_remove(...)
    doc_raw_remove(self, ...)
    this:on_text_change("remove", ...)
  end
end

---@param width integer
function TextBox:set_size(width)
  TextBox.super.set_size(
    self,
    width,
    self:get_font():get_height() + (style.padding.y * 2)
  )
  self.textview.size.x = math.max(0, self.size.x - style.padding.x)
end

--- Get the text displayed on the textbox.
---@return string
function TextBox:get_text()
  return self.textview:get_text()
end

--- Set the text displayed on the textbox.
---@param text string
---@param select? boolean
function TextBox:set_text(text, select)
  self.textview:set_text(text, select)
end

---Enable or disable password display mode.
---@param enabled boolean
function TextBox:set_password_mode(enabled)
  self.password = enabled
end

---Get whether password display mode is enabled.
---@return boolean
function TextBox:get_password_mode()
  return self.password
end

--
-- Events
--

function TextBox:on_mouse_pressed(button, x, y, clicks)
  if not TextBox.super.on_mouse_pressed(self, button, x, y, clicks) then return false end
  if button ~= "left" then return true end

  if self.parent then
    self.parent:swap_active_child(self)
  else
    self.prev_view = self.prev_view or self.outside_view or core.active_view
    self.outside_view = nil
  end
  core.set_active_view(self.textview)
  self:activate()
  self.mouse.x, self.mouse.y = x, y
  self:capture_mouse(false, button)
  self.textview:on_mouse_pressed(button, x, y, clicks)

  -- Padding belongs to the input too; resolve it at the nearest text edge.
  local view = self.textview
  x = common.clamp(x, view.position.x, view.position.x + math.max(1, view.size.x) - 1)
  y = view.position.y + math.max(1, view.size.y) / 2
  local cmd = keymap.modkeys.shift and "doc:select-to-cursor"
    or clicks >= 3 and "doc:set-cursor-line"
    or clicks == 2 and "doc:set-cursor-word"
    or "doc:set-cursor"
  command.perform(cmd, x, y)
  return true
end

function TextBox:on_mouse_released(button, x, y)
  if self.captured_button and self.captured_button ~= button then return false end
  local handled = TextBox.super.on_mouse_released(self, button, x, y)
  if handled then self.textview:on_mouse_released(button, x, y) end
  return handled
end

function TextBox:on_mouse_capture_lost()
  TextBox.super.on_mouse_capture_lost(self)
  self.textview:on_mouse_released("left", self.mouse.x, self.mouse.y)
end

function TextBox:on_mouse_moved(x, y, dx, dy)
  local handled = TextBox.super.on_mouse_moved(self, x, y, dx, dy)
  if self.textview.mouse_selecting or handled and (self.active or core.active_view == self.textview) then
    self.textview:on_mouse_moved(x, y, dx, dy)
    return true
  end
  return handled
end

function TextBox:activate()
  self.hover_border = style.caret
  self.active = true
  core.request_cursor("ibeam")
end

function TextBox:deactivate()
  self.hover_border = nil
  self:release_mouse()
  self.textview:on_mouse_released("left", self.mouse.x, self.mouse.y)
  self.active = false
  core.request_cursor("arrow")
end

function TextBox:on_text_input(text)
  TextBox.super.on_text_input(self, text)
  self.textview:on_text_input(text)
  return true
end

---Event fired on any text change event.
---@param action string Can be "insert" or "remove",
---insert arguments (see Doc:raw_insert):
---  line, col, text, undo_stack, time
---remove arguments (see Doc:raw_remove):
---  line1, col1, line2, col2, undo_stack, time
---@diagnostic disable-next-line
function TextBox:on_text_change(action, ...) end

function TextBox:update()
  if not TextBox.super.update(self) then return false end

  self.border.color = self.hover_border or style.text

  if
    self.textview.mouse_selecting
    or
    (self.active and self:mouse_on_top(self.mouse.x, self.mouse.y))
  then
    core.request_cursor("ibeam")
  end

  self.textview.position.x = self.position.x + (style.padding.x / 2)
  self.textview.position.y = self.position.y - (style.padding.y/2.5)
  self.textview.size.x = math.max(0, self.size.x - style.padding.x)
  self.textview.size.y = self.size.y - (style.padding.y * 2)

  -- Keep extending at an edge while the pointer is stationary and X scrolls.
  if self.textview.mouse_selecting and self.captured_button == "left"
    and core.active_view == self.textview
    and (self.mouse.x < self.textview.position.x
      or self.mouse.x > self.textview.position.x + self.textview.size.x)
  then
    self.textview:on_mouse_moved(self.mouse.x, self.mouse.y, 0, 0)
  end
  self.textview:update()

  self:set_size(nil, self:get_font():get_height() + (style.padding.y * 2))

  return true
end

function TextBox:draw()
  if not TextBox.super.draw(self) then return false end

  core.push_clip_rect(
    self.position.x,
    self.position.y,
    self.size.x,
    self.size.y
  )
  self.textview:draw()
  core.pop_clip_rect()

  return true
end


return TextBox
