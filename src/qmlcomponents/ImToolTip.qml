// SPDX-License-Identifier: Apache-2.0
import QtQuick
import QtQuick.Controls
import RpiImager

ToolTip {
    id: root
    padding: Style.spacingSmall
    margins: Style.spacingTiny
    implicitWidth: Math.min(Style.scaled(320),
                            parent && parent.Window.window ? parent.Window.window.width - margins * 2 : Style.scaled(320),
                            label.implicitWidth + leftPadding + rightPadding)
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSizePixelXs

    contentItem: Text {
        id: label
        text: root.text
        textFormat: Text.PlainText
        font: root.font
        color: Style.colorTextPrimary
        wrapMode: Text.Wrap
    }

    background: Rectangle {
        color: Style.colorSurfacePanel
        radius: Style.radiusCard
        border.color: Style.colorBorderSubtle
        border.width: Style.borderWidthDefault
        antialiasing: true
    }
}
