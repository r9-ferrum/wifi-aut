--!nonstrict
local nonce = 0
local function send(action)
  nonce = nonce + 1
  noctalia.state.set("command", { action = action, nonce = nonce })
end

local function render()
  local status = noctalia.state.get("status") or {}
  panel.render(ui.column({ gap = 16, align = "stretch" }, {
    ui.label({ text = "Captive Portal", fontSize = 20, fontWeight = "bold" }),
    ui.label({ text = status.network or "Ожидание NetworkManager" }),
    ui.label({ text = "Состояние: " .. (status.connectivity or "unknown") }),
    ui.label({ text = "Последняя проверка: " .. (status.checked and status.checked ~= "" and status.checked or "—") }),
    ui.label({ text = status.error or "", color = "error" }),
    ui.row({ gap = 8 }, {
      ui.button({ text = status.busy and "Проверяется…" or "Проверить сейчас", enabled = not status.busy, onClick = function() send("check") end }),
      ui.button({ text = "Открыть вход", onClick = function() send("open") end }),
    }),
    ui.button({ text = "Настройки интервалов", onClick = function()
      noctalia.runAsync("noctalia msg settings-open-plugin r9-ferrum/captive-portal")
    end }),
  }))
end

noctalia.state.watch("status", function() render() end)
function update() render() end
render()
