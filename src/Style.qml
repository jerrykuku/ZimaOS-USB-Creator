/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025 Raspberry Pi Ltd
 */

pragma Singleton

import QtQuick
import RpiImager

Item {
    id: root

    // === TEXT SCALING ===
    // Platform text-scaling factor (1.0 = default, 1.5 = 150%, etc.)
    // Reflects OS-level accessibility preferences (Windows "Make text bigger",
    // GNOME text-scaling-factor, etc.) that Qt QML does not honour automatically.
    // DPI normalization is handled by Qt via font.pointSize + screen logical DPI.
    readonly property real textScale: PlatformHelper.textScaleFactor

    // Font-specific scale: DPI correction (72/96 on Windows/Linux, 1.0 on macOS)
    // multiplied by the accessibility text scale. Applied only to font sizes so
    // that layout, spacing, and button sizes are unaffected.
    readonly property real fontScale: PlatformHelper.fontDpiCorrection * textScale

    // Scale a base value by the text scaling factor, rounding to nearest int.
    function scaled(base) { return Math.round(base * textScale) }

    // === COLORS ===
    readonly property color mainBackgroundColor: "#F5F5F5"
    readonly property color transparent: "transparent"
    readonly property color zimaBlue: "#0057FF"

    readonly property color buttonBackgroundColor: mainBackgroundColor
    readonly property color buttonForegroundColor: zimaBlue
    readonly property color buttonTextColor: "#404040"
    readonly property color buttonDisabledBackgroundColor: "#E5E5E5"
    readonly property color buttonDisabledTextColor: "#888888"
    readonly property color buttonFocusedBackgroundColor: "#d1dcfb"
    readonly property color buttonHoveredBackgroundColor: "#f2f2f2"

    readonly property color button2BackgroundColor: zimaBlue
    readonly property color button2ForegroundColor: mainBackgroundColor
    // Focused: noticeably darker for strong state indication (keyboard focus)
    readonly property color button2FocusedBackgroundColor: "#8f122c"
    // Hovered: noticeably lighter to differentiate from base (≥4.5:1 contrast vs base)
    readonly property color button2HoveredBackgroundColor: "#0047db"
    // Hovered foreground should be Raspberry Red for ≥4.5:1 contrast on the light hover bg
    readonly property color button2HoveredForegroundColor: zimaBlue
    readonly property color zimaBlueHighlight: "#0047db"

    readonly property color titleBackgroundColor: "#f5f5f5"
    readonly property color titleSeparatorColor: "#afafaf"
    readonly property color popupBorderColor: "#e7e3e4"

    readonly property color listViewRowBackgroundColor: "#ffffff"
    readonly property color listViewHoverRowBackgroundColor: titleBackgroundColor
    // Selection highlight color for OS/device lists
    readonly property color listViewHighlightColor: "#f4f8fc"
    readonly property color listViewSelectedBorderColor: "#7aa7e8"

    // Utility translucent colors
    readonly property color translucentWhite10: Qt.rgba(255, 255, 255, 0.1)
    readonly property color translucentWhite30: Qt.rgba(255, 255, 255, 0.3)

    // descriptions in list views
    readonly property color textDescriptionColor: "#1a1a1a"
    // Sidebar colors
    readonly property color sidebarTitleColor: "#171717"
    readonly property color sidebarActiveBackgroundColor: "#F5F5F5"
    readonly property color sidebarActiveBorderColor: "#D4D4D4"
    readonly property color sidebarTextOnActiveColor: "#FFFFFF"
    readonly property color sidebarTextOnInactiveColor: zimaBlue
    readonly property color sidebarTextDisabledColor: "#888888"
    // Sidebar controls
    readonly property color sidebarControlBorderColor: "#767676"
    readonly property color sidebarBackgroundColour: "#FFFFFF"
    readonly property color sidebarBorderColour: "#E7E3E4"
    readonly property color sidebarHoverBackgroundColor: "#E5E5E5"

    // OS metadata
    readonly property color textMetadataColor: "#646464"

    // for the "device / OS / storage" titles
    readonly property color subtitleColor: "#ffffff"

    readonly property color progressBarTextColor: "white"
    readonly property color progressBarVerifyForegroundColor: "#6cc04a"
    readonly property color progressBarBackgroundColor: zimaBlue
    // New: distinct colors for writing vs verification phases
    readonly property color progressBarWritingForegroundColor: zimaBlue
    readonly property color progressBarTrackColor: titleBackgroundColor

    readonly property color lanbarBackgroundColor: "#ffffe3"

    /// the check-boxes/radio-buttons have labels that might be disabled
    readonly property color formLabelColor: "black"
    readonly property color formLabelErrorColor: "#EF4444"
    readonly property color formLabelDisabledColor: "grey"
    // Active color for radio buttons, checkboxes, and switches
    readonly property color formControlActiveColor: "#0057FF"

    readonly property color embeddedModeInfoTextColor: "#ffffff"

    // Focus/outline
    readonly property color focusOutlineColor: "#0078d4"
    readonly property int focusOutlineWidth: 2
    readonly property int focusOutlineRadius: 4
    readonly property int focusOutlineMargin: -4

    // === FONTS ===
    // On Windows, use Microsoft YaHei for CJK character support (set in main.cpp)
    // On other platforms, use embedded Roboto fonts
    readonly property string fontFamily: Qt.platform.os === "windows" ? "Microsoft YaHei UI" : robotoRegular.name
    readonly property string fontFamilyLight: Qt.platform.os === "windows" ? "Microsoft YaHei UI" : robotoLight.name
    readonly property string fontFamilyBold: Qt.platform.os === "windows" ? "Microsoft YaHei UI" : robotoBold.name

    // Font sizes (point sizes — DPI-aware, scaled by Qt based on screen logical DPI)
    // Additionally scaled by the OS accessibility text-scaling factor.
    // Base scale (single source of truth)
    readonly property real fontSizeXs: Math.round(12 * fontScale)
    readonly property real fontSizeSm: Math.round(14 * fontScale)
    readonly property real fontSizeMd: Math.round(16 * fontScale)
    readonly property real fontSizeXl: Math.round(24 * fontScale)

    // Role tokens mapped to base scale
    readonly property real fontSizeTitle: fontSizeMd
    readonly property real fontSizeHeading: fontSizeMd
    readonly property real fontSizeLargeHeading: fontSizeMd
    readonly property real fontSizeFormLabel: fontSizeSm
    readonly property real fontSizeSubtitle: fontSizeSm
    readonly property real fontSizeDescription: fontSizeXs
    readonly property real fontSizeInput: fontSizeSm
    readonly property real fontSizeCaption: fontSizeXs
    readonly property real fontSizeSmall: fontSizeXs
    readonly property real fontSizeSidebarItem: fontSizeSm

    // === SPACING ===
    readonly property int spacingXXSmall: 2
    readonly property int spacingXSmall: 5
    readonly property int spacingTiny: 8
    readonly property int spacingSmall: 10
    readonly property int spacingSmallPlus: 12
    readonly property int spacingMedium: 16
    readonly property int spacingLarge: 20
    readonly property int spacingExtraLarge: 30

    // === SIZES ===
    readonly property int buttonHeightStandard: 32
    readonly property int buttonFontSize: fontSizeSm          // 14px
    readonly property int buttonLineHeight: 20
    readonly property int buttonPadding: 6
    readonly property int buttonWidthMinimum: 90
    readonly property int buttonWidthSkip: 90
    
    readonly property int sectionMaxWidth: 500
    readonly property int sectionMargins: 24
    readonly property int sectionPadding: 16
    readonly property int sectionBorderWidth: 1
    readonly property int sectionBorderRadius: 8
    readonly property int listItemBorderRadius: 8
    readonly property int listItemPadding: 12
    readonly property int cardPadding: 16
    readonly property int popupMargin: 16
    // Shared layout tokens for the main application surface.
    readonly property int pageMargin: 8
    readonly property int panelGap: 16
    readonly property int contentRadius: 14
    readonly property int panelRadius: contentRadius
    readonly property int buttonRadius: 8
    readonly property int borderWidth: 1
    readonly property int titleBarHeight: 26
    readonly property int titleBarRadius: 14
    readonly property int titleBarControlSize: 12
    readonly property int iconButtonSize: 32
    readonly property int iconSmallSize: 16
    readonly property int contentInset: 8
    readonly property int cardInset: 12
    readonly property int scrollBarWidth: 10
    readonly property int sidebarWidth: 180
    readonly property int sidebarMinWidth: 150
    readonly property int sidebarMaxWidth: 350
    readonly property int sidebarPadding: 8
    readonly property int sidebarItemBorderRadius: 8
    readonly property int sectionMargin: 4
    // Embedded-mode overrides (0 radius to avoid software renderer artifacts)
    readonly property int sectionBorderRadiusEmbedded: 8
    readonly property int listItemBorderRadiusEmbedded: 8
    readonly property int sidebarItemBorderRadiusEmbedded: 8
    readonly property int buttonBorderRadiusEmbedded: 8
    // Sidebar item heights
    readonly property int sidebarItemHeight: 40
    readonly property int contentMaxHeight: 360
    readonly property int sidebarSubItemHeight: sidebarItemHeight - 12

    function cornerRadius(normalRadius) { return normalRadius }

    // === LAYOUT (scaled by text scale factor) ===
    readonly property int formColumnSpacing: scaled(20)
    readonly property int formRowSpacing: scaled(15)
    readonly property int stepContentMargins: scaled(8)
    readonly property int stepContentSpacing: scaled(8)

    // Font loaders
    FontLoader { id: robotoRegular; source: "fonts/Roboto-Regular.ttf" }
    FontLoader { id: robotoLight;   source: "fonts/Roboto-Light.ttf" }
    FontLoader { id: robotoBold;    source: "fonts/Roboto-Bold.ttf" }
}
