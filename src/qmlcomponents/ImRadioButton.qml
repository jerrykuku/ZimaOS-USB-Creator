/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2022-2025 Raspberry Pi Ltd
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import RpiImager

RadioButton {
    id: control
    Material.accent: Style.colorAccentPrimary
    font.pointSize: Style.fontSizeSm
    font.family: Style.fontFamily
    activeFocusOnTab: true
    focusPolicy: Qt.TabFocus
    
    // Allow custom accessibility description
    property string accessibleDescription: ""
    
    // Export the natural/desired width for dialog sizing calculations
    readonly property real naturalWidth: textMetrics.width + (indicator ? indicator.width : 20) + spacing + leftPadding + rightPadding
    
    // Measure text for naturalWidth (control.font is inherited from RadioButton)
    TextMetrics {
        id: textMetrics
        font: control.font
        text: control.text
    }
    
    // Custom contentItem with text wrapping for long translations
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? Style.formLabelColor : Style.formLabelDisabledColor
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator ? (control.indicator.width + control.spacing) : 0
        wrapMode: Text.WordWrap
        width: control.availableWidth  // Constrain width so text wraps
    }
    
    // Own the indicator so platform/Material hover and focus ripples cannot
    // introduce a tinted background around the radio button.
    background: Item {}
    indicator: Rectangle {
        implicitWidth: 20
        implicitHeight: 20
        x: control.leftPadding
        y: control.height / 2 - height / 2
        radius: (ImageWriterSingleton && ImageWriterSingleton.isEmbeddedMode()) ? 0 : width / 2
        border.color: control.checked || control.visualFocus ? Style.colorAccentPrimary : Style.colorControlBorderInactive
        border.width: control.visualFocus ? 3 : 2
        color: Style.colorSurfacePage
        antialiasing: true

        Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: parent.radius > 0 ? width / 2 : 0
            color: Style.colorAccentPrimary
            visible: control.checked
            antialiasing: true
        }
    }
    
    // Accessibility properties - combine text with description in name
    Accessible.role: Accessible.RadioButton
    Accessible.name: CommonStrings.controlAccessibleName(text, accessibleDescription, enabled)
    Accessible.description: ""
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onPressAction: click()
    
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Space) {
            if (!checked)            // prevent unchecking the current one
                click()              // goes through the normal “mouse click” path
            event.accepted = true
        }
    }
    Keys.onEnterPressed: (event) => {
        if (!checked)
            click()
        event.accepted = true
    }

    Keys.onReturnPressed: (event) => {
        if (!checked)
          click()
        event.accepted = true
    }
}
