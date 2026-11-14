import SwiftUI
import AnalyzersKit
import UIComponents

/// The card at the foot of the sidebar that announces the newest release the person has not seen: "New in 2.71",
/// the release's title, the icons of its first features and a button to What's New, with a close button that
/// marks it seen without opening anything. It shows for releases only (never for the unreleased section, never on a
/// development build), never on a first launch, and comes back once with the next release. It is part of the
/// sidebar, so it goes with the sidebar and shows in the hover overlay too, on the same material as the version
/// item beneath it.
struct SidebarWhatsNewCard: View {
    let navigator: Navigator
    var floating = false

    @Environment(UpdateState.self) private var updates
    /// The release last seen; the same defaults value the Updates screen writes, so either one retires the card.
    @AppStorage(WhatsNewSeen.key) private var seen = ""
    @State private var release: ReleaseNote?

    var body: some View {
        // a stack, not a `Group`: a task on a group with nothing in it never starts, and the card is nothing until it has loaded
        VStack(spacing: 0) {
            if let release, announces(release) {
                card(release)
                    .padding([.horizontal, .top])
                    .padding(.bottom, Tokens.Space.s)
                    .frame(maxWidth: .infinity)
                    .background(floating ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.bar))
                Divider()
            }
        }
        .task {
            await WhatsNewSeen.migrate(installed: updates.installed)
            // the newest shipped release in the bundled notes; the unreleased section is never announced. Reading a
            // small file is not one of the expensive loads that queue behind each other, so it does not join them: the
            // card is there when the sidebar is, not after the screens' reads
            release = await Task.detached { ReleaseNote.newestReleased(in: ReleaseNote.bundled(includeNext: false)) }.value
        }
    }

    /// A release is announced when it is newer than the one seen, on a build that is a release.
    private func announces(_ release: ReleaseNote) -> Bool {
        !updates.build.isDevelopment && WhatsNewSeen.isNew(release.version, seen: seen)
    }

    private func card(_ release: ReleaseNote) -> some View {
        let version = release.version ?? ""
        return GroupBox {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                // one short line that always fits; the release's own title is the tooltip
                Text(Names.WhatsNew.featureCount(release.items.count))
                    .font(.callout)
                    .help(release.releaseTitle)
                HStack(spacing: Tokens.Space.m) {
                    ForEach(release.items.prefix(3)) { item in
                        Image(systemName: item.symbol ?? "sparkles")
                            .foregroundStyle(.secondary)
                            .help(item.summary)
                    }
                }
                .accessibilityHidden(true)
                Button(Names.WhatsNew.seeWhatsNew) {
                    // not marked seen here: the Updates screen marks the installed version seen once it has read what
                    // was seen before, so the rows of this release still carry "New" when it opens
                    navigator.open(target: "updates:whatsNew:latest")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack {
                Label(Names.WhatsNew.newIn(shortVersion(version)), systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button(Names.WhatsNew.dismiss, systemImage: "xmark") { WhatsNewSeen.markSeen(version) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help(Names.WhatsNew.dismiss)
            }
        }
    }

    /// "2.71.0" as "2.71": a patch of zero says nothing.
    private func shortVersion(_ version: String) -> String {
        version.hasSuffix(".0") ? String(version.dropLast(2)) : version
    }
}
