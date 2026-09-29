/* SPDX-License-Identifier: Apache-2.0 */

#include <QDebug>
#include <QEventLoop>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStyleHints>
#include <QTimer>
#include <QVariant>
#include <QtMath>
#include <qt_windows.h>
#include <windowsx.h>
#include <dwmapi.h>

// Capture the composed desktop, since QQuickWindow::grabWindow() excludes
// Qt's separate caption layer. Hit tests cannot prove the glyphs are visible.
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
    app.styleHints()->setColorScheme(Qt::ColorScheme::Light);
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
            width: 680; height: 520
            minimumWidth: 680; minimumHeight: 420
            // Same public platform flags as the Windows branch in main.qml.
            flags: Qt.Window | Qt.CustomizeWindowHint | Qt.WindowSystemMenuHint
                   | Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint
                   | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint | Qt.WindowCloseButtonHint
            color: "#f5f5f5"
            background: Rectangle { color: "#f5f5f5" }
            title: "Window regression probe"
            property bool dimmed: false
            Rectangle {
                parent: Overlay.overlay
                anchors.fill: parent
                visible: probeWindow.dimmed
                color: Qt.rgba(0, 0, 0, 0.3)
            }
            property bool protectClose: true
            property bool closeAttempted: false
            onClosing: function(close) { closeAttempted = true; close.accepted = !protectClose }
            header: WindowTitleBar {
                targetWindow: probeWindow
                height: probeWindow.visibility === Window.FullScreen ? 0 : Math.max(40, probeWindow.SafeArea.margins.top)
                visible: height > 0
                titleColor: "#646464"
                titleFont.pixelSize: 14
            }
        }
    )", QUrl("qrc:/probe.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    const HWND hwnd = reinterpret_cast<HWND>(window->winId());
    auto settle = [](int ms = 350) {
        QEventLoop loop;
        QTimer::singleShot(ms, &loop, &QEventLoop::quit);
        loop.exec();
    };
    bool passed = true;
    auto check = [&](bool ok, const char *description) {
        if (!ok) {
            qCritical() << "FAIL:" << description;
            passed = false;
        }
        return ok;
    };
    settle();
    window->raise();
    window->requestActivate();
    settle();
    if (GetForegroundWindow() != hwnd) {
        qWarning() << "No foreground test window; an interactive desktop is required";
        return 77;
    }

    // Test-only inspection of Qt's separate Windows caption rendering layer.
    // The application itself uses only the public window flags and SafeArea.
    HWND titlebar = nullptr;
    EnumChildWindows(hwnd, [](HWND child, LPARAM data) -> BOOL {
        wchar_t className[256]{};
        GetClassNameW(child, className, 256);
        if (QString::fromWCharArray(className).contains("_q_titlebar") && IsWindowVisible(child)) {
            *reinterpret_cast<HWND *>(data) = child;
            return FALSE;
        }
        return TRUE;
    }, reinterpret_cast<LPARAM>(&titlebar));
    if (!check(titlebar != nullptr, "Qt caption rendering window exists and is visible"))
        return 1;
    check(window->safeAreaMargins().top() > 0, "Title area reserved above the body");
    check((GetWindowLongPtr(hwnd, GWL_STYLE) & (WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX))
          == (WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX), "System resize and window commands retained");
    check(!(GetWindowLongPtr(hwnd, GWL_EXSTYLE) & WS_EX_LAYERED),
          "Main window retains a non-layered DWM frame");

    struct CursorRestore {
        POINT position{};
        CursorRestore() { GetCursorPos(&position); }
        ~CursorRestore() { SetCursorPos(position.x, position.y); }
    } restoreCursor;
    auto titleBounds = [&] {
        RECT rect{};
        GetWindowRect(titlebar, &rect);
        return rect;
    };
    auto buttonPoint = [&](int index) {
        const RECT rect = titleBounds();
        const int height = rect.bottom - rect.top;
        const int width = height * 3 / 2;
        return POINT{rect.right - width * (3 - index) + width / 2, rect.top + height / 2};
    };
    // Real pointer input matters: Qt's platform code consults GetAsyncKeyState
    // for these controls. Sending WM_SYSCOMMAND would bypass the buttons.
    auto click = [&](POINT point) {
        if (!check(GetForegroundWindow() == hwnd, "Probe owns foreground before pointer input"))
            return;
        SetCursorPos(point.x, point.y);
        settle(40);
        INPUT input{};
        input.type = INPUT_MOUSE;
        input.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
        check(SendInput(1, &input, sizeof(input)) == 1, "Pointer down delivered");
        settle(40);
        input.mi.dwFlags = MOUSEEVENTF_LEFTUP;
        check(SendInput(1, &input, sizeof(input)) == 1, "Pointer up delivered");
        settle(40);
    };
    auto checkPainting = [&](const char *state) {
        RECT bounds = titleBounds();
        bounds.left = bounds.right - 3 * ((bounds.bottom - bounds.top) * 3 / 2);
        // Keep the cursor out of the controls so the comparison includes no hover.
        POINT body{100, 100};
        ClientToScreen(hwnd, &body);
        SetCursorPos(body.x, body.y);
        settle();
        DwmFlush();
        const QImage desktop = captureScreen(bounds);
        if (!check(!desktop.isNull(), "Composed caption screenshot exists"))
            return;
        const QString backend = app.arguments().contains("--software") ? "software" : "default";
        check(desktop.save(QString("windowchrome-%1-%2.png").arg(backend, state)), "Caption screenshot saved");
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
                  "Each caption glyph is visible on the composed desktop");
        }
        const QImage quick = window->grabWindow();
        const QPoint point(qRound((window->width() - 24) * window->devicePixelRatio()),
                           qRound(window->safeAreaMargins().top() / 2.0 * window->devicePixelRatio()));
        check(quick.rect().contains(point) && quick.pixelColor(point).alpha() == 255,
              "Page remains opaque under Qt's separate caption layer (no cutout)");
    };
    checkPainting("normal");
    window->setProperty("dimmed", true);
    settle();
    checkPainting("dimmed");
    window->setProperty("dimmed", false);
    settle();

    const QSize normalSize = window->size();
    click(buttonPoint(1));
    settle();
    check(IsZoomed(hwnd), "Qt maximize button");
    checkPainting("maximized");
    click(buttonPoint(1));
    settle();
    check(!IsZoomed(hwnd) && window->size() == normalSize, "Qt maximize button restores original size");

    auto doubleClickTitle = [&] {
        const RECT rect = titleBounds();
        const POINT point{(rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2};
        click(point);
        click(point);
        settle();
    };
    doubleClickTitle();
    check(IsZoomed(hwnd), "Double-click centered title maximizes");
    doubleClickTitle();
    check(!IsZoomed(hwnd) && window->size() == normalSize, "Double-click restores original size");
    POINT body{200, 150};
    ClientToScreen(hwnd, &body);
    click(body);
    click(body);
    settle();
    check(!IsZoomed(hwnd), "Body double-click does not maximize");

    click(buttonPoint(0));
    settle();
    check(IsIconic(hwnd), "Qt minimize button");
    window->showNormal();
    window->requestActivate();
    settle();
    click(buttonPoint(2));
    settle();
    check(window->isVisible() && window->property("closeAttempted").toBool(), "Qt close button preserves QML close veto");
    window->setProperty("protectClose", false);
    click(buttonPoint(2));
    settle();
    check(!window->isVisible(), "Qt close button accepted after guard clears");
    if (passed)
        qInfo() << "PASS: visible caption glyphs, opaque page, real button clicks, title double-click and close guard";
    return passed ? 0 : 1;
}
