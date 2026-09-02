/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2022 Raspberry Pi Ltd
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import RpiImager

Button {
    id: control
    font.family: Style.fontFamily
    font.pixelSize: Style.buttonFontSize
    font.capitalization: Font.AllUppercase

    implicitHeight: Style.buttonHeightStandard
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
    topPadding: Style.buttonPadding
    bottomPadding: Style.buttonPadding
    leftPadding: 12
    rightPadding: 12
    
    // Allow instances to provide a custom accessibility description
    property string accessibleDescription: ""
    
    background: Rectangle {
        color: control.enabled
               ? (control.activeFocus
                   ? Style.button2HoveredBackgroundColor
                   : (control.hovered ? Style.button2HoveredBackgroundColor : Style.button2BackgroundColor))
               : Style.buttonDisabledBackgroundColor
        radius: (control.imageWriter && control.imageWriter.isEmbeddedMode()) ? Style.buttonBorderRadiusEmbedded : 8
        antialiasing: true  // Smooth edges at non-integer scale factors
        clip: true  // Prevent content overflow at non-integer scale factors
    }

    // Size to fit content, with minimum width for short labels
    implicitWidth: Math.max(Style.buttonWidthMinimum, implicitContentWidth + leftPadding + rightPadding)

    contentItem: Text {
        text: control.text
        font: control.font
        lineHeightMode: Text.FixedHeight
        lineHeight: Style.buttonLineHeight
        color: control.enabled
               ? (control.activeFocus || control.hovered ? Style.button2ForegroundColor : Style.button2ForegroundColor)
               : Style.buttonDisabledTextColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight  // Truncate if layout constrains button below content width
    }

    activeFocusOnTab: true
    focusPolicy: Qt.TabFocus
    
    // Accessibility properties
    Accessible.role: Accessible.Button
    Accessible.name: CommonStrings.controlAccessibleName(text, accessibleDescription, enabled)
    Accessible.description: ""
    Accessible.onPressAction: clicked()
    
    Keys.onEnterPressed: clicked()
    Keys.onReturnPressed: clicked()
}
