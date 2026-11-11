import QtQuick
import Quickshell.Io

Item {
    id: root
    property var pluginApi: null
    property string handledConnection: ""
    property var cfg: pluginApi?.pluginSettings || ({})
    readonly property string loginUrl: "http://neverssl.com/"

    function check() {
        if (!probe.running)
            probe.running = true;
    }

    Timer {
        interval: Math.max(10, Number(root.cfg.intervalSeconds || 20)) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check()
    }

    Process {
        id: probe
        // NetworkManager performs its configured HTTP connectivity probe.
        // UUIDs are data only; no network-provided text is executed.
        command: ["sh", "-c",
            "nmcli -t -f UUID connection show --active; nmcli -t networking connectivity check"]
        property string output: ""
        stdout: StdioCollector {
            onStreamFinished: probe.output = text
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.warn("Captive Portal: nmcli failed; verify NetworkManager and connectivity checking.");
                return;
            }
            var lines = output.trim().split(/\r?\n/);
            var state = lines.pop();
            var connection = lines.sort().join("|");
            if (state === "none" || state === "full") {
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
