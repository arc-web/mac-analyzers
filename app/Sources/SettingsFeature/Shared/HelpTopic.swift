import SwiftUI

extension View {
    /// The screen's help button: the system's own `HelpLink`, at the trailing end of the toolbar, which opens How It Works on
    /// the topic that explains this screen (no topic, no button). A screen says which topic and nothing else.
    ///
    ///     DataScreen(title: Names.Screen.monitor, …) { … }
    ///         .helpTopic(.measures)
    func helpTopic(_ topic: HowItWorksTopic?) -> some View {
        modifier(HelpTopicModifier(topic: topic))
    }
}

private struct HelpTopicModifier: ViewModifier {
    let topic: HowItWorksTopic?
    @Environment(Navigator.self) private var navigator

    func body(content: Content) -> some View {
        content.toolbar {
            if let topic {
                ToolbarItem(placement: .automatic) {
                    HelpLink { navigator.open(target: topic.target) }
                        .help("How It Works: \(topic.title)")
                }
                .toolbarRank(.secondary)
            }
        }
    }
}
