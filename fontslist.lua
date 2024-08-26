--
-- FontsList Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--
local style = require "core.style"
local Widget = require "widget"
local Button = require "widget.button"
local ListBox = require "widget.listbox"
local FontDialog = require "widget.fontdialog"
local MessageBox = require "widget.messagebox"

---@class widget.fontslist.font : widget
---@field name string
---@field path string

---@class widget.fontslist : widget
---@overload fun(parent?:widget):widget.fontslist
---@field list widget.listbox
---@field add widget.button
---@field remove widget.button
---@field up widget.button
---@field down widget.button
---@field options renderer.fontoptions
---@field private dialog boolean
local FontsList = Widget:extend()

---Constructor
---@param parent widget
function FontsList:new(parent)
  FontsList.super.new(self, parent)

  self.type_name = "widget.fontslist"

  self.border.width = 0

  self.dialog = false

  self.options = {}

  self.list = ListBox(self)

  local this = self

  function self.list:on_mouse_pressed(button, x, y, clicks)
    if not ListBox.on_mouse_pressed(self, button, x, y, clicks) then
      return false
    end

    if clicks == 2 and not this.dialog then
      this.dialog = true
      local selected = this.list:get_selected()
      local fontdata = this.list:get_row_data(selected)
      ---@type widget.inputdialog
      local font = FontDialog(fontdata, this:get_options())
      function font:on_save(fontdata, options)
        this:set_options(options)
        this:edit_font(selected, fontdata)
      end
      function font:on_close()
        FontDialog.on_close(self)
        self:destroy()
        this.dialog = false
      end
      font:show()
    end

    return true
  end

  self.add = Button(self, "Add")
  self.add:set_icon("B")
  function self.add:on_click()
    if #this.list.rows > 9 then
      MessageBox.error("Max Fonts Reached", "Only a maximum of ten fonts can be added.")
      return
    end
    if not this.dialog then
      this.dialog = true
      ---@type widget.inputdialog
      local font = FontDialog(nil, this:get_options())
      function font:on_save(fontdata, options)
        this:set_options(options)
        this:add_font(fontdata)
      end
      function font:on_close()
        FontDialog.on_close(self)
        self:destroy()
        this.dialog = false
      end
      font:show()
    end
  end

  self.remove = Button(self, "Remove")
  self.remove:set_icon("C")
  function self.remove:on_click()
    local selected = this.list:get_selected()
    if selected then
      if #this.list.rows > 1 then
        this:remove_font(selected)
      else
        MessageBox.error("Font required", "A minimum of one font is needed")
      end
    else
      MessageBox.error("No font selected", "Please select a font to remove")
    end
  end

  self.up = Button(self, "")
  self.up:set_icon("<")
  self.up:set_tooltip("increase font priority")
  function self.up:on_click()
    local selected = this.list:get_selected()
    if selected then
      this.list:move_row_up(selected)
      this:on_change()
    else
      MessageBox.error("No font selected", "Please select a font to move")
    end
  end

  self.down = Button(self, "")
  self.down:set_icon(">")
  self.down:set_tooltip("decrease font priority")
  function self.down:on_click()
    local selected = this.list:get_selected()
    if selected then
      this.list:move_row_down(selected)
      this:on_change()
    else
      MessageBox.error("No font selected", "Please select a font to move")
    end
  end
end

---Add a new font into the list.
---@param font widget.fontslist.font
function FontsList:add_font(font)
  self.list:add_row({font.name}, font)
  self.list:set_visible_rows()
  self:on_change()
end

---Edit an existing font on the list.
---@param idx integer
---@param font widget.fontslist.font
function FontsList:edit_font(idx, font)
  self.list:set_row(idx, {font.name})
  self.list:set_row_data(idx, font)
  self:on_change()
end

---Remove the given font from the list.
---@param idx integer
function FontsList:remove_font(idx)
  self.list:remove_row(idx)
  self:on_change()
end

---Return the fonts from the list.
---@return table<integer, string>
function FontsList:get_fonts()
  local output = {}
  local count = #self.list.rows
  for i=1, count, 1 do
    table.insert(output, self.list:get_row_data(i))
  end
  return output
end

---Set the global options for the fonts group
---@param options renderer.fontoptions
function FontsList:set_options(options)
  self.options = options
end

---Get the global options for the font group
---@return renderer.fontoptions
function FontsList:get_options()
  return self.options
end

function FontsList:update_size_position()
  FontsList.super.update_size_position(self)

  local size = self:get_size()

  size.x = self.add:get_width()
    + (style.padding.x / 2) + self.remove:get_width()
    + (style.padding.x / 2) + self.up:get_width()
    + (style.padding.x / 2) + self.down:get_width() + (50 * SCALE)

  self.list:set_position(0, 0)

  self.list:set_size(
    size.x,
    self.add:get_height() * 3 - (style.padding.y * 2)
  )

  self.add:set_position(0, self.list:get_bottom() + style.padding.y)

  self.remove:set_position(
    self.add:get_right() + (style.padding.x / 2),
    self.list:get_bottom() + style.padding.y
  )

  self.up:set_position(
    self.remove:get_right() + (style.padding.x / 2),
    self.list:get_bottom() + style.padding.y
  )

  self.down:set_position(
    self.up:get_right() + (style.padding.x / 2),
    self.list:get_bottom() + style.padding.y
  )

  size.y = self.down:get_bottom()
end


return FontsList
