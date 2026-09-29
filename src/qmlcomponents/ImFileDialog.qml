/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025 Raspberry Pi Ltd
 */

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import RpiImager

BaseDialog {
    id: dialog
    title: dialogTitle
    anchors.centerIn: parent
    header: null
    popupType: Popup.Item
    closePolicy: Popup.CloseOnEscape
    background: Rectangle {
        color: Style.colorSurfacePanel
        radius: Style.radiusPanel
        border.color: Style.colorBorderSubtle
        border.width: Style.borderWidthDefault
        antialiasing: true
    }

    component BrowserField: ImTextField {
        id: field
        implicitHeight: Math.max(Style.buttonHeightStandard, implicitContentHeight + Style.spacingSmallPlus)
        color: Style.colorTextPrimary
        placeholderTextColor: Style.colorTextSecondary
        leftPadding: Style.spacingSmallPlus
        rightPadding: Style.spacingSmallPlus
        background: Rectangle {
            color: Style.colorSurfacePanel
            radius: Style.radiusButton
            border.color: field.activeFocus ? Style.focusOutlineColor : Style.colorBorderSubtle
            border.width: field.activeFocus ? Style.focusOutlineWidth : Style.borderWidthDefault
            antialiasing: true
        }
    }

    // Public API (aligning loosely with FileDialog)
    property string dialogTitle: qsTr("Select File")
    property url currentFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    // Back-compat property name some callers may set
    property url folder: currentFolder
    property var nameFilters: [] // ["Images (*.png *.jpg)", "All files (*)"]
    property url selectedFile: ""
    
    // Save dialog mode - when true, shows filename input and hides file list
    property bool isSaveDialog: false
    property string suggestedFilename: ""

    // Use Dialog's built-in accepted/rejected signals; do not redeclare to avoid overrides

    property string _currentFilename: suggestedFilename
    property string _pathFieldFile: ""
    
    function open() {
        // For save dialogs, initialize filename from suggestion
        if (isSaveDialog) {
            _currentFilename = suggestedFilename
        }
        dialog.visible = true
    }
    function close() { dialog.visible = false }
    
    // Build the full file path from current folder and filename (for save mode)
    function _buildFilePath() {
        var folder = _toDisplayPath(currentFolder)
        var filename = String(_currentFilename).trim()
        if (!filename) return ""
        // Ensure folder ends with /
        if (!folder.endsWith("/")) folder += "/"
        return folder + filename
    }

    // Override BaseDialog defaults for file dialog specific sizing
    width: Math.max(0, Math.min(Style.scaled(720), parent ? parent.width - Style.spacingPopupInset * 2 : Style.scaled(720)))
    height: Math.max(0, Math.min(Style.scaled(540), parent ? parent.height - Style.spacingPopupInset * 2 : Style.scaled(540)))

    // Convert Qt-style nameFilters to FolderListModel.nameFilters
    function _extractGlobs(filters) {
        var out = []
        for (var i = 0; i < filters.length; i++) {
            var f = String(filters[i])
            var lb = f.indexOf("(")
            var rb = f.indexOf(")")
            if (lb >= 0 && rb > lb) {
                var inner = f.substring(lb+1, rb)
                var globs = inner.split(/\s+/).filter(g => g.length > 0)
                out = out.concat(globs)
            } else if (f.indexOf("*") >= 0) {
                out.push(f)
            }
        }
        if (out.length === 0) out = ["*"]
        return out
    }

    function _looksLikeFilePath(path) {
        var s = String(path || "").trim()
        if (!s || s.endsWith("/"))
            return false
        var lastSlash = s.lastIndexOf("/")
        var basename = (lastSlash >= 0) ? s.substring(lastSlash + 1) : s
        return basename.indexOf(".") > 0
    }

    // Normalize a typed path to a file URL
    function _tofileUrl(path) {
        if (!path)
            return "";
        var s = String(path).trim()
        // Expand ~ to home
        if (s === "~" || s.indexOf("~/") === 0) {
            var home = String(StandardPaths.writableLocation(StandardPaths.HomeLocation))
            s = home + s.substring(1)
        }
        if (s.indexOf("file://") === 0)
            return s
        // Allow absolute paths
        if (s.indexOf("/") === 0)
            return "file://" + s
        return s // fallback; caller may provide URL
    }

    // Convert a URL to a display path (strip file:// scheme)
    function _toDisplayPath(u) {
        var s = String(u || "").trim()
        if (s.indexOf("file://") === 0) {
            var p = s.substring(7)
            return p.length > 0 ? p : "/"
        }
        return s
    }

    // Get enforced image globs from provided filters; otherwise return defaults
    function _getImageGlobs(filters) {
        var globs = dialog._extractGlobs(filters)
        var specific = globs.filter(function(g) { return g !== "*" })
        if (specific.length > 0)
            return specific
        // Default accepted image formats
        return ["*.img", "*.zip", "*.iso", "*.gz", "*.xz", "*.zst", "*.wic"]
    }

    // Return true if the given url/path resolves to filesystem root
    function _isRoot(u) {
        var s = String(u || "").trim()
        if (s.indexOf("file://") === 0) s = s.substring(7)
        // Normalize trailing slashes
        while (s.length > 1 && s.endsWith("/")) s = s.substring(0, s.length - 1)
        return s === "/"
    }

    // Compute normalized parent folder URL without '..' segments
    function _parentUrl(u) {
        var s = String(u || "").trim()
        if (s.indexOf("file://") === 0) s = s.substring(7)
        // Strip trailing slashes
        while (s.length > 1 && s.endsWith("/")) s = s.substring(0, s.length - 1)
        if (s === "/") return "file:///"
        var slash = s.lastIndexOf("/")
        if (slash <= 0) return "file:///"
        var parent = s.substring(0, slash)
        if (parent.length === 0) parent = "/"
        return "file://" + parent
    }

    function _canGoUp() { return !_isRoot(dialog.currentFolder) }
    function _goUp() { if (_canGoUp()) dialog.currentFolder = _parentUrl(dialog.currentFolder) }

    // Data models - only scan folders when dialog is visible to avoid triggering
    // macOS permission dialogs during component initialization
    FolderListModel {
        id: folderModel
        folder: dialog.visible ? dialog.currentFolder : ""
        showDirs: true
        showFiles: true
        showDotAndDotDot: true
        nameFilters: dialog._extractGlobs(dialog.nameFilters)
        sortField: FolderListModel.Name
        sortReversed: false
    }

    // Directories-only model for left pane (subfolders of current folder)
    FolderListModel {
        id: dirsOnlyModel
        folder: dialog.visible ? dialog.currentFolder : ""
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        sortReversed: false
        nameFilters: ["*"]
    }

    // Files-only model for right pane (files of current folder)
    FolderListModel {
        id: filesOnlyModel
        folder: dialog.visible ? dialog.currentFolder : ""
        showDirs: false
        showFiles: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        sortReversed: false
        nameFilters: dialog._getImageGlobs(dialog.nameFilters)
    }

    // Places model for left pane
    ListModel { id: placesModel }

    onCurrentFolderChanged: {
        // Ensure address bar follows folder changes
        pathField.text = dialog._toDisplayPath(dialog.currentFolder)
        // Reset selection when navigating
        dialog.selectedFile = ""
        dialog._pathFieldFile = ""
    }

    // Override escape handler to call rejected signal
    function escapePressed() {
        dialog.close()
        dialog.rejected()
    }
    
    // Initialize and register focus groups when component is ready
    Component.onCompleted: {
        registerFocusGroup("heading", function() {
            return ImageWriterSingleton.screenReaderActive ? [titleText] : []
        }, -1)
        // Keep the browser aligned with the other application panels.
        if (contentLayout) {
            contentLayout.anchors.margins = Style.spacingPopupInset
            contentLayout.spacing = Style.spacingSmallPlus
        }
        
        // Add places based on dialog mode
        if (dialog.isSaveDialog) {
            // Save dialogs get common save locations
            var docsPath = String(StandardPaths.writableLocation(StandardPaths.DocumentsLocation))
            if (docsPath && docsPath.length > 0) {
                placesModel.append({ label: qsTr("Documents"), url: "file://" + docsPath })
            }
            
            var downloadPath = String(StandardPaths.writableLocation(StandardPaths.DownloadLocation))
            if (downloadPath && downloadPath.length > 0) {
                placesModel.append({ label: qsTr("Downloads"), url: "file://" + downloadPath })
            }
            
            var homePath = String(StandardPaths.writableLocation(StandardPaths.HomeLocation))
            if (homePath && homePath.length > 0) {
                placesModel.append({ label: qsTr("Home"), url: "file://" + homePath })
            }
        } else {
            // Open dialogs get removable drives shortcut based on platform
            var removableDrivesPath = ""
            if (Qt.platform.os === "linux") {
                removableDrivesPath = "file:///mnt"
            } else if (Qt.platform.os === "osx" || Qt.platform.os === "darwin") {
                removableDrivesPath = "file:///Volumes"
            } else if (Qt.platform.os === "windows") {
                // On Windows, show root which lists all drives
                removableDrivesPath = "file:///"
            } else {
                // Fallback to root for other platforms
                removableDrivesPath = "file:///"
            }
            placesModel.append({ label: qsTr("Removable drives"), url: removableDrivesPath })
        }
        
        // Initialize path field text
        pathField.text = dialog._toDisplayPath(dialog.currentFolder)
        
        // Register focus groups - different order for save vs open dialogs
        if (dialog.isSaveDialog) {
            registerFocusGroup("filename", function(){ 
                return [filenameField] 
            }, 0)
            registerFocusGroup("address", function(){ 
                return [pathField] 
            }, 1)
            registerFocusGroup("places", function(){ 
                return [placesList] 
            }, 2)
            registerFocusGroup("folders", function(){ 
                return [subfoldersList] 
            }, 3)
            registerFocusGroup("buttons", function(){ 
                return [cancelButton, openButton] 
            }, 4)
        } else {
            registerFocusGroup("address", function(){ 
                return [pathField] 
            }, 0)
            registerFocusGroup("places", function(){ 
                return [placesList] 
            }, 1)
            registerFocusGroup("folders", function(){ 
                return [subfoldersList] 
            }, 2)
            registerFocusGroup("navigation", function(){ 
                return [upEntry] 
            }, 3)
            registerFocusGroup("files", function(){ 
                return [filesList] 
            }, 4)
            registerFocusGroup("buttons", function(){ 
                return [cancelButton, openButton] 
            }, 5)
        }
    }

    FocusableHeading {
        id: titleText
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: dialog.dialogTitle
        font.pixelSize: Style.fontSizeHeadingChrome
        font.family: Style.fontFamilyBold
        font.bold: true
        color: Style.formLabelColor
    }

    // Address bar
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        spacing: 12

        // ImTextField rather than a bare TextField so that a path pasted with a
        // trailing newline is scrubbed on the way in (see issues #1627, #1687);
        // it also supplies the font, focus and accessibility defaults this field
        // previously set by hand.
        BrowserField {
            id: pathField
            objectName: "filePathField"
            Layout.fillWidth: true
            text: dialog._toDisplayPath(dialog.currentFolder)
            placeholderText: dialog.isSaveDialog
                ? qsTr("Enter path or URL\u2026")
                : qsTr("Enter folder or file path\u2026")
            trimWhitespace: true
            onTextChanged: {
                if (!dialog.isSaveDialog) {
                    dialog._pathFieldFile = dialog._looksLikeFilePath(pathField.value)
                        ? dialog._tofileUrl(pathField.value) : ""
                }
            }
            onAccepted: {
                var newUrl = dialog._tofileUrl(text)
                if (newUrl && newUrl.length > 0) {
                    dialog.currentFolder = newUrl
                }
            }
        }
    }
    
    // Filename input row (only for save dialogs)
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        spacing: 12
        visible: dialog.isSaveDialog
        
        Text {
            text: qsTr("File name:")
            font.pointSize: Style.fontSizeFormLabel
            font.family: Style.fontFamily
            color: Style.formLabelColor
        }
        
        BrowserField {
            id: filenameField
            objectName: "fileFilenameField"
            Layout.fillWidth: true
            text: dialog._currentFilename
            placeholderText: qsTr("Enter filename…")
            activeFocusOnTab: dialog.isSaveDialog
            trimWhitespace: true
            onTextChanged: {
                dialog._currentFilename = text
            }
            onAccepted: {
                if (text.trim().length > 0) {
                    dialog.selectedFile = dialog._tofileUrl(dialog._buildFilePath())
                    dialog.close()
                    dialog.accepted()
                }
            }
        }
    }

    // Main content with left navigation and file list
    RowLayout {
        id: mainRow
        Layout.preferredHeight: Style.scaled(300)
        Layout.minimumHeight: 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        // Left navigation pane
        Frame {
            implicitWidth: 0
            implicitHeight: 0
            id: leftPane
            Layout.minimumHeight: 0
            Layout.preferredWidth: Math.min(Style.scaled(180), (dialog.width - Style.spacingPopupInset * 2) * 0.32)
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            clip: true
            padding: 8
            background: Rectangle {
                color: Style.colorSurfacePage
                radius: Style.cornerRadius(Style.sectionBorderRadius)
                border.color: Style.colorBorderSubtle
                border.width: Style.sectionBorderWidth
                antialiasing: true
                clip: true
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 4

                ListView {
                    id: placesList
                    Layout.fillWidth: true
                    Layout.preferredHeight: contentHeight
                    Layout.maximumHeight: Math.max(Style.buttonHeightStandard, leftPane.availableHeight * 0.45)
                    Layout.minimumHeight: 0
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: Style.scrollBarWidth }
                    clip: true
                    activeFocusOnTab: true
                    focusPolicy: Qt.TabFocus
                    model: placesModel
                    currentIndex: -1  // No item selected by default
                    highlightFollowsCurrentItem: true
                    highlight: Rectangle {
                        color: placesList.activeFocus ? Style.colorSelectionSurface : Qt.rgba(0, 0, 0, 0.05)
                        radius: Style.cornerRadius(Style.listItemBorderRadius)
                        antialiasing: true
                        visible: placesList.currentIndex >= 0
                    }
                    
                    // Set focus to first item when list receives focus
                    onActiveFocusChanged: {
                        if (activeFocus && currentIndex < 0 && count > 0) {
                            currentIndex = 0
                        }
                    }
                    delegate: ItemDelegate {
                        required property int index
                        required property var model
                        
                        width: (ListView.view ? ListView.view.width : 0)
                        text: model.label
                        highlighted: ListView.isCurrentItem
                        Accessible.role: Accessible.ListItem
                        Accessible.name: text
                        background: Rectangle {
                            color: {
                                if (ListView.isCurrentItem && placesList.activeFocus)
                                    return Style.colorSelectionSurface
                                else if (leftPane.hovered)
                                    return Style.colorSurfaceMuted
                                else
                                    return "transparent"
                            }
                            radius: Style.cornerRadius(Style.listItemBorderRadius)
                            antialiasing: true
                        }
                        onClicked: {
                            placesList.currentIndex = index
                            dialog.currentFolder = model.url
                        }
                    }
                    Keys.onUpPressed: {
                        if (currentIndex > 0) {
                            currentIndex--
                        }
                    }
                    Keys.onDownPressed: {
                        if (currentIndex < count - 1) {
                            currentIndex++
                        }
                    }
                    Keys.onEnterPressed: {
                        if (currentIndex >= 0) {
                            dialog.currentFolder = model.get(currentIndex).url
                        }
                    }
                    Keys.onReturnPressed: {
                        if (currentIndex >= 0) {
                            dialog.currentFolder = model.get(currentIndex).url
                        }
                    }
                }

                Text { 
                    text: qsTr("Folders")
                    // Leave room for actual folders when the browser is short.
                    visible: leftPane.availableHeight >= Style.scaled(140)
                    font.pointSize: Style.fontSizeDescription
                    color: Style.colorTextPrimary
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 2
                }

                ListView {
                    id: subfoldersList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    activeFocusOnTab: true
                    focusPolicy: Qt.TabFocus
                    model: dirsOnlyModel
                    spacing: 2
                    currentIndex: -1  // No item selected by default
                    highlightFollowsCurrentItem: true
                    highlight: Rectangle {
                        color: subfoldersList.activeFocus ? Style.colorSelectionSurface : Qt.rgba(0, 0, 0, 0.05)
                        radius: Style.cornerRadius(Style.listItemBorderRadius)
                        antialiasing: true
                        visible: subfoldersList.currentIndex >= 0
                    }
                    
                    // Set focus to first item when list receives focus
                    onActiveFocusChanged: {
                        if (activeFocus && currentIndex < 0 && count > 0) {
                            currentIndex = 0
                        }
                    }
                    
                    // Reset to first item when folder changes while we have focus
                    onCountChanged: {
                        if (activeFocus && count > 0) {
                            currentIndex = 0
                        }
                    }
                    
                    delegate: ItemDelegate {
                        required property int index
                        required property string fileName
                        required property string fileUrl
                        
                        width: (ListView.view ? ListView.view.width : 0)
                        text: fileName
                        highlighted: ListView.isCurrentItem
                        Accessible.role: Accessible.ListItem
                        Accessible.name: qsTr("Folder: %1").arg(fileName)
                        background: Rectangle {
                            color: {
                                if (ListView.isCurrentItem && subfoldersList.activeFocus)
                                    return Style.colorSelectionSurface
                                else if (leftPane.hovered)
                                    return Style.colorSurfaceMuted
                                else
                                    return "transparent"
                            }
                            radius: Style.cornerRadius(Style.listItemBorderRadius)
                            antialiasing: true
                        }
                        onClicked: {
                            subfoldersList.currentIndex = index
                            dialog.currentFolder = fileUrl
                        }
                    }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: Style.scrollBarWidth }
                    Keys.onUpPressed: {
                        if (currentIndex > 0) {
                            currentIndex--
                        }
                    }
                    Keys.onDownPressed: {
                        if (currentIndex < count - 1) {
                            currentIndex++
                        }
                    }
                    Keys.onEnterPressed: {
                        if (currentIndex >= 0) {
                            dialog.currentFolder = model.get(currentIndex, "fileUrl")
                        }
                    }
                    Keys.onReturnPressed: {
                        if (currentIndex >= 0) {
                            dialog.currentFolder = model.get(currentIndex, "fileUrl")
                        }
                    }
                }
            }
        }

        // File list
        Frame {
            implicitWidth: 0
            implicitHeight: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 8
            background: Rectangle {
                color: Style.colorSurfacePage
                radius: Style.cornerRadius(Style.sectionBorderRadius)
                border.color: Style.colorBorderSubtle
                border.width: Style.sectionBorderWidth
                antialiasing: true
                clip: true
            }

            // Unified scroll area: Up entry, then directories, then files
            ScrollView {
                id: fileListScrollView
                anchors.fill: parent
                activeFocusOnTab: false  // Don't focus the ScrollView itself, only its children
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: Style.scrollBarWidth }
                
                property int currentFileIndex: -1
                
                Keys.onUpPressed: {
                    if (currentFileIndex > 0) {
                        currentFileIndex--
                        // Update selection
                        var fileItem = fileColumn.children[currentFileIndex + 1] // +1 because of up entry
                        if (fileItem && fileItem.fileUrl) {
                            dialog.selectedFile = fileItem.fileUrl
                        }
                    }
                }
                Keys.onDownPressed: {
                    if (currentFileIndex < filesOnlyModel.count - 1) {
                        currentFileIndex++
                        // Update selection
                        var fileItem = fileColumn.children[currentFileIndex + 1] // +1 because of up entry
                        if (fileItem && fileItem.fileUrl) {
                            dialog.selectedFile = fileItem.fileUrl
                        }
                    }
                }
                Keys.onEnterPressed: {
                    if (dialog.selectedFile && String(dialog.selectedFile).length > 0) {
                        dialog.close()
                        dialog.accepted()
                    }
                }
                Keys.onReturnPressed: {
                    if (dialog.selectedFile && String(dialog.selectedFile).length > 0) {
                        dialog.close()
                        dialog.accepted()
                    }
                }

                Column {
                    id: fileColumn
                    width: parent.width
                    spacing: 0

                    // Up entry at top of right pane - always show when not at root
                    ImButton {
                        id: upEntry
                        width: parent.width
                        visible: dialog._canGoUp()
                        height: visible ? implicitHeight : 0
                        text: "↑ " + qsTr("Go up a folder")
                        activeFocusOnTab: true
                        onClicked: dialog._goUp()
                        
                        // Rebuild focus order when visibility changes
                        onVisibleChanged: {
                            if (dialog.rebuildFocusOrder) {
                                Qt.callLater(dialog.rebuildFocusOrder)
                            }
                        }
                        
                        // Custom styling to make it look like a navigation item
                        background: Rectangle {
                            color: upEntry.hovered ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(0, 0, 0, 0.03)
                            radius: Style.cornerRadius(Style.listItemBorderRadius)
                            border.width: upEntry.activeFocus ? 2 : 1
                            border.color: upEntry.activeFocus ? Style.focusOutlineColor : Qt.rgba(0, 0, 0, 0.1)
                            antialiasing: true
                        }
                        
                        contentItem: Text {
                            text: upEntry.text
                            font.pointSize: Style.fontSizeDescription
                            font.family: Style.fontFamily
                            font.italic: true
                            color: Style.colorTextPrimary
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            leftPadding: 4
                        }
                    }

                    // Files list with focus support (hidden in save mode)
                    ListView {
                        id: filesList
                        width: fileColumn.width
                        height: dialog.isSaveDialog ? 0 : Math.max(contentHeight, filesOnlyModel.count === 0 ? 60 : 0)
                        visible: !dialog.isSaveDialog
                        model: filesOnlyModel
                        activeFocusOnTab: !dialog.isSaveDialog && filesOnlyModel.count > 0
                        currentIndex: -1
                        highlightFollowsCurrentItem: true
                        interactive: false
                        
                        highlight: Rectangle {
                            color: filesList.activeFocus ? Style.colorSelectionSurface : Qt.rgba(0, 0, 0, 0.05)
                            radius: Style.cornerRadius(Style.listItemBorderRadius)
                            antialiasing: true
                            visible: filesList.currentIndex >= 0
                        }
                        
                        // Set focus to first item when list receives focus
                        onActiveFocusChanged: {
                            if (activeFocus && currentIndex < 0 && count > 0) {
                                currentIndex = 0
                                // Set the selected file to the first file
                                if (count > 0) {
                                    dialog.selectedFile = model.get(0, "fileUrl")
                                }
                            }
                        }
                        
                        // Navigate with arrow keys
                        Keys.onUpPressed: {
                            if (currentIndex > 0) {
                                currentIndex--
                                dialog.selectedFile = model.get(currentIndex, "fileUrl")
                            }
                        }
                        Keys.onDownPressed: {
                            if (currentIndex < count - 1) {
                                currentIndex++
                                dialog.selectedFile = model.get(currentIndex, "fileUrl")
                            }
                        }
                        
                        delegate: ItemDelegate {
                            required property int index
                            required property string fileName
                            required property string fileUrl
                            
                            width: fileColumn.width
                            text: fileName
                            icon.source: "../icons/use_custom.svg"
                            icon.width: 20
                            icon.height: 20
                            highlighted: ListView.isCurrentItem
                            Accessible.role: Accessible.ListItem
                            Accessible.name: qsTr("File: %1").arg(fileName)
                            background: Rectangle {
                                color: {
                                    if (dialog.selectedFile === fileUrl)
                                        return Style.colorSelectionSurface
                                    else if (ListView.isCurrentItem && filesList.activeFocus)
                                        return Style.colorSelectionSurface
                                    else if (hovered)
                                        return Style.colorSurfaceMuted
                                    else
                                        return "transparent"
                                }
                                radius: Style.cornerRadius(Style.listItemBorderRadius)
                                antialiasing: true
                            }
                            onClicked: {
                                filesList.currentIndex = index
                                dialog.selectedFile = fileUrl
                            }
                        }
                        
                        Keys.onReturnPressed: {
                            if (dialog.selectedFile && String(dialog.selectedFile).length > 0) {
                                dialog.close()
                                dialog.accepted()
                            }
                        }
                        Keys.onEnterPressed: {
                            if (dialog.selectedFile && String(dialog.selectedFile).length > 0) {
                                dialog.close()
                                dialog.accepted()
                            }
                        }
                        
                        // Show message when no files are available (only in open mode)
                        Text {
                            anchors.centerIn: parent
                            visible: !dialog.isSaveDialog && filesOnlyModel.count === 0
                            text: qsTr("No files in this folder")
                            font.pointSize: Style.fontSizeDescription
                            font.family: Style.fontFamily
                            font.italic: true
                            color: Style.colorTextPrimary
                        }
                    }
                    
                    // Message for save dialogs - shown instead of file list
                    Text {
                        width: fileColumn.width
                        visible: dialog.isSaveDialog
                        text: qsTr("Navigate to a folder using the panel on the left,\nor type a path in the address bar above.")
                        font.pointSize: Style.fontSizeDescription
                        font.family: Style.fontFamily
                        font.italic: true
                        color: Style.colorTextPrimary
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        topPadding: 40
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.borderWidthDefault
        color: Style.colorBorderSubtle
        Accessible.ignored: true
    }

    // Keep both actions visible with long translations.
    GridLayout {
        Layout.alignment: Qt.AlignRight
        Layout.maximumWidth: Math.ceil(cancelButton.implicitWidth) + Math.ceil(openButton.implicitWidth) + columnSpacing + 4
        columns: width >= cancelButton.implicitWidth + openButton.implicitWidth + columnSpacing ? 2 : 1
        columnSpacing: Style.spacingSmallPlus
        rowSpacing: Style.spacingTiny
        Layout.fillWidth: true
        Layout.topMargin: 6

        ImButton {
            id: cancelButton
            objectName: "fileCancelButton"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: CommonStrings.cancel
            activeFocusOnTab: true
            onClicked: { dialog.close(); dialog.rejected() }
        }
        ImButtonRed {
            id: openButton
            objectName: "fileOpenButton"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: dialog.isSaveDialog ? qsTr("Save") : qsTr("Open")
            enabled: dialog.isSaveDialog
                ? String(dialog._currentFilename).trim().length > 0
                : (String(dialog.selectedFile).length > 0 || String(dialog._pathFieldFile).length > 0)
            activeFocusOnTab: true
            onClicked: {
                if (!enabled)
                    return
                if (dialog.isSaveDialog) {
                    dialog.selectedFile = dialog._tofileUrl(dialog._buildFilePath())
                } else if (String(dialog._pathFieldFile).length > 0) {
                    dialog.selectedFile = dialog._pathFieldFile
                }
                dialog.close()
                dialog.accepted()
            }
        }
    }
}
