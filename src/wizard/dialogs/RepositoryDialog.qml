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

    title: qsTr("Content Repository")
    header: null
    width: Math.min(parent ? parent.width - Style.spacingPopupInset * 2 : Style.scaled(480), Style.scaled(480))
    height: Math.min(parent ? parent.height - Style.spacingPopupInset * 2 : 600,
                     contentLayout.implicitHeight + Style.spacingPopupInset * 2)

    background: Rectangle {
        color: Style.colorSurfacePanel
        radius: Style.radiusPanel
        border.color: Style.colorBorderSubtle
        border.width: Style.sectionBorderWidth
        antialiasing: true
    }

    // imageWriter is inherited from BaseDialog
    property var wizardContainer: null

    property bool initialized: false
    property url selectedRepo: ""
    property string originalRepo: ""

    // Compact radio rows without the Material ripple/selection background.
    component RepositoryRadioButton: ImRadioButton {
        id: radio
        property string description: ""
        font: Qt.font({ family: Style.fontFamily, pixelSize: Style.fontSizePixelSm })
        leftPadding: 0
        rightPadding: 0
        topPadding: Style.spacingXSmall
        bottomPadding: Style.spacingXSmall
        spacing: Style.spacingSmallPlus
        implicitHeight: Math.max(Style.buttonHeightStandard, implicitContentHeight + topPadding + bottomPadding)
        background: Item {}
        contentItem: Item {
            implicitHeight: labels.implicitHeight
            Column {
                id: labels
                x: radio.indicator.width + radio.spacing
                width: parent.width - x
                spacing: Style.spacingXSmall
                Text {
                    id: sourceLabel
                    width: parent.width
                    text: radio.text
                    font: radio.font
                    color: Style.colorTextPrimary
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: radio.description
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizePixelXs
                    color: Style.colorTextSecondary
                    wrapMode: Text.WordWrap
                }
            }
        }
        indicator: Rectangle {
            implicitWidth: Style.scaled(20)
            implicitHeight: Style.scaled(20)
            x: radio.leftPadding
            y: radio.topPadding + (sourceLabel.implicitHeight - height) / 2
            radius: width / 2
            color: Style.transparent
            border.width: radio.visualFocus ? 3 : 2
            border.color: radio.checked || radio.visualFocus ? Style.colorAccentPrimary : Style.colorControlBorderInactive
            antialiasing: true

            Rectangle {
                anchors.centerIn: parent
                width: Style.scaled(10)
                height: width
                radius: width / 2
                color: Style.colorAccentPrimary
                visible: radio.checked
                antialiasing: true
            }
        }
    }

    component RepositoryTextField: ImTextField {
        id: field
        implicitHeight: Style.scaled(36)
        font: Qt.font({ family: Style.fontFamily, pixelSize: Style.fontSizePixelSm })
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
        registerFocusGroup("sources", function(){
            var items = [radioOfficial, radioCustomFile]
            if (radioCustomFile.checked)
                items.push(fieldCustomRepository, browseButton)
            items.push(radioCustomUri)
            if (radioCustomUri.checked)
                items.push(fieldCustomUri)
            return items
        }, 1)
        registerFocusGroup("buttons", function(){
            return [cancelButton, saveButton]
        }, 4)
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
                font.pixelSize: Style.fontSizeHeadingChrome
                font.family: Style.fontFamilyBold
                font.bold: true
                color: Style.colorTextPrimary
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            Text {
                text: qsTr("Choose where to get your operating system images.")
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizePixelXs
                color: Style.colorTextSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        ImScrollView {
            id: sourcesScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: sourcesCard.implicitHeight
            contentWidth: availableWidth
            contentHeight: sourcesCard.implicitHeight

            Rectangle {
                id: sourcesCard
                width: sourcesScroll.availableWidth
                height: implicitHeight
                implicitHeight: optionsLayout.implicitHeight + 20
                radius: Style.radiusCard
                color: Style.colorSurfacePage
                border.color: Style.colorBorderSubtle

                ColumnLayout {
                    id: optionsLayout
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 0
                    ButtonGroup { id: repoGroup }

                    RepositoryRadioButton {
                        id: radioOfficial
                        objectName: "RepositoryDialogradioOfficial"
                        text: qsTr("ZimaOS (default)")
                        description: qsTr("Official ZimaOS images, ready to install.")
                        accessibleDescription: qsTr("Use the official ZimaOS operating system repository")
                        checked: true
                        ButtonGroup.group: repoGroup
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: Style.spacingXSmall
                        Layout.bottomMargin: Style.spacingXSmall
                        implicitHeight: 1
                        color: Style.colorBorderSubtle
                        Accessible.ignored: true
                    }
                    RepositoryRadioButton {
                        id: radioCustomFile
                        objectName: "RepositoryDialogradioCustomFile"
                        text: qsTr("Use custom file")
                        description: qsTr("Load an image list from a file on your computer.")
                        accessibleDescription: qsTr("Load operating system list from a JSON file on your computer")
                        ButtonGroup.group: repoGroup
                        Layout.fillWidth: true
                        onCheckedChanged: {
                            if (checked && popup.opened)
                                Qt.callLater(function() { fieldCustomRepository.forceActiveFocus() })
                        }
                    }
                    Rectangle {
                        id: fileControlGroup
                        Layout.fillWidth: true
                        Layout.leftMargin: Style.scaled(20) + Style.spacingSmallPlus
                        Layout.bottomMargin: Style.spacingXSmall
                        Layout.preferredHeight: Style.scaled(36)
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
                                objectName: "RepositoryDialogfieldCustomRepository"
                                text: popup.selectedRepo.toString() !== "" ? UrlFmt.display(popup.selectedRepo) : ""
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: 0
                                placeholderText: qsTr("Select a repository file")
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
                                implicitWidth: Math.max(Style.scaled(72), implicitContentWidth + leftPadding + rightPadding)
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
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: Style.spacingXSmall
                        Layout.bottomMargin: Style.spacingXSmall
                        implicitHeight: 1
                        color: Style.colorBorderSubtle
                        Accessible.ignored: true
                    }
                    RepositoryRadioButton {
                        id: radioCustomUri
                        objectName: "RepositoryDialogradioCustomUri"
                        text: qsTr("Use custom URL")
                        description: qsTr("Load an image list from a web address.")
                        accessibleDescription: qsTr("Download operating system list from a custom web address")
                        ButtonGroup.group: repoGroup
                        Layout.fillWidth: true
                        onCheckedChanged: {
                            if (checked && popup.opened)
                                Qt.callLater(function() { fieldCustomUri.forceActiveFocus() })
                        }
                    }
                    RepositoryTextField {
                        id: fieldCustomUri
                        objectName: "RepositoryDialogfieldCustomUri"
                        visible: radioCustomUri.checked
                        Layout.fillWidth: true
                        Layout.leftMargin: Style.scaled(20) + Style.spacingSmallPlus
                        trimWhitespace: true
                        placeholderText: "https://example.com/repo.json"
                        activeFocusOnTab: true
                        inputMethodHints: Qt.ImhUrlCharactersOnly

                        Accessible.name: qsTr("Custom repository URL")

                        // Use ImageWriter's validation method for consistency
                        property bool isValid: popup.imageWriter && popup.imageWriter.isValidRepoUrl(value)
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
                text: qsTr("Changing the source returns you to device selection.")
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizePixelXs
                color: Style.colorTextSecondary
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
            ImButton {
                id: cancelButton
                objectName: "RepositoryDialogcancelButton"
                text: CommonStrings.cancel
                accessibleDescription: qsTr("Close the repository dialog without changing the content source")
                Layout.preferredHeight: Style.buttonHeightStandard
                Layout.preferredWidth: Math.max(Style.scaled(90), implicitWidth)
                activeFocusOnTab: true
                onClicked: {
                    popup.initialized = false
                    popup.close();
                }
            }

            ImButtonRed {
                id: saveButton
                objectName: "RepositoryDialogsaveButton"
                enabled: (radioOfficial.checked
                         || (radioCustomFile.checked && popup.selectedRepo.toString() !== "")
                         || (radioCustomUri.checked && fieldCustomUri.isValid))
                         // Disable while write is in progress to prevent restarting during write
                         && (imageWriter.writeState === ImageWriterSingleton.Idle ||
                             imageWriter.writeState === ImageWriterSingleton.Succeeded ||
                             imageWriter.writeState === ImageWriterSingleton.Failed ||
                             imageWriter.writeState === ImageWriterSingleton.Cancelled)
                text: qsTr("Apply changes")
                accessibleDescription: qsTr("Apply the new content repository and restart the wizard from the beginning")
                Layout.preferredHeight: Style.buttonHeightStandard
                Layout.preferredWidth: Math.max(Style.scaled(90), implicitWidth)
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
        rebuildFocusOrder()
        focusInitialItem()
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
