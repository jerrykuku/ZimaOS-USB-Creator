/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025 Raspberry Pi Ltd
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RpiImager

// A labeled switch styled for Imager; only the switch toggles, not the whole row
Item {
    id: pill
    property alias text: label.text
    property bool checked: false
    // Optional help link next to the label
    property string helpLabel: ""
    property url helpUrl: ""
    // Allow custom accessibility description
    property string accessibleDescription: ""
    signal toggled(bool checked)

    // Expose the actual focusable control for tab navigation
    property alias focusItem: sw
    // Expose the help link for tab navigation (when visible)
    property alias helpLinkItem: helpText
    
    // Single source of truth for label font (used by both label and TextMetrics)
    readonly property font labelFont: Qt.font({
        family: Style.fontFamilyBold,
        pointSize: Style.fontSizeFormLabel,
        bold: true
    })
    
    // Export the natural/desired width for dialog sizing calculations
    // This is independent of Layout.fillWidth constraints
    readonly property real naturalWidth: labelMetrics.width + sw.implicitWidth + Style.spacingMedium * 2 + Style.cardPadding

    // Measure label text independently for naturalWidth
    TextMetrics {
        id: labelMetrics
        font: pill.labelFont
        text: pill.text
    }

    implicitHeight: Math.max(Style.buttonHeightStandard - 8, 28)
    implicitWidth: label.implicitWidth + sw.implicitWidth + Style.cardPadding
    
    // Make the label text ignore accessibility so only the switch is read
    // This prevents VoiceOver from reading the label separately

    RowLayout {
        anchors.fill: parent
        spacing: Style.spacingMedium

        // Text block (label + optional help) on the left
        ColumnLayout {
            id: textColumn
            Layout.alignment: Qt.AlignVCenter
            // Constrain width so text elides properly, leaving room for switch
            Layout.maximumWidth: pill.width - sw.implicitWidth - Style.spacingMedium * 2
            spacing: Style.spacingXXSmall

            // Main label
            Text {
                id: label
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                font: pill.labelFont
                color: Style.formLabelColor
                elide: Text.ElideRight
                TapHandler { onTapped: sw.toggle() }
                
                // Ignore this for accessibility - the switch will handle it
                Accessible.ignored: true
            }

            // Optional help link under the label
            Text {
                id: helpText
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: pill.helpLabel !== "" && pill.helpUrl !== ""
                text: pill.helpLabel
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeDescription
                color: helpText.activeFocus ? Style.colorAccentPrimary : Style.buttonForegroundColor
                font.underline: helpHover.hovered || helpText.activeFocus
                
                // Keyboard accessibility
                activeFocusOnTab: true
                focusPolicy: Qt.TabFocus
                
                // Accessibility properties
                Accessible.role: Accessible.Link
                Accessible.name: text
                Accessible.description: qsTr("Opens in browser")
                
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        if (ImageWriterSingleton) {
                            ImageWriterSingleton.openUrl(pill.helpUrl)
                        } else {
                            Qt.openUrlExternally(pill.helpUrl)
                        }
                    }
                }
                HoverHandler {
                    id: helpHover
                    acceptedDevices: PointerDevice.Mouse
                    cursorShape: Qt.PointingHandCursor
                }
                
                // Keyboard activation
                Keys.onEnterPressed: {
                    if (ImageWriterSingleton) {
                        ImageWriterSingleton.openUrl(pill.helpUrl)
                    } else {
                        Qt.openUrlExternally(pill.helpUrl)
                    }
                }
                Keys.onReturnPressed: {
                    if (ImageWriterSingleton) {
                        ImageWriterSingleton.openUrl(pill.helpUrl)
                    } else {
                        Qt.openUrlExternally(pill.helpUrl)
                    }
                }
                Keys.onSpacePressed: {
                    if (ImageWriterSingleton) {
                        ImageWriterSingleton.openUrl(pill.helpUrl)
                    } else {
                        Qt.openUrlExternally(pill.helpUrl)
                    }
                }
                
                Accessible.onPressAction: {
                    if (ImageWriterSingleton) {
                        ImageWriterSingleton.openUrl(pill.helpUrl)
                    } else {
                        Qt.openUrlExternally(pill.helpUrl)
                    }
                }
            }
        }

        // Flexible spacer to push the switch flush-right and align across rows
        Item { Layout.fillWidth: true }

        // Fixed visual treatment keeps switches consistent across platforms.
        Switch {
            id: sw
            Layout.alignment: Qt.AlignVCenter
            checked: pill.checked
            activeFocusOnTab: true
            implicitWidth: indicator.implicitWidth
            implicitHeight: indicator.implicitHeight
            
            // Access imageWriter from parent context
            property var imageWriter: {
                var item = parent;
                while (item) {
                    if (item.imageWriter !== undefined) {
                        return item.imageWriter;
                    }
                    item = item.parent;
                }
                return null;
            }
            
            indicator: Rectangle {
                implicitWidth: 36
                implicitHeight: 20
                x: sw.leftPadding
                y: sw.topPadding + (sw.availableHeight - height) / 2
                radius: height / 2
                color: sw.checked ? Style.colorAccentPrimary : Style.colorSurfaceControlInactive

                Rectangle {
                    width: 16
                    height: width
                    x: sw.checked ? parent.width - width - 2 : 2
                    y: (parent.height - height) / 2
                    radius: width / 2
                    color: Style.colorSurfacePage

                    Behavior on x {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
            
            // Accessibility properties - combine label text with description
            Accessible.role: Accessible.CheckBox
            Accessible.name: {
                var name = label.text
                var desc = ""
                if (pill.accessibleDescription !== "") {
                    desc = pill.accessibleDescription
                } else if (pill.helpLabel !== "") {
                    desc = pill.helpLabel
                }
                // Combine name and description since VoiceOver reads name more reliably
                return desc !== "" ? (name + ", " + desc) : name
            }
            Accessible.description: ""
            Accessible.checkable: true
            Accessible.checked: pill.checked
            Accessible.onToggleAction: toggle()
            
            onToggled: {
                pill.checked = checked
                pill.toggled(checked)
            }
            
            Keys.onReturnPressed: toggle()
            Keys.onEnterPressed: toggle()
        }

    }

    function forceActiveFocus() { sw.forceActiveFocus() }
}
