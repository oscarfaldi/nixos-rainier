pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var workspaces: []

    function update(data) {
        try {
            const parsed = JSON.parse(data);

            if (Array.isArray(parsed))
                workspaces = parsed;
        } catch (error) {
            console.log("Failed to parse niri workspaces:", error);
        }
    }

    function workspacesForScreen(screenName) {
        return workspaces.filter(ws => ws.output === screenName);
    }

    function focusWorkspace(workspace) {
        Quickshell.execDetached([
            "niri",
            "msg",
            "action",
            "focus-workspace",
            String(workspace.idx)
        ]);
    }

    Process {
        id: workspaceProcess

        command: [
            "niri",
            "msg",
            "-j",
            "workspaces"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: root.update(this.text)
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true

        onTriggered: workspaceProcess.running = true
    }
}