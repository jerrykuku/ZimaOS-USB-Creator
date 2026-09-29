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
    title: qsTr("Update available")

    // For overlay parenting set by caller if needed
    property alias overlayParent: root.parent

    property url url
    property string version: ""

    // Custom escape handling
    function escapePressed() {
        root.reject()
    }

    // Register focus groups when component is ready
    Component.onCompleted: {
        registerFocusGroup("content", function () {
            // Only include text elements when screen reader is active (otherwise they're not focusable)
            if (ImageWriterSingleton && ImageWriterSingleton.screenReaderActive) {
                return [root.headingItem, descriptionText]
            }
            return []
        }, 0)
        registerFocusGroup("buttons", function () {
            return [noButton, yesButton]
        }, 1)
    }

    // Dialog content

    FocusableText {
        id: descriptionText
        text: root.version.length > 0 ? qsTr("Creator version %1 is available. Would you like to visit the website to download it?").arg(root.version) : qsTr("There is a newer version of Creator available. Would you like to visit the website to download it?")
        wrapMode: Text.Wrap
        font.pixelSize: Style.fontSizePixelSm
        font.family: Style.fontFamily
        color: Style.colorTextPrimary
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
            accessibleDescription: qsTr("Continue using the current version of ZimaOS USB Creator")
            activeFocusOnTab: true
            onClicked: {
                root.reject()
            }
        },
        ImButtonRed {
            id: yesButton
            objectName: "yesButton"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: Style.buttonHeightStandard
            text: qsTr("Update")
            // Make the primary action button wider to encourage clicking
            // Layout.minimumWidth: Style.buttonWidthMinimum * 1.5
            // implicitWidth: Style.buttonWidthMinimum * 1.5
            accessibleDescription: qsTr("Open the ZimaOS website in your browser to download the latest version")
            activeFocusOnTab: true
            onClicked: {
                if (root.url && root.url.toString && root.url.toString().length > 0) {
                    if (ImageWriterSingleton) {
                        ImageWriterSingleton.openUrl(root.url)
                    } else {
                        Qt.openUrlExternally(root.url)
                    }
                }
                root.accept()
            }
        }
    ]
}
