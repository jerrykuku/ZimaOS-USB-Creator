/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025 Raspberry Pi Ltd
 */

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../../qmlcomponents"

import RpiImager

BaseDialog {
    id: popup

    // Keep this custom popup in the application scene so macOS does not add a
    // rectangular native shadow around its rounded QML surface.
    popupType: Popup.Item

    // Match the rounded application surface used by the main window.
    background: Rectangle {
        color: Style.colorSurfacePanel
        radius: Style.radiusPanel
        border.color: Style.colorBorderSubtle
        border.width: Style.sectionBorderWidth
        antialiasing: true
        clip: true
        layer.enabled: true
        layer.smooth: true
    }

    // Override default height for this more complex dialog
    height: Math.min(parent ? parent.height - Style.spacingPopupInset * 2 : 600,
                     contentLayout.implicitHeight + Style.spacingPopupInset * 2)

    // imageWriter is inherited from BaseDialog
    // Optional reference to the wizard container for ephemeral flags
    property var wizardContainer: null

    property bool initialized: false
    property bool isInitializing: false

    // Custom escape handling
    function escapePressed() {
        popup.close()
    }

    title: qsTr("App Options")
    header: null
    width: Math.min(parent ? parent.width - Style.spacingPopupInset * 2 : Style.scaled(480), Style.scaled(480))
    property string repositorySummary: ""

    component SettingsSwitch: ImOptionPill {
        emphasized: false
        Layout.preferredHeight: Style.scaled(32)
    }

    component SettingsButton: ImOptionButton {
        emphasized: false
        Layout.preferredHeight: Style.scaled(36)
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Style.colorBorderSubtle
        Accessible.ignored: true
    }

    // Register focus groups when component is ready
    Component.onCompleted: {
        // Register focus groups
        registerFocusGroup("header", function(){
            // Only include header text when screen reader is active (otherwise it's not focusable)
            if (popup.imageWriter && popup.imageWriter.isScreenReaderActive()) {
                return [headerText]
            }
            return []
        }, 0)
        registerFocusGroup("options", function(){
            var items = [chkBeep.focusItem, chkEject.focusItem, chkDisableWarnings.focusItem, editRepoButton.focusItem]
            // Only include secure boot key button if visible
            if (secureBootKeyButton.visible)
                items.push(secureBootKeyButton.focusItem)
            return items
        }, 1)
        registerFocusGroup("buttons", function(){
            return [cancelButton, saveButton]
        }, 2)
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Style.spacingTiny
        spacing: Style.spacingSmallPlus

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.spacingXSmall

            FocusableHeading {
                id: headerText
                text: popup.title
                font.family: Style.fontFamilyBold
                font.pixelSize: Style.fontSizeHeadingChrome
                font.bold: true
                color: Style.colorTextPrimary
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            Text {
                text: qsTr("Manage writing preferences and image sources.")
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizePixelXs
                color: Style.colorTextSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        ImScrollView {
            id: optionsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: optionsLayout.implicitHeight
            contentWidth: availableWidth
            contentHeight: optionsLayout.implicitHeight

            ColumnLayout {
                id: optionsLayout
                width: optionsScroll.availableWidth
                spacing: Style.spacingTiny

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: preferencesLayout.implicitHeight + Style.spacingSmallPlus * 2
                    radius: Style.radiusCard
                    color: Style.colorSurfacePage
                    border.color: Style.colorBorderSubtle

                    ColumnLayout {
                        id: preferencesLayout
                        anchors.fill: parent
                        anchors.margins: Style.spacingSmallPlus
                        spacing: 0
                        SettingsSwitch {
                            id: chkBeep
                            objectName: "AppOptionsDialogchkBeep"
                            text: qsTr("Play sound when finished")
                            accessibleDescription: imageWriter.isBeepAvailable()
                                ? qsTr("Play an audio notification when the image write process completes")
                                : qsTr("Audio notification unavailable - no viable audio player found on this system")
                            Layout.fillWidth: true
                            enabled: imageWriter.isBeepAvailable()
                            Component.onCompleted: {
                                focusItem.activeFocusOnTab = true
                            }
                        }
                        Divider {}
                        SettingsSwitch {
                            id: chkEject
                            objectName: "AppOptionsDialogchkEject"
                            text: qsTr("Eject media when finished")
                            accessibleDescription: qsTr("Automatically eject the storage device when the write process completes successfully")
                            Layout.fillWidth: true
                            Component.onCompleted: {
                                focusItem.activeFocusOnTab = true
                            }
                        }
                        Divider {}
                        SettingsSwitch {
                            id: chkDisableWarnings
                            objectName: "AppOptionsDialogchkDisableWarnings"
                            text: qsTr("Disable warnings")
                            accessibleDescription: qsTr("Skip confirmation dialogs before writing images (advanced users only)")
                            Layout.fillWidth: true
                            Component.onCompleted: {
                                focusItem.activeFocusOnTab = true
                            }
                            onCheckedChanged: {
                                // Don't trigger confirmation dialog during initialization
                                if (popup.isInitializing) {
                                    return;
                                }

                                if (checked) {
                                    // Confirm before enabling this risky setting
                                    confirmDisableWarnings.open();
                                }
                            }
                        }
                        Text {
                            text: qsTr("Skip the confirmation before erasing a device.")
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizePixelXs
                            color: Style.colorTextSecondary
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.bottomMargin: Style.spacingXSmall
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: repositoryLayout.implicitHeight + Style.spacingSmallPlus * 2
                    radius: Style.radiusCard
                    color: Style.colorSurfacePage
                    border.color: Style.colorBorderSubtle

                    ColumnLayout {
                        id: repositoryLayout
                        anchors.fill: parent
                        anchors.margins: Style.spacingSmallPlus
                        spacing: 0
                        SettingsButton {
                            id: editRepoButton
                            objectName: "AppOptionsDialogeditRepoButton"
                            text: qsTr("Content Repository")
                            btnText: qsTr("Edit")
                            accessibleDescription: qsTr("Change the source of operating system images between official ZimaOS repository and custom sources")
                            Layout.fillWidth: true
                            // Disable while write is in progress to prevent changing source during write
                            enabled: imageWriter.writeState === ImageWriterSingleton.Idle ||
                                     imageWriter.writeState === ImageWriterSingleton.Succeeded ||
                                     imageWriter.writeState === ImageWriterSingleton.Failed ||
                                     imageWriter.writeState === ImageWriterSingleton.Cancelled
                            Component.onCompleted: {
                                focusItem.activeFocusOnTab = true
                            }
                            onClicked: {
                                if (!repoDialog.wizardContainer) {
                                    repoDialog.wizardContainer = popup.wizardContainer
                                }
                                popup.close()
                                Qt.callLater(function () {
                                    repoDialog.open()
                                });
                            }
                        }
                        Text {
                            text: popup.repositorySummary
                            textFormat: Text.PlainText
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizePixelXs
                            color: Style.colorTextSecondary
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }
                }
                SettingsButton {
                    id: secureBootKeyButton
                    text: qsTr("Secure Boot RSA Key")
                    btnText: rsaKeyPath.text ? qsTr("Change") : qsTr("Select")
                    accessibleDescription: qsTr("Select an RSA 2048-bit private key for signing boot images in secure boot mode")
                    Layout.fillWidth: true
                    // Only show if secure boot is available (via OS capabilities or CLI flag)
                    visible: (wizardContainer && wizardContainer.secureBootAvailable) ||
                             imageWriter.isSecureBootForcedByCliFlag() ||
                             imageWriter.checkSWCapability("secure_boot")
                    // Disable while write is in progress
                    enabled: imageWriter.writeState === ImageWriterSingleton.Idle ||
                             imageWriter.writeState === ImageWriterSingleton.Succeeded ||
                             imageWriter.writeState === ImageWriterSingleton.Failed ||
                             imageWriter.writeState === ImageWriterSingleton.Cancelled
                    Component.onCompleted: {
                        focusItem.activeFocusOnTab = true
                    }
                    onClicked: {
                        // Prefer native file dialog via Imager's wrapper, but only if available
                        if (imageWriter.nativeFileDialogAvailable()) {
                            var keyPath = imageWriter.getNativeOpenFileName(
                                qsTr("Select RSA Private Key"),
                                "",
                                qsTr("PEM Files (*.pem);;All Files (*)")
                            );
                            if (keyPath) {
                                rsaKeyPath.text = keyPath;
                            }
                        } else {
                            // Fallback to QML dialog (forced non-native)
                            rsaKeyFileDialog.open();
                        }
                    }

                    Text {
                        id: rsaKeyPath
                        text: ""
                        visible: false
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Style.colorBorderSubtle
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacingSmallPlus

            Text {
                id: versionText
                text: qsTr("Version: %1").arg(imageWriter.constantVersion())
                font.pixelSize: Style.fontSizePixelXs
                font.family: Style.fontFamily
                color: Style.colorTextSecondary
                visible: !imageWriter.hasWindowDecorations()
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
            }
            Item { Layout.fillWidth: true; visible: !versionText.visible }

            ImButton {
                id: cancelButton
                objectName: "AppOptionsDialogcancelButton"
                text: CommonStrings.cancel
                accessibleDescription: qsTr("Close the options dialog without saving any changes")
                Layout.preferredHeight: Style.buttonHeightStandard
                Layout.preferredWidth: Math.max(Style.scaled(90), implicitWidth)
                onClicked: popup.close()
            }

            ImButtonRed {
                id: saveButton
                objectName: "AppOptionsDialogsaveButton"
                text: qsTr("Save")
                accessibleDescription: qsTr("Save the selected options and apply them to ZimaOS USB Creator")
                Layout.preferredHeight: Style.buttonHeightStandard
                Layout.preferredWidth: Math.max(Style.scaled(90), implicitWidth)
                onClicked: {
                    popup.applySettings()
                    popup.close()
                }
            }
        }
    }

    RepositoryDialog {
        id: repoDialog
        parent: popup.parent
        imageWriter: popup.imageWriter
        wizardContainer: popup.wizardContainer
    }

    // File dialog for RSA key selection (embedded mode)
    ImFileDialog {
        id: rsaKeyFileDialog
        imageWriter: popup.imageWriter
        parent: popup.parent
        anchors.centerIn: parent
        dialogTitle: qsTr("Select RSA Private Key")
        nameFilters: [qsTr("PEM Files (*.pem)"), qsTr("All Files (*)")]
        Component.onCompleted: {
            // Default to ~/.ssh folder if it exists
            if (Qt.platform.os === "osx" || Qt.platform.os === "darwin") {
                var home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
                var url = "file://" + home + "/.ssh"
                rsaKeyFileDialog.currentFolder = url
                rsaKeyFileDialog.folder = url
            } else if (Qt.platform.os === "linux") {
                var lhome = StandardPaths.writableLocation(StandardPaths.HomeLocation)
                var lurl = "file://" + lhome + "/.ssh"
                rsaKeyFileDialog.currentFolder = lurl
                rsaKeyFileDialog.folder = lurl
            } else if (Qt.platform.os === "windows") {
                var whome = StandardPaths.writableLocation(StandardPaths.HomeLocation)
                var wurl = "file:///" + whome + "/.ssh"
                rsaKeyFileDialog.currentFolder = wurl
                rsaKeyFileDialog.folder = wurl
            }
        }
        onAccepted: {
            if (selectedFile && selectedFile.toString().length > 0) {
                var filePath = selectedFile.toString().replace(/^file:\/\//, "")
                rsaKeyPath.text = filePath
            }
        }
    }

    function initialize() {
        repositorySummary = imageWriter.customRepo() ? imageWriter.customRepoHost() : qsTr("ZimaOS (default)")
        if (!initialized) {
            // Set flag to prevent onCheckedChanged handlers from triggering dialogs
            isInitializing = true;

            // Load current settings from ImageWriter
            // Only enable beep if it's both saved as enabled AND available on this system
            chkBeep.checked = imageWriter.getBoolSetting("beep") && imageWriter.isBeepAvailable();
            chkEject.checked = imageWriter.getBoolSetting("eject");
            // Do not load from QSettings; keep ephemeral
            chkDisableWarnings.checked = popup.wizardContainer ? popup.wizardContainer.disableWarnings : false;
            // Load secure boot RSA key path
            var keyPath = imageWriter.getStringSetting("secureboot_rsa_key");
            rsaKeyPath.text = keyPath || "";

            initialized = true;
            // Clear initialization flag
            isInitializing = false;

        }
    }

    function applySettings() {
        // Save settings to ImageWriter
        // Only save beep as enabled if it's actually available on this system
        imageWriter.setSetting("beep", chkBeep.checked && imageWriter.isBeepAvailable());
        imageWriter.setSetting("eject", chkEject.checked);
        imageWriter.setSetting("secureboot_rsa_key", rsaKeyPath.text);
        // Do not persist disable_warnings; set ephemeral flag only
        if (popup.wizardContainer)
            popup.wizardContainer.disableWarnings = chkDisableWarnings.checked;
    }

    onClosed: initialized = false

    onOpened: {
        initialize()
        rebuildFocusOrder()
        focusInitialItem()
    }

    // Confirmation dialog for disabling warnings
    BaseDialog {
        id: confirmDisableWarnings
        objectName: "disableWarningsDialog"
        imageWriter: popup.imageWriter
        parent: popup.parent
        anchors.centerIn: parent
        popupType: Popup.Item
        title: qsTr("Disable warnings?")
        header: null
        width: Math.min(parent ? parent.width - Style.spacingPopupInset * 2 : Style.scaled(460), Style.scaled(460))
        height: Math.min(parent ? parent.height - Style.spacingPopupInset * 2 : 600,
                         contentLayout.implicitHeight + Style.spacingPopupInset * 2)

        background: Rectangle {
            color: Style.colorSurfacePanel
            radius: Style.radiusPanel
            border.color: Style.colorBorderSubtle
            border.width: Style.borderWidthDefault
            antialiasing: true
        }

        onClosed: {
            // If dialog was closed without confirming, revert the toggle
            if (!confirmAccepted) {
                chkDisableWarnings.checked = false;
            }
            confirmAccepted = false;
            chkDisableWarnings.focusItem.forceActiveFocus();
        }

        property bool confirmAccepted: false

        onOpened: {
            rebuildFocusOrder()
            if (popup.imageWriter && popup.imageWriter.isScreenReaderActive())
                confirmTitleText.forceActiveFocus()
            else
                confirmCancelButton.forceActiveFocus()
        }

        // Custom escape handling
        function escapePressed() {
            confirmDisableWarnings.close()
        }

        // Register focus groups when component is ready
        Component.onCompleted: {
            registerFocusGroup("content", function(){
                // Only include text elements when screen reader is active (otherwise they're not focusable)
                if (popup.imageWriter && popup.imageWriter.isScreenReaderActive()) {
                    return [confirmTitleText, confirmDescriptionText, systemDriveProtectionText]
                }
                return []
            }, 0)
            registerFocusGroup("buttons", function(){
                return [confirmCancelButton, confirmDisableButton]
            }, 1)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Style.spacingTiny
            spacing: Style.spacingMedium

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacingTiny

                Image {
                    Layout.preferredWidth: Style.scaled(24)
                    Layout.preferredHeight: Style.scaled(24)
                    source: "../../icons/ic_warning_24px.svg"
                    sourceSize: Qt.size(width, height)
                    Accessible.ignored: true
                }

                FocusableHeading {
                    id: confirmTitleText
                    text: confirmDisableWarnings.title
                    font.family: Style.fontFamilyBold
                    font.pixelSize: Style.fontSizeHeadingChrome
                    font.bold: true
                    color: Style.colorTextPrimary
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            ImScrollView {
                id: warningScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: warningDetails.implicitHeight
                contentWidth: availableWidth
                contentHeight: warningDetails.implicitHeight

                ColumnLayout {
                    id: warningDetails
                    width: warningScroll.availableWidth
                    spacing: Style.spacingMedium

                    FocusableText {
                        id: confirmDescriptionText
                        text: qsTr("You will no longer be asked to confirm before writing an image.")
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizePixelSm
                        color: Style.colorTextSecondary
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: protectionDetails.implicitHeight + Style.spacingSmallPlus * 2
                        radius: Style.radiusCard
                        color: Style.colorSurfacePage
                        border.color: Style.colorBorderSubtle

                        ColumnLayout {
                            id: protectionDetails
                            anchors.fill: parent
                            anchors.margins: Style.spacingSmallPlus
                            spacing: Style.spacingXSmall

                            Text {
                                text: qsTr("System drive protection stays on")
                                font.family: Style.fontFamilyBold
                                font.pixelSize: Style.fontSizePixelSm
                                font.bold: true
                                color: Style.colorTextPrimary
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                Accessible.ignored: true
                            }

                            FocusableText {
                                id: systemDriveProtectionText
                                text: qsTr("Selecting a system drive still requires its exact name.")
                                font.family: Style.fontFamily
                                font.pixelSize: Style.fontSizePixelXs
                                color: Style.colorTextSecondary
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                Accessible.name: qsTr("System drive protection stays on") + ". " + text
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.borderWidthDefault
                color: Style.colorBorderSubtle
                Accessible.ignored: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacingSmallPlus
                Item { Layout.fillWidth: true }

                ImButton {
                    id: confirmCancelButton
                    objectName: "keepWarningsButton"
                    text: qsTr("Keep warnings")
                    accessibleDescription: qsTr("Keep warnings enabled and return to the options dialog")
                    Layout.preferredHeight: Style.buttonHeightStandard
                    Layout.preferredWidth: Math.max(Style.scaled(100), implicitWidth)
                    onClicked: confirmDisableWarnings.close()
                }

                ImButtonRed {
                    id: confirmDisableButton
                    objectName: "disableWarningsButton"
                    text: qsTr("Disable anyway")
                    accessibleDescription: qsTr("Disable confirmation prompts before writing images, requiring only exact name entry for system drives")
                    Layout.preferredHeight: Style.buttonHeightStandard
                    Layout.preferredWidth: Math.max(Style.scaled(100), implicitWidth)

                    background: Rectangle {
                        radius: Style.radiusButton
                        color: confirmDisableButton.down ? Qt.darker(Style.colorTextErrorStrong, 1.25)
                               : confirmDisableButton.hovered ? Qt.darker(Style.colorTextErrorStrong, 1.1)
                               : Style.colorTextErrorStrong
                        border.width: confirmDisableButton.visualFocus ? Style.focusOutlineWidth : 0
                        border.color: Style.colorTextOnAccent
                        antialiasing: true
                    }

                    onClicked: {
                        confirmDisableWarnings.confirmAccepted = true;
                        confirmDisableWarnings.close();
                    }
                }
            }
        }
    }
}
