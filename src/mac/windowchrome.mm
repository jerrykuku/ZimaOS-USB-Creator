/*
 * SPDX-License-Identifier: Apache-2.0
 */

#include "windowchrome.h"

#include <QWindow>
#import <AppKit/AppKit.h>

namespace {
class NativeTitleDoubleClickHandler final : public QObject
{
public:
    explicit NativeTitleDoubleClickHandler(QWindow *window)
        : QObject(window), _window(window)
    {
        _monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown
            handler:^NSEvent *(NSEvent *event) {
                return handleMouseDown(event);
            }];
    }

    ~NativeTitleDoubleClickHandler() override
    {
        [NSEvent removeMonitor:_monitor];
    }

private:
    NSEvent *handleMouseDown(NSEvent *event)
    {
        if (event.clickCount != 2 || _window->windowState() == Qt::WindowFullScreen)
            return event;

        NSView *content = reinterpret_cast<NSView *>(_window->winId());
        if (!content.window || event.window != content.window)
            return event;

        const NSPoint point = [content convertPoint:event.locationInWindow fromView:nil];
        if (point.y < 0 || point.y >= _window->safeAreaMargins().top())
            return event;

        NSView *frame = content.superview;
        NSView *hit = [frame hitTest:[frame convertPoint:event.locationInWindow fromView:nil]];
        // Handle the Qt header and native title in the same event path, before
        // QML starts a system drag. Leave traffic lights and other native
        // controls to AppKit.
        const bool qtHeader = hit && [hit isDescendantOf:content];
        const bool nativeTitle = [hit isKindOfClass:[NSTextField class]]
            && ![(NSTextField *)hit isEditable];
        if (!qtHeader && !nativeTitle)
            return event;

        if (_window->windowState() == Qt::WindowMaximized)
            _window->showNormal();
        else
            _window->showMaximized();
        return nil;
    }

    QWindow *_window;
    id _monitor = nil;
};
}

void enableMacTitleBarDragging(QWindow *window)
{
    if (!window || !window->flags().testFlag(Qt::ExpandedClientAreaHint))
        return;

    NSView *content = reinterpret_cast<NSView *>(window->winId());
    // QML draws a window-centered title; keep the native title value for
    // system menus and accessibility without displaying a second label.
    content.window.titleVisibility = NSWindowTitleHidden;
    // Let AppKit drag from native views that opt in through
    // mouseDownCanMoveWindow. QNSView opts out, so normal Qt content and
    // controls retain their mouse handling; the QML header handles the title.
    content.window.movableByWindowBackground = YES;
    new NativeTitleDoubleClickHandler(window);
}
