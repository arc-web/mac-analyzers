import SwiftUI
import AnalyzersKit
import UIComponents

/// Update pane: installed vs latest release, one-click upgrade via the
/// repo's upgrade.command (runs in Terminal so progress is visible).
struct UpdateSettingsView: View {

    @Environment(UpdateState.self) private var updates

    @Environment(Navigator.self) private var navigator

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
            "Install opens Terminal and runs upgrade.command: pulls the latest version, rebuilds the app, refreshes the background agents, and relaunches. Your settings and protected lists are never touched."
        case .beta:
            "Updating opens Terminal and runs upgrade.command on your clone: pulls the newest commit on the development branch, rebuilds the app, refreshes the background agents, and relaunches. It never happens by itself. Your settings and protected lists are never touched."
        case .thisCopy:
            "Rebuilding opens Terminal and runs rebuild.command: builds your clone as it is, uncommitted changes included, refreshes the background agents, and relaunches. Nothing is pulled. Your settings and protected lists are never touched."
        }
    }

    var body: some View {
        DataScreen(title: Names.Screen.updates, subtitle: updates.build.versionText) {
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
            Section {
                Button { navigator.push(.app(.releases)) } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                                Text(Names.WhatsNew.title)
                                Text("What each release brought, release by release.").font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "sparkles") }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.inset)
        }
        .task {
            // always fresh when the pane opens — the cache is for background
            // polling, not for the screen whose job is showing the truth
            await updates.check(force: true)
        }
    }
}
