--
-- Label Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local style = require "core.style"
local Widget = require "widget"

---@class widget.label : widget
---@overload fun(parent:widget?, label?:string, word_wrap?:boolean):widget.label
---@field clickable boolean
---@field word_wrap boolean
local Label = Widget:extend()

---Constructor
---@param parent widget
---@param label string
---@param word_wrap? boolean
function Label:new(parent, label, word_wrap)
  Label.super.new(self, parent)
  self.type_name = "widget.label"
  self.clickable = false
  self.border.width = 0
  self.custom_size = {x = 0, y = 0}
  self.word_wrap = word_wrap or false
  self.wrapping = false
  self.original_label = nil
  self.last_wrap_size = 0

  self:set_label(label or "")
  self.default_height = true
end

---@param width? integer
---@param height? integer
function Label:set_size(width, height)
  Label.super.set_size(self, width, height)
  if width then self.custom_size.x = self:get_size().x end
  if height then
    self.custom_size.y = self:get_size().y
    self.default_height = false
  end
  if self.default_height then
    local _, content_height = self:get_content_size()
    Label.super.set_size(self, nil, content_height + self.border.width * 2)
  end
end

---Set the label text and recalculates the widget size.
---@param text string|widget.styledtext
function Label:set_label(text)
  Label.super.set_label(self, text)

  if not self.wrapping then
    self.original_label = type(text) == "string" and text or nil
    self.last_wrap_size = nil
  end

  local width, height = self:get_content_size()
  local size = self:get_size()
  if self.custom_size.x <= 0 then size.x = width end
  if self.default_height ~= false then
    size.y = height
  end
end

---Calculate the dimensions of the current label contents.
---@return number width
---@return number height
function Label:get_content_size()
  local width, height = 0, 0
  if type(self.label) == "table" then
    width, height = self:draw_styled_text(self.label, 0, 0, true)
  else
    local _, _, w, h = self:draw_text_multiline(
      self:get_font(), self.label, 0, 0, self.foreground_color or style.text, true
    )
    width, height = w, h
  end
  if self.border.width > 0 then
    width = width + style.padding.x
    height = height + style.padding.y
  end
  return width, height
end

---@return number
function Label:get_scrollable_size()
  if not self.scrollable then return self:get_size().y end
  local _, height = self:get_content_size()
  return math.max(self:get_size().y, height)
end

---@return number
function Label:get_h_scrollable_size()
  if not self.scrollable then return self:get_size().x end
  local width = self:get_content_size()
  return math.max(self:get_size().x, width)
end

---Disable or enable word wrap on the label when the width exceeds the
---parent width. Only works for string labels, no support for styled text
---is implemented at the moment.
---@param value? boolean
function Label:toggle_word_wrap(value)
  if type(value) == "boolean" then
    self.word_wrap = value
  else
    self.word_wrap = not self.word_wrap
  end
  if not self.word_wrap and self.original_label then
    self:set_label(self.original_label)
  end
  self.last_wrap_size = nil
  core.redraw = true
end

---@param self widget.label
local function word_wrap(self)
  if type(self.original_label) ~= "string" then
    return
  end
  local width = self.custom_size.x
  if width <= 0 and self.parent then
    -- get_position() can re-enter scale updates while layout is running.
    width = self.parent:get_size().x - (self.position.rx or 0)
  end
  if width <= 0 then
    return
  end
  if self.border.width > 0 then
    width = width - style.padding.x
  end
  width = math.max(1, width)
  local font = self:get_font()
  if
    self.last_wrap_size == width
    and self.last_wrap_font == font
    and self.last_wrap_font_size == font:get_size()
  then
    return
  end
  local lines = {}
  for paragraph in (self.original_label .. "\n"):gmatch "([^\n]*)\n" do
    local line = paragraph:match "^%s*" or ""
    for word in paragraph:gmatch "%S+" do
      local candidate = line .. (line:match "%S" and " " or "") .. word
      if line:match "%S" and font:get_width(candidate) > width then
        lines[#lines + 1], line = line, word
      else
        line = candidate
      end
    end
    lines[#lines + 1] = line
  end
  local styled = {}
  for i, line in ipairs(lines) do
    if i > 1 then
      styled[#styled + 1] = Widget.NEWLINE
    end
    styled[#styled + 1] = line
  end
  self.wrapping = true
  self:set_label(styled)
  self.wrapping = false
  if self.default_height then
    self.size.y = #lines * font:get_height()
  end
  self.last_wrap_size, self.last_wrap_font = width, font
  self.last_wrap_font_size = font:get_size()
end

---Reflow a plain-text label immediately after changing its available width.
function Label:wrap_text()
  if self.word_wrap then
    word_wrap(self)
  end
end

function Label:update_size_position()
  Label.super.update_size_position(self)
  if self.custom_size.x <= 0 then
    if self.word_wrap and self.original_label then
      self.last_wrap_size = nil
      self:wrap_text()
    else
      self:set_label(self.label)
    end
  end
  if self.border.width > 0 then
    self.scrollable = true
  end
  if self.scrollable then
    self.clickable = true
  end
end

function Label:update()
  local updated = Label.super.update(self)
  if updated and self.word_wrap then
    word_wrap(self)
  end
  return updated
end

function Label:draw()
  if not self:is_visible() then return false end

  self:draw_border()

  local px = self.border.width > 0 and (style.padding.x / 2) or 0
  local py = self.border.width > 0 and (style.padding.y / 2) or 0

  local ox, oy = self:get_content_offset()
  local posx, posy = ox + px, oy + py

  core.push_clip_rect(
    self.position.x,
    self.position.y,
    self.size.x,
    self.size.y
  )

  if type(self.label) == "table" then
    self:draw_styled_text(self.label, posx, posy)
  else
    self:draw_text_multiline(
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
