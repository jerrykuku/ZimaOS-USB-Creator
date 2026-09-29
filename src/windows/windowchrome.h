/*
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

class QWindow;

// Extend the page beneath the native DWM buttons, retaining the system frame.
void enableWindowsWindowChrome(QWindow *window);
