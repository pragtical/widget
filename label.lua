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

  if self.word_wrap and not self.wrapping and self.original_label then
    if type(text) == "string" then self.original_label = text end
  end

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
end

---@param self widget.label
local function word_wrap(self)
  if self.parent then
    local psize = self.parent:get_size()
    local lsize = self:get_size()
    if
      psize.x < lsize.x or (self.last_wrap_size ~= psize.x)
      and
      (
        (not self.original_label and type(self.label) == "string")
        or
        type(self.original_label) == "string"
      )
    then
      self.wrapping = true
      if type(self.original_label) ~= "string" then
        self.original_label = self.label
      end
      local words = {}
      for word in self.original_label:ugmatch("%S+") do
        table.insert(words, word)
      end
      local label = ""
      ---@type widget.styledtext
      local styledtext = {}
      for i=1, #words do
        local text = label .. (#label == 0 and "" or " ") .. words[i]
        self:set_label(text)
        local size = self:get_size()
        if size.x < psize.x - self:get_position().x then
          label = text
          if i == #words then
            table.insert(styledtext, label)
          end
        else
          table.insert(styledtext, label)
          table.insert(styledtext, Widget.NEWLINE)
          if i ~= #words then
            label = words[i]
          else
            table.insert(styledtext, words[i])
          end
        end
      end
      if #styledtext > 1 then
        self:set_label(styledtext)
      else
        self:set_label(self.original_label)
      end
      self.last_wrap_size = psize.x
      self.wrapping = false
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

function Label:update()
  if Label.super.update(self) and self.word_wrap then
    word_wrap(self)
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
