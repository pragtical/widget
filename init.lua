--
-- Base widget implementation for pragtical.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local style = require "core.style"
local keymap = require "core.keymap"
local View = require "core.view"
local ScrollBar = require "widget.scrollbar"

---Represents the border of a widget.
---@class widget.border
---@field public width number
---@field public color renderer.color | nil

---Represents the position of a widget.
---@class widget.position
---@field public x number Real X
---@field public y number Real y
---@field public rx number Relative X
---@field public ry number Relative Y
---@field public dx number Dragging initial x position
---@field public dy number Dragging initial y position

---Represents a padding attribute.
---@class widget.padding
---@field public x number
---@field public y number

---@class widget.animation.options
---Prevents duplicated animations from getting added.
---@field name? string
---Speed of the animation, defaults to 0.5
---@field rate? number
---Called each time the value of a property changes.
---@field on_step? fun(target:table, property:string, value:number, animation:widget.animation)
---Called when the animation finishes.
---@field on_complete? fun(widget:widget)

---@class widget.animation
---@field target table
---@field properties table<string,number>
---@field options? widget.animation.options

---Represents a reference to a color stored elsewhere.
---@class widget.colorreference
---@field public type "color"
---@field public container table<string, renderer.color>
---@field public name string

---Represents a reference to a font stored elsewhere.
---@class widget.fontreference
---@field public type "font"
---@field public container table<string, renderer.font>
---@field public name string

---@alias widget.font widget.fontreference | renderer.font | string

---@alias widget.clicktype
---| "left"
---| "right"

---@alias widget.styledtext table<integer, renderer.font|widget.fontreference|renderer.color|widget.colorreference|integer|string>

---Pointer capture shared by floating and docked widget trees.
---@class widget.mousecapture
---@field widget widget Child handling the captured gesture
---@field button core.view.mousebutton Captured mouse button
---@field grab core.rootview.mousegrab RootView capture installed for the top-level widget

---A base widget
---@class widget : core.view
---@overload fun(parent?:widget, floating?:boolean):widget
---@field public super widget
---@field public parent widget | nil
---@field public name string
---@field public position widget.position
---Modifying this property directly is not advised, use set_size() instead.
---@field public size widget.position
---@field public childs table<integer,widget>
---@field public child_active widget | nil
---@field public zindex integer
---@field public border widget.border
---@field public clickable boolean
---@field public draggable boolean
---@field public scrollable boolean
---@field public font widget.font
---@field public foreground_color renderer.color
---@field public background_color renderer.color
---@field public render_background boolean
---@field public type_name string
---@field protected visible boolean
---@field protected has_focus boolean
---@field protected dragged boolean
---@field protected tooltip? string | widget.styledtext
---@field protected tooltip_command? string
---@field protected label string | widget.styledtext
---@field protected input_text boolean
---@field protected textview widget
---@field protected next_zindex integer
---@field protected mouse widget.position
---@field protected prev_size widget.position
---@field protected mouse_is_pressed boolean
---@field protected mouse_is_hovering boolean
---@field protected hovered_child widget? Child that last received hover motion
---@field protected is_scrolling boolean
---By default is set to true to allow ctrl+wheel or cmd+wheel on mac to scale
---the interface, you can set it to false on your parent widget to allow
---manually intercepting ctrl+wheel.
---@field protected skip_scroll_ctrl boolean
---@field protected captured_widget widget Widget that captured mouse events
---@field protected captured_button core.view.mousebutton?
---@field protected mouse_press {button:core.view.mousebutton, child:widget?}?
---@field protected animations widget.animation[]
local Widget = View:extend()

---Indicates on a widget.styledtext that a new line follows.
---@type integer
Widget.NEWLINE = 1

---Keep track of last hovered widget to properly trigger on_mouse_leave
---@type widget | nil
local last_hovered_child = nil

---Flag that indicates if the tooltip is been shown
---@type boolean
local widget_showing_tooltip = false

---There is one pointer gesture, shared by floating and docked widgets.
---@type widget.mousecapture?
local mouse_capture

local function belongs_to(widget, parent)
  while widget and parent do
    if widget == parent then return true end
    widget = widget.parent
  end
  return false
end

local function clear_press(widget)
  widget.mouse_press = nil
  widget.mouse_is_pressed = false
  widget.dragged = false
end

local function cancel_mouse_gesture(widget)
  if mouse_capture and belongs_to(mouse_capture.widget, widget) then
    mouse_capture.widget:release_mouse()
  end
  local root = widget
  while root.parent do root = root.parent end
  local target = root
  while target.mouse_press and target.mouse_press.child do
    target = target.mouse_press.child
  end
  if target.mouse_press and belongs_to(target, widget) then
    root:on_mouse_capture_lost()
    local grab = core.root_view.grab
    if grab and grab.view == root then core.root_view:ungrab_mouse(grab.button) end
  end
  if belongs_to(root.child_active, widget)
    or root == widget and root.input_text and root.active
  then
    root:swap_active_child()
  end
end

---Create a child widget or a standalone view, floating by default without a parent.
---Floating placement and input are managed by the editor RootView.
---@param parent? widget
---@param floating? boolean
function Widget:new(parent, floating)
  Widget.super.new(self)

  self.updated = false -- flag to ensure we updated before drawing.

  self.v_scrollbar = ScrollBar(self, {direction = "v", alignment = "e"})
  self.h_scrollbar = ScrollBar(self, {direction = "h", alignment = "e"})

  self.type_name = "widget"
  self.parent = parent
  self.name = "---" -- defaults to the application name
  if type(floating) == "boolean" then
    self.defer_draw =  floating
  else
    self.defer_draw = true
  end
  self.childs = {}
  self.child_active = nil
  self.hovered_child = nil
  self.zindex = nil
  self.next_zindex = 1
  self.border = {
    width = 1,
    color = nil
  }
  self.foreground_color = nil
  self.background_color = nil
  self.render_background = true
  self.visible = parent and true or false
  self.has_focus = false
  self.clickable = true
  self.draggable = false
  self.dragged = false
  self.font = "font"
  self.label = ""
  self.input_text = false
  self.textview = nil
  self.mouse = {x = 0, y = 0}
  self.prev_size = {x = 0, y = 0}
  self.is_scrolling = false
  self.skip_scroll_ctrl = true

  self.mouse_is_pressed = false
  self.mouse_is_hovering = false

  self.animations = {}

  if parent then
    parent:add_child(self)
  elseif self.defer_draw then
    self:set_floating(true)
  end

  self:set_position(0, 0)
end

---Useful for debugging.
function Widget:__tostring()
  return self.type_name
end

---Add a child widget, automatically assign a zindex if non set and sorts
---them in reverse order for better events matching.
---@param child widget
function Widget:add_child(child)
  assert(not child.floating_visible, "Hide the floating widget before adding it to a parent")
  if child.floating then child:set_floating(false) end
  if not child.zindex then
    child.zindex = self.next_zindex
    self.next_zindex = self.next_zindex + 1
  end

  table.insert(self.childs, child)
  table.sort(self.childs, function(t1, t2) return t1.zindex > t2.zindex end)
end

---Remove a child widget.
---@param child widget
function Widget:remove_child(child)
  for position, element in ipairs(self.childs) do
    if child == element then
      child:hide()
      child:destroy_childs()
      table.remove(self.childs, position)
      break
    end
  end
end

---Show the widget.
function Widget:show()
  if not self.parent then
    if self.size.x <= 0 or self.size.y <= 0 then
      self.size.x = self.prev_size.x
      self.size.y = self.prev_size.y
    end
    self.prev_size.x = 0
    self.prev_size.y = 0
  end
  self.visible = true
  -- re-triggers update to make sure everything was properly calculated
  -- and redraw the interface once, maybe something else can be changed
  -- to not require this action, but for now lets do this.
  self.perform_update_size_position = true
  if not self.parent and self.defer_draw then
    self:set_floating(true)
    if not self.floating_visible then self:show_floating() end
  end
end

---Perform an animated show.
---@param lock_x? boolean Do not resize width while animating
---@param lock_y? boolean Do not resize height while animating
---@param options? widget.animation.options
function Widget:show_animated(lock_x, lock_y, options)
  if not self.parent then
    if self.prev_size.x > 0 or self.prev_size.y > 0 then
      self.size.x = self.prev_size.x
      self.size.y = self.prev_size.y
    end
    self.prev_size.x = 0
    self.prev_size.y = 0
  end

  local target_x, target_y = self.size.x, self.size.y
  self.size.x = lock_x and target_x or 0
  self.size.y = lock_y and target_y or 0
  local properties = {}
  if not lock_x then properties["x"] = target_x end
  if not lock_y then properties["y"] = target_y end
  options = options or {}
  self:animate(self.size, properties, {
    name = options.name or "show_animated",
    rate = options.rate,
    on_step = options.on_step,
    on_complete = options.on_complete
  })

  self.visible = true
  if not self.parent and self.defer_draw then
    self:set_floating(true)
    if not self.floating_visible then self:show_floating() end
  end
end

---Hide the widget.
function Widget:hide()
  cancel_mouse_gesture(self)
  if self.floating then self:hide_floating() end
  self.visible = false
  -- we need to force size to zero on parent widget to properly hide it
  -- when used as a pragtical node, otherwise the reserved space of the node
  -- will stay visible and dragging will reveal empty space.
  if not self.parent and not self.floating then
    if self.size.x > 0 or self.size.y > 0 then
      -- we only do this once to prevent issues of consecutive hide calls
      if self.prev_size.x == 0 and self.prev_size.y == 0 then
        self.prev_size.x = self.size.x
        self.prev_size.y = self.size.y
      end
      self.size.x = 0
      self.size.y = 0
    end
  end
end

---Perform an animated hide.
---@param lock_x? boolean Do not resize width while animating
---@param lock_y? boolean Do not resize height while animating
---@param options? widget.animation.options
function Widget:hide_animated(lock_x, lock_y, options)
  local x, y = self.size.x, self.size.y
  local properties = {}
  if not lock_x then properties["x"] = 0 end
  if not lock_y then properties["y"] = 0 end
  options = options or {}
  self:animate(self.size, properties, {
    name = options.name or "hide_animated",
    rate = options.rate,
    on_step = options.on_step,
    on_complete = function()
      self.size.x, self.size.y = x, y
      self:hide()
      if options.on_complete then
        options.on_complete(self)
      end
    end
  })
end

---When set to false the background rendering is disabled.
---@param enable? boolean | nil
function Widget:toggle_background(enable)
  if type(enable) == "boolean" then
    self.render_background = enable
  else
    self.render_background = not self.render_background
  end
end

---Toggle visibility of widget.
---@param animated? boolean
---@param lock_x? boolean
---@param lock_y? boolean
---@param options? widget.animation.options
function Widget:toggle_visible(animated, lock_x, lock_y, options)
  if not self.visible then
    if not animated then
      self:show()
    else
      self:show_animated(lock_x, lock_y, options)
    end
  else
    if not animated then
      self:hide()
    else
      self:hide_animated(lock_x, lock_y, options)
    end
  end
end

---Check if the widget is visible also recursing to the parent visibility.
---@return boolean
function Widget:is_visible()
  if
    not self.explicit_update
    and
    (not self.visible or (self.parent and not self.parent:is_visible()))
  then
    return false
  end
  return true
end

---Taken from the logview and modified it a tiny bit.
---TODO: something similar should be on pragtical core.
---@param font widget.font
---@param text string
---@param x integer
---@param y integer
---@param color renderer.color
---@param only_calc boolean
---@return integer resx
---@return integer resy
---@return integer width
---@return integer height
function Widget:draw_text_multiline(font, text, x, y, color, only_calc)
  font = self:get_font(font)
  local th = font:get_height()
  local resx, resy = x, y
  local width, height = 0, 0
  for line in (text .. "\n"):gmatch("(.-)\n") do
    resy = y
    if only_calc then
      resx = x + font:get_width(line)
    else
      resx = renderer.draw_text(font, line, x, y, color)
    end
    y = y + th
    width = math.max(width, resx - x)
    height = height + th
  end
  return resx, resy, width, height
end

---Render or calculate the size of the specified range of elements
---in a styled text elemet.
---@param text widget.styledtext
---@param x integer
---@param y integer
---@param only_calc? boolean
---@param start_idx? integer
---@param end_idx? integer
---@return integer width
---@return integer height
function Widget:draw_styled_text(text, x, y, only_calc, start_idx, end_idx)
  local font = self:get_font()
  local color = self.foreground_color or style.text
  local width = 0
  local height = font:get_height()
  local new_line = false
  local nx = x

  start_idx = start_idx or 1
  end_idx = end_idx or #text

  for pos=start_idx, end_idx, 1 do
    local element = text[pos]
    local ele_type = type(element)
    if
      ele_type == "userdata"
      or
      (
        ele_type == "table" and (not element.type or element.type == "font")
        and
        (element.container or type(element[1]) == "userdata")
      )
    then
      if ele_type == "table" and element.container then
        font = element.container[element.name]
      else
        font = element
      end
    elseif ele_type == "table" and (not element.type or element.type == "color") then
      if element.container then
        color = element.container[element.name]
      else
        color = element
      end
    elseif element == Widget.NEWLINE then
      y = y + font:get_height()
      nx = x
      new_line = true
    elseif ele_type == "string" then
      local rx, ry, w, h = self:draw_text_multiline(
        font, element, nx, y, color, only_calc
      )
      y = ry
      nx = rx
      if new_line then
        height = height + h
        width = math.max(width, w)
        new_line = false
      else
        height = math.max(height, h)
        width = width + w
      end
    end
  end

  return width, height
end

---Draw the widget configured border or custom one.
---@param x? number
---@param y? number
---@param w? number
---@param h? number
function Widget:draw_border(x, y, w, h)
  if self.border.width <= 0 then return end

  x = x or self.position.x
  y = y or self.position.y
  w = w or self.size.x
  h = h or self.size.y

  x = x - self.border.width
  y = y - self.border.width
  w = w + (self.border.width * 2)
  h = h + (self.border.width * 2)

  -- Keep all strokes inside the outer bounds, without blending corners twice.
  local border = self.border.width
  local color = self.border.color or style.text
  renderer.draw_rect(x, y, w, border, color)
  renderer.draw_rect(x, y + h - border, w, border, color)
  renderer.draw_rect(x, y + border, border, h - border * 2, color)
  renderer.draw_rect(x + w - border, y + border, border, h - border * 2, color)
end

---Called by pragtical node system to properly resize the widget.
---@param axis string | "'x'" | "'y'"
---@param value number
function Widget:set_target_size(axis, value)
  if not self.visible then
    return false
  end
  if axis == "x" then
    self:set_size(value)
  else
    self:set_size(nil, value)
  end
  return true
end

---@param width? integer
---@param height? integer
function Widget:set_size(width, height)
  -- take into consideration the border as part of size
  if width then
    if width > (self.border.width * 2) then
      width = width - (self.border.width * 2)
    else
      width = 0
    end
  end
  if height then
    if height > (self.border.width * 2) then
      height = height - (self.border.width * 2)
    else
      height = 0
    end
  end

  if not self.parent and not self.visible then
    if width then self.prev_size.x = width end
    if height then self.prev_size.y = height end
  else
    if width then self.size.x = width end
    if height then self.size.y = height end
  end

  if
    not self.prev_width or not self.prev_height
  then
    self.prev_width, self.prev_height = width, height
    self.perform_update_size_position = true
  end
end

---@return widget.position
function Widget:get_size()
  if not self.parent and not self.visible then
    return self.prev_size
  end
  return self.size
end

---Set the widget border size and appropriately re-set the widget size.
---@param width integer
function Widget:set_border_width(width)
  local wwidth, wheight = 0, 0;
  if self.border.width > 0 then
    local prev_width = self.border.width * 2
    local size = self:get_size()
    wwidth = size.x + prev_width
    wheight = size.y + prev_width
  end
  self.border.width = width
  self:set_size(wwidth, wheight)
end

---Called on the update function to be able to scroll the child widgets.
---@param recursive? boolean Update descendants; defaults to true.
function Widget:update_position(recursive)
  if self.parent then
    self.position.x = self.position.rx + self.border.width
    self.position.y = self.position.ry + self.border.width

    -- add offset to properly scroll
    local ox, oy = self.parent:get_content_offset()
    self.position.x = ox + self.position.x
    self.position.y = oy + self.position.y
  end

  if recursive ~= false then
    for _, child in pairs(self.childs) do
      child:update_position()
    end
  end
end

---Set the position of the widget and updates the child absolute coordinates
---@param x? integer
---@param y? integer
function Widget:set_position(x, y)
  if x then self.position.x = x + self.border.width end
  if y then self.position.y = y + self.border.width end

  if self.parent then
    -- add offset to properly scroll
    local ox, oy = self.parent:get_content_offset()

    if x then
      self.position.rx = x
      self.position.x = ox + self.position.x
    end

    if y then
      self.position.ry = y
      self.position.y = oy + self.position.y
    end
  end

  if x or y then
    for _, child in pairs(self.childs) do
      child:set_position(child.position.rx, child.position.ry)
    end
  end
end

---Get the real renderer.font associated with a widget.font.
---@param font? widget.font
---@return renderer.font
function Widget:get_font(font)
  if not font then font = self.font end
  local font_type = type(font)
  if font_type == "userdata" then
    return font
  elseif font_type == "string" then
    return style[font]
  elseif font and font.container then
    return font.container[font.name]
  end
  if not font then
    return style.font
  end
  return font
end

---Get the content origin while preserving fractional layout coordinates.
---Snap only the scroll displacement so descendants move by whole pixels
---together without shifting their borders relative to the parent's viewport.
---@return number x Screen x coordinate after horizontal scrolling
---@return number y Screen y coordinate after vertical scrolling
function Widget:get_content_offset()
  return self.position.x - common.round(self.scroll.x),
    self.position.y - common.round(self.scroll.y)
end

---Get the relative position in relation to parent
---@return widget.position
function Widget:get_position()
  self:update_if_scaled()
  local position = { x = self.position.x, y = self.position.y }
  if self.parent then
    position.x = self.position.rx
    position.y = self.position.ry
  end
  return position
end

---Get width including borders.
---@return number
function Widget:get_width()
  local size = self:get_size()
  return size.x + (self.border.width * 2)
end

---Get height including borders.
---@return number
function Widget:get_height()
  local size = self:get_size()
  return size.y + (self.border.width * 2)
end

---Get the right x coordinate relative to parent
---@return number
function Widget:get_right()
  return self:get_position().x + self:get_width()
end

---Get the bottom y coordinate relative to parent
---@return number
function Widget:get_bottom()
  return self:get_position().y + self:get_height()
end

---Overall height of the widget accounting all visible child widgets.
---@return number
function Widget:get_real_height()
  local size = 0
  for _, child in pairs(self.childs) do
    if child.visible then
      size = math.max(size, child:get_bottom())
    end
  end
  return size
end

---Overall width of the widget accounting all visible child widgets.
---@return number
function Widget:get_real_width()
  local size = 0
  for _, child in pairs(self.childs) do
    if child.visible then
      size = math.max(size, child:get_right())
    end
  end
  return size
end

---Check if the given mouse coordinate is hovering the widget
---@param x number
---@param y number
---@return boolean
function Widget:mouse_on_top(x, y)
  return
    self.visible
    and
    x >= self.position.x - self.border.width
    and
    x <= self.position.x - self.border.width + self:get_width()
    and
    y >= self.position.y - self.border.width
    and
    y <= self.position.y - self.border.width + self:get_height()
end

---Mark a widget as having focus.
---TODO: Implement set focus system by pressing a key like tab?
function Widget:set_focus(has_focus)
  self.set_focus = has_focus
end

---Text displayed when the widget is hovered.
---If a command name is also given its associated binding will be displayed
---as part of the tooltip.
---@param tooltip? string | widget.styledtext
---@param command? string
function Widget:set_tooltip(tooltip, command)
  self.tooltip = tooltip
  self.tooltip_command = command
end

---A text label for the widget, not all widgets support this.
---@param text string | widget.styledtext
function Widget:set_label(text)
  self.label = text
end

---Used internally when dragging is activated.
---@param x number
---@param y number
function Widget:drag(x, y)
  if self.position.dx and self.position.dy then
    self:set_position(x - self.position.dx, y - self.position.dy)
  end
end

---Center the widget horizontally and vertically to the screen or parent widget.
function Widget:centered()
  local w, h = system.get_window_size(core.window);
  if self.parent then
    w = self.parent:get_width()
    h = self.parent:get_height()
  end
  self:set_position(
    (w / 2) - (self:get_width() / 2),
    (h / 2) - (self:get_height() / 2)
  )
end

---Replaces current active child with a new one and calls the
---activate/deactivate events of the child. This is especially
---used to send text input events to widgets with input_text support.
---@param child? widget If nil deactivates current child
function Widget:swap_active_child(child)
  if self.parent then
    self.parent:swap_active_child(child)
    return
  end

  if child and child == self.child_active then return end

  local active_child = self.child_active

  if self.child_active then
    self.child_active:deactivate()
  elseif self.input_text then
    self:deactivate()
  end

  self.child_active = child

  if child then
    if not self.prev_view then
      self.prev_view = core.active_view
    end
    core.set_active_view(child.input_text and child.textview or child)
    self.child_active:activate()
  elseif self.prev_view then
    -- return focus to previous view
    if self.prev_view ~= active_child then
      core.set_active_view(self.prev_view)
    else
      core.set_active_view(self)
    end
    self.prev_view = nil
  end
end

---Calculates the y scrollable size taking into account the bottom most
---widget or the size of the widget it self if greater.
---@return number
function Widget:get_scrollable_size()
  if not self.scrollable then return self:get_size().y end
  return math.max(self:get_size().y, self:get_real_height())
end

---Calculates the x scrollable size taking into account the right most
---widget or the size of the widget it self if greater.
---@return number
function Widget:get_h_scrollable_size()
  if not self.scrollable then return self:get_size().x end
  return math.max(self:get_size().x, self:get_real_width())
end

---The name that is displayed on pragtical tabs.
function Widget:get_name()
  return self.parent and self.parent:get_name() or self.name
end

--
-- Events
--

---Send file drop event to hovered child.
---@param filename string
---@param x number
---@param y number
---@return boolean processed
function Widget:on_file_dropped(filename, x, y)
  if not self.visible then return false end

  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) then
      return child:on_file_dropped(filename, x, y)
    end
  end

  return false
end

---Redirects any text input to active child with the input_text flag.
---@param text string
---@return boolean processed
function Widget:on_text_input(text)
  if not self.visible then return false end

  Widget.super.on_text_input(self, text)

  if self.child_active then
    self.child_active:on_text_input(text)
    return true
  end

  return false
end

---All mouse events will be directly sent to the widget even if mouse moves
---outside the widget region.
---@param scrolling? boolean Capture for scrolling
---@param button? core.view.mousebutton Defaults to left
function Widget:capture_mouse(scrolling, button)
  button = button or "left"
  if mouse_capture then
    if mouse_capture.widget == self and mouse_capture.button == button then return end
    mouse_capture.widget:release_mouse()
  end
  local root = self
  while root.parent do root = root.parent end
  local root_view = core.root_view
  local grab = root_view.grab
  if grab and (grab.view ~= root or grab.button ~= button) then
    if grab.view:extends(Widget) then
      grab.view:on_mouse_capture_lost()
    else
      grab.view:on_mouse_released(grab.button, root_view.mouse.x, root_view.mouse.y)
    end
    if root_view.grab == grab then root_view:ungrab_mouse(grab.button) end
  end
  if not root_view.grab then root_view:grab_mouse(button, root) end
  mouse_capture = { widget = self, button = button, grab = root_view.grab }
  self.captured_button = button
  self.is_scrolling = scrolling or false
  local parent = self.parent
  while parent do
    -- propagate to parents so if mouse is not on top still
    -- reach the childrens when the mouse is released
    parent.is_scrolling = scrolling or false
    parent.captured_widget = self
    parent = parent.parent
  end
end

---Release this widget's capture and clear capture state on its ancestors.
---@param skip_cancel? boolean Skip the cancellation callback when already handling capture loss
function Widget:release_mouse(skip_cancel)
  local capture = mouse_capture
  if not capture or capture.widget ~= self then return end
  mouse_capture = nil
  self.captured_button = nil
  if core.root_view.grab == capture.grab then
    core.root_view:ungrab_mouse(capture.grab.button)
  end
  local parent = self.parent
  while parent do
    -- propagate to parents so if mouse is not on top still
    -- reach the childrens when the mouse is released
    if parent.captured_widget == self then
      parent.is_scrolling = false
      parent.captured_widget = nil
      clear_press(parent)
    end
    parent = parent.parent
  end
  self.is_scrolling = false
  if not skip_cancel then self:on_mouse_capture_lost() end
end

---End a pointer gesture without emitting a click. Override to clear drag state.
---@protected
function Widget:on_mouse_capture_lost()
  local press = self.mouse_press
  clear_press(self)
  self.is_scrolling = false
  local captured
  if mouse_capture and belongs_to(mouse_capture.widget, self) then
    captured = mouse_capture.widget
    captured:release_mouse(captured == self)
  end
  Widget.super.on_mouse_released(self, "left", self.mouse.x, self.mouse.y)
  if press and press.child and press.child ~= captured then press.child:on_mouse_capture_lost() end
end

---Send mouse pressed events to hovered child or starts dragging if enabled.
---@param button widget.clicktype
---@param x number
---@param y number
---@param clicks integer
---@return boolean processed
function Widget:on_mouse_pressed(button, x, y, clicks)
  if not self.visible then return false end

  if Widget.super.on_mouse_pressed(self, button, x, y, clicks) then
    self.mouse_press = { button = button }
    self.mouse_is_pressed = true
    self:capture_mouse(true, button)
    return true
  end

  for _, child in ipairs(self.childs) do
    if child:mouse_on_top(x, y) and child.clickable then
      self.mouse_press = { button = button, child = child }
      self.mouse_is_pressed = true
      child:on_mouse_pressed(button, x, y, clicks)
      return true
    end
  end

  if not self:mouse_on_top(x, y) then return false end
  self.mouse_press = { button = button }
  self.mouse_is_pressed = true
  if not self.input_text then self:swap_active_child() end

  if self.draggable and not self.child_active then
    self.position.dx = x - self.position.x
    self.position.dy = y - self.position.y
    system.set_cursor("hand")
    self:capture_mouse(false, button)
  end
  return true
end

---Send release to the pressed target, even outside its bounds.
---@param button widget.clicktype
---@param x number
---@param y number
---@return boolean processed
function Widget:on_mouse_released(button, x, y)
  if not self.visible then return false end

  if widget_showing_tooltip then
    widget_showing_tooltip = false
    core.status_view:remove_tooltip()
  end

  local capture = mouse_capture
  if self.captured_widget then
    local target = self.captured_widget
    if target.captured_button ~= button then return false end
    target:on_mouse_released(button, x, y)
    if mouse_capture == capture then target:release_mouse() end
    return true
  end

  local press = self.mouse_press
  local owns_capture = capture and capture.widget == self
  if owns_capture and capture.button ~= button then return false end
  if press and press.button ~= button then return false end
  if not press and not owns_capture then return false end

  local dragged = self.dragged
  clear_press(self)
  Widget.super.on_mouse_released(self, button, x, y)
  if press and press.child then
    local child = press.child
    local child_press = child.mouse_press
    child:on_mouse_released(button, x, y)
    if child_press and child.mouse_press == child_press then
      child:on_mouse_capture_lost()
    end
  elseif press and not dragged and not self.is_scrolling and self:mouse_on_top(x, y) then
    self:on_click(button, x, y)
  end

  if owns_capture and mouse_capture == capture then self:release_mouse() end
  if self.draggable then system.set_cursor("arrow") end
  return true
end

---Event emitted when the value of the widget changes.
---If applicable, child widgets should call this method
---when its value changes.
---@param value any
function Widget:on_change(value) end

---Click event emitted on a succesful on_mouse_pressed
---and on_mouse_released events combo.
---@param button widget.clicktype
---@param x number
---@param y number
function Widget:on_click(button, x, y) end

---Emitted to input_text widgets when clicked.
function Widget:activate() end

---Emitted to input_text widgets on lost focus.
function Widget:deactivate() end

---Besides the on_mouse_moved this event emits on_mouse_enter
---and on_mouse_leave for easy hover effects. Also, if the
---widget is scrollable and pressed this will drag it unless
---there is an active input_text child active.
---@param x number
---@param y number
---@param dx number
---@param dy number
function Widget:on_mouse_moved(x, y, dx, dy)
  if not self.visible then return false end

  if self.captured_widget then
    self.captured_widget:on_mouse_moved(x, y, dx, dy)
    return true
  end

  Widget.super.on_mouse_moved(self, x, y, dx, dy)

  -- store latest mouse coordinates for usage on the on_mouse_wheel event.
  self.mouse.x = x
  self.mouse.y = y

  local hovered
  if not self.dragged then
    hovered = self.mouse_press and self.mouse_press.child
    for _, child in ipairs(self.childs) do
      if not hovered and child:mouse_on_top(x, y) then
        hovered = child
      elseif child ~= hovered and (child.mouse_is_hovering or child == self.hovered_child) then
        if widget_showing_tooltip then
          widget_showing_tooltip = false
          core.status_view:remove_tooltip()
        end
        child.mouse_is_hovering = false
        child:on_mouse_leave(x, y, dx, dy)
      end
    end
    self.hovered_child = hovered
  end

  -- child_active can be a descendant of hovered, not just a direct child.
  if self.child_active and not belongs_to(self.child_active, hovered) then
    self.child_active:on_mouse_moved(x, y, dx, dy)
  end
  if hovered then
    hovered:on_mouse_moved(x, y, dx, dy)
    if last_hovered_child and not last_hovered_child:mouse_on_top(x, y) then
      local child = last_hovered_child
      last_hovered_child = nil
      child.mouse_is_hovering = false
      child:on_mouse_leave(x, y, dx, dy)
    end
    return true
  end

  if
    not self:mouse_on_top(x, y)
    and
    not self.mouse_is_pressed
    and
    not self.mouse_is_hovering
  then
    return false
  end

  local is_over = true

  if self:mouse_on_top(x, y) then
    if not self.mouse_is_hovering  then
      system.set_cursor("arrow")
      self.mouse_is_hovering = true
      if self.tooltip or self.tooltip_command then
        local binding = self.tooltip_command and keymap.get_binding(
          self.tooltip_command
        )
        ---@type table
        local tooltip = {}
        if self.tooltip and #self.tooltip > 0 then
          tooltip = type(self.tooltip) == "table"
            and {table.unpack(self.tooltip)}
            or {self.tooltip}
        end
        if binding then
          if #tooltip == 0 then
            table.insert(tooltip, command.prettify_name(self.tooltip_command))
          end
          table.insert(tooltip, style.dim)
          table.insert(tooltip, "  " .. binding)
        end
        if(#tooltip > 0) then
          widget_showing_tooltip = true
          core.status_view:show_tooltip(tooltip)
        end
      end
      self:on_mouse_enter(x, y, dx, dy)
      last_hovered_child = self
    end
  else
    self:on_mouse_leave(x, y, dx, dy)
    if widget_showing_tooltip then
      widget_showing_tooltip = false
      core.status_view:remove_tooltip()
    end
    self.mouse_is_hovering = false
    is_over = false
  end

  if not self.child_active and self.mouse_is_pressed and self.draggable then
    system.set_cursor("hand")
    self:drag(x, y)
    self.dragged = true
    return true
  end

  return is_over
end

---Emitted once when the mouse hovers the widget.
function Widget:on_mouse_enter(x, y, dx, dy)
  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) then
      child:on_mouse_enter(x, y, dx, dy)
      break
    end
  end
end

---Emitted once when the mouse leaves the widget.
function Widget:on_mouse_leave(x, y, dx, dy)
  Widget.super.on_mouse_left(self)
  self.mouse_is_hovering = false
  for _, child in pairs(self.childs) do
    if child.mouse_is_hovering or child == self.hovered_child then
      child.mouse_is_hovering = false
      child:on_mouse_leave(x, y, dx, dy)
    end
  end
  self.hovered_child = nil
  if self.parent and self.parent.hovered_child == self then
    self.parent.hovered_child = nil
  end
  if last_hovered_child == self then last_hovered_child = nil end
end

function Widget:on_mouse_left()
  if not self.captured_widget and not self.captured_button then
    Widget.super.on_mouse_left(self)
    self:on_mouse_moved(-1, -1, -1, -1)
  end
end

function Widget:on_mouse_wheel(y, x)
  if
    not self.visible
    or
    not self:mouse_on_top(self.mouse.x, self.mouse.y)
  then
    return false
  else
    local ctrl_pressed = false
    if self.skip_scroll_ctrl and not self.parent then
      local ctrl_key = PLATFORM == "Mac OS X" and "cmd" or "ctrl"
      ctrl_pressed = keymap.modkeys[ctrl_key]
      -- ensure only ctrl/cmd is pressed
      if ctrl_pressed then
        for key, status in pairs(keymap.modkeys) do
          if key ~= ctrl_key and status then
            ctrl_pressed = false
            break
          end
        end
      end
    end
    if ctrl_pressed then return false end
  end

  for _, child in pairs(self.childs) do
    if child:mouse_on_top(self.mouse.x, self.mouse.y) then
      if child:on_mouse_wheel(y, x) then
        return true
      end
    end
  end

  if self.scrollable then
    if keymap.modkeys["shift"] then
      x = y
      y = 0
    end
    if y and y ~= 0 then
      self.scroll.to.y = self.scroll.to.y + y * -config.mouse_wheel_scroll
    end
    if x and x ~= 0 then
      self.scroll.to.x = self.scroll.to.x + x * -config.mouse_wheel_scroll
    end
    return true
  end

  return false
end

---Can be overriden by widgets to listen for scale change events to apply
---any neccesary changes in sizes, padding, etc...
---@param new_scale number
---@param prev_scale number
function Widget:on_scale_change(new_scale, prev_scale)
  local font_type = type(self.font)
  if
    font_type == "userdata"
    or
    (font_type == "table" and not self.font.container)
  then
    self.font:set_size(
      self.font:get_size() * (new_scale / prev_scale)
    )
  end
  self:update_size_position()
end

---Registers a new animation to be ran on the update cycle.
---@param target? table If nil assumes properties belong to widget it self.
---@param properties table<string,number>
---@param options? widget.animation.options
function Widget:animate(target, properties, options)
  if not target then target = self end

  -- if name is set then prevent adding if another one with the same
  -- animation name is already running
  if options and options.name then
    for _, animation in ipairs(self.animations) do
      if animation.options and animation.options.name == options.name then
        return
      end
    end
  end

  table.insert(self.animations, {
    target = target,
    properties = properties,
    options = options
  })
end

---Runs all registered animations removing duplicated and finished ones.
function Widget:run_animations()
  if #self.animations > 0 then
    -- ensure animations like show_animated are more consistently rendered
    core.redraw = true
    self:schedule_update(true)

    ---@type table<widget.animation, widget.animation>
    local duplicates = {}

    local targets = {}
    local deleted = 0
    for i=1, #self.animations do
      local animation = self.animations[i - deleted]

      -- do not run animations that change same target to prevent conflicts.
      if not targets[animation.target] then
        local finished = true
        local options = animation.options or {}
        if not animation.last_value then animation.last_value = {} end
        for name, value in pairs(animation.properties) do
          if animation.target[name] ~= value then
            self:move_towards(animation.target, name, value, options.rate)
            if options.on_step then
              options.on_step(animation.target, name, animation.target[name], animation)
            end
            if animation.target[name] ~= value then
              -- avoid duplicated values from move_towards and finish the animation
              if animation.last_value[name] == animation.target[name] then
                animation.target[name] = value
              else
                finished = false
              end
            end
            animation.last_value[name] = animation.target[name]
          end
        end
        if finished then
          if options.on_complete then
            options.on_complete(self)
          end
          table.remove(self.animations, i - deleted)
          deleted = deleted + 1
        end
        targets[animation.target] = animation
      -- only registers it as duplicated if the animation does needs to
      -- perform any tasks on completion.
      elseif not targets[animation.target].on_complete then
        duplicates[targets[animation.target]] = animation
      end
    end

    -- remove older duplcated animations that modify same target and properties
    for duplicate, newer_animation in pairs(duplicates) do
      local exact_properties = true
      for name, _ in pairs(duplicate.properties) do
        if not newer_animation.properties[name] then
          exact_properties = false
          break
        end
      end
      if exact_properties then
        for name, _ in pairs(newer_animation.properties) do
          if not duplicate.properties[name] then
            exact_properties = false
            break
          end
        end
      end
      if exact_properties then
        for i, animation in ipairs(self.animations) do
          if animation == duplicate then
            table.remove(self.animations, i)
            break
          end
        end
      end
    end
  end
end

---Explicitly call the widget update procedure when the scale change even if
---the widget is not visible.
function Widget:update_if_scaled()
  if self.current_scale ~= SCALE then
    self.explicit_update = true
    self:update()
    -- after updating all widgets re-adjust sizes and positions, even if
    -- this is called directly in update -> on_scale_change it doesn't takes
    -- into account the sum of all sizing changes so we re-execute it
    self:update_size_position()
    self.explicit_update = false
  end
end

---If visible execute the widget calculations and returns true.
---@return boolean
function Widget:update()
  if self.floating_visible and (self.parent or not self.defer_draw) then
    self:set_floating(false)
  end
  if self.perform_update_size_position then
    self:update_size_position()
    self.perform_update_size_position = false
  end

  if not self:is_visible() then return false end

  Widget.super.update(self)

  -- Descendants refresh their positions before their own update below.
  self:update_position(false)

  -- run any pending animations
  self:run_animations()

  if not self.explicit_update then
    for _, child in pairs(self.childs) do
      child:update_position(false)
      child:update()
    end
  else
    for _, child in pairs(self.childs) do
      child:update_if_scaled()
    end
  end

  if not self.updated and self.size.y > 0 and self.size.x > 0 then
    self.updated = true
  end

  return true
end

---Similar to update, but here you should perform expensive calculations that
---will get executed for a predefined period of time when a widget is
---initialized, scale has changed or a widget switched from hidden to visible.
function Widget:update_size_position()
  for _, child in pairs(self.childs) do
    child:update_size_position()
  end
end

---Flag that indicates if the update schedule is in progress.
---@type boolean
local widget_update_scheduled = false

---Schedule a core update and redraw. Since widgets try to not fire updates
---and draws to child widgets to reduce cpu consumption this function can be
---used when a re-update and re-draw is strictly needed.
function Widget:schedule_update(delayed)
  if (self.parent or delayed) and not widget_update_scheduled then
    -- on older versions of lua coroutine.running() returns nil of on main
    -- so we also take that into account
    local co, is_main = coroutine.running()
    if not co or not is_main then
      -- already running on a coroutine so we don't need to schedule a new one
      core.redraw = true
      return
    end
    widget_update_scheduled = true
    core.add_thread(function()
      if delayed then coroutine.yield(0.1) end
      core.redraw = true
      widget_update_scheduled = false
    end)
  elseif not self.parent or delayed then
    core.redraw = true
  end
end

function Widget:draw_scrollbar()
  if self.scrollable then
    Widget.super.draw_scrollbar(self)
  end
end

---If visible draw the widget and returns true.
---@return boolean
function Widget:draw()
  if
    not self:is_visible() or not self.updated
    or
    self.size.x <= 0 or self.size.y <= 0
  then
    return false
  end

  Widget.super.draw(self)

  self:draw_border()

  if self.render_background then
    if self.background_color then
      self:draw_background(self.background_color)
    else
      self:draw_background(
        self.parent and style.background or style.background2
      )
    end
  end

  if #self.childs > 0 then
    core.push_clip_rect(
      self.position.x,
      self.position.y,
      self.size.x,
      self.size.y
    )
  end

  for i=#self.childs, 1, -1 do
    self.childs[i]:draw()
  end

  if #self.childs > 0 then
    core.pop_clip_rect()
  end

  self:draw_scrollbar()

  return true
end

---Recursively destroy all childs from the widget.
function Widget:destroy_childs()
  for _=1, #self.childs do
    self.childs[1]:hide()
    self.childs[1]:destroy_childs()
    table.remove(self.childs, 1)
  end
end

---Hide the widget, release its floating placement, and recursively destroy its children.
function Widget:destroy()
  self:hide()
  self:set_floating(false)
  self:destroy_childs()
end

---Get the widget's outer screen rectangle, including its border.
---@return number x Outer screen x coordinate
---@return number y Outer screen y coordinate
---@return number w Width including the border
---@return number h Height including the border
function Widget:get_floating_bounds()
  return self.position.x - self.border.width, self.position.y - self.border.width,
    self:get_width(), self:get_height()
end

---Apply outer popup bounds using the widget's border-aware size and position setters.
---Pass dimensions unchanged: set_size() already accounts for the border.
---@param x number Outer screen x coordinate
---@param y number Outer screen y coordinate
---@param w number Width including the border
---@param h number Height including the border
function Widget:set_floating_bounds(x, y, w, h)
  self:set_size(w, h)
  self:set_position(x, y)
end

---Reuse widget hit testing for RootView's floating pointer routing.
---@param x number Screen x coordinate
---@param y number Screen y coordinate
---@return boolean inside Whether the point lies over the widget
function Widget:hit_test(x, y) return self:mouse_on_top(x, y) end

---Focus the active child or its TextView, falling back to this widget's input or itself.
---@return core.view target View that should receive keyboard focus
function Widget:get_focus_target()
  local child = self.child_active
  if child then return child.textview or child end
  return self.input_text and self.textview or self
end

---Synchronize widget visibility with RootView, including owner-driven popup removal.
---@param visible boolean Whether the floating widget remains shown
function Widget:on_floating_visibility_changed(visible)
  self.visible = visible
end

---Dismiss through the widget's normal hide lifecycle and subclass hooks.
---@param reason "escape"|"outside"|"focuslost" Event requesting dismissal
function Widget:on_floating_dismiss(reason) self:hide() end


return Widget
