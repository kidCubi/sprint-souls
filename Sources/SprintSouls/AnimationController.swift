import AppKit
import QuartzCore

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Plays the Dark Souls style banner: the screen dims, a dark letterbox band
/// sweeps across the center, and gold serif text fades in while slowly
/// expanding, then everything fades away.
final class AnimationController {
    private var windows: [NSWindow] = []
    private var eventMonitor: Any?
    private var completion: (() -> Void)?
    private var finished = false
    private var sound: NSSound?

    private let fadeInDelay: TimeInterval = 0.4
    private let holdUntil: TimeInterval = 4.6
    private let fadeOutDuration: TimeInterval = 1.6

    // #61211F
    static let titleColor = NSColor(calibratedRed: 0x61 / 255.0, green: 0x21 / 255.0, blue: 0x1F / 255.0, alpha: 1.0)
    static let ruleColor = NSColor.white.withAlphaComponent(0.12)
    /// Vertical stretch applied to the banner text for the tall engraved look.
    static let verticalStretch: CGFloat = 1.2

    func play(title: String, subtitle: String?, soundPath: String?, completion: @escaping () -> Void) {
        self.completion = completion

        for screen in NSScreen.screens {
            let window = makeWindow(for: screen)
            buildScene(in: window, on: screen, title: title, subtitle: subtitle)
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)

        if let soundPath, let sound = NSSound(contentsOfFile: soundPath, byReference: true) {
            self.sound = sound
            sound.play()
        }

        // Any key press or click dismisses early.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.beginFadeOut(userInitiated: true)
            return nil
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + holdUntil) { [weak self] in
            self?.beginFadeOut(userInitiated: false)
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView?.wantsLayer = true
        return window
    }

    private func buildScene(in window: NSWindow, on screen: NSScreen, title: String, subtitle: String?) {
        guard let root = window.contentView?.layer else { return }
        let bounds = CGRect(origin: .zero, size: screen.frame.size)
        let scale = screen.backingScaleFactor

        // Full-screen dim.
        let dim = CALayer()
        dim.frame = bounds
        dim.backgroundColor = NSColor.black.cgColor
        dim.opacity = 0
        root.addSublayer(dim)

        // Letterbox band across the center with soft vertical edges.
        let bandHeight = bounds.height * 0.30
        let band = CAGradientLayer()
        band.frame = CGRect(x: 0, y: bounds.midY - bandHeight / 2, width: bounds.width, height: bandHeight)
        band.colors = [
            NSColor.black.withAlphaComponent(0).cgColor,
            NSColor.black.withAlphaComponent(0.85).cgColor,
            NSColor.black.withAlphaComponent(0.85).cgColor,
            NSColor.black.withAlphaComponent(0).cgColor,
        ]
        band.locations = [0, 0.32, 0.68, 1]
        band.startPoint = CGPoint(x: 0.5, y: 0)
        band.endPoint = CGPoint(x: 0.5, y: 1)
        band.opacity = 0
        root.addSublayer(band)

        // Thin gold rules above and below the text.
        let ruleWidth = bounds.width * 0.42
        for offset: CGFloat in [bandHeight * 0.36, -bandHeight * 0.36] {
            let rule = CALayer()
            rule.frame = CGRect(
                x: bounds.midX - ruleWidth / 2,
                y: bounds.midY + offset - 0.5,
                width: ruleWidth,
                height: 1
            )
            rule.backgroundColor = AnimationController.ruleColor.cgColor
            rule.opacity = 0
            band.superlayer?.addSublayer(rule)
            animateBanner(rule, expand: false)
        }

        // Title text, nudged 20px below center.
        let titleSize = bounds.height * 0.085
        let titleLayer = textLayer(
            text: title.uppercased(),
            fontSize: titleSize,
            kern: max(0, titleSize * 0.22 - 10),
            color: AnimationController.titleColor,
            bounds: bounds,
            contentsScale: scale
        )
        titleLayer.position = CGPoint(x: bounds.midX, y: bounds.midY + (subtitle == nil ? 0 : titleSize * 0.28) - 20)
        root.addSublayer(titleLayer)

        if let subtitle, !subtitle.isEmpty {
            let subSize = titleSize * 0.32
            let subLayer = textLayer(
                text: subtitle,
                fontSize: subSize,
                kern: subSize * 0.18,
                color: NSColor(calibratedWhite: 0.82, alpha: 1.0),
                bounds: bounds,
                contentsScale: scale
            )
            subLayer.position = CGPoint(x: bounds.midX, y: bounds.midY - titleSize * 0.75 - 20)
            root.addSublayer(subLayer)
            animateBanner(subLayer, expand: false)
        }

        // Dim fades in first, then the banner elements.
        let dimIn = CABasicAnimation(keyPath: "opacity")
        dimIn.fromValue = 0
        dimIn.toValue = 0.55
        dimIn.duration = 0.9
        dimIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        dim.opacity = 0.55
        dim.add(dimIn, forKey: "in")

        animateBanner(band, expand: false)
        animateBanner(titleLayer, expand: true)
    }

    /// Renders the text into a generously padded image so tall glyphs
    /// (Trajan's caps overshoot the font's nominal line height) never get
    /// clipped the way they do inside a CATextLayer.
    private func textLayer(text: String, fontSize: CGFloat, kern: CGFloat, color: NSColor, bounds: CGRect, contentsScale: CGFloat) -> CALayer {
        let font = Self.bannerFont(size: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .kern: kern,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()

        let padding = fontSize * 0.5
        let stretch = AnimationController.verticalStretch
        let imageSize = NSSize(width: textSize.width + padding * 2, height: (textSize.height + padding * 2) * stretch)
        let image = NSImage(size: imageSize, flipped: false) { _ in
            NSGraphicsContext.current?.cgContext.scaleBy(x: 1, y: stretch)
            attributed.draw(at: NSPoint(x: padding, y: padding))
            return true
        }

        let layer = CALayer()
        layer.bounds = CGRect(origin: .zero, size: imageSize)
        layer.contents = image.layerContents(forContentsScale: contentsScale)
        layer.contentsScale = contentsScale
        layer.opacity = 0
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = 0.45
        layer.shadowRadius = fontSize * 0.10
        layer.shadowOffset = .zero
        return layer
    }

    /// Serif font in the spirit of the game's Garamond. First installed candidate wins.
    static func bannerFont(size: CGFloat) -> NSFont {
        let candidates = ["Adobe Garamond Pro", "GaramondBE-Condensed", "Trajan Pro", "TrajanPro-Regular", "EB Garamond", "Cormorant Garamond", "Garamond", "Cochin", "Baskerville"]
        for name in candidates {
            if let font = NSFont(name: name, size: size) { return font }
        }
        let descriptor = NSFont.systemFont(ofSize: size, weight: .regular).fontDescriptor.withDesign(.serif)
        return descriptor.flatMap { NSFont(descriptor: $0, size: size) } ?? NSFont.systemFont(ofSize: size)
    }

    private func animateBanner(_ layer: CALayer, expand: Bool) {
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 1.5
        fadeIn.beginTime = CACurrentMediaTime() + fadeInDelay
        fadeIn.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fadeIn.fillMode = .backwards
        layer.opacity = 1
        layer.add(fadeIn, forKey: "in")

        if expand {
            // The signature slow "YOU DIED" expansion.
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 1.0
            grow.toValue = 1.07
            grow.duration = holdUntil + fadeOutDuration
            grow.beginTime = CACurrentMediaTime() + fadeInDelay
            grow.timingFunction = CAMediaTimingFunction(name: .linear)
            grow.isRemovedOnCompletion = false
            grow.fillMode = .forwards
            layer.add(grow, forKey: "grow")
        }
    }

    private func beginFadeOut(userInitiated: Bool) {
        guard !finished else { return }
        finished = true

        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        if userInitiated {
            sound?.stop()
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in windows {
                window.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            guard let self else { return }
            for window in self.windows {
                window.orderOut(nil)
            }
            self.windows.removeAll()
            self.waitForSoundToFinish()
        })
    }

    /// Sounds longer than the animation ring out after the banner is gone
    /// (important in --preview mode, where completion terminates the app).
    private func waitForSoundToFinish() {
        if let sound, sound.isPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.waitForSoundToFinish()
            }
            return
        }
        let completion = self.completion
        self.completion = nil
        completion?()
    }
}
