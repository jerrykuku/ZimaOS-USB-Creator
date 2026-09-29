// SPDX-License-Identifier: Apache-2.0

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RpiImager

// Shared application dialog: only the body scrolls, so actions stay reachable.
BaseDialog {
    id: root

    default property alias bodyData: body.data
    property alias buttons: actions.data
    readonly property alias headingItem: heading
    readonly property alias bodyScroll: scroll
    property url iconSource: ""
    property real preferredWidth: Style.scaled(480)
    property real preferredBodyHeight: body.implicitHeight

    popupType: Popup.Item
    header: null
    closePolicy: Popup.CloseOnEscape
    width: Math.max(0, Math.min(preferredWidth, parent ? parent.width - Style.spacingPopupInset * 2 : preferredWidth))
    height: Math.max(0, Math.min(parent ? parent.height - Style.spacingPopupInset * 2 : 600,
                                panel.implicitHeight + Style.spacingPopupInset * 2))

    background: Rectangle {
        color: Style.colorSurfacePanel
        radius: Style.radiusPanel
        border.color: Style.colorBorderSubtle
        border.width: Style.borderWidthDefault
        antialiasing: true
    }

    // Explicitly target BaseDialog's content rather than this component's body.
    contentData: ColumnLayout {
        id: panel
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.spacingMedium

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacingTiny
            visible: root.title.length > 0

            Image {
                visible: root.iconSource.toString().length > 0
                source: root.iconSource
                sourceSize: Qt.size(width, height)
                Layout.preferredWidth: Style.scaled(24)
                Layout.preferredHeight: Style.scaled(24)
                Accessible.ignored: true
            }

            FocusableHeading {
                id: heading
                text: root.title
                textFormat: Text.PlainText
                font.family: Style.fontFamilyBold
                font.pixelSize: Style.fontSizeHeadingChrome
                font.bold: true
                color: Style.colorTextPrimary
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }

        ImScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: root.preferredBodyHeight
            contentWidth: availableWidth
            contentHeight: body.implicitHeight

            ColumnLayout {
                id: body
                width: scroll.availableWidth
                spacing: Style.spacingSmallPlus
            }
        }

        Rectangle {
            visible: actions.visible
            Layout.fillWidth: true
            implicitHeight: Style.borderWidthDefault
            color: Style.colorBorderSubtle
            Accessible.ignored: true
        }

        GridLayout {
            id: actions
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.maximumWidth: naturalWidth
            Layout.alignment: Qt.AlignRight
            rowSpacing: Style.spacingTiny
            columnSpacing: Style.spacingSmallPlus
            visible: children.length > 0
            columns: width >= naturalWidth ? Math.max(1, children.length) : 1

            // At large font sizes/with long translations, stack whole buttons.
            readonly property real naturalWidth: {
                let total = 0
                let count = 0
                for (let i = 0; i < children.length; ++i) {
                    if (children[i].visible) {
                        total += Math.ceil(children[i].implicitWidth) + 2
                        ++count
                    }
                }
                return total + Math.max(0, count - 1) * columnSpacing
            }
        }
    }

    onAboutToShow: scroll.contentItem.contentY = 0
}
