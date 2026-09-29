# Desktop window chrome

macOS and Windows use system window controls. Linux uses an Ubuntu-style
client-drawn frame. Embedded mode retains its existing frameless UI. The
application title remains set on `QWindow` for
task switchers and accessibility, even where a centered QML label draws it.

| Platform | Controls and behavior | Title/background/corners |
| --- | --- | --- |
| macOS | AppKit traffic lights; system move; double-click maximizes/restores | Transparent expanded title bar, centered label, system corners/shadow |
| Windows | DWM caption buttons; caption hit testing for move, double-click, system menu and Snap | Page extends under controls; centered label; Windows 11 DWM corners/shadow |
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

Windows deliberately does **not** use `Qt::ExpandedClientAreaHint`: Qt
6.11.1 implements that mode with a separate Qt-painted title-bar window.
Instead, `windows/windowchrome.cpp` retains the native caption and resize
styles, extends the DWM frame, and removes only the top caption inset via
`WM_NCCALCSIZE`. DWM gets first refusal for caption hit testing. Remaining
title hits return `HTCAPTION`, while body hits remain `HTCLIENT`; QML does
not compete with Windows for mouse presses or double-clicks. Qt captures
the resulting non-client margins. Caption metrics follow monitor DPI and
reserve equal space on both sides of the centered title.

The Quick window requests an alpha surface and clears to transparent. Its
page background leaves a cutout at the DWM caption-button bounds, converted
from window-relative native pixels to client-relative logical pixels.
`WindowFrameBackground` applies the same cutout to dialog dimming. All other
page pixels remain opaque. Without both the alpha surface and these cutouts,
the Quick scene can cover the native buttons even though their hit tests work.
On Windows 11 the native caption color matches the page underneath the controls.

Windows 10 retains its native square outer corners. Windows 11 may also
use square corners when maximized, snapped, or running remotely/virtually.
If DWM frame extension, a supported alpha graphics surface, or valid caption
button bounds are unavailable, the ordinary system title bar is retained
and the QML title row stays hidden. Software rendering uses this fallback.
No window-region mask or `WS_EX_LAYERED` flag is used to force rounding;
the caption and resize styles remain for native shadows and corners.

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
and checks the Quick surface's alpha cutout. It also checks native caption
button hit codes (including maximize hover), title/body/top-edge hit testing,
maximize/restore geometry, minimize and native close veto. A second run checks
the software-rendering fallback. Run these tests on an unobscured interactive
desktop; missing DWM or an unavailable foreground window returns a CTest skip.

Before release, also inspect on Windows 10/11 and GNOME/KDE under both X11
and Wayland: native button hover and Snap menu, title/background continuity,
ordinary/maximized corners, physical drag and restore-drag, double-click,
edge/corner resize, title elision, 100/150/200% DPI and mixed-DPI monitors,
taskbar bounds, system theme changes, and close confirmation during writing.
Windows DWM and Linux compositor runtime checks have not been run on the
macOS development host. Linux client-frame layout and synthetic Qt mouse
interaction can be checked there without claiming Linux compositor coverage.

References: [Qt expanded client areas](https://www.qt.io/blog/expanded-client-areas-and-safe-areas-in-qt-6.9),
[Microsoft custom DWM frame](https://learn.microsoft.com/en-us/windows/win32/dwm/customframe),
[DwmDefWindowProc](https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/nf-dwmapi-dwmdefwindowproc),
[Windows 11 rounded corners](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/ui/apply-rounded-corners).

Linux control styling reference: [Ubuntu Yaru title buttons](https://github.com/ubuntu/yaru/blob/master/gtk/src/default/gtk-3.0/_tweaks.scss).
