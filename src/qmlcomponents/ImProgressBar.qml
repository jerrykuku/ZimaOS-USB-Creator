/*
 * SPDX-License-Identifier: Apache-2.0
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Basic
import RpiImager

Basic.ProgressBar {
    id: control

    implicitHeight: 10
    padding: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 10
        radius: height / 2
        color: Style.progressBarTrackColor
        antialiasing: true
    }

    contentItem: Item {
        id: content
        property real phase: 0
        scale: control.mirrored ? -1 : 1

        Rectangle {
            id: fill
            // A positive progress value starts as a circle, then grows into a
            // capsule. Zero stays empty; the fill never exceeds the track.
            width: Math.min(content.width, Math.max(height,
                            content.width * (control.indeterminate ? 0.25 : control.position)))
            height: content.height
            x: control.indeterminate ? content.phase * (content.width - width) : 0
            visible: control.indeterminate || control.position > 0
            radius: height / 2
            color: Style.colorAccentPrimary
            antialiasing: true
        }

        SequentialAnimation on phase {
            running: control.visible && control.indeterminate && !PlatformHelper.prefersReducedMotion
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 1; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1; to: 0; duration: 1000; easing.type: Easing.InOutSine }
        }
    }
}
