/* SPDX-License-Identifier: Apache-2.0 */

pragma ComponentBehavior: Bound

import QtQuick

// DWM caption buttons live behind the Quick surface. Keep their pixels clear,
// including when a modal dimmer covers the window. With no cutout this is an
// ordinary Rectangle, retaining rounded corners for client-drawn frames.
Rectangle {
    id: root
    property color surfaceColor: "transparent"
    property rect nativeControlsRect: Qt.rect(0, 0, 0, 0)
    readonly property bool hasCutout: nativeControlsRect.width > 0 && nativeControlsRect.height > 0
    readonly property real cutLeft: Math.max(0, Math.min(width, nativeControlsRect.x))
    readonly property real cutRight: Math.max(cutLeft, Math.min(width, nativeControlsRect.x + nativeControlsRect.width))
    readonly property real cutTop: Math.max(0, Math.min(height, nativeControlsRect.y))
    readonly property real cutBottom: Math.max(cutTop, Math.min(height, nativeControlsRect.y + nativeControlsRect.height))
    color: hasCutout ? "transparent" : surfaceColor

    Rectangle {
        visible: root.hasCutout
        width: root.width
        height: root.cutTop
        color: root.surfaceColor
    }
    Rectangle {
        visible: root.hasCutout
        y: root.cutTop
        width: root.cutLeft
        height: root.cutBottom - y
        color: root.surfaceColor
    }
    Rectangle {
        visible: root.hasCutout
        x: root.cutRight
        y: root.cutTop
        width: root.width - x
        height: root.cutBottom - y
        color: root.surfaceColor
    }
    Rectangle {
        visible: root.hasCutout
        y: root.cutBottom
        width: root.width
        height: root.height - y
        color: root.surfaceColor
    }
}
