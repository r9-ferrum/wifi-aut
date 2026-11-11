import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    readonly property var service: pluginApi?.mainInstance || null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 440 * Style.uiScaleRatio
    property real contentPreferredHeight: 560 * Style.uiScaleRatio
    readonly property bool allowAttach: true
    anchors.fill: parent

    function statusText(state) {
        switch (state) {
        case "full": return "Интернет доступен";
        case "portal": return "Требуется авторизация";
        case "limited": return "Ограниченное подключение";
        case "none": return "Нет подключения к интернету";
        default: return "Статус пока неизвестен";
        }
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ScrollView {
            anchors.fill: parent
            anchors.margins: Style.marginL
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: Style.marginM

                NText {
                    text: "Captive Portal"
                    pointSize: Style.fontSizeL
                    color: Color.mPrimary
                }
                NText {
                    text: "Текущая сеть / активные подключения"
                    color: Color.mOnSurfaceVariant
                }
                NText {
                    Layout.fillWidth: true
                    text: root.service?.networkName || "Нет данных"
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    color: Color.mOnSurface
                }
                NText {
                    Layout.fillWidth: true
                    text: root.service?.busy ? "Проверка…" : root.statusText(root.service?.networkStatus)
                    wrapMode: Text.WordWrap
                    color: Color.mOnSurface
                }
                NText {
                    Layout.fillWidth: true
                    text: root.service?.lastChecked ? "Последняя проверка: " + root.service.lastChecked : "Проверка ещё не выполнена"
                    color: Color.mOnSurfaceVariant
                }
                NText {
                    Layout.fillWidth: true
                    visible: !!root.service?.errorMessage
                    text: root.service?.errorMessage || ""
                    wrapMode: Text.WordWrap
                    color: Color.mOnSurface
                }
                RowLayout {
                    NButton {
                        text: "Проверить сейчас"
                        enabled: !!root.service && !root.service.busy
                        onClicked: root.service.check(true)
                    }
                    NButton {
                        text: "Открыть вход"
                        enabled: !!root.service
                        onClicked: root.service.openLogin()
                    }
                }
                NText {
                    text: "Обычный интервал, секунды"
                    color: Color.mOnSurface
                }
                SpinBox {
                    id: normalInterval
                    Layout.fillWidth: true
                    from: 10
                    to: 86400
                    stepSize: 10
                    editable: true
                    value: root.service?.checkInterval || 20
                    Accessible.name: "Обычный интервал проверки в секундах"
                }
                NText {
                    text: "После full, секунды (300 = 5 минут)"
                    color: Color.mOnSurface
                }
                SpinBox {
                    id: idleInterval
                    Layout.fillWidth: true
                    from: 30
                    to: 86400
                    stepSize: 30
                    editable: true
                    value: root.service?.idleInterval || 300
                    Accessible.name: "Интервал опроса после full в секундах"
                }
                NButton {
                    text: "Сохранить интервалы"
                    enabled: !!root.service && !!root.pluginApi
                    onClicked: {
                        root.service.saveIntervals(normalInterval.value, idleInterval.value);
                        saved.text = "Интервалы сохранены";
                    }
                }
                NText {
                    id: saved
                    text: ""
                    color: Color.mPrimary
                }
                NText {
                    Layout.fillWidth: true
                    text: "После full проверка интернета приостановлена. Редкий локальный опрос обнаруживает смену сети. Кнопка запускает проверку сразу, даже после full."
                    wrapMode: Text.WordWrap
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }
}
