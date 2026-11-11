import QtQuick
import Quickshell.Io

Item {
    id: root
    property var pluginApi: null
    property var cfg: pluginApi?.pluginSettings || ({})
    property string currentConnection: ""
    property string networkName: "Нет подключения"
    property string networkStatus: "unknown"
    property string errorMessage: ""
    property string lastChecked: ""
    property string handledConnection: ""
    property bool connectionFull: false
    property bool forceRequested: false
    readonly property bool busy: connectionReader.running || probe.running
    readonly property string loginUrl: "http://neverssl.com/"
    readonly property int checkInterval: boundedInterval(cfg.intervalSeconds, 20, 10)
    readonly property int idleInterval: boundedInterval(cfg.idleIntervalSeconds, 300, 30)

    function boundedInterval(value, fallback, minimum) {
        var n = Number(value);
        return isFinite(n) && n >= minimum ? Math.min(86400, Math.round(n)) : fallback;
    }

    function check(force) {
        if (busy)
            return;
        forceRequested = force === true;
        errorMessage = "";
        connectionReader.output = "";
        connectionReader.running = true;
    }

    function openLogin() {
        if (!browser.running)
            browser.running = true;
    }

    function saveIntervals(normal, idle) {
        if (!pluginApi)
            return;
        pluginApi.pluginSettings.intervalSeconds = boundedInterval(normal, 20, 10);
        pluginApi.pluginSettings.idleIntervalSeconds = boundedInterval(idle, 300, 30);
        pluginApi.saveSettings();
    }

    Timer {
        interval: (root.connectionFull ? root.idleInterval : root.checkInterval) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check(false)
    }

    Process {
        id: connectionReader
        // Read local NetworkManager state only. Names are never executed.
        command: ["nmcli", "--escape", "no", "-t", "-f",
                  "GENERAL.CONNECTION,GENERAL.CON-PATH", "device", "show"]
        property string output: ""
        stdout: StdioCollector {
            onStreamFinished: connectionReader.output = text
        }
        onExited: function(code) {
            if (code !== 0) {
                root.errorMessage = "Не удалось прочитать подключения NetworkManager (nmcli: " + code + ").";
                root.forceRequested = false;
                return;
            }
            var paths = [];
            var names = [];
            var name = "";
            var lines = output.trim().split(/\r?\n/);
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                if (line.indexOf("GENERAL.CONNECTION:") === 0)
                    name = line.substring("GENERAL.CONNECTION:".length);
                if (line.indexOf("GENERAL.CON-PATH:") === 0 &&
                        line.indexOf("/org/freedesktop/NetworkManager/ActiveConnection/") !== -1) {
                    paths.push(line.substring("GENERAL.CON-PATH:".length));
                    if (name && name !== "--")
                        names.push(name);
                }
            }
            var connection = paths.sort().join("|");
            root.networkName = names.length ? names.join(", ") : "Нет подключения";
            if (connection !== root.currentConnection) {
                root.currentConnection = connection;
                root.connectionFull = false;
                root.handledConnection = "";
                root.networkStatus = connection ? "unknown" : "none";
                root.lastChecked = "";
            }
            if (!connection)
                root.networkStatus = "none";
            var shouldProbe = connection && (!root.connectionFull || root.forceRequested);
            root.forceRequested = false;
            if (shouldProbe) {
                probe.output = "";
                probe.running = true;
            }
        }
    }

    Process {
        id: probe
        command: ["nmcli", "-t", "networking", "connectivity", "check"]
        property string output: ""
        stdout: StdioCollector {
            onStreamFinished: probe.output = text
        }
        onExited: function(code) {
            if (code !== 0) {
                root.errorMessage = "Ошибка проверки подключения (nmcli: " + code + ").";
                return;
            }
            var state = output.trim();
            root.networkStatus = state;
            root.lastChecked = new Date().toLocaleTimeString();
            root.connectionFull = state === "full";
            if (state === "none" || state === "full") {
                root.handledConnection = "";
                return;
            }
            if (state !== "portal" || !root.currentConnection ||
                    root.handledConnection === root.currentConnection)
                return;
            root.handledConnection = root.currentConnection;
            if (!notice.running)
                notice.running = true;
            if (root.cfg.autoOpen !== false)
                root.openLogin();
        }
    }

    Process {
        id: notice
        command: ["notify-send", "--app-name=Captive Portal",
                  "--icon=network-wireless", "--urgency=normal",
                  "Wi-Fi: требуется авторизация",
                  "Откройте страницу входа. Повторно открыть её можно в панели Captive Portal."]
    }

    Process {
        id: browser
        command: ["xdg-open", root.loginUrl]
        onExited: function(code) {
            if (code !== 0)
                root.errorMessage = "Не удалось открыть браузер.";
        }
    }
}
