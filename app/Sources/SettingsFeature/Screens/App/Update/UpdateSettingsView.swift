import SwiftUI
import AnalyzersKit
import UIComponents

/// Update pane: installed vs latest release, one-click upgrade via the
/// repo's upgrade.command (runs in Terminal so progress is visible).
struct UpdateSettingsView: View {

    @Environment(UpdateState.self) private var updates

    @Environment(Navigator.self) private var navigator

    @State private var notes: [ReleaseNote] = []
    @State private var filter: WhatsNewFilter = .all
    /// The release seen before this visit, read once: opening the screen marks what is installed as seen, and the
    /// "New" marks on the rows must still say what had not been.
    @State private var seenBefore: String?
    @State private var hasReadSeen = false

    // The latest release, whether one is newer and whether a check is running all come from the app's one
    // update state, so a check made here also reaches the sidebar, Overview and the menu-bar panel.
    private var installed: String { updates.installed }
    private var latest: String? { updates.latest }
    private var checking: Bool { updates.phase == .checking }
    private var updateAvailable: Bool { updates.isAvailable }

    private var installTitle: String {
        switch updates.channel {
        case .releases: "Install Update…"
        case .beta: Names.Channel.installBeta + "…"
        case .thisCopy: Names.Channel.rebuild + "…"
        }
    }

    private var installExplanation: String {
        switch updates.channel {
        case .releases:
            "Install opens Terminal and runs upgrade.command on your clone: it pulls the newest release, rebuilds the app, refreshes the background agents, and relaunches. Your settings and protected lists are never touched."
        case .beta:
            "Updating opens Terminal and runs beta.command on your clone: it moves your clone to the newest beta (or to the newer release, once one is out), rebuilds the app, refreshes the background agents, and relaunches. It never happens by itself. Your settings and protected lists are never touched."
        case .thisCopy:
            "Rebuilding opens Terminal and runs rebuild.command: builds your clone as it is, uncommitted changes included, refreshes the background agents, and relaunches. Nothing is pulled. Your settings and protected lists are never touched."
        }
    }

    var body: some View {
        DataScreen(title: Names.Screen.updates, subtitle: updates.build.versionText) {
        ScrollViewReader { proxy in
        List {
            UpdateChannelSection(updates: updates, checking: checking)
            Section {
                LabeledContent("Installed Version") { Text(updates.build.versionText).monospacedDigit() }
                if let build = UpdateChecker.installedBuild {
                    LabeledContent("Build") {
                        Text(build)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .help("The exact build of this copy; the version changes only on release")
                }
                if updates.channel == .releases {
                    LabeledContent("Latest Release") {
                        Text(latest.map { "v\($0)" } ?? (checking ? "Checking…" : "—"))
                            .monospacedDigit()
                    }
                    if updateAvailable {
                        Label(Names.State.updateAvailable, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    } else if updates.build.isDevelopment {
                        Label(updates.build.developmentSentence(latest: latest), systemImage: "hammer.fill")
                            .foregroundStyle(.blue)
                    } else if latest != nil {
                        Label(Names.State.upToDate, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    UpdateChannelRows(updates: updates, checking: checking)
                }
            }
            Section {
                HStack {
                    Button(checking ? "Checking…" : "Check Now") {
                        Task { await updates.check(force: true) }
                    }
                    .disabled(checking)
                    Spacer()
                    Button(installTitle) { updates.requestInstall() }
                        .buttonStyle(.glassProminent)
                        .disabled(!updateAvailable)
                }
                Text(installExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !notes.isEmpty {
                WhatsNewSections(notes: notes, filter: filter, seen: seenBefore)
            }
        }
        .onChange(of: notes.count) { applyPendingLink(proxy) }
        // a link that arrives while this screen is already showing and loaded is applied then, not at the next reload
        .onChange(of: navigator.pendingIntent) { applyPendingLink(proxy) }
        .listStyle(.inset)
        }
        }
        .toolbar {
            ToolbarItem {
                // a `Menu` shows its label in the toolbar, so the choice in force is the label
                Menu {
                    Picker(Names.WhatsNew.filter, selection: $filter) {
                        ForEach(WhatsNewFilter.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(filter.title, systemImage: filter.symbol)
                }
                .labelStyle(.titleAndIcon)
                .help("Choose which releases \(Names.WhatsNew.title) lists")
            }
        }
        .task(id: "\(updates.channel.rawValue)\(updates.channelChangelog?.count ?? 0)") {
            if !hasReadSeen {
                await WhatsNewSeen.migrate(installed: installed)
                seenBefore = WhatsNewSeen.version
                hasReadSeen = true
                // being on this screen is seeing what the installed version brought
                WhatsNewSeen.markSeen(installed)
            }
            notes = await WhatsNewSource.notes(updates: updates)
        }
        .task {
            // always fresh when the pane opens — the cache is for background
            // polling, not for the screen whose job is showing the truth
            await updates.check(force: true)
        }
    }

    /// `updates:whatsNew` scrolls to the list and `updates:whatsNew:latest` also narrows it to the newest release;
    /// both only navigate.
    private func applyPendingLink(_ proxy: ScrollViewProxy) {
        guard !notes.isEmpty, let payload = navigator.takeIntent(for: AppGroup.updates), payload.hasPrefix("whatsNew") else { return }
        if payload == "whatsNew:latest" { filter = .latest }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation { proxy.scrollTo(WhatsNewSections.anchor, anchor: .top) }
        }
    }
}
