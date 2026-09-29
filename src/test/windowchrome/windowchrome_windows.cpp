/*
 * SPDX-License-Identifier: Apache-2.0
 */

#include "../../windows/windowchrome.h"
#include <QDebug>
#include <QEventLoop>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>
#include <QVariant>
#include <QWindow>
#include <QtMath>
#include <qt_windows.h>
#include <windowsx.h>
#include <dwmapi.h>

// Capture the composed desktop, since QQuickWindow::grabWindow() excludes
// DWM. A hit-test success alone cannot prove the native glyphs are visible.
static QImage captureScreen(const RECT &rect)
{
    const int width = rect.right - rect.left, height = rect.bottom - rect.top;
    if (width <= 0 || height <= 0)
        return {};
    HDC screen = GetDC(nullptr);
    HDC memory = CreateCompatibleDC(screen);
    BITMAPINFO info{};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = width;
    info.bmiHeader.biHeight = -height;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    void *pixels = nullptr;
    HBITMAP bitmap = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &pixels, nullptr, 0);
    QImage image;
    if (bitmap) {
        HGDIOBJ previous = SelectObject(memory, bitmap);
        if (BitBlt(memory, 0, 0, width, height, screen, rect.left, rect.top, SRCCOPY | CAPTUREBLT))
            image = QImage(static_cast<uchar *>(pixels), width, height, QImage::Format_RGB32).copy();
        SelectObject(memory, previous);
        DeleteObject(bitmap);
    }
    DeleteDC(memory);
    ReleaseDC(nullptr, screen);
    return image;
}

// A standalone GUI probe: no ImageWriter, disks, network, or saved settings.
int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    app.setQuitOnLastWindowClosed(false);
    QQuickStyle::setStyle("Basic");
    BOOL composition = FALSE;
    if (FAILED(DwmIsCompositionEnabled(&composition)) || !composition)
        return 77;

    QQmlApplicationEngine engine;
    engine.loadData(R"(
        import QtQuick
        import QtQuick.Controls
        ApplicationWindow {
            id: probeWindow
            visible: true
            width: 680; height: 450
            minimumWidth: 680; minimumHeight: 420
            flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint
                   | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint | Qt.WindowCloseButtonHint
            color: "transparent"
            title: "Native window regression probe"
            property real nativeTitleBarHeight: 0
            property real nativeTitleBarInset: 0
            property rect nativeCaptionButtonsRect: Qt.rect(0, 0, 0, 0)
            readonly property color nativeTitleBarColor: "#f5f5f5"
            property bool dimmed: false
            background: WindowFrameBackground {
                surfaceColor: probeWindow.nativeTitleBarColor
                nativeControlsRect: probeWindow.nativeCaptionButtonsRect
            }
            // Use the same background component as BaseDialog's modal dimmer.
            WindowFrameBackground {
                parent: Overlay.overlay
                anchors.fill: parent
                visible: probeWindow.dimmed
                surfaceColor: Qt.rgba(0, 0, 0, 0.3)
                nativeControlsRect: probeWindow.nativeCaptionButtonsRect
            }
            property bool protectClose: true
            property bool closeAttempted: false
            onClosing: function(close) { closeAttempted = true; close.accepted = !protectClose }
            header: Item {
                height: probeWindow.nativeTitleBarHeight
                Text { anchors.centerIn: parent; text: "Native window regression probe" }
            }
        }
    )", QUrl("qrc:/probe.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    enableWindowsWindowChrome(window);
    const HWND hwnd = reinterpret_cast<HWND>(window->winId());
    auto settle = [] {
        QEventLoop loop;
        QTimer::singleShot(350, &loop, &QEventLoop::quit);
        loop.exec();
    };
    bool passed = true;
    auto check = [&](bool ok, const char *description) {
        if (!ok) {
            qCritical() << "FAIL:" << description;
            passed = false;
        }
    };
    const bool software = app.arguments().contains("--software");
    settle();
    window->raise();
    window->requestActivate();
    settle();
    if (GetForegroundWindow() != hwnd) {
        qWarning() << "No unobscured foreground test window; skipping desktop pixel checks";
        return 77;
    }
    check(software ? window->property("nativeTitleBarHeight").toReal() == 0
                   : window->property("nativeTitleBarHeight").toReal() > 0,
          "Accelerated rendering extends the title; software retains the system title");
    check((GetWindowLongPtr(hwnd, GWL_STYLE) & (WS_CAPTION | WS_THICKFRAME | WS_SYSMENU))
          == (WS_CAPTION | WS_THICKFRAME | WS_SYSMENU), "Native caption, resize and menu styles");
    check(!(GetWindowLongPtr(hwnd, GWL_EXSTYLE) & WS_EX_LAYERED),
          "Alpha surface retains a native non-layered frame for DWM corners/shadow");
    auto hit = [&](POINT point) {
        ClientToScreen(hwnd, &point);
        return SendMessage(hwnd, WM_NCHITTEST, 0, MAKELPARAM(point.x, point.y));
    };
    const int titleHeight = qRound(window->property("nativeTitleBarHeight").toReal()
                                  * window->devicePixelRatio());
    if (!software) {
        check(hit({200, titleHeight / 2}) == HTCAPTION, "Title text uses system caption hit testing");
        check(hit({200, 1}) == HTTOP, "Top resize border retained");
    }
    check(hit({200, titleHeight + 40}) == HTCLIENT, "Body is not draggable");

    auto checkPainting = [&](const char *state) {
        RECT bounds{}, windowRect{};
        if (FAILED(DwmGetWindowAttribute(hwnd, DWMWA_CAPTION_BUTTON_BOUNDS, &bounds, sizeof(bounds)))) {
            check(false, "Native caption bounds available for painting check");
            return;
        }
        GetWindowRect(hwnd, &windowRect);
        OffsetRect(&bounds, windowRect.left, windowRect.top);
        DwmFlush();
        const QImage desktop = captureScreen(bounds);
        check(!desktop.isNull(), "Composed native caption screenshot exists");
        if (desktop.isNull())
            return;
        check(desktop.save(QString("windowchrome-%1-%2.png")
                           .arg(software ? "software" : "native", state)), "Caption screenshot saved");
        // Exclude edges/borders and inspect each glyph's central area. Both
        // completely blank and completely dark rectangles must fail.
        for (int button = 0; button < 3; ++button) {
            const int cell = desktop.width() / 3;
            const QRect center(button * cell + cell / 4, desktop.height() / 4,
                               cell / 2, desktop.height() / 2);
            int tones[16]{};
            for (int y = center.top(); y <= center.bottom(); ++y)
                for (int x = center.left(); x <= center.right(); ++x)
                    ++tones[qGray(desktop.pixel(x, y)) / 16];
            int backgroundTone = 0;
            for (int i = 1; i < 16; ++i)
                if (tones[i] > tones[backgroundTone])
                    backgroundTone = i;
            int contrasting = 0;
            for (int i = 0; i < 16; ++i)
                if (qAbs(i - backgroundTone) >= 4)
                    contrasting += tones[i];
            check(contrasting >= 3 && contrasting < center.width() * center.height() / 2,
                  "Each native caption glyph is visible on the desktop");
        }
        if (!software) {
            const QRectF cutout = window->property("nativeCaptionButtonsRect").toRectF();
            const QImage quick = window->grabWindow();
            const QPoint point = (cutout.center() * window->devicePixelRatio()).toPoint();
            check(!cutout.isEmpty() && quick.rect().contains(point)
                  && quick.pixelColor(point).alpha() == 0,
                  "Quick background and dimmer leave DWM pixels transparent");
        }
    };
    checkPainting("normal");
    window->setProperty("dimmed", true);
    settle();
    checkPainting("dimmed");
    window->setProperty("dimmed", false);

    RECT buttons{}, frame{};
    check(SUCCEEDED(DwmGetWindowAttribute(hwnd, DWMWA_CAPTION_BUTTON_BOUNDS, &buttons, sizeof(buttons)))
          && buttons.right > buttons.left, "DWM exposes native caption buttons");
    GetWindowRect(hwnd, &frame);
    // Caption button bounds are window-relative, not client-relative.
    const LONG buttonWidth = (buttons.right - buttons.left) / 3;
    const LONG buttonY = frame.top + (buttons.top + buttons.bottom) / 2;
    for (int i = 0; i < 3; ++i) {
        const LONG x = frame.left + buttons.left + buttonWidth * i + buttonWidth / 2;
        const LRESULT expected[] = {HTMINBUTTON, HTMAXBUTTON, HTCLOSE};
        check(SendMessage(hwnd, WM_NCHITTEST, 0, MAKELPARAM(x, buttonY)) == expected[i],
              "Native caption button hit (including maximize hover for Snap)");
    }

    const QSize normalSize = window->size();
    // DWM bounds also provide a title-row point in standard-frame fallback.
    POINT titlePoint{frame.left + 200, buttonY};
    SendMessage(hwnd, WM_NCLBUTTONDBLCLK, HTCAPTION, MAKELPARAM(titlePoint.x, titlePoint.y));
    settle();
    check(IsZoomed(hwnd), "Caption double-click maximizes");
    checkPainting("maximized");
    GetWindowRect(hwnd, &frame);
    DwmGetWindowAttribute(hwnd, DWMWA_CAPTION_BUTTON_BOUNDS, &buttons, sizeof(buttons));
    titlePoint = {frame.left + 200, frame.top + (buttons.top + buttons.bottom) / 2};
    SendMessage(hwnd, WM_NCLBUTTONDBLCLK, HTCAPTION, MAKELPARAM(titlePoint.x, titlePoint.y));
    settle();
    check(!IsZoomed(hwnd) && window->size() == normalSize, "Double-click restores original size");
    SendMessage(hwnd, WM_SYSCOMMAND, SC_MINIMIZE, 0);
    settle();
    check(IsIconic(hwnd), "Native minimize command");
    SendMessage(hwnd, WM_SYSCOMMAND, SC_RESTORE, 0);
    settle();
    check(!IsIconic(hwnd), "Native restore command");
    SendMessage(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
    settle();
    check(window->isVisible() && window->property("closeAttempted").toBool(), "QML can veto native close");
    window->setProperty("protectClose", false);
    SendMessage(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
    settle();
    check(!window->isVisible(), "Native close accepted after guard clears");
    if (passed)
        qInfo() << "PASS: caption pixels, modal alpha, DWM hit testing, resize, maximize/restore, minimize and close guard";
    return passed ? 0 : 1;
}
