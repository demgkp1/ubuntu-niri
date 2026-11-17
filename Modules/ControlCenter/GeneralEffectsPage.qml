import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    Component.onCompleted: NiriConfigService.refresh()

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin

        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Background effects")
            description: qsTr("Create or connect the Clavis X-Ray rules.")
            integrationState: NiriConfigService.state("effects")
            busy: NiriConfigService.busy && NiriConfigService.activeFeature === "effects"
            blocked: NiriConfigService.busy
            error: NiriConfigService.error
            onSetupRequested: NiriConfigService.setup("effects")
        }

        SettingsSection {
            id: searchSection0
            Layout.fillWidth: true
            flat: true
            title: searchAnchor0.title
            SettingsSearchAnchor {
                id: searchAnchor0
                target: searchSection0
                declaration:
                    '{"id":"general.effects.section.background","route":"general.effects","title":"Background","context":"GeneralEffectsPage","icon":"blur_on","aliases":[]}'
            }
            iconName: "wallpaper"

            GeneralSliderSetting {
                title: qsTr("Background opacity")
                from: 0
                to: 100
                stepSize: 1
                suffix: "%"
                value: PersonalizationConfig.shellBackgroundOpacity * 100
                onMoved: value => PersonalizationConfig.setShellBackgroundOpacity(value / 100)
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Background blur")

                trailing: StyledSwitch {
                    enabled: BlurService.available
                    checked: PersonalizationConfig.shellBlurEnabled
                    Accessible.name: qsTr("Background blur")
                    onToggled: PersonalizationConfig.setShellBlurEnabled(checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Blur wallpaper only")
                supportingText: BlurService.niriIntegrationReady ? qsTr(
                                                                       "Turning this off also blurs windows and uses more resources") :
                                                                   qsTr("Configure Niri blur integration first")

                trailing: StyledSwitch {
                    enabled: BlurService.available && BlurService.niriIntegrationReady
                    checked: PersonalizationConfig.shellBlurXray
                    Accessible.name: qsTr("Blur wallpaper only")
                    onToggled: PersonalizationConfig.setShellBlurXray(checked)
                }
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: BlurService.lastError !== ""
                tone: "error"
                message: BlurService.lastError
            }
        }

        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Window opacity")
            description: qsTr("Create or connect the Clavis window opacity rules.")
            integrationState: NiriConfigService.state("window-rules")
            busy: NiriConfigService.busy && NiriConfigService.activeFeature === "window-rules"
            blocked: NiriConfigService.busy
            error: NiriConfigService.error
            onSetupRequested: NiriConfigService.setup("window-rules")
        }

        SettingsSection {
            id: searchSection1
            Layout.fillWidth: true
            flat: true
            title: searchAnchor1.title
            iconName: "opacity"

            SettingsSearchAnchor {
                id: searchAnchor1
                target: searchSection1
                declaration:
                    '{"id":"general.effects.section.windows","route":"general.effects","title":"Windows","context":"GeneralEffectsPage","icon":"opacity","aliases":[]}'
            }

            GeneralSliderSetting {
                title: qsTr("Window opacity")
                enabled: NiriConfigService.ready("window-rules")
                from: 10
                to: 100
                stepSize: 1
                suffix: "%"
                value: Math.round(PersonalizationConfig.windowOpacity * 100)
                onMoved: value => PersonalizationConfig.setWindowOpacity(value / 100)
            }

            GeneralSliderSetting {
                title: qsTr("Inactive window opacity")
                enabled: NiriConfigService.ready("window-rules")
                from: 10
                to: 100
                stepSize: 1
                suffix: "%"
                value: Math.round(PersonalizationConfig.windowInactiveOpacity * 100)
                onMoved: value => PersonalizationConfig.setWindowInactiveOpacity(value / 100)
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: NiriConfigService.errorFeature === "window-rules" && NiriConfigService.error !== ""
                tone: "error"
                message: NiriConfigService.error
            }
        }
    }
}
