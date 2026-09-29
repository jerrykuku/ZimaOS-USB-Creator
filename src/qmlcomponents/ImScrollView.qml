/*
 * SPDX-License-Identifier: Apache-2.0
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import RpiImager

// Keep controls reachable by keyboard when dialog content exceeds its viewport.
ScrollView {
    id: root
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    function revealFocus() {
        const window = root.Window.window
        const item = window ? window.activeFocusItem : null
        const flick = root.contentItem
        if (!visible || !item || !flick || !flick.contentItem)
            return

        let ancestor = item
        while (ancestor && ancestor !== flick.contentItem)
            ancestor = ancestor.parent
        if (!ancestor)
            return

        const top = item.mapToItem(flick.contentItem, 0, 0).y
        const bottom = top + item.height
        const margin = Style.spacingTiny
        let target = flick.contentY
        if (top < target + margin)
            target = top - margin
        else if (bottom > target + flick.height - margin)
            target = bottom - flick.height + margin
        flick.contentY = Math.max(0, Math.min(target, flick.contentHeight - flick.height))
    }

    onHeightChanged: Qt.callLater(revealFocus)
    onContentHeightChanged: Qt.callLater(revealFocus)
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { Qt.callLater(root.revealFocus) }
    }
}
