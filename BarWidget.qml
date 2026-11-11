import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
    id: root
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    icon: "world"
    tooltipText: "Captive Portal — сеть, статус и настройки"
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    customRadius: Style.radiusL
    colorBg: Style.capsuleColor
    colorFg: Color.resolveColorKey("primary")
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth
    onClicked: {
        if (pluginApi)
            pluginApi.togglePanel(root.screen, root);
    }
}
