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

    // === COLOR TOKENS ===
    // Canonical semantic names. Legacy names below remain as compatibility
    // aliases while individual pages are migrated.
    readonly property color colorSurfacePage: "#F5F5F5"
    readonly property color colorSurfacePanel: "#FFFFFF"
    readonly property color colorSurfaceMuted: "#F2F2F2"
    readonly property color colorBorderSubtle: "#E7E3E4"
    readonly property color colorBorderDefault: "#DCDCDC"
    readonly property color colorTextPrimary: "#1A1A1A"
    readonly property color colorTextSecondary: "#646464"
    readonly property color colorTextDisabled: "#888888"
    readonly property color colorAccentPrimary: "#0057FF"
    readonly property color colorAccentPrimaryHover: "#0047DB"
    readonly property color colorSelectionSurface: "#F4F8FC"
    readonly property color colorControlBorderInactive: "#BDBEBF"
    readonly property color colorBorderDisabled: "#D0D0D0"
    readonly property color colorSurfaceError: "#FFEBEE"
    readonly property color colorTextErrorStrong: "#C62828"
    readonly property color colorAccentWarning: "#FFA500"
    readonly property color colorSurfaceControlInactive: "#E1E2E7"
    readonly property color colorTextChrome: "#5A5A5A"
    readonly property color colorTextChromeMuted: "#666666"
    readonly property color colorChromeClose: "#FF5F57"
    readonly property color colorChromeMinimize: "#FEBC2E"
    readonly property color colorChromeMaximize: "#28C840"
    readonly property color colorSurfaceButtonFocus: "#D1DCFB"
    readonly property color colorSurfaceButtonHover: colorSurfaceMuted
    readonly property color colorAccentButtonFocusDanger: "#8F122C"
    readonly property color colorBorderTitle: "#AFAFAF"
    readonly property color colorBorderSelection: "#7AA7E8"
    readonly property color colorTextSidebarTitle: "#171717"
    readonly property color colorBorderSidebarControl: "#767676"
    readonly property color colorProgressVerify: "#6CC04A"
    readonly property color colorSurfaceLanbar: "#FFFFE3"
    readonly property color colorTextError: "#EF4444"
    readonly property color colorTextOnAccent: colorSurfacePanel
    readonly property color colorFocus: "#0078D4"

    // === COMPONENT COLOR TOKENS ===
    readonly property color transparent: "transparent"

    readonly property color buttonBackgroundColor: colorSurfacePage
    readonly property color buttonForegroundColor: colorAccentPrimary
    readonly property color buttonTextColor: colorTextSecondary
    readonly property color buttonDisabledBackgroundColor: colorSurfaceMuted
    readonly property color buttonDisabledTextColor: colorTextDisabled
    readonly property color buttonFocusedBackgroundColor: colorSurfaceButtonFocus
    readonly property color buttonHoveredBackgroundColor: colorSurfaceButtonHover

    readonly property color button2BackgroundColor: colorAccentPrimary
    readonly property color button2ForegroundColor: colorTextOnAccent
    // Focused: noticeably darker for strong state indication (keyboard focus)
    readonly property color button2FocusedBackgroundColor: colorAccentButtonFocusDanger
    // Hovered: noticeably lighter to differentiate from base (≥4.5:1 contrast vs base)
    readonly property color button2HoveredBackgroundColor: colorAccentPrimaryHover
    // Hovered foreground should be Raspberry Red for ≥4.5:1 contrast on the light hover bg
    readonly property color button2HoveredForegroundColor: colorAccentPrimary
    readonly property color titleSeparatorColor: colorBorderTitle
    // Selection highlight color for OS/device lists
    readonly property color listViewSelectedBorderColor: colorBorderSelection

    // Utility translucent colors
    readonly property color translucentWhite10: Qt.rgba(255, 255, 255, 0.1)
    readonly property color translucentWhite30: Qt.rgba(255, 255, 255, 0.3)

    // Sidebar colors
    readonly property color sidebarTitleColor: colorTextSidebarTitle
    readonly property color sidebarActiveBackgroundColor: colorSurfacePage
    readonly property color sidebarActiveBorderColor: colorBorderDefault
    readonly property color sidebarTextOnActiveColor: colorSurfacePanel
    readonly property color sidebarTextOnInactiveColor: colorAccentPrimary
    readonly property color sidebarTextDisabledColor: colorTextDisabled
    // Sidebar controls
    readonly property color sidebarControlBorderColor: colorBorderSidebarControl
    readonly property color sidebarBackgroundColour: colorSurfacePanel
    readonly property color sidebarBorderColour: colorBorderSubtle
    readonly property color sidebarHoverBackgroundColor: colorSurfaceMuted

    // for the "device / OS / storage" titles
    readonly property color subtitleColor: colorTextOnAccent

    readonly property color progressBarTextColor: colorTextOnAccent
    readonly property color progressBarVerifyForegroundColor: colorProgressVerify
    readonly property color progressBarBackgroundColor: colorAccentPrimary
    // New: distinct colors for writing vs verification phases
    readonly property color progressBarWritingForegroundColor: colorAccentPrimary
    readonly property color progressBarTrackColor: colorSurfacePage

    readonly property color lanbarBackgroundColor: colorSurfaceLanbar

    /// the check-boxes/radio-buttons have labels that might be disabled
    readonly property color formLabelColor: "black"
    readonly property color formLabelErrorColor: colorTextError
    readonly property color formLabelDisabledColor: "grey"
    readonly property color embeddedModeInfoTextColor: colorTextOnAccent

    // Focus/outline
    readonly property color focusOutlineColor: colorFocus
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

    // === SPACING TOKENS ===
    readonly property int spacingPageInset: 8
    readonly property int spacingPanelGap: 16
    readonly property int spacingContentInset: 8
    readonly property int spacingCardInset: 12
    readonly property int spacingPopupInset: 16

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
    // === GEOMETRY TOKENS ===
    readonly property int radiusPanel: 14
    readonly property int radiusCard: 8
    readonly property int radiusButton: 8
    readonly property int borderWidthDefault: 1
    readonly property int titleBarHeight: 36
    readonly property int titleBarRadius: 14
    readonly property int titleBarControlSize: 12
    readonly property int iconButtonSize: 32
    readonly property int iconSmallSize: 16
    readonly property int contentInset: spacingContentInset
    readonly property int cardInset: spacingCardInset
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
