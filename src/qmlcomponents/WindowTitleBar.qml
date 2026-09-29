/* SPDX-License-Identifier: Apache-2.0 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window

// The platform supplies the buttons above this item. This item only draws the
// centered title and handles pointer input on the remaining title-bar space.
MouseArea {
    id: root
    required property Window targetWindow
    property bool nativeMacTitleBar: false
    property real controlsInset: nativeMacTitleBar ? 100 : height * 4.5 + 12
    property alias titleFont: label.font
    property alias titleColor: label.color
    property point pressPosition
    property bool moveRequested: false

    acceptedButtons: Qt.LeftButton
    onPressed: function(mouse) {
        pressPosition = Qt.point(mouse.x, mouse.y)
        moveRequested = false
        // The AppKit helper processes double-clicks before this handler.
        if (nativeMacTitleBar)
            targetWindow.startSystemMove()
    }
    onPositionChanged: function(mouse) {
        // Leave a click in Qt's event stream so a second click can maximize.
        if (!nativeMacTitleBar && pressed && !moveRequested
                && Math.abs(mouse.x - pressPosition.x) + Math.abs(mouse.y - pressPosition.y)
                   >= Qt.styleHints.startDragDistance) {
            moveRequested = true
            targetWindow.startSystemMove()
        }
    }
    onDoubleClicked: {
        if (targetWindow.visibility === Window.Maximized)
            targetWindow.showNormal()
        else if (targetWindow.visibility !== Window.FullScreen)
            targetWindow.showMaximized()
    }

    Text {
        id: label
        anchors.centerIn: parent
        // Reserve equal space on each side to keep the label window-centered.
        width: Math.max(0, parent.width - 2 * root.controlsInset)
        text: root.targetWindow.title
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}
