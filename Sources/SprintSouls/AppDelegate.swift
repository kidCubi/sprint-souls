import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let preview: Bool
    private var animator: AnimationController?
    private var statusBar: StatusBarController?

    init(preview: Bool) {
        self.preview = preview
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if preview {
            let config = Config.load()
            show(config: config) {
                NSApp.terminate(nil)
            }
            return
        }

        statusBar = StatusBarController(onPreview: { [weak self] in
            self?.playPreview()
        })
        registerObservers()
        checkAndShow() // covers login / app start
    }

    /// Plays the banner without touching the shown-state, so the real
    /// sprint trigger still fires when it is due.
    private func playPreview() {
        guard animator == nil else { return }
        show(config: Config.load()) {}
    }

    private func registerObservers() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(triggerEvent),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(triggerEvent),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(triggerEvent),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func triggerEvent(_ notification: Notification) {
        // Small delay so the desktop is fully visible after unlock/wake.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.checkAndShow()
        }
    }

    private func checkAndShow() {
        guard animator == nil else { return }

        let config = Config.load()
        guard let anchorDate = config.anchorDate else {
            NSLog("sprint-souls: invalid anchor date '%@' in config", config.anchor)
            return
        }

        let scheduler = Scheduler(anchor: anchorDate, intervalDays: config.intervalDays)
        guard let boundary = scheduler.currentBoundary(asOf: Date()) else { return }

        let boundaryString = Config.dateFormat.string(from: boundary)
        var state = State.load()
        guard state.lastShownBoundary != boundaryString else { return }

        show(config: config) {
            state.lastShownBoundary = boundaryString
            state.save()
        }
    }

    private func show(config: Config, completion: @escaping () -> Void) {
        // "{n}" in the banner text stands for the current sprint number.
        var number = 1
        if let anchorDate = config.anchorDate {
            number = Scheduler(anchor: anchorDate, intervalDays: config.intervalDays).sprintNumber(asOf: Date())
        }
        let title = config.title.replacingOccurrences(of: "{n}", with: String(number))
        let subtitle = config.subtitle?.replacingOccurrences(of: "{n}", with: String(number))

        let animator = AnimationController()
        self.animator = animator
        animator.play(title: title, subtitle: subtitle, soundPath: config.resolvedSoundPath) { [weak self] in
            self?.animator = nil
            completion()
        }
    }
}
