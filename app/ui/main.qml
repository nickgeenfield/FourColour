import QtQuick 2.5
import net.asivery.AppLoad 1.0

// rm-comics: colour CBZ/CBR reader for AppLoad (reMarkable Paper Pro)
Rectangle {
    id: root
    anchors.fill: parent
    color: "white"

    property string comicsRoot: "/home/root/comics"
    property string currentDir: comicsRoot
    property var entries: []
    property var pages: []
    property int pageIndex: 0
    property string comicPath: ""
    property bool reading: false
    property bool busy: false
    property bool showBar: false
    property bool showSlider: false
    property string version: "v1.5"
    property string status: "Loading…"
    property int listTries: 0
    property var pendingDelete: null   // {name, path} while the confirmation is showing
    property string notice: ""

    signal close
    function unloading() { savePage(); }

    AppLoad {
        id: backend
        applicationID: "rm-comics"
        onMessageReceived: (type, contents) => {
            if (type === 101) {
                listTimer.stop();
                const d = JSON.parse(contents);
                root.currentDir = d.dir;
                root.entries = d.entries;
                root.status = d.entries.length ? "" : "No .cbz or .cbr files in " + d.dir;
            } else if (type === 102) {
                const d = JSON.parse(contents);
                root.busy = false;
                root.comicPath = d.path;
                root.pages = d.pages;
                root.pageIndex = Math.min(d.page, d.pages.length - 1);
                root.showBar = false;
                root.showSlider = false;
                root.reading = true;
            } else if (type === 103) {
                const d = JSON.parse(contents);
                root.pendingDelete = null;
                root.notice = "Deleted";
                noticeTimer.restart();
                listDir(d.dir);
            } else if (type === 198) {
                root.pendingDelete = null;
                root.notice = "Not deleted: " + contents;
                noticeTimer.restart();
            } else if (type === 199) {
                root.busy = false;
                root.status = "Could not open: " + contents;
            }
        }
    }

    function listDir(dir) { root.status = "Loading…"; backend.sendMessage(1, dir); }
    function openComic(path) { root.busy = true; root.status = ""; backend.sendMessage(2, path); }
    function deleteComic(path) { backend.sendMessage(4, path); }
    function savePage() { if (root.comicPath !== "") backend.sendMessage(3, root.pageIndex + "\t" + root.comicPath); }
    function turn(delta) {
        const n = root.pageIndex + delta;
        if (n < 0 || n >= root.pages.length) return;
        root.pageIndex = n;
        savePage();
    }
    function backToLibrary() {
        savePage();
        root.reading = false;
        root.pages = [];
        root.comicPath = "";
        listDir(root.currentDir);
    }

    // The backend may take a moment to start: retry the first listing a few times.
    Timer {
        id: listTimer
        interval: 1500; repeat: true; running: true; triggeredOnStart: true
        onTriggered: {
            if (root.listTries++ > 6) { stop(); root.status = "The reader's helper did not start. Close and reopen the app."; return; }
            listDir(root.currentDir);
        }
    }

    // ---------- Library ----------
    Item {
        anchors.fill: parent
        visible: !root.reading

        Rectangle {
            id: libBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 130; color: "black"
            Text {
                anchors { left: parent.left; leftMargin: 30; right: upBtn.left; verticalCenter: parent.verticalCenter }
                text: root.currentDir === root.comicsRoot ? "Comics" : root.currentDir.substring(root.comicsRoot.length + 1)
                color: "white"; font.pixelSize: 52; elide: Text.ElideLeft
            }
            Rectangle {
                id: upBtn
                visible: root.currentDir !== root.comicsRoot
                anchors { right: exitBtn.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
                width: visible ? 180 : 0; height: 96; color: "white"; radius: 10
                Text { anchors.centerIn: parent; text: "Up"; font.pixelSize: 44 }
                MouseArea { anchors.fill: parent; onClicked: listDir(root.currentDir.substring(0, root.currentDir.lastIndexOf("/"))) }
            }
            Text {
                anchors { bottom: parent.bottom; bottomMargin: 4; horizontalCenter: parent.horizontalCenter }
                text: root.version; color: "#bbbbbb"; font.pixelSize: 26
            }
            Rectangle {
                id: exitBtn
                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                width: 180; height: 96; color: "white"; radius: 10
                Text { anchors.centerIn: parent; text: "Exit"; font.pixelSize: 44 }
                MouseArea { anchors.fill: parent; onClicked: root.close() }
            }
        }

        ListView {
            id: list
            anchors { top: libBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            clip: true
            model: root.entries
            boundsBehavior: Flickable.StopAtBounds
            objectName: "list"
            delegate: Rectangle {
                width: list.width; height: 140
                color: "white"
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: "#999999" }
                Text {
                    anchors { left: parent.left; leftMargin: 30; right: pageTxt.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    text: (modelData.dir ? "▸ " : "") + modelData.name
                    font.pixelSize: 44; font.bold: modelData.dir; elide: Text.ElideRight
                }
                Text {
                    id: pageTxt
                    anchors { right: parent.right; rightMargin: modelData.dir ? 30 : 190; verticalCenter: parent.verticalCenter }
                    text: (modelData.page !== null && modelData.page !== undefined) ? "p. " + (modelData.page + 1) : ""
                    font.pixelSize: 36; color: "#555555"
                }
                // Own long-press timer: the ListView must not cancel it on small
                // finger/stylus jitter. Only release or a move > 40 px cancels it.
                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    preventStealing: true
                    property real sx: 0
                    property real sy: 0
                    property real lastY: 0
                    property bool held: false
                    property bool moved: false
                    onPressed: (mouse) => { sx = mouse.x; sy = mapToItem(list, mouse.x, mouse.y).y; lastY = sy; held = false; moved = false;
                                            holdTimer.restart(); }
                    onPositionChanged: (mouse) => {
                        if (!moved && (Math.abs(mouse.x - sx) > 40 || Math.abs(mapToItem(list, mouse.x, mouse.y).y - sy) > 40)) { moved = true; holdTimer.stop(); }
                        // Measure in list coordinates: the row itself moves as the list scrolls.
                        const ly = mapToItem(list, mouse.x, mouse.y).y;
                        if (moved) {   // we hold the grab, so scroll the list ourselves
                            list.contentY = Math.max(0, Math.min(list.contentY + (lastY - ly), Math.max(0, list.contentHeight - list.height)));
                        }
                        lastY = ly;
                    }
                    onReleased: (mouse) => {
                        holdTimer.stop();
                        if (!held && !moved) (modelData.dir ? listDir(modelData.path) : openComic(modelData.path));
                    }
                    onCanceled: { holdTimer.stop(); }
                    Timer {
                        id: holdTimer; interval: 800
                        // A long hold never opens anything; on a comic (not a folder) it asks to delete.
                        onTriggered: { rowMa.held = true; if (!modelData.dir) root.pendingDelete = { name: modelData.name, path: modelData.path }; }
                    }
                }
                // Fallback: visible Delete button on comic rows (not folders).
                Rectangle {
                    id: binBtn; objectName: "rowDelete_" + index
                    visible: !modelData.dir
                    anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    width: 150; height: 80; radius: 8
                    color: "white"; border.color: "black"; border.width: 3
                    Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: 34 }
                    MouseArea { anchors.fill: parent; preventStealing: true
                                onClicked: root.pendingDelete = { name: modelData.name, path: modelData.path } }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 120
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.busy ? "Opening comic…" : root.status
            font.pixelSize: 44
            visible: text !== ""
        }
    }

    Timer { id: noticeTimer; interval: 4000; onTriggered: root.notice = "" }

    // ---------- Notice (after a delete) ----------
    Rectangle {
        visible: root.notice !== "" && !root.reading
        anchors { bottom: parent.bottom; bottomMargin: 60; horizontalCenter: parent.horizontalCenter }
        width: Math.min(parent.width - 80, noticeTxt.implicitWidth + 80); height: noticeTxt.implicitHeight + 50
        color: "black"; radius: 12; z: 5
        Text { id: noticeTxt; anchors.centerIn: parent; width: Math.min(implicitWidth, root.width - 160)
               text: root.notice; color: "white"; font.pixelSize: 40; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
    }

    // ---------- Delete confirmation (plain black and white for e-ink) ----------
    Rectangle {
        id: confirm; objectName: "confirm"
        visible: root.pendingDelete !== null && !root.reading
        anchors.fill: parent; z: 10
        color: "#80ffffff"
        MouseArea { anchors.fill: parent; onClicked: root.pendingDelete = null }   // tap outside = Cancel
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 120; height: box.implicitHeight + 120
            color: "white"; border.color: "black"; border.width: 6; radius: 16
            MouseArea { anchors.fill: parent }   // taps inside the box do nothing
            Column {
                id: box
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 60 }
                spacing: 50
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    text: root.pendingDelete ? "Delete " + root.pendingDelete.name + "?" : ""
                    font.pixelSize: 52; font.bold: true
                }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    text: "The file is removed from the tablet. This cannot be undone."
                    font.pixelSize: 36; color: "#333333"
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 60
                    Rectangle {
                        id: cancelBtn; objectName: "cancelBtn"
                        width: Math.min(360, (box.width - 60) / 2); height: 130; color: "white"; border.color: "black"; border.width: 4; radius: 12
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 48 }
                        MouseArea { anchors.fill: parent; onClicked: root.pendingDelete = null }
                    }
                    Rectangle {
                        id: deleteBtn; objectName: "deleteBtn"
                        width: Math.min(360, (box.width - 60) / 2); height: 130; color: "black"; radius: 12
                        Text { anchors.centerIn: parent; text: "Delete"; color: "white"; font.pixelSize: 48; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: if (root.pendingDelete) deleteComic(root.pendingDelete.path) }
                    }
                }
            }
        }
    }

    // ---------- Reader ----------
    Item {
        anchors.fill: parent
        visible: root.reading

        Rectangle { anchors.fill: parent; color: "black" }

        Image {
            id: pageImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            sourceSize.width: root.width
            sourceSize.height: root.height
            source: (root.reading && root.pages.length) ? "file://" + root.pages[root.pageIndex] : ""
        }

        Text {
            anchors.centerIn: parent
            visible: pageImage.status === Image.Error
            text: "This page could not be shown (unsupported image type?)"
            color: "white"; font.pixelSize: 40
        }

        // v1.5 tap layout: top strip (top 12%) = top bar (Library / Exit);
        // bottom strip (bottom 12%) = page slider. Between them: left third =
        // back, right third = forward, middle third = nothing. Swipe turns pages.
        // While a bar is showing, any tap outside it just hides it.
        MouseArea {
            anchors.fill: parent
            property real startX: 0
            onPressed: (mouse) => { startX = mouse.x; }
            onReleased: (mouse) => {
                if (root.showBar || root.showSlider) { root.showBar = false; root.showSlider = false; return; }
                const dx = mouse.x - startX;
                if (Math.abs(dx) > 120) { turn(dx < 0 ? 1 : -1); return; }
                if (mouse.y < height * 0.12) { root.showBar = true; return; }
                if (mouse.y > height * 0.88) { root.showSlider = true; return; }
                if (mouse.x < width / 3) turn(-1);
                else if (mouse.x > width * 2 / 3) turn(1);
            }
        }

        Rectangle {
            visible: root.showBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 130; color: "black"; opacity: 0.85
            MouseArea { anchors.fill: parent }   // swallow taps on the bar itself
            Rectangle {
                id: backBtn
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                width: 260; height: 96; color: "white"; radius: 10
                Text { anchors.centerIn: parent; text: "Library"; font.pixelSize: 44 }
                MouseArea { anchors.fill: parent; onClicked: backToLibrary() }
            }
            Text {
                anchors.centerIn: parent
                text: "Page " + (root.pageIndex + 1) + " of " + root.pages.length
                color: "white"; font.pixelSize: 44
            }
            Text {
                anchors { right: exitTop.left; rightMargin: 24; verticalCenter: parent.verticalCenter }
                text: root.version; color: "#bbbbbb"; font.pixelSize: 32
            }
            Rectangle {
                id: exitTop
                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                width: 180; height: 96; color: "white"; radius: 10
                Text { anchors.centerIn: parent; text: "Exit"; font.pixelSize: 44 }
                MouseArea { anchors.fill: parent; onClicked: { savePage(); root.close(); } }
            }
        }
            // ---------- Page slider (bottom bar) ----------
        // Drag to scrub: only the number updates while dragging; the page loads on release.
        // Tapping anywhere on the track jumps straight there.
        Rectangle {
            id: bottomBar
            visible: root.showSlider
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 230; color: "black"; opacity: 0.85
            MouseArea { anchors.fill: parent }   // taps on the bar (off the track) don't fall through

            Item {
                id: pageSlider
                property int count: root.pages.length
                property bool dragging: false
                property int target: root.pageIndex
                property int handleSize: 110
                anchors { left: parent.left; right: parent.right; leftMargin: 60; rightMargin: 60; bottom: parent.bottom; bottomMargin: 30 }
                height: 130
                function frac(i) { return count > 1 ? i / (count - 1) : 0; }
                function indexAt(x) {
                    if (count <= 1) return 0;
                    const usable = width - handleSize;
                    const f = Math.max(0, Math.min(1, (x - handleSize / 2) / usable));
                    return Math.round(f * (count - 1));
                }
                Rectangle {   // track
                    anchors.verticalCenter: parent.verticalCenter
                    x: pageSlider.handleSize / 2; width: parent.width - pageSlider.handleSize
                    height: 14; radius: 7; color: "white"
                    visible: pageSlider.count > 1
                }
                Rectangle {   // handle
                    visible: pageSlider.count > 1
                    width: pageSlider.handleSize; height: pageSlider.handleSize; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: pageSlider.frac(pageSlider.dragging ? pageSlider.target : root.pageIndex) * (pageSlider.width - width)
                    color: "white"; border.color: "black"; border.width: 6
                }
                Text {
                    anchors.centerIn: parent
                    visible: pageSlider.count <= 1
                    text: "Single-page comic"; color: "white"; font.pixelSize: 44
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -60   // generous touch area
                    enabled: pageSlider.count > 1
                    preventStealing: true
                    onPressed: (mouse) => { pageSlider.target = pageSlider.indexAt(mouse.x); pageSlider.dragging = true; }
                    onPositionChanged: (mouse) => { if (pressed) pageSlider.target = pageSlider.indexAt(mouse.x); }
                    onReleased: (mouse) => {
                        pageSlider.target = pageSlider.indexAt(mouse.x);
                        pageSlider.dragging = false;
                        root.pageIndex = pageSlider.target;
                        savePage();
                        root.showSlider = false;
                    }
                    onCanceled: { pageSlider.dragging = false; }
                }
            }
            Text {   // live "Page X of Y" above the slider while dragging
                anchors { top: parent.top; topMargin: 12; horizontalCenter: parent.horizontalCenter }
                text: "Page " + ((pageSlider.dragging ? pageSlider.target : root.pageIndex) + 1) + " of " + root.pages.length
                color: "white"; font.pixelSize: 48; font.bold: pageSlider.dragging
                visible: pageSlider.count > 1
            }
        }
    }
}
