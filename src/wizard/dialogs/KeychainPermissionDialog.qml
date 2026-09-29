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
    title: qsTr("Keychain Access")

    property bool userAccepted: false
    property bool responseSent: false

    onAboutToShow: {
        userAccepted = false
        responseSent = false
    }

    function respond(accepted) {
        responseSent = true
        userAccepted = accepted
        if (accepted)
            root.accept()
        else
            root.reject()
    }

    // A programmatic dismissal also answers the pending backend request once.
    onClosed: {
        if (!responseSent) {
            responseSent = true
            root.rejected()
        }
    }

    function askForPermission() {
        root.userAccepted = false
        open()
    }

    // Custom escape handling
    function escapePressed() {
        root.respond(false)
    }

    // Register focus groups when component is ready
    Component.onCompleted: {
        registerFocusGroup("content", function () {
            // Only include text elements when screen reader is active (otherwise they're not focusable)
            if (ImageWriterSingleton && ImageWriterSingleton.screenReaderActive) {
                return [root.headingItem, descriptionText, subText]
            }
            return []
        }, 0)
        registerFocusGroup("buttons", function () {
            return [noButton, yesButton]
        }, 1)
    }

    FocusableText {
        id: descriptionText
        text: qsTr("Would you like to prefill the Wi‑Fi password from the system keychain?")
        wrapMode: Text.Wrap
        color: Style.colorTextPrimary
        font.pixelSize: Style.fontSizePixelSm
        Layout.fillWidth: true
    }

    FocusableText {
        id: subText
        text: qsTr("This will require administrator authentication on macOS.")
        wrapMode: Text.Wrap
        color: Style.colorTextSecondary
        font.pixelSize: Style.fontSizePixelXs
        Layout.fillWidth: true
    }

    buttons: [
        ImButton {
            id: noButton
            objectName: "noButton"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: Style.buttonHeightStandard
            text: CommonStrings.cancel
            accessibleDescription: qsTr("Skip keychain access and manually enter the Wi-Fi password")
            activeFocusOnTab: true
            onClicked: root.respond(false)
        },
        ImButtonRed {
            id: yesButton
            objectName: "yesButton"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: Style.buttonHeightStandard
            text: CommonStrings.continueText
            accessibleDescription: qsTr("Retrieve the Wi-Fi password from the system keychain using administrator authentication")
            activeFocusOnTab: true
            onClicked: root.respond(true)
        }
    ]
}
