--!nonstrict
local connection = ""
local handled = ""
local full = false
local busy = false
local elapsed = 0
local status = { network = "Нет подключения", connectivity = "unknown", checked = "", error = "" }

local function publish()
  status.busy = busy
  noctalia.state.set("status", status)
end

local function interval(key, fallback, minimum)
  local value = tonumber(noctalia.getConfig(key)) or fallback
  return math.clamp(math.floor(value), minimum, 86400)
end

local function finish()
  busy = false
  elapsed = 0
  noctalia.setUpdateInterval(1000)
  publish()
end

local function openLogin()
  local launched = noctalia.runAsync("xdg-open 'http://neverssl.com/'", function(result)
    if result.exitCode ~= 0 then
      status.error = "Не удалось открыть браузер."
      publish()
    end
  end)
  if not launched then
    status.error = "Не удалось запустить браузер."
    publish()
  end
end

local function check(force)
  if busy then return end
  busy = true
  status.error = ""
  publish()
  local launched = noctalia.runAsync("LC_ALL=C nmcli --escape no -t -f GENERAL.CONNECTION,GENERAL.CON-PATH device show", function(result)
    if result.exitCode ~= 0 then
      status.error = "Не удалось прочитать подключения NetworkManager."
      finish()
      return
    end
    local paths, names = {}, {}
    local name = ""
    for line in (result.stdout or ""):gmatch("[^\r\n]+") do
      local value = line:match("^GENERAL.CONNECTION:(.*)$")
      if value then name = value end
      local path = line:match("^GENERAL.CON%-PATH:(.*)$")
      if path and path:find("/org/freedesktop/NetworkManager/ActiveConnection/", 1, true) then
        table.insert(paths, path)
        if name ~= "" and name ~= "--" then table.insert(names, name) end
      end
    end
    table.sort(paths)
    local current = table.concat(paths, "|")
    status.network = #names > 0 and table.concat(names, ", ") or "Нет подключения"
    if current ~= connection then
      connection, handled, full = current, "", false
      status.connectivity, status.checked = "unknown", ""
    end
    if current == "" then
      status.connectivity = "none"
      finish()
      return
    end
    if full and not force then finish(); return end
    local probing = noctalia.runAsync("LC_ALL=C nmcli -t networking connectivity check", function(probe)
      if probe.exitCode ~= 0 then
        status.error = "Ошибка проверки подключения NetworkManager."
        finish()
        return
      end
      local state = (probe.stdout or ""):match("^%s*(.-)%s*$")
      status.connectivity = state
      status.checked = os.date("%H:%M:%S")
      full = state == "full"
      if state == "none" or full then
        handled = ""
      elseif state == "portal" and handled ~= connection then
        handled = connection
        noctalia.runAsync("notify-send --app-name='Captive Portal' --icon=network-wireless 'Wi-Fi: требуется авторизация' 'Откройте страницу входа через Captive Portal.'")
        if noctalia.getConfig("autoOpen") ~= false then openLogin() end
      end
      finish()
    end)
    if not probing then
      status.error = "Не удалось запустить проверку."
      finish()
    end
  end)
  if not launched then
    status.error = "Не удалось запустить nmcli."
    finish()
  end
end

function update()
  if busy then return end
  elapsed = elapsed + 1
  local seconds = full and interval("idleIntervalSeconds", 300, 30) or interval("intervalSeconds", 20, 10)
  if elapsed >= seconds then check(false) end
end

function onConfigChanged()
  elapsed = 0
end

function onIpc(event)
  if event == "check" then check(true)
  elseif event == "open" then openLogin() end
end

noctalia.state.watch("command", function(command)
  if type(command) == "table" then onIpc(command.action) end
end)
noctalia.setUpdateInterval(1000)
check(false)
