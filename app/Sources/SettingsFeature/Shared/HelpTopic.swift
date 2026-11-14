import SwiftUI

/// What the focused screen tells the Help menu: the How It Works topic that explains it, and the screen's own name for the
/// menu item ("How Memory Guard Works").
struct ScreenHelp: Sendable {
    let topic: HowItWorksTopic
    let screen: String
}

extension FocusedValues {
    /// Published by a screen that has a How It Works topic; Help › How <Screen> Works reads it.
    @Entry var screenHelp: ScreenHelp?
}

extension View {
    /// A screen's help: it names its How It Works topic and its own name, and the Help menu gets "How <Screen> Works" for the
    /// focused screen (no topic, no item). With `button` (the default) the screen also shows the system's own `HelpLink` at
    /// the trailing end of the toolbar; a screen whose toolbar is already full passes `button: false` and is reached from the
    /// menu and from the topic's row in How It Works.
    ///
    ///     DataScreen(title: Names.Screen.monitor, …) { … }
    ///         .helpTopic(.measures, screen: Names.Screen.monitor)
    func helpTopic(_ topic: HowItWorksTopic?, screen: String, button: Bool = true) -> some View {
        modifier(HelpTopicModifier(topic: topic, screen: screen, button: button))
    }
}

private struct HelpTopicModifier: ViewModifier {
    let topic: HowItWorksTopic?
    let screen: String
    let button: Bool
    @Environment(Navigator.self) private var navigator

    func body(content: Content) -> some View {
        content
            // a screen covered by something pushed on top is not the focused screen
            .focusedSceneValue(\.screenHelp, topic.flatMap { navigator.path.isEmpty ? ScreenHelp(topic: $0, screen: screen) : nil })
            .toolbar {
                if let topic, button {
                    ToolbarItem(placement: .automatic) {
                        HelpLink { navigator.open(target: topic.target) }
                            .help("How \(screen) Works")
                    }
                    .toolbarRank(.secondary)
                }
            }
    }
}
