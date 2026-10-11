--
-- WidgetList Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local Widget = require "widget"
local ScrollBar = require "widget.scrollbar"

local function scrollbar_gutter(scrollbar)
  return math.max(
    scrollbar.contracted_size or style.scrollbar_size,
    scrollbar.expanded_size or style.expanded_scrollbar_size
  ) + SCALE
end

local ListScrollBar = ScrollBar:extend()

function ListScrollBar:_overlaps_normal(x, y)
  local rect = self.normal_rect
  -- Keep the hover/click margin inside the gutter, clear of row controls.
  if x < rect.across + rect.across_size - scrollbar_gutter(self) then return end
  return ListScrollBar.super._overlaps_normal(self, x, y)
end

---@class widget.widgetlist.item.properties
---@field stretch? number Relative share of the remaining row width.
---@field min_size? {x?:number, y?:number} Minimum child dimensions.
---@field padding? {top?:number, right?:number, bottom?:number, left?:number}

---@class widget.widgetlist.item : widget
---@field data any
---@field private layout_childs widget[]
---@field private layout_sizes table<widget, {x:number, y:number}>
local WidgetListItem = Widget:extend()

---@param parent widget.widgetlist
---@param data any
function WidgetListItem:new(parent, data)
  WidgetListItem.super.new(self, parent)
  self.type_name = "widget.widgetlist.item"
  self.border.width = 0
  self.render_background = false
  self.data = data
  self.layout_childs = {}
  self.layout_sizes = {}
  self.padding = {
    x = style.padding.x / (2 * SCALE),
    y = style.padding.y / (2 * SCALE)
  }
  self.spacing = style.padding.x / (2 * SCALE)
end

---@param child widget
function WidgetListItem:add_child(child)
  self.layout_childs[#self.layout_childs + 1] = child
  WidgetListItem.super.add_child(self, child)
end

---@param child widget
---@param properties? widget.widgetlist.item.properties
function WidgetListItem:set_child_properties(child, properties)
  child.widgetlist_properties = properties or {}
  self.perform_update_size_position = true
end

function WidgetListItem:update_size_position()
  WidgetListItem.super.update_size_position(self)

  local px = self.padding.x * SCALE
  local py = self.padding.y * SCALE
  local spacing = self.spacing * SCALE
  local available = math.max(0, self.size.x - px * 2)
  local fixed_width = 0
  local stretch_total = 0

  for idx, child in ipairs(self.layout_childs) do
    local properties = child.widgetlist_properties or {}
    local padding = properties.padding or {}
    local min_size = properties.min_size or {}
    local horizontal_padding = ((padding.left or 0) + (padding.right or 0)) * SCALE
    local stretch = math.max(0, properties.stretch or 0)
    if stretch > 0 then
      stretch_total = stretch_total + stretch
      fixed_width = fixed_width + (min_size.x or 0) * SCALE + horizontal_padding
    else
      fixed_width = fixed_width
        + math.max(child:get_width(), (min_size.x or 0) * SCALE)
        + horizontal_padding
    end
    if idx > 1 then fixed_width = fixed_width + spacing end
  end

  local remaining = math.max(0, available - fixed_width)
  local max_height = 0
  for _, child in ipairs(self.layout_childs) do
    local properties = child.widgetlist_properties or {}
    local padding = properties.padding or {}
    local min_size = properties.min_size or {}
    local top = (padding.top or 0) * SCALE
    local bottom = (padding.bottom or 0) * SCALE
    local stretch = math.max(0, properties.stretch or 0)
    local width
    if stretch > 0 and stretch_total > 0 then
      width = (min_size.x or 0) * SCALE + remaining * stretch / stretch_total
    else
      width = math.max(child:get_width(), (min_size.x or 0) * SCALE)
    end
    local height = math.max(child:get_height(), (min_size.y or 0) * SCALE)
    child:set_size(
      math.max(0, width),
      min_size.y and height or nil
    )
    max_height = math.max(max_height, child:get_height() + top + bottom)
  end

  self:set_size(nil, max_height + py * 2)
  local x = px
  for idx, child in ipairs(self.layout_childs) do
    local padding = (child.widgetlist_properties or {}).padding or {}
    local left = (padding.left or 0) * SCALE
    local right = (padding.right or 0) * SCALE
    local top = (padding.top or 0) * SCALE
    local bottom = (padding.bottom or 0) * SCALE
    local width, height = child:get_width(), child:get_height()
    if idx > 1 then x = x + spacing end
    child:set_position(
      x + left,
      py + top + math.max(0, (max_height - height - top - bottom) / 2)
    )
    x = x + width + left + right
    self.layout_sizes[child] = { x = width, y = height }
  end
end

function WidgetListItem:update()
  if not WidgetListItem.super.update(self) then return false end
  for _, child in ipairs(self.layout_childs) do
    local size = self.layout_sizes[child]
    if not size or size.x ~= child:get_width() or size.y ~= child:get_height() then
      self:update_size_position()
      break
    end
  end
  return true
end

function WidgetListItem:on_mouse_enter(...)
  WidgetListItem.super.on_mouse_enter(self, ...)
  self.hovered = true
end

function WidgetListItem:on_mouse_leave(...)
  WidgetListItem.super.on_mouse_leave(self, ...)
  self.hovered = false
end

function WidgetListItem:draw()
  if not self:is_visible() then return false end
  if self.hovered then
    -- Highlight the viewport, including the space reserved for the scrollbar.
    renderer.draw_rect(
      self.parent.position.x,
      self.position.y,
      self.parent.size.x,
      self.size.y,
      style.line_highlight
    )
  end
  return WidgetListItem.super.draw(self)
end

---@class widget.widgetlist.entry
---@field data any
---@field row widget.widgetlist.item
---@field filter_text string
---@field matched boolean
---@field y number
---@field private height number

---@class widget.widgetlist : widget
---@overload fun(parent?:widget):widget.widgetlist
---@field items widget.widgetlist.entry[]
---@field private content_height number
---@field private filter_value string|function|nil
---@field private layout_dirty boolean
---@field private previous_width number
---@field private previous_height number
---@field private previous_gutter number
---@field private previous_alignment string
---@field private visible_row_count integer|nil
local WidgetList = Widget:extend()

---@param parent? widget
function WidgetList:new(parent)
  WidgetList.super.new(self, parent)
  self.type_name = "widget.widgetlist"
  self.scrollable = true
  self.v_scrollbar = ListScrollBar(self, { direction = "v", alignment = "e" })
  self.items = {}
  self.content_height = 0
  self.filter_value = nil
  self.layout_dirty = true
  self.previous_width = -1
  self.previous_height = -1
  self.previous_gutter = -1
  self.previous_alignment = "e"
  self.visible_row_count = nil
  self:set_size(300, (self:get_font():get_height() + style.padding.y) * 6)
end

---@param data any
---@param builder? fun(row:widget.widgetlist.item, data:any)
---@param filter_text? string
---@return widget.widgetlist.item row
function WidgetList:add_item(data, builder, filter_text)
  local row = WidgetListItem(self, data)
  self.items[#self.items + 1] = {
    data = data,
    row = row,
    filter_text = filter_text or tostring(data),
    matched = true,
    y = 0,
    height = 0
  }
  if builder then builder(row, data) end
  self.layout_dirty = true
  return row
end

---@param index integer
---@return boolean removed
function WidgetList:remove_item(index)
  local entry = self.items[index]
  if not entry then return false end
  self:remove_child(entry.row)
  table.remove(self.items, index)
  self.layout_dirty = true
  return true
end

function WidgetList:clear()
  for index = #self.items, 1, -1 do
    self:remove_child(self.items[index].row)
  end
  self.items = {}
  self.content_height = 0
  self.layout_dirty = true
end

---@param index integer
---@return any data
---@return widget.widgetlist.item? row
function WidgetList:get_item(index)
  local entry = self.items[index]
  if entry then return entry.data, entry.row end
end

---@return fun():integer,any,widget.widgetlist.item
function WidgetList:each_item()
  local index = 0
  return function()
    index = index + 1
    local entry = self.items[index]
    if entry then return index, entry.data, entry.row end
  end
end

---@param match? string|fun(data:any, index:integer, text:string):boolean
function WidgetList:filter(match)
  self.filter_value = match
  self.layout_dirty = true
  self.scroll.y = 0
  self.scroll.to.y = 0
end

---@param count integer
function WidgetList:set_visible_row_count(count)
  self.visible_row_count = math.max(1, math.floor(count))
  self:relayout()
end

---@private
function WidgetList:update_visible_row_size()
  local count = self.visible_row_count
  if not count then return end
  local height = 0
  local visible = 0
  for _, entry in ipairs(self.items) do
    if entry.matched then
      height = height + entry.row:get_height()
      visible = visible + 1
      if visible == count then break end
    end
  end
  if visible < count then
    height = height
      + (count - visible) * (self:get_font():get_height() + style.padding.y)
  end
  self:set_size(nil, height + self.border.width * 2)
end

---@private
function WidgetList:get_scrollbar_gutter()
  if not self.scrollable or self.content_height <= self.size.y then return 0 end
  local scrollbar = self.v_scrollbar
  -- Leave one scaled pixel beside the expanded scrollbar.
  return math.min(self.size.x, scrollbar_gutter(scrollbar))
end

---@private
function WidgetList:layout_rows(gutter)
  local y = 0
  local x = self.v_scrollbar.alignment == "s" and gutter or 0
  local width = math.max(0, self.size.x - gutter)
  for _, entry in ipairs(self.items) do
    if entry.matched then
      entry.y = y
      entry.row:set_size(width)
      entry.row:set_position(x, y)
      entry.row:update_size_position()
      entry.height = entry.row:get_height()
      y = y + entry.height
    end
  end
  self.content_height = y
  self:update_visible_row_size()
end

---@private
function WidgetList:relayout()
  local match = self.filter_value
  for index, entry in ipairs(self.items) do
    local matched = true
    if type(match) == "function" then
      matched = match(entry.data, index, entry.filter_text) and true or false
    elseif type(match) == "string" and match ~= "" then
      matched = system.fuzzy_match(entry.filter_text, match, false) ~= nil
    end
    entry.matched = matched
    if not matched then
      entry.row.visible = false
    end
  end
  -- Measure without a gutter first, so shrinking or filtering can remove it.
  self:layout_rows(0)
  local gutter = self:get_scrollbar_gutter()
  if gutter > 0 then self:layout_rows(gutter) end
  self.layout_dirty = false
  self.previous_width = self.size.x
  self.previous_height = self.size.y
  self.previous_gutter = gutter
  self.previous_alignment = self.v_scrollbar.alignment
end

---@private
---@param update_new? boolean
function WidgetList:update_visible_items(update_new)
  local top = self.scroll.y
  local bottom = top + self.size.y
  for _, entry in ipairs(self.items) do
    local height = entry.row:get_height()
    local visible = entry.matched
      and entry.y + height >= top
      and entry.y <= bottom
    local became_visible = visible and not entry.row.visible
    entry.row.visible = visible
    if not visible then entry.row.hovered = false end
    if became_visible and update_new then entry.row:update() end
    if entry.matched and entry.height ~= entry.row:get_height() then
      self.layout_dirty = true
    end
  end
end

function WidgetList:get_scrollable_size()
  return math.max(self.size.y, self.content_height)
end

function WidgetList:get_h_scrollable_size()
  return self.size.x
end

function WidgetList:on_scale_change(...)
  WidgetList.super.on_scale_change(self, ...)
  -- Rows outside the viewport do not receive regular updates. Scale all of
  -- them before rebuilding the cached offsets and visible-row height.
  for _, entry in ipairs(self.items) do
    entry.row:update_if_scaled()
  end
  self:relayout()
end

function WidgetList:update()
  if self.layout_dirty or self.previous_width ~= self.size.x
    or self.previous_height ~= self.size.y
    or self.previous_gutter ~= self:get_scrollbar_gutter()
    or self.previous_alignment ~= self.v_scrollbar.alignment
  then
    self:relayout()
  end
  self:update_visible_items()
  if not WidgetList.super.update(self) then return false end
  self:update_visible_items(true)
  if self.layout_dirty then
    self:relayout()
    self:clamp_scroll_position()
    self:update_position()
    self:update_scrollbar()
    self:update_visible_items(true)
  end
  return true
end

return WidgetList
