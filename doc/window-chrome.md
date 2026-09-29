# Desktop window chrome

macOS uses AppKit window controls. Windows uses Qt's platform title-bar
controls, drawn in the Windows style. Linux uses an Ubuntu-style client frame. Embedded mode retains its existing frameless UI. The
application title remains set on `QWindow` for
task switchers and accessibility, even where a centered QML label draws it.

| Platform | Controls and behavior | Title/background/corners |
| --- | --- | --- |
| macOS | AppKit traffic lights; system move; double-click maximizes/restores | Transparent expanded title bar, centered label, system corners/shadow |
| Windows | Qt platform caption buttons; system move; double-click maximizes/restores | Transparent Qt title-bar background, centered QML label; DWM corners/shadow |
| Linux | Client-drawn Yaru-style buttons; system move/resize; double-click maximizes/restores | Transparent title background, centered label, rounded surface and client shadow |

“Transparent title bar” means the application's page background continues
beneath the title and controls, as on macOS; it does not make the entire
window translucent to the desktop. Inner application panels retain their
rounded corners on every platform.

Linux combines a transparent, rounded client frame with Ubuntu Yaru-style
controls on the right: minimize, maximize/restore, close. They use neutral
circular backgrounds and dark glyphs, with hover/pressed/backdrop states.
They are drawn by the app rather than desktop native buttons. The title bar
shares the page background. A transparent
margin contains a small shadow without shrinking the content area. On
maximize, the shadow margin and outer radius are removed; fullscreen also
hides the title bar. The maximize glyph becomes a restore glyph when maximized.
The title reserves symmetric space based on the control group width.
Dialog dimming follows the same inset and corner shape.
Dragging starts after the platform drag threshold so it cannot swallow a
double-click. Edge and corner hit areas invoke `startSystemResize`; dragging
uses `startSystemMove`, leaving the compositor in charge on X11/Wayland.
These controls do not provide AppKit-only menus such as macOS's green-button
Move & Resize menu. Rounded transparency requires a compositing desktop;
the client shadow uses Qt Quick Effects and requires a graphics backend
that supports shader effects.

Windows uses the public `Qt::ExpandedClientAreaHint` and
`Qt::NoTitleBarBackgroundHint` flags. `Qt::CustomizeWindowHint` and explicit
minimize/maximize/close hints request all three controls without a second,
left-aligned title/icon. `WindowTitleBar` draws the centered title, reserves
symmetric button space and uses the window's `SafeArea` height. It starts
system movement after the drag threshold and handles double-click maximize
and restore. The application title remains available for the taskbar.

In Qt 6.10.3 and 6.11.1 the Windows platform plugin draws those controls in a
separate caption window above the Quick scene. They are Windows-style Qt
controls, **not DWM-rendered native caption buttons**. Native-only behavior,
such as the Windows 11 maximize-hover Snap flyout, is not guaranteed by this
Qt implementation. The page and modal dimmer remain opaque; there is no
transparent hole under the buttons. Windows GUI startup requests a light
application color scheme because the application's page palette is fixed
light and the Qt caption glyphs use that scheme.

The previous custom `WM_NCCALCSIZE`/DWM-button solution has been removed:
Windows testing showed an empty rectangle even after the Quick surface left
its button area transparent. Alpha-only tests did not establish visible
controls. Qt now owns frame sizing, caption drawing and button input as one
implementation, including software rendering.

Qt retains the system resize frame and DWM shadow. Windows 11 normally adds
rounded outer corners; maximized/snapped/remote windows may have square
corners, and Windows 10 retains its native square corners. The application
sets no window-region mask and does not make its main window layered.

## Validation

The macOS build and isolated AppKit event regression cover native button
presence, transparent title bar, double-click maximize/restore over the
centered title and blank header, exclusion of body clicks, minimize/restore,
and the QML close guard. They do not replace physical mouse testing on the
target desktops.

The standalone Windows probe requires a Windows graphical session and Qt
6.9 or later. It does not link ImageWriter or access storage devices:

```powershell
cmake -S src/test/windowchrome -B build-windowchrome -G Ninja -DCMAKE_PREFIX_PATH="$env:Qt6_ROOT"
cmake --build build-windowchrome
ctest --test-dir build-windowchrome --output-on-failure
```

It checks **composed desktop pixels** for all three caption glyphs in normal,
dimmed and maximized states, saves `windowchrome-*.png` in the test directory,
and verifies that the page beneath remains opaque. It uses the actual
`WindowTitleBar.qml` component and sends real pointer clicks to Qt's three
buttons, then checks title double-click maximize/restore, body exclusion,
minimize and the QML close veto. It exercises both the default renderer and
software rendering. These tests move the mouse and restore its position on
exit. Run them on an unobscured interactive desktop; missing DWM or an
unavailable foreground window returns a CTest skip.

Before release, also inspect on Windows 10/11 and GNOME/KDE under both X11
and Wayland: button glyphs and hover, title/background continuity,
ordinary/maximized corners, physical drag and restore-drag, double-click,
edge/corner resize, title elision, 100/150/200% DPI and mixed-DPI monitors,
taskbar bounds, system theme changes, and close confirmation during writing.
Windows DWM and Linux compositor runtime checks have not been run on the
macOS development host. Linux client-frame layout and synthetic Qt mouse
interaction can be checked there without claiming Linux compositor coverage.

References: [Qt expanded client areas](https://www.qt.io/blog/expanded-client-areas-and-safe-areas-in-qt-6.9),
[Qt Windows caption implementation](https://github.com/qt/qtbase/blob/v6.10.3/src/plugins/platforms/windows/qwindowswindow.cpp),
[Windows 11 rounded corners](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/ui/apply-rounded-corners).

Linux control styling reference: [Ubuntu Yaru title buttons](https://github.com/ubuntu/yaru/blob/master/gtk/src/default/gtk-3.0/_tweaks.scss).
