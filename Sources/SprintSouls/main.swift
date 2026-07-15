import AppKit

let arguments = CommandLine.arguments

if arguments.contains("--help") || arguments.contains("-h") {
    print("""
    sprint-souls — Dark Souls style sprint-start banner

    Usage:
      sprint-souls              Run in the background (used by the LaunchAgent).
                                Shows the banner on login/unlock/wake when a new
                                sprint has started since it was last shown.
      sprint-souls --preview    Play the animation immediately, then exit.

    Config: ~/.config/sprint-souls/config.json
      anchor        First sprint start, local time (e.g. "2026-07-16T08:00:00")
      intervalDays  Days between sprints (e.g. 14)
      title         Banner text (e.g. "SPRINT COMMENCED")
      subtitle      Optional smaller line under the title
      soundPath     Optional path to a sound file to play
    """)
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate(preview: arguments.contains("--preview"))
app.delegate = delegate
app.run()
