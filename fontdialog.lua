--
-- Font Dialog Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local command = require "core.command"
local style = require "core.style"
local Button = require "widget.button"
local CheckBox = require "widget.checkbox"
local NumberBox = require "widget.numberbox"
local Dialog = require "widget.dialog"
local Label = require "widget.label"
local Line = require "widget.line"
local SelectBox = require "widget.selectbox"
local MessageBox = require "widget.messagebox"
local Fonts = require "widget.fonts"

---@class widget.fontdialog : widget.dialog
---@field fontdata widget.fontslist.font
---@field preview widget.label
---@field choose widget.button
---@field font_size widget.numberbox
---@field line widget.line
---@field antialiasing widget.selectbox
---@field hinting widget.selectbox
---@field bold widget.checkbox
---@field italic widget.checkbox
---@field underline widget.checkbox
---@field save widget.button
---@field cancel widget.button
local FontDialog = Dialog:extend()

---Constructor
---@param font? widget.fontslist.font
---@param options? renderer.fontoptions
function FontDialog:new(font, options)
  FontDialog.super.new(self, "Font Selector")

  self.selected = nil

  local this = self

  self.preview = Label(self.panel, "No Font Selected")
  self.preview.border.width = 1
  self.preview.clickable = true
  self.preview:set_size(100, 100)
  function self.preview:on_mouse_enter(...)
    Label.super.on_mouse_enter(self, ...)
    self.border.color = style.caret
  end
  function self.preview:on_mouse_leave(...)
    Label.super.on_mouse_leave(self, ...)
    self.border.color = style.text
  end

  self.choose = Button(self.panel, "Choose a Font")
  self.choose:set_icon("D")
  function self.choose:on_click()
    Fonts.show_picker(function(name, path)
      local fontdata = {name = name, path = path}
      this:set_font(fontdata)
      this:update_preview()
    end)
  end

  self.font_size = NumberBox(self.panel, 15, 5)
  function self.font_size:on_change()
    this:update_preview()
  end

  self.line = Line(self.panel)

  self.antialiasing = SelectBox(self.panel, "antialiasing")
  self.antialiasing:add_option("None", "none")
  self.antialiasing:add_option("Grayscale", "grayscale")
  self.antialiasing:add_option("Subpixel", "subpixel")
  function self.antialiasing:on_selected()
    this:update_preview()
  end

  self.hinting = SelectBox(self.panel, "hinting")
  self.hinting:add_option("None", "none")
  self.hinting:add_option("Slight", "slight")
  self.hinting:add_option("full", "full")
  function self.hinting:on_selected()
    this:update_preview()
  end

  self.bold = CheckBox(self.panel, "Bold")
  function self.bold:on_checked()
    this:update_preview()
  end
  self.italic = CheckBox(self.panel, "Italic")
  function self.italic:on_checked()
    this:update_preview()
  end
  self.underline = CheckBox(self.panel, "Underline")
  function self.underline:on_checked()
    this:update_preview()
  end

  self.save = Button(self.panel, "Save")
  self.save:set_icon("S")
  function self.save:on_click()
    if this.fontdata and this.fontdata.name then
      this:on_save(this:get_font(), this:get_options())
      this:on_close()
    else
      MessageBox.error("No font selected", "Please select a font")
    end
  end

  self.cancel = Button(self.panel, "Cancel")
  self.cancel:set_icon("C")
  function self.cancel:on_click()
    this:on_close()
  end

  if font then
    self:set_font(font)
    if not options then
      self:update_preview()
    end
  end
  if options then
    self:set_options(options)
  end
end

function FontDialog:update_preview()
  local options = self:get_options()

  if self.fontdata and self.fontdata.path then
    self.preview.font = renderer.font.load(
      self.fontdata.path, options.size * SCALE, options
    )
    if self.fontdata.name then
      self.preview:set_label(self.fontdata.name)
    end
  else
    self.preview.font = renderer.font.load(
      DATADIR .. "/fonts/FiraSans-Regular.ttf",
      options.size * SCALE,
      options
    )
  end
end

---@param font widget.fontslist.font
function FontDialog:set_font(font)
  self.fontdata = font
  if self.fontdata.name then
    self.preview:set_label(self.fontdata.name)
  end
end

---@return widget.fontslist.font
function FontDialog:get_font()
  return self.fontdata
end

---@param options renderer.fontoptions
function FontDialog:set_options(options)
  if options.size then
    self.font_size:set_value(tonumber(options.size) or 15)
  end

  if options.antialiasing then
    if options.antialiasing == "none" then
      self.antialiasing:set_selected(1)
    elseif options.antialiasing == "grayscale" then
      self.antialiasing:set_selected(2)
    elseif options.antialiasing == "subpixel" then
      self.antialiasing:set_selected(3)
    end
  end

  if options.hinting then
    if options.hinting == "none" then
      self.hinting:set_selected(1)
    elseif options.hinting == "slight"then
      self.hinting:set_selected(2)
    elseif options.hinting == "full" then
      self.hinting:set_selected(3)
    end
  end

  if options.bold ~= nil then
    self.bold:set_checked(options.bold)
  end
  if options.italic ~= nil then
    self.italic:set_checked(options.italic)
  end
  if options.underline ~= nil then
    self.underline:set_checked(options.underline)
  end
end

---@return renderer.fontoptions
function FontDialog:get_options()
  return {
    size = self.font_size:get_value(),
    antialiasing = self.antialiasing:get_selected_data() or "none",
    hinting = self.hinting:get_selected_data() or "none",
    bold = self.bold:is_checked(),
    italic = self.italic:is_checked(),
    underline = self.underline:is_checked()
  }
end

---Called when the user clicks on save
---@param font widget.fontslist.font
---@param options renderer.fontoptions
function FontDialog:on_save(font, options) end

function FontDialog:update()
  if not FontDialog.super.update(self) then return false end

  self.preview:set_position(style.padding.x/2, style.padding.y/2)

  self.choose:set_position(
    style.padding.x/2,
    self.preview:get_bottom() + style.padding.y
  )

  self.font_size:set_position(
    self.choose:get_right() + (style.padding.x/2),
    self.preview:get_bottom() + style.padding.y
  )

  self.line:set_position(
    0,
    self.font_size:get_bottom() + style.padding.y
  )

  self.antialiasing:set_position(
    style.padding.x/2,
    self.line:get_bottom() + style.padding.y
  )
  self.hinting:set_position(
    self.antialiasing:get_right() + (style.padding.x/2),
    self.line:get_bottom() + style.padding.y
  )

  self.bold:set_position(
    style.padding.x/2,
    self.hinting:get_bottom() + style.padding.y
  )
  self.italic:set_position(
    self.bold:get_right() + style.padding.x,
    self.hinting:get_bottom() + style.padding.y
  )
  self.underline:set_position(
    self.italic:get_right() + style.padding.x,
    self.hinting:get_bottom() + style.padding.y
  )

  self.save:set_position(
    style.padding.x/2,
    self.underline:get_bottom() + style.padding.y
  )
  self.cancel:set_position(
    self.save:get_right() + style.padding.x,
    self.underline:get_bottom() + style.padding.y
  )

  self.panel.size.x = self.panel:get_real_width() + style.padding.x
  self.panel.size.y = self.panel:get_real_height()
  self.size.x = self:get_real_width() - (style.padding.x / 2)
  self.size.y = self:get_real_height() + (style.padding.y / 2)

  self.line:set_width(self.size.x - style.padding.x)

  self.preview:set_size(
    self.size.x - style.padding.x - (self.preview.border.width * 2),
    self.preview.size.y
  )

  return true
end


return FontDialog