import SwiftUI
import AnalyzersKit
import UIComponents

/// One topic, written with this Mac's numbers: what it does, what it never does, where it is written down, and the
/// buttons that open the screen it explains or change its settings.
struct TopicScreen: View {
    let topic: HowItWorksTopic
    @Environment(Navigator.self) private var navigator
    private var model: HowItWorksModel { .shared }

    var body: some View {
        DataScreen(title: topic.title, subtitle: topic.tab.title) {
            if let facts = model.facts {
                form(topic.content(facts))
            } else {
                LoadingState("Reading this Mac…")
            }
        }
        .task { await model.load() }
    }

    private func form(_ content: TopicContent) -> some View {
        Form {
            if !content.does.isEmpty { section(Names.HowItWorks.whatItDoes, content.does) }
            if !content.never.isEmpty { section(Names.HowItWorks.whatItNeverDoes, content.never) }
            if !content.written.isEmpty { section(Names.HowItWorks.whereItIsWritten, content.written) }
            if !content.buttons.isEmpty || topic == .healthReport {
                Section {
                    HStack {
                        ForEach(content.buttons) { button in
                            Button(button.title) { navigator.open(target: button.target) }
                        }
                        if topic == .healthReport {
                            Button(Names.HowItWorks.export) { HealthReport.save() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func section(_ title: String, _ paragraphs: [String]) -> some View {
        Section(title) {
            ForEach(paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}
