// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2025 Raspberry Pi Ltd

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RpiImager
import "../../qmlcomponents"

BaseDialog {
    id: root

    required property Item overlayParent
    parent: overlayParent
    anchors.centerIn: parent
    popupType: Popup.Item
    closePolicy: Popup.CloseOnEscape
    title: qsTr("Use this system drive?")
    header: null
    width: Math.min(parent ? parent.width - Style.spacingPopupInset * 2 : Style.scaled(520), Style.scaled(520))
    height: Math.min(parent ? parent.height - Style.spacingPopupInset * 2 : 600,
                     contentLayout.implicitHeight + Style.spacingPopupInset * 2)

    property string driveName: ""
    property string device: ""
    property real deviceSize: 0
    property string sizeStr: ""
    property var mountpoints: []
    property bool selectionConfirmed: false
    readonly property bool nameMatches: driveName.length > 0 && nameInput.text === driveName

    signal confirmed()
    signal cancelled()

    background: Rectangle {
        color: Style.colorSurfacePanel
        radius: Style.radiusPanel
        border.color: Style.colorBorderSubtle
        border.width: Style.borderWidthDefault
        antialiasing: true
    }

    function escapePressed() { root.close() }

    Component.onCompleted: {
        registerFocusGroup("warning", function() {
            return ImageWriterSingleton.screenReaderActive
                    ? [heading, riskText, driveNameText, deviceText, sizeText, mountpointsText, inputLabel] : []
        }, 0)
        registerFocusGroup("input", function() { return [nameInput] }, 1)
        registerFocusGroup("buttons", function() { return [cancelButton, continueButton] }, 2)
    }

    onAboutToShow: {
        selectionConfirmed = false
        nameInput.text = ""
    }
    onOpened: {
        detailsScroll.contentItem.contentY = 0
        rebuildFocusOrder()
        if (ImageWriterSingleton.screenReaderActive)
            heading.forceActiveFocus()
        else
            cancelButton.forceActiveFocus()
    }
    // Let the modal overlay finish closing before storage selection advances.
    onClosed: {
        if (selectionConfirmed)
            root.confirmed()
        else
            root.cancelled()
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
                id: heading
                text: root.title
                font.family: Style.fontFamilyBold
                font.pixelSize: Style.fontSizeHeadingChrome
                font.bold: true
                color: Style.colorTextPrimary
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }

        ImScrollView {
            id: detailsScroll
            objectName: "systemDriveDetailsScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: details.implicitHeight
            contentWidth: availableWidth
            contentHeight: details.implicitHeight

            ColumnLayout {
                id: details
                width: detailsScroll.availableWidth
                spacing: Style.spacingSmallPlus

                FocusableText {
                    id: riskText
                    text: qsTranslate("ConfirmUnfilterDialog", "Writing to the wrong drive will permanently erase its data and may prevent your computer from starting.")
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizePixelSm
                    color: Style.colorTextErrorStrong
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: driveDetails.implicitHeight + Style.spacingSmallPlus * 2
                    radius: Style.radiusCard
                    color: Style.colorSurfacePage
                    border.color: Style.colorBorderSubtle
                    Accessible.role: Accessible.Grouping
                    Accessible.name: qsTr("Drive information")

                    ColumnLayout {
                        id: driveDetails
                        anchors.fill: parent
                        anchors.margins: Style.spacingSmallPlus
                        spacing: Style.spacingXSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.spacingTiny

                            Image {
                                Layout.preferredWidth: Style.scaled(24)
                                Layout.preferredHeight: Style.scaled(24)
                                Layout.alignment: Qt.AlignTop
                                source: "../../icons/ic_storage_40px.svg"
                                sourceSize: Qt.size(width, height)
                                opacity: 0.65
                                Accessible.ignored: true
                            }

                            FocusableText {
                                id: driveNameText
                                objectName: "systemDriveName"
                                text: root.driveName
                                textFormat: Text.PlainText
                                font.family: Style.fontFamilyBold
                                font.pixelSize: Style.fontSizePixelSm
                                font.bold: true
                                color: Style.colorTextPrimary
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Accessible.name: qsTr("Drive name to type: %1").arg(text)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.spacingSmallPlus

                            FocusableText {
                                id: deviceText
                                text: root.device
                                textFormat: Text.PlainText
                                font.family: Style.fontFamily
                                font.pixelSize: Style.fontSizePixelXs
                                color: Style.colorTextSecondary
                                wrapMode: Text.WrapAnywhere
                                visible: text.length > 0
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Accessible.name: CommonStrings.device + " " + text
                            }

                            FocusableText {
                                id: sizeText
                                text: qsTr("Size: %1").arg(root.sizeStr)
                                textFormat: Text.PlainText
                                font.family: Style.fontFamily
                                font.pixelSize: Style.fontSizePixelXs
                                color: Style.colorTextSecondary
                                wrapMode: Text.Wrap
                                Layout.maximumWidth: detailsScroll.availableWidth / 2 - Style.spacingSmallPlus
                                Layout.alignment: Qt.AlignTop
                            }
                        }

                        FocusableText {
                            id: mountpointsText
                            objectName: "systemDriveMountpoints"
                            text: qsTr("Mounted as: %1").arg(root.mountpoints && root.mountpoints.length > 0
                                                          ? root.mountpoints.join(", ") : qsTr("Not mounted"))
                            textFormat: Text.PlainText
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizePixelXs
                            color: Style.colorTextSecondary
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.spacingTiny

                    FocusableText {
                        id: inputLabel
                        text: qsTr("To continue, type the exact drive name below:")
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizePixelSm
                        color: Style.colorTextPrimary
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Keep the original typed-name restriction; ImTextField's
                    // clipboard menu is intentionally not used for this field.
                    TextField {
                        id: nameInput
                        objectName: "systemDriveNameInput"
                        Layout.fillWidth: true
                        implicitHeight: Style.scaled(36)
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizePixelSm
                        color: Style.colorTextPrimary
                        placeholderTextColor: Style.colorTextSecondary
                        leftPadding: Style.spacingSmallPlus
                        rightPadding: Style.spacingSmallPlus
                        topPadding: 0
                        bottomPadding: 0
                        verticalAlignment: TextInput.AlignVCenter
                        placeholderText: qsTr("Type drive name exactly as shown above")
                        activeFocusOnTab: true
                        focusPolicy: Qt.TabFocus
                        Accessible.name: qsTr("Drive name input. Type exactly: %1. %2").arg(root.driveName).arg(placeholderText)
                        Accessible.description: ""

                        background: Rectangle {
                            color: Style.colorSurfacePanel
                            radius: Style.radiusButton
                            border.width: nameInput.activeFocus ? Style.focusOutlineWidth : Style.borderWidthDefault
                            border.color: nameInput.activeFocus ? Style.colorAccentPrimary : Style.colorBorderDefault
                            antialiasing: true
                        }

                        Keys.onPressed: (event) => {
                            if ((event.key === Qt.Key_V && (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) ||
                                (event.key === Qt.Key_Insert && (event.modifiers & Qt.ShiftModifier))) {
                                event.accepted = true
                            }
                        }
                        onAccepted: {
                            if (root.nameMatches)
                                continueButton.clicked()
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton | Qt.MiddleButton
                            onPressed: (mouse) => { mouse.accepted = true }
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

        GridLayout {
            id: actions
            readonly property bool stacked: cancelButton.implicitWidth + continueButton.implicitWidth
                                            + columnSpacing > width
            columns: stacked ? 1 : 3
            Layout.fillWidth: true
            columnSpacing: Style.spacingSmallPlus
            rowSpacing: Style.spacingTiny

            Item { visible: !actions.stacked; Layout.fillWidth: true }

            ImButton {
                id: cancelButton
                objectName: "cancelSystemDriveButton"
                text: CommonStrings.cancel
                font.capitalization: Font.MixedCase
                accessibleDescription: qsTr("Cancel operation and return to storage selection to choose a different device")
                Layout.fillWidth: actions.stacked
                Layout.preferredHeight: Style.scaled(Style.buttonHeightStandard)
                onClicked: root.close()
            }

            ImButtonRed {
                id: continueButton
                objectName: "confirmSystemDriveButton"
                text: CommonStrings.continueText
                font.capitalization: Font.MixedCase
                destructive: true
                accessibleDescription: qsTr("Proceed to write the image to this system drive after confirming the drive name")
                enabled: root.nameMatches
                Layout.fillWidth: actions.stacked
                Layout.preferredHeight: Style.scaled(Style.buttonHeightStandard)
                onClicked: {
                    if (!root.nameMatches)
                        return
                    root.selectionConfirmed = true
                    root.close()
                }
                onEnabledChanged: root.requestFocusRebuild()
            }
        }
    }
}
