/*
 * SPDX-License-Identifier: Apache-2.0
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../qmlcomponents"
import RpiImager

BaseDialog {
    id: root

    property string titleText: qsTranslate("main", "Error")
    property string message: ""

    title: titleText
    header: null
    popupType: Popup.Item
    width: Math.min(parent ? parent.width - Style.spacingPopupInset * 2 : Style.scaled(480), Style.scaled(480))
    height: Math.min(parent ? parent.height - Style.spacingPopupInset * 2 : 600,
                     contentLayout.implicitHeight + Style.spacingPopupInset * 2)

    background: Rectangle {
        color: Style.colorSurfacePanel
        radius: Style.radiusPanel
        border.color: Style.colorBorderSubtle
        border.width: Style.borderWidthDefault
        antialiasing: true
    }

    Component.onCompleted: {
        registerFocusGroup("content", function() {
            return ImageWriterSingleton.screenReaderActive ? [errorTitle, errorMessage] : []
        }, 0)
        registerFocusGroup("buttons", function() { return [closeButton] }, 1)
    }

    onOpened: {
        detailsScroll.contentItem.contentY = 0
        rebuildFocusOrder()
        if (ImageWriterSingleton.screenReaderActive)
            errorTitle.forceActiveFocus()
        else
            closeButton.forceActiveFocus()
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
                id: errorTitle
                objectName: "errorDialogTitle"
                text: root.titleText
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
            objectName: "errorDetailsScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: detailsCard.implicitHeight
            contentWidth: availableWidth
            contentHeight: detailsCard.implicitHeight

            Rectangle {
                id: detailsCard
                width: detailsScroll.availableWidth
                height: implicitHeight
                implicitHeight: detailsLayout.implicitHeight + Style.spacingSmallPlus * 2
                radius: Style.radiusCard
                color: Style.colorSurfacePage
                border.color: Style.colorBorderSubtle

                ColumnLayout {
                    id: detailsLayout
                    anchors.fill: parent
                    anchors.margins: Style.spacingSmallPlus
                    spacing: Style.spacingTiny

                    Text {
                        text: qsTr("Error details")
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizePixelXs
                        color: Style.colorTextSecondary
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        Accessible.ignored: true
                    }

                    FocusableText {
                        id: errorMessage
                        objectName: "errorDialogMessage"
                        // Errors can contain either styled HTML or plain line breaks.
                        text: root.message.replace(/\r\n?/g, "\n").replace(/\n/g, "<br>")
                        textFormat: Text.StyledText
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizePixelSm
                        color: Style.colorTextPrimary
                        wrapMode: Text.Wrap
                        lineHeight: 1.4
                        Layout.fillWidth: true
                        Accessible.name: text.replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]+>/g, "")
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
                id: closeButton
                objectName: "errorDialogCloseButton"
                text: qsTr("Got it")
                accessibleDescription: qsTr("Close the error details")
                Layout.preferredHeight: Style.buttonHeightStandard
                Layout.maximumHeight: Style.buttonHeightStandard
                Layout.preferredWidth: Math.max(Style.scaled(90), implicitWidth)
                onClicked: root.close()
            }
        }
    }
}
