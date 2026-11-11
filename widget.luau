--!nonstrict
local function render()
  local status = noctalia.state.get("status") or {}
  barWidget.setGlyph("world")
  barWidget.setTooltip("Captive Portal: " .. (status.connectivity or "unknown") .. "\n" .. (status.network or ""))
end
function onClick()
  noctalia.togglePanel("r9-ferrum/captive-portal:status")
end
function update() render() end
noctalia.state.watch("status", function() render() end)
render()
