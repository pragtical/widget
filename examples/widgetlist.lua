--
-- Widget list example with custom row controls.
--

local command = require "core.command"
local Widget = require "widget"
local Button = require "widget.button"
local Label = require "widget.label"
local Toggle = require "widget.toggle"
local WidgetList = require "widget.widgetlist"

local widget = Widget()
widget:set_size(400, 260)
widget.draggable = true
widget.scrollable = false
widget:centered()

local list = WidgetList(widget)
list:set_position(0, 0)
list:set_size(widget.size.x, widget.size.y)

for index = 1, 20 do
  local data = { name = "Option " .. index, enabled = index % 2 == 0 }
  list:add_item(data, function(row, item)
    local label = Label(row, item.name)
    row:set_child_properties(label, { stretch = 1 })

    local toggle = Toggle(row, "", item.enabled)
    function toggle:on_change(enabled)
      item.enabled = enabled
    end

    local remove = Button(row, "")
    remove:set_icon("C")
    remove:set_tooltip("Remove item")
    function remove:on_click()
      for item_index, candidate in list:each_item() do
        if candidate == item then
          list:remove_item(item_index)
          break
        end
      end
    end
  end, data.name)
end

widget:show()

command.add(nil, {
  ["widget-list:toggle"] = function()
    widget:toggle_visible()
  end
})
