/*
 * SPDX-License-Identifier: Apache-2.0
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../qmlcomponents"
import RpiImager

PanelDialog {
    id: root

    property string storageName: ""
    readonly property int confirmationDelay: 2
    property int countdown: confirmationDelay
    readonly property bool allowAccept: countdown === 0
    signal confirmed

    title: qsTr("Erase this device?")
    // The title is rendered in the custom header and used for accessibility.
    preferredWidth: Style.scaled(480)
    iconSource: Qt.resolvedUrl("../../icons/ic_warning_24px.svg")

    Component.onCompleted: {
        registerFocusGroup("warning", function () {
            return ImageWriterSingleton.screenReaderActive ? [root.headingItem, explanation, deviceName, permanentText] : []
        }, 0)
        registerFocusGroup("buttons", function () {
            return root.allowAccept ? [cancelButton, acceptButton] : [cancelButton]
        }, 1)
    }

    onOpened: {
        // Screen-reader users can review the warning at their own pace.
        countdown = ImageWriterSingleton.screenReaderActive ? 0 : confirmationDelay
        if (!allowAccept)
            confirmDelay.restart()
        rebuildFocusOrder()
        focusInitialItem()
        if (ImageWriterSingleton.screenReaderActive)
            root.headingItem.forceActiveFocus()
    }

    onClosed: {
        confirmDelay.stop()
        countdown = confirmationDelay
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 0
        spacing: Style.spacingMedium

        FocusableText {
            id: explanation
            text: qsTr("Writing the image will erase all data on this device.")
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizePixelSm
            color: Style.colorTextSecondary
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: deviceRow.implicitHeight + Style.spacingSmallPlus * 2
            radius: Style.radiusCard
            color: Style.colorSurfacePage
            border.color: Style.colorBorderSubtle

            RowLayout {
                id: deviceRow
                anchors.fill: parent
                anchors.margins: Style.spacingSmallPlus
                spacing: Style.spacingSmallPlus

                Image {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    source: "../../icons/ic_usb_40px.svg"
                    sourceSize: Qt.size(28, 28)
                    opacity: 0.55
                    Accessible.ignored: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Style.spacingXSmall

                    Text {
                        text: qsTr("Target storage device")
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizePixelXs
                        color: Style.colorTextSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Accessible.ignored: true
                    }

                    FocusableText {
                        id: deviceName
                        text: root.storageName || qsTr("Storage device")
                        textFormat: Text.PlainText
                        font.family: Style.fontFamilyBold
                        font.pixelSize: Style.fontSizePixelSm
                        font.bold: true
                        color: Style.colorTextPrimary
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        Accessible.name: qsTr("Target storage device") + ": " + text
                    }
                }
            }
        }

        FocusableText {
            id: permanentText
            text: qsTr("This action cannot be undone. Back up any important files before continuing.")
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizePixelSm
            color: Style.colorTextErrorStrong
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    buttons: [
        ImButton {
            id: cancelButton
            objectName: "cancelButton"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: Style.buttonHeightStandard
            text: CommonStrings.cancel
            accessibleDescription: qsTranslate("WritingStep", "Cancel and return to the write summary without erasing the storage device")
            onClicked: root.close()
        },
        ImButtonRed {
            id: acceptButton

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: Style.buttonHeightStandard
            objectName: "confirmEraseButton"
            text: root.allowAccept ? qsTr("Erase and write") : qsTr("Erase and write (%1)").arg(root.countdown)
            enabled: root.allowAccept
            implicitWidth: Math.max(Style.scaled(168), countdownLabel.implicitWidth + leftPadding + rightPadding)
            accessibleDescription: qsTranslate("WritingStep", "Confirm erasure and begin writing the image to the storage device")

            background: Rectangle {
                radius: Style.radiusButton
                color: !acceptButton.enabled ? Style.buttonDisabledBackgroundColor : acceptButton.down ? Qt.darker(Style.colorTextErrorStrong, 1.25) : acceptButton.hovered ? Qt.darker(Style.colorTextErrorStrong, 1.1) : Style.colorTextErrorStrong
                border.width: acceptButton.visualFocus ? Style.focusOutlineWidth : 0
                border.color: Style.colorTextOnAccent
                antialiasing: true
            }

            onClicked: {
                if (!root.allowAccept)
                    return
                root.close()
                root.confirmed()
            }
        }
    ]

    // Reserve the countdown label's width so enabling the button does not
    // resize the dialog or move either action under the pointer.
    Text {
        id: countdownLabel
        visible: false
        font: acceptButton.font
        text: qsTr("Erase and write (%1)").arg(root.confirmationDelay)
        Accessible.ignored: true
    }

    Timer {
        id: confirmDelay
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown = Math.max(0, root.countdown - 1)
            if (root.allowAccept) {
                stop()
                root.rebuildFocusOrder()
            }
        }
    }
}
