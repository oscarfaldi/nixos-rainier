pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real cpuUsage: 0
    property real memoryUsed: 0

    property double previousTotal: 0
    property double previousIdle: 0

    function updateStats(data) {
        const parts = data.trim().split("|");

        if (parts.length < 3)
            return;

        const total = Number(parts[0]);
        const idle = Number(parts[1]);
        const memory = Number(parts[2]);

        if (previousTotal > 0 && total > previousTotal) {
            const totalDelta = total - previousTotal;
            const idleDelta = idle - previousIdle;

            cpuUsage = Math.max(
                0,
                Math.min(
                    100,
                    ((totalDelta - idleDelta) / totalDelta) * 100
                )
            );
        }

        previousTotal = total;
        previousIdle = idle;
        memoryUsed = memory;
    }

    Process {
        id: statsProcess

        command: [
            "bash",
            "-c",
            "read cpu idle <<< $(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6; exit}' /proc/stat); mem=$(awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {printf \"%.1f\", (t-a)/1024/1024}' /proc/meminfo); printf '%s|%s|%s\\n' \"$cpu\" \"$idle\" \"$mem\""
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: root.updateStats(this.text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true

        onTriggered: statsProcess.running = true
    }
}