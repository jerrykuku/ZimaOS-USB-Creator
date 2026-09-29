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
    title: qsTr("Show system drives?")
    header: null
    width: Math.min(parent ? parent.width - Style.spacingPopupInset * 2 : Style.scaled(480), Style.scaled(480))
    height: Math.min(parent ? parent.height - Style.spacingPopupInset * 2 : 600,
                     contentLayout.implicitHeight + Style.spacingPopupInset * 2)

    signal confirmed()
    signal cancelled()
    property bool showRequested: false

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
            return ImageWriterSingleton.screenReaderActive ? [heading, explanation, riskText, selectionText] : []
        }, 0)
        registerFocusGroup("buttons", function() { return [keepFilterButton, showSystemButton] }, 1)
    }

    onAboutToShow: showRequested = false

    onOpened: {
        detailsScroll.contentItem.contentY = 0
        rebuildFocusOrder()
        if (ImageWriterSingleton.screenReaderActive)
            heading.forceActiveFocus()
        else
            keepFilterButton.forceActiveFocus()
    }

    // Apply the filter only after the dialog and its modal overlay have closed.
    // Escape and any other dismissal keep system drives hidden.
    onClosed: {
        if (showRequested)
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
            objectName: "unfilterDetailsScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: details.implicitHeight
            contentWidth: availableWidth
            contentHeight: details.implicitHeight

            ColumnLayout {
                id: details
                width: detailsScroll.availableWidth
                spacing: Style.spacingMedium

                FocusableText {
                    id: explanation
                    text: qsTr("System drives contain your operating system and may also contain personal files.")
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizePixelSm
                    color: Style.colorTextSecondary
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: warningDetails.implicitHeight + Style.spacingSmallPlus * 2
                    radius: Style.radiusCard
                    color: Style.colorSurfacePage
                    border.color: Style.colorBorderSubtle

                    ColumnLayout {
                        id: warningDetails
                        anchors.fill: parent
                        anchors.margins: Style.spacingSmallPlus
                        spacing: Style.spacingSmall

                        FocusableText {
                            id: riskText
                            text: qsTr("Writing to the wrong drive will permanently erase its data and may prevent your computer from starting.")
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizePixelSm
                            color: Style.formLabelErrorColor
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        FocusableText {
                            id: selectionText
                            text: qsTr("You will still need to select a device and confirm its name before writing to a system drive.")
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizePixelSm
                            color: Style.colorTextSecondary
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
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

            ImButtonRed {
                id: keepFilterButton
                objectName: "keepSystemDrivesHiddenButton"
                text: qsTr("Keep hidden")
                accessibleDescription: qsTr("Keep system drives hidden to prevent accidental damage to your operating system")
                activeFocusOnTab: true
                Layout.preferredHeight: Style.buttonHeightStandard
                Layout.minimumHeight: Style.buttonHeightStandard
                Layout.maximumHeight: Style.buttonHeightStandard
                Layout.preferredWidth: Math.max(Style.scaled(90), implicitWidth)
                onClicked: root.close()
            }

            ImButton {
                id: showSystemButton
                objectName: "showSystemDrivesButton"
                text: qsTr("Show system drives")
                accessibleDescription: qsTr("Remove the safety filter and display system drives in the storage device list")
                activeFocusOnTab: true
                Layout.preferredHeight: Style.buttonHeightStandard
                Layout.minimumHeight: Style.buttonHeightStandard
                Layout.maximumHeight: Style.buttonHeightStandard
                Layout.preferredWidth: Math.max(Style.scaled(90), implicitWidth)
                onClicked: {
                    root.showRequested = true
                    root.close()
                }
            }
        }
    }
}
