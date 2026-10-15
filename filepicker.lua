local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local Widget = require "widget"
local Button = require "widget.button"
local Label = require "widget.label"
local TextBox = require "widget.textbox"

---@class widget.filepicker : widget
---@overload fun(parent?:widget, path?:string):widget.filepicker
---@field public pick_mode integer
---@field public filters table<integer,string>
---@field public picker_title? string
---@field private editable boolean
---@field private path string
---@field private file widget.label
---@field private textbox? widget.textbox
---@field private setting_path? boolean
---@field private button widget.button
local FilePicker = Widget:extend()

---Operation modes for the file picker.
---@type table<string,integer>
FilePicker.mode = {
  ---Opens file browser the selected file does not has to exist.
  FILE = 1,
  ---Opens file browser the selected file has to exist.
  FILE_EXISTS = 2,
  ---Opens directory browser the selected directory does not has to exist.
  DIRECTORY = 4,
  ---Opens directory browser the selected directory has to exist.
  DIRECTORY_EXISTS = 8
}

---@param text string
---@return string[]
local function suggest_directory(text)
  text = common.home_expand(text)
  if not common.is_absolute_path(text) then
    text = core.root_project().path .. PATHSEP .. text
  end
  return common.home_encode_list(
    common.dir_path_suggest(text, core.root_project().path)
  )
end

---@param path string
local function check_directory_path(path)
  local abs_path = core.project_absolute_path(path)
  local info = abs_path and system.get_file_info(abs_path)
  if not info or info.type ~= 'dir' then return nil end
  return abs_path
end

---@param str string
---@param find string
---@param replace string
local function str_replace(str, find, replace)
  local start, ending = str:find(find, 1, true)
  if start == 1 then
    return replace .. str:sub(ending + 1)
  else
    return str:sub(1, start - 1) .. replace .. str:sub(ending + 1)
  end
end

---@alias widget.filepicker.modes
---| `FilePicker.mode.FILE`
---| `FilePicker.mode.FILE_EXISTS`
---| `FilePicker.mode.DIRECTORY`
---| `FilePicker.mode.DIRECTORY_EXISTS`

---Constructor
---@param parent widget
---@param path? string
function FilePicker:new(parent, path)
  FilePicker.super.new(self, parent)

  local this = self

  self.type_name = "widget.filepicker"

  self.filters = {}
  self.border.width = 0
  self.pick_mode = FilePicker.mode.FILE
  self.editable = false

  self.file = Label(self, "")
  self.file.clickable = true
  self.file:set_border_width(1)
  function self.file:on_click(button)
    if button == "left" then
      this:show_picker()
    end
  end
  function self.file:on_mouse_enter(...)
    Label.super.on_mouse_enter(self, ...)
    self.border.color = style.caret
  end
  function self.file:on_mouse_leave(...)
    Label.super.on_mouse_leave(self, ...)
    self.border.color = style.text
  end

  self.button = Button(self, "")
  self.button:set_icon("D")
  self.button:set_tooltip("open file browser")
  function self.button:on_click(button)
    if button == "left" then
      this:show_picker()
    end
  end

  local label_width = self.file:get_width()
  if label_width <= 10 then
    label_width = 200 + (self.file.border.width * 2)
    self.file:set_size(
      200, self.button:get_height() - self.button.border.width * 2
    )
  end

  self:set_size(
    label_width + self.button:get_width(),
    math.max(self.file:get_height(), self.button:get_height())
  )

  self:set_path(path)
end

---Set the filepicker size
---@param width? number
---@param height? number
function FilePicker:set_size(width, height)
  FilePicker.super.set_size(self, width, height)

  local input = self.editable and self.textbox or self.file
  local gap = self.editable and style.padding.x / 2 or 0
  input:set_position(0, 0)
  input:set_size(
    math.max(1, self:get_width() - self.button:get_width() - gap),
    self.button:get_height()
  )

  self.button:set_position(input:get_right() + gap, 0)

  self:get_size().y = math.max(
    input:get_height(),
    self.button:get_height()
    -- something is off on calculation since adding border width should not
    -- be needed to display whole rendered control at all...
  ) + self.button.border.width
end

---Enable direct text editing; the default displays a clickable path label.
---@param enabled boolean
function FilePicker:set_editable(enabled)
  self.editable = enabled == true
  if self.editable then
    if not self.textbox then
      self.textbox = TextBox(self, self.path)
      self.textbox.on_change = function(_, text)
        if not self.setting_path then
          self:set_path(text)
          self:on_change(self:get_path())
        end
      end
    end
    self.file:hide()
    self.textbox:show()
  else
    self.file:show()
    if self.textbox then self.textbox:hide() end
  end
  self:set_mode(self.pick_mode)
  self:set_size(self:get_width(), self:get_height())
  self:schedule_update()
end

---Add a lua pattern to the filters list
---@param pattern string
function FilePicker:add_filter(pattern)
  table.insert(self.filters, pattern)
end

---Clear the filters list
function FilePicker:clear_filters()
  self.filters = {}
end

---Set the operation mode for the file picker.
---@param mode widget.filepicker.modes | string | integer
function FilePicker:set_mode(mode)
  if type(mode) == "string" then
    ---@type integer
    local intmode = FilePicker.mode[mode:upper()]
    self.pick_mode = intmode
  else
    self.pick_mode = mode
  end
  local file = self.pick_mode == FilePicker.mode.FILE
    or self.pick_mode == FilePicker.mode.FILE_EXISTS
  self.button:set_tooltip(file and "Choose file" or "Choose directory")
  if self.textbox then
    self.textbox.placeholder = file and "File path..." or "Directory path..."
  end
end

---Set the full path including directory and filename.
---@param path? string
function FilePicker:set_path(path)
  if path then
    self.path = path or ""
    if common.path_belongs_to(path, core.root_project().path) then
      self.file.label = path ~= "" and
        common.relative_path(core.root_project().path, path)
        or
        ""
    else
      self.file.label = path
    end
  else
    self.path = ""
    self.file.label = ""
  end
  if self.textbox and self.textbox:get_text() ~= self.path then
    self.setting_path = true
    self.textbox:set_text(self.path)
    self.setting_path = false
  end
end

---Get the full path including directory and filename.
---@return string | nil
function FilePicker:get_path()
  if self.path ~= "" then
    return self.path
  end
  return nil
end

---Get the full path relative to current project dir or absolute if it doesn't
---belongs to the current project directory.
---@return string
function FilePicker:get_relative_path()
  if
    self.path ~= ""
    and
    common.path_belongs_to(self.path, core.root_project().path)
  then
    return common.relative_path(core.root_project().path, self.path)
  end
  return self.path or ""
end

---Set the filename part only.
---@param name string
function FilePicker:set_filename(name)
  local dir_part = common.dirname(self.path)
  if dir_part then
    self:set_path(dir_part .. PATHSEP .. name)
  else
    self:set_path(name)
  end
end

---Get the filename part only.
---@return string | nil
function FilePicker:get_filename()
  local dir_part = common.dirname(self.path)
  if dir_part then
    local filename = str_replace(self.path, dir_part .. PATHSEP, "")
    return filename
  elseif self.path ~= "" then
    return self.path
  end
  return nil
end

---Set the directory part only.
---@param dir string
function FilePicker:set_directory(dir)
  local filename = self:get_filename()
  if filename then
    self:set_path(dir:gsub("[\\/]$", "") .. PATHSEP .. filename)
  else
    self:set_path(dir:gsub("[\\/]$", ""))
  end
end

---Get the directory part only.
---@return string | nil
function FilePicker:get_directory()
  if self.path ~= "" then
    local dir_part = common.dirname(self.path)
    if dir_part then return dir_part end
  end
  return nil
end

---Filter a list of directories by applying currently set filters.
---@param self widget.filepicker
---@param list table<integer, string>
---@return table<integer,string>
local function filter(self, list)
  for i=1, #list do
    local path = common.home_expand(list[i])
    if common.path_belongs_to(path, core.root_project().path) then
      list[i] = common.relative_path(core.root_project().path, path)
    end
  end
  if #self.filters > 0 then
    local new_list = {}
    for _, value in ipairs(list) do
      if common.match_pattern(value, self.filters) then
        table.insert(new_list, value)
      elseif
        self.pick_mode == FilePicker.mode.FILE
        or
        self.pick_mode == FilePicker.mode.FILE_EXISTS
      then
        local path = common.home_expand(value)
        local abs_path = check_directory_path(path)
        if abs_path then
          table.insert(new_list, value)
        end
      end
    end
    return new_list
  end
  return list
end

---@param self widget.filepicker
local function file_picker_options(self)
  return {
    text = self:get_relative_path(),
    submit = function(text)
      ---@type string
      local filename = text
      local dirname = common.dirname(common.home_expand(text))
      if dirname then
        filename = common.home_expand(text)
        filename = core.project_absolute_path(dirname)
          .. PATHSEP
          .. str_replace(filename, dirname .. PATHSEP, "")
      elseif filename ~= "" then
        filename = core.root_project().path .. PATHSEP .. filename
      end
      self:set_path(filename)
      self:on_change(filename ~= "" and filename or nil)
    end,
    suggest = function (text)
      return filter(
        self,
        common.home_encode_list(
          common.path_suggest(
            common.home_expand(text), core.root_project().path
          )
        )
      )
    end,
    validate = function(text)
      if
        #self.filters > 0 and text ~= ""
        and
        not common.match_pattern(text, self.filters)
      then
        core.error(
          "File does not match the filters: %s",
          table.concat(self.filters, ", ")
        )
        return false
      end
      local filename = common.home_expand(text)
      local path_stat, err = system.get_file_info(filename)
      if path_stat and path_stat.type == 'dir' then
        core.error("Cannot open %s, is a folder", text)
        return false
      end
      if self.pick_mode == FilePicker.mode.FILE_EXISTS then
        if not path_stat then
          core.error("Cannot open file %s: %s", text, err)
          return false
        end
      else
        local dirname = common.dirname(filename)
        local dir_stat = dirname and system.get_file_info(dirname)
        if dirname and not dir_stat then
          core.error("Directory does not exists: %s", dirname)
          return false
        end
      end
      return true
    end,
  }
end

---@param self widget.filepicker
local function directory_picker_options(self)
  return {
    text = self:get_relative_path(),
    submit = function(text)
      local path = common.home_expand(text)
      local abs_path = check_directory_path(path)
      self:set_path(abs_path or text)
      self:on_change(abs_path or (text ~= "" and text or nil))
    end,
    suggest = function(text)
      return filter(self, suggest_directory(text))
    end,
    validate = function(text)
      if
        #self.filters > 0 and text ~= ""
        and
        not common.match_pattern(text, self.filters)
      then
        core.error(
          "Directory does not match the filters: %s",
          table.concat(self.filters, ", ")
        )
        return false
      end
      if self.pick_mode == FilePicker.mode.DIRECTORY_EXISTS then
        local path = common.home_expand(text)
        local abs_path = check_directory_path(path)
        if not abs_path then
          core.error("Cannot open directory %q", path)
          return false
        end
      end
      return true
    end
  }
end

---Browse with the command view or the editor's configured system picker.
function FilePicker:show_picker()
  local file = self.pick_mode == FilePicker.mode.FILE
    or self.pick_mode == FilePicker.mode.FILE_EXISTS
  local options = file and file_picker_options(self)
    or directory_picker_options(self)
  local title = self.picker_title
    or (file and "Choose File" or "Choose Directory")
  local open = core.open_directory_dialog
  if self.pick_mode == FilePicker.mode.FILE_EXISTS then
    open = core.open_file_dialog
  elseif file then
    open = core.save_file_dialog
  end
  if not config.use_system_file_picker or not open then
    core.command_view:enter(title, options)
    return
  end
  local destination = core.project_absolute_path(common.home_expand(self.path))
  local location = destination
  while location ~= "" do
    local info = system.get_file_info(location)
    if info and info.type == "dir" then break end
    local parent = common.dirname(location)
    if not parent or parent == location then
      location = ""
      break
    end
    location = parent
  end
  open(core.window, function(status, result)
    if status == "accept" then
      local path = type(result) == "table" and result[1] or result
      if path and options.validate(path) then options.submit(path) end
    elseif status == "error" then
      core.error("Error while opening dialog: %s", result or "")
    end
  end, {
    title = title,
    default_location = file and destination
      or location ~= "" and location or nil,
    allow_many = false,
  })
end

function FilePicker:update_size_position()
  FilePicker.super.update_size_position(self)
  self:set_size(
    self:get_width(),
    self.button:get_height()
  )
end

return FilePicker
