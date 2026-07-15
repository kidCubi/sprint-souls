import AppKit

/// Menu bar item: shows the next sprint date and gives access to the
/// schedule editor and a manual preview.
final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let onPreview: () -> Void
    private var settings: SettingsWindowController?

    init(onPreview: @escaping () -> Void) {
        self.onPreview = onPreview
        super.init()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = Self.menuBarIcon()
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let config = Config.load()
        let infoTitle: String
        if let anchor = config.anchorDate {
            let scheduler = Scheduler(anchor: anchor, intervalDays: config.intervalDays)
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d MMM 'at' HH:mm"
            infoTitle = "Next sprint: " + formatter.string(from: scheduler.nextBoundary(asOf: Date()))
        } else {
            infoTitle = "Invalid schedule"
        }
        let info = NSMenuItem(title: infoTitle, action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(.separator())

        menu.addItem(makeItem("Set Schedule…", action: #selector(openSettings)))
        menu.addItem(makeItem("Play Animation Now", action: #selector(playNow)))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit Sprint Souls", action: #selector(quit)))
    }

    /// Custom icon.png next to the config (user override) or next to the
    /// binary (shipped by install.sh); falls back to the flame SF Symbol.
    /// Rendered as a template image so macOS tints it for light/dark menu bars.
    private static func menuBarIcon() -> NSImage? {
        var candidates = [Config.directory.appendingPathComponent("icon.png")]
        if let executable = Bundle.main.executableURL {
            candidates.append(executable.deletingLastPathComponent().appendingPathComponent("icon.png"))
        }
        for url in candidates {
            if let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                return image
            }
        }
        return NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Sprint Souls")
    }

    private func makeItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openSettings() {
        if settings == nil { settings = SettingsWindowController() }
        settings?.show()
    }

    @objc private func playNow() {
        onPreview()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Small programmatic settings window: sprint start date/time, interval, banner text.
final class SettingsWindowController: NSObject {
    private var window: NSWindow?
    private let datePicker = NSDatePicker()
    private let intervalField = NSTextField()
    private let intervalStepper = NSStepper()
    private let titleField = NSTextField()

    func show() {
        if window == nil { build() }
        loadValues()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        datePicker.datePickerMode = .single

        let intervalFormatter = NumberFormatter()
        intervalFormatter.minimum = 1
        intervalFormatter.maximum = 365
        intervalFormatter.allowsFloats = false
        intervalField.formatter = intervalFormatter
        intervalField.alignment = .right
        intervalField.widthAnchor.constraint(equalToConstant: 44).isActive = true

        intervalStepper.minValue = 1
        intervalStepper.maxValue = 365
        intervalStepper.increment = 1
        intervalStepper.target = self
        intervalStepper.action = #selector(stepperChanged)

        titleField.placeholderString = "SPRINT COMMENCED"
        titleField.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let daysLabel = NSTextField(labelWithString: "days")
        let intervalRow = NSStackView(views: [intervalField, intervalStepper, daysLabel])
        intervalRow.orientation = .horizontal
        intervalRow.spacing = 4

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Sprint starts:"), datePicker],
            [NSTextField(labelWithString: "Repeat every:"), intervalRow],
            [NSTextField(labelWithString: "Banner text:"), titleField],
        ])
        grid.rowSpacing = 12
        grid.column(at: 0).xPlacement = .trailing

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        let buttons = NSStackView(views: [cancelButton, saveButton])
        buttons.orientation = .horizontal

        let content = NSStackView(views: [grid, buttons])
        content.orientation = .vertical
        content.alignment = .trailing
        content.spacing = 16
        content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sprint Schedule"
        window.isReleasedWhenClosed = false
        window.contentView = content
        window.setContentSize(content.fittingSize)
        self.window = window
    }

    private func loadValues() {
        let config = Config.load()
        datePicker.dateValue = config.anchorDate ?? Date()
        intervalField.integerValue = config.intervalDays
        intervalStepper.integerValue = config.intervalDays
        titleField.stringValue = config.title
    }

    @objc private func stepperChanged() {
        intervalField.integerValue = intervalStepper.integerValue
    }

    @objc private func save() {
        window?.makeFirstResponder(nil) // commit any in-progress text editing

        var config = Config.load()
        config.anchor = Config.dateFormat.string(from: datePicker.dateValue)
        config.intervalDays = max(1, min(365, intervalField.integerValue))
        let title = titleField.stringValue.trimmingCharacters(in: .whitespaces)
        config.title = title.isEmpty ? "SPRINT COMMENCED" : title
        config.save()

        window?.close()
    }

    @objc private func cancel() {
        window?.close()
    }
}
