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

    private var note: ReleaseNote? { notes.first { $0.items.contains { $0.id == id } } }
    private var item: WhatsNewItem? { note?.items.first { $0.id == id } }

    var body: some View {
        Group {
            if let item, let note {
                content(item, in: note)
            } else if loaded {
                EmptyState(Names.WhatsNew.feature + " Not Found", systemImage: "sparkles",
                           description: Text("It is not in the release notes this copy carries."))
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
        let others = note.items.filter { $0.id != item.id }
        return Form {
            Section {
                Label {
                    Text(WhatsNewText.styled(item.body)).textSelection(.enabled)
                } icon: {
                    Image(systemName: item.symbol ?? "sparkles")
                }
                LabeledContent("Release", value: WhatsNewText.arrived(item))
                LabeledContent("Release Title", value: item.releaseTitle)
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
