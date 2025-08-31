//@ pragma UseQApplication
import Quickshell
import "bar"
import QtQuick

ShellRoot {
    Bar {}

    // Create a Dock window per screen (NeXTSTEP-style)
    Variants {
        model: Quickshell.screens
        Dock {
            id: dock
            property var modelData
            screen: modelData
        }
    }
}
