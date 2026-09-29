/*
 * SPDX-License-Identifier: Apache-2.0
 */

#include "../../windows/windowchrome.h"
#include <QDebug>
#include <QEventLoop>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QTimer>
#include <QVariant>
#include <QWindow>
#include <QtMath>
#include <qt_windows.h>
#include <windowsx.h>
#include <dwmapi.h>

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
            color: "#f5f5f5"
            title: "Native window regression probe"
            property real nativeTitleBarHeight: 0
            property real nativeTitleBarInset: 0
            property bool protectClose: true
            property bool closeAttempted: false
            onClosing: function(close) { closeAttempted = true; close.accepted = !protectClose }
            header: Item {
                height: probeWindow.nativeTitleBarHeight
                Text { anchors.centerIn: parent; text: "Native window regression probe" }
            }
        }
    )");
    if (engine.rootObjects().isEmpty())
        return 1;
    auto *window = qobject_cast<QWindow *>(engine.rootObjects().first());
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
    settle();
    check(window->property("nativeTitleBarHeight").toReal() > 0, "DWM title area reserved");
    check((GetWindowLongPtr(hwnd, GWL_STYLE) & (WS_CAPTION | WS_THICKFRAME | WS_SYSMENU))
          == (WS_CAPTION | WS_THICKFRAME | WS_SYSMENU), "Native caption, resize and menu styles");
    auto hit = [&](POINT point) {
        ClientToScreen(hwnd, &point);
        return SendMessage(hwnd, WM_NCHITTEST, 0, MAKELPARAM(point.x, point.y));
    };
    const int titleHeight = qRound(window->property("nativeTitleBarHeight").toReal()
                                  * window->devicePixelRatio());
    check(hit({200, titleHeight / 2}) == HTCAPTION, "Title text uses system caption hit testing");
    check(hit({200, titleHeight + 40}) == HTCLIENT, "Body is not draggable");
    check(hit({200, 1}) == HTTOP, "Top resize border retained");

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
    POINT titlePoint{200, titleHeight / 2};
    ClientToScreen(hwnd, &titlePoint);
    SendMessage(hwnd, WM_NCLBUTTONDBLCLK, HTCAPTION, MAKELPARAM(titlePoint.x, titlePoint.y));
    settle();
    check(IsZoomed(hwnd), "Caption double-click maximizes");
    titlePoint = {200, titleHeight / 2};
    ClientToScreen(hwnd, &titlePoint);
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
        qInfo() << "PASS: native DWM hit testing, resize, maximize/restore, minimize and close guard";
    return passed ? 0 : 1;
}
