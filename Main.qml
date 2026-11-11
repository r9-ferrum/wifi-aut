import QtQuick
import Quickshell.Io

Item {
    id: root
    property var pluginApi: null
    property string handledConnection: ""
    property var cfg: pluginApi?.pluginSettings || ({})
    readonly property string loginUrl: "http://neverssl.com/"

    property string currentConnection: ""
    property bool connectionFull: false

    function check() {
        if (!connectionReader.running && !probe.running)
            connectionReader.running = true;
    }

    function updateConnection(connection) {
        if (connection !== currentConnection) {
            currentConnection = connection;
            connectionFull = false;
            handledConnection = "";
        }
        return connection !== "" && !connectionFull;
    }

    Process {
        id: connectionReader
        // Local D-Bus query only: no internet connectivity probe.
        // ActiveConnection paths change even when reconnecting to the same profile.
        command: ["nmcli", "-t", "-f", "GENERAL.CON-PATH", "device", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var paths = text.trim().split(/\r?\n/).filter(
                    line => line.indexOf("/org/freedesktop/NetworkManager/ActiveConnection/") !== -1);
                var connection = paths.sort().join("|");
                if (root.updateConnection(connection))
                    probe.running = true;
            }
        }
    }

    Timer {
        interval: root.connectionFull ? 300000 : Math.max(10, Number(root.cfg.intervalSeconds || 20)) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check()
    }

    Process {
        id: probe
        // Only runs until this connection reports full connectivity.
        command: ["nmcli", "-t", "networking", "connectivity", "check"]
        property string output: ""
        stdout: StdioCollector {
            onStreamFinished: probe.output = text
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.warn("Captive Portal: nmcli failed; verify NetworkManager and connectivity checking.");
                return;
            }
            var state = output.trim();
            var connection = root.currentConnection;
            if (state === "full") {
                root.connectionFull = true;
                root.handledConnection = "";
                return;
            }
            if (state === "none") {
                root.handledConnection = "";
                return;
            }
            if (state !== "portal" || !connection || root.handledConnection === connection)
                return;
            root.handledConnection = connection;
            if (!notice.running)
                notice.running = true;
            if (root.cfg.autoOpen !== false && !browser.running)
                browser.running = true;
        }
    }

    Process {
        id: notice
        command: ["notify-send", "--app-name=Captive Portal",
            "--icon=network-wireless", "--urgency=normal",
            "Wi-Fi: требуется авторизация",
            "Откройте страницу входа. Повторно открыть её можно кнопкой Captive Portal на панели."]
        onExited: function(code) {
            if (code !== 0)
                console.warn("Captive Portal: notify-send failed.");
        }
    }

    Process {
        id: browser
        command: ["xdg-open", root.loginUrl]
        onExited: function(code) {
            if (code !== 0)
                console.warn("Captive Portal: cannot open the default browser.");
        }
    }
}
