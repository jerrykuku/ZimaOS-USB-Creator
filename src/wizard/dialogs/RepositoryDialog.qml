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
    popupType: Popup.Item

    // Dynamic width based on widest radio button or button row
    // Updates automatically when language/text changes
    implicitWidth: Math.max(
        Math.max(radioOfficial.naturalWidth, radioCustomFile.naturalWidth, radioCustomUri.naturalWidth),
        cancelButton.implicitWidth + saveButton.implicitWidth + Style.spacingMedium * 2
    ) + Style.spacingPopupInset * 2

    // imageWriter is inherited from BaseDialog
    property var wizardContainer: null

    property bool initialized: false
    property url selectedRepo: ""
    property string originalRepo: ""

    // Compact radio rows without the Material ripple/selection background.
    component RepositoryRadioButton: ImRadioButton {
        id: radio
        leftPadding: 0
        rightPadding: 0
        topPadding: Style.spacingTiny
        bottomPadding: Style.spacingTiny
        spacing: Style.spacingTiny
        implicitHeight: Math.max(Style.buttonHeightStandard, implicitContentHeight + topPadding + bottomPadding)
        background: Item {}
        indicator: Rectangle {
            implicitWidth: 20
            implicitHeight: 20
            x: radio.leftPadding
            y: (radio.height - height) / 2
            radius: width / 2
            color: Style.transparent
            border.width: 2
            border.color: radio.checked ? Style.colorAccentPrimary : Style.colorControlBorderInactive

            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: width
                radius: width / 2
                color: Style.colorAccentPrimary
                visible: radio.checked
            }
        }
    }

    component RepositoryTextField: ImTextField {
        id: field
        implicitHeight: Style.buttonHeightStandard
        font.pixelSize: Style.fontSizePixelSm
        leftPadding: Style.spacingSmallPlus
        rightPadding: Style.spacingSmallPlus
        topPadding: 0
        bottomPadding: 0
        verticalAlignment: TextInput.AlignVCenter
        background: Rectangle {
            color: Style.colorSurfacePanel
            radius: Style.radiusButton
            border.width: Style.borderWidthDefault
            border.color: field.activeFocus ? Style.colorAccentPrimary : Style.colorBorderSubtle
        }
    }

    Component.onCompleted: {
        registerFocusGroup("header", function(){
            // Only include header text when screen reader is active (otherwise it's not focusable)
            if (popup.imageWriter && popup.imageWriter.isScreenReaderActive()) {
                return [headerText]
            }
            return []
        }, 0)
        registerFocusGroup("sourceTypes", function(){
            return [radioOfficial, radioCustomFile, radioCustomUri]
        }, 1)
        registerFocusGroup("customFile", function(){
            return radioCustomFile.checked ? [fieldCustomRepository, browseButton] : []
        }, 2)
        registerFocusGroup("customUri", function(){
            return radioCustomUri.checked ? [fieldCustomUri] : []
        }, 3)
        registerFocusGroup("buttons", function(){
            return [cancelButton, saveButton]
        }, 4)
    }

    // Header
    Text {
        id: headerText
        text: qsTr("Content Repository")
        font.pixelSize: Style.fontSizeHeadingChrome
        font.family: Style.fontFamilyBold
        font.bold: true
        color: Style.formLabelColor
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        Accessible.role: Accessible.Heading
        Accessible.name: text + ", " + qsTr("Choose the source for operating system images")
        Accessible.ignored: false
        Accessible.focusable: popup.imageWriter ? popup.imageWriter.isScreenReaderActive() : false
        focusPolicy: (popup.imageWriter && popup.imageWriter.isScreenReaderActive()) ? Qt.TabFocus : Qt.NoFocus
        activeFocusOnTab: popup.imageWriter ? popup.imageWriter.isScreenReaderActive() : false
    }

    // Options section
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: optionsLayout.implicitHeight

        ColumnLayout {
            id: optionsLayout
            anchors.fill: parent
            anchors.margins: 0
            spacing: Style.spacingMedium

            WizardFormLabel {
                text: qsTr("Repository source:")
            }

            ButtonGroup { id: repoGroup }

            RepositoryRadioButton {
                id: radioOfficial
                text: qsTr("ZimaOS (default)")
                accessibleDescription: qsTr("Use the official ZimaOS operating system repository")
                checked: true
                ButtonGroup.group: repoGroup
                Layout.fillWidth: true  // Enable text wrapping for long translations
            }

            RepositoryRadioButton {
                id: radioCustomFile
                text: qsTr("Use custom file")
                accessibleDescription: qsTr("Load operating system list from a JSON file on your computer")
                checked: false
                ButtonGroup.group: repoGroup
                Layout.fillWidth: true  // Enable text wrapping for long translations
                onCheckedChanged: {
                    if (checked) {
                        Qt.callLater(function() {
                            fieldCustomRepository.forceActiveFocus()
                        })
                    }
                }
            }

            RepositoryRadioButton {
                id: radioCustomUri
                text: qsTr("Use custom URL")
                accessibleDescription: qsTr("Download operating system list from a custom web address")
                checked: false
                ButtonGroup.group: repoGroup
                Layout.fillWidth: true  // Enable text wrapping for long translations
                onCheckedChanged: {
                    if (checked) {
                        Qt.callLater(function() {
                            fieldCustomUri.forceActiveFocus()
                        })
                    }
                }
            }

            // One shared outline joins the path field and browse action.
            Rectangle {
                id: fileControlGroup
                Layout.fillWidth: true
                Layout.preferredHeight: Style.buttonHeightStandard
                visible: radioCustomFile.checked
                radius: Style.radiusButton
                color: Style.colorSurfacePanel
                border.width: Style.borderWidthDefault
                border.color: fieldCustomRepository.activeFocus || browseButton.visualFocus
                              ? Style.colorAccentPrimary : Style.colorBorderSubtle

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: fileControlGroup.border.width
                    spacing: 0

                    RepositoryTextField {
                        id: fieldCustomRepository
                        text: popup.selectedRepo.toString() !== "" ? UrlFmt.display(popup.selectedRepo) : ""
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        placeholderText: qsTr("Please select a custom repository json file")
                        readOnly: true
                        background: Item {}
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        Layout.preferredWidth: Style.borderWidthDefault
                        color: fileControlGroup.border.color
                    }

                    ImButton {
                        id: browseButton
                        text: CommonStrings.browse
                        accessibleDescription: qsTr("Select a custom repository JSON file from your computer")
                        Layout.fillHeight: true
                        implicitWidth: Math.max(80, implicitContentWidth + leftPadding + rightPadding)
                        background: Rectangle {
                            color: browseButton.down ? Style.colorSurfaceControlInactive
                                   : browseButton.hovered ? Style.colorSurfaceMuted : Style.colorSurfacePage
                            radius: Math.max(0, Style.radiusButton - fileControlGroup.border.width)
                            topLeftRadius: 0
                            bottomLeftRadius: 0
                        }
                        onClicked: {
                            // Prefer native file dialog via Imager's wrapper, but only if available
                            if (imageWriter.nativeFileDialogAvailable()) {
                                // Defer opening the native dialog until after the current event completes
                                Qt.callLater(function () {
                                    var path = popup.imageWriter.getNativeOpenFileName(
                                        qsTr("Select Repository"), "", CommonStrings.repoFiltersString);
                                    if (path) {
                                        popup.selectedRepo = UrlFmt.fromLocalFile(path);
                                    }
                                });
                            } else {
                                // Fallback to QML dialog (forced non-native)
                                repoFileDialog.open();
                            }
                        }
                    }
                }
            }

            RepositoryTextField {
                id: fieldCustomUri
                visible: radioCustomUri.checked
                Layout.fillWidth: true
                trimWhitespace: true
                placeholderText: "https://example.com/repo.json"
                font.pixelSize: Style.fontSizePixelSm
                activeFocusOnTab: true
                inputMethodHints: Qt.ImhUrlCharactersOnly

                // Use ImageWriter's validation method for consistency
                property bool isValid: popup.imageWriter && popup.imageWriter.isValidRepoUrl(value)
            }
        }
    }

    // Spacer
    Item {
        Layout.fillHeight: true
    }

    // Buttons section with background
    Rectangle {
        Layout.fillWidth: true
        // Ensure minimum width accommodates buttons
        Layout.minimumWidth: cancelButton.implicitWidth + saveButton.implicitWidth + Style.spacingMedium * 2
        Layout.preferredHeight: buttonRow.implicitHeight
        color: Style.colorSurfacePage

        RowLayout {
            id: buttonRow
            anchors.fill: parent
            anchors.margins: 0
            spacing: Style.spacingMedium

            Item {
                Layout.fillWidth: true
            }

            ImButton {
                id: cancelButton
                text: CommonStrings.cancel
                accessibleDescription: qsTr("Close the repository dialog without changing the content source")
                Layout.minimumWidth: Style.buttonWidthMinimum
                activeFocusOnTab: true
                onClicked: {
                    popup.initialized = false
                    popup.close();
                }
            }

            ImButtonRed {
                id: saveButton
                enabled: (radioOfficial.checked
                         || (radioCustomFile.checked && popup.selectedRepo.toString() !== "")
                         || (radioCustomUri.checked && fieldCustomUri.isValid))
                         // Disable while write is in progress to prevent restarting during write
                         && (imageWriter.writeState === ImageWriterSingleton.Idle ||
                             imageWriter.writeState === ImageWriterSingleton.Succeeded ||
                             imageWriter.writeState === ImageWriterSingleton.Failed ||
                             imageWriter.writeState === ImageWriterSingleton.Cancelled)
                // TODO: only show or enable when settings changed
                text: qsTr("Apply & Restart")
                accessibleDescription: qsTr("Apply the new content repository and restart the wizard from the beginning")
                Layout.minimumWidth: Style.buttonWidthMinimum
                // Allow button to grow to fit text
                implicitWidth: Math.max(Style.buttonWidthMinimum, implicitContentWidth + leftPadding + rightPadding)
                activeFocusOnTab: true
                onClicked: {
                    popup.applySettings();
                    popup.close();
                }
                onEnabledChanged: {
                    // Rebuild focus order when button becomes enabled/disabled
                    Qt.callLater(popup.rebuildFocusOrder)
                }
            }
        }
    }

    Connections {
        target: repoGroup
        function onCheckedButtonChanged() {
            popup.rebuildFocusOrder()
        }
    }

    function initialize() {
        if (!initialized) {
            initialized = true
            selectedRepo = ""
            fieldCustomUri.text = ""

            if (imageWriter.customRepo()) {
                // Get URL as string to check the scheme
                var repoStr = imageWriter.osListUrl().toString()
                if (repoStr.startsWith("file:")) {
                    radioOfficial.checked = false
                    radioCustomFile.checked = true
                    radioCustomUri.checked = false
                    selectedRepo = imageWriter.osListUrl()
                    originalRepo = repoStr
                } else if (repoStr.startsWith("http:") || repoStr.startsWith("https:")) {
                    radioOfficial.checked = false
                    radioCustomFile.checked = false
                    radioCustomUri.checked = true
                    fieldCustomUri.text = repoStr
                    originalRepo = repoStr
                } else {
                    radioOfficial.checked = true
                    radioCustomFile.checked = false
                    radioCustomUri.checked = false
                    originalRepo = ""
                }
            } else {
                radioOfficial.checked = true
                radioCustomFile.checked = false
                radioCustomUri.checked = false
                selectedRepo = ""
                originalRepo = ""
            }

            // Ensure focus order is built after initial state
            popup.rebuildFocusOrder()
        }
    }

    function applySettings() {
        // Save settings to ImageWriter
        // Only save repository setting if it has actually changed
        if (radioOfficial.checked && originalRepo !== "") {
            imageWriter.refreshOsListFromDefaultUrl()
            // reset wizard to device selection because the repository changed
            wizardContainer.resetWizard()
        } else if (radioCustomFile.checked && originalRepo !== selectedRepo.toString()) {
            imageWriter.refreshOsListFrom(selectedRepo)
            // reset wizard to device selection because the repository changed
            wizardContainer.resetWizard()
        } else if (radioCustomUri.checked && originalRepo !== fieldCustomUri.value) {
            // QML auto-converts string to QUrl for C++ method
            imageWriter.refreshOsListFrom(fieldCustomUri.value)
            // reset wizard to device selection because the repository changed
            wizardContainer.resetWizard()
        }
        initialized = false
    }

    onClosed: initialized = false

    onOpened: {
        initialize()
    }

    property alias repoFileDialog: repoFileDialog

    ImFileDialog {
        id: repoFileDialog
        imageWriter: popup.imageWriter
        dialogTitle: qsTr("Select custom repository")
        nameFilters: CommonStrings.repoFiltersList
        onAccepted: {
            popup.selectedRepo = selectedFile;
        }
        onRejected:
        // No-op; user cancelled
        {}
    }
}
