--
-- Extends core.scrollbar with widget hit testing and force status propagation.
--

---@type core.scrollbar
local CoreScrollBar = require "core.scrollbar"

---@class widget.scrollbar : core.scrollbar
---@overload fun(parent?:widget, options?:table):widget.scrollbar
---@field super widget.scrollbar
---@field widget_parent widget
local ScrollBar = CoreScrollBar:extend()

function ScrollBar:new(parent, options)
  self.widget_parent = parent
  ScrollBar.super.new(self, options)
end

function ScrollBar:_overlaps_normal(x, y)
  local result = ScrollBar.super._overlaps_normal(self, x, y)
  if not result then return end
  local track_x = self:_get_track_rect_normal()
  if self.widget_parent and x < track_x then
    -- Invisible scrollbar margins must not intercept child widgets.
    local real_x, real_y = self:normal_to_real(x, y)
    for _, child in ipairs(self.widget_parent.childs) do
      if child:mouse_on_top(real_x, real_y) then return end
    end
  end
  return result
end

function ScrollBar:set_forced_status(status)
  ScrollBar.super.set_forced_status(self, status)
  if self.widget_parent and self.widget_parent.childs then
    for _, child in pairs(self.widget_parent.childs) do
      if self.direction == "v" then
        child.v_scrollbar:set_forced_status(status)
      else
        child.h_scrollbar:set_forced_status(status)
      end
    end
  end
end


return ScrollBar
