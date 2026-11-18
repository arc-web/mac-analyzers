import SwiftUI
import AnalyzersKit
import UIComponents

/// What's New, top level: one card per release (its title, its version and how many features it brought, its date on
/// the right). A card pushes that release's own screen, which lists its features grouped by the screen they belong to.
struct WhatsNewReleasesView: View {
    @Environment(UpdateState.self) private var updates
    @Environment(Navigator.self) private var navigator
    @State private var notes: [ReleaseNote] = []
    @State private var loaded = false
    /// The release seen before this visit, read once: opening the screen marks what is installed as seen, and the
    /// "New" marks on the cards must still say what had not been.
    @State private var seenBefore: String?

    var body: some View {
        DataScreen(title: Names.WhatsNew.title, subtitle: subtitle) {
            if !loaded {
                LoadingState()
            } else if notes.isEmpty {
                EmptyState(Names.WhatsNew.title, systemImage: "sparkles", description: Text(Names.WhatsNew.notInTheseNotes))
            } else {
                List(notes) { note in
                    card(note)
                        .listRowSeparator(.hidden)
                        .listRowBackground(RoundedRectangle(cornerRadius: Tokens.Radius.card).fill(.quaternary)
                            .padding(.vertical, Tokens.Space.xxs))
                }
                .listStyle(.inset)
            }
        }
        .task(id: "\(updates.channel.rawValue)\(updates.channelChangelog?.count ?? 0)") {
            if seenBefore == nil {
                await WhatsNewSeen.migrate(installed: updates.installed)
                seenBefore = WhatsNewSeen.version ?? ""
                // being on this screen is seeing what the installed version brought
                WhatsNewSeen.markSeen(updates.installed)
            }
            notes = await WhatsNewSource.notes(updates: updates)
            loaded = true
        }
    }

    private var subtitle: String { loaded ? "\(notes.count) \(notes.count == 1 ? "release" : "releases")" : "" }

    private func card(_ note: ReleaseNote) -> some View {
        Button { navigator.push(.app(.release(WhatsNewReleaseScreen.key(note)))) } label: {
            HStack(spacing: Tokens.Space.xl) {
                Label {
                    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                        Text(note.isUnreleased ? note.title : note.releaseTitle).font(Tokens.Typography.rowTitleKey)
                        Text(line(note)).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    IconTile(symbol: note.isUnreleased ? "hammer.fill" : "sparkles",
                             color: note.isUnreleased ? .blue : .orange, side: 28)
                }
                .labelStyle(.centeredIcon)
                Spacer(minLength: Tokens.Space.xl)
                if WhatsNewSeen.isNew(note.version, seen: seenBefore) {
                    Text(Names.WhatsNew.new).font(.caption.weight(.semibold)).foregroundStyle(.tint)
                }
                Text(note.released.map { $0.formatted(.dateTime.day().month(.abbreviated)) }
                     ?? (note.isUnreleased ? Names.WhatsNew.notYetReleased : ""))
                    .font(.callout).foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .padding(.vertical, Tokens.Space.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this release")
    }

    /// "v2.72.0 · 7 new features".
    private func line(_ note: ReleaseNote) -> String {
        let features = Names.WhatsNew.featureCount(note.listedItems.count)
        return note.version.map { "v\($0) · \(features)" } ?? features
    }
}
