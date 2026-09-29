/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Effects
import "qmlcomponents"
import "wizard"
import "wizard/dialogs"

import RpiImager

ApplicationWindow {
    id: window
    visible: true
    readonly property bool usesPlatformWindowChrome: !ImageWriterSingleton.isEmbeddedMode()
            && (Qt.platform.os === "osx" || Qt.platform.os === "windows")
    readonly property bool usesMacTitleBar: usesPlatformWindowChrome && Qt.platform.os === "osx"
    readonly property bool usesLinuxCustomChrome: Qt.platform.os === "linux" && !ImageWriterSingleton.isEmbeddedMode()
    readonly property bool fillsScreen: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property int customShadowInset: usesLinuxCustomChrome ? 12
            : !usesPlatformWindowChrome && Qt.platform.os === "windows" ? 8 : 0
    readonly property int windowFrameInset: fillsScreen ? 0 : customShadowInset
    readonly property real windowCornerRadius: usesPlatformWindowChrome || fillsScreen ? 0 : Style.radiusPanel
    // Linux uses a client-drawn title bar with Ubuntu-style controls so its transparent
    // background and centered title do not depend on the desktop theme.
    // Qt's Windows platform plugin draws the caption buttons above Quick.
    // CustomizeWindowHint without WindowTitleHint suppresses its left-aligned
    // title/icon; WindowTitleBar below supplies the centered title instead.
    flags: usesMacTitleBar ? Qt.Window | Qt.WindowFullscreenButtonHint
                             | Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint
           : usesPlatformWindowChrome ? Qt.Window | Qt.CustomizeWindowHint | Qt.WindowSystemMenuHint
                                      | Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint
                                      | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint
                                      | Qt.WindowCloseButtonHint
                                    : Qt.FramelessWindowHint | Qt.Window

    background: Rectangle {
        color: window.usesPlatformWindowChrome ? Style.colorSurfacePage : Style.transparent
    }

    header: WindowTitleBar {
        targetWindow: window
        nativeMacTitleBar: window.usesMacTitleBar
        height: window.visibility === Window.FullScreen ? 0
                : window.usesMacTitleBar ? window.SafeArea.margins.top
                : window.usesPlatformWindowChrome ? Math.max(Style.scaled(40), window.SafeArea.margins.top) : 0
        visible: height > 0
        titleColor: Style.colorTextChromeMuted
        titleFont.family: Style.fontFamilyBold
        titleFont.pixelSize: Style.fontSizePixelSm
        titleFont.bold: true
    }
    color: usesPlatformWindowChrome ? Style.colorSurfacePage : Style.transparent

    function toggleMaximized() {
        if (visibility === Window.FullScreen)
            return
        if (visibility === Window.Maximized)
            showNormal()
        else
            showMaximized()
    }

    // macOS/Windows own the outer corners and shadow. Linux draws its rounded
    // surface on a transparent window, with room for a small client shadow.
    Rectangle {
        id: windowSurface
        anchors.fill: parent
        anchors.margins: window.windowFrameInset
        color: Style.colorSurfacePage
        radius: window.windowCornerRadius
        antialiasing: true
        clip: true
        z: 0

        // Native Windows keeps its DWM shadow; never draw a second one.
        layer.enabled: window.windowFrameInset > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.15)
            shadowBlur: 0.5
            blurMax: window.usesLinuxCustomChrome ? 16 : 32
            shadowVerticalOffset: window.usesLinuxCustomChrome ? 2 : 4
            shadowHorizontalOffset: 0
        }
    }

    // Whether to show the landing Language Selection step (set from C++)
    property bool showLanguageSelection: false
    // Wizard manages drive list and selection state
    property bool forceQuit: false
    // Expose overlay root to child components for dialog parenting
    readonly property alias overlayRootItem: overlayRoot

    width: ImageWriterSingleton.isEmbeddedMode() ? -1 : Style.scaled(680) + 2 * customShadowInset
    // Leave room for the native frame and desktop panels on shorter displays.
    height: ImageWriterSingleton.isEmbeddedMode() ? -1
            : Math.min(Style.scaled(520) + 2 * customShadowInset,
                       Math.max(minimumHeight, Screen.desktopAvailableHeight - 48))
    minimumWidth: ImageWriterSingleton.isEmbeddedMode() ? -1 : Style.scaled(680) + 2 * customShadowInset
    minimumHeight: ImageWriterSingleton.isEmbeddedMode() ? -1 : Style.scaled(420) + 2 * customShadowInset

    // Track custom repo host for title display
    property string customRepoHost: ImageWriterSingleton.customRepoHost()
    
    // Track offline state for title display (derived from whether OS list data is available)
    property bool isOffline: ImageWriterSingleton.isOsListUnavailable
    property bool isWindowsTitleBar: Qt.platform.os === "windows"
    
    title: {
        var baseTitle = qsTr("ZimaOS USB Creator")
        if (isOffline) {
            baseTitle += " — " + qsTr("Offline")
        }

        if (customRepoHost.length > 0) {
            baseTitle += " — " + qsTr("Using data from %1").arg(customRepoHost)
        }

        return baseTitle
    }

    // Linux and embedded/other frameless platforms use the custom controls.
    Rectangle {
        id: customTitleBar
        parent: windowSurface
        anchors.top: windowSurface.top
        anchors.left: windowSurface.left
        anchors.right: windowSurface.right
        visible: !window.usesPlatformWindowChrome && window.visibility !== Window.FullScreen
        height: visible ? Style.titleBarHeight : 0
        color: Style.transparent
        clip: true
        z: 2000

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            property point pressPosition
            property bool moveRequested: false
            onPressed: function(mouse) {
                pressPosition = Qt.point(mouse.x, mouse.y)
                moveRequested = false
            }
            // Starting a system move on every press can swallow the second
            // click. Start only once the pointer crosses the drag threshold.
            onPositionChanged: function(mouse) {
                if (pressed && !moveRequested
                        && Math.abs(mouse.x - pressPosition.x) + Math.abs(mouse.y - pressPosition.y)
                           >= Qt.styleHints.startDragDistance) {
                    moveRequested = true
                    window.startSystemMove()
                }
            }
            onDoubleClicked: window.toggleMaximized()
        }

        Row {
            id: windowControls
            readonly property bool rightAligned: window.isWindowsTitleBar || window.usesLinuxCustomChrome
            anchors.left: rightAligned ? undefined : parent.left
            anchors.right: rightAligned ? parent.right : undefined
            anchors.top: parent.top
            anchors.leftMargin: rightAligned ? 0 : Style.spacingCardInset
            // Windows caption controls sit flush with the right edge. The
            // title bar's rounded clipping keeps the window's top-right
            // corner rounded while allowing the close button to reach it.
            anchors.rightMargin: window.usesLinuxCustomChrome ? 12 : 0
            anchors.topMargin: (parent.height - height) / 2
            spacing: window.usesLinuxCustomChrome ? 6 : window.isWindowsTitleBar ? 0 : Style.spacingContentInset

            Repeater {
                // Ubuntu/Windows: minimize/maximize/close on the right.
                model: windowControls.rightAligned ? [1, 2, 0] : [0, 1, 2]
                delegate: Rectangle {
                    required property int modelData
                    required property int index
                    readonly property int actionIndex: modelData
                    readonly property bool windowsStyle: window.isWindowsTitleBar
                    readonly property bool ubuntuStyle: window.usesLinuxCustomChrome
                    readonly property bool maximized: window.visibility === Window.Maximized
                    onMaximizedChanged: glyphCanvas.requestPaint()
                    width: ubuntuStyle ? 28 : windowsStyle ? 40 : Style.titleBarControlSize
                    height: ubuntuStyle ? 28 : windowsStyle ? 32 : Style.titleBarControlSize
                    radius: ubuntuStyle || windowsStyle ? 0 : Style.titleBarControlSize / 2
                    opacity: ubuntuStyle && !window.active ? 0.5 : 1
                    // The close button reaches the window edge, so preserve
                    // the title bar's rounded top-right corner on that item.
                    topLeftRadius: ubuntuStyle || windowsStyle ? 0 : Style.titleBarControlSize / 2
                    topRightRadius: ubuntuStyle ? 0 : windowsStyle && actionIndex === 0
                                    ? Style.radiusPanel : (windowsStyle ? 0 : Style.titleBarControlSize / 2)
                    bottomLeftRadius: ubuntuStyle || windowsStyle ? 0 : Style.titleBarControlSize / 2
                    bottomRightRadius: ubuntuStyle || windowsStyle ? 0 : Style.titleBarControlSize / 2
                    color: ubuntuStyle ? Style.transparent : windowsStyle
                           ? (hovered
                              ? (actionIndex === 0 ? "#C42B1C" : "#E5E5E5")
                              : Style.transparent)
                           : [Style.colorChromeClose, Style.colorChromeMinimize, Style.colorChromeMaximize][actionIndex]
                    border.width: ubuntuStyle || windowsStyle ? 0 : Style.borderWidthDefault
                    border.color: windowsStyle
                                  ? Style.transparent
                                  : Qt.darker(color, 1.08)

                    property bool hovered: false
                    onHoveredChanged: glyphCanvas.requestPaint()

                    // Yaru's light title buttons: neutral circles, stronger
                    // hover/pressed fills, and no colored traffic lights.
                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        radius: 12
                        visible: parent.ubuntuStyle && window.active
                        color: Qt.rgba(0.24, 0.24, 0.24,
                                       controlMouseArea.pressed ? 0.25 : parent.hovered ? 0.15 : 0.10)
                        antialiasing: true
                    }

                    MouseArea {
                        id: controlMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        onClicked: {
                            if (parent.actionIndex === 0)
                                window.close()
                            else if (parent.actionIndex === 1)
                                window.showMinimized()
                            else
                                window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
                        }
                    }

                    Canvas {
                        id: glyphCanvas
                        anchors.fill: parent
                        visible: parent.ubuntuStyle || parent.windowsStyle || parent.hovered
                        antialiasing: true
                        onPaint: {
                            var context = getContext("2d")
                            context.reset()
                            context.strokeStyle = parent.ubuntuStyle ? "#3D3D3D"
                                                  : parent.windowsStyle && parent.hovered && parent.actionIndex === 0
                                                  ? "#FFFFFF" : Style.colorTextChrome
                            context.lineWidth = parent.ubuntuStyle ? 1.4 : parent.windowsStyle ? 1.2 : 1.15
                            context.lineCap = "round"
                            context.beginPath()
                            if (parent.windowsStyle || parent.ubuntuStyle) {
                                // Windows caption glyphs: minimize, maximize, close.
                                var glyphSize = parent.ubuntuStyle ? 10 : 9
                                var glyphLeft = (width - glyphSize) / 2
                                var glyphRight = glyphLeft + glyphSize
                                var glyphTop = (height - glyphSize) / 2
                                var glyphBottom = glyphTop + glyphSize
                                if (parent.actionIndex === 1) {
                                    var minimizeY = height / 2 + (parent.ubuntuStyle ? 0 : 3)
                                    context.moveTo(glyphLeft, minimizeY)
                                    context.lineTo(glyphRight, minimizeY)
                                } else if (parent.actionIndex === 2) {
                                    if (parent.maximized) {
                                        context.rect(glyphLeft + 0.5, glyphTop + 3.5, glyphSize - 4, glyphSize - 4)
                                        context.moveTo(glyphLeft + 3.5, glyphTop + 2)
                                        context.lineTo(glyphLeft + 3.5, glyphTop + 0.5)
                                        context.lineTo(glyphRight - 0.5, glyphTop + 0.5)
                                        context.lineTo(glyphRight - 0.5, glyphBottom - 3.5)
                                        context.lineTo(glyphRight - 2, glyphBottom - 3.5)
                                    } else {
                                        context.rect(glyphLeft + 0.5, glyphTop + 0.5, glyphSize - 1, glyphSize - 1)
                                    }
                                } else {
                                    context.moveTo(glyphLeft, glyphTop)
                                    context.lineTo(glyphRight, glyphBottom)
                                    context.moveTo(glyphRight, glyphTop)
                                    context.lineTo(glyphLeft, glyphBottom)
                                }
                            } else if (parent.actionIndex === 0) {
                                // Close: compact cross centered on the button geometry.
                                var closeMin = 3.8
                                var closeMax = width - closeMin
                                var closeCenter = height / 2
                                context.moveTo(closeMin, closeCenter - 2.2)
                                context.lineTo(closeMax, closeCenter + 2.2)
                                context.moveTo(closeMax, closeCenter - 2.2)
                                context.lineTo(closeMin, closeCenter + 2.2)
                            } else if (parent.actionIndex === 1) {
                                // Minimize: centered horizontal stroke.
                                var center = width / 2
                                context.moveTo(3.0, center + 0.5)
                                context.lineTo(width - 3.0, center + 0.5)
                            } else {
                                // Fullscreen: opposing diagonal arrows.
                                context.moveTo(3.0, 5.0)
                                context.lineTo(3.0, 3.0)
                                context.lineTo(5.0, 3.0)
                                context.moveTo(width - 3.0, height - 5.0)
                                context.lineTo(width - 3.0, height - 3.0)
                                context.lineTo(width - 5.0, height - 3.0)
                            }
                            context.stroke()
                        }
                    }
                }
            }
        }


        Text {
            anchors.centerIn: parent
            text: window.title
            color: Style.colorTextChromeMuted
            font.family: Style.fontFamilyBold
            font.pixelSize: Style.fontSizePixelSm
            font.bold: true
            elide: Text.ElideRight
            width: Math.max(0, parent.width - 2 * Math.max(100, windowControls.width + 24))
            horizontalAlignment: Text.AlignHCenter
        }

    }

    // Frameless Linux windows need explicit edge/corner resize hit areas.
    // Keep these outside the controls and content, and let the compositor
    // perform the operation (including Wayland's interactive resize).
    Item {
        parent: windowSurface
        anchors.fill: parent
        visible: window.usesLinuxCustomChrome && !window.fillsScreen
        z: 3000

        Repeater {
            model: [Qt.TopEdge | Qt.LeftEdge, Qt.TopEdge, Qt.TopEdge | Qt.RightEdge,
                    Qt.LeftEdge, Qt.RightEdge, Qt.BottomEdge | Qt.LeftEdge,
                    Qt.BottomEdge, Qt.BottomEdge | Qt.RightEdge]
            delegate: MouseArea {
                required property int modelData
                readonly property bool leftEdge: (modelData & Qt.LeftEdge) !== 0
                readonly property bool rightEdge: (modelData & Qt.RightEdge) !== 0
                readonly property bool topEdge: (modelData & Qt.TopEdge) !== 0
                readonly property bool bottomEdge: (modelData & Qt.BottomEdge) !== 0
                readonly property bool corner: (leftEdge || rightEdge) && (topEdge || bottomEdge)
                width: corner ? 12 : (leftEdge || rightEdge) ? 5 : parent.width - 24
                height: corner ? 12 : (topEdge || bottomEdge) ? 5 : parent.height - 24
                x: leftEdge ? 0 : rightEdge ? parent.width - width : 12
                y: topEdge ? 0 : bottomEdge ? parent.height - height : 12
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: corner ? (leftEdge === topEdge ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                                    : (leftEdge || rightEdge) ? Qt.SizeHorCursor : Qt.SizeVerCursor
                onPressed: window.startSystemResize(modelData)
            }
        }
    }

    Component.onCompleted: {
        // Set the main window for modal file dialogs
        ImageWriterSingleton.setMainWindow(window)
    }

    onClosing: function (close) {
        if (wizardContainer.isWriting && !forceQuit) {
            close.accepted = false;
            quitDialog.open();
        } else {
            // allow close
            close.accepted = true;
        }
    }

    // Global overlay to parent/center dialogs across the whole window
    Item {
        id: overlayRoot
        parent: windowSurface
        anchors.fill: parent
        z: 1000
    }

    // Keyboard shortcut to export performance data (Ctrl+Shift+P)
    Shortcut {
        sequence: "Ctrl+Shift+P"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (ImageWriterSingleton.hasPerformanceData()) {
                console.log("Exporting performance data...")
                ImageWriterSingleton.exportPerformanceData()
            } else {
                console.log("No performance data available to export")
            }
        }
    }
    
    // Secret keyboard shortcut to open debug options (Cmd+Option+S on macOS, Ctrl+Alt+S on others)
    Shortcut {
        sequence: "Ctrl+Alt+S"
        context: Qt.ApplicationShortcut
        onActivated: {
            console.log("Opening debug options dialog...")
            debugOptionsLoader.active = true
            debugOptionsLoader.item.initialize()
            debugOptionsLoader.item.open()
        }
    }

    // Main wizard interface
    Rectangle {
        id: wizardBackground
        parent: windowSurface
        anchors.left: windowSurface.left
        anchors.right: windowSurface.right
        anchors.bottom: windowSurface.bottom
        anchors.top: customTitleBar.bottom
        anchors.leftMargin: Style.spacingPageInset
        anchors.rightMargin: Style.spacingPageInset
        anchors.bottomMargin: Style.spacingPageInset
        anchors.topMargin: Style.spacingPageInset
        color: Style.colorSurfacePage
        radius: Style.radiusPanel
        clip: true

        WizardContainer {
            id: wizardContainer
            anchors.fill: parent
            imageWriter: ImageWriterSingleton
            overlayRootRef: overlayRoot
            // Show Language step if C++ requested it
            showLanguageSelection: window.showLanguageSelection

            onWizardCompleted: {
                // Reset to start of wizard or close application
                wizardContainer.currentStep = 0;
            }

            onAppOptionsRequested: {
                appOptionsLoader.active = true
                appOptionsLoader.item.initialize()
                appOptionsLoader.item.open()
            }

            onUpdatePopupRequested: function(updateUrl, version) {
                if (!window.updatePopupShown) {
                    window.updatePopupShown = true
                    updatepopup.url = updateUrl
                    updatepopup.version = version
                    updatepopup.open()
                }
            }
        }
    }

    ErrorDialog {
        id: errorDialog
        parent: overlayRoot
        anchors.centerIn: parent
    }

    // Specific dialog for storage removal during write
    PanelDialog {
        id: storageRemovedDialog
        title: qsTr("Storage device removed")
        iconSource: Qt.resolvedUrl("icons/ic_warning_24px.svg")
        parent: overlayRoot
        anchors.centerIn: parent

        // Custom escape handling
        function escapePressed() {
            storageRemovedDialog.close()
        }

        // Register focus groups when component is ready
        Component.onCompleted: {
            registerFocusGroup("content", function () {
                // Only include text elements when screen reader is active (otherwise they're not focusable)
                if (ImageWriterSingleton && ImageWriterSingleton.screenReaderActive) {
                    return [storageRemovedDialog.headingItem, storageRemovedMessage]
                }
                return []
            }, 0)
            registerFocusGroup("buttons", function () {
                return [storageOkButton]
            }, 1)
        }

        // Dialog content

        FocusableText {
            id: storageRemovedMessage
            text: qsTr("The storage device was removed while writing, so the operation was cancelled. Please reinsert the device or select a different one to continue.")
            wrapMode: Text.Wrap
            font.pixelSize: Style.fontSizePixelSm
            font.family: Style.fontFamily
            color: Style.colorTextPrimary
            Layout.fillWidth: true
        }

        buttons: [
            ImButtonRed {
                id: storageOkButton
                objectName: "storageOkButton"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: Style.buttonHeightStandard
                text: qsTranslate("ErrorDialog", "Got it")
                accessibleDescription: qsTr("Close the storage removed notification and return to storage selection")
                activeFocusOnTab: true
                onClicked: storageRemovedDialog.close()
            }
        ]
    }

    // Quit dialog (modern style)
    PanelDialog {
        id: quitDialog
        title: qsTr("Are you sure you want to quit?")
        iconSource: Qt.resolvedUrl("icons/ic_warning_24px.svg")
        parent: overlayRoot
        anchors.centerIn: parent

        // Custom escape handling
        function escapePressed() {
            quitDialog.close()
        }

        // Register focus groups when component is ready
        Component.onCompleted: {
            registerFocusGroup("content", function () {
                // Only include text elements when screen reader is active (otherwise they're not focusable)
                if (ImageWriterSingleton && ImageWriterSingleton.screenReaderActive) {
                    return [quitDialog.headingItem, quitMessage]
                }
                return []
            }, 0)
            registerFocusGroup("buttons", function () {
                return [quitNoButton, quitYesButton]
            }, 1)
        }

        // Dialog content

        FocusableText {
            id: quitMessage
            text: qsTr("ZimaOS USB Creator is still busy. Are you sure you want to quit?")
            font.pixelSize: Style.fontSizePixelSm
            font.family: Style.fontFamily
            color: Style.colorTextPrimary
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        buttons: [
            ImButton {
                id: quitNoButton
                objectName: "quitNoButton"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: Style.buttonHeightStandard
                text: CommonStrings.cancel
                accessibleDescription: qsTr("Return to ZimaOS USB Creator and continue the current operation")
                activeFocusOnTab: true
                onClicked: quitDialog.close()
            },
            ImButtonRed {
                id: quitYesButton
                destructive: true
                objectName: "quitYesButton"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: Style.buttonHeightStandard
                text: qsTr("Exit")
                accessibleDescription: qsTr("Force quit ZimaOS USB Creator and cancel the current write operation")
                activeFocusOnTab: true
                onClicked: {
                    window.forceQuit = true
                    Qt.quit()
                }
            }
        ]
    }

    KeychainPermissionDialog {
        id: keychainpopup
        parent: overlayRoot
        onAccepted: {
            ImageWriterSingleton.keychainPermissionResponse(true);
        }
        onRejected: {
            ImageWriterSingleton.keychainPermissionResponse(false);
        }
    }

    // Track whether update popup has been shown this session
    property bool updatePopupShown: false

    UpdateAvailableDialog {
        id: updatepopup
        // parent can be set to overlayRoot if needed for centering above
        parent: overlayRoot
        onAccepted: {}
        onRejected: {}
    }

    // Permission warning dialog for when not running with elevated privileges
    PanelDialog {
        id: permissionWarningDialog
        title: qsTr("Insufficient Permissions")
        iconSource: Qt.resolvedUrl("icons/ic_warning_24px.svg")
        parent: overlayRoot
        anchors.centerIn: parent
        closePolicy: Popup.NoAutoClose  // Prevent closing with escape or clicking outside

        property string warningMessage: ""

        function showWarning(message) {
            warningMessage = message
            open()
        }

        // Custom escape handling - exit the application
        function escapePressed() {
            Qt.quit()
        }

        // Register focus groups when component is ready
        Component.onCompleted: {
            registerFocusGroup("heading", function () {
                return [permissionWarningDialog.headingItem]
            }, 0)
            registerFocusGroup("message", function () {
                return [messageText]
            }, 1)
            registerFocusGroup("buttons", function () {
                return [installAuthButton, exitButton]
            }, 2)
        }

        // Dialog content

        FocusableText {
            id: messageText
            text: permissionWarningDialog.warningMessage
            font.pixelSize: Style.fontSizePixelSm
            font.family: Style.fontFamily
            color: Style.colorTextPrimary
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Accessible.description: qsTr("Error message explaining why elevated privileges are required")
            Accessible.ignored: false
        }

        buttons: [
            ImButton {
                id: installAuthButton
                objectName: "installAuthButton"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: Style.buttonHeightStandard
                text: qsTr("Install Authorization")
                accessibleDescription: qsTr("Install system authorization to allow ZimaOS USB Creator to run with elevated privileges")
                activeFocusOnTab: true
                visible: ImageWriterSingleton && ImageWriterSingleton.isElevatableBundle()
                // Make button wide enough to fit the text, with sensible bounds
                implicitWidth: Math.max(Style.buttonWidthMinimum, implicitContentWidth + leftPadding + rightPadding)
                onClicked: {
                    if (ImageWriterSingleton.installElevationPolicy()) {
                        // Policy installed successfully - restart with elevated privileges
                        ImageWriterSingleton.restartWithElevatedPrivileges()
                    }
                }
            },
            ImButtonRed {
                id: exitButton
                objectName: "exitButton"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: Style.buttonHeightStandard
                text: qsTr("Exit")
                accessibleDescription: qsTr("Exit ZimaOS USB Creator - you must restart with elevated privileges to write images")
                activeFocusOnTab: true
                onClicked: Qt.quit()
            }
        ]
    }

    // Lazily constructed: each of these dialogs is ~600 lines of QML and is only
    // reachable on user action (the "App Options" button / a debug shortcut), so we
    // keep them off the startup path. The Loader is inactive until first use; once
    // realized it persists, so subsequent opens reuse the same instance.
    Loader {
        id: appOptionsLoader
        active: false
        sourceComponent: AppOptionsDialog {
            parent: overlayRoot
            wizardContainer: wizardContainer
        }
    }

    Loader {
        id: debugOptionsLoader
        active: false
        sourceComponent: DebugOptionsDialog {
            parent: overlayRoot
            wizardContainer: wizardContainer
        }
    }

    // Removed embeddedFinishedPopup; handled by Wizard Done step

    // QML fallback save dialog for performance data export
    ImSaveFileDialog {
        id: performanceSaveDialog
        parent: overlayRoot
        anchors.centerIn: parent
        dialogTitle: qsTr("Save Performance Data")
        nameFilters: [qsTr("JSON files (*.json)"), qsTr("All files (*)")]
        
        onAccepted: {
            var filePath = String(selectedFile)
            // Strip file:// prefix for the C++ call
            if (filePath.indexOf("file://") === 0) {
                filePath = filePath.substring(7)
            }
            if (filePath.length > 0) {
                console.log("Saving performance data to:", filePath)
                ImageWriterSingleton.exportPerformanceDataToFile(filePath)
            }
        }
    }

    // Handle signal from C++ when native save dialog isn't available
    Connections {
        target: ImageWriterSingleton
        function onPerformanceSaveDialogNeeded(suggestedFilename, initialDir) {
            console.log("Native save dialog not available, using QML fallback")
            performanceSaveDialog.suggestedFilename = suggestedFilename
            var folderUrl = (Qt.platform.os === "windows") ? ("file:///" + initialDir) : ("file://" + initialDir)
            performanceSaveDialog.currentFolder = folderUrl
            performanceSaveDialog.folder = folderUrl
            performanceSaveDialog.open()
        }
        
        // Update title when custom repository changes
        function onCustomRepoChanged() {
            window.customRepoHost = ImageWriterSingleton.customRepoHost()
        }
        
        // Update title when repo host changes after redirect
        // This ensures "Using data from X" shows the final URL host after redirects
        function onCustomRepoHostChanged() {
            window.customRepoHost = ImageWriterSingleton.customRepoHost()
        }
    }

    /* Slots for signals imagewrite emits */
    function onDownloadProgress(now, total) {
        // Forward to wizard container
        wizardContainer.onDownloadProgress(now, total);
    }

    function onWriteProgress(now, total) {
        // Forward to wizard container
        wizardContainer.onWriteProgress(now, total);
    }

    function onVerifyProgress(now, total) {
        // Forward to wizard container
        wizardContainer.onVerifyProgress(now, total);
    }

    function onPreparationStatusUpdate(msg) {
        // Forward to wizard container
        wizardContainer.onPreparationStatusUpdate(msg);
    }

    function onError(msg) {
        errorDialog.titleText = qsTr("Error");
        errorDialog.message = msg;
        errorDialog.open();
    }

    function onFinalizing() {
        wizardContainer.onFinalizing();
    }

    function onCancelled() {
        // Forward to wizard container to handle write cancellation
        if (wizardContainer) {
            wizardContainer.onWriteCancelled();
        }
    }

    function onNetworkInfo(msg) {
        if (ImageWriterSingleton.isEmbeddedMode() && wizardContainer) {
            wizardContainer.networkInfoText = msg;
        }
    }

    // Called from C++ when selected device is removed
    function onSelectedDeviceRemoved() {
        if (wizardContainer) {
            wizardContainer.selectedStorageName = "";
        }
        ImageWriterSingleton.setDst("");

        // If we are past storage selection, navigate back there
        if (wizardContainer && wizardContainer.currentStep > wizardContainer.stepStorageSelection) {
            wizardContainer.jumpToStep(wizardContainer.stepStorageSelection);
            // Inform the user with the dedicated modern dialog (only if we navigated back)
            storageRemovedDialog.open();
        }
        // If we're already on storage selection screen, don't show dialog - user can see the device disappeared
    }

    // Called from C++ when a write was cancelled because the storage device was removed
    function onWriteCancelledDueToDeviceRemoval() {
        if (wizardContainer) {
            wizardContainer.selectedStorageName = "";
        }
        // Clear backend dst reference
        ImageWriterSingleton.setDst("");
        // Navigate back to storage selection for safety
        if (wizardContainer)
            wizardContainer.jumpToStep(wizardContainer.stepStorageSelection);
        // Show dedicated dialog
        storageRemovedDialog.open();
    }

    function onKeychainPermissionRequested() {
        // If warnings are disabled, automatically grant permission without showing dialog
        if (wizardContainer.disableWarnings) {
            ImageWriterSingleton.keychainPermissionResponse(true);
        } else {
            keychainpopup.askForPermission();
        }
    }
    
    function onPermissionWarning(message) {
        permissionWarningDialog.showWarning(message);
    }

}
