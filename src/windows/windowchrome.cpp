/*
 * SPDX-License-Identifier: Apache-2.0
 */

#include "windowchrome.h"

#include <QAbstractNativeEventFilter>
#include <QColor>
#include <QCoreApplication>
#include <QTimer>
#include <QVariant>
#include <QWindow>
#include <QtMath>
#include <qt_windows.h>
#include <windowsx.h>
#include <dwmapi.h>

namespace {
class NativeWindowChrome final : public QObject, public QAbstractNativeEventFilter
{
public:
    explicit NativeWindowChrome(QWindow *window)
        : QObject(window), _window(window), _hwnd(reinterpret_cast<HWND>(window->winId()))
    {
        QCoreApplication::instance()->installNativeEventFilter(this);
        connect(window, &QWindow::screenChanged, this, [this] { scheduleUpdate(); });
        connect(window, &QWindow::widthChanged, this, [this] { scheduleUpdate(); });
        connect(window, &QWindow::windowStateChanged, this, [this] { scheduleUpdate(); });
        updateFrame();
    }

    ~NativeWindowChrome() override
    {
        QCoreApplication::instance()->removeNativeEventFilter(this);
    }

    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override
    {
        if (eventType != "windows_generic_MSG")
            return false;
        const auto *msg = static_cast<const MSG *>(message);
        if (msg->hwnd != _hwnd)
            return false;

        switch (msg->message) {
        case WM_DWMCOMPOSITIONCHANGED:
        case WM_DPICHANGED:
        case WM_THEMECHANGED:
        case WM_SETTINGCHANGE:
        case WM_SHOWWINDOW:
            scheduleUpdate();
            break;
        default:
            break;
        }

        if (!_extended || _window->windowState() == Qt::WindowFullScreen)
            return false;

        if (msg->message == WM_NCCALCSIZE && msg->wParam) {
            auto *params = reinterpret_cast<NCCALCSIZE_PARAMS *>(msg->lParam);
            const LONG top = params->rgrc[0].top;
            // Keep the real side/bottom resize borders and let Windows
            // calculate maximized bounds (including the taskbar). Only the
            // caption is removed; WS_CAPTION/WS_THICKFRAME remain intact.
            DefWindowProc(_hwnd, msg->message, msg->wParam, msg->lParam);
            params->rgrc[0].top = top + (IsZoomed(_hwnd) ? resizeBorder() : 0);
            *result = 0;
            return true;
        }

        // DWM owns the actual buttons and their hover/press/Snap behavior.
        // In particular WM_NCMOUSELEAVE must reach it to clear hover state.
        LRESULT nativeResult = 0;
        if (DwmDefWindowProc(_hwnd, msg->message, msg->wParam, msg->lParam, &nativeResult)) {
            *result = nativeResult;
            return true;
        }

        if (msg->message != WM_NCHITTEST)
            return false;

        // Preserve side/bottom resizing from the normal system frame.
        nativeResult = DefWindowProc(_hwnd, msg->message, msg->wParam, msg->lParam);
        switch (nativeResult) {
        case HTLEFT: case HTRIGHT: case HTTOP: case HTBOTTOM:
        case HTTOPLEFT: case HTTOPRIGHT: case HTBOTTOMLEFT: case HTBOTTOMRIGHT:
            *result = nativeResult;
            return true;
        default:
            break;
        }

        POINT point{GET_X_LPARAM(msg->lParam), GET_Y_LPARAM(msg->lParam)};
        ScreenToClient(_hwnd, &point);
        RECT client{};
        GetClientRect(_hwnd, &client);
        if (!PtInRect(&client, point))
            return false;

        if (!IsZoomed(_hwnd) && point.y < resizeBorder()) {
            // Removing the caption also removes the top resize strip.
            *result = point.x < resizeBorder() ? HTTOPLEFT
                    : point.x >= client.right - resizeBorder() ? HTTOPRIGHT : HTTOP;
        } else {
            // A real caption hit gives us system move, double-click maximize,
            // restore-drag, right-click menu and Aero Snap without QML races.
            *result = point.y < titleBarHeight() ? HTCAPTION : HTCLIENT;
        }
        return true;
    }

private:
    int resizeBorder() const
    {
        const UINT dpi = GetDpiForWindow(_hwnd);
        return GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi)
                + GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
    }

    int titleBarHeight() const
    {
        return GetSystemMetricsForDpi(SM_CYCAPTION, GetDpiForWindow(_hwnd)) + resizeBorder();
    }

    void scheduleUpdate()
    {
        if (_updatePending)
            return;
        _updatePending = true;
        // DPI and state changes must finish in Qt/DefWindowProc first.
        QTimer::singleShot(0, this, [this] {
            _updatePending = false;
            updateFrame();
        });
    }

    void updateFrame()
    {
        BOOL composition = FALSE;
        const bool available = SUCCEEDED(DwmIsCompositionEnabled(&composition)) && composition;
        const bool fullScreen = _window->windowState() == Qt::WindowFullScreen;
        const MARGINS margins{0, 0, available && !fullScreen ? titleBarHeight() : 0, 0};
        const bool extended = SUCCEEDED(DwmExtendFrameIntoClientArea(_hwnd, &margins)) && available;
        const bool changed = _extended != extended;
        _extended = extended;

        if (_extended) {
            // DWMWA_WINDOW_CORNER_PREFERENCE / DWMWCP_ROUND (Windows 11).
            // Older systems reject this optional attribute and retain their
            // native corners. Do not use a region mask or a layered window:
            // both prevent DWM from rounding the actual window.
            const DWORD round = 2;
            DwmSetWindowAttribute(_hwnd, static_cast<DWMWINDOWATTRIBUTE>(33), &round, sizeof(round));
            // Caption glyphs must contrast with the actual page beneath
            // them, even if the OS uses dark chrome and this page is light.
            const QColor background = _window->property("color").value<QColor>();
            const BOOL dark = background.isValid() && background.lightnessF() < 0.5;
            DwmSetWindowAttribute(_hwnd, static_cast<DWMWINDOWATTRIBUTE>(20), &dark, sizeof(dark));
        }

        if (changed)
            SetWindowPos(_hwnd, nullptr, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);

        const qreal scale = _window->devicePixelRatio();
        const int height = _extended && !fullScreen ? titleBarHeight() : 0;
        // Reserve both sides symmetrically so even a long translated title
        // stays centered in the window and never runs under native buttons.
        RECT buttons{};
        int inset = height * 5;
        if (height && !IsIconic(_hwnd)
                && SUCCEEDED(DwmGetWindowAttribute(_hwnd, DWMWA_CAPTION_BUTTON_BOUNDS,
                                                   &buttons, sizeof(buttons)))
                && buttons.right > buttons.left) {
            inset = buttons.right - buttons.left + resizeBorder();
        }
        _window->setProperty("nativeTitleBarHeight", height / scale);
        _window->setProperty("nativeTitleBarInset", qCeil(inset / scale) + 12);
    }

    QWindow *_window;
    HWND _hwnd;
    bool _extended = false;
    bool _updatePending = false;
};
}

void enableWindowsWindowChrome(QWindow *window)
{
    if (!window || window->flags().testFlag(Qt::FramelessWindowHint))
        return;
    new NativeWindowChrome(window);
}
