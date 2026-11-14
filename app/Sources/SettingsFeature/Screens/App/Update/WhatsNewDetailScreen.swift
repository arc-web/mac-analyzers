import SwiftUI
import AnalyzersKit
import UIComponents

/// One feature on its own screen: what it is, when it arrived, the release it came with and a button that opens the
/// screen it belongs to. The release's other features are one level further, each its own screen.
struct WhatsNewDetailScreen: View {
    let id: String

    @Environment(UpdateState.self) private var updates
    @Environment(Navigator.self) private var navigator
    @State private var notes: [ReleaseNote] = []
    @State private var loaded = false

    private var note: ReleaseNote? { notes.first { $0.listedItems.contains { $0.id == id } } }
    private var item: WhatsNewItem? { note?.listedItems.first { $0.id == id } }

    var body: some View {
        Group {
            if let item, let note {
                content(item, in: note)
            } else if loaded {
                EmptyState(Names.WhatsNew.featureNotFound, systemImage: "sparkles",
                           description: Text(Names.WhatsNew.notInTheseNotes))
            } else {
                LoadingState()
            }
        }
        .navigationTitle(item?.summary ?? Names.WhatsNew.feature)
        .task {
            notes = await WhatsNewSource.notes(updates: updates)
            loaded = true
        }
    }

    private func content(_ item: WhatsNewItem, in note: ReleaseNote) -> some View {
        let screen = item.target.flatMap(WhatsNewGroups.screen(of:))
        let others = note.listedItems.filter { $0.id != item.id }
        return Form {
            Section {
                Label {
                    Text(WhatsNewText.styled(item.body)).textSelection(.enabled)
                } icon: {
                    Image(systemName: item.symbol ?? "sparkles")
                }
                LabeledContent(Names.WhatsNew.release, value: WhatsNewText.arrived(item))
                LabeledContent(Names.WhatsNew.releaseTitle, value: item.releaseTitle)
            }
            if let target = item.target, let screen {
                Section {
                    Button { navigator.open(target: target) } label: {
                        Label(Names.WhatsNew.open(screen.title), systemImage: screen.symbol)
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Go to \(screen.title)")
                }
            }
            if !note.intro.isEmpty {
                Section(Names.WhatsNew.aboutThisRelease) {
                    ForEach(note.intro, id: \.self) { paragraph in
                        Text(WhatsNewText.styled(paragraph)).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }
            // the paragraphs after the bullets ("Fixed: …") belong to the release; the "Other Notes" row itself already shows them
            if !note.closing.isEmpty, !item.isNotes {
                Section(Names.WhatsNew.otherNotes) {
                    ForEach(note.closing, id: \.self) { paragraph in
                        Text(WhatsNewText.styled(paragraph)).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }
            if !others.isEmpty {
                Section(Names.WhatsNew.moreInThisRelease) {
                    ForEach(others) { other in
                        WhatsNewRow(item: other, isNew: false) { navigator.push(.app(.whatsNew(other.id))) }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
