/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025 Raspberry Pi Ltd
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../qmlcomponents"
import RpiImager

PanelDialog {
    id: root
    title: qsTr("Passwordless Sudo")
    iconSource: Qt.resolvedUrl("../../icons/ic_warning_24px.svg")

    property bool userAccepted: false

    signal confirmed
    signal cancelled

    function askForConfirmation() {
        root.userAccepted = false
        open()
    }

    // Custom escape handling
    function escapePressed() {
        root.userAccepted = false
        root.close()
    }

    // Register focus groups when component is ready
    Component.onCompleted: {
        registerFocusGroup("content", function () {
            if (ImageWriterSingleton && ImageWriterSingleton.screenReaderActive) {
                return [root.headingItem, warningText, detailText]
            }
            return []
        }, 0)
        registerFocusGroup("buttons", function () {
            return [cancelButton, enableButton]
        }, 1)
    }

    // Dialog content

    FocusableText {
        id: warningText
        text: qsTr("Enabling passwordless sudo allows any process running as this user to gain full root privileges without authentication. This significantly weakens the security of your system.")
        wrapMode: Text.Wrap
        color: Style.colorTextPrimary
        font.pixelSize: Style.fontSizePixelSm
        Layout.fillWidth: true
    }

    FocusableText {
        id: detailText
        text: qsTr("Only enable this if you understand the risks and have a specific need, such as automated scripts or headless operation.")
        wrapMode: Text.Wrap
        color: Style.colorTextSecondary
        font.pixelSize: Style.fontSizePixelXs
        Layout.fillWidth: true
    }

    buttons: [
        ImButton {
            id: cancelButton
            objectName: "cancelButton"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: Style.buttonHeightStandard
            text: CommonStrings.cancel
            accessibleDescription: qsTr("Cancel and keep sudo requiring a password")
            activeFocusOnTab: true
            onClicked: {
                root.userAccepted = false
                root.close()
            }
        },
        ImButtonRed {
            id: enableButton
            destructive: true
            objectName: "enableButton"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: Style.buttonHeightStandard
            text: qsTr("ENABLE")
            accessibleDescription: qsTr("Enable passwordless sudo for this user account")
            activeFocusOnTab: true
            onClicked: {
                root.userAccepted = true
                root.close()
            }
        }
    ]

    onClosed: {
        if (root.userAccepted) {
            root.confirmed()
        } else {
            root.cancelled()
        }
    }
}
